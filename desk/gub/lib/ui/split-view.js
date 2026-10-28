// <split-view> — a resizable, collapsible two-pane split.
//
// No web-platform element does this; everyone reaches for split.js or a
// pile of bespoke CSS + drag JS. This is the one primitive with the
// highest reuse and no equivalent, so it's where the library starts.
//
// CONTRACT
//   attributes (config in):
//     orientation  "horizontal" (default, panes side-by-side, drag L/R)
//                | "vertical"   (panes stacked, drag up/down)
//     primary      "start" (default) | "end"
//                  which pane is the sized/persisted/collapsible one
//     size         initial primary size, any CSS length ("240px", "30%")
//     min          min primary size in px (default 80)
//     max          max primary size in px (default Infinity)
//     collapsed    boolean; primary pane hidden, thin reopen rail shown
//     no-rail      boolean; when collapsed, hide the pane fully (no reopen
//                  sliver) — reopen only via .toggle()/.expand() from the host
//     persist      localStorage key; when set, size + collapsed survive reload
//   slots (content in):
//     start, end   the two panes
//   css vars (theme in), with house-light defaults:
//     --sv-handle-size    thickness of the drag handle (default 6px)
//     --sv-handle-color   idle handle color (default transparent)
//     --sv-handle-hover   hover/active handle color (default #d0d7de)
//     --sv-rail-bg        collapsed reopen-rail bg (default #f6f8fa)
//     --sv-rail-hover     rail hover bg (default #eaeef2)
//     --sv-border         divider line color (default #e2e7ee)
//   events (state out), all bubbling + composed (library policy):
//     sv-resize   detail: { size } px, while/after dragging
//     sv-collapse detail: { collapsed } bool
//   methods:
//     .toggle()  collapse/expand the primary pane
//     .collapse(), .expand()
//
// DESIGN NOTES (why it's built this way)
//   - Pure web component: one self-contained .js file, no build step, no
//     framework. Served verbatim from the ship (web-test/ui/). "It's just a
//     file the browser runs" is the whole point.
//   - Shadow DOM for real style isolation: a host page's CSS can't reach in
//     and break this, and our internals can't leak out. The cost is theming,
//     which we pay deliberately via the --sv-* CSS custom properties above —
//     that variable set IS the public theming surface. Defaults are house-light.
//   - Four-channel contract: attributes in, slots in, CSS vars in, events out.
//     No form participation (no ElementInternals) — layout chrome has no value.
//   - State kept minimal + local: only chrome state (size, collapsed) lives
//     here, in localStorage. No domain state, no second source of truth.
//
// TWO SHADOW-DOM GOTCHAS worth knowing (both annotated at their site below):
//   1. <slot> defaults to display:contents, so it is NOT a grid/flex item and
//      `order`/sizing on a <slot> does nothing. We wrap each slot in a real
//      <div> (#pane-start/#pane-end) and make THOSE the grid items. (see CSS)
//   2. A backtick anywhere inside this `TPL.innerHTML = ` template literal --
//      even inside a CSS comment -- ends the string and throws SyntaxError,
//      so the element never registers. Keep the template backtick-free.

