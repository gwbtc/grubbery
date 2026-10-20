// <namespace-explorer>: the explorer as a web component, the directory
// browser. The page (browse.html) holds one full-size; an app page can
// hold one inside its own layout. Renders a directory listing via
// <file-table> and drives every action through POST endpoints — success
// re-fetches the listing in place (no page reloads), failure shows the
// server's text in the status toast. Dialogs are kit <modal-dialog>s.
// Navigation is client-side for dirs, normal for files.
//
//   el.mount({ url, scope, mount, page, storageKey })
//     url         the namespace path to open (the page passes location.pathname)
//     scope       ?scope= root, a namespace path (ignored when `mount` is set)
//     mount       {route, root, title, icon, viewers}: an app serving this
//                 explorer at its own route (see MOUNT below)
//     page        true when the explorer IS the page: it then writes the
//                 browser url (history), the document title and favicon,
//                 and marks <body> `cols` in the finder view. An embedding
//                 page leaves it false and owns those itself.
//     storageKey  prefix for the explorer's localStorage keys (default
//                 'explorer'); an embedder names its own so tabs, view and
//                 tree state don't collide with the explorer page's
//     view        'list' | 'grid' | 'cols': fix the view and hide the
//                 toggle (an embedder that is always the finder)
//
// Light DOM on purpose: FileView and the app panes mount into the normal
// document, inject their own styles, and the kit components stay reachable.
const PREFIX = '/grubbery/ball';
// this ship's own routes, the only places a mount may load a pane script or
// ask for viewers from: the kernel's /grubbery/... and the shell's /apps/grubbery/...
const OWN_ROUTE = /^\/(grubbery|apps\/grubbery)\/[^\s]*$/;

