// Grubbery docs reader. Static shell + data endpoints: pull the nav tree,
// pull one doc's raw markdown on demand, render client-side with marked.
// Sidebar is a recursive tree (sections + docs). Search lives in the top-right
// input; ⌘K focuses it; results drop down beneath it from the server-side
// /search endpoint (the ship greps its own grubs).
'use strict';

var BASE = '/apps/grubbery/docs';
var NAV = document.getElementById('nav');
var DOC = document.getElementById('doc');
var WRAP = document.getElementById('search-wrap');
var INPUT = document.getElementById('search-input');
var RESULTS = document.getElementById('search-results');

var tree = [];
var leaves = [];
var textCache = {};
var results = [];   // current search hits
var sel = -1;       // highlighted result index
var searchTimer = null;

// multi-collection routing. A collection IS its target path; the hash is
// #<collection-path>/<tail> where tail is a doc name or "coverage". Empty
// hash → the index. CUR is the collection currently in view.
var COLLECTIONS = [];   // the registry: list of {path, docs} entries
var CUR = '';           // current collection path (empty on the index)
var CUR_SECTION = '';   // active coverage section (empty = whole collection)

// collPath: a registry entry's target path. Entries are {path, docs} objects
// (docs = the handbook's subpath within the target, server-side only). The
// browser keys everything off the path.
function collPath(c) { return c.path; }

// hashFor: the URL hash for a doc/coverage within the current collection.
function hashFor(tail) { return '#' + CUR + (tail ? '/' + tail : ''); }
// withC: scope a per-collection API url to the current collection. The hash
// is client-only, so the collection path rides on the request as ?c=<path>.
function withC(url) { return CUR ? url + (url.indexOf('?') >= 0 ? '&' : '?') + 'c=' + encodeURIComponent(CUR) : url; }
// matchCollection: the registered collection whose path is a prefix of h
// (longest wins; collections don't nest, so at most one matches meaningfully).
function matchCollection(h, cols) {
  var best = '';
  cols.forEach(function (c) {
    var p = collPath(c);
    if ((h === p || h.indexOf(p + '/') === 0) && p.length > best.length) best = p;
  });
  return best;
}
// collLabel: the display name for a collection — its path's last segment.
function collLabel(path) {
  var segs = path.split('/').filter(Boolean);
  return segs.length ? segs[segs.length - 1] : path;
}

// ---- helpers ----

function escHtml(s) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function el(tag, cls, text) {
  var e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text !== undefined && text !== null) e.textContent = text;
  return e;
}

// a code-shaped shimmer placeholder: n bars of varied width + indent so an
// in-flight snippet reads as code loading, not a bare "loading…" line.
function codeSkeleton(n) {
  var widths = [46, 78, 62, 88, 40, 70, 54, 82, 34, 66];
  var indents = [0, 14, 14, 28, 14, 0, 14, 28, 14, 0];
  var wrap = el('div', 'code-sk');
  var rows = Math.max(3, Math.min(n || 6, 12));
  for (var i = 0; i < rows; i++) {
    var bar = el('i');
    bar.style.width = widths[i % widths.length] + '%';
    bar.style.marginLeft = indents[i % indents.length] + 'px';
    wrap.appendChild(bar);
  }
  return wrap;
}
// rows to draw for a snippet whose range reads like "12-40"; a guess, capped.
function rangeRows(spec) {
  var m = /(\d+)\s*[-–]\s*(\d+)/.exec(spec || '');
  return m ? (Number(m[2]) - Number(m[1]) + 1) : 6;
}

function highlight(text, q) {
  var out = escHtml(text);
  var re = new RegExp('(' + q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ')', 'ig');
  return out.replace(re, '<mark>$1</mark>');
}

function collectLeaves(items, out) {
  items.forEach(function (it) {
    if (it.path) out.push({ path: it.path, title: it.title });
    if (it.kids) collectLeaves(it.kids, out);
  });
  return out;
}

function render(md) {
  DOC.innerHTML = window.marked ? marked.parse(md) : '<pre></pre>';
  if (!window.marked) DOC.querySelector('pre').textContent = md;
  upgradeLiveBlocks();
  upgradeStaticBlocks();
}

// Syntax-highlight ordinary fenced code blocks (```hoon, ```js, ```css,
// ```json) with the same shiki + pkova grammar the live embeds use.
function upgradeStaticBlocks() {
  var blocks = DOC.querySelectorAll('pre > code[class*="language-"]');
  for (var i = 0; i < blocks.length; i++) {
    (function (code) {
      var cls = code.className || '';
      if (cls.indexOf('language-live') > -1) return;
      var m = cls.match(/language-([\w-]+)/);
      if (!m) return;
      var lang = m[1] === 'js' ? 'javascript' : m[1];
      if (['hoon', 'javascript', 'css', 'json'].indexOf(lang) < 0) return;
      var text = code.textContent;
      var pre = code.parentElement;
      ensureShiki().then(function (hl) {
        if (!hl) return;
        try {
          var tmp = document.createElement('div');
          tmp.innerHTML = hl.codeToHtml(text, { lang: lang, theme: 'github-light' });
          if (tmp.firstChild) pre.replaceWith(tmp.firstChild);
        } catch (e) { /* leave plain */ }
      });
    })(blocks[i]);
  }
}

// ---- live code embeds ----
// A ```live fenced block whose body is "<path> [from-to]" is replaced with
// the actual lines of that file, read live from the running ship via the
// explorer's ball endpoint, and highlighted with shiki + the pkova Hoon
// grammar (same setup forge/explorer use). Never drifts — it's live source.

var shikiP = null;

function ensureShiki() {
  if (shikiP) return shikiP;
  shikiP = import('https://esm.sh/shiki@1.24.0').then(function (m) {
    return fetch('/apps/grubbery/docs/hoon-grammar.json')
      .then(function (r) { return r.json(); })
      .then(function (grammar) {
        return m.createHighlighter({
          themes: ['github-light'],
          langs: [grammar, 'javascript', 'css', 'json']
        });
      });
  }).catch(function () { return null; });
  return shikiP;
}

function langFor(path) {
  if (/\.hoon$/.test(path)) return 'hoon';
  if (/\.js$/.test(path)) return 'javascript';
  if (/\.css$/.test(path)) return 'css';
  if (/\.json$/.test(path)) return 'json';
  return 'text';
}

function parseRange(r) {
  if (!r) return null;
  var m = r.split('-');
  var from = parseInt(m[0], 10);
  if (isNaN(from)) return null;
  var to = m.length > 1 ? parseInt(m[1], 10) : from;
  return { from: from, to: isNaN(to) ? from : to };
}

function sliceLines(text, range) {
  var lines = text.split('\n');
  if (!range) return lines.slice(0, 200).join('\n');
  return lines.slice(range.from - 1, range.to).join('\n');
}

function highlightInto(el, path, code) {
  ensureShiki().then(function (hl) {
    if (!hl) { var p = document.createElement('pre'); p.textContent = code; el.innerHTML = ''; el.appendChild(p); return; }
    try {
      el.innerHTML = hl.codeToHtml(code, { lang: langFor(path), theme: 'github-light' });
    } catch (e) {
      var pre = document.createElement('pre'); pre.textContent = code; el.innerHTML = ''; el.appendChild(pre);
    }
  });
}

