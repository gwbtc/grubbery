'use strict';
var API = '/grubbery/ghostprompter';
var busy = false;
var liveProfiles = {};   // pubkey -> profile, from the last feed load

// ---------- the flow ----------

async function loadFeed() {
  var box = document.getElementById('flow-list');
  var data;
  try {
    data = await fetch(API + '/api/feed?limit=40').then(function(r) { return r.json(); });
  } catch (e) { data = null; }
  var posts = data && Array.isArray(data.posts) ? data.posts : null;
  var profiles = (data && data.profiles) || {};
  liveProfiles = profiles;
  box.textContent = '';
  if (!posts) {
    box.innerHTML = '<div class="empty">Flow unreachable — is the nostr mirror (/apps/nostr) up?</div>';
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

// ---------- post popup: the shared viewer (lib/ui/post-viewer.js) ----------
function openPost(p, prof) {
  PostViewer.open({ post: { id: p.id, pubkey: p.pubkey, content: p.content, created_at: p.at }, profile: prof || {} });
}

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

// text and media rendering come from the shared lib (lib/ui/post-text.js,
// in ui/components.js); these names stay for the callers in this file.
function classify(url) { return PostText.classify(url); }
function mediaOf(text) { return PostText.mediaOf(text); }
function renderText(el, text) { PostText.render(el, text, {}); }
function attachmentsEl(media, mode, onMedia) { return PostText.attachments(media, mode, onMedia); }

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
var refsToken = 0;
var deck = document.getElementById('deck');
deck.render = function(p, i, isCurrent) { return cardEl(p, isCurrent); };
deck.addEventListener('cd-change', function(e) { renderRefs(e.detail.item); });

async function loadProposals() {
  try {
    props = await fetch(API + '/api/proposals').then(function(r) { return r.json(); });
  } catch (e) { props = []; }
  if (!Array.isArray(props)) props = [];
  props.sort(function(a, b) { return ((b.doc && b.doc.at) || 0) - ((a.doc && a.doc.at) || 0); });
  document.getElementById('prop-count').textContent = props.length ? props.length + ' filed' : '';
  deck.items = props;
  renderRefs(deck.current || null);
}

function cardEl(p, live) {
  var d = p.doc || {};
  var card = document.createElement('div');
  card.className = 'conn';
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

  // flow side: the cited posts, read by id from the nostr mirror.
  // Events are immutable grubs there, so this is the post exactly as
  // it was when the connection was filed; proposals without ids fall
  // back to the pasted lines
  var ids = Array.isArray(d.post_ids) ? d.post_ids.filter(Boolean) : [];
  if (ids.length) {
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
      miss.textContent = 'post ' + ids[i].slice(0, 12) + '… is not in the mirror';
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
  if (d.source) {
    var srcLink = document.createElement('a');
    srcLink.href = '#';
    srcLink.textContent = d.source;
    srcLink.addEventListener('click', function(e) { e.preventDefault(); libFm.ready.then(function() { libFm.open(d.source, { from: d.from, to: d.to }); }); });
    cite.append('— ', srcLink, d.from ? ', lines ' + d.from + (d.to && d.to !== d.from ? '–' + d.to : '') : '');
  }
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
      open.textContent = 'open ' + d.source + ' in the library';
      open.href = '#';
      open.addEventListener('click', function(e) {
        e.preventDefault();
        libFm.ready.then(function() { libFm.open(d.source, { from: d.from, to: d.to }); });
      });
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

document.getElementById('panel-collapse').onclick = function() { document.getElementById('gp-split').collapse(); };
// narrow screens: the deck is the app; the sidebar starts collapsed and
// opens as a full-width overlay from its rail
(function() {
  var split = document.getElementById('gp-split');
  var mq = window.matchMedia('(max-width: 700px)');
  function apply() {
    document.body.classList.toggle('narrow', mq.matches);
    if (mq.matches && !split.hasAttribute('collapsed')) split.collapse();
  }
  mq.addEventListener('change', apply);
  customElements.whenDefined('split-view').then(apply);
})();

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
