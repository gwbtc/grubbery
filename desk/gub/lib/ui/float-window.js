// <float-window> — a draggable, resizable, stackable desktop-style window.
//
// The same machinery as split-view's drag handle, generalized: pointer
// capture on pointerdown, delta math on pointermove, write left/top/
// width/height back to the host style, persist on pointerup. Eight grip
// strips around the frame handle resizing; the titlebar handles moving;
// the page-global manager in window-manager.js (window.floatwm) handles
// stacking, snap geometry, and the drag shield — this file is only the
// widget, and requires window-manager.js loaded before it.
//
// CONTRACT
//   attributes (config in):
//     title        titlebar text
//     icon         optional single glyph/emoji shown before the title
//     x, y         initial position; px or % of viewport ("120px", "60%")
//     width,height initial size in px (default 320x240)
//     min-width    px, default 200
//     min-height   px, default 120
//     persist      localStorage key; geometry + shaded/minimized/closed
//                  survive reload
//     closed       boolean; window hidden and absent from desk-bars. A
//                  persisted window closes into this state (the element
//                  STAYS in the DOM so page scripts keep their references);
//                  call .reopen() to bring it back. Windows without persist
//                  are removed outright on close.
//     shaded       boolean; rolled up to just the titlebar
//     minimized    boolean; hidden entirely (a desk-bar shows it instead)
//     active       boolean; set by the stacking manager on the top window —
//                  style hook only, don't set it yourself
//     no-close     boolean; hide the close button
//   slots (content in):
//     (default)    the window body
//   css vars (theme in), house-light defaults:
//     --fw-bg, --fw-border, --fw-head-bg, --fw-head-bg-active,
//     --fw-radius, --fw-shadow, --fw-shadow-active
//   events (state out), all bubbling + composed:
//     fw-move      detail: { x, y } px, while dragging
//     fw-resize    detail: { width, height } px, while resizing
//     fw-focus     detail: { }        raised to top
//     fw-shade     detail: { shaded }
//     fw-minimize  detail: { minimized }
//     fw-close     fired just before removal
//   attributes (state out, style hooks):
//     adjusting    present while keyboard move/resize mode is active
//   methods:
//     .adjust()    enter keyboard move/resize mode: arrows move (shift = 32px
//                  steps), alt+arrows resize, Enter/Escape or focus loss ends
//                  it. API-only (no chrome) — a keyboard layer's hook.
//     .raise(), .close(), .reopen(), .minimize(), .restore(),
//     .toggleShade(), .center()
//     .snap(spec)  tile the window into a region of the viewport:
//                  'left' 'right' 'top' 'bottom' 'full' — or a grid cell
//                  {cols, rows, x, y, w, h} (w/h in cells, default 1) for a
//                  fully custom layout. Dragging the titlebar away unsnaps
//                  back to the pre-snap size. This is the API a keyboard
//                  layer calls; edge-dragging (below) is the mouse path.
//     .unsnap()    restore pre-snap geometry (position AND size). The
//                  titlebar two-arrow button toggles snap('full')/unsnap().
//
// EDGE-DRAG SNAPPING (mouse path to the same regions)
//   while moving a window, shoving the pointer against a screen edge shows a
//   translucent preview: left/right edge → half, top edge → full, corners →
//   quarter. Release to snap. The tiling area shrinks past any reserved
//   screen edge (see the --fw-area-inset-bottom protocol in
//   window-manager.js) — a <desk-bar> reserves its own strip that way.
//
// DESIGN NOTES
//   - position:fixed on the host; the page it sits on needs no layout
//     cooperation at all. Drop one anywhere.
//   - stacking lives in the manager, shared by every window on the page.
//     The previously-active window loses its `active` attribute — that
//     plus fw-focus is all a taskbar needs.
//   - minimize does NOT remove the element (state lives in the light DOM);
//     it's display:none plus an attribute a desk-bar can see.
//   - iframes: a cross-document iframe would swallow pointermove mid-drag,
//     so every drag/resize raises a full-viewport transparent shield for its
//     duration. Windows can host iframes freely.
//   - template must stay backtick-free (see split-view gotcha #2).

