// desk workspace — Files (browse code/data, live or checkout),
// Snapshots (world history + compose live), Config (source + sharing).

var BASE = window.location.pathname;
if (!BASE.endsWith('/')) BASE += '/';
var parts = BASE.split('/').filter(Boolean);
var NAME = parts.length ? parts[parts.length - 1] : 'desk';

var CHECKOUT = null;   // world snapshot N checked out, or null (live)
var SNAPS = [];        // [{n, da, tags}] newest first
var AXIS = 'code';     // Files: which axis
var MODE = 'live';     // Files: view the live dir vs the /checkout dir

// ── request loading bar (indeterminate; shown while any fetch is in flight) ──
// wraps window.fetch once so every request — no matter the call site — drives
// the bar. mirrors the forge's load-bar.
var _inflight = 0, _loadBar = null;
function _loadBarEl() {
  if (!_loadBar) { _loadBar = document.createElement('div'); _loadBar.id = 'load-bar'; document.body.appendChild(_loadBar); }
  return _loadBar;
}
(function () {
  var _fetch = window.fetch.bind(window);
  window.fetch = function (u, o) {
    if (_inflight++ === 0) _loadBarEl().classList.add('active');
    var done = function () { if (--_inflight <= 0) { _inflight = 0; _loadBarEl().classList.remove('active'); } };
    return _fetch(u, o).then(function (r) { done(); return r; }, function (e) { done(); throw e; });
  };
})();

// ── top-level tabs ──
function switchView(name) {
  document.querySelectorAll('.main-tab').forEach(function (it) {
    it.classList.toggle('active', it.getAttribute('data-view') === name);
  });
  document.querySelectorAll('.view').forEach(function (v) {
    v.classList.toggle('active', v.id === 'view-' + name);
  });
  if (name === 'files') loadTree();
  if (name === 'source') loadIncoming();
}
document.querySelectorAll('.main-tab').forEach(function (it) {
  it.onclick = function () { switchView(it.getAttribute('data-view')); };
});

// ── Files toggles (axis + mode) ──
document.querySelectorAll('#axis-seg .seg-btn').forEach(function (b) {
  b.onclick = function () {
    AXIS = b.getAttribute('data-axis');
    document.querySelectorAll('#axis-seg .seg-btn').forEach(function (x) {
      x.classList.toggle('active', x === b);
    });
    loadTree();
  };
});
// snapshot selector: which snapshot to check out (— none — = clear)
document.getElementById('snap-select').onchange = function () {
  if (this.value === 'none') returnToLive();
  else checkout(parseInt(this.value, 10));
};
// mode toggle: while checked out, view the live dir vs the checkout
document.querySelectorAll('#mode-seg .seg-btn').forEach(function (b) {
  b.onclick = function () {
    MODE = b.getAttribute('data-mode');
    document.querySelectorAll('#mode-seg .seg-btn').forEach(function (x) {
      x.classList.toggle('active', x === b);
    });
    updateFilesLabels();
    loadTree();
  };
});
function modeParam() { return MODE; }
function updateSnapSelect() {
  var sel = document.getElementById('snap-select');
  sel.innerHTML = '';
  sel.appendChild(new Option('— none —', 'none'));
  SNAPS.forEach(function (r) { sel.appendChild(new Option(snapLabel(r), String(r.n))); });
  sel.value = (CHECKOUT == null) ? 'none' : String(CHECKOUT);
  document.querySelectorAll('#mode-seg .seg-btn').forEach(function (x) {
    x.classList.toggle('active', x.getAttribute('data-mode') === MODE);
  });
  var note = document.getElementById('files-note');
  note.innerHTML = (MODE === 'live') ? ''
    : (CHECKOUT == null) ? 'checkout is empty — nothing checked out'
    : 'inert &mdash; inspecting snapshot <b>' + CHECKOUT + '</b>';
  updateFilesLabels();
}
// labels for the checked-out snapshot, editable inline in the Files view.
// Shown only when a snapshot is actually checked out; opens the same modal.
function updateFilesLabels() {
  var fl = document.getElementById('files-labels');
  fl.innerHTML = '';
  if (MODE !== 'checkout' || CHECKOUT == null) { fl.style.display = 'none'; return; }
  fl.style.display = '';
  fl.onclick = function () { openLabels(CHECKOUT); };
  var snap = null;
  SNAPS.forEach(function (r) { if (r.n === CHECKOUT) snap = r; });
  var tags = (snap && snap.tags) || [];
  if (!tags.length) {
    var add = document.createElement('span'); add.className = 'lbl-add'; add.textContent = '+ label';
    fl.appendChild(add);
  } else {
    tags.forEach(function (t) {
      var chip = document.createElement('span'); chip.className = 'tag-chip ro';
      chip.textContent = t; fl.appendChild(chip);
    });
  }
}

