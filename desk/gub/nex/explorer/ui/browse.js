// explorer browse app. Renders a directory listing via <file-table> and
// drives every action through POST endpoints — success re-fetches the
// listing in place (no page reloads), failure shows the server's text
// in the status toast. Dialogs are kit <modal-dialog>s. Navigation is
// client-side for dirs, normal for files.
const $ = (id) => document.getElementById(id);
const PREFIX = '/grubbery/ball';
// SCOPE: the explorer opened at a root. ?scope=/apps/foo/projects makes
// that directory "/" for the crumbs, the tab titles and the parent link,
// and the scope's tabs persist on their own. An app page is the explorer
// scoped at the app's root (a clanker collection, a repo's working tree);
// an element page is the explorer scoped at the element. The namespace
// paths underneath are unchanged: every request still goes to the real
// /grubbery/ball url, nothing is folded or hidden.
// MOUNT: an app serving this shell at its own route. The page declares
// window.EXPLORER_MOUNT = {route, root, title, icon, viewers} before this
// script: urls under `route` are namespace paths under `root`, so
// /grubbery/clanker/x is the explorer rooted at the clanker collection,
// showing x. Same scope rules as ?scope=, with the route's url form kept
// in history. `viewers` (optional) is an endpoint of the app's that says,
// per file, which pane it opens in (see viewerFor): its own files, in its
// own shell, open in its own panes. The plain explorer has no viewers; a
// file means a pane only where the mounting app says so.
const MOUNT = (window.EXPLORER_MOUNT && window.EXPLORER_MOUNT.route && window.EXPLORER_MOUNT.root) ? window.EXPLORER_MOUNT : null;
const SCOPE = (MOUNT ? MOUNT.root : ((new URLSearchParams(location.search)).get('scope') || '')).replace(/\/+$/, '');
const ROOT = PREFIX + SCOPE;
const SCOPE_NAME = MOUNT && MOUNT.title ? MOUNT.title : SCOPE.slice(SCOPE.lastIndexOf('/') + 1);
// a path as the scope shows it: relative to ROOT inside the scope, to the
// namespace root otherwise (a symlink can resolve outside the scope)
const rel = (p) => (p === ROOT || p.startsWith(ROOT + '/')) ? (p.slice(ROOT.length) || '/') : (p.slice(PREFIX.length) || '/');
// the url for a namespace path, and back: the mount's route form inside
// the scope, the ball url (with ?scope=) otherwise
const toUrl = (p) => {
  if (MOUNT && (p === ROOT || p.startsWith(ROOT + '/'))) return MOUNT.route.replace(/\/+$/, '') + p.slice(ROOT.length);
  return SCOPE && !MOUNT ? p + '?scope=' + encodeURIComponent(SCOPE) : p;
};
const fromUrl = (u) => {
  if (!MOUNT) return u;
  const route = MOUNT.route.replace(/\/+$/, '');
  if (u === route || u.startsWith(route + '/')) return ROOT + u.slice(route.length).replace(/\/+$/, '');
  return u;
};
let here = fromUrl(location.pathname);
let dirPath = rel(here);

function nav(p, push) {
  here = p;
  dirPath = rel(p);
  if (push !== false) history.pushState(null, '', toUrl(p));
  document.title = SCOPE ? (SCOPE_NAME + (dirPath === '/' ? '' : ' ' + dirPath)) : dirPath;
  renderCrumbs();
  if (view === 'list') ft.showLoading(); else fg.showLoading();
  load();
}
document.addEventListener('click', (e) => {
  const a = e.target.closest('a[data-nav]');
  if (!a || e.metaKey || e.ctrlKey || e.shiftKey) return;
  e.preventDefault();
  nav(new URL(a.href).pathname);
});
window.addEventListener('popstate', () => nav(fromUrl(location.pathname), false));

let data = null;
const ft = $('ft');

function fmtSize(n) {
  if (n == null) return '–';
  if (n < 1024) return n + ' B';
  if (n < 1024 * 1024) return Math.round(n / 1024) + ' KB';
  return (n / (1024 * 1024)).toFixed(1) + ' MB';
}

// ---- file-table setup ----
ft.columns = [
  {
    key: 'name', label: 'Name', width: '30%',
    format: (v, item) => {
      if (item.kind === 'dir') return v + '/';
      return v;
    },
    link: (item) => {
      if (item.kind === 'dir') return here.replace(/\/$/, '') + '/' + item.name;
      if (item.binary) return here.replace(/\/$/, '') + '/' + item.name + '?pretty';
      // a symlink's name opens the link itself (its editor); the target
      // arrow, added below, is what follows it
      return here.replace(/\/$/, '') + '/' + item.name;
    },
    decorate: (cell, item) => {
      if (item.kind === 'symlink' && item.target) {
        const arrow = document.createElement('span');
        arrow.className = 'sym';
        arrow.textContent = ' → ';
        const a = document.createElement('a');
        a.className = 'sym';
        a.href = PREFIX + item.resolved;
        a.textContent = item.target;
        a.title = 'follow the link';
        a.addEventListener('click', (e) => { e.stopPropagation(); });
        cell.append(arrow, a);
      }
      const bangText = item.kind === 'boom' ? item.boom : item.bang;
      if (bangText) {
        const x = document.createElement('span');
        x.style.cssText = 'color:#cf222e;font-weight:700;cursor:pointer;margin-left:5px;';
        x.textContent = '!';
        x.title = 'crash details';
        x.addEventListener('click', (e) => { e.stopPropagation(); showBoom(bangText); });
        cell.appendChild(x);
      }
    },
  },
  {
    key: 'blot', label: 'Blot / Neck', cls: 'mono',
    format: (v, item) => {
      if (item.kind === 'dir') return item.neck || '–';
      return v || '–';
    },
    link: (item) => {
      if (item.kind === 'dir' && item['neck-url']) return item['neck-url'];
      if (item['blot-url']) return item['blot-url'];
      return null;
    },
  },
  {
    key: 'weir', label: 'Weir', cls: 'mono',
    // dirs only: a small restricted/unrestricted tag, the same thing as the
    // top-bar sandbox chip. Click to edit that directory's roads in the weir
    // modal — writes target that row's own URL, so the server edits it, not
    // the directory we're viewing.
    format: (v, item) => item.kind === 'dir' ? (item.weir ? 'restricted' : 'unrestricted') : '',
    decorate: (cell, item) => {
      if (item.kind !== 'dir') return;
      cell.style.cursor = 'pointer';
      cell.style.color = item.weir ? '#9a6700' : '#1a7f37';
      cell.title = "edit this directory's weir";
      cell.addEventListener('click', (e) => {
        e.stopPropagation();
        const dp = here.replace(/\/$/, '') + '/' + item.name;
        const show = (w) => renderWeir(w || null, dp, true, dp);
        // after an edit, load() refreshes children; re-read this row's weir
        weirRefresh = () => {
          const fresh = (data.children || []).find((c) => c.name === item.name);
          show(fresh ? fresh.weir : null);
        };
        show(item.weir);
        $('weir-modal').show();
      });
    },
  },
  {
    key: 'built', label: 'Build', cls: 'mono',
    // ✓ compiled, ✗ build error, blank for non-code or non-hoon. Click the
    // file (its name) to open the viewer's Build tab for the detail/tang.
    format: (v) => v === 'vase' ? '✓' : v === 'tang' ? '✗' : '',
    decorate: (cell, item) => {
      if (item.built === 'vase') { cell.style.color = '#116329'; }
      else if (item.built === 'tang') {
        cell.style.color = '#cf222e'; cell.style.fontWeight = '700';
        cell.title = 'build error — open the file for the tang';
      }
    },
  },
  {
    key: 'mime', label: 'Mime Type', cls: 'mono',
    format: (v, item) => {
      if (item.kind === 'dir' || item.kind === 'symlink' || item.kind === 'boom') return '–';
      return v || '–';
    },
  },
  {
    key: 'size', label: 'Size', cls: 'mono',
    format: (v, item) => {
      if (item.kind === 'dir' || item.kind === 'symlink' || item.kind === 'boom') return '–';
      return fmtSize(v);
    },
  },
  { key: 'modified', label: 'Modified', cls: 'mono' },
];

