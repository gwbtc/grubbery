// contacts: the shell's people record, read and written through the
// kernel's namespace api. profiles/<ship>.json is what a ship publishes,
// overlays/<ship>.json is yours. A poke to main.sig writes; a peek reads.

var API = '/grubbery/api';
var BALL = 'apps/shell/contacts';
var me = '';
var people = {};   // ship (no sig) -> {profile, overlay}

function status(t) { document.getElementById('status').textContent = t || ''; }

function peek(path) {
  return fetch(API + '/peek/' + BALL + '/' + path).then(function(r) {
    if (!r.ok) return null;
    return r.json();
  }).catch(function() { return null; });
}

function poke(body) {
  return fetch(API + '/poke/' + BALL + '/main.sig?blot=/json', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  }).then(function(r) { return r.ok; });
}

function listing(dir) {
  return peek(dir + '/').then(function(d) {
    return ((d && d.files) || []).filter(function(f) { return /\.json$/.test(f); })
      .map(function(f) { return f.replace(/\.json$/, ''); });
  });
}

function load() {
  status('loading');
  return fetch('/~/host').then(function(r) { return r.text(); }).then(function(h) {
    me = h.trim().replace(/^~/, '');
    document.getElementById('me-ship').textContent = '~' + me;
    return Promise.all([listing('profiles'), listing('overlays')]);
  }).then(function(ls) {
    var ships = {};
    ls[0].forEach(function(s) { ships[s] = true; });
    ls[1].forEach(function(s) { ships[s] = true; });
    var names = Object.keys(ships);
    return Promise.all(names.map(function(s) {
      return Promise.all([peek('profiles/' + s + '.json'), peek('overlays/' + s + '.json')])
        .then(function(pv) { return [s, { profile: pv[0] || {}, overlay: pv[1] || {} }]; });
    }));
  }).then(function(rows) {
    people = {};
    rows.forEach(function(r) { people[r[0]] = r[1]; });
    render();
    status('');
  }).catch(function() { status('could not load'); });
}

// after a poke the writer has to land; read back a moment later
function reload() { setTimeout(load, 400); }

function esc(s) {
  var d = document.createElement('div');
  d.textContent = s == null ? '' : String(s);
  return d.innerHTML;
}

// a form of key/value fields over an object, with a row to add a key
function fieldForm(form, obj, onSave, saveLabel) {
  form.innerHTML = '';
  var keys = Object.keys(obj);
  keys.forEach(function(k) {
    var l = document.createElement('label'); l.textContent = k; form.appendChild(l);
    var i = document.createElement('input'); i.name = k;
    i.value = Array.isArray(obj[k]) ? obj[k].join(', ') : (obj[k] == null ? '' : String(obj[k]));
    form.appendChild(i);
  });
  var nk = document.createElement('div'); nk.className = 'newkey';
  nk.innerHTML = '<input placeholder="field" name="__k"><input placeholder="value" name="__v">';
  form.appendChild(nk);
  var act = document.createElement('div'); act.className = 'actions';
  var save = document.createElement('button'); save.type = 'submit'; save.className = 'primary';
  save.textContent = saveLabel; act.appendChild(save);
  form.appendChild(act);
  form.onsubmit = function(e) {
    e.preventDefault();
    var out = {};
    keys.forEach(function(k) {
      var v = form.elements[k].value;
      if (v === '') return;
      out[k] = (k === 'labels') ? v.split(',').map(function(x) { return x.trim(); }).filter(Boolean) : v;
    });
    var k = form.elements['__k'].value.trim(), v = form.elements['__v'].value;
    if (k) out[k] = (k === 'labels') ? v.split(',').map(function(x) { return x.trim(); }).filter(Boolean) : v;
    onSave(out);
  };
}

function render() {
  var mine = people[me] || { profile: {}, overlay: {} };
  var prof = Object.assign({ name: '' }, mine.profile);
  fieldForm(document.getElementById('me-form'), prof, function(out) {
    status('saving');
    poke({ action: 'profile', profile: out }).then(reload);
  }, 'Publish');

  var el = document.getElementById('people');
  el.innerHTML = '';
  var names = Object.keys(people).filter(function(s) { return s !== me; }).sort(function(a, b) {
    var an = (people[a].overlay.name || people[a].profile.name || a).toLowerCase();
    var bn = (people[b].overlay.name || people[b].profile.name || b).toLowerCase();
    return an < bn ? -1 : an > bn ? 1 : 0;
  });
  if (!names.length) {
    el.innerHTML = '<div class="empty">nobody yet. add a ship above.</div>';
    return;
  }
  names.forEach(function(s) {
    var p = people[s];
    var name = p.overlay.name || p.profile.name || '~' + s;
    var card = document.createElement('div'); card.className = 'person';
    var row = document.createElement('div'); row.className = 'person-row';
    row.innerHTML =
      '<span class="person-name">' + esc(name) + '</span>' +
      '<span class="person-ship">~' + esc(s) + '</span>' +
      '<span class="person-labels">' +
        (p.overlay.labels || []).map(function(l) { return '<span class="label">' + esc(l) + '</span>'; }).join('') +
      '</span>';
    row.onclick = function() { card.classList.toggle('open'); };
    card.appendChild(row);
    var body = document.createElement('div'); body.className = 'person-body';
    var pk = Object.keys(p.profile);
    body.innerHTML = '<h3>their profile</h3>' +
      (pk.length
        ? '<div class="profile-kv">' + pk.map(function(k) {
            return '<span class="k">' + esc(k) + '</span><span>' + esc(p.profile[k]) + '</span>';
          }).join('') + '</div>'
        : '<div class="muted">nothing published yet</div>') +
      '<h3>your overlay</h3>';
    var f = document.createElement('form'); f.className = 'fields';
    fieldForm(f, Object.assign({ name: '', labels: [] }, p.overlay), function(out) {
      status('saving');
      poke({ action: 'set', ship: '~' + s, overlay: out }).then(reload);
    }, 'Save');
    var del = document.createElement('button'); del.type = 'button'; del.className = 'danger';
    del.textContent = 'Remove'; del.onclick = function() {
      status('removing');
      poke({ action: 'del', ship: '~' + s }).then(reload);
    };
    f.querySelector('.actions').appendChild(del);
    body.appendChild(f);
    card.appendChild(body);
    el.appendChild(card);
  });
}

document.getElementById('sync-ames').onclick = function() {
  status('importing peers');
  poke({ action: 'sync-ames' }).then(function(ok) { status(ok ? '' : 'refused'); reload(); });
};

document.getElementById('add-form').onsubmit = function(e) {
  e.preventDefault();
  var ship = document.getElementById('add-ship').value.trim();
  if (!ship) return;
  if (ship[0] !== '~') ship = '~' + ship;
  status('adding');
  poke({ action: 'set', ship: ship, overlay: {} }).then(function(ok) {
    if (!ok) { status('refused'); return; }
    document.getElementById('add-ship').value = '';
    reload();
  });
};

load();