// ── config ──
function setSource() {
  var c = document.getElementById('source-code').value.trim();
  if (!c) { alert('a code path is required'); return; }
  fetch(BASE + 'set-source', { method: 'POST', body: JSON.stringify({ code: c }) })
    .then(function () { load(); });
}
function fetchLatest() {
  fetch(BASE + 'fetch-latest', { method: 'POST' })
    .then(function (r) { if (!r.ok) r.text().then(alert); load(); loadIncoming(); });
}

// ── Incoming: how far the source is ahead of our /desk/code head ──
function loadIncoming() {
  var head = document.getElementById('incoming-headline');
  var list = document.getElementById('incoming-list');
  if (head) { head.className = 'inc-headline muted'; head.textContent = 'checking source…'; }
  if (list) list.textContent = '';
  fetch(BASE + 'source-diff').then(function (r) { return r.json(); }).then(renderIncoming)
    .catch(function () { if (head) head.textContent = 'could not read source'; });
}
function renderIncoming(d) {
  var head = document.getElementById('incoming-headline');
  var list = document.getElementById('incoming-list');
  var changes = (d && d.changes) || [];
  var sv = (d && d.sourceVersion) || null, ov = (d && d.ownVersion) || null;
  if (head) {
    if (!d || !d.hasSource) { head.className = 'inc-headline muted'; head.textContent = 'no source configured'; }
    else {
      head.className = 'inc-headline';
      var lead = changes.length
        ? changes.length + ' incoming change' + (changes.length === 1 ? '' : 's')
        : 'up to date';
      var vers = (sv || ov) ? ' — source ' + (sv || '—') + ', head ' + (ov || '—') : '';
      head.textContent = lead + vers;
    }
  }
  if (!list) return;
  list.textContent = '';
  if (!changes.length) {
    var e = document.createElement('div');
    e.className = 'muted'; e.style.padding = '8px 4px'; e.textContent = 'nothing to pull';
    list.appendChild(e); return;
  }
  var rank = { add: 0, modify: 1, remove: 2 };
  changes.slice().sort(function (a, b) {
    return (rank[a.status] - rank[b.status]) || (a.path < b.path ? -1 : a.path > b.path ? 1 : 0);
  }).forEach(function (c) {
    var row = document.createElement('div'); row.className = 'inc-row';
    var mk = document.createElement('span');
    mk.className = 'inc-mark inc-' + c.status;
    mk.textContent = c.status === 'add' ? 'A' : c.status === 'remove' ? 'D' : 'M';
    mk.title = c.status;
    var pth = document.createElement('span'); pth.className = 'inc-path'; pth.textContent = c.path;
    row.appendChild(mk); row.appendChild(pth);
    list.appendChild(row);
  });
}

