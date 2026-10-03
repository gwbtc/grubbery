var BASE = '/grubbery/forge';
var API = BASE + '/api';

// ── state ──
var repos = [];            // repo cards from /api/list
var selected = null;       // full instance name, e.g. contacts.git_repo
var tree = [];             // working-tree file paths for selected repo
var lane = null;           // command lane state {queue, active, log} for selected repo
var branches = [];         // local branch names for selected repo
var mode = 'files';        // workspace mode: files (repo) | settings
var tabsBy = { files: [] };   // per-mode open tabs [{file, text, dirty}]
var focusBy = { files: null };  // per-mode focused file
var panel = 'status';      // active bottom pane (files mode)

function esc(s) {
  var d = document.createElement('div');
  d.textContent = (s == null) ? '' : String(s);
  return d.innerHTML;
}
// ── request loading indicator ──
// every request goes through get()/post(); we count in-flight requests and
// show a thin indeterminate top bar while any are pending. The pier is slow
// (~3s per API call), so this keeps the UI from looking frozen.
var inflight = 0, loadBar = null;
function loadBarEl() {
  if (!loadBar) { loadBar = document.createElement('div'); loadBar.id = 'load-bar'; document.body.appendChild(loadBar); }
  return loadBar;
}
function loadStart() { if (inflight++ === 0) loadBarEl().classList.add('active'); }
function loadEnd() { if (--inflight <= 0) { inflight = 0; loadBarEl().classList.remove('active'); } }
function track(p) { loadStart(); return p.then(function(r) { loadEnd(); return r; }, function(e) { loadEnd(); throw e; }); }

function get(u) { return track(fetch(API + u).then(function(r) { return r.json(); })); }
function post(u, b) {
  return track(fetch(API + u, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(b)
  }));
}
function openTabs() { return tabsBy[mode] || []; }
function focusedF() { return focusBy[mode]; }
// tear down every open tab's cached FileView + panel — call before
// resetting tabsBy (switching repos, deleting the current repo).
function clearTabs() {
  openTabs().forEach(function(t) { if (t.fv) t.fv.destroy(); if (t.host) t.host.remove(); });
  dirViewPath = ''; // the directory tab goes back to the (next) repo's root
}
function shortName(n) {
  return n && n.slice(-9) === '.git_repo' ? n.slice(0, -9) : n;
}
function fullName(n) {
  return n && n.slice(-9) !== '.git_repo' ? n + '.git_repo' : n;
}