ft.actions = (item) => {
  if (item.kind === 'dir') {
    return [
      { label: 'New folder…', action: 'new-folder' },
      { label: 'New nexus…', action: 'new-nexus' },
      { label: 'New file…', action: 'new-file' },
      { label: 'New symlink…', action: 'new-symlink' },
      { label: 'Download', action: 'download' },
      { label: 'Rename', action: 'rename' },
      { label: 'Move', action: 'move' },
      { label: 'Copy', action: 'copy' },
      { label: 'Delete', action: 'delete', danger: true },
    ];
  }
  const acts = [
    { label: 'Download', action: 'download' },
    { label: 'Rename', action: 'rename' },
    { label: 'Move', action: 'move' },
    { label: 'Copy', action: 'copy' },
    { label: 'Delete', action: 'delete', danger: true },
  ];
  return acts;
};

// ---- file-grid setup ----
const fg = $('fg');
fg.baseHref = here;
fg.actions = ft.actions;

// ---- finder (cols) view: the whole subtree rooted at the current
// directory, via the shared <tree-view> (lib/ui/tree-view.js) — the whole
// subtree's names prefetch in the background right after render (the
// component's own job, see tree-view.js), a dir's name navigates the page
// (same data-nav handling as the breadcrumbs), a file opens/focuses a tab.
// A tabbed FileView preview sits on the right. The component's own defaults
// are already explorer's look, so no --tv-* overrides are needed here.
const finder = $('finder');
const finderTree = $('finder-tree'); // a <tree-view> element
const finderTreeToggle = $('finder-tree-toggle');
const badgesToggle = $('finder-badges-toggle');
let badgesOn = true;
try { badgesOn = localStorage.getItem('explorer-badges') !== 'off'; } catch (e) {}

// the whole subtree under `here` comes down as ONE nested document from
// ?tree=1 ({dirs: {name: subtree}, files: [name]}, names only — see
// explorer.hoon's +tree-json); getChildren answers from it synchronously.
let treeDoc = null;
function treeNodeAt(path) {
  const rel = path.slice(here.length).split('/').filter(Boolean);
  let node = treeDoc;
  for (const seg of rel) {
    node = node && node.dirs && node.dirs[seg];
    if (!node) return null;
  }
  return node;
}
function getChildren(path) {
  const node = treeNodeAt(path);
  if (!node) return [];
  return Object.entries(node.dirs).map(([n, sub]) => ({
    name: n, isDir: true, kind: 'dir',
    hasWeir: !!(sub && sub.weir), neck: (sub && sub.neck) || null,
  })).concat(node.files.map((f) => ({
    name: f.name, isDir: false, kind: 'file', blot: f.blot || null,
  })));
}
finderTree.getChildren = getChildren;
// the sidebar is the launcher: a click opens (or focuses) a tab for that
// item. Navigation WITHIN a tab (its listing rows, crumbs, back/fwd) stays
// in the tab — see navigateTab.
finderTree.onOpenDir = (item, path) => openOrFocusTab(path, 'dir');
finderTree.onOpenFile = (item, path) => openOrFocusTab(path, 'file');
finderTree.decorateRow = (row, item, path) => {
  // item.__dir is the directory this item actually lives in —
  // handleAction posts there, not to the page's current root
  item.__dir = path.slice(0, path.lastIndexOf('/')) || PREFIX;
  row.__item = item;
  // badges come from the shared kit builder (lib/ui/badges.js). The ?tree=1
  // payload carries presence + names only, so each click fetches that row's
  // listing lazily: weir → the editable modal, neck/blot → navigate.
  window.attachBadges(row, item, {
    enabled: badgesOn,
    onWeir: () => openWeirFor(path),
    onNeck: () => openRefFor(item.__dir, item.name, 'neck'),
    onBlot: () => openRefFor(item.__dir, item.name, 'blot'),
  });
};
// a sidebar badge click fetches that row's listing lazily — the tree payload
// carries only presence, not the roads/ref the detail views need.
function openWeirFor(url) {
  fetch(url + '?list=1').then((r) => r.json()).then((d) => {
    const show = (w) => renderWeir(w || null, url, true, url);
    weirRefresh = () =>
      fetch(url + '?list=1').then((r) => r.json()).then((dd) => show(dd.weir)).catch(() => {});
    show(d.weir);
    $('weir-modal').show();
  }).catch((e) => toast('weir load failed: ' + e, true));
}
function openRefFor(dirUrl, name, kind) {
  fetch(dirUrl + '?list=1').then((r) => r.json()).then((d) => {
    const it = (d.children || []).find((c) => c.name === name);
    const u = it && (kind === 'neck' ? it['neck-url'] : it['blot-url']);
    if (u) { location.href = u; return; }
    toast('no ' + kind + ' link', true);
  }).catch((e) => toast(kind + ' load failed: ' + e, true));
}
async function renderFinderTree() {
  const root = here;
  try {
    const r = await fetch(root + '?tree=1');
    if (!r.ok) throw new Error(r.status);
    treeDoc = await r.json();
  } catch (e) { toast('tree failed: ' + e, true); return; }
  if (root !== here) return; // navigated again while this was in flight
  finderTree.root = here;
  finderTree.persistKey = 'explorer-tree:' + here;
  finderTree.upRow = null; // the breadcrumbs are the way up
  finderTree.render(getChildren(here));
  finderTree.markActive(activeTabPath);
  updateTreeToggleLabel();
}
function updateTreeToggleLabel() {
  finderTreeToggle.textContent = finderTree.anyOpen ? 'collapse all' : 'expand all';
}
finderTreeToggle.addEventListener('click', async () => {
  if (finderTreeToggle.textContent === 'expand all') await finderTree.expandAll();
  else await finderTree.collapseAll();
  updateTreeToggleLabel();
});
function updateBadgesToggleLabel() {
  badgesToggle.textContent = badgesOn ? 'hide badges' : 'show badges';
}
badgesToggle.addEventListener('click', () => {
  badgesOn = !badgesOn;
  try { localStorage.setItem('explorer-badges', badgesOn ? 'on' : 'off'); } catch (e) {}
  for (const b of finderTree.shadowRoot.querySelectorAll('.row-badges'))
    b.style.display = badgesOn ? 'inline-flex' : 'none';
  updateBadgesToggleLabel();
});
updateBadgesToggleLabel();

