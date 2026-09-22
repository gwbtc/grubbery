// nostr nexus UI: a reader over the mirror. Everything on this page is a
// grub — the feed index, the events, the profiles — read through two
// endpoints that do nothing but peek and join.
'use strict';
const $ = (id) => document.getElementById(id);
const BASE = '/grubbery/nostr';
const jget = async (u) => { const r = await fetch(BASE + u); if (!r.ok) throw new Error(await r.text()); return r.json(); };

// a spinner in place of content while a request is in flight. Every
// loader calls this first, so a slow ship shows as "waiting", not as
// stale or empty content.
function spinner(label) {
  const el = document.createElement('div');
  el.className = 'loading';
  const s = document.createElement('span'); s.className = 'spinner';
  el.append(s, document.createTextNode(label || 'loading…'));
  return el;
}
function busy(el, label) { el.textContent = ''; el.appendChild(spinner(label)); }
function spinBtn(b, on) { b.disabled = on; b.classList.toggle('busy', on); }

function fmtAge(unix) {
  if (!unix) return '';
  const s = Math.max(0, Date.now() / 1000 - unix);
  if (s < 60) return 'now';
  if (s < 3600) return Math.round(s / 60) + 'm';
  if (s < 86400) return Math.round(s / 3600) + 'h';
  return Math.round(s / 86400) + 'd';
}
function ago(unix) {
  if (!unix) return 'no index yet';
  const s = Math.max(0, Date.now() / 1000 - unix);
  if (s < 90) return 'indexed just now';
  if (s < 5400) return 'indexed ' + Math.round(s / 60) + 'm ago';
  return 'indexed ' + Math.round(s / 3600) + 'h ago';
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

function relayChip(r) {
  const el = document.createElement('span');
  el.className = 'relay ' + (r.stage || '');
  el.textContent = r.host;
  el.title = r.host + ': ' + r.stage + (r.error ? ' — ' + r.error : '') +
    (r.eose_at ? ' · ' + r.events + ' events, ' + r.profiles + ' profiles this session' : '') +
    (r.tries ? ' · ' + r.tries + ' failed attempts' : '');
  return el;
}

async function loadStatus() {
  const st = $('status');
  if (!st.textContent) busy(st, 'reading status…');
  try {
    const s = await jget('/api/status');
    $('status').textContent = s.events + ' events · ' + s.profiles + ' profiles · ' + ago(s.at);
    const box = $('relays');
    box.textContent = '';
    (s.relays || []).forEach((r) => box.appendChild(relayChip(r)));
  } catch (e) { $('status').textContent = ''; }
}

async function loadFeed() {
  const box = $('feed');
  busy(box, 'reading the feed…');
  let d;
  try { d = await jget('/api/feed?limit=80'); } catch (e) { d = null; }
  box.textContent = '';
  if (!d || !Array.isArray(d.posts)) { box.innerHTML = '<div class="empty">could not read the feed</div>'; return; }
  $('feed-count').textContent = d.count + ' posts';
  if (!d.posts.length) { box.innerHTML = '<div class="empty">Nothing yet — the relay clients fill this in as events arrive.</div>'; return; }
  d.posts.forEach((p) => box.appendChild(postEl(p)));
}

// ---- people: follows joined with profiles ----
async function loadPeople() {
  const box = $('people');
  busy(box, 'reading follows and profiles…');
  let d;
  try { d = await jget('/api/people'); } catch (e) { d = null; }
  box.textContent = '';
  if (!d) { box.innerHTML = '<div class="empty">could not read follows</div>'; return; }
  $('people-count').textContent = d.count + ' followed';
  $('follows-note').textContent = d.is_default
    ? 'This is the starting list from defaults.json: ' + d.default_count + ' well-known accounts (nostrill\'s defaults), not people you chose. Follow or unfollow to make it yours.'
    : 'Your own list (follows.json). defaults.json has ' + d.default_count + '.';
  if (!d.people.length) { box.innerHTML = '<div class="empty">Following nobody. Add a pubkey above.</div>'; return; }
  d.people.forEach((p) => {
    const row = document.createElement('div');
    row.className = 'person';
    row.appendChild(avatarEl(p, p.pubkey));
    const body = document.createElement('div');
    body.className = 'person-body';
    const name = document.createElement('div');
    name.className = 'who' + (p.name ? '' : ' pk');
    name.textContent = p.name || p.display_name || p.pubkey.slice(0, 16) + '…';
    if (p.nip05) { const n = document.createElement('span'); n.className = 'nip05'; n.textContent = p.nip05; name.appendChild(n); }
    const about = document.createElement('div');
    about.className = 'about';
    about.textContent = p.known ? (p.about || '') : 'no profile received yet';
    const keys = document.createElement('div');
    keys.className = 'keys mono';
    keys.textContent = p.npub || p.pubkey;
    keys.title = p.pubkey;
    body.append(name, about, keys);
    const un = document.createElement('button');
    un.className = 'small';
    un.textContent = 'Unfollow';
    un.onclick = async () => {
      un.disabled = true;
      await fetch(BASE + '/api/follows', { method: 'POST', body: JSON.stringify({ pubkey: p.pubkey, action: 'remove' }) });
      loadPeople();
    };
    row.append(body, un);
    box.appendChild(row);
  });
}

$('follows-reset').onclick = async () => {
  if (!confirm('Replace follows.json with the default list?')) return;
  await fetch(BASE + '/api/follows', { method: 'POST', body: JSON.stringify({ action: 'reset' }) });
  loadPeople();
};

$('follow-form').onsubmit = async (e) => {
  e.preventDefault();
  const pk = $('follow-pk').value.trim().toLowerCase();
  if (!/^[0-9a-f]{64}$/.test(pk)) { alert('a pubkey is 64 hex characters (npub not accepted here yet)'); return; }
  await fetch(BASE + '/api/follows', { method: 'POST', body: JSON.stringify({ pubkey: pk, action: 'add' }) });
  $('follow-pk').value = '';
  loadPeople();
};

// ---- relays: one card per client, from relays/<host>.json ----
function fmtUnix(u) { return u ? new Date(u * 1000).toLocaleString() : '—'; }

let relayData = null;       // last /api/relays payload
let openRelay = null;       // host shown in the modal, if any

function relayCmd(host, action, text) {
  const note = $('relay-modal-body').querySelector('.cmd-note');
  const label = { start: 'connecting', stop: 'disconnecting', reconnect: 'reconnecting', raw: 'sending' }[action] || action;
  if (note) { note.textContent = ''; note.appendChild(spinner(label + '…')); }
  return fetch(BASE + '/api/relays/cmd', { method: 'POST', body: JSON.stringify({ host, action, text: text || '' }) })
    .then(() => new Promise((res) => setTimeout(res, 1200)))
    .then(() => Promise.all([loadRelays(), loadStatus()]))
    .then(() => { const n = $('relay-modal-body').querySelector('.cmd-note'); if (n) n.textContent = ''; });
}

function relayFor(url) {
  const host = url.replace(/^wss?:\/\//, '').replace(/\/$/, '');
  const byHost = {};
  ((relayData && relayData.relays) || []).forEach((r) => { byHost[r.host] = r; });
  return { host, r: byHost[host] || { host, stage: 'stopped' }, known: !!byHost[host] };
}

async function loadRelays() {
  const box = $('relay-list');
  if (!box.children.length || box.querySelector('.empty')) busy(box, 'reading relay clients…');
  try { relayData = await jget('/api/relays'); } catch (e) { relayData = null; }
  box.textContent = '';
  if (!relayData) { box.innerHTML = '<div class="empty">could not read relays</div>'; return; }
  const d = relayData;
  $('relays-note').textContent = d.is_default
    ? 'The starting relays from defaults.json. Any public relay works; more relays means more of your follows\' posts reach you. Click a relay for its socket, its state, and a raw line into it.'
    : 'Your own relay set (config.json). Defaults: ' + (d.defaults || []).join(', ') + '. Click a relay for detail.';
  if (!d.configured || !d.configured.length) { box.innerHTML = '<div class="empty">No relays configured. Add one above.</div>'; return; }
  d.configured.forEach((url) => {
    const { host, r } = relayFor(url);
    const row = document.createElement('div');
    row.className = 'relay-row';
    row.appendChild(relayChip(r));
    const u = document.createElement('code'); u.className = 'muted'; u.textContent = url;
    const sum = document.createElement('span'); sum.className = 'muted';
    sum.textContent = r.eose_at
      ? (r.events || 0) + ' posts this session · ' + (r.profiles || 0) + ' profiles'
      : (r.stage === 'stopped' ? 'stopped' : r.error ? r.error : 'waiting for history');
    row.append(u, sum);
    row.onclick = () => openRelayModal(url);
    box.appendChild(row);
  });
  if (openRelay) renderRelayModal(openRelay);
}

function openRelayModal(url) {
  openRelay = url;
  renderRelayModal(url);
  $('relay-modal').show();
}

function renderRelayModal(url) {
  const { host, r, known } = relayFor(url);
  const body = $('relay-modal-body');
  body.textContent = '';
  const head = document.createElement('div');
  head.className = 'relay-head';
  head.appendChild(relayChip(r));
  const u = document.createElement('code'); u.className = 'muted'; u.textContent = url;
  head.appendChild(u);
  body.appendChild(head);
  // actions on their own row, so a long url never pushes them out of view
  const actions = document.createElement('div');
  actions.className = 'relay-actions';
  const mk = (label, title, fn) => { const b = document.createElement('button'); b.className = 'small'; b.textContent = label; b.title = title; b.onclick = fn; return b; };
  const stopped = !known || r.stage === 'stopped';
  if (stopped) actions.appendChild(mk('Connect', 'start the client for this relay', () => relayCmd(host, 'start')));
  else {
    actions.appendChild(mk('Reconnect', 'close this socket and open a new one (re-reads follows.json and config.json)', () => relayCmd(host, 'reconnect')));
    actions.appendChild(mk('Disconnect', 'close the socket and stop the client until you press Connect', () => relayCmd(host, 'stop')));
  }
  actions.appendChild(mk('Remove', 'drop this relay from config.json and stop its client', async () => {
    await fetch(BASE + '/api/relays', { method: 'POST', body: JSON.stringify({ url, action: 'remove' }) });
    $('relay-modal').close(); openRelay = null; loadRelays(); loadStatus();
  }));
  const note = document.createElement('span'); note.className = 'cmd-note muted'; actions.appendChild(note);
  body.appendChild(actions);
  const grid = document.createElement('div');
  grid.className = 'kvs';
  [
    ['stage', r.stage + (r.error ? ' — ' + r.error : '')],
    ['socket', r.wid != null ? 'wid ' + r.wid + ' (the kernel\'s id for this socket)' : 'none'],
    ['this session', (r.events || 0) + ' posts (' + (r.new || 0) + ' new to us), ' + (r.profiles || 0) + ' profiles'],
    ['asked for', r.req || '—'],
    ['history complete', r.eose_at ? fmtUnix(r.eose_at) : 'not yet'],
    ['session started', r.started ? fmtUnix(r.started) : '—'],
    ['failed attempts', String(r.tries || 0)],
    ['last notice', r.notice || '—'],
    ['status written', fmtUnix(r.updated)],
    ['file', 'relays/' + host + '.json'],
  ].forEach(([k, v]) => {
    const kv = document.createElement('div'); kv.className = 'kv';
    const kk = document.createElement('span'); kk.className = 'k'; kk.textContent = k;
    const vv = document.createElement('span'); vv.className = 'v'; vv.textContent = v;
    kv.append(kk, vv); grid.appendChild(kv);
  });
  body.appendChild(grid);
  const h3 = document.createElement('h4'); h3.textContent = 'Send a frame'; body.appendChild(h3);
  const p = document.createElement('p'); p.className = 'explain tight';
  p.textContent = 'Everything a nostr client says is one JSON array per line: ["REQ", id, filter] to subscribe, ["CLOSE", id] to stop one, ["EVENT", event] to publish. This goes down the socket verbatim; the answer shows up in the frames below.';
  body.appendChild(p);
  const raw = document.createElement('form'); raw.className = 'raw';
  const inp = document.createElement('input'); inp.className = 'mono';
  inp.placeholder = '["REQ","probe",{"kinds":[1],"limit":1}]';
  const go = document.createElement('button'); go.className = 'small'; go.type = 'submit'; go.textContent = 'Send';
  raw.append(inp, go);
  raw.onsubmit = (e) => { e.preventDefault(); if (inp.value.trim()) { relayCmd(host, 'raw', inp.value.trim()); inp.value = ''; } };
  body.appendChild(raw);
  const h4 = document.createElement('h4'); h4.textContent = 'Last frames'; body.appendChild(h4);
  const log = document.createElement('pre'); log.className = 'frames';
  log.textContent = (r.recent && r.recent.length) ? r.recent.join('\n') : '(no frames yet)';
  log.title = '> sent, < received; newest first';
  body.appendChild(log);
}

$('relays-reset').onclick = async () => {
  if (!confirm('Replace the relay list with the defaults?')) return;
  await fetch(BASE + '/api/relays', { method: 'POST', body: JSON.stringify({ action: 'reset' }) });
  loadRelays(); loadStatus();
};

$('relay-form').onsubmit = async (e) => {
  e.preventDefault();
  const url = $('relay-url').value.trim();
  if (!/^wss?:\/\/.+/.test(url)) { alert('a relay url starts with wss://'); return; }
  await fetch(BASE + '/api/relays', { method: 'POST', body: JSON.stringify({ url, action: 'add' }) });
  $('relay-url').value = '';
  loadRelays(); loadStatus();
};

// ---- me: identity, profile, publishing, outbox ----
let me = null;

async function loadMe() {
  if (!me) { busy($('outbox'), 'reading me/ and outbox/…'); }
  try { me = await jget('/api/me'); } catch (e) { me = null; }
  if (!me) { busy($('outbox'), 'could not read me/'); return; }
  const has = !!me.has_key && me.identity && me.identity.pubkey;
  $('me-nokey').hidden = !!has;
  $('me-key').hidden = !has;
  if (has) {
    $('me-pubkey').textContent = me.identity.pubkey;
    $('me-npub').textContent = me.identity.npub || '';
    $('me-since').textContent = fmtUnix(me.identity.since);
  }
  $('pf-name').value = me.profile.name || '';
  $('pf-about').value = me.profile.about || '';
  $('pf-picture').value = me.profile.picture || '';
  renderOutbox(me.outbox || []);
  $('outbox-count').textContent = (me.outbox || []).length + ' published';
}

function renderOutbox(items) {
  const box = $('outbox');
  box.textContent = '';
  if (!items.length) { box.innerHTML = '<div class="empty">Nothing published yet.</div>'; return; }
  items.forEach((o) => {
    const ev = o.event || {};
    const card = document.createElement('div');
    card.className = 'card outbox-item';
    const head = document.createElement('div');
    head.className = 'post-head';
    const kind = document.createElement('span');
    kind.className = 'kind';
    kind.textContent = ev.kind === 0 ? 'profile' : ev.kind === 1 ? 'post' : 'kind ' + ev.kind;
    const age = document.createElement('span');
    age.className = 'age';
    age.textContent = fmtAge(ev.created_at);
    age.title = fmtUnix(ev.created_at);
    head.append(kind, age);
    const content = document.createElement('div');
    content.className = 'content';
    renderText(content, ev.content || '');
    const verdicts = document.createElement('div');
    verdicts.className = 'verdicts';
    const rel = o.relays || {};
    const hosts = Object.keys(rel);
    if (!hosts.length) {
      const w = document.createElement('span'); w.className = 'verdict pending'; w.textContent = 'no relay has answered yet'; verdicts.appendChild(w);
    }
    hosts.forEach((h) => {
      const v = rel[h];
      const chip = document.createElement('span');
      chip.className = 'verdict ' + (v.ok ? 'ok' : 'bad');
      chip.textContent = h + (v.ok ? ' accepted' : ' rejected') + (v.message ? ': ' + v.message : '');
      verdicts.appendChild(chip);
    });
    const id = document.createElement('div');
    id.className = 'post-id';
    const a = document.createElement('a');
    a.href = '/grubbery/ball/apps/nostr/outbox/' + encodeURIComponent(ev.id) + '.json';
    a.target = '_blank';
    a.textContent = (ev.id || '').slice(0, 16) + '…';
    id.appendChild(a);
    card.append(head, content, verdicts, id);
    box.appendChild(card);
  });
}

$('gen-key').onclick = async () => {
  const b = $('gen-key');
  spinBtn(b, true); b.textContent = 'Generating…';
  await fetch(BASE + '/api/me/generate', { method: 'POST' });
  spinBtn(b, false); b.textContent = 'Generate a keypair';
  loadMe();
};

$('reveal').onclick = async () => {
  const code = $('me-nsec');
  if (!code.hidden) { code.hidden = true; $('reveal').textContent = 'Reveal nsec'; return; }
  const s = await jget('/api/me/secret');
  code.textContent = s.nsec || s.privkey || '(none)';
  code.hidden = false;
  $('reveal').textContent = 'Hide';
};

$('profile-form').onsubmit = async (e) => {
  e.preventDefault();
  const msg = $('pf-msg');
  msg.textContent = ''; msg.appendChild(spinner('signing and publishing…'));
  const r = await fetch(BASE + '/api/me/profile', { method: 'POST', body: JSON.stringify({
    name: $('pf-name').value.trim(), about: $('pf-about').value.trim(), picture: $('pf-picture').value.trim() }) });
  const d = await r.json().catch(() => ({}));
  msg.textContent = d.published ? 'saved and published as ' + d.published.slice(0, 12) + '…' : 'saved (no key: not published)';
  setTimeout(loadMe, 1500);
};

$('post-form').onsubmit = async (e) => {
  e.preventDefault();
  const msg = $('post-msg');
  const content = $('post-content').value.trim();
  if (!content) return;
  msg.textContent = ''; msg.appendChild(spinner('signing…'));
  const r = await fetch(BASE + '/api/publish', { method: 'POST', body: JSON.stringify({ content }) });
  if (!r.ok) { msg.textContent = await r.text(); return; }
  const d = await r.json();
  msg.textContent = 'published ' + d.id.slice(0, 12) + '… — waiting for relays';
  $('post-content').value = '';
  setTimeout(loadMe, 1500);
  setTimeout(loadMe, 5000);
};

async function loadAll() {
  await Promise.all([loadStatus(), loadFeed(), loadPeople(), loadRelays(), loadMe()]);
}

$('refresh').onclick = async () => {
  const b = $('refresh');
  spinBtn(b, true);
  await loadAll();
  spinBtn(b, false);
};

loadAll();
setInterval(() => { loadStatus(); loadRelays(); }, 60000);