// ── url routing: /repo/<short>?file=..&panel=.. ──
function urlState() {
  var m = location.pathname.match(/\/forge\/repo\/([^\/]+)(?:\/(files|settings))?/);
  var q = new URLSearchParams(location.search);
  return {
    repo: m ? fullName(decodeURIComponent(m[1])) : null,
    mode: (m && m[2]) || 'files',
    file: q.get('file'),
    panel: q.get('panel') || 'status'
  };
}
function pushUrl(replace) {
  var u = BASE;
  if (selected) {
    u += '/repo/' + encodeURIComponent(shortName(selected)) + '/' + mode;
  }
  var q = new URLSearchParams();
  if (focusedF()) q.set('file', focusedF());
  if (mode === 'files' && panel !== 'status') q.set('panel', panel);
  var qs = q.toString();
  if (qs) u += '?' + qs;
  if (u === location.pathname + location.search) return;
  history[replace ? 'replaceState' : 'pushState'](null, '', u);
}
window.addEventListener('popstate', function() { applyUrl(); });
function applyUrl() {
  var st = urlState();
  panel = st.panel;
  mode = st.mode;
  renderPanelTabs();
  if (st.repo !== selected) {
    clearTabs();
    selected = st.repo;
    tabsBy = { files: [] };
    focusBy = { files: null };
    onRepoChanged();
  }
  renderMode();
  if (st.file && st.file !== focusedF()) openFile(st.file, true);
  if (!st.file && focusedF()) { focusBy[mode] = null; edTabsEl().select(0); mountEditor(); }
}
function renderMode() {
  var has = !!selected;
  var editorish = has && mode !== 'settings';
  document.getElementById('landing').style.display = has ? 'none' : '';
  document.getElementById('sidebar').style.display = editorish ? '' : 'none';
  document.getElementById('mode-tabs').style.display = has ? 'flex' : 'none';
  document.getElementById('console').style.display = (has && mode === 'files') ? '' : 'none';
  // settings is a full-bleed view outside the split nest: swap #main out for it.
  var settingsOn = has && mode === 'settings';
  document.getElementById('settings-pane').style.display = settingsOn ? '' : 'none';
  document.getElementById('main').style.display = settingsOn ? 'none' : '';
  // no console outside files (transient, doesn't touch the saved layout).
  document.getElementById('main').toggleAttribute('hide-primary', !(has && mode === 'files'));
  Array.prototype.forEach.call(document.querySelectorAll('.mode-tab'), function(t) {
    t.classList.toggle('active', t.getAttribute('data-mode') === mode);
  });
  var sbh = document.getElementById('sb-head');
  sbh.innerHTML = 'files' +
    '<span class="ft-all"><button id="ft-toggle" title="expand/collapse all"></button></span>';
  document.getElementById('ft-toggle').onclick = function() {
    // the label is the action about to happen
    var p = document.getElementById('ft-toggle').textContent === 'expand all'
      ? sidebarTree.expandAll() : Promise.resolve(sidebarTree.collapseAll());
    p.then(updateFtToggle);
  };
  if (mode === 'settings') { renderSettings(); }
  renderFiles();
  mountEditor();
}
function renderSettings() {
  var r = repos.find(function(x) { return x.name === selected; }) || {};
  var pane = document.getElementById('settings-pane');
  pane.innerHTML =
    '<div class="set-section"><div class="run-head">origin</div>' +
    '<label class="m-label">repository <input id="set-origin" type="text" value="' + esc(r.repo || '') + '" placeholder="owner/repo"></label>' +
    '<label class="m-label">ref <input id="set-ref" type="text" value="' + esc(r.ref || '') + '" placeholder="main"></label>' +
    '<label class="m-label">account <span class="hint">(github login to push as; empty = none)</span> <input id="set-account" type="text" value="' + esc(r.account || '') + '" placeholder="none"></label>' +
    '<label class="m-label">poll <span class="hint">(minutes between fetches; 0 = only on demand)</span> <input id="set-poll" type="number" min="0" value="' + esc(String(r.poll == null ? '' : r.poll)) + '" placeholder="15"></label></div>' +
    '<div class="set-section"><div class="run-head">author</div>' +
    '<label class="m-label">name <span class="hint">(stamped into commits you make)</span> <input id="set-author-name" type="text" value="' + esc(r.author_name || '') + '" placeholder="Your Name"></label>' +
    '<label class="m-label">email <input id="set-author-email" type="text" value="' + esc(r.author_email || '') + '" placeholder="you@example.com"></label>' +
    '<button class="hdr-btn primary" id="set-save">save config</button></div>' +
    '<div class="set-section danger-zone"><div class="run-head">danger</div>' +
    '<div class="set-act"><button class="hdr-btn red" id="set-delete">delete repo</button><span>permanently removes the instance and its working tree</span></div></div>';
  pane.querySelector('#set-save').onclick = function() {
    var pollRaw = document.getElementById('set-poll').value.trim();
    var cfg = {
      repo: selected,
      origin: document.getElementById('set-origin').value.trim(),
      ref: document.getElementById('set-ref').value.trim(),
      account: document.getElementById('set-account').value.trim(),
      author_name: document.getElementById('set-author-name').value.trim(),
      author_email: document.getElementById('set-author-email').value.trim()
    };
    if (pollRaw !== '' && !isNaN(Number(pollRaw))) { cfg.poll = Number(pollRaw); }
    post('/config', cfg).then(function(r2) {
      if (r2.ok) { refreshSoon(); } else { alert('save failed'); }
    });
  };
  pane.querySelector('#set-delete').onclick = function() {
    var word = prompt('CAREFUL: this permanently deletes ' + selected + '. Type "' + shortName(selected) + '" to confirm:');
    if (word !== shortName(selected)) return;
    post('/delete', { repo: selected }).then(function() {
      clearTabs();
      selected = null;
      tabsBy = { files: [] };
      focusBy = { files: null };
      pushUrl();
      onRepoChanged();
    });
  };
}
Array.prototype.forEach.call(document.querySelectorAll('.mode-tab'), function(t) {
  t.onclick = function() {
    mode = t.getAttribute('data-mode');
    pushUrl();
    renderMode();
  };
});
// ── repo list (sidebar) ──
function loadRepos() {
  get('/list').then(function(rs) {
    repos = rs;
    renderLanding();
    renderStock();
    renderRepoMenu();
    renderTopbar();
  });
}
// ── stock repos: the house catalog, one-click clone ──
var stock = null;
function renderStock() {
  var grid = document.getElementById('stock-grid');
  if (!grid) return;
  var draw = function() {
    var have = {};
    repos.forEach(function(r) { have[shortName(r.name)] = true; });
    grid.innerHTML = stock.map(function(s) {
      var action = have[s.name]
        ? '<span class="stock-have">cloned ✓</span>'
        : '<button class="hdr-btn stock-clone" data-name="' + esc(s.name) + '">clone</button>';
      return '<div class="repo-row stock-row' + (have[s.name] ? ' have' : '') + '" data-stock="' + esc(s.name) + '">' +
        '<span class="rr-name">' + esc(s.name) + '</span>' +
        '<span class="rr-origin">' + esc(s.repo) + '</span>' +
        '<span class="chip">' + esc(s.ref) + '</span>' +
        '<span class="rr-last">' + esc(s.desc || '') + '</span>' +
        action +
        '</div>';
    }).join('');
    Array.prototype.forEach.call(grid.querySelectorAll('.stock-clone'), function(btn) {
      btn.onclick = function() {
        var s = stock.find(function(x) { return x.name === btn.getAttribute('data-name'); });
        if (!s) return;
        btn.disabled = true;
        btn.textContent = 'cloning…';
        post('/add', { name: s.name, repo: s.repo, ref: s.ref }).then(loadRepos);
      };
    });
  };
  if (stock) return draw();
  get('/stock').then(function(s) { stock = s || []; draw(); });
}
function enterRepo(name) {
  if (name === selected) return;
  clearTabs();
  selected = name;
  tabsBy = { files: [] };
  focusBy = { files: null };
  mode = 'files';
  pushUrl();
  onRepoChanged();
}
function renderLanding() {
  var grid = document.getElementById('landing-grid');
  if (!grid) return;
  var count = document.getElementById('landing-count');
  if (count) count.textContent = repos.length ? '(' + repos.length + ')' : '';
  if (!repos.length) {
    grid.innerHTML = '<div class="empty">no repos yet — hit + repo</div>';
    return;
  }
  grid.innerHTML = repos.map(function(r) {
    var cur = r.current || {};
    var last = r.last || {};
    return '<div class="repo-row" data-repo="' + esc(r.name) + '">' +
      '<span class="rr-name">' + esc(shortName(r.name)) + '</span>' +
      '<span class="rr-origin">' + esc(r.repo || 'local') + '</span>' +
      (cur.branch ? '<span class="chip">' + esc(cur.branch) + '</span>' : '<span></span>') +
      '<span class="rr-last">' +
        (last.short || last.hash
          ? '<span class="c-hash">' + esc(String(last.short || last.hash).slice(0, 7)) + '</span> '
          : '') +
        esc(last.message || '') + '</span>' +
      '<span class="rr-x" data-del="' + esc(r.name) + '" title="delete repo">×</span>' +
      '<span class="rr-go">›</span>' +
      '</div>';
  }).join('');
  Array.prototype.forEach.call(grid.querySelectorAll('.repo-row'), function(el) {
    el.onclick = function(e) {
      var name = el.getAttribute('data-repo');
      if (e.target.hasAttribute('data-del')) {
        var word = prompt('CAREFUL: this permanently deletes ' + name +
          ' and its working tree. Type "' + shortName(name) + '" to confirm:');
        if (word !== shortName(name)) return;
        post('/delete', { repo: name }).then(loadRepos);
        return;
      }
      enterRepo(name);
    };
  });
}
// <drop-menu> owns toggle, click-outside, Esc. We inject the items as its
// children (preserving the slot="trigger" button), and it closes on click.
function renderRepoMenu() {
  var menu = document.getElementById('repo-menu');
  var trigger = menu.querySelector('[slot="trigger"]');
  menu.innerHTML = '';
  menu.appendChild(trigger);
  repos.forEach(function(r) {
    var cur = r.current || {};
    var el = document.createElement('div');
    el.className = 'rm-item' + (r.name === selected ? ' sel' : '');
    el.setAttribute('data-repo', r.name);
    el.innerHTML = esc(shortName(r.name)) +
      (cur.branch ? ' <span class="chip">' + esc(cur.branch) + '</span>' : '');
    el.onclick = function() { enterRepo(r.name); };
    menu.appendChild(el);
  });
}