function setup(root, opts) {
  const $ = (id) => root.querySelector('#' + id);
  const K = opts.storageKey || 'explorer';
  const PAGE = !!opts.page;
  // SCOPE: the explorer opened at a root. ?scope=/apps/foo/projects makes
  // that directory "/" for the crumbs, the tab titles and the parent link,
  // and the scope's tabs persist on their own. An app page is the explorer
  // scoped at the app's root (a clanker collection, a repo's working tree);
  // an element page is the explorer scoped at the element. The namespace
  // paths underneath are unchanged: every request still goes to the real
  // /grubbery/ball url, nothing is folded or hidden.
  // MOUNT: an app serving this explorer at its own route, declared as
  // {route, root, title, icon, viewers}: urls under `route` are namespace
  // paths under `root`, so /grubbery/clanker/x is the explorer rooted at the
  // clanker collection, showing x. Same scope rules as ?scope=, with the
  // route's url form kept in history. `viewers` (optional) is an endpoint of
  // the app's that says, per path, which pane it opens in (see viewerFor):
  // its own files, in its own explorer, open in its own panes. The plain
  // explorer has no viewers; a path means a pane only where the mounting
  // app says so.
  const MOUNT = (opts.mount && opts.mount.route && opts.mount.root) ? opts.mount : null;
  const SCOPE = (MOUNT ? MOUNT.root : (opts.scope || '')).replace(/\/+$/, '');
  const ROOT = PREFIX + SCOPE;
  let SCOPE_NAME = (MOUNT && MOUNT.title) ? MOUNT.title : (opts.title || SCOPE.slice(SCOPE.lastIndexOf('/') + 1));
  // VIEW: without a mount, views are declared in the namespace: a
  // directory carries view.json ({viewers, title, icon}) and it governs
  // everything under it, the nearest one winning. The explorer asks its
  // server which declaration governs a directory (<dir>?view=1 walks up
  // and answers it plus `at`, the directory carrying it). Asked for the
  // root once, for the chrome (title, icon); and per tab, for the tab's
  // own directory, so a path finds its declaration wherever the sidebar
  // is rooted, above it or inside it. Paths are asked of `viewers`
  // relative to `at`: the declaring directory is the one that knows its
  // tree. Nothing registers: carrying the file is declaring.
  const viewCache = {};   // dir -> Promise<decl|null>
  function viewFor(dir) {
    if (MOUNT) return Promise.resolve(null);
    if (!viewCache[dir]) viewCache[dir] = (async () => {
      try {
        const r = await fetch(dir + '?view=1', { cache: 'no-store' });
        const v = r.ok ? await r.json() : null;
        if (v && typeof v.at === 'string' && typeof v.viewers === 'string' && OWN_ROUTE.test(v.viewers)) return v;
      } catch (e) { /* no views: the plain explorer */ }
      return null;
    })();
    return viewCache[dir];
  }
  const viewReady = (MOUNT || !SCOPE) ? Promise.resolve() : viewFor(ROOT).then((v) => {
    if (!v) return;
    if (typeof v.title === 'string' && v.title && !opts.title) { SCOPE_NAME = v.title; setTitle(); }
    if (PAGE && typeof v.icon === 'string' && OWN_ROUTE.test(v.icon)) {
      const link = document.querySelector('link[rel="icon"]');
      if (link) link.href = v.icon;
    }
  });
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
  let here = fromUrl(opts.url || ROOT);
  let pageNav = true;              // the finder owns url routing until a client takes the page
  let dirPath = rel(here);
  // the page's title follows the explorer only when the explorer is the page
  const setTitle = () => { if (PAGE) document.title = SCOPE ? (SCOPE_NAME + (dirPath === '/' ? '' : ' ' + dirPath)) : dirPath; };

  function nav(p, push) {
    here = p;
    dirPath = rel(p);
    if (push !== false && PAGE) history.pushState(null, '', toUrl(p));
    setTitle();
    renderCrumbs();
    if (view === 'list') ft.showLoading(); else fg.showLoading();
    load();
  }
  root.addEventListener('click', (e) => {
    const a = e.target.closest('a[data-nav]');
    if (!a || e.metaKey || e.ctrlKey || e.shiftKey) return;
    e.preventDefault();
    nav(new URL(a.href).pathname);
  });
  // The phone client takes the whole page and keeps its OWN position in
  // history, so the finder's url routing must stand down — otherwise its
  // popstate runs first and re-navigates the finder (title, crumbs, a listing
  // load) underneath the client that is actually on screen.
  if (PAGE) window.addEventListener('popstate', () => { if (!pageNav) return; nav(fromUrl(location.pathname), false); });
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
      // files: ✓ compiled, ✗ build error, blank for non-code or non-hoon.
      // Click the file (its name) to open the viewer's Build tab for the
      // detail/tang. Directories: a tally of the artifacts below them,
      // "✓ 12" when all compiled, "✗ 2 · ✓ 10" when some failed — a
      // failure anywhere below shows at every level, so open the dir to
      // drill down to it. Blank when nothing below has been built.
      format: (v, item) => {
        if (item.kind === 'dir') {
          if (!v || typeof v !== 'object') return '';
          return v.fail ? '✗ ' + v.fail + ' · ✓ ' + v.ok : '✓ ' + v.ok;
        }
        return v === 'vase' ? '✓' : v === 'tang' ? '✗' : '';
      },
      decorate: (cell, item) => {
        const v = item.built;
        if (item.kind === 'dir') {
          if (!v || typeof v !== 'object') return;
          // each count in its own color: the ✗ tally red and bold, the ✓
          // tally green, whatever the mix
          cell.textContent = '';
          if (v.fail) {
            const bad = document.createElement('span');
            bad.textContent = '✗ ' + v.fail;
            bad.style.color = '#cf222e'; bad.style.fontWeight = '700';
            cell.appendChild(bad);
            cell.appendChild(document.createTextNode(' · '));
            cell.title = v.fail + ' build error' + (v.fail === 1 ? '' : 's') + ' below — open the directory to find them';
          } else {
            cell.title = v.ok + ' artifact' + (v.ok === 1 ? '' : 's') + ' below, all compiled';
          }
          const good = document.createElement('span');
          good.textContent = '✓ ' + v.ok;
          good.style.color = '#116329';
          cell.appendChild(good);
          return;
        }
        if (v === 'vase') { cell.style.color = '#116329'; }
        else if (v === 'tang') {
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
  try { badgesOn = localStorage.getItem(K + '-badges') !== 'off'; } catch (e) {}

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
    finderTree.persistKey = K + '-tree:' + here;
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
    try { localStorage.setItem(K + '-badges', badgesOn ? 'on' : 'off'); } catch (e) {}
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
  const TABS_KEY = K + '-tabs' + SCOPE;   // a scope keeps its own tabs
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
    try { return localStorage.getItem(K + '-dir-mode') === 'grid' ? 'grid' : 'table'; } catch (_) { return 'table'; }
  }
  // active/idle look for a tab's view-mode buttons — mirrors the top bar's
  // #view-toggle .on state (blue) vs the plain bordered button
  function styleModeBtn(btn, active) {
    // a disabled mode button is a declared pane that may not run here:
    // muted, crossed, its title says why (set where the viewer was asked)
    if (btn.disabled) {
      btn.style.background = '#f6f8fa'; btn.style.borderColor = '#d0d7de';
      btn.style.color = '#8b949e'; btn.style.fontWeight = '400'; btn.style.cursor = 'not-allowed';
      return;
    }
    btn.style.cursor = '';
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
      panel._modeWrap.style.display = 'inline-flex';   // not '': the gap needs flex
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
      let viewer = await viewerFor(path, 'dir', neck);
      if (panel.dataset.path !== path) return; // moved on while in flight
      // a pane that is declared but may not run here: its button shows,
      // disabled and saying why, so the declaration is visible even though
      // the pane is not; the tab falls back to rows or desktop
      const blocked = viewer && viewer.blocked ? viewer : null;
      if (blocked) viewer = null;
      panel._dirViewer = viewer;
      panel._modeView.style.display = (viewer || blocked) ? '' : 'none';
      panel._modeView.disabled = !!blocked;
      panel._modeView.title = blocked ? ('the "' + blocked.label + '" pane is declared for this path but not allowed: ' + blocked.blocked) : '';
      if (viewer) panel._modeView.textContent = viewer.label || 'View';
      if (blocked) panel._modeView.textContent = blocked.label + ' ⊘';
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
      const opts = { url: path, wrapKey: K + '-wrap', crumbBase: ROOT, onNavigate: (u) => navigateTab(panel, u, 'dir') };
      // a registered viewer for this file's mark becomes FileView's first
      // pane (the file itself stays one click away in Source)
      const viewer = await viewerFor(path, 'file');
      if (panel.dataset.path !== path) return; // moved on while in flight
      if (viewer && !viewer.blocked) opts.viewer = viewer;
      panel._fv = window.FileView.mount(panel._body, opts);
      // a declared pane that may not run: say so above the file, so the
      // declaration is visible even though the pane is not
      if (viewer && viewer.blocked) {
        const note = document.createElement('div');
        note.style.cssText = 'margin:0 0 8px;padding:6px 10px;border:1px solid #e0d4f7;background:#f6f3fc;border-radius:7px;font:12px/1.5 -apple-system,sans-serif;color:#57606a';
        note.innerHTML = '<b style="color:#8250df">' + viewer.label + ' ⊘</b> a pane is declared for this file but not allowed here: ' + viewer.blocked;
        panel._body.insertBefore(note, panel._body.firstChild);
      }
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
  // a rule the explorer enforces. The script runs with this page's reach, so
  // only this ship's own routes are loaded: a /grubbery/... path, never
  // another origin.
  const MOUNT_VIEWERS = (MOUNT && typeof MOUNT.viewers === 'string' && OWN_ROUTE.test(MOUNT.viewers)) ? MOUNT.viewers : null;
  const viewerLoads = {};      // script url -> Promise
  // a stock viewer by name + script: the explorer's own renderers (the tree),
  // loaded once, mounted like any declared one. null when it will not load.
  async function stockViewer(view, src) {
    window.Viewers = window.Viewers || {};
    if (!window.Viewers[view]) {
      if (!viewerLoads[src]) viewerLoads[src] = new Promise((res, rej) => { const s = document.createElement('script'); s.src = src; s.onload = res; s.onerror = () => rej(new Error('viewer failed to load: ' + src)); document.head.appendChild(s); });
      try { await viewerLoads[src]; } catch (_) { return null; }
    }
    const v = window.Viewers[view];
    return (v && typeof v.mount === 'function') ? v : null;
  }
  // `view`: the moment's ?view= when it is not one the host renders itself
  // (rows|grid|tree); the app answers its own view names (a selector, a
  // record form) and the bare path (no view) with whatever it opens as
  //
  // TODO(perf): every leaf costs three serial trips: the ?list=1 probe in
  // paneContent, this ask, then its data. (1) An app answering a LAYOUT
  // already knows the layout's leaves: let it inline their rules
  // ({layout, rules: {path: rule}}) so leaves under it skip the probe and
  // the ask. (2) Then let it hydrate: each visible leaf's first body in the
  // same answer, handed to mount as initial state → one request per
  // visible layout on a cold open. See project memory "gmux".
  async function viewerFor(path, kind, neck, askView) {
    try {
      await viewReady;
      // who answers, and from where paths are relative: the mount's root,
      // or the directory carrying the view.json that governs THIS path
      // (the nearest at or above the tab's own directory)
      const VIEW = MOUNT ? null : await viewFor(kind === 'dir' ? path : path.slice(0, path.lastIndexOf('/')) || PREFIX);
      const viewers = MOUNT ? MOUNT_VIEWERS : (VIEW ? VIEW.viewers : null);
      const base = MOUNT ? ROOT : (VIEW ? PREFIX + VIEW.at.replace(/\/+$/, '') : null);
      if (!viewers || !base) return null;
      const rel = path === base ? '' : path.startsWith(base + '/') ? path.slice(base.length) : null;
      if (rel === null) return null; // outside the declaring directory: not its path
      let blot = '';
      if (kind !== 'dir') {
        const info = await fetch(path + '?info=1').then((r) => r.json());
        blot = ((info && info.blot) || '').replace(/^\//, '');
      }
      // the path as the kernel spells it: its directories from the declaring
      // one down, each with its neck, so a rule can switch on the nexuses
      // along the way and not only on names
      let pant = '';
      try {
        const pr = await fetch(path + '?pant=1&from=' + encodeURIComponent(base.slice(PREFIX.length) || '/'), { cache: 'no-store' });
        const pj = pr.ok ? await pr.json() : null;
        if (pj && Array.isArray(pj.pant)) pant = JSON.stringify(pj.pant);
      } catch (e) { /* the rule gets the path alone */ }
      // a dir is told by its neck (the nexus it runs, '' when plain), a file by its blot
      const q = '?path=' + encodeURIComponent(rel) + '&kind=' + (kind === 'dir' ? 'dir' : 'file') +
        '&blot=' + encodeURIComponent(blot) + '&neck=' + encodeURIComponent(kind === 'dir' ? (neck || '') : '') +
        (pant ? '&pant=' + encodeURIComponent(pant) : '') + (askView ? '&view=' + encodeURIComponent(askView) : '');
      const r = await fetch(viewers + q, { cache: 'no-store' });
      if (!r.ok) return null;
      const text = await r.text();
      const rule = text.trim() ? JSON.parse(text) : null;
      if (!rule || typeof rule !== 'object') return null;
      // {layout}: the app says this DIRECTORY opens as a layout (a url on
      // this ship) rooted at it: entry paths in the layout starting with
      // './' resolve against the opened dir. One layout, any instance.
      if (typeof rule.layout === 'string') return OWN_ROUTE.test(rule.layout) ? { layout: rule.layout } : null;
      const src = rule.script, view = rule.view;
      if (typeof view !== 'string' || typeof src !== 'string' || !OWN_ROUTE.test(src)) { toast('viewer refused: needs a view name and a script on this ship', true); return null; }
      window.Viewers = window.Viewers || {};
      if (!window.Viewers[view]) {
        if (!viewerLoads[src]) viewerLoads[src] = new Promise((res, rej) => {
          const s = document.createElement('script');
          s.src = src; s.onload = res; s.onerror = () => rej(new Error('viewer failed to load: ' + src));
          document.head.appendChild(s);
        });
        try { await viewerLoads[src]; }
        catch (e) {
          // the pane exists but its script would not run. Say WHY, so a
          // declared view that is not allowed here is shown as such and
          // not mistaken for no view: the kernel marks a script it served
          // inert because its app's weir does not reach eyre
          // (x-grubbery-serve: sandboxed); a 404 is a missing script;
          // anything else is a broken one.
          const why = await blockedWhy(src);
          return { label: view, blocked: why };
        }
      }
      const v = window.Viewers[view];
      if (!v || typeof v.mount !== 'function') return { label: view, blocked: 'the script loaded but registered no "' + view + '" pane' };
      // the app's args ride along with the pane; a mount passes them through
      const args = (rule.args && typeof rule.args === 'object') ? rule.args : {};
      // follow: the roads this instance's rendering depends on, [{road, body?}].
      // The explorer keeps them on its one stream (see live) and tells the
      // mounted pane when they move; absent → the rendering is static.
      const follow = Array.isArray(rule.follow) ? rule.follow.filter((f) => f && typeof f.road === 'string' && f.road.startsWith('/')).map((f) => ({ road: f.road, body: !!f.body, fold: !!f.fold })) : null;
      return { label: v.label, follow, mount: (root, opts) => v.mount(root, Object.assign({}, opts, { args })) };
    } catch (e) { toast('viewer: ' + e.message, true); return null; }
  }
  async function blockedWhy(src) {
    try {
      const r = await fetch(src, { cache: 'no-store' });
      if (r.status === 404) return 'its script is missing';
      if (!r.ok) return 'its script could not be fetched (' + r.status + ')';
      if (r.headers.get('x-grubbery-serve') === 'sandboxed') return 'sandboxed: the app declaring it may not serve code (its weir does not reach eyre)';
      return 'its script failed to run';
    } catch (e) { return 'its script could not be fetched'; }
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
    // the same spacing as the top bar's #view-toggle: a 2px gap, roomy buttons
    modeWrap.style.cssText = 'display:inline-flex;gap:2px;flex:none;margin-left:10px';
    const viewBtn = (glyph, title) => {
      const b = document.createElement('button');
      b.textContent = glyph; b.title = title;
      b.style.cssText = 'all:unset;cursor:pointer;padding:3px 11px;border-radius:6px;font-size:12px;border:1px solid #d0d7de;background:#fff;color:#24292f;line-height:1.4';
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
      if (m !== 'view') { try { localStorage.setItem(K + '-dir-mode', m); } catch (_) {} }
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

  // experimental: a tab holding a <gmux-host> tiling workspace. Each pane is a
  // <tab-group> of file views (dir tables / FileViews). Click an item -> new TAB
  // in that pane; cmd/ctrl/shift-click -> new PANE beside it. A hover grip
  // (top-left) carries close-pane / split. One tab shows no strip; closing the
  // last tab leaves the pane empty (close the pane from the grip or Ctrl-B x).
  // experimental: a tab holding a <gmux-host> tiling workspace. gmux owns
  // the tabs + per-tab history now; the host just renders a path's content and
  // routes navigation back in (plain = in place, ⌘-click = new pane). The whole
  // workspace persists to localStorage (the `persist` attr) as pure data.
  // gmux holds bare NAMESPACE paths (e.g. /apps/explorer.explorer), not
  // http urls — the /grubbery/ball serve prefix is added here, only at fetch.
  // a moment is a path, optionally with ?args saying HOW that path is looked
  // at (a dir's ?view=rows|grid|tree). Args never change what is fetched.
  // psNs/psUrl/psBase see the path alone; psArgs reads the args; psMoment
  // keeps both when a link is followed.
  const psSplit = (p) => { const s = p || ''; const i = s.indexOf('?'); return i < 0 ? { path: s, query: '' } : { path: s.slice(0, i), query: s.slice(i + 1) }; };
  const psArgs = (p) => { const o = {}; for (const kv of psSplit(p).query.split('&')) { if (!kv) continue; const j = kv.indexOf('='); const k = decodeURIComponent(j < 0 ? kv : kv.slice(0, j)); o[k] = j < 0 ? '1' : decodeURIComponent(kv.slice(j + 1)); } return o; };
  const psNs = (p) => { const q = psSplit(p).path; const n = (q && q.startsWith(PREFIX)) ? q.slice(PREFIX.length) : (q || '/'); return n || '/'; };
  const psMoment = (p) => { const q = psSplit(p).query; return psNs(p) + (q ? '?' + q : ''); };
  const psUrl = (p) => { const n = psNs(p); return n === '/' ? PREFIX : PREFIX + n; };   // root → /grubbery/ball (no trailing slash)
  const psBase = (p) => psNs(p).replace(/\/$/, '').split('/').filter(Boolean).pop() || '/';
  // ---- @name prefixes: a path under a /sys/link name ----
  // A moment may start with a NAME instead of a place: `@forge/repos` is the
  // app claiming `forge` (earliest claimant) plus `/repos`. Names are paths;
  // a one-segment name is bare, a longer one is quoted: `@'/some/name'/x`.
  // A digit before the name picks that claimant instead of the first:
  // `@2forge/x`, `@2'/some/name'/x`. The moment STAYS symbolic — the pane
  // holds `@forge/repos`, links made under it are `@forge/repos/…`, and the
  // name is resolved at fetch time, so a layout outlives the app moving and
  // a re-claim shows as the pane following it. The resolved place is the
  // navbar's tooltip. The claimant list is read from the ball as json
  // (the lanes mark: an array of paths) and cached per name; the cache is
  // dropped and the pane re-rendered when that dest.lanes moves.
  const psLink = (ns) => {
    const m = /^@(\d*)(?:'([^']*)'|([^/']*))(\/.*)?$/.exec(ns || '');
    if (!m) return null;
    const raw = m[2] != null ? m[2] : m[3];
    if (!raw) return null;
    const name = '/' + raw.replace(/^\/+/, '').replace(/\/+$/, '');
    return { name, idx: m[1] ? parseInt(m[1], 10) : 1, rest: (m[4] || '').replace(/^\/+/, ''), head: ns.slice(0, ns.length - (m[4] || '').length) };
  };
  const psLinkRoad = (name) => '/sys/link' + name + '/dest.lanes';
  const psLanes = new Map();                                                // name → Promise<[path]>
  const psLinkLanes = (name) => {
    let p = psLanes.get(name);
    if (!p) {
      p = fetch(PREFIX + psLinkRoad(name), { cache: 'no-store' }).then((r) => r.ok ? r.json() : []).then((a) => Array.isArray(a) ? a.filter((s) => typeof s === 'string') : []);
      p.catch(() => psLanes.delete(name));
      psLanes.set(name, p);
    }
    return p;
  };
  const psResolved = new Map();                                             // symbolic ns → resolved ns (for hints)
  // the absolute path a symbolic ns stands for; rejects with a reason when
  // the name has no claimant (or not that many), or a file lane gets a suffix
  async function psResolve(ns) {
    const l = psLink(ns);
    if (!l) return ns;
    const lanes = await psLinkLanes(l.name);
    const lane = lanes[l.idx - 1];
    if (!lane) throw new Error(lanes.length ? 'no claimant #' + l.idx + ' for ' + l.head + ' (' + lanes.length + ' claim it)' : 'no claimant for ' + l.head);
    const root = lane.replace(/\/$/, '');
    const abs = l.rest ? root + '/' + l.rest : (root || '/');
    psResolved.set(ns, abs);
    return abs;
  }
  // the moment one step up: within the suffix it stays symbolic; at the name
  // itself it is the claimant's own parent, a real place
  const psUp = (ns, abs) => {
    const l = psLink(ns);
    if (!l) return ns.replace(/\/$/, '').replace(/\/[^/]+$/, '');
    if (l.rest.replace(/\/$/, '').includes('/')) return ns.replace(/\/$/, '').replace(/\/[^/]+$/, '');
    if (l.rest.replace(/\/$/, '')) return l.head;
    return abs.replace(/\/$/, '').replace(/\/[^/]+$/, '');
  };
  // ---- how a rendering names another place ----
  // A link (open/close) or a layout entry is spelled one of three ways, and
  // the host accepts all three:
  //   absolute   /apps/x/y                 that place
  //   by name    @forge/repos/x            under a /sys/link name, any app's
  //   relative   ./chats/build  ../other   against the moment it was spelled
  //              in, AS SPELLED: under @clanker it stays under @clanker,
  //              under an absolute path it stays absolute
  // A viewer therefore never needs to know where it lives to point at its
  // own children, and can point at another app by name without knowing
  // where that one lives either. `?args` ride along untouched.
  const psRel = (ns, href) => {
    const { path: p, query } = psSplit(href || '');
    if (!/^\.\.?(\/|$)/.test(p)) return href;
    let base = (ns || '/').replace(/\/$/, '');
    for (const seg of p.split('/')) {
      if (seg === '.' || seg === '') continue;
      if (seg === '..') base = psUp(base, psResolved.get(base) || base);
      else base = (base === '/' ? '' : base) + '/' + seg;
    }
    if (!base) base = '/';
    return base + (query ? '?' + query : '');
  };
  const TREE_JS = PREFIX + '/apps/explorer.explorer/tree-viewer.js';           // the explorer's own tree, a stock viewer
  // a pane's waiting state: `text` over an optional `sub` line (what is being
  // fetched); psWaitFail turns the same block into the failure it ended in
  const psWait = (el, text, sub) => {
    psChrome();                                                               // its styles ride with the workspace chrome: make sure they are in
    el.innerHTML = ''; el.className = 'ps-wait'; el.style.cssText = 'height:100%';
    const ring = document.createElement('div'); ring.className = 'ps-wait-ring';
    const t = document.createElement('div'); t.className = 'ps-wait-text'; t.textContent = text;
    el.append(ring, t);
    if (sub) { const s = document.createElement('div'); s.className = 'ps-wait-sub'; s.textContent = sub; s.title = sub; el.appendChild(s); }
  };
  const psWaitFail = (el, text, sub) => { psWait(el, text, sub); el.classList.add('fail'); };
  // back to a bare content element once the answer is in
  const psClear = (el) => { el.innerHTML = ''; el.className = ''; el.style.cssText = 'height:100%;overflow:auto'; };
  // a path's name + icon for its tab chip: basename + the kind we learn while
  // listing (dir) or opening (file). redrawBars() sharpens the glyph once known.
  const psKind = new Map();
  // a tab is its name; no glyph guessed from kind. A moment with ?page= (a
  // rendering's own sub-page: the docs pane) is named by that page, so the
  // history reads as the pages visited, not the same grub nine times
  function paneTabInfo(p) { const pg = psArgs(p).page; return { icon: '', label: pg ? (pg.split('/').filter(Boolean).pop() || pg) : psBase(p), dead: psDead.has(psNs(p).replace(/\/$/, '') || '/') }; }
  // ---- deletion: a moment whose path is gone is DEAD, not closed ----
  // Every content moment follows its parent dir, folded (one event when a
  // direct child is made or culled). On that event the moment's own path is
  // checked: gone → its rendering is torn down and replaced by the failed
  // wait block, its follows dropped, its path marked in psDead, and the tab
  // chips redrawn. Only the leaf: a layout tab above it is a container, not
  // a path, and says nothing of its own (its inner tabs do). A path that
  // comes back revives the moment with a fresh render. Nothing closes by
  // itself: the user does.
  // The watch is per KIND, and never on a parent (a parent can be the root or
  // an app dir, and a fold keep there diffs the whole namespace on every write;
  // that wedges the ship). A file moment keeps its own file, one grub: `del`
  // kills it, `new` revives it. A dir moment keeps nothing extra: its listing
  // already follows the dir, and a refresh that finds it gone renders dead.
  const psDead = new Set();
  // `why` is what the block says: 'deleted' when the stream saw it go (a
  // del event), 'does not exist' when it was simply never there (a 404 on
  // the first look, a layout naming a dir nothing has made yet)
  function psMarkDead(ps, el, ns, why) {
    const key = ns.replace(/\/$/, '');
    if (el._dead) return;
    el._dead = true;
    try { if (el._live) el._live(); } catch (_) {} el._live = null;
    try { if (el._fv && el._fv.destroy) el._fv.destroy(); } catch (_) {} el._fv = null;
    el._menu = null; el._dirUrl = null;
    psWaitFail(el, why || 'does not exist', key);
    psDead.add(key);
    ps.redrawBars();
  }
  // ns is the moment's path (symbolic under an @name: the dead key the tab
  // chips look up); abs is the place actually kept
  function psWatchFile(ps, paneId, el, ns, abs) {
    if (!abs || abs === '/') return () => {};
    const key = ns.replace(/\/$/, '');
    const idOf = () => { const p = el.closest('.ps-pane'); return p ? p.dataset.paneId : paneId; };
    return live([{ road: abs.replace(/\/$/, '') }], (ev) => {
      if (ev.kind === 'del') psMarkDead(ps, el, ns, 'deleted');
      else if (el._dead) { psDead.delete(key); ps.redrawBars(); ps.refresh(idOf()); }
    }, null);
  }
  // an @name moment follows its name's dest.lanes: a re-claim or a move of
  // the app drops the cached lanes and re-renders the pane where it sits
  function psWatchLink(ps, paneId, el, ns) {
    const l = psLink(ns);
    if (!l) return () => {};
    const idOf = () => { const p = el.closest('.ps-pane'); return p ? p.dataset.paneId : paneId; };
    return live([{ road: psLinkRoad(l.name) }], () => { psLanes.delete(l.name); psResolved.delete(ns); ps.refresh(idOf()); }, null);
  }
  // live: the page's one SSE stream and the follow set behind it. Every
  // rendered instance registers the roads it depends on (a dir road ends in
  // '/', a file road does not); the union is POSTed to the ship whenever it
  // changes, and each incoming `new|upd|del <path>` is routed to the instances
  // whose road covers that path. An instance with onUpdate gets every event
  // as it comes and patches itself; one without is refetched, debounced so a
  // burst under its road costs one redraw. The stream reconnects on its own
  // and re-sends the set, since a fresh session starts with nothing followed.
  const live = (() => {
    const insts = new Set();
    let sid = null, lastSent = null, backoff = 1000, started = false;
    const SSE = PREFIX.replace(/\/ball$/, '/explorer') + '/sse', FOLLOW = PREFIX.replace(/\/ball$/, '/explorer') + '/follow';
    function want() {
      const m = new Map();
      // the same road wanted two ways takes the richer: body beats names,
      // and names (per-file events) beats fold (one event for the dir)
      for (const i of insts) for (const f of i.follow) { const p = m.get(f.road); m.set(f.road, { road: f.road, body: !!(f.body || (p && p.body)), fold: !!(f.fold && (!p || p.fold)) }); }
      return [...m.values()].sort((a, b) => a.road < b.road ? -1 : 1);
    }
    async function sync() {
      if (!sid) return;
      const roads = want(), key = JSON.stringify(roads);
      if (key === lastSent) return;
      lastSent = key;
      try { await fetch(FOLLOW, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ s: sid, roads }) }); }
      catch (_) { lastSent = null; }
    }
    function covers(road, path) { return road.endsWith('/') ? path.startsWith(road) : path === road; }
    function dispatch(kind, path, body) {
      for (const i of insts) for (const f of i.follow) if (covers(f.road, path)) { i.hit({ road: f.road, kind, path, body }); break; }
    }
    function parse(block) {
      let ev = null; const data = [];
      for (const line of block.split('\n')) {
        if (line.startsWith('event: ')) ev = line.slice(7);
        else if (line.startsWith('data: ')) data.push(line.slice(6));
        else if (line.startsWith('data:')) data.push(line.slice(5));
      }
      if (!ev) return;
      if (ev.startsWith('session ') || ev === 'session') { sid = data.join('\n').trim(); lastSent = null; backoff = 1000; sync(); return; }
      const sp = ev.indexOf(' '); if (sp < 0) return;
      const kind = ev.slice(0, sp), path = ev.slice(sp + 1), text = data.join('\n');
      let body = null; if (text) { try { body = JSON.parse(text); } catch (_) { body = text; } }
      if (kind !== 'old') dispatch(kind, path, body);          // old = replay on follow; the instance already fetched that state
    }
    async function connect() {
      if (started) return; started = true;
      for (;;) {
        try {
          const r = await fetch(SSE, { headers: { Accept: 'text/event-stream' }, cache: 'no-store' });
          if (!r.ok || !r.body) throw new Error('sse ' + r.status);
          const rd = r.body.getReader(), dec = new TextDecoder(); let buf = '';
          for (;;) {
            const c = await rd.read(); if (c.done) break;
            buf += dec.decode(c.value, { stream: true });
            const blocks = buf.split('\n\n'); buf = blocks.pop();
            for (const b of blocks) if (b.trim()) parse(b);
          }
        } catch (_) { /* fall through to reconnect */ }
        sid = null;
        await new Promise((res) => setTimeout(res, backoff)); backoff = Math.min(backoff * 2, 15000);
      }
    }
    // register: follow = [{road, body?}]; onEvent(ev) patches in place, or
    // null → refetch() (debounced); gate(ev) optionally drops events the
    // instance does not care about. Returns the unregister.
    // TODO(perf): refetches are debounced per instance only; a burst under a
    // busy dir (a turn writing log + status + runs) makes several panes
    // refetch the same URL at once. One shared in-flight fetch per URL
    // would dedupe that.
    return function register(follow, onEvent, refetch, gate) {
      if (!follow || !follow.length) return () => {};
      let timer = null;
      const inst = { follow, hit(ev) {
        if (gate && !gate(ev)) return;
        if (onEvent) { try { onEvent(ev); } catch (_) {} return; }
        clearTimeout(timer); timer = setTimeout(() => { timer = null; try { refetch(); } catch (_) {} }, 120);
      } };
      insts.add(inst); connect(); sync();
      return () => { clearTimeout(timer); insts.delete(inst); sync(); };
    };
  })();
  // wire a mounted pane content to live: the viewer's declared follow, or the
  // built-in rendering's own path. A viewer's onUpdate (on what mount returned)
  // takes the events; without one, the pane re-renders
  // content just mounted in a pane: if it is the active pane and the
  // keyboard is not somewhere on purpose (nothing focused, or focus sat on
  // this pane's bare content while it loaded), land the keyboard on it:
  // the chat's message box, a navigator's list. Covers page load, where
  // the active pane's content arrives after the workspace is built.
  function psLanded(ps, paneId, el) {
    const p = el.closest('.ps-pane'), id = p ? p.dataset.paneId : paneId;
    if (!ps.cursor) return;
    // the active pane, or a container selected above it (a layout whose
    // first leaf this is)
    if (ps.cursor.id !== id) { const cdom = ps.querySelector('.ps-pane[data-pane-id="' + ps.cursor.id + '"]'); if (!cdom || !cdom.contains(el)) return; }
    const a = document.activeElement;
    if (a && a !== document.body && a !== ps && a !== el && !el.contains(a)) return;   // ps itself: the host's own focus on load
    ps.focusContent(id);
  }
  function paneLive(ps, paneId, el, follow, gate) {
    if (!el.isConnected) return;                                   // the pane moved on while we fetched: nothing to keep live
    const fv = el._fv, on = (fv && typeof fv.onUpdate === 'function') ? (ev) => fv.onUpdate(ev) : null;
    // a split moves this element into a new child pane: find the pane it is
    // in NOW rather than the id it mounted under
    const idOf = () => { const p = el.closest('.ps-pane'); return p ? p.dataset.paneId : paneId; };
    el._live = live(follow, on, () => ps.refresh(idOf()), gate);
  }
  // ---- workspace actions: right-click menus and inline asks, no modals ----
  // A rendering owns its menu: a viewer exposes contextMenu(e) → [{label, run,
  // danger}] on what mount returned, a built-in rendering sets el._menu. The
  // workspace owns one popup and one inline strip. Server writes POST to the
  // item's own dir; the stream refreshes whatever shows it, so nothing reloads.
  let psCtx = null, psCss = false;
  function psChrome() {
    if (!psCss) {
      psCss = true;
      const s = document.createElement('style');
      s.textContent =
        /* an action view: one card, centered, the same bones every time:
           header (verb, then the path it acts on) · body (fields) · footer (cancel, then the verb) */
        /* the card survives a squeeze: the wrap is a container, and below 440px the
           padding tightens, footers and pickers wrap, the weir grid stacks, and
           nothing keeps a fixed width. Vertically the pane scrolls; the top padding is
           capped so a short pane shows the card, not its margin. */
        /* a pane waiting on the ship (a layout being fetched): a quiet ring and a
           label, centered; the same block names a failure with the ring stopped */
        /* shown only after a beat, so a fast answer never flashes it */
        '.ps-wait{height:100%;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:12px;color:#8b949e;font:13px -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;background:#fff;user-select:none;animation:ps-wait-in .25s .2s both}' +
        '@keyframes ps-wait-in{from{opacity:0}to{opacity:1}}' +
        '.ps-wait.fail{animation:none}' +
        '.ps-wait-ring{width:22px;height:22px;border-radius:50%;border:2px solid #eaeef2;border-top-color:#8b949e;animation:ps-spin .9s linear infinite}' +
        '.ps-wait-text{letter-spacing:.01em}.ps-wait-sub{font:11px ui-monospace,SFMono-Regular,Menlo,monospace;color:#8b949e;max-width:80%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +
        '.ps-wait.fail .ps-wait-ring{animation:none;border-color:#ffcecb;border-top-color:#cf222e}.ps-wait.fail .ps-wait-text{color:#cf222e}' +
        '@keyframes ps-spin{to{transform:rotate(360deg)}}' +
        '.ps-form-wrap{min-height:100%;box-sizing:border-box;padding:min(48px,6vh) 24px 24px;display:flex;justify-content:center;align-items:flex-start;background:#f6f8fa;font:13px -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:#24292f;container-type:inline-size}' +
        /* a floor: below 260px the pane scrolls the card sideways instead of crushing it;
           every text run inside is one line, clipped with an ellipsis, full value on hover */
        '.ps-form{width:100%;max-width:520px;min-width:260px;background:#fff;border:1px solid #d0d7de;border-radius:10px;box-shadow:0 1px 3px rgba(31,35,40,.06)}' +
        '.ps-form-wrap{overflow-x:auto}' +
        '.ps-form-verb,.ps-form-path,.ps-form label span,.ps-weir-k,.ps-file > span:first-child{overflow:hidden;text-overflow:ellipsis;white-space:nowrap;min-width:0}' +
        '.ps-form-path{word-break:normal}' +
        '.ps-form-foot{flex-wrap:wrap}.ps-form-foot button{white-space:nowrap;min-width:0;overflow:hidden;text-overflow:ellipsis}' +
        '.ps-weir-road{max-width:100%;min-width:0}.ps-weir-road > span{overflow:hidden;text-overflow:ellipsis;white-space:nowrap;min-width:0}' +
        '.ps-drop{overflow:hidden}.ps-drop > span{display:block;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +
        '@container (max-width:440px){.ps-form-wrap{padding:10px 8px}.ps-form-head{padding:12px 14px 10px}.ps-form-body{padding:12px 14px;gap:10px}.ps-form-foot{padding:10px 14px}.ps-form-foot button{flex:1 1 auto}' +
        '.ps-weir-cat{grid-template-columns:1fr;gap:4px}.ps-weir-k{padding-top:0}.ps-weir-roads input{width:100%}.ps-drop{padding:16px 10px}.ps-drop-acts{flex-wrap:wrap}.ps-drop-acts button{flex:1 1 auto}.ps-form button.ghost-danger{margin-right:0}}' +
        '.ps-form-head{padding:16px 20px 14px;border-bottom:1px solid #eaeef2}.ps-form-verb{font-weight:600;font-size:15px;line-height:1.3}.ps-form-path{margin-top:4px;font:12px ui-monospace,SFMono-Regular,Menlo,monospace;color:#57606a;word-break:break-all}' +
        '.ps-form-body{padding:16px 20px;display:flex;flex-direction:column;gap:14px}.ps-form-note{color:#57606a;line-height:1.5}' +
        '.ps-form label{display:block}.ps-form label span{display:block;font-size:12px;font-weight:600;color:#57606a;margin-bottom:5px}' +
        '.ps-form input,.ps-form select{width:100%;box-sizing:border-box;font:13px ui-monospace,SFMono-Regular,Menlo,monospace;padding:7px 10px;border:1px solid #d0d7de;border-radius:6px;background:#fff;color:#24292f}' +
        '.ps-form input:focus,.ps-form select:focus{outline:none;border-color:#0969da;box-shadow:0 0 0 3px rgba(9,105,218,.15)}.ps-form input::placeholder{color:#8b949e}' +
        '.ps-form-foot{display:flex;justify-content:flex-end;gap:8px;padding:12px 20px;border-top:1px solid #eaeef2;background:#f6f8fa;border-radius:0 0 10px 10px}' +
        '.ps-form button{font:inherit;font-weight:500;padding:6px 14px;border:1px solid #d0d7de;border-radius:6px;background:#fff;color:#24292f;cursor:pointer;line-height:1.3}.ps-form button:hover{background:#f3f4f6}' +
        '.ps-form button.go{background:#0969da;color:#fff;border-color:#0969da}.ps-form button.go:hover{background:#0860ca}.ps-form button.danger{background:#cf222e;color:#fff;border-color:#cf222e}.ps-form button.danger:hover{background:#a40e26}.ps-form button:disabled{opacity:.5;cursor:default}' +
        /* a destructive action that is not the card\'s point (clear weir): quiet, left, red on hover */
        '.ps-form button.ghost-danger{color:#cf222e;background:#fff;margin-right:auto}.ps-form button.ghost-danger:hover{background:#ffebe9;border-color:#cf222e}' +
        '.ps-weir-cat{display:grid;grid-template-columns:56px 1fr;gap:10px;align-items:start}.ps-weir-k{font-weight:600;font-size:12px;color:#57606a;padding-top:6px;text-transform:uppercase;letter-spacing:.04em}.ps-weir-roads{display:flex;flex-wrap:wrap;gap:6px;align-items:center}' +
        '.ps-weir-road{display:inline-flex;align-items:center;gap:6px;padding:3px 4px 3px 9px;border:1px solid #d0d7de;border-radius:12px;background:#f6f8fa;font:12px ui-monospace,SFMono-Regular,Menlo,monospace}.ps-weir-road button{all:unset;cursor:pointer;color:#8b949e;padding:0 4px;border-radius:8px;line-height:1}.ps-weir-road button:hover{color:#cf222e;background:#fff}' +
        '.ps-weir-roads input{width:180px;padding:4px 8px;font-size:12px}' +
        /* upload: a drop zone, the chosen files, a progress bar */
        '.ps-drop{border:2px dashed #d0d7de;border-radius:8px;padding:26px 16px;text-align:center;color:#57606a;background:#f6f8fa;transition:border-color .12s,background .12s}.ps-drop.over{border-color:#0969da;background:#ddf4ff;color:#0969da}' +
        '.ps-drop-acts{display:flex;justify-content:center;gap:8px;margin-top:10px}' +
        '.ps-files{max-height:min(220px,40vh);overflow:auto;border:1px solid #eaeef2;border-radius:6px}.ps-file{display:grid;grid-template-columns:minmax(0,1fr) auto auto;gap:10px;align-items:center;padding:5px 10px;border-bottom:1px solid #eaeef2;font:12px ui-monospace,SFMono-Regular,Menlo,monospace}.ps-file:last-child{border-bottom:0}.ps-file > span:first-child{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +
        '.ps-file .size{color:#8b949e}.ps-file button{all:unset;cursor:pointer;color:#8b949e;padding:0 4px}.ps-file button:hover{color:#cf222e}' +
        '.ps-prog{height:6px;border-radius:3px;background:#eaeef2;overflow:hidden}.ps-prog > div{height:100%;width:0;background:#0969da;transition:width .15s}' +
        '.ps-menu .mi{display:block;width:100%;text-align:left;font:13px -apple-system,BlinkMacSystemFont,sans-serif;padding:5px 12px;border:0;background:none;cursor:pointer;white-space:nowrap}.ps-menu .mi:hover{background:#eaeef2}.ps-menu .mi.danger{color:#cf222e}';
      document.head.appendChild(s);
    }
    if (!psCtx) {
      psCtx = document.createElement('drop-menu');
      psCtx.className = 'ps-menu';
      psCtx.style.cssText = 'position:fixed;display:none;z-index:60';
      const t = document.createElement('button'); t.setAttribute('slot', 'trigger'); t.style.display = 'none';
      psCtx.appendChild(t);
      psCtx.addEventListener('dm-close', () => { psCtx.style.display = 'none'; });
      root.appendChild(psCtx);
    }
    return psCtx;
  }
  function showMenu(items, x, y) {
    const m = psChrome();
    m.querySelectorAll('.mi').forEach((b) => b.remove());
    for (const it of items) {
      const b = document.createElement('button');
      b.className = 'mi' + (it.danger ? ' danger' : ''); b.textContent = it.label;
      b.addEventListener('click', () => { m.close(); try { it.run(); } catch (e) { toast(String(e), true); } });
      m.appendChild(b);
    }
    m.style.display = ''; m.style.left = x + 'px'; m.style.top = y + 'px'; m.removeAttribute('flip');
    m.open();
  }
  async function psPost(dir, params) {
    try {
      const r = await fetch(dir, { method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' }, redirect: 'manual', body: new URLSearchParams(params) });
      if (r.status >= 400) { toast(await r.text() || 'failed (' + r.status + ')', true); return false; }
      toast('done ✓'); return true;
    } catch (e) { toast('failed: ' + e, true); return false; }
  }
  // every interface an action needs is a RENDERING of a path: <dir>?view=new,
  // <item>?view=rename, <item>?view=delete, <dir>?view=weir. The menu routes
  // there like any link, so it opens in the pane's target (or in place), sits
  // in history, and back returns. Nothing pops over the pane you are in.
  const ACTION_VIEWS = { new: 1, rename: 1, delete: 1, weir: 1, upload: 1, 'term-new': 1 };
  function go(el, href, kind) { const r = el._ctx && el._ctx.route; if (r) r(href, kind, null); }
  // the menu for a listing-like rendering (table, grid, tree): the row's item
  // under the cursor, or the rendering's own dir on whitespace
  function listingMenu(e, el, dirUrl) {
    const hit = e.composedPath().find((x) => x && x.__item);
    const item = hit ? hit.__item : null;
    if (item) return itemMenu(el, item);
    return dirMenu(el, dirUrl);
  }
  function dirMenu(el, dirUrl) {
    if (dirUrl === PREFIX + SESSIONS.replace(/\/$/, '')) return [       // the dill sessions: terminals
      { label: 'Terminal', run: () => go(el, dirUrl + '?view=term', 'dir') },
      { label: 'New terminal…', run: () => go(el, dirUrl + '?view=term-new', 'dir') },
    ];
    return [
      { label: 'New…', run: () => go(el, dirUrl + '?view=new', 'dir') },
      { label: 'Weir…', run: () => go(el, dirUrl + '?view=weir', 'dir') },
      { label: 'Upload…', run: () => go(el, dirUrl + '?view=upload', 'dir') },
      { label: 'Download', run: () => { location.href = dirUrl + '?download=tar'; } },
    ];
  }
  // the browser's file picker, no dialog of ours: files or a whole directory
  function pickFiles(dir, cb) {
    const inp = document.createElement('input'); inp.type = 'file'; inp.multiple = true; if (dir) inp.webkitdirectory = true;
    inp.style.display = 'none'; document.body.appendChild(inp);
    inp.addEventListener('change', () => { const fs = [...inp.files]; inp.remove(); if (fs.length) cb(fs); });
    inp.click();
  }
  function itemMenu(el, item) {
    const dir = item.__dir, isDir = item.kind === 'dir' || item.isDir, base = dir.replace(/\/$/, '') + '/' + item.name;
    const items = [];
    if (isDir) items.push(...dirMenu(el, base));
    else items.push({ label: 'Download', run: () => { const l = document.createElement('a'); l.href = base + '?raw=1'; l.download = item.name; l.click(); } });
    // move/copy go to the pane's TARGET: the dir the target pane shows is the
    // destination. That is what a target is for. No target → ask for a path.
    const ctx = el._ctx || {};
    const tgtDir = () => { const t = ctx.ps && ctx.ps.routeTargetId && ctx.ps.routeTargetId(ctx.paneId); const p = t && ctx.ps.pathOf(t); return p ? psNs(p).replace(/\/$/, '') : null; };
    const send = (verb) => () => {
      const act = isDir ? verb + '-folder' : verb + '-grub', key = isDir ? 'foldername' : 'filename';
      const d = tgtDir();
      if (d != null) { psPost(dir, { action: act, [key]: item.name, dest: (d || '') + '/' + item.name }); return; }
      toast('no target: set this pane\'s target (⇒ in its bar) to the pane showing the destination', true);
    };
    const k = isDir ? 'dir' : 'file';
    items.push(
      { label: 'Move to target', run: send('move') },
      { label: 'Copy to target', run: send('copy') },
      { label: 'Rename…', run: () => go(el, base + '?view=rename&kind=' + k, k) },
      { label: 'Delete…', danger: true, run: () => go(el, base + '?view=delete&kind=' + k, k) },
    );
    return items;
  }
  // the action views. Each is a small form over the path it was opened on;
  // submit posts to the server and steps the pane back (the form was a moment,
  // so back is cancel too). The stream refreshes whatever showed the item.
  // abs: the place the moment stands for (differs from its path under an @name)
  function actionView(ps, paneId, el, path, abs) {
    const args = psArgs(path), ns = psNs(path), view = args.view;
    abs = abs || ns;
    const url = psUrl(abs), name = psBase(abs), parentUrl = psUrl(abs.replace(/\/[^/]*$/, '') || '/');
    const isDir = args.kind === 'dir';
    psChrome();
    const wrap = document.createElement('div'); wrap.className = 'ps-form-wrap';
    const form = document.createElement('div'); form.className = 'ps-form'; wrap.appendChild(form); el.appendChild(wrap);
    const head = document.createElement('div'); head.className = 'ps-form-head';
    const body = document.createElement('div'); body.className = 'ps-form-body';
    form.append(head, body);
    const h = (verb, p) => { head.textContent = ''; const v = document.createElement('div'); v.className = 'ps-form-verb'; v.textContent = verb; const d = document.createElement('div'); d.className = 'ps-form-path'; d.textContent = p; d.title = p; head.append(v, d); };
    const note = (t) => { const d = document.createElement('div'); d.className = 'ps-form-note'; d.textContent = t; body.appendChild(d); };
    const field = (label, value, ph) => { const l = document.createElement('label'); const s = document.createElement('span'); s.textContent = label; const i = document.createElement('input'); i.value = value || ''; i.placeholder = ph || ''; i.spellcheck = false; l.append(s, i); body.appendChild(l); return i; };
    const buttons = (ok, danger, run) => { const foot = document.createElement('div'); foot.className = 'ps-form-foot'; const c = document.createElement('button'); c.textContent = 'cancel'; c.addEventListener('click', () => ps.back(paneId)); const b = document.createElement('button'); b.className = danger ? 'danger' : 'go'; b.textContent = ok; b.addEventListener('click', async () => { b.disabled = true; const okd = await run(); b.disabled = false; if (okd) ps.back(paneId); }); foot.append(c, b); form.appendChild(foot); return b; };
    const onEnter = (inp, btn) => inp.addEventListener('keydown', (e) => { if (e.key === 'Enter') btn.click(); else if (e.key === 'Escape') ps.back(paneId); });
    if (view === 'new') {
      h('New', ns);
      const kind = document.createElement('select'); ['file', 'folder', 'nexus', 'symlink'].forEach((k) => { const o = document.createElement('option'); o.value = k; o.textContent = k; kind.appendChild(o); });
      const kl = document.createElement('label'); const ks = document.createElement('span'); ks.textContent = 'kind'; kl.append(ks, kind); body.appendChild(kl);
      const nm = field('name', '', 'name');
      // the second field is the kind's: a file's blot (optional), a nexus's
      // neck, a symlink's target; a folder has none
      const extra = field('', '', '');
      const EXTRA = {
        file: { label: 'blot (optional)', ph: '/json, /txt, /hoon … or leave empty for mime' },
        folder: null,
        nexus: { label: 'neck', ph: '/git/repo' },
        symlink: { label: 'target', ph: '/path/to/target' },
      };
      const applyKind = () => { const x = EXTRA[kind.value]; const l = extra.parentElement; l.style.display = x ? '' : 'none'; if (x) { l.querySelector('span').textContent = x.label; extra.placeholder = x.ph; } };
      kind.addEventListener('change', applyKind); applyKind();
      const b = buttons('create', false, () => {
        const n = nm.value.trim(); if (!n) return false; const x = extra.value.trim();
        const k = kind.value;
        if ((k === 'nexus' || k === 'symlink') && !x) { extra.focus(); return false; }
        const params = k === 'folder' ? { action: 'create-folder', foldername: n }
          : k === 'nexus' ? { action: 'create-nexus', foldername: n, neck: x }
          : k === 'symlink' ? { action: 'create-symlink', linkname: n, target: x }
          : { action: 'create-file', filename: n, ...(x ? { blot: x } : {}) };
        return psPost(url, params);
      });
      onEnter(nm, b); onEnter(extra, b); nm.focus();
    } else if (view === 'term-new') {
      // a new dill session on hood's dojo; the pane becomes its terminal
      h('New terminal', ns);
      note('A new dojo session. The name is one word: letters, digits, dashes.');
      const nm = field('session', '', 'name');
      const b = buttons('open', false, async () => {
        const n = nm.value.trim();
        if (!/^[a-z][a-z0-9-]*$/.test(n)) { toast('a session name is lowercase letters, digits and dashes', true); nm.focus(); return false; }
        try {
          const r = await fetch(TERM, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ session: n, open: true }) });
          if (!r.ok) { let why = 'open failed (' + r.status + ')'; try { why = (await r.json()).error || why; } catch (_) {} throw new Error(why); }
        } catch (e) { toast('terminal: ' + (e && e.message || e), true); return false; }
        psKind.set(SESSIONS + n, 'file');
        ps.openFrom(paneId, SESSIONS + n);
        return false;                                                  // the pane moved on to the session; nothing to go back to
      });
      onEnter(nm, b); nm.focus();
    } else if (view === 'rename') {
      h('Rename', ns + (isDir ? '/' : ''));
      const nm = field('new name', name);
      const b = buttons('rename', false, () => { const n = nm.value.trim(); if (!n || n === name) return false; return psPost(parentUrl, isDir ? { action: 'rename-folder', foldername: name, newname: n } : { action: 'rename-grub', filename: name, newname: n }); });
      onEnter(nm, b); nm.focus(); const dot = name.lastIndexOf('.'); nm.setSelectionRange(0, dot > 0 ? dot : name.length);
    } else if (view === 'delete') {
      h('Delete', ns + (isDir ? '/' : ''));
      note(isDir ? 'The directory and everything in it will be removed. This cannot be undone.' : 'The file will be removed. This cannot be undone.');
      const b = buttons('delete', true, () => psPost(parentUrl, isDir ? { action: 'delete-folder', foldername: name } : { action: 'delete-grub', filename: name }));
      b.focus();
    } else if (view === 'weir') {
      h('Weir', ns);
      weirView(ps, paneId, el, form, body, ns, url);
    } else if (view === 'upload') {
      h('Upload', ns);
      uploadView(ps, paneId, form, body, url);
    }
  }
  // upload as a rendering of its dir: drop files or a folder onto the card, or
  // pick them; see the list (relative paths kept for a folder); one request
  // with a progress bar; done steps back. The stream shows the new files.
  function uploadView(ps, paneId, form, body, url) {
    let files = [];
    const drop = document.createElement('div'); drop.className = 'ps-drop'; const dropText = document.createElement('span'); dropText.textContent = 'drop files or a folder here'; drop.appendChild(dropText);
    const acts = document.createElement('div'); acts.className = 'ps-drop-acts';
    const pickBtn = (t, dir) => { const b = document.createElement('button'); b.textContent = t; b.addEventListener('click', () => pickFiles(dir, (fs) => add(fs))); return b; };
    acts.append(pickBtn('choose files', false), pickBtn('choose folder', true)); drop.appendChild(acts);
    const list = document.createElement('div'); list.className = 'ps-files'; list.style.display = 'none';
    const prog = document.createElement('div'); prog.className = 'ps-prog'; prog.style.display = 'none'; const bar = document.createElement('div'); prog.appendChild(bar);
    const note = document.createElement('div'); note.className = 'ps-form-note'; note.style.display = 'none';
    body.append(drop, list, prog, note);
    const fmt = (n) => n < 1024 ? n + ' B' : n < 1048576 ? (n / 1024).toFixed(1) + ' KB' : (n / 1048576).toFixed(1) + ' MB';
    const nameOf = (f) => f.__path || f.webkitRelativePath || f.name;
    const draw = () => {
      list.textContent = ''; list.style.display = files.length ? '' : 'none';
      files.forEach((f, i) => { const row = document.createElement('div'); row.className = 'ps-file'; const n = document.createElement('span'); n.textContent = nameOf(f); const s = document.createElement('span'); s.className = 'size'; s.textContent = fmt(f.size); const x = document.createElement('button'); x.textContent = '×'; x.title = 'remove'; x.addEventListener('click', () => { files.splice(i, 1); draw(); }); row.append(n, s, x); list.appendChild(row); });
      go.disabled = !files.length; go.textContent = files.length ? 'upload ' + files.length + (files.length === 1 ? ' file' : ' files') : 'upload';
    };
    const add = (fs) => { files = files.concat(fs); draw(); };
    // drag and drop: files, or a dropped directory walked through the entry api
    ['dragenter', 'dragover'].forEach((t) => drop.addEventListener(t, (e) => { e.preventDefault(); drop.classList.add('over'); }));
    ['dragleave', 'drop'].forEach((t) => drop.addEventListener(t, (e) => { e.preventDefault(); drop.classList.remove('over'); }));
    drop.addEventListener('drop', async (e) => {
      const out = [];
      const walk = (entry, prefix) => new Promise((res) => {
        if (entry.isFile) entry.file((f) => { f.__path = prefix + f.name; out.push(f); res(); }, res);
        else if (entry.isDirectory) { const rd = entry.createReader(); const all = []; const next = () => rd.readEntries(async (es) => { if (!es.length) { for (const s of all) await walk(s, prefix + entry.name + '/'); res(); } else { all.push(...es); next(); } }, res); next(); }
        else res();
      });
      const items = [...(e.dataTransfer.items || [])];
      const entries = items.map((it) => it.webkitGetAsEntry && it.webkitGetAsEntry()).filter(Boolean);
      if (entries.length) { for (const en of entries) await walk(en, ''); }
      else out.push(...e.dataTransfer.files);
      add(out);
    });
    const foot = document.createElement('div'); foot.className = 'ps-form-foot';
    const cancel = document.createElement('button'); cancel.textContent = 'cancel'; cancel.addEventListener('click', () => ps.back(paneId));
    const go = document.createElement('button'); go.className = 'go'; go.disabled = true; go.textContent = 'upload';
    go.addEventListener('click', () => {
      const fd = new FormData(); for (const f of files) fd.append('file', f, nameOf(f));
      const xhr = new XMLHttpRequest(); xhr.open('POST', url);
      prog.style.display = ''; note.style.display = ''; note.textContent = 'uploading…'; go.disabled = true; cancel.disabled = true;
      xhr.upload.addEventListener('progress', (ev) => { if (ev.lengthComputable) bar.style.width = Math.round(ev.loaded / ev.total * 100) + '%'; });
      xhr.addEventListener('load', () => { cancel.disabled = false; if (xhr.status >= 400) { note.textContent = 'upload failed: ' + (xhr.responseText || xhr.status); go.disabled = false; return; } bar.style.width = '100%'; toast('uploaded ' + files.length + ' ✓'); ps.back(paneId); });
      xhr.addEventListener('error', () => { note.textContent = 'upload failed'; go.disabled = false; cancel.disabled = false; });
      xhr.send(fd);
    });
    foot.append(cancel, go); form.appendChild(foot);
    draw();
  }
  // the weir editor as a rendering of its dir: roads by category, add/remove,
  // restrict/clear. Follows the dir (fold) so an edit redraws from the ship.
  function weirView(ps, paneId, el, form, body, ns, url) {
    let weir = null;
    let foot = null;
    const draw = () => {
      body.textContent = ''; if (foot) { foot.remove(); foot = null; }
      foot = document.createElement('div'); foot.className = 'ps-form-foot';
      const btn = (t, cls, run) => { const b = document.createElement('button'); if (cls) b.className = cls; b.textContent = t; b.addEventListener('click', run); return b; };
      if (!weir) {
        const p = document.createElement('div'); p.className = 'ps-form-note'; p.textContent = 'Unrestricted: this directory has no weir. Restricting it starts fully closed; open it road by road.'; body.appendChild(p);
        foot.append(btn('done', null, () => ps.back(paneId)), btn('restrict this directory', 'danger', () => psPost(url, { action: 'make-weir' })));
        form.appendChild(foot);
        return;
      }
      for (const cat of ['write', 'poke', 'read']) {
        const row = document.createElement('div'); row.className = 'ps-weir-cat';
        const k = document.createElement('span'); k.className = 'ps-weir-k'; k.textContent = cat; row.appendChild(k);
        const rs = document.createElement('div'); rs.className = 'ps-weir-roads';
        for (const rd of (weir[cat] || [])) { const s = document.createElement('span'); s.className = 'ps-weir-road'; s.title = rd; const t = document.createElement('span'); t.textContent = rd; s.appendChild(t); const x = document.createElement('button'); x.textContent = '×'; x.title = 'remove road'; x.addEventListener('click', () => psPost(url, { action: 'del-weir-road', category: cat, 'road-path': rd })); s.appendChild(x); rs.appendChild(s); }
        const inp = document.createElement('input'); inp.placeholder = 'add /path or /path/'; inp.spellcheck = false;
        inp.addEventListener('keydown', (e) => { if (e.key === 'Enter' && inp.value.trim()) { psPost(url, { action: 'add-weir-road', category: cat, 'road-path': inp.value.trim() }); inp.value = ''; } });
        rs.appendChild(inp); row.appendChild(rs); body.appendChild(row);
      }
      foot.append(btn('clear weir', 'ghost-danger', () => psPost(url, { action: 'clear-weir' })), btn('done', 'go', () => ps.back(paneId)));
      form.appendChild(foot);
    };
    const load = () => fetch(url + '?list=1', { cache: 'no-store' }).then((r) => r.ok ? r.json() : null).then((d) => { if (!el.isConnected) return; weir = (d && d.weir) || null; draw(); }).catch(() => {});
    load();
    el._fv = { destroy() {}, onUpdate() { load(); } };
    paneLive(ps, paneId, el, [{ road: ns === '/' ? '/' : ns.replace(/\/$/, '') + '/', fold: true }]);
  }
  // re-read a layout file and reapply it to the pane showing it (a refresh
  // on a layout pane, or a followed source that changed)
  // a layout's source is the MOMENT it was opened as (path + ?args), so a
  // restored pane keeps ?follow=1
  function psReloadLayout(ps, paneId, src) {
    psResolve(psNs(src)).then((abs) => fetch(psUrl(abs), { cache: 'no-store' })).then((r) => r.ok ? r.json() : Promise.reject(r.status))
      .then((spec) => { if (ps.srcOf(paneId) === src) ps.reapplyLayout(paneId, spec, src); })
      .catch((e) => ps.hint('could not re-read the layout: ' + e));
  }
  // follow a layout pane's source for as long as the pane shows it. By
  // default a shown layout is the user's (their resizes, folds and tabs): a
  // change to the file only says so in the hint, and ↻ or ⌃B R re-applies
  // it. `?follow=1` on the moment re-applies on every change, live leaves
  // kept where their address and moment match. Called when a pane lands on
  // a layout, and again for every layout pane a restored workspace holds.
  function psFollowLayout(ps, paneId, src) {
    const ns = psNs(src), follow = psArgs(src).follow === '1';
    psResolve(ns).then((abs) => {
      const un = live([{ road: abs }], (ev) => {
        if (ps.srcOf(paneId) !== src) { un(); return; }                 // the pane moved on: this follow is done
        if (ev.kind === 'del') { un(); ps.hint('layout source deleted: ' + ns); return; }
        if (follow) psReloadLayout(ps, paneId, src);
        else ps.hint('layout source changed · ↻ or ⌃B R to re-apply · ' + ns);
      }, null);
    }).catch(() => {});
  }
  function paneContent(ps, paneId, path) {
    const el = document.createElement('div');
    el.style.cssText = 'height:100%;overflow:auto';
    el._moment = path;                                                        // what this content shows (updateContent compares against it)
    const ns = psNs(path);
    if (!psLink(ns)) { paneContentAt(ps, paneId, el, path, ns, ns); return el; }
    // an @name moment: resolve the name first, then render at the place it
    // stands for. The name is followed for the life of this content
    psWait(el, 'resolving', ns);
    el._link = psWatchLink(ps, paneId, el, ns);
    psResolve(ns).then((abs) => { if (!el._dead) { psClear(el); ps.redrawBars(); paneContentAt(ps, paneId, el, path, ns, abs); } })
      .catch((e) => psWaitFail(el, 'link: ' + (e && e.message ? e.message : e), ns));
    return el;
  }
  // render a moment whose place is known: ns is the moment's own path (what
  // links under it are spelled with, what the tab chips show), abs the place
  // fetched and followed; they differ only under an @name
  function paneContentAt(ps, paneId, el, path, ns, abs) {
    const url = psUrl(abs);
    // route a link: the view says WHAT (a moment, maybe with an offered name);
    // the layout this pane sits in says WHERE (its routing table; in place by
    // default). ⌘-click is the user's own override: a new pane beside.
    const route = (href, kind, mods, name) => {
      const h = psMoment(psRel(ns, href));                                  // relative to this moment, as spelled
      if (kind) psKind.set(psNs(h), kind === 'dir' ? 'dir' : 'file');      // glyph the target before nav
      if (mods && (mods.meta || mods.ctrl)) { ps.open(h, 'beside'); return; }   // ⌘-click → new pane
      ps.openFrom(paneId, h, name);
    };
    const unroute = (href) => ps.closeFrom(paneId, psMoment(psRel(ns, href)));   // the view says a moment is gone
    el._ctx = { ps, paneId, route };                                        // menus route through the pane's target via this
    const raw = !!(ps.viewOf && ps.viewOf(paneId) === 'raw');              // toolbar toggle: skip all special rendering
    if (ACTION_VIEWS[psArgs(path).view]) { actionView(ps, paneId, el, path, abs); return; }   // a form over this path
    if (!raw && /\.layout$/.test(abs)) {                                   // this pane landed ON a layout → become it
      psWait(el, 'opening layout', ns);
      fetch(url).then((r) => r.ok ? r.json() : Promise.reject('x')).then((spec) => {
        ps.replaceWithLayout(paneId, spec, path);                        // the source is the moment, ?args and all
        psFollowLayout(ps, paneId, path);
      }).catch((e) => psWaitFail(el, 'not a valid layout: ' + ((e && e.message) || e), ns));   // the file, or applying it
      return;
    }
    // viewers get open(url, {name}) and close(url) over moments; onNavigate(url,
    // kind, {name}) is the same open with a kind hint, kept for every viewer
    // written against it
    // {beside: true} is the keyboard's ⌘-click: open in a new pane beside
    const mods = (o) => (o && o.beside) ? { meta: true } : null;
    const onNav = (u, k, o) => route(u, k === 'file' ? 'file' : 'dir', mods(o), o && o.name);
    const vopen = (u, o) => route(u, null, mods(o), o && o.name);
    psWait(el, 'loading', ns);                                                // until the first answer lands (fades in after a beat)
    const vclose = (u) => unroute(u);
    fetch(url + '?list=1').then((r) => r.ok ? r.json() : Promise.reject(r.status)).then(async (d) => {
      if (!d || !Array.isArray(d.children)) throw 'f';
      psClear(el);
      psKind.set(ns, 'dir'); ps.redrawBars();                              // this path lists → it's a dir
      el._dirUrl = url;                                                    // whitespace right-click: this dir's actions
      // ?view= says how this dir is looked at: tree (the stock tree viewer),
      // grid, or rows. Absent, a viewer the app declares for the dir wins,
      // else rows. raw ignores all of it: the plain listing.
      const want = raw ? null : (psArgs(path).view || null);
      if (want === 'term' && abs === SESSIONS) { psTerminal(ps, paneId, el, ns, abs, '', psArgs(path)); return; }   // the default session's terminal
      const hostView = want === 'tree' || want === 'grid' || want === 'rows';
      if (want === 'tree') {
        const tv = await stockViewer('tree', TREE_JS);
        // mounted whether or not el is in the document: an inactive tab's
        // content is stashed off-document and shown later, and falling
        // through here would render it as rows instead
        if (tv) { el._fv = tv.mount(el, { url, args: { root: abs }, onNavigate: onNav, open: vopen, close: vclose }); el._menu = (e) => listingMenu(e, el, url); psLanded(ps, paneId, el); return; }
      }
      // the app is asked for the bare dir and for any view name of its own;
      // the host's own views (rows, grid, tree) never reach it
      let viewer = null;
      if (!raw && !hostView) { try { viewer = await viewerFor(url, 'dir', '', want); } catch (_) {} }
      if (viewer && viewer.layout) {                                       // the app opens this dir as a layout rooted here
        psWait(el, 'opening layout', ns);
        // a layout's relative entries ('./x', './', './?args', '../y') resolve
        // against the opened dir as spelled (psRel); absolute and @name
        // entries stay as written
        const rebase = (o) => Array.isArray(o) ? o.map(rebase)
          : (o && typeof o === 'object') ? Object.fromEntries(Object.keys(o).map((k) => [k, (k === 'path' && typeof o[k] === 'string') ? psRel(ns, o[k]) : rebase(o[k])]))
          : o;
        fetch(viewer.layout, { cache: 'no-store' }).then((r) => r.ok ? r.json() : Promise.reject('x'))
          .then((spec) => { if (el.isConnected) ps.replaceWithLayout(paneId, rebase(spec), ns); })
          .catch((e) => psWaitFail(el, 'not a valid layout: ' + ((e && e.message) || e), viewer.layout));
        return;
      }
      if (viewer && !viewer.blocked && viewer.mount) { el._fv = viewer.mount(el, { url, onNavigate: onNav, open: vopen, close: vclose, query: psArgs(path) }); paneLive(ps, paneId, el, viewer.follow); psLanded(ps, paneId, el); return; }
      const t = document.createElement(want === 'grid' ? 'file-grid' : 'file-table');
      t.style.height = '100%';
      // ?scope: this listing is the top of what the pane may show. A layout
      // names a dir as `./files?scope=1` and the listing has no `../`;
      // links to child dirs carry `?scope=<that top>` so a descent stays
      // fenced: `../` climbs back up to the top and no further. The scope
      // is a moment arg, so it is how the dir is looked at, not where it is
      const scopeArg = psArgs(path).scope;
      const scope = scopeArg === '1' ? ns.replace(/\/$/, '') : (scopeArg || null);
      const atTop = scope != null && ns.replace(/\/$/, '') === scope;
      const scoped = (p) => scope != null ? p + '?scope=' + encodeURIComponent(scope) : p;
      const up = psUp(ns, abs);
      if (want === 'grid') t.baseHref = ns.replace(/\/$/, '');
      else {
        if (ns !== '/' && !atTop) t.parentHref = scoped(up || '/');     // ../ row → up in place; top-level dirs go to root; none at a scope's top
          t.columns = ft.columns.map((c) => c.key === 'name' ? Object.assign({}, c, { link: (item) => { const h = ns.replace(/\/$/, '') + '/' + item.name; return item.kind === 'dir' ? scoped(h) : h; } })
          // the weir tag opens that dir's weir view where links open
          : c.key === 'weir' ? Object.assign({}, c, { decorate: (cell, item) => { if (item.kind !== 'dir') return; cell.style.cursor = 'pointer'; cell.style.color = item.weir ? '#9a6700' : '#1a7f37'; cell.title = "this directory's weir"; cell.addEventListener('click', (e) => { e.stopPropagation(); route(ns.replace(/\/$/, '') + '/' + item.name + '?view=weir', 'dir', null); }); } })
          : c);
      }
      t.addEventListener('ft-navigate', (e) => { const { item, href, mods } = e.detail; route(href, item ? item.kind : 'dir', mods); });
      el._menu = (e) => listingMenu(e, el, url);                            // right-click: the row's item, or this dir
      el.appendChild(t);
      d.children.forEach((c) => { c.__dir = url; });
      t.items = d.children;
      psLanded(ps, paneId, el);                                            // the keyboard lands on the table if this pane is the one chosen
      // the listing follows its dir in FOLD mode: one event whenever anything
      // under it moves. The answer is a row refresh on the SAME table, never a
      // pane re-render: a dir with busy nexuses beneath it (/apps) moves
      // constantly, and a listing that rebuilt itself on each move could not
      // be clicked. Refreshes coalesce to at most one every 500ms.
      let timer = null;
      const refreshRows = () => fetch(url + '?list=1', { cache: 'no-store' }).then((r) => { if (r.status === 404) { psMarkDead(ps, el, ns, 'deleted'); return null; } return r.ok ? r.json() : null; }).then((nd) => {
        if (!nd || !Array.isArray(nd.children) || !el.isConnected) return;
        nd.children.forEach((c) => { c.__dir = url; });
        t.items = nd.children;
      }).catch(() => {});
      el._fv = { destroy() { clearTimeout(timer); }, onUpdate() { if (timer) return; timer = setTimeout(() => { timer = null; refreshRows(); }, 500); } };
      paneLive(ps, paneId, el, [{ road: abs === '/' ? '/' : abs.replace(/\/$/, '') + '/', fold: true }]);
    }).catch(async (why) => {
      if (why === 404) { psMarkDead(ps, el, ns); return; }                 // no such path: dead where it sits (a deleted thing in history)
      psClear(el);
      psKind.set(ns, 'file'); ps.redrawBars();                            // not a listing → it's a file
      el._gone = psWatchFile(ps, paneId, el, ns, abs);                      // its own file, one keep: del → dead, new → back
      // rendered = JUST the declared viewer's rendering (no FileView chrome);
      // raw = the full Source|Preview|Build package. The viewer never rides
      // along inside raw — the two are separate panes you toggle between.
      // a dill session: a terminal. The default session's grub has the empty
      // name, so /sys/dill/sessions/ itself IS that file (the kernel serves
      // it there), and the pane on it is the ship's own terminal
      if (!raw && abs.startsWith(SESSIONS) && !abs.slice(SESSIONS.length).includes('/')) { psTerminal(ps, paneId, el, ns, abs, abs.slice(SESSIONS.length), psArgs(path)); return; }
      if (!raw) {
        let v = null; try { v = await viewerFor(url, 'file', '', psArgs(path).view || null); } catch (_) {}
        if (v && !v.blocked && v.mount) {
          // the moment's ?args ride along as `query`: a viewer may read how it
          // is being looked at (a docs pane's ?page=, say) without parsing urls
          try { el._fv = v.mount(el, { url, onNavigate: onNav, open: vopen, close: vclose, query: psArgs(path) }); paneLive(ps, paneId, el, v.follow); psLanded(ps, paneId, el); } catch (e) { el.textContent = 'viewer failed: ' + e; }
          return;                                                         // rendered: the rendering alone
        }
      }
      const opts = { url, crumbBase: ROOT, onNavigate: onNav, open: vopen, close: vclose };          // raw, or no renderer → the raw package
      // right-click anywhere in the file: the file's own actions
      el._menu = () => itemMenu(el, { kind: 'file', name: psBase(abs), __dir: psUrl(abs.replace(/\/[^/]*$/, '') || '/') });
      try { el._fv = window.FileView.mount(el, opts); paneLive(ps, paneId, el, [{ road: abs }]); psLanded(ps, paneId, el); }   // the raw package follows its file
      catch (e) { el.textContent = 'open failed: ' + e; }
    });
  }
  function saveTabs() {
    const panels = tabPanels().filter((p) => !p._panes);   // the panes scratchpad is ephemeral
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
  // an embedder can fix the view (opts.view): that view, and no toggle
  let view = opts.view || localStorage.getItem(K + '-view') || 'list';
  if (opts.view) $('view-toggle').style.display = 'none';

  function setView(v) {
    view = v;
    try { localStorage.setItem(K + '-view', v); } catch (_) {}
    ft.style.display = v === 'list' ? '' : 'none';
    fg.style.display = v === 'grid' ? '' : 'none';
    finder.style.display = v === 'cols' ? 'grid' : 'none';
    root.classList.toggle('cols', v === 'cols'); // a fixed column in the finder view
    if (PAGE) document.body.classList.toggle('cols', v === 'cols'); // and the page with it
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
  setTitle();
  // a mounting app's explorer wears that app's icon, not the explorer app's
  if (PAGE && MOUNT && typeof MOUNT.icon === 'string' && OWN_ROUTE.test(MOUNT.icon)) {
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

  root.addEventListener('contextmenu', (e) => {
    // only a listing gets the explorer's menu; anywhere else (a rendered
    // viewer, a pane bar, whitespace) keeps the browser's own right-click
    if (!e.target.closest('file-table, file-grid') || e.target.closest('drop-menu, modal-dialog, #bar')) return;
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

  // ---- snaps: pictures of the page for tools on the ship ----
  // A tool writes snaps/<id>.json {moment} under the explorer; this page,
  // the only thing that can see itself, renders the pane showing that
  // moment (or the whole workspace when none does) to a PNG and uploads
  // <id>.png beside the request. The tool awaits the png and culls both.
  const SNAPS = '/apps/explorer.explorer/snaps/';
  let h2c = null;
  function html2canvasLoad() {
    if (h2c) return h2c;
    return h2c = new Promise((res, rej) => {
      if (window.html2canvas) return res(window.html2canvas);
      const s = document.createElement('script');
      s.src = PREFIX + '/apps/explorer.explorer/html2canvas.min.js';
      s.onload = () => res(window.html2canvas);
      s.onerror = () => { h2c = null; rej(new Error('html2canvas did not load')); };
      document.head.appendChild(s);
    });
  }
  // the pane whose content shows `moment`: the exact moment first, else the
  // same place under other ?args
  function psPaneShowing(ps, moment) {
    if (!moment) return null;
    const want = psNs(moment);
    let near = null;
    for (const body of ps.querySelectorAll('.ps-pane-body')) {
      const el = body.firstChild; if (!el || !el._moment) continue;
      const pane = body.closest('.ps-pane');
      if (el._moment === moment) return pane;
      if (!near && psNs(el._moment) === want) near = pane;
    }
    return near;
  }
  function psSnaps(ps) {
    live([{ road: SNAPS, body: true }], async (ev) => {
      if (ev.kind !== 'new' || !ev.path.endsWith('.json')) return;
      const id = ev.path.slice(SNAPS.length, -5);
      const moment = ev.body && typeof ev.body === 'object' ? String(ev.body.moment || '') : '';
      try {
        const render = await html2canvasLoad();
        const target = psPaneShowing(ps, moment) || ps;
        const w = target.getBoundingClientRect().width || 1;
        const canvas = await render(target, { useCORS: true, logging: false, backgroundColor: '#ffffff', scale: Math.min(1, 1600 / w) });
        const blob = await new Promise((res) => canvas.toBlob(res, 'image/png'));
        const fd = new FormData(); fd.append('file', blob, id + '.png');
        const r = await fetch(PREFIX + SNAPS.replace(/\/$/, ''), { method: 'POST', body: fd, redirect: 'manual' });
        if (r.status >= 400) throw new Error('upload ' + r.status);
      } catch (e) { toast('snap failed: ' + (e && e.message || e), true); }
    }, null);
  }

  // ---- terminal panes: a dill session as a document of lines (explorer.hoon +handle-term) ----
  // A session grub /sys/dill/sessions/<name> holds one version per blit batch
  // dill emitted. dill's output is line-oriented: drum edits the ONE line
  // the cursor is on (hop sets the column, put/klr write at it, wyp wipes
  // it) and commits it with nel. So a session renders as what it is: a
  // scrollable document of committed lines, wrapping to the pane, with the
  // live line last and the cursor in it. No grid, no emulator, nothing to
  // size — the browser lays out, wraps, scrolls, selects and copies.
  // The pane replays the last batches for history (with the slogs from the
  // same span of time), then follows the grub and fetches each new batch BY
  // VERSION, so none is missed when several land between stream events.
  // Slogs — dill's %logs told for a named session, and the runtime's
  // /~_~/slog stream for every pane (~&, printfs, crash traces: those go to
  // the tty and that stream, never through dill) — go in above the live
  // line, grey italic. Keys go back as belts through /grubbery/explorer/term.
  const TERM = PREFIX.replace(/\/ball$/, '/explorer') + '/term';
  const SESSIONS = '/sys/dill/sessions/';
  const LOGS = '/sys/dill/logs.dill-told';
  const termUrl = (session, q) => TERM + '?session=' + encodeURIComponent(session) + q;
  // the runtime's slog stream: one connection per page, every terminal pane
  // hears it; the stream has no history, so a pane shows them from when it
  // opened. (vere drops the priority, so there is no red/yellow/green.)
  const slogStream = (() => {
    const subs = new Set(); let started = false;
    async function connect() {
      if (started) return; started = true;
      let backoff = 1000;
      for (;;) {
        try {
          const r = await fetch('/~_~/slog', { headers: { Accept: 'text/event-stream' }, cache: 'no-store' });
          if (!r.ok || !r.body) throw new Error('slog ' + r.status);
          backoff = 1000;
          const rd = r.body.getReader(), dec = new TextDecoder(); let buf = '';
          for (;;) {
            const c = await rd.read(); if (c.done) break;
            buf += dec.decode(c.value, { stream: true });
            const blocks = buf.split('\n\n'); buf = blocks.pop();
            for (const b of blocks) {
              const lines = b.split('\n').filter((l) => l.startsWith('data:')).map((l) => l.slice(5).replace(/^ /, ''));
              if (lines.length) for (const s of subs) { try { s(lines); } catch (_) {} }
            }
          }
        } catch (_) { /* reconnect */ }
        await new Promise((res) => setTimeout(res, backoff)); backoff = Math.min(backoff * 2, 15000);
      }
    }
    return (fn) => { subs.add(fn); connect(); return () => subs.delete(fn); };
  })();
  // a styled run's css, from the dill-blit mark's stye {deco, back, fore}
  const TINT = { k: '#1f2328', r: '#cf222e', g: '#1a7f37', y: '#9a6700', b: '#0969da', m: '#8250df', c: '#1b7c83', w: '#6e7781' };
  const tintCss = (t) => t == null ? null : typeof t === 'string' ? (TINT[t] || null) : 'rgb(' + ((t.r || 0) % 256) + ',' + ((t.g || 0) % 256) + ',' + ((t.b || 0) % 256) + ')';
  function styleOf(s) {
    if (!s) return '';
    const parts = [];
    (s.deco || []).forEach((d) => { if (d === 'br') parts.push('font-weight:600'); else if (d === 'un') parts.push('text-decoration:underline'); else if (d === 'bl') parts.push('opacity:.7'); });
    const f = tintCss(s.fore), b = tintCss(s.back);
    if (f) parts.push('color:' + f);
    if (b) parts.push('background:' + b);
    return parts.join(';');
  }
  const SLOG_CSS = 'color:#6e7781;font-style:italic';
  const toldLines = (told) => {
    if (!told || typeof told !== 'object') return [];
    let lines = told.type === 'text' ? [String(told.text || '')] : (told.lines || []).map(String);
    if (told.type === 'crud') { if (!lines.length) return []; lines = ['ERROR [' + (told.tag || '') + ']:'].concat(lines); }   // the grub's seed is an empty crud
    return lines;
  };
  // the screen: committed lines, the live line last, a cursor column in it.
  // Each line is cells {ch, css}; a slog line is marked. Renders into `doc`
  // incrementally: only lines from the first changed one are redrawn.
  function makeScreen(doc, host) {
    const MAX = 5000;
    const lines = [];                                         // {cells, slog?, dom?}
    let col = 0, dirty = 0, focused = false;
    const live = () => { if (!lines.length) { lines.push({ cells: [] }); touch(lines.length - 1); } return lines[lines.length - 1]; };
    const touch = (i) => { if (i < dirty) dirty = i; };
    const write = (text, css) => {
      const l = live(); touch(lines.length - 1);
      while (l.cells.length < col) l.cells.push({ ch: ' ', css: '' });
      for (const ch of [...text]) { l.cells[col] = { ch, css }; col++; }
    };
    const apply = (b) => {
      if (!b || typeof b !== 'object') return;
      switch (b.type) {
        case 'mor': (b.blits || []).forEach(apply); break;
        case 'hop': { const p = b.pos; col = typeof p === 'number' ? p : ((p && p.x) || 0); live(); touch(lines.length - 1); break; }
        case 'put': write(b.text || '', ''); break;
        case 'klr': (b.stub || []).forEach((s) => write(s.text || '', styleOf(s.stye))); break;
        case 'wyp': live().cells.length = 0; col = 0; touch(lines.length - 1); break;
        case 'nel': live(); lines.push({ cells: [] }); col = 0; touch(lines.length - 2); break;
        case 'clr': live(); break;                            // dill clears on resize/open and redraws the prompt: a document has nothing to clear
        case 'url': if (b.url) try { window.open(b.url); } catch (_) {} break;
        default: break;                                       // bel, sag, sav
      }
    };
    const slog = (text) => { live(); lines.splice(lines.length - 1, 0, { cells: [...text].map((ch) => ({ ch, css: SLOG_CSS })), slog: true }); touch(lines.length - 2); };
    const render = (l, isLive) => {
      const d = l.dom || (l.dom = document.createElement('div'));
      d.className = 'tm-line' + (l.slog ? ' tm-slog' : '') + (isLive ? ' tm-live' : '');
      d.textContent = '';
      const cells = l.cells, n = isLive ? Math.max(cells.length, col + 1) : cells.length;
      let i = 0;
      while (i < n) {
        const c = cells[i] || { ch: ' ', css: '' };
        if (isLive && i === col) { const cur = document.createElement('span'); cur.className = 'tm-cursor' + (focused ? '' : ' tm-blur'); cur.textContent = c.ch; d.appendChild(cur); i++; continue; }
        let j = i, text = '';
        while (j < n && !(isLive && j === col) && (cells[j] || { css: '' }).css === c.css) { text += (cells[j] || { ch: ' ' }).ch; j++; }
        const sp = document.createElement('span'); if (c.css) sp.style.cssText = c.css; sp.textContent = text; d.appendChild(sp);
        i = j;
      }
      if (!n) d.appendChild(document.createTextNode('​'));   // an empty line keeps its height
      return d;
    };
    const flush = () => {
      const pinned = host.scrollHeight - host.scrollTop - host.clientHeight < 24;
      if (lines.length > MAX) { const drop = lines.splice(0, lines.length - MAX); drop.forEach((l) => l.dom && l.dom.remove()); dirty = 0; }
      for (let i = dirty; i < lines.length; i++) {
        const d = render(lines[i], i === lines.length - 1);
        const before = i + 1 < lines.length ? lines[i + 1].dom : null;
        if (d.parentNode !== doc || (before && d.nextSibling !== before)) doc.insertBefore(d, before && before.parentNode === doc ? before : null);
      }
      dirty = lines.length;
      if (pinned) host.scrollTop = host.scrollHeight;
    };
    const clear = () => { lines.forEach((l) => l.dom && l.dom.remove()); lines.length = 0; col = 0; dirty = 0; };
    const focus = (f) => { focused = f; if (lines.length) { touch(lines.length - 1); flush(); } };
    return { apply, slog, flush, clear, focus };
  }
  // a key as a belt: dill's shapes (see explorer.hoon +json-to-belt).
  // ⌘ stays the browser's (copy, paste, tabs); ⌥ is dill's %met; ctrl is
  // %ctl except ctrl-d, which would end the session.
  function keyBelt(e) {
    if (e.isComposing) return null;
    const k = e.key;
    if (e.metaKey) return null;
    if (k === 'Enter') return 'ret';
    if (k === 'Backspace') return e.altKey ? { mod: { mod: 'met', key: 'bac' } } : 'bac';
    if (k === 'Delete') return 'del';
    if (k === 'Tab') return { txt: '  ' };
    if (k === 'ArrowUp') return { aro: 'u' };
    if (k === 'ArrowDown') return { aro: 'd' };
    if (k === 'ArrowLeft') return { aro: 'l' };
    if (k === 'ArrowRight') return { aro: 'r' };
    if (k === 'Escape') return null;
    if (k.length === 1) {
      if (e.ctrlKey) { const c = k.toLowerCase(); return c === 'd' ? null : { mod: { mod: 'ctl', key: c } }; }
      if (e.altKey) return { mod: { mod: 'met', key: k } };
      return k;
    }
    return null;
  }
  let termCss = false;
  function termChrome() {
    if (termCss) return; termCss = true;
    const s = document.createElement('style');
    s.textContent =
      '.tm-doc{min-height:100%;box-sizing:border-box;padding:6px 10px 8px;display:flex;flex-direction:column;justify-content:flex-end;background:#fff;color:#1f2328;font:13px/1.4 "SF Mono",Menlo,Consolas,"Roboto Mono","Courier New",monospace;cursor:text}' +
      '.tm-line{white-space:pre-wrap;word-break:break-all;min-height:1.4em}' +
      '.tm-cursor{background:#1f2328;color:#fff;border-radius:1px}' +
      '.tm-cursor.tm-blur{background:transparent;color:inherit;box-shadow:inset 0 0 0 1px #8c959f}' +
      '.tm-input{position:absolute;width:1px;height:1px;opacity:0;border:0;padding:0;margin:0;resize:none;overflow:hidden}';
    document.head.appendChild(s);
  }
  function psTerminal(ps, paneId, el, ns, abs, session, args) {
    termChrome();
    psClear(el);
    el.style.overflow = 'auto';
    el.style.position = 'relative';
    const doc = document.createElement('div'); doc.className = 'tm-doc';
    const inp = document.createElement('textarea'); inp.className = 'tm-input'; inp.setAttribute('aria-label', 'terminal input'); inp.autocapitalize = 'off'; inp.spellcheck = false;
    inp.dataset.focus = '1';                                        // gmux lands the keyboard here when the pane is selected (focusContent); arrows then reach dill, not the workspace
    el.append(inp, doc);
    const screen = makeScreen(doc, el);
    const own = session !== '';                                    // a named session: this pane sizes it, once
    const post = (body) => fetch(TERM, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(Object.assign({ session }, body)) })
      .then(async (r) => { if (!r.ok) { let why = 'term ' + r.status; try { why = (await r.json()).error || why; } catch (_) {} throw new Error(why); } });
    // dill's own width, for how drum lays the live line out: wide, so dill
    // does not fold lines the document wraps anyway. ?cols= overrides.
    const cols = (() => { const n = parseInt(args && args.cols, 10); return n >= 20 && n <= 500 ? n : 160; })();
    if (own) post({ blew: { w: cols, h: 40 } }).catch(() => {});
    const batch = (blits) => { blits.forEach(screen.apply); screen.flush(); };
    const slog = (told) => { const ls = toldLines(told); if (!ls.length) return; ls.forEach(screen.slog); screen.flush(); };
    // history, then each new batch by version; reads are serialized so a
    // burst of events is one read after another, never two at once
    let cur = 0, chain = Promise.resolve();
    const play = (d) => {
      // dill prints the slogs into the default session itself; a grey copy
      // there would double every line. A named session sees them only here.
      const items = (d.versions || []).map((v) => ({ da: v.da || 0, v })).concat(own ? (d.logs || []).map((l) => ({ da: l.da || 0, l })) : []);
      items.sort((a, b) => a.da - b.da);
      items.forEach((it) => { if (it.v) { cur = Math.max(cur, it.v.ud || 0); (it.v.blits || []).forEach(screen.apply); } else toldLines(it.l.told).forEach(screen.slog); });
      if (typeof d.cur === 'number') cur = Math.max(cur, d.cur);
      screen.flush();
    };
    const pull = (first) => chain = chain.then(async () => {
      if (el._dead) return;
      const r = await fetch(termUrl(session, first ? '&last=300' : '&from=' + (cur + 1)), { cache: 'no-store' });
      if (r.status === 404) { psMarkDead(ps, el, ns, 'no such session'); return; }
      if (!r.ok) throw new Error('term ' + r.status);
      play(await r.json());
      if (first) el.scrollTop = el.scrollHeight;
    }).catch((e) => { if (first) toast('terminal: ' + (e && e.message || e), true); });
    pull(true);
    const send = (belts) => belts.forEach((b) => post({ belt: b }).catch((e) => toast('terminal: ' + (e && e.message || e), true)));
    // the keyboard is either IN the prompt (arrows are dojo's history) or
    // on the pane (arrows scroll the document): Escape steps out, prefix+i
    // or a click steps back in; PageUp/PageDown scroll from either place
    el.tabIndex = -1;
    inp.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') { e.preventDefault(); inp.blur(); el.focus({ preventScroll: true }); return; }
      if (e.key === 'PageUp' || e.key === 'PageDown') { e.preventDefault(); el.scrollBy({ top: (e.key === 'PageUp' ? -1 : 1) * el.clientHeight * 0.9 }); return; }
      const b = keyBelt(e); if (b == null) return; e.preventDefault(); send([b]);
    });
    inp.addEventListener('compositionend', (e) => { if (e.data) send([{ txt: e.data }]); inp.value = ''; });
    inp.addEventListener('input', () => { if (!inp.value) return; const v = inp.value; inp.value = ''; if (v.length) send([v.length === 1 ? v : { txt: v }]); });   // what keydown did not take: dead keys, mobile
    inp.addEventListener('paste', (e) => { e.preventDefault(); const t = (e.clipboardData || window.clipboardData).getData('text'); if (t) send([{ txt: t.replace(/\r?\n/g, ' ') }]); });
    inp.addEventListener('focus', () => screen.focus(true));
    inp.addEventListener('blur', () => screen.focus(false));
    // a click focuses the input unless it is selecting text; the pane keeps
    // native selection and copy
    el.addEventListener('mouseup', () => { const sel = window.getSelection(); if (!sel || sel.isCollapsed) inp.focus({ preventScroll: true }); });
    const unslog = slogStream((lines) => { lines.forEach(screen.slog); screen.flush(); });
    el._fv = {
      destroy() { el._dead = true; unslog(); },
      onUpdate(ev) {
        if (ev.road === LOGS) { if (own && ev.body && typeof ev.body === 'object') slog(ev.body); return; }
        if (!own || ev.path === abs) pull(false);                      // a named session follows its own grub; the default follows the dir
      },
    };
    el._menu = () => [
      { label: 'New terminal…', run: () => go(el, PREFIX + SESSIONS.replace(/\/$/, '') + '?view=term-new', 'dir') },
      { label: 'Clear', run: () => { screen.clear(); screen.flush(); } },
      own ? { label: 'Close session', danger: true, run: () => post({ shut: true }).then(() => ps.back(paneId)).catch((e) => toast('terminal: ' + (e && e.message || e), true)) } : null,
    ].filter(Boolean);
    // the session's grub by name (the default session's is the empty name
    // under the dir, so the dir is followed for it) and the slog stream
    paneLive(ps, paneId, el, own ? [{ road: abs }, { road: LOGS, body: true }] : [{ road: SESSIONS }]);
    psLanded(ps, paneId, el);
    inp.focus({ preventScroll: true });
  }

  // ---- toast ----
  let toastTimer = null;
  function toast(msg, err) {
    // the pane workspace drops the finder's chrome; the toast is the one piece
    // the workspace keeps, so it is rebuilt here when missing
    let s = $('status');
    if (!s) { s = document.createElement('div'); s.id = 'status'; root.appendChild(s); }
    s.textContent = msg;
    s.className = err ? 'err' : '';
    s.style.display = 'block';
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { s.style.display = 'none'; }, err ? 6000 : 2000);
  }

  // standalone panes endpoint (/grubbery/explorer): stand the pane workspace up
  // full-screen using the SAME wiring as the ⊞ panes tab — no finder.
  const SESSION_API = PREFIX.replace(/\/ball$/, '/explorer') + '/session';
  const SESSIONS_DIR = '/apps/explorer.explorer/sessions/';
  // ---- the session protocol: every client of a workspace speaks it ----
  // The session grub is the record. A client attaches (taking over whoever
  // held it), restores the spec, applies the ops waiting in it, and from then
  // on writes back every change its model announces, carrying the ids of the
  // ops it applied. The grub is followed: a change brings either ops to apply
  // or the news that someone else attached, and then this client goes passive
  // and mirrors what the driver writes until it takes over again.
  // `settled` is the renderer's cue that the model changed under it.
  function sessionClient(ps, root, sessionName, settled) {
    settled = settled || function () {};
    // The session grub is the record. We attach (taking over any other tab),
    // restore its spec, apply the ops waiting in it, and from then on: every
    // change gmux announces is written back (debounced) with the ids of the
    // ops applied; the grub is followed, and a change of it brings either
    // ops to apply (an agent's, another sender's) or the news that another
    // client attached — then this tab goes passive until it takes over again.
    const clientId = Math.random().toString(36).slice(2, 10) + Date.now().toString(36);
    const sessionRoad = SESSIONS_DIR + sessionName + '.json';
    const api = (body) => fetch(SESSION_API, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(Object.assign({ name: sessionName }, body)) })
      .then(async (r) => ({ status: r.status, json: await r.json().catch(() => null) }));
    let attached = false, passive = false, ver = 0, mirrored = null;
    const appliedIds = new Set(); let toReport = [];
    const banner = document.createElement('div');
    banner.style.cssText = 'position:fixed;left:50%;top:12px;transform:translateX(-50%);z-index:50;background:#fff8c5;color:#4d2d00;border:1px solid #d4a72c;border-radius:8px;padding:8px 14px;font:13px -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;box-shadow:0 4px 14px rgba(0,0,0,.12);display:none;gap:12px;align-items:center';
    root.appendChild(banner);
    const say = (text, action, run) => { banner.textContent = ''; banner.style.display = 'flex'; banner.appendChild(document.createTextNode(text)); if (action) { const b = document.createElement('button'); b.textContent = action; b.style.cssText = 'font:inherit;font-weight:600;padding:3px 10px;border-radius:6px;border:1px solid #b08800;background:#fff;cursor:pointer'; b.addEventListener('click', run); banner.appendChild(b); } const x = document.createElement('button'); x.textContent = '×'; x.title = 'dismiss'; x.style.cssText = 'font:inherit;border:0;background:none;cursor:pointer;color:inherit'; x.addEventListener('click', () => { banner.style.display = 'none'; }); banner.appendChild(x); };
    const doOp = (op) => {
      const t = op && op.type;
      if (t === 'open' && typeof op.path === 'string') { if (op.where === 'here') ps.navigate(null, op.path); else ps.open(op.path, 'beside'); }
      else if (t === 'close' && typeof op.path === 'string') { const want = psNs(op.path); for (const p of ps.querySelectorAll('.ps-pane[data-pane-id]')) { const id = p.dataset.paneId, cur = ps.pathOf(id); if (cur && psNs(cur) === want) { ps.closeLeaf(id); break; } } }
      else if (t === 'layout' && op.spec && typeof op.spec === 'object') { ps.restore(op.spec); settled(); }
      else if (t === 'split') { if (op.dir === 'down') ps.splitDown(); else ps.splitRight(); }
      else if (t === 'collapse') ps.collapse();
    };
    const applyOps = (ops) => {
      if (!Array.isArray(ops)) return;
      for (const op of ops) { if (!op || typeof op.id !== 'number' || appliedIds.has(op.id)) continue; appliedIds.add(op.id); toReport.push(op.id); try { doOp(op); } catch (e) { toast('session op failed: ' + (e && e.message || e), true); } }
      if (toReport.length) writeBack();
    };
    let wbTimer = null, wbChain = Promise.resolve();
    const writeBack = () => { if (!attached || passive) return; clearTimeout(wbTimer); wbTimer = setTimeout(() => { wbChain = wbChain.then(async () => {
      if (!attached || passive) return;
      const applied = toReport; toReport = [];
      const r = await api({ client: clientId, spec: ps.serialize(), applied });
      if (r.status === 409) { goPassive(r.json); return; }
      if (r.status !== 200 || !r.json) { toast('session: write failed (' + r.status + ')', true); toReport = applied.concat(toReport); return; }
      ver = r.json.ver || ver;
    }).catch(() => {}); }, 250); };
    const goPassive = (st) => {
      if (passive) return;
      passive = true;
      const who = st && st.client && st.client.since ? new Date(st.client.since).toLocaleTimeString() : '';
      say('This session is now open in another tab' + (who ? ' (since ' + who + ')' : '') + '. This tab is passive.', 'Take over', attach);
    };
    // while attaching, the workspace sits under the same waiting block a pane
    // shows while it fetches; a failed attach leaves it there, stopped
    const cover = document.createElement('div');
    const covering = (text, sub, fail) => { (fail ? psWaitFail : psWait)(cover, text, sub); cover.style.cssText = 'position:absolute;inset:0;z-index:40'; if (!cover.parentNode) root.appendChild(cover); };
    root.style.position = 'relative';
    const attach = async () => {
      banner.style.display = 'none';
      covering('attaching', sessionName);
      const r = await api({ attach: clientId });
      if (r.status !== 200 || !r.json) { covering('could not attach to this session', 'http ' + r.status, true); say('Could not attach to session "' + sessionName + '" (' + r.status + ').', 'Sessions', () => { location.href = '/grubbery/explorer'; }); return; }
      cover.remove();
      const st = r.json;
      passive = false; attached = true; ver = st.ver || 0; mirrored = null;
      if (st.spec && typeof st.spec === 'object') ps.restore(st.spec);
      else if (typeof st.layout === 'string' && st.layout) {
        ps.open('/', 'here');
        try { const spec = await fetch(psUrl(st.layout), { cache: 'no-store' }).then((x) => x.ok ? x.json() : Promise.reject(x.status)); ps.replaceWithLayout(ps.cursor.id, spec, st.layout); } catch (e) { toast('layout did not load: ' + e, true); }
      } else ps.open('/', 'here');
      settled();
      applyOps(st.ops);
      writeBack();
    };
    ps.addEventListener('gmux-change', () => writeBack());
    live([{ road: sessionRoad, body: true }], (ev) => {
      if (ev.kind === 'del') { attached = false; say('Session "' + sessionName + '" was deleted.', 'Sessions', () => { location.href = '/grubbery/explorer'; }); return; }
      const st = ev.body; if (!st || typeof st !== 'object') return;
      if (st.client && st.client.id && st.client.id !== clientId) {
        // another tab drives: this one mirrors what it writes, read-only
        goPassive(st);
        if (!st.spec || typeof st.spec !== 'object') return;
        // only the selection moved → hop; anything else → rebuild from the spec
        const sansCursor = (sp) => { const c = Object.assign({}, sp); delete c.cursor; return JSON.stringify(c); };
        const key = sansCursor(st.spec);
        if (key !== mirrored) { mirrored = key; ps.restore(st.spec); settled(); }
        else if (typeof st.spec.cursor === 'string' && st.spec.cursor !== ps.cursorAddr()) ps.cursorToAddr(st.spec.cursor);
        return;
      }
      if (!passive && attached) applyOps(st.ops);
    }, null);
    window.addEventListener('pagehide', () => { if (attached && !passive) { try { navigator.sendBeacon(SESSION_API, new Blob([JSON.stringify({ name: sessionName, detach: clientId })], { type: 'application/json' })); } catch (_) {} } });
    return { attach: attach, writeBack: writeBack };
  }
  // ---- mobile: the palace through a phone-sized aperture ----
  // The same palace and the same session, walked instead of surveyed. A phone
  // cannot tile a workspace, so it shows ONE NODE of the tree at a time: a
  // leaf renders its content full screen, a container renders its subtree
  // stacked evenly down the phone. You swipe between the two sides of a
  // division (the left/top side is a left swipe, the right/bottom side a
  // right one), descend into what you are on, and climb back out.
  //
  // A tile drops a rung of fidelity as it gets smaller: content, then a name,
  // then the owning app's icon over its colour, then the colour alone. Below
  // the top rung a tile is a target, not a thing you use, so a tap descends
  // into it rather than reaching the content under your finger.
  //
  // It is a full client, not a viewer. Two choices a phone has no use for are
  // simply made for it: a division's orientation (everything stacks) and its
  // ratio (always even). Flipping the two sides still matters, since it
  // decides which way you swipe to reach them.
  //
  // The model is a HEADLESS gmux: it owns the tree, the splits, the history
  // and serialize/restore exactly as the desktop does, and never draws. Only
  // the drawing and the gestures here are new, so there is one implementation
  // of what a split is.
  const MB_LIVE = 140, MB_NAME = 36, MB_ICON = 20;      // rungs, by tile height
  const MB_BAR = 26;                                    // what a pane's own bar costs the body below it
  let mbCss = false;
  function mobileChrome() {
    if (mbCss) return; mbCss = true;
    const s = document.createElement('style');
    s.textContent =
      '.mb-body{flex:1;min-height:0;position:relative;overflow:hidden;touch-action:pan-y;overscroll-behavior-x:none;background:#eaeef2}' +
      // the swipe strip: the lateral gesture lives HERE, not over the content.
      // Across the body it fought everything at once — a scroller underneath,
      // a map that pans itself, and Chrome's own horizontal overscroll, which
      // navigates back and so (through popstate) moved the seat somewhere
      // unrelated. A strip we own takes none of that: touch-action none, no
      // content beneath it, nothing else that can claim it.
      '.mb-swipe{flex:none;height:26px;display:flex;align-items:center;justify-content:center;touch-action:none;overscroll-behavior:contain;background:#f8f8f8;border-bottom:1px solid #e8e8e8;cursor:grab}' +
      '.mb-swipe:active{cursor:grabbing}' +
      '.mb-swipe .grip{width:38px;height:4px;border-radius:2px;background:#cdd3da;transition:opacity .15s}' +
      '.mb-swipe.alone .grip{opacity:.3}' +
      // a division is a BOX its children sit inside, tinted a step darker with
      // depth, so three levels read as three levels and not as four stripes
      '.mb-split{position:relative;display:flex;flex-direction:column;gap:5px;height:100%;min-height:0;padding:5px;border-radius:11px;box-sizing:border-box}' +
      '.mb-split>*{flex:1;min-height:0}' +
      '.mb-leaf{position:relative;display:flex;flex-direction:column;overflow:hidden;height:100%;background:#fff;border-radius:8px;border:1px solid #cdd5dd;box-sizing:border-box}' +
      // a pane that only holds other panes has no card of its own: its bar sits
      // straight on top of what it holds
      '.mb-leaf.mb-group{background:transparent;border:0;border-radius:0}' +
      '.mb-leaf.mb-group > .mb-head{border-radius:6px 6px 0 0}' +
      '.mb-leaf.mb-group > .mb-split{flex:1;min-height:0}' +
      // what a pane IS, said in colour: the owning app's tile colour, carried
      // on a strip when the content is live and over the whole tile when not
      // the pane head is part of the container, not a label stuck on content:
      // the same ground, border and ink as the bar at the bottom of the screen
      '.mb-head{position:relative;flex:0 0 auto;display:flex;align-items:stretch;gap:0;padding:0 7px;background:#f6f8fa;border-bottom:1px solid #d0d7de;color:#1f2328;font:600 11px -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;overflow-x:auto;scrollbar-width:none}' +
      '.mb-head::-webkit-scrollbar{display:none}' +
      '.mb-head .mb-g,.mb-head .mb-n{align-self:center;padding:4px 0}' +
      '.mb-head .mb-g{margin-right:6px}' +
      '.mb-tab{flex:0 0 auto;padding:6px 10px 4px;border-bottom:2px solid transparent;color:#57606a;white-space:nowrap;max-width:42vw;overflow:hidden;text-overflow:ellipsis;cursor:pointer}' +
      '.mb-tab.on{color:#1f2328;border-bottom-color:#1f2328}' +
      '.mb-head .mb-g{font-size:12px;opacity:.9}' +
      '.mb-head .mb-n{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +
      '.mb-content{flex:1;min-height:0;overflow:hidden;position:relative}' +
      '.mb-content>*{height:100%;overflow:auto}' +
      '.mb-tap{position:absolute;inset:0;z-index:5}' +
      '.mb-tile{flex:1;min-height:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:5px;overflow:hidden;color:#fff;font:600 13px -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;text-align:center;padding:6px}' +
      '.mb-tile .mb-sub{font:400 11px ui-monospace,Menlo,monospace;opacity:.85;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;max-width:94%}' +
      '.mb-tile.mb-empty{background:#f6f8fa;color:#8c959f;border:1px dashed #cdd5dd;border-radius:7px;font-weight:400}' +
      '.mb-glyph{font-size:20px;line-height:1}' +
      '.mb-head .mb-tabn{margin-left:auto;flex:0 0 auto;font-weight:700;opacity:.9}' +
      '.mb-work{box-shadow:0 0 0 2px #1a7f37}' +

      '.mb-bars{flex:0 0 auto;border-top:1px solid #d0d7de;background:#f6f8fa;font:13px -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}' +
      '.mb-row{position:relative;display:flex;align-items:center;gap:4px;padding:7px 9px}' +
      '.mb-row.mb-pathrow{padding-top:0;gap:6px}' +
      '.mb-bars button{font:inherit;font-size:15px;line-height:1;padding:8px 11px;border:1px solid #d0d7de;border-radius:8px;background:#fff;color:#1f2328}' +
      '.mb-bars button:disabled{opacity:.3}' +
      // which of a division's two sides you are on, and swipe is how you move
      '.mb-dots{position:absolute;left:0;right:0;top:0;bottom:0;display:flex;align-items:center;justify-content:center;gap:8px;pointer-events:none}' +
      '.mb-dots button{pointer-events:auto}' +
      '.mb-gap{flex:1}' +
      '.mb-dots button{width:9px;height:9px;padding:0;border:0;border-radius:50%;background:#cdd5dd}' +
      '.mb-dots button.on{background:#57606a}' +
      '.mb-kind{flex:0 0 auto;width:10px;height:10px;border-radius:3px;background:#cdd5dd}' +
      '.mb-path{flex:1;min-width:0;font:12px ui-monospace,Menlo,monospace;padding:8px 9px;border:1px solid #d0d7de;border-radius:8px;background:#fff;color:#1f2328}' +
      '.mb-bars button.danger{color:#1f2328}' +
      '.mb-tabrow{display:flex;gap:6px;padding:8px 9px 0;overflow-x:auto;scrollbar-width:none}' +
      '.mb-tabrow::-webkit-scrollbar{display:none}' +
      '.mb-tabchip{flex:0 0 auto;font:600 12px -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;padding:6px 12px;border:1px solid #d0d7de;border-radius:999px;background:#fff;color:#57606a;max-width:46vw;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +
      '.mb-tabchip.on{background:#1f2328;border-color:#1f2328;color:#fff}' +
      '.mb-tabs{flex:0 0 auto;display:flex;align-items:center;gap:5px;padding:8px 10px;border:1px solid #d0d7de;border-radius:8px;background:#fff;font:600 12px -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:#1f2328}' +
      // the tab grid: every tab of this pane, drawn by the same renderer at
      // the size a card has, so each one looks like what it is
      '.mb-sheet{position:absolute;inset:0;z-index:20;display:flex;flex-direction:column;background:#eaeef2}' +
      '.mb-sheet-head{flex:0 0 auto;display:flex;align-items:center;gap:8px;padding:10px 12px;background:#f6f8fa;border-bottom:1px solid #d0d7de;font:600 13px -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}' +
      '.mb-sheet-head .t{flex:1;color:#57606a;font-weight:400}' +
      '.mb-sheet-head button{font:inherit;padding:7px 11px;border:1px solid #d0d7de;border-radius:8px;background:#fff;color:#1f2328}' +
      '.mb-grid{flex:1;min-height:0;overflow:auto;display:grid;grid-template-columns:1fr 1fr;gap:10px;padding:12px;align-content:start}' +
      '.mb-card{position:relative;display:flex;flex-direction:column;border-radius:10px;overflow:hidden;background:#fff;border:1px solid #cdd5dd}' +
      '.mb-card.on{box-shadow:0 0 0 2px #0969da}' +
      '.mb-card .shot{height:150px;position:relative;overflow:hidden;pointer-events:none}' +
      '.mb-card .cap{display:flex;align-items:center;gap:6px;padding:7px 8px;border-top:1px solid #eaeef2;font:600 11px -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}' +
      '.mb-card .cap .t{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +
      '.mb-card .x{position:absolute;top:6px;right:6px;z-index:2;width:23px;height:23px;padding:0;border:0;border-radius:50%;background:rgba(31,35,40,.5);color:#fff;font-size:13px;line-height:1}' +
      '.mb-confirm{display:flex;align-items:center;gap:8px;padding:9px 10px;background:#fff8c5;border-top:1px solid #d4a72c;font:13px -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}' +
      '.mb-confirm .t{flex:1;color:#4d2d00}' +
      '.mb-confirm button{font:inherit;font-weight:600;padding:7px 12px;border:1px solid #d0d7de;border-radius:8px;background:#fff;color:#1f2328}' +
      '.mb-confirm button.danger{background:#1f2328;border-color:#1f2328;color:#fff}' +
      '.mb-newtab{display:flex;align-items:center;justify-content:center;min-height:130px;border:1px dashed #b9c2cc;border-radius:10px;background:#fff;color:#57606a;font:600 13px -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}';
    document.head.appendChild(s);
  }
  function mobileWorkspace(root, sessionName) {
    pageNav = false;               // this client owns the page and its history
    mobileChrome();
    while (root.firstChild) root.removeChild(root.firstChild);
    // dvh, not vh: on mobile Chrome 100vh is the viewport with the URL bar
    // RETRACTED, so a column that tall pushes the bars below the fold — the
    // phone client renders with no bottom toolbar at all. dvh tracks what is
    // actually visible; vh stays as the fallback for anything without dvh.
    root.style.cssText = 'display:flex;flex-direction:column;height:100vh;height:100dvh;background:#fff;position:relative';
    document.title = sessionName + ' · gmux';
    // the model, never shown
    const model = document.createElement('gmux-host');
    model.renderPath = () => document.createElement('div');
    model.style.cssText = 'position:fixed;left:-10000px;top:0;width:900px;height:700px;visibility:hidden;pointer-events:none';
    document.body.appendChild(model);

    const body = document.createElement('div'); body.className = 'mb-body';
    const bars = document.createElement('div'); bars.className = 'mb-bars';
    const tabRow = document.createElement('div'); tabRow.className = 'mb-tabrow';
    const bar = document.createElement('div'); bar.className = 'mb-row';
    const pathRow = document.createElement('div'); pathRow.className = 'mb-row mb-pathrow';
    const swipe = document.createElement('div'); swipe.className = 'mb-swipe';
    const grip = document.createElement('div'); grip.className = 'grip'; swipe.appendChild(grip);
    swipe.title = 'drag sideways to move between the two panes at this level';
    bars.append(swipe, tabRow, bar, pathRow);
    root.append(body, bars);

    // what paneContent expects of a workspace
    const host = document.createElement('div');
    Object.assign(host, {
      cursor: null, redrawBars() {}, refresh() { schedule(); }, focusContent() {},
      pathOf() { return null; }, viewOf() { return null; }, back() {}, layoutSources() { return []; },
      // a view that opens a moment is ROUTED by the layout, exactly as on the
      // desktop: it lands in the pane the table names, not on top of the
      // navigator that opened it. The aperture then follows it there.
      open(p) { routeOpen(seat, p); },
      openFrom(addr, p, name) { routeOpen(addr, p, name); },
      closeFrom(addr, p) { if (model.cursorToAddr(addr)) { model.closeFrom(model.cursor && model.cursor.id, p); redraw(); } },
      // a dir an app opens as a layout becomes a real subtree in the model,
      // the same as it would on a desktop; the aperture stays where it is
      replaceWithLayout(addr, spec, src) { if (model.cursorToAddr(addr)) { model.replaceWithLayout(model.cursor.id, spec, src); redraw(); } },
    });

    // ---- the tree: ONE node per pane in the spec, addressed as gmux
    // addresses it. A pane's active tab holds one entry, and that entry is
    // what the pane IS: a division of two panes, a single pane held inside
    // it, or a moment. Nothing is folded away, so every pane is a level you
    // can stand on and every address gmux hands us names a node.
    const emptyPane = () => ({ tabs: [{ entries: [], cursor: -1 }], activeTab: 0 });
    const treeOf = (spec) => mkNode(spec || emptyPane(), '.', null, null);
    function mkNode(ps, addr, parent, slot) {
      const tabs = (ps && ps.tabs) || [];
      const ti = (ps && ps.activeTab) || 0;
      const tab = tabs[ti] || tabs[0] || { entries: [], cursor: -1 };
      const e = (tab.cursor >= 0) ? tab.entries[tab.cursor] : null;
      const n = { spec: ps, addr, parent, slot, tabs, tab, entry: e, kids: [] };
      const down = (seg) => (addr === '.' ? '' : addr + '/') + ti + '/' + seg;
      if (e && e.div) { n.kind = 'div'; n.div = e.div; n.kids = [mkNode(e.div.a || emptyPane(), down('a'), n, 'a'), mkNode(e.div.b || emptyPane(), down('b'), n, 'b')]; }
      else if (e && e.pane) { n.kind = 'hold'; n.kids = [mkNode(e.pane, down('a'), n, 'a')]; }
      else { n.kind = 'leaf'; n.path = e ? e.path : null; n.name = (e && e.name) || null; }
      return n;
    }
    const find = (n, addr) => { if (n.addr === addr) return n; for (const k of n.kids) { const f = find(k, addr); if (f) return f; } return null; };
    const holds = (n, addr) => !!find(n, addr);
    const nearest = (addr) => {
      const segs = addr === '.' ? [] : addr.split('/');
      for (let i = segs.length; i >= 0; i -= 2) {
        const n = find(tree, i === 0 ? '.' : segs.slice(0, i).join('/'));
        if (n) return n;
      }
      return tree;
    };
    // the other side of the division this pane is in — this level's own pair,
    // never an ancestor's: a level with no sibling has nowhere lateral to go
    const sibling = (n, slot) => { const p = n.parent; if (!p || p.kind !== 'div') return null; const k = p.kids.find((x) => x.slot === slot); return (k && k !== n) ? k : null; };

    // ---- rendering ----
    // THE SEAT: where this client sits in the tree. The phone shows one level,
    // so it needs no selector — nothing to disambiguate — and it must not write
    // the workspace's cursor, which says what is SELECTED and belongs to the
    // desktop along with its nested per-context zooms. The seat is the phone's
    // alone, carried in session state so a session resumes where you were
    // sitting, and never in the URL.
    let seat = '.', seeded = false;
    let drag = null;                 // an in-flight swipe: the two levels on a track
    let tree = treeOf(model.serialize());
    // what opened a container: a division carries it on the div, a held pane on the entry
    const srcOf = (n) => (n.entry ? (n.entry.div ? n.entry.div.src : (n.entry.pane ? n.entry.src : null)) : null) || null;
    const countLeaves = (n) => n.kind === 'leaf' ? 1 : n.kids.reduce((a, k) => a + countLeaves(k), 0);
    // a container is named the way gmux names one: what opened it, else 'layout'
    const labelOf = (n) => n.kind === 'leaf' ? (n.name || (n.path ? psBase(n.path) : 'empty')) : tabLabel(n.tab);
    // the user's name for a tab, else the name the content offered when it
    // opened, else what it is — the same order gmux uses on the desktop
    const tabLabel = (t) => {
      if (!t) return 'empty';
      if (t.label) return t.label;
      const e = t.cursor >= 0 ? t.entries[t.cursor] : null;
      if (!e) return 'empty';
      if (e.name) return e.name;
      if (e.div || e.pane) { const src = (e.div && e.div.src) || e.src; return src ? psBase(src) : 'layout'; }
      return psBase(e.path) || 'empty';
    };
    const tabIcon = (t) => {
      const e = t && t.cursor >= 0 ? t.entries[t.cursor] : null;
      return e && (e.div || e.pane) ? '▣' : null;
    };
    // ---- one way to draw a pane, at every level ----
    // BAR: its tabs when it holds more than one, else its name. The bar is
    // also the handle: tapping it steps into that pane, the way clicking a
    // pane's bar selects it on the desktop.
    function barEl(n, standing) {
      const many = n.tabs.length > 1;
      // A pane that is one of a division's two sides ALWAYS wears its bar,
      // standing on it or not: climbing onto it takes you from one dot to two,
      // and that has to show on the screen and not only in the dots. Only a
      // pane with no sibling at all can go bare, and only when it has no tabs
      // to show — the bar at the bottom of the screen names that one.
      const half = !!(n.parent && n.parent.kind === 'div');
      if (standing && !many && !half) return null;
      const strip = document.createElement('div'); strip.className = 'mb-head';
      strip.addEventListener('pointerup', (e) => { e.stopPropagation(); });
      strip.addEventListener('click', (e) => { e.stopPropagation(); goTo(n.addr); });
      if (many) {
        const active = (n.spec && n.spec.activeTab) || 0;
        n.tabs.forEach((t, i) => {
          const tabEl = document.createElement('div'); tabEl.className = 'mb-tab' + (i === active ? ' on' : '');
          tabEl.textContent = tabLabel(t);
          tabEl.addEventListener('pointerup', (e) => e.stopPropagation());
          // a tab switch changes what this pane HOLDS, not where you stand:
          // the aperture stays exactly where it is. It only moves if you were
          // standing inside the subtree that just went away, and then only as
          // far as this pane (draw falls back to the nearest level alive).
          tabEl.addEventListener('click', (e) => {
            e.stopPropagation();
            if (!model.cursorToAddr(n.addr)) return;
            model.selectTab(model.cursor && model.cursor.id, i);
            redraw();
          });
          strip.appendChild(tabEl);
        });
      } else {
        const glyph = tabIcon(n.tab);
        if (glyph) { const g = document.createElement('span'); g.className = 'mb-g'; g.textContent = glyph; strip.appendChild(g); }
        const nm = document.createElement('span'); nm.className = 'mb-n'; nm.textContent = tabLabel(n.tab);
        strip.appendChild(nm);
      }
      return strip;
    }
    // BODY: a division draws its two panes stacked evenly, a holder draws the
    // pane it holds, a moment draws itself — live when there is room for it,
    // its app's colour when there is not.
    function levelEl(n, h, cursorAddr, depth, standing) {
      const el = document.createElement('div');
      el.className = 'mb-leaf' + (n.kind === 'leaf' ? '' : ' mb-group');
      el.dataset.addr = n.addr;
      if (n.addr === cursorAddr) el.classList.add('mb-work');
      const bar = h >= MB_NAME ? barEl(n, standing) : null;
      if (bar) el.appendChild(bar);
      const inner = h - (bar ? MB_BAR : 0);
      if (n.kind === 'div') {
        const box = document.createElement('div'); box.className = 'mb-split';
        box.style.background = 'rgba(31,35,40,' + Math.min(0.05 + depth * 0.045, 0.2) + ')';
        const half = (inner - 15) / 2;                                 // padding 10 + gap 5
        box.append(levelEl(n.kids[0], half, cursorAddr, depth + 1, false), levelEl(n.kids[1], half, cursorAddr, depth + 1, false));
        el.appendChild(box);
      } else if (n.kind === 'hold') {
        const held = levelEl(n.kids[0], inner, cursorAddr, depth, false);
        held.style.flex = '1'; held.style.minHeight = '0';
        el.appendChild(held);
      } else if (inner >= MB_LIVE && n.path) {
        const box = document.createElement('div'); box.className = 'mb-content';
        box.appendChild(contentFor(n));
        el.appendChild(box);
        wireTarget(el, n);
      } else {
        const t = document.createElement('div'); t.className = 'mb-tile' + (n.path ? '' : ' mb-empty');
        if (!bar) {                                                    // no bar, so the block carries the name
          if (inner >= MB_NAME) t.appendChild(Object.assign(document.createElement('div'), { textContent: n.path ? labelOf(n) : 'empty' }));
        }
        el.appendChild(t);
        wireTarget(el, n);
      }
      return el;
    }
    // a tap on a moment goes to that moment; a drag is a swipe or a scroll
    function wireTarget(el, n) {
      let sx = 0, sy = 0;
      el.addEventListener('pointerdown', (e) => { sx = e.clientX; sy = e.clientY; });
      el.addEventListener('pointerup', (e) => {
        if (Math.abs(e.clientX - sx) > 8 || Math.abs(e.clientY - sy) > 8) return;
        e.preventDefault(); e.stopPropagation();
        el.addEventListener('click', (c) => { c.preventDefault(); c.stopPropagation(); }, { capture: true, once: true });
        goTo(n.addr);
      });
    }
    // Mounted content is KEPT, and it is keyed by WHAT A PANE SHOWS, not by
    // where the pane sits. Flipping two panes swaps their addresses, and an
    // address key would remount both for no reason; two panes on the same
    // moment are interchangeable anyway, so a pool per path is enough. A
    // mount is dropped only when the workspace stops holding that moment.
    const pool = new Map();                 // path -> [content elements]
    const scrollOf = new Map();             // element -> where it was scrolled
    let claimed = new Set();
    const contentFor = (n) => {
      const path = n.path || '';
      let list = pool.get(path);
      if (!list) { list = []; pool.set(path, list); }
      let el = list.find((e) => !claimed.has(e));
      if (!el) { el = paneContent(host, n.addr, n.path); list.push(el); }
      claimed.add(el);
      if (scrollOf.has(el)) { const y = scrollOf.get(el); requestAnimationFrame(() => { el.scrollTop = y; }); }
      return el;
    };
    const destroyEl = (el) => {
      try { if (el._live) el._live(); } catch (_) {}
      try { if (el._gone) el._gone(); } catch (_) {}
      try { if (el._link) el._link(); } catch (_) {}
      try { if (el._fv && el._fv.destroy) el._fv.destroy(); } catch (_) {}
    };
    // how many panes show each moment, across EVERY tab of every pane: a tab
    // you are not looking at is still a tab, and its content is still wanted
    const pathCounts = (ps, acc) => {
      const tabs = (ps && ps.tabs) || [];
      tabs.forEach((t) => {
        const e = t && t.cursor >= 0 ? t.entries[t.cursor] : null;
        if (e && e.div) { pathCounts(e.div.a, acc); pathCounts(e.div.b, acc); }
        else if (e && e.pane) pathCounts(e.pane, acc);
        else { const k = (e && e.path) || ''; acc.set(k, (acc.get(k) || 0) + 1); }
      });
      return acc;
    };
    const prune = () => {
      const need = pathCounts(model.serialize(), new Map());
      for (const [path, list] of [...pool]) {
        const want = need.get(path) || 0;
        while (list.length > want) { const el = list.pop(); destroyEl(el); scrollOf.delete(el); }
        if (!list.length) pool.delete(path);
      }
    };
    let drawn = '', drawnBody = '', orphan = null;
    function draw() {
      if (drag) return;                             // a swipe owns the body until it settles
      const spec = model.serialize();
      tree = treeOf(spec);
      // resume where the session says we were, and make that the baseline entry
      // so the first back has somewhere to land instead of leaving the session
      if (!seeded) { seeded = true; seat = (typeof model.seat === 'string' && model.seat) || '.'; }
      // An address names a tab index at every level, so switching an ancestor's
      // tab takes yours out of the tree. Fall back to the nearest surviving
      // ancestor, but REMEMBER where you were: switching that tab back puts
      // you there again instead of leaving you at the top.
      let node = find(tree, seat);
      if (!node) { if (!orphan) orphan = seat; node = nearest(seat); seat = node.addr; }
      else if (orphan) { const back = find(tree, orphan); if (back) { seat = orphan; node = back; } orphan = null; }
      const key = JSON.stringify(spec) + '|' + seat;
      if (key === drawn) return;
      // selecting a pane changes only the cursor: move the mark and redo the
      // bar, and leave the panes standing
      const bodyKey = JSON.stringify(Object.assign({}, spec, { cursor: null, seat: null })) + '|' + seat;
      if (bodyKey === drawnBody && body.firstChild) {
        drawn = key;
        const c = spec && spec.cursor;
        body.querySelectorAll('.mb-leaf[data-addr]').forEach((el) => el.classList.toggle('mb-work', el.dataset.addr === c));
        drawBar(node);
        return;
      }
      drawn = key; drawnBody = bodyKey;
      const cursorAddr = spec && spec.cursor;
      for (const list of pool.values()) for (const el of list) if (el.isConnected) scrollOf.set(el, el.scrollTop);   // a rebuild moves them; keep their place
      claimed = new Set();
      body.textContent = '';
      const h = body.clientHeight || window.innerHeight - 90;
      body.appendChild(levelEl(node, h, cursorAddr, 0, true));        // standing here: the bar at the bottom is this pane's bar
      prune();
      drawBar(node);
      // the grip dims when this level holds one pane: nothing to swipe to
      swipe.classList.toggle('alone', !(node.parent && node.parent.kind === 'div'));
      shapeNav();
      sitHere();
    }
    // the seat rides in the workspace, so a session resumes where you sat. Set
    // it where the draw settles, and tell the session to save when it moved.
    const sitHere = () => {
      if (model.seat === seat) return;
      model.seat = seat;
      try { model.dispatchEvent(new CustomEvent('gmux-change')); } catch (_) {}
    };
    let pending = null;
    const schedule = () => { if (pending) return; pending = setTimeout(() => { pending = null; draw(); }, 0); };
    const redraw = () => { drawn = ''; drawnBody = ''; draw(); };

    function drawBar(node) {
      bar.textContent = ''; pathRow.textContent = ''; tabRow.textContent = '';
      const ask = bars.querySelector('.mb-confirm'); if (ask) ask.remove();
      tabRow.style.display = 'none';                                  // tabs belong to the pane's own strip, not down here
      const b = (glyph, title, on, fn, cls) => { const x = document.createElement('button'); x.textContent = glyph; x.title = title; if (cls) x.className = cls; x.disabled = !on; if (on) x.addEventListener('click', fn); return x; };
      const up = node.parent, tab = node.tab || { entries: [], cursor: -1 };
      const canBack = tab.cursor > 0, canFwd = tab.cursor >= 0 && tab.cursor < tab.entries.length - 1;
      bar.append(
        b('▲', 'climb out', !!up, () => goTo(up.addr)),
        b('◀', 'back', canBack, () => withCursor(() => { model.back(model.cursor && model.cursor.id); redraw(); })),
        b('▶', 'forward', canFwd, () => withCursor(() => { model.forward(model.cursor && model.cursor.id); redraw(); })),
        b('↻', 'load this again', true, () => refreshAt(node)));
      // the two sides of the division this pane sits in; swipe moves between
      // them, and the dots say which one you are on
      const dots = document.createElement('div'); dots.className = 'mb-dots';
      if (up && up.kind === 'div') for (const k of up.kids) {
        const d = document.createElement('button'); d.title = k.slot === 'a' ? 'the left or top pane' : 'the right or bottom pane';
        if (k === node) d.classList.add('on'); else d.addEventListener('click', () => goTo(k.addr));
        dots.appendChild(d);
      } else {
        // no sibling: ONE dot, and you are on it. The dots count what is at
        // this level and mark where you are, so they never vanish and come
        // back as you climb.
        const d = document.createElement('button'); d.className = 'on'; d.title = 'this level holds one pane';   // not disabled: the bar fades a disabled button
        dots.appendChild(d);
      }
      bar.appendChild(dots);
      bar.appendChild(Object.assign(document.createElement('div'), { className: 'mb-gap' }));
      // flip swaps the two panes you are LOOKING AT: the children of the
      // container you are in, or, standing on a leaf, it and its sibling
      const flipAt = node.kind === 'div' ? (node.kids[0] && node.kids[0].addr) : (up && up.kind === 'div' ? node.addr : null);
      bar.append(
        // the aperture STAYS on the pane that was split, which now holds the
        // division: you watch it become two and then dive into one
        b('⬓', 'split this pane in two', true, () => withCursor(() => { model.splitDown(); redraw(); })),
        b('⇄', 'flip the two panes here', !!flipAt, () => {
          const inner = node.kind === 'div';
          if (model.cursorToAddr(flipAt) && model.flip()) { if (!inner) seat = model.cursorAddr() || seat; redraw(); }
        }),
        b('×', 'close this pane', true, () => askClose(node), 'danger'));
      // the path this pane shows, editable; a container takes one too, and
      // back brings the division it was holding straight back
      // a container shows the path of the LAYOUT it is holding, exactly as the
      // desktop navbar does: a layout is a moment, so @clanker stays @clanker
      const shown = node.kind === 'leaf' ? node.path : srcOf(node);
      const kind = document.createElement('span'); kind.className = 'mb-kind';
      const inp = document.createElement('input'); inp.className = 'mb-path'; inp.type = 'text'; inp.spellcheck = false;
      inp.value = shown ? psNs(shown) : '';
      inp.placeholder = node.kind === 'leaf' ? 'path…' : 'layout';
      inp.addEventListener('keydown', (e) => { e.stopPropagation(); if (e.key === 'Enter') { const v = inp.value.trim(); if (v) navTo(v); inp.blur(); } });
      const tabs = document.createElement('button'); tabs.className = 'mb-tabs';
      tabs.title = node.tabs.length + ' tab' + (node.tabs.length === 1 ? '' : 's') + ' in this pane';
      tabs.append(Object.assign(document.createElement('span'), { textContent: '⧉' }), document.createTextNode(String(node.tabs.length)));
      tabs.addEventListener('click', () => openTabs(node));
      pathRow.append(kind, inp, tabs);
    }
    // a pane showing nothing has nothing to lose: it closes on the tap, the
    // way gmux closes an empty one without arming the ask
    const isEmpty = (n) => n.kind === 'leaf' && !n.tabs.some((t) => t.cursor >= 0);
    function closeNode(node) {
      if (!model.cursorToAddr(node.addr)) return;
      model.closeLeaf(model.cursor && model.cursor.id, true);
      seat = model.cursorAddr() || '.';
      redraw();
    }
    // closing a pane with content is asked for first: gmux asks with Enter,
    // which a phone has no way to send, so the ask lives here and the close
    // is forced
    function askClose(node) {
      if (isEmpty(node)) { closeNode(node); return; }
      const old = bars.querySelector('.mb-confirm'); if (old) old.remove();
      const c = document.createElement('div'); c.className = 'mb-confirm';
      const t = document.createElement('div'); t.className = 't';
      t.textContent = node.kind === 'leaf' ? 'Close this pane?' : 'Close this pane and all its descendants?';
      const no = document.createElement('button'); no.textContent = 'cancel';
      no.addEventListener('click', () => c.remove());
      const yes = document.createElement('button'); yes.className = 'danger'; yes.textContent = 'close';
      yes.addEventListener('click', () => { c.remove(); closeNode(node); });
      c.append(t, no, yes);
      bars.insertBefore(c, bar);
    }
    // every tab of this pane as a card, each drawn by the same renderer at the
    // card's size: a tab holding a split looks like a split, a leaf like its
    // content's rung. Tapping one selects it, × closes it, + opens another.
    function openTabs(node) {
      const sheet = document.createElement('div'); sheet.className = 'mb-sheet';
      const head = document.createElement('div'); head.className = 'mb-sheet-head';
      const title = document.createElement('div'); title.className = 't';
      title.textContent = node.tabs.length + ' tab' + (node.tabs.length === 1 ? '' : 's');
      head.append(title);                                              // no done, no second +: tap a tab to go to it
      const grid = document.createElement('div'); grid.className = 'mb-grid';
      node.tabs.forEach((t, i) => {
        const preview = mkNode(Object.assign({}, node.spec, { activeTab: i }), node.addr, node.parent, node.slot);
        const card = document.createElement('div'); card.className = 'mb-card' + (i === (node.spec.activeTab || 0) ? ' on' : '');
        const shot = document.createElement('div'); shot.className = 'shot';
        shot.appendChild(levelEl(preview, 150, null, 0, false));
        const cap = document.createElement('div'); cap.className = 'cap';
        const dot = document.createElement('span'); dot.className = 'mb-kind';
        const label = document.createElement('span'); label.className = 't';
        label.textContent = t.label || labelOf(preview);
        cap.append(dot, label);
        const x = document.createElement('button'); x.className = 'x'; x.textContent = '×'; x.title = 'close this tab';
        x.addEventListener('click', (e) => {
          e.stopPropagation();
          if (!model.cursorToAddr(node.addr)) return;
          model.closeTab(model.cursor && model.cursor.id, i);
          sheet.remove(); redraw();
          const again = find(tree, node.addr);                  // stay in the grid, one card fewer
          if (again) openTabs(again);
        });
        card.append(x, shot, cap);
        card.addEventListener('click', () => { if (model.cursorToAddr(node.addr)) { model.selectTab(model.cursor && model.cursor.id, i); sheet.remove(); redraw(); } });
        grid.appendChild(card);
      });
      const more = document.createElement('div'); more.className = 'mb-newtab'; more.textContent = '+ new tab';
      more.addEventListener('click', () => { if (model.cursorToAddr(node.addr)) { model.newTab(model.cursor && model.cursor.id, '/'); sheet.remove(); redraw(); } });
      grid.appendChild(more);
      sheet.append(head, grid);
      sheet.addEventListener('click', (e) => { if (e.target === sheet || e.target === grid) sheet.remove(); });   // tap past the cards to back out
      root.appendChild(sheet);                                       // over everything, and not wiped by a redraw of the body
    }
    // drop this pane's cached content (and anything under it) and build again
    function refreshAt(node) {
      const drop = (n) => { if (n.kind === 'leaf') { const l = pool.get(n.path || ''); if (l) { l.forEach((el) => { destroyEl(el); scrollOf.delete(el); }); pool.delete(n.path || ''); } } n.kids.forEach(drop); };
      drop(node);
      redraw();
    }
    // actions BORROW the model's cursor for the length of the call — gmux acts
    // on a cursor — but nothing persists it: walking never selects.
    const withCursor = (fn) => { if (model.cursorToAddr(seat)) fn(); };
    // Walking in pushes a history entry, so the back gesture climbs back out
    // instead of abandoning the session — and the Android edge-swipe, which no
    // page can intercept, becomes the right gesture rather than a hazard. The
    // position rides in history.state, NOT in the URL: the session's own state
    // stays the system of record and the link stays clean.
    function goTo(addr) {
      orphan = null; seat = addr;
      redraw();                                          // draw re-shapes the history for where we land
    }
    // Back/forward are NEUTRALISED. On a phone they cannot be prevented — the
    // edge-swipe is the system's and Chrome navigates on horizontal overscroll
    // — and while they were real navigation a stray one yanked the seat to an
    // older entry mid-gesture, which is the jumping that made the dots change
    // under you. So one spare entry is kept behind us and any pop is answered
    // by stepping back onto it: the gesture becomes inert instead of wrong.
    // Moving between the pair is the swipe strip's job, which does it with
    // direction and an animation. Climbing out is the ⬆ button.
    let navFix = false;
    const shapeNav = () => {
      if (navFix) return;
      try { if ((history.state || {}).nav !== 'here') history.pushState({ nav: 'here' }, ''); } catch (_) {}
    };
    window.addEventListener('popstate', () => {
      if (navFix) { navFix = false; return; }
      navFix = true;
      try { history.pushState({ nav: 'here' }, ''); } catch (_) {}      // step back onto our own entry
      navFix = false;
    });
    function routeOpen(addr, path, name) {
      if (!model.cursorToAddr(addr)) return;
      // spell the destination the way the pane that opened it is spelled, so
      // walking down from @clanker stays under @clanker instead of turning
      // into the place the name resolves to
      const from = find(tree, addr);
      const here = from && from.path ? psNs(from.path) : null;
      const to = here ? psMoment(psRel(here, path)) : path;
      model.openFrom(model.cursor && model.cursor.id, to, name);
      // gmux SELECTS what it opened. A link in a sidebar lands in the pane the
      // layout routes it to, and that pane is usually already on screen beside
      // the sidebar, so the aperture stays put and the mark moves. Only when
      // the destination is somewhere you cannot see from here do you follow it.
      const dest = model.cursorAddr();
      const seen = find(treeOf(model.serialize()), seat);
      if (dest && !(seen && holds(seen, dest))) seat = dest;
      redraw();
    }
    function navTo(path) { withCursor(() => { model.navigate(null, path); redraw(); }); }

    // ---- gestures: a swipe is lateral, between the two sides of a division ----
    // Judging the gesture at its END is too late on a phone: `touch-action:
    // pan-y` lets the browser claim it for a vertical scroll the moment the
    // finger drifts, and it then fires pointercancel — the swipe is simply
    // lost, which is why it only ever worked on content too short to scroll.
    // So claim it as soon as it reads horizontal: preventDefault() in
    // touchmove stops the browser starting a scroll, and takes Chrome's
    // horizontal overscroll back/forward navigation out of the running too.
    // The gesture is PHYSICAL: the content follows your finger. Dragging left
    // pulls the right/bottom side in from the right; dragging right pulls the
    // left/top side in. Both levels ride a track that tracks the finger, so you
    // are grabbing the screen and pulling the other one through — released past
    // a quarter width it carries on and commits, short of that it springs back.
    const SWIPE_MIN = 10;                                  // px before we claim the gesture
    // Gestures belong to content that asks for them, the same way menus do. A
    // rendering declares the axes it pans with data-pan ("x", "y", "xy") on
    // itself or any ancestor inside the body, and the swipe will not claim an
    // axis the content owns — a map takes both, and you change panes with the
    // dots instead. This has to be a DECLARATION rather than an event: the
    // claim happens before the browser commits the gesture, so there is no
    // waiting to see whether the content handled it.
    const ownsAxis = (t, axis) => {
      for (let n = t; n && n !== body; n = n.parentElement) {
        const v = n.dataset && n.dataset.pan;
        if (v) return v === 'xy' || v.indexOf(axis) >= 0;
      }
      return false;
    };
    const destFor = (dx) => {
      const node = find(tree, seat); if (!node) return null;
      return sibling(node, dx < 0 ? 'b' : 'a');            // left → the side to your right
    };
    const beginDrag = (dx) => {
      const node = find(tree, seat); if (!node) return null;
      const dest = destFor(dx); if (!dest) return null;
      const w = body.clientWidth; if (!w) return null;
      const h = body.clientHeight || window.innerHeight - 90;
      const cursorAddr = (model.serialize() || {}).cursor;
      const cell = (el) => { const c = document.createElement('div'); c.style.cssText = 'flex:0 0 ' + w + 'px;width:' + w + 'px;height:100%;position:relative'; c.appendChild(el); return c; };
      const cur = cell(levelEl(node, h, cursorAddr, 0, true));
      const nxt = cell(levelEl(dest, h, cursorAddr, 0, true));
      const destIsRight = dx < 0;
      const track = document.createElement('div');
      track.style.cssText = 'position:absolute;top:0;left:0;height:100%;display:flex;width:' + (2 * w) + 'px;will-change:transform';
      track.append(destIsRight ? cur : nxt, destIsRight ? nxt : cur);
      const base = destIsRight ? 0 : -w;                   // keep the pane you are on in view
      track.style.transform = 'translateX(' + base + 'px)';
      body.textContent = '';
      body.appendChild(track);
      return { dest, track, w, base, destIsRight, t0: Date.now() };
    };
    const dragMove = (dx) => {
      if (!drag) return;
      const lim = drag.destIsRight ? Math.min(0, dx) : Math.max(0, dx);   // no rubber-banding past the edge
      drag.track.style.transform = 'translateX(' + (drag.base + lim) + 'px)';
    };
    const dragEnd = (dx) => {
      const d = drag; if (!d) return;
      // A flick counts as much as a haul. Distance alone wanted a quarter of
      // the pane — about a hundred px across a strip a couple of fingers tall —
      // so an ordinary quick swipe sprang back and you had to do it twice.
      // Either travelling far enough OR moving fast enough carries it over.
      const dt = Math.max(1, Date.now() - d.t0);
      const speed = Math.abs(dx) / dt;                     // px per ms
      const past = Math.abs(dx) > d.w * 0.12 || speed > 0.3;
      const to = past ? (d.destIsRight ? d.base - d.w : d.base + d.w) : d.base;
      let done = false;
      const finish = () => {
        if (done) return; done = true;
        drag = null;
        if (!past) { redraw(); return; }
        // Ask what is beside me NOW, rather than trusting the address taken when
        // the finger went down: an address names a tab index at every level, so
        // a workspace that moved mid-swipe (a streaming log, a pane closing)
        // leaves that address pointing elsewhere — and committing it drops the
        // seat somewhere unrelated, which shows up as the level's dots changing
        // under you.
        const fresh = find(treeOf(model.serialize()), seat);
        const to = fresh && sibling(fresh, d.destIsRight ? 'b' : 'a');
        if (to) goTo(to.addr); else redraw();
      };
      d.track.addEventListener('transitionend', finish, { once: true });
      setTimeout(finish, 320);                             // transitionend can be skipped if nothing moves
      d.track.style.transition = 'transform ' + (speed > 0.6 ? '.13s' : '.2s') + ' cubic-bezier(.22,.61,.36,1)';
      requestAnimationFrame(() => { d.track.style.transform = 'translateX(' + to + 'px)'; });
    };
    let sx = 0, sy = 0, swiping = false, touching = false, tracking = false;
    swipe.addEventListener('touchstart', (e) => {
      if (drag || e.touches.length !== 1) { touching = false; return; }   // a pinch is not a swipe
      const t = e.touches[0]; sx = t.clientX; sy = t.clientY; swiping = false; touching = true;
    }, { passive: true });
    swipe.addEventListener('touchmove', (e) => {
      if (!touching || e.touches.length !== 1) return;
      const t = e.touches[0], dx = t.clientX - sx, dy = t.clientY - sy;
      if (!swiping && Math.abs(dx) > SWIPE_MIN && Math.abs(dx) > Math.abs(dy)) {
        swiping = true;
        drag = beginDrag(dx);                              // no sibling that way → nothing to drag
        if (!drag) touching = false;
      }
      if (swiping) { e.preventDefault(); dragMove(dx); }   // the gesture is ours: no scroll, no back-swipe
    }, { passive: false });
    swipe.addEventListener('touchend', (e) => {
      if (!touching) return;
      touching = false;
      if (!swiping) return;
      swiping = false;
      const t = e.changedTouches && e.changedTouches[0];
      dragEnd(t ? t.clientX - sx : 0);
    });
    swipe.addEventListener('touchcancel', () => { touching = false; swiping = false; if (drag) dragEnd(0); });
    // mouse / trackpad: same physics, nothing competing for the gesture
    swipe.addEventListener('pointerdown', (e) => { if (e.pointerType === 'touch' || drag) return; sx = e.clientX; sy = e.clientY; tracking = true; });
    swipe.addEventListener('pointermove', (e) => {
      if (e.pointerType === 'touch' || !tracking) return;
      const dx = e.clientX - sx, dy = e.clientY - sy;
      if (!drag && Math.abs(dx) > SWIPE_MIN && Math.abs(dx) > Math.abs(dy)) { drag = beginDrag(dx); if (!drag) tracking = false; }
      if (drag) dragMove(dx);
    });
    swipe.addEventListener('pointerup', (e) => {
      if (e.pointerType === 'touch' || !tracking) return;
      tracking = false;
      if (drag) dragEnd(e.clientX - sx);
    });
    swipe.addEventListener('pointercancel', () => { tracking = false; if (drag) dragEnd(0); });

    model.addEventListener('gmux-change', schedule);
    // Android fires `resize` when the soft keyboard opens, because the viewport
    // height shrinks. A redraw rebuilds the bars from scratch, which destroys
    // the very input you just focused — the keyboard appears and instantly
    // closes again. Only a WIDTH change is a relayout we care about (rotation,
    // a resized window); a height-only change is the keyboard, so leave it be.
    let lastW = window.innerWidth;
    window.addEventListener('resize', () => {
      const w = window.innerWidth;
      if (w === lastW) return;
      lastW = w;
      redraw();
    });
    sessionClient(model, root, sessionName, redraw).attach();
  }
  if (opts.panes) {
    // /grubbery/explorer: the SESSIONS page — the workspaces the ship holds,
    // open one (attaching this tab to it, taking it over from another), or
    // start one. /grubbery/explorer/s/<name>: attached to that session.
    // Any other /grubbery/explorer/<path>: a workspace kept in this browser
    // alone (localStorage), as before — the old standalone page.
    while (root.firstChild) root.removeChild(root.firstChild);
    root.style.cssText = 'display:block;height:100vh;height:100dvh';
    document.body.classList.add('cols');
    const here = location.pathname.replace(/\/+$/, '');
    const sm = here.match(/^\/grubbery\/explorer\/s\/([a-z][a-z0-9-]*)$/);
    const sessionName = sm ? sm[1] : null;
    if (!sessionName && here === '/grubbery/explorer') { sessionsPage(root, SESSION_API, psWait, psWaitFail); return; }
    // A phone walks the palace instead of tiling it. What makes it a phone is
    // the POINTER, not the width: a finger cannot hit a pane bar or drag a
    // divider at any size, a phone held sideways is wider than plenty of
    // desktop windows, and one asked to "request desktop site" reports a
    // width it does not have. A touchscreen laptop keeps its mouse, so it
    // keeps the tiled client. A narrow window still gets the phone client so
    // it can be worked on from a desktop, and ?m=1 / ?m=0 force either way.
    // "Request desktop site" defeats BOTH of those: it reports a fine pointer
    // AND a ~980px viewport, so a real phone reads as a desktop. What it does
    // not fake is the hardware — maxTouchPoints is a device capability, and
    // screen.width is the physical screen rather than the layout viewport. A
    // touch device whose SCREEN is phone-sized is a phone whatever it claims,
    // while a touchscreen laptop still has a big screen and keeps the tiling.
    const mq = (q) => { try { return window.matchMedia(q).matches; } catch (_) { return false; } };
    const finger = mq('(pointer: coarse)') && !mq('(any-pointer: fine)');
    const touch = (navigator.maxTouchPoints || 0) > 0;
    const smallScreen = ((window.screen && window.screen.width) || 9999) <= 900;
    const MOBILE = /[?&]m=1/.test(location.search) || (!/[?&]m=0/.test(location.search) && (finger || mq('(max-width: 720px)') || (touch && smallScreen)));
    // ?diag=1: what THIS device actually reports, so a phone that picks the
    // wrong client can say why without anyone guessing at its media queries.
    if (/[?&]diag=1/.test(location.search)) {
      const pre = document.createElement('pre');
      pre.style.cssText = 'margin:0;padding:16px;font:13px/1.6 ui-monospace,SFMono-Regular,Menlo,monospace;white-space:pre-wrap;word-break:break-all';
      pre.textContent = JSON.stringify({
        decision: MOBILE ? 'PHONE client' : 'TILED client',
        sessionName, finger, touch, smallScreen,
        pointerCoarse: mq('(pointer: coarse)'), anyPointerFine: mq('(any-pointer: fine)'),
        maxWidth720: mq('(max-width: 720px)'),
        innerWidth: window.innerWidth, screenWidth: window.screen && window.screen.width,
        devicePixelRatio: window.devicePixelRatio, maxTouchPoints: navigator.maxTouchPoints,
        ua: navigator.userAgent,
      }, null, 2);
      root.appendChild(pre);
      return;
    }
    if (sessionName && MOBILE) { mobileWorkspace(root, sessionName); return; }
    const persistKey = sessionName ? null : K + '-standalone';
    const ps = document.createElement('gmux-host');
    if (persistKey) ps.setAttribute('persist', persistKey);
    ps.style.cssText = 'display:block;height:100%';
    ps.renderPath = (path, paneId) => paneContent(ps, paneId, path);
    ps.tabInfo = paneTabInfo;
    ps.pathHint = (p) => { const ns = psNs(p); return psLink(ns) ? (psResolved.get(ns) || 'resolving ' + ns) : ''; };   // an @name moment's tooltip: where it landed
    // the same path with new ?args: a viewer that takes args (onArgs on what
    // mount returned) is handed them and stays mounted, so a docs pane turns
    // the page without a remount, a wait block, or a refetch of its nav.
    // Anything else (another path, a built-in rendering, an action view, a
    // viewer without onArgs) is rebuilt as before.
    ps.reloadLayout = (id, src) => psReloadLayout(ps, id, src);           // ↻ on a layout pane re-reads its file
    ps.updateContent = (el, path) => {
      if (!el || el._dead || !el._fv || typeof el._fv.onArgs !== 'function') return false;
      if (psNs(el._moment || '') !== psNs(path)) return false;
      el._moment = path;
      el._fv.onArgs(psArgs(path));
      return true;
    };
    ps.viewModes = [{ id: 'rendered', glyph: '▣', title: 'rendered' }, { id: 'raw', glyph: '◰', title: 'raw file / plain listing' }];
    ps.onDestroy = (id, body) => { const c = body.firstChild; try { if (c && c._live) c._live(); } catch (_) {} try { if (c && c._gone) c._gone(); } catch (_) {} try { if (c && c._link) c._link(); } catch (_) {} try { if (c && c._fv) c._fv.destroy(); } catch (_) {} };
    root.appendChild(ps);
    // right-click: the rendering under the cursor answers (a viewer's
    // contextMenu, a built-in's _menu); nothing to say → the browser's own
    // menu. Capture, so the finder's handler never sees workspace clicks.
    root.addEventListener('contextmenu', (e) => {
      e.stopPropagation();
      if (e.target.closest('.ps-bar, drop-menu, .ps-form')) return;
      const body = e.target.closest('.ps-pane-body'); const el = body && body.firstChild;
      if (!el) return;
      let items = null;
      try {
        if (el._fv && typeof el._fv.contextMenu === 'function') items = el._fv.contextMenu(e);
        else if (typeof el._menu === 'function') items = el._menu(e);
        // a rendering with no menu of its own, whose rows still say what they
        // are (__item): the item's actions, or its dir's on whitespace
        if (!items || !items.length) { const hit = e.composedPath().find((x) => x && x.__item); if (hit) items = itemMenu(el, hit.__item); else if (el._dirUrl) items = dirMenu(el, el._dirUrl); }
      } catch (_) { items = null; }
      if (!items || !items.length) return;
      e.preventDefault();
      showMenu(items, e.clientX, e.clientY);
    }, true);
    if (!sessionName) {
      let saved = null; try { saved = localStorage.getItem('gmux:' + K + '-standalone') || localStorage.getItem('pane-split:' + K + '-standalone'); } catch (_) {}
      if (!saved) ps.open('/', 'here');                 // fresh → root; otherwise the persisted workspace restores (stateful)
      ps.layoutSources().forEach(({ id, src }) => psFollowLayout(ps, id, src));   // restored layout panes follow their files again
      psSnaps(ps);
      return;
    }
    // ---- a session: this tab is its one client ----
    document.title = sessionName + ' · gmux';
    psSnaps(ps);
    sessionClient(ps, root, sessionName, () => ps.layoutSources().forEach(({ id, src }) => psFollowLayout(ps, id, src))).attach();
    return;
  }
  load();
}

