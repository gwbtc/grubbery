// desks: one UI over the /desk and /git/desk backends. Lists what's
// installed, and adds / configures / drives them by POSTing to the
// desks nexus, which pokes the backends.

function el(id) { return document.getElementById(id); }
function esc(s) {
  var d = document.createElement('div');
  d.textContent = (s == null) ? '' : String(s);
  return d.innerHTML;
}

var editing = null;   // null = add; else the app dir name being configured
var mode = 'git';     // 'git' | 'ship'

var HELP = {
  config: "Change where this desk comes from and how it's treated — repo, branch, poll interval, push token, or (cross-ship) source.",
  sync: "Pull the latest from the git repo and install it. Version-gated: nothing changes unless the repo's version was bumped.",
  push: "Publish THIS ship's copy of the desk's code back up to GitHub — commits the current code and pushes it to a branch you name, with a commit message you write.",
  open: "Open this desk's own backend page (checkpoints, history, lower-level controls)."
};

function setMode(m) {
  mode = m;
  el('src-git').classList.toggle('active', m === 'git');
  el('src-ship').classList.toggle('active', m === 'ship');
  el('git-fields').style.display = m === 'git' ? '' : 'none';
  el('ship-fields').style.display = m === 'ship' ? '' : 'none';
}

function openAdd() {
  editing = null;
  el('modal-title').textContent = 'new desk';
  el('m-save').textContent = 'create';
  el('m-name').value = ''; el('m-name').disabled = false;
  el('m-repo').value = ''; el('m-ref').value = 'main'; el('m-poll').value = '0'; el('m-token').value = '';
  el('m-token').placeholder = 'GitHub token';
  el('m-source').value = ''; el('m-public').checked = false;
  el('src-git').style.display = ''; el('src-ship').style.display = '';
  setMode('git');
  el('modal-back').classList.add('open');
}

function openEdit(d) {
  editing = d.name;
  el('modal-title').textContent = 'configure ' + d.name;
  el('m-save').textContent = 'save';
  el('m-name').value = d.name; el('m-name').disabled = true;
  el('m-repo').value = d.repo || ''; el('m-ref').value = d.ref || 'main';
  el('m-poll').value = (d.poll == null ? '0' : d.poll);
  el('m-token').value = d.token || '';
  el('m-token').placeholder = 'GitHub token';
  el('m-source').value = d.source || ''; el('m-public').checked = !!d.public;
  // type is fixed once created — lock the toggle
  el('src-git').style.display = 'none'; el('src-ship').style.display = 'none';
  setMode(d.type === 'git' ? 'git' : 'ship');
  el('modal-back').classList.add('open');
}

function closeModal() { el('modal-back').classList.remove('open'); }

function post(path, body) {
  return fetch('/grubbery/desks/' + path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  }).then(function(r) { return r.text().then(function(t) { return { ok: r.ok, text: t }; }); });
}

function fields(body) {
  body.public = el('m-public').checked;
  if (mode === 'git') {
    body.repo = el('m-repo').value.trim();
    body.ref = el('m-ref').value.trim() || 'main';
    body.poll = Number(el('m-poll').value) || 0;
    body.token = el('m-token').value.trim();  // the field IS the token
  } else {
    body.source = el('m-source').value.trim();
  }
  return body;
}

function save() {
  if (editing) {
    post('config', fields({ app: editing })).then(function() { closeModal(); load(); });
    return;
  }
  var name = el('m-name').value.trim();
  if (!name) return;
  var body = fields({ name: name, type: mode === 'git' ? 'git' : 'cross-ship' });
  post('add', body).then(function() { closeModal(); setTimeout(load, 700); });
}

function doSync(name) {
  post('sync', { app: name }).then(function() { setTimeout(load, 900); });
}

function openPush(d) {
  el('push-back').setAttribute('data-app', d.name);
  el('push-name').textContent = d.name;
  el('push-branch-label').textContent = d.ref || 'main';
  el('push-message').value = 'update from ship';
  el('push-status').textContent = '';
  el('push-back').classList.add('open');
}

function closePush() { el('push-back').classList.remove('open'); }

function doPush() {
  var name = el('push-back').getAttribute('data-app');
  var message = el('push-message').value.trim() || 'update from ship';
  el('push-status').textContent = 'pushing…';
  post('push', { app: name, message: message })  // branch comes from config
    .then(function(r) { el('push-status').textContent = r.text; });
}

function renderCkpts(box, rows) {
  box.innerHTML = '';
  if (!rows || !rows.length) { box.innerHTML = '<div class="muted">no checkpoints</div>'; return; }
  rows.slice().reverse().forEach(function(r) {
    var lbl = (r.tags || []).filter(function(t) { return t !== 'checkpoint'; }).join(' ');
    var when = r.da ? new Date(r.da).toLocaleString() : '';
    var div = document.createElement('div');
    div.className = 'ckpt';
    div.innerHTML = '<span>' + (lbl ? esc(lbl) + ' · ' : '') + 'rev ' + esc(r.ud) +
      '</span><span class="muted">' + esc(when) + '</span>';
    box.appendChild(div);
  });
}

