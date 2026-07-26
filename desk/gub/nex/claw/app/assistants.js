// assistants explorer: the /assistants/ namespace as a tree.
// Categories are directories; leaves are <name>.assistant instances.
// Manage each via its card; config edits main.assistant directly.

var API = '/grubbery/api';
var state = null;

function fetchState() {
  var ld = document.getElementById('loader');
  if (ld) ld.classList.add('on');
  return fetch('/grubbery/claw/api/state.json')
    .then(function(r) { return r.json(); })
    .then(function(s) { state = s; render(); })
    .catch(function() {})
    .finally(function() { if (ld) ld.classList.remove('on'); });
}

function poke(body, cb) {
  fetch(API + '/poke/' + state.ball + '/main.sig?blot=/json', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  }).then(function(r) { if (cb) cb(r.ok); });
}

function assistantRel(path) {
  var segs = path.split('/');
  segs[segs.length - 1] += '.assistant';
  return 'assistants/' + segs.join('/') + '/main.assistant';
}

function grubRead(rel) {
  return fetch('/grubbery/ball/' + state.ball + '/' + rel + '?blot=/json')
    .then(function(r) { return r.json(); });
}

function grubWrite(rel, jon) {
  return fetch(API + '/over/' + state.ball + '/' + rel + '?blot=/json', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(jon)
  });
}

function esc(s) {
  var d = document.createElement('div');
  d.textContent = s == null ? '' : String(s);
  return d.innerHTML;
}

function recurLabel(cfg) {
  var r = (cfg && cfg.recur) || {};
  var a = r.args || {};
  var k = r.kind || '?';
  if (k === 'every') return 'every ' + (a.period || '?') + ' min';
  if (k === 'daily') return 'daily ' + fmtAt(a.at);
  if (k === 'weekly') return 'weekly ' + ((a.days || []).join('/')) + ' ' + fmtAt(a.at);
  return k;
}

function fmtAt(at) {
  if (at == null) return '';
  if (typeof at === 'string') return at;
  var h = Math.floor(at / 60), m = at % 60;
  return ('0' + h).slice(-2) + ':' + ('0' + m).slice(-2);
}

// ---- tree ---------------------------------------------------------

function buildTree(list) {
  // nested {dirs: {name: node}, leaves: [assistant]}
  var root = { dirs: {}, leaves: [] };
  list.forEach(function(a) {
    var segs = a.path.split('/');
    var node = root;
    for (var i = 0; i < segs.length - 1; i++) {
      node.dirs[segs[i]] = node.dirs[segs[i]] || { dirs: {}, leaves: [] };
      node = node.dirs[segs[i]];
    }
    a.name = segs[segs.length - 1];
    node.leaves.push(a);
  });
  return root;
}

function render() {
  var el = document.getElementById('tree');
  el.innerHTML = '';
  var list = (state.assistants || []).slice()
    .sort(function(a, b) { return a.path.localeCompare(b.path); });
  if (!list.length) {
    el.innerHTML = '<div class="empty">no assistants yet — create one above</div>';
    return;
  }
  renderNode(buildTree(list), el);
}

function renderNode(node, el) {
  node.leaves
    .sort(function(a, b) { return a.name.localeCompare(b.name); })
    .forEach(function(a) { el.appendChild(assistantCard(a)); });
  Object.keys(node.dirs).sort().forEach(function(d) {
    var wrap = document.createElement('div');
    wrap.className = 'tree-dir';
    var label = document.createElement('div');
    label.className = 'tree-dir-label';
    label.textContent = '▾ ' + d + '/';
    var kids = document.createElement('div');
    kids.className = 'tree-kids';
    label.onclick = function() {
      var open = kids.style.display !== 'none';
      kids.style.display = open ? 'none' : '';
      label.textContent = (open ? '▸ ' : '▾ ') + d + '/';
    };
    wrap.appendChild(label);
    wrap.appendChild(kids);
    renderNode(node.dirs[d], kids);
    el.appendChild(wrap);
  });
}

function assistantCard(a) {
  var cfg = a.config || {};
  var on = cfg.enabled === true;
  var card = document.createElement('div');
  card.className = 'entity-card';
  card.innerHTML =
    '<div class="entity-info">' +
      '<span class="dot ' + (on ? 'on' : 'off') + '"></span>' +
      '<a class="asst-name" href="/grubbery/claw/assistants/' + esc(a.path) + '">' +
        esc(a.name) + '</a>' +
      (cfg.code
        ? '<a class="entity-type code-link" href="/grubbery/ball/code/lib/assistants/' +
          esc(cfg.code) + '.hoon?view=1" target="_blank">' + esc(cfg.code) + '</a>'
        : '<span class="entity-type">?</span>') +
      '<span class="asst-recur">' + esc(recurLabel(cfg)) +
        (cfg.zone ? ' · ' + esc(cfg.zone) : '') + '</span>' +
    '</div>' +
    '<div class="card-actions">' +
      '<button class="hdr-btn" onclick="toggleAssistant(\'' + a.path + '\')">' +
        (on ? 'disable' : 'enable') + '</button>' +
      '<button class="hdr-btn" onclick="openAssistant(\'' + a.path + '\')">config</button>' +
      '<button class="delete-btn" onclick="deleteAssistant(\'' + a.path + '\')">delete</button>' +
    '</div>';
  return card;
}

// ---- actions ------------------------------------------------------

function createAssistant() {
  var p = document.getElementById('asst-path').value.trim();
  if (!p) return;
  poke({ action: 'assistant-create', path: p }, function() {
    document.getElementById('asst-path').value = '';
    setTimeout(fetchState, 500);
  });
}

function deleteAssistant(path) {
  if (!confirm('Delete assistant ' + path + '?')) return;
  poke({ action: 'assistant-delete', path: path }, function() {
    setTimeout(fetchState, 500);
  });
}

function toggleAssistant(path) {
  grubRead(assistantRel(path)).then(function(cfg) {
    cfg.enabled = !(cfg.enabled === true);
    return grubWrite(assistantRel(path), cfg);
  }).then(function() { setTimeout(fetchState, 500); });
}

// ---- config modal (shared component) ------------------------------

function openAssistant(path) {
  openAssistantConfig(state.ball, path, fetchState);
}

fetchState();
