'use strict';
var API = '/grubbery/ghostprompter';
var busy = false;

// ---------- the flow ----------

async function loadFeed() {
  var box = document.getElementById('flow-list');
  var data;
  try {
    data = await fetch(API + '/api/feed?limit=40').then(function(r) { return r.json(); });
  } catch (e) { data = null; }
  var posts = data && Array.isArray(data.posts) ? data.posts : null;
  var profiles = (data && data.profiles) || {};
  box.textContent = '';
  if (!posts) {
    box.innerHTML = '<div class="empty">Flow unreachable — is nostrill up?</div>';
    document.getElementById('flow-count').textContent = '';
    return;
  }
  document.getElementById('flow-count').textContent = posts.length + ' posts';
  if (!posts.length) {
    box.innerHTML = '<div class="empty">The flow is quiet.</div>';
    return;
  }
  posts.forEach(function(p) {
    var prof = profiles[p.pubkey] || {};
    var item = document.createElement('div');
    item.className = 'flow-item';

    var head = document.createElement('div');
    head.className = 'flow-head';
    head.appendChild(avatarEl(prof, p.pubkey));
    var who = document.createElement('span');
    who.className = 'flow-name';
    who.textContent = prof.name || (p.pubkey || '').slice(0, 8);
    if (!prof.name) who.classList.add('pk');
    var age = document.createElement('span');
    age.className = 'flow-age';
    age.textContent = fmtAge(p.at);
    head.append(who, age);

    var content = document.createElement('div');
    content.className = 'flow-content';
    renderText(content, p.content || '');
    item.append(head, content);
    var media = mediaOf(p.content || '');
    if (media.length) item.appendChild(attachmentsEl(media, 'thumb', null));
    item.addEventListener('click', function(e) {
      if (e.target.closest('a')) return;  // links navigate
      openPost(p, prof);
    });
    box.appendChild(item);
  });
}

// ---------- post modal: page 0 = the post, pages 1..N = its media ----------

var modalState = { p: null, prof: null, media: [], page: 0 };

function openPost(p, prof) {
  modalState = { p: p, prof: prof, media: mediaOf(p.content || ''), page: 0 };
  renderModalPage();
  document.getElementById('post-modal').show();
}

function renderModalPage() {
  var st = modalState;
  var head = document.getElementById('post-modal-head');
  var body = document.getElementById('post-modal-body');
  var idEl = document.getElementById('post-modal-id');
  var nav = document.getElementById('post-modal-nav');
  head.textContent = '';
  body.textContent = '';

  head.appendChild(avatarEl(st.prof, st.p.pubkey));
  var who = document.createElement('div');
  who.className = 'post-modal-who';
  var nm = document.createElement('div');
  nm.className = 'flow-name';
  nm.textContent = st.prof.name || (st.p.pubkey || '').slice(0, 12);
  if (!st.prof.name) nm.classList.add('pk');
  var when = document.createElement('div');
  when.className = 'post-modal-when';
  when.textContent = st.p.at ? new Date(st.p.at * 1000).toLocaleString() : '';
  who.append(nm, when);
  head.appendChild(who);

  body.classList.toggle('media-page', st.page > 0);
  if (st.page === 0) {
    // the whole post: text, then the attachments expanded below;
    // clicking an image jumps to its focused page
    var txt = document.createElement('div');
    txt.className = 'pm-text';
    renderText(txt, st.p.content || '');
    if (txt.textContent.trim()) body.appendChild(txt);
    if (st.media.length) {
      body.appendChild(attachmentsEl(st.media, 'full', function(idx) {
        modalState.page = idx + 1;
        renderModalPage();
      }));
    }
  } else {
    var m = st.media[st.page - 1];
    var wrap = document.createElement('div');
    wrap.className = 'pm-media';
    if (m.video) {
      var vel = document.createElement('video');
      vel.controls = true;
      vel.preload = 'metadata';
      vel.src = m.url;
      wrap.appendChild(vel);
      body.appendChild(wrap);
    } else {
      wrap.classList.add('fp');
      body.appendChild(wrap);
      pmViewer(wrap, m.url);
    }
  }

  var pages = 1 + st.media.length;
  nav.classList.toggle('hidden', pages < 2);
  document.getElementById('pm-count').textContent =
    st.page === 0 ? 'post · ' + st.media.length + ' media' : st.page + ' / ' + st.media.length;
  document.getElementById('pm-prev').disabled = st.page === 0;
  document.getElementById('pm-next').disabled = st.page >= pages - 1;
  idEl.textContent = 'event ' + (st.p.id || '');
}