function onRepoChanged() {
  loadRepos();
  renderTopbar();
  renderMode();
  if (!selected) {
    sidebarTree.render([]); // <tree-view>'s content is shadow DOM — innerHTML can't touch it
    ['status', 'history'].forEach(function(p) {
      document.getElementById('pane-' + p).innerHTML = '';
    });
    return;
  }
  loadDetail();
}

function renderTopbar() {
  var r = repos.find(function(x) { return x.name === selected; });
  document.getElementById('sb-toggle').style.display = selected ? '' : 'none';
  var tb = document.getElementById('tb-repo');
  tb.textContent = selected ? shortName(selected) + ' ▾' : '';
  tb.style.display = selected ? '' : 'none';
  document.getElementById('tb-origin').textContent = (r && r.repo) || '';
  var br = document.getElementById('tb-branch');
  var cur = (r && r.current) || {};
  br.textContent = cur.branch || '';
  br.style.display = cur.branch ? '' : 'none';

}

// ── file tree (sidebar) ── the shared TreeView (lib/ui/tree-view.js) — same
// component as explorer's cols sidebar, here fed eagerly from the already-
// fully-known working-tree path list instead of a lazy per-dir fetch, and
// with no onOpenDir: this is one bounded repo, not a namespace to climb
// around in, so a dir's row only ever toggles, never navigates anywhere.
// nest a flat list of paths into { dirs, files }
function buildTree(paths) {
  var root = { dirs: {}, files: [] };
  paths.forEach(function(f) {
    var segs = f.split('/');
    segs.pop();
    var node = root;
    segs.forEach(function(s) {
      if (!node.dirs[s]) node.dirs[s] = { dirs: {}, files: [] };
      node = node.dirs[s];
    });
    node.files.push(f);
  });
  return root;
}
// sidebarTree is the <tree-view> element itself (see index.html's #sb-list).
// Same model as explorer's sidebar, scoped to this repo: a directory's name
// opens it in the directory tab (tab 0), a file opens a tab, and every row
// carries its item (row.__item) for the right-click menu below. Paths here
// are repo-relative ('' = the repo root); nothing ever points above it.
var sidebarTree = document.getElementById('sb-list');
var treeRoot = { dirs: {}, files: [] }; // buildTree(tree), rebuilt per render
function nodeAt(path) {
  var node = treeRoot;
  if (!path) return node;
  var segs = path.split('/');
  for (var i = 0; i < segs.length; i++) {
    node = node.dirs[segs[i]];
    if (!node) return { dirs: {}, files: [] };
  }
  return node;
}
function joinRel(dir, name) { return dir ? dir + '/' + name : name; }
// a level's children as items: { name, isDir, kind, path } — kind/path are
// what file-table rows and the action menu read
function childrenAt(path) {
  var node = nodeAt(path);
  return Object.keys(node.dirs).map(function (n) {
    return { name: n, isDir: true, kind: 'dir', path: joinRel(path, n) };
  }).concat(node.files.map(function (f) {
    return { name: f.split('/').pop(), isDir: false, kind: 'file', path: f };
  }));
}
sidebarTree.onOpenFile = function (item, path) { openFile('tree:' + path); };
sidebarTree.onOpenDir = function (item, path) { showDirView(path); };
sidebarTree.decorateRow = function (row, item) { row.__item = item; };
function renderFiles() {
  if (!selected) { sidebarTree.render([]); return; }
  var keepScroll = sidebarTree.scrollTop;
  treeRoot = buildTree(tree);
  sidebarTree.root = '';
  sidebarTree.persistKey = 'forge-tree:' + selected;
  sidebarTree.getChildren = childrenAt;
  sidebarTree.render(childrenAt(''));
  sidebarTree.markActive(focusedF() ? splitId(focusedF()).file : null);
  sidebarTree.scrollTop = keepScroll;
  updateFtToggle();
  showDirView(dirViewPath, false); // refresh tab 0's listing from the new tree
}
// ── directory view: tab 0, fixed. A directory's listing (the kit
// <file-table>, names only — a working tree has nothing else to show per
// file), built from the already-known tree, no request. Starts at the repo
// root; a sidebar directory click retargets it to that directory and
// selects it. A dir row drills further in; a file row opens a tab.
var dirViewPath = '';
var dirFt = document.getElementById('ed-dir-ft');
dirFt.columns = [{
  key: 'name', label: 'Name',
  format: function (v, item) { return item.kind === 'dir' ? v + '/' : v; },
  link: function (item) { return '#' + item.path; }, // a clickable name; never followed
}];
dirFt.actions = rowActions;
dirFt.addEventListener('ft-navigate', function (e) {
  var item = e.detail.item;
  if (!item) return;
  if (item.kind === 'dir') showDirView(item.path); else openFile('tree:' + item.path);
});
dirFt.addEventListener('ft-action', function (e) { doAction(e.detail.action, e.detail.item); });
// select=false refreshes the listing without stealing the selection
function showDirView(path, select) {
  if (select === undefined) select = true;
  dirViewPath = path;
  var ed = document.getElementById('ed-dir');
  ed.setAttribute('tab-label', path ? path.slice(path.lastIndexOf('/') + 1) + '/' : '/');
  ed.setAttribute('tab-title', '/' + path);
  edTabsEl().refresh(); // attr edits don't fire slotchange; keeps the selection
  dirFt.items = childrenAt(path);
  if (select) edTabsEl().select(0); // → tg-change: focus cleared, url + sidebar updated
}

