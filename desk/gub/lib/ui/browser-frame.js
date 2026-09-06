// <browser-frame> — tabbed iframe browser with history stacks.
//
// USAGE
//   <browser-frame home="/grubbery/..." persist="my-key"></browser-frame>
//
// CONTRACT
//   attributes:
//     home      default page for new tabs (required)
//     persist   localStorage key for session restore (optional)
//   events (bubbling + composed):
//     bf-navigate  { path, tab }  — a tab navigated to a new path

const STYLE = `
  :host { display: flex; flex-direction: column; height: 100%; }
  .nav { display: flex; gap: 6px; padding: 8px; border-bottom: 1px solid #e2e7ee; }
  .nav input {
    flex: 1; padding: 6px 11px; border: 1px solid #d0d7de; border-radius: 8px;
    font: 12px ui-monospace, SFMono-Regular, Menlo, monospace; outline: none; color: #24292f;
  }
  .nav input:focus { border-color: #0969da; }
  .nav button {
    all: unset; cursor: pointer; padding: 4px 10px; border-radius: 7px;
    font-size: 13px; color: #57606a;
  }
  .nav button:hover { background: #eaeef2; color: #24292f; }
  .nav button:disabled { opacity: .3; cursor: default; }
  .nav button:disabled:hover { background: none; color: #57606a; }
  .nav .wrap { position: relative; }
  .hist-drop {
    display: none; position: absolute; top: 100%; left: 0; margin-top: 4px;
    min-width: 220px; max-height: 300px; overflow-y: auto;
    background: #fff; border: 1px solid #d0d7de; border-radius: 8px;
    box-shadow: 0 8px 24px rgba(31,35,40,.12); z-index: 20;
    padding: 4px 0;
  }
  .hist-drop.open { display: block; }
  .hist-drop button {
    all: unset; display: block; width: 100%; padding: 5px 12px; font-size: 12px;
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    color: #24292f; cursor: pointer; box-sizing: border-box;
  }
  .hist-drop button:hover { background: #f6f8fa; }
  .hist-drop button.current { font-weight: 700; color: #0969da; }
  tab-group { flex: 1; min-height: 0; padding: 0 8px; }
  .page { height: 100%; }
  iframe { display: block; width: 100%; height: 100%; border: none; background: #fff; }
`;

const TPL = document.createElement('template');
TPL.innerHTML = `
  <style>${STYLE}</style>
  <div class="nav">
    <span class="wrap"><button id="back" title="back">&#9664;</button><div class="hist-drop" id="back-drop"></div></span>
    <span class="wrap"><button id="fwd" title="forward">&#9654;</button><div class="hist-drop" id="fwd-drop"></div></span>
    <button id="reload" title="reload">&#8635;</button>
    <input id="url" spellcheck="false">
    <button id="go" title="open in current tab">go</button>
    <button id="new" title="new tab">+</button>
  </div>
  <tab-group id="tabs" closable></tab-group>
`;

class BrowserFrame extends HTMLElement {
  #root; #tabs; #url; #backBtn; #fwdBtn;
  #backDrop; #fwdDrop;
  #longFired = false;
  #backTimer; #fwdTimer;

  constructor() {
    super();
    this.#root = this.attachShadow({ mode: 'open' });
    this.#root.appendChild(TPL.content.cloneNode(true));
    this.#tabs = this.#root.getElementById('tabs');
    this.#url = this.#root.getElementById('url');
    this.#backBtn = this.#root.getElementById('back');
    this.#fwdBtn = this.#root.getElementById('fwd');
    this.#backDrop = this.#root.getElementById('back-drop');
    this.#fwdDrop = this.#root.getElementById('fwd-drop');
  }

  get home() { return this.getAttribute('home') || '/'; }
  get persistKey() { return this.getAttribute('persist'); }

  #panels() { return [...this.#tabs.children].filter(c => c.hasAttribute('tab-label')); }
  #activePanel() { return this.#panels().find(p => !p.hidden); }

  #label(path) { return path.split('/').filter(Boolean).pop() || path; }

