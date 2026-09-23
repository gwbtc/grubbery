// typesafe nexus UI: key + default model, a systemone playground,
// the usage ledger.
const $ = (id) => document.getElementById(id);
const BASE = '/grubbery/typesafe';

async function jget(u) { const r = await fetch(BASE + u); if (!r.ok) throw new Error(await r.text()); return r.json(); }
async function jpost(u, b) { const r = await fetch(BASE + u, { method: 'POST', body: JSON.stringify(b) }); if (!r.ok) throw new Error(await r.text()); return r; }

const fmt = (n) => (n || 0).toLocaleString();
const fmtTime = (t) => t ? new Date(t * 1000).toLocaleString() : '–';
const ago = (t) => {
  if (!t) return 'never synced';
  const s = Math.max(0, Date.now() / 1000 - t);
  if (s < 90) return 'synced just now';
  if (s < 5400) return `synced ${Math.round(s / 60)}m ago`;
  if (s < 129600) return `synced ${Math.round(s / 3600)}h ago`;
  return `synced ${Math.round(s / 86400)}d ago`;
};
const fmtCost = (c) => c === 0 ? '$0.00' : c >= 0.01 ? '$' + c.toFixed(2) : '$' + c.toPrecision(2);
const cost = (c) => parseFloat(c && c.cost != null ? c.cost : 0) || 0;
const pct = (p) => Math.round((p || 0) * 100) + '%';

const EXAMPLE = {
  department: {
    type: 'choice',
    instructions: 'Which team should handle this?',
    criteria: { billing: 'Payments, invoicing, refunds', technical: 'Bugs, outages, integrations', sales: 'Pricing, upgrades, new accounts' }
  },
  frustration: { type: 'score', instructions: 'How frustrated is the customer?', criteria: ['Calm', 'Frustrated', 'Very angry'] },
  is_urgent: { type: 'noul', instructions: 'Does this convey urgency?' }
};
$('test-questions').value = JSON.stringify(EXAMPLE, null, 2);
$('test-state').value = 'Help! My payouts have been failing for 3 days.';

let MODELS = {};
let modelsLoaded = false;
async function loadModels() {
  MODELS = await jget('/api/models');
  const dl = $('model-list');
  dl.textContent = '';
  for (const id of Object.keys(MODELS).sort()) {
    const o = document.createElement('option');
    o.value = id;
    dl.appendChild(o);
  }
  modelsLoaded = true;
}

async function refresh() {
  const s = await jget('/api/status');
  $('conn-dot').className = 'dot ' + (s.keySet ? 'on' : '');
  $('conn-label').textContent = s.keySet ? 'API key set' : 'no API key';
  $('set-key').textContent = s.keySet ? 'Replace API key' : 'Set API key';
  $('key-row').hidden = !s.keySet;
  if (document.activeElement !== $('model')) $('model').value = s.model || '';
  $('sync-ago').textContent = ago(s.syncedAt);
  $('models-sync').textContent = s.models ? `Sync models (${s.models})` : 'Sync models';
  if (s.models && !modelsLoaded) loadModels().catch(() => {});
  const g = await jget('/api/usage');
  $('in-tok').textContent = fmt(g['input-tokens']);
  $('out-tok').textContent = fmt(g['output-tokens']);
  $('requests').textContent = fmt(g.requests);
  const calls = g.calls || [];
  let total = 0;
  for (const c of calls) total += cost(c);
  $('total-cost').textContent = fmtCost(total);
  $('status').textContent = `${fmt(g.requests)} requests · ${s.pending} in flight · ${fmtCost(total)}`;

  const per = Object.create(null);
  for (const c of calls) {
    const f = c.from || 'unknown';
    per[f] = per[f] || { reqs: 0, tin: 0, tout: 0, cost: 0 };
    per[f].reqs++; per[f].tin += c.in || 0; per[f].tout += c.out || 0; per[f].cost += cost(c);
  }
  const ct = $('caller-log');
  ct.textContent = '';
  for (const f of Object.keys(per).sort()) {
    const p = per[f], tr = document.createElement('tr');
    tr.innerHTML = `<td class="caller mono" title="${f}">${f}</td><td>${p.reqs}</td><td>${fmt(p.tin)}</td><td>${fmt(p.tout)}</td><td class="r cost">${fmtCost(p.cost)}</td>`;
    ct.appendChild(tr);
  }

  const tb = $('call-log');
  tb.textContent = '';
  for (const c of calls) {
    const tr = document.createElement('tr');
    tr.innerHTML = `<td>${fmtTime(c.time)}</td><td class="caller mono" title="${c.from || '–'}">${c.from || '–'}</td><td class="mono">${c.model || '–'}</td><td>${fmt(c.in)}</td><td>${fmt(c.out)}</td><td class="r cost">${fmtCost(cost(c))}</td>`;
    tb.appendChild(tr);
  }
}