// the preview pane is a <tab-group> of shared <FileView>s — full Source|
// Preview|Edit|Save per open file, same component as the file page. Tabs
// persist across directory navigation (and across reloads, via
// localStorage): opening a file adds or focuses a tab, it doesn't replace
// whatever else is already open.
const TABS_KEY = 'explorer-tabs' + SCOPE;   // a scope keeps its own tabs
const finderTabs = $('finder-tabs');
let activeTabPath = null;

// a split-view tab is a uniform "location tab": a panel carrying its current
// path and its own history {stack:[{path,kind}], idx}, with a ◀▶ chrome bar
// above a body that renders either a dir listing (<file-table>) or a FileView,
// chosen by the location's kind. navigateTab is the single sink every nav
// source funnels through; there is no longer a fixed directory tab.
const tabPanels = () => [...finderTabs.children].filter((p) => p.hasAttribute('tab-label'));
const activePanel = () => tabPanels().find((p) => !p.hidden) || tabPanels()[0] || null;

// reflect the active tab onto its tree row (cheap — no re-render)
function markActiveInTree(path) {
  activeTabPath = path;
  finderTree.markActive(path);
}
function selectPanel(panel) {
  const idx = tabPanels().indexOf(panel);
  if (idx >= 0) finderTabs.select(idx);
}
function tabLabel(path, kind) {
  const disp = rel(path);
  const base = disp === '/' ? '/' : disp.slice(disp.lastIndexOf('/') + 1);
  return kind === 'dir' ? (base === '/' ? '/' : base + '/') : base;
}

// a dir listing inside a tab: the list view's columns, but the name link and
// row navigation drive navigateTab on THIS tab rather than a page load
function makeDirTable(panel) {
  const t = document.createElement('file-table');
  t.style.height = '100%';
  t.columns = ft.columns.map((c) => c.key !== 'name' ? c : Object.assign({}, c, {
    link: (item) => (t.__dir || '').replace(/\/$/, '') + '/' + item.name,
  }));
  t.actions = ft.actions;
  t.addEventListener('ft-navigate', (e) => {
    const { item, href } = e.detail;
    if (item) navigateTab(panel, href, item.kind);
  });
  t.addEventListener('ft-action', handleAction);
  return t;
}
// a dir listing as the desktop/icon grid instead of rows
function makeDirGrid(panel, path) {
  const g = document.createElement('file-grid');
  g.style.height = '100%';
  g.baseHref = path;
  g.actions = ft.actions;
  g.addEventListener('ft-navigate', (e) => {
    const { item, href } = e.detail;
    if (item) navigateTab(panel, href, item.kind);
  });
  g.addEventListener('ft-action', handleAction);
  return g;
}
function dirModeDefault() {
  try { return localStorage.getItem('explorer-dir-mode') === 'grid' ? 'grid' : 'table'; } catch (_) { return 'table'; }
}
// active/idle look for a tab's view-mode buttons — mirrors the top bar's
// #view-toggle .on state (blue) vs the plain bordered button
function styleModeBtn(btn, active) {
  btn.style.background = active ? '#ddf4ff' : '#fff';
  btn.style.borderColor = active ? '#54aeff' : '#d0d7de';
  btn.style.color = active ? '#0969da' : '#24292f';
  btn.style.fontWeight = active ? '600' : '400';
}
// clickable path breadcrumbs for a dir tab — each segment navigates THIS tab
// (and so lands in its history), the way the old top-bar crumbs did the page
function buildCrumbs(panel, path) {
  const wrap = panel._crumbs;
  wrap.textContent = '';
  const mk = (label, p) => {
    const a = document.createElement('a');
    a.textContent = label; a.href = p;
    a.style.cssText = 'color:#57606a;text-decoration:none;padding:1px 3px;border-radius:4px;white-space:nowrap';
    a.addEventListener('mouseenter', () => { a.style.background = '#eaeef2'; });
    a.addEventListener('mouseleave', () => { a.style.background = ''; });
    a.addEventListener('click', (e) => { e.preventDefault(); navigateTab(panel, p, 'dir'); });
    return a;
  };
  const sep = () => { const s = document.createElement('span'); s.textContent = '/'; s.style.color = '#c0c7d0'; return s; };
  const base = (path === ROOT || path.startsWith(ROOT + '/')) ? ROOT : PREFIX;
  wrap.appendChild(mk('/', base));
  let acc = base;
  (path.slice(base.length) || '').split('/').filter(Boolean).forEach((s, i) => {
    acc += '/' + s;
    if (i > 0) wrap.appendChild(sep()); // the root crumb already shows the first '/'
    wrap.appendChild(mk(s, acc));
  });
}