// ── row actions — one set, used by the right-click menu (sidebar rows,
// listing rows, and the empty space of either, which acts on the directory
// being shown) and by the listing's own ⋯ menu. Scoped to what the server
// supports: write a file, delete a file. Deleting a directory = deleting
// every file under it, which in a working tree IS deleting the directory.
function rowActions(item) {
  if (item.kind === 'dir') {
    var acts = [{ label: 'New file…', action: 'new-file' }];
    if (item.path) acts.push({ label: 'Delete', action: 'delete', danger: true });
    return acts;
  }
  return [
    { label: 'Download', action: 'download' },
    { label: 'Delete', action: 'delete', danger: true },
  ];
}
function filesUnder(dir) { return tree.filter(function (f) { return f.indexOf(dir + '/') === 0; }); }
function createFile(name) {
  post('/src', { repo: selected, file: name, root: 'tree', text: '' }).then(function () {
    loadDetail();
    openFile('tree:' + name);
  });
}
function deleteFiles(files) {
  return files.reduce(function (p, f) {
    return p.then(function () {
      return post('/src-delete', { repo: selected, file: f, root: 'tree' }).then(function () {
        var t = tabFor('tree:' + f);
        if (t) { t.dirty = false; closeTab('tree:' + f); }
      });
    });
  }, Promise.resolve()).then(function () { loadDetail(); });
}
function doAction(action, item) {
  if (action === 'new-file') {
    var name = prompt('new file in ' + (item.path ? item.path + '/' : '/') + ':', '');
    if (name && name.trim()) createFile(joinRel(item.path, name.trim()));
  } else if (action === 'download') {
    var a = document.createElement('a');
    a.href = rawUrlFor(item.path); a.download = item.name; a.click();
  } else if (action === 'delete') {
    var files = item.kind === 'dir' ? filesUnder(item.path) : [item.path];
    var what = item.kind === 'dir' ? files.length + ' file(s) under ' + item.path + '/' : item.path;
    if (!files.length || !confirm('delete ' + what + '?')) return;
    deleteFiles(files);
  }
}