// A non-cryptographic content hash (cyrb53 -> 8 hex). We hash the sliced
// source text AS WRITTEN — no normalization — so any drift in the covered
// span shows up. This is drift detection, not security, so a fast hash is
// exactly right. The same function will compute coverage/freshness later.
// Coverage is computed on the ship (from the mirror, hashed with mug) and
// returned whole by /coverage.json. The browser is a pure reader: no hashing,
// no per-file source fetch to compute — just render the ship's verdict.
var cov = null;
var covLoaded = false;
function loadCoverage() {
  var u = withC(BASE + '/coverage.json');
  if (CUR_SECTION) u += '&section=' + encodeURIComponent(CUR_SECTION);
  return fetch(u, { cache: 'no-store' })
    .then(function (r) { return r.ok ? r.json() : { files: [] }; })
    .then(function (c) { cov = c || { files: [] }; covLoaded = true; return cov; })
    .catch(function () { cov = { files: [] }; covLoaded = true; return cov; });
}
function covFile(file) {
  if (!cov || !cov.files) return null;
  for (var i = 0; i < cov.files.length; i++) if (cov.files[i].file === file) return cov.files[i];
  return null;
}
// a block's identity for re-confirm: {doc, file, range}. Whole-file is "all".
function blockOf(file, a) { return { doc: a.doc, file: file, range: a.to === 0 ? 'all' : (a.from + '-' + a.to) }; }
// re-confirm freshness: tell the ship these blocks are verified; it re-hashes
// each current span and re-pins. One block from a chip, or a batch from an
// audit. The ship computes the mug — the browser only names the blocks.
function confirmBlocks(blocks) {
  return fetch(withC(BASE + '/confirm'), { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ blocks: blocks }) })
    .then(function (r) { return r.ok ? r.json() : null; })
    .catch(function () { return null; });
}
// re-confirm a whole section: the ship re-hashes its scope and re-pins it.
function confirmSection(name) {
  return fetch(withC(BASE + '/confirm'), { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ sections: [name] }) })
    .then(function (r) { return r.ok ? r.json() : null; })
    .catch(function () { return null; });
}
// the ship's freshness verdict for one live block (by doc + file + range)
function anchorStatus(doc, file, range) {
  var f = covFile(file);
  if (!f || !f.anchors) return null;
  for (var i = 0; i < f.anchors.length; i++) {
    var a = f.anchors[i];
    if (a.doc !== doc) continue;
    if (range ? (a.from === range.from && a.to === range.to) : (a.to === 0)) return a.status;
  }
  return null;
}

// cross-navigation between the coverage heatmap and the docs that cover it.
// pendingScroll: a block to scroll to once a doc has rendered; covFocus: a
// file+line to expand and scroll to once the coverage view has rendered.
var pendingScroll = null;
var covFocus = null;
function rangeStr(r) { return r ? (r.from + '-' + r.to) : 'all'; }
function flashEl(e) { var o = e.style.boxShadow; e.style.transition = 'box-shadow .2s'; e.style.boxShadow = '0 0 0 3px #ffd98a'; setTimeout(function () { e.style.boxShadow = o; }, 1400); }
function scrollToBlock() {
  if (!pendingScroll) return;
  var ws = document.querySelectorAll('.live-wrap');
  for (var i = 0; i < ws.length; i++) {
    if (ws[i].dataset.file === pendingScroll.file && ws[i].dataset.range === pendingScroll.range) {
      ws[i].scrollIntoView({ block: 'center' }); flashEl(ws[i]); pendingScroll = null; return;
    }
  }
}
function goToDoc(doc, file, rstr) {
  if (typeof closeHeatmapModal === 'function') closeHeatmapModal();
  pendingScroll = { file: file, range: rstr };
  if (decodeURIComponent(location.hash.slice(1)) === CUR + '/' + doc) scrollToBlock();
  else location.hash = hashFor(doc);   // hashchange -> openDoc -> runUpgrade -> scrollToBlock
}
function goToCoverage(file, range) {
  covFocus = { file: file, from: range ? range.from : 1 };
  if (decodeURIComponent(location.hash.slice(1)) === CUR + '/coverage') renderCoverage();
  else location.hash = hashFor('coverage');
}

// The freshness badge for one live block — the ship's verdict, read from
// coverage. fresh: span matches its pin; drifted: it changed since pinned;
// not a target: the file isn't under a coverage target so it isn't measured.
function freshBadge(doc, file, range) {
  var b = document.createElement('span');
  b.className = 'live-fresh';
  b.style.cssText = 'margin-left:auto;font:11px/1 ui-monospace,monospace;padding:2px 6px;border-radius:4px';
  var st = anchorStatus(doc, file, range);
  if (st === 'fresh') { b.textContent = '✓ fresh'; b.style.color = '#1a7f37'; b.style.background = '#e6f4ea'; b.title = 'the covered span still matches its pin'; }
  else if (st === 'drifted') { b.textContent = '⚠ drifted'; b.style.color = '#9a6700'; b.style.background = '#fff4e0'; b.title = 'the span changed since it was pinned'; }
  else if (st === 'gone') { b.textContent = '⚠ not a target'; b.style.color = '#a40e26'; b.style.background = '#fdecea'; b.title = 'this file is not under a coverage target, so it is not mirrored or measured'; }
  else { b.textContent = '· untracked'; b.style.color = '#79808a'; b.style.background = '#f2f4f6'; b.title = 'no coverage record for this span yet'; }
  return b;
}

function delay(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }
function copyText(t) { try { navigator.clipboard.writeText(t); } catch (e) {} }
function flash(el, msg) { var o = el.textContent; el.textContent = msg; setTimeout(function () { el.textContent = o; }, 900); }

