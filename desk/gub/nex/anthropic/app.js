// anthropic nexus UI: key state, the usage ledger, rates.
const $ = (id) => document.getElementById(id);
const BASE = '/grubbery/anthropic';

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

let RATES = {};
// exact match first, then a rate key that prefixes the model — so a
// dated id (claude-sonnet-4-5-20250929) finds its undated rate
function rate(model, dir) {
  let r = RATES[model];
  if (!r && model) {
    const k = Object.keys(RATES).filter(k => model.startsWith(k)).sort((a, b) => b.length - a.length)[0];
    if (k) r = RATES[k];
  }
  return r ? parseFloat(r[dir] || '0') : 0;
}
const fmtCost = (c) => c === 0 ? '$0.00' : c >= 0.01 ? '$' + c.toFixed(2) : '$' + c.toPrecision(2);
// prefer the cost STAMPED at call time (rates in force then); compute
// from current rates only for old entries that predate stamping.
// cache reads bill at 0.1x input, cache writes at 1.25x input
function callCost(c) {
  if (c && c.cost != null) return parseFloat(c.cost) || 0;
  const ri = rate(c.model, 'in'), ro = rate(c.model, 'out');
  return ((c.in || 0) / 1e6) * ri
       + ((c['cache-read'] || 0) / 1e6) * ri * 0.1
       + ((c['cache-write'] || 0) / 1e6) * ri * 1.25
       + ((c.out || 0) / 1e6) * ro;
}

async function refresh() {
  const s = await jget('/api/status');
  $('conn-dot').className = 'dot ' + (s.keySet ? 'on' : '');
  $('conn-label').textContent = s.keySet ? 'API key set' : 'no API key';
  $('set-key').textContent = s.keySet ? 'Replace API key' : 'Set API key';
  $('key-row').hidden = !s.keySet;
  $('sync-ago').textContent = ago(s.syncedAt);
  const u = await jget('/api/usage');
  RATES = u.rates || {};
  fillModels();
  showModelInfo();
  const g = u.usage || {};
  $('in-tok').textContent = fmt(g['input-tokens']);
  $('out-tok').textContent = fmt(g['output-tokens']);
  $('cache-read').textContent = fmt(g['cache-read-tokens']);
  $('cache-write').textContent = fmt(g['cache-write-tokens']);
  $('requests').textContent = fmt(g.requests);
  const calls = g.calls || [];
  let total = 0;
  for (const c of calls) total += callCost(c);
  $('total-cost').textContent = fmtCost(total);
  $('status').textContent = `${fmt(g.requests)} requests · ${s.pending} in flight · ${fmtCost(total)}`;

  // cost by caller
  const per = Object.create(null);
  for (const c of calls) {
    const f = c.from || 'unknown';
    per[f] = per[f] || { reqs: 0, tin: 0, tout: 0, cost: 0 };
    per[f].reqs++; per[f].tin += c.in || 0; per[f].tout += c.out || 0; per[f].cost += callCost(c);
  }
  const ct = $('caller-log');
  ct.textContent = '';
  for (const f of Object.keys(per).sort()) {
    const p = per[f], tr = document.createElement('tr');
    tr.innerHTML = `<td class="caller mono" title="${f}">${f}</td><td>${p.reqs}</td><td>${fmt(p.tin)}</td><td>${fmt(p.tout)}</td><td class="r cost">${fmtCost(p.cost)}</td>`;
    ct.appendChild(tr);
  }

  // recent calls
  const tb = $('call-log');
  tb.textContent = '';
  for (const c of calls) {
    const tr = document.createElement('tr');
    tr.innerHTML = `<td>${fmtTime(c.time)}</td><td class="caller mono" title="${c.from || '–'}">${c.from || '–'}</td><td class="mono">${c.model || '–'}</td><td>${fmt(c.in)}</td><td>${fmt(c['cache-read'])}</td><td>${fmt(c['cache-write'])}</td><td>${fmt(c.out)}</td><td class="r cost">${fmtCost(callCost(c))}</td>`;
    tb.appendChild(tr);
  }
}

