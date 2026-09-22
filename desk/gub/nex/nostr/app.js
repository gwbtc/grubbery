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

// an <avatar-pic> from a profile (the kit component; see lib/ui/avatar-pic.js)
function avatarEl(prof, pubkey, size) {
  const av = document.createElement('avatar-pic');
  av.setAttribute('name', (prof && prof.name) || '');
  av.setAttribute('seed', pubkey || '');
  av.setAttribute('src', (prof && prof.picture) || '');
  if (size) av.setAttribute('size', String(size));
  return av;
}

// mentions in text: the lib decodes them, we say who a key is
const nameCache = {};
async function nameFor(pk) {
  if (nameCache[pk] !== undefined) return nameCache[pk];
  try { const p = await jget('/api/person?pubkey=' + pk); nameCache[pk] = (p.profile && p.profile.name) || ''; }
  catch (e) { nameCache[pk] = ''; }
  return nameCache[pk];
}

// text via the shared lib (lib/ui/post-text.js): links, mentions, and
// media urls pulled out to render as attachments under the text
function renderText(el, text) {
  PostText.render(el, text, { onPerson: openPerson, onPost: openThread, onTag: openTag, nameFor });
}

// ---- a hashtag: the posts we hold under tags/<t>.json, and a fetch ----
async function openTag(t) {
  const body = $('tag-modal-body');
  busy(body, 'reading #' + t + '…');
  $('tag-modal').show();
  await renderTag(t);
}
async function renderTag(t) {
  const body = $('tag-modal-body');
  let d; try { d = await jget('/api/tag?t=' + encodeURIComponent(t)); } catch (e) { d = null; }
  body.textContent = '';
  if (!d) { body.innerHTML = '<div class="empty">could not read this tag</div>'; return; }
  const h = document.createElement('h4'); h.textContent = '#' + d.tag; body.appendChild(h);
  const p = document.createElement('p'); p.className = 'explain tight';
  p.textContent = 'Posts we hold carrying this tag (tags/' + d.tag + '.json), newest first: ' + d.count + '. Fetch asks each connected relay for the 50 latest posts tagged this way, from anyone.';
  body.appendChild(p);
  const row = document.createElement('div'); row.className = 'relay-actions';
  const fb = document.createElement('button'); fb.className = 'small'; fb.textContent = 'Fetch from relays';
  const fn = document.createElement('span'); fn.className = 'cmd-note muted';
  fb.onclick = async () => {
    spinBtn(fb, true); fn.textContent = ''; fn.appendChild(spinner('asking relays…'));
    await fetch(BASE + '/api/fetch-tag', { method: 'POST', body: JSON.stringify({ tag: t }) });
    await new Promise((r) => setTimeout(r, 3000));
    await renderTag(t);
  };
  const rb = document.createElement('button'); rb.className = 'small'; rb.textContent = 'Rebuild index';
  rb.title = 'walk every held post and re-file it under its hashtags (t tags and #words in the text)';
  rb.onclick = async () => {
    spinBtn(rb, true); fn.textContent = ''; fn.appendChild(spinner('walking events/…'));
    let r; try { r = await (await fetch(BASE + '/api/reindex-tags', { method: 'POST' })).json(); } catch (e) { r = null; }
    fn.textContent = r ? 'looked at ' + r.events + ' events' : 'failed';
    await renderTag(t);
  };
  row.append(fb, rb, fn); body.appendChild(row);
  const list = document.createElement('div'); list.className = 'thread';
  if (!d.posts.length) list.innerHTML = '<div class="empty">none indexed — Fetch asks relays; Rebuild index re-reads what we already hold</div>';
  d.posts.forEach((x) => list.appendChild(postEl(x, { onChange: () => renderTag(t) })));
  body.appendChild(list);
}

// ---- a person: profile, follow state, posts we hold, fetch from relays ----
async function openPerson(pk) {
  const body = $('person-modal-body');
  busy(body, 'reading the profile…');
  $('person-modal').show();
  await renderPerson(pk);
}