function upgradeLiveBlocks() {
  (covLoaded ? Promise.resolve() : loadCoverage()).then(runUpgrade);
}
function runUpgrade() {
  // the doc name is the hash tail, past the collection path (coverage records
  // key blocks by the bare doc name, e.g. "intro.md", not the full hash).
  var doc = decodeURIComponent(location.hash.slice(1)).slice(CUR.length).replace(/^\//, '');
  var blocks = DOC.querySelectorAll('pre > code.language-live');
  for (var i = 0; i < blocks.length; i++) {
    (function (code) {
      var ref = code.textContent.trim();
      var parts = ref.split(/\s+/);
      var path = parts[0];
      var range = parseRange(parts[1]);
      var pre = code.parentElement;
      var host = document.createElement('div');
      host.className = 'live-wrap';
      host.dataset.file = path;
      host.dataset.range = rangeStr(range);
      var head = document.createElement('div');
      head.className = 'live-head';
      head.style.display = 'flex';
      head.style.alignItems = 'center';
      var label = document.createElement('span');
      label.textContent = path + (parts[1] ? '  ' + parts[1] : '');
      head.appendChild(label);
      // link back to this span in the coverage heatmap
      var covLink = document.createElement('span');
      covLink.textContent = ' ◆';
      covLink.title = 'show this span in Coverage';
      covLink.style.cssText = 'cursor:pointer;color:#b0b6bd;margin-left:6px;font-size:11px';
      covLink.onmouseenter = function () { covLink.style.color = '#57606a'; };
      covLink.onmouseleave = function () { covLink.style.color = '#b0b6bd'; };
      (function (p, r) { covLink.onclick = function () { goToCoverage(p, r); }; })(path, range);
      head.appendChild(covLink);
      var body = document.createElement('div');
      body.className = 'live-body';
      body.appendChild(codeSkeleton(rangeRows(parts[1])));
      host.appendChild(head);
      host.appendChild(body);
      pre.replaceWith(host);
      // read the source from the docs mirror — the same copy coverage measures,
      // so the doc page and the coverage page always agree on a block's source
      // and its freshness. Paths are mirror-relative (e.g. /gub/lib/shell.hoon).
      fetch(withC(BASE + '/mirror?path=' + encodeURIComponent(path)), { cache: 'no-store' })
        .then(function (r) { return r.ok ? r.text() : Promise.reject(r.status); })
        .then(function (text) {
          var slice = sliceLines(text, range);
          highlightInto(body, path, slice);
          head.appendChild(freshBadge(doc, path, range));
        })
        .catch(function () {
          body.textContent = 'could not load ' + path + ' — the file or range may be gone';
          var b = document.createElement('span');
          b.className = 'live-fresh';
          b.style.cssText = 'margin-left:auto;font:11px/1 ui-monospace,monospace;padding:2px 6px;border-radius:4px;color:#a40e26;background:#fdecea';
          b.textContent = '⚠ gone';
          b.title = 'the anchored file or range no longer resolves — the doc points at code that moved or was deleted';
          head.appendChild(b);
        });
    })(blocks[i]);
  }
  scrollToBlock();  // if we arrived here to focus a specific block
}

function markActive(path) {
  var links = NAV.querySelectorAll('a');
  for (var i = 0; i < links.length; i++) {
    var on = links[i].dataset.path === path;
    links[i].classList.toggle('active', on);
    if (on) {
      var sec = links[i].closest('.sec');
      while (sec) { sec.classList.remove('collapsed'); sec = sec.parentElement.closest('.sec'); }
    }
  }
}

function showLoading() {
  DOC.innerHTML =
    '<div class="doc-skeleton">' +
      '<div class="sk sk-title"></div>' +
      '<div class="sk"></div><div class="sk"></div><div class="sk sk-short"></div>' +
      '<div class="sk-gap"></div>' +
      '<div class="sk sk-sub"></div>' +
      '<div class="sk"></div><div class="sk"></div><div class="sk"></div>' +
      '<div class="sk sk-short"></div>' +
    '</div>';
}

function openDoc(path) {
  if (!path) return;
  if (decodeURIComponent(location.hash.slice(1)) !== CUR + '/' + path) location.hash = hashFor(path);
  markActive(path);
  if (textCache[path] != null) { render(textCache[path]); return; }
  showLoading();
  fetch(withC(BASE + '/page?path=' + encodeURIComponent(path)))
    .then(function (r) { return r.ok ? r.text() : Promise.reject(r.status); })
    .then(function (md) { textCache[path] = md; render(md); })
    .catch(function () { DOC.innerHTML = '<p id="empty">Could not load this doc.</p>'; });
}

// ---- sidebar (recursive tree) ----

function docLink(it) {
  var a = document.createElement('a');
  a.textContent = it.title;
  a.href = hashFor(it.path);
  a.dataset.path = it.path;
  a.onclick = function (e) { e.preventDefault(); openDoc(it.path); };
  return a;
}

// open a section's sub-coverage view (its declared scope).
function openSection(name) {
  CUR_SECTION = name;
  if (decodeURIComponent(location.hash.slice(1)) === CUR + '/coverage') renderCoverage();
  else location.hash = hashFor('coverage');
}

function renderTree(items, container) {
  items.forEach(function (it) {
    if (it.path) {
      var li = document.createElement('li');
      li.appendChild(docLink(it));
      container.appendChild(li);
    } else {
      // a section: the collapsible doc group, plus a ◆ handle that opens its
      // sub-coverage (the code its docs reference, or its declared scope).
      var sec = document.createElement('li');
      sec.className = 'sec';
      var head = document.createElement('div');
      head.className = 'sec-head';
      var lbl = document.createElement('span');
      lbl.textContent = it.title;
      lbl.style.flex = '1';
      lbl.style.overflow = 'hidden';
      lbl.style.textOverflow = 'ellipsis';
      head.appendChild(lbl);
      head.onclick = function () { sec.classList.toggle('collapsed'); };
      // ◆ only when the section has coverage to show (ship-tagged `cov`).
      if (it.cov) {
        var cov = document.createElement('span');
        cov.textContent = '◆';
        cov.className = 'sec-cov-handle';
        cov.title = 'coverage of what this section documents';
        (function (nm) { cov.onclick = function (e) { e.stopPropagation(); openSection(nm); }; })(it.title);
        head.appendChild(cov);
      }
      var ul = document.createElement('ul');
      sec.appendChild(head);
      sec.appendChild(ul);
      renderTree(it.kids || [], ul);
      container.appendChild(sec);
    }
  });
}

function showNav() {
  NAV.innerHTML = '';
  var idx = document.createElement('a');
  idx.textContent = '‹ All collections';
  idx.href = '#';
  idx.style.cssText = 'display:block;margin-bottom:10px;color:#79808a;font-size:12px';
  idx.onclick = function (e) { e.preventDefault(); location.hash = ''; renderIndex(); };
  NAV.appendChild(idx);
  var cov = document.createElement('a');
  cov.textContent = '◆ Coverage';
  cov.href = hashFor('coverage');
  cov.dataset.path = 'coverage';
  cov.style.cssText = 'font-weight:600;display:block;margin-bottom:8px';
  cov.onclick = function (e) { e.preventDefault(); CUR_SECTION = ''; location.hash = hashFor('coverage'); renderCoverage(); };
  NAV.appendChild(cov);
  renderTree(tree, NAV);
  var tail = decodeURIComponent(location.hash.slice(1)).slice(CUR.length).replace(/^\//, '');
  if (tail) markActive(tail);
}

// ---- search (top-right input + dropdown, server-side query) ----

function hideResults() { RESULTS.classList.add('hidden'); }
function showResults() { if (results.length || INPUT.value.trim()) RESULTS.classList.remove('hidden'); }

function paintSel() {
  var items = RESULTS.querySelectorAll('.result');
  for (var i = 0; i < items.length; i++) items[i].classList.toggle('sel', i === sel);
  if (sel >= 0 && items[sel]) items[sel].scrollIntoView({ block: 'nearest' });
}

function choose(i) {
  var h = results[i];
  if (!h) return;
  hideResults();
  INPUT.blur();
  openDoc(h.path);
}

function renderResults(q) {
  RESULTS.innerHTML = '';
  if (!results.length) {
    var none = document.createElement('li');
    none.className = 'no-hits';
    none.textContent = 'No matches';
    RESULTS.appendChild(none);
    showResults();
    return;
  }
  results.forEach(function (h, i) {
    var li = document.createElement('li');
    li.className = 'result' + (i === sel ? ' sel' : '');
    li.onmouseenter = function () { sel = i; paintSel(); };
    li.onclick = function () { choose(i); };
    var t = document.createElement('div');
    t.className = 'r-title';
    t.textContent = h.title;
    li.appendChild(t);
    if (h.snippet) {
      var s = document.createElement('div');
      s.className = 'r-snip';
      s.innerHTML = highlight(h.snippet, q);
      li.appendChild(s);
    }
    RESULTS.appendChild(li);
  });
  showResults();
}

function runSearch(q) {
  fetch(withC(BASE + '/search?q=' + encodeURIComponent(q)))
    .then(function (r) { return r.json(); })
    .then(function (hits) {
      results = Array.isArray(hits) ? hits : [];
      sel = results.length ? 0 : -1;
      renderResults(q);
    })
    .catch(function () { /* leave prior results on transient error */ });
}

function onInput() {
  var q = INPUT.value.trim();
  clearTimeout(searchTimer);
  if (!q) { results = []; sel = -1; RESULTS.innerHTML = ''; hideResults(); return; }
  searchTimer = setTimeout(function () { runSearch(q); }, 150);
}

// ---- coverage: read the ship's computed coverage.json and render it ----
// The ship computes coverage and freshness from its mirror (mug hashes); the
// browser only reads and renders. Heatmap source comes from /mirror, lazily.

// the coverage target list: the DIRECTORIES we want documented. Editable and
// persisted on the ship; the mirror (and so the file list) follows it.
function loadTargets() {
  return fetch(BASE + '/targets.json', { cache: 'no-store' })
    .then(function (r) { return r.ok ? r.json() : []; })
    .then(function (t) {
      // entries are {path, docs} objects; docs is opaque to the browser but
      // carried through so a save can't drop a target's handbook location.
      return Array.isArray(t) ? t.filter(function (e) { return e && typeof e === 'object'; }) : [];
    })
    .catch(function () { return []; });
}
function saveTargets(list) {
  return fetch(BASE + '/targets', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(list) }).catch(function () {});
}
function loadIgnore() {
  return fetch(withC(BASE + '/ignore.json'), { cache: 'no-store' })
    .then(function (r) { return r.ok ? r.json() : []; })
    .then(function (t) { return Array.isArray(t) ? t : []; })
    .catch(function () { return []; });
}
function saveIgnore(list) {
  return fetch(BASE + '/ignore', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(list) }).catch(function () {});
}

