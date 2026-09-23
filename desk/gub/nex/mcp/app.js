// mcp ui: a reader over the endpoint's data routes. Running a tool from
// the page is a plain JSON-RPC tools/call to the endpoint — the same
// request every MCP client makes.
// The page is a viewer for ONE tools nexus, the one its URL names:
// /grubbery/tools                 this endpoint's own tools
// /grubbery/tools/apps/nostr/tools   the nostr app's
// Every data route takes ?path=; no registry, no scanning.
//   GET  /grubbery/tools/api/tools-tree?path=  {path, own, dirs, tools}
//   GET  /grubbery/tools/api/runs?path=        [{id, tool, step, args, result}]
//   GET  /grubbery/tools/api/src?path=&tool=   {path, text}
//   POST /grubbery/tools                       JSON-RPC
'use strict';
const $ = (id) => document.getElementById(id);
const BASE = '/grubbery/tools';
// the tools nexus this page is about: the URL suffix, or none for our own
const AT = (() => { const s = location.pathname.replace(/^\/grubbery\/tools\/?/, '').replace(/\/$/, ''); return s ? '/' + s : ''; })();
const Q = AT ? '?path=' + encodeURIComponent(AT) : '';
const jget = async (u) => { const r = await fetch(BASE + u + (u.includes('?') ? (AT ? '&path=' + encodeURIComponent(AT) : '') : Q)); if (!r.ok) throw new Error(u + ': ' + r.status + ' ' + await r.text()); return r.json(); };

function spinner(label) {
  const el = document.createElement('div'); el.className = 'loading';
  const s = document.createElement('span'); s.className = 'spinner';
  el.append(s, document.createTextNode(label || 'loading…'));
  return el;
}
function busy(el, label) { el.textContent = ''; el.appendChild(spinner(label)); }
function spinBtn(b, on) { b.disabled = on; b.classList.toggle('busy', on); }
function el(tag, cls, text) { const e = document.createElement(tag); if (cls) e.className = cls; if (text !== undefined) e.textContent = text; return e; }

// ---- tools: the one tools nexus, its files as a tree flattened ----
let here = { path: '', own: true };
let allTools = [];
let filter = '';

function fileOf(name) { const p = name.split('__'); return p[p.length - 1].replace(/_/g, '-') + '.hoon'; }

async function loadTools() {
  if (!allTools.length) busy($('tools'), 'reading ' + (AT || 'this nexus') + '…');
  let tree;
  try { tree = await jget('/api/tools-tree'); } catch (e) { $('tools').textContent = ''; $('tools').innerHTML = '<div class="empty">could not read the tools nexus at ' + (AT || 'this nexus') + ': ' + e.message + '</div>'; return; }
  here = { path: tree.path || AT, own: !!tree.own };
  $('at').value = here.path;
  document.title = 'Tools · ' + here.path;
  const flat = (node) => [].concat(node.tools || [], ...(node.dirs || []).map(flat));
  allTools = flat(tree).sort((a, b) => a.name.localeCompare(b.name));
  renderTools();
}

function renderTools() {
  const box = $('tools'); box.textContent = '';
  const q = filter.trim().toLowerCase();
  const tools = allTools.filter((t) => !q || t.name.toLowerCase().includes(q) || (t.description || '').toLowerCase().includes(q));
  if (!allTools.length) box.innerHTML = '<div class="empty">No tools compiled at ' + here.path + '/code/lib/tools.</div>';
  else if (!tools.length) box.innerHTML = '<div class="empty">nothing matches</div>';
  tools.forEach((t) => box.appendChild(toolRow(t)));
  $('tools-count').textContent = q ? tools.length + ' of ' + allTools.length : allTools.length + ' tools';
  updateCounts();
}

$('at-form').onsubmit = (e) => {
  e.preventDefault();
  const p = $('at').value.trim().replace(/\/$/, '');
  location.href = BASE + (p && p !== '/' ? p : '');
};

function toolRow(t) {
  const row = el('div', 'tool-row');
  const name = el('span', 'tool-name mono', t.name); name.title = fileOf(t.name);
  const desc = el('span', 'tool-desc', t.description || ''); desc.title = t.description || '';
  const params = el('span', 'tool-params');
  const props = (t.inputSchema && t.inputSchema.properties) || {};
  const req = (t.inputSchema && t.inputSchema.required) || [];
  Object.keys(props).forEach((k) => { const c = el('span', 'chip' + (req.includes(k) ? ' req' : ''), k); c.title = (props[k].type || '') + (props[k].description ? ' — ' + props[k].description : ''); params.appendChild(c); });
  row.append(name, desc, params);
  row.onclick = () => openTool(t);
  return row;
}

