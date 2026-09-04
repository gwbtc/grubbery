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
//     persist      localStorage key; geometry + shaded/minimized survive reload
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
//   methods:
//     .raise(), .close(), .minimize(), .restore(),
//     .toggleShade(), .center()
//     .snap(spec)  tile the window into a region of the viewport:
//                  'left' 'right' 'top' 'bottom' 'full' — or a grid cell
//                  {cols, rows, x, y, w, h} (w/h in cells, default 1) for a
//                  fully custom layout. Dragging the titlebar away unsnaps
//                  back to the pre-snap size. This is the API a keyboard
//                  layer calls; edge-dragging (below) is the mouse path.
//     .unsnap()    restore pre-snap size in place
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
    :host([shaded]) #body { display: none; }
    :host([minimized]) { display: none; }

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
    <button id="minimize" title="minimize">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><line x1="5" y1="12" x2="19" y2="12"/></svg>
    </button>
    <button id="close" title="close">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><line x1="6" y1="6" x2="18" y2="18"/><line x1="18" y1="6" x2="6" y2="18"/></svg>
    </button>
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

  constructor() {
    super();
    this.attachShadow({ mode: 'open' }).appendChild(TPL.content.cloneNode(true));
    this.#head = this.shadowRoot.getElementById('head');
  }

  connectedCallback() {
    this.#syncChrome();

    const saved = this.#load();
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
    // never restore fully off-screen (viewport may have shrunk since save)
    geo.x = Math.max(48 - geo.w, Math.min(innerWidth - 48, geo.x));
    geo.y = Math.max(0, Math.min(innerHeight - 36, geo.y));
    this.#apply(geo);
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
    this.style.left = Math.round(g.x) + 'px';
    this.style.top = Math.round(g.y) + 'px';
    this.style.width = Math.round(g.w) + 'px';
    this.style.height = this.hasAttribute('shaded') ? 'auto' : Math.round(g.h) + 'px';
  }

  // ---- drag: one handler for move + all eight resize directions ----
  #drag = null;
  #snapped = null;    // pre-snap {w, h}, present iff currently snapped
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
    if (this.hasAttribute('shaded')) this.toggleShade();
    if (!this.#snapped) this.#snapped = { w: this.#geo.w, h: this.#geo.h };
    this.#apply({ x: r.x, y: r.y, w: r.w, h: r.h });
    this.raise();
    this.dispatchEvent(new CustomEvent('fw-resize',
      { detail: { width: r.w, height: r.h }, bubbles: true, composed: true }));
    this.#save();
  }

  unsnap() {
    if (!this.#snapped) return;
    const g = this.#geo;
    g.w = this.#snapped.w; g.h = this.#snapped.h;
    this.#snapped = null;
    this.#savedHeight = g.h;
    this.#apply(g);
    this.#save();
  }

  center() {
    const g = this.#geo;
    g.x = (innerWidth - g.w) / 2;
    g.y = Math.max(0, (innerHeight - g.h) / 2.4);
    this.#apply(g);
    this.#save();
  }

  close() {
    this.dispatchEvent(new CustomEvent('fw-close', { bubbles: true, composed: true }));
    this.remove();
  }

  // ---- persistence, same shape as split-view ----
  #key() {
    const k = this.getAttribute('persist');
    return k ? 'float-window:' + k : null;
  }
  #save() {
    const k = this.#key();
    if (!k) return;
    const g = this.#geo;
    if (this.hasAttribute('shaded')) g.h = this.#savedHeight;
    try {
      localStorage.setItem(k, JSON.stringify({
        x: g.x, y: g.y, w: g.w, h: Math.round(g.h),
        shaded: this.hasAttribute('shaded'),
        minimized: this.hasAttribute('minimized'),
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