const TPL = document.createElement('template');
TPL.innerHTML = `
  <style>
    :host {
      display: grid;
      width: 100%;
      height: 100%;
      min-width: 0;
      min-height: 0;
      overflow: hidden;
      box-sizing: border-box;
    }
    ::slotted(*) { min-width: 0; min-height: 0; }
    /* real grid-item wrappers around each slot. slots default to
       display:contents (not grid items), so order on a slot is inert --
       these divs are the actual grid items we place and order. */
    #pane-start, #pane-end { min-width: 0; min-height: 0; overflow: hidden; display: block; }

    #handle {
      background: var(--sv-handle-color, transparent);
      position: relative;
      z-index: 1;
      touch-action: none;
    }
    /* the only visible part of the handle is a hairline divider, centered
       in a wider invisible hit-target. hover just darkens/thickens the line. */
    #handle::after {
      content: "";
      position: absolute;
      background: var(--sv-border, #e2e7ee);
      transition: background .12s;
    }
    #handle:hover::after, #handle.dragging::after {
      background: var(--sv-handle-hover, #adb5bd);
    }
    :host(:not([orientation="vertical"])) #handle:hover::after,
    :host(:not([orientation="vertical"])) #handle.dragging::after { width: 3px; }
    :host([orientation="vertical"]) #handle:hover::after,
    :host([orientation="vertical"]) #handle.dragging::after { height: 3px; }

    :host([orientation="vertical"]) #handle { cursor: row-resize; }
    :host(:not([orientation="vertical"])) #handle { cursor: col-resize; }

    /* the hairline divider sits centered in the fatter hit-target */
    :host(:not([orientation="vertical"])) #handle::after {
      top: 0; bottom: 0; left: 50%; width: 1px; transform: translateX(-.5px);
    }
    :host([orientation="vertical"]) #handle::after {
      left: 0; right: 0; top: 50%; height: 1px; transform: translateY(-.5px);
    }

    /* collapsed: primary pane and handle gone, thin reopen rail in place.
       the chevron points toward where the pane will reappear. with the
       no-rail attribute set, the pane collapses fully (no sliver) and the
       only way back is .toggle()/expand() from the host. */
    #rail {
      display: none;
      background: var(--sv-rail-bg, #f6f8fa);
      align-items: center;
      justify-content: center;
      cursor: pointer;
      user-select: none;
      color: var(--sv-rail-color, #57606a);
    }
    #rail svg { width: 16px; height: 16px; transition: transform .12s; }
    #rail:hover { background: var(--sv-rail-hover, #eaeef2); color: var(--sv-rail-hover-color, #24292f); }
    :host([collapsed]:not([no-rail])) #rail { display: flex; }
    /* base chevron points right (left sidebar → expand rightward); rotate for
       the other three geometries so it always points into the reveal. */
    :host([primary="end"]:not([orientation="vertical"])) #rail svg { transform: rotate(180deg); }
    :host([orientation="vertical"]:not([primary="end"])) #rail svg { transform: rotate(90deg); }
    :host([orientation="vertical"][primary="end"]) #rail svg { transform: rotate(-90deg); }
  </style>
  <div id="pane-start" part="pane"><slot name="start"></slot></div>
  <div id="handle" part="handle" role="separator" tabindex="0"></div>
  <div id="pane-end" part="pane"><slot name="end"></slot></div>
  <div id="rail" part="rail" title="expand" role="button" tabindex="0">
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"></polyline></svg>
  </div>
`;

class SplitView extends HTMLElement {
  // hide-primary: transient, host-driven full hide of the primary pane (no
  // rail, no handle) — like collapsed+no-rail but NOT persisted and orthogonal
  // to the user's `collapsed` state. Use it to drop a pane per app-mode
  // (e.g. no console in a tools view) without clobbering the saved layout.
  static observedAttributes = ['orientation', 'primary', 'size', 'collapsed', 'no-rail', 'hide-primary'];

  #handle;
  #rail;
  #paneStart;
  #paneEnd;
  #dragging = false;
  #railSize = 22; // px reserved for the reopen rail when collapsed

  constructor() {
    super();
    this.attachShadow({ mode: 'open' }).appendChild(TPL.content.cloneNode(true));
    this.#handle = this.shadowRoot.getElementById('handle');
    this.#rail = this.shadowRoot.getElementById('rail');
    this.#paneStart = this.shadowRoot.getElementById('pane-start');
    this.#paneEnd = this.shadowRoot.getElementById('pane-end');
  }

