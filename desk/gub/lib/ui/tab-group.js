// <tab-group> — a tabbed panel switcher.
//
// You slot in panels, each tagged with a tab-label attribute; the component
// renders the tab strip from those labels and shows one panel at a time.
// Forge hand-rolls three separate tab strips (mode-tabs, console tabs, tool
// subtabs) — this replaces all of them with one element.
//
// USAGE
//   <tab-group persist="forge-mode">
//     <div tab-label="Repo">...panel content...</div>
//     <div tab-label="Tools">...</div>
//     <section tab-label="Settings">...</section>
//   </tab-group>
//
// CONTRACT
//   attributes (config in):
//     active   initial tab, by 0-based index ("0") or by label ("Tools")
//     persist  localStorage key; when set, the active tab survives reload
//   slots (content in):
//     default  each direct child is a panel; its tab-label attribute names
//              the tab. A child with no tab-label is ignored (not a panel).
//   css vars (theme in), house-light defaults:
//     --tg-border      strip underline / divider color (default #e2e7ee)
//     --tg-tab-color   idle tab text (default #57606a)
//     --tg-tab-hover   hovered tab text (default #24292f)
//     --tg-tab-active  active tab text (default #1f2328)
//     --tg-accent      active tab underline (default #0969da)
//     --tg-gap         space between tabs (default 4px)
//   events (state out):
//     tg-change   detail: { index, label }
//   methods:
//     .select(indexOrLabel)
//
// DESIGN NOTES — same as <split-view>: one self-contained file, shadow DOM
// for isolation, --tg-* vars are the theming surface, four-channel contract,
// no form participation. State kept minimal (just the active index, in
// localStorage). Panels here are laid out with plain block flow (strip on
// top, one panel shown below), so the <slot> display:contents quirk that bit
// split-view's grid doesn't apply — we just toggle `hidden` on the slotted
// panels. Keep this template literal backtick-free (a stray backtick, even in
// a CSS comment, ends the string and the element never registers).

const TPL = document.createElement('template');
TPL.innerHTML = `
  <style>
    :host {
      display: flex;
      flex-direction: column;
      min-width: 0;
      min-height: 0;
    }
    #strip {
      flex: 0 0 auto;
      display: flex;
      gap: var(--tg-gap, 4px);
      border-bottom: 1px solid var(--tg-border, #e2e7ee);
      overflow-x: auto;
      scrollbar-width: none;
    }
    #strip::-webkit-scrollbar { display: none; }
    button.tab {
      appearance: none;
      background: none;
      border: none;
      font: inherit;
      font-size: 13px;
      color: var(--tg-tab-color, #57606a);
      padding: 8px 12px;
      cursor: pointer;
      white-space: nowrap;
      border-bottom: 2px solid transparent;
      margin-bottom: -1px;
      transition: color .12s, border-color .12s;
    }
    button.tab:hover { color: var(--tg-tab-hover, #24292f); }
    button.tab[aria-selected="true"] {
      color: var(--tg-tab-active, #1f2328);
      border-bottom-color: var(--tg-accent, #0969da);
      font-weight: 600;
    }
    button.tab:focus-visible {
      outline: 2px solid var(--tg-accent, #0969da);
      outline-offset: -2px;
      border-radius: 4px;
    }
    #panels { flex: 1 1 auto; min-height: 0; }
    ::slotted([tab-label]) { height: 100%; }
    ::slotted([hidden]) { display: none !important; }
  </style>
  <div id="strip" part="strip" role="tablist"></div>
  <div id="panels" part="panels"><slot></slot></div>
`;

class TabGroup extends HTMLElement {
  static observedAttributes = ['active'];

  #strip;
  #slot;
  #panels = [];   // the slotted elements that are panels (have tab-label)
  #index = 0;

  constructor() {
    super();
    this.attachShadow({ mode: 'open' }).appendChild(TPL.content.cloneNode(true));
    this.#strip = this.shadowRoot.getElementById('strip');
    this.#slot = this.shadowRoot.querySelector('slot');
  }

  connectedCallback() {
    this.#slot.addEventListener('slotchange', this.#rebuild);
    this.#rebuild();
  }

  attributeChangedCallback(name, _old, val) {
    if (name === 'active' && this.#panels.length) this.select(val ?? 0);
  }

  // read the slotted panels, (re)render the tab strip, restore active tab
  #rebuild = () => {
    this.#panels = this.#slot.assignedElements().filter(el => el.hasAttribute('tab-label'));
    this.#strip.textContent = '';
    this.#panels.forEach((panel, i) => {
      const label = panel.getAttribute('tab-label');
      const id = `tg-tab-${i}`;
      const btn = document.createElement('button');
      btn.className = 'tab';
      btn.textContent = label;
      btn.id = id;
      btn.setAttribute('role', 'tab');
      btn.setAttribute('type', 'button');
      btn.tabIndex = -1;
      btn.addEventListener('click', () => this.select(i));
      btn.addEventListener('keydown', this.#onKey);
      this.#strip.appendChild(btn);
      panel.setAttribute('role', 'tabpanel');
      panel.setAttribute('aria-labelledby', id);
    });
    if (!this.#panels.length) return;
    // pick the starting tab: persisted, else the `active` attr, else 0
    const start = this.#load() ?? this.getAttribute('active') ?? 0;
    this.select(start, true);
  };

  // resolve an index-or-label to an index; -1 if not found
  #resolve(indexOrLabel) {
    if (indexOrLabel == null) return 0;
    const asNum = Number(indexOrLabel);
    if (Number.isInteger(asNum) && String(asNum) === String(indexOrLabel)) return asNum;
    return this.#panels.findIndex(p => p.getAttribute('tab-label') === indexOrLabel);
  }

  select(indexOrLabel, silent = false) {
    let i = this.#resolve(indexOrLabel);
    if (i < 0 || i >= this.#panels.length) i = 0;
    this.#index = i;
    this.#panels.forEach((panel, j) => { panel.hidden = j !== i; });
    [...this.#strip.children].forEach((btn, j) => {
      const on = j === i;
      btn.setAttribute('aria-selected', on ? 'true' : 'false');
      btn.tabIndex = on ? 0 : -1;
    });
    this.#save();
    if (!silent) {
      this.dispatchEvent(new CustomEvent('tg-change', {
        detail: { index: i, label: this.#panels[i].getAttribute('tab-label') },
        bubbles: true,
      }));
    }
  }

  // arrow keys move between tabs (roving tabindex), Home/End jump to ends
  #onKey = (e) => {
    const n = this.#panels.length;
    let to = this.#index;
    if (e.key === 'ArrowRight') to = (this.#index + 1) % n;
    else if (e.key === 'ArrowLeft') to = (this.#index - 1 + n) % n;
    else if (e.key === 'Home') to = 0;
    else if (e.key === 'End') to = n - 1;
    else return;
    this.select(to);
    this.#strip.children[to].focus();
    e.preventDefault();
  };

  get value() { return this.#panels[this.#index]?.getAttribute('tab-label') ?? null; }

  #key() {
    const k = this.getAttribute('persist');
    return k ? 'tab-group:' + k : null;
  }
  #save() {
    const k = this.#key();
    if (!k) return;
    try { localStorage.setItem(k, String(this.#index)); } catch (_) {}
  }
  #load() {
    const k = this.#key();
    if (!k) return null;
    const v = localStorage.getItem(k);
    return v == null ? null : Number(v);
  }
}

customElements.define('tab-group', TabGroup);