// default model: saved on change, blur, or enter
async function saveModel() {
  const m = $('model').value.trim();
  if (!m) return;
  await jpost('/api/config', { model: m });
  refresh();
}
$('model').addEventListener('change', saveModel);
$('model').addEventListener('keydown', (e) => { if (e.key === 'Enter') $('model').blur(); });

$('models-sync').addEventListener('click', async () => {
  $('models-sync').textContent = 'syncing…';
  try {
    const r = await (await jpost('/api/models-sync', {})).json();
    modelsLoaded = false;
    $('models-sync').textContent = `Sync models (${r.synced})`;
    loadModels().catch(() => {});
  } catch (e) { $('models-sync').textContent = 'sync failed'; }
  refresh();
});

// render one answer as a small bar chart of its probabilities
function renderAnswer(name, a) {
  const div = document.createElement('div');
  div.className = 'answer';
  let head = '';
  let dist = null;
  if (a.type === 'choice') {
    head = `<b>${a.choice}</b> <span class="muted">confidence ${pct(a.confidence)}</span>`;
    dist = a.probabilities || {};
  } else if (a.type === 'score') {
    head = `<b>${(a.score ?? 0).toFixed(2)}</b> <span class="muted">confidence ${pct(a.confidence)}</span>`;
    dist = {};
    for (const k of Object.keys(a.probabilities || {})) dist[(a.legend || {})[k] || k] = a.probabilities[k];
  } else if (a.type === 'noul') {
    head = `<b>${pct(a.noul)}</b> <span class="muted">yes</span>`;
    dist = { yes: a.noul, no: 1 - (a.noul || 0) };
  } else {
    head = `<span class="muted">${JSON.stringify(a)}</span>`;
  }
  let bars = '';
  if (dist) {
    for (const k of Object.keys(dist)) {
      const p = dist[k] || 0;
      bars += `<div class="bar-row"><span class="bar-label mono">${k}</span><span class="bar"><span class="bar-fill" style="width:${Math.max(1, p * 100)}%"></span></span><span class="bar-pct">${pct(p)}</span></div>`;
    }
  }
  div.innerHTML = `<div class="answer-head"><span class="mono answer-name">${name}</span> <span class="tag">${a.type}</span> ${head}</div>${bars}`;
  return div;
}

$('test-run').addEventListener('click', async () => {
  const state = $('test-state').value.trim();
  if (!state) return;
  let questions;
  try { questions = JSON.parse($('test-questions').value); }
  catch (e) { $('test-out').hidden = false; $('test-out').textContent = 'questions: ' + e.message; return; }
  const out = $('test-out');
  out.hidden = false;
  out.textContent = 'deciding…';
  try {
    const { id } = await (await jpost('/api/call-new', { state, questions })).json();
    let c = null;
    for (let i = 0; i < 60; i++) {
      await new Promise(res => setTimeout(res, 500));
      try {
        const r = await jget(`/api/call?id=${encodeURIComponent(id)}`);
        if (r.status === 'done') { c = r; break; }
      } catch (e) { /* not yet */ }
    }
    if (!c) throw new Error('timed out waiting for the call');
    jpost('/api/call-cull', { id }).catch(() => {});
    const resp = c.response || {};
    out.textContent = '';
    if (resp.error) {
      out.textContent = 'error: ' + (typeof resp.error === 'string' ? resp.error : JSON.stringify(resp.error));
    } else if (resp.answers) {
      for (const k of Object.keys(resp.answers)) out.appendChild(renderAnswer(k, resp.answers[k]));
      const u = resp.usage || {};
      const foot = document.createElement('p');
      foot.className = 'muted';
      foot.textContent = `${resp.model} · ${u.input_tokens || 0} in / ${u.output_tokens || 0} out`;
      out.appendChild(foot);
    } else {
      out.textContent = JSON.stringify(resp, null, 2);
    }
  } catch (e) { out.textContent = e.message; }
  refresh();
});
$('test-state').addEventListener('keydown', (e) => { if (e.key === 'Enter') $('test-run').click(); });