// test call: prompt in, reply + cost out, through the full lifecycle
function fillModels() {
  const sel = $('test-model');
  const cur = sel.value;
  const models = Object.keys(RATES).sort();
  if (models.join(',') === sel.dataset.models) return;
  sel.dataset.models = models.join(',');
  sel.textContent = '';
  for (const m of models) {
    const o = document.createElement('option');
    o.value = m; o.textContent = m;
    sel.appendChild(o);
  }
  if (cur && models.includes(cur)) sel.value = cur;
}
$('test-run').addEventListener('click', async () => {
  const prompt = $('test-prompt').value.trim();
  if (!prompt) return;
  const out = $('test-out');
  out.hidden = false;
  out.textContent = 'thinking…';
  try {
    const body = {
      model: $('test-model').value,
      max_tokens: 1024,
      messages: [{ role: 'user', content: prompt }],
    };
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
      const text = (resp.content || []).map(b => b.text || '').join('');
      const u = resp.usage || {};
      const cost = callCost({ model: resp.model, in: u.input_tokens, out: u.output_tokens, 'cache-read': u.cache_read_input_tokens, 'cache-write': u.cache_creation_input_tokens });
      out.textContent = text + `\n\n— ${resp.model} · ${u.input_tokens || 0} in / ${u.output_tokens || 0} out · ${fmtCost(cost)}`;
    }
  } catch (e) { out.textContent = e.message; }
  refresh();
});
$('test-prompt').addEventListener('keydown', (e) => { if (e.key === 'Enter') $('test-run').click(); });

// Sync models: model list + rates from OpenRouter's public catalog
// (browser-direct, no key). Their listed Anthropic rates match
// Anthropic's own. Catalog wins on collision; hand-added rows survive.
$('models-sync').addEventListener('click', async () => {
  $('models-sync').textContent = 'syncing…';
  try {
    const r = await (await fetch('https://openrouter.ai/api/v1/models')).json();
    const merged = { ...RATES };
    let n = 0;
    for (const m of r.data || []) {
      if (!m.id || !m.id.startsWith('anthropic/')) continue;
      const key = m.id.slice('anthropic/'.length).replace(/\./g, '-');
      const p = m.pricing || {};
      merged[key] = {
        in: (parseFloat(p.prompt || '0') * 1e6).toFixed(2),
        out: (parseFloat(p.completion || '0') * 1e6).toFixed(2),
      };
      n++;
    }
    await jpost('/api/rates', merged);
    $('models-sync').textContent = `Synced ${n} via OpenRouter`;
    setTimeout(() => { $('models-sync').textContent = 'Sync models'; }, 2500);
  } catch (e) { $('models-sync').textContent = 'sync failed'; }
  refresh();
});

// live rate line for the selected model
function showModelInfo() {
  const r = RATES[$('test-model').value];
  $('model-info').textContent = !r ? '' :
    `$${r.in}/M in · $${r.out}/M out · cache read 0.1× / write 1.25×`;
}
$('test-model').addEventListener('change', showModelInfo);

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

// rates modal — read-only; Sync models updates the table
$('rates').addEventListener('click', () => {
  const tb = $('rate-rows');
  tb.textContent = '';
  if (!Object.keys(RATES).length) {
    tb.innerHTML = '<tr><td colspan="3" class="muted">empty — no rates yet. Hit Sync models.</td></tr>';
  }
  for (const m of Object.keys(RATES).sort()) {
    const tr = document.createElement('tr');
    tr.innerHTML = `<td class="mono">${m}</td><td class="r">$${RATES[m].in}</td><td class="r">$${RATES[m].out}</td>`;
    tb.appendChild(tr);
  }
  $('rates-modal').hidden = false;
});
$('rates-modal').addEventListener('click', (e) => { if (e.target === $('rates-modal')) $('rates-modal').hidden = true; });

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
