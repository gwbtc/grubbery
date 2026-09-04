// <drop-menu> — a button that opens an anchored popover menu.
//
// Forge hand-rolls this twice (#repo-menu, #branch-menu): a trigger, an
// absolutely-positioned panel, click-outside-to-close, keyboard. This is the
// reusable version.
//
// USAGE
//   <drop-menu align="start">
//     <button slot="trigger">branch: main ▾</button>
//     <button>main</button>
//     <button>dev</button>
//     <button>feature/x</button>
//   </drop-menu>
//
// CONTRACT
//   attributes (config in):
//     open    boolean; reflects/controls the menu
//     align   "start" (default, left-aligned) | "end" (right-aligned)
//   slots (content in):
//     trigger   the button that opens the menu
//     default   the menu items (any focusable elements; a click inside
//               closes the menu unless the item has [data-keep-open])
//   css vars (theme in), house-light defaults:
//     --dm-bg, --dm-border, --dm-radius, --dm-shadow, --dm-min-width, --dm-gap
//   events (state out), all bubbling + composed (library policy):
//     dm-open, dm-close
//   methods:
//     .open(), .close(), .toggle()
//
// DESIGN NOTES — real behavior to encapsulate: toggle, click-outside, Esc,
// arrow-key roving, and anchoring the panel under the trigger. v1 anchors
// straight below (no collision/flip yet — noted, not silently missing). Shadow
// DOM isolates the panel. Keep this template literal backtick-free.

const TPL = document.createElement('template');
TPL.innerHTML = `
  <style>
    :host { position: relative; display: inline-block; }
    #panel {
      position: absolute;
      top: calc(100% + 4px);
      z-index: 60;
      min-width: var(--dm-min-width, 180px);
      background: var(--dm-bg, #fff);
      border: 1px solid var(--dm-border, #d0d7de);
      border-radius: var(--dm-radius, 10px);
      box-shadow: var(--dm-shadow, 0 8px 24px rgba(0,0,0,0.15));
      padding: var(--dm-gap, 4px);
      display: none;
      flex-direction: column;
    }
    :host([open]) #panel { display: flex; }
    :host(:not([align="end"])) #panel { left: 0; }
    :host([align="end"]) #panel { right: 0; }
    /* style slotted menu items into a consistent list */
    ::slotted(:not([slot="trigger"])) {
      appearance: none;
      background: none;
      border: none;
      font: inherit;
      font-size: 13px;
      text-align: left;
      color: inherit;
      padding: 7px 10px;
      border-radius: 6px;
      cursor: pointer;
      white-space: nowrap;
    }
    ::slotted(:not([slot="trigger"]):hover),
    ::slotted(:not([slot="trigger"]):focus-visible) {
      background: var(--dm-item-hover, #f2f4f7);
      outline: none;
    }
  </style>
  <slot name="trigger"></slot>
  <div id="panel" part="panel" role="menu"><slot></slot></div>
`;

class DropMenu extends HTMLElement {
  static observedAttributes = ['open'];

  #panel;
  #triggerSlot;
  #itemSlot;

  constructor() {
    super();
    this.attachShadow({ mode: 'open' }).appendChild(TPL.content.cloneNode(true));
    this.#panel = this.shadowRoot.getElementById('panel');
    this.#triggerSlot = this.shadowRoot.querySelector('slot[name="trigger"]');
    this.#itemSlot = this.shadowRoot.querySelector('#panel slot');
  }

  connectedCallback() {
    this.#triggerSlot.addEventListener('click', () => this.toggle());
    // a click closes the menu, unless it lands inside a [data-keep-open]
    // subtree (e.g. an inline input row that should stay open while used)
    this.#itemSlot.addEventListener('click', (e) => {
      if (!e.target.closest('[data-keep-open]')) this.close();
    });
    this.addEventListener('keydown', this.#onKey);
    // click / focus outside closes — bound once, active only while open
    this.#onDocPointer = (e) => { if (!this.contains(e.target)) this.close(); };
  }

  #onDocPointer;

  attributeChangedCallback(name) {
    if (name !== 'open') return;
    if (this.hasAttribute('open')) {
      document.addEventListener('pointerdown', this.#onDocPointer, true);
      this.dispatchEvent(new CustomEvent('dm-open', { bubbles: true, composed: true }));
    } else {
      document.removeEventListener('pointerdown', this.#onDocPointer, true);
      this.dispatchEvent(new CustomEvent('dm-close', { bubbles: true, composed: true }));
    }
  }

  #items() {
    return this.#itemSlot.assignedElements().filter(el => !el.disabled);
  }

  #onKey = (e) => {
    if (e.key === 'Escape' && this.hasAttribute('open')) {
      this.close();
      this.#triggerSlot.assignedElements()[0]?.focus();
      return;
    }
    if (!['ArrowDown', 'ArrowUp'].includes(e.key)) return;
    e.preventDefault();
    if (!this.hasAttribute('open')) { this.open(); }
    const items = this.#items();
    if (!items.length) return;
    const cur = items.indexOf(document.activeElement);
    const next = e.key === 'ArrowDown'
      ? (cur + 1) % items.length
      : (cur - 1 + items.length) % items.length;
    items[next < 0 ? 0 : next].focus();
  };

  open() { this.setAttribute('open', ''); }
  close() { this.removeAttribute('open'); }
  toggle() { this.hasAttribute('open') ? this.close() : this.open(); }
}

customElements.define('drop-menu', DropMenu);
