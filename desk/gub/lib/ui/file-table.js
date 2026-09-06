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
  }

  connectedCallback() {
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
      '"><span class="dload">◆</span> loading…</td></tr>';
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
        this.#emit('ft-navigate', { item: null, href: this.#parentHref });
      });
      tr.appendChild(this.#td('', a));
      for (let i = 1; i < this.#columns.length; i++)
        tr.appendChild(this.#td('mono', '–'));
      if (this.#actionsFn) tr.appendChild(this.#td('acts', ''));
      this.#rows.appendChild(tr);
    }
    for (const item of this.#sorted())
      this.#rows.appendChild(this.#row(item));
  }

  #row(item) {
    const tr = document.createElement('tr');
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
            this.#emit('ft-navigate', { item, href });
          });
          const cell = this.#td(col.cls || '', a);
          if (item.kind === 'symlink' && col.key === 'name' && item.target) {
            const sym = document.createElement('span');
            sym.className = 'sym';
            sym.textContent = ' → ' + item.target;
            cell.appendChild(sym);
          }
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
