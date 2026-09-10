// mcp ui: tool registry, runs in flight, and a reference reader.
// Data: GET /grubbery/mcp/api/tools-tree  (registry as a location tree)
//       GET /grubbery/mcp/api/runs        (run grubs in the tools child)
//       GET /grubbery/mcp/api/src?tool=
//       POST /grubbery/mcp                (JSON-RPC tools/call — the same
//                                          path every MCP client uses)

const $ = (id) => document.getElementById(id);

let tools = [];        // flat, for the run form's tool select
let toolsTree = { dirs: [], tools: [] }; // location tree, root = lib/tools
let runs = [];
const toolsCollapsed = new Set(); // registry group paths the user closed

async function fetchJson(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${url}: ${res.status}`);
  return res.json();
}

// ── tools pane ─────────────────────────────────────────────────────

async function loadTools() {
  toolsTree = await fetchJson('/grubbery/mcp/api/tools-tree');
  tools = [];
  (function flatten(node) {
    for (const t of node.tools || []) tools.push(t);
    for (const d of node.dirs || []) flatten(d);
  })(toolsTree);
  renderToolsTree();
}

function lastSeg(name) {
  const parts = name.split('__');
  return parts[parts.length - 1];
}

function fileOf(name) {
  return lastSeg(name).replace(/_/g, '-') + '.hoon';
}

function row(depth) {
  const el = document.createElement('div');
  el.className = 'tree-row';
  el.style.paddingLeft = `${8 + depth * 20}px`;
  return el;
}

function toolRow(t, depth) {
  const el = row(depth);
  el.classList.add('tree-file', 'tool-row');
  const pad = document.createElement('span');
  pad.className = 'caret-pad';
  const name = document.createElement('span');
  name.className = 'tool-row-name mono';
  name.textContent = fileOf(t.name);
  name.title = t.name;
  const call = document.createElement('span');
  call.className = 'tool-row-call mono';
  call.textContent = t.name;
  call.title = 'callable name';
  const desc = document.createElement('span');
  desc.className = 'tool-row-desc';
  desc.textContent = t.description || '';
  desc.title = t.description || '';
  const params = document.createElement('span');
  params.className = 'tool-params tool-row-params';
  const props = (t.inputSchema && t.inputSchema.properties) || {};
  const required = (t.inputSchema && t.inputSchema.required) || [];
  for (const key of Object.keys(props)) {
    const chip = document.createElement('span');
    chip.className = 'chip' + (required.includes(key) ? ' req' : '');
    chip.textContent = key;
    chip.title = `${props[key].type || ''} — ${props[key].description || ''}`;
    params.appendChild(chip);
  }
  el.append(pad, name, call, desc, params);
  el.addEventListener('click', () => showToolModal(t));
  return el;
}

function countTools(node) {
  let n = (node.tools || []).length;
  for (const d of node.dirs || []) n += countTools(d);
  return n;
}

function renderToolsNode(node, path, depth, out) {
  const el = row(depth);
  el.classList.add('tree-dir');
  const caret = document.createElement('button');
  caret.className = 'caret';
  caret.textContent = toolsCollapsed.has(path) ? '▸' : '▾';
  const toggle = () => {
    if (toolsCollapsed.has(path)) toolsCollapsed.delete(path);
    else toolsCollapsed.add(path);
    renderToolsTree();
  };
  caret.addEventListener('click', (e) => { e.stopPropagation(); toggle(); });
  const name = document.createElement('span');
  name.className = 'dir-name mono';
  name.textContent = node.name + '/';
  const count = document.createElement('span');
  count.className = 'sb-count';
  const n = countTools(node);
  count.textContent = `${n} tool${n === 1 ? '' : 's'}`;
  el.append(caret, name, count);
  el.addEventListener('click', toggle);
  out.appendChild(el);
  if (toolsCollapsed.has(path)) return;
  for (const d of node.dirs || []) {
    renderToolsNode(d, `${path}/${d.name}`, depth + 1, out);
  }
  for (const t of node.tools || []) out.appendChild(toolRow(t, depth + 1));
}

function renderToolsTree() {
  const out = $('tools-tree');
  out.textContent = '';
  // root is implicit /code/lib/tools: its dirs and tools render at top level
  for (const d of toolsTree.dirs || []) renderToolsNode(d, d.name, 0, out);
  for (const t of toolsTree.tools || []) out.appendChild(toolRow(t, 0));
  updateCounts();
}

// ── runs pane: run grubs in the tools child, in flight ─────────────

async function loadRuns() {
  runs = await fetchJson('/grubbery/mcp/api/runs');
  renderRuns();
}

function stepClass(step) {
  if (step === 'done') return 'step done';
  if (step === 'start') return 'step start';
  return 'step running';
}

function resultSummary(run) {
  const r = run.result;
  if (r === null || r === undefined) return { text: '—', cls: 'muted' };
  if (r.type === 'error') return { text: 'error', cls: 'err' };
  if (typeof r.text === 'string') {
    const flat = r.text.replace(/\s+/g, ' ').trim();
    return { text: flat.slice(0, 60) || '(empty)', cls: '' };
  }
  return { text: 'result', cls: '' };
}

function runRow(run) {
  const el = row(0);
  el.classList.add('tree-file');
  const pad = document.createElement('span');
  pad.className = 'caret-pad';
  const id = document.createElement('span');
  id.className = 'file-id mono';
  id.textContent = run.id;
  const tool = document.createElement('span');
  tool.className = 'file-tool';
  tool.textContent = run.tool;
  const step = document.createElement('span');
  step.className = stepClass(run.step);
  step.textContent = run.step;
  const sum = resultSummary(run);
  const result = document.createElement('span');
  result.className = 'file-result ' + sum.cls;
  result.textContent = sum.text;
  el.append(pad, id, tool, step, result);
  el.addEventListener('click', () =>
    showModal(`${run.tool} · ${run.id}`, JSON.stringify(run, null, 2)));
  return el;
}

function renderRuns() {
  const out = $('runs-list');
  out.textContent = '';
  for (const r of runs) out.appendChild(runRow(r));
  $('runs-empty').hidden = runs.length !== 0;
  updateCounts();
}

function updateCounts() {
  $('counts').textContent = `${tools.length} tools · ${runs.length} runs`;
}

function selectPane(pane) {
  $('tab-tools').classList.toggle('active', pane === 'tools');
  $('tab-runs').classList.toggle('active', pane === 'runs');
  $('tab-reference').classList.toggle('active', pane === 'reference');
  $('tools-view').hidden = pane !== 'tools';
  $('runs-view').hidden = pane !== 'runs';
  $('reference-view').hidden = pane !== 'reference';
  if (pane === 'reference') renderReference();
}
$('tab-tools').addEventListener('click', () => selectPane('tools'));
$('tab-runs').addEventListener('click', () => selectPane('runs'));
$('tab-reference').addEventListener('click', () => selectPane('reference'));

// ── reference: a docs-style reading surface over the registry ──────
// Sidebar of tool names grouped by directory; main panel stacks every
// tool as a readable section: description as markdown, plus a
// Schema | Source toggle. Source lazy-loads from /api/src.

let refRendered = false;

function refGroups() {
  const groups = [];
  (function walk(node, prefix) {
    const here = prefix || 'lib/tools';
    if ((node.tools || []).length) groups.push({ dir: here, tools: node.tools });
    for (const d of node.dirs || []) walk(d, `${here}/${d.name}`);
  })(toolsTree, '');
  return groups;
}

function md(text) {
  const el = document.createElement('div');
  el.className = 'ref-md';
  el.innerHTML = marked.parse(text || '', { async: false });
  return el;
}

function refSchemaTable(t) {
  const props = (t.inputSchema && t.inputSchema.properties) || {};
  const required = (t.inputSchema && t.inputSchema.required) || [];
  const table = document.createElement('table');
  table.className = 'ref-schema';
  const head = table.insertRow();
  for (const h of ['parameter', 'type', 'required', 'description']) {
    const th = document.createElement('th');
    th.textContent = h;
    head.appendChild(th);
  }
  for (const key of Object.keys(props)) {
    const row = table.insertRow();
    row.insertCell().appendChild(Object.assign(document.createElement('code'), { textContent: key }));
    row.insertCell().textContent = props[key].type || '';
    const reqCell = row.insertCell();
    if (required.includes(key)) {
      reqCell.textContent = 'yes';
      reqCell.className = 'ref-req';
    }
    row.insertCell().textContent = props[key].description || '';
  }
  return table;
}

function refSection(t) {
  // shell only: header + placeholder. Body (markdown, schema, source
  // toggle) fills lazily when the section nears the viewport.
  const sec = document.createElement('section');
  sec.className = 'ref-tool';
  sec.id = `ref-${t.name}`;
  sec.style.minHeight = '120px';

  const h = document.createElement('h2');
  h.textContent = fileOf(t.name).replace(/\.hoon$/, '');
  const call = document.createElement('code');
  call.className = 'ref-call';
  call.textContent = t.name;
  h.appendChild(call);
  sec.appendChild(h);

  let filled = false;
  sec.refFill = () => {
    if (filled) return;
    filled = true;
    sec.style.minHeight = '';

    sec.appendChild(md(t.description || ''));

    const toggle = document.createElement('div');
    toggle.className = 'seg-group ref-toggle';
    const bSchema = Object.assign(document.createElement('button'), { textContent: 'Schema', className: 'seg active' });
    const bSource = Object.assign(document.createElement('button'), { textContent: 'Source', className: 'seg' });
    toggle.append(bSchema, bSource);
    sec.appendChild(toggle);

    const schemaPane = refSchemaTable(t);
    const sourcePane = document.createElement('div');
    sourcePane.className = 'ref-source-wrap';
    sourcePane.hidden = true;
    let sourceLoaded = false;
    sec.append(schemaPane, sourcePane);

    bSchema.addEventListener('click', () => {
      bSchema.classList.add('active'); bSource.classList.remove('active');
      schemaPane.hidden = false; sourcePane.hidden = true;
    });
    bSource.addEventListener('click', async () => {
      bSource.classList.add('active'); bSchema.classList.remove('active');
      schemaPane.hidden = true; sourcePane.hidden = false;
      if (sourceLoaded) return;
      sourceLoaded = true;
      try {
        const r = await fetchJson(`/grubbery/mcp/api/src?tool=${encodeURIComponent(t.name)}`);
        sourcePane.textContent = '';
        sourcePane.appendChild(highlightHoon(r.text));
      } catch (e) { sourcePane.textContent = `could not load source: ${e.message}`; }
    });
  };
  refObserver.observe(sec);
  return sec;
}

const refObserver = new IntersectionObserver((entries) => {
  for (const e of entries) {
    if (e.isIntersecting && e.target.refFill) {
      e.target.refFill();
      refObserver.unobserve(e.target);
    }
  }
}, { root: null, rootMargin: '600px' });

function renderReference() {
  if (refRendered) return;
  refRendered = true;
  const side = $('ref-sidebar');
  const main = $('ref-main');
  side.textContent = '';
  main.textContent = '';
  for (const g of refGroups()) {
    const dirH = document.createElement('div');
    dirH.className = 'ref-side-dir';
    dirH.textContent = g.dir + '/';
    side.appendChild(dirH);
    const mainDirH = document.createElement('h1');
    mainDirH.className = 'ref-dir-head';
    mainDirH.textContent = g.dir + '/';
    main.appendChild(mainDirH);
    for (const t of g.tools) {
      const link = document.createElement('a');
      link.className = 'ref-side-link';
      link.textContent = fileOf(t.name).replace(/\.hoon$/, '');
      link.href = `#ref-${t.name}`;
      link.addEventListener('click', (e) => {
        e.preventDefault();
        const target = document.getElementById(`ref-${t.name}`);
        if (!target) return;
        if (target.refFill) target.refFill();
        target.scrollIntoView({ behavior: 'smooth', block: 'start' });
      });
      side.appendChild(link);
      main.appendChild(refSection(t));
    }
  }
}