$('tools-filter').addEventListener('input', () => { filter = $('tools-filter').value; renderTools(); });

// ---- one tool: Schema | Source | Run, in a modal ----
// The Schema tab leads with the description (collapsible, open by default)
// and the schema table sits below it — one place for "what is this and what
// does it take", read top to bottom.
function openTool(t) {
  const body = $('tool-modal-body'); body.textContent = '';
  const head = el('div', 'tool-head');
  head.append(el('h4', 'mono', t.name), el('span', 'muted mono', fileOf(t.name)), el('span', 'muted', 'in ' + here.path));
  body.appendChild(head);
  const tabs = document.createElement('tab-group'); tabs.setAttribute('persist', 'mcp-tool-tab');
  const schema = el('section'); schema.setAttribute('tab-label', 'Schema');
  const about = el('details', 'about'); about.open = true;
  const sum = el('summary'); sum.append(el('span', 'about-label', 'Description'));
  about.append(sum, el('p', 'desc', t.description || '(no description)'));
  schema.append(about, schemaTable(t));
  const source = el('section'); source.setAttribute('tab-label', 'Source');
  busy(source, 'reading the source…');
  jget('/api/src?tool=' + encodeURIComponent(t.name)).then((res) => {
    source.textContent = '';
    source.append(el('div', 'src-path mono', res.path), highlightHoon(res.text));
  }).catch((e) => { source.textContent = ''; source.appendChild(el('div', 'empty tight', 'no source: ' + e.message)); });
  const run = el('section'); run.setAttribute('tab-label', 'Run');
  run.appendChild(runForm(t));
  tabs.append(schema, source, run);
  body.appendChild(tabs);
  $('tool-modal').show();
}

function schemaTable(t) {
  const props = (t.inputSchema && t.inputSchema.properties) || {};
  const req = (t.inputSchema && t.inputSchema.required) || [];
  const keys = Object.keys(props);
  if (!keys.length) return el('div', 'empty tight', 'No parameters.');
  const table = el('table', 'schema');
  const hr = table.insertRow();
  ['parameter', 'type', '', 'description'].forEach((h) => { const th = document.createElement('th'); th.textContent = h; hr.appendChild(th); });
  keys.forEach((k) => {
    const tr = table.insertRow();
    tr.insertCell().appendChild(el('code', '', k));
    tr.insertCell().appendChild(el('span', 'type', props[k].type || ''));
    tr.insertCell().appendChild(el('span', 'req', req.includes(k) ? 'required' : ''));
    tr.insertCell().textContent = props[k].description || '';
  });
  return table;
}

// comments, strings, %terms, rune digraphs — enough to read by
function highlightHoon(src) {
  const pre = el('pre', 'hoon');
  const re = /(::[^\n]*)|('[^'\n]*'|"[^"\n]*")|(%[a-z][a-z0-9-]*)|([|$%:.^~;=?!_+][|$%:.^~;=?!_+*@&<>#-])/g;
  let last = 0, m;
  while ((m = re.exec(src)) !== null) {
    if (m.index > last) pre.append(src.slice(last, m.index));
    const span = el('span', m[1] ? 'hl-com' : m[2] ? 'hl-str' : m[3] ? 'hl-term' : 'hl-rune', m[0]);
    pre.appendChild(span);
    last = m.index + m[0].length;
  }
  if (last < src.length) pre.append(src.slice(last));
  return pre;
}

// the Run tab is an MCP client: a JSON-RPC tools/call to the endpoint,
// the same request Claude makes, so a run here is exactly a run there
let rpcId = 0;
async function callTool(name, args) {
  const res = await fetch(BASE, { method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ jsonrpc: '2.0', id: ++rpcId, method: 'tools/call', params: { name, arguments: args } }) });
  if (!res.ok) throw new Error('tools/call: ' + res.status + ' ' + await res.text());
  return res.json();
}

