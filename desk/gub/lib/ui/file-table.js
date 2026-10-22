// TODO: icon/thumbnail column — file-type icons (folder, code, image, doc)
// or actual image thumbnails for raster files.
//
// <file-table> — a sortable file/directory listing table with row actions.
//
// USAGE
//   const ft = document.querySelector('file-table');
//   ft.columns = [
//     { key: 'name', label: 'Name', render: (v, item) => ..., link: item => url },
//     { key: 'blot', label: 'Blot / Neck' },
//     { key: 'size', label: 'Size', format: v => fmtSize(v) },
//     { key: 'modified', label: 'Modified' },
//   ];
//   ft.items = [ { name: 'foo/', kind: 'dir', ... }, ... ];
//   ft.actions = (item) => [
//     { label: 'Rename', action: 'rename' },
//     { label: 'Delete', action: 'delete', danger: true },
//   ];
//   ft.addEventListener('ft-action', e => {
//     // e.detail = { action: 'rename', item: {...} }
//   });
//   ft.addEventListener('ft-navigate', e => {
//     // e.detail = { item: {...}, href: '...' }
//   });
//
// CONTRACT
//   properties:
//     items     Array of row objects. Each should have at least `name` and
//               `kind` ('dir'|'file'|'symlink'|'boom'). Dirs sort first.
//     columns   Array of { key, label, ?format, ?link, ?cls, ?decorate }.
//               key reads from the item; label is the header text;
//               format(value, item) returns display text; link(item) returns
//               an href; cls is an extra class on the td; decorate(cell, item)
//               can append extra DOM to a built cell.
//     actions   Function(item) => Array of { label, action, ?danger }.
//               Omit to hide the actions column.
//     parentHref  String. If set, shows a ../ row linking here.
//   attributes:
//     sort-key  initial sort column key (default: first column)
//     sort-dir  '1' (asc, default) or '-1' (desc)
//   events (all bubbling + composed):
//     ft-action   { action, item }  — a row action was clicked
//     ft-navigate { item, href }    — a name link was clicked (preventDefault to handle)
//     ft-sort     { key, dir }      — sort changed

const STYLE = `
  :host { display: block; }
  table { border-collapse: collapse; width: 100%; }
  th, td { text-align: left; padding: 7px 10px; }
  th {
    position: sticky; top: var(--ft-header-top, 0); background: #fff; z-index: 4;
    font-size: 10px; font-weight: 600; text-transform: uppercase;
    letter-spacing: .05em; color: #8b949e;
    border-bottom: 1px solid #d0d7de;
    cursor: pointer; user-select: none; white-space: nowrap;
  }
  th:hover { color: #24292f; }
  th .arr { opacity: .35; }
  th.sorted .arr { opacity: 1; }
  td {
    border-bottom: 1px solid #eef1f4; font-size: 13px;
    overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
  }
  tr:hover td { background: #f6f8fa; }
  /* neutral, not the pane accent: gmux outlines the SELECTED PANE in
     --ps-accent, so a blue row inside one reads as a second selection */
  tr.sel td { background: #f6f8fa; }
  tr.sel td:first-child { box-shadow: inset 3px 0 0 var(--ps-cursor, #8c959f); }
  :host(:focus) tr.sel td { background: #eaeef2; }
  :host { outline: none; }
  td.mono {
    font: 12px ui-monospace, SFMono-Regular, Menlo, monospace;
    color: #57606a;
  }
  td.mono a { font: inherit; }
  a { color: #0969da; text-decoration: none; }
  a:hover { text-decoration: underline; }
  a.name {
    font: 12.5px ui-monospace, SFMono-Regular, Menlo, monospace;
  }
  td.acts {
    white-space: nowrap; text-align: right;
    overflow: visible; text-overflow: clip;
  }
  td.acts .dots {
    all: unset; cursor: pointer; padding: 1px 9px; border-radius: 7px;
    font-size: 15px; color: #57606a; opacity: 0; transition: opacity .1s;
  }
  tr:hover td.acts .dots,
  td.acts drop-menu[open] .dots { opacity: 1; }
  td.acts .dots:hover { background: #eaeef2; color: #24292f; }
  .sym { color: #8b949e; font-size: 12px; }
  .boom { color: #cf222e; font-weight: 700; cursor: pointer; margin-left: 5px; }
  .dload { display: inline-block; animation: dpulse 1.1s ease-in-out infinite; }
  @keyframes dpulse { 50% { opacity: .2; } }
  .loading td { color: #8b949e; }
`;