// ── modals: raw view, tool detail (schema | source | run) ──────────

function showModal(title, text) {
  $('modal-title').textContent = title;
  const pre = document.createElement('pre');
  pre.textContent = text;
  $('modal-body').replaceChildren(pre);
  $('modal').hidden = false;
}

// Compact hoon highlighter: comments, strings, %terms, rune digraphs.
function highlightHoon(src) {
  const pre = document.createElement('pre');
  pre.className = 'hoon';
  const re = /(::[^\n]*)|('[^'\n]*'|"[^"\n]*")|(%[a-z][a-z0-9-]*)|([|$%:.^~;=?!_+][|$%:.^~;=?!_+*@&<>#-])/g;
  let last = 0;
  let m;
  while ((m = re.exec(src)) !== null) {
    if (m.index > last) pre.append(src.slice(last, m.index));
    const span = document.createElement('span');
    span.className = m[1] ? 'hl-com' : m[2] ? 'hl-str' : m[3] ? 'hl-term' : 'hl-rune';
    span.textContent = m[0];
    pre.appendChild(span);
    last = m.index + m[0].length;
  }
  if (last < src.length) pre.append(src.slice(last));
  return pre;
}

function showToolModal(t) {
  $('modal-title').textContent = t.name;

  const tabs = document.createElement('div');
  tabs.className = 'tabs';
  const schemaTab = document.createElement('button');
  schemaTab.className = 'tab active';
  schemaTab.textContent = 'Schema';
  const sourceTab = document.createElement('button');
  sourceTab.className = 'tab';
  sourceTab.textContent = 'Source';
  const runTab = document.createElement('button');
  runTab.className = 'tab';
  runTab.textContent = 'Run';
  tabs.append(schemaTab, sourceTab, runTab);

  const panel = document.createElement('div');
  panel.className = 'tab-panel';
  let sourceEl = null;

  function select(tab) {
    schemaTab.classList.toggle('active', tab === 'schema');
    sourceTab.classList.toggle('active', tab === 'source');
    runTab.classList.toggle('active', tab === 'run');
    if (tab === 'schema') {
      panel.replaceChildren(schemaDetail(t));
      return;
    }
    if (tab === 'run') {
      panel.replaceChildren(runForm(t));
      return;
    }
    if (sourceEl) { panel.replaceChildren(sourceEl); return; }
    const loading = document.createElement('p');
    loading.className = 'muted pad';
    loading.textContent = 'Loading source…';
    panel.replaceChildren(loading);
    fetchJson(`/grubbery/mcp/api/src?tool=${encodeURIComponent(t.name)}`)
      .then((res) => {
        sourceEl = document.createElement('div');
        const path = document.createElement('div');
        path.className = 'src-path mono';
        path.textContent = res.path;
        sourceEl.append(path, highlightHoon(res.text));
        if (sourceTab.classList.contains('active'))
          panel.replaceChildren(sourceEl);
      })
      .catch((err) => { loading.textContent = String(err); });
  }
  schemaTab.addEventListener('click', () => select('schema'));
  sourceTab.addEventListener('click', () => select('source'));
  runTab.addEventListener('click', () => select('run'));

  select('schema');
  $('modal-body').replaceChildren(tabs, panel);
  $('modal').hidden = false;
}