// rates modal — the rate table plus the synced model catalog
async function renderRates() {
  const rates = await jget('/api/rates');
  const tb = $('rate-rows');
  tb.textContent = '';
  for (const k of Object.keys(rates).sort()) {
    const tr = document.createElement('tr');
    tr.innerHTML = `<td class="mono">${k}</td><td class="r">$${rates[k].in}</td>`;
    tb.appendChild(tr);
  }
  const mb = $('model-rows');
  mb.textContent = '';
  if (!Object.keys(MODELS).length) {
    mb.innerHTML = '<tr><td colspan="2" class="muted">empty — hit Sync models.</td></tr>';
    return;
  }
  for (const m of Object.keys(MODELS).sort()) {
    const tr = document.createElement('tr');
    tr.innerHTML = `<td class="mono">${m}</td><td>${MODELS[m].description || ''}</td>`;
    mb.appendChild(tr);
  }
}
$('rates').addEventListener('click', () => { renderRates().catch(() => {}); $('rates-modal').hidden = false; });
$('rates-modal').addEventListener('click', (e) => { if (e.target === $('rates-modal')) $('rates-modal').hidden = true; });

// key view/hide/copy (SVGs have no .hidden property — toggle the attribute)
const KEY_DOTS = '••••••••••••••••••••';
let keyShown = false;
$('key-toggle').addEventListener('click', async () => {
  keyShown = !keyShown;
  if (keyShown) {
    const k = await jget('/api/key');
    $('key-view').textContent = k.key || '(empty)';
  } else {
    $('key-view').textContent = KEY_DOTS;
  }
  $('eye-open').toggleAttribute('hidden', keyShown);
  $('eye-shut').toggleAttribute('hidden', !keyShown);
  $('key-toggle').title = keyShown ? 'hide key' : 'show key';
});
$('key-copy').addEventListener('click', async () => {
  const k = await jget('/api/key');
  await navigator.clipboard.writeText(k.key);
  $('copy-icon').toggleAttribute('hidden', true);
  $('copy-done').toggleAttribute('hidden', false);
  setTimeout(() => {
    $('copy-icon').toggleAttribute('hidden', false);
    $('copy-done').toggleAttribute('hidden', true);
  }, 1500);
});

// key modal
$('set-key').addEventListener('click', () => {
  $('key-input').value = '';
  $('key-modal').hidden = false;
  $('key-input').focus();
});
$('key-modal').addEventListener('click', (e) => { if (e.target === $('key-modal')) $('key-modal').hidden = true; });
$('key-save').addEventListener('click', async () => {
  const k = $('key-input').value.trim();
  if (k) await jpost('/api/config', { 'api-key': k });
  $('key-modal').hidden = true;
  refresh();
});
$('key-input').addEventListener('keydown', (e) => { if (e.key === 'Enter') $('key-save').click(); });

$('reset').addEventListener('click', async () => {
  if (!confirm('Reset the entire usage ledger? This cannot be undone.')) return;
  await jpost('/api/reset', {});
  refresh();
});

refresh();
setInterval(() => refresh().catch(() => {}), 5000);

// info modal
$('info').addEventListener('click', () => { $('info-modal').hidden = false; });
$('info-modal').addEventListener('click', (e) => { if (e.target === $('info-modal')) $('info-modal').hidden = true; });
