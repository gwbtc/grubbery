// <start-menu> — a launcher menu that pops up from a trigger button.
//
// Built to slot into a <desk-bar>'s launcher area, but it's really just an
// anchored popup: trigger at the bottom, panel opens upward. Menu items are
// whatever you slot in — plain buttons work; give them normal click handlers.
// The menu closes itself after any item click, on Escape, and on any click
// outside.
//
// CONTRACT
//   attributes (config in):
//     label        text on the trigger button (default just the glyph)
//     glyph        trigger glyph (default a diamond)
//     open         boolean, reflected; present while the panel is up
//   slots (content in):
//     (default)    the menu items, stacked vertically
//     header       optional header area pinned above the items
//   css vars (theme in), house-light defaults:
//     --sm-panel-bg, --sm-border, --sm-radius, --sm-shadow, --sm-width
//   events (state out):
//     sm-toggle    detail: { open }
//   methods:
//     .show(), .hide(), .toggle()
//
// DESIGN NOTES
//   - the panel is position:fixed anchored to the trigger's rect, so it works
//     inside the desk-bar's shadow slot without any z-index negotiation with
//     windows (it sits above the bar which is already on top).
//   - slotted items get their look from the HOST page (they're light DOM);
//     ::slotted() rules below only provide layout defaults, not skin. That
//     keeps app entries fully styleable per page.
//   - template must stay backtick-free (split-view gotcha #2).

const TPL = document.createElement('template');
TPL.innerHTML = `
  <style>
    :host { display: inline-block; position: relative; }
    #trigger {
      all: unset; cursor: pointer;
      display: inline-flex; align-items: center; gap: 7px;
      padding: 5px 10px; border-radius: 8px;
      font: 600 13px/1.4 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      color: #24292f; user-select: none;
    }
    #trigger:hover, :host([open]) #trigger { background: #eaeef2; }
    #glyph { font-size: 14px; line-height: 1; }
    #label:empty { display: none; }

    #panel {
      display: none;
      position: fixed;
      min-width: var(--sm-width, 220px);
      background: var(--sm-panel-bg, #ffffff);
      border: 1px solid var(--sm-border, #d0d7de);
      border-radius: var(--sm-radius, 12px);
      box-shadow: var(--sm-shadow, 0 12px 36px rgba(31,35,40,.18));
      padding: 6px;
      box-sizing: border-box;
      z-index: 2147483001;
    }
    :host([open]) #panel { display: block; }
    #items { display: flex; flex-direction: column; }
    ::slotted(*) { border-radius: 8px; }
    #header ::slotted(*) { margin-bottom: 4px; }
  </style>
  <button id="trigger">
    <span id="glyph"></span><span id="label"></span>
  </button>
  <div id="panel">
    <div id="header"><slot name="header"></slot></div>
    <div id="items"><slot></slot></div>
  </div>
`;

class StartMenu extends HTMLElement {
  static observedAttributes = ['label', 'glyph'];

  #trigger; #panel;

  constructor() {
    super();
    this.attachShadow({ mode: 'open' }).appendChild(TPL.content.cloneNode(true));
    this.#trigger = this.shadowRoot.getElementById('trigger');
    this.#panel = this.shadowRoot.getElementById('panel');
  }

  connectedCallback() {
    this.#syncChrome();
    this.#trigger.addEventListener('click', (e) => { e.stopPropagation(); this.toggle(); });
    // any item click closes; the item's own handler already ran
    this.#panel.addEventListener('click', () => this.hide());
    document.addEventListener('pointerdown', this.#onOutside);
    document.addEventListener('keydown', this.#onKey);
  }

  disconnectedCallback() {
    document.removeEventListener('pointerdown', this.#onOutside);
    document.removeEventListener('keydown', this.#onKey);
  }

  attributeChangedCallback() {
    if (this.shadowRoot) this.#syncChrome();
  }

  #syncChrome() {
    this.shadowRoot.getElementById('glyph').textContent = this.getAttribute('glyph') || '◆';
    this.shadowRoot.getElementById('label').textContent = this.getAttribute('label') || '';
  }

  #onOutside = (e) => {
    if (this.hasAttribute('open') && !e.composedPath().includes(this)) this.hide();
  };
  #onKey = (e) => {
    if (e.key === 'Escape' && this.hasAttribute('open')) this.hide();
  };

  show() {
    // anchor the panel just above the trigger, hugging its left edge
    const r = this.#trigger.getBoundingClientRect();
    this.#panel.style.left = Math.max(6, r.left) + 'px';
    this.#panel.style.bottom = (innerHeight - r.top + 8) + 'px';
    this.setAttribute('open', '');
    this.dispatchEvent(new CustomEvent('sm-toggle',
      { detail: { open: true }, bubbles: true, composed: true }));
  }

  hide() {
    this.removeAttribute('open');
    this.dispatchEvent(new CustomEvent('sm-toggle',
      { detail: { open: false }, bubbles: true, composed: true }));
  }

  toggle() { this.hasAttribute('open') ? this.hide() : this.show(); }
}

customElements.define('start-menu', StartMenu);