// The Run tab is an MCP client: it POSTs a JSON-RPC tools/call to the
// endpoint itself, so a UI run is exactly what a Claude run is — same
// path, same tools child, same weir. The result lands in the form.
let rpcId = 0;
async function callTool(name, args) {
  const res = await fetch('/grubbery/mcp', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ jsonrpc: '2.0', id: ++rpcId, method: 'tools/call',
                           params: { name, arguments: args } }),
  });
  if (!res.ok) throw new Error(`tools/call: ${res.status} ${await res.text()}`);
  return res.json();
}

function runForm(t) {
  const body = document.createElement('div');
  body.className = 'sb-form';

  const props = (t.inputSchema && t.inputSchema.properties) || {};
  const required = (t.inputSchema && t.inputSchema.required) || [];
  const fields = [];
  for (const key of Object.keys(props)) {
    const def = props[key];
    const field = document.createElement('label');
    field.className = 'sb-field run-field';
    const name = document.createElement('span');
    name.textContent = key + (required.includes(key) ? ' *' : '');
    name.title = def.description || '';
    let input;
    if (def.type === 'boolean') {
      input = document.createElement('input');
      input.type = 'checkbox';
    } else if (def.type === 'object' || def.type === 'array') {
      input = document.createElement('textarea');
      input.rows = 3;
      input.placeholder = def.type === 'array' ? '[...]' : '{...}';
    } else {
      input = document.createElement('input');
      input.type = 'text';
      input.placeholder = def.description || def.type || '';
      input.spellcheck = false;
    }
    fields.push({ key, def, input });
    field.append(name, input);
    body.appendChild(field);
  }
  if (!fields.length) {
    const none = document.createElement('p');
    none.className = 'muted';
    none.textContent = 'No parameters.';
    body.appendChild(none);
  }

  const status = document.createElement('p');
  status.className = 'sb-note';
  const out = document.createElement('pre');
  out.className = 'run-result';
  out.hidden = true;
  const actions = document.createElement('div');
  actions.className = 'sb-actions';
  const runBtn = document.createElement('button');
  runBtn.className = 'small primary';
  runBtn.textContent = 'Run';
  runBtn.addEventListener('click', async () => {
    const args = {};
    try {
      for (const { key, def, input } of fields) {
        if (def.type === 'boolean') {
          if (input.checked) args[key] = true;
          continue;
        }
        const raw = input.value.trim();
        if (!raw) {
          if (required.includes(key)) throw new Error(`${key} is required`);
          continue;
        }
        if (def.type === 'number') {
          const n = Number(raw);
          if (Number.isNaN(n)) throw new Error(`${key} must be a number`);
          args[key] = n;
        } else if (def.type === 'object' || def.type === 'array') {
          args[key] = JSON.parse(raw);
        } else {
          args[key] = raw;
        }
      }
    } catch (err) {
      status.textContent = String(err.message || err);
      return;
    }
    runBtn.disabled = true;
    status.textContent = 'Running…';
    out.hidden = true;
    loadRuns().catch(() => {});
    try {
      const rpc = await callTool(t.name, args);
      status.textContent = rpc.error ? 'error' : 'done';
      const text = rpc.error
        ? rpc.error.message
        : ((rpc.result && rpc.result.content) || []).map((c) => c.text ?? JSON.stringify(c)).join('\n');
      out.textContent = text || JSON.stringify(rpc, null, 2);
      out.hidden = false;
    } catch (err) {
      status.textContent = String(err.message || err);
    } finally {
      runBtn.disabled = false;
      loadRuns().catch(() => {});
    }
  });
  actions.appendChild(runBtn);
  body.append(status, actions, out);
  return body;
}