// ── right-click menu: the kit <drop-menu> forge already uses for
// repo-menu/branch-menu, its items rebuilt per click from rowActions. A row
// (row.__item, set by the sidebar's decorateRow and by file-table on its
// own rows) acts on itself; empty space in the sidebar acts on the repo
// root, empty space in the directory view on the directory it's showing.
var sbCtx = document.getElementById('sb-ctx');
var sidebarEl = document.getElementById('sidebar');
var edDirEl = document.getElementById('ed-dir');
document.addEventListener('contextmenu', function (e) {
  var path = e.composedPath();
  var hit = path.find(function (el) { return el && el.__item; });
  var inSidebar = path.indexOf(sidebarEl) >= 0;
  var inDirView = path.indexOf(edDirEl) >= 0;
  if (!hit && !inSidebar && !inDirView) return;
  if (!selected) return;
  e.preventDefault();
  var item = hit ? hit.__item
    : { name: '', isDir: true, kind: 'dir', path: inDirView ? dirViewPath : '' };
  Array.prototype.forEach.call(sbCtx.querySelectorAll('[data-act]'), function (b) { b.remove(); });
  rowActions(item).forEach(function (act) {
    var b = document.createElement('button');
    b.className = 'rm-item' + (act.danger ? ' danger' : '');
    b.setAttribute('data-act', act.action);
    b.textContent = act.label;
    b.onclick = function () { sbCtx.close(); doAction(act.action, item); };
    sbCtx.appendChild(b);
  });
  sbCtx.style.display = ''; // the host starts display:none — .open() alone doesn't clear it
  sbCtx.style.left = e.clientX + 'px';
  sbCtx.style.top = e.clientY + 'px';
  sbCtx.open();
});
sbCtx.addEventListener('dm-close', function () { sbCtx.style.display = 'none'; });
function updateFtToggle() {
  var tog = document.getElementById('ft-toggle');
  if (tog) tog.textContent = sidebarTree.anyOpen ? 'collapse all' : 'expand all';
}
// ── detail: status + history panes ──
function loadDetail() {
  if (!selected) return;
  get('/detail?repo=' + encodeURIComponent(selected)).then(function(d) {
    var r = repos.find(function(x) { return x.name === selected; });
    if (r) r.current = d.current || r.current;
    branches = d.branches || [];
    tree = d.tree || [];
    lane = d.lane || null;
    renderTopbar();
    renderStatus(d.status || {}, d.current || {}, d.stash || []);
    renderHistory(d.commits || []);
    renderLane();
    renderFiles();
  });
}
// ── command lane: type git commands, they run through /actions/run ──
function renderLane() {
  var log = document.getElementById('lane-log');
  var entries = (lane && lane.log) || [];
  // backend log is newest-first; render oldest→newest, top→bottom (terminal style)
  var html = entries.slice().reverse().map(function(e) {
    var cls = e.ok ? 'ok' : 'err';
    return '<div class="lane-line ' + cls + '"><span class="lane-dot">' + (e.ok ? '✓' : '✕') + '</span>' +
      '<span class="lane-cmd">' + esc(e.raw) + '</span> <span class="lane-msg">' + esc(e.message || '') + '</span></div>';
  }).join('');
  // the currently-running command sits at the bottom, nearest the input
  if (lane && lane.active) {
    html += '<div class="lane-line running"><span class="lane-dot">▸</span>' +
      esc(lane.active.raw) + ' <span class="lane-msg">running…</span></div>';
  }
  log.innerHTML = html;
  log.scrollTop = log.scrollHeight;
}
function submitLane() {
  var inp = document.getElementById('lane-input');
  var cmd = inp.value.trim();
  if (!cmd || !selected) return;
  inp.value = '';
  post('/run', { repo: selected, command: cmd }).then(function() {
    // give the lane a beat to process, then refresh its state
    setTimeout(loadDetail, 400);
    setTimeout(loadDetail, 1500);
  });
}
function renderStatus(st, current, stash) {
  var pane = document.getElementById('pane-status');
  current = current || {};
  stash = stash || [];
  // where HEAD sits — branch or detached, + ahead/behind of remote
  var head = '';
  if (current.hash) {
    var where = current.branch
      ? 'on <b>' + esc(current.branch) + '</b>'
      : '<b>detached</b>';
    var ahead = (current.remote && current.remote !== current.hash)
      ? ' <span class="st-ahead">↑ ahead of remote</span>' : '';
    head = '<div class="st-head">' + where + ' @ <code>' +
      esc((current.hash || '').slice(0, 7)) + '</code>' + ahead + '</div>';
  }
  var groups = [
    ['staged', st.staged || [], 'ok'],
    ['unstaged', st.unstaged || [], 'warn'],
    ['untracked', st.untracked || [], 'muted']
  ];
  var body = groups.map(function(g) {
    if (!g[1].length) return '';
    return '<div class="st-group"><div class="st-title ' + g[2] + '">' + g[0] +
      ' (' + g[1].length + ')</div>' +
      g[1].map(function(f) {
        var p = typeof f === 'string' ? f : (f.path || JSON.stringify(f));
        var s = (typeof f === 'object' && f.status) ? f.status : '';
        var mark = s
          ? '<span class="st-mark st-mark-' + esc(s) + '" title="' + esc(s) + '">' + esc(s.charAt(0).toUpperCase()) + '</span>'
          : '';
        return '<div class="st-file">' + mark + '<span class="st-path">' + esc(p) + '</span></div>';
      }).join('') + '</div>';
  }).join('');
  if (!body) body = '<div class="empty">working tree clean</div>';
  // the stash stack (newest = @0)
  var stashHtml = '';
  if (stash.length) {
    stashHtml = '<div class="st-group"><div class="st-title muted">stash (' + stash.length + ')</div>' +
      stash.map(function(s) {
        return '<div class="st-file"><span class="st-mark st-mark-stash">@' + esc(String(s.index)) +
          '</span><span class="st-path"><code>' + esc(s.short || '') + '</code> ' + esc(s.message || '') + '</span></div>';
      }).join('') + '</div>';
  }
  pane.innerHTML = head + body + stashHtml;
}
function renderHistory(commits) {
  var pane = document.getElementById('pane-history');
  if (!commits.length) {
    pane.innerHTML = '<div class="empty">no commits</div>';
    return;
  }
  pane.innerHTML = commits.map(function(c) {
    var refs = (c.refs || []).map(function(r) {
      return '<span class="chip">' + esc(r) + '</span>';
    }).join(' ');
    return '<div class="commit">' +
      '<span class="c-hash">' + esc(String(c.short || c.hash || '').slice(0, 7)) + '</span>' +
      '<span class="c-msg">' + esc(c.message || '') + '</span> ' + refs +
      '<span class="c-author">' + esc(c.author || '') + '</span>' +
      '</div>';
  }).join('');
}

