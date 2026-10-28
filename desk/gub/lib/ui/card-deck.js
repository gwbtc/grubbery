// <card-deck> — a swipeable deck of cards: one in focus, neighbors peeking
// at the edges, dots below. Arrows and keys on desktop, drag on touch and
// mouse, animated on every change. The host renders each card; the deck
// owns everything about moving between them.
//
// USAGE
//   <card-deck id="deck" persist="gp-deck" loop></card-deck>
//   const deck = document.getElementById('deck');
//   deck.render = (item, i, isCurrent) => { const el = ...; return el; };
//   deck.items = [...];              // re-render; index is clamped
//   deck.addEventListener('cd-change', e => showDetail(e.detail.item));
//   deck.index = 3;  deck.next();  deck.prev();
//
// CONTRACT
//   properties:
//     items    Array. Setting re-renders. Empty shows the empty slot.
//     render   Function(item, index, isCurrent) => Element. Required.
//              Called for the visible window only (current ± peek).
//     index    Number, the card in focus. Setting animates to it.
//   attributes (config in):
//     persist  localStorage key; the index survives reload
//     loop     boolean; wrap around at the ends
//     peek     how many neighbors to show each side (default 1)
//   slots (content in):
//     empty    shown when items is empty
//   css vars (theme in), house-light defaults:
//     --cd-height       stage height (default 240px)
//     --cd-card-width   card width (default min(640px, 78%))
//     --cd-peek-shift   how far a neighbor sits from center (default 72%)
//     --cd-peek-scale   neighbor scale (default .88)
//     --cd-peek-opacity neighbor opacity (default .45)
//     --cd-duration     transition time (default .28s)
//     --cd-accent       active dot / arrow hover (default #1f2328)
//     --cd-muted        idle dot, arrow border (default #d6dae0)
//   events (state out), bubbling + composed:
//     cd-change  detail: { index, item } — after a move (not on every drag frame)
//   methods:
//     .next(), .prev(), .go(i)
//
// DESIGN NOTES — every card carries its offset from the focus as a CSS
// custom property; the transform is a function of that, so a move is one
// property change per card and the transition does the animation. Dragging
// sets a live pixel delta on the stage that the same transform adds, so the
// finger drives the cards until release, then a snap. Below 600px the
// arrows hide (dots + swipe carry it) and the peek shrinks so the focused
// card gets the width. Keep this template literal backtick-free.

const TPL = document.createElement('template');
TPL.innerHTML = `
  <style>
    :host { display: block; min-width: 0; --_drag: 0px; }
    #wrap { display: grid; grid-template-columns: 44px minmax(0, 1fr) 44px; align-items: center; }
    .arrow {
      width: 36px; height: 36px; margin: auto; border-radius: 50%;
      border: 1px solid var(--cd-muted, #d6dae0); background: #fff;
      color: #57606a; font-size: 22px; line-height: 1; cursor: pointer;
      user-select: none; -webkit-tap-highlight-color: transparent;
    }
    .arrow:hover { color: var(--cd-accent, #1f2328); background: #f6f7f9; }
    .arrow:disabled { opacity: .3; cursor: default; }
    #stage {
      position: relative; width: 100%; min-width: 0; height: var(--cd-height, 240px); overflow: hidden;
      display: flex; align-items: center; justify-content: center;
      touch-action: pan-y; user-select: none; cursor: grab;
    }
    #stage.dragging { cursor: grabbing; }
    ::slotted([data-off]) {
      position: absolute; width: var(--cd-card-width, min(640px, 78%));
      box-sizing: border-box;
      transform:
        translateX(calc(var(--_off, 0) * var(--cd-peek-shift, 72%) + var(--_drag)))
        scale(calc(1 - (1 - var(--cd-peek-scale, .88)) * min(1, max(var(--_off, 0), -1 * var(--_off, 0)))));
      opacity: calc(1 - (1 - var(--cd-peek-opacity, .45)) * min(1, max(var(--_off, 0), -1 * var(--_off, 0))));
      transition: transform var(--cd-duration, .28s) cubic-bezier(.22,.8,.3,1),
                  opacity var(--cd-duration, .28s) ease;
      will-change: transform, opacity;
    }
    #stage.dragging ::slotted([data-off]) { transition: none; }
    ::slotted([data-off="0"]) { z-index: 3; cursor: default; }
    ::slotted([data-off]:not([data-off="0"])) { z-index: 1; cursor: pointer; }
    ::slotted([data-off]:not([data-off="0"]):hover) { opacity: .7; }
    ::slotted([data-far]) { opacity: 0 !important; pointer-events: none; }
    #empty { color: #9aa0a8; font-size: 13.5px; line-height: 1.5; text-align: center; max-width: 420px; }
    #dots { display: flex; justify-content: center; gap: 6px; padding: 6px 0 2px; flex-wrap: wrap; }
    .dot {
      width: 7px; height: 7px; border-radius: 50%; border: none; padding: 0;
      background: var(--cd-muted, #d6dae0); cursor: pointer;
      transition: transform .18s ease, background .18s ease;
    }
    .dot.on { background: var(--cd-accent, #1f2328); transform: scale(1.3); }
    @media (max-width: 600px) {
      #wrap { grid-template-columns: minmax(0, 1fr); }
      .arrow { display: none; }
      :host { --cd-peek-shift: 88%; --cd-card-width: 86%; }
    }
  </style>
  <div id="wrap">
    <button class="arrow" id="prev" title="Previous">&#8249;</button>
    <div id="stage"><slot></slot><div id="empty"><slot name="empty">Nothing here yet.</slot></div></div>
    <button class="arrow" id="next" title="Next">&#8250;</button>
  </div>
  <div id="dots"></div>
`;