function schemaDetail(t) {
  const body = document.createElement('div');
  body.className = 'tool-detail';

  const desc = document.createElement('p');
  desc.className = 'detail-desc';
  desc.textContent = t.description || '(no description)';
  body.appendChild(desc);

  const props = (t.inputSchema && t.inputSchema.properties) || {};
  const required = (t.inputSchema && t.inputSchema.required) || [];
  const keys = Object.keys(props);
  if (keys.length) {
    const table = document.createElement('table');
    table.className = 'param-table';
    const thead = document.createElement('thead');
    const hr = document.createElement('tr');
    for (const h of ['parameter', 'type', '', 'description']) {
      const th = document.createElement('th');
      th.textContent = h;
      hr.appendChild(th);
    }
    thead.appendChild(hr);
    const tbody = document.createElement('tbody');
    for (const key of keys) {
      const tr = document.createElement('tr');
      const name = document.createElement('td');
      name.className = 'mono';
      name.textContent = key;
      const type = document.createElement('td');
      type.className = 'param-type';
      type.textContent = props[key].type || '';
      const req = document.createElement('td');
      req.className = 'param-req';
      req.textContent = required.includes(key) ? 'required' : '';
      const pdesc = document.createElement('td');
      pdesc.className = 'param-desc';
      pdesc.textContent = props[key].description || '';
      tr.append(name, type, req, pdesc);
      tbody.appendChild(tr);
    }
    table.append(thead, tbody);
    body.appendChild(table);
  } else {
    const none = document.createElement('p');
    none.className = 'muted';
    none.textContent = 'No parameters.';
    body.appendChild(none);
  }

  return body;
}

$('modal-close').addEventListener('click', () => { $('modal').hidden = true; });
$('modal').addEventListener('click', (e) => {
  if (e.target === $('modal')) $('modal').hidden = true;
});
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') $('modal').hidden = true;
});

// ── boot ───────────────────────────────────────────────────────────

async function refresh() {
  try {
    await Promise.all([loadTools(), loadRuns()]);
  } catch (err) {
    $('counts').textContent = String(err);
  }
}

$('refresh').addEventListener('click', refresh);
refresh();
setInterval(() => loadRuns().catch(() => {}), 10000);