// image viewer for media pages: black canvas, drag to reposition,
// shift-scroll (or pinch) to zoom toward the cursor, dblclick to
// toggle, plus the explorer-style − / % / + / fit / 1:1 bar.
function pmViewer(wrap, url) {
  var img = document.createElement('img');
  img.draggable = false;
  img.src = url;
  wrap.appendChild(img);

  var scale = 1, tx = 0, ty = 0, drag = null;
  function nat() { return img.naturalWidth || img.clientWidth || 1; }
  function apply() {
    img.style.transform = 'translate(' + tx + 'px,' + ty + 'px) scale(' + scale + ')';
    wrap.classList.toggle('zoomed', scale > 1.001);
    pct.textContent = Math.round(scale * (img.clientWidth / nat()) * 100) + '%';
  }
  function setScale(next, cx, cy) {
    next = Math.max(0.2, Math.min(12, next));
    if (next === scale) return;
    if (cx !== undefined) {
      var r = img.getBoundingClientRect();
      var px = cx - (r.left + r.width / 2);
      var py = cy - (r.top + r.height / 2);
      tx -= px * (next / scale - 1);
      ty -= py * (next / scale - 1);
    }
    if (next <= 1.001) { tx = 0; ty = 0; }
    scale = next;
    apply();
  }
  // drag owns repositioning, so the wheel owns zoom — no modifier
  wrap.addEventListener('wheel', function(e) {
    e.preventDefault();
    var d = e.deltaY || e.deltaX;
    setScale(scale * (d < 0 ? 1.15 : 1 / 1.15), e.clientX, e.clientY);
  }, { passive: false });
  img.addEventListener('dblclick', function(e) {
    setScale(scale > 1.001 ? 1 : 2.5, e.clientX, e.clientY);
  });
  img.addEventListener('pointerdown', function(e) {
    e.preventDefault();
    drag = { x: e.clientX - tx, y: e.clientY - ty };
    wrap.classList.add('dragging');
    img.setPointerCapture(e.pointerId);
  });
  img.addEventListener('pointermove', function(e) {
    if (!drag) return;
    tx = e.clientX - drag.x;
    ty = e.clientY - drag.y;
    apply();
  });
  img.addEventListener('pointerup', function() {
    drag = null;
    wrap.classList.remove('dragging');
  });

  var bar = document.createElement('div');
  bar.className = 'pmv-bar';
  function btn(label, title, fn) {
    var b = document.createElement('button');
    b.textContent = label;
    b.title = title;
    b.addEventListener('click', fn);
    return b;
  }
  var pct = document.createElement('span');
  pct.className = 'pmv-pct';
  bar.appendChild(btn('−', 'zoom out', function() { setScale(scale / 1.25); }));
  bar.appendChild(pct);
  bar.appendChild(btn('+', 'zoom in', function() { setScale(scale * 1.25); }));
  bar.appendChild(btn('fit', 'fit to view', function() { setScale(1); }));
  bar.appendChild(btn('1:1', 'actual size', function() {
    setScale(nat() / (img.clientWidth || 1));
  }));
  wrap.appendChild(bar);
  if (img.complete) apply();
  else img.addEventListener('load', apply, { once: true });
}

// open-state via the component's own events — offsetParent is unreliable
// across the shadow/top-layer boundary
var pmOpen = false;
document.getElementById('post-modal').addEventListener('md-open', function() { pmOpen = true; });
document.getElementById('post-modal').addEventListener('md-close', function() {
  pmOpen = false;
  document.getElementById('post-modal-body').textContent = '';  // stops video
});

function modalStep(d) {
  if (!pmOpen) return;
  var pages = 1 + modalState.media.length;
  var next = modalState.page + d;
  if (next < 0 || next >= pages) return;
  modalState.page = next;
  renderModalPage();
}

document.getElementById('pm-prev').onclick = function() { modalStep(-1); };
document.getElementById('pm-next').onclick = function() { modalStep(1); };
document.addEventListener('keydown', function(e) {
  if (e.key === 'ArrowLeft') modalStep(-1);
  if (e.key === 'ArrowRight') modalStep(1);
});