// ── sharing ──
function setShare(group, on) {
  var cmd = {}; cmd[on ? 'add' : 'remove'] = group;
  fetch(BASE + 'share', { method: 'POST', body: JSON.stringify(cmd) }).then(function () { load(); });
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
    var mt = document.createElement('div'); mt.className = 'muted';
    mt.textContent = 'private — not opened to any usergroup';
    el.appendChild(mt); return;
  }
  share.forEach(function (g) {
    var div = document.createElement('div'); div.className = 'row';
    var span = document.createElement('span'); span.className = 'row-label'; span.textContent = g;
    var rm = document.createElement('button');
    rm.className = 'btn btn-red'; rm.textContent = 'Remove';
    rm.onclick = function () { setShare(g, false); };
    div.appendChild(span); div.appendChild(rm); el.appendChild(div);
  });
}

// ── snapshots ──
function snapshotNow() {
  fetch(BASE + 'snapshot', { method: 'POST', body: '{}' }).then(function () { load(); });
}
function checkout(n) {
  MODE = 'checkout';  // default to viewing what you just checked out
  fetch(BASE + 'checkout', { method: 'POST', body: JSON.stringify({ n: n }) })
    .then(function () { load(); });
}
function returnToLive() {
  fetch(BASE + 'checkout', { method: 'POST', body: JSON.stringify({}) }).then(function () { load(); });
}
function clearSnap(n) {
  if (!confirm('Clear snapshot ' + n + '? Frees its storage; live is untouched.')) return;
  fetch(BASE + 'clear', { method: 'POST', body: JSON.stringify({ n: n }) }).then(function () { load(); });
}
function clearUntil(n) {
  if (!confirm('Clear every snapshot up to and including ' + n +
    '? Frees their storage; live is untouched.')) return;
  fetch(BASE + 'clear-until', { method: 'POST', body: JSON.stringify({ before: n }) })
    .then(function () { load(); });
}
function addTag(n, tag) {
  tag = (tag || '').trim();
  if (!tag) return;
  if (/^\d+$/.test(tag)) { alert('Numeric labels are reserved for snapshot identity.'); return; }
  return fetch(BASE + 'tag-add', { method: 'POST', body: JSON.stringify({ n: n, tag: tag }) })
    .then(function () { load(); });
}
function delTag(n, tag) {
  return fetch(BASE + 'tag-del', { method: 'POST', body: JSON.stringify({ n: n, tag: tag }) })
    .then(function () { load(); });
}