// ── coverage file tree ──
// nest the flat coverage file list into dirs, carrying covered/total up each
// node so a directory summary shows its own aggregate coverage.
function buildCovTree(files) {
  var root = { dirs: {}, files: [], total: 0, covered: 0 };
  files.forEach(function (f) {
    var segs = (f.file || '').split('/').filter(Boolean);
    segs.pop(); // basename stays on the leaf
    var node = root;
    // extra-credit files are shown but excluded from the denominator, so they
    // don't move the directory percentages
    var counts = !f.extra;
    if (counts) { node.total += f.total; node.covered += f.covered; }
    var here = '';
    segs.forEach(function (s) {
      here += '/' + s;
      if (!node.dirs[s]) node.dirs[s] = { dirs: {}, files: [], total: 0, covered: 0, path: here };
      node = node.dirs[s];
      if (counts) { node.total += f.total; node.covered += f.covered; }
    });
    node.files.push(f);
  });
  return root;
}
// dir open/closed state, survives rerenders and reloads. Default collapsed;
// only an explicit open is remembered.
var covTreeState = {};
function loadCovTreeState() {
  try { covTreeState = JSON.parse(localStorage.getItem('docs-cov-tree')) || {}; }
  catch (e) { covTreeState = {}; }
}
function saveCovTreeState() {
  try { localStorage.setItem('docs-cov-tree', JSON.stringify(covTreeState)); } catch (e) {}
}
function updateCovToggle() {
  var tog = document.getElementById('cov-tree-toggle');
  var box = document.getElementById('cov-tree');
  if (tog && box) tog.textContent = box.querySelector('.cov-dir-det[open]') ? 'collapse all' : 'expand all';
}
function renderCovNode(parent, node, here) {
  here = here || '';
  Object.keys(node.dirs).sort().forEach(function (name) {
    var d = node.dirs[name];
    var dirPath = here + name + '/';
    var det = document.createElement('details');
    det.className = 'cov-dir-det';
    det.open = covTreeState[dirPath] === true;
    det.addEventListener('toggle', function () { covTreeState[dirPath] = det.open; saveCovTreeState(); updateCovToggle(); });
    var sum = document.createElement('summary'); sum.className = 'cov-dir';
    var p = d.total ? Math.round(100 * d.covered / d.total) : 0;
    sum.append(el('span', 'cov-dir-nm', name + '/'));
    sum.append(el('span', 'cov-dir-pct', p + '%  ' + d.covered + '/' + d.total));
    det.appendChild(sum);
    var kids = el('div', 'cov-kids');
    renderCovNode(kids, d, dirPath);
    det.appendChild(kids);
    parent.appendChild(det);
  });
  node.files.slice().sort(function (a, b) { return (a.file || '').localeCompare(b.file || ''); })
    .forEach(function (f) { parent.appendChild(fileRow(f, f.file.split('/').pop())); });
}

function pct(f) { return f.total ? f.covered / f.total : 0; }

