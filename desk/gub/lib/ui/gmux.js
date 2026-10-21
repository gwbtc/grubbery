// gmux — the tiling window manager (<gmux-host>). THE ONLY NOUN IS A PANE.
//
// THE MODEL (pure, serializable data — panes all the way down):
//   pane  = { tabs:[tab], activeTab }        a rectangle; owns its tabs + bar
//   tab   = { entries:[entry], cursor }       one browser history-line
//   entry = { path } | { div }                what the current cursor renders as
//   div   = { dir, ratio, fold, src, a, b }   a division: two child PANES
//
// A pane has TABS; a tab is a history (a list of entries + a cursor into it).
// The entry at the cursor renders as EITHER a leaf (a path, via renderPath) OR
// a division of two child panes. Every pane is identical → ONE uniform bar
// everywhere (tabs · back/fwd · navbar · split · close). No group/leaf split.
//
// History is a tab's entry-list; it lives wherever its content lives:
//   · navigate(id,path) / openLayout(id,spec)  push an entry → history STAYS on
//     this tab; back/forward step in and out of it (a layout you can back out of).
//   · splitRight/Down(id)  is STRUCTURAL: the active tab's history MIGRATES down
//     to the child that keeps the original content; the parent tab becomes the
//     division. close(pane) is the inverse — the surviving sibling's history
//     comes back UP to the parent. So the same picture (a division on screen) can
//     have its history at the parent (navigated) or in a child (split).
//
// Four cursors read this one structure: selection (which pane), zoom (which
// viewport), tab (which history-line), history (which entry in time).
//
// ZOOM IS RELATIVE. A zoom is a pane shown alone inside a FRAME. The frame
// is the nearest CONTEXT above the pane, else the window. z on the cursor:
// it fills its frame (the rest of the frame folds into a wall; the rest of
// the window stays). Contexts are standing: C toggles any pane as one (a
// wall marks it); any number may be set; the root always is one (there is
// no window zoom, only the outermost pane as frame). z on a context itself fills the
// next context above it. Contexts and zooms persist with the structure. Zooms stack,
// inner inside outer; Z pops one. A zoomed frame shows a thicker, darker
// wall around its body on every side, each saying zoomed.
//
// CONTRACT (host sets in JS):
//   renderPath (path, paneId) => HTMLElement   content for a leaf path
//   leafFactory (paneId) => HTMLElement        optional: empty-pane placeholder
//   onDestroy (paneId, bodyEl) => void         optional: teardown before re-render
//   onNavigate (paneId, path) => void          optional: the navbar committed a path
//   attributes: prefix ("ctrl+b") · persist (localStorage key)
//   content: open(path,'here'|'beside') · navigate(id,path) · openLayout(id,spec)
//     back/forward(id) · newTab(id,path) · selectTab(id,i) · closeTab(id,i)
//   structure: splitRight/splitDown · close · closeLeaf · swap · collapse · nudge
//     zoomToggle/zoomReset · focusPane · climb/descend/sibling · setBar · toggleBars
//   data: serialize() · restore(spec) · instantiate(spec)
//
//   KEYS (after prefix): % / | split right · " / - split down · c collapse · e expand · f flip · r rotate ·
//     z zoom toggle · C set/clear zoom context · x close · b lock bars · o cycle · m mark · ␣ swap ·
//     [ ] climb/descend · Tab sibling · Esc reset · h highlight · 1-9 jump ·
//     t new tab · w close tab · T toggle bar · : focus navbar · < > prev/next tab · , . back/forward ·
//     arrows move · shift+arrows resize (sticky).
//
// Light DOM; the JS tree is the source of truth and the DOM mirrors it. A
// division nests via a <split-view> living in the owner pane's body; each child
// pane renders its own bar + body, so bars appear at every level.

const STYLE_ID = 'gmux-style';
const CSS = `
  gmux-host { display:block; width:100%; height:100%; min-width:0; min-height:0; position:relative; }
  gmux-host split-view { width:100%; height:100%; }
  .ps-pane {
    position:relative; width:100%; height:100%; min-width:0; min-height:0;
    box-sizing:border-box; overflow:hidden; display:flex; flex-direction:column;
  }
  .ps-pane-body { flex:1 1 auto; min-height:0; overflow:auto; position:relative; isolation:isolate; }
  .ps-pane-body > split-view { position:absolute; inset:0; }
  .ps-empty { height:100%; display:flex; align-items:center; justify-content:center; color:#8b949e; font:16px -apple-system,sans-serif; }
  .ps-pane::after {
    content:""; position:absolute; inset:0; pointer-events:none; z-index:4;
    outline:1px solid transparent; outline-offset:-1px; transition:outline-color .1s;
  }
  /* a zoomed frame: a pane whose body shows one descendant alone. Its wall is the
     ordinary pane border, thicker and a shade darker: structure, not selection.
     The folded siblings are that wall with their names set into it, on the side
     they lived; a click on it zooms back out. The border has to live on the
     ::after overlay, same as the active-selection outline just below it — a
     box-shadow on .ps-pane-body gets painted UNDER a division's absolutely
     positioned split-view (line above) and simply never shows for any zoomed
     pane that itself holds a split, only for bare leaves.
  */
  .ps-pane.ps-zoom-frame > .ps-pane-body, .ps-pane.ps-zoom-ctx > .ps-pane-body { padding:3px; }
  .ps-pane.ps-zoom-frame::after, .ps-pane.ps-zoom-ctx::after { outline:6px solid #8b949e; outline-offset:-6px; }
  .ps-pane.ps-active::after { outline:2px solid var(--ps-accent,#0969da); outline-offset:-2px; }
  .ps-zoom-wall { position:absolute; z-index:3; background:#cfd5db; color:#57606a; font:600 11px ui-monospace,Menlo,monospace; cursor:pointer; display:flex; gap:12px; align-items:center; overflow:hidden; white-space:nowrap; user-select:none; box-sizing:border-box; }
  .ps-zoom-wall:hover { background:#c2c9d0; color:#24292f; }
  .ps-zoom-wall.left { left:0; top:0; bottom:0; width:16px; padding:8px 0; writing-mode:vertical-rl; }
  .ps-zoom-wall.right { right:0; top:0; bottom:0; width:16px; padding:8px 0; writing-mode:vertical-rl; }
  .ps-zoom-wall.top { left:0; right:0; top:0; height:16px; padding:0 8px; }
  .ps-zoom-wall.bottom { left:0; right:0; bottom:0; height:16px; padding:0 8px; }
  .ps-zoom-wall .ps-zw-n { opacity:.7; font-weight:400; }
  .ps-sel-box { position:absolute; pointer-events:none; z-index:20; display:none; border:3px solid var(--ps-sel,#8250df); box-sizing:border-box; border-radius:3px; }
  .ps-sel-box.on { display:block; }
  .ps-mark-box { position:absolute; pointer-events:none; z-index:19; display:none; border:3px dashed var(--ps-mark,#bf8700); box-sizing:border-box; border-radius:3px; }
  .ps-mark-box.on { display:block; }
  /* picking a target: the pane's CURRENT target wears a dashed blue box, the pane
     under the mouse a solid one; the pick flashes the chosen pane */
  .ps-pane.ps-dim { opacity:.4; transition:opacity .1s; }
  /* uniform per-pane topbar: committed on/off; the hover toggle (bar ▾) flips it;
     a global switch (ps-no-hovertoggle) hides every toggle so bars are locked. */
  .ps-bar { flex:0 0 auto; display:none; flex-direction:column; align-items:stretch; gap:3px; padding:3px 4px; box-sizing:border-box; background:#f6f8fa; border-bottom:1px solid #e2e7ee; font:14px -apple-system,BlinkMacSystemFont,sans-serif; color:#57606a; }
  .ps-pane.ps-bar-on > .ps-bar { display:flex; }
  /* ≡ toggles the bar between full (tabs, icons, navbar) and tabs only (≡ and the
     tab chips, nothing else); the quickbar still brings the structure icons on hover */
  .ps-pane.ps-nav-off > .ps-bar > .ps-bar-row:nth-child(2) { display:none; }
  .ps-pane.ps-nav-off > .ps-bar > .ps-bar-row:first-child > .ps-bar-btn:not(.ps-bar-menu) { display:none; }
  .ps-pane.ps-nav-off > .ps-bar .ps-tab-x { display:none; }   /* tabs only: no close glyph to hit by accident */
  .ps-bar-row { display:flex; align-items:center; gap:2px; min-width:0; }
  /* one fixed height for every bar control (buttons, tab chips, the quickbar's) so the bar's
     first row and the quickbar come out the same height by construction, not by font math */
  .ps-bar-btn { all:unset; cursor:pointer; padding:0 6px; height:22px; box-sizing:border-box; display:inline-flex; align-items:center; border-radius:4px; color:#57606a; font-size:14px; line-height:1; }
  .ps-bar-btn:hover { background:#eaeef2; color:#24292f; }
  .ps-bar-btn[disabled] { opacity:.3; cursor:default; }
  .ps-bar-tabs { display:flex; align-items:center; gap:2px; flex:0 1 auto; min-width:0; overflow-x:auto; scrollbar-width:none; }
  .ps-bar-tabs::-webkit-scrollbar { display:none; }
  /* the gap between "+" and the structural buttons (split, zoom, close…) —
     tabs stay fit-content so + sits right after the last one, Chrome-style,
     and this spacer absorbs the rest of the row's width instead */
  .ps-bar-spacer { flex:1 1 auto; min-width:4px; }
  .ps-tab { all:unset; cursor:pointer; display:inline-flex; align-items:center; gap:4px; padding:0 8px; height:22px; box-sizing:border-box; border-radius:6px 6px 0 0; font:600 13px ui-monospace,Menlo,monospace; color:#57606a; white-space:nowrap; border:1px solid transparent; }
  .ps-tab:hover { background:#eaeef2; }
  .ps-tab.on { background:#fff; color:#1f2328; border-color:#e2e7ee; }
  .ps-tab.named { font:600 13px -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif; }
  .ps-tab.dead .ps-tab-t { text-decoration:line-through; color:#cf222e; opacity:.75; }
  .ps-tab.dead .ps-tab-ic { color:#cf222e; }
  .ps-tab-t { overflow:hidden; text-overflow:ellipsis; max-width:220px; }
  .ps-tab-edit { all:unset; box-sizing:border-box; height:18px; padding:0 4px; border:1px solid #0969da; border-radius:4px; background:#fff; color:#1f2328; font:600 13px -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif; box-shadow:0 0 0 2px rgba(9,105,218,.15); }
  .ps-tab-edit::placeholder { color:#8b949e; font-weight:400; }
  .ps-tab.editing { cursor:text; }
  .ps-tab-ic { font-weight:400; opacity:.85; }
  .ps-tab-x { opacity:.5; padding:0 2px; border-radius:3px; font-weight:400; }
  .ps-tab-x:hover { opacity:1; background:#d7dde3; }
  .ps-nav { flex:1 1 auto; min-width:40px; display:flex; align-items:center; }
  .ps-nav input { width:100%; box-sizing:border-box; border:1px solid #e2e7ee; background:#fff; border-radius:6px; padding:3px 8px; font:13px ui-monospace,Menlo,monospace; color:#1f2328; outline:none; }
  .ps-nav input:focus { border-color:var(--ps-accent,#0969da); box-shadow:0 0 0 2px rgba(9,105,218,.15); }
  .ps-nav input::placeholder { color:#8b949e; }
  /* an @name prefix shown as a chip: the field's border moves to the wrapper so
     the chip and the rest of the path read as one box */
  .ps-chip { display:none; flex:0 0 auto; white-space:nowrap; font:12px ui-monospace,Menlo,monospace; line-height:1; padding:4px 6px; margin:0; border:0; border-radius:4px; background:#dde7f5; color:#0a4ea8; cursor:pointer; }
  .ps-chip:hover { background:#cfdef3; }
  .ps-chip.ps-chip-abs { background:#e9edf1; color:#50575e; }
  .ps-nav.ps-chipped { gap:4px; padding-left:4px; border:1px solid #e2e7ee; background:#fff; border-radius:6px; overflow-x:auto; scrollbar-width:none; }
  .ps-nav.ps-chipped::-webkit-scrollbar { display:none; }
  .ps-nav.ps-chipped:focus-within { border-color:var(--ps-accent,#0969da); box-shadow:0 0 0 2px rgba(9,105,218,.15); }
  .ps-chipped > .ps-chip { display:block; }
  .ps-nav.ps-chipped input { border:0; border-radius:0; box-shadow:none; padding-left:2px; }
  .ps-nav.ps-chipped input:focus { border:0; box-shadow:none; }
  .ps-histmenu { position:absolute; z-index:30; display:none; flex-direction:column; min-width:160px; max-width:320px; max-height:50%; overflow-y:auto; background:#fff; border:1px solid #d0d7de; border-radius:8px; box-shadow:0 6px 20px rgba(0,0,0,.14); padding:4px; }
  .ps-histmenu.on { display:flex; }
  .ps-hm-row { all:unset; cursor:pointer; display:flex; align-items:center; gap:6px; padding:5px 9px; border-radius:6px; font:13px -apple-system,BlinkMacSystemFont,sans-serif; color:#24292f; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
  /* forget-this-step: present but quiet, so a history row still reads as one
     thing to click; it only asserts itself under the cursor */
  .ps-hm-x { margin-left:auto; padding:0 3px; border-radius:4px; color:#8b949e; opacity:0; }
  .ps-hm-row:hover .ps-hm-x { opacity:1; }
  .ps-hm-x:hover { background:#d7dde3; color:#cf222e; }
  .ps-hm-row:hover { background:#eaeef2; }
  .ps-hm-row.on { background:#ddf4ff; color:#0969da; font-weight:600; }
  .ps-hm-ic { opacity:.85; }
  /* one pill, anchored top-left of the SELECTED pane; materializes ITS bar */
  /* thin quick-action dropdown: ONE host-level element (like the old pill, so it
     is never clipped by a pane's overflow nor stacked under an ancestor's bar),
     anchored over the SELECTED pane's top edge and sized to its width. Drops in
     on top-edge hover; a grace timer keeps it a few seconds. Not persisted. */
  /* sized to the pane it drops over; what does not fit is clipped at its right edge, never spilled */
  /* the same metrics and look as the bar's first row (.ps-bar / .ps-bar-btn), so the drop reads as the bar without its navbar */
  .ps-quickbar { position:absolute; z-index:27; display:none; align-items:center; gap:2px; box-sizing:border-box; padding:3px 4px; background:#f6f8fa; border-bottom:1px solid #e2e7ee; font:14px -apple-system,BlinkMacSystemFont,sans-serif; color:#57606a; user-select:none; white-space:nowrap; overflow:hidden; min-width:0; }
  .ps-quickbar > * { flex:none; }
  .ps-quickbar.on { display:flex; animation:ps-qb-drop .13s ease-out; }
  @keyframes ps-qb-drop { from { opacity:0; transform:translateY(-6px); } to { opacity:1; transform:none; } }
  .ps-qb-btn { all:unset; cursor:pointer; padding:0 6px; height:22px; box-sizing:border-box; display:inline-flex; align-items:center; border-radius:4px; color:#57606a; font-size:14px; line-height:1; }
  .ps-qb-btn:hover { background:#eaeef2; color:#24292f; }
  .ps-qb-count { margin-left:auto; padding:0 4px 0 8px; height:22px; box-sizing:border-box; display:inline-flex; align-items:center; justify-content:flex-end; color:#8b949e; font:600 12px ui-monospace,SFMono-Regular,Menlo,monospace; min-width:20px; }
  gmux-host.ps-no-hovertoggle .ps-quickbar { display:none !important; }
  .ps-hint { position:absolute; left:8px; bottom:8px; z-index:10; background:#1f2328; color:#fff; font:12px ui-monospace,Menlo,monospace; padding:4px 9px; border-radius:6px; opacity:0; transition:opacity .1s; pointer-events:none; }
  .ps-hint.on { opacity:.92; }
`;

function ensureStyle() {
  if (document.getElementById(STYLE_ID)) return;
  const s = document.createElement('style');
  s.id = STYLE_ID; s.textContent = CSS;
  document.head.appendChild(s);
}

let SEQ = 0;
const DIR = { ArrowLeft: 'left', ArrowRight: 'right', ArrowUp: 'up', ArrowDown: 'down' };
const MODS = { Shift: 1, Control: 1, Alt: 1, Meta: 1 };
const base = (p) => (p || '').split('/').filter(Boolean).pop() || p || '';

