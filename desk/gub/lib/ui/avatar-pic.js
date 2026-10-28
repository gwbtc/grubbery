// <avatar-pic> — a round avatar: the picture when there is one, else the
// first letter of the name on a color derived from a seed (a pubkey, a
// ship name — anything stable), so the same person always gets the same
// color even before their profile has arrived.
//
// USAGE
//   <avatar-pic name="fiatjaf" src="https://…/pic.jpg" seed="3bf0c6…" size="30"></avatar-pic>
//
// CONTRACT
//   attributes (config in):
//     name   shown as its first letter while no picture loads (default "?")
//     src    picture url; only http(s) is used; a broken image falls back
//     seed   string the fallback color is derived from (default: name)
//     size   pixels, square (default 30)
//   css vars (theme in):
//     --av-size    overrides the size attribute
//     --av-weight  letter weight (default 650)
//   events: none. Purely presentational; the host decides what a click means.
//
// DESIGN NOTES — hue is a small hash of the seed's first 8 chars; a light
// background with a dark letter of the same hue reads well on the house
// light theme. The <img> is only created when src is http(s), and removes
// itself on error so the letter shows through. Keep the template backtick-free.

const TPL = document.createElement('template');
TPL.innerHTML = `
  <style>
    :host {
      --_s: var(--av-size, 30px);
      position: relative; display: inline-flex; align-items: center; justify-content: center;
      width: var(--_s); height: var(--_s); border-radius: 50%; flex: none; overflow: hidden;
      font-size: calc(var(--_s) * .4); font-weight: var(--av-weight, 650); line-height: 1;
      font-family: inherit; user-select: none; vertical-align: middle;
    }
    img { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; }
  </style>
  <span id="letter"></span>
`;

class AvatarPic extends HTMLElement {
  static get observedAttributes() { return ['name', 'src', 'seed', 'size']; }
  constructor() {
    super();
    this.attachShadow({ mode: 'open' }).appendChild(TPL.content.cloneNode(true));
  }
  connectedCallback() { this.#render(); }
  attributeChangedCallback() { if (this.isConnected) this.#render(); }
  #render() {
    const name = this.getAttribute('name') || '';
    const seed = this.getAttribute('seed') || name || '?';
    const size = this.getAttribute('size');
    if (size) this.style.setProperty('--av-size', parseInt(size, 10) + 'px');
    let hue = 0;
    for (let i = 0; i < Math.min(8, seed.length); i++) hue = (hue * 31 + seed.charCodeAt(i)) % 360;
    this.style.background = 'hsl(' + hue + ', 32%, 82%)';
    this.style.color = 'hsl(' + hue + ', 45%, 30%)';
    this.shadowRoot.getElementById('letter').textContent = (name || seed).slice(0, 1).toUpperCase();
    const old = this.shadowRoot.querySelector('img');
    if (old) old.remove();
    const src = this.getAttribute('src') || '';
    if (/^https?:\/\//.test(src)) {
      const img = document.createElement('img');
      img.loading = 'lazy';
      img.referrerPolicy = 'no-referrer';
      img.alt = '';
      img.onerror = () => img.remove();
      img.src = src;
      this.shadowRoot.appendChild(img);
    }
  }
}
customElements.define('avatar-pic', AvatarPic);
