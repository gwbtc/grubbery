// <file-grid> — an icon grid view for files and directories.
//
// USAGE
//   const fg = document.querySelector('file-grid');
//   fg.items = [ { name: 'foo/', kind: 'dir', ... }, ... ];
//   fg.actions = (item) => [
//     { label: 'Rename', action: 'rename' },
//     { label: 'Delete', action: 'delete', danger: true },
//   ];
//   fg.addEventListener('ft-action', e => {
//     // e.detail = { action: 'rename', item: {...} }
//   });
//   fg.addEventListener('ft-navigate', e => {
//     // e.detail = { item: {...}, href: '...' }
//   });
//
// CONTRACT
//   properties:
//     items     Array of item objects. Each needs at least `name` and
//               `kind` ('dir'|'file'|'symlink'|'boom'). Dirs sort first.
//     actions   Function(item) => Array of { label, action, ?danger }.
//     glyphs    Object mapping extension/kind to emoji glyphs.
//               Special keys: dir, dir-app, badge, file (fallback).
//     icon      Function(item) => url string | null. Custom icon image.
//     label     Function(item) => string. Display name override.
//     baseHref  String. URL prefix for navigation hrefs.
//   attributes:
//     layout    "flow" (default, wrapped grid) | "free" (absolute drag)
//     persist   localStorage key for free-layout positions
//   events (all bubbling + composed):
//     ft-action   { action, item }  — a context/action was triggered
//     ft-navigate { item, href }    — an icon was double-clicked

const STYLE = `
  :host { display: block; position: relative; }
  :host([layout="free"]) { position: absolute; inset: 0; }
  .icon {
    width: 84px;
    display: flex; flex-direction: column; align-items: center; gap: 3px;
    padding: 8px 4px 6px; border-radius: 10px;
    cursor: default; user-select: none; text-align: center;
  }
  :host(:not([layout="free"])) .icon {
    display: inline-flex; vertical-align: top; margin: 4px;
  }
  :host([layout="free"]) .icon { position: absolute; }
  .icon:hover { background: rgba(31,35,40,.05); }
  /* neutral, not blue: blue is the selected PANE's colour, and a blue
     tile inside a pane reads as a second, competing selection */
  .icon.sel { background: var(--fg-sel-bg, #eaeef2); }
  .gl { font-size: 34px; line-height: 1.15; position: relative; }
  .gl .badge { position: absolute; right: -7px; bottom: -3px; font-size: 15px; }
  .gl img { width: 40px; height: 40px; object-fit: contain; display: block; }
  .lb {
    font-size: 11px; line-height: 1.25; color: #3b434b; max-width: 80px;
    overflow: hidden; display: -webkit-box; -webkit-line-clamp: 2;
    -webkit-box-orient: vertical; overflow-wrap: anywhere;
  }
  .lb.unnamed { color: #8b949e; font-style: italic; }
  .loading {
    display: flex; align-items: center; justify-content: center; gap: 8px;
    font-size: 12px; color: #8b949e; user-select: none;
    padding: 28px 18px; grid-column: 1 / -1;
  }
  .loading .d { animation: dpulse 1.1s ease-in-out infinite; }
  @keyframes dpulse { 50% { opacity: .2; } }
`;

const TPL = document.createElement('template');
TPL.innerHTML = `<style>${STYLE}</style><div id="grid"></div>`;

const DEFAULT_GLYPHS = {
  dir: '\u{1F4C1}', 'dir-app': '\u{1F4C1}', badge: '☀️',
  file: '\u{1F4C4}', md: '\u{1F4DD}', txt: '\u{1F4C4}',
  json: '\u{1F527}', hoon: '\u{1F300}', js: '\u{1F4DC}',
  html: '\u{1F310}', css: '\u{1F3A8}', svg: '\u{1F5BC}️',
  png: '\u{1F5BC}️', jpg: '\u{1F5BC}️', gif: '\u{1F5BC}️',
  sig: '✳️', csv: '\u{1F4CA}', pdf: '\u{1F4D5}',
};

class FileGrid extends HTMLElement {
  #items = [];
  #actionsFn = null;
  #glyphs = DEFAULT_GLYPHS;
  #iconFn = null;
  #labelFn = null;
  #baseHref = '';
  #grid; #keys = false;

  constructor() {
    super();
    this.attachShadow({ mode: 'open' });
    this.shadowRoot.appendChild(TPL.content.cloneNode(true));
    this.#grid = this.shadowRoot.getElementById('grid');
  }