// ── editor tabs ──
function tabFor(f) {
  return openTabs().find(function(t) { return t.file === f; });
}
function splitId(id) {
  var i = id.indexOf(':');
  return i < 0 ? { root: 'tree', file: id } : { root: id.slice(0, i), file: id.slice(i + 1) };
}
// ed-tabs is the shared <tab-group> (same component, same pattern as
// explorer's cols-view finder tabs) — each open file is a slotted panel
// hosting its own cached <FileView>, created once at open time and shown/
// hidden by tab-group itself from then on.
function edTabsEl() { return document.getElementById('ed-tabs'); }
function mountTabPanel(t) {
  var s = splitId(t.file);
  var host = document.createElement('div');
  host.setAttribute('tab-label', s.file.split('/').pop());
  host.setAttribute('tab-title', s.root + '/' + s.file);
  host.dataset.file = t.file;
  host.style.height = '100%';
  edTabsEl().appendChild(host);
  var repoRoot = '/grubbery/ball/apps/forge.git_forge/repos/' + selected + '/data/tree';
  var url = repoRoot + '/' + s.file;
  t.fv = window.FileView.mount(host, { url: url, wrapKey: 'forge-wrap', crumbBase: repoRoot });
  t.host = host;
}
function selectTab(f) {
  var panels = Array.prototype.slice.call(edTabsEl().children);
  var idx = panels.findIndex(function(p) { return p.dataset.file === f; });
  if (idx >= 0) edTabsEl().select(idx);
}
function openFile(id, fromUrl) {
  if (id.indexOf(':') < 0) id = 'tree:' + id;
  var isNew = !tabFor(id);
  if (isNew) { openTabs().push({ file: id }); mountTabPanel(tabFor(id)); }
  focusBy[mode] = id;
  if (!fromUrl) pushUrl();
  edTabsEl().refresh();
  var settle = function() { selectTab(id); };
  settle();
  // appendChild above queues a native slotchange tab-group's own listener
  // rebuilds on asynchronously, defaulting back to tab 0 — re-assert the
  // selection once that settles (same race explorer's tabs hit).
  if (isNew) queueMicrotask(settle);
  renderFiles();
  mountEditor();
}
function closeTab(f) {
  var ct = tabFor(f);
  if (ct) { if (ct.fv) ct.fv.destroy(); if (ct.host) ct.host.remove(); }
  tabsBy[mode] = openTabs().filter(function(x) { return x.file !== f; });
  edTabsEl().refresh();
  if (focusedF() === f) {
    var ts = openTabs();
    focusBy[mode] = ts.length ? ts[ts.length - 1].file : null;
    if (focusBy[mode]) selectTab(focusBy[mode]); else edTabsEl().select(0); // the directory tab
  }
  pushUrl();
  renderFiles();
  mountEditor();
}
edTabsEl().addEventListener('tg-close', function(e) { closeTab(e.detail.panel.dataset.file); });
edTabsEl().addEventListener('tg-change', function(e) {
  var panel = edTabsEl().children[e.detail.index];
  focusBy[mode] = (panel && panel.dataset.file) ? panel.dataset.file : null; // tab 0 has none
  pushUrl();
  renderFiles();
});

