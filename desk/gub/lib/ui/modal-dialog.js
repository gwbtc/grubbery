// <modal-dialog> — a centered modal over a backdrop.
//
// A thin wrapper over the native <dialog> element, which already gives us the
// backdrop, focus trap, Esc-to-close, and top-layer stacking for free. Forge
// hand-rolls this twice (#modal-back/#modal, #json-back/#json-modal) with
// bespoke show/hide + backdrop divs; this replaces that with one tag.
//
// USAGE
//   <modal-dialog id="m">
//     <h2>New repo</h2>
//     <label>name <input></label>
//     <div class="actions">
//       <button data-close>cancel</button>
//       <button>create</button>
//     </div>
//   </modal-dialog>
//   m.show();   // open   (also: <modal-dialog open>)
//   m.close();  // close
//
// CONTRACT
//   attributes (config in):
//     open              boolean; reflects/controls visibility
//     no-backdrop-close boolean; clicking the backdrop won't close it
//   slots (content in):
//     default   the modal body. Any element with a [data-close] attribute
//               closes the dialog on click (wire your own cancel/close button).
//   css vars (theme in), house-light defaults:
//     --md-bg        card background (default #fff)
//     --md-border    card border (default none — set e.g. "1px solid #bbb")
//     --md-width     max card width (default 440px)
//     --md-radius    card corner radius (default 14px)
//     --md-pad       card padding (default 22px)
//     --md-shadow    card box-shadow (default 0 16px 48px rgba(0,0,0,.28))
//     --md-backdrop  backdrop color (default rgba(0,0,0,.35))
//   events (state out), all bubbling + composed (library policy):
//     md-open, md-close   ({ detail: { returnValue } } on close)
//   methods:
//     .show(), .close(returnValue)
//
// DESIGN NOTES — behavior worth encapsulating: native <dialog>.showModal()
// gives focus trap + Esc + top layer, but backdrop-click-to-close and
// data-close wiring are ours. Shadow DOM isolates the card styling. Keep this
// template literal backtick-free.

const TPL = document.createElement('template');
TPL.innerHTML = `
  <style>
    dialog {
      border: var(--md-border, none);
      padding: 0;
      color: inherit;
      background: var(--md-bg, #fff);
      border-radius: var(--md-radius, 14px);
      width: min(var(--md-width, 440px), calc(100vw - 32px));
      box-shadow: var(--md-shadow, 0 16px 48px rgba(0,0,0,0.28));
      overflow: hidden;
    }
    dialog::backdrop { background: var(--md-backdrop, rgba(0,0,0,0.35)); }
    .wrap { padding: var(--md-pad, 22px); }
    /* fade/scale in */
    dialog[open] { animation: md-in .14s ease-out; }
    @keyframes md-in { from { opacity: 0; transform: translateY(4px) scale(.98); } }
    @media (prefers-reduced-motion: reduce) { dialog[open] { animation: none; } }
  </style>
  <dialog part="dialog"><div class="wrap"><slot></slot></div></dialog>
`;

class ModalDialog extends HTMLElement {
  static observedAttributes = ['open'];

  #dialog;

  constructor() {
    super();
    this.attachShadow({ mode: 'open' }).appendChild(TPL.content.cloneNode(true));
    this.#dialog = this.shadowRoot.querySelector('dialog');
  }

  connectedCallback() {
    // Bookkeeping is driven from our own close() and from the dialog's own
    // events, all funneled through #reflectClosed (idempotent). We do NOT
    // rely solely on the native 'close' event: programmatic .close() does not
    // reliably dispatch it in every engine, so close() reflects directly.
    // 'cancel' (Esc) DOES fire, and covers keyboard dismissal.
    this.#dialog.addEventListener('close', () => this.#reflectClosed(this.#dialog.returnValue));
    this.#dialog.addEventListener('cancel', () => this.#reflectClosed(''));
    // backdrop click closes (target is the <dialog> itself, not the card)
    this.#dialog.addEventListener('click', (e) => {
      if (e.target === this.#dialog && !this.hasAttribute('no-backdrop-close')) this.close();
    });
    // any [data-close] element in the light DOM closes it
    this.addEventListener('click', (e) => {
      if (e.target.closest('[data-close]')) this.close();
    });
    if (this.hasAttribute('open')) this.show();
  }

  // remove the open attr + emit md-close, exactly once per close
  #reflectClosed(returnValue) {
    if (!this.hasAttribute('open')) return;
    this.removeAttribute('open');
    this.dispatchEvent(new CustomEvent('md-close', {
      detail: { returnValue }, bubbles: true, composed: true,
    }));
  }

  attributeChangedCallback(name, _old, val) {
    if (name !== 'open') return;
    const wantOpen = val !== null;
    if (wantOpen && !this.#dialog.open) this.show();
    else if (!wantOpen && this.#dialog.open) this.#dialog.close();
  }

  show() {
    if (this.#dialog.open) return;
    this.#dialog.showModal();
    this.setAttribute('open', '');
    this.dispatchEvent(new CustomEvent('md-open', { bubbles: true, composed: true }));
  }

  close(returnValue = '') {
    if (this.#dialog.open) this.#dialog.close(returnValue);
    this.#reflectClosed(returnValue);   // don't wait on the native close event
  }
}

customElements.define('modal-dialog', ModalDialog);
