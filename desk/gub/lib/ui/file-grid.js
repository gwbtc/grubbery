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
  .icon.sel { background: rgba(9,105,218,.12); }
  .gl { font-size: 34px; line-height: 1.15; position: relative; }
  .gl .badge { position: absolute; right: -7px; bottom: -3px; font-size: 15px; }
  .gl img { width: 40px; height: 40px; object-fit: contain; display: block; }
  .lb {
    font-size: 11px; line-height: 1.25; color: #3b434b; max-width: 80px;
    overflow: hidden; display: -webkit-box; -webkit-line-clamp: 2;
    -webkit-box-orient: vertical; overflow-wrap: anywhere;
  }
  .loading {
    display: flex; align-items: center; gap: 8px;
    font-size: 12px; color: #8b949e; user-select: none;
    padding: 18px;
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
  #grid;

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
      lb.textContent = this.#labelFn ? this.#labelFn(item) : item.name;

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

  #wireClick(el, item) {
    if (!this.#isFree()) {
      el.addEventListener('click', () => {
        this.#grid.querySelectorAll('.icon.sel').forEach(x => x.classList.remove('sel'));
        el.classList.add('sel');
      });
    }
    el.addEventListener('dblclick', () => {
      const href = this.#baseHref
        ? this.#baseHref + '/' + item.name
        : item.name;
      this.#emit('ft-navigate', { item, href });
    });
  }
}

customElements.define('file-grid', FileGrid);