// ── labels modal ──
var LABELS_N = null;
function openLabels(n) {
  LABELS_N = n;
  renderLabelsModal();
  document.getElementById('labels-back').classList.add('open');
  var inp = document.getElementById('labels-input'); if (inp) inp.focus();
}
function closeLabels() {
  document.getElementById('labels-back').classList.remove('open');
  LABELS_N = null;
}
function renderLabelsModal() {
  if (LABELS_N == null) return;
  var snap = null;
  SNAPS.forEach(function (r) { if (r.n === LABELS_N) snap = r; });
  document.getElementById('labels-n').textContent = LABELS_N;
  var chips = document.getElementById('labels-chips');
  chips.innerHTML = '';
  var tags = (snap && snap.tags) || [];
  if (!tags.length) {
    chips.innerHTML = '<div class="muted" style="padding:2px 0 6px">no labels yet</div>';
  }
  tags.forEach(function (t) {
    var chip = document.createElement('span'); chip.className = 'tag-chip';
    var txt = document.createElement('span'); txt.textContent = t; chip.appendChild(txt);
    var x = document.createElement('button'); x.className = 'tag-x'; x.textContent = '×';
    x.title = 'remove'; x.onclick = function () { delTag(LABELS_N, t); };
    chip.appendChild(x); chips.appendChild(chip);
  });
}
function submitLabel() {
  var inp = document.getElementById('labels-input');
  var v = inp.value;
  var p = addTag(LABELS_N, v);
  if (p) { inp.value = ''; inp.focus(); }
}
function renderSnaps(el) {
  el.innerHTML = '';
  if (!SNAPS.length) { el.innerHTML = '<div class="muted" style="padding:8px 4px">no snapshots yet</div>'; return; }
  var table = document.createElement('div'); table.className = 'ckpt-table';
  var head = document.createElement('div'); head.className = 'ckpt-row ckpt-head';
  ['snapshot', 'when', 'labels', ''].forEach(function (h) {
    var s = document.createElement('span'); s.textContent = h; head.appendChild(s);
  });
  table.appendChild(head);
  SNAPS.forEach(function (r) {
    var isOut = CHECKOUT != null && CHECKOUT === r.n;
    var row = document.createElement('div'); row.className = 'ckpt-row';
    if (isOut) row.classList.add('sel');
    var num = document.createElement('span'); num.className = 'ckpt-rev'; num.textContent = r.n;
    var when = document.createElement('span'); when.className = 'ckpt-when';
    when.textContent = new Date(r.da).toLocaleString();
    var labels = document.createElement('span'); labels.className = 'ckpt-labels';
    labels.title = 'edit labels';
    labels.onclick = function () { openLabels(r.n); };
    var tags = r.tags || [];
    if (!tags.length) {
      var add = document.createElement('span'); add.className = 'lbl-add'; add.textContent = '+ label';
      labels.appendChild(add);
    } else {
      tags.forEach(function (t) {
        var chip = document.createElement('span'); chip.className = 'tag-chip ro';
        chip.textContent = t; labels.appendChild(chip);
      });
    }
    var acts = document.createElement('span'); acts.className = 'ckpt-acts';
    var co = document.createElement('button');
    co.className = isOut ? 'btn btn-grn' : 'btn';
    co.textContent = isOut ? 'Checked out' : 'Checkout';
    co.disabled = !!isOut;
    co.onclick = function () { checkout(r.n); };
    var clr = document.createElement('button');
    clr.className = 'btn btn-red'; clr.textContent = 'Clear';
    clr.onclick = function () { clearSnap(r.n); };
    var clu = document.createElement('button');
    clu.className = 'btn btn-red'; clu.textContent = 'Clear Until';
    clu.title = 'clear this and all older snapshots';
    clu.onclick = function () { clearUntil(r.n); };
    acts.appendChild(co); acts.appendChild(clr); acts.appendChild(clu);
    row.appendChild(num); row.appendChild(when); row.appendChild(labels); row.appendChild(acts);
    table.appendChild(row);
  });
  el.appendChild(table);
}

// ── compose live ──
function snapLabel(r) {
  var s = 'snapshot ' + r.n;
  if (r.tags && r.tags.length) s += ' · ' + r.tags.join(', ');
  return s;
}
function openCompose() {
  var codeSel = document.getElementById('compose-code');
  var dataSel = document.getElementById('compose-data');
  codeSel.innerHTML = '';
  dataSel.innerHTML = '';
  codeSel.appendChild(new Option('keep live code', 'live'));
  dataSel.appendChild(new Option('keep live data', 'live'));
  SNAPS.forEach(function (r) {
    codeSel.appendChild(new Option(snapLabel(r), String(r.n)));
    dataSel.appendChild(new Option(snapLabel(r), String(r.n)));
  });
  document.getElementById('compose-back').classList.add('open');
}
function closeCompose() { document.getElementById('compose-back').classList.remove('open'); }
function doCompose() {
  var code = document.getElementById('compose-code').value;
  var data = document.getElementById('compose-data').value;
  var body = {
    code: (code === 'live') ? 'live' : parseInt(code, 10),
    data: (data === 'live') ? 'live' : parseInt(data, 10)
  };
  var summary = 'Compose live — code: ' + code + ', data: ' + data +
    '.\nThe current world is snapshotted first. Continue?';
  if (!confirm(summary)) return;
  fetch(BASE + 'compose', { method: 'POST', body: JSON.stringify(body) })
    .then(function () { closeCompose(); load(); });
}
document.addEventListener('keydown', function (e) { if (e.key === 'Escape') closeCompose(); });