function coverageStyles() {
  if (document.getElementById('cov-style')) return;
  var s = document.createElement('style');
  s.id = 'cov-style';
  s.textContent =
    '.cov h1{margin:0 0 4px}.cov .sub{color:#79808a;margin:0 0 20px}' +
    '.cov-row{display:grid;grid-template-columns:1fr 84px 108px 108px 20px;gap:12px;align-items:center;padding:9px 4px;border-bottom:1px solid #f2f4f6;cursor:pointer}' +
    '.cov-row:hover{background:#fafbfc}.cov-row.cov-gap{cursor:default}.cov-row.cov-gap .cov-file{color:#a40e26}' +
    '.cov-file{font:12.5px ui-monospace,monospace;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +
    '.cov-act{color:#b0b6bd;text-align:center;font-size:14px;cursor:pointer;user-select:none}.cov-act:hover{color:#57606a}' +
    '.cov-tgt{display:flex;justify-content:space-between;align-items:center;padding:6px 4px;border-bottom:1px solid #f2f4f6;font:12.5px ui-monospace,monospace}' +
    '.cov-sec{margin:22px 0 2px;font-size:12px;text-transform:uppercase;letter-spacing:.05em;color:#57606a}' +
    '.cov-secsub{color:#9aa0a8;font-size:12px;margin:0 0 6px}' +
    '.cov-add{display:flex;gap:8px;margin:6px 0 10px}' +
    '.cov-add-inp{flex:1;font:12px ui-monospace,monospace;padding:6px 9px;border:1px solid #e4e7eb;border-radius:6px}' +
    '.cov-add-btn{font-size:12px;padding:6px 12px;border:1px solid #d7dbe0;border-radius:6px;background:#fff;cursor:pointer}.cov-add-btn:hover{background:#f6f8fa}' +
    '.cov-bar{height:7px;border-radius:4px;background:#eef0f3;overflow:hidden}.cov-bar>i{display:block;height:100%;background:#1a7f37}' +
    '.cov-pct{font:12px ui-monospace,monospace;color:#57606a;text-align:right}' +
    '.cov-flags{font:11px ui-monospace,monospace;display:flex;gap:6px;justify-content:flex-end}' +
    '.cov-flags .f{color:#1a7f37}.cov-flags .d{color:#9a6700}.cov-flags .g{color:#a40e26}.cov-flags .u{color:#79808a}' +
    '.cov-heat{margin:2px 0 18px}' +
    '.cov-slices{display:flex;flex-wrap:wrap;gap:6px;align-items:center;margin:0 0 8px}' +
    '.cov-slices-lab{font-size:10.5px;text-transform:uppercase;letter-spacing:.05em;color:#9aa0a8;margin-right:2px}' +
    '.cov-slice{font:11px ui-monospace,monospace;padding:3px 9px;border-radius:12px;background:#eef6f0;color:#1a7f37;border:1px solid #d4e8db;cursor:pointer}' +
    '.cov-slice:hover{background:#e0efe6}.cov-slice.dr{background:#fff4e0;color:#9a6700;border-color:#f0dcae}' +
    '.cov-reconfirm{font:11px ui-monospace,monospace;padding:3px 9px;border-radius:12px;background:#1f2328;color:#fff;border:1px solid #1f2328;cursor:pointer;margin-left:-2px}.cov-reconfirm:hover{background:#000}' +
    '.cov-src .ln[data-line]:hover{filter:brightness(0.97)}' +
    '.cov-src{margin:0;border:1px solid #eef0f3;border-radius:6px;overflow:auto;max-height:60vh}' +
    '.cov-src pre{margin:0;font:11.5px/1.5 ui-monospace,monospace}' +
    '.cov-src .ln{display:block;padding:0 10px;white-space:pre;color:#8a929c}' +
    '.cov-src .ln.on{background:#e6f4ea;color:#1f2328;box-shadow:inset 3px 0 #1a7f37}' +
    '.cov-src .ln.dr{background:#fff4e0;box-shadow:inset 3px 0 #9a6700}' +
    '.cov-modal{position:fixed;inset:0;z-index:100;background:rgba(20,22,26,.44);display:flex;align-items:center;justify-content:center;padding:4vh 4vw}' +
    '.cov-modal-panel{background:#fff;border-radius:10px;box-shadow:0 12px 48px rgba(0,0,0,.28);width:min(940px,100%);max-height:92vh;display:flex;flex-direction:column;overflow:hidden}' +
    '.cov-modal-hdr{display:flex;align-items:center;gap:12px;padding:12px 16px;border-bottom:1px solid #eef0f3}' +
    '.cov-modal-file{font:12.5px ui-monospace,monospace;color:#1f2328;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;flex:1}' +
    '.cov-modal-meta{font:11.5px ui-monospace,monospace;color:#79808a;flex:0 0 auto;white-space:nowrap}' +
    '.cov-modal-x{flex:0 0 auto;font-size:22px;line-height:1;color:#9aa0a8;background:none;border:none;cursor:pointer;padding:0 2px}.cov-modal-x:hover{color:#1f2328}' +
    '.cov-modal-body{padding:14px 16px;overflow:auto}.cov-modal .cov-heat{margin:0}' +
    '.cov-modal .cov-src{max-height:none;border:none;border-radius:0;overflow:visible}' +
    '.cov-overall{display:flex;align-items:baseline;gap:10px;margin:0 0 18px;flex-wrap:wrap}.cov-overall b{font-size:26px}.cov-overall span{color:#79808a}' +
    '.cov-scroll{overflow-y:auto;border:1px solid #f2f4f6;border-radius:6px;margin-bottom:4px}' +
    '.cov-scroll-t{max-height:20vh}.cov-scroll-f{max-height:48vh}' +
    '.cov-scroll .cov-row,.cov-scroll .cov-tgt{padding-left:8px;padding-right:8px}' +
    '.cov-coll{display:flex;align-items:center;gap:12px;padding:14px 14px;border:1px solid #eef0f3;border-radius:8px;margin:0 0 8px;cursor:pointer;background:#fff}' +
    '.cov-coll:hover{background:#fafbfc;border-color:#e2e7ee}' +
    '.cov-coll-main{flex:1;min-width:0}' +
    '.cov-coll-name{font:13.5px -apple-system,sans-serif;font-weight:600;color:#1f2328}' +
    '.cov-coll-path{font:11.5px ui-monospace,monospace;color:#8a929c;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;margin-top:2px}' +
    '.cov-coll-open{font-size:12px;color:#79808a;flex:0 0 auto}' +
    '.cov-secbar{display:flex;flex-wrap:wrap;gap:6px;align-items:center;margin:0 0 16px}' +
    '.cov-secbar-lab{font-size:10.5px;text-transform:uppercase;letter-spacing:.05em;color:#9aa0a8;margin-right:2px}' +
    '.cov-secpill{font:12px -apple-system,sans-serif;padding:4px 11px;border-radius:13px;background:#fff;border:1px solid #e2e7ee;color:#57606a;cursor:pointer}' +
    '.cov-secpill:hover{background:#fafbfc}.cov-secpill.on{background:#1f2328;border-color:#1f2328;color:#fff}' +
    '.cov-secname{font:13px ui-monospace,monospace;font-weight:600;color:#1f2328}' +
    '.cov-secwarn{display:flex;align-items:center;gap:12px;padding:9px 12px;margin:0 0 16px;background:#fff8ec;border:1px solid #f0dcae;border-radius:8px;font-size:12.5px;color:#9a6700}' +
    '.cov-secwarn-txt{flex:1}' +
    '.cov-secwarn-btn{font:12px -apple-system,sans-serif;padding:4px 11px;border-radius:8px;background:#9a6700;color:#fff;border:none;cursor:pointer;flex:0 0 auto}.cov-secwarn-btn:hover{background:#7a5200}' +
    '.cov-tabs{display:flex;gap:2px;border-bottom:1px solid #eceef1;margin:0 0 14px}' +
    '.cov-tab{font:12px -apple-system,sans-serif;color:#79808a;background:none;border:none;border-bottom:2px solid transparent;padding:7px 12px;margin-bottom:-1px;cursor:pointer}' +
    '.cov-tab:hover{color:#1f2328}.cov-tab.on{color:#1f2328;font-weight:600;border-bottom-color:#1f2328}' +
    '.cov-files-hdr{display:flex;align-items:baseline;justify-content:space-between;margin:0 0 4px}' +
    '.cov-tree-toggle{font-size:11px;color:#79808a;background:none;border:none;cursor:pointer;padding:0}.cov-tree-toggle:hover{color:#1f2328;text-decoration:underline}' +
    '.cov-dir-det>summary{list-style:none;cursor:pointer;display:flex;align-items:center;justify-content:space-between;padding:6px 8px;border-bottom:1px solid #f2f4f6;font:12.5px ui-monospace,monospace;color:#3a4149}' +
    '.cov-dir-det>summary::-webkit-details-marker{display:none}' +
    '.cov-dir-det>summary::before{content:"▸";display:inline-block;width:12px;color:#a6adb5;font-size:10px}' +
    '.cov-dir-det[open]>summary::before{content:"▾"}' +
    '.cov-dir-det>summary:hover{background:#fafbfc}' +
    '.cov-dir-nm{flex:1;margin-left:2px}.cov-dir-pct{color:#8a929c;font-size:11px}' +
    '.cov-kids{margin-left:13px;border-left:1px solid #f2f4f6}' +
    '.cov-leg{position:relative;display:inline-block;margin-left:2px}' +
    '.cov-leg-trig{font-size:11px;color:#9aa0a8;cursor:default;border-bottom:1px dotted #cbd0d6}' +
    '.cov-leg-pop{display:none;position:absolute;top:22px;right:0;z-index:20;width:320px;padding:10px 13px;background:#fff;border:1px solid #e4e7eb;border-radius:8px;box-shadow:0 6px 24px rgba(0,0,0,.12);color:#57606a}' +
    '.cov-leg:hover .cov-leg-pop{display:block}' +
    // the handbook prose sets font-size directly on b/strong, which beats an inherited size — pin the popover text explicitly
    '.cov-leg-pop,.cov-leg-pop div,.cov-leg-pop b{font:11.5px/1.6 -apple-system,system-ui,sans-serif}' +
    '.cov-leg-pop b{font-weight:600}' +
    '.cov-leg-pop div{padding:1px 0}.cov-leg-pop div.n{margin-top:6px;padding-top:6px;border-top:1px solid #eef0f3;color:#9aa0a8}' +
    '.cov-leg-pop b.f{color:#1a7f37}.cov-leg-pop b.d{color:#9a6700}.cov-leg-pop b.g{color:#a40e26}.cov-leg-pop b.x{color:#8250df}' +
    '.cov-xc{font:10px ui-monospace,monospace;color:#8250df;background:#f5f0ff;border:1px solid #e6dcff;border-radius:9px;padding:1px 7px;vertical-align:1px}' +
    '.cov-extra .cov-bar>i{background:#8250df}' +
    '.cov-leg-pop .n{color:#9aa0a8;margin-top:5px;padding-top:5px;border-top:1px solid #eef0f3}' +
    '.cov-legend{font:11.5px/1.7 -apple-system,sans-serif;color:#79808a;margin:0 0 20px;padding:9px 12px;background:#fafbfc;border:1px solid #f2f4f6;border-radius:6px}' +
    '.cov-legend .f{color:#1a7f37;font-weight:600}.cov-legend .d{color:#9a6700;font-weight:600}.cov-legend .g{color:#a40e26;font-weight:600}.cov-legend .u{color:#57606a;font-weight:600}' +
    '.cov-legend>div{padding:1px 0}.cov-legend .f,.cov-legend .d,.cov-legend .g,.cov-legend .u{display:inline-block;min-width:82px}' +
    '.cov-legnote{margin-top:6px;padding-top:6px!important;border-top:1px solid #eef0f3;color:#9aa0a8}' +
    '.cov-load{display:flex;align-items:center;gap:11px;color:#79808a;font-size:13px;padding:26px 4px}' +
    '@keyframes cov-spin{to{transform:rotate(360deg)}}' +
    '.cov-load .spinner{display:inline-block;box-sizing:border-box;width:18px;height:18px;border:2px solid #d7dbe0;border-top-color:#57606a;border-radius:50%;animation:cov-spin 0.7s linear infinite;flex:0 0 auto}';
  document.head.appendChild(s);
}