const TPL = document.createElement('template');
TPL.innerHTML = `
  <style>
    :host {
      position: fixed;
      display: flex;
      flex-direction: column;
      background: var(--fw-bg, #ffffff);
      border: 1px solid var(--fw-border, #d0d7de);
      border-radius: var(--fw-radius, 10px);
      box-shadow: var(--fw-shadow, 0 4px 16px rgba(31,35,40,.10));
      overflow: hidden;
      box-sizing: border-box;
      min-width: 0; min-height: 0;
    }
    :host([active]) {
      box-shadow: var(--fw-shadow-active, 0 12px 36px rgba(31,35,40,.22));
    }
    :host([adjusting]) { outline: 2px dashed #0969da; outline-offset: 2px; }
    :host { outline: none; }
    :host([shaded]) #body { display: none; }
    :host([minimized]) { display: none; }
    :host([closed]) { display: none; }

    #head {
      display: flex; align-items: center; gap: 8px;
      padding: 7px 12px;
      background: var(--fw-head-bg, #f6f8fa);
      border-bottom: 1px solid var(--fw-border, #e2e7ee);
      cursor: grab; user-select: none;
      flex: none;
    }
    :host([active]) #head { background: var(--fw-head-bg-active, #eef1f4); }
    :host([shaded]) #head { border-bottom: none; }
    #head.dragging { cursor: grabbing; }
    #icon { flex: none; font-size: 13px; line-height: 1; }
    #icon:empty { display: none; }
    #title {
      flex: 1; font-weight: 600; font-size: 13px;
      color: var(--fw-title-color, #57606a);
      white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
    }
    :host([active]) #title { color: var(--fw-title-color-active, #24292f); }
    #head button {
      all: unset; cursor: pointer; width: 22px; height: 22px; flex: none;
      display: grid; place-items: center; border-radius: 6px; color: #57606a;
    }
    #head button:hover { background: #e2e7ee; color: #24292f; }
    #head svg { width: 13px; height: 13px; }
    :host([no-close]) #close { display: none; }

    #body { flex: 1; min-height: 0; overflow: auto; }

    #snapmenu {
      display: none;
      position: absolute; top: 34px; right: 34px; z-index: 3;
      background: #fff; border: 1px solid var(--fw-border, #d0d7de);
      border-radius: 9px; box-shadow: 0 8px 24px rgba(31,35,40,.16);
      padding: 5px; grid-template-columns: repeat(5, 26px); gap: 2px;
    }
    :host([menu-open]) #snapmenu { display: grid; }
    #snapmenu button {
      all: unset; cursor: pointer; width: 26px; height: 26px;
      display: grid; place-items: center; border-radius: 6px;
      font-size: 14px; color: #57606a; line-height: 1;
    }
    #snapmenu button:hover { background: #eaeef2; color: #24292f; }

    .grip { position: absolute; z-index: 2; }
    :host([shaded]) .grip { display: none; }
    .grip[data-dir="n"], .grip[data-dir="s"] { left: 10px; right: 10px; height: 7px; cursor: ns-resize; }
    .grip[data-dir="e"], .grip[data-dir="w"] { top: 10px; bottom: 10px; width: 7px; cursor: ew-resize; }
    .grip[data-dir="n"] { top: -3px; } .grip[data-dir="s"] { bottom: -3px; }
    .grip[data-dir="e"] { right: -3px; } .grip[data-dir="w"] { left: -3px; }
    .grip[data-dir="ne"], .grip[data-dir="nw"],
    .grip[data-dir="se"], .grip[data-dir="sw"] { width: 13px; height: 13px; }
    .grip[data-dir="ne"] { top: -4px; right: -4px; cursor: nesw-resize; }
    .grip[data-dir="nw"] { top: -4px; left: -4px; cursor: nwse-resize; }
    .grip[data-dir="se"] { bottom: -4px; right: -4px; cursor: nwse-resize; }
    .grip[data-dir="sw"] { bottom: -4px; left: -4px; cursor: nesw-resize; }
  </style>
  <div id="head" part="head">
    <span id="icon"></span>
    <span id="title"></span>
    <button id="max" title="maximize / restore">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 3 21 3 21 9"/><polyline points="9 21 3 21 3 15"/><line x1="21" y1="3" x2="14" y2="10"/><line x1="3" y1="21" x2="10" y2="14"/></svg>
    </button>
    <button id="minimize" title="minimize">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><line x1="5" y1="12" x2="19" y2="12"/></svg>
    </button>
    <button id="close" title="close">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><line x1="6" y1="6" x2="18" y2="18"/><line x1="18" y1="6" x2="6" y2="18"/></svg>
    </button>
  </div>
  <div id="snapmenu">
    <button data-snap="restore" title="restore">&#10530;</button>
    <button data-snap="full" title="full">&#9974;</button>
    <button data-snap="left" title="left half">&#9703;</button>
    <button data-snap="right" title="right half">&#9704;</button>
    <button data-snap="top" title="top half">&#11026;</button>
    <button data-snap="bottom" title="bottom half">&#11027;</button>
    <button data-snap="nw" title="top-left quarter">&#9712;</button>
    <button data-snap="ne" title="top-right quarter">&#9715;</button>
    <button data-snap="sw" title="bottom-left quarter">&#9713;</button>
    <button data-snap="se" title="bottom-right quarter">&#9714;</button>
  </div>
  <div id="body" part="body"><slot></slot></div>
  <div class="grip" data-dir="n"></div><div class="grip" data-dir="s"></div>
  <div class="grip" data-dir="e"></div><div class="grip" data-dir="w"></div>
  <div class="grip" data-dir="ne"></div><div class="grip" data-dir="nw"></div>
  <div class="grip" data-dir="se"></div><div class="grip" data-dir="sw"></div>
`;

