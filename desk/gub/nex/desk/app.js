// desk workspace — populates the shell from /state and drives the
// config / sharing / checkpoint / checkout endpoints.

var BASE = window.location.pathname;
if (!BASE.endsWith('/')) BASE += '/';
var parts = BASE.split('/').filter(Boolean);
var NAME = parts.length ? parts[parts.length - 1] : 'desk';

// the revision currently checked out into /checkout, or null for live.
var CHECKOUT = null;

// ── view switching ──
function switchView(name) {
  document.querySelectorAll('.main-tab').forEach(function (it) {
    it.classList.toggle('active', it.getAttribute('data-view') === name);
  });
  document.querySelectorAll('.view').forEach(function (v) {
    v.classList.toggle('active', v.id === 'view-' + name);
  });
  if (name === 'code' || name === 'data') loadTree(name);
}
document.querySelectorAll('.main-tab').forEach(function (it) {
  it.onclick = function () { switchView(it.getAttribute('data-view')); };
});

// ── sub-tab switching (Files / Checkpoints within an axis) ──
function switchSub(view, sub) {
  view.querySelectorAll('.subtab').forEach(function (x) {
    x.classList.toggle('active', x.getAttribute('data-sub') === sub);
  });
  view.querySelectorAll('.sub').forEach(function (s) {
    s.style.display = s.classList.contains('sub-' + sub) ? '' : 'none';
  });
}
document.querySelectorAll('.subtab').forEach(function (b) {
  b.onclick = function () { switchSub(b.closest('.view'), b.getAttribute('data-sub')); };
});

// ── config ──
function setSource() {
  var v = document.getElementById('source-version').value.trim();
  var c = document.getElementById('source-code').value.trim();
  if (!v || !c) { alert('both a version path and a code path are required'); return; }
  fetch(BASE + 'set-source', { method: 'POST', body: JSON.stringify({ version: v, code: c }) })
    .then(function () { load(); });
}
function clearSource() {
  if (!confirm('Make this desk standalone (stop following a source)?')) return;
  fetch(BASE + 'set-source', { method: 'POST', body: JSON.stringify({}) })
    .then(function () { load(); });
}
function fetchLatest() {
  fetch(BASE + 'fetch-latest', { method: 'POST' })
    .then(function (r) { if (!r.ok) r.text().then(alert); load(); });
}

// ── sharing ──
function setShare(group, on) {
  var cmd = {};
  cmd[on ? 'add' : 'remove'] = group;
  fetch(BASE + 'share', { method: 'POST', body: JSON.stringify(cmd) })
    .then(function () { load(); });
}
function addShare() {
  var g = document.getElementById('share-input').value.trim();
  if (!g) return;
  document.getElementById('share-input').value = '';
  setShare(g, true);
}
function renderShare(el, share) {
  el.innerHTML = '';
  if (!share.length) {
    var mt = document.createElement('div');
    mt.className = 'muted';
    mt.textContent = 'private — not opened to any usergroup';
    el.appendChild(mt);
    return;
  }
  share.forEach(function (g) {
    var div = document.createElement('div'); div.className = 'row';
    var span = document.createElement('span'); span.className = 'row-label';
    span.textContent = g;
    var rm = document.createElement('button');
    rm.className = 'btn btn-red'; rm.textContent = 'Remove';
    rm.onclick = function () { setShare(g, false); };
    div.appendChild(span); div.appendChild(rm); el.appendChild(div);
  });
}

// ── checkout (code only) ──
function checkout(ud) {
  fetch(BASE + 'checkout', { method: 'POST', body: JSON.stringify({ ud: ud }) })
    .then(function () { switchSub(document.getElementById('view-code'), 'files'); load(); });
}
function returnToLive() {
  fetch(BASE + 'checkout', { method: 'POST', body: JSON.stringify({}) })
    .then(function () { load(); });
}
function updateCheckoutBar() {
  var bar = document.getElementById('code-checkout-bar');
  if (!CHECKOUT) { bar.style.display = 'none'; bar.innerHTML = ''; return; }
  bar.style.display = '';
  bar.innerHTML = '';
  var span = document.createElement('span');
  span.innerHTML = '&#9670; checked out — rev <b>' + CHECKOUT.ud + '</b> · ' +
    new Date(CHECKOUT.da).toLocaleString();
  var btn = document.createElement('button');
  btn.className = 'btn'; btn.textContent = 'Return to Live';
  btn.onclick = returnToLive;
  bar.appendChild(span); bar.appendChild(btn);
}