// the single navigation sink: point `panel` at `path` (dir or file), render
// it, and — unless replaying back/forward — push onto the tab's own history
async function navigateTab(panel, path, kind, push = true) {
  const h = panel._hist;
  if (push && !(h.idx >= 0 && h.stack[h.idx] && h.stack[h.idx].path === path)) {
    h.stack = h.stack.slice(0, h.idx + 1);
    h.stack.push({ path, kind });
    h.idx = h.stack.length - 1;
  }
  panel.dataset.path = path;
  panel._rendered = true;
  panel.setAttribute('tab-label', tabLabel(path, kind));
  panel.setAttribute('tab-title', rel(path));
  finderTabs.refresh();
  panel._back.disabled = h.idx <= 0;
  panel._fwd.disabled = h.idx >= h.stack.length - 1;
  panel._back.style.opacity = panel._back.disabled ? '.3' : '';
  panel._fwd.style.opacity = panel._fwd.disabled ? '.3' : '';
  if (panel._fv) { panel._fv.destroy(); panel._fv = null; }
  panel._body.textContent = '';
  if (kind === 'dir') {
    // chrome: clickable breadcrumbs + the rows/desktop view icons
    buildCrumbs(panel, path);
    panel._modeWrap.style.display = '';
    // the listing first: it also says which nexus this dir runs (its
    // neck), which the app's viewer endpoint is told
    let d = null;
    try {
      const r = await fetch(path + '?list=1');
      if (!r.ok) throw new Error(r.status);
      d = await r.json();
    } catch (e) { toast('listing failed: ' + e, true); }
    if (panel.dataset.path !== path) return; // moved on while in flight
    const neckDisp = d && d.nexus && typeof d.nexus.display === 'string' ? d.nexus.display : '-';
    const neck = neckDisp === '-' ? '' : neckDisp;
    // the app's pane for this dir, if it has one: a third mode, shown
    // first unless this tab has chosen rows or desktop by hand
    const viewer = await viewerFor(path, 'dir', neck);
    if (panel.dataset.path !== path) return; // moved on while in flight
    panel._dirViewer = viewer;
    panel._modeView.style.display = viewer ? '' : 'none';
    if (viewer) panel._modeView.textContent = viewer.label || 'View';
    let mode = panel._dirMode;
    if (viewer && !panel._modeChosen) mode = 'view';
    if (!viewer && mode === 'view') mode = dirModeDefault();
    styleModeBtn(panel._modeRows, mode === 'table');
    styleModeBtn(panel._modeGrid, mode === 'grid');
    styleModeBtn(panel._modeView, mode === 'view');
    if (mode === 'view') {
      // a dir pane navigates this tab to a dir by default, or to a file
      // when it says so: onNavigate(url, 'file')
      try { panel._fv = viewer.mount(panel._body, { url: path, onNavigate: (u, k) => navigateTab(panel, u, k === 'file' ? 'file' : 'dir') }) || { destroy() {} }; }
      catch (e) { panel._body.textContent = 'viewer failed: ' + e; }
      if (!panel.hidden) markActiveInTree(path);
      saveTabs();
      return;
    }
    const view = mode === 'grid' ? makeDirGrid(panel, path) : makeDirTable(panel);
    if (mode !== 'grid') view.__dir = path;
    panel._body.appendChild(view);
    if (d) {
      d.children.forEach((c) => { c.__dir = path; }); // handleAction posts there
      view.items = d.children;
    } else view.showLoading();
  } else {
    // a file: FileView carries its own crumbs; wire them to navigate in-tab
    panel._crumbs.textContent = '';
    const n = document.createElement('span');
    n.textContent = path.slice(path.lastIndexOf('/') + 1);
    n.style.cssText = 'color:#8b949e;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;padding:1px 3px';
    panel._crumbs.appendChild(n);
    panel._modeWrap.style.display = 'none';
    // under a scope the header crumb starts at the scope's root, like the tree
    const opts = { url: path, wrapKey: 'explorer-wrap', crumbBase: ROOT, onNavigate: (u) => navigateTab(panel, u, 'dir') };
    // a registered viewer for this file's mark becomes FileView's first
    // pane (the file itself stays one click away in Source)
    const viewer = await viewerFor(path, 'file');
    if (panel.dataset.path !== path) return; // moved on while in flight
    if (viewer) opts.viewer = viewer;
    panel._fv = window.FileView.mount(panel._body, opts);
  }
  if (!panel.hidden) markActiveInTree(path);
  saveTabs();
}