// one file's heatmap: covered lines (from ship-computed ranges) lit, drifted
// spans amber, source pulled lazily from the mirror (local, one fetch).
function renderHeatmap(f) {
  var wrap = el('div', 'cov-heat');
  var coveredSet = {}, driftSet = {}, lineDoc = {};
  (f.ranges || []).forEach(function (r) { for (var n = r[0]; n <= r[1]; n++) coveredSet[n] = true; });
  (f.anchors || []).forEach(function (a) {
    if (a.status === 'gone') return;
    var hi = a.to === 0 ? f.total : a.to;
    for (var n = a.from; n <= hi; n++) { if (a.status === 'drifted') driftSet[n] = true; lineDoc[n] = a; }
  });
  var slices = el('div', 'cov-slices');
  slices.appendChild(el('span', 'cov-slices-lab', 'Referenced by'));
  (f.anchors || []).forEach(function (a) {
    if (a.status === 'gone') return;
    var hi = a.to === 0 ? f.total : a.to;
    var chip = el('span', 'cov-slice' + (a.status === 'drifted' ? ' dr' : ''), 'lines ' + a.from + '–' + hi + ' · ' + a.doc);
    chip.title = 'go to this block in ' + a.doc;
    (function (an) { var rs = an.to === 0 ? 'all' : (an.from + '-' + an.to); chip.onclick = function () { goToDoc(an.doc, f.file, rs); }; })(a);
    slices.appendChild(chip);
    if (a.status === 'drifted') {
      var rc = el('span', 'cov-reconfirm', 're-confirm');
      rc.title = 'the code changed since this was pinned; if the prose still holds, re-pin at the current version';
      (function (an) { rc.onclick = function (e) {
        e.stopPropagation(); rc.textContent = '…';
        confirmBlocks([blockOf(f.file, an)]).then(function () { closeHeatmapModal(); renderCoverage(); });
      }; })(a);
      slices.appendChild(rc);
    }
  });
  wrap.appendChild(slices);
  var src = el('div', 'cov-src'); src.appendChild(codeSkeleton(10));
  wrap.appendChild(src);
  fetch(withC(BASE + '/mirror?path=' + encodeURIComponent(f.file)), { cache: 'no-store' })
    .then(function (r) { return r.ok ? r.text() : ''; })
    .then(function (text) {
      src.textContent = '';
      var pre = document.createElement('pre');
      text.split('\n').forEach(function (line, i) {
        var n = i + 1;
        var cls = 'ln' + (driftSet[n] ? ' dr' : coveredSet[n] ? ' on' : '');
        var d = el('span', cls, (n + '  ').slice(0, 4) + '  ' + line + '\n');
        d.dataset.line = n;
        var a = lineDoc[n];
        if (a) {
          d.style.cursor = 'pointer';
          d.title = 'covered by ' + a.doc + ' — click to open';
          (function (an) { var rs = an.to === 0 ? 'all' : (an.from + '-' + an.to); d.onclick = function () { goToDoc(an.doc, f.file, rs); }; })(a);
        }
        pre.appendChild(d);
      });
      src.appendChild(pre);
    })
    .catch(function () { src.textContent = 'could not load mirrored source'; });
  return wrap;
}

// the file reader opens in a modal: the heatmap (referenced-by slices + the
// mirrored source with covered lines lit) over a dimmed backdrop.
var covModalEsc = null;
function closeHeatmapModal() {
  var ov = document.getElementById('cov-modal');
  if (ov) ov.remove();
  if (covModalEsc) { document.removeEventListener('keydown', covModalEsc); covModalEsc = null; }
}
function showHeatmapModal(f, focusLine) {
  closeHeatmapModal();
  var ov = el('div', 'cov-modal'); ov.id = 'cov-modal';
  var panel = el('div', 'cov-modal-panel');
  var hdr = el('div', 'cov-modal-hdr');
  var title = el('div', 'cov-modal-file', f.file); title.title = f.file;
  var meta = el('span', 'cov-modal-meta', (f.total ? Math.round(100 * pct(f)) + '%' : '—') + ' · ' + f.covered + '/' + f.total + ' lines' + (f.extra ? ' · extra credit' : ''));
  var close = el('button', 'cov-modal-x', '×'); close.title = 'close (Esc)'; close.onclick = closeHeatmapModal;
  hdr.append(title, meta, close);
  var body = el('div', 'cov-modal-body');
  body.appendChild(renderHeatmap(f));
  panel.append(hdr, body); ov.appendChild(panel);
  ov.onclick = function (e) { if (e.target === ov) closeHeatmapModal(); };
  covModalEsc = function (e) { if (e.key === 'Escape') closeHeatmapModal(); };
  document.addEventListener('keydown', covModalEsc);
  document.body.appendChild(ov);
  if (focusLine) setTimeout(function () {
    var ln = body.querySelector('.ln[data-line="' + focusLine + '"]');
    if (ln) { ln.scrollIntoView({ block: 'center' }); flashEl(ln); }
  }, 450);
}

