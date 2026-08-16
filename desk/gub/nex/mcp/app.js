// mcp tools ui: read-only v1 — registry + run history.
// Data: GET /grubbery/mcp/api/tools (JSON-RPC tools/list response),
//       GET /grubbery/mcp/api/runs  ([{id, tool, step, args, result}]).

const $ = (id) => document.getElementById(id);

let tools = [];
let runs = [];

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
    const step = document.createElement('td');
    const stepSpan = document.createElement('span');
    stepSpan.className = stepClass(run.step);
    stepSpan.textContent = run.step;
    step.appendChild(stepSpan);
    const result = document.createElement('td');
    const sum = resultSummary(run);
    result.textContent = sum.text;
    if (sum.cls) result.className = sum.cls;
    tr.append(id, tool, step, result);
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
  tabs.append(schemaTab, sourceTab);

  const panel = document.createElement('div');
  panel.className = 'tab-panel';
  let sourceEl = null;

  function select(tab) {
    schemaTab.classList.toggle('active', tab === 'schema');
    sourceTab.classList.toggle('active', tab === 'source');
    if (tab === 'schema') {
      panel.replaceChildren(schemaDetail(t));
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

  select('schema');
  $('modal-body').replaceChildren(tabs, panel);
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
  if (e.key === 'Escape') $('modal').hidden = true;
});

async function refresh() {
  try {
    await Promise.all([loadTools(), loadRuns()]);
  } catch (err) {
    $('counts').textContent = String(err);
  }
}

$('refresh').addEventListener('click', refresh);
refresh();
setInterval(loadRuns, 10000);
