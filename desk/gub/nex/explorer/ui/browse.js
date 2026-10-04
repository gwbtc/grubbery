// explorer browse app. Renders a directory listing via <file-table> and
// drives every action through POST endpoints — success re-fetches the
// listing in place (no page reloads), failure shows the server's text
// in the status toast. Dialogs are kit <modal-dialog>s. Navigation is
// client-side for dirs, normal for files.
const $ = (id) => document.getElementById(id);
const PREFIX = '/grubbery/ball';
let here = location.pathname;
let dirPath = here.slice(PREFIX.length) || '/';

function nav(p, push) {
  here = p;
  dirPath = p.slice(PREFIX.length) || '/';
  dirViewPath = p; // the directory tab follows the breadcrumbs
  if (push !== false) history.pushState(null, '', p);
  document.title = dirPath;
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
window.addEventListener('popstate', () => nav(location.pathname, false));

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
finderTree.onOpenDir = (item, path) => showDirView(path);
finderTree.onOpenFile = (item, path) => openTab(path);
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
const TABS_KEY = 'explorer-tabs';
const finderTabs = $('finder-tabs');
const finderDir = $('finder-dir');  // tab 0, fixed: the directory view
const dirFt = $('finder-dir-ft');
const openFiles = new Map(); // path -> { panel, fv }
let activeTabPath = null;
let dirViewPath = here; // what the directory tab shows: follows nav, retargets on sidebar clicks
// the tab-group's children are NOT all tabs — #finder-dir (the directory
// view) lives in there too, with no tab-label. tab-group's own indices only
// count labelled panels, so anything that indexes or persists tabs must go
// through this, never finderTabs.children directly.
const tabPanels = () => [...finderTabs.children].filter((p) => p.hasAttribute('tab-label'));

// reflect the active tab onto its tree row (cheap — no re-render)
function markActiveInTree(path) {
  activeTabPath = path;
  finderTree.markActive(path);
}

function selectPath(path) {
  const panels = tabPanels();
  const idx = panels.findIndex(p => p.dataset.path === path);
  if (idx >= 0) finderTabs.select(idx);
  markActiveInTree(path);
}

// persisted: the open FILE tabs (the directory tab is always there, never
// persisted) and which is active — '' meaning the directory tab
function saveTabs() {
  const panels = tabPanels();
  const activePanel = panels.find(p => !p.hidden);
  try {
    localStorage.setItem(TABS_KEY, JSON.stringify({
      paths: panels.map(p => p.dataset.path).filter(Boolean),
      active: activePanel === finderDir ? '' : (activePanel && activePanel.dataset.path),
    }));
  } catch (_) {}
}

function mountTab(path) {
  const name = path.slice(path.lastIndexOf('/') + 1) || path;
  const panel = document.createElement('div');
  panel.setAttribute('tab-label', name);
  panel.setAttribute('tab-title', path.slice(PREFIX.length) || path);
  panel.dataset.path = path;
  panel.style.height = '100%';
  finderTabs.appendChild(panel);
  // the FileView itself mounts lazily, on first selection — a FileView
  // fires two requests (?info=1, ?raw=1) the moment it mounts, and on a
  // pier that serializes requests, restoring N persisted tabs eagerly costs
  // 2N round trips before the page is usable
  openFiles.set(path, { panel, fv: null });
  return panel;
}
function ensureMounted(path) {
  const entry = openFiles.get(path);
  if (!entry || entry.fv) return;
  entry.fv = window.FileView.mount(entry.panel, { url: path, wrapKey: 'explorer-wrap' });
}

function openTab(path) {
  const isNew = !openFiles.has(path);
  if (isNew) mountTab(path);
  finderTabs.refresh();
  const settle = () => { selectPath(path); saveTabs(); };
  settle();
  // appendChild above queues a native slotchange that tab-group's own
  // listener rebuilds on asynchronously, defaulting back to tab 0 (nothing
  // here is `persist`ed) — that clobbers the select() just above. Re-assert
  // it once that settles.
  if (isNew) queueMicrotask(settle);
}

function closeTab(path) {
  const entry = openFiles.get(path);
  if (!entry) return;
  if (entry.fv) entry.fv.destroy();
  entry.panel.remove();
  openFiles.delete(path);
  finderTabs.refresh();
  const stillActive = tabPanels().find(p => !p.hidden);
  markActiveInTree(stillActive ? stillActive.dataset.path : null);
  saveTabs();
}

finderTabs.addEventListener('tg-close', (e) => closeTab(e.detail.panel.dataset.path));
finderTabs.addEventListener('tg-change', (e) => {
  const panel = tabPanels()[e.detail.index];
  if (panel) ensureMounted(panel.dataset.path);
  markActiveInTree(panel ? panel.dataset.path : null);
  saveTabs();
});

// restore persisted tabs on load (independent of which view is active —
// mounting is cheap and they should be there the moment you switch to cols)
(function restoreTabs() {
  let saved;
  try { saved = JSON.parse(localStorage.getItem(TABS_KEY) || 'null'); } catch (_) { saved = null; }
  // a bad persisted entry must never take the whole page down with it —
  // this runs at module top level, an exception here aborts everything
  const paths = (saved && Array.isArray(saved.paths) ? saved.paths : []).filter((p) => typeof p === 'string');
  if (!paths.length) return; // tab-group's own rebuild selects tab 0: the directory tab
  for (const path of paths) mountTab(path);
  finderTabs.refresh();
  // only the active tab's FileView mounts now (the others on first click);
  // '' = the directory tab was active
  if (saved.active === '') { finderTabs.select(0); return; }
  const active = paths.includes(saved.active) ? saved.active : paths[0];
  selectPath(active);
  // belt and braces: the appendChilds above queued a native slotchange
  // whose rebuild keeps the current selection, but re-assert once it settles
  queueMicrotask(() => selectPath(active));
})();

// ---- directory view: tab 0, fixed. Shows a directory's listing (the same
// <file-table> the list view uses, scoped to that directory). It follows
// the breadcrumbs (nav() retargets it to `here`) and clicking a directory
// in the sidebar retargets it to that one and selects it. No page
// navigation from the sidebar — `here` only moves via the breadcrumbs. A
// dir row in the listing drills further in; a file row opens a tab.
dirFt.columns = ft.columns.map((c) => c.key !== 'name' ? c : Object.assign({}, c, {
  link: (item) => dirViewPath.replace(/\/$/, '') + '/' + item.name,
}));
dirFt.actions = ft.actions;
dirFt.addEventListener('ft-navigate', (e) => {
  const { item, href } = e.detail;
  if (!item) return;
  if (item.kind === 'dir') showDirView(href); else openTab(href);
});
dirFt.addEventListener('ft-action', handleAction);
// select=false refreshes what the tab shows without stealing the selection
// (a nav or an action changed things while a file tab is up front)
async function showDirView(path, select = true) {
  dirViewPath = path;
  const disp = path.slice(PREFIX.length) || '/';
  finderDir.setAttribute('tab-label', disp === '/' ? '/' : disp.slice(disp.lastIndexOf('/') + 1) + '/');
  finderDir.setAttribute('tab-title', disp);
  finderTabs.refresh(); // attr edits don't fire slotchange; keeps the selection
  if (select) { finderTabs.select(0); markActiveInTree(null); }
  dirFt.showLoading();
  let d;
  try {
    const r = await fetch(path + '?list=1');
    if (!r.ok) throw new Error(r.status);
    d = await r.json();
  } catch (e) { toast('listing failed: ' + e, true); return; }
  if (dirViewPath !== path) return; // moved on while this was in flight
  d.children.forEach((c) => { c.__dir = path; }); // handleAction posts there
  dirFt.items = d.children;
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
  const itemDirDisp = itemDir.slice(PREFIX.length) || '/';
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
document.title = dirPath;

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
  ft.parentHref = dirPath !== '/' ? PREFIX + (dirPath.split('/').slice(0, -1).join('/') || '') : null;
  ft.items = data.children;
  fg.baseHref = here;
  fg.items = data.children;
  renderFinderTree(); // re-points the tree at the new root; drops stale caches
  showDirView(dirViewPath, false); // refresh tab 0: follows nav, and an action may have changed it
  renderManage();
  if ($('weir-modal').hasAttribute('open')) weirRefresh();
}

function renderCrumbs() {
  const c = $('crumbs');
  c.textContent = '';
  const segs = dirPath === '/' ? [] : dirPath.slice(1).split('/');
  const a = document.createElement('a');
  a.href = PREFIX;
  a.textContent = '/';
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
      l.href = PREFIX + acc;
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
      ? label : label + ' in ' + (createTarget.slice(PREFIX.length) || '/');
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