async function renderPerson(pk) {
  const body = $('person-modal-body');
  let d;
  try { d = await jget('/api/person?pubkey=' + pk); } catch (e) { d = null; }
  body.textContent = '';
  if (!d) { body.innerHTML = '<div class="empty">could not read this person</div>'; return; }
  const prof = d.profile || {};
  const head = document.createElement('div'); head.className = 'person-head';
  head.appendChild(avatarEl(prof, pk, 52));
  const names = document.createElement('div'); names.className = 'person-names';
  const n1 = document.createElement('div'); n1.className = 'who' + (prof.name ? '' : ' pk');
  n1.textContent = prof.display_name || prof.name || pk.slice(0, 16) + '…';
  const n2 = document.createElement('div'); n2.className = 'muted';
  n2.textContent = [prof.name && prof.display_name ? '@' + prof.name : '', prof.nip05 || ''].filter(Boolean).join(' · ');
  names.append(n1, n2);
  head.appendChild(names);
  body.appendChild(head);
  if (!d.known) {
    const w = document.createElement('p'); w.className = 'explain tight';
    w.textContent = 'No profile event has reached us for this key yet. Fetch asks the relays for their kind-0 and recent posts.';
    body.appendChild(w);
  }
  if (prof.about) { const ab = document.createElement('div'); ab.className = 'about'; renderText(ab, prof.about); body.appendChild(ab); }
  const grid = document.createElement('div'); grid.className = 'kvs';
  const site = (prof.website || '').trim();
  const siteHref = site ? (/^https?:\/\//i.test(site) ? site : 'https://' + site) : '';
  const ln = prof.lud16 || prof.lud06 || '';
  [
    ['npub', d.npub || '', null, 'copy'],
    ['pubkey', pk, null, 'copy'],
    ['website', site, siteHref, null],
    ['lightning', ln, ln && ln.includes('@') ? 'lightning:' + ln : null, 'copy'],
  ].filter(([, v]) => v).forEach(([k, v, href, extra]) => {
    const kv = document.createElement('div'); kv.className = 'kv';
    const kk = document.createElement('span'); kk.className = 'k'; kk.textContent = k;
    const vv = document.createElement('span'); vv.className = 'v';
    if (href) {
      const link = document.createElement('a'); link.href = href; link.textContent = v;
      if (href.startsWith('http')) { link.target = '_blank'; link.rel = 'noopener'; }
      vv.appendChild(link);
    } else {
      const code = document.createElement('code'); code.textContent = v; vv.appendChild(code);
    }
    if (extra === 'copy') {
      const cp = document.createElement('button'); cp.className = 'small copy'; cp.textContent = 'copy';
      cp.onclick = async () => { try { await navigator.clipboard.writeText(v); cp.textContent = 'copied'; setTimeout(() => { cp.textContent = 'copy'; }, 1200); } catch (e) {} };
      vv.appendChild(cp);
    }
    kv.append(kk, vv); grid.appendChild(kv);
  });
  body.appendChild(grid);
  const actions = document.createElement('div'); actions.className = 'relay-actions';
  const fol = document.createElement('button'); fol.className = 'small' + (d.followed ? '' : ' primary');
  fol.textContent = d.followed ? 'Unfollow' : 'Follow';
  fol.onclick = async () => {
    spinBtn(fol, true);
    await fetch(BASE + '/api/follows', { method: 'POST', body: JSON.stringify({ pubkey: pk, action: d.followed ? 'remove' : 'add' }) });
    await renderPerson(pk); loadPeople();
  };
  const fb = document.createElement('button'); fb.className = 'small'; fb.textContent = 'Fetch from relays';
  fb.title = 'ask every connected relay for this key\'s profile and its 40 latest posts';
  const note = document.createElement('span'); note.className = 'cmd-note muted';
  fb.onclick = async () => {
    spinBtn(fb, true); note.textContent = ''; note.appendChild(spinner('asking relays…'));
    await fetch(BASE + '/api/fetch-person', { method: 'POST', body: JSON.stringify({ pubkey: pk }) });
    await new Promise((r) => setTimeout(r, 2500));
    delete nameCache[pk];
    await renderPerson(pk);
  };
  actions.append(fol, fb, note);
  body.appendChild(actions);
  const h = document.createElement('h4'); h.textContent = 'Posts we hold (' + d.posts.length + ')'; body.appendChild(h);
  const list = document.createElement('div'); list.className = 'thread';
  if (!d.posts.length) list.innerHTML = '<div class="empty">none yet — try Fetch</div>';
  d.posts.forEach((p) => list.appendChild(postEl(p, { onChange: () => renderPerson(pk) })));
  body.appendChild(list);
}

// a <post-card> (lib/ui/post-card.js) wired to this page: the card draws
// the header and the standard row and asks for everything else by event;
// we render the text (mentions, links) into its content slot and answer
// its events with the endpoints. `opts.inThread` = part of a thread view
// (indent from opts.depth, Reply selects the target via opts.onReply).
function postEl(p, opts) {
  opts = opts || {};
  const card = document.createElement('post-card');
  if (opts.inThread) card.setAttribute('in-thread', '');
  if (opts.depth) card.setAttribute('depth', String(opts.depth));
  if (opts.compact) card.setAttribute('compact', '');
  card.post = p;
  const content = document.createElement('div'); content.slot = 'content';
  // trimmed: the slot is pre-wrap, so stray newlines would be blank lines
  renderText(content, (p.content || '').trim());
  const media = PostText.mediaOf(p.content || '');
  if (media.length) content.appendChild(PostText.attachments(media, 'thumb', (i) => openViewer(p, i + 1)));
  // a mentioned post (nostr:note… / nevent…) renders inline as a quote,
  // and the "note abc…" link comes out of the text (the quote IS the link)
  if (!opts.compact) {
    const seen = {};
    const links = [...content.querySelectorAll('a.mention.post')].filter((m) => m.title && m.title !== p.id);
    links.forEach((m) => {
      const id = m.title;
      if (seen[id]) { m.remove(); return; }
      seen[id] = true;
      if (Object.keys(seen).length > 3) return;
      // trim the whitespace the link sat in, so no blank line is left
      const prev = m.previousSibling, next = m.nextSibling;
      if (prev && prev.nodeType === 3) prev.textContent = prev.textContent.replace(/\s+$/, '');
      if (next && next.nodeType === 3) next.textContent = next.textContent.replace(/^\s+/, '');
      m.remove();
      content.appendChild(quoteEl(id));
    });
  }
  card.appendChild(content);
  card.addEventListener('pc-open', () => openThread(p.id));
  card.addEventListener('pc-person', (e) => openPerson(e.detail.pubkey));
  card.addEventListener('pc-reply', () => { if (opts.inThread) { if (opts.onReply) opts.onReply(); } else openThread(p.id, p.id); });
  card.addEventListener('pc-react', async (e) => {
    const r = await fetch(BASE + '/api/react', { method: 'POST', body: JSON.stringify({ id: p.id, content: e.detail.content }) });
    e.detail.done();
    if (!r.ok) { alert(await r.text()); return; }
    if (opts.onChange) opts.onChange();
  });
  card.addEventListener('pc-who', () => toggleWho(card, p));
  card.addEventListener('pc-repost', async (e) => {
    const r = await fetch(BASE + '/api/repost', { method: 'POST', body: JSON.stringify({ id: p.id }) });
    e.detail.done();
    if (!r.ok) { alert(await r.text()); return; }
    if (opts.onChange) opts.onChange();
  });
  return card;
}

// a quoted post: the compact card when we hold it, else a gap with a
// Fetch (by id, on every relay) that fills in when it arrives
function quoteEl(id) {
  const box = document.createElement('div'); box.className = 'quote';
  const load = async () => {
    busy(box, 'quoted post…');
    let d; try { d = await jget('/api/post?id=' + encodeURIComponent(id)); } catch (e) { d = null; }
    box.textContent = '';
    if (d && d.held) { box.appendChild(postEl(d.post, { compact: true })); return; }
    const gap = document.createElement('div'); gap.className = 'quote-missing';
    const t = document.createElement('span'); t.textContent = 'quoted post not here yet (' + id.slice(0, 12) + '…)';
    const b = document.createElement('button'); b.className = 'small'; b.textContent = 'Fetch';
    b.onclick = async (e) => {
      e.stopPropagation(); spinBtn(b, true);
      await fetch(BASE + '/api/fetch', { method: 'POST', body: JSON.stringify({ id }) });
      await new Promise((r) => setTimeout(r, 2500));
      load();
    };
    gap.append(t, b); box.appendChild(gap);
  };
  load();
  return box;
}

// the post popup (lib/ui/post-viewer.js): page 0 the post, then its media
function openViewer(p, page) {
  PostViewer.open({ post: p, profile: p.profile || {}, page: page || 0, renderText, onPerson: openPerson });
}

// the who-list under a card: who reposted and who reacted with what.
// Names come from the thread endpoint's engagement (events we hold), so
// the list can be shorter than the count — the count is from refs/.
async function toggleWho(card, p) {
  const cur = card.querySelector('[slot="who"]');
  if (cur) { cur.remove(); return; }
  const box = document.createElement('div'); box.slot = 'who'; box.className = 'who-list';
  busy(box, 'who…'); card.appendChild(box);
  let d; try { d = await jget('/api/thread?id=' + encodeURIComponent(p.id)); } catch (x) { d = null; }
  if (!box.isConnected) return;
  const shown = (x) => x.kind === 6 ? '🔁' : (x.content === '+' || !x.content) ? '👍' : x.content;
  const eng = (d && Array.isArray(d.engagement) ? d.engagement : []).filter((x) => x.on === p.id);
  box.textContent = '';
  if (!eng.length) { box.innerHTML = '<div class="empty tight">nobody we know of — the count is from refs/, the names from events we hold</div>'; return; }
  eng.forEach((x) => {
    const r = document.createElement('div'); r.className = 'eng-row';
    r.appendChild(avatarEl({ name: x.name, picture: x.picture }, x.pubkey, 22));
    const nm = document.createElement('span'); nm.className = 'who clickable' + (x.name ? '' : ' pk');
    nm.textContent = x.name || x.pubkey.slice(0, 12); nm.title = x.pubkey;
    nm.onclick = (ev) => { ev.stopPropagation(); openPerson(x.pubkey); };
    const what = document.createElement('span'); what.className = 'what'; what.textContent = shown(x);
    const at = document.createElement('span'); at.className = 'muted'; at.textContent = fmtAge(x.at);
    r.append(nm, what, at);
    box.appendChild(r);
  });
}

// ---- thread: the root and every reply in refs/<root>, as a tree ----
let threadState = { id: null, replyTo: null };

async function openThread(id, replyTo) {
  threadState = { id, replyTo: replyTo || null };
  const body = $('thread-modal-body');
  busy(body, 'reading the thread…');
  $('thread-modal').show();
  await renderThread();
}

async function renderThread() {
  const body = $('thread-modal-body');
  let d;
  try { d = await jget('/api/thread?id=' + encodeURIComponent(threadState.id)); } catch (e) { d = null; }
  body.textContent = '';
  if (!d || !Array.isArray(d.posts)) { body.innerHTML = '<div class="empty">could not read the thread</div>'; return; }
  const h = document.createElement('h4'); h.textContent = 'Thread'; body.appendChild(h);
  const p = document.createElement('p'); p.className = 'explain tight';
  p.textContent = 'The root post and every reply that points at it (refs/' + d.root.slice(0, 12) + '….json), in time order, indented by what each answers. This is what has reached us so far, not everything that exists: no relay has everything. Fetch asks each connected relay for anything pointing at this thread.';
  body.appendChild(p);
  const fetchRow = document.createElement('div'); fetchRow.className = 'relay-actions';
  const fb = document.createElement('button'); fb.className = 'small'; fb.textContent = 'Fetch from relays';
  fb.title = 'ask every connected relay for the root by id and for anything pointing at it, then re-read';
  const fn = document.createElement('span'); fn.className = 'cmd-note muted';
  fb.onclick = async () => {
    spinBtn(fb, true); fn.textContent = ''; fn.appendChild(spinner('asking relays…'));
    await fetch(BASE + '/api/fetch', { method: 'POST', body: JSON.stringify({ id: d.root }) });
    await new Promise((r) => setTimeout(r, 2500));
    await renderThread();
  };
  fetchRow.append(fb, fn);
  body.appendChild(fetchRow);
  // depth by parent chain
  const byId = {}; d.posts.forEach((x) => { byId[x.id] = x; });
  const depth = (x) => { let n = 0, cur = x; while (cur && cur.reply_to && byId[cur.reply_to.parent] && n < 12) { cur = byId[cur.reply_to.parent]; n++; } return n; };
  const list = document.createElement('div'); list.className = 'thread';
  if (d.root_held === false) {
    const gap = document.createElement('div'); gap.className = 'root-missing';
    const h = document.createElement('div'); h.className = 'rm-head'; h.textContent = 'Root post missing';
    const t = document.createElement('div'); t.className = 'rm-text';
    t.textContent = 'These are replies to a post that has not reached us (' + d.root.slice(0, 16) + '…). No relay we asked has sent it yet.';
    const b = document.createElement('button'); b.className = 'small primary'; b.textContent = 'Fetch the root from relays';
    b.onclick = async () => { spinBtn(b, true); await fetch(BASE + '/api/fetch', { method: 'POST', body: JSON.stringify({ id: d.root }) }); await new Promise((r) => setTimeout(r, 2500)); await renderThread(); };
    gap.append(h, t, b);
    list.appendChild(gap);
  }
  d.posts.forEach((x) => {
    const el = postEl(x, { inThread: true, depth: x.id === d.root ? 0 : depth(x), onChange: renderThread,
                           onReply: () => { threadState.replyTo = x.id; renderThread(); } });
    if (x.id === threadState.replyTo) el.setAttribute('target', '');
    list.appendChild(el);
  });
  body.appendChild(list);
  // reply box: to the selected post, else the root
  // reply to the selected post, else the root, else (root missing) the first reply we hold
  const target = byId[threadState.replyTo] || byId[d.root] || d.posts[0];
  if (!target) return;
  const form = document.createElement('form'); form.className = 'card form reply-form';
  const replyLabel = document.createElement('div'); replyLabel.className = 'muted';
  replyLabel.textContent = 'replying to ' + ((target.profile && target.profile.name) || (target.pubkey || '').slice(0, 12)) + (target.id === d.root ? ' (the root)' : '');
  const ta = document.createElement('textarea'); ta.rows = 3; ta.placeholder = 'your reply';
  const rowEl = document.createElement('div'); rowEl.className = 'row';
  const send = document.createElement('button'); send.className = 'small primary'; send.type = 'submit'; send.textContent = 'Reply';
  const msg = document.createElement('span'); msg.className = 'muted';
  rowEl.append(send, msg);
  form.append(replyLabel, ta, rowEl);
  form.onsubmit = async (e) => {
    e.preventDefault();
    const content = ta.value.trim(); if (!content) return;
    msg.textContent = ''; msg.appendChild(spinner('signing…'));
    const r = await fetch(BASE + '/api/reply', { method: 'POST', body: JSON.stringify({ parent: target.id, content }) });
    if (!r.ok) { msg.textContent = await r.text(); return; }
    ta.value = '';
    await renderThread();
  };
  body.appendChild(form);
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

// the feed filter is a view, not a query: the index is the record, the
// page chooses what to show from it
let feedPosts = [];
let feedFilter = 'all';
try { feedFilter = localStorage.getItem('nostr-feed-filter') || 'all'; } catch (e) {}

function renderFeed() {
  const box = $('feed');
  box.textContent = '';
  const shown = feedPosts.filter((p) =>
    feedFilter === 'all' ? true : feedFilter === 'replies' ? !!p.reply_to : feedFilter === 'reposts' ? !!p.repost : !p.reply_to);
  $('feed-filter-note').textContent = feedFilter === 'all' ? '' : shown.length + ' of ' + feedPosts.length;
  document.querySelectorAll('#feed-filters .chip').forEach((b) => b.classList.toggle('on', b.dataset.filter === feedFilter));
  if (!feedPosts.length) { box.innerHTML = '<div class="empty">Nothing yet — the relay clients fill this in as events arrive.</div>'; return; }
  if (!shown.length) { box.innerHTML = '<div class="empty">nothing of that kind in the last ' + feedPosts.length + '</div>'; return; }
  shown.forEach((p) => box.appendChild(postEl(p, { onChange: loadFeed })));
}

async function loadFeed() {
  const box = $('feed');
  if (!feedPosts.length) busy(box, 'reading the feed…');
  let d;
  try { d = await jget('/api/feed?limit=80'); } catch (e) { d = null; }
  if (!d || !Array.isArray(d.posts)) { box.textContent = ''; box.innerHTML = '<div class="empty">could not read the feed</div>'; return; }
  $('feed-count').textContent = d.count + ' posts';
  feedPosts = d.posts;
  renderFeed();
}

// the relay clients ask for unknown profiles and missing roots as
// events arrive; this asks for everything still missing, at once
$('fill').onclick = async () => {
  const b = $('fill'), note = $('fill-note');
  spinBtn(b, true); note.textContent = ''; note.appendChild(spinner('listing gaps…'));
  let r; try { r = await (await fetch(BASE + '/api/fill', { method: 'POST' })).json(); } catch (e) { r = null; }
  spinBtn(b, false);
  note.textContent = !r ? 'failed' : (!r.authors && !r.roots) ? 'nothing missing' : 'asked for ' + r.authors + ' profiles, ' + r.roots + ' roots';
  setTimeout(() => { note.textContent = ''; loadAll(); }, 4000);
};

document.querySelectorAll('#feed-filters .chip').forEach((b) => {
  b.onclick = () => { feedFilter = b.dataset.filter; try { localStorage.setItem('nostr-feed-filter', feedFilter); } catch (e) {} renderFeed(); };
});

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
    row.className = 'person clickable';
    row.title = 'open';
    row.onclick = (e) => { if (e.target.closest('button')) return; openPerson(p.pubkey); };
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
    id.textContent = (ev.id || '').slice(0, 16) + '…';
    id.title = ev.id || '';
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
