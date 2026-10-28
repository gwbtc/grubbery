// <desk-bar> — a bottom taskbar that manages every <float-window> on the page.
//
// Zero wiring: drop one <desk-bar> anywhere and it discovers windows itself.
// It watches the document for float-window connect/disconnect (via a
// MutationObserver) and listens for the windows' bubbling fw-* events to keep
// its buttons in sync. One button per window; click semantics match every
// desktop OS: minimized → restore, active → minimize, otherwise → raise.
//
// CONTRACT
//   attributes (config in):
//     no-clock     boolean; hide the clock on the right
//   slots (content in):
//     (default)    launcher area on the left (buttons, menus — your call);
//                  whatever you slot sits before the window buttons
//   css vars (theme in), house-light defaults:
//     --db-bg, --db-border, --db-height (default 44px),
//     --db-btn-bg, --db-btn-active-bg, --db-btn-color
//   events (state out): none of its own — it only reflects window state.
//     Window buttons call the windows' public methods directly.
//
// DESIGN NOTES
//   - the bar is display-only state derived from the DOM; the windows remain
//     the single source of truth (their attributes ARE the state). No
//     registry to corrupt: rescan-on-mutation + event-driven refresh.
//   - on connect the bar reserves its strip of screen by setting
//     --fw-area-inset-bottom on the document root (cleared on disconnect) —
//     the window manager's tiling area honors it without knowing about us.
//     See the inset protocol note in window-manager.js.
//   - template must stay backtick-free (split-view gotcha #2).

const TPL = document.createElement('template');
TPL.innerHTML = `
  <style>
    :host {
      position: fixed;
      left: 0; right: 0; bottom: 0;
      height: var(--db-height, 44px);
      display: flex; align-items: center; gap: 6px;
      padding: 0 10px;
      background: var(--db-bg, rgba(246, 248, 250, .92));
      backdrop-filter: blur(10px);
      border-top: 1px solid var(--db-border, #d0d7de);
      box-sizing: border-box;
      z-index: 2147483000;
      font: 13px/1.4 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      user-select: none;
    }
    #launchers { display: flex; align-items: center; gap: 6px; flex: none; }
    #sep { width: 1px; height: 22px; background: var(--db-border, #d0d7de); flex: none; margin: 0 4px; }
    #wins { display: flex; align-items: center; gap: 6px; flex: 1; min-width: 0; overflow-x: auto; }
    #wins::-webkit-scrollbar { display: none; }
    #wins button {
      all: unset; cursor: pointer;
      display: inline-flex; align-items: center; gap: 7px;
      max-width: 180px; padding: 5px 12px;
      border-radius: 8px;
      background: var(--db-btn-bg, transparent);
      border: 1px solid transparent;
      color: var(--db-btn-color, #57606a);
      white-space: nowrap;
    }
    #wins button .label { overflow: hidden; text-overflow: ellipsis; }
    #wins button .glyph { flex: none; font-size: 13px; }
    #wins button:hover { background: #eaeef2; }
    #wins button.active {
      background: var(--db-btn-active-bg, #ffffff);
      border-color: var(--db-border, #d0d7de);
      color: #24292f; font-weight: 600;
    }
    #wins button.minimized { opacity: .55; }
    #clock {
      flex: none; margin-left: auto; padding: 0 6px;
      font: 12px ui-monospace, SFMono-Regular, Menlo, monospace;
      color: #57606a;
    }
    :host([no-clock]) #clock { display: none; }
  </style>
  <div id="launchers"><slot></slot></div>
  <div id="sep"></div>
  <div id="wins"></div>
  <div id="clock"></div>
`;

class DeskBar extends HTMLElement {
  #wins; #clock;
  #observer = null;
  #timer = null;

  constructor() {
    super();
    this.attachShadow({ mode: 'open' }).appendChild(TPL.content.cloneNode(true));
    this.#wins = this.shadowRoot.getElementById('wins');
    this.#clock = this.shadowRoot.getElementById('clock');
  }

  connectedCallback() {
    // reserve our strip of screen: the window manager's tiling area reads
    // --fw-area-inset-bottom off the root, so snapped windows stop above us.
    // We declare it about ourselves; the manager never learns who we are.
    document.documentElement.style.setProperty(
      '--fw-area-inset-bottom', this.offsetHeight + 'px');

    // windows appearing/disappearing anywhere in the document
    this.#observer = new MutationObserver((muts) => {
      for (const m of muts) {
        for (const n of [...m.addedNodes, ...m.removedNodes]) {
          if (n.nodeType === 1 &&
              (n.tagName === 'FLOAT-WINDOW' || n.querySelector?.('float-window'))) {
            this.#render();
            return;
          }
        }
      }
    });
    this.#observer.observe(document.body, { childList: true, subtree: true });

    // window state changes arrive as bubbling events; re-render is cheap
    for (const ev of ['fw-focus', 'fw-minimize', 'fw-shade', 'fw-close'])
      document.addEventListener(ev, this.#refresh);

    this.#tick();
    this.#timer = setInterval(() => this.#tick(), 10000);
    this.#render();
  }

  disconnectedCallback() {
    document.documentElement.style.removeProperty('--fw-area-inset-bottom');
    this.#observer?.disconnect();
    for (const ev of ['fw-focus', 'fw-minimize', 'fw-shade', 'fw-close'])
      document.removeEventListener(ev, this.#refresh);
    clearInterval(this.#timer);
  }

  #refresh = () => this.#render();

  #tick() {
    const d = new Date();
    const hh = String(d.getHours()).padStart(2, '0');
    const mm = String(d.getMinutes()).padStart(2, '0');
    this.#clock.textContent = hh + ':' + mm;
  }

  #render() {
    this.#wins.textContent = '';
    for (const w of document.querySelectorAll('float-window')) {
      if (w.hasAttribute('closed')) continue;
      const b = document.createElement('button');
      const glyph = document.createElement('span');
      glyph.className = 'glyph';
      glyph.textContent = w.getAttribute('icon') || '';
      const label = document.createElement('span');
      label.className = 'label';
      label.textContent = w.getAttribute('title') || 'window';
      if (glyph.textContent) b.appendChild(glyph);
      b.appendChild(label);
      if (w.hasAttribute('active')) b.classList.add('active');
      if (w.hasAttribute('minimized')) b.classList.add('minimized');
      b.addEventListener('click', () => {
        if (w.hasAttribute('minimized')) w.restore();
        else if (w.hasAttribute('active')) w.minimize();
        else w.raise();
      });
      this.#wins.appendChild(b);
    }
  }
}

customElements.define('desk-bar', DeskBar);
