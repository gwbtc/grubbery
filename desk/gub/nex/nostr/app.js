// nostr nexus UI: a reader over the mirror. Everything on this page is a
// grub — the feed index, the events, the profiles — read through two
// endpoints that do nothing but peek and join.
'use strict';
const $ = (id) => document.getElementById(id);
const BASE = '/grubbery/nostr';
const jget = async (u) => { const r = await fetch(BASE + u); if (!r.ok) throw new Error(await r.text()); return r.json(); };

function fmtAge(unix) {
  if (!unix) return '';
  const s = Math.max(0, Date.now() / 1000 - unix);
  if (s < 60) return 'now';
  if (s < 3600) return Math.round(s / 60) + 'm';
  if (s < 86400) return Math.round(s / 3600) + 'h';
  return Math.round(s / 86400) + 'd';
}
function ago(unix) {
  if (!unix) return 'never synced';
  const s = Math.max(0, Date.now() / 1000 - unix);
  if (s < 90) return 'synced just now';
  if (s < 5400) return 'synced ' + Math.round(s / 60) + 'm ago';
  return 'synced ' + Math.round(s / 3600) + 'h ago';
}

function avatarEl(prof, pubkey) {
  const wrap = document.createElement('span');
  wrap.className = 'avatar';
  let hue = 0;
  for (let i = 0; i < Math.min(8, (pubkey || '').length); i++) hue = (hue * 31 + pubkey.charCodeAt(i)) % 360;
  wrap.style.background = 'hsl(' + hue + ', 32%, 82%)';
  wrap.style.color = 'hsl(' + hue + ', 45%, 30%)';
  wrap.textContent = (prof.name || pubkey || '?').slice(0, 1).toUpperCase();
  if (prof.picture && /^https?:\/\//.test(prof.picture)) {
    const img = document.createElement('img');
    img.loading = 'lazy';
    img.referrerPolicy = 'no-referrer';
    img.src = prof.picture;
    img.onerror = () => img.remove();
    wrap.appendChild(img);
  }
  return wrap;
}

// text with bare URLs turned into links; everything else is text nodes
function renderText(el, text) {
  const re = /https?:\/\/[^\s<>"')\]]+/g;
  let last = 0, m;
  while ((m = re.exec(text))) {
    if (m.index > last) el.appendChild(document.createTextNode(text.slice(last, m.index)));
    const a = document.createElement('a');
    a.href = m[0]; a.target = '_blank'; a.rel = 'noopener';
    let label = m[0].replace(/^https?:\/\/(www\.)?/, '');
    if (label.length > 48) label = label.slice(0, 45) + '…';
    a.textContent = label;
    el.appendChild(a);
    last = m.index + m[0].length;
  }
  if (last < text.length) el.appendChild(document.createTextNode(text.slice(last)));
}

function postEl(p) {
  const prof = p.profile || {};
  const item = document.createElement('div');
  item.className = 'post';
  const head = document.createElement('div');
  head.className = 'post-head';
  head.appendChild(avatarEl(prof, p.pubkey));
  const who = document.createElement('span');
  who.className = 'who' + (prof.name ? '' : ' pk');
  who.textContent = prof.name || (p.pubkey || '').slice(0, 12);
  who.title = p.pubkey || '';
  const age = document.createElement('span');
  age.className = 'age';
  age.textContent = fmtAge(p.created_at);
  age.title = p.created_at ? new Date(p.created_at * 1000).toLocaleString() : '';
  head.append(who, age);
  const content = document.createElement('div');
  content.className = 'content';
  renderText(content, p.content || '');
  const id = document.createElement('div');
  id.className = 'post-id';
  const a = document.createElement('a');
  a.href = '/grubbery/ball/apps/nostr/events/' + encodeURIComponent(p.id) + '.json';
  a.target = '_blank';
  a.textContent = (p.id || '').slice(0, 16) + '…';
  a.title = 'the event grub';
  id.appendChild(a);
  item.append(head, content, id);
  return item;
}

async function loadStatus() {
  try {
    const s = await jget('/api/status');
    $('status').textContent = s.events + ' events · ' + s.profiles + ' profiles · ' + ago(s.at) + ' · every ' + s.interval + 's';
  } catch (e) { $('status').textContent = ''; }
}

async function loadFeed() {
  const box = $('feed');
  let d;
  try { d = await jget('/api/feed?limit=80'); } catch (e) { d = null; }
  box.textContent = '';
  if (!d || !Array.isArray(d.posts)) { box.innerHTML = '<div class="empty">could not read the feed</div>'; return; }
  $('feed-count').textContent = d.count + ' posts';
  if (!d.posts.length) { box.innerHTML = '<div class="empty">Nothing mirrored yet — sync to pull from nostrill.</div>'; return; }
  d.posts.forEach((p) => box.appendChild(postEl(p)));
}

$('sync').onclick = async () => {
  const b = $('sync');
  b.disabled = true; b.textContent = 'Syncing…';
  try { await fetch(BASE + '/api/sync', { method: 'POST' }); } catch (e) {}
  // the pass runs in its own fiber; give it a moment, then re-read
  setTimeout(async () => { await loadStatus(); await loadFeed(); b.disabled = false; b.textContent = 'Sync'; }, 2500);
};

loadStatus();
loadFeed();
setInterval(loadStatus, 60000);