// ── checkpoints ──
function materialize(axis, ud) {
  if (!confirm('Materialize ' + axis + ' at revision ' + ud + ' into live?')) return;
  var body = {}; body[axis] = ud;
  fetch(BASE + 'restore', { method: 'POST', body: JSON.stringify(body) })
    .then(function () { load(); });
}
function clearCkpt(axis, ud) {
  if (!confirm('Clear ' + axis + ' checkpoint at revision ' + ud + '? This frees its storage.')) return;
  fetch(BASE + 'clear', { method: 'POST', body: JSON.stringify({ axis: axis, ud: ud }) })
    .then(function () { load(); });
}
function checkpointNow(axis) {
  var label = document.getElementById(axis + '-label').value.trim();
  fetch(BASE + 'checkpoint', { method: 'POST', body: JSON.stringify({ axis: axis, label: label }) })
    .then(function () { document.getElementById(axis + '-label').value = ''; load(); });
}
function clearBefore(axis) {
  var v = document.getElementById(axis + '-clear-before').value.trim();
  var n = parseInt(v, 10);
  if (!v || isNaN(n)) { alert('enter a revision number'); return; }
  if (!confirm('Clear all ' + axis + ' checkpoints at or before rev ' + n +
    '? Frees their storage; the live desk is untouched.')) return;
  fetch(BASE + 'clear-checkpoints', { method: 'POST', body: JSON.stringify({ axis: axis, before: n }) })
    .then(function () { document.getElementById(axis + '-clear-before').value = ''; load(); });
}
function clearAllCkpts(axis) {
  if (!confirm('Clear ALL ' + axis + ' checkpoints except the current top?' +
    ' Frees their storage; the live desk is untouched.')) return;
  fetch(BASE + 'clear-checkpoints', { method: 'POST', body: JSON.stringify({ axis: axis }) })
    .then(function () { load(); });
}
function ckptLabel(tags) {
  var out = tags.filter(function (t) { return t !== 'checkpoint'; });
  return out.length ? out.join(' ') : null;
}
function renderList(el, rows, axis) {
  el.innerHTML = '';
  if (!rows.length) { el.innerHTML = '<div class="muted" style="padding:8px 4px">no checkpoints yet</div>'; return; }
  var table = document.createElement('div'); table.className = 'ckpt-table';
  var head = document.createElement('div'); head.className = 'ckpt-row ckpt-head';
  ['label', 'rev', 'when', ''].forEach(function (h) {
    var s = document.createElement('span'); s.textContent = h; head.appendChild(s);
  });
  table.appendChild(head);
  rows.slice().reverse().forEach(function (r) {
    var row = document.createElement('div'); row.className = 'ckpt-row';
    var isOut = axis === 'code' && CHECKOUT && CHECKOUT.ud === r.ud;
    if (isOut) row.classList.add('sel');
    var v = ckptLabel(r.tags);
    var lab = document.createElement('span'); lab.className = 'ckpt-label';
    lab.textContent = v || '—'; if (!v) lab.classList.add('muted');
    var rev = document.createElement('span'); rev.className = 'ckpt-rev'; rev.textContent = r.ud;
    var when = document.createElement('span'); when.className = 'ckpt-when';
    when.textContent = new Date(r.da).toLocaleString();
    var acts = document.createElement('span'); acts.className = 'ckpt-acts';
    // Checkout is a code-only, non-destructive inspection of a revision.
    if (axis === 'code') {
      var co = document.createElement('button');
      co.className = isOut ? 'btn btn-grn' : 'btn';
      co.textContent = isOut ? 'Checked out' : 'Checkout';
      co.disabled = !!isOut;
      co.onclick = function () { checkout(r.ud); };
      acts.appendChild(co);
    }
    var mat = document.createElement('button');
    mat.className = 'btn btn-grn'; mat.textContent = 'Materialize';
    mat.onclick = function () { materialize(axis, r.ud); };
    var clr = document.createElement('button');
    clr.className = 'btn btn-red'; clr.textContent = 'Clear';
    clr.onclick = function () { clearCkpt(axis, r.ud); };
    acts.appendChild(mat); acts.appendChild(clr);
    row.appendChild(lab); row.appendChild(rev); row.appendChild(when); row.appendChild(acts);
    table.appendChild(row);
  });
  el.appendChild(table);
}

// ── file tree + viewer (reads live, or /checkout when checked out) ──
function loadTree(axis) {
  fetch(BASE + 'tree/' + axis).then(function (r) { return r.json(); }).then(function (t) {
    renderTree(document.getElementById(axis + '-tree'), axis, t.files);
  }).catch(function () { });
}
function buildTree(files) {
  var root = { dirs: {}, files: [] };
  files.forEach(function (f) {
    var segs = f.path === '/' ? [] : f.path.split('/').filter(Boolean);
    var node = root;
    segs.forEach(function (s) {
      if (!node.dirs[s]) node.dirs[s] = { dirs: {}, files: [] };
      node = node.dirs[s];
    });
    node.files.push(f);
  });
  return root;
}
function renderNode(parent, axis, node) {
  Object.keys(node.dirs).sort().forEach(function (name) {
    var det = document.createElement('details'); det.open = true; det.className = 'tree-dir';
    var sum = document.createElement('summary'); sum.textContent = name;
    det.appendChild(sum);
    var kids = document.createElement('div'); kids.className = 'tree-kids';
    renderNode(kids, axis, node.dirs[name]);
    det.appendChild(kids); parent.appendChild(det);
  });
  node.files.sort(function (a, b) { return a.name < b.name ? -1 : 1; }).forEach(function (f) {
    var full = (f.path === '/' ? '' : f.path) + '/' + f.name;
    var row = document.createElement('div'); row.className = 'tree-file';
    row.setAttribute('data-full', full);
    var nm = document.createElement('span'); nm.textContent = f.name;
    var bl = document.createElement('span'); bl.className = 'muted'; bl.textContent = f.blot;
    row.appendChild(nm); row.appendChild(bl);
    row.onclick = function () { openFile(axis, full); };
    parent.appendChild(row);
  });
}
function renderTree(el, axis, files) {
  el.innerHTML = '';
  if (!files.length) {
    var mt = document.createElement('div'); mt.className = 'tree-empty muted'; mt.textContent = '(empty)';
    el.appendChild(mt); return;
  }
  var body = document.createElement('div'); body.className = 'tree-body';
  renderNode(body, axis, buildTree(files));
  el.appendChild(body);
}
function openFile(axis, full) {
  document.querySelectorAll('#' + axis + '-tree .tree-file').forEach(function (r) {
    r.classList.toggle('sel', r.getAttribute('data-full') === full);
  });
  fetch(BASE + 'cat/' + axis + '?path=' + full).then(function (r) { return r.json(); }).then(function (d) {
    renderViewer(document.getElementById(axis + '-view'), d, axis);
  }).catch(function () { });
}