// all page-global window-manager concerns — stacking, the active window,
// snap geometry, drag preview, iframe shield, the click-into-iframe focus
// hook — live in window-manager.js (window.floatwm). This file is only the
// widget. Load order: window-manager.js first.
const WM = window.floatwm;
if (!WM) throw new Error('float-window: window-manager.js must be loaded first');

class FloatWindow extends HTMLElement {
  static observedAttributes = ['title', 'icon'];

  #head;
  #savedHeight = null;   // body height remembered across shade/minimize
  #lastGeo = null;       // last APPLIED geometry — the truth while hidden

  constructor() {
    super();
    this.attachShadow({ mode: 'open' }).appendChild(TPL.content.cloneNode(true));
    this.#head = this.shadowRoot.getElementById('head');
  }

  connectedCallback() {
    this.#syncChrome();

    const saved = this.#load();
    // a persisted window the user closed stays closed across reloads —
    // hidden, not removed, so page scripts keep their element references
    if (saved && saved.closed) this.setAttribute('closed', '');
    const geo = saved || {
      x: this.#resolve(this.getAttribute('x') || '96px', innerWidth),
      y: this.#resolve(this.getAttribute('y') || '96px', innerHeight),
      w: parseFloat(this.getAttribute('width')) || 320,
      h: parseFloat(this.getAttribute('height')) || 240,
    };
    this.#savedHeight = geo.h;
    if (saved) {
      this.toggleAttribute('shaded', !!saved.shaded);
      this.toggleAttribute('minimized', !!saved.minimized);

    }
    // sanity-clamp the restore: never off-screen (viewport may have shrunk)
    // and never below minimums (heals any zero-size state that leaked into
    // storage from a save taken while the window was display:none)
    geo.w = Math.max(geo.w || 0, this.#minW);
    geo.h = Math.max(geo.h || 0, this.#minH);
    geo.x = Math.max(48 - geo.w, Math.min(innerWidth - 48, geo.x));
    geo.y = Math.max(0, Math.min(innerHeight - 36, geo.y));
    this.#apply(geo);
    if (saved && saved.region) this.snap(saved.region);
    this.raise();

    // any pointerdown anywhere in the window raises it (capture phase so it
    // wins even when the target is deep in slotted content)
    this.addEventListener('pointerdown', () => this.raise(), true);
    this.#head.addEventListener('pointerdown', (e) => this.#down(e, 'move'));
    this.#head.addEventListener('dblclick', (e) => {
      if (!e.target.closest('button')) this.toggleShade();
    });
    this.shadowRoot.querySelectorAll('.grip').forEach((g) =>
      g.addEventListener('pointerdown', (e) => this.#down(e, g.dataset.dir)));
    // hover reveals the snap menu; click is the plain maximize/restore
    // toggle. Leaving both button and menu closes after a short grace.
    const maxBtn = this.shadowRoot.getElementById('max');
    const menu = this.shadowRoot.getElementById('snapmenu');
    maxBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      this.#toggleMenu(false);
      this.#snapped ? this.unsnap() : this.snap('full');
    });
    for (const el of [maxBtn, menu]) {
      el.addEventListener('mouseenter', () => {
        clearTimeout(this.#menuTimer);
        this.#toggleMenu(true);
      });
      el.addEventListener('mouseleave', () => {
        clearTimeout(this.#menuTimer);
        this.#menuTimer = setTimeout(() => this.#toggleMenu(false), 220);
      });
    }
    this.shadowRoot.getElementById('snapmenu').addEventListener('click', (e) => {
      const b = e.target.closest('[data-snap]');
      if (!b) return;
      e.stopPropagation();
      this.#toggleMenu(false);
      const QUARTERS = {
        nw: { cols: 2, rows: 2, x: 0, y: 0 }, ne: { cols: 2, rows: 2, x: 1, y: 0 },
        sw: { cols: 2, rows: 2, x: 0, y: 1 }, se: { cols: 2, rows: 2, x: 1, y: 1 },
      };
      const v = b.dataset.snap;
      if (v === 'restore') this.unsnap();
      else this.snap(QUARTERS[v] || v);
    });
    this.shadowRoot.getElementById('minimize').addEventListener('click',
      (e) => { e.stopPropagation(); this.minimize(); });
    this.shadowRoot.getElementById('close').addEventListener('click',
      (e) => { e.stopPropagation(); this.close(); });
  }

  disconnectedCallback() {
    WM.forget(this);
  }

  attributeChangedCallback() {
    if (this.shadowRoot) this.#syncChrome();
  }

  #syncChrome() {
    this.shadowRoot.getElementById('title').textContent = this.getAttribute('title') || '';
    this.shadowRoot.getElementById('icon').textContent = this.getAttribute('icon') || '';
  }

  get #geo() {
    return { x: this.offsetLeft, y: this.offsetTop, w: this.offsetWidth, h: this.offsetHeight };
  }
  get #minW() { return parseFloat(this.getAttribute('min-width')) || 200; }
  get #minH() { return parseFloat(this.getAttribute('min-height')) || 120; }