function openDetail(d) {
  var git = d.type === 'git';
  el('detail-name').textContent = d.name;
  var origin = git ? ((d.repo || '?') + ' @ ' + (d.ref || 'main')) : (d.source || '?');
  el('detail-meta').innerHTML =
    '<div class="entry-repo">' + esc(origin) + '</div>' +
    '<div class="entry-ver">' + (git ? 'git' : 'cross-ship') + ' · version <b>' +
      esc(d.version) + '</b>' + (d.public ? ' · public' : '') + '</div>';
  var acts = '<button class="verb" data-act="config">configure</button>';
  if (git) {
    acts += '<button class="verb" data-act="sync">sync</button>';
    acts += '<button class="verb" data-act="push">push</button>';
  }
  acts += '<button class="verb danger" data-act="delete">delete</button>';
  el('detail-actions').innerHTML = acts;
  Array.prototype.forEach.call(el('detail-actions').querySelectorAll('[data-act]'), function(b) {
    var a = b.getAttribute('data-act');
    b.onclick = function() {
      if (a === 'config') { closeDetail(); openEdit(d); }
      else if (a === 'sync') doSync(d.name);
      else if (a === 'push') { closeDetail(); openPush(d); }
      else if (a === 'delete') doDelete(d);
    };
  });
  el('detail-code').innerHTML = '<div class="muted">loading…</div>';
  el('detail-data').innerHTML = '<div class="muted">loading…</div>';
  el('detail-back').classList.add('open');
  post('detail', { app: d.name }).then(function(r) {
    var s = {};
    try { s = JSON.parse(r.text); } catch (e) {}
    renderCkpts(el('detail-code'), s.code);
    renderCkpts(el('detail-data'), s.data);
  });
}

function closeDetail() { el('detail-back').classList.remove('open'); }

function doDelete(d) {
  if (!confirm('Delete "' + d.name + '"? This removes the whole desk from /apps on this ship. It stays on GitHub.')) return;
  post('delete', { app: d.name }).then(function() { closeDetail(); setTimeout(load, 400); });
}

function load() {
  el('loader').classList.add('on');
  return fetch('/grubbery/desks/list')
    .then(function(r) { return r.json(); })
    .then(render)
    .catch(function() { render([]); })
    .finally(function() { el('loader').classList.remove('on'); });
}

function render(desks) {
  var box = el('entries');
  box.innerHTML = '';
  if (!desks || !desks.length) {
    box.innerHTML = '<div class="empty">no desks yet — add one</div>';
    return;
  }
  desks.sort(function(a, b) { return a.name.localeCompare(b.name); });
  desks.forEach(function(d) {
    var git = d.type === 'git';
    var origin = git
      ? esc(d.repo || '?') + ' @ ' + esc(d.ref || 'main')
      : esc(d.source || '?');
    var card = document.createElement('div');
    card.className = 'entry';
    var acts = '<button class="verb" data-act="config" title="' + esc(HELP.config) + '">configure</button>';
    if (git) {
      acts += '<button class="verb" data-act="sync" title="' + esc(HELP.sync) + '">sync</button>';
      acts += '<button class="verb" data-act="push" title="' + esc(HELP.push) + '">push</button>';
    }
    card.innerHTML =
      '<div class="entry-main">' +
        '<div class="entry-top">' +
          '<span class="entry-name">' + esc(d.name) + '</span>' +
          '<span class="src-tag ' + (git ? 'git' : 'ship') + '">' +
            (git ? 'git' : 'cross-ship') + '</span>' +
          (d.public ? '<span class="badge src">public</span>' : '') +
        '</div>' +
        '<div class="entry-repo">' + origin + '</div>' +
        '<div class="entry-ver">version <b>' + esc(d.version) + '</b></div>' +
      '</div>' +
      '<div class="entry-actions">' + acts + '</div>';
    Array.prototype.forEach.call(card.querySelectorAll('[data-act]'), function(b) {
      var a = b.getAttribute('data-act');
      b.onclick = function(e) {
        e.stopPropagation();  // don't also open the detail modal
        if (a === 'config') openEdit(d);
        else if (a === 'sync') doSync(d.name);
        else if (a === 'push') openPush(d);
      };
    });
    card.style.cursor = 'pointer';
    card.onclick = function() { openDetail(d); };
    box.appendChild(card);
  });
}

el('new-desk').onclick = openAdd;
el('m-cancel').onclick = closeModal;
el('m-save').onclick = save;
el('src-git').onclick = function() { setMode('git'); };
el('src-ship').onclick = function() { setMode('ship'); };
el('push-cancel').onclick = closePush;
el('push-go').onclick = doPush;
el('detail-close').onclick = closeDetail;
load();
