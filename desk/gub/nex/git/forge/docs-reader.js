// Grubbery docs reader. Static shell + data endpoints: pull the nav tree,
// pull one doc's raw markdown on demand, render client-side with marked.
// Sidebar is a recursive tree (sections + docs). Search lives in the top-right
// input; ⌘K focuses it; results drop down beneath it from the server-side
// /search endpoint (the ship greps its own grubs).
'use strict';

// forge per-repo reader: served at /grubbery/forge/repo/<name>/docs, so derive
// the repo and the API base from our own path. One collection (this repo) — no
// ?c= scoping, no collection index; the hash is just #<repo>/<tail>.
var REPO = (location.pathname.match(/\/repo\/([^\/]+)\/docs/) || [])[1] || '';
var BASE = location.pathname.replace(/\/+$/, '');
var NAV = document.getElementById('nav');
var DOC = document.getElementById('doc');
var OTP = document.getElementById('onthispage');
var WRAP = document.getElementById('search-wrap');
var INPUT = document.getElementById('search-input');
var RESULTS = document.getElementById('search-results');

var tree = [];
var leaves = [];
var textCache = {};
var blocksCache = {};   // doc path -> its resolved live blocks (from /page)
var results = [];   // current search hits
var sel = -1;       // highlighted result index
var searchTimer = null;

// single-repo routing: the hash is #<repo>/<tail> where tail is a doc name or
// "coverage". CUR is the repo (set once at start).
var CUR = '';           // the repo in view
var CUR_SECTION = '';   // active coverage section (empty = whole collection)

// the sidebar TOC always carries inline coverage signal per scoped node (a
// freshness-colored %); these hold the summaries it reads.
var covSecByName = null;   // section-title -> summary {covered,total,status}; null = unloaded
var covOverall = null;     // whole-collection {covered,total,drifted}; null = unloaded


// hashFor: the URL hash for a doc/coverage within the current collection.
function hashFor(tail) { return '#' + CUR + (tail ? '/' + tail : ''); }
// withC: scope a per-collection API url to the current collection. The hash
// is client-only, so the collection path rides on the request as ?c=<path>.
function withC(url) { return url; }  // BASE is already repo-scoped by the path

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
  upgradeCallouts();
  upgradeLiveBlocks();
  upgradeStaticBlocks();
  buildOnThisPage();
}

// A blockquote whose first line is `[!type] optional title` becomes a colored
// callout box (type ∈ background|note|tip|warn). Markdown has no native
// admonition; this is our convention, transformed after marked parses.
function calloutLabel(t) {
  return { background: 'Background', note: 'Note', tip: 'Tip', warn: 'Warning', warning: 'Warning' }[t]
    || (t.charAt(0).toUpperCase() + t.slice(1));
}
function upgradeCallouts() {
  var bqs = DOC.querySelectorAll('blockquote');
  for (var i = 0; i < bqs.length; i++) {
    var bq = bqs[i];
    var first = bq.querySelector('p');
    if (!first) continue;
    var m = /^\s*\[!(\w+)\]\s*([\s\S]*)$/.exec(first.innerHTML);
    if (!m) continue;
    var type = m[1].toLowerCase();
    var box = document.createElement('div');
    box.className = 'callout callout-' + type;
    var head = document.createElement('div');
    head.className = 'callout-h';
    head.innerHTML = m[2].trim() || calloutLabel(type);
    box.appendChild(head);
    first.remove();                         // consume the marker line
    while (bq.firstChild) box.appendChild(bq.firstChild);
    bq.replaceWith(box);
  }
}

