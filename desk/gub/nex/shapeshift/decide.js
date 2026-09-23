// decide.js — the calm-UI state machine. Raw model output flickers as
// you type; this turns a stream of systemone results into states that
// only change when a challenger wins twice (or is very sure).
//
//   normalize(res)            -> systemone answers with confidence filled in
//   rawState(res)             -> {kind: input|ghost|choose|committed}
//   decide(mem, res, text)    -> next memory
//   force / promote / gateSignals
(function () {
  const THRESHOLDS = {
    inputBelow: 0.4, commitAt: 0.7, chooseGap: 0.15, chooseFloor: 0.25,
    challengerOverride: 0.85, challengerWins: 2, dropBelow: 0.3, forcedChangeRatio: 0.3,
  };
  const SIGNAL = { choiceMin: 0.6, choiceKeep: 0.5, noulOn: 0.65, noulOff: 0.45, urgentOn: 1.2, urgentOff: 1.0 };
  const ESCAPES = new Set(['unspecified', 'other']);

  // ---- normalisation: any answer shape -> {type, value, confidence, probabilities}
  function normDist(p) {
    const out = {};
    let sum = 0;
    for (const k of Object.keys(p || {})) { const v = Math.max(0, Number(p[k]) || 0); out[k] = v; sum += v; }
    if (sum > 0) for (const k of Object.keys(out)) out[k] /= sum;
    return out;
  }
  function confidenceOf(dist) {
    const v = Object.values(dist).sort((a, b) => b - a);
    if (!v.length) return 0;
    return Math.max(0, Math.min(1, v[0] - (v[1] || 0)));
  }
  function normChoice(a, criteria) {
    const dist = normDist(a.probabilities);
    for (const k of Object.keys(criteria || {})) if (!(k in dist)) dist[k] = 0;
    let top = a.choice, best = -1;
    for (const k of Object.keys(dist)) if (dist[k] > best) { best = dist[k]; top = k; }
    if (!Object.keys(dist).length && a.choice) dist[a.choice] = 1;
    return { type: 'choice', value: top, confidence: a.confidence != null ? a.confidence : confidenceOf(dist), probabilities: dist };
  }
  function normScore(a, criteria) {
    const dist = normDist(a.probabilities);
    const n = (criteria || []).length;
    for (let i = 0; i < n; i++) if (!(String(i) in dist)) dist[String(i)] = 0;
    let score = 0;
    if (Object.keys(dist).length) for (const k of Object.keys(dist)) score += Number(k) * dist[k];
    else score = Number(a.score) || 0;
    return { type: 'score', score, confidence: a.confidence != null ? a.confidence : confidenceOf(dist), probabilities: dist };
  }
  function normNoul(a) {
    const p = Math.max(0, Math.min(1, Number(a.noul) || 0));
    return { type: 'noul', noul: p, confidence: Math.abs(p - 0.5) * 2 };
  }
  // text: a free-string answer (an LLM-backend extension; Jev has no such type)
  function normText(a) {
    const v = a == null ? '' : typeof a === 'string' ? a : a.text != null ? a.text : a.value != null ? a.value : '';
    return { type: 'text', value: String(v).trim(), confidence: String(v).trim() ? 1 : 0 };
  }
  // res: {answers, model, source}; questions: the schema
  function normalize(res, questions) {
    const out = { model: res.model || '', source: res.source || 'llm', answers: {} };
    for (const id of Object.keys(questions)) {
      const q = questions[id], a = (res.answers || {})[id] || {};
      if (q.type === 'choice') out.answers[id] = normChoice(a, q.criteria);
      else if (q.type === 'score') out.answers[id] = normScore(a, q.criteria);
      else if (q.type === 'text') out.answers[id] = normText(a);
      else out.answers[id] = normNoul(a);
    }
    return out;
  }

  // ---- ui states
  function ranked(intent) {
    return Object.entries(intent.probabilities).sort((a, b) => b[1] - a[1]);
  }
  function rawState(res) {
    const intent = res.answers.intent;
    const top = intent.value, conf = intent.confidence;
    if (top === 'none' || conf < THRESHOLDS.inputBelow) {
      const r = ranked(intent).filter(([k]) => k !== 'none');
      if (top !== 'none' && r.length >= 2) {
        const [[a, pa], [b, pb]] = r;
        if (pa > THRESHOLDS.chooseFloor && pb > THRESHOLDS.chooseFloor && pa - pb < THRESHOLDS.chooseGap) return { kind: 'choose', options: [a, b] };
      }
      return { kind: 'input' };
    }
    const r = ranked(intent);
    if (r.length >= 2) {
      const [[a, pa], [b, pb]] = r;
      if (a !== 'none' && b !== 'none' && pa > THRESHOLDS.chooseFloor && pb > THRESHOLDS.chooseFloor && pa - pb < THRESHOLDS.chooseGap) return { kind: 'choose', options: [a, b] };
    }
    if (conf < THRESHOLDS.commitAt) return { kind: 'ghost', intent: top };
    return { kind: 'committed', intent: top };
  }

  function levenshtein(a, b) {
    if (a === b) return 0;
    if (!a.length) return b.length;
    if (!b.length) return a.length;
    let prev = Array.from({ length: b.length + 1 }, (_, i) => i);
    for (let i = 1; i <= a.length; i++) {
      const cur = [i];
      for (let j = 1; j <= b.length; j++) cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
      prev = cur;
    }
    return prev[b.length];
  }
  function changedSubstantially(from, to) {
    const len = Math.max(from.length, to.length, 1);
    return levenshtein(from, to) > THRESHOLDS.forcedChangeRatio * len;
  }

  const initialMemory = { ui: { kind: 'input' }, challenger: null, forcedText: null };

  function decide(mem, res, text) {
    if (!text.trim()) return initialMemory;
    const prev = mem.ui;
    if (prev.kind === 'committed' && prev.forced && mem.forcedText !== null) {
      if (!changedSubstantially(mem.forcedText, text)) return mem;
    }
    const raw = rawState(res);
    if (prev.kind === 'committed' && !prev.forced) {
      const current = prev.intent;
      const intent = res.answers.intent;
      const top = intent.value, topConf = intent.confidence;
      const currentP = intent.probabilities[current] || 0;
      if (top === current) return { ui: prev, challenger: null, forcedText: null };
      if (top === 'none') {
        if (currentP < THRESHOLDS.dropBelow) return { ui: { kind: 'input' }, challenger: null, forcedText: null };
        return { ...mem, challenger: null };
      }
      if (topConf >= THRESHOLDS.challengerOverride) return { ui: { kind: 'committed', intent: top }, challenger: null, forcedText: null };
      const wins = mem.challenger && mem.challenger.intent === top ? mem.challenger.wins + 1 : 1;
      if (wins >= THRESHOLDS.challengerWins && topConf >= THRESHOLDS.inputBelow) return { ui: raw, challenger: null, forcedText: null };
      if (currentP < THRESHOLDS.dropBelow && topConf < THRESHOLDS.inputBelow) return { ui: { kind: 'input' }, challenger: null, forcedText: null };
      return { ui: prev, challenger: { intent: top, wins }, forcedText: null };
    }
    return { ui: raw, challenger: null, forcedText: null };
  }
  function force(intent, text) { return { ui: { kind: 'committed', intent, forced: true }, challenger: null, forcedText: text }; }
  function promote(mem) {
    if (mem.ui.kind !== 'ghost') return mem;
    return { ui: { kind: 'committed', intent: mem.ui.intent }, challenger: null, forcedText: null };
  }
  function activeIntent(ui) { return ui.kind === 'committed' || ui.kind === 'ghost' ? ui.intent : null; }

  // ---- signals with hysteresis. `used` lists the signal ids a card reads.
  const CHOICE_KEYS = ['eventMode', 'transport', 'tripType', 'expenseCategory', 'colorMood', 'timerKind', 'tone'];
  const NOUL_KEYS = ['recurring', 'isQuestion', 'hasExplicitOptions', 'isShoppingList'];
  const TEXT_KEYS = ['fromZone', 'toZone'];
  const neutralGated = { eventMode: null, transport: null, tripType: null, expenseCategory: null, colorMood: null, timerKind: null, tone: null, recurring: false, isQuestion: false, hasExplicitOptions: false, isShoppingList: false, fromZone: null, toZone: null, urgency: 0, urgent: false };
  function gateChoice(a, prev) {
    if (!a) return null;
    if (ESCAPES.has(a.value)) return null;
    if (a.confidence >= SIGNAL.choiceMin) return a.value;
    if (prev === a.value && a.confidence >= SIGNAL.choiceKeep) return prev;
    return null;
  }
  function gateNoul(a, prev) {
    const p = a ? a.noul : 0;
    if (p >= SIGNAL.noulOn) return true;
    if (p <= SIGNAL.noulOff) return false;
    return prev;
  }
  function gateSignals(prev, res, used) {
    const s = res.answers, uses = new Set(used), next = { ...neutralGated };
    for (const k of CHOICE_KEYS) if (uses.has(k)) next[k] = gateChoice(s[k], prev[k]);
    for (const k of NOUL_KEYS) if (uses.has(k)) next[k] = gateNoul(s[k], prev[k]);
    // text answers: the offline lane says '' (unknown), which never overwrites a model answer
    for (const k of TEXT_KEYS) if (uses.has(k)) next[k] = s[k] && s[k].value ? s[k].value : prev[k];
    if (uses.has('urgency') && s.urgency) {
      next.urgency = s.urgency.score;
      next.urgent = prev.urgent ? s.urgency.score > SIGNAL.urgentOff : s.urgency.score > SIGNAL.urgentOn;
    }
    return next;
  }

  window.Decide = { THRESHOLDS, normalize, rawState, decide, force, promote, activeIntent, initialMemory, gateSignals, neutralGated, confidenceOf };
})();
