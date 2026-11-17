// contacts: the shell's people record, read and written through the
// kernel's namespace api. A poke to main.sig writes; a peek reads.
//
// Both sides are facets. share/<group>/profile.json is what we publish to
// one usergroup; profiles/<ship>/<group>/profile.json is what one of
// THEIR groups told us, kept apart so the page can show where two of
// their groups disagree. The union is a view the ship computes.
//
// Your own profile is published per usergroup: share/<group>/profile.json
// is a facet, and the group's weir is what lets that group read it. The
// facets come from the page's own endpoint, which walks the tree.

var API = '/grubbery/api';
var BALL = 'apps/shell/contacts';
var me = '';
var people = {};   // ship (no sig) -> {profile, overlay}
var facets = {};   // group path -> the profile published to it
var groups = [];   // this ship's usergroups, for the facet picker

function status(t) { document.getElementById('status').textContent = t || ''; }

function poke(body) {
  return fetch(API + '/poke/' + BALL + '/main.sig?blot=/json', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  }).then(function(r) { return r.ok; });
}

function json(url) {
  return fetch(url).then(function(r) { return r.ok ? r.json() : null; })
    .catch(function() { return null; });
}

function load() {
  status('loading');
  return fetch('/~/host').then(function(r) { return r.text(); }).then(function(h) {
    me = h.trim().replace(/^~/, '');
    document.getElementById('me-ship').textContent = '~' + me;
    return Promise.all([
      json('/grubbery/contacts/api/facets'),
      json('/apps/grubbery/groups.json')
    ]);
  }).then(function(fg) {
    facets = fg[0] || {};
    groups = fg[1] || [];
    var dl = document.getElementById('group-list');
    dl.innerHTML = '';
    groups.forEach(function(g) {
      var o = document.createElement('option'); o.value = g; dl.appendChild(o);
    });
    // what each ship told each of ITS groups, kept apart, plus our overlays
    return Promise.all([
      json('/grubbery/contacts/api/peers'),
      json('/grubbery/contacts/api/overlays')
    ]);
  }).then(function(po) {
    var peers = po[0] || {}, overs = po[1] || {};
    people = {};
    Object.keys(peers).forEach(function(k) {
      var s = k.replace(/^~/, '');
      people[s] = { profile: peers[k].profile || {}, facets: peers[k].facets || {},
                    clashes: peers[k].clashes || {}, overlay: {} };
    });
    Object.keys(overs).forEach(function(k) {
      var s = k.replace(/^~/, '');
      if (!people[s]) people[s] = { profile: {}, facets: {}, clashes: {} };
      people[s].overlay = overs[k] || {};
    });
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
  // a field that came in as a list goes back out as one; 'labels' is a
  // list even when it is empty and has no shape of its own yet
  function val(k, v) {
    if (k !== 'labels' && !Array.isArray(obj[k])) return v;
    return v.split(',').map(function(x) { return x.trim(); }).filter(Boolean);
  }
  form.onsubmit = function(e) {
    e.preventDefault();
    var out = {};
    keys.forEach(function(k) {
      var v = form.elements[k].value;
      if (v === '') return;
      out[k] = val(k, v);
    });
    var k = form.elements['__k'].value.trim(), v = form.elements['__v'].value;
    if (k) out[k] = val(k, v);
    onSave(out);
  };
}

function renderFacets() {
  var el = document.getElementById('facets');
  el.innerHTML = '';
  var names = Object.keys(facets).sort();
  if (!names.length) {
    el.innerHTML = '<div class="empty">no facets yet. name a group above to publish one.</div>';
    return;
  }
  names.forEach(function(g) {
    var card = document.createElement('div'); card.className = 'facet';
    var head = document.createElement('div'); head.className = 'facet-head';
    head.innerHTML = '<span class="facet-group">' + esc(g) + '</span>' +
      '<span class="muted">' + (g === '/public' ? 'every ship' : 'the ships in this group') + '</span>';
    card.appendChild(head);
    var f = document.createElement('form'); f.className = 'fields';
    fieldForm(f, Object.assign({ name: '' }, facets[g]), function(out) {
      status('saving');
      poke({ action: 'facet', group: g, profile: out }).then(reload);
    }, 'Save');
    var del = document.createElement('button'); del.type = 'button'; del.className = 'danger';
    del.textContent = 'Unpublish'; del.onclick = function() {
      status('unpublishing');
      poke({ action: 'facet', group: g, remove: true }).then(reload);
    };
    f.querySelector('.actions').appendChild(del);
    card.appendChild(f);
    el.appendChild(card);
  });
}

function render() {
  renderFacets();

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
    var groups = Object.keys(p.facets || {}).sort();
    var clashes = p.clashes || {};
    var pk = Object.keys(p.profile);
    body.innerHTML = '<h3>their profile</h3>' +
      (pk.length
        ? '<div class="profile-kv">' + pk.map(function(k) {
            return '<span class="k' + (clashes[k] ? ' clash' : '') + '">' + esc(k) + '</span>' +
              '<span>' + esc(p.profile[k]) + '</span>';
          }).join('') + '</div>'
        : '<div class="muted">nothing read yet</div>') +
      // the whole point of keeping the facets apart: two of their groups
      // told us different things about the same key
      (Object.keys(clashes).length
        ? '<div class="clashes"><b>they do not say the same thing to everyone</b>' +
          Object.keys(clashes).sort().map(function(k) {
            return '<div class="clash-row"><span class="k clash">' + esc(k) + '</span>' +
              Object.keys(clashes[k]).sort().map(function(g) {
                return '<span class="clash-v"><span class="me-group">' + esc(g) + '</span> ' +
                  esc(clashes[k][g]) + '</span>';
              }).join('') + '</div>';
          }).join('') + '</div>'
        : '') +
      (groups.length
        ? '<h3>what each of their groups was told</h3>' +
          groups.map(function(g) {
            var f = p.facets[g] || {};
            return '<div class="their-facet"><span class="me-group">' + esc(g) + '</span>' +
              '<span class="muted">' + Object.keys(f).length + ' fields</span></div>';
          }).join('')
        : '');
    // the groups THEY have you in, as they told you: what +pull asks for
    var pull = document.createElement('form'); pull.className = 'pull';
    var gi = document.createElement('input');
    gi.value = (p.overlay.groups || ['/public']).join(', ');
    gi.placeholder = '/public';
    gi.spellcheck = false;
    var pb = document.createElement('button'); pb.type = 'submit'; pb.textContent = 'Fetch profile';
    pull.appendChild(gi);
    pull.appendChild(pb);
    pull.onsubmit = function(e) {
      e.preventDefault();
      var gs = gi.value.split(',').map(function(x) { return x.trim(); }).filter(Boolean);
      if (!gs.length) gs = ['/public'];
      status('fetching');
      var ov = Object.assign({}, p.overlay, { groups: gs });
      poke({ action: 'set', ship: '~' + s, overlay: ov }).then(function() {
        return poke({ action: 'pull', ship: '~' + s, groups: gs });
      }).then(function(ok) { status(ok ? '' : 'refused'); reload(); });
    };
    body.appendChild(pull);
    var oh = document.createElement('h3'); oh.textContent = 'your overlay';
    body.appendChild(oh);
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

document.getElementById('facet-form').onsubmit = function(e) {
  e.preventDefault();
  var g = document.getElementById('facet-group').value.trim() || '/public';
  if (g[0] !== '/') g = '/' + g;
  if (facets[g]) { status('that group already has a facet'); return; }
  status('publishing to ' + g);
  poke({ action: 'facet', group: g, profile: { name: '' } }).then(function(ok) {
    if (!ok) { status('refused'); return; }
    document.getElementById('facet-group').value = '';
    reload();
  });
};

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