  #emit(name, detail) {
    this.dispatchEvent(new CustomEvent(name, { bubbles: true, composed: true, detail }));
  }

  connectedCallback() {
    this.#url.placeholder = this.home.replace(/^\/[^/]+/, '') + '…';

    this.#root.getElementById('go').addEventListener('click', () => this.navigate(this.#url.value));
    this.#url.addEventListener('keydown', (e) => { if (e.key === 'Enter') this.navigate(this.#url.value); });
    this.#root.getElementById('new').addEventListener('click', () => this.openTab(this.home));
    this.#root.getElementById('reload').addEventListener('click', () => this.#reload());

    this.#backBtn.addEventListener('click', () => {
      if (this.#longFired) { this.#longFired = false; return; }
      const p = this.#activePanel();
      if (p && p._histIdx > 0) this.#histGo(p, p._histIdx - 1);
    });
    this.#fwdBtn.addEventListener('click', () => {
      if (this.#longFired) { this.#longFired = false; return; }
      const p = this.#activePanel();
      if (p && p._histIdx < p._hist.length - 1) this.#histGo(p, p._histIdx + 1);
    });

    this.#initLongPress(this.#backBtn, 'back');
    this.#initLongPress(this.#fwdBtn, 'fwd');

    this.#root.addEventListener('click', (e) => {
      if (!e.target.closest('.hist-drop')) this.#closeDrops();
    }, true);

    this.#tabs.addEventListener('tg-close', (e) => {
      e.detail.panel.remove();
      if (this.#panels().length === 0) this.openTab(this.home);
      this.#save();
    });
    this.#tabs.addEventListener('tg-change', (e) => {
      const p = this.#panels()[e.detail.index];
      if (p) this.#url.value = p.dataset.path || '';
      this.#updateNav();
      this.#save();
    });

    this.#restore();
    this.#updateNav();
  }

  // -- public API --

  openTab(path) {
    const d = document.createElement('div');
    d.className = 'page';
    d.setAttribute('tab-label', this.#label(path));
    d.dataset.path = path;
    d._hist = [path];
    d._histIdx = 0;
    d._histNav = true;
    const f = document.createElement('iframe');
    f.src = path;
    this.#hookFrame(d, f);
    d.appendChild(f);
    this.#tabs.appendChild(d);
    this.#save();
    requestAnimationFrame(() => this.#tabs.select(this.#panels().length - 1));
  }

  navigate(path) {
    path = (path || '').trim();
    if (!path) return;
    if (!path.startsWith('/')) path = '/' + path;
    const cur = this.#activePanel();
    if (!cur) return this.openTab(path);
    cur.dataset.path = path;
    cur.setAttribute('tab-label', this.#label(path));
    cur._hist.splice(cur._histIdx + 1);
    cur._hist.push(path);
    cur._histIdx = cur._hist.length - 1;
    cur._histNav = true;
    cur.querySelector('iframe').src = path;
    this.#updateNav();
    this.#tabs.refresh();
    requestAnimationFrame(() => this.#tabs.select(this.#panels().indexOf(cur)));
  }

  // -- internals --

  #hookFrame(panel, f) {
    f.addEventListener('load', () => {
      let doc;
      try { doc = f.contentDocument; } catch (_) { return; }
      if (!doc) return;
      const loc = f.contentWindow.location;
      const path = loc.pathname + loc.search;
      panel.dataset.path = path;
      panel.setAttribute('tab-label', this.#label(path));
      if (!panel.hidden) this.#url.value = path;
      if (panel._histNav) {
        panel._histNav = false;
      } else if (path !== panel._hist[panel._histIdx]) {
        panel._hist.splice(panel._histIdx + 1);
        panel._hist.push(path);
        panel._histIdx = panel._hist.length - 1;
      }
      const vis = this.#panels().findIndex(x => !x.hidden);
      this.#tabs.refresh();
      if (vis >= 0) this.#tabs.select(vis);
      this.#updateNav();
      this.#save();
      this.#emit('bf-navigate', { path, tab: panel });

      doc.addEventListener('click', (e) => {
        const a = e.target && e.target.closest && e.target.closest('a[target="_blank"]');
        if (!a || !a.href) return;
        const u = new URL(a.href, loc.href);
        if (u.origin !== location.origin) return;
        e.preventDefault();
        this.openTab(u.pathname + u.search);
      }, true);
      f.contentWindow.open = (url) => {
        if (!url) return null;
        const u = new URL(url, loc.href);
        if (u.origin === location.origin) { this.openTab(u.pathname + u.search); return null; }
        return window.open(u.href);
      };

      // SPA pages (e.g. explorer) use pushState instead of full navigations,
      // so the iframe load event never fires. Monkey-patch to catch them.
      const win = f.contentWindow;
      const origPush = win.history.pushState.bind(win.history);
      const origReplace = win.history.replaceState.bind(win.history);
      const onSpa = () => {
        const p = win.location.pathname + win.location.search;
        panel.dataset.path = p;
        panel.setAttribute('tab-label', this.#label(p));
        if (!panel.hidden) this.#url.value = p;
        if (p !== panel._hist[panel._histIdx]) {
          panel._hist.splice(panel._histIdx + 1);
          panel._hist.push(p);
          panel._histIdx = panel._hist.length - 1;
        }
        this.#updateNav();
        this.#save();
        this.#emit('bf-navigate', { path: p, tab: panel });
      };
      win.history.pushState = function(state, title, url) { origPush(state, title, url); onSpa(); };
      win.history.replaceState = function(state, title, url) { origReplace(state, title, url); onSpa(); };
      win.addEventListener('popstate', onSpa);
    });
  }

  #histGo(panel, idx) {
    if (!panel || idx < 0 || idx >= panel._hist.length) return;
    panel._histNav = true;
    panel._histIdx = idx;
    const path = panel._hist[idx];
    panel.dataset.path = path;
    panel.setAttribute('tab-label', this.#label(path));
    panel.querySelector('iframe').src = path;
    this.#updateNav();
  }

  #reload() {
    const p = this.#activePanel();
    if (!p) return;
    p._histNav = true;
    const f = p.querySelector('iframe');
    try { f.contentWindow.location.reload(); } catch (_) { f.src = f.src; }
  }

  #updateNav() {
    const p = this.#activePanel();
    this.#backBtn.disabled = !p || p._histIdx <= 0;
    this.#fwdBtn.disabled = !p || p._histIdx >= p._hist.length - 1;
  }

  // -- long-press history dropdown --

  #closeDrops() {
    this.#backDrop.classList.remove('open');
    this.#fwdDrop.classList.remove('open');
  }

  #showDrop(drop, entries, onPick) {
    this.#closeDrops();
    drop.textContent = '';
    entries.forEach((path, i) => {
      const b = document.createElement('button');
      b.textContent = path;
      b.addEventListener('click', () => { this.#closeDrops(); onPick(i); });
      drop.appendChild(b);
    });
    drop.classList.add('open');
  }

  #initLongPress(btn, dir) {
    let timer;
    btn.addEventListener('mousedown', () => {
      timer = setTimeout(() => {
        this.#longFired = true;
        const p = this.#activePanel();
        if (!p) return;
        if (dir === 'back' && p._histIdx > 0) {
          const entries = p._hist.slice(0, p._histIdx).reverse();
          this.#showDrop(this.#backDrop, entries, (i) => this.#histGo(p, p._histIdx - 1 - i));
        } else if (dir === 'fwd' && p._histIdx < p._hist.length - 1) {
          const entries = p._hist.slice(p._histIdx + 1);
          this.#showDrop(this.#fwdDrop, entries, (i) => this.#histGo(p, p._histIdx + 1 + i));
        }
      }, 400);
    });
    btn.addEventListener('mouseup', () => clearTimeout(timer));
    btn.addEventListener('mouseleave', () => clearTimeout(timer));
  }

  // -- session persistence --

  #save() {
    const key = this.persistKey;
    if (!key) return;
    try {
      localStorage.setItem(key, JSON.stringify({
        tabs: this.#panels().map(p => ({ path: p.dataset.path, hist: p._hist, histIdx: p._histIdx })),
        active: this.#panels().findIndex(p => !p.hidden),
      }));
    } catch (_) {}
  }

  #restore() {
    const key = this.persistKey;
    if (!key) { this.openTab(this.home); return; }
    let session = null;
    try { session = JSON.parse(localStorage.getItem(key) || 'null'); } catch (_) {}
    if (!session) { this.openTab(this.home); return; }
    const tabs = session.tabs || (session.paths || []).map(p => ({ path: p }));
    if (!tabs.length) { this.openTab(this.home); return; }
    tabs.forEach(t => {
      this.openTab(t.path || this.home);
      if (t.hist) {
        const panel = this.#panels()[this.#panels().length - 1];
        panel._hist = t.hist;
        panel._histIdx = t.histIdx ?? t.hist.length - 1;
      }
    });
    this.#updateNav();
    requestAnimationFrame(() =>
      this.#tabs.select(Math.min(session.active >= 0 ? session.active : 0, this.#panels().length - 1)));
  }
}

customElements.define('browser-frame', BrowserFrame);
