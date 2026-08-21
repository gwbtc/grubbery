// openrouter nexus UI: key state, models, the usage ledger with
// native costs.
const $ = (id) => document.getElementById(id);
const BASE = '/grubbery/openrouter';

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
$('test-model').addEventListener('input', () => {
  const m = MODELS[$('test-model').value];
  $('model-info').textContent = !m ? '' :
    `context ${fmt(m.context)} · $${(parseFloat(m.prompt) * 1e6).toFixed(2)}/M in · $${(parseFloat(m.completion) * 1e6).toFixed(2)}/M out`;
});

async function refresh() {
  const s = await jget('/api/status');
  $('conn-dot').className = 'dot ' + (s.keySet ? 'on' : '');
  $('conn-label').textContent = s.keySet ? 'API key set' : 'no API key';
  $('set-key').textContent = s.keySet ? 'Replace API key' : 'Set API key';
  $('key-row').hidden = !s.keySet;
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

// test call
$('test-run').addEventListener('click', async () => {
  const prompt = $('test-prompt').value.trim();
  const model = $('test-model').value.trim();
  if (!prompt || !model) return;
  const out = $('test-out');
  out.hidden = false;
  out.textContent = 'thinking…';
  try {
    const body = { model, max_tokens: 1024, messages: [{ role: 'user', content: prompt }] };
    const { id } = await (await jpost('/api/call-new', body)).json();
    let c = null;
    for (let i = 0; i < 60; i++) {
      await new Promise(res => setTimeout(res, 1000));
      try {
        const r = await jget(`/api/call?id=${encodeURIComponent(id)}`);
        if (r.status === 'done') { c = r; break; }
      } catch (e) { /* not yet */ }
    }
    if (!c) throw new Error('timed out waiting for the call');
    jpost('/api/call-cull', { id }).catch(() => {});
    const resp = c.response || {};
    if (resp.error) {
      out.textContent = 'error: ' + (typeof resp.error === 'string' ? resp.error : JSON.stringify(resp.error));
    } else {
      const text = ((resp.choices || [])[0] || {}).message?.content || '';
      const u = resp.usage || {};
      out.textContent = text + `\n\n— ${resp.model} · ${u.prompt_tokens || 0} in / ${u.completion_tokens || 0} out · ${fmtCost(parseFloat(u.cost) || 0)}`;
    }
  } catch (e) { out.textContent = e.message; }
  refresh();
});
$('test-prompt').addEventListener('keydown', (e) => { if (e.key === 'Enter') $('test-run').click(); });

// rates modal — read-only view of the synced catalog, filterable
function renderRates() {
  const q = $('rate-filter').value.trim().toLowerCase();
  const tb = $('rate-rows');
  tb.textContent = '';
  if (!Object.keys(MODELS).length) {
    tb.innerHTML = '<tr><td colspan="4" class="muted">empty — no catalog yet. Hit Sync models.</td></tr>';
    return;
  }
  for (const m of Object.keys(MODELS).sort()) {
    if (q && !m.toLowerCase().includes(q)) continue;
    const r = MODELS[m];
    const tr = document.createElement('tr');
    tr.innerHTML = `<td class="mono">${m}</td><td class="r">$${(parseFloat(r.prompt) * 1e6).toFixed(2)}</td><td class="r">$${(parseFloat(r.completion) * 1e6).toFixed(2)}</td><td class="r">${fmt(r.context)}</td>`;
    tb.appendChild(tr);
  }
}
$('rates').addEventListener('click', () => { $('rate-filter').value = ''; renderRates(); $('rates-modal').hidden = false; });
$('rate-filter').addEventListener('input', renderRates);
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