class CardDeck extends HTMLElement {
  static get observedAttributes() { return ['peek']; }
  #items = [];
  #render = null;
  #index = 0;
  #stage; #dots; #prev; #next; #empty;
  #drag = null;   // { x0, moved }

  constructor() {
    super();
    this.attachShadow({ mode: 'open' }).appendChild(TPL.content.cloneNode(true));
    const $ = (id) => this.shadowRoot.getElementById(id);
    this.#stage = $('stage'); this.#dots = $('dots');
    this.#prev = $('prev'); this.#next = $('next'); this.#empty = $('empty');
    this.#prev.addEventListener('click', () => this.prev());
    this.#next.addEventListener('click', () => this.next());
    this.#wireDrag();
  }

  connectedCallback() {
    // a classic script may have set .render / .items before this class
    // upgraded the element; those landed as own properties that shadow
    // the setters. Adopt them, then delete so the setters take over.
    for (const p of ['render', 'items', 'index']) {
      if (Object.prototype.hasOwnProperty.call(this, p)) {
        const v = this[p]; delete this[p]; this[p] = v;
      }
    }
    const key = this.getAttribute('persist');
    if (key) {
      try { const v = parseInt(localStorage.getItem(key), 10); if (!isNaN(v)) this.#index = v; } catch (_) {}
    }
    this.#keyHandler = (e) => {
      if (e.target.closest && e.target.closest('input, textarea, [contenteditable]')) return;
      if (document.querySelector('modal-dialog[open], dialog[open]')) return;
      if (e.key === 'ArrowLeft') { this.prev(); e.preventDefault(); }
      if (e.key === 'ArrowRight') { this.next(); e.preventDefault(); }
    };
    document.addEventListener('keydown', this.#keyHandler);
    this.#paint();
  }
  disconnectedCallback() { document.removeEventListener('keydown', this.#keyHandler); }
  #keyHandler = null;

  attributeChangedCallback() { this.#paint(); }

  set items(v) { this.#items = Array.isArray(v) ? v : []; this.#clamp(); this.#paint(); }
  get items() { return this.#items; }
  set render(fn) { this.#render = fn; this.#paint(); }
  get render() { return this.#render; }
  set index(i) { this.go(i); }
  get index() { return this.#index; }
  get current() { return this.#items[this.#index]; }

  next() { this.go(this.#index + 1); }
  prev() { this.go(this.#index - 1); }
  go(i) {
    const n = this.#items.length;
    if (!n) return;
    if (this.hasAttribute('loop')) i = ((i % n) + n) % n;
    else i = Math.max(0, Math.min(n - 1, i));
    if (i === this.#index) { this.#paint(); return; }
    this.#index = i;
    this.#persist();
    this.#paint();
    this.dispatchEvent(new CustomEvent('cd-change', {
      bubbles: true, composed: true, detail: { index: i, item: this.#items[i] },
    }));
  }

  #clamp() {
    const n = this.#items.length;
    if (this.#index >= n) this.#index = Math.max(0, n - 1);
    if (this.#index < 0) this.#index = 0;
  }
  #persist() {
    const key = this.getAttribute('persist');
    if (key) { try { localStorage.setItem(key, String(this.#index)); } catch (_) {} }
  }

  // keep card elements keyed by item index so a move re-positions the
  // existing nodes (that is what animates) instead of rebuilding them.
  // Cards live in the host's light DOM, slotted into the stage, so the
  // host's own CSS styles them; the deck only sets data-off / --_off.
  #cards = new Map();
  #paint() {
    const n = this.#items.length;
    const peek = Math.max(1, parseInt(this.getAttribute('peek'), 10) || 1);
    const loop = this.hasAttribute('loop');
    this.#prev.disabled = this.#next.disabled = n < 2;
    if (!loop) { this.#prev.disabled = this.#index <= 0; this.#next.disabled = this.#index >= n - 1; }
    this.#empty.style.display = n ? 'none' : '';
    const want = new Map();
    if (n && this.#render) {
      for (let off = -peek - 1; off <= peek + 1; off++) {
        let j = this.#index + off;
        if (loop) j = ((j % n) + n) % n; else if (j < 0 || j >= n) continue;
        if (want.has(j)) continue;
        want.set(j, off);
      }
    }
    for (const [j, el] of this.#cards) {
      if (!want.has(j)) { el.remove(); this.#cards.delete(j); }
    }
    for (const [j, off] of want) {
      let el = this.#cards.get(j);
      const isCur = off === 0;
      if (!el || el.dataset.cur !== String(isCur)) {
        const fresh = this.#render(this.#items[j], j, isCur);
        fresh.dataset.cur = String(isCur);
        // start where the node it replaces was (or, brand new, just past
        // the edge on its side) so it animates in rather than popping
        const start = el ? el.style.getPropertyValue('--_off') : String(off + Math.sign(off));
        fresh.style.setProperty('--_off', start || String(off));
        fresh.dataset.off = String(off);
        if (el) el.replaceWith(fresh); else this.appendChild(fresh);
        el = fresh;
        this.#cards.set(j, el);
        el.addEventListener('click', () => { if (el.dataset.off !== '0' && !this.#drag?.moved) this.go(j); });
      }
      if (Math.abs(off) > peek) el.dataset.far = ''; else delete el.dataset.far;
      el.dataset.off = String(off);
      // commit the start position, then set the target: the transition
      // runs between the two. Synchronous and deterministic — no rAF.
      void el.offsetWidth;
      el.style.setProperty('--_off', String(off));
    }
    // dots
    this.#dots.textContent = '';
    if (n > 1 && n <= 40) {
      for (let i = 0; i < n; i++) {
        const d = document.createElement('button');
        d.className = 'dot' + (i === this.#index ? ' on' : '');
        d.title = String(i + 1) + ' / ' + n;
        d.addEventListener('click', () => this.go(i));
        this.#dots.appendChild(d);
      }
    } else if (n > 40) {
      const t = document.createElement('span');
      t.style.cssText = 'font-size:12px;color:#9aa0a8';
      t.textContent = (this.#index + 1) + ' / ' + n;
      this.#dots.appendChild(t);
    }
  }

  // drag: the finger (or mouse) drives --_drag live; on release, snap to
  // the neighbor if the pull was far or fast enough
  #wireDrag() {
    const st = this.#stage;
    const down = (x, t) => { this.#drag = { x0: x, t0: t, moved: false }; st.classList.add('dragging'); };
    const move = (x) => {
      if (!this.#drag) return;
      const dx = x - this.#drag.x0;
      if (Math.abs(dx) > 4) this.#drag.moved = true;
      this.style.setProperty('--_drag', dx + 'px');
    };
    const up = (x, t) => {
      if (!this.#drag) return;
      const dx = x - this.#drag.x0, dt = Math.max(1, t - this.#drag.t0);
      const w = st.clientWidth || 1;
      const fast = Math.abs(dx) / dt > 0.5;   // px/ms
      st.classList.remove('dragging');
      this.style.setProperty('--_drag', '0px');
      const moved = this.#drag.moved;
      this.#drag = null;
      if (Math.abs(dx) > w * 0.22 || (fast && Math.abs(dx) > 24)) this.go(this.#index + (dx < 0 ? 1 : -1));
      // swallow the click that follows a real drag
      if (moved) { const eat = (e) => { e.stopPropagation(); e.preventDefault(); }; st.addEventListener('click', eat, { capture: true, once: true }); }
    };
    st.addEventListener('touchstart', (e) => down(e.touches[0].clientX, e.timeStamp), { passive: true });
    st.addEventListener('touchmove', (e) => move(e.touches[0].clientX), { passive: true });
    st.addEventListener('touchend', (e) => up(e.changedTouches[0].clientX, e.timeStamp));
    st.addEventListener('mousedown', (e) => { if (e.button === 0 && !e.target.closest('button, a, input, textarea')) down(e.clientX, e.timeStamp); });
    window.addEventListener('mousemove', (e) => move(e.clientX));
    window.addEventListener('mouseup', (e) => up(e.clientX, e.timeStamp));
  }
}

if (!customElements.get('card-deck')) customElements.define('card-deck', CardDeck);
