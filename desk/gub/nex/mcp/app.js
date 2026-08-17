// mcp ui: tool registry (left) + the /proc tree (right).
// Data: GET /grubbery/mcp/api/tools  (JSON-RPC tools/list shape, full registry)
//       GET /grubbery/mcp/api/proc   ({dirs, files, transport} tree)
//       GET /grubbery/mcp/api/src?tool=
//       POST /grubbery/mcp/api/run | run-del | sandbox-add | sandbox-edit | sandbox-del

const $ = (id) => document.getElementById(id);

let tools = [];        // flat, for the run form's tool select
let toolsTree = { dirs: [], tools: [] }; // location tree, root = lib/mcp
let proc = { dirs: [], files: [], transport: [] };
const collapsed = new Set();     // /proc dir paths the user closed
const toolsCollapsed = new Set(); // registry group paths the user closed

async function fetchJson(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${url}: ${res.status}`);
  return res.json();
}

async function postJson(url, body) {
  const res = await fetch(url, { method: 'POST', body: JSON.stringify(body) });
  if (!res.ok) throw new Error(`${url}: ${res.status} ${await res.text()}`);
  return res;
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
  // root is implicit /code/lib/mcp: its dirs and tools render at top level
  for (const d of toolsTree.dirs || []) renderToolsNode(d, d.name, 0, out);
  for (const t of toolsTree.tools || []) out.appendChild(toolRow(t, 0));
  updateCounts();
}

// ── the /proc tree ─────────────────────────────────────────────────

async function loadProc() {
  proc = await fetchJson('/grubbery/mcp/api/proc');
  renderProc();
}

function countRuns(node) {
  let n = (node.files || []).length;
  for (const d of node.dirs || []) n += countRuns(d);
  return n;
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

function row(depth) {
  const el = document.createElement('div');
  el.className = 'tree-row';
  el.style.paddingLeft = `${8 + depth * 20}px`;
  return el;
}

function dirRow(node, path, depth) {
  const el = row(depth);
  el.classList.add('tree-dir');

  const caret = document.createElement('button');
  caret.className = 'caret';
  caret.textContent = collapsed.has(path) ? '▸' : '▾';
  caret.addEventListener('click', (e) => {
    e.stopPropagation();
    if (collapsed.has(path)) collapsed.delete(path);
    else collapsed.add(path);
    renderProc();
  });

  const name = document.createElement('span');
  name.className = 'dir-name mono';
  name.textContent = node.name + '/';

  const rules = document.createElement('span');
  rules.className = 'sb-count';
  if (node.rules === null || node.rules === undefined) {
    rules.textContent = 'open';
    rules.title = 'no weir: nothing filtered';
  } else if (!node.rules.length) {
    rules.textContent = 'closed';
    rules.title = 'empty weir: reaches nothing';
  } else {
    rules.textContent = `${node.rules.length} rule${node.rules.length === 1 ? '' : 's'}`;
    rules.title = node.rules.map((r) => `${r.kind} ${r.road}`).join('\n');
  }

  const spacer = document.createElement('span');
  spacer.className = 'sb-spacer';

  const add = document.createElement('button');
  add.className = 'small';
  add.textContent = '+';
  add.title = `New run or sandbox inside ${path}`;
  add.addEventListener('click', (e) => { e.stopPropagation(); openChooser(path + '/'); });

  const edit = document.createElement('button');
  edit.className = 'small';
  edit.textContent = 'edit';
  edit.title = 'Edit this sandbox’s weir';
  edit.addEventListener('click', (e) => { e.stopPropagation(); openEditor(path, node.rules); });

  const del = document.createElement('button');
  del.className = 'small danger';
  del.textContent = '×';
  del.title = 'Delete this sandbox and everything inside it';
  del.addEventListener('click', async (e) => {
    e.stopPropagation();
    if (!confirm(`Delete sandbox "${path}" and everything inside it?`)) return;
    try {
      await postJson('/grubbery/mcp/api/sandbox-del', { path });
      await loadProc();
    } catch (err) { alert(err.message); }
  });

  el.append(caret, name, rules, spacer, add, edit, del);
  el.addEventListener('click', () => openEditor(path, node.rules));
  return el;
}

function fileRow(run, dirPath, depth, transport) {
  const el = row(depth);
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

  const spacer = document.createElement('span');
  spacer.className = 'sb-spacer';

  el.append(pad, id, tool, step, result, spacer);

  if (!transport) {
    const del = document.createElement('button');
    del.className = 'small danger';
    del.textContent = '×';
    del.title = 'Delete this run';
    del.addEventListener('click', async (e) => {
      e.stopPropagation();
      const path = dirPath ? `${dirPath}/${run.id}` : run.id;
      if (!confirm(`Delete run "${path}"? Its result and history go with it.`)) return;
      try {
        await postJson('/grubbery/mcp/api/run-del', { path });
        await loadProc();
      } catch (err) { alert(err.message); }
    });
    el.appendChild(del);
  }

  el.addEventListener('click', () =>
    showModal(`${run.tool} · ${dirPath ? dirPath + '/' : ''}${run.id}`,
      JSON.stringify(run, null, 2)));
  return el;
}

function renderNode(node, path, depth, out) {
  out.appendChild(dirRow(node, path, depth));
  if (collapsed.has(path)) return;
  const dirs = node.dirs || [];
  const files = node.files || [];
  if (!dirs.length && !files.length) {
    const el = row(depth + 1);
    el.classList.add('tree-empty');
    const pad = document.createElement('span');
    pad.className = 'caret-pad';
    const msg = document.createElement('span');
    msg.className = 'muted';
    msg.textContent = 'no running processes';
    el.append(pad, msg);
    out.appendChild(el);
    return;
  }
  for (const d of dirs) {
    renderNode(d, path ? `${path}/${d.name}` : d.name, depth + 1, out);
  }
  for (const f of files) {
    out.appendChild(fileRow(f, path, depth + 1, false));
  }
}

function renderProc() {
  const out = $('proc-tree');
  out.textContent = '';
  for (const d of proc.dirs || []) renderNode(d, d.name, 0, out);
  for (const f of proc.files || []) out.appendChild(fileRow(f, '', 0, false));

  const transport = proc.transport || [];
  if (transport.length) {
    const hdr = row(0);
    hdr.classList.add('tree-dir', 'transport');
    const pad = document.createElement('span');
    pad.className = 'caret-pad';
    const name = document.createElement('span');
    name.className = 'dir-name mono';
    name.textContent = 'tools/ (transport, in flight)';
    hdr.append(pad, name);
    out.appendChild(hdr);
    for (const f of transport) out.appendChild(fileRow(f, null, 1, true));
  }

  $('proc-empty').hidden =
    (proc.dirs || []).length !== 0 ||
    (proc.files || []).length !== 0 ||
    transport.length !== 0;
  updateCounts();
}

function updateCounts() {
  $('counts').textContent =
    `${tools.length} tools · ${countRuns(proc)} runs`;
}

// ── creation: chooser -> run form / sandbox editor ─────────────────

let chooserPrefix = '';

function openChooser(prefix) {
  chooserPrefix = prefix || '';
  $('new-modal-title').textContent =
    chooserPrefix ? `New in ${chooserPrefix}` : 'New';
  $('new-modal').hidden = false;
}

$('new-run').addEventListener('click', () => {
  $('new-modal').hidden = true;
  showRunModal(chooserPrefix);
});
$('new-sandbox').addEventListener('click', () => {
  $('new-modal').hidden = true;
  openEditor(null, null, chooserPrefix);
});
$('new-modal-close').addEventListener('click', () => { $('new-modal').hidden = true; });
$('proc-new').addEventListener('click', () => openChooser(''));

function selectPane(pane) {
  $('tab-tools').classList.toggle('active', pane === 'tools');
  $('tab-instances').classList.toggle('active', pane === 'instances');
  $('tools-view').hidden = pane !== 'tools';
  $('instances-view').hidden = pane !== 'instances';
}
$('tab-tools').addEventListener('click', () => selectPane('tools'));
$('tab-instances').addEventListener('click', () => selectPane('instances'));

// ── sandbox editor ─────────────────────────────────────────────────

const KINDS = ['poke', 'peek', 'make'];

// Every tool needs these two boundary crossings just to run. Pre-filled,
// not hidden — delete them and the sandbox can't run anything, which is
// a legitimate choice.
const BASELINE_RULES = [
  { kind: 'poke', road: '/sys/bowl.sig' },  // fiber runtime: time, identity, entropy
  { kind: 'peek', road: '/code/' },         // load tool code (app tools also need /apps/)
];

function ruleRow(rule) {
  const rowEl = document.createElement('div');
  rowEl.className = 'sb-rule-row';
  const kind = document.createElement('select');
  for (const k of KINDS) {
    const opt = document.createElement('option');
    opt.value = k;
    opt.textContent = k;
    if (rule && rule.kind === k) opt.selected = true;
    kind.appendChild(opt);
  }
  const road = document.createElement('input');
  road.type = 'text';
  road.placeholder = '/sys/eyre/  (trailing / = subtree)';
  road.spellcheck = false;
  road.value = rule ? rule.road : '';
  const rm = document.createElement('button');
  rm.className = 'small danger';
  rm.textContent = '×';
  rm.addEventListener('click', () => rowEl.remove());
  rowEl.append(kind, road, rm);
  return rowEl;
}

// editPath = existing sandbox path (edit mode); prefix = for new nested
function openEditor(editPath, rules, prefix) {
  $('sb-modal-title').textContent = editPath ? `Edit sandbox: ${editPath}` : 'New sandbox';
  $('sb-name').value = editPath ? editPath : (prefix || '');
  $('sb-name').disabled = !!editPath;
  setWeirMode(editPath ? (rules === null || rules === undefined) : false);
  $('sb-rules').textContent = '';
  for (const r of (editPath ? (rules || []) : BASELINE_RULES)) {
    $('sb-rules').appendChild(ruleRow(r));
  }
  $('sb-modal').hidden = false;
}

let weirOpen = false;
function setWeirMode(open) {
  weirOpen = open;
  $('sb-mode-rules').classList.toggle('active', !open);
  $('sb-mode-open').classList.toggle('active', open);
  $('sb-rules').style.display = open ? 'none' : '';
  $('sb-add-rule').disabled = open;
}
$('sb-mode-rules').addEventListener('click', () => setWeirMode(false));
$('sb-mode-open').addEventListener('click', () => setWeirMode(true));

function readEditor() {
  const path = $('sb-name').value.trim().replace(/^\/+|\/+$/g, '');
  if (!path || !/^[a-z0-9-]+(\/[a-z0-9-]+)*$/.test(path)) {
    throw new Error('path must be segments of lowercase, digits, hyphens');
  }
  if (weirOpen) return { path, rules: null };
  const rules = [];
  for (const rowEl of $('sb-rules').children) {
    const [kind, road] = rowEl.children;
    if (!road.value.trim()) continue;
    if (!road.value.startsWith('/')) throw new Error(`road must start with /: ${road.value}`);
    rules.push({ kind: kind.value, road: road.value.trim() });
  }
  return { path, rules };
}

$('sb-add-rule').addEventListener('click', () => $('sb-rules').appendChild(ruleRow()));
$('sb-cancel').addEventListener('click', () => { $('sb-modal').hidden = true; });
$('sb-modal-close').addEventListener('click', () => { $('sb-modal').hidden = true; });
$('sb-save').addEventListener('click', async () => {
  let body;
  try { body = readEditor(); } catch (err) { alert(err.message); return; }
  const isEdit = $('sb-name').disabled;
  try {
    await postJson(`/grubbery/mcp/api/sandbox-${isEdit ? 'edit' : 'add'}`, body);
    $('sb-modal').hidden = true;
    await loadProc();
  } catch (err) { alert(err.message); }
});

// ── modals: raw view, tool detail, run form ────────────────────────

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
      panel.replaceChildren(runForm(t, ''));
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

function showRunModal(prefix) {
  $('modal-title').textContent = 'New run';
  const wrap = document.createElement('div');
  const picker = document.createElement('label');
  picker.className = 'sb-field run-field pad-top';
  const pickName = document.createElement('span');
  pickName.textContent = 'tool';
  const sel = document.createElement('select');
  const blank = document.createElement('option');
  blank.value = '';
  blank.textContent = 'select a tool…';
  sel.appendChild(blank);
  for (const t of tools) {
    const opt = document.createElement('option');
    opt.value = t.name;
    opt.textContent = t.name;
    sel.appendChild(opt);
  }
  picker.append(pickName, sel);
  const formSlot = document.createElement('div');
  sel.addEventListener('change', () => {
    const t = tools.find((x) => x.name === sel.value);
    formSlot.replaceChildren();
    if (t) formSlot.appendChild(runForm(t, prefix || ''));
  });
  wrap.append(picker, formSlot);
  $('modal-body').replaceChildren(wrap);
  $('modal').hidden = false;
}

function runForm(t, prefix) {
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

  const place = document.createElement('label');
  place.className = 'sb-field run-field';
  const placeName = document.createElement('span');
  placeName.textContent = 'path';
  placeName.title = 'Where under /proc this run lives. Blank = auto id at /proc root.';
  const placeInput = document.createElement('input');
  placeInput.type = 'text';
  placeInput.placeholder = 'sandbox/run-name — blank for auto';
  placeInput.spellcheck = false;
  placeInput.value = prefix || '';
  place.append(placeName, placeInput);
  body.appendChild(place);

  const status = document.createElement('p');
  status.className = 'sb-note';
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
    const req = { tool: t.name, args };
    const pathVal = placeInput.value.trim().replace(/^\/+|\/+$/g, '');
    if (pathVal) req.path = pathVal;
    runBtn.disabled = true;
    status.textContent = 'Starting…';
    try {
      await postJson('/grubbery/mcp/api/run', req);
      $('modal').hidden = true;
      selectPane('instances');
      await loadProc();
    } catch (err) {
      status.textContent = String(err.message || err);
    } finally {
      runBtn.disabled = false;
    }
  });
  actions.appendChild(runBtn);
  body.append(status, actions);
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
  if (e.key === 'Escape') {
    $('modal').hidden = true;
    $('sb-modal').hidden = true;
    $('new-modal').hidden = true;
  }
});

// ── boot ───────────────────────────────────────────────────────────

async function refresh() {
  try {
    await Promise.all([loadTools(), loadProc()]);
  } catch (err) {
    $('counts').textContent = String(err);
  }
}

$('refresh').addEventListener('click', refresh);
refresh();
setInterval(loadProc, 10000);