// one file's coverage row: bar, percent, freshness flags, click-to-expand.
// Everything is read from the ship's coverage.json — no client computation.
function fileRow(f, label) {
  var gap = !f.covered && !f.extra;
  var row = el('div', 'cov-row' + (gap ? ' cov-gap' : '') + (f.extra ? ' cov-extra' : ''));
  row.dataset.file = f.file;
  var nm = el('div', 'cov-file', label || f.file); nm.title = f.file;
  if (f.extra) { var xc = el('span', 'cov-xc', 'extra credit'); xc.title = 'documented but excluded from the count (ignored path)'; nm.append(document.createTextNode(' ')); nm.append(xc); }
  row.append(nm);
  var bar = el('div', 'cov-bar'); var fill = document.createElement('i');
  fill.style.width = Math.round(100 * pct(f)) + '%';
  if (gap) fill.style.background = '#d0555f';
  bar.appendChild(fill); row.appendChild(bar);
  row.append(el('div', 'cov-pct', (f.total ? Math.round(100 * pct(f)) + '%' : '—') + '  ' + f.covered + '/' + f.total));
  var flags = el('div', 'cov-flags');
  function flag(cls, glyph, n, word) {
    var e = el('span', cls, glyph + n);
    e.title = n + ' live block' + (n > 1 ? 's' : '') + ' ' + word;
    return e;
  }
  if (f.fresh) flags.appendChild(flag('f', '✓', f.fresh, 'covering this file, fresh'));
  if (f.drifted) flags.appendChild(flag('d', '⚠', f.drifted, 'drifted (the code changed since pinned)'));
  if (f.gone) flags.appendChild(flag('g', '✗', f.gone, 'pointing at a span that is gone'));
  if (gap) { var u = el('span', 'u', 'no docs'); u.title = 'no live block covers this file'; flags.appendChild(u); }
  row.appendChild(flags);
  row.appendChild(el('span', 'cov-act', f.anchors && f.anchors.length ? '⤢' : ''));
  row.onclick = function () {
    if (!(f.anchors && f.anchors.length)) return;
    showHeatmapModal(f);
  };
  return row;
}

// a compact hover trigger that reveals the flag legend, so it costs no space
function legendTrigger() {
  var w = el('span', 'cov-leg');
  w.appendChild(el('span', 'cov-leg-trig', 'ⓘ flags'));
  var pop = el('div', 'cov-leg-pop');
  pop.innerHTML =
    '<div><b class="f">✓ fresh</b> — the span still matches its pin (mug, ship-side)</div>' +
    '<div><b class="d">⚠ drifted</b> — the span changed since it was pinned</div>' +
    '<div><b class="g">✗ gone</b> — a live block points at a file not under any target</div>' +
    '<div><b class="x">extra credit</b> — a documented file on an ignored path; shown, not counted</div>' +
    '<div class="n">the number after a flag counts the file\'s blocks in that state</div>';
  w.appendChild(pop);
  return w;
}

function renderCoverage() {
  markActive('coverage');
  DOC.innerHTML = '';
  coverageStyles();
  var root = el('div', 'cov');
  root.appendChild(el('h1', null, 'Coverage'));
  root.appendChild(el('p', 'sub', 'How much of the source we mean to document actually is. Targets are directories the ship mirrors; coverage and freshness are computed on the ship.'));
  var overall = el('div', 'cov-overall'); root.appendChild(overall);
  var body = el('div', null); root.appendChild(body);
  DOC.appendChild(root);
  var load = el('div', 'cov-load');
  load.append(el('span', 'spinner'), el('span', null, 'reading coverage…'));
  body.appendChild(load);
  var targets = [], ignore = [];
  Promise.all([loadTargets(), loadCoverage(), loadIgnore(), delay(300)]).then(function (r) {
    targets = r[0];
    ignore = r[2];
    var c = r[1] || { files: [] };
    body.textContent = '';
    var files = (c.files || []).slice().sort(function (a, b) { return pct(b) - pct(a); });
    overall.innerHTML = '';
    if (c.totalLines) {
      overall.append(el('b', null, Math.round(100 * (c.coveredLines || 0) / c.totalLines) + '%'),
        el('span', null, (c.coveredLines || 0) + ' / ' + c.totalLines + ' lines · ' + files.length + ' files · '),
        el('span', null, (c.fresh || 0) + ' fresh, ' + (c.drifted || 0) + ' drifted, ' + (c.gone || 0) + ' gone'));
    } else {
      overall.append(el('span', null, 'No coverage yet — add a target directory below.'));
    }
    overall.appendChild(legendTrigger());
    // active section indicator — sub-coverage is entered from the sidebar's ◆
    // section handles; here we show which section is in view and offer a way
    // back to the whole collection. No section = the whole collection.
    if (CUR_SECTION) {
      var secBar = el('div', 'cov-secbar');
      secBar.appendChild(el('span', 'cov-secbar-lab', 'Section'));
      secBar.appendChild(el('span', 'cov-secname', CUR_SECTION));
      var allBtn = el('button', 'cov-secpill', '× whole collection');
      allBtn.onclick = function () { CUR_SECTION = ''; renderCoverage(); };
      secBar.appendChild(allBtn);
      body.appendChild(secBar);
    }
    // section drift: soft "code changed, re-audit" prompt (not a doc lying).
    if (c.section && c.section.status === 'drifted') {
      var warn = el('div', 'cov-secwarn');
      warn.appendChild(el('span', 'cov-secwarn-txt', '⟳ ' + c.section.name + ' changed since it was last confirmed — worth a re-audit'));
      var rcs = el('button', 'cov-secwarn-btn', 're-confirm section');
      rcs.onclick = function () { rcs.textContent = '…'; confirmSection(c.section.name).then(function () { renderCoverage(); }); };
      warn.appendChild(rcs);
      body.appendChild(warn);
    }
    // two sub-views: Files (the coverage data you read) and Config (the
    // targets + ignore you set once). Files leads; config tucks behind a tab.
    var tabbar = el('div', 'cov-tabs');
    var tabFiles = el('button', 'cov-tab', 'Files');
    var tabConf = el('button', 'cov-tab', 'Config');
    tabbar.append(tabFiles, tabConf); body.appendChild(tabbar);
    var filesPanel = el('div', null), confPanel = el('div', null);
    body.append(filesPanel, confPanel);
    // ── Config panel: this collection's target (READ-ONLY). The registry —
    // adding/removing collections — lives on the index, not here. ──
    confPanel.appendChild(el('h3', 'cov-sec', 'Target'));
    confPanel.appendChild(el('div', 'cov-secsub', 'The namespace directory this collection mirrors and measures. Registered on the index (All collections).'));
    var tscroll = el('div', 'cov-scroll cov-scroll-t');
    var trow = el('div', 'cov-tgt'); trow.append(el('span', 'cov-file', CUR || '(none)'));
    tscroll.appendChild(trow);
    confPanel.appendChild(tscroll);
    // ── Config panel: Ignored (READ-ONLY) — authored in the target's own
    // man/docs manifest, so it's shown here but edited in the desk source. ──
    confPanel.appendChild(el('h3', 'cov-sec', 'Ignored'));
    confPanel.appendChild(el('div', 'cov-secsub', 'Paths under a target excluded from the count — vendored code, tests, anything that should not count. Declared in the target’s man/docs/docs.json, so edit it there, not here.'));
    var igscroll = el('div', 'cov-scroll cov-scroll-t');
    if (!ignore.length) igscroll.appendChild(el('div', 'cov-secsub', 'Nothing ignored.'));
    ignore.forEach(function (ig) {
      var irow = el('div', 'cov-tgt');
      irow.append(el('span', 'cov-file', ig));
      igscroll.appendChild(irow);
    });
    confPanel.appendChild(igscroll);
    // ── Files panel: collapsible tree, each dir showing its aggregate coverage ──
    var fhdr = el('div', 'cov-files-hdr');
    fhdr.append(el('span', 'cov-secsub', files.length + ' files under a target'));
    var tog = el('button', 'cov-tree-toggle', 'expand all'); tog.id = 'cov-tree-toggle';
    fhdr.append(tog);
    filesPanel.appendChild(fhdr);
    loadCovTreeState();
    var fscroll = el('div', 'cov-scroll cov-scroll-f'); fscroll.id = 'cov-tree';
    if (!files.length) fscroll.appendChild(el('div', 'cov-secsub', 'No mirrored files yet — add a target in Config.'));
    else renderCovNode(fscroll, buildCovTree(files), '');
    filesPanel.appendChild(fscroll);
    tog.onclick = function () {
      var expand = tog.textContent === 'expand all';
      Array.prototype.forEach.call(fscroll.querySelectorAll('.cov-dir-det'), function (d) { d.open = expand; });
      // toggle events fire per <details> and update state + label
    };
    updateCovToggle();
    // tab switching — Files by default, remembered across visits
    function pickTab(name) {
      var isF = name !== 'config';
      try { localStorage.setItem('docs-cov-tab', isF ? 'files' : 'config'); } catch (e) {}
      filesPanel.hidden = !isF; confPanel.hidden = isF;
      tabFiles.classList.toggle('on', isF); tabConf.classList.toggle('on', !isF);
    }
    tabFiles.onclick = function () { pickTab('files'); };
    tabConf.onclick = function () { pickTab('config'); };
    var startTab = 'files';
    try { startTab = localStorage.getItem('docs-cov-tab') || 'files'; } catch (e) {}
    if (covFocus) startTab = 'files';
    pickTab(startTab);
    // arrived from a doc block's ◆ link: open that file's reader on the line
    if (covFocus) {
      var want = covFocus; covFocus = null;
      var wf = files.filter(function (x) { return x.file === want.file; })[0];
      if (wf && wf.anchors && wf.anchors.length) showHeatmapModal(wf, want.from);
    }
  });
}