  set items(v) { this.#items = v || []; this.#render(); }
  get items() { return this.#items; }

  set actions(fn) { this.#actionsFn = fn; }
  get actions() { return this.#actionsFn; }

  set glyphs(v) { this.#glyphs = v || DEFAULT_GLYPHS; this.#render(); }
  get glyphs() { return this.#glyphs; }

  set icon(fn) { this.#iconFn = fn; this.#render(); }
  get icon() { return this.#iconFn; }

  set label(fn) { this.#labelFn = fn; this.#render(); }
  get label() { return this.#labelFn; }

  set baseHref(v) { this.#baseHref = v || ''; }
  get baseHref() { return this.#baseHref; }

  #emit(name, detail) {
    this.dispatchEvent(new CustomEvent(name, { bubbles: true, composed: true, detail }));
  }

  showLoading() {
    this.#grid.innerHTML = '<div class="loading"><span class="d">◆</span> loading…</div>';
  }

  #isFree() { return this.getAttribute('layout') === 'free'; }
  #persistKey() { return this.getAttribute('persist') || ''; }

  #sorted() {
    return [...this.#items].sort((a, b) => {
      if (a.kind === 'dir' && b.kind !== 'dir') return -1;
      if (b.kind === 'dir' && a.kind !== 'dir') return 1;
      const x = a.name ?? '', y = b.name ?? '';
      return x < y ? -1 : x > y ? 1 : 0;
    });
  }

  #render() {
    this.#grid.textContent = '';
    const free = this.#isFree();
    const pos = free && this.#persistKey()
      ? JSON.parse(localStorage.getItem(this.#persistKey()) || '{}')
      : {};
    const rows = free ? Math.max(1, Math.floor((innerHeight - 44 - 24) / 104)) : 0;
    const sorted = this.#sorted();

    // empty state — a genuinely empty directory reads as empty, not broken
    if (!sorted.length) {
      this.#grid.innerHTML = '<div class="loading"><span class="d">◆</span> empty directory</div>';
      return;
    }

    sorted.forEach((item, i) => {
      const el = document.createElement('div');
      el.className = 'icon';
      el.__item = item;

      const gl = document.createElement('div');
      gl.className = 'gl';
      const customIcon = this.#iconFn ? this.#iconFn(item) : null;
      if (customIcon) {
        const img = document.createElement('img');
        img.src = customIcon;
        gl.appendChild(img);
      } else {
        const g = this.#glyphs;
        const isApp = item.kind === 'dir' && (item.icon || item.tile);
        if (item.kind === 'dir') {
          gl.textContent = isApp ? (g['dir-app'] || g.dir) : (g.dir || '\u{1F4C1}');
          if (isApp) {
            const b = document.createElement('span');
            b.className = 'badge';
            b.textContent = g.badge || '☀️';
            gl.appendChild(b);
          }
        } else {
          const ext = item.name.includes('.') ? item.name.split('.').pop().toLowerCase() : '';
          gl.textContent = g[ext] || g.file || '\u{1F4C4}';
        }
      }

      const lb = document.createElement('div');
      lb.className = 'lb';
      const lab = this.#labelFn ? this.#labelFn(item) : item.name;
      // a grub may have no name (dill's default session is the empty one):
      // an empty label is an invisible target, so it is named for the reader
      if (lab === '' || lab == null) { lb.textContent = '[unnamed]'; lb.classList.add('unnamed'); }
      else lb.textContent = lab;
      // the label clamps to two lines; hover shows the full name
      el.title = item.name || '[unnamed]';

      el.append(gl, lb);

      if (free) {
        const p = pos[item.name] ||
          { x: 18 + Math.floor(i / rows) * 96, y: 18 + (i % rows) * 104 };
        el.style.left = p.x + 'px';
        el.style.top = p.y + 'px';
        this.#wireDrag(el, item);
      }

      this.#wireClick(el, item);
      this.#grid.appendChild(el);
    });
    this.#attachKeys();
  }

  #wireDrag(el, item) {
    el.addEventListener('pointerdown', (e) => {
      if (e.button !== 0) return;
      this.#grid.querySelectorAll('.icon.sel').forEach(x => x.classList.remove('sel'));
      el.classList.add('sel');
      const sx = e.clientX - el.offsetLeft, sy = e.clientY - el.offsetTop;
      el.setPointerCapture(e.pointerId);
      const onMove = (ev) => {
        el.style.left = Math.max(0, ev.clientX - sx) + 'px';
        el.style.top = Math.max(0, ev.clientY - sy) + 'px';
      };
      el.addEventListener('pointermove', onMove);
      el.addEventListener('pointerup', () => {
        el.removeEventListener('pointermove', onMove);
        const key = this.#persistKey();
        if (key) {
          const pos = JSON.parse(localStorage.getItem(key) || '{}');
          pos[item.name] = { x: el.offsetLeft, y: el.offsetTop };
          try { localStorage.setItem(key, JSON.stringify(pos)); } catch (_) {}
        }
      }, { once: true });
    });
  }

  // one open path for the mouse and the keyboard
  #open(el, item, mods) {
    const href = this.#baseHref ? this.#baseHref + '/' + item.name : item.name;
    this.#emit('ft-navigate', { item, href, mods: mods || { meta: false, ctrl: false, shift: false, alt: false } });
  }

  // ← ↑ → ↓ move the selection, Enter opens it. Nothing else: the same
  // minimal vocabulary <tree-view> uses, and it reuses .sel, the class a
  // click and a drag already set, rather than inventing a second cursor.
  //
  // Movement is measured, not assumed: the grid is auto-fill (and in free
  // mode the tiles are absolutely positioned and draggable), so the column
  // count is whatever the layout happens to be. Up/down pick the nearest
  // tile by x in the adjacent visual row. getBoundingClientRect, not
  // offsetTop/offsetLeft -- offsetParent is null inside a shadow root, so
  // those offsets are not meaningful here.
  #attachKeys() {
    if (this.#keys) return;
    this.#keys = true;
    this.setAttribute('data-focus', '');          // gmux +focusContent finds this; querySelector cannot cross the shadow boundary
    const g = this.#grid;
    if (!g.hasAttribute('tabindex')) g.tabIndex = 0;
    g.addEventListener('keydown', (e) => {
      if (e.metaKey || e.ctrlKey || e.altKey) return;
      const k = e.key;
      let used = true;
      if (k === 'ArrowLeft' || k === 'ArrowRight' || k === 'ArrowUp' || k === 'ArrowDown') {
        this.#move(k.slice(5).toLowerCase());
      } else if (k === 'Enter') {
        const cur = g.querySelector('.icon.sel') || this.#tiles()[0];
        if (cur) { this.#point(cur); if (cur.__item) this.#open(cur, cur.__item, { meta: false, ctrl: false, shift: e.shiftKey, alt: false }); }
      } else used = false;
      if (used) { e.preventDefault(); e.stopPropagation(); }
    });
    g.addEventListener('focus', () => {
      if (!g.querySelector('.icon.sel')) { const t = this.#tiles(); if (t.length) this.#point(t[0]); }
    });
  }
  #tiles() { return Array.from(this.#grid.querySelectorAll('.icon')); }
  #point(el) {
    this.#grid.querySelectorAll('.icon.sel').forEach((x) => x.classList.remove('sel'));
    if (el) { el.classList.add('sel'); el.scrollIntoView({ block: 'nearest' }); }
  }
  #move(dir) {
    const t = this.#tiles();
    if (!t.length) return;
    const cur = this.#grid.querySelector('.icon.sel');
    const i = t.indexOf(cur);
    if (i < 0) { this.#point(t[0]); return; }
    const r = t.map((e) => e.getBoundingClientRect());
    const laidOut = r.some((x) => x.width || x.height);
    // left/right walk the flat order; so does everything when the grid is
    // unrendered, so the keys never go dead for a layout reason
    if (!laidOut || dir === 'left' || dir === 'right') {
      const n = i + ((dir === 'right' || dir === 'down') ? 1 : -1);
      if (n >= 0 && n < t.length) this.#point(t[n]);
      return;
    }
    const cx = r[i].left, cy = r[i].top;
    const ahead = t.map((e, j) => ({ e, x: r[j].left, y: r[j].top }))
      .filter((o) => (dir === 'down' ? o.y > cy + 1 : o.y < cy - 1));
    if (!ahead.length) return;
    const ys = ahead.map((o) => o.y);
    const row = dir === 'down' ? Math.min.apply(null, ys) : Math.max.apply(null, ys);
    const band = ahead.filter((o) => Math.abs(o.y - row) < 2);
    band.sort((a, b) => Math.abs(a.x - cx) - Math.abs(b.x - cx));
    this.#point(band[0].e);
  }

  // gmux focuses the host; the keys live on the shadow grid.
  focus(o) {
    if (this.#grid) this.#grid.focus(o);
    else HTMLElement.prototype.focus.call(this, o);
  }

  #wireClick(el, item) {
    if (!this.#isFree()) {
      el.addEventListener('click', () => {
        this.#grid.querySelectorAll('.icon.sel').forEach(x => x.classList.remove('sel'));
        el.classList.add('sel');
      });
    }
    el.addEventListener('dblclick', (e) => {
      this.#open(el, item, { meta: e.metaKey, ctrl: e.ctrlKey, shift: e.shiftKey, alt: e.altKey });
    });
  }
}

customElements.define('file-grid', FileGrid);