function runForm(t) {
  const form = el('form', 'form run-form');
  const props = (t.inputSchema && t.inputSchema.properties) || {};
  const req = (t.inputSchema && t.inputSchema.required) || [];
  const fields = [];
  Object.keys(props).forEach((k) => {
    const def = props[k];
    const label = el('label'); label.append(document.createTextNode(k + (req.includes(k) ? ' *' : '') + ' '));
    let input;
    if (def.type === 'boolean') { input = document.createElement('input'); input.type = 'checkbox'; label.classList.add('check'); }
    else if (def.type === 'object' || def.type === 'array') { input = document.createElement('textarea'); input.rows = 3; input.placeholder = def.type === 'array' ? '[…]' : '{…}'; input.className = 'mono'; }
    else { input = document.createElement('input'); input.type = 'text'; input.placeholder = def.description || def.type || ''; input.spellcheck = false; }
    label.title = def.description || '';
    label.appendChild(input); form.appendChild(label);
    fields.push({ k, def, input });
  });
  if (!fields.length) form.appendChild(el('p', 'muted', 'No parameters.'));
  // another nexus's tool is called through its path, like a client would
  if (!here.own) form.appendChild(el('p', 'muted', 'called as call_tool with path=' + here.path));
  const row = el('div', 'row');
  const btn = el('button', 'small primary', 'Run'); btn.type = 'submit';
  const msg = el('span', 'muted');
  row.append(btn, msg); form.appendChild(row);
  const out = el('pre', 'run-result'); out.hidden = true; form.appendChild(out);
  form.onsubmit = async (e) => {
    e.preventDefault();
    const args = {};
    try {
      fields.forEach(({ k, def, input }) => {
        if (def.type === 'boolean') { if (input.checked) args[k] = true; return; }
        const raw = input.value.trim();
        if (!raw) { if (req.includes(k)) throw new Error(k + ' is required'); return; }
        if (def.type === 'number') { const n = Number(raw); if (Number.isNaN(n)) throw new Error(k + ' must be a number'); args[k] = n; }
        else if (def.type === 'object' || def.type === 'array') args[k] = JSON.parse(raw);
        else args[k] = raw;
      });
    } catch (err) { msg.textContent = err.message; return; }
    spinBtn(btn, true); msg.textContent = ''; msg.appendChild(spinner('running…')); out.hidden = true;
    loadRuns().catch(() => {});
    try {
      const rpc = !here.own
        ? await callTool('call_tool', { tool_name: t.name, path: here.path, tool_args: args })
        : await callTool(t.name, args);
      msg.textContent = rpc.error ? 'error' : 'done';
      const text = rpc.error ? rpc.error.message : ((rpc.result && rpc.result.content) || []).map((c) => c.text !== undefined ? c.text : JSON.stringify(c)).join('\n');
      out.textContent = text || JSON.stringify(rpc, null, 2); out.hidden = false;
    } catch (err) { msg.textContent = err.message; }
    finally { spinBtn(btn, false); loadRuns().catch(() => {}); }
  };
  return form;
}

// ---- runs: run grubs in the tools child ----
let runs = [];
async function loadRuns() {
  try { runs = await jget('/api/runs'); } catch (e) { runs = []; }
  renderRuns();
}
function renderRuns() {
  const box = $('runs'); box.textContent = '';
  $('runs-count').textContent = runs.length ? runs.length + ' in flight' : '';
  if (!runs.length) { box.innerHTML = '<div class="empty">No runs in flight.</div>'; updateCounts(); return; }
  runs.forEach((r) => {
    const row = el('div', 'run-row');
    const sum = r.result === null || r.result === undefined ? '—' : r.result.type === 'error' ? 'error' : typeof r.result.text === 'string' ? r.result.text.replace(/\s+/g, ' ').trim().slice(0, 80) : 'result';
    row.append(el('span', 'mono muted', r.id), el('span', 'tool-name mono', r.tool), el('span', 'step ' + (r.step || ''), r.step), el('span', 'run-sum' + (r.result && r.result.type === 'error' ? ' err' : ''), sum));
    row.onclick = () => { const b = $('run-modal-body'); b.textContent = ''; b.append(el('h4', 'mono', r.tool + ' · ' + r.id), el('pre', 'json', JSON.stringify(r, null, 2))); $('run-modal').show(); };
    box.appendChild(row);
  });
  updateCounts();
}

function updateCounts() { $('counts').textContent = allTools.length + ' tools · ' + runs.length + ' runs'; }

async function refresh() { await Promise.all([loadTools(), loadRuns()]); }
$('refresh').onclick = refresh;
refresh();
setInterval(() => loadRuns().catch(() => {}), 10000);