class Gmux extends HTMLElement {
  renderPath = null;
  leafFactory = null;
  onDestroy = null;
  onNavigate = null;
  tabInfo = null;      // optional (path) => { icon?:string, label?:string } for the tab chip
  pathHint = null;     // optional (path) => string: the navbar's tooltip for a moment (what a symbolic path resolved to)
  pathChip = null;     // optional (path) => {head,rest}|null: split a leading @name off so the navbar shows it as a chip
  pathChipAlt = null;  // optional (head) => string|Promise<string>: the place that @name resolves to, for the chip's other face
  updateContent = null; // optional (el, path, paneId) => bool: update the shown content to a new moment in place; false → rebuild
  reloadLayout = null;  // optional (paneId, src) => void: re-read a layout's source and reapplyLayout (a refresh on a layout pane)
  seat = null;                  // the phone client's SEAT: where it sits in the tree.
                                // Carried in the workspace and never read here — desktop
                                // has a cursor and nested zooms instead, and does not sit.
  viewModes = null;    // optional [{id, glyph, title}] → a per-pane render-mode toggle on the bar; host's renderPath reads viewOf(id)

  #root = null;                 // the root PANE
  #panes = new Map();           // id -> pane
  #activeId = null;             // the selected/active pane id
  #selLevel = 2;
  // zoom lives on the TAB, not a global stack: pane.tabs[i].zoom is an address
  // string (within that pane) naming the descendant this tab shows zoomed —
  // a tab fully owns its own zoom, so switching away and back just works,
  // and nothing anywhere needs reconciling against a list.
  #mark = null;                 // a marked pane (for swap)
  #contexts = new Set();        // standing zoom frames (C toggles a pane); z fills the nearest one above the cursor, else the window
  #pendingClose = null;         // a pane with content whose close awaits Enter
  #closing = false;             // set only while Enter runs the confirmed close
  #hoistInfo = new Map();       // frame pane -> the hoist currently applied to its DOM: { z:{pane,frame}, hid, wall, pad }
  #hoverToggle = true;
  #pillTimer = null;            // interval that counts the quickbar's sticky grace down
  #pillEnd = 0;                 // when the quickbar is due to retract (ms epoch)
  #padBody = null;             // the pane body currently padded down to make room for the quickbar
  #padRestore = null;           // its own paddingTop/split-view top from before — a zoom frame already carries 16px from its wall, which undisplace must give back exactly, not blank to 0
  #pillPane = null;            // the pane the quickbar is showing for: always the selected one
  #repeat = null;
  #awaiting = false;
  #awaitTimer = null;
  #saveTimer = null;
  #hint = null;
  #selBox = null;
  #markBox = null;
  #barToggle = null;            // the one host-level quickbar dropdown element
  #histMenu = null;

