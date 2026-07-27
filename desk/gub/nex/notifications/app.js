// inbox: the notification service's human-facing surface.
// Un-acked notifications are loud; acked ones recede. Display
// decisions live here — the protocol only records mack.

var API = '/grubbery/api';
var BALL = 'apps/notifications.notifications';
var notes = [];

function fetchInbox() {
  var ld = document.getElementById('loader');
  ld.classList.add('on');
  return fetch('/grubbery/ball/' + BALL + '/inbox.inbox?blot=/json')
    .then(function(r) { return r.json(); })
    .then(function(ns) { notes = ns || []; render(); })
    .catch(function() {})
    .finally(function() { ld.classList.remove('on'); });
}

function poke(body, cb) {
  fetch(API + '/poke/' + BALL + '/main.sig?blot=/json', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  }).then(function(r) { if (cb) cb(r.ok); });
}

function esc(s) {
  var d = document.createElement('div');
  d.textContent = s == null ? '' : String(s);
  return d.innerHTML;
}

function ago(ms) {
  var s = Math.floor((Date.now() - ms) / 1000);
  if (s < 60) return 'now';
  if (s < 3600) return Math.floor(s / 60) + 'm';
  if (s < 86400) return Math.floor(s / 3600) + 'h';
  return Math.floor(s / 86400) + 'd';
}

function render() {
  var el = document.getElementById('notes');
  el.innerHTML = '';
  var sorted = notes.slice().sort(function(a, b) {
    return (b.created_ms || 0) - (a.created_ms || 0);
  });
  if (!sorted.length) {
    el.innerHTML = '<div class="empty">nothing here — a quiet ship</div>';
    return;
  }
  sorted.forEach(function(n) {
    var md = n.metadata || {};
    var acked = n.mack != null;
    var card = document.createElement('div');
    card.className = 'note' + (acked ? ' acked' : '');
    card.innerHTML =
      '<div class="note-main">' +
        '<div class="note-top">' +
          (acked ? '' : '<span class="dot on"></span>') +
          '<span class="note-app">' + esc(n.app) + '</span>' +
          '<span class="note-time">' + ago(n.created_ms) + '</span>' +
        '</div>' +
        '<div class="note-title">' + esc(md.title || '(untitled)') + '</div>' +
        (md.body ? '<div class="note-body">' + esc(md.body) + '</div>' : '') +
      '</div>' +
      '<div class="note-actions"></div>';
    if (!acked) {
      var b = document.createElement('button');
      b.className = 'hdr-btn';
      b.textContent = 'Mark as read';
      b.onclick = function(e) { e.stopPropagation(); ack(n.id); };
      card.querySelector('.note-actions').appendChild(b);
    }
    var t = document.createElement('button');
    t.className = 'note-del';
    t.textContent = '✕';
    t.title = 'Delete';
    t.onclick = function(e) { e.stopPropagation(); clearNote(n.id); };
    card.querySelector('.note-actions').appendChild(t);
    if (md.url || !acked) {
      card.style.cursor = 'pointer';
      card.onclick = function() {
        if (!acked) ack(n.id);
        if (md.url) window.open(md.url, '_blank');
      };
    }
    el.appendChild(card);
  });
}

function ack(id) {
  poke({ action: 'ack', id: id }, function() { setTimeout(fetchInbox, 400); });
}

function clearNote(id) {
  poke({ action: 'clear', id: id }, function() { setTimeout(fetchInbox, 400); });
}

document.getElementById('ack-all').onclick = function() {
  var un = notes.filter(function(n) { return n.mack == null; });
  var left = un.length;
  if (!left) return;
  un.forEach(function(n) {
    poke({ action: 'ack', id: n.id }, function() {
      if (--left <= 0) setTimeout(fetchInbox, 400);
    });
  });
};

fetchInbox();