// viewers: the mount's `viewers` is the url of an endpoint the app serves.
// When a path opens in a tab, it is asked with the path relative to the
// mount root, its kind (file|dir), a file's blot and a dir's neck
// (?path=…&kind=…&blot=…&neck=…) and answers {view, script, args?} or an empty
// body: the app decides, in its own code, which of its paths open in
// which pane, and hands the pane whatever context it needs as `args`
// (the pane never has to parse the tree's shape out of a url). The
// script registers itself as
// window.Viewers[view] = { label, mount(root, opts) -> { destroy() } },
// the same contract as FileView, with opts = {url, args, onNavigate}. A
// file's pane is FileView's first pane; a dir's pane is a third mode of
// the dir tab beside rows and desktop. Loaded lazily, once; a path the
// app declines (or a script that fails) just gets the usual view. A pane
// is about the path it opens on: that is a convention the app keeps, not
// a rule the shell enforces. The script runs with this page's reach, so
// only this ship's own routes are loaded: a /grubbery/... path, never
// another origin.
const VIEWERS = (MOUNT && typeof MOUNT.viewers === 'string' && /^\/grubbery\/[^\s]*$/.test(MOUNT.viewers)) ? MOUNT.viewers : null;
const viewerLoads = {};      // script url -> Promise
async function viewerFor(path, kind, neck) {
  try {
    if (!VIEWERS) return null;
    const rel = path === ROOT ? '' : path.startsWith(ROOT + '/') ? path.slice(ROOT.length) : null;
    if (rel === null) return null; // outside the mount: not the app's path
    let blot = '';
    if (kind !== 'dir') {
      const info = await fetch(path + '?info=1').then((r) => r.json());
      blot = ((info && info.blot) || '').replace(/^\//, '');
    }
    // a dir is told by its neck (the nexus it runs, '' when plain), a file by its blot
    const q = '?path=' + encodeURIComponent(rel) + '&kind=' + (kind === 'dir' ? 'dir' : 'file') +
      '&blot=' + encodeURIComponent(blot) + '&neck=' + encodeURIComponent(kind === 'dir' ? (neck || '') : '');
    const r = await fetch(VIEWERS + q, { cache: 'no-store' });
    if (!r.ok) return null;
    const text = await r.text();
    const rule = text.trim() ? JSON.parse(text) : null;
    if (!rule || typeof rule !== 'object') return null;
    const src = rule.script, view = rule.view;
    if (typeof view !== 'string' || typeof src !== 'string' || !/^\/grubbery\/[^\s]*$/.test(src)) { toast('viewer refused: needs a view name and a /grubbery/ script', true); return null; }
    window.Viewers = window.Viewers || {};
    if (!window.Viewers[view]) {
      if (!viewerLoads[src]) viewerLoads[src] = new Promise((res, rej) => {
        const s = document.createElement('script');
        s.src = src; s.onload = res; s.onerror = () => rej(new Error('viewer failed to load: ' + src));
        document.head.appendChild(s);
      });
      await viewerLoads[src];
    }
    const v = window.Viewers[view];
    if (!v || typeof v.mount !== 'function') return null;
    // the app's args ride along with the pane; a mount passes them through
    const args = (rule.args && typeof rule.args === 'object') ? rule.args : {};
    return { label: v.label, mount: (root, opts) => v.mount(root, Object.assign({}, opts, { args })) };
  } catch (e) { toast('viewer: ' + e.message, true); return null; }
}

// build a tab's chrome + body; its initial location renders lazily (on first
// select) so restoring N tabs doesn't fire N listings/FileViews up front
function mountTabPanel(path, kind) {
  const panel = document.createElement('div');
  panel.dataset.path = path;
  panel.setAttribute('tab-label', tabLabel(path, kind));
  panel.setAttribute('tab-title', rel(path));
  panel.style.cssText = 'height:100%;display:flex;flex-direction:column;min-height:0';
  const bar = document.createElement('div');
  bar.style.cssText = 'flex:none;display:flex;align-items:center;gap:2px;padding:3px 8px;border-bottom:1px solid #eaeef2;background:#fafbfc';
  const mkbtn = (t) => { const b = document.createElement('button'); b.textContent = t; b.style.cssText = 'all:unset;cursor:pointer;padding:1px 7px;border-radius:5px;color:#57606a;font-size:12px'; return b; };
  const back = mkbtn('◀'); back.title = 'back';
  const fwd = mkbtn('▶'); fwd.title = 'forward';
  const crumbs = document.createElement('div');
  crumbs.style.cssText = 'display:flex;align-items:center;gap:1px;margin-left:4px;flex:1;min-width:0;overflow:hidden;font:600 11px ui-monospace,SFMono-Regular,Menlo,monospace';
  // the same two view icons as the top bar: rows (☰) vs desktop (▦)
  const modeWrap = document.createElement('span');
  modeWrap.style.cssText = 'display:inline-flex;gap:2px;flex:none';
  const viewBtn = (glyph, title) => {
    const b = document.createElement('button');
    b.textContent = glyph; b.title = title;
    b.style.cssText = 'all:unset;cursor:pointer;padding:2px 9px;border-radius:6px;font-size:12px;border:1px solid #d0d7de;background:#fff;color:#24292f;line-height:1.4';
    return b;
  };
  const modeRows = viewBtn('☰', 'row view');
  const modeGrid = viewBtn('▦', 'desktop view');
  // the app's own pane for a dir, when the mount answers one (label set then)
  const modeView = viewBtn('View', 'the app\'s view of this directory');
  modeView.style.display = 'none';
  modeWrap.append(modeView, modeRows, modeGrid);
  bar.append(back, fwd, crumbs, modeWrap);
  const body = document.createElement('div');
  body.style.cssText = 'flex:1;min-height:0;min-width:0;overflow:auto';
  panel.append(bar, body);
  panel._hist = { stack: [], idx: -1 };
  panel._back = back; panel._fwd = fwd; panel._crumbs = crumbs;
  panel._modeWrap = modeWrap; panel._modeRows = modeRows; panel._modeGrid = modeGrid; panel._modeView = modeView; panel._body = body;
  panel._fv = null; panel._rendered = false; panel._init = { path, kind };
  panel._dirMode = dirModeDefault(); panel._modeChosen = false; panel._dirViewer = null;
  const setMode = (m) => {
    panel._dirMode = m; panel._modeChosen = true;
    if (m !== 'view') { try { localStorage.setItem('explorer-dir-mode', m); } catch (_) {} }
    const cur = panel._hist.stack[panel._hist.idx];
    if (cur && cur.kind === 'dir') navigateTab(panel, cur.path, 'dir', false);
  };
  modeRows.addEventListener('click', () => setMode('table'));
  modeGrid.addEventListener('click', () => setMode('grid'));
  modeView.addEventListener('click', () => setMode('view'));
  back.addEventListener('click', () => {
    const hh = panel._hist; if (hh.idx <= 0) return; hh.idx -= 1;
    const e = hh.stack[hh.idx]; navigateTab(panel, e.path, e.kind, false);
  });
  fwd.addEventListener('click', () => {
    const hh = panel._hist; if (hh.idx >= hh.stack.length - 1) return; hh.idx += 1;
    const e = hh.stack[hh.idx]; navigateTab(panel, e.path, e.kind, false);
  });
  finderTabs.appendChild(panel);
  return panel;
}
function ensureRendered(panel) {
  if (!panel || panel._rendered) return;
  const i = panel._init; navigateTab(panel, i.path, i.kind, true);
}
function openInNewTab(path, kind) {
  mountTabPanel(path, kind);
  finderTabs.refresh();
  const panel = tabPanels()[tabPanels().length - 1];
  const settle = () => { selectPanel(panel); ensureRendered(panel); saveTabs(); };
  settle(); queueMicrotask(settle);
}
// open a tab for `path`, or focus the one already showing it — the sidebar's
// launch behavior (so clicking around the tree builds up tabs, not replaces)
function openOrFocusTab(path, kind) {
  const existing = tabPanels().find((p) => p.dataset.path === path);
  if (existing) { selectPanel(existing); return; }
  openInNewTab(path, kind);
}

function saveTabs() {
  const panels = tabPanels();
  const act = panels.find((p) => !p.hidden);
  try {
    localStorage.setItem(TABS_KEY, JSON.stringify({
      tabs: panels.map((p) => ({ path: p.dataset.path, kind: (p._hist.stack[p._hist.idx] || p._init || {}).kind || 'dir' })),
      active: act ? panels.indexOf(act) : 0,
    }));
  } catch (_) {}
}

finderTabs.addEventListener('tg-close', (e) => {
  const panel = e.detail.panel;
  if (panel._fv) panel._fv.destroy();
  panel.remove();
  finderTabs.refresh();
  if (!tabPanels().length) { seedTab(here); return; } // never leave zero tabs
  const act = activePanel();
  if (act) { ensureRendered(act); markActiveInTree(act.dataset.path); }
  saveTabs();
});
finderTabs.addEventListener('tg-change', (e) => {
  const panel = tabPanels()[e.detail.index];
  if (!panel) return;
  ensureRendered(panel);
  markActiveInTree(panel.dataset.path);
  saveTabs();
});

function seedTab(path) {
  mountTabPanel(path, 'dir');
  finderTabs.refresh();
  const panel = tabPanels()[tabPanels().length - 1];
  const settle = () => { selectPanel(panel); ensureRendered(panel); };
  settle(); queueMicrotask(settle);
}

// restore persisted tabs (or seed one at `here`); only the active tab renders
// now, the rest on first select — keeps N tabs from firing N fetches up front
(function restoreTabs() {
  let saved;
  try { saved = JSON.parse(localStorage.getItem(TABS_KEY) || 'null'); } catch (_) { saved = null; }
  const tabs = (saved && Array.isArray(saved.tabs) ? saved.tabs : []).filter((t) => t && typeof t.path === 'string');
  if (!tabs.length) { seedTab(here); return; }
  tabs.forEach((t) => mountTabPanel(t.path, t.kind || 'dir'));
  finderTabs.refresh();
  const panels = tabPanels();
  const ai = (typeof saved.active === 'number' && saved.active >= 0 && saved.active < panels.length) ? saved.active : 0;
  const settle = () => { finderTabs.select(ai); ensureRendered(tabPanels()[ai]); };
  settle(); queueMicrotask(settle);
})();

// refresh the active tab's listing in place after an action changed data —
// re-render its current dir location without pushing history (a file tab
// refreshes through its own FileView)
function refreshActiveTab() {
  const panel = activePanel();
  if (!panel || !panel._rendered) return;
  const cur = panel._hist.stack[panel._hist.idx];
  if (cur && cur.kind === 'dir') navigateTab(panel, cur.path, 'dir', false);
}

// ---- view toggle ----
const vList = $('v-list');
const vGrid = $('v-grid');
const vCols = $('v-cols');
let view = localStorage.getItem('explorer-view') || 'list';

function setView(v) {
  view = v;
  try { localStorage.setItem('explorer-view', v); } catch (_) {}
  ft.style.display = v === 'list' ? '' : 'none';
  fg.style.display = v === 'grid' ? '' : 'none';
  finder.style.display = v === 'cols' ? 'grid' : 'none';
  vList.classList.toggle('on', v === 'list');
  vGrid.classList.toggle('on', v === 'grid');
  vCols.classList.toggle('on', v === 'cols');
  if (v === 'cols' && data) renderFinderTree();
}
vList.addEventListener('click', () => setView('list'));
vGrid.addEventListener('click', () => setView('grid'));
vCols.addEventListener('click', () => setView('cols'));
$('finder-collapse').addEventListener('click', () => finder.toggle());
$('finder-new-tab').addEventListener('click', () => {
  const a = activePanel();
  const cur = a && a._hist.stack[a._hist.idx];
  openInNewTab(a ? a.dataset.path : here, (cur && cur.kind) || 'dir');
});
setView(view);

// ---- navigation (shared by both views) ----
function handleNavigate(e) {
  const { item, href } = e.detail;
  if (!item) { nav(href); return; }
  if (item.kind === 'dir') { nav(href); return; }
  location.href = href;
}
ft.addEventListener('ft-navigate', (e) => {
  const { item, href, column } = e.detail;
  if (!item) { nav(href); return; }
  if (item.kind === 'dir' && column === 'name') { nav(href); return; }
  location.href = href;
});
fg.addEventListener('ft-navigate', handleNavigate);

function handleAction(e) {
  const { action, item } = e.detail;
  // item.__dir is the directory this item actually lives in — set by the
  // tree for nested items; ft/fg only ever show `here`'s own children, so
  // it's absent there and `here` is correct. Actions always POST to the
  // item's OWN directory (that's what the server-side handler resolves
  // bare names against), never blindly to the page's current root.
  const itemDir = item.__dir || here;
  const itemDirDisp = rel(itemDir);
  const base = itemDir.replace(/\/$/, '') + '/' + item.name;
  if (item.kind === 'dir') {
    switch (action) {
      case 'new-folder': openModal('folder-modal', 'm-folder', base); break;
      case 'new-nexus': openModal('nexus-modal', 'm-nexus-name', base); break;
      case 'new-file': openModal('file-modal', 'm-file-name', base); break;
      case 'new-symlink': openModal('symlink-modal', 'm-link', base); break;
      case 'download': location.href = base + '?download=tar'; break;
      case 'rename': ask('rename ' + item.name, item.name, nn =>
        post({ action: 'rename-folder', foldername: item.name, newname: nn }, itemDir)); break;
      case 'move': ask('move ' + item.name + ' to', itemDirDisp + '/' + item.name, d =>
        post({ action: 'move-folder', foldername: item.name, dest: d }, itemDir)); break;
      case 'copy': ask('copy ' + item.name + ' to', itemDirDisp + '/' + item.name + '-copy', d =>
        post({ action: 'copy-folder', foldername: item.name, dest: d }, itemDir)); break;
      case 'delete': if (confirm('Delete ' + item.name + '/?'))
        post({ action: 'delete-folder', foldername: item.name }, itemDir); break;
    }
    return;
  }
  switch (action) {
    case 'download': {
      const l = document.createElement('a');
      l.href = base + '?raw=1'; l.download = item.name; l.click();
    } break;
    case 'rename': ask('rename ' + item.name, item.name, nn =>
      post({ action: 'rename-grub', filename: item.name, newname: nn }, itemDir)); break;
    case 'move': ask('move ' + item.name + ' to', itemDirDisp + '/' + item.name, d =>
      post({ action: 'move-grub', filename: item.name, dest: d }, itemDir)); break;
    case 'copy': ask('copy ' + item.name + ' to', itemDirDisp + '/' + item.name, d =>
      post({ action: 'copy-grub', filename: item.name, dest: d }, itemDir)); break;
    case 'delete': if (confirm('Delete ' + item.name + '?'))
      post({ action: 'delete-grub', filename: item.name }, itemDir); break;
  }
}
ft.addEventListener('ft-action', handleAction);
fg.addEventListener('ft-action', handleAction);

// ---- fetch + render ----
renderCrumbs();
document.title = SCOPE ? (SCOPE_NAME + (dirPath === '/' ? '' : ' ' + dirPath)) : dirPath;
// a mounting app's shell wears that app's icon, not the explorer's
if (MOUNT && typeof MOUNT.icon === 'string' && /^\/grubbery\/[^\s]*$/.test(MOUNT.icon)) {
  const link = document.querySelector('link[rel="icon"]');
  if (link) link.href = MOUNT.icon;
}

async function load() {
  try {
    const r = await fetch(here + '?list=1');
    if (!r.ok) throw new Error(r.status);
    data = await r.json();
  } catch (e) {
    toast('listing failed: ' + e, true);
    return;
  }
  renderChips();
  renderBang();
  // the way up stops at the scope's root
  ft.parentHref = dirPath !== '/' ? here.slice(0, here.lastIndexOf('/')) : null;
  ft.items = data.children;
  fg.baseHref = here;
  fg.items = data.children;
  renderFinderTree(); // re-points the tree at the new root; drops stale caches
  refreshActiveTab(); // an action may have changed the active tab's listing
  renderManage();
  if ($('weir-modal').hasAttribute('open')) weirRefresh();
}

function renderCrumbs() {
  const c = $('crumbs');
  c.textContent = '';
  const segs = dirPath === '/' ? [] : dirPath.slice(1).split('/');
  const base = (here === ROOT || here.startsWith(ROOT + '/')) ? ROOT : PREFIX;
  const a = document.createElement('a');
  a.href = base;
  // a scoped root shows its own name as the root crumb
  a.textContent = base === ROOT && SCOPE ? SCOPE_NAME + '/' : '/';
  a.dataset.nav = '1';
  c.appendChild(a);
  let acc = '';
  segs.forEach((s, i) => {
    acc += '/' + s;
    if (i === segs.length - 1) {
      const sp = document.createElement('span');
      sp.className = 'here';
      sp.textContent = s + '/';
      c.appendChild(sp);
    } else {
      const l = document.createElement('a');
      l.href = base + acc;
      l.textContent = s + '/';
      l.dataset.nav = '1';
      c.appendChild(l);
    }
  });
}

function chip(k, v, warn) {
  const s = document.createElement('span');
  s.className = 'chip' + (warn ? ' warn' : '');
  const kk = document.createElement('span'); kk.className = 'k'; kk.textContent = k;
  const vv = document.createElement('span'); vv.className = 'v';
  if (v instanceof Node) vv.appendChild(v); else vv.textContent = v;
  s.append(kk, vv);
  return s;
}

function renderChips() {
  const c = $('chips');
  c.textContent = '';
  if (data.nexus && data.nexus.display !== '-') {
    let v = data.nexus.display;
    if (data.nexus.url) {
      const a = document.createElement('a');
      a.href = data.nexus.url;
      a.textContent = data.nexus.display;
      v = a;
    }
    c.appendChild(chip('nexus', v));
  }
  c.appendChild(chip('items', String(data.children.length)));
  const open = data.root || !data.weir;
  const sb = chip('sandbox', open ? 'unrestricted' : 'restricted', open);
  const PROTECTED = ['/apps', '/apps/explorer.explorer'];
  if (!data.root && !PROTECTED.includes(dirPath)) {
    sb.classList.add('click');
    sb.title = 'manage this sandbox';
    sb.addEventListener('click', () => {
      weirRefresh = () => renderWeir();
      renderWeir();
      $('weir-modal').show();
    });
  } else if (PROTECTED.includes(dirPath)) {
    sb.classList.add('locked');
    sb.querySelector('.v').append(' 🔒');
    sb.title = 'load-bearing: restricting this directory would make grubbery painfully difficult to interface with from the outside — the server refuses it';
  }
  c.appendChild(sb);
}

// which dir the open weir modal writes to (the top bar edits the current dir;
// the column edits the clicked row's dir). Reset by every renderWeir call.
let weirEndpoint = here;
// how to re-render the open modal after a load() — the top bar re-reads the
// current dir; the column re-reads its row from the freshly loaded children.
let weirRefresh = () => renderWeir();

// renderWeir(weir, dpath, editable, endpoint): the top bar calls it with no
// args — the current dir's weir, editable, writing to `here`. The per-directory
// column calls it with that row's weir and URL, so edits target that dir.
function renderWeir(weir, dpath, editable, endpoint) {
  if (weir === undefined) weir = data.weir;
  if (dpath === undefined) dpath = dirPath;
  if (editable === undefined) editable = true;
  weirEndpoint = endpoint || here;
  $('w-path').textContent = dpath;
  const roads = $('m-weir-roads');
  roads.textContent = '';
  $('m-weir-clear').style.display = (editable && weir) ? '' : 'none';
  $('m-weir-make').style.display = (editable && !weir) ? '' : 'none';
  if (!weir) {
    const p = document.createElement('div');
    p.className = 'w-none';
    p.textContent = editable
      ? 'unrestricted — no weir. Restricting starts fully closed; open it road by road.'
      : 'unrestricted — no weir on this directory.';
    roads.appendChild(p);
    return;
  }
  for (const cat of ['write', 'poke', 'read']) {
    const row = document.createElement('div');
    row.className = 'w-cat';
    const k = document.createElement('span');
    k.className = 'w-k';
    k.textContent = cat;
    const rs = document.createElement('div');
    rs.className = 'w-roads';
    for (const rd of (weir[cat] || [])) {
      const s = document.createElement('span');
      s.className = 'weir-road';
      s.append(rd);
      if (editable) {
        const x = document.createElement('button');
        x.textContent = '×';
        x.title = 'remove road';
        x.addEventListener('click', () =>
          post({ action: 'del-weir-road', category: cat, 'road-path': rd }, weirEndpoint));
        s.appendChild(x);
      }
      rs.appendChild(s);
    }
    if (editable) {
      const plus = document.createElement('button');
      plus.className = 'w-plus';
      plus.textContent = '+';
      plus.title = 'add ' + cat + ' road';
      plus.addEventListener('click', () => {
        const inp = document.createElement('input');
        inp.className = 'w-inline';
        inp.placeholder = '/path or /path/';
        inp.spellcheck = false;
        rs.replaceChild(inp, plus);
        inp.focus();
        const done = () => { if (inp.parentNode) rs.replaceChild(plus, inp); };
        inp.addEventListener('keydown', (e) => {
          if (e.key === 'Enter' && inp.value.trim()) {
            post({ action: 'add-weir-road', category: cat, 'road-path': inp.value.trim() }, weirEndpoint);
            done();
          }
          if (e.key === 'Escape') done();
        });
        inp.addEventListener('blur', done);
      });
      rs.appendChild(plus);
    }
    row.append(k, rs);
    roads.appendChild(row);
  }
}

function renderBang() {
  const b = $('bang');
  if (!data.bang) { b.style.display = 'none'; return; }
  b.style.display = '';
  b.textContent = 'nexus crashed — click for details';
  b.onclick = () => showBoom(data.bang);
}

// ---- actions ----
async function post(params, dir) {
  try {
    const r = await fetch(dir || here, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      redirect: 'manual',
      body: new URLSearchParams(params),
    });
    if (r.status >= 400) { toast(await r.text() || 'failed (' + r.status + ')', true); return; }
    toast('done ✓');
    load();
  } catch (e) { toast('failed: ' + e, true); }
}

