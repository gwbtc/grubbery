// mcp tools ui: read-only v1 — registry + run history.
// Data: GET /grubbery/mcp/api/tools (JSON-RPC tools/list response),
//       GET /grubbery/mcp/api/runs  ([{id, tool, step, args, result}]).

const $ = (id) => document.getElementById(id);

let tools = [];
let runs = [];
let sandboxes = [];
let editingSandbox = null; // null = closed, '' = creating, name = editing

async function fetchJson(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${url}: ${res.status}`);
  return res.json();
}

async function loadTools() {
  const rpc = await fetchJson('/grubbery/mcp/api/tools');
  tools = (rpc.result && rpc.result.tools) || [];
  renderTools();
}

async function loadRuns() {
  runs = await fetchJson('/grubbery/mcp/api/runs');
  runs.reverse(); // newest first
  renderRuns();
}

function renderTools() {
  const list = $('tool-list');
  list.textContent = '';
  for (const t of tools) {
    const card = document.createElement('div');
    card.className = 'tool-card';
    const name = document.createElement('div');
    name.className = 'tool-name';
    name.textContent = t.name;
    const desc = document.createElement('div');
    desc.className = 'tool-desc';
    desc.textContent = t.description || '';
    const params = document.createElement('div');
    params.className = 'tool-params';
    const props = (t.inputSchema && t.inputSchema.properties) || {};
    const required = (t.inputSchema && t.inputSchema.required) || [];
    for (const key of Object.keys(props)) {
      const chip = document.createElement('span');
      chip.className = 'chip' + (required.includes(key) ? ' req' : '');
      chip.textContent = key;
      chip.title = `${props[key].type || ''} — ${props[key].description || ''}`;
      params.appendChild(chip);
    }
    card.append(name, desc, params);
    card.addEventListener('click', () => showToolModal(t));
    list.appendChild(card);
  }
  updateCounts();
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
    return { text: flat.slice(0, 80) || '(empty)', cls: '' };
  }
  return { text: 'result', cls: '' };
}

function renderRuns() {
  const body = $('run-rows');
  body.textContent = '';
  $('runs-empty').hidden = runs.length !== 0;
  for (const run of runs) {
    const tr = document.createElement('tr');
    const id = document.createElement('td');
    id.className = 'mono';
    id.textContent = run.id;
    const tool = document.createElement('td');
    tool.textContent = run.tool;
    const sb = document.createElement('td');
    if (run.sandbox === null || run.sandbox === undefined) {
      sb.className = 'muted';
      sb.textContent = 'trusted';
    } else if (run.sandbox === '') {
      sb.className = 'muted';
      sb.textContent = 'unsandboxed';
    } else {
      sb.className = 'mono';
      sb.textContent = run.sandbox;
    }
    const step = document.createElement('td');
    const stepSpan = document.createElement('span');
    stepSpan.className = stepClass(run.step);
    stepSpan.textContent = run.step;
    step.appendChild(stepSpan);
    const result = document.createElement('td');
    const sum = resultSummary(run);
    result.textContent = sum.text;
    if (sum.cls) result.className = sum.cls;
    const del = document.createElement('td');
    if (run.sandbox !== null && run.sandbox !== undefined) {
      const btn = document.createElement('button');
      btn.className = 'small danger';
      btn.textContent = '×';
      btn.title = 'Delete this run';
      btn.addEventListener('click', async (e) => {
        e.stopPropagation();
        const body = { path: run.sandbox ? `${run.sandbox}/${run.id}` : run.id };
        try {
          await postJson('/grubbery/mcp/api/run-del', body);
          await loadRuns();
        } catch (err) { alert(err.message); }
      });
      del.appendChild(btn);
    }
    tr.append(id, tool, sb, step, result, del);
    tr.addEventListener('click', () =>
      showModal(`${run.tool} · ${run.id}`, JSON.stringify(run, null, 2)));
    body.appendChild(tr);
  }
  updateCounts();
}

function updateCounts() {
  $('counts').textContent = `${tools.length} tools · ${runs.length} runs`;
}

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

  const place = document.createElement('label');
  place.className = 'sb-field run-field';
  const placeName = document.createElement('span');
  placeName.textContent = 'path';
  placeName.title = 'Where under /proc this run lives. First segment = sandbox. Blank = auto id at /proc root.';
  const placeInput = document.createElement('input');
  placeInput.type = 'text';
  placeInput.placeholder = 'sandbox/run-name — blank for auto';
  placeInput.spellcheck = false;
  placeInput.setAttribute('list', 'sb-paths');
  const datalist = document.createElement('datalist');
  datalist.id = 'sb-paths';
  fetchJson('/grubbery/mcp/api/sandboxes').then((sbs) => {
    for (const sb of sbs) {
      const opt = document.createElement('option');
      opt.value = sb.name + '/';
      datalist.appendChild(opt);
    }
  }).catch(() => {});
  place.append(placeName, placeInput, datalist);
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
    if (placeInput.value.trim()) req.path = placeInput.value.trim();
    runBtn.disabled = true;
    status.textContent = 'Starting…';
    try {
      await postJson('/grubbery/mcp/api/run', req);
      $('modal').hidden = true;
      selectPane('runs');
      await loadRuns();
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

function showRunModal() {
  $('modal-title').textContent = 'New run';
  const wrap = document.createElement('div');
  const picker = document.createElement('label');
  picker.className = 'sb-field run-field pad-top';
  const pickName = document.createElement('span');
  pickName.textContent = 'tool';
  const sel = document.createElement('select');
  const blank = document.createElement('option');
  blank.value = '';
  blank.textContent = 'select a tool\u2026';
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
    if (t) formSlot.appendChild(runForm(t));
  });
  wrap.append(picker, formSlot);
  $('modal-body').replaceChildren(wrap);
  $('modal').hidden = false;
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
  }
});

// ── sandboxes ──────────────────────────────────────────────────────

async function postJson(url, body) {
  const res = await fetch(url, { method: 'POST', body: JSON.stringify(body) });
  if (!res.ok) throw new Error(`${url}: ${res.status} ${await res.text()}`);
  return res;
}

async function loadSandboxes() {
  try {
    sandboxes = await fetchJson('/grubbery/mcp/api/sandboxes');
    $('sb-error').hidden = true;
  } catch (err) {
    sandboxes = [];
    $('sb-error').textContent = `Sandbox API unavailable: ${err.message}`;
    $('sb-error').hidden = false;
  }
  renderSandboxes();
}

const KINDS = ['poke', 'peek', 'make'];

function renderSandboxes() {
  const list = $('sandbox-list');
  list.textContent = '';
  $('sb-empty').hidden = sandboxes.length !== 0 || !$('sb-error').hidden;
  for (const sb of sandboxes) {
    const card = document.createElement('div');
    card.className = 'sb-card';

    const head = document.createElement('div');
    head.className = 'sb-card-head';
    const name = document.createElement('span');
    name.className = 'sb-name mono';
    name.textContent = sb.name;
    const count = document.createElement('span');
    count.className = 'sb-count';
    count.textContent = sb.rules.length
      ? `${sb.rules.length} rule${sb.rules.length === 1 ? '' : 's'}`
      : 'closed — reaches nothing';
    const spacer = document.createElement('span');
    spacer.className = 'sb-spacer';
    const edit = document.createElement('button');
    edit.className = 'small';
    edit.textContent = 'Edit';
    edit.addEventListener('click', () => openEditor(sb.name));
    const del = document.createElement('button');
    del.className = 'small danger';
    del.textContent = 'Delete';
    del.addEventListener('click', async () => {
      if (!confirm(`Delete sandbox "${sb.name}"? Its run history goes with it.`)) return;
      try {
        await postJson('/grubbery/mcp/api/sandbox-del', { name: sb.name });
        await loadSandboxes();
      } catch (err) { alert(err.message); }
    });
    head.append(name, count, spacer, edit, del);
    card.appendChild(head);

    if (sb.rules.length) {
      const table = document.createElement('table');
      table.className = 'sb-rules-table';
      for (const r of sb.rules) {
        const tr = document.createElement('tr');
        const kind = document.createElement('td');
        kind.innerHTML = '';
        const chip = document.createElement('span');
        chip.className = `chip kind-${r.kind}`;
        chip.textContent = r.kind;
        kind.appendChild(chip);
        const road = document.createElement('td');
        road.className = 'mono';
        road.textContent = r.road;
        tr.append(kind, road);
        table.appendChild(tr);
      }
      card.appendChild(table);
    }
    list.appendChild(card);
  }
}

// ── sandbox editor ─────────────────────────────────────────────────

function ruleRow(rule) {
  const row = document.createElement('div');
  row.className = 'sb-rule-row';
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
  rm.addEventListener('click', () => row.remove());
  row.append(kind, road, rm);
  return row;
}

// Every tool needs these two boundary crossings just to run: the fiber
// runtime pokes /sys/bowl.sig (time, identity, entropy) and loading the
// tool's own code is a peek into /code/. Pre-filled, not hidden — delete
// them and the sandbox can't run anything, which is a legitimate choice.
const BASELINE_RULES = [
  { kind: 'poke', road: '/sys/bowl.sig' },  // fiber runtime: time, identity, entropy
  { kind: 'peek', road: '/code/' },         // load tool code (app tools also need /apps/)
];

function openEditor(name) {
  editingSandbox = name === undefined ? '' : name;
  const existing = sandboxes.find((s) => s.name === editingSandbox);
  $('sb-modal-title').textContent = existing
    ? `Edit sandbox: ${editingSandbox}`
    : 'New sandbox';
  $('sb-name').value = existing ? existing.name : '';
  $('sb-name').disabled = !!existing;
  $('sb-rules').textContent = '';
  for (const r of (existing ? existing.rules : BASELINE_RULES)) {
    $('sb-rules').appendChild(ruleRow(r));
  }
  $('sb-modal').hidden = false;
}

function readEditor() {
  const name = $('sb-name').value.trim();
  if (!/^[a-z][a-z0-9-]*$/.test(name)) {
    throw new Error('name must be a term: lowercase, digits, hyphens');
  }
  const rules = [];
  for (const row of $('sb-rules').children) {
    const [kind, road] = row.children;
    if (!road.value.trim()) continue;
    if (!road.value.startsWith('/')) throw new Error(`road must start with /: ${road.value}`);
    rules.push({ kind: kind.value, road: road.value.trim() });
  }
  return { name, rules };
}

$('sb-new').addEventListener('click', () => openEditor());
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
    await loadSandboxes();
  } catch (err) { alert(err.message); }
});

// ── tabs ───────────────────────────────────────────────────────────

function selectPane(pane) {
  $('tab-runs').classList.toggle('active', pane === 'runs');
  $('tab-sandboxes').classList.toggle('active', pane === 'sandboxes');
  $('runs-view').hidden = pane !== 'runs';
  $('sandboxes-view').hidden = pane !== 'sandboxes';
  if (pane === 'sandboxes') loadSandboxes();
}
$('tab-runs').addEventListener('click', () => selectPane('runs'));
$('tab-sandboxes').addEventListener('click', () => selectPane('sandboxes'));

async function refresh() {
  try {
    await Promise.all([loadTools(), loadRuns()]);
  } catch (err) {
    $('counts').textContent = String(err);
  }
  if (!$('sandboxes-view').hidden) await loadSandboxes();
}

$('run-new').addEventListener('click', showRunModal);
$('refresh').addEventListener('click', refresh);
refresh();
setInterval(loadRuns, 10000);
