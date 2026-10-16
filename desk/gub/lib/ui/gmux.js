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
//     zoomToggle/zoomOut/zoomReset · focusPane · climb/descend/sibling · setBar · toggleBars
//   data: serialize() · restore(spec) · instantiate(spec)
//
//   KEYS (after prefix): % / | split right · " / - split down · c collapse · e expand ·
//     z/Z zoom in/out · C set/clear zoom context · x close · b lock bars · o cycle · m mark · ␣ swap ·
//     [ ] climb/descend · Tab sibling · Esc reset · h highlight · 1-9 jump ·
//     t new tab · w close tab · T toggle bar · : focus navbar · < > prev/next tab · , . back/forward ·
//     arrows move · shift+arrows / r resize (sticky).
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
    content:""; position:absolute; inset:0; pointer-events:none;
    outline:1px solid transparent; outline-offset:-1px; transition:outline-color .1s;
  }
  .ps-pane.ps-active::after { outline:2px solid var(--ps-accent,#0969da); outline-offset:-2px; }
  /* a zoomed frame: a pane whose body shows one descendant alone. Its wall is the
     ordinary pane border, thicker and a shade darker: structure, not selection.
     The folded siblings are that wall with their names set into it, on the side
     they lived; a click on it zooms back out. */
  .ps-pane.ps-zoom-frame > .ps-pane-body { padding:3px; }
  .ps-pane.ps-zoom-ctx > .ps-pane-body { padding:3px; box-shadow: inset 0 0 0 3px var(--ps-wall,#cfd5db); }
  .ps-zoom-wall { position:absolute; z-index:3; background:var(--ps-wall,#cfd5db); color:#57606a; font:600 11px ui-monospace,Menlo,monospace; cursor:pointer; display:flex; gap:12px; align-items:center; overflow:hidden; white-space:nowrap; user-select:none; box-sizing:border-box; }
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
  .ps-bar-tabs { display:flex; align-items:center; gap:2px; flex:1 1 auto; min-width:0; overflow-x:auto; scrollbar-width:none; }
  .ps-bar-tabs::-webkit-scrollbar { display:none; }
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
  .ps-histmenu { position:absolute; z-index:30; display:none; flex-direction:column; min-width:160px; max-width:320px; max-height:50%; overflow-y:auto; background:#fff; border:1px solid #d0d7de; border-radius:8px; box-shadow:0 6px 20px rgba(0,0,0,.14); padding:4px; }
  .ps-histmenu.on { display:flex; }
  .ps-hm-row { all:unset; cursor:pointer; display:flex; align-items:center; gap:6px; padding:5px 9px; border-radius:6px; font:13px -apple-system,BlinkMacSystemFont,sans-serif; color:#24292f; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
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
  updateContent = null; // optional (el, path, paneId) => bool: update the shown content to a new moment in place; false → rebuild
  reloadLayout = null;  // optional (paneId, src) => void: re-read a layout's source and reapplyLayout (a refresh on a layout pane)
  viewModes = null;    // optional [{id, glyph, title}] → a per-pane render-mode toggle on the bar; host's renderPath reads viewOf(id)

  #root = null;                 // the root PANE
  #panes = new Map();           // id -> pane
  #activeId = null;             // the selected/active pane id
  #selLevel = 2;
  #zoomStack = [];              // zooms, outer to inner: { pane, frame }; the root is a frame like any other
  #mark = null;                 // a marked pane (for swap)
  #contexts = new Set();        // standing zoom frames (C toggles a pane); z fills the nearest one above the cursor, else the window
  #pendingClose = null;         // a pane with content whose close awaits Enter
  #closing = false;             // set only while Enter runs the confirmed close
  #hoists = [];                 // zooms applied to the DOM: { entry, hid, wall, pad }
  #hoverToggle = true;
  #pillTimer = null;            // interval that counts the quickbar's sticky grace down
  #pillEnd = 0;                 // when the quickbar is due to retract (ms epoch)
  #padBody = null;             // the pane body currently padded down to make room for the quickbar
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
    const pane = { kind: 'pane', id, dom, body, bar, tabs: [{ entries: [], cursor: -1 }], activeTab: 0, parent: null, showBar: false, nav: true, open: null, view: null };
    this.#panes.set(id, pane);
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
    row1.append(menu, hide, tabs, add, viewBtn,
      btn('◨', 'split right', () => this.splitRight(id)), btn('⬓', 'split down', () => this.splitDown(id)),
      btn('⤓', 'collapse pane', () => this.collapse(id)),
      btn('⬉', 'select parent container', () => this.selectParent(id)),
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
    input.addEventListener('keydown', (e) => {
      e.stopPropagation();
      if (e.key === 'Enter') { const v = input.value.trim(); if (v) { this.focusPane(id); this.navigate(id, v); if (this.onNavigate) try { this.onNavigate(id, v); } catch (_) {} } }
      else if (e.key === 'Escape') { input.value = this.#curPath(id) || ''; input.blur(); }
    });
    nav.appendChild(input);
    // where links from this pane land is the layout's routing table (its
    // `open` rules), edited in the layout file: nothing on the bar sets it
    row2.append(back, fwd, reload, nav);
    bar.append(row1, row2);
    bar._back = back; bar._fwd = fwd; bar._tabs = tabs; bar._nav = input; bar._view = viewBtn;
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
    if (bar._nav !== document.activeElement) bar._nav.value = navVal;
    bar._nav.placeholder = (e && (e.div || e.pane)) ? (this.#entrySrc(e) || 'layout') : 'path…';
    let hint = ''; if (this.pathHint && navVal) { try { hint = this.pathHint(navVal) || ''; } catch (_) {} }
    bar._nav.title = hint;
    // per-pane render-mode toggle — an ACTION button, so it shows the mode it
    // will switch TO (not the current one).
    if (this.viewModes && this.viewModes.length) {
      const cur = pane.view || this.viewModes[0].id;
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
    this.#dropZoomsFramedBy(pane);                                  // its body is about to be rebuilt: nothing stays hoisted in it
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
    if (entry && (entry.div || entry.pane) && pane.view && src) {
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
  #addrWithin(holder, pane) {
    if (holder === pane) return '.';
    const segs = [];
    let n = pane;
    for (;;) {
      const par = n && n.parent; if (!par) return null;
      let node, entry;
      if (par.div) { segs.unshift(par.slot); node = par.div.owner; entry = (e) => e.div === par.div; if (par.div === holder) return segs.join('/'); }
      else { segs.unshift('a'); node = par.host; entry = (e) => e.pane === n; }
      if (!node) return null;
      const ti = node.tabs.findIndex((t) => t.entries.some(entry));
      if (ti < 0) return null;
      segs.unshift(String(ti));
      if (node === holder) return segs.join('/');
      n = node;
    }
  }
  #descend(holder, addr) {
    addr = String(addr || '').trim();
    if (addr === '.' || addr === '') return holder.kind === 'pane' ? holder : null;
    const parts = addr.split('/').filter((s) => s.length && s !== '.');
    let at = holder;                                   // a pane, or a division
    for (const seg of parts) {
      if (at.kind === 'pane') {
        const t = at.tabs[Number(seg)]; if (!t) return null;
        const e = t.entries[t.cursor]; if (!e) return null;
        at = e.div ? e.div : e.pane ? { pane: e.pane } : null; if (!at) return null;
        continue;
      }
      if (at.pane) { if (seg !== 'a') return null; at = at.pane; continue; }   // a pane entry's single slot
      if (seg !== 'a' && seg !== 'b') return null;
      at = at[seg]; if (!at) return null;              // a division's side
    }
    return at.kind === 'pane' ? at : at.pane || null;
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
  #routeFrom(pane) {
    for (const h of this.#holdersOf(pane)) {
      if (!h.open) continue;
      const a = this.#addrWithin(h, pane); if (a == null) continue;
      const rule = h.open[a]; if (!rule) continue;
      const t = this.#descend(h, rule.to);
      if (t) return { target: t, mode: rule.mode === 'tab' ? 'tab' : 'replace' };
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
    this.#renderPane(p); this.#reconcileCursor(); this.#afterStructure(); this.#persist();
    this.#refocus();
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
      if (op.view) np.view = op.view;
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
  viewOf(id) { const p = this.#panes.get(id ?? this.#activeId); return p ? p.view : null; }
  setView(id, v) { const p = this.#panes.get(id ?? this.#activeId); if (!p) return; p.view = v || null; this.#renderPane(p); this.#persist(); }
  #cycleView(id) {
    if (!this.viewModes || !this.viewModes.length) return;
    const p = this.#panes.get(id); if (!p) return;
    const cur = p.view || this.viewModes[0].id;
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
    const cur = p.body.firstChild, leaving = p.tabs[p.activeTab];
    if (cur && cur.tagName !== 'SPLIT-VIEW' && !cur.classList.contains('ps-pane')) { leaving.el = cur; cur.remove(); }
    p.activeTab = i;
    const tab = p.tabs[i];
    if (tab.el) { const el = tab.el; tab.el = null; p.body.textContent = ''; p.body.appendChild(el); this.#renderBar(p); }
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

  #split(id, orientation) {
    const pane = this.#panes.get(id);
    if (!pane) return null;
    const scroll = this.#snapshotScroll();     // reuse the live DOM across the split → preserve scroll
    const savedZoom = this.#zoomStack;
    if (savedZoom.length) { this.#zoomStack = []; this.#applyZoom(); }
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
    if (savedZoom.length) { this.#zoomStack = savedZoom; this.#applyZoom(); }
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
  close(pane) {
    pane = pane ?? this.cursor;
    if (!pane) return;
    // a pane with content is closed only on Enter: the ask arms it, Enter
    // closes, Esc or any other key cancels. A second × is not a confirm, so a
    // double-click cannot close it. An empty pane closes outright.
    const hasContent = pane.tabs.some(t => t.cursor >= 0);
    if (hasContent && !this.#closing) {
      this.#pendingClose = pane; this.cursorTo(pane); this.focus();
      this.#flashHint('close this pane? Enter to confirm · Esc to cancel');
      return;
    }
    this.#cancelClose();
    if (this.#zoomStack.length) this.zoomReset();
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
    // promote the sibling's ACTIVE tab history into the owner's active tab
    const ownerTab = owner.tabs[owner.activeTab];
    const sibTab = sib.tabs[sib.activeTab];
    const sibEntry = sibTab.entries[sibTab.cursor];
    const sibLive = sib.body.firstChild;        // the sibling's live content
    ownerTab.entries = sibTab.entries; ownerTab.cursor = sibTab.cursor;
    owner.showBar = sib.showBar; owner.dom.classList.toggle('ps-bar-on', owner.showBar);  // bar bubbles back up with the content
    this.#reparentDiv(ownerTab.entries[ownerTab.cursor], owner);
    // drop sib's OTHER tabs' panes (its active history moved up)
    sib.tabs.forEach((t, i) => { if (i !== sib.activeTab) this.#eachEntryPane(t, cp => this.#forgetPane(cp)); });
    // hand the sibling's LIVE leaf content to the owner (no re-render / no reload)
    if (sibLive && sibEntry && !sibEntry.div && !sibEntry.pane) { sib.body.removeChild(sibLive); owner.body.textContent = ''; owner.body.appendChild(sibLive); this.#renderBar(owner); }
    else this.#renderPane(owner);
    this.#forgetPane(sib);
    this.#afterStructure();
    this.#restoreScroll(scroll);
    this.cursorTo(owner);
    this.#emit('ps-close', {}); this.#persist();
    this.#refocus();
  }
  closeLeaf(id) { const p = this.#panes.get(id); if (p) this.close(p); }
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
  #forgetPane(pane) { if (!pane) return; pane.tabs.forEach(t => this.#dropStash(pane, t)); try { if (this.onDestroy) this.onDestroy(pane.id, pane.body); } catch (_) {} this.#panes.delete(pane.id); pane.dom.remove(); }
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
  #afterStructure() { if (this.#zoomStack.length) this.#applyZoom(); else this.#reconnectDivs(); this.#reposition(); }
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
  climb() { const o = this.#ownerOf(this.cursor); if (o) this.cursorTo(o); }
  // select the parent container (the division that owns this pane) and show the
  // purple container box around it.
  selectParent(id) { const p = id != null ? this.#panes.get(id) : this.cursor; const o = this.#ownerOf(p); if (!o) return; if (this.#selLevel < 2) this.#selLevel = 2; this.cursorTo(o); }
  descend() { const e = this.#curEntry(this.cursor); if (e && e.pane) this.cursorTo(e.pane); else if (e && e.div) this.cursorTo(e.div.last === 'b' ? e.div.b : e.div.a); }
  sibling() { const c = this.cursor; if (c && c.parent && c.parent.div) { const d = c.parent.div; this.cursorTo(c.parent.slot === 'a' ? d.b : d.a); } }
  escape() { if (this.#zoomStack.length) this.zoomReset(); else this.#render(); }

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
    if (id !== this.#activeId) return;
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
    c.body.style.paddingTop = h + 'px';
    const sv = c.body.querySelector(':scope > split-view');
    if (sv) sv.style.top = h + 'px';
    this.#padBody = c.body;
  }
  #undisplace() {
    if (!this.#padBody) return;
    this.#padBody.style.paddingTop = '';
    const sv = this.#padBody.querySelector(':scope > split-view');
    if (sv) sv.style.top = '';
    this.#padBody = null;
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
    // a zoom hides everything in its frame that is not in its pane
    for (const z of this.#zoomStack) {
      if (z.frame === pane) continue;                              // a frame is not hidden by the zoom it holds
      const inFrame = this.#within(z.frame, pane);
      if (inFrame && !this.#within(z.pane, pane)) return true;
    }
    let n = pane;
    while (n) {
      // a hoisted pane sits in its frame's body: what lies between the two
      // (divisions, folds, tabs) no longer applies to it; a window zoom ends the walk
      const z = this.#zoomStack.find(z => z.pane === n);
      if (z) { n = z.frame; continue; }
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
  focusMove(dir) {
    const cur = this.cursor;
    if (!cur) return;
    const a = center(cur.dom);
    let best = null, bestD = Infinity;
    this.#eachVisibleLeaf(this.#root, (l) => {
      if (l === cur) return;
      const b = center(l.dom), dx = b.x - a.x, dy = b.y - a.y;
      const ok = dir === 'left' ? dx < -1 && Math.abs(dy) <= Math.abs(dx)
        : dir === 'right' ? dx > 1 && Math.abs(dy) <= Math.abs(dx)
          : dir === 'up' ? dy < -1 && Math.abs(dx) <= Math.abs(dy)
            : dy > 1 && Math.abs(dx) <= Math.abs(dy);
      if (!ok) return;
      const d = dx * dx + dy * dy;
      if (d < bestD) { bestD = d; best = l; }
    });
    if (best) this.focusPane(best.id);
  }

  // ---- zoom: a pane alone inside a frame; zooms stack outer to inner ----

  // z: the cursor fills its frame: the context when one is set and the
  // cursor is inside it, else the window. The same zoom again pops it.
  zoomToggle(pane) {
    pane = pane ?? this.cursor;
    if (!pane || !pane.parent) return;                              // the root already fills the window
    // the nearest context strictly above the cursor; the root is always one
    let frame = this.#root;
    for (let n = this.#ownerOf(pane); n; n = this.#ownerOf(n)) if (this.#contexts.has(n) || n === this.#root) { frame = n; break; }
    const z = { pane, frame };
    const top = this.#zoomStack[this.#zoomStack.length - 1];
    if (top && top.pane === z.pane && top.frame === z.frame) { this.#zoomStack.pop(); this.#afterZoom(z.pane); return; }
    if (this.#hidden(z.pane)) return;                               // not on screen: nothing to zoom
    // one zoom per pane and one per frame; a pane that is itself a FRAME of
    // an inner zoom may still be zoomed outward (the context goes full screen)
    if (this.#zoomStack.some(o => (o.pane === z.pane) || (z.frame && o.frame === z.frame))) return;
    this.#zoomStack.push(z);
    this.#afterZoom(z.pane);
  }
  // C: toggles the cursor as a standing zoom context. Any number of panes
  // may be contexts; z fills the nearest one above the cursor.
  contextToggle() {
    const c = this.cursor; if (!c) return false;
    if (c === this.#root) return true;                              // the root is always a context
    const on = !this.#contexts.has(c);
    if (on) this.#contexts.add(c); else this.#contexts.delete(c);
    this.#renderContext(); this.#persist();
    return on;
  }
  clearContext() { this.#contexts.clear(); this.#renderContext(); }
  #renderContext() {
    for (const p of this.#panes.values()) p.dom.classList.toggle('ps-zoom-ctx', p !== this.#root && this.#contexts.has(p) && !this.#hidden(p));
  }
  // Z: pop the innermost zoom; the cursor stays on what WAS zoomed, not its frame
  zoomOut() { if (this.#zoomStack.length) { const z = this.#zoomStack.pop(); this.#afterZoom(z.pane); } }
  zoomReset() { if (this.#zoomStack.length) { this.#zoomStack = []; this.#afterZoom(this.cursor); } }
  // make a specific pane fill the window (toolbar "full screen this").
  zoomPane(id) {
    const p = this.#panes.get(id ?? this.#activeId);
    if (!p || !p.parent) { this.zoomReset(); return; }   // root already fills
    this.#zoomStack = [{ pane: p, frame: this.#root }]; this.#afterZoom(p);
  }
  // step the window zoom out to the parent of what's currently zoomed (or of this pane).
  zoomParent(id) {
    const top = this.#zoomStack[this.#zoomStack.length - 1];
    const from = (top && top.pane) || this.#panes.get(id ?? this.#activeId);
    const owner = from && this.#ownerOf(from);
    if (owner && owner.parent) { this.#zoomStack = [{ pane: owner, frame: this.#root }]; this.#afterZoom(owner); }
    else this.zoomReset();                                 // parent is the root → show everything
  }
  #afterZoom(focusPane) { this.#applyZoom(); if (focusPane) this.cursorTo(focusPane); this.#emit('ps-zoom', { depth: this.#zoomStack.length }); this.#persist(); }
  // a frame about to rebuild its body cannot keep a pane hoisted in it
  #dropZoomsFramedBy(pane) {
    if (!this.#zoomStack.some(z => z.frame === pane)) return;
    this.#zoomStack = this.#zoomStack.filter(z => z.frame !== pane);
    this.#applyZoom();
  }
  // bring the DOM to the stack: undo hoists no longer wanted (inner first),
  // make the ones missing (outer first). Idempotent; cheap when nothing changed.
  #applyZoom() {
    const scroll = this.#snapshotScroll();   // reparenting a pane zeroes its scrollers — keep them
    const want = this.#zoomStack;
    for (const h of [...this.#hoists].reverse()) if (!want.includes(h.entry)) this.#unhoist(h);
    this.#hoists = this.#hoists.filter(h => want.includes(h.entry));
    for (const z of want) if (!this.#hoists.some(h => h.entry === z)) this.#hoists.push(this.#hoist(z));
    for (const p of this.#panes.values()) p.dom.classList.toggle('ps-zoom-frame', want.some(z => z.frame === p));
    this.#reconnectDivs();
    this.#restoreScroll(scroll);
  }
  #hoist(z) {
    const body = z.frame.body, hid = body.firstChild;                // the frame's division (or nested pane)
    if (hid) hid.style.display = 'none';
    this.#placePane(z.pane, body, null);
    const wall = this.#buildWall(z);
    let pad = null;
    if (wall) { body.appendChild(wall); pad = 'all'; body.style.padding = '16px'; }
    return { entry: z, hid, wall, pad };
  }
  #unhoist(h) {
    const z = h.entry, p = z.pane;
    if (h.wall) h.wall.remove();
    if (h.pad) z.frame.body.style.padding = '';
    if (h.hid) h.hid.style.display = '';
    if (p.parent) { const pp = p.parent; if (pp.div) this.#placePane(p, pp.div.sv, pp.slot === 'a' ? 'start' : 'end'); else this.#placePane(p, pp.host.body, null); }
  }
  // the frame's wall: thick on the side of the frame's own division that X
  // is not in; a click on it unfolds
  // the frame's walls, one on every side; a click on any of them unfolds
  #buildWall(z) {
    const e = this.#curEntry(z.frame); if (!e || !e.div) return null;
    const box = document.createElement('div'); box.className = 'ps-zoom-walls';
    for (const side of ['top', 'bottom', 'left', 'right']) {
      const w = document.createElement('div'); w.className = 'ps-zoom-wall ' + side;
      w.title = 'click, or Z, to unzoom';
      w.addEventListener('click', (ev) => { ev.stopPropagation(); const i = this.#zoomStack.indexOf(z); if (i >= 0) { this.#zoomStack.splice(i, 1); this.#afterZoom(z.pane); } });
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

  serialize() { return this.#serPane(this.#root); }
  #serPane(pane) {
    if (!pane) return null;
    const z = this.#zoomStack.find(z => z.frame === pane);
    return { tabs: pane.tabs.map(t => ({ entries: t.entries.map(e => this.#serEntry(e)), cursor: t.cursor, label: t.label || undefined })), activeTab: pane.activeTab, bar: pane.showBar || undefined, nav: pane.nav === false ? false : undefined, open: pane.open || undefined, view: pane.view || undefined, ctx: this.#contexts.has(pane) || undefined, zoom: z ? (this.#addrWithin(pane, z.pane) || undefined) : undefined };
  }
  #serEntry(e) {
    const name = e.name || undefined;
    if (e.div) return { name, div: { dir: e.div.dir, ratio: e.div.ratio, fold: e.div.fold || undefined, src: e.div.src || undefined, open: e.div.open || undefined, a: this.#serPane(e.div.a), b: this.#serPane(e.div.b) } };
    if (e.pane) return { name, pane: Object.assign(this.#serPane(e.pane), { src: e.src || undefined }) };
    return name ? { path: e.path, name } : { path: e.path };
  }
  restore(spec) {
    if (this.#root) { this.#eachPaneDeep(this.#root, p => this.#forgetPane(p), true); for (const h of this.#hoists) h.entry.pane.dom.remove(); this.#root.dom?.remove(); }
    this.#panes.clear(); this.#zoomStack = []; this.#hoists = []; this.#activeId = null; this.#mark = null; this.#contexts.clear();
    this.#root = spec ? this.#deserPane(spec, null) : this.#makePane();
    this.#placePane(this.#root, this, null);
    this.#afterStructure();
    // zooms are structure too: each frame that saved one gets it back, outer first
    const frames = []; this.#eachPaneDeep(this.#root, (p) => { if (p._zoomAddr) frames.push(p); }, true);
    frames.sort((a, b) => this.#depthOf(a) - this.#depthOf(b));
    for (const f of frames) { const addr = f._zoomAddr; delete f._zoomAddr; const target = this.#descend(f, addr); if (target && target !== f) this.#zoomStack.push({ pane: target, frame: f }); }
    if (this.#zoomStack.length) this.#applyZoom();
    this.cursorTo(firstVisibleLeaf(this.#root, this));
  }
  // build a detached pane subtree from a spec (for openLayout / instantiate)
  instantiate(spec) { return this.#deserPane(spec, null); }
  #buildDiv(spec, hostPane) {
    if (!spec || !spec.div) return null;
    const s = spec.div;
    const sv = document.createElement('split-view');
    sv.setAttribute('orientation', s.dir || 'horizontal'); sv.setAttribute('min', '40');
    const div = { dir: s.dir || 'horizontal', ratio: typeof s.ratio === 'number' ? s.ratio : 0.5, fold: s.fold || null, src: s.src || null, open: (s.open && typeof s.open === 'object') ? s.open : null, a: null, b: null, sv, owner: hostPane || null };
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
    }));
    pane.activeTab = typeof spec.activeTab === 'number' ? spec.activeTab : 0;
    pane.open = (spec.open && typeof spec.open === 'object') ? spec.open : null;   // this pane as a layout root: its routing table
    if (spec.ctx) this.#contexts.add(pane);
    if (typeof spec.zoom === 'string') pane._zoomAddr = spec.zoom;                // rebuilt in restore once the tree stands
    pane.view = spec.view || null;
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
  #persist() { const k = this.#saveKey(); if (!k) return; clearTimeout(this.#saveTimer); this.#saveTimer = setTimeout(() => { try { localStorage.setItem(k, JSON.stringify(this.serialize())); } catch (_) {} }, 150); }

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
  #showsSrc(pane) { const e = this.#curEntry(pane); return !!(pane.view && e && (e.div || e.pane) && this.#entrySrc(e)); }
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
        this.#flashHint('gmux · % split · " stack · c/e collapse/expand · z/Z zoom · C context · x close · t/w tab · T bar · : path · i content · <> tab · ,. back/fwd · R refresh · m mark · ␣ swap · [ ] climb/descend · Tab sibling · h highlight · b bars · 1-9 jump · ←↑↓→ move · ⇧←↑↓→ resize');
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
    else if (k === 'Z') this.zoomOut();
    else if (k === 'C') { const on = this.contextToggle(); this.#flashHint(on ? 'context: z on a pane inside it fills it · C here again clears' : 'context cleared'); }
    else if (k === 'b') { const on = this.toggleBars(); this.#flashHint('pane bars: ' + (on ? 'toggleable on hover' : 'locked')); }
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
    else if (k === 'r') this.#arm('resize');
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
function center(el) { const r = el.getBoundingClientRect(); return { x: r.left + r.width / 2, y: r.top + r.height / 2 }; }
// the first leaf under a pane: through a division's `a` side and through a
// pane moment's nested pane, down to a pane whose moment is a path
function firstVisibleLeaf(pane, ps) {
  const e = pane.tabs[pane.activeTab] && pane.tabs[pane.activeTab].entries[pane.tabs[pane.activeTab].cursor];
  if (e && e.div) return firstVisibleLeaf(e.div.a, ps);
  if (e && e.pane) return firstVisibleLeaf(e.pane, ps);
  return pane;
}

customElements.define('gmux-host', Gmux);