  connectedCallback() {
    // restore persisted state before first layout so there's no flash
    const saved = this.#load();
    if (saved) {
      if (saved.size != null) this.setAttribute('size', saved.size + 'px');
      this.toggleAttribute('collapsed', !!saved.collapsed);
    }
    this.#handle.addEventListener('pointerdown', this.#onDown);
    this.#handle.addEventListener('keydown', this.#onKey);
    this.#rail.addEventListener('click', () => this.expand());
    this.#rail.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') { this.expand(); e.preventDefault(); }
    });
    this.#layout();
  }

  attributeChangedCallback() {
    if (this.isConnected) this.#layout();
  }

  get #vertical() { return this.getAttribute('orientation') === 'vertical'; }
  get #primaryStart() { return this.getAttribute('primary') !== 'end'; }
  get #min() { return Number(this.getAttribute('min')) || 80; }
  get #max() { return Number(this.getAttribute('max')) || Infinity; }

  // current primary size in px, resolved from the size attribute
  get #size() {
    const raw = this.getAttribute('size') || '240px';
    if (raw.endsWith('%')) {
      const box = this.#vertical ? this.clientHeight : this.clientWidth;
      return (parseFloat(raw) / 100) * box;
    }
    return parseFloat(raw) || 240;
  }

  #layout() {
    const axis = this.#vertical ? 'grid-template-rows' : 'grid-template-columns';
    const other = this.#vertical ? 'grid-template-columns' : 'grid-template-rows';
    this.style[other] = '';
    this.style.removeProperty('grid-template-rows');
    this.style.removeProperty('grid-template-columns');

    const hs = `var(--sv-handle-size, 6px)`;
    const hidden = this.hasAttribute('hide-primary');
    let track;
    if (hidden || this.hasAttribute('collapsed')) {
      // primary → 0, handle → 0, rail takes its reserved sliver at the primary
      // edge — unless no-rail (or hide-primary), where it collapses fully.
      const rail = (hidden || this.hasAttribute('no-rail')) ? '0' : this.#railSize + 'px';
      track = this.#primaryStart ? `0 0 ${rail} 1fr` : `1fr ${rail} 0 0`;
      // grid needs 4 tracks now (rail is a real cell); reorder slots via order
      this.#applyOrder(true);
    } else {
      const p = Math.max(this.#min, Math.min(this.#max, this.#size)) + 'px';
      track = this.#primaryStart ? `${p} ${hs} 1fr` : `1fr ${hs} ${p}`;
      this.#applyOrder(false);
    }
    this.style[axis] = track;
  }

  // slot/handle/rail source order is fixed in the template; use `order` so
  // the panes, handle, and rail line up with the grid tracks. The track
  // definitions in #layout already place the primary size on the correct
  // side, so the non-collapsed order is just natural (start, handle, end).
  #applyOrder(collapsed) {
    const startSlot = this.#paneStart;
    const endSlot = this.#paneEnd;
    const h = this.#handle, r = this.#rail;
    if (!collapsed) {
      // tracks: primary=start → [p][handle][1fr]; primary=end → [1fr][handle][p]
      // either way the leftmost source slot maps to the leftmost track.
      startSlot.style.order = 0; h.style.order = 1; endSlot.style.order = 2;
      r.style.order = 99;
    } else if (this.#primaryStart) {
      // tracks: [primary=0][handle=0][rail][content=1fr]
      startSlot.style.order = 0; h.style.order = 1; r.style.order = 2; endSlot.style.order = 3;
    } else {
      // tracks: [content=1fr][rail][handle=0][primary=0]
      startSlot.style.order = 0; r.style.order = 1; h.style.order = 2; endSlot.style.order = 3;
    }
  }

  #onDown = (e) => {
    if (this.hasAttribute('collapsed')) return;
    this.#dragging = true;
    this.#handle.classList.add('dragging');
    this.#handle.setPointerCapture(e.pointerId);
    this.#handle.addEventListener('pointermove', this.#onMove);
    this.#handle.addEventListener('pointerup', this.#onUp, { once: true });
    e.preventDefault();
  };

  #onMove = (e) => {
    if (!this.#dragging) return;
    const rect = this.getBoundingClientRect();
    const pos = this.#vertical ? e.clientY - rect.top : e.clientX - rect.left;
    const box = this.#vertical ? rect.height : rect.width;
    let size = this.#primaryStart ? pos : box - pos;
    size = Math.max(this.#min, Math.min(this.#max, size));
    this.setAttribute('size', Math.round(size) + 'px');
    this.dispatchEvent(new CustomEvent('sv-resize', { detail: { size: Math.round(size) }, bubbles: true, composed: true }));
  };

  #onUp = () => {
    this.#dragging = false;
    this.#handle.classList.remove('dragging');
    this.#handle.removeEventListener('pointermove', this.#onMove);
    this.#save();
  };

  #onKey = (e) => {
    const step = e.shiftKey ? 32 : 8;
    let d = 0;
    if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') d = -step;
    else if (e.key === 'ArrowRight' || e.key === 'ArrowDown') d = step;
    else if (e.key === 'Enter' || e.key === ' ') { this.toggle(); e.preventDefault(); return; }
    else return;
    if (!this.#primaryStart) d = -d;
    const size = Math.max(this.#min, Math.min(this.#max, this.#size + d));
    this.setAttribute('size', Math.round(size) + 'px');
    this.dispatchEvent(new CustomEvent('sv-resize', { detail: { size: Math.round(size) }, bubbles: true, composed: true }));
    this.#save();
    e.preventDefault();
  };

  toggle() { this.hasAttribute('collapsed') ? this.expand() : this.collapse(); }

  collapse() {
    this.setAttribute('collapsed', '');
    this.dispatchEvent(new CustomEvent('sv-collapse', { detail: { collapsed: true }, bubbles: true, composed: true }));
    this.#save();
  }

  expand() {
    this.removeAttribute('collapsed');
    this.dispatchEvent(new CustomEvent('sv-collapse', { detail: { collapsed: false }, bubbles: true, composed: true }));
    this.#save();
  }

  #key() {
    const k = this.getAttribute('persist');
    return k ? 'split-view:' + k : null;
  }
  #save() {
    const k = this.#key();
    if (!k) return;
    try {
      localStorage.setItem(k, JSON.stringify({
        size: Math.round(this.#size),
        collapsed: this.hasAttribute('collapsed'),
      }));
    } catch (_) {}
  }
  #load() {
    const k = this.#key();
    if (!k) return null;
    try { return JSON.parse(localStorage.getItem(k) || 'null'); } catch (_) { return null; }
  }
}

customElements.define('split-view', SplitView);