// ── file tree + viewer ──
function loadTree() {
  var split = document.querySelector('#view-files .split');
  if (split) split.classList.add('busy');
  var done = function () { if (split) split.classList.remove('busy'); };
  fetch(BASE + 'tree/' + AXIS + '?mode=' + modeParam())
    .then(function (r) { return r.json(); }).then(function (t) {
      renderTree(document.getElementById('file-tree'), t.files, t.necks || []);
      done();
    }).catch(done);
}
function buildTree(files) {
  var root = { dirs: {}, files: [], path: '' };
  files.forEach(function (f) {
    var segs = f.path === '/' ? [] : f.path.split('/').filter(Boolean);
    var node = root, p = '';
    segs.forEach(function (s) {
      p += '/' + s;
      if (!node.dirs[s]) node.dirs[s] = { dirs: {}, files: [], path: p };
      node = node.dirs[s];
    });
    node.files.push(f);
  });
  return root;
}
function renderNode(parent, node, neckMap) {
  Object.keys(node.dirs).sort().forEach(function (name) {
    var child = node.dirs[name];
    var det = document.createElement('details'); det.open = true; det.className = 'tree-dir';
    var sum = document.createElement('summary'); sum.title = name;
    var dn = document.createElement('span'); dn.className = 'tree-dirname'; dn.textContent = name;
    sum.appendChild(dn);
    var nk = neckMap && neckMap[child.path];
    if (nk) {
      var badge = document.createElement('span'); badge.className = 'nexus-badge';
      badge.textContent = nk; badge.title = 'nexus · governed by ' + nk;
      sum.appendChild(badge);
    }
    det.appendChild(sum);
    var kids = document.createElement('div'); kids.className = 'tree-kids';
    renderNode(kids, child, neckMap);
    det.appendChild(kids); parent.appendChild(det);
  });
  node.files.sort(function (a, b) { return a.name < b.name ? -1 : 1; }).forEach(function (f) {
    var full = (f.path === '/' ? '' : f.path) + '/' + f.name;
    var row = document.createElement('div'); row.className = 'tree-file';
    row.setAttribute('data-full', full);
    var nm = document.createElement('span'); nm.textContent = f.name; nm.title = full;
    var bl = document.createElement('span'); bl.className = 'muted'; bl.textContent = f.blot;
    row.appendChild(nm); row.appendChild(bl);
    row.onclick = function () { openFile(full); };
    parent.appendChild(row);
  });
}
function renderTree(el, files, necks) {
  el.innerHTML = '';
  if (!files.length) {
    var mt = document.createElement('div'); mt.className = 'tree-empty muted'; mt.textContent = '(empty)';
    el.appendChild(mt); return;
  }
  var neckMap = {};
  (necks || []).forEach(function (n) { neckMap[n.path] = n.neck; });
  var body = document.createElement('div'); body.className = 'tree-body';
  renderNode(body, buildTree(files), neckMap);
  el.appendChild(body);
}
function openFile(full) {
  document.querySelectorAll('#file-tree .tree-file').forEach(function (r) {
    r.classList.toggle('sel', r.getAttribute('data-full') === full);
  });
  fetch(BASE + 'cat/' + AXIS + '?path=' + full + '&mode=' + modeParam())
    .then(function (r) { return r.json(); }).then(function (d) {
      renderViewer(document.getElementById('file-view'), d);
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
        return m.createHighlighter({ themes: ['github-dark'], langs: [grammar, 'json', 'javascript', 'css', 'xml', 'markdown'] });
      });
  }).then(function (hl) { shikiHl = hl; return hl; }).catch(function () { return null; });
}
function langForName(name) {
  var m = /\.([a-z0-9]+)$/i.exec(name);
  var ext = m ? m[1].toLowerCase() : '';
  var map = { hoon: 'hoon', js: 'javascript', mjs: 'javascript', json: 'json', css: 'css', svg: 'xml', xml: 'xml', html: 'xml', md: 'markdown', markdown: 'markdown' };
  return map[ext] || null;
}
// remembers each file's Source|Preview choice across re-renders, keyed by path.
var PV = {};
function renderViewer(el, d) {
  el.innerHTML = '';
  var name = (d.path || '').split('/').filter(Boolean).pop() || '';
  var head = document.createElement('div'); head.className = 'vp-head';
  var t = document.createElement('span'); t.className = 'vp-title'; t.textContent = d.path || '';
  var b = document.createElement('span'); b.className = 'vp-blot muted'; b.textContent = d.type || d.blot || '';
  head.appendChild(t); head.appendChild(b);
  // svg/html arrive as text — offer a Source|Preview toggle (raster has no source).
  var fp = window.FilePreview;
  var pk = fp ? fp.kind(name) : null;
  var textPreview = (pk === 'svg' || pk === 'html') && d.text != null;
  if (textPreview) {
    var view = PV[d.path] || 'source';
    var tg = document.createElement('div'); tg.className = 'vp-view';
    ['source', 'preview'].forEach(function (v) {
      var btn = document.createElement('button');
      btn.className = 'vp-vtab' + (v === view ? ' active' : '');
      btn.textContent = v === 'source' ? 'Source' : 'Preview';
      btn.onclick = function () { PV[d.path] = v; renderViewer(el, d); };
      tg.appendChild(btn);
    });
    head.appendChild(tg);
  }
  el.appendChild(head);
  var body = document.createElement('div'); body.className = 'vp-body'; el.appendChild(body);
  if (textPreview && (PV[d.path] || 'source') === 'preview') {
    fp.render(body, { name: name, text: d.text }); return;
  }
  if (d.text != null) {
    var pre = document.createElement('pre'); pre.textContent = d.text; body.appendChild(pre);
    var lang = langForName(name);
    if (!lang) return;
    ensureShiki().then(function (hl) {
      if (!hl) return;
      try { body.innerHTML = hl.codeToHtml(d.text, { lang: lang, theme: 'github-dark' }); } catch (e) { }
    });
    return;
  }
  if (d.type && d.type.indexOf('image/') === 0) {
    var rawUrl = BASE + 'raw/' + AXIS + '?path=' + (d.path || '') + '&mode=' + modeParam();
    if (fp && fp.render(body, { name: name, rawUrl: rawUrl })) return;
    var img = document.createElement('img'); img.className = 'vp-img'; img.src = rawUrl;
    body.appendChild(img); return;
  }
  var mt = document.createElement('div'); mt.className = 'vp-reason';
  mt.textContent = d.reason || 'not viewable';
  body.appendChild(mt);
}