// the sessions page (/grubbery/explorer): the workspaces the ship holds.
// Each row: name, who holds it (a client attached, since when) or free, when
// it last changed; open attaches this tab (taking over). The list scrolls;
// the new-session form stays put. New: a name, and either an empty
// workspace or a layout file to start from.
function sessionsPage(root, api, wait, waitFail) {
  const css = document.createElement('style');
  css.textContent = '.ss-wrap{max-width:720px;margin:0 auto;padding:40px 24px 24px;height:100%;box-sizing:border-box;display:flex;flex-direction:column;font:14px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:#1f2328}' +
    '.ss-wrap h1{font-size:20px;font-weight:600;margin:0 0 4px}.ss-sub{color:#57606a;margin:0 0 24px}' +
    '.ss-list{border:1px solid #d0d7de;border-radius:8px;overflow:auto;margin-bottom:28px;flex:0 1 auto;min-height:0}.ss-list.loading{border-color:transparent;min-height:96px}.ss-row,.ss-row:hover,.ss-row *{text-decoration:none}.ss-row{display:flex;align-items:center;gap:14px;padding:12px 16px;border-top:1px solid #d0d7de;color:inherit}.ss-row:first-child{border-top:0}.ss-row:hover{background:#f6f8fa}' +
    '.ss-name{font:600 14px ui-monospace,Menlo,monospace;min-width:140px;overflow-wrap:anywhere}.ss-meta{color:#57606a;flex:1;min-width:0}.ss-held{color:#9a6700}.ss-free{color:#1a7f37}.ss-del{border:0;background:none;color:#8c959f;cursor:pointer;font-size:16px;padding:0 4px}.ss-del:hover{color:#cf222e}' +
    '.ss-empty{padding:20px 16px;color:#57606a}' +
    '.ss-new{border:1px solid #d0d7de;border-radius:8px;padding:16px;flex:0 0 auto}.ss-hint{color:#57606a;font-size:13px;margin:0 0 10px}.ss-hint code{font:12px ui-monospace,Menlo,monospace;background:#f6f8fa;padding:1px 5px;border-radius:4px;overflow-wrap:anywhere}.ss-new h2{font-size:14px;font-weight:600;margin:0 0 12px}.ss-new label{display:flex;gap:10px;align-items:center;margin:10px 0 2px}.ss-new label span{min-width:90px;color:#57606a}.ss-new input[type=text]{flex:1;font:13px ui-monospace,Menlo,monospace;padding:6px 8px;border:1px solid #d0d7de;border-radius:6px}.ss-help{margin:0 0 6px 100px;color:#57606a;font-size:12px}' +
    '.ss-new button{font:inherit;font-weight:600;padding:6px 14px;border-radius:6px;border:1px solid #1f883d;background:#2da44e;color:#fff;cursor:pointer;margin-top:12px}.ss-err{color:#cf222e;margin-top:8px}' +
    // a phone: the page is the same page, with the room it actually has. The
    // label column and the indent under it are desktop furniture, so a field
    // becomes a label above its input, and everything a finger hits grows.
    '@media (max-width:560px){' +
      '.ss-wrap{padding:20px 14px 14px}' +
      '.ss-sub{margin-bottom:18px}' +
      '.ss-list{margin-bottom:20px}' +
      '.ss-row{flex-wrap:wrap;gap:4px 10px;padding:14px}' +
      '.ss-name{min-width:0;flex:1 1 100%}' +
      '.ss-meta{flex:1 1 auto;font-size:13px}' +
      '.ss-del{padding:4px 8px;font-size:18px}' +
      '.ss-new label{flex-direction:column;align-items:stretch;gap:5px}' +
      '.ss-new label span{min-width:0}' +
      '.ss-new input[type=text]{width:100%;font-size:16px;padding:9px 10px}' +   // 16px: iOS zooms a smaller field on focus
      '.ss-help{margin-left:0}' +
      '.ss-new button{width:100%;padding:11px 14px;font-size:15px}' +
    '}';
  document.head.appendChild(css);
  root.style.cssText = 'display:block;height:100vh;height:100dvh;overflow:hidden;background:#fff';
  const wrap = document.createElement('div'); wrap.className = 'ss-wrap'; root.appendChild(wrap);
  const h1 = document.createElement('h1'); h1.textContent = 'gmux sessions'; wrap.appendChild(h1);
  const sub = document.createElement('p'); sub.className = 'ss-sub'; sub.textContent = 'A workspace the ship keeps. One tab holds a session at a time; opening it here takes it over.'; wrap.appendChild(sub);
  const list = document.createElement('div'); list.className = 'ss-list'; wrap.appendChild(list);
  const when = (ms) => { if (!ms) return ''; const d = new Date(ms); const today = new Date(); return d.toDateString() === today.toDateString() ? d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : d.toLocaleDateString(); };
  let known = [];                                                  // the names in the list, for a default that is new
  // ?m=1 / ?m=0 forces which client a session opens in; carry it through, so
  // trying the phone client from a desktop survives opening a session
  const force = /[?&]m=[01]/.test(location.search) ? ('?m=' + (/[?&]m=1/.test(location.search) ? '1' : '0')) : '';
  const load = async () => {
    list.textContent = ''; list.classList.add('loading');
    const w = document.createElement('div'); list.appendChild(w); wait(w, 'loading sessions'); w.style.cssText = 'height:96px';
    let rows = [], failed = false;
    try { const r = await fetch(api, { cache: 'no-store' }); if (!r.ok) throw new Error(r.status); const j = await r.json(); rows = Array.isArray(j.sessions) ? j.sessions : []; } catch (e) { failed = true; }
    if (failed) { waitFail(w, 'could not list sessions', api); w.style.cssText = 'height:96px'; return; }
    list.textContent = ''; list.classList.remove('loading');
    known = rows.map((r) => r.name);
    rows.sort((a, b) => (b.updated || 0) - (a.updated || 0));
    if (!rows.length) { const e = document.createElement('div'); e.className = 'ss-empty'; e.textContent = 'No sessions yet. Start one below.'; list.appendChild(e); return; }
    for (const s of rows) {
      const a = document.createElement('a'); a.className = 'ss-row'; a.href = '/grubbery/explorer/s/' + encodeURIComponent(s.name) + force;
      const n = document.createElement('div'); n.className = 'ss-name'; n.textContent = s.name;
      const m = document.createElement('div'); m.className = 'ss-meta';
      const held = s.client && s.client.id;
      const st = document.createElement('span'); st.className = held ? 'ss-held' : 'ss-free'; st.textContent = held ? 'held since ' + when(s.client.since) : 'free';
      m.appendChild(st);
      if (s.updated) m.appendChild(document.createTextNode(' · changed ' + when(s.updated)));
      if (s.layout) m.appendChild(document.createTextNode(' · from ' + s.layout));
      const del = document.createElement('button'); del.className = 'ss-del'; del.title = 'delete this session'; del.textContent = '×';
      del.addEventListener('click', async (e) => { e.preventDefault(); e.stopPropagation(); if (del.dataset.armed) { await fetch(api, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ name: s.name, delete: true }) }); load(); } else { del.dataset.armed = '1'; del.textContent = 'delete?'; setTimeout(() => { delete del.dataset.armed; del.textContent = '×'; }, 2500); } });
      a.append(n, m, del); list.appendChild(a);
    }
  };
  const form = document.createElement('div'); form.className = 'ss-new'; wrap.appendChild(form);
  const h2 = document.createElement('h2'); h2.textContent = 'New session'; form.appendChild(h2);
  const code = (t) => { const c = document.createElement('code'); c.textContent = t; return c; };
  const field = (label, ...help) => { const l = document.createElement('label'); const sp = document.createElement('span'); sp.textContent = label; const i = document.createElement('input'); i.type = 'text'; i.spellcheck = false; l.append(sp, i); form.appendChild(l); const h = document.createElement('div'); h.className = 'ss-help ss-hint'; h.append(...help); form.appendChild(h); return i; };
  const name = field('name', 'One word: lowercase letters, digits, dashes. Empty picks one.');
  name.placeholder = 'main';
  const layout = field('layout', 'Optional. A ', code('.layout'), ' file in the namespace to start from, such as ', code('/apps/forge.git_forge/ui/forge.layout'), '. Empty starts at the root.');
  const go = document.createElement('button'); go.textContent = 'start'; form.appendChild(go);
  const err = document.createElement('div'); err.className = 'ss-err'; form.appendChild(err);
  const start = async () => {
    err.textContent = '';
    let n = name.value.trim();
    if (!n) { n = 'main'; for (let i = 2; known.includes(n); i++) n = 'main-' + i; }   // just "start": the first free name
    if (!/^[a-z][a-z0-9-]*$/.test(n)) { err.textContent = 'a session name is lowercase letters, digits and dashes'; name.focus(); return; }
    const body = { name: n, create: true };
    const lay = layout.value.trim(); if (lay) body.layout = lay;
    go.disabled = true;
    try {
      const r = await fetch(api, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) });
      if (!r.ok) { let why = 'could not create (' + r.status + ')'; try { why = (await r.json()).error || why; } catch (_) {} throw new Error(why); }
      location.href = '/grubbery/explorer/s/' + encodeURIComponent(n) + force;
    } catch (e) { err.textContent = e && e.message || String(e); go.disabled = false; }
  };
  go.addEventListener('click', start);
  [name, layout].forEach((i) => i.addEventListener('keydown', (e) => { if (e.key === 'Enter') start(); }));
  load();
  name.focus();
}

