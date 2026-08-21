// anthropic nexus UI: key state, the usage ledger, rates.
const $ = (id) => document.getElementById(id);
const BASE = '/grubbery/anthropic';

async function jget(u) { const r = await fetch(BASE + u); if (!r.ok) throw new Error(await r.text()); return r.json(); }
async function jpost(u, b) { const r = await fetch(BASE + u, { method: 'POST', body: JSON.stringify(b) }); if (!r.ok) throw new Error(await r.text()); return r; }

const fmt = (n) => (n || 0).toLocaleString();
const fmtTime = (t) => t ? new Date(t * 1000).toLocaleString() : '–';

let RATES = {};
function rate(model, dir) {
  const r = RATES[model];
  return r ? parseFloat(r[dir] || '0') : 0;
}
// cache reads bill at 0.1x input, cache writes at 1.25x input
function callCost(c) {
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
  const u = await jget('/api/usage');
  RATES = u.rates || {};
  fillModels();
  const g = u.usage || {};
  $('in-tok').textContent = fmt(g['input-tokens']);
  $('out-tok').textContent = fmt(g['output-tokens']);
  $('cache-read').textContent = fmt(g['cache-read-tokens']);
  $('cache-write').textContent = fmt(g['cache-write-tokens']);
  $('requests').textContent = fmt(g.requests);
  const calls = g.calls || [];
  let total = 0;
  for (const c of calls) total += callCost(c);
  $('total-cost').textContent = '$' + total.toFixed(4);
  $('status').textContent = `${fmt(g.requests)} requests · ${s.pending} in flight · $${total.toFixed(2)}`;

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
    tr.innerHTML = `<td class="caller mono" title="${f}">${f}</td><td>${p.reqs}</td><td>${fmt(p.tin)}</td><td>${fmt(p.tout)}</td><td class="r cost">$${p.cost.toFixed(4)}</td>`;
    ct.appendChild(tr);
  }

  // recent calls
  const tb = $('call-log');
  tb.textContent = '';
  for (const c of calls) {
    const tr = document.createElement('tr');
    tr.innerHTML = `<td>${fmtTime(c.time)}</td><td class="caller mono" title="${c.from || '–'}">${c.from || '–'}</td><td class="mono">${c.model || '–'}</td><td>${fmt(c.in)}</td><td>${fmt(c['cache-read'])}</td><td>${fmt(c['cache-write'])}</td><td>${fmt(c.out)}</td><td class="r cost">$${callCost(c).toFixed(4)}</td>`;
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
      out.textContent = text + `\n\n— ${resp.model} · ${u.input_tokens || 0} in / ${u.output_tokens || 0} out · $${cost.toFixed(4)}`;
    }
  } catch (e) { out.textContent = e.message; }
  refresh();
});
$('test-prompt').addEventListener('keydown', (e) => { if (e.key === 'Enter') $('test-run').click(); });

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

// rates modal
function addRateRow(model, rin, rout) {
  const d = document.createElement('div');
  d.className = 'rate-row';
  d.innerHTML = `<input class="r-model mono" placeholder="model-id" value="${model}">` +
    `<input class="r-price" type="number" step="0.01" placeholder="in" value="${rin}">` +
    `<input class="r-price" type="number" step="0.01" placeholder="out" value="${rout}">` +
    `<button class="icon r-del" title="remove"><svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg></button>`;
  d.querySelector('.r-del').addEventListener('click', () => d.remove());
  $('rate-rows').appendChild(d);
}
$('rates').addEventListener('click', () => {
  $('rate-rows').textContent = '';
  for (const m of Object.keys(RATES).sort()) addRateRow(m, RATES[m].in || '0', RATES[m].out || '0');
  $('rates-modal').hidden = false;
});
$('rate-add').addEventListener('click', () => addRateRow('', '', ''));
$('rates-modal').addEventListener('click', (e) => { if (e.target === $('rates-modal')) $('rates-modal').hidden = true; });
$('rates-save').addEventListener('click', async () => {
  const obj = Object.create(null);
  for (const row of $('rate-rows').querySelectorAll('.rate-row')) {
    const inputs = row.querySelectorAll('input');
    const m = inputs[0].value.trim();
    if (m) obj[m] = { in: inputs[1].value || '0', out: inputs[2].value || '0' };
  }
  await jpost('/api/rates', obj);
  $('rates-modal').hidden = true;
  refresh();
});

$('reset').addEventListener('click', async () => {
  if (!confirm('Reset the entire usage ledger? This cannot be undone.')) return;
  await jpost('/api/reset', {});
  refresh();
});

refresh();
setInterval(() => refresh().catch(() => {}), 5000);
