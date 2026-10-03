// <tree-view> — a shared, collapsible file/dir tree, shadow DOM + CSS
// custom properties for theming (same contract as <tab-group>/<file-table>
// in this kit). The host loads the whole tree up front, however it likes
// (one server document, an in-memory file list, …), and getChildren
// answers from that local data — this component never fetches on its own,
// so nothing is ever "still loading" once it's on screen. Rows start
// collapsed; only the data is front-loaded, not the visible state. Whether
// directories navigate anywhere is the host's call: give onOpenDir to make
// a dir's name a real link, or leave it unset so the whole row just toggles.
//
// USAGE
//   <tree-view id="t"></tree-view>
//   t.root = '/some/path';                  // this level's own key
//   t.getChildren = function(path) { ... };   // → items[], from local data
//   t.onOpenFile = function(item, path) { ... };
//   t.onOpenDir = function(item, path) { ... };   // omit: dirs don't
//                                                  // navigate, the row toggles
//   t.decorateRow = function(row, item, path, isDir) { ... };  // optional
//   t.persistKey = 'my-app-tree:' + scopeId;
//   t.upRow = { label: '../', href: parentUrl };  // optional, root level only
//   t.render(rootItems);     // (re)draw the root level from scratch
//   t.markActive(path);      // toggle .sel onto that file row (or null)
//   t.expandAll();           // opens every dir (returns a promise)
//   t.collapseAll();
//   t.anyOpen                // getter
//
// Each item needs at least { name, isDir }; anything else on it is yours —
// decorateRow gets the original item back untouched (for a right-click
// payload, a delete button, whatever the host needs). The row element it
// receives is a real DOM node — properties set on it (a right-click payload,
// say) and composed events (click, contextmenu) both cross the shadow
// boundary normally, so a document-level listener using composedPath()
// still finds it.
//
// CSS VARS (theme in), house-light defaults:
//   --tv-row-padding     one row's padding (default 7px 8px)
//   --tv-indent           a dir's children indent (default 14px)
//   --tv-caret-size        the caret's square hit target (default 20px)
//   --tv-caret-color       idle caret color (default #8b949e)
//   --tv-caret-hover       hovered caret color (default #57606a)
//   --tv-name-font         file/dir name font (default 13px ui-monospace…)
//   --tv-name-color        a file's (and, if onOpenDir is set, a dir's) name
//                          color (default #0969da)
//   --tv-dir-color         a dir's name color when it's NOT a link — no
//                          onOpenDir set (default #57606a)
//   --tv-hover-bg          row hover background (default #f6f8fa)
//   --tv-sel-bg / --tv-sel-color   the active file row (default #ddf4ff /
//                          #0969da)
//   --tv-loading-color     the "loading…" placeholder (default #8b949e) —
//                          only ever briefly visible on first expand, before
//                          the background prefetch has caught up with a slow
//                          connection; never shown for an eager/sync tree

