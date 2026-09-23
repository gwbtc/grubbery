// parse.js — deterministic parsers, one per card (after the original's
// src/lib/parse). The model never extracts a value; these do. Each
// returns {data, complete: 0..1}. Dates go through chrono (window.chrono,
// served alongside); time zones through Intl.
(function () {
  const collapse = (s) => s.replace(/\s+/g, ' ').trim();
  const capitalize = (s) => (s ? s.charAt(0).toUpperCase() + s.slice(1) : s);
  const titleCase = (s) => s.split(/\s+/).filter(Boolean).map(capitalize).join(' ');
  function tidy(s) {
    let out = collapse(s.replace(/[,;]+\s*$/g, '').replace(/^\s*[,;:-]+/g, ''));
    const dangling = /\s+(on|at|by|for|with|to|in|and|the|this|next|from|every)$/i;
    const leading = /^(on|at|by|for|and|the|to)\s+/i;
    for (let i = 0; i < 4; i++) {
      const next = out.replace(dangling, '').replace(leading, '');
      if (next === out) break;
      out = next;
    }
    return out.trim();
  }
  const removeRange = (text, index, length) => text.slice(0, index) + ' ' + text.slice(index + length);

  // ---------- dates via chrono, with a fallback when it isn't loaded
  function findDate(text, ref) {
    ref = ref || new Date();
    const c = window.chrono;
    if (!c) return null;
    const results = c.parse(text, ref, { forwardDate: true });
    if (!results.length) return null;
    const r = results[0];
    if (/^\d+$/.test(r.text.trim())) return null;
    return { start: r.start.date(), end: r.end ? r.end.date() : null, hasTime: r.start.isCertain('hour'), text: r.text, index: r.index };
  }
  const iso = (d) => (d ? d.toISOString() : null);

  // ---------- money
  const CURRENCY = [[/₹|\brs\.?\b|\binr\b|rupees?/i, '₹'], [/\$|\busd\b|dollars?|bucks/i, '$'], [/€|\beur(os?)?\b/i, '€'], [/£|\bgbp\b|pounds? sterling|\bquid\b/i, '£'], [/\bkr\b|\bnok\b|\bsek\b|\bdkk\b|kroner?|kronor/i, 'kr']];
  function detectCurrency(t) { for (const [re, s] of CURRENCY) if (re.test(t)) return s; return '$'; }
  const AMOUNT_RE = /(?:₹|rs\.?|inr|\$|€|£)?\s?(\d[\d,]*(?:\.\d+)?)\s?(k\b)?/i;
  function findAmount(text) {
    const re = new RegExp(AMOUNT_RE.source, 'gi');
    let m;
    while ((m = re.exec(text))) {
      const n = Number(m[1].replace(/,/g, ''));
      if (!Number.isFinite(n)) continue;
      return { value: m[2] ? n * 1000 : n, index: m.index, length: m[0].length };
    }
    return null;
  }
  function formatAmount(n, currency) {
    const rounded = Math.round(n * 100) / 100;
    return (currency || '$') + rounded.toLocaleString(undefined, { minimumFractionDigits: Number.isInteger(rounded) ? 0 : 2, maximumFractionDigits: 2 });
  }

  // ---------- event
  const LINKS = { zoom: 'Zoom', meet: 'Google Meet', 'google meet': 'Google Meet', gmeet: 'Google Meet', teams: 'Teams', facetime: 'FaceTime', skype: 'Skype', discord: 'Discord', whatsapp: 'WhatsApp' };
  const STOP = /\s+(?:on|at|in|for|about|to|from|via|over)\s+.*$/i;
  function parseEvent(text, ref) {
    let rest = ` ${collapse(text)} `;
    const date = findDate(rest, ref);
    if (date) rest = removeRange(rest, date.index, date.text.length);
    let link = null;
    const lm = rest.match(/\s(?:on|over|via)\s+(google meet|gmeet|zoom|meet|teams|facetime|skype|discord|whatsapp)\b/i);
    if (lm) { link = LINKS[lm[1].toLowerCase()] || null; rest = removeRange(rest, lm.index, lm[0].length); }
    let location = null;
    const loc = rest.match(/\s(?:at|in)\s+(?!\d)([a-z][\w' ]{1,40}?)(?=\s+(?:with|on|for)\s|\s*$)/i);
    if (loc) { location = titleCase(loc[1].trim()); rest = removeRange(rest, loc.index, loc[0].length); }
    let people = [];
    const wm = rest.match(/\swith\s+(.+)$/i);
    if (wm) {
      const segment = wm[1].replace(STOP, '');
      people = segment.split(/\s*(?:,|&|\band\b)\s*/i).map((p) => p.trim()).filter((p) => p && p.split(' ').length <= 3 && !/^(the|my|a)$/i.test(p)).map(titleCase);
      rest = rest.slice(0, wm.index) + ' ' + wm[1].slice(segment.length);
    }
    const title = capitalize(tidy(rest));
    const d = { title, date: date ? iso(date.start) : null, hasTime: date ? date.hasTime : false, people, link, location };
    return { data: d, complete: (title ? 0.35 : 0) + (d.date ? 0.3 : 0) + (d.hasTime ? 0.2 : 0) + (people.length || link || location ? 0.15 : 0) };
  }

  // ---------- reminder
  function parseReminder(text, ref) {
    let rest = ` ${collapse(text)} `;
    rest = rest.replace(/\s(?:please\s+)?(?:remind me(?:\s+to)?|reminder:?|don'?t forget(?:\s+to)?|remember to)\s/i, ' ');
    rest = rest.replace(/\s(?:urgent(?:ly)?|asap|important|!+)(?=\s|$)/gi, ' ');
    const date = findDate(rest, ref);
    if (date) rest = removeRange(rest, date.index, date.text.length);
    const d = { task: capitalize(tidy(rest)), when: date ? iso(date.start) : null, hasTime: date ? date.hasTime : false };
    return { data: d, complete: (d.task ? 0.55 : 0) + (d.when ? 0.3 : 0) + (d.hasTime ? 0.15 : 0) };
  }

  // ---------- todo
  function parseTodo(text) {
    let rest = collapse(text.replace(/\n/g, ', '));
    rest = rest.replace(/^(?:to ?do|todo list|list|shopping list|groceries|checklist)\s*:?\s*/i, '');
    let verb = null;
    const vm = rest.match(/^(buy|get|pick up|grab|order)\s+/i);
    if (vm) { verb = vm[1].toLowerCase(); rest = rest.slice(vm[0].length); }
    const items = rest.split(/\s*(?:,|;|\s&\s|\band\b|\n)\s*/i).map((s) => s.trim().replace(/^(?:buy|get|also)\s+/i, '').replace(/[.!]+$/, '')).filter(Boolean).map(capitalize);
    return { data: { items, verb }, complete: Math.min(1, items.length / 3) };
  }

  // ---------- timer
  const TUNIT = { h: 3600, m: 60, s: 1 };
  function parseTimer(text) {
    let rest = ` ${collapse(text).toLowerCase()} `;
    let seconds = 0, found = false;
    for (const [re, s] of [[/\bpomodoro\b/, 25 * 60], [/\bhalf an? hour\b/, 30 * 60], [/\ban? hour\b/, 60 * 60], [/\ba minute\b/, 60]]) {
      if (re.test(rest)) { seconds += s; found = true; if (re.source !== '\\bpomodoro\\b') rest = rest.replace(re, ' '); }
    }
    rest = rest.replace(/(\d+(?:\.\d+)?)\s*(hours?|hrs?|h|minutes?|mins?|m|seconds?|secs?|s)\b/g, (_, n, u) => { seconds += Number(n) * TUNIT[u[0]]; found = true; return ' '; });
    rest = rest.replace(/\b(\d{1,2}):(\d{2})\b/, (_, m, s) => { seconds += Number(m) * 60 + Number(s); found = true; return ' '; });
    const label = capitalize(tidy(rest.replace(/\b(?:timer|set|start|a|for|countdown|of)\b/g, ' ')));
    const d = { seconds: found ? Math.round(seconds) : null, label };
    return { data: d, complete: (d.seconds ? 0.8 : 0) + (label ? 0.2 : 0) };
  }
  function formatClock(total) {
    const s = Math.max(0, Math.round(total));
    const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60;
    return (h ? h + ':' : '') + String(m).padStart(2, '0') + ':' + String(sec).padStart(2, '0');
  }

  // ---------- habit
  const HDAYS = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
  const HDAY_RE = /\b(sun|mon|tue|tues|wed|thu|thur|thurs|fri|sat)(?:day|nesday|sday|urday|rsday)?s?\b/gi;
  const FULL_DAY = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  function spread(n) { const presets = { 1: [1], 2: [2, 4], 3: [1, 3, 5], 4: [1, 2, 4, 5], 5: [1, 2, 3, 4, 5] }; return (presets[n] || [1, 3, 5, 0, 2, 4, 6].slice(0, Math.min(7, n))).sort(); }
  function parseHabit(text) {
    let rest = ` ${collapse(text)} `;
    let days = [], perWeek = null, label = null;
    const nx = rest.match(/\b(\d|once|twice|thrice)\s*(?:x|times?)?\s*(?:a|per|each|every)\s+week\b/i);
    if (nx) { const w = nx[1].toLowerCase(); perWeek = w === 'once' ? 1 : w === 'twice' ? 2 : w === 'thrice' ? 3 : Number(w); rest = rest.replace(nx[0], ' '); label = `${perWeek}× a week`; }
    if (/\b(?:every\s*day|daily|every (?:morning|night|evening|afternoon)|each (?:day|morning|night))\b/i.test(rest)) {
      days = [0, 1, 2, 3, 4, 5, 6];
      const part = rest.match(/\b(?:every|each)\s+(morning|night|evening|afternoon)\b/i);
      label = part ? `Every ${part[1].toLowerCase()}` : 'Daily';
      rest = rest.replace(/\b(?:every\s*day|daily|every (?:morning|night|evening|afternoon)|each (?:day|morning|night))\b/gi, ' ');
    } else if (/\b(?:weekdays|every weekday)\b/i.test(rest)) { days = [1, 2, 3, 4, 5]; label = 'Weekdays'; rest = rest.replace(/\b(?:every\s+)?weekdays?\b/gi, ' '); }
    else if (/\b(?:weekends|every weekend)\b/i.test(rest)) { days = [0, 6]; label = 'Weekends'; rest = rest.replace(/\b(?:every\s+)?weekends?\b/gi, ' '); }
    else {
      const found = new Set();
      rest = rest.replace(HDAY_RE, (m, d) => { const i = HDAYS.indexOf(d.slice(0, 3).toLowerCase()); if (i >= 0) found.add(i); return ' '; });
      if (found.size) { days = [...found].sort(); if (!label) label = days.length === 1 ? `Every ${FULL_DAY[days[0]]}` : `${days.length}× a week`; }
    }
    if (!label && /\bweekly\b/i.test(rest)) { perWeek = 1; label = 'Weekly'; }
    rest = rest.replace(/\b(?:every|each|weekly|habit|routine|start|i want to|i will|i'll|and)\b/gi, ' ');
    rest = rest.replace(/\b(?:in the )?(?:morning|night|evening)s?\b/gi, ' ');
    if (!days.length && perWeek) days = spread(perWeek);
    const d = { title: capitalize(tidy(rest)), days, perWeek, label };
    return { data: d, complete: (d.title ? 0.5 : 0) + (label ? 0.5 : 0) };
  }

  // ---------- split / expense
  const WORD_NUM = { two: 2, three: 3, four: 4, five: 5, six: 6, seven: 7, eight: 8, nine: 9, ten: 10 };
  function parseSplit(text) {
    let rest = text, people = null;
    const n = rest.match(/\b(?:between|among|amongst|with|by|for|into)\s+(\d+|two|three|four|five|six|seven|eight|nine|ten)\b(?:\s*(?:people|persons|friends|of us|ways))?/i)
      || rest.match(/\b(\d+|two|three|four|five|six|seven|eight|nine|ten)\s*(?:ways|people|persons|friends|of us)\b/i);
    if (n) { people = WORD_NUM[n[1].toLowerCase()] || Number(n[1]); rest = rest.replace(n[0], ' '); }
    else {
      const names = rest.match(/\b(?:between|among|with)\s+(.+)$/i);
      if (names) {
        const parts = names[1].split(/\s*(?:,|&|\band\b)\s*/i).filter((p) => /[a-z]/i.test(p));
        if (parts.length >= 2) people = parts.length; else if (parts.length === 1 && !/\d/.test(parts[0])) people = 2;
        rest = rest.replace(names[0], ' ');
      }
    }
    const amount = findAmount(rest);
    const d = { total: amount ? amount.value : null, people: people && people > 0 ? people : null, currency: detectCurrency(text) };
    d.each = d.total && d.people ? Math.round((d.total / d.people) * 100) / 100 : null;
    return { data: d, complete: (d.total ? 0.55 : 0) + (d.people ? 0.45 : 0) };
  }
  function parseExpense(text) {
    const amount = findAmount(text);
    const rest = amount ? removeRange(text, amount.index, amount.length) : text;
    const on = rest.match(/\b(?:on|for|at|in)\s+(.+)$/i);
    let item = on ? on[1] : rest;
    item = item.replace(/\b(?:spent|paid|pay|bought|cost|costs|rupees|rs|bucks|dollars|today|yesterday)\b/gi, ' ');
    const d = { amount: amount ? amount.value : null, item: capitalize(tidy(item)), currency: detectCurrency(text) };
    return { data: d, complete: (d.amount ? 0.6 : 0) + (d.item ? 0.4 : 0) };
  }

  // ---------- convert (a hand-rolled table; no convert-units)
  const FACTORS = {
    length: { km: 1000, mi: 1609.344, m: 1, cm: 0.01, mm: 0.001, ft: 0.3048, in: 0.0254, yd: 0.9144 },
    mass: { kg: 1, g: 0.001, lb: 0.45359237, oz: 0.028349523 },
    volume: { l: 1, ml: 0.001, gal: 3.785411784, cup: 0.2365882365, 'fl-oz': 0.0295735296 },
    speed: { 'km/h': 1, 'm/h': 1.609344, 'm/s': 3.6 },
  };
  const ALIASES = {
    km: 'km', kms: 'km', kilometer: 'km', kilometers: 'km', kilometre: 'km', kilometres: 'km', mi: 'mi', mile: 'mi', miles: 'mi',
    m: 'm', meter: 'm', meters: 'm', metre: 'm', metres: 'm', cm: 'cm', centimeter: 'cm', centimeters: 'cm', centimetre: 'cm', centimetres: 'cm',
    mm: 'mm', millimeter: 'mm', millimeters: 'mm', ft: 'ft', foot: 'ft', feet: 'ft', in: 'in', inch: 'in', inches: 'in', yd: 'yd', yard: 'yd', yards: 'yd',
    kg: 'kg', kgs: 'kg', kilo: 'kg', kilos: 'kg', kilogram: 'kg', kilograms: 'kg', g: 'g', gram: 'g', grams: 'g', lb: 'lb', lbs: 'lb', pound: 'lb', pounds: 'lb', oz: 'oz', ounce: 'oz', ounces: 'oz',
    l: 'l', liter: 'l', liters: 'l', litre: 'l', litres: 'l', ml: 'ml', milliliter: 'ml', milliliters: 'ml', millilitre: 'ml', millilitres: 'ml', gal: 'gal', gallon: 'gal', gallons: 'gal', cup: 'cup', cups: 'cup',
    c: 'C', '°c': 'C', celsius: 'C', centigrade: 'C', f: 'F', '°f': 'F', fahrenheit: 'F', k: 'K', kelvin: 'K',
    'km/h': 'km/h', kmh: 'km/h', kph: 'km/h', mph: 'm/h',
  };
  const DEFAULT_TARGET = { km: 'mi', mi: 'km', m: 'ft', cm: 'in', mm: 'in', ft: 'm', in: 'cm', yd: 'm', kg: 'lb', g: 'oz', lb: 'kg', oz: 'g', l: 'gal', ml: 'fl-oz', gal: 'l', cup: 'ml', C: 'F', F: 'C', K: 'C', 'km/h': 'm/h', 'm/h': 'km/h' };
  const LABELS = { km: 'km', mi: 'mi', m: 'm', cm: 'cm', mm: 'mm', ft: 'ft', in: 'in', yd: 'yd', kg: 'kg', g: 'g', lb: 'lb', oz: 'oz', l: 'L', ml: 'mL', gal: 'gal', cup: 'cup', 'fl-oz': 'fl oz', C: '°C', F: '°F', K: 'K', 'km/h': 'km/h', 'm/h': 'mph', 'm/s': 'm/s' };
  const UNIT_PATTERN = Object.keys(ALIASES).sort((a, b) => b.length - a.length).map((u) => u.replace(/[/.*+?^${}()|[\]\\]/g, '\\$&')).join('|');
  const FULL_RE = new RegExp(`(-?\\d+(?:\\.\\d+)?)\\s*(${UNIT_PATTERN})\\s+(?:to|in|into|as|=|->)\\s+(${UNIT_PATTERN})(?![a-z])`, 'i');
  const PART_RE = new RegExp(`(-?\\d+(?:\\.\\d+)?)\\s*(${UNIT_PATTERN})(?![a-z])`, 'i');
  const toC = (v, u) => (u === 'C' ? v : u === 'F' ? (v - 32) * 5 / 9 : v - 273.15);
  const fromC = (v, u) => (u === 'C' ? v : u === 'F' ? v * 9 / 5 + 32 : v + 273.15);
  function convertValue(v, from, to) {
    if (['C', 'F', 'K'].includes(from)) return ['C', 'F', 'K'].includes(to) ? fromC(toC(v, from), to) : null;
    for (const table of Object.values(FACTORS)) if (from in table && to in table) return v * table[from] / table[to];
    return null;
  }
  function unitOptions(unit) {
    if (['C', 'F', 'K'].includes(unit)) return ['C', 'F', 'K'];
    for (const table of Object.values(FACTORS)) if (unit in table) return Object.keys(table);
    return [];
  }
  function parseConvert(text) {
    const t = text.toLowerCase().replace(/degrees?\s+/g, '°').replace(/°\s+/g, '°');
    const full = t.match(FULL_RE);
    if (full) {
      const value = Number(full[1]), from = ALIASES[full[2]], to = ALIASES[full[3]];
      const result = convertValue(value, from, to);
      if (result !== null) return { data: { value, from, to, result }, complete: 1 };
    }
    const part = t.match(PART_RE);
    if (part) {
      const value = Number(part[1]), from = ALIASES[part[2]], to = DEFAULT_TARGET[from] || null;
      const result = to ? convertValue(value, from, to) : null;
      return { data: { value, from, to, result }, complete: 0.7 + (result !== null ? 0.3 : 0) };
    }
    return { data: { value: null, from: null, to: null, result: null }, complete: 0 };
  }

  // ---------- calc (shunting-yard; never eval)
  const PREC = { '+': 1, '-': 1, '*': 2, '/': 2, '^': 3, 'u-': 4 };
  const RIGHT = new Set(['^', 'u-']);
  function normalizeExpression(text) {
    let s = text.toLowerCase().trim();
    s = s.replace(/^(?:what(?:'s| is)|calc(?:ulate)?|compute|how much is)\s+/, '').replace(/[=?]+\s*$/, '');
    s = s.replace(/(\d),(\d{3})/g, '$1$2');
    s = s.replace(/(\d+(?:\.\d+)?)\s*%\s*off\s+(\d+(?:\.\d+)?)/g, '$2*(1-$1/100)');
    s = s.replace(/(\d+(?:\.\d+)?)\s*%\s*of\s+/g, '($1/100)*');
    s = s.replace(/(\d+(?:\.\d+)?)\s*%/g, '($1/100)');
    s = s.replace(/\bplus\b/g, '+').replace(/\bminus\b/g, '-').replace(/\b(?:times|multiplied by)\b/g, '*');
    s = s.replace(/\b(?:divided by|over)\b/g, '/').replace(/\bsquared\b/g, '^2').replace(/\bcubed\b/g, '^3');
    s = s.replace(/[×x]/g, '*').replace(/÷/g, '/').replace(/\*\*/g, '^');
    return s;
  }
  function tokenize(s) {
    const out = [];
    let i = 0;
    while (i < s.length) {
      const c = s[i];
      if (c === ' ') { i++; continue; }
      if (/[\d.]/.test(c)) { let j = i; while (j < s.length && /[\d.]/.test(s[j])) j++; const v = Number(s.slice(i, j)); if (!Number.isFinite(v)) return null; out.push({ t: 'num', v }); i = j; continue; }
      if ('+-*/^'.includes(c)) { const prev = out[out.length - 1]; const unary = c === '-' && (!prev || prev.t === 'op' || prev.t === 'lp'); out.push({ t: 'op', v: unary ? 'u-' : c }); i++; continue; }
      if (c === '(') { const prev = out[out.length - 1]; if (prev && (prev.t === 'num' || prev.t === 'rp')) out.push({ t: 'op', v: '*' }); out.push({ t: 'lp' }); i++; continue; }
      if (c === ')') { out.push({ t: 'rp' }); i++; continue; }
      return null;
    }
    return out;
  }
  function evaluate(expr) {
    const tokens = tokenize(expr);
    if (!tokens || !tokens.length) return null;
    const output = [], ops = [];
    for (const tok of tokens) {
      if (tok.t === 'num') output.push(tok);
      else if (tok.t === 'op') {
        while (ops.length) { const top = ops[ops.length - 1]; if (top.t !== 'op') break; const p1 = PREC[tok.v], p2 = PREC[top.v]; if (p2 > p1 || (p2 === p1 && !RIGHT.has(tok.v))) output.push(ops.pop()); else break; }
        ops.push(tok);
      } else if (tok.t === 'lp') ops.push(tok);
      else { while (ops.length && ops[ops.length - 1].t !== 'lp') output.push(ops.pop()); if (!ops.length) return null; ops.pop(); }
    }
    while (ops.length) { const op = ops.pop(); if (op.t === 'lp') return null; output.push(op); }
    const stack = [];
    for (const tok of output) {
      if (tok.t === 'num') stack.push(tok.v);
      else if (tok.t === 'op') {
        if (tok.v === 'u-') { if (!stack.length) return null; stack.push(-stack.pop()); continue; }
        if (stack.length < 2) return null;
        const b = stack.pop(), a = stack.pop();
        stack.push(tok.v === '+' ? a + b : tok.v === '-' ? a - b : tok.v === '*' ? a * b : tok.v === '/' ? a / b : a ** b);
      }
    }
    if (stack.length !== 1 || !Number.isFinite(stack[0])) return null;
    return stack[0];
  }
  const prettyExpression = (expr) => expr.replace(/\s+/g, '').replace(/\*/g, ' × ').replace(/\//g, ' ÷ ').replace(/\+/g, ' + ').replace(/(?<=[\d)])-/g, ' − ');
  function parseCalc(text) {
    const norm = normalizeExpression(text);
    const result = evaluate(norm);
    const pretty = /%/.test(text) ? text.trim().replace(/[=?]+\s*$/, '') : prettyExpression(norm);
    const d = { expression: pretty, result: result === null ? null : Math.round(result * 1e10) / 1e10 };
    return { data: d, complete: d.result !== null ? 1 : d.expression ? 0.3 : 0 };
  }

  // ---------- travel
  function weekend(ref, next) {
    const d = new Date(ref); d.setHours(0, 0, 0, 0);
    const day = d.getDay();
    const sat = new Date(d); sat.setDate(d.getDate() + (day === 0 ? -1 : 6 - day));
    if (next && (day === 5 || day === 6 || day === 0)) sat.setDate(sat.getDate() + 7);
    const sun = new Date(sat); sun.setDate(sat.getDate() + 1);
    return [sat, sun];
  }
  const TRAVEL_STOP = /\s+(?:to|next|this|on|for|from|in|by|via|tomorrow|today|tonight|with|and|trip|flight|train|bus|weekend|week|month|work|business|vacation|holiday|leave|leaving|return(?:ing)?|jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?|(?:mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)(?:day)?|\d)\b.*$/i;
  function parseTravel(text, ref) {
    ref = ref || new Date();
    let rest = ` ${collapse(text)} `;
    let start = null, end = null;
    const wk = rest.match(/\b(this|next)\s+weekend\b/i);
    if (wk) { [start, end] = weekend(ref, wk[1].toLowerCase() === 'next'); rest = rest.replace(wk[0], ' '); }
    else {
      const date = findDate(rest.replace(/[–—]/g, '-'), ref);
      if (date) { start = date.start; end = date.end; rest = removeRange(rest, date.index, date.text.length); }
    }
    const grab = (re) => { const m = rest.match(re); if (!m) return null; const place = ` ${m[1]}`.replace(TRAVEL_STOP, '').trim(); return place ? titleCase(place) : null; };
    const destination = grab(/\b(?:to|for|visit(?:ing)?|in)\s+([a-z][a-z .'-]{1,40})/i);
    const origin = grab(/\bfrom\s+([a-z][a-z .'-]{1,40})/i);
    const d = { destination, origin, start: iso(start), end: iso(end) };
    return { data: d, complete: (destination ? 0.5 : 0) + (start ? 0.35 : 0) + (end ? 0.15 : 0) };
  }

  // ---------- poll
  const QUESTION_START = /^(?:should|shall|what|which|where|when|who|do|does|would|want|let'?s|vote|poll)\b/i;
  const POLL_CONTEXT = /\s+((?:for|on|at|this|next|tonight|tomorrow|today)\b.*)$/i;
  function parsePoll(text) {
    let t = collapse(text).replace(/\?+$/, '');
    let stem = null;
    const colon = t.indexOf(':');
    if (colon > 0) { stem = t.slice(0, colon).trim(); t = t.slice(colon + 1).trim(); }
    let parts = t.split(/\s*(?:,|\bor\b|\bvs\.?\b|\/)\s*/i).filter(Boolean);
    if (parts.length < 2) return { data: { title: stem ? `${capitalize(stem)}?` : '', options: [] }, complete: stem ? 0.2 : 0 };
    let context = null;
    const last = parts[parts.length - 1];
    const cm = last.match(POLL_CONTEXT);
    if (cm && cm.index > 0) { context = cm[1]; parts[parts.length - 1] = last.slice(0, cm.index); }
    if (!stem && QUESTION_START.test(parts[0])) {
      const words = parts[0].split(' ');
      const take = Math.max(1, parts[1].split(' ').length);
      if (words.length > take) { stem = words.slice(0, words.length - take).join(' '); parts[0] = words.slice(words.length - take).join(' '); }
    }
    parts = parts.map((p) => p.trim()).filter(Boolean);
    const base = capitalize(stem || parts.join(' or '));
    parts = parts.map(capitalize);
    const d = { title: `${base}${context ? ` ${context}` : ''}?`, options: parts };
    return { data: d, complete: Math.min(1, parts.length / 2) * 0.8 + (d.title ? 0.2 : 0) };
  }

  // ---------- contact
  const EMAIL_RE = /[\w.+-]+@[\w-]+(?:\.[\w-]+)+/;
  const PHONE_RE = /(?:\+?\d{1,3}[\s-]?)?\(?\d{3,5}\)?[\s-]?\d{3,5}[\s-]?\d{0,5}/;
  function formatPhone(raw) {
    const digits = raw.replace(/\D/g, '');
    if (digits.length === 10) return `(${digits.slice(0, 3)}) ${digits.slice(3, 6)}-${digits.slice(6)}`;
    if (digits.length === 11 && digits.startsWith('1')) return `+1 (${digits.slice(1, 4)}) ${digits.slice(4, 7)}-${digits.slice(7)}`;
    return raw.trim();
  }
  function parseContact(text) {
    let rest = collapse(text);
    const em = rest.match(EMAIL_RE);
    const email = em ? em[0].toLowerCase() : null;
    if (em) rest = rest.replace(em[0], ' ');
    let phone = null;
    const pm = rest.match(PHONE_RE);
    if (pm && pm[0].replace(/\D/g, '').length >= 7) { phone = formatPhone(pm[0]); rest = rest.replace(pm[0], ' '); }
    const name = titleCase(rest.replace(/\b(?:save|add|contact|number|phone|email|mail|is|his|her|their|new|:)\b/gi, ' ').replace(/[^a-z\s'.-]/gi, ' ').trim());
    const initials = name.split(' ').filter(Boolean).slice(0, 2).map((w) => w[0].toUpperCase()).join('');
    const d = { name, phone, email, initials };
    return { data: d, complete: (name ? 0.4 : 0) + (phone || email ? 0.4 : 0) + (phone && email ? 0.2 : 0) };
  }

  // ---------- link
  const URL_RE = /\b((?:https?:\/\/|www\.)[^\s]+|[a-z0-9-]+(?:\.[a-z0-9-]+)*\.(?:com|dev|io|app|org|net|co|ai|in|so|xyz|me|design|sh|gg|tv)(?:\/[^\s]*)?)/i;
  function parseLink(text) {
    const m = text.match(URL_RE);
    if (!m) return { data: { url: null, domain: null, monogram: '', note: capitalize(tidy(text)) }, complete: 0 };
    const raw = m[1].replace(/[.,)]+$/, '');
    const url = /^https?:\/\//i.test(raw) ? raw : `https://${raw}`;
    let domain = null;
    try { domain = new URL(url).hostname.replace(/^www\./, ''); } catch (e) { domain = raw.replace(/^https?:\/\//, '').split('/')[0]; }
    const note = capitalize(tidy(collapse(text.replace(m[0], ' '))));
    const d = { url, domain, monogram: (domain ? domain[0] : '').toUpperCase(), note };
    return { data: d, complete: 0.8 + (note ? 0.2 : 0) };
  }

  // ---------- countdown
  const HOLIDAYS = {
    christmas: [11, 25], xmas: [11, 25], 'christmas eve': [11, 24], 'new year': [0, 1], 'new years': [0, 1], "new year's": [0, 1], 'new years eve': [11, 31], "new year's eve": [11, 31],
    halloween: [9, 31], "valentine's day": [1, 14], 'valentines day': [1, 14], valentines: [1, 14], 'independence day': [6, 4], 'fourth of july': [6, 4], '4th of july': [6, 4], thanksgiving: null, 'st patricks day': [2, 17], "st patrick's day": [2, 17],
  };
  const startOfDay = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate());
  const daysBetween = (from, to) => Math.round((startOfDay(to).getTime() - startOfDay(from).getTime()) / 86400000);
  function thanksgiving(year) { const nov1 = new Date(year, 10, 1); const first = (4 - nov1.getDay() + 7) % 7 + 1; return new Date(year, 10, first + 21); }
  function parseCountdown(text, ref) {
    ref = ref || new Date();
    let rest = ` ${collapse(text)} `;
    let date = null, title = '';
    for (const name of Object.keys(HOLIDAYS).sort((a, b) => b.length - a.length)) {
      const re = new RegExp(`\\b${name.replace(/'/g, "'?")}\\b`, 'i');
      const m = rest.match(re);
      if (!m) continue;
      const md = HOLIDAYS[name];
      if (md) { date = new Date(ref.getFullYear(), md[0], md[1]); if (daysBetween(ref, date) < 0) date = new Date(ref.getFullYear() + 1, md[0], md[1]); }
      else { date = thanksgiving(ref.getFullYear()); if (daysBetween(ref, date) < 0) date = thanksgiving(ref.getFullYear() + 1); }
      title = name.replace(/\b\w/g, (c) => c.toUpperCase()).replace("'S", "'s");
      rest = rest.replace(m[0], ' ');
      break;
    }
    if (!date) { const hit = findDate(rest, ref); if (hit) { date = hit.start; rest = removeRange(rest, hit.index, hit.text.length); } }
    if (!title) title = capitalize(tidy(rest.replace(/\b(?:how many|days?|weeks?|until|till|til|to go|left|countdown|count down|before|is it|are there|the|my)\b/gi, ' ').replace(/\?/g, ' ')));
    const d = { title, date: iso(date), days: date ? daysBetween(ref, date) : null };
    return { data: d, complete: (date ? 0.7 : 0) + (title ? 0.3 : 0) };
  }

  // ---------- timezone: the model names IANA zones, Intl validates and converts.
  // A dozen aliases keep the offline preview honest before the model answers.
  const ZONE_ALIASES = {
    pst: 'America/Los_Angeles', pdt: 'America/Los_Angeles', pt: 'America/Los_Angeles', mst: 'America/Denver', mdt: 'America/Denver', cst: 'America/Chicago', cdt: 'America/Chicago', ct: 'America/Chicago',
    est: 'America/New_York', edt: 'America/New_York', et: 'America/New_York', utc: 'UTC', gmt: 'Europe/London', bst: 'Europe/London', cet: 'Europe/Paris', cest: 'Europe/Paris', ist: 'Asia/Kolkata', jst: 'Asia/Tokyo', aest: 'Australia/Sydney', sgt: 'Asia/Singapore',
    'new york': 'America/New_York', nyc: 'America/New_York', chicago: 'America/Chicago', denver: 'America/Denver', 'los angeles': 'America/Los_Angeles', la: 'America/Los_Angeles', 'san francisco': 'America/Los_Angeles', seattle: 'America/Los_Angeles',
    london: 'Europe/London', paris: 'Europe/Paris', berlin: 'Europe/Berlin', oslo: 'Europe/Oslo', tokyo: 'Asia/Tokyo', sydney: 'Australia/Sydney', dubai: 'Asia/Dubai', singapore: 'Asia/Singapore', mumbai: 'Asia/Kolkata', delhi: 'Asia/Kolkata', 'hong kong': 'Asia/Hong_Kong', toronto: 'America/Toronto',
  };
  const ZONE_RE = new RegExp('\\b(' + Object.keys(ZONE_ALIASES).sort((a, b) => b.length - a.length).join('|') + ')\\b', 'gi');
  let ZONE_SET = null;
  function validZone(tz) {
    if (!tz || typeof tz !== 'string') return null;
    if (!ZONE_SET) { try { ZONE_SET = new Set(Intl.supportedValuesOf('timeZone')); } catch (e) { ZONE_SET = new Set(); } ZONE_SET.add('UTC'); }
    if (ZONE_SET.has(tz)) return tz;
    try { new Intl.DateTimeFormat('en-US', { timeZone: tz }); return tz; } catch (e) { return null; }
  }
  const localZone = () => Intl.DateTimeFormat().resolvedOptions().timeZone;
  const zoneLabel = (tz) => (tz === localZone() ? 'Local' : tz.split('/').pop().replace(/_/g, ' '));
  function tzOffset(tz, at) {
    const p = Object.fromEntries(new Intl.DateTimeFormat('en-US', { timeZone: tz, hourCycle: 'h23', year: 'numeric', month: 'numeric', day: 'numeric', hour: 'numeric', minute: 'numeric' }).formatToParts(at).map((x) => [x.type, x.value]));
    return Math.round((Date.UTC(+p.year, +p.month - 1, +p.day, +p.hour % 24, +p.minute) - at.getTime()) / 60000);
  }
  function ymdIn(tz, at) {
    const p = Object.fromEntries(new Intl.DateTimeFormat('en-US', { timeZone: tz, year: 'numeric', month: 'numeric', day: 'numeric' }).formatToParts(at).map((x) => [x.type, x.value]));
    return { y: +p.year, m: +p.month - 1, d: +p.day };
  }
  function wallTimeToInstant(tz, h, m, ref) {
    const { y, m: mo, d } = ymdIn(tz, ref);
    const guess = Date.UTC(y, mo, d, h, m);
    let at = new Date(guess - tzOffset(tz, new Date(guess)) * 60000);
    at = new Date(guess - tzOffset(tz, at) * 60000);
    return at;
  }
  const formatIn = (tz, at) => new Intl.DateTimeFormat('en-US', { timeZone: tz, hour: 'numeric', minute: '2-digit' }).format(at);
  function dayShift(fromTz, toTz, at) { const a = ymdIn(fromTz, at), b = ymdIn(toTz, at); return Math.sign(Date.UTC(b.y, b.m, b.d) - Date.UTC(a.y, a.m, a.d)); }
  function parseTimezone(text, ctx) {
    const ref = (ctx && ctx.ref) || new Date();
    const t = text.toLowerCase();
    const hits = [...t.matchAll(ZONE_RE)].map((m) => ({ tz: ZONE_ALIASES[m[1]], index: m.index }));
    const time = t.match(/\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b|\b(\d{1,2}):(\d{2})\b|\b(noon|midnight)\b/);
    let hm = null;
    if (time) {
      if (time[6]) hm = time[6] === 'noon' ? [12, 0] : [0, 0];
      else if (time[3]) { let h = Number(time[1]) % 12; if (time[3] === 'pm') h += 12; hm = [h, Number(time[2] || 0)]; }
      else hm = [Number(time[4]), Number(time[5])];
    }
    let from, to;
    if (hits.length >= 2) { from = hits[0].tz; to = hits[1].tz; }
    else if (hits.length === 1) {
      const before = t.slice(0, hits[0].index).trimEnd();
      const isTarget = /\b(?:in|to|into|for|at)$/.test(before) || !hm;
      from = isTarget ? localZone() : hits[0].tz;
      to = isTarget ? hits[0].tz : localZone();
    } else { from = localZone(); to = null; }
    // the model's answer wins over the alias table, if it names a real zone
    const mf = ctx && validZone(ctx.fromZone), mt = ctx && validZone(ctx.toZone);
    if (mf) from = mf;
    if (mt) to = mt;
    if (mt && !mf && hits.length === 0 && hm) { /* "3pm in tokyo": local -> tokyo */ }
    const instant = hm ? wallTimeToInstant(from, hm[0], hm[1], ref) : ref;
    const d = { instant: iso(instant), isNow: !hm, from, to, fromLabel: zoneLabel(from), toLabel: to ? zoneLabel(to) : null };
    if (to) { d.fromTime = formatIn(from, instant); d.toTime = formatIn(to, instant); d.dayShift = dayShift(from, to, instant); }
    return { data: d, complete: (to ? 0.7 : 0) + (hm ? 0.3 : 0.1) };
  }

  // ---------- random (dice, coin, number range, pick one)
  function parseRandom(text) {
    const t = text.toLowerCase().trim();
    let m;
    if ((m = t.match(/(\d*)\s*d\s*(\d+)/))) {
      const count = Math.max(1, Math.min(20, Number(m[1] || 1))), sides = Math.max(2, Math.min(1000, Number(m[2])));
      return { data: { kind: 'dice', count, sides }, complete: 1 };
    }
    if (/\b(dice|die)\b/.test(t)) {
      // "2 20 sided dice", "a twenty-sided die", "roll 3 d8s"
      const sm = t.match(/\b(\d+|four|six|eight|ten|twelve|twenty|hundred)\s*-?\s*sided\b/);
      const SIDES = { four: 4, six: 6, eight: 8, ten: 10, twelve: 12, twenty: 20, hundred: 100 };
      const sides = sm ? (SIDES[sm[1]] || Number(sm[1]) || 6) : 6;
      const rest = sm ? t.replace(sm[0], ' ') : t;
      const n = rest.match(/\b(\d+|two|three|four|five|six)\b/);
      const count = n ? (WORD_NUM[n[1]] || Number(n[1]) || 1) : (/\bdice\b/.test(t) ? 2 : 1);
      return { data: { kind: 'dice', count: Math.min(20, count), sides: Math.max(2, Math.min(1000, sides)) }, complete: 0.9 };
    }
    if (/\b(coin|heads or tails|flip)\b/.test(t)) return { data: { kind: 'coin' }, complete: 1 };
    if ((m = t.match(/(?:between|from)\s+(-?\d+)\s+(?:and|to|-)\s+(-?\d+)/)) || (m = t.match(/(\d+)\s*-\s*(\d+)/))) {
      return { data: { kind: 'number', min: Math.min(+m[1], +m[2]), max: Math.max(+m[1], +m[2]) }, complete: 1 };
    }
    if (/\brandom number\b/.test(t)) return { data: { kind: 'number', min: 1, max: 100 }, complete: 0.7 };
    if ((m = t.match(/(?:pick|choose|decide)(?:\s+one)?(?:\s+for me)?\s*:?\s*(.+)$/))) {
      const options = m[1].split(/\s*(?:,|\bor\b|\/|\|)\s*/).map((s) => s.trim()).filter(Boolean);
      return { data: { kind: 'pick', options }, complete: options.length >= 2 ? 1 : 0.4 };
    }
    return { data: { kind: null }, complete: 0.2 };
  }

  // ---------- goal
  const GNUM = String.raw`(\d[\d,]*(?:\.\d+)?)(k)?`;
  function parseGoal(text) {
    let rest = ` ${collapse(text)} `;
    let current = 0, target = null;
    const val = (num, k) => Number(num.replace(/,/g, '')) * (k ? 1000 : 1);
    const of = rest.match(new RegExp(String.raw`\b${GNUM}\s*(?:of|/|out of)\s*${GNUM}\b`, 'i'));
    if (of) { current = val(of[1], of[2]); target = val(of[3], of[4]); rest = rest.replace(of[0], ' '); }
    else {
      const done = rest.match(new RegExp(String.raw`(?:\b(?:saved|done|finished|completed|at)\s+${GNUM}|\b${GNUM}\s*(?:done|so far|completed|finished|in))\b`, 'i'));
      if (done) { current = val(done[1] || done[3], done[2] || done[4]); rest = rest.replace(done[0], ' '); }
      const t = rest.match(new RegExp(String.raw`\b${GNUM}\b`, 'i'));
      if (t) { target = val(t[1], t[2]); rest = rest.replace(t[0], ' '); }
    }
    const unitMatch = rest.match(/^\s*(?:[a-z]+\s+)?(books?|km|kms|miles?|pages?|workouts?|runs?|steps?|kg|lbs?|hours?|articles?|courses?|₹|rs|\$|dollars|rupees)\b/i);
    const unit = unitMatch ? unitMatch[1].toLowerCase() : null;
    rest = rest.replace(/\b(?:goal|target|progress|this year|this month|so far|done|by (?:end of )?\w+|in (?:january|february|march|april|may|june|july|august|september|october|november|december))\b/gi, ' ').replace(/[,;]+/g, ' ');
    const d = { title: capitalize(tidy(rest)), current: Math.min(current, target == null ? current : target), target, unit };
    return { data: d, complete: (target ? 0.6 : 0) + (d.title ? 0.3 : 0) + (current ? 0.1 : 0) };
  }

  // ---------- note
  function parseNote(text) {
    const lines = text.split('\n');
    const first = collapse(lines[0] || '');
    const body = collapse(lines.slice(1).join(' '));
    let d;
    if (body) d = { title: capitalize(first), body };
    else { const m = first.match(/^(.{8,80}?[.!?])\s+(.+)$/); d = m ? { title: capitalize(m[1]), body: m[2] } : { title: capitalize(first), body: '' }; }
    const words = (d.title + ' ' + d.body).trim().split(/\s+/).filter(Boolean).length;
    return { data: d, complete: Math.min(1, words / 10) };
  }

  const parsers = {
    event: (t, c) => parseEvent(t, c.ref),
    reminder: (t, c) => parseReminder(t, c.ref),
    todo: (t) => parseTodo(t),
    timer: (t) => parseTimer(t),
    habit: (t) => parseHabit(t),
    color: (t, c) => parseColor(t, c.colorMood),
    split: (t) => parseSplit(t),
    expense: (t) => parseExpense(t),
    convert: (t) => parseConvert(t),
    calc: (t) => parseCalc(t),
    travel: (t, c) => parseTravel(t, c.ref),
    poll: (t) => parsePoll(t),
    contact: (t) => parseContact(t),
    link: (t) => parseLink(t),
    countdown: (t, c) => parseCountdown(t, c.ref),
    timezone: (t, c) => parseTimezone(t, c),
    random: (t) => parseRandom(t),
    goal: (t) => parseGoal(t),
    note: (t) => parseNote(t),
  };

  // ---------- color (kept last: long tables)
  const NAMED = { red: '#e03131', crimson: '#c2255c', scarlet: '#f03e3e', maroon: '#862e2e', burgundy: '#7a1f3d', pink: '#f06595', rose: '#e64980', coral: '#ff7f6b', salmon: '#fa8072', peach: '#ffb38a', orange: '#ff7a1a', tangerine: '#ff8c2b', amber: '#f59f00', gold: '#e8b000', yellow: '#fcc419', mustard: '#d4a017', lemon: '#fff06a', cream: '#f7f0dc', beige: '#e8dcc4', sand: '#d8c49c', tan: '#c9a77c', brown: '#8b5a2b', chocolate: '#5d3a1a', olive: '#808a2f', lime: '#82c91e', green: '#2f9e44', sage: '#9caf88', mint: '#96f2d7', emerald: '#0ca678', forest: '#2b5c34', teal: '#0c8599', turquoise: '#22b8cf', cyan: '#15aabf', sky: '#74c0fc', blue: '#1c7ed6', navy: '#1b2a5c', cobalt: '#2451b7', indigo: '#4c6ef5', violet: '#7950f2', purple: '#7048e8', lavender: '#b197fc', lilac: '#c8a2c8', magenta: '#d6336c', plum: '#8e4585', grey: '#868e96', gray: '#868e96', slate: '#5c6b7a', charcoal: '#343a40', black: '#141414', white: '#fafaf9', ivory: '#fffff0' };
  const REFERENCE = { 'minecraft diamond': '#4aedd9', 'minecraft grass': '#7cbd6b', 'minecraft emerald': '#17dd62', 'minecraft gold': '#fcee4b', 'minecraft redstone': '#ff0000', 'tiffany blue': '#0abab5', tiffany: '#0abab5', 'barbie pink': '#e0218a', barbie: '#e0218a', 'spotify green': '#1db954', 'coca cola red': '#f40009', 'coke red': '#f40009', 'netflix red': '#e50914', 'facebook blue': '#1877f2', 'twitter blue': '#1da1f2', 'instagram pink': '#e1306c', 'discord blurple': '#5865f2', blurple: '#5865f2', 'starbucks green': '#00704a', 'ferrari red': '#ff2800', 'ikea blue': '#0058a3', 'ikea yellow': '#ffda1a', 'mcdonalds yellow': '#ffc72c', 'hermes orange': '#f37021', 'klein blue': '#002fa7', 'millennial pink': '#f3cfc6', 'matrix green': '#00ff41', 'shrek green': '#b5c91f', 'minion yellow': '#fce029', 'pikachu yellow': '#f6d02f', pikachu: '#f6d02f', 'hulk green': '#5ba331', 'smurf blue': '#3d8ed9', 'barney purple': '#7a3fa0', diamond: '#b9f2ff', ruby: '#e0115f', sapphire: '#0f52ba', amethyst: '#9966cc', jade: '#00a86b', topaz: '#ffc87c', pearl: '#eae0c8', onyx: '#353839', 'sky blue': '#87ceeb', 'baby blue': '#89cff0', 'baby pink': '#f4c2c2', 'hot pink': '#ff69b4', 'neon green': '#39ff14', 'electric blue': '#7df9ff', 'midnight blue': '#191970', 'forest green': '#228b22', 'blood red': '#8a0303', 'brick red': '#b22222', 'royal blue': '#4169e1', 'powder blue': '#b0e0e6', 'army green': '#4b5320', 'hunter green': '#355e3b', 'burnt orange': '#cc5500', 'rose gold': '#b76e79', 'dusty rose': '#c4a4a7', 'off white': '#f5f5f0', 'off-white': '#f5f5f0', terracotta: '#e2725b', denim: '#1560bd', champagne: '#f7e7ce', copper: '#b87333', bronze: '#cd7f32', silver: '#c0c0c0', blush: '#de5d83', 'urbit purple': '#4d3ab5' };
  const REF_RE = new RegExp('\\b(' + Object.keys(REFERENCE).sort((a, b) => b.length - a.length).map((k) => k.replace(/[-]/g, '\\-')).join('|') + ')\\b', 'i');
  const NAMED_RE = new RegExp('\\b(' + Object.keys(NAMED).join('|') + ')(ish)?\\b', 'i');
  const hex = (r, g, b) => '#' + [r, g, b].map((v) => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, '0')).join('');
  function shade(h, mood) {
    const r = parseInt(h.slice(1, 3), 16), g = parseInt(h.slice(3, 5), 16), b = parseInt(h.slice(5, 7), 16);
    if (mood === 'pastel') return hex(r + (255 - r) * 0.45, g + (255 - g) * 0.45, b + (255 - b) * 0.45);
    if (mood === 'dark') return hex(r * 0.55, g * 0.55, b * 0.55);
    if (mood === 'vivid') { const m = Math.max(r, g, b) || 1; return hex(r * 255 / m, g * 255 / m, b * 255 / m); }
    return h;
  }
  function colorReference(t) { const m = t.match(REF_RE); return m ? REFERENCE[m[1].toLowerCase()] : null; }
  function parseColor(text, mood) {
    const t = text.trim();
    let m;
    if ((m = t.match(/#([0-9a-f]{6})\b/i))) return { data: { hex: '#' + m[1].toLowerCase(), name: null, source: 'hex' }, complete: 1 };
    if ((m = t.match(/#([0-9a-f]{3})\b/i))) return { data: { hex: '#' + m[1].toLowerCase().split('').map((c) => c + c).join(''), name: null, source: 'hex' }, complete: 1 };
    if ((m = t.match(/rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/i))) return { data: { hex: hex(+m[1], +m[2], +m[3]), name: null, source: 'rgb' }, complete: 1 };
    if ((m = t.match(REF_RE))) return { data: { hex: REFERENCE[m[1].toLowerCase()], name: m[1], source: 'named' }, complete: 1 };
    if ((m = t.match(NAMED_RE))) {
      const base = NAMED[m[1].toLowerCase()];
      const modified = /\b(light|pale|pastel|soft)\b/i.test(t) ? shade(base, 'pastel') : /\b(dark|deep)\b/i.test(t) ? shade(base, 'dark') : /\b(bright|neon|vivid)\b/i.test(t) ? shade(base, 'vivid') : shade(base, mood === 'pastel' || mood === 'dark' || mood === 'vivid' ? mood : null);
      return { data: { hex: modified, name: m[1], source: 'named' }, complete: 0.9 };
    }
    if ((m = t.match(/#([0-9a-f]{1,5})$/i))) return { data: { hex: null, name: null, source: 'hex' }, complete: 0.3 };
    return { data: { hex: null, name: null, source: null }, complete: 0 };
  }

  function parseFor(intent, text, ctx) { return (parsers[intent] || parsers.note)(text, ctx || {}); }
  function completeness(intent, text, ctx) { return parseFor(intent, text, ctx).complete; }

  window.Parse = { parseFor, completeness, colorReference, convertValue, unitOptions, LABELS, findDate, formatClock, formatAmount, formatIn, validZone, zoneLabel, localZone };
})();
