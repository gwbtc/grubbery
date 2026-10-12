// <pane-split> — a tiling window manager. THE ONLY NOUN IS A PANE.
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
//     z/Z zoom in/out · x close · b lock bars · o cycle · m mark · ␣ swap ·
//     [ ] climb/descend · Tab sibling · Esc reset · h highlight · 1-9 jump ·
//     t new tab · w close tab · T toggle bar · : focus navbar · < > prev/next tab · , . back/forward ·
//     arrows move · shift+arrows / r resize (sticky).
//
// Light DOM; the JS tree is the source of truth and the DOM mirrors it. A
// division nests via a <split-view> living in the owner pane's body; each child
// pane renders its own bar + body, so bars appear at every level.

const STYLE_ID = 'pane-split-style';
const CSS = `
  pane-split { display:block; width:100%; height:100%; min-width:0; min-height:0; position:relative; }
  pane-split split-view { width:100%; height:100%; }
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
  .ps-sel-box { position:absolute; pointer-events:none; z-index:20; display:none; border:3px solid var(--ps-sel,#8250df); box-sizing:border-box; border-radius:3px; }
  .ps-sel-box.on { display:block; }
  .ps-mark-box { position:absolute; pointer-events:none; z-index:19; display:none; border:3px dashed var(--ps-mark,#bf8700); box-sizing:border-box; border-radius:3px; }
  .ps-mark-box.on { display:block; }
  .ps-pane.ps-dim { opacity:.4; transition:opacity .1s; }
  /* uniform per-pane topbar: committed on/off; the hover toggle (bar ▾) flips it;
     a global switch (ps-no-hovertoggle) hides every toggle so bars are locked. */
  .ps-bar { flex:0 0 auto; display:none; flex-direction:column; align-items:stretch; gap:3px; padding:3px 4px; box-sizing:border-box; background:#f6f8fa; border-bottom:1px solid #e2e7ee; font:14px -apple-system,BlinkMacSystemFont,sans-serif; color:#57606a; }
  .ps-pane.ps-bar-on > .ps-bar { display:flex; }
  .ps-bar-row { display:flex; align-items:center; gap:2px; min-width:0; }
  .ps-bar-btn { all:unset; cursor:pointer; padding:2px 6px; border-radius:4px; color:#57606a; font-size:14px; line-height:1.4; }
  .ps-bar-btn:hover { background:#eaeef2; color:#24292f; }
  .ps-bar-btn[disabled] { opacity:.3; cursor:default; }
  .ps-bar-tabs { display:flex; align-items:center; gap:2px; flex:1 1 auto; min-width:0; overflow-x:auto; scrollbar-width:none; }
  .ps-bar-tabs::-webkit-scrollbar { display:none; }
  .ps-tab { all:unset; cursor:pointer; display:inline-flex; align-items:center; gap:4px; padding:3px 8px; border-radius:6px 6px 0 0; font:600 13px ui-monospace,Menlo,monospace; color:#57606a; white-space:nowrap; border:1px solid transparent; }
  .ps-tab:hover { background:#eaeef2; }
  .ps-tab.on { background:#fff; color:#1f2328; border-color:#e2e7ee; }
  .ps-tab-ic { font-weight:400; opacity:.85; }
  .ps-tab-x { opacity:.5; padding:0 2px; border-radius:3px; font-weight:400; }
  .ps-tab-x:hover { opacity:1; background:#d7dde3; }
  .ps-nav { flex:1 1 auto; min-width:40px; display:flex; align-items:center; }
  .ps-nav input { width:100%; box-sizing:border-box; border:1px solid #e2e7ee; background:#fff; border-radius:6px; padding:3px 8px; font:13px ui-monospace,Menlo,monospace; color:#1f2328; outline:none; }
  .ps-nav input:focus { border-color:var(--ps-accent,#0969da); box-shadow:0 0 0 2px rgba(9,105,218,.15); }
  .ps-nav input::placeholder { color:#8b949e; }
  .ps-tnav { flex:0 1 130px; min-width:40px; display:flex; align-items:center; }
  .ps-tnav input { width:100%; box-sizing:border-box; border:1px solid #e2e7ee; background:#fff; border-radius:6px; padding:3px 8px; font:13px ui-monospace,Menlo,monospace; color:#1f2328; outline:none; }
  .ps-tnav input:focus { border-color:var(--ps-accent,#0969da); box-shadow:0 0 0 2px rgba(9,105,218,.15); }
  .ps-tnav input::placeholder { color:#8b949e; }
  pane-split.ps-arming .ps-pane { cursor:crosshair; }
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
  .ps-quickbar { position:absolute; z-index:27; display:none; align-items:center; gap:2px; box-sizing:border-box; padding:3px 6px; background:#f6f8fa; border:1px solid #d0d7de; box-shadow:0 3px 8px rgba(0,0,0,.1); user-select:none; }
  .ps-quickbar.on { display:flex; animation:ps-qb-drop .13s ease-out; }
  @keyframes ps-qb-drop { from { opacity:0; transform:translateY(-6px); } to { opacity:1; transform:none; } }
  .ps-qb-btn { all:unset; cursor:pointer; padding:2px 8px; border-radius:5px; color:#57606a; font:14px -apple-system,BlinkMacSystemFont,sans-serif; line-height:1.4; }
  .ps-qb-btn:hover { background:#eaeef2; color:#24292f; }
  .ps-qb-count { margin-left:auto; padding:0 4px 0 8px; color:#8b949e; font:600 12px ui-monospace,SFMono-Regular,Menlo,monospace; min-width:20px; text-align:right; }
  pane-split.ps-no-hovertoggle .ps-quickbar { display:none !important; }
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

class PaneSplit extends HTMLElement {
  renderPath = null;
  leafFactory = null;
  onDestroy = null;
  onNavigate = null;
  tabInfo = null;      // optional (path) => { icon?:string, label?:string } for the tab chip
  viewModes = null;    // optional [{id, glyph, title}] → a per-pane render-mode toggle on the bar; host's renderPath reads viewOf(id)

  #root = null;                 // the root PANE
  #panes = new Map();           // id -> pane
  #activeId = null;             // the selected/active pane id
  #selLevel = 2;
  #zoomStack = [];              // panes hoisted to viewport (ancestry path)
  #mark = null;                 // a marked pane (for swap)
  #armTarget = null;            // source pane id while picking a target
  #hoisted = null;              // the pane currently hoisted for zoom
  #hoverToggle = true;
  #pillTimer = null;            // interval that counts the quickbar's sticky grace down
  #pillEnd = 0;                 // when the quickbar is due to retract (ms epoch)
  #padBody = null;             // the pane body currently padded down to make room for the quickbar
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
    this.#barToggle.append(
      act('bar ▾', 'materialize the full topbar', () => this.setBar(this.#activeId, true)),
      act('⤓', 'collapse pane', () => this.collapse(this.#activeId)),
      act('⬉', 'select parent container', () => this.selectParent(this.#activeId)),
      act('⛶', 'zoom to this pane', () => this.zoomPane(this.#activeId)),
      act('↑', 'zoom to parent', () => this.zoomParent(this.#activeId)),
      act('⤢', 'zoom all the way out', () => this.zoomReset()),
      act('×', 'close pane', () => this.closeLeaf(this.#activeId)));
    const count = document.createElement('span'); count.className = 'ps-qb-count';   // sticky countdown, right-aligned
    this.#barToggle.append(count); this.#barToggle._count = count;
    this.#barToggle.addEventListener('mouseenter', () => this.#holdPill());         // interacting → keep it open
    this.#barToggle.addEventListener('mouseleave', () => this.#schedulePillHide(5000));
    this.#histMenu = this.#chrome('ps-histmenu');
    this.addEventListener('keydown', this.#onKey);
    window.addEventListener('keydown', this.#onKeyGlobal, true);     // armed-swap: bare Space anywhere
    this.addEventListener('mousedown', this.#onPickTarget, true);   // capture: pick a target before normal select
    this.addEventListener('mousedown', (e) => { if (this.#histMenu && this.#histMenu.classList.contains('on') && !this.#histMenu.contains(e.target) && !(e.target.closest && e.target.closest('.ps-histcaret'))) this.#closeHistMenu(); }, true);
    this.addEventListener('sv-resize', this.#onSvResize);
    this.addEventListener('sv-collapse', this.#onSvCollapse);
    window.addEventListener('resize', this.#reposition);
    let restored = false;
    const k = this.#saveKey();
    if (k) { try { const s = JSON.parse(localStorage.getItem(k) || 'null'); if (s) { this.restore(s); restored = true; } } catch (_) {} }
    if (!restored && !this.#root) this.seed();
    this.focus({ preventScroll: true });
  }

  disconnectedCallback() {
    this.removeEventListener('keydown', this.#onKey);
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
    const pane = { kind: 'pane', id, dom, body, bar, tabs: [{ entries: [], cursor: -1 }], activeTab: 0, parent: null, showBar: false, openTo: null, view: null };
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
    row1.append(btn('▴', 'hide bar', () => this.setBar(id, false)), tabs, add, viewBtn,
      btn('◨', 'split right', () => this.splitRight(id)), btn('⬓', 'split down', () => this.splitDown(id)),
      btn('⤓', 'collapse pane', () => this.collapse(id)),
      btn('⬉', 'select parent container', () => this.selectParent(id)),
      btn('⛶', 'zoom to this pane', () => this.zoomPane(id)), btn('↑', 'zoom to parent', () => this.zoomParent(id)), btn('⤢', 'zoom all the way out', () => this.zoomReset()),
      btn('×', 'close pane', () => this.closeLeaf(id)));
    // row 2 — history + navbar
    const row2 = document.createElement('div'); row2.className = 'ps-bar-row';
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
    // target control: pick a destination pane (or type the relative address),
    // and toggle how links land there (replace current tab / new tab).
    const tpick = btn('⇒', 'set target — click the pane links should open into', () => this.armTargetPick(id));
    const tnav = document.createElement('div'); tnav.className = 'ps-tnav';
    const tin = document.createElement('input');
    tin.type = 'text'; tin.spellcheck = false; tin.placeholder = '→ target';
    tin.addEventListener('mousedown', (e) => e.stopPropagation());
    tin.addEventListener('keydown', (e) => {
      e.stopPropagation();
      if (e.key === 'Enter') { this.setTargetTo(id, tin.value); tin.blur(); }
      else if (e.key === 'Escape') { tin.blur(); this.#renderBar(this.#panes.get(id)); }
    });
    tnav.appendChild(tin);
    const tmode = btn('', 'open mode — click to toggle replace / new tab', () => this.toggleTargetMode(id));
    row2.append(back, fwd, nav, tpick, tnav, tmode);
    bar.append(row1, row2);
    bar._back = back; bar._fwd = fwd; bar._tabs = tabs; bar._nav = input; bar._view = viewBtn; bar._tin = tin; bar._tmode = tmode;
    return bar;
  }

  #renderBar(pane) {
    const bar = pane.bar;
    bar._tabs.textContent = '';
    pane.tabs.forEach((tab, i) => {
      const b = document.createElement('button');
      b.className = 'ps-tab' + (i === pane.activeTab ? ' on' : '');
      b.title = this.#tabTitle(tab);
      const m = this.#tabMeta(tab);
      if (m.icon) { const ic = document.createElement('span'); ic.className = 'ps-tab-ic'; ic.textContent = m.icon; b.appendChild(ic); }
      b.appendChild(document.createTextNode(m.label));
      b.addEventListener('click', (e) => { e.stopPropagation(); this.selectTab(pane.id, i); });
      const x = document.createElement('span'); x.className = 'ps-tab-x'; x.textContent = '×';
      x.addEventListener('click', (e) => { e.stopPropagation(); this.closeTab(pane.id, i); });
      b.appendChild(x);
      bar._tabs.appendChild(b);
    });
    const e = this.#curEntry(pane);
    bar._back.disabled = !this.#canBack(pane);
    bar._fwd.disabled = !this.#canFwd(pane);
    const navVal = e ? (e.div ? (e.div.src || '') : (e.path != null ? e.path : '')) : '';
    if (bar._nav !== document.activeElement) bar._nav.value = navVal;
    bar._nav.placeholder = (e && e.div) ? (e.div.src || 'layout') : 'path…';
    // target control: the relative address + how links land there
    if (bar._tin !== document.activeElement) bar._tin.value = pane.openTo ? pane.openTo.to : '';
    bar._tmode.textContent = (pane.openTo && pane.openTo.mode === 'tab') ? '⊕' : '⇄';
    bar._tmode.style.visibility = pane.openTo ? '' : 'hidden';
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
    if (e.div) return { icon: '▣', label: e.div.src ? base(e.div.src) : 'layout' };
    if (this.tabInfo) { try { const m = this.tabInfo(e.path); if (m) return { icon: m.icon || '', label: m.label || base(e.path) || 'empty' }; } catch (_) {} }
    return { icon: '', label: base(e.path) || 'empty' };
  }
  #tabMeta(tab) { return this.#entryMeta(tab.entries[tab.cursor]); }
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
  #tabTitle(tab) { const e = tab.entries[tab.cursor]; if (!e) return 'empty tab'; return e.div ? (e.div.src || 'layout') : (e.path || ''); }

  // re-render every pane's bar (e.g. after the host learns a path's name/icon)
  redrawBars() { for (const p of this.#panes.values()) this.#renderBar(p); }

  #curEntry(pane) { const t = pane.tabs[pane.activeTab]; return t ? t.entries[t.cursor] || null : null; }
  #curPath(id) { const p = this.#panes.get(id); const e = p && this.#curEntry(p); return e && e.path != null ? e.path : null; }
  #canBack(pane) { const t = pane.tabs[pane.activeTab]; return !!t && t.cursor > 0; }
  #canFwd(pane) { const t = pane.tabs[pane.activeTab]; return !!t && t.cursor >= 0 && t.cursor < t.entries.length - 1; }

  // render a pane's body from its active tab's current entry. A leaf entry is
  // re-instantiated from its path (we keep paths, never live views). A division
  // entry mounts its (persistent) split-view; its children render themselves.
  #renderPane(pane) {
    const prev = pane.body.firstChild;
    const entry = this.#curEntry(pane);
    // detach old body without destroying a division's child panes
    if (prev) {
      if (prev.tagName === 'SPLIT-VIEW') prev.remove();
      else { try { if (this.onDestroy) this.onDestroy(pane.id, pane.body); } catch (_) {} pane.body.textContent = ''; }
    }
    if (entry && entry.div && pane.view && entry.div.src) {
      // a non-default view (e.g. raw) on a layout: show its SOURCE via renderPath,
      // keeping the live division intact underneath — flip back and it returns.
      const el = this.renderPath ? this.renderPath(entry.div.src, pane.id) : document.createTextNode(entry.div.src);
      if (el) pane.body.appendChild(el);
    } else if (entry && entry.div) {
      const div = entry.div;
      this.#placePane(div.a, div.sv, 'start');
      this.#placePane(div.b, div.sv, 'end');
      pane.body.appendChild(div.sv);
      this.#applyDivLayout(div);
    } else if (entry && entry.path != null) {
      const el = this.renderPath ? this.renderPath(entry.path, pane.id) : document.createTextNode(entry.path);
      if (el) pane.body.appendChild(el);
    } else {
      const el = this.leafFactory ? this.leafFactory(pane.id) : this.#empty();
      if (el) pane.body.appendChild(el);
    }
    this.#renderBar(pane);
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
  navigate(id, path) { this.#pushEntry(id ?? this.#activeId, { path }); }
  // push a division entry built from a layout spec. History stays — back/forward
  // steps in and out of it. `spec` is a serialized division (see serialize()).
  openLayout(id, spec) {
    const pid = id ?? this.#activeId;
    const div = this.#buildDiv(spec, this.#panes.get(pid));
    if (div) this.#pushEntry(pid, { div });
  }
  // REPLACE the active entry with a layout (for navigating TO a .layout path: the
  // entry you landed on BECOMES the layout, so back returns to where you were).
  replaceWithLayout(id, spec, src) {
    const pane = this.#panes.get(id ?? this.#activeId);
    if (!pane) return;
    const div = this.#buildDiv(spec, pane);
    if (!div) return;
    if (src) div.src = src;
    const tab = pane.tabs[pane.activeTab];
    if (tab.cursor < 0) { tab.entries = [{ div }]; tab.cursor = 0; }
    else tab.entries[tab.cursor] = { div };
    this.#renderPane(pane); this.#afterStructure(); this.#persist();
  }
  // where a pane's navigations go: openTo = { to, mode }. `to` is a RELATIVE
  // structural address from the SOURCE pane — '..' climbs to the owner, 'a'/'b'
  // descend through active divisions (like a filesystem path: '../b', '../../a/b').
  // `mode` is 'tab' (new tab in the target) or 'replace' (in place, default).
  // Resolved on demand against the CURRENT structure; the host decides WHEN to
  // use it (e.g. files, not dirs).
  #targetPane(source) {
    const spec = source && source.openTo;
    if (!spec || !spec.to) return null;
    const parts = String(spec.to).split('/').filter((s) => s.length && s !== '.');
    let n = source, i = 0;
    while (i < parts.length && parts[i] === '..') { n = this.#ownerOf(n); if (!n) return null; i++; }
    for (; i < parts.length; i++) {
      const slot = parts[i]; if (slot !== 'a' && slot !== 'b') return null;
      const div = this.#curEntry(n)?.div; if (!div) return null;
      n = div[slot]; if (!n) return null;
    }
    return n !== source ? n : null;
  }
  targetId(id) { const t = this.#targetPane(this.#panes.get(id ?? this.#activeId)); return t && this.#panes.has(t.id) ? t.id : null; }
  targetMode(id) { const p = this.#panes.get(id ?? this.#activeId); return (p && p.openTo && p.openTo.mode) || 'replace'; }
  // ---- editing a target ----
  // the relative address from source to target (inverse of #targetPane): climb
  // source to their common ancestor, then descend to target.
  #addrOf(source, target) {
    if (!source || !target || source === target) return null;
    const anc = new Set(); for (let t = target; t; t = this.#ownerOf(t)) anc.add(t);
    let a = source, ups = 0;
    while (a && !anc.has(a)) { a = this.#ownerOf(a); ups++; }
    if (!a) return null;
    const slots = []; for (let t = target; t && t !== a; t = this.#ownerOf(t)) slots.unshift(t.parent.slot);
    return '../'.repeat(ups) + slots.join('/');
  }
  // arm "set target": the next pane click becomes this pane's target.
  armTargetPick(id) { this.#armTarget = id ?? this.#activeId; this.classList.add('ps-arming'); this.#flashHint('set target: click the pane links should open into (Esc to cancel)'); }
  #cancelTargetPick() { if (this.#armTarget == null) return; this.#armTarget = null; this.classList.remove('ps-arming'); this.#flashHint(''); }
  setTargetTo(id, addr) {
    const p = this.#panes.get(id ?? this.#activeId); if (!p) return;
    addr = (addr || '').trim();
    p.openTo = addr ? { to: addr, mode: (p.openTo && p.openTo.mode) || 'replace' } : null;
    this.#renderBar(p); this.#render(); this.#persist();
  }
  toggleTargetMode(id) { const p = this.#panes.get(id ?? this.#activeId); if (!p || !p.openTo) return; p.openTo.mode = p.openTo.mode === 'tab' ? 'replace' : 'tab'; this.#renderBar(p); this.#persist(); }
  #onPickTarget = (e) => {
    if (this.#armTarget == null) return;
    const el = e.target && e.target.closest && e.target.closest('.ps-pane');
    const id = el && el.dataset.paneId;
    e.preventDefault(); e.stopPropagation();
    const src = this.#armTarget; this.#cancelTargetPick();
    if (id && src !== id) this.setTargetTo(src, this.#addrOf(this.#panes.get(src), this.#panes.get(id)));
  };
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
  newTab(id, path) {
    const p = this.#panes.get(id ?? this.#activeId); if (!p) return;
    p.tabs.push({ entries: path != null ? [{ path }] : [], cursor: path != null ? 0 : -1 });
    p.activeTab = p.tabs.length - 1;
    this.#renderPane(p); this.#afterStructure(); this.#persist();
  }
  selectTab(id, i) { const p = this.#panes.get(id ?? this.#activeId); if (!p || i < 0 || i >= p.tabs.length) return; p.activeTab = i; this.#renderPane(p); this.#reconcileCursor(); this.#afterStructure(); this.#persist(); }
  closeTab(id, i) {
    const p = this.#panes.get(id ?? this.#activeId); if (!p || i < 0 || i >= p.tabs.length) return;
    const [tab] = p.tabs.splice(i, 1);
    this.#eachEntryPane(tab, cp => this.#forgetPane(cp));
    if (!p.tabs.length) p.tabs.push({ entries: [], cursor: -1 });
    if (p.activeTab >= p.tabs.length) p.activeTab = p.tabs.length - 1;
    this.#renderPane(p); this.#reconcileCursor(); this.#afterStructure(); this.#persist();
  }

  // ---- topbar visibility ----

  setBar(id, on) { const p = this.#panes.get(id); if (!p) return; p.showBar = (on == null) ? !p.showBar : !!on; p.dom.classList.toggle('ps-bar-on', p.showBar); if (p.showBar) this.#hidePill(); this.#positionBarToggle(); this.#persist(); }
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
    if (liveBody && curEntry && !curEntry.div) { pane.body.removeChild(liveBody); childA.body.textContent = ''; childA.body.appendChild(liveBody); this.#renderBar(childA); }
    else this.#renderPane(childA);
    // the parent tab loses its history to childA; it now holds the division.
    tab.entries = [{ div }]; tab.cursor = 0;
    this.#renderPane(pane);                     // pane.body is now empty → mounts the division
    if (savedZoom.length) { this.#zoomStack = savedZoom.map(z => z === pane ? pane : z); this.#applyZoom(); }
    this.#afterStructure();
    this.#restoreScroll(scroll);
    this.focusPane(childB.id);
    this.#emit('ps-split', { id, dir: orientation, newId: childB.id });
    this.#persist();
    return childB.id;
  }

  // ---- closing: the surviving sibling's active history comes back UP ----

  // close a pane. If it lives in a division, its sibling is promoted into the
  // owner pane's active tab (history returns to the parent). If it's the owner's
  // whole content, close removes the whole pane from ITS parent division.
  close(pane) {
    pane = pane ?? this.cursor;
    if (!pane) return;
    if (this.#zoomStack.length) this.zoomReset();
    const par = pane.parent;
    if (!par) {
      // root pane — clear the active tab's content entirely
      const tab = pane.tabs[pane.activeTab];
      if (this.#curEntry(pane)) { this.#eachEntryPane({ entries: tab.entries, cursor: tab.cursor }, cp => { if (cp !== pane) this.#forgetPane(cp); }); }
      tab.entries = []; tab.cursor = -1;
      this.#renderPane(pane); this.#reconcileCursor(); this.#afterStructure(); this.#persist();
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
    if (sibLive && sibEntry && !sibEntry.div) { sib.body.removeChild(sibLive); owner.body.textContent = ''; owner.body.appendChild(sibLive); this.#renderBar(owner); }
    else this.#renderPane(owner);
    this.#forgetPane(sib);
    this.#afterStructure();
    this.#restoreScroll(scroll);
    this.cursorTo(owner);
    this.#emit('ps-close', {}); this.#persist();
  }
  closeLeaf(id) { const p = this.#panes.get(id); if (p) this.close(p); }
  #forgetPane(pane) { if (!pane) return; try { if (this.onDestroy) this.onDestroy(pane.id, pane.body); } catch (_) {} this.#panes.delete(pane.id); pane.dom.remove(); }
  // after moving an entry into a new owner, fix the division's owner backref.
  #reparentDiv(entry, owner) { if (entry && entry.div) entry.div.owner = owner; }

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
  #afterStructure() { this.#reconnectDivs(); this.#reposition(); }
  // walk the visible tree, (re)binding each division's owner + child parents, so
  // backrefs stay correct after history/tab moves, and lay out split-views.
  #reconnectDivs() {
    const walk = (pane) => {
      const e = this.#curEntry(pane);
      if (e && e.div) {
        const div = e.div;
        div.owner = pane;
        div.a.parent = { div, slot: 'a' }; div.b.parent = { div, slot: 'b' };
        this.#applyDivLayout(div);
        walk(div.a); walk(div.b);
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
    if (pane.id !== this.#activeId) this.#hidePill();   // pill belongs to the pane you hovered; re-hover the new one
    this.#activeId = pane.id;
    // record a descend breadcrumb up the ownership chain
    let n = pane, owner = this.#ownerOf(pane);
    while (owner) { this.#curEntry(owner).div.last = n.parent.slot; n = owner; owner = this.#ownerOf(owner); }
    this.#render();
    this.#emit('ps-focus', { id: pane.id, kind: this.#curEntry(pane)?.div ? 'split' : 'leaf' });
  }
  focusPane(id) { const p = this.#panes.get(id); if (p) this.cursorTo(p); }
  #ownerOf(pane) { return pane && pane.parent ? pane.parent.div.owner : null; }
  climb() { const o = this.#ownerOf(this.cursor); if (o) this.cursorTo(o); }
  // select the parent container (the division that owns this pane) and show the
  // purple container box around it.
  selectParent(id) { const p = id != null ? this.#panes.get(id) : this.cursor; const o = this.#ownerOf(p); if (!o) return; if (this.#selLevel < 2) this.#selLevel = 2; this.cursorTo(o); }
  descend() { const e = this.#curEntry(this.cursor); if (e && e.div) this.cursorTo(e.div.last === 'b' ? e.div.b : e.div.a); }
  sibling() { const c = this.cursor; if (c && c.parent) { const d = c.parent.div; this.cursorTo(c.parent.slot === 'a' ? d.b : d.a); } }
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
    this.#positionBarToggle();
  };
  // keep a showing quickbar anchored to the selected pane across scroll/resize;
  // hide it if that pane went away, got hidden, or locked its bar on.
  #positionBarToggle() {
    const t = this.#barToggle; if (!t || !t.classList.contains('on')) return;
    const c = this.cursor;
    if (!c || c.showBar || this.#hidden(c)) { this.#hidePill(); return; }
    this.#placeToggle(c);
  }
  // ---- sticky quickbar (thin host-level drop-down on top-edge hover of the selected pane) ----
  #onTopHover(e, id) {
    if (id !== this.#activeId || !this.#hoverToggle) return;
    const p = this.#panes.get(id); if (!p || p.showBar || this.#hidden(p)) return;
    const r = p.dom.getBoundingClientRect();
    if (e.clientY - r.top <= 24) this.#showPill();                 // near the top → drop it + refresh grace
  }
  #placeToggle(c) {
    const t = this.#barToggle, cr = this.getBoundingClientRect(), r = c.dom.getBoundingClientRect(), m = 3;
    t.style.left = (r.left - cr.left + m) + 'px';                   // inset so the selection frame stays visible
    t.style.top = (r.top - cr.top + m) + 'px';
    t.style.width = (r.width - m * 2) + 'px';
  }
  #showPill() {
    const t = this.#barToggle, c = this.cursor;
    if (!t || !this.#hoverToggle || !c || c.showBar || this.#hidden(c)) return;
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
  #hidePill() { if (this.#barToggle) this.#barToggle.classList.remove('on'); this.#undisplace(); this.#holdPill(); }
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
    const top = this.#zoomStack[this.#zoomStack.length - 1];
    if (top && !this.#within(top, pane)) return true;
    let n = pane;
    while (n && n !== top) {
      const par = n.parent; if (!par) break;
      const owner = par.div.owner;
      if (this.#curEntry(owner)?.div !== par.div) return true;   // owner looking elsewhere
      if (this.#showsSrc(owner)) return true;                    // owner showing its layout's source (raw), not the division
      if (par.div.fold === par.slot) return true;                // folded away
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

  // ---- zoom (viewport stack of panes) ----

  zoomToggle(pane) {
    pane = pane ?? this.cursor;
    if (!pane) return;
    const top = this.#zoomStack[this.#zoomStack.length - 1];
    if (pane === top) this.#zoomStack.pop();
    else { if (!pane.parent) return; if (top && !this.#within(top, pane)) return; this.#zoomStack.push(pane); }
    this.#afterZoom(pane);
  }
  zoomOut() { if (this.#zoomStack.length) { this.#zoomStack.pop(); this.#afterZoom(this.#zoomStack[this.#zoomStack.length - 1] ?? this.cursor); } }
  zoomReset() { if (this.#zoomStack.length) { this.#zoomStack = []; this.#afterZoom(this.cursor); } }
  // make a specific pane fill the viewport (toolbar "full screen this").
  zoomPane(id) {
    const p = this.#panes.get(id ?? this.#activeId);
    if (!p || !p.parent) { this.zoomReset(); return; }   // root already fills
    this.#zoomStack = [p]; this.#afterZoom(p);
  }
  // step the zoom out to the parent of what's currently zoomed (or of this pane).
  zoomParent(id) {
    const top = this.#zoomStack[this.#zoomStack.length - 1];
    const from = top || this.#panes.get(id ?? this.#activeId);
    const owner = from && this.#ownerOf(from);
    if (owner && owner.parent) { this.#zoomStack = [owner]; this.#afterZoom(owner); }
    else this.zoomReset();                                 // parent is the root → show everything
  }
  #afterZoom(focusPane) { this.#applyZoom(); if (focusPane) this.cursorTo(focusPane); this.#emit('ps-zoom', { depth: this.#zoomStack.length }); }
  #applyZoom() {
    const scroll = this.#snapshotScroll();   // reparenting a pane zeroes its scrollers — keep them
    const top = this.#zoomStack[this.#zoomStack.length - 1] || null;
    if (this.#hoisted && this.#hoisted !== top) {
      const hn = this.#hoisted;
      if (hn.parent) this.#placePane(hn, hn.parent.div.sv, hn.parent.slot === 'a' ? 'start' : 'end');
      this.#hoisted = null;
    }
    if (top) {
      if (this.#hoisted !== top) { this.#placePane(top, this, null); this.#hoisted = top; }
      if (this.#root) this.#root.dom.style.display = (top === this.#root) ? '' : 'none';
      this.classList.add('ps-zoomed');
    } else {
      if (this.#root) this.#root.dom.style.display = '';
      this.classList.remove('ps-zoomed');
    }
    this.#reconnectDivs();
    this.#restoreScroll(scroll);
  }
  // snapshot/restore scroll offsets across a DOM reparent (scrollTop zeroes on move)
  #snapshotScroll() { const m = []; this.querySelectorAll('*').forEach((el) => { if (el.scrollTop || el.scrollLeft) m.push([el, el.scrollTop, el.scrollLeft]); }); return m; }
  #restoreScroll(m) { for (const [el, t, l] of m) { if (t) el.scrollTop = t; if (l) el.scrollLeft = l; } }

  // ---- collapse / resize (nearest ancestor division) ----

  // collapse: fold the given (or SELECTED) pane's slot → its sibling fills (toggle).
  collapse(id) {
    const pane = id != null ? this.#panes.get(id) : this.cursor, par = pane && pane.parent;
    if (!par) return;
    par.div.fold = (par.div.fold === par.slot) ? null : par.slot;
    this.#applyDivLayout(par.div); this.#render(); this.#persist();
  }
  // expand: fold the COUNTERPART's slot → the selected pane fills (toggle).
  expand() {
    const pane = this.cursor, par = pane && pane.parent;
    if (!par) return;
    const other = par.slot === 'a' ? 'b' : 'a';
    par.div.fold = (par.div.fold === other) ? null : other;
    this.#applyDivLayout(par.div); this.#render(); this.#persist();
  }
  nudge(dir) {
    const start = this.cursor;
    if (!start) return;
    const axis = (dir === 'left' || dir === 'right') ? 'horizontal' : 'vertical';
    let node = start, par = start.parent;
    while (par && par.div.dir !== axis) { node = par.div.owner; par = node.parent; }
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
    if (!p) return;
    const div = p.div, scroll = this.#snapshotScroll();
    [div.a, div.b] = [div.b, div.a];
    this.#placePane(div.a, div.sv, 'start'); this.#placePane(div.b, div.sv, 'end');   // move the DOM to match
    this.#afterStructure(); this.#restoreScroll(scroll); this.#render(); this.#persist();
  }
  #swapPanes(n1, n2) {
    if (n1 === n2 || !n1.parent || !n2.parent) return false;
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
    return { tabs: pane.tabs.map(t => ({ entries: t.entries.map(e => this.#serEntry(e)), cursor: t.cursor })), activeTab: pane.activeTab, bar: pane.showBar || undefined, openTo: pane.openTo || undefined, view: pane.view || undefined };
  }
  #serEntry(e) {
    if (e.div) return { div: { dir: e.div.dir, ratio: e.div.ratio, fold: e.div.fold || undefined, src: e.div.src || undefined, a: this.#serPane(e.div.a), b: this.#serPane(e.div.b) } };
    return { path: e.path };
  }
  restore(spec) {
    if (this.#root) { this.#eachPaneDeep(this.#root, p => this.#forgetPane(p), true); if (this.#hoisted) this.#hoisted.dom.remove(); this.#root.dom?.remove(); }
    this.#panes.clear(); this.#zoomStack = []; this.#hoisted = null; this.#activeId = null; this.#mark = null;
    this.classList.remove('ps-zoomed');
    this.#root = spec ? this.#deserPane(spec, null) : this.#makePane();
    this.#placePane(this.#root, this, null);
    this.#afterStructure();
    this.cursorTo(firstVisibleLeaf(this.#root, this));
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
    div.a = this.#deserPane(s.a, { div, slot: 'a' });
    div.b = this.#deserPane(s.b, { div, slot: 'b' });
    return div;
  }
  #deserPane(spec, parent) {
    const pane = this.#makePane();
    pane.parent = parent;
    if (!spec) return pane;
    pane.tabs = (spec.tabs || [{ entries: [], cursor: -1 }]).map(t => ({
      entries: (t.entries || []).map(e => e.div ? { div: this.#buildDiv(e, pane) } : { path: e.path }),
      cursor: typeof t.cursor === 'number' ? t.cursor : (t.entries && t.entries.length ? 0 : -1),
    }));
    pane.activeTab = typeof spec.activeTab === 'number' ? spec.activeTab : 0;
    pane.openTo = spec.openTo || null;
    pane.view = spec.view || null;
    // bind division owners for every entry (not just the active one)
    pane.tabs.forEach(t => t.entries.forEach(e => { if (e.div) e.div.owner = pane; }));
    if (spec.bar) { pane.showBar = true; pane.dom.classList.add('ps-bar-on'); }
    this.#renderPane(pane);
    return pane;
  }
  #saveKey() { const a = this.getAttribute('persist'); return a ? 'pane-split:' + a : null; }
  #persist() { const k = this.#saveKey(); if (!k) return; clearTimeout(this.#saveTimer); this.#saveTimer = setTimeout(() => { try { localStorage.setItem(k, JSON.stringify(this.serialize())); } catch (_) {} }, 150); }

  // ---- traversal helpers ----

  // every pane in the tree (all tabs/entries), optionally skipping the root itself
  #eachPaneDeep(pane, fn, includeSelf) {
    if (!pane) return;
    pane.tabs.forEach(t => t.entries.forEach(e => { if (e.div) { this.#eachPaneDeep(e.div.a, fn, true); this.#eachPaneDeep(e.div.b, fn, true); } }));
    if (includeSelf) fn(pane);
  }
  // every pane reachable through one tab's entries (its division children)
  #eachEntryPane(tab, fn) { tab.entries.forEach(e => { if (e.div) { this.#eachPaneDeep(e.div.a, fn, true); this.#eachPaneDeep(e.div.b, fn, true); } }); }
  // visible leaves: follow the active entry; a pane showing a division recurses,
  // one showing a path/empty is a leaf.
  // a pane "divides" only when its active entry is a div AND it's not showing that
  // layout's source (raw view) — a raw layout pane is a leaf (it shows a file).
  // a pane is showing its layout's SOURCE (raw) instead of the live division —
  // only when a non-default view is set AND there's a src to show. A src-less
  // inner split in raw view keeps dividing; raw there has nothing to swap in.
  #showsSrc(pane) { const e = this.#curEntry(pane); return !!(pane.view && e && e.div && e.div.src); }
  #divides(pane) { const e = this.#curEntry(pane); return !!(e && e.div) && !this.#showsSrc(pane); }
  #isVisibleLeaf(pane) { return this.#panes.has(pane.id) && !this.#divides(pane) && !this.#hidden(pane); }
  #eachVisibleLeaf(pane, fn) {
    if (!pane) return;
    if (this.#divides(pane)) { const d = this.#curEntry(pane).div; this.#eachVisibleLeaf(d.a, fn); this.#eachVisibleLeaf(d.b, fn); }
    else if (!this.#hidden(pane)) fn(pane);
  }

  // ---- keys ----

  get #prefix() {
    const raw = (this.getAttribute('prefix') || 'ctrl+b').toLowerCase().split('+');
    return { key: raw.pop(), ctrl: raw.includes('ctrl'), meta: raw.includes('meta') || raw.includes('cmd'), alt: raw.includes('alt') };
  }
  // a set mark ARMS a swap: bare Space completes it from anywhere on the page
  // (no prefix, even mid-move), as long as you're not typing in a field. Lives
  // at window level so it fires regardless of which element holds focus.
  #onKeyGlobal = (e) => {
    if (!this.#mark || e.key !== ' ' || e.ctrlKey || e.metaKey || e.altKey) return;
    if (isEditable(e.target) || isEditable(document.activeElement)) return;
    this.#endRepeat(); this.swap(); e.preventDefault(); e.stopPropagation();
  };
  #onKey = (e) => {
    if (this.#armTarget != null && e.key === 'Escape') { this.#cancelTargetPick(); e.preventDefault(); e.stopPropagation(); return; }
    if (this.#histMenu && this.#histMenu.classList.contains('on') && e.key === 'Escape') { this.#closeHistMenu(); e.preventDefault(); e.stopPropagation(); return; }
    if (this.#repeat && !this.#awaiting) {
      if (MODS[e.key]) return;
      const d = DIR[e.key];
      if (d) { if (this.#repeat === 'resize' || e.shiftKey) this.nudge(d); else this.focusMove(d); this.#arm(this.#repeat); e.preventDefault(); e.stopPropagation(); return; }
      this.#endRepeat();
      if (e.key === 'Escape') { e.preventDefault(); return; }
    }
    if (!this.#awaiting) {
      const p = this.#prefix;
      if (e.key.toLowerCase() === p.key && e.ctrlKey === p.ctrl && e.metaKey === p.meta && e.altKey === p.alt) {
        this.#awaiting = true;
        this.#flashHint('% split · " stack · c/e collapse/expand · z/Z zoom · x close · t/w tab · T bar · : path · <> tab · ,. hist · m mark · ␣ swap · [ ] climb/descend · Tab sibling · h highlight · b bars · 1-9 jump · ←↑↓→ move · ⇧←↑↓→ resize');
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
    else if (k === 'z') this.zoomToggle();
    else if (k === 'Z') this.zoomOut();
    else if (k === 'b') { const on = this.toggleBars(); this.#flashHint('pane bars: ' + (on ? 'toggleable on hover' : 'locked')); }
    else if (k === 'c') this.collapse();
    else if (k === 'e' || k === 'E') this.expand();
    else if (k === 'h') { const lv = this.cycleHighlight(); this.#flashHint('highlight: ' + ['none', 'active only', 'full'][lv]); }
    else if (k === 'o') this.focusNext();
    else if (k === ' ') this.swap();
    else if (k === 'm') { const on = this.markToggle(); this.#flashHint(on ? 'marked — move the cursor, then space to swap' : 'mark cleared'); }
    else if (k === 't') this.newTab(this.#activeId, this.#curPath(this.#activeId));
    else if (k === 'T') this.setBar(this.#activeId);   // toggle the selected pane's bar
    else if (k === ':') this.focusNav(this.#activeId); // jump to the navbar to type a path
    else if (k === 'w') this.closeTab(this.#activeId, this.cursor ? this.cursor.activeTab : -1);
    else if (k === '<' || k === ',') { if (k === '<') this.#cycleTab(-1); else this.back(); }
    else if (k === '>' || k === '.') { if (k === '>') this.#cycleTab(1); else this.forward(); }
    else if (k === '[') this.climb();
    else if (k === ']') this.descend();
    else if (k === 'Tab') this.sibling();
    else if (k === 'Escape') this.escape();
    else if (k >= '1' && k <= '9') this.focusIndex(+k - 1);
    else if (k === 'r') this.#arm('resize');
    else if (dir && e.shiftKey) { this.nudge(dir); this.#arm('resize'); }
    else if (dir) { this.focusMove(dir); this.#arm('move'); }
    else handled = false;
    if (handled) { e.preventDefault(); e.stopPropagation(); }
  };
  #cycleTab(delta) { const p = this.cursor; if (!p || p.tabs.length < 2) return; this.selectTab(p.id, (p.activeTab + delta + p.tabs.length) % p.tabs.length); }
  #arm(kind) { this.#repeat = kind; this.#flashHint((kind === 'resize' ? 'resize' : 'move') + ': ←↑↓→  (any other key or Esc to exit)'); }
  #endRepeat() { this.#repeat = null; this.#flashHint(''); }
  #flashHint(msg) { if (!this.#hint) return; this.#hint.textContent = msg; this.#hint.classList.toggle('on', !!msg); }
  #emit(name, detail) { this.dispatchEvent(new CustomEvent(name, { detail, bubbles: true, composed: true })); }
}

function isEditable(el) { if (!el) return false; const t = el.tagName; return t === 'INPUT' || t === 'TEXTAREA' || t === 'SELECT' || !!el.isContentEditable; }
function center(el) { const r = el.getBoundingClientRect(); return { x: r.left + r.width / 2, y: r.top + r.height / 2 }; }
function firstVisibleLeaf(pane, ps) {
  const e = pane.tabs[pane.activeTab] && pane.tabs[pane.activeTab].entries[pane.tabs[pane.activeTab].cursor];
  if (e && e.div) return firstVisibleLeaf(e.div.a, ps);
  return pane;
}

customElements.define('pane-split', PaneSplit);