// ── the editor: transparent textarea over a shiki-rendered pre ──
var shikiHl = null;
var shikiTried = false;
function ensureShiki() {
  if (shikiHl || shikiTried) return Promise.resolve(shikiHl);
  shikiTried = true;
  return import('https://esm.sh/shiki@1.24.0').then(function(m) {
    return fetch('/grubbery/ball/apps/explorer.explorer/hoon-grammar.json')
      .then(function(r) { return r.json(); })
      .then(function(grammar) {
        return m.createHighlighter({ themes: ['github-dark'], langs: [grammar] });
      });
  }).then(function(hl) { shikiHl = hl; return hl; })
    .catch(function() { return null; });
}
function highlightInto(el, text) {
  if (!shikiHl) { el.textContent = text; return; }
  el.innerHTML = shikiHl.codeToHtml(text, { lang: 'hoon', theme: 'github-dark' });
}
function updateTang() {
  document.getElementById('ed-tang').style.display = 'none';
}
// ── file preview (Source | Preview toggle) ──
// render logic lives in the shared window.FilePreview helper (file-preview.js).
// text kinds render from the buffer; raster (image/pdf/svg) loads bytes from the
// generic namespace lane (/grubbery/ball/<repo file>?raw=1) — no forge endpoint.
function previewKind(name) {
  return window.FilePreview ? FilePreview.kind(name) : null;
}
// bytes for the selected repo's file, via the shared namespace serving.
function rawUrlFor(file) {
  return '/grubbery/ball/apps/forge.git_forge/repos/' +
    selected + '/data/tree/' + file + '?raw=1';
}
function isRaster(k) { return k === 'image' || k === 'pdf'; }
// forge's file panes are the shared <FileView> (lib/ui/file-view.js) — the same
// editor the explorer file page and finder use. One FileView per open tab,
// mounted once over the tab's /grubbery/ball URL and CACHED: switching tabs is
// just show/hide (its scroll, edit mode, and unsaved text all persist), no
// refetch. Each tab is its own panel inside the shared <tab-group> #ed-tabs.
function mountEditor() {
  var has = !!selected;
  var editorish = has && mode !== 'settings';
  document.getElementById('ed-wrap').style.display = editorish ? '' : 'none';
  edTabsEl().style.display = editorish ? '' : 'none'; // tab 0 is always there: never empty
}
function saveFocused() {
  var t = focusedF() ? tabFor(focusedF()) : null;
  if (!t) return;
  var s = splitId(t.file);
  post('/src', { repo: selected, file: s.file, root: s.root, text: t.text }).then(function(r) {
    if (r.ok) {
      t.dirty = false;
      setTimeout(loadDetail, 2000);
    } else {
      alert('save failed');
    }
  });
}

