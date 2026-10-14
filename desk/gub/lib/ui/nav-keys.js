// nav-keys: one keyboard vocabulary for every list of things you can open
// (a navigator): the clanker collection and chats, the forge repo list, the
// docs nav, a search dropdown. A navigator attaches it to its list and says
// what its rows are and what opening one means; the keys are then the same
// everywhere, and the cursor is real ARIA state (listbox / option,
// aria-selected), not a class the app invents.
//
//   ↓ ↑  j k      move the cursor
//   Enter          open the row (where this pane's links go)
//   ⇧Enter         open beside (the keyboard's ⌘-click)
//   → ←  l h       unfold / fold a row with children; ← on a leaf → its parent
//   Home End       first / last row
//   a letter       type-ahead: the next row whose text starts with it
//   Esc            clear the cursor and the type-ahead
//
// navKeys(list, {
//   rows:   () => Element[]        the rows, top to bottom, as shown now
//   open:   (row, {beside}) => void
//   fold:   (row, open) => void    optional: unfold (true) / fold (false)
//   folded: (row) => bool|null     optional: null = not foldable
//   parent: (row) => Element|null  optional: ← on a leaf
//   text:   (row) => string        optional: for type-ahead (default: textContent)
// }) -> { focus(), cursor(), setCursor(row), destroy() }
//
// The list becomes focusable (tabindex) and gets the keys; nothing else on
// the page changes. The pane host moves focus to the active pane's content
// when the keyboard chose the pane, so prefix-arrows then ↓ ↓ Enter opens
// the second row without a mouse. Keys inside an input never reach here.
(function () {
  'use strict';
  var CSS_ID = 'nav-keys-css';
  function css() {
    if (document.getElementById(CSS_ID)) return;
    var s = document.createElement('style'); s.id = CSS_ID;
    s.textContent =
      '[data-nk]{outline:none}' +
      '[data-nk] [role=option][aria-selected=true]{box-shadow:inset 3px 0 0 var(--ps-accent,#0969da);background:#f6f8fa}' +
      '[data-nk]:focus [role=option][aria-selected=true]{background:#eef3fb}';
    document.head.appendChild(s);
  }
  function isEditable(el) { if (!el) return false; var t = el.tagName; return t === 'INPUT' || t === 'TEXTAREA' || t === 'SELECT' || !!el.isContentEditable; }

  function navKeys(list, opts) {
    css();
    opts = opts || {};
    var rows = opts.rows || function () { return Array.prototype.slice.call(list.querySelectorAll('[role=option]')); };
    var text = opts.text || function (r) { return (r.textContent || '').trim(); };
    var cur = null, ahead = '', aheadAt = 0, dead = false;
    list.setAttribute('data-nk', '');
    list.setAttribute('role', 'listbox');
    if (!list.hasAttribute('tabindex')) list.tabIndex = 0;

    function mark() {
      var rs = rows();
      for (var i = 0; i < rs.length; i++) {
        var r = rs[i];
        if (r.getAttribute('role') !== 'option') r.setAttribute('role', 'option');
        var on = r === cur;
        if (on) { r.setAttribute('aria-selected', 'true'); list.setAttribute('aria-activedescendant', r.id || ''); }
        else if (r.hasAttribute('aria-selected')) r.removeAttribute('aria-selected');
      }
      if (cur && !cur.isConnected) cur = null;
    }
    function setCursor(r) { cur = r || null; mark(); if (cur && cur.scrollIntoView) cur.scrollIntoView({ block: 'nearest' }); }
    function index() { var rs = rows(); return { rs: rs, i: rs.indexOf(cur) }; }
    function move(d) {
      var x = index(); if (!x.rs.length) return;
      var i = x.i < 0 ? (d > 0 ? 0 : x.rs.length - 1) : Math.max(0, Math.min(x.rs.length - 1, x.i + d));
      setCursor(x.rs[i]);
    }
    function edge(end) { var rs = rows(); if (rs.length) setCursor(rs[end ? rs.length - 1 : 0]); }
    function ensure() { if (!cur || !cur.isConnected) { var rs = rows(); if (rs.length) setCursor(rs[0]); } return !!cur; }
    function foldable(r) { return opts.folded ? opts.folded(r) : null; }
    function typeAhead(ch) {
      var now = Date.now();
      ahead = (now - aheadAt < 700 ? ahead : '') + ch.toLowerCase(); aheadAt = now;
      var x = index(); var rs = x.rs; if (!rs.length) return;
      // from the row after the cursor, wrapping; a repeated single letter cycles
      var start = x.i < 0 ? 0 : (ahead.length === 1 ? x.i + 1 : x.i);
      for (var k = 0; k < rs.length; k++) {
        var r = rs[(start + k) % rs.length];
        if (text(r).toLowerCase().indexOf(ahead) === 0) { setCursor(r); return; }
      }
    }
    function onKey(e) {
      if (dead) return;
      if (isEditable(e.target)) return;                          // typing in a field inside the list
      if (e.metaKey || e.ctrlKey || e.altKey) return;            // chords belong to someone else (the pane prefix, ⌘K)
      var k = e.key, used = true;
      if (k === 'ArrowDown' || k === 'j') move(1);
      else if (k === 'ArrowUp' || k === 'k') move(-1);
      else if (k === 'Home') edge(false);
      else if (k === 'End') edge(true);
      else if (k === 'Enter') { if (ensure()) opts.open(cur, { beside: e.shiftKey }); }
      else if (k === 'ArrowRight' || k === 'l') {
        if (ensure()) { var f = foldable(cur); if (f === true && opts.fold) opts.fold(cur, true); else if (f === false) move(1); }
      }
      else if (k === 'ArrowLeft' || k === 'h') {
        if (ensure()) {
          var g = foldable(cur);
          if (g === false && opts.fold) opts.fold(cur, false);
          else if (opts.parent) { var p = opts.parent(cur); if (p) setCursor(p); }
        }
      }
      else if (k === 'Escape') { if (ahead) ahead = ''; else setCursor(null); }
      else if (k.length === 1 && /\S/.test(k)) typeAhead(k);
      else used = false;
      if (used) { e.preventDefault(); e.stopPropagation(); }
    }
    function onFocus() { ensure(); }
    list.addEventListener('keydown', onKey);
    list.addEventListener('focus', onFocus);
    // a click on a row puts the cursor there (the app's own click handler opens it)
    function onClick(e) { var rs = rows(); for (var i = 0; i < rs.length; i++) if (rs[i].contains(e.target)) { setCursor(rs[i]); return; } }
    list.addEventListener('click', onClick);
    mark();
    return {
      focus: function () { list.focus({ preventScroll: true }); },
      cursor: function () { return cur; },
      setCursor: setCursor,
      mark: mark,
      destroy: function () { dead = true; list.removeEventListener('keydown', onKey); list.removeEventListener('focus', onFocus); list.removeEventListener('click', onClick); }
    };
  }
  window.navKeys = navKeys;
})();