(function () {
  'use strict';

  // join a dir path + a child name — handles an empty-string root (a path
  // convention with no leading separator at all, e.g. a bounded tree's own
  // relative paths) the same as a non-empty one (e.g. an absolute namespace
  // path), so the root's own path convention is the host's choice, not ours.
  function joinPath(dir, name) {
    return dir ? dir.replace(/\/$/, '') + '/' + name : name;
  }

  const TPL = document.createElement('template');
  TPL.innerHTML = `
    <style>
      :host { display: block; }
      .row {
        display: flex; align-items: center;
        padding: var(--tv-row-padding, 7px 8px);
        border-radius: 6px; cursor: pointer;
      }
      .row:hover { background: var(--tv-hover-bg, #f6f8fa); }
      .caret {
        flex: none;
        width: var(--tv-caret-size, 20px); height: var(--tv-caret-size, 20px);
        margin-right: 6px; display: flex; align-items: center; justify-content: center;
        font-size: 13px; color: var(--tv-caret-color, #8b949e);
        cursor: pointer; user-select: none;
      }
      .caret:hover { color: var(--tv-caret-hover, #57606a); }
      .kids { padding-left: var(--tv-indent, 14px); }
      .kids[hidden] { display: none; }
      .name {
        flex: 1 1 auto; min-width: 0;
        font: var(--tv-name-font, 13px ui-monospace, SFMono-Regular, Menlo, monospace);
        color: var(--tv-name-color, #0969da);
        text-decoration: none; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
      }
      .name:hover { text-decoration: underline; }
      .dir-row.plain .name {
        color: var(--tv-dir-color, #57606a); text-decoration: none; cursor: inherit;
      }
      .file-row.sel .name { font-weight: 600; }
      .file-row.sel { background: var(--tv-sel-bg, #ddf4ff); }
      .file-row.sel .name { color: var(--tv-sel-color, #0969da); }
      .loading {
        padding: var(--tv-row-padding, 7px 8px) var(--tv-row-padding, 7px 8px) var(--tv-row-padding, 7px 8px) 22px;
        font: var(--tv-name-font, 13px ui-monospace, SFMono-Regular, Menlo, monospace);
        color: var(--tv-loading-color, #8b949e);
      }
    </style>
    <div id="root"></div>
  `;

  class TreeView extends HTMLElement {
    #root; #getChildren; #onOpenFile; #onOpenDir; #decorateRow; #persistKey; #upRow;
    #treeOpen = {}; #activePath = null; #childCache = new Map();
    #container;

    constructor() {
      super();
      this.attachShadow({ mode: 'open' }).appendChild(TPL.content.cloneNode(true));
      this.#container = this.shadowRoot.getElementById('root');
    }

    set root(v) { this.#root = v; }
    get root() { return this.#root; }
    set getChildren(fn) { this.#getChildren = fn; }
    set onOpenFile(fn) { this.#onOpenFile = fn; }
    set onOpenDir(fn) { this.#onOpenDir = fn; }
    set decorateRow(fn) { this.#decorateRow = fn; }
    set persistKey(v) { this.#persistKey = v; }
    set upRow(v) { this.#upRow = v; }
    get anyOpen() { return Object.keys(this.#treeOpen).some((k) => this.#treeOpen[k] === true); }

    #loadOpen() {
      try { this.#treeOpen = JSON.parse(localStorage.getItem(this.#persistKey)) || {}; }
      catch (_) { this.#treeOpen = {}; }
    }
    #saveOpen() {
      try { localStorage.setItem(this.#persistKey, JSON.stringify(this.#treeOpen)); } catch (_) {}
    }
    #fetchChildren(path) {
      if (this.#childCache.has(path)) return Promise.resolve(this.#childCache.get(path));
      return Promise.resolve(this.#getChildren(path)).then((items) => {
        this.#childCache.set(path, items);
        return items;
      });
    }
    #sortItems(items) {
      return items.slice().sort((a, b) => a.name.localeCompare(b.name));
    }
    #caretSlot(onToggle) {
      const c = document.createElement('span');
      c.className = 'caret';
      if (onToggle) {
        c.textContent = '▸';
        // stopPropagation: a plain (no onOpenDir) dir row also toggles on
        // ANY click, via its own listener below — without this, clicking
        // the caret bubbles into that listener too and fires it a second
        // time, toggling right back to where it started
        c.addEventListener('click', (e) => { e.stopPropagation(); onToggle(); });
      }
      return c;
    }

    #renderLevel(parent, items, dirPath) {
      parent.textContent = '';
      const dirs = this.#sortItems(items.filter((i) => i.isDir));
      const files = this.#sortItems(items.filter((i) => !i.isDir));
      dirs.forEach((item) => {
        const childPath = joinPath(dirPath, item.name);
        const row = document.createElement('div');
        row.className = 'row dir-row' + (this.#onOpenDir ? '' : ' plain');
        const kids = document.createElement('div');
        kids.className = 'kids';
        kids.hidden = true;
        const expand = (open) => {
          this.#treeOpen[childPath] = open;
          caret.textContent = open ? '▾' : '▸';
          kids.hidden = !open;
          this.#saveOpen();
          if (open) {
            // usually already warm from the background prefetch — only a
            // slow connection or a huge subtree ever shows this placeholder
            if (!this.#childCache.has(childPath)) {
              kids.textContent = '';
              const loading = document.createElement('div');
              loading.className = 'loading';
              loading.textContent = 'loading…';
              kids.appendChild(loading);
            }
            this.#fetchChildren(childPath).then((kidItems) => this.#renderLevel(kids, kidItems, childPath));
          }
        };
        const caret = this.#caretSlot(() => expand(this.#treeOpen[childPath] !== true));
        row.appendChild(caret);
        if (this.#onOpenDir) {
          const link = document.createElement('a');
          link.className = 'name';
          link.href = childPath;
          link.textContent = item.name + '/';
          link.addEventListener('click', (e) => { e.preventDefault(); this.#onOpenDir(item, childPath); });
          row.appendChild(link);
        } else {
          const label = document.createElement('span');
          label.className = 'name';
          label.textContent = item.name + '/';
          row.appendChild(label);
          row.addEventListener('click', () => expand(this.#treeOpen[childPath] !== true));
        }
        if (this.#decorateRow) this.#decorateRow(row, item, childPath, true);
        parent.appendChild(row);
        parent.appendChild(kids);
        if (this.#treeOpen[childPath] === true) expand(true);
      });
      files.forEach((item) => {
        const filePath = joinPath(dirPath, item.name);
        const row = document.createElement('div');
        row.className = 'row file-row' + (filePath === this.#activePath ? ' sel' : '');
        row.dataset.path = filePath;
        row.appendChild(this.#caretSlot(null));
        const link = document.createElement('a');
        link.className = 'name';
        link.href = filePath;
        link.textContent = item.name;
        link.addEventListener('click', (e) => { e.preventDefault(); this.#onOpenFile(item, filePath); });
        row.appendChild(link);
        if (this.#decorateRow) this.#decorateRow(row, item, filePath, false);
        parent.appendChild(row);
      });
    }

    // synchronous: the host hands over a tree whose children are already
    // local (getChildren answers from memory), so there is nothing to wait
    // for — rows start collapsed, expand() reads what's there.
    render(rootItems) {
      this.#loadOpen();
      this.#childCache = new Map();
      this.#childCache.set(this.#root, rootItems);
      this.#container.textContent = '';
      if (this.#upRow) {
        const up = document.createElement('div');
        up.className = 'row';
        up.appendChild(this.#caretSlot(null));
        const a = document.createElement('a');
        a.className = 'name';
        a.href = this.#upRow.href;
        a.textContent = this.#upRow.label;
        up.appendChild(a);
        this.#container.appendChild(up);
      }
      this.#renderLevel(this.#container, rootItems, this.#root);
    }

    markActive(path) {
      if (this.#activePath) {
        const old = this.shadowRoot.querySelector(`.file-row[data-path="${cssEscape(this.#activePath)}"]`);
        if (old) old.classList.remove('sel');
      }
      this.#activePath = path;
      if (path) {
        const now = this.shadowRoot.querySelector(`.file-row[data-path="${cssEscape(path)}"]`);
        if (now) now.classList.add('sel');
      }
    }

    #walkOpenAll(path, items) {
      const dirs = items.filter((i) => i.isDir);
      return dirs.reduce((p, item) => p.then(() => {
        const childPath = joinPath(path, item.name);
        this.#treeOpen[childPath] = true;
        return this.#fetchChildren(childPath).then((kids) => this.#walkOpenAll(childPath, kids));
      }), Promise.resolve());
    }
    expandAll() {
      this.#loadOpen();
      const rootItems = this.#childCache.get(this.#root) || [];
      return this.#walkOpenAll(this.#root, rootItems).then(() => {
        this.#saveOpen();
        return this.render(rootItems);
      });
    }
    collapseAll() {
      this.#treeOpen = {};
      this.#saveOpen();
      return this.render(this.#childCache.get(this.#root) || []);
    }
  }

  function cssEscape(s) { return window.CSS && CSS.escape ? CSS.escape(s) : s.replace(/["\\]/g, '\\$&'); }

  customElements.define('tree-view', TreeView);
})();