// ── shiki syntax highlighting (loaded on demand, plain-text fallback) ──
var shikiHl = null, shikiTried = false;
function ensureShiki() {
  if (shikiHl || shikiTried) return Promise.resolve(shikiHl);
  shikiTried = true;
  return import('https://esm.sh/shiki@1.24.0').then(function (m) {
    return fetch('/grubbery/ball/apps/explorer.explorer/hoon-grammar.json')
      .then(function (r) { return r.json(); })
      .then(function (grammar) {
        return m.createHighlighter({
          themes: ['github-dark'],
          langs: [grammar, 'json', 'javascript', 'css', 'xml', 'markdown']
        });
      });
  }).then(function (hl) { shikiHl = hl; return hl; }).catch(function () { return null; });
}
function langForName(name) {
  var m = /\.([a-z0-9]+)$/i.exec(name);
  var ext = m ? m[1].toLowerCase() : '';
  var map = {
    hoon: 'hoon', js: 'javascript', mjs: 'javascript', json: 'json',
    css: 'css', svg: 'xml', xml: 'xml', html: 'xml', md: 'markdown', markdown: 'markdown'
  };
  return map[ext] || null;
}
function renderViewer(el, d, axis) {
  el.innerHTML = '';
  var name = (d.path || '').split('/').filter(Boolean).pop() || '';
  var head = document.createElement('div'); head.className = 'vp-head';
  var t = document.createElement('span'); t.className = 'vp-title'; t.textContent = d.path || '';
  var b = document.createElement('span'); b.className = 'vp-blot muted';
  b.textContent = d.type || d.blot || '';
  head.appendChild(t); head.appendChild(b); el.appendChild(head);
  var body = document.createElement('div'); body.className = 'vp-body'; el.appendChild(body);
  if (d.text != null) {
    var pre = document.createElement('pre'); pre.textContent = d.text; body.appendChild(pre);
    var lang = langForName(name);
    if (!lang) return;
    ensureShiki().then(function (hl) {
      if (!hl) return;
      try { body.innerHTML = hl.codeToHtml(d.text, { lang: lang, theme: 'github-dark' }); }
      catch (e) { }
    });
    return;
  }
  if (d.type && d.type.indexOf('image/') === 0) {
    var img = document.createElement('img'); img.className = 'vp-img';
    img.src = BASE + 'raw/' + axis + '?path=' + (d.path || '');
    body.appendChild(img); return;
  }
  var mt = document.createElement('div'); mt.className = 'vp-reason';
  mt.textContent = d.reason || 'not viewable (no diagnostic returned)';
  body.appendChild(mt);
}

// ── load ──
function load() {
  fetch(BASE + 'state').then(function (r) { return r.json(); }).then(function (s) {
    CHECKOUT = s.checkout || null;
    document.getElementById('tb-name').textContent = NAME;
    var src = s.source || null;
    document.getElementById('source-version').value = src ? src.version : '';
    document.getElementById('source-code').value = src ? src.code : '';
    document.getElementById('tb-source').textContent = src ? src.code : '';
    var st = document.getElementById('tb-status');
    st.textContent = src ? 'following' : 'standalone';
    st.classList.toggle('off', !src);
    document.getElementById('fetch-btn').style.display = src ? '' : 'none';
    document.getElementById('sb-version').textContent =
      'version ' + (s.version || '—') + (src ? ' · ' + src.code : '');
    updateCheckoutBar();
    renderShare(document.getElementById('share-list'), s.share || []);
    renderList(document.getElementById('code-ckpts'), s.code, 'code');
    renderList(document.getElementById('data-ckpts'), s.data, 'data');
    var active = document.querySelector('.main-tab.active');
    var cur = active ? active.getAttribute('data-view') : null;
    if (cur === 'code' || cur === 'data') loadTree(cur);
  });
}

switchView('code');
load();