async function upload(files, withPaths) {
  if (!files.length) return;
  const fd = new FormData();
  for (const f of files)
    fd.append('file', f, (withPaths && f.webkitRelativePath) || f.name);
  toast('uploading…');
  try {
    const r = await fetch(here, { method: 'POST', redirect: 'manual', body: fd });
    if (r.status >= 400) { toast(await r.text() || 'upload failed', true); return; }
    toast('uploaded ✓');
    load();
  } catch (e) { toast('upload failed: ' + e, true); }
}

// ---- dialogs ----
function ask(title, initial, fn) {
  $('ask-title').textContent = title;
  const inp = $('ask-input');
  inp.value = initial;
  const go = $('ask-go');
  const done = () => { $('ask-modal').close(); fn(inp.value.trim()); };
  go.onclick = done;
  inp.onkeydown = (e) => { if (e.key === 'Enter') done(); };
  $('ask-modal').show();
  inp.focus();
  inp.select();
}

function showBoom(text) {
  $('boom-text').textContent = text;
  $('boom-modal').show();
}

function renderManage() {
  $('mi-reload').style.display = (data.nexus && data.nexus.display !== '-') ? '' : 'none';
}

// create-modals default to `here`; a directory's own right-click actions
// (new-folder/new-nexus/new-file/new-symlink) pass that directory's own
// path instead, so the thing they create lands under the row you clicked,
// not under whatever directory the page happens to be showing
let createTarget = here;
const CREATE_TITLES = {
  'folder-modal': 'new folder', 'nexus-modal': 'new nexus',
  'file-modal': 'new file', 'symlink-modal': 'new symlink',
};
function openModal(id, focus, targetDir) {
  createTarget = targetDir || here;
  const label = CREATE_TITLES[id];
  if (label) {
    $(id).querySelector('.m-title').textContent = createTarget === here
      ? label : label + ' in ' + rel(createTarget);
  }
  $(id).show();
  if (focus) { $(focus).focus(); }
}
$('mi-folder').addEventListener('click', () => openModal('folder-modal', 'm-folder'));
$('mi-nexus').addEventListener('click', () => openModal('nexus-modal', 'm-nexus-name'));
$('mi-file').addEventListener('click', () => openModal('file-modal', 'm-file-name'));
$('mi-symlink').addEventListener('click', () => openModal('symlink-modal', 'm-link'));
$('mi-upload').addEventListener('click', () => openModal('upload-modal'));
$('mi-upload-dir').addEventListener('click', () => openModal('upload-dir-modal'));
$('mi-download').addEventListener('click', () => { location.href = here + '?download=tar'; });
$('mi-reload').addEventListener('click', () => post({ action: 'reload-nexus' }));
$('m-weir-make').addEventListener('click', () => post({ action: 'make-weir' }, weirEndpoint));
$('m-weir-clear').addEventListener('click', () =>
  confirm('Remove weir? This gives unrestricted access.') &&
  post({ action: 'clear-weir' }, weirEndpoint));