  connectedCallback() {
    ensureStyle();
    this.tabIndex = this.tabIndex < 0 ? 0 : this.tabIndex;
    this.#hint = this.#chrome('ps-hint');
    this.#selBox = this.#chrome('ps-sel-box');
    this.#markBox = this.#chrome('ps-mark-box');
    this.#barToggle = this.#chrome('ps-quickbar');
    const act = (t, title, fn) => { const b = document.createElement('button'); b.className = 'ps-qb-btn'; b.textContent = t; b.title = title; b.addEventListener('mousedown', (e) => e.stopPropagation()); b.addEventListener('click', (e) => { e.stopPropagation(); if (this.#activeId) fn(); }); return b; };
    // the quickbar acts on the pane it dropped for: a bar-less container
    // the selection sits in, or the selected pane itself
    const pid = () => (this.#pillPane || this.cursor || {}).id || this.#activeId;
    this.#barToggle.append(
      act('▾', 'materialize the full topbar', () => this.setBar(pid(), true)),
      act('⇄', 'flip the two panes of this division', () => this.flip(pid())),
      act('⟳', 'turn this division a quarter turn clockwise', () => this.rotate(pid())),
      act('⤓', 'collapse pane', () => this.collapse(pid())),
      act('⬉', 'select parent container', () => this.selectParent(pid())),
      act('⛶', 'zoom to this pane', () => this.zoomPane(pid())),
      act('↑', 'zoom to parent', () => this.zoomParent(pid())),
      act('⤢', 'zoom all the way out', () => this.zoomReset()),
      act('×', 'close pane', () => this.closeLeaf(pid())));
    const count = document.createElement('span'); count.className = 'ps-qb-count';   // sticky countdown, right-aligned
    this.#barToggle.append(count); this.#barToggle._count = count;
    this.#barToggle.addEventListener('mouseenter', () => this.#holdPill());         // interacting → keep it open
    this.#barToggle.addEventListener('mouseleave', () => this.#schedulePillHide(5000));
    this.#histMenu = this.#chrome('ps-histmenu');
    // capture: once the prefix is down (or a move/resize repeat is armed) the
    // next key is ours before any content handler (a navigator's list) can
    // take it; at every other time #onKey lets the key pass untouched
    this.addEventListener('keydown', this.#onKey, true);
    window.addEventListener('keydown', this.#onKeyGlobal, true);     // armed-swap: bare Space anywhere
    this.addEventListener('mousedown', (e) => { if (this.#histMenu && this.#histMenu.classList.contains('on') && !this.#histMenu.contains(e.target) && !(e.target.closest && e.target.closest('.ps-histcaret'))) this.#closeHistMenu(); }, true);
    this.addEventListener('sv-resize', this.#onSvResize);
    this.addEventListener('sv-collapse', this.#onSvCollapse);
    window.addEventListener('resize', this.#reposition);
    let restored = false;
    const k = this.#saveKey();
    if (k) {
      try {
        let s = JSON.parse(localStorage.getItem(k) || 'null'), legacy = false;
        if (!s) { s = JSON.parse(localStorage.getItem(this.#legacyKey()) || 'null'); legacy = !!s; }
        if (s) { this.restore(s); restored = true; if (legacy) this.#persist(); }
      } catch (_) {}
    }
    if (!restored && !this.#root) this.seed();
    this.focus({ preventScroll: true });
  }

  disconnectedCallback() {
    this.removeEventListener('keydown', this.#onKey, true);
    window.removeEventListener('keydown', this.#onKeyGlobal, true);
    this.removeEventListener('sv-resize', this.#onSvResize);
    this.removeEventListener('sv-collapse', this.#onSvCollapse);
    window.removeEventListener('resize', this.#reposition);
  }

  #chrome(cls) { const d = document.createElement('div'); d.className = cls; this.appendChild(d); return d; }

  get activeId() { return this.#activeId; }
  get cursor() { return this.#panes.get(this.#activeId) || null; }
  get leafIds() { const out = []; this.#eachVisibleLeaf(this.#root, l => out.push(l.id)); return out; }

  // ---- tree construction ----

  seed() {
    if (this.#root) return this.#activeId;
    const pane = this.#makePane();
    this.#root = pane;
    this.#contexts.add(pane);              // a fresh workspace starts zoomable; C can turn it off like any pane
    this.#placePane(pane, this, null);
    this.focusPane(pane.id);
    return pane.id;
  }

  // a fresh pane owns one empty tab.
  #makePane() {
    const id = 'p' + (++SEQ);
    const dom = document.createElement('div');
    dom.className = 'ps-pane';
    dom.dataset.paneId = id;
    const bar = this.#makeBar(id);
    const body = document.createElement('div');
    body.className = 'ps-pane-body';
    dom.append(bar, body);
    // mouse structural cursor: plain click selects this pane; shift-click climbs.
    // capture, but only the INNERMOST pane under the cursor selects — otherwise
    // every ancestor's handler fires too, thrashing the cursor through parents
    // (which would e.g. hide the quickbar before the click lands on the leaf).
    dom.addEventListener('mousedown', (e) => { if (!e.shiftKey && e.target.closest('.ps-pane') === dom) this.focusPane(id); }, true);
    dom.addEventListener('click', (e) => {
      if (!e.shiftKey) return;
      e.preventDefault(); e.stopPropagation();
      this.#activeId = id; this.climb();
    }, true);
    // sticky quickbar: hovering the selected pane's top edge drops the thin
    // quick-action bar; it lingers (grace timer) and the bar itself holds it
    // open while you interact (wired where the element is built).
    dom.addEventListener('mousemove', (e) => this.#onTopHover(e, id));
    const pane = { kind: 'pane', id, dom, body, bar, tabs: [{ entries: [], cursor: -1, view: null }], activeTab: 0, parent: null, showBar: false, nav: true, open: null, ref: null };
    this.#panes.set(id, pane);
    this.#refIndex = null;                        // membership changed: the id index rebuilds on next lookup
    this.#renderPane(pane);
    return pane;
  }

  // uniform topbar, two rows: (1) tabs · new-tab · split · close pane
  //                           (2) back/fwd · navbar (namespace path, editable)
  #makeBar(id) {
    const bar = document.createElement('div');
    bar.className = 'ps-bar';
    const btn = (t, title, fn) => { const b = document.createElement('button'); b.className = 'ps-bar-btn'; b.textContent = t; b.title = title; b.addEventListener('click', (e) => { e.stopPropagation(); fn(); }); return b; };
    // row 1 — tabs + structure controls
    const row1 = document.createElement('div'); row1.className = 'ps-bar-row';
    const tabs = document.createElement('div'); tabs.className = 'ps-bar-tabs';
    const add = btn('+', 'new tab', () => this.newTab(id, this.#curPath(id)));
    const viewBtn = btn('', 'rendering mode', () => this.#cycleView(id));
    const menu = btn('≡', 'full bar / tabs only', () => this.setNav(id)); menu.classList.add('ps-bar-menu');
    const hide = btn('▴', 'hide bar', () => this.setBar(id, false)); hide.classList.add('ps-bar-menu');   // stays in tabs-only too
    const spacer = document.createElement('div'); spacer.className = 'ps-bar-spacer';
    row1.append(menu, hide, tabs, add, spacer, viewBtn,
      btn('◨', 'split right', () => this.splitRight(id)), btn('⬓', 'split down', () => this.splitDown(id)),
      btn('⇄', 'flip the two panes of this division', () => this.flip(id)),
      btn('⟳', 'turn this division a quarter turn clockwise', () => this.rotate(id)),
      btn('⤓', 'collapse pane', () => this.collapse(id)),
      btn('⬉', 'select parent container', () => this.selectParent(id)),
      btn('C', 'toggle this pane as a zoom context — z on a pane inside it then fills it', () => this.contextToggle(this.#panes.get(id))),
      btn('⛶', 'zoom to this pane', () => this.zoomPane(id)), btn('↑', 'zoom to parent', () => this.zoomParent(id)), btn('⤢', 'zoom all the way out', () => this.zoomReset()),
      btn('×', 'close pane', () => this.closeLeaf(id)));
    // row 2 — history + navbar
    const row2 = document.createElement('div'); row2.className = 'ps-bar-row';
    // refresh: re-render the current moment in place (what it shows is
    // refetched; history, tabs and scroll stay)
    const reload = btn('↻', 'refresh this moment', () => this.refresh(id));
    const back = document.createElement('button'); back.className = 'ps-bar-btn'; back.textContent = '◀'; back.title = 'back (hold for history)';
    const fwd = document.createElement('button'); fwd.className = 'ps-bar-btn'; fwd.textContent = '▶'; fwd.title = 'forward (hold for history)';
    this.#wireHold(back, id, () => this.back(id), 'back');     // click = step, hold = history dropdown
    this.#wireHold(fwd, id, () => this.forward(id), 'forward');
    const nav = document.createElement('div'); nav.className = 'ps-nav';
    const input = document.createElement('input');
    input.type = 'text'; input.spellcheck = false; input.placeholder = 'path…';
    input.addEventListener('mousedown', (e) => e.stopPropagation());
    // the chip reads and writes the field, so the handlers go through it
    // rather than input.value: `get` rejoins the @name with the rest
    let chip = null;
    input.addEventListener('keydown', (e) => {
      e.stopPropagation();
      if (e.key === 'Enter') { const v = (chip ? chip.get() : input.value).trim(); if (v) { this.focusPane(id); this.navigate(id, v); if (this.onNavigate) try { this.onNavigate(id, v); } catch (_) {} } }
      else if (e.key === 'Escape') { const p = this.#curPath(id) || ''; if (chip) chip.set(p); else input.value = p; input.blur(); }
    });
    nav.appendChild(input);
    if (this.pathChip && window.attachPathChip)
      chip = window.attachPathChip(input, { parse: (v) => this.pathChip(v), alt: (h) => this.pathChipAlt && this.pathChipAlt(h) });
    // where links from this pane land is the layout's routing table (its
    // `open` rules), edited in the layout file: nothing on the bar sets it
    row2.append(back, fwd, reload, nav);
    bar.append(row1, row2);
    bar._back = back; bar._fwd = fwd; bar._tabs = tabs; bar._nav = input; bar._view = viewBtn; bar._chip = chip;
    return bar;
  }

  // the tab's name, edited in place: an input where its text was, sized to
  // it. Enter keeps, Escape cancels, leaving the field keeps; an empty name
  // clears the name, so the tab describes its entry again.
  #editTabName(pane, i, b, txt) {
    const tab = pane.tabs[i]; if (!tab) return;
    const input = document.createElement('input');
    const e = tab.entries[tab.cursor];
    input.className = 'ps-tab-edit'; input.value = tab.label || ''; input.placeholder = (e && e.name) || this.#entryMeta(e).label;
    input.style.width = Math.max(60, txt.offsetWidth + 16) + 'px';
    let done = false;
    const finish = (keep) => {
      if (done) return; done = true;
      if (keep) this.setTabLabel(pane.id, i, input.value.trim()); else this.#renderBar(pane);
    };
    input.addEventListener('keydown', (e) => { e.stopPropagation(); if (e.key === 'Enter') { e.preventDefault(); finish(true); } else if (e.key === 'Escape') { e.preventDefault(); finish(false); } });
    input.addEventListener('blur', () => finish(true));
    input.addEventListener('click', (e) => e.stopPropagation());
    input.addEventListener('dblclick', (e) => e.stopPropagation());
    txt.replaceWith(input); b.classList.add('editing');
    input.focus(); input.select();
  }

  #renderBar(pane) {
    const bar = pane.bar;
    bar._tabs.textContent = '';
    pane.tabs.forEach((tab, i) => {
      const b = document.createElement('button');
      // a NAMED tab (the user's word for it, or the name a click/layout gave it)
      // reads as a word: sans, no glyph. An unnamed one describes its current
      // entry: the kind glyph and the path's basename, in mono. Double-click
      // names it; an empty name is no name.
      const m = this.#tabMeta(tab);
      const named = !!tab.label || !!m.offered;
      b.className = 'ps-tab' + (i === pane.activeTab ? ' on' : '') + (named ? ' named' : '') + (m.dead ? ' dead' : '');
      b.title = this.#tabTitle(tab) + (m.dead ? '\n(deleted)' : '') + '\n(double-click to name)';
      if (m.icon && !named) { const ic = document.createElement('span'); ic.className = 'ps-tab-ic'; ic.textContent = m.icon; b.appendChild(ic); }
      const txt = document.createElement('span'); txt.className = 'ps-tab-t'; txt.textContent = m.label; b.appendChild(txt);
      b.addEventListener('click', (e) => { e.stopPropagation(); this.selectTab(pane.id, i); });
      b.addEventListener('dblclick', (e) => { e.stopPropagation(); e.preventDefault(); this.#editTabName(pane, i, b, txt); });
      const x = document.createElement('span'); x.className = 'ps-tab-x'; x.textContent = '×';
      x.addEventListener('click', (e) => { e.stopPropagation(); this.closeTab(pane.id, i); });
      b.appendChild(x);
      bar._tabs.appendChild(b);
    });
    const e = this.#curEntry(pane);
    bar._back.disabled = !this.#canBack(pane);
    bar._fwd.disabled = !this.#canFwd(pane);
    const navVal = e ? ((e.div || e.pane) ? (this.#entrySrc(e) || '') : (e.path != null ? e.path : '')) : '';
    if (bar._nav !== document.activeElement) { if (bar._chip) bar._chip.set(navVal); else bar._nav.value = navVal; }
    const ph = (e && (e.div || e.pane)) ? (this.#entrySrc(e) || 'layout') : 'path…';
    bar._nav.placeholder = (bar._chip && bar._chip.chipped && !bar._nav.value) ? '' : ph;
    let hint = ''; if (this.pathHint && navVal) { try { hint = this.pathHint(navVal) || ''; } catch (_) {} }
    bar._nav.title = hint;
    // per-pane render-mode toggle — an ACTION button, so it shows the mode it
    // will switch TO (not the current one).
    if (this.viewModes && this.viewModes.length) {
      const cur = this.#tabView(pane) || this.viewModes[0].id;
      const i = this.viewModes.findIndex(v => v.id === cur);
      const next = this.viewModes[(i + 1) % this.viewModes.length];
      bar._view.textContent = next.glyph; bar._view.title = 'switch to ' + (next.title || next.id); bar._view.style.display = '';
    } else bar._view.style.display = 'none';
  }
  // {icon,label} for one entry — host's tabInfo(path) wins for leaf entries.
  #entryMeta(e) {
    if (!e) return { icon: '', label: 'empty' };
    // `dead` (from the host's tabInfo): the path this entry shows is gone
    if (e.div || e.pane) {
      const s = this.#entrySrc(e); let dead = false;
      if (s && this.tabInfo) { try { const m = this.tabInfo(s); dead = !!(m && m.dead); } catch (_) {} }
      return { icon: '▣', label: s ? base(s) : 'layout', dead };
    }
    if (this.tabInfo) { try { const m = this.tabInfo(e.path); if (m) return { icon: m.icon || '', label: m.label || base(e.path) || 'empty', dead: !!m.dead }; } catch (_) {} }
    return { icon: '', label: base(e.path) || 'empty' };
  }
  // a tab's chip: the user's name (tab.label) over the moment's offered name
  // (entry.name, given when content opened it) over the derived description
  #tabMeta(tab) {
    const e = tab.entries[tab.cursor], m = this.#entryMeta(e);
    if (tab.label) return { icon: m.icon, label: tab.label, dead: m.dead };
    if (e && e.name) return { icon: '', label: e.name, dead: m.dead, offered: true };
    return m;
  }
  // the tab's entry list (its history) for a back/forward dropdown.
  historyList(id) {
    const p = this.#panes.get(id ?? this.#activeId); if (!p) return [];
    const tab = p.tabs[p.activeTab];
    return tab.entries.map((e, i) => { const m = this.#entryMeta(e); return { i, icon: m.icon, label: m.label, current: i === tab.cursor }; });
  }
  // +dropEntry: remove ONE entry from the active tab's history.
  //
  //   Modelled on closeMoment, which removes the current entry of every tab
  //   showing a path: a structural entry's panes are forgotten rather than
  //   orphaned, a tab left with nothing goes the way closeTab sends it, and
  //   the stash is released only when the entry being removed is the one on
  //   screen. The cursor names a MOMENT, not a slot, so it follows the entry
  //   it was already on rather than staying at its index.
  //
  dropEntry(id, i) {
    const p = this.#panes.get(id ?? this.#activeId); if (!p) return false;
    const t = p.tabs[p.activeTab]; if (!t) return false;
    if (i < 0 || i >= t.entries.length) return false;
    const e = t.entries[i];
    if (e && e.div) { this.#forgetPane(e.div.a); this.#forgetPane(e.div.b); }
    else if (e && e.pane) this.#forgetPane(e.pane);
    t.entries.splice(i, 1);
    if (!t.entries.length) {
      this.#dropStash(p, t);
      const ti = p.tabs.indexOf(t);
      p.tabs.splice(ti, 1);
      if (p.activeTab >= ti && p.activeTab > 0) p.activeTab--;
    } else {
      if (i < t.cursor) t.cursor--;
      else if (i === t.cursor) { t.cursor = Math.max(0, i - 1); if (t.el) this.#dropStash(p, t); }
      if (t.cursor >= t.entries.length) t.cursor = t.entries.length - 1;
    }
    if (!p.tabs.length) p.tabs.push({ entries: [], cursor: -1 });
    if (p.activeTab >= p.tabs.length) p.activeTab = p.tabs.length - 1;
    if (this.#reconsolidate(p)) return true;
    this.#renderPane(p); this.#reconcileCursor(); this.#afterStructure(); this.#persist();
    this.#refocus();
    return true;
  }
  goTo(id, i) {
    const p = this.#panes.get(id ?? this.#activeId); if (!p) return;
    const tab = p.tabs[p.activeTab]; if (i < 0 || i >= tab.entries.length || i === tab.cursor) return;
    tab.cursor = i; this.#renderPane(p); this.#afterStructure(); this.#persist();
  }
  // click = step; press-and-hold = the history dropdown for that direction.
  #wireHold(el, id, step, dir) {
    let timer = null, held = false;
    el.addEventListener('mousedown', () => { held = false; timer = setTimeout(() => { held = true; timer = null; this.#openHistMenu(id, el, dir); }, 350); });
    el.addEventListener('mouseup', () => { if (timer) { clearTimeout(timer); timer = null; } if (!held) step(); });
    el.addEventListener('mouseleave', () => { if (timer) { clearTimeout(timer); timer = null; } });
    el.addEventListener('click', (e) => { e.preventDefault(); });   // handled via mousedown/up
  }
  #closeHistMenu() { if (this.#histMenu) { this.#histMenu.classList.remove('on'); this.#histMenu.__anchor = null; } }
  // browser-style directional dropdown: 'back' = past (nearest first), 'forward'
  // = future (nearest first), 'all' = whole line newest-first.
  #openHistMenu(id, anchor, dir) {
    const menu = this.#histMenu, p = this.#panes.get(id ?? this.#activeId); if (!menu || !p) return;
    const cur = p.tabs[p.activeTab].cursor, full = this.historyList(id);
    const rows = dir === 'back' ? full.filter(e => e.i < cur).reverse()
      : dir === 'forward' ? full.filter(e => e.i > cur)
        : full.slice().reverse();
    if (!rows.length) return;
    menu.textContent = '';
    rows.forEach((e) => {
      const row = document.createElement('button');
      row.className = 'ps-hm-row' + (e.current ? ' on' : '');
      row.title = e.label;
      if (e.icon) { const ic = document.createElement('span'); ic.className = 'ps-hm-ic'; ic.textContent = e.icon; row.appendChild(ic); }
      row.appendChild(document.createTextNode(e.label));
      row.addEventListener('mousedown', (ev) => ev.stopPropagation());
      row.addEventListener('mouseup', (ev) => { ev.stopPropagation(); this.goTo(id, e.i); this.#closeHistMenu(); });
      row.addEventListener('click', (ev) => { ev.stopPropagation(); this.goTo(id, e.i); this.#closeHistMenu(); });
      // forget this step. A span rather than a button because the row IS a
      // button; it swallows all three events the row listens for, or the
      // delete would navigate on its way out.
      const x = document.createElement('span');
      x.className = 'ps-hm-x'; x.textContent = '\u00d7'; x.title = 'forget this step';
      const stop = (ev) => { ev.stopPropagation(); ev.preventDefault(); };
      x.addEventListener('mousedown', stop);
      x.addEventListener('click', stop);
      x.addEventListener('mouseup', (ev) => {
        stop(ev);
        if (!this.dropEntry(id, e.i)) return;
        this.#closeHistMenu();
        this.#openHistMenu(id, anchor, dir);        // same list, one step shorter
      });
      row.appendChild(x);
      menu.appendChild(row);
    });
    const cr = this.getBoundingClientRect(), r = anchor.getBoundingClientRect();
    menu.style.left = Math.max(0, r.left - cr.left) + 'px';
    menu.style.top = (r.bottom - cr.top + 2) + 'px';
    menu.__anchor = anchor; menu.classList.add('on');
  }
  #tabTitle(tab) { const e = tab.entries[tab.cursor]; if (!e) return 'empty tab'; return (e.div || e.pane) ? (this.#entrySrc(e) || 'layout') : (e.path || ''); }

  // re-render every pane's bar (e.g. after the host learns a path's name/icon)
  redrawBars() { for (const p of this.#panes.values()) this.#renderBar(p); }

  #curEntry(pane) { const t = pane.tabs[pane.activeTab]; return t ? t.entries[t.cursor] || null : null; }
  #curPath(id) { const p = this.#panes.get(id); const e = p && this.#curEntry(p); return e && e.path != null ? e.path : null; }
  // the path a pane currently shows (null for a division, a pane moment, or empty)
  pathOf(id) { return this.#curPath(id ?? this.#activeId); }
  #canBack(pane) { const t = pane.tabs[pane.activeTab]; return !!t && t.cursor > 0; }
  #canFwd(pane) { const t = pane.tabs[pane.activeTab]; return !!t && t.cursor >= 0 && t.cursor < t.entries.length - 1; }

  // render a pane's body from its active tab's current entry. A leaf entry is
  // re-instantiated from its path (we keep paths, never live views). A division
  // entry mounts its (persistent) split-view; its children render themselves.
  #renderPane(pane, rebuild = false) {
    // zoom is applied right here, from this pane's own active tab's own
    // data — not a separate pass reconciled against a global list. Whatever
    // the tab wants is what gets shown; nothing else needs to know.
    const tab = pane.tabs[pane.activeTab];
    const want = (tab && tab.zoom) ? this.#descend(pane, tab.zoom) : null;
    const cur = this.#hoistInfo.get(pane);
    if (cur && cur.z.pane !== want) {
      this.#unhoist(cur); this.#hoistInfo.delete(pane); pane.dom.classList.remove('ps-zoom-frame');
    }
    if (want) {
      if (!this.#hoistInfo.has(pane)) {
        this.#hoistInfo.set(pane, this.#hoist({ pane: want, frame: pane }));
        pane.dom.classList.add('ps-zoom-frame');
      }
      this.#renderBar(pane);
      return;
    }
    const prev = pane.body.firstChild;
    const entry = this.#curEntry(pane);
    // a leaf moving to another moment: the host may update the content it
    // already shows instead of rebuilding it (same path, new ?args, a viewer
    // that takes them). The moment is still in history; only the bar redraws.
    // `rebuild` (refresh) skips this: the content itself is what changed.
    if (!rebuild && prev && entry && entry.path != null && !entry.div && !entry.pane && this.updateContent
        && !(prev.tagName === 'SPLIT-VIEW' || prev.classList.contains('ps-pane'))) {
      let kept = false;
      try { kept = !!this.updateContent(prev, entry.path, pane.id); } catch (_) { kept = false; }
      if (kept) { this.#renderBar(pane); return; }
    }
    // detach old body without destroying a division's child panes
    if (prev) {
      // a division's split-view and a pane moment's nested pane are live
      // objects: detach, never destroy
      if (prev.tagName === 'SPLIT-VIEW' || prev.classList.contains('ps-pane')) prev.remove();
      else { try { if (this.onDestroy) this.onDestroy(pane.id, pane.body); } catch (_) {} pane.body.textContent = ''; }
    }
    const src = this.#entrySrc(entry);
    if (entry && (entry.div || entry.pane) && this.#tabView(pane) && src) {
      // a non-default view (e.g. raw) on a layout: show its SOURCE via renderPath,
      // keeping the live structure intact underneath — flip back and it returns.
      const el = this.renderPath ? this.renderPath(src, pane.id) : document.createTextNode(src);
      if (el) pane.body.appendChild(el);
    } else if (entry && entry.div) {
      const div = entry.div;
      this.#placePane(div.a, div.sv, 'start');
      this.#placePane(div.b, div.sv, 'end');
      pane.body.appendChild(div.sv);
      this.#applyDivLayout(div);
    } else if (entry && entry.pane) {
      // a pane moment: the nested pane (tabs of its own) fills the body
      this.#placePane(entry.pane, pane.body, null);
    } else if (entry && entry.path != null) {
      const el = this.renderPath ? this.renderPath(entry.path, pane.id) : document.createTextNode(entry.path);
      if (el) pane.body.appendChild(el);
    } else {
      const el = this.leafFactory ? this.leafFactory(pane.id) : this.#empty();
      if (el) pane.body.appendChild(el);
    }
    this.#renderBar(pane);
  }
  // re-render a pane's current entry in place (the host asks when what the
  // pane shows has moved underneath it); scroll position survives
  refresh(id) {
    const p = this.#panes.get(id ?? this.#activeId); if (!p) return;
    // a pane showing a layout from a file: refresh re-reads the file (the
    // host fetches and re-applies); its live leaves are kept where they match
    const src = this.#entrySrc(this.#curEntry(p));
    if (src && this.reloadLayout && !this.#showsSrc(p)) { try { this.reloadLayout(p.id, src); } catch (_) {} return; }
    const body = p.body.firstChild, top = body ? body.scrollTop : 0;
    this.#renderPane(p, true);                                      // a refresh always rebuilds: the content is what moved
    const nb = p.body.firstChild; if (nb && top) requestAnimationFrame(() => { nb.scrollTop = top; });
  }
  #empty() { const d = document.createElement('div'); d.className = 'ps-empty'; d.textContent = 'empty pane'; return d; }

  #placePane(pane, parentEl, slot) {
    if (slot) pane.dom.setAttribute('slot', slot); else pane.dom.removeAttribute('slot');
    parentEl.appendChild(pane.dom);
  }

  // ---- content: open / navigate / layout / history / tabs ----

  open(path, disposition = 'beside') {
    if (disposition === 'here') { this.navigate(this.#activeId, path); return this.#activeId; }
    const id = this.splitRight();
    if (id) this.navigate(id, path);
    return id;
  }
  // push a leaf entry onto the active tab (drops the forward tail). History stays.
  // `name` is the moment's offered name (content's description of it).
  navigate(id, path, name) { this.#pushEntry(id ?? this.#activeId, name ? { path, name } : { path }); }
  // ---- routing: where a moment from a pane goes ----
  // A view says WHAT (a moment); its context says WHERE. A layout carries one
  // table, `open: {<origin>: {to, mode}}`, at its root (a division or a pane):
  // origin and destination are addresses within that root, exact. The origin
  // pane climbs its holders (itself, its division, that division's owner, …)
  // and the first holder whose table names its address decides; a nested
  // layout is opaque to the ones above (they see the slot it sits in). With
  // no rule anywhere the moment opens in place.
  //
  // Addresses within a holder: at a pane, a segment is a tab index whose
  // CURRENT entry is the next step; at a division entry, 'a' or 'b'; at a
  // pane entry, 'a'. '.' is the holder itself. So '0/a' from a tabbed root
  // is the left side of its first tab.
  // an address only ever records a real DIVISION choice (a/b). Crossing a
  // pane boundary — its own active tab, a nested-pane entry's single slot —
  // isn't a recorded choice at all: it's always whatever that pane's
  // activeTab says RIGHT NOW, never a tab frozen in by index. That's what
  // makes an address keep meaning what it meant even if something upstream
  // switched tabs in between.
  #addrWithin(holder, pane) {
    if (holder === pane) return '.';
    const segs = [];
    let n = pane;
    for (;;) {
      const par = n && n.parent; if (!par) return null;
      let node;
      if (par.div) {
        segs.unshift(par.slot); node = par.div.owner;
        if (par.div === holder) return segs.join('/');
      } else {
        node = par.host;                                // a nested-pane entry — not a real choice, no segment
      }
      if (!node) return null;
      if (node === holder) return segs.join('/');
      n = node;
    }
  }
  #descend(holder, addr) {
    addr = String(addr || '').trim();
    const parts = (addr === '.' || addr === '') ? [] : addr.split('/').filter((s) => s.length && s !== '.');
    let at = holder;                                   // a pane, or a division
    // before a real choice (a/b) can be applied, skip through anything that
    // isn't one: a nested-pane entry (one pane sitting directly inside
    // another, no slot chosen) — repeatedly, since several can stack. A pane
    // whose current entry is a DIVISION is a stopping point, not something to
    // settle through: once all segments are consumed the addressed pane is
    // the exact target, even if it itself divides further — that's a valid
    // whole-subtree target, not something to auto-drill past.
    const settleToDivision = () => {
      while (at && at.kind === 'pane') {
        const t = at.tabs[at.activeTab]; if (!t) return;        // empty/fresh — at itself is the resolved target
        const e = t.entries[t.cursor]; if (!e) return;
        if (e.div) { at = e.div; return; }
        if (e.pane) { at = e.pane; continue; }
        return;
      }
    };
    for (const seg of parts) {
      settleToDivision();
      if (!at || at.kind === 'pane') return null;       // a real choice only ever happens at a division
      if (seg !== 'a' && seg !== 'b') return null;
      at = at[seg]; if (!at) return null;
    }
    return at && at.kind === 'pane' ? at : null;
  }
  // the holders above a pane, nearest first: the pane, its division, the
  // division's owner pane, that pane's host, …
  *#holdersOf(pane) {
    let n = pane;
    while (n) {
      yield n;
      const par = n.parent; if (!par) return;
      if (par.div) { yield par.div; n = par.div.owner; } else n = par.host;
    }
  }
  // ---- ids: an AUTHOR's name for a pane, resolved by widening outward ----
  // Ids are written by hand in a layout ("viewer", "sidebar"); nothing is
  // generated, and most panes have none. They are NOT required to be unique:
  // `#viewer` means "the nearest viewer to me", so a layout opened twice just
  // works, each sidebar finding the viewer in its own copy. Resolution walks
  // out from the asking pane — itself, its division, that division's owner, …
  // — and the first holder that contains a match decides; inside one holder,
  // the shallowest address wins, then 'a' before 'b'. Because a layout
  // instance IS a subtree, widening never reaches a stranger's pane while
  // your own is in reach: scope falls out of ancestry, with nothing declared.
  #refIndex = null;
  #reindexRefs() {
    const m = new Map();
    for (const p of this.#panes.values()) {
      if (!p.ref) continue;
      const l = m.get(p.ref); if (l) l.push(p); else m.set(p.ref, [p]);
    }
    this.#refIndex = m;
  }
  #findRef(from, ref) {
    if (!this.#refIndex) this.#reindexRefs();
    const cands = this.#refIndex.get(ref);
    if (!cands || !cands.length || !from) return null;
    if (from.ref === ref) return from;                     // self first
    for (const h of this.#holdersOf(from)) {
      const inside = [];
      for (const c of cands) { const a = this.#addrWithin(h, c); if (a != null) inside.push([a, c]); }
      if (!inside.length) continue;
      inside.sort((x, y) => (x[0].split('/').length - y[0].split('/').length) || (x[0] < y[0] ? -1 : 1));
      return inside[0][1];
    }
    return null;
  }
  #routeFrom(pane) {
    // SOURCE-declared: the pane asking says where its moments go — from here to
    // there, stated by here. `{to:'#name', mode}`. A holder table (the older
    // form, keyed by the origin's address) still answers below, so existing
    // layouts keep routing while they are converted.
    // A pane may name ITSELF (a content pane whose id it also targets), which
    // is how "open these in tabs of me" is said — so a self-target keeps the
    // declared mode rather than degrading to replace.
    if (pane.open && typeof pane.open.to === 'string') {
      const to = pane.open.to.trim();
      const t = to.startsWith('#') ? this.#findRef(pane, to.slice(1)) : null;
      if (t) return { target: t, mode: pane.open.mode === 'tab' ? 'tab' : 'replace' };
    }
    return { target: pane, mode: 'replace' };
  }
  routeTargetId(id) { const p = this.#panes.get(id ?? this.#activeId); if (!p) return null; const r = this.#routeFrom(p); return r.target !== p ? r.target.id : null; }
  // openFrom(id, path, name): a view in pane `id` wants `path` shown. Routed;
  // tab mode selects a tab already on that exact moment, else makes one that
  // carries `name` as its offered name; replace mode navigates the target.
  openFrom(id, path, name) {
    const p = this.#panes.get(id ?? this.#activeId); if (!p || path == null) return;
    const { target, mode } = this.#routeFrom(p);
    if (mode === 'tab') this.newTab(target.id, path, name); else this.navigate(target.id, path, name);
    // open means VISIBLE: a target in a folded slot (a collapsed sidebar,
    // a folded chat pane) is unfolded, all the way up. Structure only —
    // the zoom is the user's viewport and is left where it is
    this.#unfold(target);
    // an open selects what it opened: the first LEAF under the target (a
    // tab already holding a layout is a container; its chat is inside),
    // and the keyboard goes to that content — now if it is there, else
    // the content root, which hands focus on when the content mounts
    const leaf = firstVisibleLeaf(target, this);
    this.focusPane(leaf.id);
    this.focusContent(leaf.id);
  }
  // closeFrom(id, path): a view in pane `id` says `path` is gone. Routed the
  // same way; every tab in the target CURRENTLY on that exact moment steps
  // off it (to the entry before, else after); a tab left with nothing closes.
  // History elsewhere is untouched.
  closeFrom(id, path) {
    const p = this.#panes.get(id ?? this.#activeId); if (!p || path == null) return;
    const { target } = this.#routeFrom(p);
    this.closeMoment(target.id, path);
  }
  closeMoment(id, path) {
    const p = this.#panes.get(id ?? this.#activeId); if (!p) return;
    const at = (e) => !!e && ((e.div || e.pane) ? this.#entrySrc(e) === path : e.path === path);
    let changed = false;
    for (let i = p.tabs.length - 1; i >= 0; i--) {
      const t = p.tabs[i], e = t.entries[t.cursor];
      if (!at(e)) continue;
      changed = true;
      if (e.div) { this.#forgetPane(e.div.a); this.#forgetPane(e.div.b); } else if (e.pane) this.#forgetPane(e.pane);
      t.entries.splice(t.cursor, 1);
      if (!t.entries.length) {
        this.#dropStash(p, t); p.tabs.splice(i, 1);
        if (p.activeTab >= i && p.activeTab > 0) p.activeTab--;
      } else { t.cursor = Math.max(0, t.cursor - 1); if (t.el) { this.#dropStash(p, t); } }
    }
    if (!changed) return;
    if (!p.tabs.length) p.tabs.push({ entries: [], cursor: -1 });
    if (p.activeTab >= p.tabs.length) p.activeTab = p.tabs.length - 1;
    if (this.#reconsolidate(p)) return;
    this.#renderPane(p); this.#reconcileCursor(); this.#afterStructure(); this.#persist();
    this.#refocus();
  }
  // a pane that has nothing left to show is not a pane: it dissolves, and its
  // sibling takes the space back, exactly as closing it by hand would. Only
  // the root may stand empty — that is the cleared workspace.
  #reconsolidate(pane) {
    if (!pane || !pane.parent) return false;
    if (pane.tabs.some((t) => t.cursor >= 0)) return false;
    this.close(pane, true);
    return true;
  }
  // push a division entry built from a layout spec. History stays — back/forward
  // steps in and out of it. `spec` is a serialized division (see serialize()).
  openLayout(id, spec) {
    const pid = id ?? this.#activeId;
    const entry = this.#buildEntry(spec, this.#panes.get(pid));
    if (entry) this.#pushEntry(pid, entry);
  }
  // REPLACE the active entry with a layout (for navigating TO a .layout path: the
  // entry you landed on BECOMES the layout, so back returns to where you were).
  // A layout's root is a division ({div}) or a pane ({tabs}): the latter
  // becomes a pane moment, tabs inside this tab.
  replaceWithLayout(id, spec, src) {
    const pane = this.#panes.get(id ?? this.#activeId);
    if (!pane) return;
    const entry = this.#buildEntry(spec, pane);
    if (!entry) return;
    if (src) { if (entry.div) entry.div.src = src; else entry.src = src; }
    const tab = pane.tabs[pane.activeTab];
    const was = tab.entries[tab.cursor];
    if (was && was.name) entry.name = was.name;                    // the moment's offered name survives becoming a layout
    if (tab.cursor < 0) { tab.entries = [entry]; tab.cursor = 0; }
    else tab.entries[tab.cursor] = entry;
    this.#renderPane(pane); this.#afterStructure(); this.#persist();
    // the pane that was selected just became a container: the selection
    // follows into its first leaf (a chat's layout → the chat itself), so
    // the keyboard lands on content, not on the structure around it
    if (this.#activeId === pane.id) { const leaf = firstVisibleLeaf(pane, this); if (leaf !== pane) this.cursorTo(leaf); }
  }
  // reapplyLayout(id, spec, src): the pane's current layout, rebuilt from a
  // new spec of the same source (the file changed; a refresh). A reshape,
  // not a flash: a leaf of the new tree whose address and moment match a
  // leaf of the old tree takes the old pane's LIVE content (viewer, follows,
  // scroll) instead of rendering again; everything else is new. The user's
  // ratios and folds are the spec's business now, since the spec is what
  // changed. Falls back to replaceWithLayout when the pane shows no layout.
  reapplyLayout(id, spec, src) {
    const pane = this.#panes.get(id ?? this.#activeId);
    if (!pane) return;
    const was = this.#curEntry(pane);
    const oldHolder = was && was.div ? was.div : (was && was.pane ? was.pane : null);
    if (!oldHolder) { this.replaceWithLayout(id, spec, src); return; }
    const entry = this.#buildEntry(spec, pane);
    if (!entry) return;
    if (src) { if (entry.div) entry.div.src = src; else entry.src = src; }
    if (was.name) entry.name = was.name;
    const newHolder = entry.div ? entry.div : entry.pane;
    // carry live content across by address + moment
    const leaves = (p, fn) => { const e = this.#curEntry(p); if (e && e.div) { leaves(e.div.a, fn); leaves(e.div.b, fn); } else if (e && e.pane) leaves(e.pane, fn); else fn(p); };
    const roots = newHolder.kind === 'pane' ? [newHolder] : [newHolder.a, newHolder.b];
    roots.forEach((r) => leaves(r, (np) => {
      const addr = this.#addrWithin(newHolder, np); if (addr == null) return;
      const op = this.#descend(oldHolder, addr); if (!op || op.kind !== 'pane') return;
      const ne = this.#curEntry(np), oe = this.#curEntry(op);
      if (!ne || !oe || ne.path == null || oe.path == null || ne.path !== oe.path) return;
      const live = op.body.firstChild;
      if (!live || live.tagName === 'SPLIT-VIEW' || live.classList.contains('ps-pane')) return;
      op.body.removeChild(live); np.body.textContent = ''; np.body.appendChild(live); np.cold = false;   // moved (a fresh pane's body holds the empty placeholder; the old pane's destroy finds nothing)
      np.showBar = op.showBar; np.dom.classList.toggle('ps-bar-on', np.showBar);
      const ov = this.#tabView(op); if (ov && np.tabs[np.activeTab]) np.tabs[np.activeTab].view = ov;
      this.#renderBar(np);                                         // a fresh pane's bar was drawn before it had tabs: draw it for real
    }));
    // the old tree goes (a moved leaf is empty by now; its viewer lives on)
    this.#eachEntryPane({ entries: [was], cursor: 0 }, (cp) => this.#forgetPane(cp));
    if (was.div) was.div.sv.__psdiv = null;
    const tab = pane.tabs[pane.activeTab];
    tab.entries[tab.cursor] = entry;
    this.#renderPane(pane); this.#reconcileCursor(); this.#afterStructure(); this.#persist();
    this.#refocus();
  }
  // the source a pane's current moment came from (a layout file), or null
  srcOf(id) { const p = this.#panes.get(id ?? this.#activeId); return p ? this.#entrySrc(this.#curEntry(p)) : null; }
  // every pane whose current moment came from a layout file: [{id, src}].
  // A restored workspace holds the built structure, not the file, so the
  // host re-follows these sources after a restore (the follow is its)
  layoutSources() { const out = []; for (const p of this.#panes.values()) { const src = this.#entrySrc(this.#curEntry(p)); if (src) out.push({ id: p.id, src }); } return out; }
  // a line in the hint strip, from the host
  hint(msg) { this.#flashHint(msg || ''); }
  // a moment from a layout spec: {div} → division, {tabs} → pane moment
  #buildEntry(spec, host) {
    if (!spec) return null;
    if (spec.div) { const div = this.#buildDiv(spec, host); return div ? { div } : null; }
    if (spec.tabs) return { pane: this.#deserPane(spec, { host, slot: 'a' }), src: spec.src || null };
    return null;
  }
  // per-pane render mode (opaque; host's renderPath interprets, e.g. 'raw'). The
  // bar's toggle cycles through `viewModes`; the default mode is stored as null.
  // the render mode belongs to the TAB, not the pane: a pane holds many
  // tabs and each is pointed at its own moment, so switching tabs must
  // bring that tab's mode (and the bar's toggle) with it.
  #tabView(pane) { const t = pane && pane.tabs[pane.activeTab]; return (t && t.view) || null; }
  viewOf(id) { const p = this.#panes.get(id ?? this.#activeId); return this.#tabView(p); }
  setView(id, v) { const p = this.#panes.get(id ?? this.#activeId); if (!p) return; const t = p.tabs[p.activeTab]; if (!t) return; t.view = v || null; this.#renderPane(p); this.#persist(); }
  cycleView(id) { return this.#cycleView(id); }
  #cycleView(id) {
    if (!this.viewModes || !this.viewModes.length) return;
    const p = this.#panes.get(id); if (!p) return;
    const cur = this.#tabView(p) || this.viewModes[0].id;
    const i = this.viewModes.findIndex(v => v.id === cur);
    const next = this.viewModes[(i + 1) % this.viewModes.length].id;
    this.setView(id, next === this.viewModes[0].id ? null : next);
  }
  #pushEntry(id, entry) {
    const pane = this.#panes.get(id);
    if (!pane) return;
    const tab = pane.tabs[pane.activeTab];
    if (tab.cursor < tab.entries.length - 1) tab.entries.splice(tab.cursor + 1);
    tab.entries.push(entry);
    tab.cursor = tab.entries.length - 1;
    this.#renderPane(pane); this.#afterStructure(); this.#persist();
  }
  back(id) { const p = this.#panes.get(id ?? this.#activeId); if (!this.#canBack(p)) return; p.tabs[p.activeTab].cursor--; this.#renderPane(p); this.#afterStructure(); this.#persist(); }
  forward(id) { const p = this.#panes.get(id ?? this.#activeId); if (!this.#canFwd(p)) return; p.tabs[p.activeTab].cursor++; this.#renderPane(p); this.#afterStructure(); this.#persist(); }
  // newTab(id, path, name): `name` is the moment's offered name (content's
  // description, kept on the entry); the tab's own name stays the user's.
  newTab(id, path, name) {
    const p = this.#panes.get(id ?? this.#activeId); if (!p) return;
    // a tab already showing this exact moment (path with its args, as its
    // CURRENT entry; a layout entry by the path that opened it) is selected
    // instead of being made again; the first such tab wins and keeps its name
    if (path != null) {
      const i = p.tabs.findIndex((t) => { const e = t.entries[t.cursor]; return !!e && ((e.div || e.pane) ? this.#entrySrc(e) === path : e.path === path); });
      if (i >= 0) { this.selectTab(p.id, i); this.focusPane(p.id); return; }
    }
    const cur = p.tabs[p.activeTab];
    // a sole empty tab is filled rather than joined by a second
    const entry = name ? { path, name } : { path };
    if (path != null && p.tabs.length === 1 && cur && cur.cursor < 0) { cur.entries = [entry]; cur.cursor = 0; this.#renderPane(p); this.#afterStructure(); this.#persist(); return; }
    const body = p.body.firstChild;
    if (body && body.tagName !== 'SPLIT-VIEW' && !body.classList.contains('ps-pane')) { cur.el = body; body.remove(); }   // the leaving tab keeps its content
    p.tabs.push({ entries: path != null ? [entry] : [], cursor: path != null ? 0 : -1, label: null });
    p.activeTab = p.tabs.length - 1;
    this.#renderPane(p); this.#afterStructure(); this.#persist();
  }
  // switching tabs keeps each tab's rendered content alive: the leaving tab's
  // element is stashed on it (tab.el) and put back when it returns, so a
  // switch is instant and loses nothing. Only navigation (push, back,
  // forward) re-renders. A division tab needs no stash: its split-view is
  // the live object and #renderPane re-places it.
  selectTab(id, i) {
    const p = this.#panes.get(id ?? this.#activeId); if (!p || i < 0 || i >= p.tabs.length) return;
    if (i === p.activeTab) return;
    // a hoisted frame's body holds more than the one stashable element (the
    // hidden original plus the zoomed pane plus maybe a wall), and the tab
    // we're entering may itself want a hoist — either way this has to go
    // through #renderPane, which is the only place that knows how to
    // reconcile a hoist; the stash fast path assumes a single plain node
    const hoisted = this.#hoistInfo.has(p), enteringZoom = !!p.tabs[i].zoom;
    const leaving = p.tabs[p.activeTab];
    if (!hoisted && !enteringZoom) {
      const cur = p.body.firstChild;
      if (cur && cur.tagName !== 'SPLIT-VIEW' && !cur.classList.contains('ps-pane')) { leaving.el = cur; cur.remove(); }
    }
    p.activeTab = i;
    const tab = p.tabs[i];
    if (!hoisted && !enteringZoom && tab.el) { const el = tab.el; tab.el = null; p.body.textContent = ''; p.body.appendChild(el); this.#renderBar(p); }
    else this.#renderPane(p);
    this.#reconcileCursor(); this.#afterStructure(); this.#persist();
  }
  // a stashed tab's content is destroyed the way a rendered one is: the
  // host's onDestroy sees it as a body's child, so viewers and follows end
  #dropStash(pane, tab) {
    if (!tab || !tab.el) return;
    const tmp = document.createElement('div'); tmp.appendChild(tab.el); tab.el = null;
    try { if (this.onDestroy) this.onDestroy(pane.id, tmp); } catch (_) {}
  }
  closeTab(id, i) {
    const p = this.#panes.get(id ?? this.#activeId); if (!p || i < 0 || i >= p.tabs.length) return;
    const [tab] = p.tabs.splice(i, 1);
    this.#dropStash(p, tab);
    this.#eachEntryPane(tab, cp => this.#forgetPane(cp));
    if (!p.tabs.length) p.tabs.push({ entries: [], cursor: -1 });
    if (p.activeTab >= p.tabs.length) p.activeTab = p.tabs.length - 1;
    if (this.#reconsolidate(p)) return;
    this.#renderPane(p); this.#reconcileCursor(); this.#afterStructure(); this.#persist();
    this.#refocus();
  }

  // ---- topbar visibility ----

  setBar(id, on) { const p = this.#panes.get(id); if (!p) return; p.showBar = (on == null) ? !p.showBar : !!on; p.dom.classList.toggle('ps-bar-on', p.showBar); if (p.showBar) this.#hidePill(); this.#positionBarToggle(); this.#persist(); }
  // the bar's second row (back/forward, navbar, target) folds away per pane
  setNav(id, on) { const p = this.#panes.get(id ?? this.#activeId); if (!p) return; p.nav = (on == null) ? !p.nav : !!on; p.dom.classList.toggle('ps-nav-off', !p.nav); this.#persist(); }
  // a tab's chip label: set to override the path's basename, null to clear
  setTabLabel(id, i, label) { const p = this.#panes.get(id ?? this.#activeId); const t = p && p.tabs[i == null ? p.activeTab : i]; if (!t) return; t.label = label || null; this.#renderBar(p); this.#persist(); }
  // focus the pane's navbar (materializing its bar if hidden) and select the text,
  // ready for the user to type a path. Enter navigates, Esc restores & blurs.
  focusNav(id) { const p = this.#panes.get(id ?? this.#activeId); if (!p) return; if (!p.showBar) this.setBar(p.id, true); const input = p.bar && p.bar._nav; if (input) { input.focus(); input.select(); } }
  toggleBars() { this.#hoverToggle = !this.#hoverToggle; this.classList.toggle('ps-no-hovertoggle', !this.#hoverToggle); this.#positionBarToggle(); return this.#hoverToggle; }

  // ---- splitting: STRUCTURAL. active tab's history migrates to the child that
  // keeps the original content; the parent tab becomes the division. ----

  splitRight(id) { return this.#split(id ?? this.#activeId, 'horizontal'); }
  splitDown(id) { return this.#split(id ?? this.#activeId, 'vertical'); }

  // flip: the two sides of this division trade CONTENTS. The frame does not
  // move with them — same axis, same ratio, same folded slot — so flipping
  // twice is the identity and nothing resizes under you.
  flip(id) {
    const p = this.#panes.get(id ?? this.#activeId), par = p && p.parent;
    if (!par || !par.div) return false;
    const d = par.div, owner = d.owner, scroll = this.#snapshotScroll();
    const held = this.#addrWithin(owner, this.cursor) != null ? this.cursor : null;   // the PANE the selection is on, which is about to move
    const a = d.a, b = d.b;
    d.a = b; d.b = a;
    // the ratio belongs to the pane, not to the slot: a sidebar flipped to the
    // other side keeps ITS share rather than inheriting whatever the side it
    // moved into happened to have. ratio is always the START pane's fraction,
    // so swapping the panes inverts it.
    d.ratio = 1 - d.ratio;
    if (d.fold) d.fold = d.fold === 'a' ? 'b' : 'a';   // a folded side follows its pane
    d.a.parent = { div: d, slot: 'a' }; d.b.parent = { div: d, slot: 'b' };
    if (d.last) d.last = d.last === 'a' ? 'b' : 'a';   // follows the pane it names
    this.#placePane(d.a, d.sv, 'start'); this.#placePane(d.b, d.sv, 'end');
    this.#applyDivLayout(d); this.#afterStructure(); this.#restoreScroll(scroll);
    // the selection follows the PANE, not the slot: flipping moves what you
    // selected to the other side and you stay on it, so a flip reads as
    // carrying the thing rather than letting go of it
    if (held) this.cursorTo(held);
    this.#render(); this.#persist();
    return true;
  }
  // rotate: turn this division a quarter turn CLOCKWISE, panes and all. Side
  // by side becomes stacked with the left pane on top; stacked becomes side
  // by side with the top pane on the RIGHT, which is the step where the two
  // trade slots and the ratio inverts so each keeps the share it had. Four of
  // them put the division back exactly as it was, ratio and fold included.
  rotate(id) {
    const p = this.#panes.get(id ?? this.#activeId), par = p && p.parent;
    if (!par || !par.div) return false;
    const d = par.div, scroll = this.#snapshotScroll();
    const over = d.dir === 'vertical';                 // the half of the turn that carries the top pane around to the right
    d.dir = over ? 'horizontal' : 'vertical';
    if (over) {
      const a = d.a, b = d.b;
      d.a = b; d.b = a;
      d.a.parent = { div: d, slot: 'a' }; d.b.parent = { div: d, slot: 'b' };
      d.ratio = 1 - d.ratio;                           // each pane keeps its share of the division
      if (d.fold) d.fold = d.fold === 'a' ? 'b' : 'a'; // the folded one stays the folded one
      if (d.last) d.last = d.last === 'a' ? 'b' : 'a';
      this.#placePane(d.a, d.sv, 'start'); this.#placePane(d.b, d.sv, 'end');
    }
    this.#applyDivLayout(d); this.#afterStructure(); this.#restoreScroll(scroll);
    this.#render(); this.#persist();
    return true;
  }

  #split(id, orientation) {
    const pane = this.#panes.get(id);
    if (!pane) return null;
    const scroll = this.#snapshotScroll();     // reuse the live DOM across the split → preserve scroll
    // if this exact pane is itself currently hoisted, its body's real content
    // (what #renderPane would reapply below) is hidden behind the hoist —
    // undo that first, or liveBody below would just grab the hidden half
    const hoisted = this.#hoistInfo.get(pane);
    if (hoisted) { this.#unhoist(hoisted); this.#hoistInfo.delete(pane); pane.dom.classList.remove('ps-zoom-frame'); }
    const tab = pane.tabs[pane.activeTab];
    const curEntry = tab.entries[tab.cursor];
    const liveBody = pane.body.firstChild;      // the content already on screen
    // childA keeps the original content AND inherits this tab's whole history.
    const childA = this.#makePane();
    childA.tabs = [{ entries: tab.entries, cursor: tab.cursor }];
    childA.activeTab = 0;
    if (pane.showBar) { childA.showBar = true; childA.dom.classList.add('ps-bar-on'); }  // bar rides with the content
    if (pane.tabs.length <= 1) { pane.showBar = false; pane.dom.classList.remove('ps-bar-on'); }  // sole tab is now just the division → no bar; KEEP it if other tabs remain
    const childB = this.#makePane();   // fresh empty pane
    const sv = document.createElement('split-view');
    sv.setAttribute('orientation', orientation); sv.setAttribute('min', '40');
    const div = { dir: orientation, ratio: 0.5, fold: null, src: null, owner: pane, a: childA, b: childB, sv };
    sv.__psdiv = div;
    childA.parent = { div, slot: 'a' }; childB.parent = { div, slot: 'b' };
    // hand the LIVE content element to childA (no re-render / no reload); a
    // division entry is cheap to re-mount, so only reuse for leaf content.
    if (liveBody && curEntry && !curEntry.div && !curEntry.pane) { pane.body.removeChild(liveBody); childA.body.textContent = ''; childA.body.appendChild(liveBody); this.#renderBar(childA); }
    else this.#renderPane(childA);
    // the parent tab loses its history to childA; it now holds the division.
    tab.entries = [{ div }]; tab.cursor = 0;
    this.#renderPane(pane);                     // pane.body is now empty → mounts the division
    this.#afterStructure();
    this.#restoreScroll(scroll);
    this.focusPane(childB.id);
    this.#emit('ps-split', { id, dir: orientation, newId: childB.id });
    this.#persist();
    return childB.id;
  }
  // nest: wrap the active tab's content in a pane of its own, no split. The
  // tab's moment becomes a pane moment whose single child carries this tab's
  // whole history (and the live content, unreloaded). The child shows its bar,
  // since tabs of its own are the point. Prefix-n.
  nest(id) {
    const pane = this.#panes.get(id ?? this.#activeId); if (!pane) return null;
    const scroll = this.#snapshotScroll();
    const tab = pane.tabs[pane.activeTab];
    const curEntry = tab.entries[tab.cursor];
    const liveBody = pane.body.firstChild;
    const child = this.#makePane();
    child.tabs = [{ entries: tab.entries, cursor: tab.cursor, label: null }];
    child.activeTab = 0;
    child.parent = { host: pane, slot: 'a' };
    child.showBar = true; child.dom.classList.add('ps-bar-on');
    if (liveBody && curEntry && !curEntry.div && !curEntry.pane) { pane.body.removeChild(liveBody); child.body.textContent = ''; child.body.appendChild(liveBody); this.#renderBar(child); }
    else this.#renderPane(child);
    tab.entries = [{ pane: child, src: null }]; tab.cursor = 0;
    this.#renderPane(pane);
    this.#afterStructure(); this.#restoreScroll(scroll);
    this.focusPane(child.id);
    this.#emit('ps-nest', { id: pane.id, newId: child.id });
    this.#persist();
    return child.id;
  }

  // ---- closing: the surviving sibling's active history comes back UP ----

  // close a pane. If it lives in a division, its sibling is promoted into the
  // owner pane's active tab (history returns to the parent). If it's the owner's
  // whole content, close removes the whole pane from ITS parent division.
  // `force` skips the ask: for a caller that has already confirmed in its own
  // way (a touch client has no Enter to offer).
  close(pane, force) {
    pane = pane ?? this.cursor;
    if (!pane) return;
    // a pane with content is closed only on Enter: the ask arms it, Enter
    // closes, Esc or any other key cancels. A second × is not a confirm, so a
    // double-click cannot close it. An empty pane closes outright.
    const hasContent = pane.tabs.some(t => t.cursor >= 0);
    if (hasContent && !this.#closing && !force) {
      this.#pendingClose = pane; this.cursorTo(pane); this.focus();
      this.#flashHint('close this pane? Enter to confirm · Esc to cancel');
      return;
    }
    this.#cancelClose();
    if (this.#hoistInfo.size) this.zoomReset();
    const par = pane.parent;
    if (!par) {
      // root pane — clear the active tab's content entirely
      const tab = pane.tabs[pane.activeTab];
      if (this.#curEntry(pane)) { this.#eachEntryPane({ entries: tab.entries, cursor: tab.cursor }, cp => { if (cp !== pane) this.#forgetPane(cp); }); }
      tab.entries = []; tab.cursor = -1;
      this.#renderPane(pane); this.#reconcileCursor(); this.#afterStructure(); this.#persist();
      this.#refocus();
      return;
    }
    if (par.host) {
      // a nested pane: it IS its host tab's content, so closing it closes that tab
      const host = par.host;
      const i = host.tabs.findIndex(t => t.entries[t.cursor] && t.entries[t.cursor].pane === pane);
      if (i >= 0) this.closeTab(host.id, i);
      return;
    }
    const div = par.div, owner = div.owner;
    const sib = par.slot === 'a' ? div.b : div.a;
    const scroll = this.#snapshotScroll();      // reuse the sibling's live DOM → preserve scroll
    // free the whole closing subtree (the pane and everything under it)
    this.#eachPaneDeep(pane, cp => this.#forgetPane(cp), true);
    div.sv.__psdiv = null;
    // The survivor is NOT absorbed. The division becomes a pane moment holding
    // it — a monochild — so it keeps its own identity: every tab, every
    // history, its bar, its ref. Absorbing it used to mean promoting only its
    // ACTIVE tab and destroying the others, so closing one side of a split
    // silently cost you the survivor's other tabs, and cost you everything
    // when the active one happened to be empty. Moving its tabs up is a
    // deliberate act now (+promote), not a side effect of closing a neighbour.
    //
    //   The owner's bar is untouched: bar state is inherited DOWNWARD only (a
    //   split hands it to the child standing in for the pane you were looking
    //   at). The owner is a pane in its own right and keeps the visibility it
    //   was given.
    //
    const ownerTab = owner.tabs[owner.activeTab];
    const was = ownerTab.entries[ownerTab.cursor];
    const moment = { pane: sib };
    if (div.src) moment.src = div.src;                 // the layout it came from
    if (was && was.name) moment.name = was.name;       // and the name it was opened under
    ownerTab.entries[ownerTab.cursor] = moment;
    sib.parent = { host: owner, slot: 'a' };
    this.#renderPane(owner);                           // places sib's own DOM: scroll rides along
    this.#afterStructure();
    this.#restoreScroll(scroll);
    this.cursorTo(firstVisibleLeaf(owner, this));
    this.#emit('ps-close', {}); this.#persist();
    this.#refocus();
  }
  // +promote: move a HELD pane's tabs into the pane holding it, and let it go.
  //
  //   The deliberate half of consolidation. Closing one side of a split leaves
  //   a monochild — the owner holding a single pane — because absorbing it
  //   automatically meant keeping one tab and destroying the rest. This moves
  //   ALL of them: the held pane's tabs take the place of the moment that held
  //   it, in order, and the active one stays active. Afterwards the held pane
  //   is gone and the owner shows what it was showing.
  //
  //   From one SIDE of a division it means the same thing: this pane's tabs
  //   go up and this pane goes. The sibling stays — the division is left
  //   holding it alone, a monochild — so nothing is destroyed and there is
  //   nothing to confirm. The tabs land beside the division they came out of,
  //   not on top of it.
  //
  promote(id) {
    const p = this.#panes.get(id ?? this.#activeId); if (!p) return false;
    const par = p.parent;
    if (!par) { this.#flashHint('nothing holds this pane: there is nowhere to promote it to'); return false; }
    const scroll = this.#snapshotScroll();
    const mine = p.tabs;
    if (par.div) {
      const owner = par.div.owner;
      const at = owner.activeTab;
      // hand the tabs over BEFORE closing, so close has nothing to release and
      // sees an empty pane (no confirm): it then leaves the division holding
      // the sibling alone, and these slot in beside it.
      p.tabs = [{ entries: [], cursor: -1 }];
      this.close(p, true);
      owner.tabs.splice(at + 1, 0, ...mine);
      owner.activeTab = at + 1 + (p.activeTab || 0);
      owner.tabs.forEach((t) => t.entries.forEach((e) => this.#reparentDiv(e, owner)));
      this.#renderPane(owner);
      this.#afterStructure();
      this.#restoreScroll(scroll);
      this.cursorTo(owner);
      this.#persist();
      this.#refocus();
      return true;
    }
    if (!par.host) { this.#flashHint('nothing holds this pane: there is nowhere to promote it to'); return false; }
    const host = par.host;
    const i = host.tabs.findIndex((t) => { const e = t.entries[t.cursor]; return !!e && e.pane === p; });
    if (i < 0) { this.#flashHint('cannot find the moment holding this pane'); return false; }
    host.tabs.splice(i, 1, ...mine);
    host.activeTab = i + p.activeTab;
    // every structural moment that moved belongs to the host now, in every
    // tab and at every point in its history — a division sitting back in a
    // tab's past still named the pane it came from, which is about to go.
    host.tabs.forEach((t) => t.entries.forEach((e) => this.#reparentDiv(e, host)));
    p.tabs = [{ entries: [], cursor: -1 }];   // moved, not released: keep forgetPane off their stashes
    this.#forgetPane(p);
    this.#renderPane(host);
    this.#afterStructure();
    this.#restoreScroll(scroll);
    this.cursorTo(firstVisibleLeaf(host, this));
    this.#persist();
    this.#refocus();
    return true;
  }
  closeLeaf(id, force) { const p = this.#panes.get(id); if (p) this.close(p, force); }
  // the keyboard was in a pane that is gone: DOM focus fell to the body,
  // where the host's key listener cannot hear it. Land it in the active
  // pane's content, else on the host itself
  #refocus() {
    const a = document.activeElement;
    if (a && a !== document.body && this.contains(a)) return;
    this.focusContent();
    const b = document.activeElement;
    if (!b || b === document.body || !this.contains(b)) this.focus({ preventScroll: true });
  }
  #forgetPane(pane) { if (!pane) return; pane.tabs.forEach(t => this.#dropStash(pane, t)); try { if (this.onDestroy) this.onDestroy(pane.id, pane.body); } catch (_) {} this.#panes.delete(pane.id); this.#refIndex = null; pane.dom.remove(); }
  // after moving an entry into a new owner, fix the division's owner backref.
  #reparentDiv(entry, owner) { if (!entry) return; if (entry.div) entry.div.owner = owner; else if (entry.pane) entry.pane.parent = { host: owner, slot: 'a' }; }

  // ---- division layout (ratio + fold → split-view) ----

  #applyDivLayout(div) {
    const sv = div.sv;
    sv.setAttribute('orientation', div.dir);
    // split-view's `size` is the PRIMARY pane's size. ratio is always the START
    // pane's fraction, so when the primary is 'end' (collapsing b) the size must
    // be the END fraction (1 - ratio) — otherwise reopen restores it inverted.
    const primaryEnd = div.fold === 'b';
    sv.setAttribute('size', ((primaryEnd ? 1 - div.ratio : div.ratio) * 100) + '%');
    if (div.fold) { sv.setAttribute('primary', primaryEnd ? 'end' : 'start'); sv.setAttribute('collapsed', ''); }
    else { sv.setAttribute('primary', 'start'); sv.removeAttribute('collapsed'); }
  }
  #afterStructure() { this.#refIndex = null; this.#reconnectDivs(); this.#reposition(); }
  // walk the visible tree, (re)binding each division's owner + child parents, so
  // backrefs stay correct after history/tab moves, and lay out split-views.
  #reconnectDivs() {
    const walk = (pane) => {
      if (pane.cold) { pane.cold = false; this.#renderPane(pane); }   // first time visible: render now
      const e = this.#curEntry(pane);
      if (e && e.div) {
        const div = e.div;
        div.owner = pane;
        div.a.parent = { div, slot: 'a' }; div.b.parent = { div, slot: 'b' };
        this.#applyDivLayout(div);
        walk(div.a); walk(div.b);
      } else if (e && e.pane) {
        e.pane.parent = { host: pane, slot: 'a' };
        walk(e.pane);
      }
    };
    if (this.#root) walk(this.#root);
  }
  #onSvResize = (e) => {
    const div = e.target && e.target.__psdiv;
    // ignore resize while folded: `primary` points at the collapsed (end) side, so
    // the reported size is that side's — storing it would invert the ratio.
    if (div && !div.fold) { const dim = div.dir === 'horizontal' ? e.target.clientWidth : e.target.clientHeight; if (dim) div.ratio = Math.max(0.02, Math.min(0.98, (e.detail?.size ?? 0) / dim)); }
    this.#reposition(); this.#persist();
  };
  #onSvCollapse = (e) => {
    const div = e.target && e.target.__psdiv;
    if (!div) return;
    div.fold = e.detail?.collapsed ? ((e.target.getAttribute('primary') || 'start') === 'start' ? 'a' : 'b') : null;
    this.#applyDivLayout(div);   // re-drive the view from state (restore primary='start' + ratio on reopen)
    this.#render(); this.#persist();
  };

  // ---- cursor (structural selection over panes) ----

  get highlight() { return this.#selLevel; }
  set highlight(v) { this.#selLevel = Math.max(0, Math.min(2, v | 0)); this.#render(); }
  cycleHighlight() { this.#selLevel = (this.#selLevel + 2) % 3; this.#render(); return this.#selLevel; }

  cursorTo(pane) {
    if (!pane) return;
    if (this.#pendingClose && this.#pendingClose !== pane) this.#cancelClose();   // moving on backs out of a pending close
    // the quickbar belongs to the pane it dropped for, which is the selected
    // one: selecting any other pane retracts it, leaf or container alike
    if (this.#pillPane && pane !== this.#pillPane) this.#hidePill();
    this.#activeId = pane.id;
    // record a descend breadcrumb up the ownership chain
    let n = pane, owner = this.#ownerOf(pane);
    while (owner) { const ce = this.#curEntry(owner); if (ce && ce.div) ce.div.last = n.parent.slot; n = owner; owner = this.#ownerOf(owner); }
    this.#render();
    this.#emit('ps-focus', { id: pane.id, kind: this.#divides(pane) ? 'split' : 'leaf' });
    this.#persist();                                                 // the selection is part of the saved workspace
  }
  focusPane(id) { const p = this.#panes.get(id); if (p) this.cursorTo(p); }
  // DOM focus into the active pane's content, so unprefixed keys reach it:
  // the element the content marks data-focus (a chat's message box), else a
  // navigator's list (data-nk, see nav-keys.js), else the content element
  // itself (made focusable; keys then bubble up here and do nothing).
  // Called when the KEYBOARD chose the pane, and by prefix-i on demand; a
  // click focuses whatever was clicked by itself.
  focusContent(id) {
    let p = this.#panes.get(id ?? this.#activeId); if (!p) return;
    p = firstVisibleLeaf(p, this);                                   // a container: its first leaf is where content is
    const c = p.body.firstChild;
    if (!c || c.tagName === 'SPLIT-VIEW' || c.classList.contains('ps-pane')) return;
    const t = c.querySelector('[data-focus]') || c.querySelector('[data-nk]') || c;
    if (t.tabIndex < 0 && !t.hasAttribute('tabindex')) t.tabIndex = -1;
    try { t.focus({ preventScroll: true }); } catch (_) {}
  }
  // the pane one level up: the owner of the division this pane sits in, or
  // the host whose tab holds this pane (a pane moment)
  #ownerOf(pane) { const par = pane && pane.parent; return par ? (par.div ? par.div.owner : par.host) : null; }
  // clear every fold that hides `pane`, from it up to the root
  #unfold(pane) {
    let n = pane, changed = false;
    while (n && n.parent) {
      const par = n.parent;
      if (par.div && par.div.fold === par.slot) { par.div.fold = null; this.#applyDivLayout(par.div); changed = true; }
      n = this.#ownerOf(n);
    }
    if (changed) { this.#afterStructure(); this.#persist(); }
  }
  // a hoisted pane's own .parent still points at its REAL owner in the full
  // tree — correct for descendants inside it (hoisting only moves the
  // zoomed pane's own dom, not its children's logical parents), but wrong
  // at the top of the zoom itself: that real owner is now hidden behind the
  // zoom. Climbing from exactly that pane should land on the frame instead
  // — the thing actually standing in for "outward" while zoomed.
  #climbTarget(pane) {
    const ctx = this.#nearestContext(pane);
    const tab = ctx && ctx.tabs[ctx.activeTab];
    if (tab && tab.zoom && this.#descend(ctx, tab.zoom) === pane) return ctx;
    return this.#ownerOf(pane);
  }
  climb() { const o = this.#climbTarget(this.cursor); if (o) this.cursorTo(o); }
  // select the parent container (the division that owns this pane) and show the
  // purple container box around it.
  selectParent(id) { const p = id != null ? this.#panes.get(id) : this.cursor; const o = this.#climbTarget(p); if (!o) return; if (this.#selLevel < 2) this.#selLevel = 2; this.cursorTo(o); }
  // the mirror of #climbTarget: a frame currently hosting a hoisted zoom has
  // its OWN real structure hidden behind it, so descending from the frame
  // itself should land on the zoomed pane actually showing, not on that
  // hidden structure underneath.
  descend() {
    const cur = this.cursor;
    const tab = cur && cur.tabs[cur.activeTab];
    if (tab && tab.zoom) {
      const target = this.#descend(cur, tab.zoom);
      if (target) { this.cursorTo(target); return; }
    }
    const e = this.#curEntry(cur);
    if (e && e.pane) this.cursorTo(e.pane);
    else if (e && e.div) this.cursorTo(e.div.last === 'b' ? e.div.b : e.div.a);
  }
  sibling() { const c = this.cursor; if (c && c.parent && c.parent.div) { const d = c.parent.div; this.cursorTo(c.parent.slot === 'a' ? d.b : d.a); } }
  escape() {
    const z = this.#effectiveZoom(this.cursor);
    if (z) { z.frame.tabs[z.frame.activeTab].zoom = null; this.#afterZoom(z.frame, this.cursor); }
    else this.#render();
  }

  // if the selected pane became hidden (tab switch, close), pull the cursor to
  // the nearest visible ancestor.
  #reconcileCursor() {
    let c = this.cursor;
    if (!c) { this.#activeId = this.#root ? firstVisibleLeaf(this.#root, this).id : null; this.#render(); return; }
    while (c && this.#hidden(c)) c = this.#ownerOf(c);
    this.#activeId = (c || this.#root || {}).id || null;
    this.#render();
  }

  #render() {
    for (const p of this.#panes.values()) p.dom.classList.remove('ps-active', 'ps-dim');
    const sel = this.cursor;
    const selDivides = sel && this.#divides(sel);
    if (this.#selLevel >= 2 && selDivides && !this.#hidden(sel)) {
      const inSel = new Set(); this.#eachVisibleLeaf(sel, l => inSel.add(l.id));
      for (const p of this.#panes.values()) if (this.#isVisibleLeaf(p) && !inSel.has(p.id)) p.dom.classList.add('ps-dim');
      this.#placeBox(this.#selBox, sel);
    } else {
      this.#selBox?.classList.remove('on');
      if (this.#selLevel >= 1 && sel && !this.#hidden(sel)) sel.dom.classList.add('ps-active');
    }
    this.#renderMark();
    this.#positionBarToggle();
  }
  #reposition = () => {
    const sel = this.cursor;
    if (this.#selLevel >= 2 && sel && this.#divides(sel) && !this.#hidden(sel)) this.#placeBox(this.#selBox, sel);
    else this.#selBox?.classList.remove('on');
    this.#renderMark();
    this.#renderContext();
    this.#positionBarToggle();
  };
  // keep a showing quickbar anchored to the selected pane across scroll/resize;
  // hide it if that pane went away, got hidden, or locked its bar on.
  #positionBarToggle() {
    const t = this.#barToggle; if (!t || !t.classList.contains('on')) return;
    const c = this.#pillPane || this.cursor;
    if (!c || c.showBar || this.#hidden(c) || !this.#panes.has(c.id)) { this.#hidePill(); return; }
    this.#placeToggle(c);
  }
  // ---- sticky quickbar (thin host-level drop-down on top-edge hover) ----
  // It drops for the SELECTED pane only, when it has no bar. A container
  // (the root, a layout's own pane) gets it once selected — shift+click a
  // pane or prefix+[ climbs to it — never because a leaf inside it is.
  #onTopHover(e, id) {
    if (!this.#hoverToggle) return;
    const p = this.#panes.get(id); if (!p || p.showBar || this.#hidden(p)) return;
    // top-hover ownership belongs to exactly one pane at a time. A zoom's
    // frame owns it unconditionally (it's the outer edge the user actually
    // sees, even though it's never "active" while something is hoisted into
    // it); a pane that's currently hoisted INTO someone else's frame defers
    // entirely, rather than also answering for the same physical region —
    // otherwise the two fight over #pillPane on every mousemove tick,
    // each undoing the other's displacement. Everyone else: the plain old
    // "only the active pane" rule.
    const isFrame = this.#hoistInfo.has(p);
    const isHoisted = Array.from(this.#hoistInfo.values()).some((h) => h.z.pane === p);
    if (!isFrame && (id !== this.#activeId || isHoisted)) return;
    const r = p.dom.getBoundingClientRect();
    if (e.clientY - r.top <= 24) this.#showPill(p);                // near the top → drop it + refresh grace
  }
  #placeToggle(c) {
    const t = this.#barToggle, cr = this.getBoundingClientRect(), r = c.dom.getBoundingClientRect(), m = 3;
    t.style.left = (r.left - cr.left + m) + 'px';                   // inset so the selection frame stays visible
    t.style.top = (r.top - cr.top + m) + 'px';
    t.style.width = (r.width - m * 2) + 'px';
  }
  #showPill(p) {
    const t = this.#barToggle, c = p || this.cursor;
    if (!t || !this.#hoverToggle || !c || c.showBar || this.#hidden(c)) return;
    if (this.#pillPane && this.#pillPane !== c) this.#undisplace();
    this.#pillPane = c;
    this.#placeToggle(c);
    t.classList.add('on');
    this.#displace(c);                                             // shift the pane's content down beneath the bar
    this.#schedulePillHide(5000);
  }
  // push the pane's content down by the bar's height so it isn't hidden under it.
  // leaf bodies take padding; a division body holds an absolute split-view
  // (inset:0) that ignores padding, so shift its top instead.
  #displace(c) {
    this.#undisplace();
    const h = (this.#barToggle.offsetHeight || 30) + 6;
    const sv = c.body.querySelector(':scope > split-view');
    // a zoom frame's body already carries inline padding (its wall's 16px,
    // set in #hoist) — remember what was actually there so undisplace can
    // give it back exactly, instead of blanking it to 0 and leaving the
    // wall's own spacing permanently broken on the side we touched
    this.#padRestore = { paddingTop: c.body.style.paddingTop, sv, svTop: sv ? sv.style.top : null };
    c.body.style.paddingTop = h + 'px';
    if (sv) sv.style.top = h + 'px';
    this.#padBody = c.body;
  }
  #undisplace() {
    if (!this.#padBody) return;
    const r = this.#padRestore;
    this.#padBody.style.paddingTop = r ? r.paddingTop : '';
    if (r && r.sv) r.sv.style.top = r.svTop;
    this.#padBody = null; this.#padRestore = null;
  }
  #hidePill() { if (this.#barToggle) this.#barToggle.classList.remove('on'); this.#undisplace(); this.#holdPill(); this.#pillPane = null; }
  #holdPill() { if (this.#pillTimer) { clearInterval(this.#pillTimer); this.#pillTimer = null; } const el = this.#barToggle && this.#barToggle._count; if (el) el.textContent = ''; }
  #schedulePillHide(ms) { this.#holdPill(); this.#pillEnd = Date.now() + ms; this.#tickPill(); this.#pillTimer = setInterval(() => this.#tickPill(), 200); }
  #tickPill() {
    const rem = this.#pillEnd - Date.now();
    if (rem <= 0) { this.#hidePill(); return; }
    const el = this.#barToggle && this.#barToggle._count; if (el) el.textContent = Math.ceil(rem / 1000) + 's';
  }
  #placeBox(box, pane) {
    if (!box) return;
    const cr = this.getBoundingClientRect(), r = pane.dom.getBoundingClientRect();
    box.style.left = (r.left - cr.left) + 'px'; box.style.top = (r.top - cr.top) + 'px';
    box.style.width = r.width + 'px'; box.style.height = r.height + 'px';
    box.classList.add('on');
  }
  #renderMark() { if (!this.#markBox) return; if (this.#mark && this.#panes.has(this.#mark.id) && !this.#hidden(this.#mark)) this.#placeBox(this.#markBox, this.#mark); else this.#markBox.classList.remove('on'); }

  // a pane is hidden if a zoom excludes it, an ancestor folded its branch, or an
  // ancestor switched its tab/history away from the division that contains it.
  #hidden(pane) {
    // a zoom hides everything in its frame that is not in its target — every
    // ancestor's OWN active tab can independently carry one, so this has to
    // check each of them, not just the nearest
    for (let n = this.#ownerOf(pane); n; n = this.#ownerOf(n)) {
      const t = n.tabs[n.activeTab];
      if (t && t.zoom) {
        const target = this.#descend(n, t.zoom);
        if (target && !this.#within(target, pane)) return true;
      }
    }
    let n = pane;
    while (n) {
      // a hoisted pane sits in its frame's body: what lies between the two
      // (divisions, folds, tabs) no longer applies to it; a window zoom ends
      // the walk. n is hoisted iff n's own nearest context's active tab is
      // currently zoomed exactly onto n.
      const ctx = this.#nearestContext(n);
      const ctxTab = ctx && ctx.tabs[ctx.activeTab];
      if (ctxTab && ctxTab.zoom && this.#descend(ctx, ctxTab.zoom) === n) { n = ctx; continue; }
      const par = n.parent; if (!par) break;
      const owner = this.#ownerOf(n), ce = this.#curEntry(owner);
      if (par.div) {
        if (ce?.div !== par.div) return true;                     // owner looking elsewhere
        if (par.div.fold === par.slot) return true;              // folded away
      } else if (ce?.pane !== n) return true;                     // host's tab moved off this nested pane
      if (this.#showsSrc(owner)) return true;                    // owner showing its layout's source (raw), not the structure
      n = owner;
    }
    return false;
  }
  #within(anc, pane) { let n = pane; while (n) { if (n === anc) return true; n = this.#ownerOf(n); } return false; }

  focusNext() { const ids = this.leafIds; if (ids.length < 2) return; const i = ids.indexOf(this.#activeId); this.focusPane(ids[(i + 1) % ids.length]); }
  focusIndex(i) { const ids = this.leafIds; if (i >= 0 && i < ids.length) this.focusPane(ids[i]); }
  // move by the TREE, not by pixels: climb to the first division that splits
  // along this direction and has a side that way, cross to it, then take the
  // first leaf under it (slot a, first tab, all the way down). Same walk every
  // time, from wherever the pane happens to sit on screen.
  focusMove(dir) {
    const cur = this.cursor;
    if (!cur) return;
    const axis = (dir === 'left' || dir === 'right') ? 'horizontal' : 'vertical';
    const want = (dir === 'left' || dir === 'up') ? 'a' : 'b';
    let node = cur, par = node.parent;
    while (par && !(par.div && par.div.dir === axis && par.slot !== want)) { node = this.#ownerOf(node); par = node ? node.parent : null; }
    if (!par) return;                                  // nothing that way: stay put
    const leaf = firstVisibleLeaf(par.div[want], this);
    if (leaf && !this.#hidden(leaf)) this.focusPane(leaf.id);
  }

  // ---- zoom: a pane alone inside a frame; zooms stack outer to inner ----

  // the nearest context strictly above a pane — every zoom action fills
  // exactly this, never something hardcoded further out. No context
  // anywhere above it (root included, if it's been turned off) means no
  // frame exists, so there is nothing to zoom — a context can't be skipped.
  #nearestContext(pane) {
    for (let n = this.#ownerOf(pane); n; n = this.#ownerOf(n)) if (this.#contexts.has(n)) return n;
    return null;
  }
  // the zoom (if any) actually in effect for this pane right now: the
  // nearest ancestor (itself included) whose own active tab is zoomed onto
  // something that contains it. This is "what z/zoomParent/escape should act
  // on from here" — the tab-scoped replacement for "the top of the stack".
  #effectiveZoom(pane) {
    for (let n = pane; n; n = this.#ownerOf(n)) {
      const tab = n.tabs[n.activeTab];
      if (tab && tab.zoom) {
        const target = this.#descend(n, tab.zoom);
        if (target && this.#within(target, pane)) return { frame: n, pane: target };
      }
    }
    return null;
  }
  // z: the cursor fills its frame: the context when one is set and the
  // cursor is inside it, else the window. The same zoom again pops it.
  zoomToggle(pane) {
    pane = pane ?? this.cursor;
    if (!pane || !pane.parent) return;                              // the root already fills the window
    const frame = this.#nearestContext(pane);
    if (!frame) return;
    if (this.#hidden(pane)) return;                                 // not on screen: nothing to zoom
    const addr = this.#addrWithin(frame, pane);
    if (addr == null) return;
    const tab = frame.tabs[frame.activeTab];
    tab.zoom = (tab.zoom === addr) ? null : addr;
    this.#afterZoom(frame, pane);
  }
  // C: toggles a pane (the cursor, unless one is given — the toolbar button
  // passes its own pane explicitly) as a standing zoom context. Any number
  // of panes may be contexts; z fills the nearest one above the cursor.
  contextToggle(pane) {
    const c = pane ?? this.cursor; if (!c) return false;
    const on = !this.#contexts.has(c);                               // the root is a context like any other — turn it off and z has nowhere to land
    if (on) {
      this.#contexts.add(c);
      this.#renderContext(); this.#persist();
      this.#flashHint('context: z on a pane inside it fills it · C here again clears');
      return on;
    }
    this.#contexts.delete(c);
    // the frame this context offered inner zooms is gone — any zoom of c's
    // OWN (every tab, not just the active one) no longer has the boundary
    // that justified it, so it goes too
    let had = false;
    for (const t of c.tabs) if (t.zoom) { t.zoom = null; had = true; }
    this.#renderContext();
    if (had) { this.#renderPane(c); this.#afterStructure(); }
    this.#persist();
    this.#flashHint('context cleared');
    return on;
  }
  clearContext() {
    this.#contexts.clear();
    // no context left anywhere means no frame survives for any standing zoom
    for (const p of this.#panes.values()) for (const t of p.tabs) t.zoom = null;
    const frames = Array.from(this.#hoistInfo.keys());               // only these actually need re-rendering
    this.#renderContext();
    for (const f of frames) this.#renderPane(f);
    if (frames.length) this.#afterStructure();
    this.#persist();
  }
  #renderContext() {
    for (const p of this.#panes.values()) p.dom.classList.toggle('ps-zoom-ctx', this.#contexts.has(p) && !this.#hidden(p));
  }
  // pop whatever zoom is actually in effect from here — the tab-scoped
  // replacement for "pop the whole stack"
  zoomReset() {
    const frames = Array.from(this.#hoistInfo.keys());
    if (!frames.length) return;
    for (const f of frames) for (const t of f.tabs) t.zoom = null;
    for (const f of frames) this.#renderPane(f);
    this.#afterStructure();
    this.#emit('ps-zoom', {});
    this.#persist();
  }
  // make a specific pane fill its nearest context (toolbar "full screen this")
  zoomPane(id) {
    const p = this.#panes.get(id ?? this.#activeId);
    if (!p || !p.parent) { this.zoomReset(); return; }   // root already fills
    const frame = this.#nearestContext(p);
    if (!frame) return;                                   // no context above it: nothing to fill
    const addr = this.#addrWithin(frame, p);
    if (addr == null) return;
    frame.tabs[frame.activeTab].zoom = addr;
    this.#afterZoom(frame, p);
  }
  // step the zoom out to the parent of what's currently zoomed (or of this pane).
  zoomParent(id) {
    const given = this.#panes.get(id ?? this.#activeId);
    const active = this.#effectiveZoom(given || this.cursor);
    const from = active ? active.pane : given;
    const owner = from && this.#ownerOf(from);
    if (!owner || !owner.parent) { this.zoomReset(); return; }   // parent is the root → show everything
    const frame = this.#nearestContext(owner);
    if (!frame) return;                                           // no context above it: nothing to fill
    const addr = this.#addrWithin(frame, owner);
    if (addr == null) return;
    frame.tabs[frame.activeTab].zoom = addr;
    this.#afterZoom(frame, owner);
  }
  #afterZoom(frame, focusPane) {
    this.#renderPane(frame);
    this.#afterStructure();
    if (focusPane) this.cursorTo(focusPane);
    this.#emit('ps-zoom', {});
    this.#persist();
  }
  // apply or undo one frame's hoist, reparenting its live DOM in place —
  // #renderPane is what decides WHETHER to call these now, per its own
  // pane's tab data; these two just do the DOM work.
  #hoist(z) {
    const scroll = this.#snapshotScroll();   // reparenting a pane zeroes its scrollers — keep them
    const body = z.frame.body, hid = body.firstChild;                // the frame's division (or nested pane)
    if (hid) hid.style.display = 'none';
    this.#placePane(z.pane, body, null);
    const wall = this.#buildWall(z);
    let pad = null;
    if (wall) { body.appendChild(wall); pad = 'all'; body.style.padding = '16px'; }
    this.#restoreScroll(scroll);
    return { z, hid, wall, pad };
  }
  #unhoist(h) {
    const scroll = this.#snapshotScroll();
    const z = h.z, p = z.pane;
    if (h.wall) h.wall.remove();
    if (h.pad) z.frame.body.style.padding = '';
    if (h.hid) h.hid.style.display = '';
    if (p.parent) { const pp = p.parent; if (pp.div) this.#placePane(p, pp.div.sv, pp.slot === 'a' ? 'start' : 'end'); else this.#placePane(p, pp.host.body, null); }
    this.#restoreScroll(scroll);
  }
  // the frame's wall: thick on the side of the frame's own division that X
  // is not in; a click on it unfolds
  // the frame's walls, one on every side; a click on any of them unfolds
  #buildWall(z) {
    const e = this.#curEntry(z.frame); if (!e || !e.div) return null;
    const box = document.createElement('div'); box.className = 'ps-zoom-walls';
    for (const side of ['top', 'bottom', 'left', 'right']) {
      const w = document.createElement('div'); w.className = 'ps-zoom-wall ' + side;
      w.title = 'click, or z, to unzoom';
      w.addEventListener('click', (ev) => {
        ev.stopPropagation();
        const tab = z.frame.tabs[z.frame.activeTab];
        if (tab.zoom) { tab.zoom = null; this.#afterZoom(z.frame, z.pane); }
      });
      box.appendChild(w);
    }
    return box;
  }
  // snapshot/restore scroll offsets across a DOM reparent (scrollTop zeroes on move)
  #snapshotScroll() { const m = []; this.querySelectorAll('*').forEach((el) => { if (el.scrollTop || el.scrollLeft) m.push([el, el.scrollTop, el.scrollLeft]); }); return m; }
  #restoreScroll(m) { for (const [el, t, l] of m) { if (t) el.scrollTop = t; if (l) el.scrollLeft = l; } }

  // ---- collapse / resize (nearest ancestor division) ----

  // collapse: fold the given (or SELECTED) pane's slot → its sibling fills (toggle).
  collapse(id) {
    const pane = id != null ? this.#panes.get(id) : this.cursor, par = pane && pane.parent;
    if (!par || !par.div) return;
    par.div.fold = (par.div.fold === par.slot) ? null : par.slot;
    this.#applyDivLayout(par.div); this.#render(); this.#persist();
  }
  // expand: fold the COUNTERPART's slot → the selected pane fills (toggle).
  expand() {
    const pane = this.cursor, par = pane && pane.parent;
    if (!par || !par.div) return;
    const other = par.slot === 'a' ? 'b' : 'a';
    par.div.fold = (par.div.fold === other) ? null : other;
    this.#applyDivLayout(par.div); this.#render(); this.#persist();
  }
  nudge(dir) {
    const start = this.cursor;
    if (!start) return;
    const axis = (dir === 'left' || dir === 'right') ? 'horizontal' : 'vertical';
    let node = start, par = start.parent;
    while (par && (!par.div || par.div.dir !== axis)) { node = this.#ownerOf(node); par = node ? node.parent : null; }
    if (!par) return;
    const div = par.div;
    const dim = axis === 'horizontal' ? div.sv.clientWidth : div.sv.clientHeight;
    if (!dim) return;
    const step = 32 / dim, grow = (dir === 'right' || dir === 'down');
    div.ratio = Math.max(0.05, Math.min(0.95, div.ratio + (grow ? step : -step)));
    div.sv.setAttribute('size', (div.ratio * 100) + '%');
    this.#reposition(); this.#persist();
  }

  // ---- mark & swap (exchange two panes' positions) ----

  markToggle() { this.#mark = (this.#mark === this.cursor) ? null : this.cursor; this.#renderMark(); return !!this.#mark; }
  clearMark() { this.#mark = null; this.#renderMark(); }
  swap() {
    const c = this.cursor;
    if (this.#mark && this.#mark !== c) { if (this.#swapPanes(c, this.#mark)) { this.clearMark(); this.cursorTo(c); this.#persist(); } return; }
    const p = c && c.parent;
    if (!p || !p.div) return;
    const div = p.div, scroll = this.#snapshotScroll();
    [div.a, div.b] = [div.b, div.a];
    this.#placePane(div.a, div.sv, 'start'); this.#placePane(div.b, div.sv, 'end');   // move the DOM to match
    this.#afterStructure(); this.#restoreScroll(scroll); this.#render(); this.#persist();
  }
  #swapPanes(n1, n2) {
    if (n1 === n2 || !n1.parent || !n2.parent || !n1.parent.div || !n2.parent.div) return false;   // only division slots swap
    if (this.#within(n1, n2) || this.#within(n2, n1)) return false;
    const p1 = n1.parent, p2 = n2.parent, d1 = p1.div, d2 = p2.div, scroll = this.#snapshotScroll();
    d1[p1.slot] = n2; d2[p2.slot] = n1;
    n1.parent = { div: d2, slot: p2.slot }; n2.parent = { div: d1, slot: p1.slot };
    this.#placePane(n2, d1.sv, p1.slot === 'a' ? 'start' : 'end');   // re-append each pane into its new slot
    this.#placePane(n1, d2.sv, p2.slot === 'a' ? 'start' : 'end');
    this.#afterStructure(); this.#restoreScroll(scroll);
    return true;
  }

  // ---- serialize / restore / instantiate / persist ----

  // the workspace, with the selected pane as an address from the root: a
  // session's mirror follows the selection too (see browse.js sessions)
  // the root's ctx flag is written explicitly (true or false), never omitted
  // like other panes' — there's no implicit default to fall back to after a
  // reload, so "turned off" has to actually round-trip as false, not absent.
  serialize() { const s = this.#serPane(this.#root); if (s) { s.ctx = this.#contexts.has(this.#root); const c = this.#addrWithin(this.#root, this.cursor); if (c) s.cursor = c; if (this.seat) s.seat = this.seat; } return s; }
  cursorAddr() { return this.#root ? this.#addrWithin(this.#root, this.cursor) : null; }
  cursorToAddr(addr) { if (!this.#root || typeof addr !== 'string') return false; const t = this.#descend(this.#root, addr); if (!t) return false; this.cursorTo(t); return true; }
  #serPane(pane) {
    if (!pane) return null;
    // zoom is each tab's own field now — no separate reconstruction needed on
    // the way back in, #deserPane just reads it straight onto the same tab
    return { id: pane.ref || undefined, tabs: pane.tabs.map(t => ({ entries: t.entries.map(e => this.#serEntry(e)), cursor: t.cursor, label: t.label || undefined, view: t.view || undefined, zoom: t.zoom || undefined })), activeTab: pane.activeTab, bar: pane.showBar || undefined, nav: pane.nav === false ? false : undefined, open: pane.open || undefined, ctx: this.#contexts.has(pane) || undefined };
  }
  #serEntry(e) {
    const name = e.name || undefined;
    if (e.div) return { name, div: { dir: e.div.dir, ratio: e.div.ratio, fold: e.div.fold || undefined, src: e.div.src || undefined, a: this.#serPane(e.div.a), b: this.#serPane(e.div.b) } };
    if (e.pane) return { name, pane: Object.assign(this.#serPane(e.pane), { src: e.src || undefined }) };
    return name ? { path: e.path, name } : { path: e.path };
  }
  restore(spec) {
    if (this.#root) { this.#eachPaneDeep(this.#root, p => this.#forgetPane(p), true); for (const h of this.#hoistInfo.values()) h.z.pane.dom.remove(); this.#root.dom?.remove(); }
    this.#panes.clear(); this.#refIndex = null; this.#hoistInfo.clear(); this.#activeId = null; this.#mark = null; this.#contexts.clear();
    this.seat = (spec && typeof spec.seat === 'string' && spec.seat) || null;   // carried through, for whoever sits
    this.#root = spec ? this.#deserPane(spec, null) : this.#makePane();
    if (!spec) this.#contexts.add(this.#root);   // same default as seed(): fresh root starts as a context
    this.#placePane(this.#root, this, null);
    // zoom now lives on each tab directly (#deserPane already read it in) and
    // #reconnectDivs (inside #afterStructure) renders every cold pane it
    // walks through, which is exactly where #renderPane applies a hoist —
    // no separate reconstruction pass needed.
    this.#afterStructure();
    const sel = spec && typeof spec.cursor === 'string' ? this.#descend(this.#root, spec.cursor) : null;
    this.cursorTo(sel || firstVisibleLeaf(this.#root, this));
  }
  // build a detached pane subtree from a spec (for openLayout / instantiate)
  instantiate(spec) { return this.#deserPane(spec, null); }
  #buildDiv(spec, hostPane) {
    if (!spec || !spec.div) return null;
    const s = spec.div;
    const sv = document.createElement('split-view');
    sv.setAttribute('orientation', s.dir || 'horizontal'); sv.setAttribute('min', '40');
    const div = { dir: s.dir || 'horizontal', ratio: typeof s.ratio === 'number' ? s.ratio : 0.5, fold: s.fold || null, src: s.src || null, a: null, b: null, sv, owner: hostPane || null };
    sv.__psdiv = div;
    // a side is a pane. A side written as a bare {div} (the natural way to
    // nest splits by hand) is taken as a bar-less pane holding that division
    const side = (sp, slot) => this.#deserPane((sp && sp.div && !sp.tabs) ? { tabs: [{ entries: [sp], cursor: 0 }] } : sp, { div, slot });
    div.a = side(s.a, 'a');
    div.b = side(s.b, 'b');
    return div;
  }
  #deserPane(spec, parent) {
    const pane = this.#makePane();
    pane.parent = parent;
    if (!spec) return pane;
    pane.tabs = (spec.tabs || [{ entries: [], cursor: -1 }]).map(t => ({
      entries: (t.entries || []).map(e => {
        const name = (typeof e.name === 'string' && e.name) ? e.name : null;
        const out = e.div ? { div: this.#buildDiv(e, pane) } : e.pane ? { pane: this.#deserPane(e.pane, { host: pane, slot: 'a' }), src: e.pane.src || null } : { path: e.path };
        if (name) out.name = name;
        return out;
      }),
      cursor: typeof t.cursor === 'number' ? t.cursor : (t.entries && t.entries.length ? 0 : -1),
      label: (typeof t.label === 'string' && t.label) || null,
      view: (typeof t.view === 'string' && t.view) || null,
      zoom: (typeof t.zoom === 'string' && t.zoom) || null,
    }));
    pane.activeTab = typeof spec.activeTab === 'number' ? spec.activeTab : 0;
    pane.open = (spec.open && typeof spec.open === 'object') ? spec.open : null;
    pane.ref = (typeof spec.id === 'string' && spec.id) ? spec.id : null;        // the AUTHOR's id, written in a layout (pane.id is the internal handle)
    if (pane.ref) this.#refIndex = null;
    // root (parent === null) defaults to being a context when the field is
    // simply absent (a session saved before root's ctx was explicit) — every
    // other pane keeps the plain "present and truthy" reading
    if (parent === null ? spec.ctx !== false : spec.ctx) this.#contexts.add(pane);
    // a session saved before zoom moved onto the tab carried it on the pane
    // instead — give it to the tab that was active, same as the old `view` field
    if (typeof spec.zoom === 'string' && pane.tabs[pane.activeTab] && !pane.tabs[pane.activeTab].zoom) {
      pane.tabs[pane.activeTab].zoom = spec.zoom;
    }
    // an older workspace stored one view on the pane: give it to the tab
    // that was active, rather than dropping it
    if (spec.view && pane.tabs[pane.activeTab]) pane.tabs[pane.activeTab].view = spec.view;
    if (spec.nav === false) { pane.nav = false; pane.dom.classList.add('ps-nav-off'); }
    // bind division owners for every entry (not just the active one)
    pane.tabs.forEach(t => t.entries.forEach(e => { if (e.div) e.div.owner = pane; }));
    if (spec.bar) { pane.showBar = true; pane.dom.classList.add('ps-bar-on'); }
    // COLD: the structure is built, the content is not. A pane renders the
    // first time it is reachable through active entries (#reconnectDivs
    // walks exactly that path after every structural change), so a tab
    // nobody has selected, or a layout deep in some history, costs no
    // requests until it is looked at.
    pane.cold = true;
    return pane;
  }
  // TODO(perf): history is unbounded, and every layout a tab ever walked
  // through stays in it as a full pane tree (a real workspace reached 87
  // structural panes for 4 visible). Cold building makes that free at load,
  // but it is still built and serialized on every change. Cap history per
  // tab, or drop layout entries past N steps back.
  #depthOf(pane) { let d = 0; for (let n = this.#ownerOf(pane); n; n = this.#ownerOf(n)) d++; return d; }
  #saveKey() { const a = this.getAttribute('persist'); return a ? 'gmux:' + a : null; }
  // a workspace saved under the old name (pane-split:) is read once and re-saved under gmux:
  #legacyKey() { const a = this.getAttribute('persist'); return a ? 'pane-split:' + a : null; }
  // every change of the workspace is announced (gmux-change) whether or not
  // it persists locally: a session client writes it to the ship from that
  #persist() { this.#emit('gmux-change', {}); const k = this.#saveKey(); if (!k) return; clearTimeout(this.#saveTimer); this.#saveTimer = setTimeout(() => { try { localStorage.setItem(k, JSON.stringify(this.serialize())); } catch (_) {} }, 150); }

  // ---- traversal helpers ----

  // every pane in the tree (all tabs/entries), optionally skipping the root itself
  #eachPaneDeep(pane, fn, includeSelf) {
    if (!pane) return;
    pane.tabs.forEach(t => t.entries.forEach(e => { if (e.div) { this.#eachPaneDeep(e.div.a, fn, true); this.#eachPaneDeep(e.div.b, fn, true); } else if (e.pane) this.#eachPaneDeep(e.pane, fn, true); }));
    if (includeSelf) fn(pane);
  }
  // every pane reachable through one tab's entries (its division children, its nested panes)
  #eachEntryPane(tab, fn) { tab.entries.forEach(e => { if (e.div) { this.#eachPaneDeep(e.div.a, fn, true); this.#eachPaneDeep(e.div.b, fn, true); } else if (e.pane) this.#eachPaneDeep(e.pane, fn, true); }); }
  // visible leaves: follow the active entry; a pane showing a division recurses,
  // one showing a path/empty is a leaf.
  // a pane "divides" only when its active entry is a div AND it's not showing that
  // layout's source (raw view) — a raw layout pane is a leaf (it shows a file).
  // a pane is showing its layout's SOURCE (raw) instead of the live division —
  // only when a non-default view is set AND there's a src to show. A src-less
  // inner split in raw view keeps dividing; raw there has nothing to swap in.
  // the source a structural moment came from: a division's src, a pane moment's
  #entrySrc(e) { return e ? (e.div ? e.div.src : e.pane ? e.src : null) : null; }
  #showsSrc(pane) { const e = this.#curEntry(pane); return !!(this.#tabView(pane) && e && (e.div || e.pane) && this.#entrySrc(e)); }
  // a pane "divides" (is a container, not a leaf) when its moment is a division
  // or a pane moment, and it is not showing that moment's source
  #divides(pane) { const e = this.#curEntry(pane); return !!(e && (e.div || e.pane)) && !this.#showsSrc(pane); }
  #isVisibleLeaf(pane) { return this.#panes.has(pane.id) && !this.#divides(pane) && !this.#hidden(pane); }
  #eachVisibleLeaf(pane, fn) {
    if (!pane) return;
    if (this.#divides(pane)) { const e = this.#curEntry(pane); if (e.pane) this.#eachVisibleLeaf(e.pane, fn); else { this.#eachVisibleLeaf(e.div.a, fn); this.#eachVisibleLeaf(e.div.b, fn); } }
    else if (!this.#hidden(pane)) fn(pane);
  }

  // ---- keys ----

  get #prefix() {
    const raw = (this.getAttribute('prefix') || 'ctrl+b').toLowerCase().split('+');
    return { key: raw.pop(), ctrl: raw.includes('ctrl'), meta: raw.includes('meta') || raw.includes('cmd'), alt: raw.includes('alt') };
  }
  #isPrefix(e) { const p = this.#prefix; return e.key.toLowerCase() === p.key && e.ctrlKey === p.ctrl && e.metaKey === p.meta && e.altKey === p.alt; }
  // a set mark ARMS a swap: bare Space completes it from anywhere on the page
  // (no prefix, even mid-move), as long as you're not typing in a field. Lives
  // at window level so it fires regardless of which element holds focus.
  #onKeyGlobal = (e) => {
    if (!this.#mark || e.key !== ' ' || e.ctrlKey || e.metaKey || e.altKey) return;
    if (isEditable(e.target) || isEditable(document.activeElement)) return;
    this.#endRepeat(); this.swap(); e.preventDefault(); e.stopPropagation();
  };
  #cancelClose() { if (!this.#pendingClose) return; this.#pendingClose = null; this.#flashHint(''); }
  #onKey = (e) => {
    // typing in a field (the navbar, a chat box) is the field's, except the
    // prefix chord itself, which must work from anywhere to leave the field;
    // a prefix already down, or a repeat, still owns the next key
    if (!this.#awaiting && !this.#repeat && !this.#pendingClose && isEditable(e.target) && !this.#isPrefix(e)) return;
    if (this.#pendingClose) {
      const p = this.#pendingClose;
      e.preventDefault(); e.stopPropagation();
      if (e.key === 'Enter') { this.#closing = true; try { this.close(p); } finally { this.#closing = false; } return; }   // Enter closes for real
      this.#cancelClose(); return;                                // anything else backs out
    }
    if (this.#histMenu && this.#histMenu.classList.contains('on') && e.key === 'Escape') { this.#closeHistMenu(); e.preventDefault(); e.stopPropagation(); return; }
    if (this.#repeat && !this.#awaiting) {
      if (MODS[e.key]) return;
      const d = DIR[e.key];
      if (d) { if (this.#repeat === 'resize' || e.shiftKey) this.nudge(d); else this.focusMove(d); this.#arm(this.#repeat); e.preventDefault(); e.stopPropagation(); return; }
      this.#endRepeat();
      if (e.key === 'Escape') { e.preventDefault(); return; }
    }
    if (!this.#awaiting) {
      if (this.#isPrefix(e)) {
        this.#awaiting = true;
        this.#flashHint('gmux · % split · " stack · c/e collapse/expand · z zoom · C context · f flip · r rotate · x close · t/w tab · T bar · : path · i content · <> tab · ,. back/fwd · R refresh · m mark · ␣ swap · [ ] climb/descend · Tab sibling · h highlight · b bars · 1-9 jump · ←↑↓→ move · ⇧←↑↓→ resize');
        clearTimeout(this.#awaitTimer);
        this.#awaitTimer = setTimeout(() => { this.#awaiting = false; this.#flashHint(''); }, 2500);
        e.preventDefault(); e.stopPropagation();
      }
      return;
    }
    const k = e.key;
    if (MODS[k]) { e.preventDefault(); return; }
    this.#awaiting = false; clearTimeout(this.#awaitTimer); this.#flashHint('');
    let handled = true;
    const dir = DIR[k];
    if (k === '%' || k === '|') this.splitRight();
    else if (k === '"' || k === '-') this.splitDown();
    else if (k === 'x') this.close();
    else if (k === 'n') { this.nest(); this.#flashHint('nested: this tab now holds a pane of its own'); }
    else if (k === 'z') this.zoomToggle();
    else if (k === 'C') this.contextToggle();
    else if (k === 'b') { const on = this.toggleBars(); this.#flashHint('pane bars: ' + (on ? 'toggleable on hover' : 'locked')); }
    else if (k === 'f') this.flip();                   // swap the two sides of this division
    else if (k === 'c') this.collapse();
    else if (k === 'e' || k === 'E') this.expand();
    else if (k === 'h') { const lv = this.cycleHighlight(); this.#flashHint('highlight: ' + ['none', 'active only', 'full'][lv]); }
    else if (k === 'o') this.focusNext();
    else if (k === ' ') this.swap();
    else if (k === 'm') { const on = this.markToggle(); this.#flashHint(on ? 'marked — space on another pane swaps' : 'mark cleared'); }
    else if (k === 't') this.newTab(this.#activeId, this.#curPath(this.#activeId));
    else if (k === 'T') this.setBar(this.#activeId);   // toggle the selected pane's bar
    else if (k === ':') this.focusNav(this.#activeId); // jump to the navbar to type a path
    else if (k === 'i') { /* into the content: its input or navigator (focusContent runs below) */ }
    else if (k === 'w') this.closeTab(this.#activeId, this.cursor ? this.cursor.activeTab : -1);
    else if (k === '<' || k === ',') { if (k === '<') this.#cycleTab(-1); else this.back(); }
    else if (k === '>' || k === '.') { if (k === '>') this.#cycleTab(1); else this.forward(); }
    else if (k === '[') this.climb();
    else if (k === ']') this.descend();
    else if (k === 'Tab') this.sibling();
    else if (k === 'Escape') this.escape();
    else if (k >= '1' && k <= '9') this.focusIndex(+k - 1);
    else if (k === 'r') this.rotate();                 // a quarter turn clockwise; four of them are the identity
    else if (k === 'R') this.refresh(this.#activeId);   // refresh the moment in place
    else if (dir && e.shiftKey) { this.nudge(dir); this.#arm('resize'); }
    // a prefixed arrow moves ONCE and hands the keys to the pane it landed in,
    // so ↓ ↑ there walk its navigator right away; another move is another
    // prefix. Only resize (r, ⇧arrows) keeps the arrows as a repeat.
    else if (dir) this.focusMove(dir);
    else handled = false;
    if (handled) { e.preventDefault(); e.stopPropagation(); }
    // the keyboard chose a pane: give its content the keys. Not while a
    // move/resize repeat is armed (the arrows are ours until it ends) and not
    // after `:`, which put the caret in the navbar on purpose
    if (handled && !this.#repeat && k !== ':') this.focusContent();
  };
  #cycleTab(delta) { const p = this.cursor; if (!p || p.tabs.length < 2) return; this.selectTab(p.id, (p.activeTab + delta + p.tabs.length) % p.tabs.length); }
  #arm(kind) { this.#repeat = kind; this.#flashHint((kind === 'resize' ? 'resize' : 'move') + ': ←↑↓→  (any other key or Esc to exit)'); }
  #endRepeat() { this.#repeat = null; this.#flashHint(''); this.focusContent(); }
  #flashHint(msg) { if (!this.#hint) return; this.#hint.textContent = msg; this.#hint.classList.toggle('on', !!msg); }
  #emit(name, detail) { this.dispatchEvent(new CustomEvent(name, { detail, bubbles: true, composed: true })); }
}

function isEditable(el) { if (!el) return false; const t = el.tagName; return t === 'INPUT' || t === 'TEXTAREA' || t === 'SELECT' || !!el.isContentEditable; }
// the first leaf under a pane: through a division's `a` side and through a
// pane moment's nested pane, down to a pane whose moment is a path
function firstVisibleLeaf(pane, ps) {
  const e = pane.tabs[pane.activeTab] && pane.tabs[pane.activeTab].entries[pane.tabs[pane.activeTab].cursor];
  if (e && e.div) return firstVisibleLeaf(e.div.a, ps);
  if (e && e.pane) return firstVisibleLeaf(e.pane, ps);
  return pane;
}

// attachPathChip: show a path's leading @name as a CHIP instead of text.
//
// The chip is the resting state and plain text is the editing state. Clicking
// the chip swaps what it READS between the name and the place it resolves to;
// it never changes what the field commits, because `@clanker/x` is how the
// moment is stored and written — the absolute form is a readout. Backspace
// with the caret at the head dissolves the chip back into literal text, and
// the field re-chips when it settles (blur, or a fresh value set on it).
//
// Re-chipping as you type would fight you — `@cl` would snap shut mid-word —
// so nothing re-chips while the field has focus.
//
//   opts.parse(value)  -> {head, rest} | null   head is the literal '@name'
//   opts.alt(head)     -> string | Promise<string> | null   where it resolves
//
// Returns { set(value), get(), el } — `get` is the full stored path, chip and
// rest rejoined, so callers read it instead of input.value.
window.attachPathChip = function attachPathChip(input, opts) {
  const wrap = input.parentNode;
  const chip = document.createElement('button');
  chip.type = 'button'; chip.className = 'ps-chip'; chip.tabIndex = -1;
  wrap.insertBefore(chip, input);
  let full = '', abs = false, off = false, cut = null;   // cut: the parse the chip is showing
  const render = () => {
    cut = off ? null : (() => { try { return opts.parse(full); } catch (_) { return null; } })();
    wrap.classList.toggle('ps-chipped', !!cut);
    if (!cut) { input.value = full; return; }
    input.value = cut.rest;
    const show = (t) => { chip.textContent = t; chip.classList.toggle('ps-chip-abs', abs && t !== cut.head); };
    if (!abs) { show(cut.head); chip.title = 'click to see where ' + cut.head + ' resolves to'; return; }
    chip.title = 'click to go back to ' + cut.head;
    let a = null; try { a = opts.alt ? opts.alt(cut.head) : null; } catch (_) {}
    if (a && typeof a.then === 'function') {
      const was = cut.head; show('resolving…');
      a.then((t) => { if (cut && cut.head === was && abs) show(t || was); }, () => { if (cut && cut.head === was && abs) show(was); });
    } else show(a || cut.head);
  };
  // the chip is a readout, so toggling it must not take the caret out of the
  // field someone may be typing in
  chip.addEventListener('mousedown', (e) => e.preventDefault());
  chip.addEventListener('click', (e) => { e.preventDefault(); e.stopPropagation(); abs = !abs; render(); });
  // The chip contributes its head to a REST. Typing a whole @path over the
  // rest means the chip is being replaced, not added to, so it stands aside
  // rather than doubling its own name onto the front.
  const get = () => {
    if (!cut) return input.value;
    return input.value.startsWith('@') ? input.value : cut.head + input.value;
  };
  input.addEventListener('keydown', (e) => {
    if (e.key !== 'Backspace' || !cut) return;
    if (input.selectionStart !== 0 || input.selectionEnd !== 0) return;   // only at the very head, nothing selected
    e.preventDefault();
    const head = cut.head, rest = input.value;
    off = true; abs = false; full = head + rest;
    render();
    try { input.setSelectionRange(head.length, head.length); } catch (_) {}
  });
  // settling re-chips: what you left behind is a stored path again
  input.addEventListener('blur', () => { full = get(); off = false; render(); });
  return { el: chip, get, get chipped() { return !!cut; }, set(v) { full = v == null ? '' : String(v); off = false; abs = false; render(); } };
};

customElements.define('gmux-host', Gmux);