const TPL = document.createElement('template');
TPL.innerHTML = `
  <style>${STYLE}</style>
  <table>
    <thead><tr id="hdr"></tr></thead>
    <tbody id="rows"></tbody>
  </table>
`;

class FileTable extends HTMLElement {
  #items = [];
  #columns = [];
  #actionsFn = null;
  #parentHref = null;
  #sortKey = '';
  #sortDir = 1;
  #hdr; #rows;

  constructor() {
    super();
    this.attachShadow({ mode: 'open' });
    this.shadowRoot.appendChild(TPL.content.cloneNode(true));
    this.#hdr = this.shadowRoot.getElementById('hdr');
    this.#rows = this.shadowRoot.getElementById('rows');
    // the table is a navigator: the keyboard lands on it (data-nk is what
    // the pane host looks for) and the navigator keys apply:
    //   ↓ ↑ j k      move the cursor      Enter   open the row
    //   ⇧Enter       open beside          ← h     up to the parent dir
    //   → l          open a dir row       Home End  first / last
    //   a letter     type-ahead           Esc     clear
    // (attributes are set in connectedCallback: a constructor may not)
    this.addEventListener('keydown', (e) => this.#key(e));
    this.addEventListener('focus', () => { if (!this.#cur) this.#select(this.#rowList()[0] || null); });
  }
  #cur = null;            // the selected row (a <tr>)
  #ahead = ''; #aheadAt = 0;
  #rowList() { return Array.from(this.#rows.querySelectorAll('tr:not(.loading)')); }
  #select(tr) {
    if (this.#cur) { this.#cur.classList.remove('sel'); this.#cur.removeAttribute('aria-selected'); }
    this.#cur = tr || null;
    if (this.#cur) { this.#cur.classList.add('sel'); this.#cur.setAttribute('aria-selected', 'true'); this.#cur.scrollIntoView({ block: 'nearest' }); }
  }
  #open(tr, mods) {
    if (!tr) return;
    const a = tr.querySelector('a.name'); if (!a) return;
    const href = a.getAttribute('href');
    this.#emit('ft-navigate', { item: tr.__item || null, href, column: 'name', mods: mods || { meta: false, ctrl: false, shift: false, alt: false } });
  }
  #key(e) {
    if (e.metaKey || e.ctrlKey || e.altKey) return;                       // chords are never the table's
    const rows = this.#rowList(); if (!rows.length) return;
    const i = rows.indexOf(this.#cur), k = e.key;
    let used = true;
    const to = (n) => this.#select(rows[Math.max(0, Math.min(rows.length - 1, n))]);
    if (k === 'ArrowDown' || k === 'j') to(i < 0 ? 0 : i + 1);
    else if (k === 'ArrowUp' || k === 'k') to(i < 0 ? rows.length - 1 : i - 1);
    else if (k === 'Home') to(0);
    else if (k === 'End') to(rows.length - 1);
    else if (k === 'Enter') { if (!this.#cur) to(0); this.#open(this.#cur, { meta: e.shiftKey, ctrl: false, shift: e.shiftKey, alt: false }); }
    else if (k === 'ArrowRight' || k === 'l') { if (this.#cur && this.#cur.__item && this.#cur.__item.kind === 'dir') this.#open(this.#cur); else used = false; }
    else if (k === 'ArrowLeft' || k === 'h') { if (this.#parentHref) this.#emit('ft-navigate', { item: null, href: this.#parentHref, mods: { meta: false, ctrl: false, shift: false, alt: false } }); else used = false; }
    else if (k === 'Escape') { if (this.#ahead) this.#ahead = ''; else this.#select(null); }
    else if (k.length === 1 && /\S/.test(k)) {
      const now = Date.now(); this.#ahead = (now - this.#aheadAt < 700 ? this.#ahead : '') + k.toLowerCase(); this.#aheadAt = now;
      const start = i < 0 ? 0 : (this.#ahead.length === 1 ? i + 1 : i);
      for (let n = 0; n < rows.length; n++) { const r = rows[(start + n) % rows.length]; const nm = (r.__item && r.__item.name) || r.textContent.trim(); if (nm.toLowerCase().indexOf(this.#ahead) === 0) { this.#select(r); break; } }
    }
    else used = false;
    if (used) { e.preventDefault(); e.stopPropagation(); }
  }

  connectedCallback() {
    if (!this.hasAttribute('tabindex')) this.tabIndex = 0;
    if (!this.hasAttribute('data-nk')) this.setAttribute('data-nk', '');
    if (!this.hasAttribute('role')) this.setAttribute('role', 'listbox');
    if (!this.#sortKey && this.hasAttribute('sort-key'))
      this.#sortKey = this.getAttribute('sort-key');
    if (this.hasAttribute('sort-dir'))
      this.#sortDir = parseInt(this.getAttribute('sort-dir')) || 1;
  }

  set items(v) { this.#items = v || []; this.#render(); }
  get items() { return this.#items; }

  set columns(v) {
    this.#columns = v || [];
    if (!this.#sortKey && v.length) this.#sortKey = v[0].key;
    this.#renderHeader();
    this.#render();
  }
  get columns() { return this.#columns; }

  set actions(fn) { this.#actionsFn = fn; this.#renderHeader(); this.#render(); }
  get actions() { return this.#actionsFn; }

  set parentHref(v) { this.#parentHref = v; this.#render(); }
  get parentHref() { return this.#parentHref; }

  showLoading() {
    this.#rows.innerHTML =
      '<tr class="loading"><td colspan="' + (this.#columns.length + (this.#actionsFn ? 1 : 0)) +
      '" style="padding:28px 12px;text-align:center"><span class="dload">◆</span> loading…</td></tr>';
  }

  #emit(name, detail) {
    this.dispatchEvent(new CustomEvent(name, { bubbles: true, composed: true, detail }));
  }

  #renderHeader() {
    this.#hdr.textContent = '';
    for (const col of this.#columns) {
      const th = document.createElement('th');
      th.dataset.k = col.key;
      th.textContent = col.label + ' ';
      if (col.width) th.style.width = col.width;
      const arr = document.createElement('span');
      arr.className = 'arr';
      arr.innerHTML = col.key === this.#sortKey
        ? (this.#sortDir === 1 ? '&#8593;' : '&#8595;')
        : '&#8597;';
      th.appendChild(arr);
      if (col.key === this.#sortKey) th.classList.add('sorted');
      th.addEventListener('click', () => {
        if (this.#sortKey === col.key) this.#sortDir = -this.#sortDir;
        else { this.#sortKey = col.key; this.#sortDir = 1; }
        this.#emit('ft-sort', { key: this.#sortKey, dir: this.#sortDir });
        this.#renderHeader();
        this.#render();
      });
      this.#hdr.appendChild(th);
    }
    if (this.#actionsFn) {
      const th = document.createElement('th');
      th.style.width = '48px';
      this.#hdr.appendChild(th);
    }
  }

  #sorted() {
    const col = this.#columns.find(c => c.key === this.#sortKey) || this.#columns[0];
    if (!col) return this.#items;
    const key = col.key;
    const dir = this.#sortDir;
    return [...this.#items].sort((a, b) => {
      if (a.kind === 'dir' && b.kind !== 'dir') return -1;
      if (b.kind === 'dir' && a.kind !== 'dir') return 1;
      const x = a[key] ?? '', y = b[key] ?? '';
      return (x < y ? -1 : x > y ? 1 : 0) * dir;
    });
  }

  #td(cls, content) {
    const t = document.createElement('td');
    if (cls) t.className = cls;
    if (content instanceof Node) t.appendChild(content);
    else t.textContent = content;
    const full = t.textContent.trim();
    if (full && full !== '–') t.title = full;
    return t;
  }

  #render() {
    const keep = this.#cur && this.#cur.__item ? this.#cur.__item.name : (this.#cur ? '..' : null);   // the cursor survives a redraw, by name
    this.#cur = null;
    this.#rows.textContent = '';
    // parent row
    if (this.#parentHref) {
      const tr = document.createElement('tr');
      const a = document.createElement('a');
      a.className = 'name';
      a.href = this.#parentHref;
      a.textContent = '../';
      a.addEventListener('click', (e) => {
        e.preventDefault();
        this.#emit('ft-navigate', { item: null, href: this.#parentHref, mods: { meta: e.metaKey, ctrl: e.ctrlKey, shift: e.shiftKey, alt: e.altKey } });
      });
      tr.appendChild(this.#td('', a));
      for (let i = 1; i < this.#columns.length; i++)
        tr.appendChild(this.#td('mono', '–'));
      if (this.#actionsFn) tr.appendChild(this.#td('acts', ''));
      this.#rows.appendChild(tr);
    }
    const rows = this.#sorted();
    for (const item of rows)
      this.#rows.appendChild(this.#row(item));
    if (keep != null) { const back = this.#rowList().find((r) => (r.__item ? r.__item.name : '..') === keep); if (back) this.#select(back); }
    // empty state — so a genuinely empty directory reads as empty, not broken
    if (!rows.length) {
      const tr = document.createElement('tr');
      tr.className = 'loading';
      const td = document.createElement('td');
      td.colSpan = this.#columns.length + (this.#actionsFn ? 1 : 0);
      td.textContent = 'empty directory';
      tr.appendChild(td);
      this.#rows.appendChild(tr);
    }
  }

  #row(item) {
    const tr = document.createElement('tr');
    tr.__item = item;
    for (const col of this.#columns) {
      const raw = item[col.key];
      const display = col.format ? col.format(raw, item) : (raw ?? '–');

      if (col.link) {
        const href = col.link(item);
        if (href) {
          const a = document.createElement('a');
          a.className = 'name';
          a.href = href;
          a.textContent = display;
          a.addEventListener('click', (e) => {
            e.preventDefault();
            this.#emit('ft-navigate', { item, href, column: col.key, mods: { meta: e.metaKey, ctrl: e.ctrlKey, shift: e.shiftKey, alt: e.altKey } });
          });
          const cell = this.#td(col.cls || '', a);
          if (col.decorate) col.decorate(cell, item);
          tr.appendChild(cell);
          continue;
        }
      }
      const cell = this.#td(col.cls || 'mono', display);
      if (col.decorate) col.decorate(cell, item);
      tr.appendChild(cell);
    }
    // actions column
    if (this.#actionsFn) {
      const acts = this.#actionsFn(item);
      if (acts && acts.length) {
        const cell = this.#td('acts', '');
        cell.removeAttribute('title');
        const dm = document.createElement('drop-menu');
        dm.setAttribute('align', 'end');
        const trig = document.createElement('button');
        trig.slot = 'trigger';
        trig.className = 'dots';
        trig.textContent = '⋯';
        trig.title = 'actions';
        const buttons = acts.map(a => {
          const b = document.createElement('button');
          if (a.danger) b.classList.add('danger');
          b.textContent = a.label;
          b.addEventListener('click', () => this.#emit('ft-action', { action: a.action, item }));
          return b;
        });
        dm.append(trig, ...buttons);
        cell.appendChild(dm);
        tr.appendChild(cell);
      } else {
        tr.appendChild(this.#td('acts', ''));
      }
    }
    return tr;
  }
}

customElements.define('file-table', FileTable);