// ── load ──
function load() {
  fetch(BASE + 'state').then(function (r) { return r.json(); }).then(function (s) {
    CHECKOUT = (s.checkout == null) ? null : s.checkout;
    SNAPS = s.snapshots || [];
    document.getElementById('tb-name').textContent = NAME;
    var src = s.source || null;
    document.getElementById('source-code').value = src ? src.code : '';
    document.getElementById('tb-source').textContent = src ? src.code : '';
    var st = document.getElementById('tb-status');
    st.textContent = src ? 'following' : 'no source';
    st.classList.toggle('off', !src);
    document.getElementById('fetch-btn').style.display = src ? '' : 'none';
    document.getElementById('sb-version').textContent =
      'version ' + (s.version || '—') + (src ? ' · ' + src.code : '');
    var snapBtn = document.getElementById('snap-now-btn');
    if (snapBtn) {
      snapBtn.disabled = !s.dirty;
      snapBtn.title = s.dirty ? '' : 'live matches the latest snapshot — nothing to capture';
    }
    renderShare(document.getElementById('share-list'), s.share || []);
    renderSnaps(document.getElementById('snap-list'));
    if (LABELS_N != null) renderLabelsModal();
    updateSnapSelect();
    var active = document.querySelector('.main-tab.active');
    if (active && active.getAttribute('data-view') === 'files') loadTree();
  });
}

document.getElementById('labels-input').addEventListener('keydown', function (e) {
  if (e.key === 'Enter') { e.preventDefault(); submitLabel(); }
  else if (e.key === 'Escape') closeLabels();
});

switchView('files');
load();
