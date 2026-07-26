// claw dashboard: static shell over /api/state.json.
// Mutations poke main.sig via the generic api; grub reads/writes use
// the ball/over pair. Refetch after every action — no SSE.

var API = '/grubbery/api';
var state = null;   // {ball, agents, apis, channels, assistants}

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

// ---- render -------------------------------------------------------

function render() {
  renderAssistants();
  renderAgents();
  renderTyped('apis', state.apis);
  renderTyped('channels', state.channels);
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

// dashboard shows a read-only summary; management lives on /assistants
function renderAssistants() {
  var el = document.getElementById('assistants');
  el.innerHTML = '';
  var list = (state.assistants || []).slice()
    .sort(function(a, b) { return a.path.localeCompare(b.path); });
  if (!list.length) {
    el.innerHTML = '<div class="empty">no assistants yet</div>';
    return;
  }
  list.forEach(function(a) {
    var cfg = a.config || {};
    var on = cfg.enabled === true;
    var card = document.createElement('div');
    card.className = 'entity-card';
    card.style.cursor = 'pointer';
    card.onclick = function() { location.href = '/grubbery/claw/assistants'; };
    card.innerHTML =
      '<div class="entity-info">' +
        '<span class="dot ' + (on ? 'on' : 'off') + '"></span>' +
        '<span class="asst-name">' + esc(a.path) + '</span>' +
        '<span class="asst-recur">' + esc(recurLabel(cfg)) +
          (cfg.zone ? ' · ' + esc(cfg.zone) : '') + '</span>' +
      '</div>';
    el.appendChild(card);
  });
}

function renderAgents() {
  var el = document.getElementById('agents');
  el.innerHTML = '';
  var list = (state.agents || []).slice().sort();
  if (!list.length) {
    el.innerHTML = '<div class="empty">no agents yet</div>';
    return;
  }
  list.forEach(function(n) {
    var card = document.createElement('div');
    card.className = 'entity-card';
    card.innerHTML =
      '<div class="entity-info">' +
        '<a class="agent-name" href="/grubbery/ball/' + state.ball +
          '/agents/' + esc(n) + '/page.html">' + esc(n) + '</a>' +
      '</div>' +
      '<div class="card-actions">' +
        '<button class="hdr-btn" onclick="openConfig(\'agents\',\'' + n + '\')">config</button>' +
        '<button class="delete-btn" onclick="deleteEntity(\'agents\',\'' + n + '\')">delete</button>' +
      '</div>';
    el.appendChild(card);
  });
}

function renderTyped(kind, items) {
  var el = document.getElementById(kind);
  el.innerHTML = '';
  var nameClass = kind === 'apis' ? 'api-name' : 'channel-name';
  var list = (items || []).slice()
    .sort(function(a, b) { return a.name.localeCompare(b.name); });
  if (!list.length) {
    el.innerHTML = '<div class="empty">no ' + kind + ' yet</div>';
    return;
  }
  list.forEach(function(it) {
    var card = document.createElement('div');
    card.className = 'entity-card';
    card.innerHTML =
      '<div class="entity-info">' +
        '<span class="' + nameClass + '">' + esc(it.name) + '</span>' +
        '<span class="entity-type">' + esc(it.type) + '</span>' +
      '</div>' +
      '<div class="card-actions">' +
        '<button class="hdr-btn" onclick="openConfig(\'' + kind + '\',\'' + it.name + '\')">config</button>' +
        '<button class="delete-btn" onclick="deleteEntity(\'' + kind + '\',\'' + it.name + '\')">delete</button>' +
      '</div>';
    el.appendChild(card);
  });
}

// ---- actions ------------------------------------------------------

var ACTIONS = {
  agents: { create: 'create', del: 'delete', nameId: 'agent-name' },
  apis: { create: 'create-api', del: 'delete-api', nameId: 'api-name', typeId: 'api-type' },
  channels: { create: 'create-channel', del: 'delete-channel', nameId: 'ch-name', typeId: 'ch-type' }
};

function createEntity(kind) {
  var a = ACTIONS[kind];
  var name = document.getElementById(a.nameId).value.trim();
  if (!name) return;
  var body = { action: a.create, name: name };
  if (a.typeId) {
    var t = document.getElementById(a.typeId).value.trim();
    if (!t) return;
    body.type = t;
  }
  poke(body, function() {
    document.getElementById(a.nameId).value = '';
    setTimeout(fetchState, 500);
  });
}

function deleteEntity(kind, name) {
  if (!confirm('Delete ' + name + '?')) return;
  poke({ action: ACTIONS[kind].del, name: name }, function() {
    setTimeout(fetchState, 500);
  });
}

// ---- config modal -------------------------------------------------

var cfgTarget = null;   // rel path of the grub being edited

function openModal(title, rel) {
  cfgTarget = rel;
  document.getElementById('cfg-title').textContent = title;
  document.getElementById('cfg-status').textContent = '';
  document.getElementById('cfg-json').value = '';
  document.getElementById('cfg-backdrop').classList.add('open');
  grubRead(rel).then(function(j) {
    document.getElementById('cfg-json').value = JSON.stringify(j, null, 2);
  }).catch(function() {
    document.getElementById('cfg-status').textContent = 'could not load';
  });
}

function openConfig(kind, name) {
  openModal(kind + '/' + name + ' config', kind + '/' + name + '/config.json');
}

document.getElementById('cfg-close').onclick = function() {
  document.getElementById('cfg-backdrop').classList.remove('open');
};
document.getElementById('cfg-backdrop').onclick = function(e) {
  if (e.target === this) this.classList.remove('open');
};
document.getElementById('cfg-save').onclick = function() {
  var st = document.getElementById('cfg-status');
  var jon;
  try { jon = JSON.parse(document.getElementById('cfg-json').value); }
  catch (e) { st.textContent = 'invalid JSON'; return; }
  grubWrite(cfgTarget, jon).then(function(r) {
    if (!r.ok) { st.textContent = 'save failed'; return; }
    document.getElementById('cfg-backdrop').classList.remove('open');
    setTimeout(fetchState, 500);
  });
};

fetchState();