  #resolve(raw, box) {
    return raw.endsWith('%') ? (parseFloat(raw) / 100) * box : parseFloat(raw) || 0;
  }

  #apply(g) {
    this.#lastGeo = { x: g.x, y: g.y, w: g.w, h: g.h };
    this.style.left = Math.round(g.x) + 'px';
    this.style.top = Math.round(g.y) + 'px';
    this.style.width = Math.round(g.w) + 'px';
    this.style.height = this.hasAttribute('shaded') ? 'auto' : Math.round(g.h) + 'px';
  }

  // ---- drag: one handler for move + all eight resize directions ----
  #drag = null;
  #snapped = null;    // pre-snap {x, y, w, h}, present iff currently snapped
  #region = null;     // the snap spec currently applied (persisted; the
                      // saved x/y/w/h are ALWAYS the real, un-snapped
                      // geometry — a snap is a mode, never a size)
  #dropZone = null;   // snap spec the in-flight drag would drop into

  #down(e, mode) {
    if (e.button !== 0) return;
    if (mode === 'move' && e.target.closest('button')) return;
    if (mode !== 'move' && this.hasAttribute('shaded')) return;
    const start = this.#geo;
    if (this.hasAttribute('shaded')) start.h = this.#savedHeight;
    this.#drag = { mode, sx: e.clientX, sy: e.clientY, start };
    const tgt = e.currentTarget;
    tgt.setPointerCapture(e.pointerId);
    WM.shield(true);
    if (mode === 'move') this.#head.classList.add('dragging');
    const onMove = (ev) => this.#move(ev);
    tgt.addEventListener('pointermove', onMove);
    tgt.addEventListener('pointerup', () => {
      tgt.removeEventListener('pointermove', onMove);
      this.#head.classList.remove('dragging');
      this.#drag = null;
      WM.preview(null);
      WM.shield(false);
      if (this.#dropZone) { this.snap(this.#dropZone); this.#dropZone = null; }
      this.#save();
    }, { once: true });
    e.preventDefault();
  }

  #move(e) {
    if (!this.#drag) return;
    const d = this.#drag;
    const dx = e.clientX - d.sx, dy = e.clientY - d.sy;
    const g = { x: d.start.x, y: d.start.y, w: d.start.w, h: d.start.h };
    if (d.mode === 'move') {
      // dragging a snapped window away unsnaps it: restore the pre-snap size
      // with the cursor staying proportionally placed on the titlebar
      if (this.#snapped && (Math.abs(dx) > 4 || Math.abs(dy) > 4)) {
        this.#region = null;
        const frac = (e.clientX - d.start.x) / d.start.w;
        d.start.w = this.#snapped.w;
        d.start.h = this.#snapped.h;
        d.start.x = e.clientX - d.start.w * frac - dx;
        this.#savedHeight = d.start.h;
        this.#snapped = null;
      }
      g.w = d.start.w; g.h = d.start.h;
      g.x = d.start.x + dx; g.y = d.start.y + dy;
      // keep at least a graspable sliver of titlebar on screen
      g.x = Math.max(48 - g.w, Math.min(innerWidth - 48, g.x));
      g.y = Math.max(0, Math.min(innerHeight - 36, g.y));
      this.#apply(g);
      // edge shove → show the snap target this drop would tile into
      this.#dropZone = WM.zoneAt(e.clientX, e.clientY);
      WM.preview(this.#dropZone ? WM.snapRect(this.#dropZone) : null);
      this.dispatchEvent(new CustomEvent('fw-move',
        { detail: { x: g.x, y: g.y }, bubbles: true, composed: true }));
      return;
    }
    const dir = d.mode;
    if (dir.includes('e')) g.w = d.start.w + dx;
    if (dir.includes('s')) g.h = d.start.h + dy;
    if (dir.includes('w')) { g.w = d.start.w - dx; g.x = d.start.x + dx; }
    if (dir.includes('n')) { g.h = d.start.h - dy; g.y = d.start.y + dy; }
    if (g.w < this.#minW) { if (dir.includes('w')) g.x -= this.#minW - g.w; g.w = this.#minW; }
    if (g.h < this.#minH) { if (dir.includes('n')) g.y -= this.#minH - g.h; g.h = this.#minH; }
    this.#snapped = null;   // a hand-resized window is no longer tiled
    this.#region = null;
    this.#savedHeight = g.h;
    this.#apply(g);
    this.dispatchEvent(new CustomEvent('fw-resize',
      { detail: { width: g.w, height: g.h }, bubbles: true, composed: true }));
  }

  // ---- window verbs ----
  raise() {
    WM.raise(this);
    this.dispatchEvent(new CustomEvent('fw-focus', { bubbles: true, composed: true }));
  }

  minimize() {
    this.setAttribute('minimized', '');
    WM.forget(this);
    this.dispatchEvent(new CustomEvent('fw-minimize',
      { detail: { minimized: true }, bubbles: true, composed: true }));
    this.#save();
  }

  restore() {
    this.removeAttribute('minimized');
    this.raise();
    this.dispatchEvent(new CustomEvent('fw-minimize',
      { detail: { minimized: false }, bubbles: true, composed: true }));
    this.#save();
  }

  toggleShade() {
    const shaded = this.toggleAttribute('shaded');
    if (shaded) this.#savedHeight = this.#geo.h;
    this.style.height = shaded ? 'auto' : Math.round(this.#savedHeight) + 'px';
    this.dispatchEvent(new CustomEvent('fw-shade',
      { detail: { shaded }, bubbles: true, composed: true }));
    this.#save();
  }

  snap(spec) {
    const r = WM.snapRect(spec);
    if (!r) return;
    this.#region = spec;
    if (this.hasAttribute('shaded')) this.toggleShade();
    if (!this.#snapped) {
      // hidden windows measure 0×0 — the last applied geometry is the truth
      const g = (this.offsetWidth === 0 && this.#lastGeo) ? this.#lastGeo : this.#geo;
      this.#snapped = { x: g.x, y: g.y, w: g.w, h: g.h };
    }
    this.#apply({ x: r.x, y: r.y, w: r.w, h: r.h });
    this.raise();
    this.dispatchEvent(new CustomEvent('fw-resize',
      { detail: { width: r.w, height: r.h }, bubbles: true, composed: true }));
    this.#save();
  }

  unsnap() {
    if (!this.#snapped) return;
    const g = { ...this.#snapped };
    this.#snapped = null;
    this.#region = null;
    this.#savedHeight = g.h;
    g.x = Math.max(48 - g.w, Math.min(innerWidth - 48, g.x));
    g.y = Math.max(0, Math.min(innerHeight - 36, g.y));
    this.#apply(g);
    this.#save();
  }

  #menuTimer = null;

  #toggleMenu(force) {
    const open = force ?? !this.hasAttribute('menu-open');
    this.toggleAttribute('menu-open', open);
    if (open) {
      this.raise();
      document.addEventListener('pointerdown', this.#closeMenu, true);
    } else {
      document.removeEventListener('pointerdown', this.#closeMenu, true);
    }
  }

  #closeMenu = (e) => {
    if (e.composedPath().includes(this.shadowRoot.getElementById('snapmenu'))) return;
    this.#toggleMenu(false);
  };

  // keyboard move/resize mode: focus the host and steer with arrows.
  // Ends on Enter/Escape or when focus leaves the window frame.
  adjust() {
    if (this.hasAttribute('adjusting')) return this.#endAdjust();
    this.raise();
    this.setAttribute('adjusting', '');
    this.tabIndex = -1;
    this.focus();
    this.addEventListener('keydown', this.#onAdjustKey);
    this.addEventListener('blur', this.#endAdjust);
  }

  #endAdjust = () => {
    this.removeAttribute('adjusting');
    this.removeEventListener('keydown', this.#onAdjustKey);
    this.removeEventListener('blur', this.#endAdjust);
    this.#save();
  };

  #onAdjustKey = (e) => {
    if (e.key === 'Enter' || e.key === 'Escape') {
      this.#endAdjust();
      this.blur();
      e.preventDefault();
      return;
    }
    const step = e.shiftKey ? 32 : 8;
    let dx = 0, dy = 0;
    if (e.key === 'ArrowLeft') dx = -step;
    else if (e.key === 'ArrowRight') dx = step;
    else if (e.key === 'ArrowUp') dy = -step;
    else if (e.key === 'ArrowDown') dy = step;
    else return;
    const g = this.#geo;
    if (e.altKey) {
      g.w = Math.max(this.#minW, g.w + dx);
      g.h = Math.max(this.#minH, g.h + dy);
      this.#snapped = null;
      this.#savedHeight = g.h;
      this.dispatchEvent(new CustomEvent('fw-resize',
        { detail: { width: g.w, height: g.h }, bubbles: true, composed: true }));
    } else {
      g.x = Math.max(48 - g.w, Math.min(innerWidth - 48, g.x + dx));
      g.y = Math.max(0, Math.min(innerHeight - 36, g.y + dy));
      this.dispatchEvent(new CustomEvent('fw-move',
        { detail: { x: g.x, y: g.y }, bubbles: true, composed: true }));
    }
    this.#apply(g);
    e.preventDefault();
  };

  center() {
    const g = this.#geo;
    g.x = (innerWidth - g.w) / 2;
    g.y = Math.max(0, (innerHeight - g.h) / 2.4);
    this.#apply(g);
    this.#save();
  }

  close() {
    this.dispatchEvent(new CustomEvent('fw-close', { bubbles: true, composed: true }));
    if (!this.#key()) return this.remove();
    this.setAttribute('closed', '');
    WM.forget(this);
    this.#save();
  }

  reopen() {
    this.removeAttribute('closed');
    this.removeAttribute('minimized');
    this.raise();
    this.#save();
  }

  // ---- persistence, same shape as split-view ----
  #key() {
    const k = this.getAttribute('persist');
    return k ? 'float-window:' + k : null;
  }
  #save() {
    const k = this.#key();
    if (!k) return;
    // saved geometry is ALWAYS the real, un-snapped one: pre-snap geo if
    // tiled; last applied if hidden (display:none measures 0×0); else live
    const g = this.#snapped ? { ...this.#snapped }
      : (this.offsetWidth === 0 && this.#lastGeo) ? { ...this.#lastGeo }
      : this.#geo;
    if (this.hasAttribute('shaded')) g.h = this.#savedHeight;
    try {
      localStorage.setItem(k, JSON.stringify({
        x: g.x, y: g.y, w: g.w, h: Math.round(g.h),
        shaded: this.hasAttribute('shaded'),
        minimized: this.hasAttribute('minimized'),
        closed: this.hasAttribute('closed'),
        region: this.#region,
      }));
    } catch (_) {}
  }
  #load() {
    const k = this.#key();
    if (!k) return null;
    try { return JSON.parse(localStorage.getItem(k) || 'null'); } catch (_) { return null; }
  }
}

customElements.define('float-window', FloatWindow);
