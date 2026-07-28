// desks: the manager surface. Reads entry config/state grubs via
// the ball; the verbs are pokes to main.sig.

var API = '/grubbery/api';
var BALL = 'apps/desks.desks';

function el(id) { return document.getElementById(id); }

function esc(s) {
  var d = document.createElement('div');
  d.textContent = s == null ? '' : String(s);
  return d.innerHTML;
}

function poke(body, cb) {
  fetch(API + '/poke/' + BALL + '/main.sig?blot=/json', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  }).then(function() { setTimeout(cb || load, 600); });
}

function grub(rel) {
  return fetch('/grubbery/ball/' + BALL + '/' + rel + '?blot=/json')
    .then(function(r) { return r.ok ? r.json() : null; })
    .catch(function() { return null; });
}

function load() {
  el('loader').classList.add('on');
  return fetch(API + '/tree/' + BALL + '/entries')
    .then(function(r) { return r.json(); })
    .then(function(t) {
      var names = Object.keys((t && t.dirs) || {});
      return Promise.all(names.map(function(n) {
        return Promise.all([
          grub('entries/' + n + '/config.json'),
          grub('entries/' + n + '/state.json')
        ]).then(function(pair) {
          return { name: n, config: pair[0] || {}, state: pair[1] || {} };
        });
      }));
    })
    .then(render)
    .catch(function() { render([]); })
    .finally(function() { el('loader').classList.remove('on'); });
}

function verbBtn(label, name, action, cls) {
  var b = document.createElement('button');
  b.className = 'verb' + (cls ? ' ' + cls : '');
  b.textContent = label;
  b.onclick = function() { poke({ action: action, name: name }); };
  return b;
}

function render(entries) {
  var box = el('entries');
  box.innerHTML = '';
  if (!entries.length) {
    box.innerHTML = '<div class="empty">no desks yet — add one</div>';
    return;
  }
  entries.sort(function(a, b) { return a.name.localeCompare(b.name); });
  entries.forEach(function(e) {
    var c = e.config, s = e.state;
    var synced = s.synced, deployed = s.deployed;
    var drift = (synced != null && deployed != null && synced !== deployed);
    var card = document.createElement('div');
    card.className = 'entry';
    card.innerHTML =
      '<div class="entry-main">' +
        '<div class="entry-top">' +
          '<span class="entry-name">' + esc(e.name) + '</span>' +
          (c.poll ? '<span class="badge sink">sink ' + esc(c.poll) + 'm</span>'
                  : '<span class="badge src">source</span>') +
        '</div>' +
        '<div class="entry-repo">' + esc(c.repo || '?') + ' @ ' + esc(c.ref || 'main') +
          ' → ' + esc(c.app || '?') + '</div>' +
        '<div class="entry-ver">' +
          'synced <b>' + (synced == null ? '—' : esc(synced)) + '</b>' +
          '<span class="arrow">' + (drift ? '⟩' : '=') + '</span>' +
          'deployed <b>' + (deployed == null ? '—' : esc(deployed)) + '</b>' +
          (drift ? '<span class="drift">update staged</span>' : '') +
        '</div>' +
      '</div>' +
      '<div class="entry-actions"></div>';
    var acts = card.querySelector('.entry-actions');
    acts.appendChild(verbBtn('sync', e.name, 'sync'));
    acts.appendChild(verbBtn('deploy', e.name, 'deploy', drift ? 'hot' : ''));
    acts.appendChild(verbBtn('push', e.name, 'push'));
    box.appendChild(card);
  });
}

el('new-entry').onclick = function() {
  el('m-name').value = '';
  el('m-repo').value = '';
  el('m-ref').value = 'main';
  el('m-app').value = '';
  el('modal-back').classList.add('open');
  el('m-name').focus();
};

el('m-cancel').onclick = function() { el('modal-back').classList.remove('open'); };
el('modal-back').onclick = function(e) {
  if (e.target === el('modal-back')) el('modal-back').classList.remove('open');
};

el('m-save').onclick = function() {
  var name = el('m-name').value.trim();
  var repo = el('m-repo').value.trim();
  var app = el('m-app').value.trim();
  if (!name || !repo || !app) return;
  poke({
    action: 'install',
    name: name,
    repo: repo,
    ref: el('m-ref').value.trim() || 'main',
    app: app
  });
  el('modal-back').classList.remove('open');
};

load();
