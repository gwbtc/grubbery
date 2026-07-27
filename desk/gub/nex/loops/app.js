// loops: flat commitments per context. Reads store grubs via the
// ball, mutations poke main.sig. Display rules live here; the
// protocol only stores loops.

var API = '/grubbery/api';
var BALL = 'apps/loops.loops';
var ctx = localStorage.getItem('loops-ctx') || 'urbit';
var store = { open: {}, closed: {} };

function el(id) { return document.getElementById(id); }

function esc(s) {
  var d = document.createElement('div');
  d.textContent = s == null ? '' : String(s);
  return d.innerHTML;
}

function fetchContexts() {
  return fetch(API + '/tree/' + BALL + '/store')
    .then(function(r) { return r.json(); })
    .then(function(t) {
      var names = Object.keys((t && t.files) || {})
        .filter(function(n) { return n.slice(-11) === '.open-loops'; })
        .map(function(n) { return n.slice(0, -11); });
      if (!names.length) names = ['urbit'];
      if (names.indexOf(ctx) < 0) ctx = names[0];
      var sel = el('ctx-select');
      sel.innerHTML = '';
      names.sort().forEach(function(n) {
        var o = document.createElement('option');
        o.value = n; o.textContent = n;
        if (n === ctx) o.selected = true;
        sel.appendChild(o);
      });
    })
    .catch(function() {});
}

function fetchStore() {
  el('loader').classList.add('on');
  return fetch('/grubbery/ball/' + BALL + '/store/' + ctx + '.open-loops?blot=/json')
    .then(function(r) { if (!r.ok) throw 0; return r.json(); })
    .then(function(s) { store = s || { open: {}, closed: {} }; })
    .catch(function() { store = { open: {}, closed: {} }; })
    .finally(function() {
      el('loader').classList.remove('on');
      render();
    });
}

function poke(body, cb) {
  body.context = ctx;
  fetch(API + '/poke/' + BALL + '/main.sig?blot=/json', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  }).then(function() { setTimeout(cb || fetchStore, 450); });
}

function daysUntil(dstr) {
  if (!dstr) return null;
  var d = new Date(dstr + 'T00:00:00');
  return Math.ceil((d - new Date()) / 86400000);
}

function loopCard(id, lp, closed) {
  var card = document.createElement('div');
  card.className = 'loop' + (closed ? ' closed' : '');
  var days = daysUntil(lp.best_by);
  var badge = '';
  if (days !== null && !closed) {
    if (days < 0) badge = '<span class="badge overdue">overdue</span>';
    else if (days === 0) badge = '<span class="badge soon">today</span>';
    else if (days <= 3) badge = '<span class="badge soon">' + days + 'd</span>';
    else badge = '<span class="badge">' + esc(lp.best_by) + '</span>';
  }
  var chips = (lp.labels || []).sort().map(function(l) {
    return '<span class="chip">' + esc(l) + '</span>';
  }).join('');
  card.innerHTML =
    '<div class="loop-main">' +
      '<div class="loop-text">' + esc(lp.text) + '</div>' +
      '<div class="loop-meta">' + chips + badge + '</div>' +
    '</div>' +
    '<div class="loop-actions"></div>';
  var acts = card.querySelector('.loop-actions');
  var b = document.createElement('button');
  b.className = 'hdr-btn';
  b.textContent = closed ? 'reopen' : 'close';
  b.onclick = function() { poke({ action: closed ? 'reopen' : 'close', id: Number(id) }); };
  acts.appendChild(b);
  if (closed) {
    var del = document.createElement('button');
    del.className = 'del-btn';
    del.textContent = '✕';
    del.title = 'Delete forever';
    del.onclick = function() { poke({ action: 'delete', id: Number(id) }); };
    acts.appendChild(del);
  }
  return card;
}

function sortIds(m) {
  return Object.keys(m).sort(function(a, b) {
    var la = m[a], lb = m[b];
    var da = daysUntil(la.best_by), db = daysUntil(lb.best_by);
    var ka = da === null ? 1e9 : da, kb = db === null ? 1e9 : db;
    if (ka !== kb) return ka - kb;
    return (lb.updated || '').localeCompare(la.updated || '');
  });
}

function render() {
  var list = el('list');
  list.innerHTML = '';
  var ids = sortIds(store.open || {});
  if (!ids.length) {
    list.innerHTML = '<div class="empty">nothing dangling — a closed circuit</div>';
  }
  ids.forEach(function(id) { list.appendChild(loopCard(id, store.open[id], false)); });
  var cl = el('closed-list');
  cl.innerHTML = '';
  var cids = Object.keys(store.closed || {}).sort(function(a, b) { return b - a; });
  el('closed-toggle').style.display = cids.length ? '' : 'none';
  cids.forEach(function(id) { cl.appendChild(loopCard(id, store.closed[id], true)); });
}

el('ctx-select').onchange = function() {
  ctx = this.value;
  localStorage.setItem('loops-ctx', ctx);
  fetchStore();
};

el('new-ctx').onclick = function() {
  var n = prompt('new context name (short, no spaces):');
  if (!n) return;
  n = n.trim().toLowerCase().replace(/[^a-z0-9-]/g, '-');
  if (!n) return;
  ctx = n;
  localStorage.setItem('loops-ctx', ctx);
  var sel = el('ctx-select');
  var o = document.createElement('option');
  o.value = n; o.textContent = n; o.selected = true;
  sel.appendChild(o);
  fetchStore();
};

el('new-loop').onclick = function() {
  el('m-text').value = '';
  el('m-labels').value = '';
  el('m-date').value = '';
  el('modal-back').classList.add('open');
  el('m-text').focus();
};

el('m-cancel').onclick = function() { el('modal-back').classList.remove('open'); };
el('modal-back').onclick = function(e) {
  if (e.target === el('modal-back')) el('modal-back').classList.remove('open');
};

el('m-save').onclick = function() {
  var text = el('m-text').value.trim();
  if (!text) return;
  var labels = el('m-labels').value.split(',')
    .map(function(s) { return s.trim(); })
    .filter(function(s) { return s.length; });
  poke({
    action: 'open',
    text: text,
    labels: labels,
    best_by: el('m-date').value || ''
  });
  el('modal-back').classList.remove('open');
};

el('closed-toggle').onclick = function() {
  var cl = el('closed-list');
  var showing = cl.style.display !== 'none';
  cl.style.display = showing ? 'none' : '';
  this.textContent = showing ? 'show closed' : 'hide closed';
};

fetchContexts().then(fetchStore);