$('m-folder-go').addEventListener('click', () => {
  const n = $('m-folder').value.trim();
  if (!n) return;
  post({ action: 'create-folder', foldername: n }, createTarget);
  $('m-folder').value = '';
  $('folder-modal').close();
});
$('m-folder').addEventListener('keydown', (e) => { if (e.key === 'Enter') $('m-folder-go').click(); });
$('m-nexus-go').addEventListener('click', () => {
  const n = $('m-nexus-name').value.trim();
  const neck = $('m-nexus-neck').value.trim();
  if (!n) return;
  post({ action: 'create-nexus', foldername: n, ...(neck ? { neck } : {}) }, createTarget);
  $('m-nexus-name').value = '';
  $('m-nexus-neck').value = '';
  $('nexus-modal').close();
});
$('m-nexus-name').addEventListener('keydown', (e) => { if (e.key === 'Enter') $('m-nexus-go').click(); });
$('m-nexus-neck').addEventListener('keydown', (e) => { if (e.key === 'Enter') $('m-nexus-go').click(); });
$('m-file-go').addEventListener('click', () => {
  const n = $('m-file-name').value.trim();
  if (!n) return;
  const blot = $('m-file-blot').value.trim();
  post({ action: 'create-file', filename: n, ...(blot ? { blot } : {}) }, createTarget);
  $('m-file-name').value = '';
  $('m-file-blot').value = '';
  $('file-modal').close();
});
$('m-file-name').addEventListener('keydown', (e) => { if (e.key === 'Enter') $('m-file-go').click(); });
$('m-file-blot').addEventListener('keydown', (e) => { if (e.key === 'Enter') $('m-file-go').click(); });
$('m-link-go').addEventListener('click', () => {
  const n = $('m-link').value.trim(), t = $('m-target').value.trim();
  if (!(n && t)) return;
  post({ action: 'create-symlink', linkname: n, target: t }, createTarget);
  $('symlink-modal').close();
});
function wirePicker(pick, input, label, what) {
  $(pick).addEventListener('click', () => $(input).click());
  $(input).addEventListener('change', () => {
    const n = $(input).files.length;
    $(label).textContent = n === 0 ? 'nothing chosen'
      : n === 1 ? $(input).files[0].name
      : n + ' ' + what;
  });
}
wirePicker('m-files-pick', 'm-files', 'm-files-n', 'files');
wirePicker('m-dir-pick', 'm-dir', 'm-dir-n', 'files in directory');
$('m-files-go').addEventListener('click', () => {
  upload([...$('m-files').files], false);
  $('upload-modal').close();
});
$('m-dir-go').addEventListener('click', () => {
  upload([...$('m-dir').files], true);
  $('upload-dir-modal').close();
});