// the component. mount() builds the explorer's markup inside the element (light
// DOM) and wires it; the stylesheet goes into <head> once per document.
const EXPLORER_CSS = `/* the explorer's own look. body > #bar in the page became namespace-explorer > #bar:
   the mounted FileView (light DOM) has its OWN #bar / #crumbs / #status
   inside a tab, and an unscoped rule made its bar sticky + z-indexed too. */
namespace-explorer { display: block; }
namespace-explorer.cols { display: flex; flex-direction: column; height: 100%; min-height: 0; }
namespace-explorer modal-dialog:not(:defined), namespace-explorer drop-menu:not(:defined), namespace-explorer file-grid:not(:defined) { display: none; }
namespace-explorer > #bar { position: sticky; top: 0; height: 38px; flex: none; display: flex; align-items: center; gap: 8px; padding: 0 14px; background: #f6f8fa; border-bottom: 1px solid #d0d7de; z-index: 20; min-width: max-content; }
namespace-explorer > #bar > #crumbs { display: flex; align-items: center; gap: 2px; font: 600 13px ui-monospace, SFMono-Regular, Menlo, monospace; }
namespace-explorer > #bar > #crumbs a { color: #57606a; padding: 2px 4px; border-radius: 5px; }
namespace-explorer > #bar > #crumbs a:hover { color: #24292f; background: #eaeef2; text-decoration: none; }
namespace-explorer > #bar > #crumbs .here { color: #24292f; padding: 2px 4px; }
namespace-explorer .grow { flex: 1; }
namespace-explorer #chips { display: inline-flex; align-items: center; gap: 7px; }
namespace-explorer .chip { display: inline-flex; align-items: center; gap: 5px; background: #eef1f4; border: 1px solid #e2e7ee; border-radius: 6px; padding: 2px 8px; white-space: nowrap; }
namespace-explorer .chip.click { cursor: pointer; }
namespace-explorer .chip.click:hover { border-color: #d0d7de; background: #e2e7ee; }
namespace-explorer .chip.locked { cursor: not-allowed; }
namespace-explorer .chip .k { font-size: 10px; text-transform: uppercase; letter-spacing: .05em; color: #8b949e; }
namespace-explorer .chip .v { font: 11px ui-monospace, SFMono-Regular, Menlo, monospace; color: #24292f; }
namespace-explorer .chip .v a { font: inherit; }
namespace-explorer .chip.warn .v { color: #bc4c00; font-weight: 600; }
namespace-explorer > #bar button:not(.mi), namespace-explorer .btn { all: unset; cursor: pointer; padding: 4px 12px; border-radius: 7px; font-size: 12px; color: #24292f; border: 1px solid #d0d7de; background: #fff; }
namespace-explorer > #bar button:not(.mi):hover, namespace-explorer .btn:hover { background: #f6f8fa; }

namespace-explorer #bang { margin: 12px 20px; padding: 10px 14px; background: #fff8f8; border: 1px solid #ffcecb; border-radius: 8px; cursor: pointer; color: #cf222e; }
namespace-explorer #bang:hover { background: #ffebe9; }
namespace-explorer .dload { display: inline-block; animation: dpulse 1.1s ease-in-out infinite; }
@keyframes dpulse { 50% { opacity: .2; } }
namespace-explorer > #status { position: fixed; bottom: 14px; left: 50%; transform: translateX(-50%); background: #24292f; color: #fff; font-size: 12px; padding: 7px 16px; border-radius: 8px; box-shadow: 0 8px 24px rgba(31,35,40,.25); display: none; max-width: 70vw; white-space: pre-wrap; z-index: 50; }
namespace-explorer > #status.err { background: #cf222e; }

namespace-explorer file-table { margin: 0 20px; --ft-header-top: auto; }
namespace-explorer file-table:not(:defined) { display: none; }
/* the list-view table keeps its intrinsic width (page scrolls for it); the
   element itself does NOT, so the finder's editor content can't inflate it */
namespace-explorer #ft { min-width: max-content; }
namespace-explorer file-grid { margin: 8px 16px; }
namespace-explorer #view-toggle button.on { background: #ddf4ff; border-color: #54aeff; color: #0969da; font-weight: 600; }

/* finder view: listing on the left, a read-only quick-look on the right.
   The element is a fixed column here (bar + finder fill it, only the panes
   scroll); the page gives it the window's height (see browse.html). */
namespace-explorer > #finder { flex: 1; min-height: 0; }
namespace-explorer #finder-list { height: 100%; overflow: auto; }
namespace-explorer #finder-lhead { position: sticky; top: 0; z-index: 2; display: flex; align-items: center; justify-content: space-between; gap: 4px; padding: 4px 6px; background: #fff; border-bottom: 1px solid #eaeef2; }
namespace-explorer #finder-collapse { all: unset; cursor: pointer; padding: 1px 9px; border-radius: 6px; color: #57606a; font-size: 15px; line-height: 1.2; }
namespace-explorer #finder-collapse:hover { background: #eaeef2; color: #24292f; }
namespace-explorer .ft-all button { all: unset; cursor: pointer; padding: 2px 8px; border-radius: 6px; font-size: 11px; color: #57606a; }
namespace-explorer .ft-all button:hover { color: #24292f; background: #eaeef2; }
/* <tree-view> is shadow DOM — its own defaults already match this
   look, so no --tv-* overrides are needed here (see lib/ui/tree-view.js) */
namespace-explorer #finder-tree { display: block; padding: 4px 4px 10px; }
namespace-explorer #finder-tree:not(:defined) { display: none; }
namespace-explorer #finder-preview { height: 100%; overflow: hidden; background: #fff; display: flex; flex-direction: column; }
namespace-explorer #finder-tabs { flex: 1; min-height: 0; }
namespace-explorer #finder-tabs[hidden] { display: none; }
namespace-explorer #finder-preview .finder-empty { flex: 1; }
namespace-explorer #finder-tabs [tab-label] { overflow: auto; }
/* gmux workspace: tab strip auto-hides at one tab (pane chrome is gmux's own) */
tab-group[data-one]::part(strip) { display: none; }
namespace-explorer #finder-dir { height: 100%; overflow: auto; }
namespace-explorer #finder-dir-ft { margin: 0; min-width: max-content; }
namespace-explorer .finder-pbody { flex: 1; min-height: 0; overflow: auto; }
namespace-explorer .finder-head { position: sticky; top: 0; z-index: 1; display: flex; align-items: center; gap: 10px; padding: 8px 16px; background: #f6f8fa; border-bottom: 1px solid #d0d7de; font: 600 12px ui-monospace, SFMono-Regular, Menlo, monospace; color: #24292f; white-space: nowrap; }
namespace-explorer .finder-head a { font: inherit; color: #0969da; }
namespace-explorer .finder-src { margin: 0; padding: 14px 18px; font: 12.5px/1.55 ui-monospace, SFMono-Regular, Menlo, monospace; white-space: pre-wrap; overflow-wrap: anywhere; color: #24292f; }
namespace-explorer .finder-empty { padding: 48px 24px; text-align: center; color: #9aa0a6; }
namespace-explorer .finder-dl { display: inline-block; margin: 24px; color: #0969da; }

/* modal internals */
namespace-explorer .m-title { margin: 0 0 12px; font-size: 15px; overflow-wrap: anywhere; }
namespace-explorer #w-path { word-break: break-all; }
namespace-explorer .m-sec { margin-bottom: 14px; }
namespace-explorer .m-sec h4 { font-size: 10px; font-weight: 600; text-transform: uppercase; letter-spacing: .05em; color: #8b949e; margin: 0 0 6px; }
namespace-explorer .m-row { display: flex; gap: 6px; align-items: center; margin-bottom: 6px; flex-wrap: wrap; }
namespace-explorer .m-row input[type="text"] { flex: 1; min-width: 120px; font: 12px ui-monospace, Menlo, monospace; padding: 5px 9px; border: 1px solid #d0d7de; border-radius: 7px; outline: none; }
namespace-explorer .m-row input[type="text"]:focus { border-color: #0969da; }
namespace-explorer .picked { flex: 1; font-size: 12px; color: #8b949e; font-style: italic; }
namespace-explorer .m-row select { font-size: 12px; padding: 4px 6px; border: 1px solid #d0d7de; border-radius: 7px; background: #fff; }
namespace-explorer .m-row button, namespace-explorer .m-actions button { all: unset; cursor: pointer; padding: 4px 12px; border-radius: 7px; font-size: 12px; border: 1px solid #d0d7de; color: #24292f; }
namespace-explorer .m-row button:hover, namespace-explorer .m-actions button:hover { background: #f6f8fa; }
namespace-explorer .m-actions { display: flex; justify-content: flex-end; gap: 8px; margin-top: 14px; }
namespace-explorer .m-actions button.primary { background: #0969da; border-color: #0969da; color: #fff; }
namespace-explorer .m-actions button.primary:hover { background: #0857b8; }
namespace-explorer #m-weir-roads { display: flex; flex-direction: column; gap: 9px; margin: 6px 0 16px; }
namespace-explorer .w-cat { display: flex; align-items: flex-start; gap: 12px; }
namespace-explorer .w-k { flex: none; width: 40px; font-size: 10px; font-weight: 600; text-transform: uppercase; letter-spacing: .05em; color: #8b949e; padding-top: 4px; }
namespace-explorer .w-roads { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; min-height: 24px; }
namespace-explorer .w-none { color: #8b949e; font-size: 12px; padding-top: 2px; }
namespace-explorer .weir-road { display: inline-flex; align-items: center; gap: 5px; max-width: 100%; background: #f6f8fa; border: 1px solid #e2e7ee; border-radius: 6px; padding: 2px 4px 2px 9px; font: 11px ui-monospace, SFMono-Regular, Menlo, monospace; color: #8250df; overflow-wrap: anywhere; word-break: break-all; }
namespace-explorer .weir-road button { all: unset; cursor: pointer; color: #8b949e; padding: 0 5px; border-radius: 4px; line-height: 1.2; }
namespace-explorer .weir-road button:hover { background: #ffebe9; color: #cf222e; }
namespace-explorer #m-weir-clear { color: #cf222e; border-color: #ffcecb; }
namespace-explorer #m-weir-clear:hover { background: #fff8f8; }
namespace-explorer .w-plus { all: unset; cursor: pointer; width: 20px; height: 20px; display: grid; place-items: center; border-radius: 6px; border: 1px dashed #d0d7de; color: #8b949e; font-size: 13px; }
namespace-explorer .w-plus:hover { background: #eef1f4; color: #24292f; border-style: solid; }
namespace-explorer .w-inline { font: 11px ui-monospace, SFMono-Regular, Menlo, monospace; padding: 3px 8px; border: 1px solid #0969da; border-radius: 6px; outline: none; width: 160px; }
namespace-explorer #boom-text { white-space: pre-wrap; font: 12px/1.5 ui-monospace, Menlo, monospace; max-height: 60vh; overflow: auto; background: #fff8f8; padding: 10px; border-radius: 8px; margin: 0; }`;
const EXPLORER_HTML = (K) => `  <div id="bar">
    <div id="crumbs"></div>
    <span class="grow"></span>
    <span id="chips"></span>
    <span id="view-toggle" style="display:inline-flex; gap:2px;">
      <button id="v-list" class="on" title="list view">&#9776;</button>
      <button id="v-grid" title="grid view">&#9638;</button>
      <button id="v-cols" title="finder view">&#9707;</button>
    </span>
    <drop-menu align="end" id="manage-menu">
      <button slot="trigger" id="manage-btn" title="manage this directory">manage &#9662;</button>
      <button class="mi" id="mi-folder">New folder&hellip;</button>
      <button class="mi" id="mi-nexus">New nexus&hellip;</button>
      <button class="mi" id="mi-file">New file&hellip;</button>
      <button class="mi" id="mi-symlink">New symlink&hellip;</button>
      <button class="mi" id="mi-upload">Upload files&hellip;</button>
      <button class="mi" id="mi-upload-dir">Upload directory&hellip;</button>
      <button class="mi" id="mi-download">Download as tarball</button>
      <button class="mi" id="mi-reload" style="display:none">Reload nexus</button>
    </drop-menu>
  </div>
  <div id="bang" style="display:none"></div>
  <file-table id="ft"></file-table>
  <file-grid id="fg" style="display:none"></file-grid>
  <split-view id="finder" orientation="horizontal" primary="start"
              size="300px" min="180" max="560" persist="${K}-finder" style="display:none">
    <div slot="start" id="finder-list">
      <div id="finder-lhead">
        <button id="finder-collapse" title="collapse sidebar">&#8676;</button>
        <span style="display:flex; gap:4px; align-items:center;">
          <span class="ft-all"><button id="finder-new-tab" title="open a new tab">+ tab</button></span>
          <span class="ft-all"><button id="finder-badges-toggle" title="show/hide row badges"></button></span>
          <span class="ft-all"><button id="finder-tree-toggle" title="expand/collapse all"></button></span>
        </span>
      </div>
      <tree-view id="finder-tree"></tree-view>
    </div>
    <div slot="end" id="finder-preview">
      <!-- tabs are seeded by browse.js: each is a uniform location tab (a dir
           listing or a FileView) carrying its own ◀▶ history. -->
      <tab-group id="finder-tabs" closable></tab-group>
    </div>
  </split-view>
  <div id="status"></div>
  <drop-menu id="ctx-menu" style="position:fixed; display:none; z-index:50;">
    <button slot="trigger" style="display:none"></button>
    <button class="mi" data-ctx="folder">New folder&hellip;</button>
    <button class="mi" data-ctx="nexus">New nexus&hellip;</button>
    <button class="mi" data-ctx="file">New file&hellip;</button>
    <button class="mi" data-ctx="symlink">New symlink&hellip;</button>
    <button class="mi" data-ctx="upload">Upload files&hellip;</button>
    <button class="mi" data-ctx="upload-dir">Upload directory&hellip;</button>
  </drop-menu>

  <modal-dialog id="folder-modal">
    <h3 class="m-title">new folder</h3>
    <div class="m-row"><input type="text" id="m-folder" placeholder="folder-name"></div>
    <div class="m-actions"><button class="primary" id="m-folder-go">create</button></div>
  </modal-dialog>

  <modal-dialog id="nexus-modal">
    <h3 class="m-title">new nexus</h3>
    <div class="m-row"><input type="text" id="m-nexus-name" placeholder="folder-name"></div>
    <div class="m-row"><input type="text" id="m-nexus-neck" placeholder="neck path (e.g. /tools, /wallet/account)"></div>
    <div class="m-actions"><button class="primary" id="m-nexus-go">create</button></div>
  </modal-dialog>

  <modal-dialog id="file-modal">
    <h3 class="m-title">new file</h3>
    <div class="m-row"><input type="text" id="m-file-name" placeholder="filename.ext"></div>
    <div class="m-row"><input type="text" id="m-file-blot" placeholder="mark path (e.g. /hoon, /json) — optional"></div>
    <div class="m-actions"><button class="primary" id="m-file-go">create</button></div>
  </modal-dialog>

  <modal-dialog id="symlink-modal">
    <h3 class="m-title">new symlink</h3>
    <div class="m-row"><input type="text" id="m-link" placeholder="link-name"></div>
    <div class="m-row"><input type="text" id="m-target" placeholder="target-path"></div>
    <div class="m-actions"><button class="primary" id="m-link-go">create</button></div>
  </modal-dialog>

  <modal-dialog id="upload-modal">
    <h3 class="m-title">upload files</h3>
    <div class="m-row">
      <button id="m-files-pick">choose files&hellip;</button>
      <span class="picked" id="m-files-n">nothing chosen</span>
      <input type="file" id="m-files" multiple hidden>
    </div>
    <div class="m-actions"><button class="primary" id="m-files-go">upload</button></div>
  </modal-dialog>

  <modal-dialog id="upload-dir-modal">
    <h3 class="m-title">upload directory</h3>
    <div class="m-row">
      <button id="m-dir-pick">choose directory&hellip;</button>
      <span class="picked" id="m-dir-n">nothing chosen</span>
      <input type="file" id="m-dir" webkitdirectory directory hidden>
    </div>
    <div class="m-actions"><button class="primary" id="m-dir-go">upload</button></div>
  </modal-dialog>

  <modal-dialog id="weir-modal" style="--md-width: 480px">
    <h3 class="m-title">sandbox <span id="w-path" style="font: 600 13px ui-monospace, Menlo, monospace; color: #57606a"></span></h3>
    <div id="m-weir-roads"></div>
    <div class="m-actions" style="justify-content: flex-start">
      <button id="m-weir-make" style="display:none">restrict this directory</button>
      <button id="m-weir-clear" style="display:none">clear weir</button>
    </div>
  </modal-dialog>

  <modal-dialog id="ask-modal">
    <h3 class="m-title" id="ask-title"></h3>
    <div class="m-row"><input type="text" id="ask-input"></div>
    <div class="m-actions">
      <button class="primary" id="ask-go">ok</button>
    </div>
  </modal-dialog>

  <modal-dialog id="boom-modal" style="--md-width: 640px">
    <h3 class="m-title" style="color:#cf222e">crash details</h3>
    <pre id="boom-text"></pre>
  </modal-dialog>`;
class NamespaceExplorer extends HTMLElement {
  mount(opts) {
    if (this._mounted) return this;
    this._mounted = true;
    opts = opts || {};
    const K = opts.storageKey || 'explorer';
    if (!document.getElementById('namespace-explorer-css')) {
      const s = document.createElement('style');
      s.id = 'namespace-explorer-css';
      s.textContent = EXPLORER_CSS;
      document.head.appendChild(s);
    }
    this.innerHTML = EXPLORER_HTML(K);
    setup(this, opts);
    return this;
  }
}
if (!customElements.get('namespace-explorer')) customElements.define('namespace-explorer', NamespaceExplorer);