// avatar: profile picture, or a tinted initial disc derived from the pubkey
function avatarEl(prof, pubkey) {
  var wrap = document.createElement('span');
  wrap.className = 'flow-avatar';
  var hue = 0;
  for (var i = 0; i < Math.min(8, (pubkey || '').length); i++) {
    hue = (hue * 31 + pubkey.charCodeAt(i)) % 360;
  }
  wrap.style.background = 'hsl(' + hue + ', 32%, 82%)';
  wrap.style.color = 'hsl(' + hue + ', 45%, 30%)';
  wrap.textContent = (prof.name || pubkey || '?').slice(0, 1).toUpperCase();
  if (prof.picture && /^https?:\/\//.test(prof.picture)) {
    var img = document.createElement('img');
    img.loading = 'lazy';
    img.referrerPolicy = 'no-referrer';
    img.src = prof.picture;
    img.onerror = function() { img.remove(); };
    wrap.appendChild(img);
  }
  return wrap;
}

// media classification shared by the feed cards and the post modal
var IMG_RE = /\.(jpe?g|png|gif|webp|avif)(\?\S*)?$/i;
var VID_RE = /\.(mp4|webm|mov|m4v)(\?\S*)?$/i;
function classify(url) {
  if (VID_RE.test(url)) return 'video';
  if (IMG_RE.test(url) || /picsum\.photos|\/media\./.test(url)) return 'image';
  return 'link';
}
function mediaOf(text) {
  var out = [];
  text.split(/(https?:\/\/\S+)/g).forEach(function(part) {
    if (!/^https?:\/\//.test(part)) return;
    var kind = classify(part);
    if (kind !== 'link') out.push({ url: part, video: kind === 'video' });
  });
  return out;
}

// A post is TEXT plus ATTACHED MEDIA. The text renders with media URLs
// removed (plain links stay clickable); the media renders as its own
// attachment block below — thumbnails in the feed, expanded and
// playable in the modal.
function renderText(el, text) {
  var parts = text.split(/(https?:\/\/\S+)/g).filter(function(x) { return x; });
  var isMedia = function(x) { return /^https?:\/\//.test(x) && classify(x) !== 'link'; };
  parts.forEach(function(part, i) {
    if (/^https?:\/\//.test(part)) {
      if (!isMedia(part)) el.appendChild(linkEl(part));
      return;
    }
    var t = part.replace(/\n{3,}/g, '\n\n');
    if (t.trim() === '') {
      if ((i > 0 && isMedia(parts[i - 1])) || (i < parts.length - 1 && isMedia(parts[i + 1]))) return;
    }
    if (i > 0 && isMedia(parts[i - 1])) t = t.replace(/^\s+/, '');
    if (i < parts.length - 1 && isMedia(parts[i + 1])) t = t.replace(/\s+$/, '');
    el.appendChild(document.createTextNode(t));
  });
}

// attachment block. mode 'thumb': cropped previews in a grid (feed
// card). mode 'full': natural-size, centered, videos playable (modal
// page 0). onMedia(i) fires on click when given.
function attachmentsEl(media, mode, onMedia) {
  var box = document.createElement('div');
  box.className = 'attach ' + mode;
  media.forEach(function(m, i) {
    var cell = document.createElement('div');
    cell.className = 'attach-cell';
    var el;
    if (m.video) {
      if (mode === 'full') {
        el = document.createElement('video');
        el.controls = true;
        el.preload = 'metadata';
        el.playsInline = true;
      } else {
        el = document.createElement('video');
        el.muted = true;
        el.playsInline = true;
        el.preload = 'metadata';
        var badge = document.createElement('span');
        badge.className = 'flow-vid-badge';
        badge.textContent = '▶';
        cell.appendChild(badge);
      }
    } else {
      el = document.createElement('img');
      el.loading = 'lazy';
      el.referrerPolicy = 'no-referrer';
      el.onerror = function() { cell.remove(); };
      if (mode === 'thumb') {
        // mark clipped previews so the fade + expand badge show
        el.onload = function() {
          if (el.offsetHeight > cell.clientHeight + 2) cell.classList.add('cut');
        };
      }
    }
    el.src = m.url;
    cell.insertBefore(el, cell.firstChild);
    if (onMedia && !(m.video && mode === 'full')) {
      cell.addEventListener('click', function(e) { e.stopPropagation(); onMedia(i); });
      cell.classList.add('clickable');
    }
    box.appendChild(cell);
  });
  return box;
}

function linkEl(url) {
  var a = document.createElement('a');
  a.className = 'flow-link';
  a.href = url;
  a.target = '_blank';
  a.rel = 'noopener noreferrer';
  var short = url.replace(/^https?:\/\/(www\.)?/, '');
  a.textContent = short.length > 42 ? short.slice(0, 42) + '…' : short;
  return a;
}

function fmtAge(unix) {
  if (!unix) return '';
  var s = Math.max(0, Math.floor(Date.now() / 1000) - unix);
  if (s < 60) return 'now';
  if (s < 3600) return Math.floor(s / 60) + 'm';
  if (s < 86400) return Math.floor(s / 3600) + 'h';
  return Math.floor(s / 86400) + 'd';
}

// ---------- library ----------
// a plain directory under the nexus; the shared file-manager is the whole
// surface (list/grid, upload, new file, edit, preview, delete)
var libFm = FileManager.mount(document.getElementById('lib-mount'), {
  root: '/grubbery/ball/apps/ghostprompter/library',
  rootLabel: 'library',
  persist: 'gp-lib-view',
});
function loadLibrary() { libFm.ready.then(function () { libFm.load(); }); }

// ---------- connections: a deck you page through; references below ----------
//
// The card is the connection at a glance (topic, question, source
// pointers). The references panel underneath is the same connection at
// full zoom: the cited posts rendered like the flow, the passage with
// its document and lines. Structured refs (post_ids, source+from/to)
// drive that; older proposals carry only pasted text and render that.

var props = [];
var deckIdx = 0;
var refsToken = 0;

async function loadProposals() {
  try {
    props = await fetch(API + '/api/proposals').then(function(r) { return r.json(); });
  } catch (e) { props = []; }
  if (!Array.isArray(props)) props = [];
  props.sort(function(a, b) { return ((b.doc && b.doc.at) || 0) - ((a.doc && a.doc.at) || 0); });
  document.getElementById('prop-count').textContent = props.length ? props.length + ' filed' : '';
  if (deckIdx >= props.length) deckIdx = Math.max(0, props.length - 1);
  renderDeck();
}

function showCard(i) {
  if (!props.length) return;
  deckIdx = (i + props.length) % props.length;
  renderDeck();
}

function renderDeck() {
  var stage = document.getElementById('deck-stage');
  var dots = document.getElementById('deck-dots');
  stage.textContent = '';
  dots.textContent = '';
  var prev = document.getElementById('deck-prev'), next = document.getElementById('deck-next');
  prev.disabled = next.disabled = props.length < 2;
  if (!props.length) {
    stage.innerHTML = '<div class="deck-empty">No connections yet. Summon the ghost to index the flow against your library.</div>';
    renderRefs(null);
    return;
  }
  // neighbors peek at the edges: prev | current | next
  [-1, 0, 1].forEach(function(off) {
    var j = deckIdx + off;
    if (props.length < 3 && (j < 0 || j >= props.length)) return;
    var p = props[(j + props.length) % props.length];
    var card = cardEl(p, off === 0);
    card.classList.add(off === 0 ? 'cur' : off < 0 ? 'prev' : 'next');
    if (off !== 0) card.onclick = function() { showCard(j); };
    stage.appendChild(card);
  });
  props.forEach(function(_, i) {
    var d = document.createElement('span');
    d.className = 'dot' + (i === deckIdx ? ' on' : '');
    d.onclick = function() { showCard(i); };
    dots.appendChild(d);
  });
  renderRefs(props[deckIdx]);
}

function cardEl(p, live) {
  var d = p.doc || {};
  var card = document.createElement('div');
  card.className = 'card';
  var top = document.createElement('div');
  top.className = 'card-top';
  var topic = document.createElement('div');
  topic.className = 'card-topic';
  topic.textContent = d.topic || '(untitled)';
  var age = document.createElement('span');
  age.className = 'card-age';
  age.textContent = d.at ? fmtAge(d.at) : '';
  top.append(topic, age);
  card.appendChild(top);
  if (d.question) {
    var q = document.createElement('div');
    q.className = 'card-question';
    q.textContent = d.question;
    card.appendChild(q);
  }
  // source pointers: what this connection is made of
  var srcs = document.createElement('div');
  srcs.className = 'card-srcs';
  var nPosts = (d.posts || '').split('\n').filter(function(l) { return l.trim(); }).length;
  if (nPosts) srcs.appendChild(chip('flow', nPosts + (nPosts === 1 ? ' post' : ' posts')));
  if (d.passage) srcs.appendChild(chip('library', (d.source || 'a document') + (d.from ? ' · ' + d.from + (d.to && d.to !== d.from ? '–' + d.to : '') : '')));
  card.appendChild(srcs);
  if (live) {
    var actions = document.createElement('div');
    actions.className = 'card-actions';
    if (d.passage) {
      var copy = document.createElement('button');
      copy.textContent = 'Copy passage';
      copy.onclick = async function(e) {
        e.stopPropagation();
        try { await navigator.clipboard.writeText(d.passage); copy.textContent = 'Copied ✓'; setTimeout(function() { copy.textContent = 'Copy passage'; }, 1600); } catch (_) {}
      };
      actions.appendChild(copy);
    }
    var dismiss = document.createElement('button');
    dismiss.className = 'danger';
    dismiss.textContent = 'Dismiss';
    dismiss.onclick = async function(e) {
      e.stopPropagation();
      await fetch(API + '/api/proposals/' + encodeURIComponent(p.id), { method: 'DELETE' });
      loadProposals();
    };
    actions.appendChild(dismiss);
    card.appendChild(actions);
  }
  return card;
}

function chip(kind, text) {
  var c = document.createElement('span');
  c.className = 'src-chip ' + kind;
  c.textContent = text;
  return c;
}

// ---- references: the connection at full zoom ----
async function renderRefs(p) {
  var token = ++refsToken;
  var flowBody = document.getElementById('refs-flow-body');
  var libBody = document.getElementById('refs-lib-body');
  flowBody.textContent = '';
  libBody.textContent = '';
  if (!p) return;
  var d = p.doc || {};

  // flow side: the posts as they were when the connection was filed
  // (snapshotted by propose); older proposals fall back to a live lookup
  // by id, and before that to the pasted lines
  var snap = Array.isArray(d.post_snap) ? d.post_snap : [];
  var ids = Array.isArray(d.post_ids) ? d.post_ids.filter(Boolean) : [];
  if (snap.length) {
    snap.forEach(function(sp) {
      flowBody.appendChild(postEl({ id: sp.id, pubkey: sp.pubkey, at: sp.at, content: sp.content }, { name: sp.name, picture: sp.picture }));
    });
    if (d.posts) flowBody.appendChild(excerptsEl(d.posts));
  } else if (ids.length) {
    flowBody.innerHTML = '<div class="empty">loading posts…</div>';
    var got = await Promise.all(ids.map(function(id) {
      return fetch(API + '/api/post?id=' + encodeURIComponent(id)).then(function(r) { return r.json(); }).catch(function() { return null; });
    }));
    if (token !== refsToken) return;
    flowBody.textContent = '';
    got.forEach(function(res, i) {
      if (res && res.post) { flowBody.appendChild(postEl(res.post, (res.profiles || {})[res.post.pubkey] || {})); return; }
      var miss = document.createElement('div');
      miss.className = 'ref-missing';
      miss.textContent = 'post ' + ids[i].slice(0, 12) + '… is no longer in the feed';
      flowBody.appendChild(miss);
    });
    // the agent's excerpts, as a caption under the real posts
    if (d.posts) flowBody.appendChild(excerptsEl(d.posts));
  } else if (d.posts) {
    flowBody.appendChild(excerptsEl(d.posts));
  } else {
    flowBody.innerHTML = '<div class="empty">no flow side</div>';
  }

  // library side: the passage, then the actual lines around it
  if (!d.passage) { libBody.innerHTML = '<div class="empty">no library side</div>'; return; }
  var q = document.createElement('blockquote');
  q.className = 'ref-quote';
  q.textContent = d.passage;
  libBody.appendChild(q);
  var cite = document.createElement('div');
  cite.className = 'ref-cite';
  cite.textContent = d.source ? '— ' + d.source + (d.from ? ', lines ' + d.from + (d.to && d.to !== d.from ? '–' + d.to : '') : '') : '';
  libBody.appendChild(cite);
  if (d.source && d.from) {
    var lo = Math.max(1, d.from - 15), hi = (d.to || d.from) + 15;
    var ctx = document.createElement('pre');
    ctx.className = 'ref-context';
    ctx.textContent = 'loading context…';
    libBody.appendChild(ctx);
    try {
      var raw = await fetch('/grubbery/ball/apps/ghostprompter/library/' + encodeURIComponent(d.source) + '?raw=1').then(function(r) { return r.text(); });
      if (token !== refsToken) return;
      var lines = raw.split('\n');
      ctx.textContent = '';
      for (var n = lo; n <= Math.min(hi, lines.length); n++) {
        var ln = document.createElement('div');
        ln.className = 'ref-line' + (n >= d.from && n <= (d.to || d.from) ? ' hit' : '');
        ln.innerHTML = '<span class="ln">' + n + '</span>';
        ln.appendChild(document.createTextNode(lines[n - 1]));
        ctx.appendChild(ln);
      }
      var open = document.createElement('a');
      open.className = 'ref-open';
      open.textContent = 'open ' + d.source + ' in the library ↗';
      open.href = '/grubbery/ball/apps/ghostprompter/library/' + encodeURIComponent(d.source);
      open.target = '_blank';
      libBody.appendChild(open);
    } catch (e) { ctx.textContent = 'could not load ' + d.source; }
  }
}

function excerptsEl(posts) {
  var wrap = document.createElement('div');
  wrap.className = 'ref-excerpts';
  posts.split('\n').forEach(function(line) {
    line = line.trim();
    if (!line) return;
    var seg = line.split('|');
    var row = document.createElement('div');
    row.className = 'ref-excerpt';
    if (seg.length >= 3) {
      var meta = document.createElement('span');
      meta.className = 'ref-excerpt-meta';
      meta.textContent = seg[0].trim() + ' · ' + seg[1].trim() + ' ';
      row.appendChild(meta);
      row.appendChild(document.createTextNode(seg.slice(2).join('|').trim()));
    } else row.textContent = line;
    wrap.appendChild(row);
  });
  return wrap;
}

// a flow post rendered the way the flow tab does it, click = the post modal
function postEl(p, prof) {
  var item = document.createElement('div');
  item.className = 'flow-item ref-post';
  var head = document.createElement('div');
  head.className = 'flow-head';
  head.appendChild(avatarEl(prof, p.pubkey));
  var who = document.createElement('span');
  who.className = 'flow-name';
  who.textContent = prof.name || (p.pubkey || '').slice(0, 8);
  if (!prof.name) who.classList.add('pk');
  var age = document.createElement('span');
  age.className = 'flow-age';
  age.textContent = fmtAge(p.at);
  head.append(who, age);
  var content = document.createElement('div');
  content.className = 'flow-content';
  renderText(content, p.content || '');
  item.append(head, content);
  var media = mediaOf(p.content || '');
  if (media.length) item.appendChild(attachmentsEl(media, 'thumb', null));
  item.addEventListener('click', function(e) { if (!e.target.closest('a')) openPost(p, prof); });
  return item;
}

document.getElementById('deck-prev').onclick = function() { showCard(deckIdx - 1); };
document.getElementById('deck-next').onclick = function() { showCard(deckIdx + 1); };
document.addEventListener('keydown', function(e) {
  if (e.target.closest('input, textarea') || document.querySelector('modal-dialog[open]')) return;
  if (e.key === 'ArrowLeft') showCard(deckIdx - 1);
  if (e.key === 'ArrowRight') showCard(deckIdx + 1);
});
// swipe on touch
(function() {
  var x0 = null, stage = document.getElementById('deck-stage');
  stage.addEventListener('touchstart', function(e) { x0 = e.touches[0].clientX; }, { passive: true });
  stage.addEventListener('touchend', function(e) {
    if (x0 == null) return;
    var dx = e.changedTouches[0].clientX - x0; x0 = null;
    if (Math.abs(dx) > 40) showCard(deckIdx + (dx < 0 ? 1 : -1));
  }, { passive: true });
})();
document.getElementById('panel-collapse').onclick = function() { document.getElementById('gp-split').collapse(); };

document.getElementById('btn-summon').onclick = function() {
  sendMessage('Index the current flow against my library: file the 2-3 strongest topic connections with the propose tool. Raw material only — include full post ids and the passage line range.');
};

// ---------- chat ----------

async function loadHistory() {
  var log = document.getElementById('chat-log');
  var conv;
  try {
    conv = await fetch(API + '/history').then(function(r) { return r.json(); });
  } catch (e) { conv = []; }
  if (!Array.isArray(conv)) conv = [];
  log.textContent = '';
  conv.forEach(function(m) { renderMsg(log, m); });
  log.scrollTop = log.scrollHeight;
}

function renderMsg(log, m) {
  if (!m || typeof m.content !== 'string') return;
  if (m.role === 'user') {
    var u = document.createElement('div');
    u.className = 'msg user';
    u.textContent = m.content;
    log.appendChild(u);
    return;
  }
  // assistant: interleave parts (text + tool chips) when present
  var parts = Array.isArray(m.parts) && m.parts.length
    ? m.parts
    : [{ type: 'text', text: m.content }];
  parts.forEach(function(p) {
    if (p.type === 'tool') {
      var chip = document.createElement('div');
      chip.className = 'tool-chip';
      chip.textContent = '⚙ ' + p.tool + (p.arg ? ' · ' + p.arg : '');
      log.appendChild(chip);
    } else if (p.text && p.text.trim()) {
      var a = document.createElement('div');
      a.className = 'msg asst';
      a.textContent = p.text;
      log.appendChild(a);
    }
  });
}

async function sendMessage(text) {
  if (busy || !text.trim()) return;
  busy = true;
  var log = document.getElementById('chat-log');
  var send = document.getElementById('chat-send');
  var summon = document.getElementById('btn-summon');
  send.disabled = true;
  summon.disabled = true;

  var u = document.createElement('div');
  u.className = 'msg user';
  u.textContent = text;
  log.appendChild(u);
  var pending = document.createElement('div');
  pending.className = 'msg pending';
  pending.textContent = 'the ghost is thinking…';
  log.appendChild(pending);
  log.scrollTop = log.scrollHeight;

  try {
    await fetch(API + '/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: text })
    });
  } catch (e) {}
  busy = false;
  send.disabled = false;
  summon.disabled = false;
  await loadHistory();
  loadProposals();
}

document.getElementById('chat-form').onsubmit = function(e) {
  e.preventDefault();
  var input = document.getElementById('chat-input');
  var text = input.value;
  input.value = '';
  sendMessage(text);
};

document.getElementById('chat-input').addEventListener('keydown', function(e) {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault();
    document.getElementById('chat-form').requestSubmit();
  }
});