// ── console panel chrome ──
function renderPanelTabs() {
  Array.prototype.forEach.call(document.querySelectorAll('.con-tab'), function(t) {
    t.classList.toggle('active', t.getAttribute('data-panel') === panel);
  });
  ['status', 'history', 'run'].forEach(function(p) {
    document.getElementById('pane-' + p).style.display = p === panel ? '' : 'none';
  });
}
Array.prototype.forEach.call(document.querySelectorAll('.con-tab'), function(t) {
  t.onclick = function() {
    panel = t.getAttribute('data-panel');
    renderPanelTabs();
    pushUrl();
  };
});
document.getElementById('con-toggle').onclick = function() {
  document.getElementById('main').toggle();  // <split-view> collapses the console
};
document.getElementById('lane-input').addEventListener('keydown', function(e) {
  if (e.key === 'Enter') { e.preventDefault(); submitLane(); }
});
document.getElementById('lane-info').onclick = function() {
  document.getElementById('pane-run').classList.toggle('docs-open');
};
document.getElementById('sb-toggle').onclick = function() {
  document.getElementById('body').toggle();  // <split-view> collapses the sidebar
};
// ── branch switcher ──
// <drop-menu> owns toggle/click-outside/Esc. We rebuild the branch list each
// time it opens (dm-open), injecting items as children while preserving the
// slot="trigger" button. The inline create-branch row is [data-keep-open] so
// typing in it doesn't close the menu.
function renderBranchMenu() {
  var cur = ((repos.find(function(x) { return x.name === selected; }) || {}).current || {}).branch;
  var menu = document.getElementById('branch-menu');
  var trigger = menu.querySelector('[slot="trigger"]');
  menu.innerHTML = '';
  menu.appendChild(trigger);
  branches.forEach(function(b) {
    var el = document.createElement('div');
    el.className = 'rm-item' + (b === cur ? ' sel' : '');
    el.setAttribute('data-branch', b);
    el.textContent = b;
    el.onclick = function() {
      if (b === cur) return;
      var dirty = openTabs().some(function(t) { return t.dirty; });
      if (dirty && !confirm('unsaved editor changes will be left behind — switch anyway?')) return;
      post('/run', { repo: selected, command: 'checkout ' + b }).then(refreshSoon);
    };
    menu.appendChild(el);
  });
  var row = document.createElement('div');
  row.className = 'bm-new';
  row.setAttribute('data-keep-open', '');
  row.innerHTML = '<input id="bm-name" type="text" placeholder="new branch">' +
    '<button class="hdr-btn" id="bm-create">create</button>';
  row.querySelector('#bm-create').onclick = function() {
    var name = document.getElementById('bm-name').value.trim();
    if (!name) return;
    menu.close();
    post('/run', { repo: selected, command: 'branch ' + name }).then(refreshSoon);
  };
  menu.appendChild(row);
}
document.getElementById('branch-menu').addEventListener('dm-open', renderBranchMenu);

// ── new repo modal ──
// <modal-dialog> handles backdrop-click, Esc, focus-trap, and the [data-close]
// cancel button itself — we just open it and close it on success.
var repoModal = document.getElementById('repo-modal');
document.getElementById('new-repo').onclick = function() { repoModal.show(); };
document.getElementById('m-save').onclick = function() {
  var name = document.getElementById('m-name').value.trim();
  if (!name) return;
  post('/add', {
    name: name,
    repo: document.getElementById('m-repo').value.trim(),
    ref: document.getElementById('m-ref').value.trim()
  }).then(function(r) {
    if (!r.ok) { alert('create failed'); return; }
    repoModal.close();
    selected = fullName(name);
    pushUrl();
    onRepoChanged();
    setTimeout(loadRepos, 3000);
  });
};

// ── forge-level defaults modal ──
var defaultsModal = document.getElementById('defaults-modal');
document.getElementById('edit-defaults').onclick = function() {
  get('/defaults').then(function(d) {
    d = d || {};
    document.getElementById('d-author-name').value = d.author_name || '';
    document.getElementById('d-author-email').value = d.author_email || '';
    document.getElementById('d-account').value = d.account || '';
    defaultsModal.show();
  });
};
document.getElementById('d-save').onclick = function() {
  post('/defaults', {
    author_name: document.getElementById('d-author-name').value.trim(),
    author_email: document.getElementById('d-author-email').value.trim(),
    account: document.getElementById('d-account').value.trim()
  }).then(function(r) {
    if (!r.ok) { alert('save failed'); return; }
    defaultsModal.close();
  });
};

function refreshSoon() {
  setTimeout(function() { loadDetail(); loadRepos(); }, 1200);
  setTimeout(function() { loadDetail(); }, 4000);
}

// ── boot ──
loadRepos();
applyUrl();
pushUrl(true);
setInterval(function() {
  if (selected) { loadDetail(); }
}, 8000);