// ---- boot ----

// collapse the sidebar via <split-view> (the component shows a reopen rail and
// persists the collapsed state through its `persist` key).
function wireSidebarCollapse() {
  var btn = document.getElementById('sb-collapse');
  var sv = document.getElementById('docs');
  if (!btn || !sv) return;
  btn.onclick = function () { if (sv.collapse) sv.collapse(); else sv.setAttribute('collapsed', ''); };
}

// load one collection's nav (scoped by CUR), populate the sidebar.
function loadNav() {
  return fetch(withC(BASE + '/nav.json'))
    .then(function (r) { return r.json(); })
    .then(function (list) { tree = Array.isArray(list) ? list : []; })
    .catch(function () { tree = []; })
    .then(function () { leaves = collectLeaves(tree, []); showNav(); });
}

// the index / main page: every registered collection, with add/remove. This
// is where the registry (targets) is edited — a cross-collection action.
function renderIndex() {
  CUR = '';
  markActive(null);
  NAV.innerHTML = '';
  DOC.innerHTML = '';
  coverageStyles();
  var root = el('div', 'cov');
  root.appendChild(el('h1', null, 'Documentation'));
  root.appendChild(el('p', 'sub', 'Each collection is a documented target — its handbook and its coverage. Open one to read it, or register another target.'));
  var body = el('div', null); root.appendChild(body);
  DOC.appendChild(root);
  loadTargets().then(function (cols) {
    COLLECTIONS = cols;
    body.appendChild(el('h3', 'cov-sec', 'Collections'));
    var addWrap = el('div', 'cov-add');
    var inp = document.createElement('input'); inp.className = 'cov-add-inp';
    inp.placeholder = 'register a target, e.g. /sys/clay/desks/grubbery';
    var addBtn = el('button', 'cov-add-btn', 'add');
    function doAdd() { var v = inp.value.trim(); if (!v) return; if (v[0] !== '/') v = '/' + v; if (cols.some(function (c) { return collPath(c) === v; })) { inp.value = ''; return; } saveTargets(cols.concat([{ path: v, docs: '/man/docs' }])).then(renderIndex); }
    addBtn.onclick = doAdd; inp.onkeydown = function (e) { if (e.key === 'Enter') doAdd(); };
    addWrap.append(inp, addBtn); body.appendChild(addWrap);
    if (!cols.length) { body.appendChild(el('div', 'cov-secsub', 'No collections yet — register a target above.')); return; }
    var list = el('div', 'cov-scroll');
    cols.forEach(function (c) {
      var path = collPath(c);
      var row = el('div', 'cov-coll');
      var main = el('div', 'cov-coll-main');
      main.appendChild(el('div', 'cov-coll-name', collLabel(path)));
      main.appendChild(el('div', 'cov-coll-path', path));
      row.append(main, el('span', 'cov-coll-open', 'Open ›'));
      var x = el('span', 'cov-act', '×'); x.title = 'remove from the registry';
      x.onclick = function (e) { e.stopPropagation(); saveTargets(cols.filter(function (q) { return collPath(q) !== path; })).then(renderIndex); };
      row.appendChild(x);
      row.onclick = function () { location.hash = path; };
      list.appendChild(row);
    });
    body.appendChild(list);
  });
}

// resolve the hash: empty (or no registered match) → index; otherwise the
// matched collection + a tail (doc name or "coverage").
function route() {
  var h = decodeURIComponent(location.hash.slice(1));
  var go = function (cols) {
    COLLECTIONS = cols;
    var col = h ? matchCollection(h, cols) : '';
    if (!col) { renderIndex(); return; }
    var tail = h.slice(col.length).replace(/^\//, '');
    var show = function () {
      if (tail === 'coverage') renderCoverage();
      else openDoc(tail || (leaves[0] && leaves[0].path));
    };
    if (col === CUR && tree.length) { show(); return; }   // same collection, nav cached
    CUR = col;
    loadNav().then(show);
  };
  if (COLLECTIONS.length) go(COLLECTIONS);
  else loadTargets().then(go);
}

function start() {
  wireSidebarCollapse();
  route();
}

INPUT.addEventListener('input', onInput);
INPUT.addEventListener('focus', function () { if (INPUT.value.trim()) showResults(); });
INPUT.addEventListener('keydown', function (e) {
  if (e.key === 'ArrowDown') {
    e.preventDefault();
    if (results.length) { sel = (sel + 1) % results.length; paintSel(); }
  } else if (e.key === 'ArrowUp') {
    e.preventDefault();
    if (results.length) { sel = (sel - 1 + results.length) % results.length; paintSel(); }
  } else if (e.key === 'Enter') {
    e.preventDefault();
    if (sel >= 0) choose(sel);
  } else if (e.key === 'Escape') {
    e.preventDefault();
    INPUT.value = ''; results = []; sel = -1; hideResults(); INPUT.blur();
  }
});

// ⌘K / Ctrl-K focuses the top-right box (does not open a modal).
document.addEventListener('keydown', function (e) {
  if ((e.metaKey || e.ctrlKey) && (e.key === 'k' || e.key === 'K')) {
    e.preventDefault();
    INPUT.focus();
    INPUT.select();
  }
});
// click outside the search area closes the dropdown
document.addEventListener('click', function (e) {
  if (!WRAP.contains(e.target)) hideResults();
});
window.addEventListener('hashchange', route);

start();