document.getElementById('chat-clear').onclick = async function() {
  if (!confirm('Clear the conversation? (It gets archived.)')) return;
  await fetch(API + '/clear', { method: 'POST' });
  loadHistory();
};

document.getElementById('chat-stop').onclick = function() {
  fetch(API + '/stop', { method: 'POST' });
};

// ---------- config modal ----------

document.getElementById('chat-config').onclick = async function() {
  var cfg;
  try {
    cfg = await fetch(API + '/config').then(function(r) { return r.json(); });
  } catch (e) { cfg = {}; }
  document.getElementById('cfg-system').value = cfg.system || '';
  var c = cfg.config || {};
  document.getElementById('cfg-model').value = c.model || 'claude-sonnet-4-6';
  document.getElementById('cfg-max').value = c.max_tokens || 2048;
  document.getElementById('config-modal').show();
};

document.getElementById('cfg-cancel').onclick = function() {
  document.getElementById('config-modal').close();
};

document.getElementById('cfg-save').onclick = async function() {
  await fetch(API + '/config', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: document.getElementById('cfg-model').value.trim(),
      max_tokens: parseInt(document.getElementById('cfg-max').value, 10) || 2048
    })
  });
  document.getElementById('config-modal').close();
};

// ---------- boot ----------

document.getElementById('btn-refresh').onclick = function() {
  loadFeed();
  loadProposals();
  loadLibrary();
};

loadFeed();
loadProposals();
loadHistory();
setInterval(loadFeed, 120000);
