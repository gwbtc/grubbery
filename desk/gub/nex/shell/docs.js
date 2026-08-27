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

// ---- helpers ----

function escHtml(s) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
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

function upgradeLiveBlocks() {
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
      var head = document.createElement('div');
      head.className = 'live-head';
      head.textContent = path + (parts[1] ? '  ' + parts[1] : '');
      var body = document.createElement('div');
      body.className = 'live-body';
      body.textContent = 'loading…';
      host.appendChild(head);
      host.appendChild(body);
      pre.replaceWith(host);
      // read via the kernel's own runtime API (/grubbery/api/file), not the
      // explorer app — no userspace dependency. Source lives under /code.
      var apiPath = path.indexOf('/code/') === 0 ? path : ('/code' + path);
      fetch('/grubbery/api/file' + apiPath)
        .then(function (r) { return r.ok ? r.text() : Promise.reject(r.status); })
        .then(function (text) { highlightInto(body, path, sliceLines(text, range)); })
        .catch(function () { body.textContent = 'could not load ' + path; });
    })(blocks[i]);
  }
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

function openDoc(path) {
  if (!path) return;
  if (location.hash.slice(1) !== path) location.hash = path;
  markActive(path);
  if (textCache[path] != null) { render(textCache[path]); return; }
  fetch(BASE + '/page?path=' + encodeURIComponent(path))
    .then(function (r) { return r.ok ? r.text() : Promise.reject(r.status); })
    .then(function (md) { textCache[path] = md; render(md); })
    .catch(function () { DOC.innerHTML = '<p id="empty">Could not load this doc.</p>'; });
}

// ---- sidebar (recursive tree) ----

function docLink(it) {
  var a = document.createElement('a');
  a.textContent = it.title;
  a.href = '#' + it.path;
  a.dataset.path = it.path;
  a.onclick = function (e) { e.preventDefault(); openDoc(it.path); };
  return a;
}

function renderTree(items, container) {
  items.forEach(function (it) {
    if (it.path) {
      var li = document.createElement('li');
      li.appendChild(docLink(it));
      container.appendChild(li);
    } else {
      var sec = document.createElement('li');
      sec.className = 'sec';
      var head = document.createElement('div');
      head.className = 'sec-head';
      head.textContent = it.title;
      head.onclick = function () { sec.classList.toggle('collapsed'); };
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
  renderTree(tree, NAV);
  var want = decodeURIComponent(location.hash.slice(1));
  if (want) markActive(want);
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
  fetch(BASE + '/search?q=' + encodeURIComponent(q))
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

// ---- boot ----

function start() {
  fetch(BASE + '/nav.json')
    .then(function (r) { return r.json(); })
    .then(function (list) {
      tree = Array.isArray(list) ? list : [];
      leaves = collectLeaves(tree, []);
      showNav();
      var want = decodeURIComponent(location.hash.slice(1));
      openDoc(want || (leaves[0] && leaves[0].path));
    })
    .catch(function () { DOC.innerHTML = '<p id="empty">Could not load the docs index.</p>'; });
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
window.addEventListener('hashchange', function () {
  var p = decodeURIComponent(location.hash.slice(1));
  if (p) openDoc(p);
});

start();
