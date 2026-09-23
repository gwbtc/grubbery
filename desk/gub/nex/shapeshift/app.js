// app.js — the shell. One input; every keystroke runs the offline
// classifier instantly and, after a pause, asks the model. Both feed
// the same state machine. Enter saves the card as a grub.
//
// Model scheduling (after the original's useIntent): debounce, abort
// the in-flight call when the text moves on, cache by normalised text,
// time out to offline.
(function () {
  const $ = (id) => document.getElementById(id);
  const BASE = '/grubbery/shapeshift';
  const { Decide, Classify, Parse, Cards } = window;
  const DEBOUNCE_MS = 350, TIMEOUT_MS = 8000, CACHE_MAX = 300, MIN_CHARS = 3;

  let QUESTIONS = {};
  let mem = Decide.initialMemory;
  let gated = Decide.neutralGated;
  let offlineResult = null;        // last offline result (normalised)
  let modelResult = null;          // last model result (raw from the server)
  let lastApplied = null;          // whichever fed the state machine last
  let editing = null;              // id of the saved card being edited
  let overrides = {};              // per-card user tweaks (convert target, etc.)
  let debounce = null, inflight = null, seq = 0;
  let modelOn = true;
  const cache = new Map();         // normalised text -> raw model result

  async function jget(u) { const r = await fetch(BASE + u); if (!r.ok) throw new Error(await r.text()); return r.json(); }
  async function jsend(method, u, body, opts) { const r = await fetch(BASE + u, { method, body: body == null ? undefined : JSON.stringify(body), ...(opts || {}) }); if (!r.ok) throw new Error(await r.text()); return r; }
  const norm = (t) => t.trim().replace(/\s+/g, ' ').toLowerCase();

  // ---- classification
  function apply(res, text) {
    lastApplied = res;
    mem = Decide.decide(mem, res, text);
    const intent = Decide.activeIntent(mem.ui);
    if (intent && Cards[intent]) gated = Decide.gateSignals(gated, res, Cards[intent].signals);
    render();
  }
  function classifyOffline(text) {
    offlineResult = Decide.normalize(Classify.classify(text), QUESTIONS);
    apply(offlineResult, text);
  }
  function applyModel(raw, text) {
    modelResult = raw;
    showError(raw.error ? describeError(raw) : null);
    if (!raw.error && $('input').value === text) apply(Decide.normalize(raw, QUESTIONS), text);
    hud();
    Inspector.refreshLive();
  }
  async function classifyModel(text) {
    if (!modelOn || text.trim().length < MIN_CHARS) return;
    const key = norm(text);
    if (cache.has(key)) { applyModel({ ...cache.get(key), cached: true }, text); return; }
    if (inflight) inflight.abort();
    const ctl = new AbortController();
    inflight = ctl;
    const my = ++seq;
    const timer = setTimeout(() => ctl.abort('timeout'), TIMEOUT_MS);
    hud();
    const started = performance.now();
    try {
      const raw = await (await jsend('POST', '/api/intent', { state: text, questions: QUESTIONS }, { signal: ctl.signal })).json();
      raw.latencyMs = Math.round(performance.now() - started);
      if (!raw.error) {
        cache.set(key, raw);
        if (cache.size > CACHE_MAX) cache.delete(cache.keys().next().value);
      }
      if (my === seq) applyModel(raw, text);
    } catch (e) {
      if (my !== seq) return;                       // superseded: nothing to say
      modelResult = { error: ctl.signal.aborted ? (ctl.signal.reason === 'timeout' ? 'timed out, staying offline' : 'aborted') : e.message, state: text };
      if (ctl.signal.reason !== 'user') showError(describeError(modelResult));
      hud();
      Inspector.refreshLive();
    } finally {
      clearTimeout(timer);
      if (inflight === ctl) inflight = null;
      hud();
    }
  }
  function showError(msg) {
    $('model-error').hidden = !msg;
    $('model-error-text').textContent = msg || '';
  }
  function onInput() {
    const text = $('input').value;
    overrides = {};
    clearTimeout(debounce);
    showError(null);
    if (!text.trim()) {
      if (inflight) { inflight.abort(); inflight = null; seq++; }
      mem = Decide.initialMemory; gated = Decide.neutralGated; offlineResult = null; lastApplied = null; render(); hud(); return;
    }
    classifyOffline(text);
    debounce = setTimeout(() => classifyModel(text), DEBOUNCE_MS);
  }

  // ---- rendering
  function currentCard() {
    const intent = Decide.activeIntent(mem.ui);
    if (!intent || !Cards[intent]) return null;
    const text = $('input').value;
    const parsed = Parse.parseFor(intent, text, { colorMood: gated.colorMood, fromZone: gated.fromZone, toZone: gated.toZone });
    let data = parsed.data;
    if (intent === 'convert' && overrides.to && data.from) {
      data = { ...data, to: overrides.to, result: Parse.convertValue(data.value, data.from, overrides.to) };
    }
    return { intent, data, complete: parsed.complete };
  }
  let stageResult = null, stageText = null;   // a rolled random result, kept only while the text is unchanged
  function render() {
    const stage = $('stage');
    stage.textContent = '';
    const chips = $('chips');
    chips.textContent = '';
    const ui = mem.ui;
    $('shell').dataset.state = ui.kind;
    if (ui.kind === 'choose') {
      chips.hidden = false;
      chips.appendChild(document.createTextNode('Did you mean '));
      ui.options.forEach((opt, i) => {
        const b = document.createElement('button');
        b.className = 'chip-btn'; b.textContent = Cards[opt].icon + ' ' + Cards[opt].label; b.dataset.i = i;
        b.addEventListener('click', () => { mem = Decide.force(opt, $('input').value); render(); $('input').focus(); });
        chips.appendChild(b);
      });
      $('save').disabled = true;
      Inspector.refreshLive();
      return;
    }
    chips.hidden = true;
    const cur = currentCard();
    const text = $('input').value;
    if (!cur) { $('save').disabled = true; Inspector.refreshLive(); return; }
    const def = Cards[cur.intent];
    const node = def.render({
      data: cur.data, signals: gated,
      saved: cur.intent === 'random' && stageResult && stageText === text ? { result: stageResult } : null,
      onChangeTarget: (to) => { overrides.to = to; render(); },
      onRoll: (r) => { stageResult = r; },
    });
    if (cur.intent === 'random') { stageResult = node.result; stageText = text; } else { stageResult = null; stageText = null; }
    node.classList.toggle('ghost', ui.kind === 'ghost');
    const head = document.createElement('div');
    head.className = 'card-kind';
    head.textContent = def.icon + ' ' + def.label + (ui.kind === 'ghost' ? ' · tab to keep' : mem.ui.forced ? ' · chosen' : '');
    node.prepend(head);
    stage.appendChild(node);
    $('save').disabled = ui.kind === 'ghost';
    Inspector.refreshLive();
  }
  function describeError(r) {
    const e = typeof r.error === 'string' ? r.error : JSON.stringify(r.error);
    return 'Model failed: ' + e + (r.raw ? ' — see Model tab' : '') + '. The keyword classifier is driving the card.';
  }
  function hud() {
    const h = $('hud');
    if (!modelOn) { h.textContent = 'offline · keyword classifier'; return; }
    if (inflight) { h.textContent = 'asking model…'; return; }
    if (!modelResult) { h.textContent = 'model idle'; return; }
    if (modelResult.error) { h.textContent = 'model: ' + modelResult.error; return; }
    const u = modelResult.usage || {};
    h.textContent = `${modelResult.model || 'model'} · ${modelResult.cached ? 'cached' : modelResult.latencyMs + ' ms'} · ${u.input_tokens || 0} in`;
  }

  // ---- saved cards
  async function loadCards() {
    let cards = [];
    try { cards = await jget('/api/cards'); } catch (e) { cards = []; }
    cards.sort((a, b) => (b.created || 0) - (a.created || 0));
    const list = $('saved');
    list.textContent = '';
    $('saved-head').hidden = !cards.length;
    for (const card of cards) {
      const def = Cards[card.intent];
      if (!def) continue;
      const wrap = document.createElement('div');
      wrap.className = 'saved-card' + (editing === card.id ? ' editing' : '');
      const node = def.render({
        data: card.data, signals: card.signals || Decide.neutralGated, saved: card,
        onToggle: async (i, on) => {
          const done = new Set(card.done || []);
          if (on) done.add(i); else done.delete(i);
          card.done = [...done];
          await jsend('PUT', '/api/cards/' + card.id, card);
        },
        onRoll: async (r) => { card.result = r; await jsend('PUT', '/api/cards/' + card.id, card); },
        onVote: async (i) => { card.votes = card.votes || {}; card.votes[i] = (card.votes[i] || 0) + 1; await jsend('PUT', '/api/cards/' + card.id, card); loadCards(); },
        onProgress: async (n) => { card.current = n; await jsend('PUT', '/api/cards/' + card.id, card); loadCards(); },
      });
      const bar = document.createElement('div');
      bar.className = 'saved-bar';
      const kind = document.createElement('span'); kind.className = 'card-kind'; kind.textContent = def.icon + ' ' + def.label; bar.appendChild(kind);
      const edit = document.createElement('button'); edit.className = 'small'; edit.textContent = 'Edit';
      edit.addEventListener('click', () => { editing = card.id; $('input').value = card.text; onInput(); $('input').focus(); loadCards(); });
      const del = document.createElement('button'); del.className = 'small danger'; del.textContent = 'Delete';
      del.addEventListener('click', async () => { await jsend('DELETE', '/api/cards/' + card.id); if (editing === card.id) cancelEdit(); loadCards(); });
      bar.appendChild(edit); bar.appendChild(del);
      wrap.appendChild(bar); wrap.appendChild(node);
      list.appendChild(wrap);
    }
  }
  async function save() {
    const cur = currentCard();
    if (!cur || mem.ui.kind === 'ghost') return;
    const id = editing || Date.now().toString(36);
    const card = { intent: cur.intent, text: $('input').value, data: cur.data, signals: gated, created: Math.floor(Date.now() / 1000) };
    if (cur.intent === 'random' && stageResult) card.result = stageResult;
    if (editing) {
      try { const old = (await jget('/api/cards')).find((c) => c.id === id); if (old) { card.created = old.created; card.done = old.done; } } catch (e) { /* fine */ }
    }
    await jsend('PUT', '/api/cards/' + id, card);
    cancelEdit();
    loadCards();
  }
  function cancelEdit() {
    editing = null;
    $('input').value = '';
    onInput();
  }

  // ---- explainer: shown while the box is empty; each example fills it in
  const EXAMPLES = Object.keys(Cards).map((k) => [k, Cards[k].example]);
  function renderHints() {
    const h = $('hints');
    if (h.childElementCount) return;
    let collapsed = false;
    try { collapsed = localStorage.getItem('ss-hints') === '1'; } catch (e) { /* fine */ }
    const head = document.createElement('button');
    head.className = 'hints-head';
    head.setAttribute('aria-expanded', String(!collapsed));
    head.innerHTML = '<span class="hints-chev">›</span><span>What you can type</span>';
    h.appendChild(head);
    const body = document.createElement('div');
    body.className = 'hints-body';
    const p = document.createElement('p');
    p.textContent = 'One box, nineteen shapes. Start typing and it becomes the right card: a keyword pass guesses instantly, the model confirms after you pause. Tab keeps a faint guess, Enter saves the card as a grub, / lists every card. Values are never up to the model: dates, sums, units and hex codes are computed.';
    body.appendChild(p);
    const grid = document.createElement('div');
    grid.className = 'hint-grid';
    for (const [intent, text] of EXAMPLES) {
      const b = document.createElement('button');
      b.className = 'hint';
      b.innerHTML = `<span class="hint-kind">${Cards[intent].icon} ${Cards[intent].label}</span><span class="hint-try">${esc(text)}</span>`;
      b.addEventListener('click', () => { $('input').value = text; onInput(); $('input').focus(); });
      grid.appendChild(b);
    }
    body.appendChild(grid);
    h.appendChild(body);
    h.classList.toggle('collapsed', collapsed);
    head.addEventListener('click', toggleHints);
  }
  function toggleHints() {
    const h = $('hints');
    const now = !h.classList.contains('collapsed');
    h.classList.toggle('collapsed', now);
    const head = h.querySelector('.hints-head');
    if (head) head.setAttribute('aria-expanded', String(!now));
    try { localStorage.setItem('ss-hints', now ? '1' : '0'); } catch (e) { /* fine */ }
  }

  // ---- palette
  function palette(show) {
    const p = $('palette');
    p.hidden = !show;
    if (!show) return;
    p.textContent = '';
    for (const k of Object.keys(Cards)) {
      const b = document.createElement('button');
      b.className = 'palette-item';
      b.innerHTML = `<span class="palette-icon">${Cards[k].icon}</span><span>${Cards[k].label}</span>`;
      b.addEventListener('click', () => { palette(false); mem = Decide.force(k, $('input').value); render(); $('input').focus(); });
      p.appendChild(b);
    }
  }

  // ---- inspector drawer: live | model | trace | questions
  const Inspector = (() => {
    let open = false, tab = 'live', traces = [], selected = null;
    const pretty = (o) => JSON.stringify(o, null, 2);
    function answersTable(res) {
      if (!res) return '<p class="muted">nothing yet</p>';
      let html = '<table class="insp-table">';
      for (const k of Object.keys(res.answers)) {
        const v = res.answers[k];
        let cells = '';
        if (v.type === 'choice') {
          cells = `<td class="mono">${v.value}</td><td class="r">${(v.confidence * 100).toFixed(0)}%</td><td>` +
            Object.entries(v.probabilities).sort((x, y) => y[1] - x[1]).slice(0, 5).map(([o, p]) => `<span class="pbar"><span class="pfill" style="width:${Math.max(1, p * 100)}%"></span><span class="plab">${o} ${(p * 100).toFixed(0)}</span></span>`).join('') + '</td>';
        } else if (v.type === 'score') {
          cells = `<td class="mono">${v.score.toFixed(2)}</td><td class="r">${(v.confidence * 100).toFixed(0)}%</td><td>` +
            Object.entries(v.probabilities).map(([o, p]) => `<span class="pbar"><span class="pfill" style="width:${Math.max(1, p * 100)}%"></span><span class="plab">${o} ${(p * 100).toFixed(0)}</span></span>`).join('') + '</td>';
        } else if (v.type === 'text') cells = `<td class="mono">${esc(v.value || '—')}</td><td class="r"></td><td></td>`;
        else cells = `<td class="mono">${(v.noul * 100).toFixed(0)}% yes</td><td class="r">${(v.confidence * 100).toFixed(0)}%</td><td></td>`;
        html += `<tr><th>${k}</th>${cells}</tr>`;
      }
      return html + '</table>';
    }
    function stateLine() {
      const c = mem.challenger ? ` · challenger ${mem.challenger.intent} ×${mem.challenger.wins}` : '';
      return `<div class="insp-state">ui <b>${mem.ui.kind}</b>${mem.ui.intent ? ' ' + mem.ui.intent : ''}${mem.ui.forced ? ' (forced)' : ''}${c} · applied from <b>${lastApplied ? lastApplied.source : '—'}</b></div>`;
    }
    function renderLive() {
      const modelNorm = modelResult && !modelResult.error ? Decide.normalize(modelResult, QUESTIONS) : null;
      $('insp-body').innerHTML = stateLine() +
        `<h3>Offline classifier</h3>${answersTable(offlineResult)}` +
        `<h3>Model${modelResult && modelResult.state && modelResult.state !== $('input').value ? ' <span class="muted">(for an earlier text)</span>' : ''}</h3>` +
        (modelResult && modelResult.error ? `<p class="err">${modelResult.error}</p>` : answersTable(modelNorm));
    }
    function renderModel() {
      if (!modelResult) { $('insp-body').innerHTML = '<p class="muted">no model call yet</p>'; return; }
      const { prompt, raw, answers, ...rest } = modelResult;
      $('insp-body').innerHTML =
        `<h3>Prompt</h3><pre>${esc(prompt || '')}</pre>` +
        `<h3>Raw reply</h3><pre>${esc(raw || '')}</pre>` +
        `<h3>Parsed answers</h3><pre>${esc(pretty(answers || null))}</pre>` +
        `<h3>Meta</h3><pre>${esc(pretty(rest))}</pre>`;
    }
    async function renderTrace() {
      try { traces = await jget('/api/trace'); } catch (e) { traces = []; }
      let html = `<div class="row"><button id="insp-trace-refresh" class="small">Refresh</button><button id="insp-trace-clear" class="small danger">Clear all</button><span class="muted">${traces.length} of last 50</span></div>`;
      html += '<div class="trace-list">' + traces.map((t) => `<div class="trace-row${selected === t.id ? ' sel' : ''}" data-id="${t.id}"><span class="mono muted">${t.time ? new Date(t.time * 1000).toLocaleTimeString() : ''}</span><span class="trace-state">${esc(t.state || '')}</span><span class="muted">${t.error ? '⚠ ' + esc(String(t.error)) : (t.ms != null ? t.ms + ' ms' : '')}</span></div>`).join('') + '</div>';
      html += '<div id="trace-detail"></div>';
      $('insp-body').innerHTML = html;
      $('insp-trace-refresh').addEventListener('click', renderTrace);
      $('insp-trace-clear').addEventListener('click', async () => { if (!confirm('Cull all trace grubs?')) return; await jsend('POST', '/api/trace-clear', {}); selected = null; renderTrace(); });
      for (const row of $('insp-body').querySelectorAll('.trace-row')) row.addEventListener('click', () => showTrace(row.dataset.id));
      if (selected) showTrace(selected);
    }
    async function showTrace(id) {
      selected = id;
      for (const row of $('insp-body').querySelectorAll('.trace-row')) row.classList.toggle('sel', row.dataset.id === id);
      let t;
      try { t = await jget('/api/trace/' + id); } catch (e) { $('trace-detail').innerHTML = `<p class="err">${e.message}</p>`; return; }
      const normd = !t.error && t.answers ? Decide.normalize(t, QUESTIONS) : null;
      $('trace-detail').innerHTML =
        `<div class="row"><b class="trace-state">${esc(t.state || '')}</b><button id="insp-replay" class="small">Replay now</button></div>` +
        (t.error ? `<p class="err">${esc(String(t.error))}</p>` : answersTable(normd)) +
        `<h3>Prompt</h3><pre>${esc(t.prompt || '')}</pre><h3>Raw reply</h3><pre>${esc(t.raw || '')}</pre>` +
        `<h3>Meta</h3><pre>${esc(pretty({ model: t.model, ms: t.ms, usage: t.usage, time: t.time }))}</pre>`;
      $('insp-replay').addEventListener('click', () => { cache.delete(norm((t.state || ''))); $('input').value = t.state || ''; onInput(); $('input').focus(); });
    }
    function renderQuestions() {
      $('insp-body').innerHTML = `<p class="muted">The systemone schema sent with every call. Saved to questions.json; the cache is cleared on save so replays re-ask.</p><textarea id="insp-q" class="mono" rows="24" spellcheck="false">${esc(pretty(QUESTIONS))}</textarea><div class="row"><button id="insp-q-save" class="primary small">Save</button><span id="insp-q-msg" class="muted"></span></div>`;
      $('insp-q-save').addEventListener('click', async () => {
        let q;
        try { q = JSON.parse($('insp-q').value); } catch (e) { $('insp-q-msg').textContent = e.message; return; }
        await jsend('PUT', '/api/questions', q);
        QUESTIONS = q; cache.clear();
        $('insp-q-msg').textContent = 'saved';
        onInput();
      });
    }
    function show() {
      const split = $('split');
      open = !split.hasAttribute('collapsed');
      if (!open) return;
      for (const b of $('insp-tabs').querySelectorAll('button')) b.classList.toggle('active', b.dataset.tab === tab);
      if (tab === 'live') renderLive(); else if (tab === 'model') renderModel(); else if (tab === 'trace') renderTrace(); else renderQuestions();
    }
    return {
      toggle() { $('split').toggle(); },
      open() { $('split').expand(); },
      show,
      setTab(t) { tab = t; show(); },
      refreshLive() { if (open && tab === 'live') renderLive(); },
    };
  })();
  function esc(s) { return String(s).replace(/[&<>]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c])); }

  // ---- wiring
  const input = $('input');
  input.addEventListener('input', onInput);
  input.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') { e.preventDefault(); save(); }
    else if (e.key === 'Escape') { e.preventDefault(); if (!$('palette').hidden) palette(false); else cancelEdit(); }
    else if (e.key === 'Tab' && mem.ui.kind === 'ghost') { e.preventDefault(); mem = Decide.promote(mem); render(); }
    else if (e.key === '/' && !input.value && !e.metaKey && !e.ctrlKey && !e.altKey) { e.preventDefault(); palette($('palette').hidden); }
    else if (mem.ui.kind === 'choose' && (e.key === 'ArrowLeft' || e.key === 'ArrowRight')) {
      e.preventDefault();
      const btns = $('chips').querySelectorAll('.chip-btn');
      btns[e.key === 'ArrowLeft' ? 0 : 1].click();
    }
  });
  $('save').addEventListener('click', save);
  $('model-retry').addEventListener('click', () => {
    const text = $('input').value;
    if (!text.trim()) return;
    cache.delete(norm(text));
    if (inflight) inflight.abort('user');
    clearTimeout(debounce);
    showError(null);
    modelOn = true; $('model-toggle').classList.remove('off');
    classifyModel(text);
  });
  $('model-toggle').addEventListener('click', () => { modelOn = !modelOn; $('model-toggle').classList.toggle('off', !modelOn); hud(); });
  $('inspect-toggle').addEventListener('click', () => Inspector.toggle());
  $('insp-close').addEventListener('click', () => Inspector.toggle());
  for (const b of $('insp-tabs').querySelectorAll('button')) b.addEventListener('click', () => Inspector.setTab(b.dataset.tab));
  // ⌘/ (Ctrl+/) toggles the examples from anywhere, including mid-typing;
  // pairs with bare / on an empty box opening the palette
  document.addEventListener('keydown', (e) => {
    if ((e.metaKey || e.ctrlKey) && !e.shiftKey && !e.altKey && e.key === '/') { e.preventDefault(); toggleHints(); }
  });
  document.addEventListener('click', (e) => { if (!$('palette').hidden && !$('palette').contains(e.target) && e.target !== input) palette(false); });

  (async () => {
    QUESTIONS = await jget('/api/questions');
    try { const cfg = await jget('/api/config'); $('model-name').textContent = cfg.model || ''; } catch (e) { /* fine */ }
    hud();
    renderHints();
    loadCards();
    input.focus();
    customElements.whenDefined('split-view').then(() => {
      $('split').addEventListener('sv-collapse', () => Inspector.show());
      if (location.search.includes('debug=1')) Inspector.open();
      Inspector.show();
    });
  })();
})();