// ---- context menu ----
const ctx = $('ctx-menu');
const CTX_MAP = {
  folder: 'folder-modal', nexus: 'nexus-modal', file: 'file-modal',
  symlink: 'symlink-modal', upload: 'upload-modal', 'upload-dir': 'upload-dir-modal',
};
const CTX_FOCUS = {
  folder: 'm-folder', nexus: 'm-nexus-name', file: 'm-file-name', symlink: 'm-link',
};
ctx.querySelectorAll('[data-ctx]').forEach(btn => {
  btn.addEventListener('click', () => {
    const k = btn.dataset.ctx;
    openModal(CTX_MAP[k], CTX_FOCUS[k]);
  });
});

function showCtx(x, y) {
  ctx.style.display = '';
  ctx.style.left = x + 'px';
  ctx.style.top = y + 'px';
  ctx.removeAttribute('flip');
  ctx.open();
}

function showItemCtx(item, x, y) {
  const acts = ft.actions(item);
  if (!acts || !acts.length) return;
  ctx.querySelectorAll('[data-item-act]').forEach(b => b.remove());
  ctx.querySelectorAll('[data-ctx]').forEach(b => { b.style.display = 'none'; });
  const target = view === 'list' ? ft : fg;
  for (const a of acts) {
    const b = document.createElement('button');
    b.className = 'mi';
    if (a.danger) b.classList.add('danger');
    b.textContent = a.label;
    b.setAttribute('data-item-act', '');
    b.addEventListener('click', () => {
      target.dispatchEvent(new CustomEvent('ft-action', {
        bubbles: true, composed: true,
        detail: { action: a.action, item },
      }));
    });
    ctx.appendChild(b);
  }
  showCtx(x, y);
}

document.addEventListener('contextmenu', (e) => {
  if (e.target.closest('drop-menu, modal-dialog, #bar')) return;
  e.preventDefault();
  const hit = e.composedPath().find(el => el.__item);
  if (hit) {
    showItemCtx(hit.__item, e.clientX, e.clientY);
    return;
  }
  // whitespace: show dir actions, hide any leftover item actions
  ctx.querySelectorAll('[data-item-act]').forEach(b => b.remove());
  ctx.querySelectorAll('[data-ctx]').forEach(b => { b.style.display = ''; });
  showCtx(e.clientX, e.clientY);
});
ctx.addEventListener('dm-close', () => {
  ctx.style.display = 'none';
  // clean up item actions on close
  ctx.querySelectorAll('[data-item-act]').forEach(b => b.remove());
  ctx.querySelectorAll('[data-ctx]').forEach(b => { b.style.display = ''; });
});

// ---- toast ----
let toastTimer = null;
function toast(msg, err) {
  const s = $('status');
  s.textContent = msg;
  s.className = err ? 'err' : '';
  s.style.display = 'block';
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { s.style.display = 'none'; }, err ? 6000 : 2000);
}

load();
