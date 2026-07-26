// per-assistant detail page: config summary + file tree + editor.
// The assistant path comes from the URL after /assistants/.

var API = '/grubbery/api';
var BALL = null;
var asstPath = decodeURIComponent(
  location.pathname.replace(/^.*\/assistants\//, '').replace(/\/$/, ''));

function $(id) { return document.getElementById(id); }

function esc(s) {
  var d = document.createElement('div');
  d.textContent = s == null ? '' : String(s);
  return d.innerHTML;
}

function asstDir() {
  var segs = asstPath.split('/');
  segs[segs.length - 1] += '.assistant';
  return 'assistants/' + segs.join('/');
}

function recurLabel(cfg) {
  var r = (cfg && cfg.recur) || {};
  var a = r.args || {};
  var k = r.kind || '?';
  var at = typeof a.at === 'string' ? a.at : '';
  if (k === 'every') return 'every ' + (a.period || '?') + ' min';
  if (k === 'daily') return 'daily ' + at;
  if (k === 'weekly') return 'weekly ' + ((a.days || []).join('/')) + ' ' + at;
  return k;
}

// ---- load ---------------------------------------------------------

var config = null;

function load() {
  var ld = $('loader');
  ld.classList.add('on');
  $('asst-title').textContent = asstPath;
  document.title = asstPath;
  Promise.all([
    fetch('/grubbery/claw/api/state.json').then(function(r) { return r.json(); }),
    fetch('/grubbery/claw/api/tree.json?path=' + encodeURIComponent(asstPath))
      .then(function(r) { return r.json(); })
  ]).then(function(res) {
    BALL = res[0].ball;
    var mine = (res[0].assistants || []).filter(function(a) {
      return a.path === asstPath;
    })[0];
    config = (mine && mine.config) || {};
    renderMeta();
    renderFiles(res[1]);
  }).finally(function() { ld.classList.remove('on'); });
}

function renderMeta() {
  var on = config.enabled === true;
  $('asst-meta').style.display = '';
  $('m-dot').className = 'dot ' + (on ? 'on' : 'off');
  $('m-code').textContent = config.code || '?';
  $('m-code').href = '/grubbery/ball/code/lib/assistants/' + (config.code || '') + '.hoon?view=1';
  $('m-recur').textContent = recurLabel(config) + (config.zone ? ' · ' + config.zone : '');
  $('m-toggle').textContent = on ? 'disable' : 'enable';
}

$('m-config').onclick = function() {
  openAssistantConfig(BALL, asstPath, load);
};

$('m-toggle').onclick = function() {
  config.enabled = !(config.enabled === true);
  fetch(API + '/over/' + BALL + '/' + asstDir() + '/main.assistant?blot=/json', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(config)
  }).then(function() { setTimeout(load, 500); });
};

// ---- files --------------------------------------------------------

function renderFiles(files) {
  var el = $('files');
  el.innerHTML = '';
  files.sort(function(a, b) { return a.path.localeCompare(b.path); });
  if (!files.length) {
    el.innerHTML = '<div class="empty">no files</div>';
    return;
  }
  files.forEach(function(f) {
    var rel = f.path.replace(/^\//, '');
    var card = document.createElement('div');
    card.className = 'entity-card';
    card.style.cursor = 'pointer';
    card.onclick = function() { openFile(rel, f.blot); };
    card.innerHTML =
      '<div class="entity-info">' +
        '<span class="file-name">' + esc(rel) + '</span>' +
        '<span class="entity-type">' + esc(f.blot) + '</span>' +
      '</div>';
    el.appendChild(card);
  });
}

// ---- file modal: view first, edit on request ----------------------

var edTarget = null;   // {rel, blot: '/json'|'/txt'}

function setMode(editing) {
  $('ed-view').style.display = editing ? 'none' : '';
  $('ed-text').style.display = editing ? '' : 'none';
  $('ed-edit').style.display = editing ? 'none' : '';
  $('ed-save').style.display = editing ? '' : 'none';
}

function openFile(rel, blot) {
  var url = '/grubbery/ball/' + BALL + '/' + asstDir() + '/' + rel;
  // json blots edit as pretty json; everything else tries txt
  var asJson = blot === 'json' || rel === 'main.assistant';
  var q = asJson ? '?blot=/json' : '?blot=/txt';
  fetch(url + q)
    .then(function(r) {
      if (!r.ok) throw new Error('fetch failed');
      return asJson ? r.json().then(function(j) {
        return JSON.stringify(j, null, 2);
      }) : r.text();
    })
    .then(function(text) {
      edTarget = { rel: rel, blot: asJson ? '/json' : '/txt' };
      $('ed-name').textContent = rel;
      $('ed-view').textContent = text;
      $('ed-text').value = text;
      $('ed-status').textContent = '';
      setMode(false);
      $('file-back').classList.add('open');
    })
    .catch(function() {
      alert('cannot read ' + rel + ' as text or json');
    });
}

$('ed-edit').onclick = function() {
  setMode(true);
  $('ed-text').focus();
};

$('ed-close').onclick = function() {
  $('file-back').classList.remove('open');
  edTarget = null;
};
$('file-back').onclick = function(e) {
  if (e.target === this) { this.classList.remove('open'); edTarget = null; }
};

$('ed-save').onclick = function() {
  if (!edTarget) return;
  var st = $('ed-status');
  var body = $('ed-text').value;
  if (edTarget.blot === '/json') {
    try { body = JSON.stringify(JSON.parse(body)); }
    catch (e) { st.textContent = 'invalid JSON'; st.className = 'err'; return; }
  }
  fetch(API + '/over/' + BALL + '/' + asstDir() + '/' + edTarget.rel +
        '?blot=' + edTarget.blot, {
    method: 'POST',
    body: body
  }).then(function(r) {
    if (!r.ok) { st.textContent = 'save failed'; st.className = 'err'; return; }
    st.className = '';
    st.textContent = 'saved';
    $('ed-view').textContent = $('ed-text').value;
    setMode(false);
    setTimeout(function() { st.textContent = ''; }, 1500);
  });
};

function createFile() {
  var name = $('new-file').value.trim();
  if (!name) return;
  var isJson = /\.json$/.test(name);
  fetch(API + '/file/' + BALL + '/' + asstDir() + '/' + name +
        '?blot=' + (isJson ? '/json' : '/txt'), {
    method: 'PUT',
    body: isJson ? '{}' : ''
  }).then(function() {
    $('new-file').value = '';
    setTimeout(load, 500);
  });
}

load();