// ---- "On this page": a scroll-spied TOC of the current doc's headings ----
var otpObserver = null;
function slugify(t) {
  return t.toLowerCase().replace(/[^\w]+/g, '-').replace(/^-+|-+$/g, '');
}
function clearOnThisPage() {
  if (otpObserver) { otpObserver.disconnect(); otpObserver = null; }
  if (OTP) { OTP.innerHTML = ''; OTP.hidden = true; }
}
function buildOnThisPage() {
  if (!OTP) return;
  clearOnThisPage();
  var hs = DOC.querySelectorAll('h2, h3, h4');
  if (hs.length < 2) return;   // nothing worth a rail
  OTP.appendChild(el('div', 'otp-h', 'On this page'));
  var byId = {}, used = {};
  for (var i = 0; i < hs.length; i++) {
    var h = hs[i];
    // unique id even when two headings share text (e.g. the same subsection
    // name under two different parents) — the scroll-spy keys on it.
    var base = slugify(h.textContent) || ('h' + i);
    var id = base, n = 2;
    while (used[id]) { id = base + '-' + n; n++; }
    used[id] = true;
    h.id = id;
    var cls = h.tagName === 'H4' ? 'lvl4' : h.tagName === 'H3' ? 'lvl3' : null;
    var a = el('a', cls, h.textContent);
    a.href = '#';
    (function (el2) { a.onclick = function (e) { e.preventDefault(); el2.scrollIntoView({ behavior: 'smooth', block: 'start' }); }; })(h);
    OTP.appendChild(a);
    byId[id] = a;
  }
  OTP.hidden = false;
  // scroll-spy: the heading nearest the top of the viewport is the active one.
  otpObserver = new IntersectionObserver(function (ents) {
    ents.forEach(function (en) {
      if (!en.isIntersecting) return;
      var links = OTP.querySelectorAll('a');
      for (var j = 0; j < links.length; j++) links[j].classList.remove('active');
      var a = byId[en.target.id];
      if (a) a.classList.add('active');
    });
  }, { root: document.getElementById('content'), rootMargin: '0px 0px -72% 0px', threshold: 0 });
  for (var k = 0; k < hs.length; k++) otpObserver.observe(hs[k]);
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
    return fetch('/grubbery/ball/apps/explorer.explorer/hoon-grammar.json')
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

// resolves once the code is in the element (highlighted, or plain when the
// highlighter is unavailable), so a caller can wait for the layout to settle
function highlightInto(el, path, code) {
  return ensureShiki().then(function (hl) {
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
  if (CUR_SECTION) u += (u.indexOf('?') >= 0 ? '&' : '?') + 'section=' + encodeURIComponent(CUR_SECTION);
  return fetch(u, { cache: 'no-store' })
    .then(function (r) { return r.ok ? r.json() : { files: [] }; })
    .then(function (c) { cov = c || { files: [] }; covLoaded = true; return cov; })
    .catch(function () { cov = { files: [] }; covLoaded = true; return cov; });
}
// the commit(s) a file's coverage is pinned at: the distinct pins of the
// blocks that cite it (short). One pin is the usual case; several when
// different pages pinned the file at different commits.
function filePins(f) {
  var seen = {}, out = [];
  (f.anchors || []).forEach(function (a) {
    if (a.status === 'gone' || !a.commit) return;
    var s = a.commit.slice(0, 7);
    if (!seen[s]) { seen[s] = true; out.push(s); }
  });
  return out;
}
// "<pin> " as a muted prefix before a file name: the commit the file's
// coverage is AT (its blocks' pin), which is what the file view shows
function pinStamp(f) {
  var pins = filePins(f);
  var s = el('span', 'cov-head', pins.length ? pins[0] + (pins.length > 1 ? '+' + (pins.length - 1) : '') + ' ' : '');
  if (pins.length) s.title = 'coverage pinned at ' + pins.join(', ');
  return s;
}
// the per-section coverage summaries the sidebar dashboard renders. One read
// of the whole coverage.json (which carries `sections`), cached until the
// collection changes (loadNav nulls it). The browser is still a pure reader.
function ensureCovSummary(cb) {
  if (covSecByName) { if (cb) cb(); return; }
  fetch(withC(BASE + '/coverage.json'), { cache: 'no-store' })
    .then(function (r) { return r.ok ? r.json() : {}; })
    .then(function (c) {
      var secs = c.sections || [];
      covSecByName = {};
      secs.forEach(function (s) { covSecByName[s.name] = s; });
      // the top indicator is the APEX of the section rollup — drifted iff any
      // scoped section is (grouping nodes already derive from their leaves).
      var anyDrift = secs.some(function (s) { return s.status === 'drifted'; });
      // apex % = the union of the TOP-LEVEL scoped sections (a group's total
      // already dedupes within it). NOT c.coveredLines/totalLines — that
      // denominator is the whole mirror (all of base+grubbery), so it rounds to
      // 0%; we only document the scoped code, so that's the honest denominator.
      var cvd = 0, tot = 0;
      (tree || []).forEach(function (n) {
        var s = n.cov && covSecByName[n.title];
        if (s) { cvd += s.covered || 0; tot += s.total || 0; }
      });
      covOverall = { covered: cvd, total: tot, drifted: anyDrift ? 1 : 0 };
      if (cb) cb();
    })
    .catch(function () { covSecByName = {}; if (cb) cb(); });
}
function covFile(file) {
  if (!cov || !cov.files) return null;
  for (var i = 0; i < cov.files.length; i++) if (cov.files[i].file === file) return cov.files[i];
  return null;
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
// a block's range key, the same spelling coverage uses for its chips: "from-to",
// or "all" for a whole-file block (which the ship encodes as to: 0)
function rangeStr(r) { return (r && r.to) ? (r.from + '-' + r.to) : 'all'; }
function flashEl(e) { var o = e.style.boxShadow; e.style.transition = 'box-shadow .2s'; e.style.boxShadow = '0 0 0 3px #ffd98a'; setTimeout(function () { e.style.boxShadow = o; }, 1400); }
// bring the pending block into view. Called twice per arrival: once as soon
// as the blocks are mounted (so the jump is immediate), and again with
// settled=true once every block's code has been highlighted — the bodies
// above the target grow when their code lands, which would otherwise push
// it back out of view. The target keeps a marked outline (.live-focus)
// until the next page renders; a flash was gone before the layout settled.
function scrollToBlock(settled) {
  if (!pendingScroll) return;
  var ws = document.querySelectorAll('.live-wrap');
  for (var i = 0; i < ws.length; i++) {
    if (ws[i].dataset.file === pendingScroll.file && ws[i].dataset.range === pendingScroll.range) {
      ws[i].classList.add('live-focus');
      ws[i].scrollIntoView({ block: 'start' });
      if (settled) pendingScroll = null;
      return;
    }
  }
  if (settled) pendingScroll = null;   // no such block on this page: stop looking
}
function goToDoc(doc, file, rstr) {
  if (typeof closeHeatmapModal === 'function') closeHeatmapModal();
  pendingScroll = { file: file, range: rstr };
  // the page is already up (its blocks highlighted): one settled jump
  if (decodeURIComponent(location.hash.slice(1)) === CUR + '/' + doc) scrollToBlock(true);
  else location.hash = hashFor(doc);   // hashchange -> openDoc -> runUpgrade -> scrollToBlock
}
// jump from a live block in a doc to that span in Coverage: open the block's
// OWN section page (the section whose page is this doc) and pop the file's
// heatmap at the line. covFocus is consumed by renderSection once it renders.
function goToCoverage(doc, file, range) {
  covFocus = { file: file, from: range ? range.from : 1 };
  var node = doc && findNavByPath(tree, doc);
  var tail = node ? 'coverage/' + encodeURIComponent(node.title) : 'coverage';
  if (decodeURIComponent(location.hash.slice(1)) === CUR + '/' + tail) {
    if (node) renderSection(node.title); else renderCoverage();
  } else location.hash = hashFor(tail);
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

// the ship precomputes each block's status, so no coverage fetch is needed to
// render live blocks — runUpgrade reads the blocks the page shipped with.
function upgradeLiveBlocks() { runUpgrade(); }
// one ship-side verdict as a badge, always naming the HEAD it was computed
// against (and, for drift, the pinned commit it diverged from).
function statusBadge(status, head, pin) {
  var b = document.createElement('span');
  b.className = 'live-fresh';
  var vs = head ? ' · ' + head : '';
  var base = 'margin-left:auto;font:11px/1 ui-monospace,monospace;padding:2px 6px;border-radius:4px;';
  if (status === 'drifted') {
    b.textContent = '⚠ drifted' + vs; b.style.cssText = base + 'color:#9a6700;background:#fff8c5';
    b.title = 'pinned at ' + (pin || '?') + '; the cited lines changed as of HEAD ' + (head || '?');
  } else if (status === 'gone') {
    b.textContent = '⚠ gone' + vs; b.style.cssText = base + 'color:#a40e26;background:#fdecea';
    b.title = 'the anchored file or range no longer resolves at HEAD ' + (head || '?');
  } else {
    b.textContent = '✓ fresh' + vs; b.style.cssText = base + 'color:#1a7f37;background:#dafbe1';
    b.title = 'the slice at ' + (pin || 'HEAD') + ' matches HEAD ' + (head || '?');
  }
  return b;
}
function runUpgrade() {
  var doc = decodeURIComponent(location.hash.slice(1)).slice(CUR.length).replace(/^\//, '');
  var resolved = blocksCache[doc] || [];
  var blocks = DOC.querySelectorAll('pre > code.language-live');
  var settles = [];   // one promise per block body, resolved when its code is in
  for (var i = 0; i < blocks.length; i++) {
    (function (code, blk) {
      // prefer the ship's resolved block; fall back to parsing the fence ref.
      var parts = code.textContent.trim().split(/\s+/);
      var fileTok = parts[0], at = fileTok.indexOf('@');
      var path = blk ? blk.file : (at >= 0 ? fileTok.slice(0, at) : fileTok);
      var range = blk ? { from: blk.from, to: blk.to } : parseRange(parts[1]);
      var rLabel = range ? (range.to && range.to !== range.from ? range.from + '-' + range.to : '' + range.from) : '';
      var short = blk ? (blk.short || '') : (at >= 0 ? fileTok.slice(at + 1, at + 8) : '');
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
      label.textContent = path + (rLabel ? '  ' + rLabel : '');
      head.appendChild(label);
      // the short commit this block is pinned to (full hash on hover)
      if (short) {
        var sc = document.createElement('span');
        sc.textContent = short;
        sc.title = (blk && blk.commit) ? blk.commit : short;
        sc.style.cssText = 'margin-left:8px;color:#8b949e;font:11px/1 ui-monospace,monospace';
        head.appendChild(sc);
      }
      // link back to this span in the coverage heatmap
      var covLink = document.createElement('span');
      covLink.textContent = ' ▤';
      covLink.title = 'show this span in Coverage';
      covLink.style.cssText = 'cursor:pointer;color:#b0b6bd;margin-left:6px;font-size:11px';
      covLink.onmouseenter = function () { covLink.style.color = '#57606a'; };
      covLink.onmouseleave = function () { covLink.style.color = '#b0b6bd'; };
      (function (dc, p, r) { covLink.onclick = function () { goToCoverage(dc, p, r); }; })(doc, path, range);
      head.appendChild(covLink);
      var body = document.createElement('div');
      body.className = 'live-body';
      host.appendChild(head);
      host.appendChild(body);
      pre.replaceWith(host);
      // the lines were resolved on the ship AT THE PINNED COMMIT — just display.
      if (blk && blk.lines) {
        settles.push(highlightInto(body, path, blk.lines.join('\n')));
        head.appendChild(statusBadge(blk.status, blk.head, short));
      } else {
        body.textContent = 'could not load ' + path;
        head.appendChild(statusBadge('gone', blk ? blk.head : '', short));
      }
    })(blocks[i], resolved[i]);
  }
  // arrived here to focus a specific block: jump now, and again once every
  // block's code is in and the page has its final height
  scrollToBlock(false);
  Promise.all(settles).then(function () { requestAnimationFrame(function () { scrollToBlock(true); }); });
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
  clearOnThisPage();
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
  // load THIS doc's section coverage so the live-block badges have per-file
  // anchors — the whole view is slimmed to files:[], so it can't source them.
  var sec = findNavByPath(tree, path);
  CUR_SECTION = (sec && sec.cov) ? sec.title : '';
  covLoaded = false;
  if (textCache[path] != null) { render(textCache[path]); addDocTabs(path); return; }
  showLoading();
  // one fetch gets the markdown AND the page's live blocks already resolved
  // (lines at the pinned commit, short commit, status) — the ship precomputed
  // them, so the browser does no per-block source fetch.
  fetch(withC(BASE + '/page?path=' + encodeURIComponent(path)))
    .then(function (r) { return r.ok ? r.json() : Promise.reject(r.status); })
    .then(function (obj) {
      textCache[path] = obj.markdown || '';
      blocksCache[path] = obj.blocks || [];
      render(textCache[path]); addDocTabs(path);
    })
    .catch(function () { DOC.innerHTML = '<p id="empty">Could not load this doc.</p>'; });
}
// a scoped page reads as [ Text | Coverage ]: prepend the tabs above its
// markdown so its coverage is one click away (and the same node, one URL).
function addDocTabs(path) {
  var node = findNavByPath(tree, path);
  if (!node || !node.cov) return;
  coverageStyles();
  DOC.insertBefore(nodeTabBar(node, 'text'), DOC.firstChild);
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

// dashboard mode: a scoped node's freshness-colored % (green fresh, amber
// drifted), right-aligned beside its name. Returns null when the toggle is off
// or this node's summary hasn't loaded yet — the row then stays a plain entry.
function covPct(title) {
  var s = covSecByName && covSecByName[title];
  if (!s) return null;
  var drift = s.status === 'drifted';
  var p = s.total ? Math.round(100 * s.covered / s.total) : 0;
  var span = el('span', 'nav-cov-pct ' + (drift ? 'd' : 'f'), p + '%');
  span.title = 'open ' + title + ' coverage';
  // the % is the way into this node's coverage view — for a grouping section
  // that's its rolled-up aggregate, embedded right here in the TOC.
  (function (nm) { span.onclick = function (e) { e.stopPropagation(); location.hash = hashFor('coverage/' + encodeURIComponent(nm)); }; })(title);
  return span;
}

function renderTree(items, container) {
  items.forEach(function (it) {
    if (it.path) {
      var li = document.createElement('li');
      li.appendChild(docLink(it));
      // dashboard mode: a scoped page carries its freshness % beside its name.
      // Coverage itself is reached via the page's Coverage tab, not from here.
      var ppct = it.cov && covPct(it.title);
      if (ppct) {
        li.style.display = 'flex';
        li.style.alignItems = 'center';
        li.firstChild.style.flex = '1';
        li.firstChild.style.overflow = 'hidden';
        li.appendChild(ppct);
      }
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
      // dashboard mode: the section's rolled-up freshness %, beside its title.
      var spct = it.cov && covPct(it.title);
      if (spct) head.appendChild(spct);
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
  idx.textContent = '‹ Handbook';
  idx.href = '#';
  idx.style.cssText = 'display:block;margin-bottom:10px;color:#79808a;font-size:12px';
  idx.onclick = function (e) { e.preventDefault(); location.hash = hashFor((leaves[0] && leaves[0].path) || ''); };
  NAV.appendChild(idx);
  // the sidebar IS the coverage map. The top row links to the full Coverage
  // overview and carries the whole-collection apex % (drifted iff any scoped
  // section is); each scoped node below carries its own freshness %.
  var covRow = el('div', 'cov-toggle');
  var lnk = el('a', 'cov-toplink', 'Coverage');
  lnk.href = hashFor('coverage');
  lnk.onclick = function (e) { e.preventDefault(); location.hash = hashFor('coverage'); };
  covRow.appendChild(lnk);
  if (covOverall && covOverall.total) {
    var op = Math.round(100 * covOverall.covered / covOverall.total);
    var ospan = el('span', 'nav-cov-pct ' + (covOverall.drifted > 0 ? 'd' : 'f'), op + '%');
    ospan.title = 'whole-collection coverage';
    ospan.onclick = function () { location.hash = hashFor('coverage'); };
    covRow.appendChild(ospan);
  }
  NAV.appendChild(covRow);
  renderTree(tree, NAV);
  var tail = decodeURIComponent(location.hash.slice(1)).slice(CUR.length).replace(/^\//, '');
  if (tail) markActive(tail);
  // summaries not yet read: fetch once, then repaint the tree with them.
  if (!covSecByName) ensureCovSummary(showNav);
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
// browser only reads and renders. Heatmap source comes from /slice (HEAD).


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
    '.cov-head{display:flex;align-items:baseline;justify-content:space-between;gap:12px}' +
    '.cov-link{font-size:12px;color:#57606a;text-decoration:none;border:1px solid #e2e7ee;border-radius:7px;padding:4px 10px;white-space:nowrap}' +
    '.cov-link:hover{background:#fafbfc;color:#1f2328}' +
    '.cov-back{display:inline-block;font-size:12px;color:#79808a;text-decoration:none;margin:0 0 10px}' +
    '.cov-back:hover{color:#1f2328}' +
    '.cov-file-rng{color:#8a929c;font-weight:400}' +
    '.cov-target{display:flex;align-items:center;gap:12px;margin:0 0 20px;flex-wrap:wrap}' +
    '.cov-target-lab{font:10.5px -apple-system,sans-serif;text-transform:uppercase;letter-spacing:.05em;color:#9aa0a8}' +
    '.cov-target-path{font:12px ui-monospace,monospace;color:#57606a}' +
    '.cov-src-chip{display:inline-flex;align-items:center;gap:7px}' +
    '.cov-src-tag{font:11px ui-monospace,monospace;background:#eef2f7;color:#3a4149;border-radius:5px;padding:2px 7px}' +
    '.cov-src-path{font:12px ui-monospace,monospace;color:#8a929c}' +
    '.cov-seclist{display:flex;flex-direction:column;gap:8px}' +
    '.cov-secrow{display:grid;grid-template-columns:1fr 52px 120px 14px;gap:14px;align-items:center;padding:13px 14px;border:1px solid #eef0f3;border-radius:8px;text-decoration:none;background:#fff}' +
    '.cov-secrow:hover{background:#fafbfc;border-color:#e2e7ee}' +
    '.cov-secrow.dr{border-color:#f0dcae;background:#fffdf8}' +
    '.cov-secrow-main{min-width:0}' +
    '.cov-secrow-name{font:14px -apple-system,sans-serif;font-weight:600;color:#1f2328}' +
    '.cov-secrow-sub{font:11.5px ui-monospace,monospace;color:#8a929c;margin-top:2px}' +
    '.cov-secrow.dr .cov-secrow-sub{color:#9a6700}' +
    '.cov-secrow-pct{font:15px -apple-system,sans-serif;font-weight:600;color:#1f2328;text-align:right}' +
    '.cov-secrow-go{color:#b0b6bd;font-size:16px;text-align:center}' +
    '.cov-secgroup{font:11px -apple-system,sans-serif;text-transform:uppercase;letter-spacing:.05em;color:#9aa0a8;margin:12px 0 0}' +
    '.cov-row{display:grid;grid-template-columns:1fr 84px 108px 108px 20px;gap:12px;align-items:center;padding:9px 4px;border-bottom:1px solid #f2f4f6;cursor:pointer}' +
    '.cov-row:hover{background:#fafbfc}.cov-row.cov-gap{cursor:default}.cov-row.cov-gap .cov-file{color:#a40e26}' +
    '.cov-file{font:12.5px ui-monospace,monospace;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +
    '.cov-head{color:#8b949e}' +
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
    '.cov-src .ln[data-line]:hover{filter:brightness(0.97)}' +
    '.cov-src{margin:0;border:1px solid #eef0f3;border-radius:6px;overflow:auto;max-height:60vh}' +
    '.cov-src pre{margin:0;font:11.5px/1.5 ui-monospace,monospace}' +
    '.cov-src .ln{display:block;padding:0 10px;white-space:pre;color:#8a929c;border-left:2px solid transparent}' +
    '.cov-src .ln.on{background:#e6f4ea;color:#1f2328;box-shadow:inset 3px 0 #1a7f37}' +
    '.cov-src .ln.dr{background:#fff4e0;box-shadow:inset 3px 0 #9a6700}' +
    // segment boundaries: a rule where a block starts, alternating tint for
    // abutting blocks, and a label on each block\'s first line naming its doc
    '.cov-src .ln.a-top{border-top:0}' +
    '.cov-src .ln.a-bot{border-bottom:1px solid #9ccfae}' +
    '.cov-src .ln.on.alt{background:#d9eee0}' +
    '.cov-src .ln.dr.a-top,.cov-src .ln.dr.a-bot{border-color:#e8c97a}' +
    '.cov-src .a-hdr{display:block;padding:4px 10px 3px 14px;background:#f3faf5;border-top:1px solid #9ccfae;white-space:normal;line-height:1.3}' +
    '.cov-src .a-hdr.dr{background:#fffaf0;border-top-color:#e8c97a}' +
    '.cov-src .a-lab{display:inline-block;font:10px/1.6 ui-monospace,monospace;color:#1a7f37;background:#fff;border:1px solid #bfe0c9;border-radius:4px;padding:0 6px;margin:0 6px 0 0;cursor:pointer}' +
    '.cov-src .a-lab:hover{background:#e6f4ea}' +
    '.cov-src .a-hdr.dr .a-lab{color:#9a6700;border-color:#f0dcae}' +
    // scope outline: dim lines outside a section\'s scope, bracket those inside it
    '.cov-src .ln.sc-out{opacity:.32}' +
    '.cov-src .ln.sc{border-left-color:#8b93e6}' +
    '.cov-src .ln.sc-top{border-top:1px solid #8b93e6}' +
    '.cov-src .ln.sc-bot{border-bottom:1px solid #8b93e6}' +
    '.cov-scope-note{font:11px -apple-system,sans-serif;color:#5960b8;background:#f2f3ff;padding:5px 12px;border-bottom:1px solid #e3e5fb;position:sticky;top:0}' +
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
    '.cov-secbar{display:flex;flex-wrap:wrap;gap:6px;align-items:center;margin:0 0 16px}' +
    '.cov-secbar-lab{font-size:10.5px;text-transform:uppercase;letter-spacing:.05em;color:#9aa0a8;margin-right:2px}' +
    '.cov-secpill{font:12px -apple-system,sans-serif;padding:4px 11px;border-radius:13px;background:#fff;border:1px solid #e2e7ee;color:#57606a;cursor:pointer}' +
    '.cov-secpill:hover{background:#fafbfc}.cov-secpill.on{background:#1f2328;border-color:#1f2328;color:#fff}' +
    '.cov-secname{font:13px ui-monospace,monospace;font-weight:600;color:#1f2328}' +
    '.cov-secwarn{display:flex;align-items:center;gap:12px;padding:9px 12px;margin:0 0 16px;background:#fff8ec;border:1px solid #f0dcae;border-radius:8px;font-size:12.5px;color:#9a6700}' +
    '.cov-secwarn-txt{flex:1}' +
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
function renderHeatmap(f, focusLine) {
  var wrap = el('div', 'cov-heat');
  var coveredSet = {}, driftSet = {}, lineAnchors = {};
  (f.ranges || []).forEach(function (r) { for (var n = r[0]; n <= r[1]; n++) coveredSet[n] = true; });
  // every block (anchor) touching each line, in document order; blocks may
  // abut or overlap, so a line can belong to several
  var live = (f.anchors || []).filter(function (a) { return a.status !== 'gone'; });
  live.forEach(function (a, idx) {
    a._idx = idx;
    a._hi = a.to === 0 ? f.total : a.to;
    for (var n = a.from; n <= a._hi; n++) {
      if (a.status === 'drifted') driftSet[n] = true;
      (lineAnchors[n] = lineAnchors[n] || []).push(a);
    }
  });
  // the block a line "belongs" to for tint and click: the narrowest one
  // touching it (the most specific when blocks overlap)
  function ownerOf(n) {
    var as = lineAnchors[n] || [];
    var best = null;
    as.forEach(function (a) { if (!best || (a._hi - a.from) < (best._hi - best.from)) best = a; });
    return best;
  }
  function jump(an) { var rs = an.to === 0 ? 'all' : (an.from + '-' + an.to); goToDoc(an.doc, f.file, rs); }
  var slices = el('div', 'cov-slices');
  slices.appendChild(el('span', 'cov-slices-lab', 'Referenced by'));
  (f.anchors || []).forEach(function (a) {
    if (a.status === 'gone') return;
    var hi = a.to === 0 ? f.total : a.to;
    var chip = el('span', 'cov-slice' + (a.status === 'drifted' ? ' dr' : ''), 'lines ' + a.from + '–' + hi + ' · ' + a.doc);
    chip.title = 'go to this block in ' + a.doc;
    (function (an) { var rs = an.to === 0 ? 'all' : (an.from + '-' + an.to); chip.onclick = function () { goToDoc(an.doc, f.file, rs); }; })(a);
    slices.appendChild(chip);
  });
  wrap.appendChild(slices);
  // in-scope line set — when a section scopes this file to certain ranges, we
  // outline those ranges in the source and dim everything outside them.
  var scopeSet = {};
  (f.scope || []).forEach(function (r) { for (var n = r[0]; n <= r[1]; n++) scopeSet[n] = true; });
  var src = el('div', 'cov-src'); src.appendChild(codeSkeleton(10));
  wrap.appendChild(src);
  // the file AT ITS COVERAGE'S PIN: the blocks' line ranges are at their
  // pinned commit, so the source is read at that commit and the painted
  // ranges are the lines the blocks actually cite. With blocks pinned at
  // several commits the first pin is shown (its own blocks align; the
  // others' chips still open their page). No pins: HEAD.
  var pins = filePins(f);
  var at = pins.length ? (f.anchors || []).filter(function (a) { return a.commit && a.commit.slice(0, 7) === pins[0]; })[0].commit : '';
  fetch(withC(BASE + '/slice?file=' + encodeURIComponent(f.file) + (at ? '&commit=' + encodeURIComponent(at) : '')), { cache: 'no-store' })
    .then(function (r) { return r.ok ? r.text() : ''; })
    .then(function (text) {
      src.textContent = '';
      var nLines = text.split('\n').length;
      var scopeCount = Object.keys(scopeSet).length;
      // only outline when scope is a proper subset (a section) — not the whole
      // file (the whole-collection view, where every line is "in scope").
      var partial = (f.scope && f.scope.length) && scopeCount > 0 && scopeCount < nLines;
      if (partial) {
        var note = el('div', 'cov-scope-note', '◈ outlined lines are this section’s scope');
        src.appendChild(note);
      }
      var pre = document.createElement('pre');
      text.split('\n').forEach(function (line, i) {
        var n = i + 1;
        var cls = 'ln' + (driftSet[n] ? ' dr' : coveredSet[n] ? ' on' : '');
        if (partial) {
          if (scopeSet[n]) {
            cls += ' sc';
            if (!scopeSet[n - 1]) cls += ' sc-top';
            if (!scopeSet[n + 1]) cls += ' sc-bot';
          } else cls += ' sc-out';
        }
        var a = ownerOf(n);
        // boundaries: a rule where any block starts or ends, and alternate
        // tint by block so two abutting blocks read as two
        var starts = (lineAnchors[n] || []).filter(function (x) { return x.from === n; });
        var ends = (lineAnchors[n] || []).filter(function (x) { return x._hi === n; });
        if (starts.length) cls += ' a-top';
        if (ends.length) cls += ' a-bot';
        if (a && (a._idx % 2)) cls += ' alt';
        var d = el('span', cls, (n + '  ').slice(0, 4) + '  ' + line);
        d.dataset.line = n;
        if (a) {
          d.style.cursor = 'pointer';
          d.title = 'covered by ' + a.doc + ' (' + a.from + '–' + a._hi + ') — click to open';
          (function (an) { d.onclick = function () { jump(an); }; })(a);
        }
        // where a block starts, its own header row above the first line
        // (one label per block starting here; overlapping blocks each get
        // theirs) — a row of its own, so it never sits over code
        if (starts.length) {
          var hdr = el('span', 'a-hdr' + (a && a.status === 'drifted' ? ' dr' : ''));
          starts.forEach(function (an) {
            var lab = el('span', 'a-lab', an.doc + ' · ' + an.from + '–' + an._hi);
            lab.title = 'open this block in ' + an.doc;
            (function (x) { lab.onclick = function (e) { e.stopPropagation(); jump(x); }; })(an);
            hdr.appendChild(lab);
          });
          hdr.appendChild(document.createTextNode('\n'));
          pre.appendChild(hdr);
        }
        d.appendChild(document.createTextNode('\n'));
        pre.appendChild(d);
      });
      src.appendChild(pre);
      // arrived from a doc's block: focus its first line once the source is
      // actually here (the fetch decides when, not a timer)
      if (focusLine) {
        var ln = pre.querySelector('.ln[data-line="' + focusLine + '"]');
        if (ln) { ln.scrollIntoView({ block: 'center' }); flashEl(ln); }
      }
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
  var title = el('div', 'cov-modal-file'); title.title = f.file;
  title.appendChild(pinStamp(f));
  title.appendChild(document.createTextNode(f.file));
  var meta = el('span', 'cov-modal-meta', (f.total ? Math.round(100 * pct(f)) + '%' : '—') + ' · ' + f.covered + '/' + f.total + ' lines' + (f.extra ? ' · extra credit' : ''));
  var close = el('button', 'cov-modal-x', '×'); close.title = 'close (Esc)'; close.onclick = closeHeatmapModal;
  hdr.append(title, meta, close);
  var body = el('div', 'cov-modal-body');
  body.appendChild(renderHeatmap(f, focusLine));
  panel.append(hdr, body); ov.appendChild(panel);
  ov.onclick = function (e) { if (e.target === ov) closeHeatmapModal(); };
  covModalEsc = function (e) { if (e.key === 'Escape') closeHeatmapModal(); };
  document.addEventListener('keydown', covModalEsc);
  document.body.appendChild(ov);
}

// one file's coverage row: bar, percent, freshness flags, click-to-expand.
// Everything is read from the ship's coverage.json — no client computation.
// format compressed [lo,hi] ranges as "12–40, 88" (single-line lines collapse).
function rangeText(ranges) {
  return (ranges || []).map(function (r) { return r[0] === r[1] ? ('' + r[0]) : (r[0] + '–' + r[1]); }).join(', ');
}
function fileRow(f, label, showScope) {
  var gap = !f.covered && !f.extra;
  var row = el('div', 'cov-row' + (gap ? ' cov-gap' : '') + (f.extra ? ' cov-extra' : ''));
  row.dataset.file = f.file;
  var nm = el('div', 'cov-file'); nm.title = f.file;
  nm.appendChild(pinStamp(f));
  nm.appendChild(document.createTextNode(label || f.file));
  // when a file is in scope only for certain line ranges (a section), show them
  if (showScope && f.scope && f.scope.length) {
    var rt = el('span', 'cov-file-rng', ' ' + rangeText(f.scope));
    rt.title = 'in scope: lines ' + rangeText(f.scope);
    nm.appendChild(rt);
  }
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

// shared: the spinner while coverage loads, and the big "% covered" header.
function covSpinner(body) {
  var load = el('div', 'cov-load');
  load.append(el('span', 'spinner'), el('span', null, 'reading coverage…'));
  body.appendChild(load);
}
function fillOverall(overall, c, nFiles) {
  overall.innerHTML = '';
  if (c.totalLines) {
    overall.append(el('b', null, Math.round(100 * (c.coveredLines || 0) / c.totalLines) + '%'),
      el('span', null, (c.coveredLines || 0) + ' / ' + c.totalLines + ' lines · ' + nFiles + ' files · '),
      el('span', null, (c.fresh || 0) + ' fresh, ' + (c.drifted || 0) + ' drifted, ' + (c.gone || 0) + ' gone'),
      el('span', null, c.head ? ' · vs HEAD ' + c.head : ''));
  } else {
    overall.append(el('span', null, 'No coverage yet.'));
  }
  overall.appendChild(legendTrigger());
}

// whole-collection coverage: overall %, then the file tree. Sections have their
// own pages (the sidebar ◆); config (target + ignored) has its own page.
// coverage landing = a sections overview: every documented section that
// declares a scope, with its % and freshness, linking to its own page. The
// target is shown read-only (it's registered on the index, not editable here).
function renderCoverage() {
  CUR_SECTION = '';
  markActive('coverage');
  DOC.innerHTML = '';
  clearOnThisPage();
  coverageStyles();
  var root = el('div', 'cov');
  root.appendChild(el('h1', null, 'Coverage'));
  root.appendChild(el('p', 'sub', 'Each documented section and how much of the code it covers — measured against the repo at HEAD, each block at its pinned commit.'));
  var srcs = [];
  var tgt = el('div', 'cov-target');
  tgt.appendChild(el('span', 'cov-target-lab', srcs.length === 1 ? 'Source' : 'Sources'));
  if (!srcs.length) tgt.appendChild(el('span', 'cov-target-path', CUR || '(none)'));
  srcs.forEach(function (s) {
    var chip = el('span', 'cov-src-chip');
    chip.append(el('span', 'cov-src-tag', s.tag), el('span', 'cov-src-path', s.path));
    tgt.appendChild(chip);
  });
  root.appendChild(tgt);
  var body = el('div', null); root.appendChild(body);
  DOC.appendChild(root);
  covSpinner(body);
  Promise.all([loadCoverage(), delay(300)]).then(function (r) {
    var c = r[0] || {};
    body.textContent = '';
    var secs = c.sections || [];
    if (!secs.length) {
      body.appendChild(el('div', 'cov-secsub', 'No sections declare coverage yet. Give a nav section a "scope" in the target’s man/docs/docs.json to measure it.'));
      return;
    }
    var byName = {}; secs.forEach(function (s) { byName[s.name] = s; });
    var list = el('div', 'cov-seclist');
    renderCovSections(tree, list, 0, byName);   // walk the nav tree, keep its hierarchy
    body.appendChild(list);
  });
}


// does this nav node, or anything under it, declare a coverage scope?
function hasScopedDescendant(node) {
  if (node.cov) return true;
  return (node.kids || []).some(hasScopedDescendant);
}
// the nav node with this title, at any depth (nav titles are unique).
function findNavByTitle(nodes, title) {
  for (var i = 0; i < (nodes || []).length; i++) {
    if (nodes[i].title === title) return nodes[i];
    var k = nodes[i].kids && findNavByTitle(nodes[i].kids, title);
    if (k) return k;
  }
  return null;
}
// the nav node whose kids contain this title — its parent, or null at the root.
function findNavParent(nodes, title, parent) {
  for (var i = 0; i < (nodes || []).length; i++) {
    if (nodes[i].title === title) return parent || null;
    var k = nodes[i].kids && findNavParent(nodes[i].kids, title, nodes[i]);
    if (k) return k;
  }
  return null;
}
// the nav node whose page is this path (page nodes are unique by path).
function findNavByPath(nodes, path) {
  for (var i = 0; i < (nodes || []).length; i++) {
    if (nodes[i].path === path) return nodes[i];
    var k = nodes[i].kids && findNavByPath(nodes[i].kids, path);
    if (k) return k;
  }
  return null;
}
// the [ Text | Coverage ] tabs for a scoped node. The two tabs ARE the node's
// two routes — #<c>/<path> (its markdown) and #<c>/coverage/<title> (its
// scope + heatmap) — so switching is a hash change, linkable and refresh-safe.
// A grouping section (no .md, coverage rolled up from its kids) gets Coverage
// alone.
function nodeTabBar(node, active) {
  var bar = el('div', 'cov-tabs');
  if (node.path) {
    var t = el('button', 'cov-tab' + (active === 'text' ? ' on' : ''), 'Text');
    (function (p) { t.onclick = function () { if (active !== 'text') location.hash = hashFor(p); }; })(node.path);
    bar.appendChild(t);
  }
  var c = el('button', 'cov-tab' + (active === 'coverage' ? ' on' : ''), 'Coverage');
  (function (nm) { c.onclick = function () { if (active !== 'coverage') location.hash = hashFor('coverage/' + encodeURIComponent(nm)); }; })(node.title);
  bar.appendChild(c);
  return bar;
}
// render every scoped node (section OR page) in its nav-tree position: a scoped
// node is a coverage row, an unscoped section that only groups scoped children
// is a plain header, nesting is shown by indent. Unscoped pages and empty
// branches are skipped.
function renderCovSections(nodes, container, depth, byName) {
  (nodes || []).forEach(function (node) {
    if (!hasScopedDescendant(node)) return;   // nothing measured here or below
    if (node.cov) {
      container.appendChild(covSectionRow(node.title, byName[node.title], depth));
    } else if (!node.path) {
      var h = el('div', 'cov-secgroup', node.title);
      h.style.marginLeft = (depth * 18) + 'px';
      container.appendChild(h);
    }
    renderCovSections(node.kids, container, depth + 1, byName);
  });
}
function covSectionRow(name, s, depth) {
  s = s || { covered: 0, total: 0, status: 'fresh' };
  var p = s.total ? Math.round(100 * s.covered / s.total) : 0;
  var drift = s.status === 'drifted';
  var row = el('a', 'cov-secrow' + (drift ? ' dr' : ''));
  row.style.marginLeft = (depth * 18) + 'px';
  row.href = hashFor('coverage/' + encodeURIComponent(name));
  (function (nm) { row.onclick = function (e) { e.preventDefault(); location.hash = hashFor('coverage/' + encodeURIComponent(nm)); }; })(name);
  var main = el('div', 'cov-secrow-main');
  main.appendChild(el('div', 'cov-secrow-name', name));
  main.appendChild(el('div', 'cov-secrow-sub', s.covered + ' / ' + s.total + ' lines' + (drift ? '  ·  ⟳ drifted' : '')));
  var bar = el('div', 'cov-bar'); var fill = document.createElement('i');
  fill.style.width = p + '%'; if (drift) fill.style.background = '#9a6700';
  bar.appendChild(fill);
  row.append(main, el('div', 'cov-secrow-pct', p + '%'), bar, el('span', 'cov-secrow-go', '›'));
  return row;
}

// one section's own coverage page: its scope as a flat file list WITH line
// ranges, its coverage %, its drift + re-confirm. Linkable at
// #<collection>/coverage/<section>; reached from the sidebar ◆.
function renderSection(name) {
  CUR_SECTION = name;
  DOC.innerHTML = '';
  clearOnThisPage();
  coverageStyles();
  var node = findNavByTitle(tree, name);
  // highlight this node in the sidebar (its doc link, if it's a page).
  markActive(node && node.path ? node.path : null);
  // a grouping node (its coverage rolls up from scoped children) breaks down
  // into those children; a leaf (its own scope) shows its files.
  var grouping = !!(node && (node.kids || []).some(hasScopedDescendant));
  var root = el('div', 'cov');
  // breadcrumb up: to the parent section's coverage when it's a scoped node,
  // else (a top-level section) to the whole-collection Coverage overview.
  var parent = node && findNavParent(tree, name);
  var up = el('a', 'cov-back');
  if (parent && parent.cov) {
    up.textContent = '‹ ' + parent.title;
    up.href = hashFor('coverage/' + encodeURIComponent(parent.title));
    (function (pt) { up.onclick = function (e) { e.preventDefault(); location.hash = hashFor('coverage/' + encodeURIComponent(pt)); }; })(parent.title);
  } else {
    up.textContent = '‹ Coverage';
    up.href = hashFor('coverage');
    up.onclick = function (e) { e.preventDefault(); location.hash = hashFor('coverage'); };
  }
  root.appendChild(up);
  // [ Text | Coverage ] tabs — Text switches to the markdown page. A grouping
  // section (no .md) gets a Coverage-only bar; a scoped page gets both.
  if (node && node.cov) root.appendChild(nodeTabBar(node, 'coverage'));
  root.appendChild(el('h1', null, name));
  root.appendChild(el('p', 'sub', grouping
    ? 'Coverage across the sections this groups — each documenting its own code.'
    : 'Coverage of the code this section documents — its scope, and how much of it a live block embeds.'));
  var overall = el('div', 'cov-overall'); root.appendChild(overall);
  var body = el('div', null); root.appendChild(body);
  DOC.appendChild(root);
  covSpinner(body);
  Promise.all([loadCoverage(), delay(300)]).then(function (r) {
    var c = r[0] || { files: [] };
    body.textContent = '';
    var files = (c.files || []).slice().sort(function (a, b) { return pct(b) - pct(a); });
    fillOverall(overall, c, files.length);
    if (grouping) {
      // the sub-breakdown: each scoped child section/page as its own coverage
      // row (linking to its page), nested by the tree — not a flat file dump.
      ensureCovSummary(function () {
        var byName = covSecByName || {};
        body.appendChild(el('div', 'cov-secsub', 'Sections'));
        var list = el('div', 'cov-seclist');
        renderCovSections(node.kids, list, 0, byName);
        body.appendChild(list);
      });
      covFocus = null;  // a grouping page has no files to focus
      return;
    }
    if (c.section && c.section.status === 'drifted') {
      var warn = el('div', 'cov-secwarn');
      warn.appendChild(el('span', 'cov-secwarn-txt', '⟳ ' + name + ' changed since its blocks were pinned — worth a re-audit; re-pin in the page source when the prose still holds'));
      body.appendChild(warn);
    }
    var hdr = el('div', 'cov-files-hdr');
    hdr.append(el('span', 'cov-secsub', 'Scope — ' + files.length + ' file' + (files.length === 1 ? '' : 's')));
    body.appendChild(hdr);
    var fscroll = el('div', 'cov-scroll cov-scroll-f');
    if (!files.length) fscroll.appendChild(el('div', 'cov-secsub', 'This section declares no coverage scope.'));
    files.forEach(function (f) { fscroll.appendChild(fileRow(f, f.file, true)); });
    body.appendChild(fscroll);
    // arrived from a doc's ◆ (goToCoverage): pop this file's heatmap at the line.
    if (covFocus) {
      var ff = files.filter(function (x) { return x.file === covFocus.file; })[0];
      var fline = covFocus.from; covFocus = null;
      if (ff) showHeatmapModal(ff, fline);
    }
  });
}

// the collection's config, read-only, on its own page (out of coverage). Target
// is registered on the index; ignored is authored in the target's man/docs
// manifest — shown here for reference, edited at their source.
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
  covSecByName = null;   // new collection: its coverage summaries refetch on demand
  covOverall = null;
  return fetch(withC(BASE + '/nav.json'))
    .then(function (r) { return r.json(); })
    .then(function (list) { tree = Array.isArray(list) ? list : []; })
    .catch(function () { tree = []; })
    .then(function () { leaves = collectLeaves(tree, []); showNav(); });
}


// single-repo routing: the hash is #<repo>/<tail> (tail = a doc path, or
// "coverage" / "coverage/<section>"). No collection index — this reader is
// already scoped to one repo by its URL.
function routeTail() {
  var h = decodeURIComponent(location.hash.slice(1));
  var tail = (h === CUR || h.indexOf(CUR + '/') === 0) ? h.slice(CUR.length).replace(/^\//, '') : h;
  if (tail === 'coverage') renderCoverage();
  else if (tail.indexOf('coverage/') === 0) renderSection(tail.slice(9));
  else openDoc(tail || (leaves[0] && leaves[0].path));
}

// ---- the handbook chat: the repo's clanker, in its own pane ----
// forge answers /chat with where the repo clanker's `docs` chat log lives
// (making the clanker and the chat if missing), or null when no clanker
// app is installed. The pane is clanker's viewer.js, the same script the
// explorer mounts on a chat-log, loaded from clanker's route and mounted
// here with the same {url, args} the explorer would hand it.
// The pane lives in a <float-window> (the shared /lib/ui component, bundled
// in components.js): draggable, resizable, snappable. The host element is
// built once and moved into a fresh window on each open, so the mounted
// pane (and what it shows) survives close and reopen; each open starts at
// the default geometry, docked bottom-right.
var chatInfo = null, chatHandle = null, chatWin = null;
var CHAT_TOGGLE = document.getElementById('chat-toggle');
var CHAT_HOST = document.createElement('div');
CHAT_HOST.id = 'chat-host';
var CHAT_DEF = { w: 460, h: 620 };
// docked bottom-right, sitting ABOVE the launcher (46px tall at bottom:22)
function chatDefaultPos() {
  var rightGap = 22, bottomGap = 88;
  return {
    x: Math.max(22, window.innerWidth - CHAT_DEF.w - rightGap),
    y: Math.max(22, window.innerHeight - CHAT_DEF.h - bottomGap),
  };
}
function makeChatWindow() {
  var w = document.createElement('float-window');
  w.setAttribute('title', (REPO || 'repo') + ' handbook chat');
  w.setAttribute('icon', '◆');
  var p = chatDefaultPos();
  w.setAttribute('x', p.x + 'px');
  w.setAttribute('y', p.y + 'px');
  w.setAttribute('width', CHAT_DEF.w);
  w.setAttribute('height', CHAT_DEF.h);
  w.setAttribute('min-width', 320);
  w.setAttribute('min-height', 320);
  w.appendChild(CHAT_HOST);
  // keep the launcher's active state honest when the window is closed or
  // minimized from its own titlebar rather than the launcher
  w.addEventListener('fw-close', function () { chatWin = null; CHAT_TOGGLE.classList.remove('active'); });
  w.addEventListener('fw-minimize', function (e) { if (e.detail && e.detail.minimized) CHAT_TOGGLE.classList.remove('active'); });
  w.addEventListener('fw-focus', function () { CHAT_TOGGLE.classList.add('active'); });
  return w;
}
function loadScript(src) {
  return new Promise(function (res, rej) {
    var s = document.createElement('script'); s.src = src; s.onload = res; s.onerror = function () { rej(new Error('failed to load ' + src)); };
    document.head.appendChild(s);
  });
}
function chatProbe() {
  return fetch(BASE + '/chat', { cache: 'no-store' })
    .then(function (r) { return r.ok ? r.json() : null; })
    .then(function (info) { chatInfo = info && info.url ? info : null; CHAT_TOGGLE.hidden = !chatInfo; })
    .catch(function () { chatInfo = null; CHAT_TOGGLE.hidden = true; });
}
// resolves once the pane is mounted (at once when it already is)
function mountChat() {
  if (chatHandle || !chatInfo) return Promise.resolve();
  var info = chatInfo;
  var ready = (window.Viewers && window.Viewers.chat) ? Promise.resolve() : loadScript(info.viewer);
  return ready.then(function () {
    var v = window.Viewers && window.Viewers.chat;
    if (!v) throw new Error('no chat pane');
    chatHandle = v.mount(CHAT_HOST, { url: info.url, args: { proj: info.proj, chat: info.chat } }) || { destroy: function () {} };
  }).catch(function (e) {
    CHAT_HOST.innerHTML = '';
    var d = document.createElement('div'); d.className = 'chat-none'; d.textContent = 'The chat pane could not load: ' + e.message;
    CHAT_HOST.appendChild(d);
  });
}
// the cursor in the input, the transcript at its end. Moving the host into
// a fresh window resets its scroll, so a reopen has to scroll it back down.
function focusChat() {
  var log = CHAT_HOST.querySelector('.log');
  if (log) log.scrollTop = log.scrollHeight;
  var ta = CHAT_HOST.querySelector('textarea');
  if (ta) ta.focus();
}
function chatIsOpen() {
  return !!(chatWin && chatWin.isConnected && !chatWin.hasAttribute('minimized'));
}
function openChat() {
  if (!customElements.get('float-window')) {
    alertNoWindow();
    return;
  }
  if (chatWin) chatWin.remove();
  chatWin = makeChatWindow();
  document.body.appendChild(chatWin);
  if (chatWin.raise) chatWin.raise();
  CHAT_TOGGLE.classList.add('active');
  mountChat().then(function () { setTimeout(focusChat, 60); });
}
function closeChat() {
  if (chatWin) { chatWin.remove(); chatWin = null; }
  CHAT_TOGGLE.classList.remove('active');
}
function toggleChat(force) {
  var open = typeof force === 'boolean' ? force : !chatIsOpen();
  if (open) openChat(); else closeChat();
}
// components.js failed to define the window: say so instead of nothing
function alertNoWindow() {
  var d = document.createElement('div');
  d.className = 'chat-none';
  d.textContent = 'The chat window component did not load (components.js).';
  d.style.cssText = 'position:fixed;right:22px;bottom:22px;background:#fff;border:1px solid var(--line);border-radius:10px;z-index:30';
  document.body.appendChild(d);
  setTimeout(function () { d.remove(); }, 4000);
}
CHAT_TOGGLE.addEventListener('click', function () { toggleChat(); });
document.addEventListener('keydown', function (e) {
  if ((e.metaKey || e.ctrlKey) && (e.key === 'j' || e.key === 'J') && !CHAT_TOGGLE.hidden) { e.preventDefault(); toggleChat(); }
});

function start() {
  wireSidebarCollapse();
  CUR = REPO;
  document.title = REPO ? REPO + ' docs' : 'Docs';
  chatProbe();
  var hl = document.getElementById('home-link');
  if (hl) hl.href = '/grubbery/forge/repo/' + REPO;
  loadNav().then(routeTail);
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
window.addEventListener('hashchange', routeTail);

start();
