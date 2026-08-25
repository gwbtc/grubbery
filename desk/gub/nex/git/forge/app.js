var BASE = '/grubbery/forge';
var API = BASE + '/api';

// ── state ──
var repos = [];            // repo cards from /api/list
var selected = null;       // full instance name, e.g. contacts.git_repo
var toolDefs = [];         // tool defs for selected repo
var weirReq = {};          // tools/weir.json request for selected repo
var weirAct = {};          // weir enforced on /tools/proc right now
var files = [];            // tools/code file paths for selected repo
var tree = [];             // working-tree file paths for selected repo
var branches = [];         // local branch names for selected repo
var mode = 'files';        // workspace mode: files (repo) | tools
var toolSub = 'run';       // tools sub-tab: run | permissions
var permEdit = false;      // permissions: false = view weir, true = edit form
var tabsBy = { files: [], tools: [] };   // per-mode open tabs [{file, text, dirty}]
var focusBy = { files: null, tools: null };  // per-mode focused file (null in tools = runner)
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
function shortName(n) {
  return n && n.slice(-9) === '.git_repo' ? n.slice(0, -9) : n;
}
function fullName(n) {
  return n && n.slice(-9) !== '.git_repo' ? n + '.git_repo' : n;
}

// ── url routing: /repo/<short>?file=..&panel=.. ──
function urlState() {
  var m = location.pathname.match(/\/forge\/repo\/([^\/]+)(?:\/(files|tools|settings))?/);
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
    selected = st.repo;
    tabsBy = { files: [], tools: [] };
    focusBy = { files: null, tools: null };
    onRepoChanged();
  }
  renderMode();
  if (st.file && st.file !== focusedF()) openFile(st.file, true);
  if (!st.file && focusedF()) { focusBy[mode] = null; renderTabs(); mountEditor(); }
}
function renderMode() {
  var has = !!selected;
  var editorish = has && mode !== 'settings';
  document.getElementById('landing').style.display = has ? 'none' : '';
  document.getElementById('sidebar').style.display = editorish ? '' : 'none';
  document.getElementById('mode-tabs').style.display = has ? 'flex' : 'none';
  document.getElementById('console').style.display = (has && mode === 'files') ? '' : 'none';
  document.getElementById('settings-pane').style.display = (has && mode === 'settings') ? '' : 'none';
  Array.prototype.forEach.call(document.querySelectorAll('.mode-tab'), function(t) {
    t.classList.toggle('active', t.getAttribute('data-mode') === mode);
  });
  document.getElementById('sb-head').textContent = mode === 'files' ? 'files' : 'tools';
  document.getElementById('ft-new').style.display = editorish ? 'flex' : 'none';
  document.getElementById('ft-new-name').placeholder =
    mode === 'files' ? 'path/to/new-file.md' : 'lib/tools/new-tool.hoon';
  if (mode === 'settings') { renderSettings(); }
  renderFiles();
  renderTabs();
  mountEditor();
}
var PERM_CATS = [
  { k: 'poke', label: 'message (poke)' },
  { k: 'peek', label: 'read (peek)' },
  { k: 'make', label: 'create / edit / delete (make)' }
];
function renderPermissions() {
  var pane = document.getElementById('tool-sub-permissions');
  if (!pane) return;
  // While editing, NEVER re-render from a poll — it would wipe selections.
  // Render the edit form once (when entering edit mode) and leave it alone.
  if (permEdit) { if (!pane.querySelector('.perm-apply')) renderPermEdit(pane); return; }
  renderPermView(pane);
}
function renderPermView(pane) {
  var totalActive = PERM_CATS.reduce(function(n, c) { return n + wRoads(weirAct, c.k).length; }, 0);
  var html = '<div class="perm-bar"><div class="perm-title">sandbox — the weir on <code>/tools/proc</code></div>' +
    '<button class="hdr-btn perm-editbtn">edit</button></div>';
  if (!totalActive) {
    html += '<div class="perm-jailed">🔒 <b>jailed</b> — every road below is blocked; tools can only touch their own folder.</div>';
  }
  PERM_CATS.forEach(function(c) {
    var act = wRoads(weirAct, c.k);
    var reqOnly = wRoads(weirReq, c.k).filter(function(r) { return act.indexOf(r) < 0; });
    html += '<div class="perm-cat"><div class="perm-cat-head">' + c.label + '</div>';
    if (!act.length && !reqOnly.length) html += '<div class="perm-empty">blocked — no roads</div>';
    act.forEach(function(road) {
      html += '<div class="perm-row"><code>' + esc(road) + '</code>' +
        '<span class="perm-chip perm-active">active</span></div>';
    });
    reqOnly.forEach(function(road) {
      var rq = (weirReq[c.k] || []).filter(function(x) { return x && typeof x === 'object' && x.road === road; })[0];
      var why = (rq && rq.why) ? '<span class="perm-why">' + esc(rq.why) + '</span>' : '';
      html += '<div class="perm-row"><code>' + esc(road) + '</code>' +
        '<span class="perm-chip perm-requested">requested</span>' + why + '</div>';
    });
    html += '</div>';
  });
  pane.innerHTML = html;
  pane.querySelector('.perm-editbtn').onclick = function() { permEdit = true; renderPermissions(); };
}
function renderPermEdit(pane) {
  var html = '<div class="perm-bar"><div class="perm-title">edit sandbox</div>' +
    '<button class="hdr-btn perm-cancel">cancel</button></div>' +
    '<div class="perm-intro">Checked = allowed in the sandbox you’re about to apply. ' +
    'Amber = the tools <b>requested</b> it but it isn’t granted yet. Add custom paths per row.</div>';
  PERM_CATS.forEach(function(c) {
    var act = wRoads(weirAct, c.k);
    var all = act.slice();
    wRoads(weirReq, c.k).forEach(function(r) { if (all.indexOf(r) < 0) all.push(r); });
    html += '<div class="perm-cat"><div class="perm-cat-head">' + c.label + '</div>';
    if (!all.length) html += '<div class="perm-empty">nothing granted or requested</div>';
    all.forEach(function(road) {
      var isAct = act.indexOf(road) >= 0;
      var chip = isAct
        ? '<span class="perm-chip perm-active">active</span>'
        : '<span class="perm-chip perm-requested">requested</span>';
      var rq = (weirReq[c.k] || []).filter(function(x) { return x && typeof x === 'object' && x.road === road; })[0];
      var why = (rq && rq.why) ? '<span class="perm-why">' + esc(rq.why) + '</span>' : '';
      html += '<label class="perm-row"><input type="checkbox" class="perm-cb" data-cat="' + c.k + '" data-road="' + esc(road) + '" data-base="' + (isAct ? '1' : '0') + '"' + (isAct ? ' checked' : '') + '>' +
        '<code>' + esc(road) + '</code>' + chip + why + '<span class="perm-delta"></span></label>';
    });
    html += '<div class="perm-add"><input class="perm-add-in" data-cat="' + c.k + '" placeholder="add a path — /sys/iris/ , /apps/foo/ …"></div></div>';
  });
  html += '<div class="perm-foot"><span class="perm-note"></span>' +
    '<button class="hdr-btn primary perm-apply" disabled>no changes</button></div>';
  pane.innerHTML = html;
  var btn = pane.querySelector('.perm-apply');
  var note = pane.querySelector('.perm-note');

  function gather() {
    var weir = { make: [], poke: [], peek: [] };
    Array.prototype.forEach.call(pane.querySelectorAll('.perm-cb'), function(cb) {
      if (cb.checked) weir[cb.getAttribute('data-cat')].push(cb.getAttribute('data-road'));
    });
    Array.prototype.forEach.call(pane.querySelectorAll('.perm-add-in'), function(inp) {
      inp.value.split(/[\n,]/).map(function(s) { return s.trim(); }).filter(Boolean).forEach(function(p) {
        if (weir[inp.getAttribute('data-cat')].indexOf(p) < 0) weir[inp.getAttribute('data-cat')].push(p);
      });
    });
    return weir;
  }
  function refresh() {
    var adds = 0, revs = 0;
    Array.prototype.forEach.call(pane.querySelectorAll('.perm-cb'), function(cb) {
      var base = cb.getAttribute('data-base') === '1';
      var d = cb.parentNode.querySelector('.perm-delta');
      if (cb.checked && !base) { d.textContent = '+ granting'; d.className = 'perm-delta perm-add-d'; adds++; }
      else if (!cb.checked && base) { d.textContent = '− revoking'; d.className = 'perm-delta perm-rev-d'; revs++; }
      else { d.textContent = ''; d.className = 'perm-delta'; }
    });
    var newPaths = 0;
    Array.prototype.forEach.call(pane.querySelectorAll('.perm-add-in'), function(inp) {
      newPaths += inp.value.split(/[\n,]/).map(function(s) { return s.trim(); }).filter(Boolean).length;
    });
    var changes = adds + revs + newPaths;
    btn.disabled = !changes;
    btn.textContent = changes ? 'apply sandbox' : 'no changes';
    var bits = [];
    if (adds + newPaths) bits.push('+' + (adds + newPaths) + ' granted');
    if (revs) bits.push('−' + revs + ' revoked');
    note.textContent = changes ? bits.join(', ') : 'sandbox matches what’s enforced now';
  }
  pane.addEventListener('change', refresh);
  pane.addEventListener('input', refresh);
  refresh();

  pane.querySelector('.perm-cancel').onclick = function() { permEdit = false; renderPermissions(); };
  btn.onclick = function() {
    btn.textContent = 'applying…';
    btn.disabled = true;
    post('/weir', { repo: selected, weir: gather() }).then(function() {
      permEdit = false;
      setTimeout(function() { loadTools(); }, 700);
    });
  };
}
function renderSettings() {
  var r = repos.find(function(x) { return x.name === selected; }) || {};
  var pane = document.getElementById('settings-pane');
  pane.innerHTML =
    '<div class="set-section"><div class="run-head">origin</div>' +
    '<label class="m-label">repository <input id="set-origin" type="text" value="' + esc(r.repo || '') + '" placeholder="owner/repo"></label>' +
    '<label class="m-label">ref <input id="set-ref" type="text" value="' + esc(r.ref || '') + '" placeholder="main"></label>' +
    '<label class="m-label">token <span class="hint">(write to change; never shown)</span> <input id="set-token" type="text" placeholder="unchanged"></label>' +
    '<label class="m-label">account <span class="hint">(github login to act as; empty = first connected)</span> <input id="set-account" type="text" value="' + esc(r.account || '') + '" placeholder="first"></label>' +
    '<label class="m-label">poll <span class="hint">(minutes between fetches; 0 = only on demand)</span> <input id="set-poll" type="number" min="0" value="' + esc(String(r.poll == null ? '' : r.poll)) + '" placeholder="15"></label>' +
    '<button class="hdr-btn primary" id="set-save">save config</button></div>' +
    '<div class="set-section"><div class="run-head">actions</div>' +
    '<div class="set-act"><button class="hdr-btn" data-sact="sync">sync</button><span>fetch from the remote and check out the configured ref</span></div>' +
    '<div class="set-act"><button class="hdr-btn" data-sact="push">push</button><span>publish local commits to the remote</span></div>' +
    '<div class="set-act"><button class="hdr-btn" data-sact="stash">stash</button><span>set aside staged changes and reset to HEAD</span></div>' +
    '<div class="set-act"><button class="hdr-btn" data-sact="stash-pop">stash pop</button><span>restore the most recent stash</span></div></div>' +
    '<div class="set-section danger-zone"><div class="run-head">danger</div>' +
    '<div class="set-act"><button class="hdr-btn red" id="set-delete">delete repo</button><span>permanently removes the instance, its tree, tools, and procs</span></div></div>';
  pane.querySelector('#set-save').onclick = function() {
    var pollRaw = document.getElementById('set-poll').value.trim();
    var cfg = {
      repo: selected,
      origin: document.getElementById('set-origin').value.trim(),
      ref: document.getElementById('set-ref').value.trim(),
      token: document.getElementById('set-token').value.trim(),
      account: document.getElementById('set-account').value.trim()
    };
    if (pollRaw !== '' && !isNaN(Number(pollRaw))) { cfg.poll = Number(pollRaw); }
    post('/config', cfg).then(function(r2) {
      if (r2.ok) { refreshSoon(); } else { alert('save failed'); }
    });
  };
  Array.prototype.forEach.call(pane.querySelectorAll('[data-sact]'), function(b) {
    b.onclick = function() {
      post('/action', { repo: selected, action: b.getAttribute('data-sact') }).then(refreshSoon);
    };
  });
  pane.querySelector('#set-delete').onclick = function() {
    var word = prompt('CAREFUL: this permanently deletes ' + selected + '. Type "' + shortName(selected) + '" to confirm:');
    if (word !== shortName(selected)) return;
    post('/delete', { repo: selected }).then(function() {
      selected = null;
      tabsBy = { files: [], tools: [] };
      focusBy = { files: null, tools: null };
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
Array.prototype.forEach.call(document.querySelectorAll('.tool-subtab'), function(s) {
  s.onclick = function() {
    toolSub = s.getAttribute('data-sub');
    if (toolSub === 'permissions') { permEdit = false; loadTools(); }
    mountEditor();
  };
});

// ── repo list (sidebar) ──
function loadRepos() {
  get('/list').then(function(rs) {
    repos = rs;
    renderLanding();
    renderRepoMenu();
    renderTopbar();
  });
}
function enterRepo(name) {
  if (name === selected) return;
  selected = name;
  tabsBy = { files: [], tools: [] };
  focusBy = { files: null, tools: null };
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
          ' — its tree, tools, and procs. Type "' + shortName(name) + '" to confirm:');
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
    document.getElementById('sb-list').innerHTML = '';
    ['status', 'history'].forEach(function(p) {
      document.getElementById('pane-' + p).innerHTML = '';
    });
    return;
  }
  loadTools();
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

// ── file tree (sidebar) ──
function treeRows(paths, root, withMarks) {
  var seen = {};
  var rows = [];
  paths.forEach(function(f) {
    var segs = f.split('/');
    for (var d = 0; d < segs.length - 1; d++) {
      var dir = segs.slice(0, d + 1).join('/');
      if (!seen[dir]) {
        seen[dir] = true;
        rows.push('<div class="ft-dir" style="padding-left:' + (12 + d * 12) + 'px">' +
          esc(segs[d]) + '/</div>');
      }
    }
    var depth = segs.length - 1;
    var base = segs[segs.length - 1];
    var mark = '';
    if (withMarks) {
      var def = defForFile(f);
      mark = def
        ? (def.error
          ? ' <span class="ft-err" title="build error">✕</span>'
          : ' <span class="ft-tool" data-run="1" title="show in tools">▸</span>')
        : '';
    }
    var del = '<span class="ft-x" data-del="' + esc(f) + '" title="delete file">×</span>';
    var id = root + ':' + f;
    rows.push('<div class="ft-file' + (id === focusedF() ? ' sel' : '') +
      '" data-root="' + root + '" data-file="' + esc(f) + '">' +
      '<span style="padding-left:' + (depth * 12) + 'px">' + esc(base) + '</span>' + mark + del + '</div>');
  });
  return rows.join('');
}
function renderFiles() {
  var box = document.getElementById('sb-list');
  if (!selected) { box.innerHTML = ''; return; }
  box.innerHTML = mode === 'files'
    ? treeRows(tree, 'tree', false)
    : treeRows(files.filter(function(f) { return f !== 'weir.json' && f !== 'procs.json'; }), 'tools', true);
  wireFileRows(box);
}
function wireFileRows(box) {
  Array.prototype.forEach.call(box.querySelectorAll('.ft-file'), function(el) {
    el.onclick = function(e) {
      var f = el.getAttribute('data-file');
      var root = el.getAttribute('data-root');
      var id = root + ':' + f;
      if (e.target.hasAttribute('data-del')) {
        if (!confirm('delete ' + f + '?')) return;
        post('/src-delete', { repo: selected, file: f, root: root }).then(function() {
          var t = tabFor(id);
          if (t) { t.dirty = false; closeTab(id); }
          loadTools();
          if (root === 'tree') loadDetail();
        });
        return;
      }
      if (e.target.hasAttribute('data-run')) {
        focusBy.tools = null;
        pushUrl();
        renderTabs();
        mountEditor();
        return;
      }
      openFile(id);
    };
  });
}
document.getElementById('ft-create').onclick = function() {
  var name = document.getElementById('ft-new-name').value.trim();
  if (!name || !selected) return;
  var root = mode === 'files' ? 'tree' : 'tools';
  var seed = root === 'tools' ? '::  ' + name + '\n' : '';
  post('/src', { repo: selected, file: name, root: root, text: seed })
    .then(function() {
      document.getElementById('ft-new-name').value = '';
      loadTools();
      openFile(root + ':' + name);
    });
};

// ── tools + procs ──
function defForFile(f) {
  var base = f.split('/').pop().replace(/\.hoon$/, '');
  for (var i = 0; i < toolDefs.length; i++) {
    if (toolDefs[i].file === base) return toolDefs[i];
  }
  return null;
}
var lastDefs = '';
var lastFiles = '';
function loadTools() {
  if (!selected) return;
  get('/tools?repo=' + encodeURIComponent(selected)).then(function(t) {
    toolDefs = t.tools || [];
    weirReq = t['weir-requested'] || {};
    weirAct = t['weir-active'] || {};
    if (mode === 'tools' && toolSub === 'permissions') renderPermissions();
    updateTang();
    files = t.files || [];
    tree = t.tree || [];
    procs = t.procs || [];
    var dj = JSON.stringify(toolDefs);
    var fj = JSON.stringify(files) + '|' + JSON.stringify(tree);
    var rt = document.getElementById('run-tools');
    var typing = document.activeElement && rt && rt.contains(document.activeElement);
    if (fj !== lastFiles) { lastFiles = fj; renderFiles(); }
    if (dj !== lastDefs && !typing) { lastDefs = dj; renderToolCards(); }
    renderProcs();
  });
}
var procs = [];
function wRoads(obj, cat) {
  return (obj[cat] || []).map(function(r) {
    return (r && typeof r === 'object') ? r.road : r;
  }).filter(Boolean);
}
function renderToolCards() {
  var box = document.getElementById('run-tools');
  var html = '';
  if (!toolDefs.length) html += '<div class="empty">no tools — create one in lib/tools/</div>';
  toolDefs.forEach(function(d, i) {
    if (d.error) {
      html += '<div class="tool-card"><div class="tc-head"><span class="p-name">' + esc(d.file) + '</span>' +
        '<button class="hdr-btn tc-edit" data-file="lib/tools/' + esc(d.file) + '.hoon">edit</button></div>' +
        '<div class="p-result err">' + esc(d.error) + '</div></div>';
      return;
    }
    var params = Object.keys(d.parameters || {}).map(function(k) {
      var req = (d.required || []).indexOf(k) >= 0;
      var desc = (d.parameters[k] || {}).description || '';
      return '<label class="tc-param">' + esc(k) + (req ? ' *' : '') +
        '<input data-tool="' + i + '" data-param="' + esc(k) + '" type="text" placeholder="' + esc(desc) + '"></label>';
    }).join('');
    html += '<div class="tool-card">' +
      '<div class="tc-head"><span class="p-name">' + esc(d.name) + '</span>' +
      '<span class="t-desc">' + esc(d.description || '') + '</span>' +
      '<button class="hdr-btn tc-edit" data-file="lib/tools/' + esc(d.file) + '.hoon">edit</button></div>' +
      params +
      '<div class="tc-run"><input data-tool="' + i + '" data-procname="1" type="text" placeholder="proc name">' +
      '<button class="hdr-btn primary tc-go" data-tool="' + i + '">run</button></div>' +
      '</div>';
  });
  box.innerHTML = html;
  Array.prototype.forEach.call(box.querySelectorAll('.tc-go'), function(b) {
    b.onclick = function() { runFromCard(box, +b.getAttribute('data-tool')); };
  });
  Array.prototype.forEach.call(box.querySelectorAll('.tc-edit'), function(b) {
    b.onclick = function() {
      openFile('tools:' + b.getAttribute('data-file'));
    };
  });
}
function renderProcs() {
  var box = document.getElementById('run-procs');
  var html = '';
  if (!procs.length) html += '<div class="empty">nothing installed</div>';
  procs.forEach(function(p) {
    var res = p.result;
    var resHtml = '';
    if (res && res.type === 'text') resHtml = '<div class="p-result">' + esc(res.text) + '</div>';
    else if (res && res.type === 'error') resHtml = '<div class="p-result err">' + esc(res.message) + '</div>';
    else if (res) resHtml = '<button class="hdr-btn p-out" data-out="' + esc(p.name) + '">output</button>';
    html += '<div class="proc">' +
      '<span class="p-name">' + esc(p.name) + '</span>' +
      '<span class="chip">' + esc(p.tool || '') + '</span>' +
      '<span class="p-step ' + (p.step === 'done' ? 'ok' : 'live') + '">' + esc(p.step || '?') + '</span>' +
      '<button class="hdr-btn danger p-del" data-proc="' + esc(p.name) + '">delete</button>' +
      resHtml + '</div>';
  });
  box.innerHTML = html;
  Array.prototype.forEach.call(box.querySelectorAll('.p-del'), function(b) {
    b.onclick = function() {
      post('/cull', { repo: selected, proc: b.getAttribute('data-proc') }).then(refreshSoon);
    };
  });
  Array.prototype.forEach.call(box.querySelectorAll('.p-out'), function(b) {
    b.onclick = function() {
      var p = procs.find(function(x) { return x.name === b.getAttribute('data-out'); });
      if (p) showJson(p.name + ' — ' + (p.tool || ''), p.result);
    };
  });
}
function showJson(title, obj) {
  document.getElementById('json-title').textContent = title;
  document.getElementById('json-pre').textContent = JSON.stringify(obj, null, 2);
  document.getElementById('json-back').classList.add('open');
}
document.getElementById('json-close').onclick = function() {
  document.getElementById('json-back').classList.remove('open');
};
document.getElementById('json-back').onclick = function(e) {
  if (e.target === document.getElementById('json-back')) e.target.classList.remove('open');
};
function runFromCard(box, i) {
  var d = toolDefs[i];
  var nameInp = box.querySelector('input[data-procname][data-tool="' + i + '"]');
  var procName = nameInp.value.trim();
  if (!procName) { nameInp.focus(); return; }
  var args = {};
  Array.prototype.forEach.call(
    box.querySelectorAll('input[data-param][data-tool="' + i + '"]'),
    function(inp) {
      var v = inp.value.trim();
      if (v) args[inp.getAttribute('data-param')] = v;
    });
  post('/run', { repo: selected, name: procName, tool: d.name, args: args }).then(refreshSoon);
}

// ── detail: status + history panes ──
function loadDetail() {
  if (!selected) return;
  get('/detail?repo=' + encodeURIComponent(selected)).then(function(d) {
    var r = repos.find(function(x) { return x.name === selected; });
    if (r) r.current = d.current || r.current;
    branches = d.branches || [];
    renderTopbar();
    renderStatus(d.status || {});
    renderHistory(d.commits || []);
  });
}
function renderStatus(st) {
  var pane = document.getElementById('pane-status');
  var groups = [
    ['staged', st.staged || [], 'ok'],
    ['unstaged', st.unstaged || [], 'warn'],
    ['untracked', st.untracked || [], 'muted']
  ];
  var html = groups.map(function(g) {
    if (!g[1].length) return '';
    return '<div class="st-group"><div class="st-title ' + g[2] + '">' + g[0] +
      ' (' + g[1].length + ')</div>' +
      g[1].map(function(f) {
        var p = typeof f === 'string' ? f : (f.path || JSON.stringify(f));
        return '<div class="st-file">' + esc(p) + '</div>';
      }).join('') + '</div>';
  }).join('');
  if (!html) html = '<div class="empty">working tree clean</div>';
  html += '<div class="st-acts">' +
    '<button class="hdr-btn" id="st-add">stage all</button>' +
    '<button class="hdr-btn" id="st-stash">stash</button>' +
    '<input id="st-msg" type="text" placeholder="commit message">' +
    '<button class="hdr-btn primary" id="st-commit">commit</button></div>';
  pane.innerHTML = html;
  document.getElementById('st-add').onclick = function() {
    post('/action', { repo: selected, action: 'add' }).then(refreshSoon);
  };
  document.getElementById('st-stash').onclick = function() {
    post('/action', { repo: selected, action: 'stash' }).then(refreshSoon);
  };
  document.getElementById('st-commit').onclick = function() {
    var msg = document.getElementById('st-msg').value.trim();
    if (!msg) return;
    post('/action', { repo: selected, action: 'commit', text: msg }).then(refreshSoon);
  };
}
function renderHistory(commits) {
  var pane = document.getElementById('pane-history');
  if (!commits.length) {
    pane.innerHTML = '<div class="empty">no commits</div>';
    return;
  }
  pane.innerHTML = '<div class="hist-acts"><button class="hdr-btn" id="hist-push">push</button></div>' +
  commits.map(function(c) {
    var refs = (c.refs || []).map(function(r) {
      return '<span class="chip">' + esc(r) + '</span>';
    }).join(' ');
    return '<div class="commit">' +
      '<span class="c-hash">' + esc(String(c.short || c.hash || '').slice(0, 7)) + '</span>' +
      '<span class="c-msg">' + esc(c.message || '') + '</span> ' + refs +
      '<span class="c-author">' + esc(c.author || '') + '</span>' +
      '</div>';
  }).join('');
  var pb = pane.querySelector('#hist-push');
  if (pb) pb.onclick = function() {
    post('/action', { repo: selected, action: 'push' }).then(refreshSoon);
  };
}

// ── editor tabs ──
function tabFor(f) {
  return openTabs().find(function(t) { return t.file === f; });
}
function splitId(id) {
  var i = id.indexOf(':');
  return i < 0 ? { root: 'tools', file: id } : { root: id.slice(0, i), file: id.slice(i + 1) };
}
function openFile(id, fromUrl) {
  if (id.indexOf(':') < 0) id = (mode === 'files' ? 'tree:' : 'tools:') + id;
  var t = tabFor(id);
  if (t) {
    focusBy[mode] = id;
    if (!fromUrl) pushUrl();
    renderTabs();
    renderFiles();
    mountEditor();
    return;
  }
  var s = splitId(id);
  get('/src?repo=' + encodeURIComponent(selected) + '&file=' + encodeURIComponent(s.file) +
      '&root=' + s.root)
    .then(function(d) {
      openTabs().push({ file: id, text: d.text || '', dirty: false });
      focusBy[mode] = id;
      if (!fromUrl) pushUrl();
      renderTabs();
      renderFiles();
      mountEditor();
    });
}
function closeTab(f) {
  var t = tabFor(f);
  if (t && t.dirty && !confirm('discard unsaved changes to ' + f + '?')) return;
  tabsBy[mode] = openTabs().filter(function(x) { return x.file !== f; });
  if (focusedF() === f) {
    var ts = openTabs();
    focusBy[mode] = ts.length ? ts[ts.length - 1].file : null;
  }
  pushUrl();
  renderTabs();
  renderFiles();
  mountEditor();
}
function renderTabs() {
  var focused = focusedF();
  var t = focused ? tabFor(focused) : null;
  var sv = document.getElementById('ed-save');
  sv.style.display = t ? '' : 'none';
  sv.disabled = !(t && t.dirty);
  sv.classList.toggle('primary', !!(t && t.dirty));
  var bar = document.getElementById('ed-tabs');
  var html = '';
  if (mode === 'tools') {
    html += '<div class="ed-tab runner-tab' + (focused === null ? ' active' : '') + '" data-runner="1">▸ runner</div>';
  }
  html += openTabs().map(function(t) {
    var s = splitId(t.file);
    return '<div class="ed-tab' + (t.file === focused ? ' active' : '') + '" data-file="' + esc(t.file) + '" title="' + esc(s.root + '/' + s.file) + '">' +
      (t.dirty ? '<span class="dot">●</span>' : '') +
      esc(s.file.split('/').pop()) +
      '<span class="x" data-close="' + esc(t.file) + '">×</span></div>';
  }).join('');
  bar.innerHTML = html;
  Array.prototype.forEach.call(bar.querySelectorAll('.ed-tab'), function(el) {
    el.onclick = function(e) {
      if (e.target.hasAttribute('data-close')) {
        closeTab(e.target.getAttribute('data-close'));
        return;
      }
      if (el.hasAttribute('data-runner')) {
        focusBy.tools = null;
        pushUrl();
        renderTabs();
        renderFiles();
        mountEditor();
        return;
      }
      focusBy[mode] = el.getAttribute('data-file');
      pushUrl();
      renderTabs();
      renderFiles();
      mountEditor();
    };
  });
}

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
  var el = document.getElementById('ed-tang');
  var focused = focusedF();
  var err = null;
  if (focused && mode === 'tools') {
    var s = splitId(focused);
    var def = defForFile(s.file);
    if (def && def.error) err = def.error;
  }
  if (err) { el.textContent = err; el.style.display = ''; }
  else { el.style.display = 'none'; }
}
// ── file preview (Source | Preview toggle) ──
// render logic lives in the shared window.FilePreview helper (file-preview.js).
// forge has no raw-byte lane, so raster stays source-only here: only svg/html,
// which render straight from the buffer text, get a toggle.
function previewKind(name) {
  var k = window.FilePreview ? FilePreview.kind(name) : null;
  return (k === 'svg' || k === 'html') ? k : null;
}
function mountEditor() {
  var has = !!selected;
  var editorish = has && mode !== 'settings';
  var focused = focusedF();
  var t = focused ? tabFor(focused) : null;
  var runner = editorish && mode === 'tools' && !t;
  document.getElementById('ed-bar').style.display = editorish ? 'flex' : 'none';
  document.getElementById('runner-pane').style.display = runner ? '' : 'none';
  if (runner) {
    Array.prototype.forEach.call(document.querySelectorAll('.tool-subtab'), function(s) {
      s.classList.toggle('active', s.getAttribute('data-sub') === toolSub);
    });
    document.getElementById('tool-sub-run').style.display = toolSub === 'run' ? '' : 'none';
    document.getElementById('tool-sub-permissions').style.display = toolSub === 'permissions' ? '' : 'none';
    if (toolSub === 'permissions') renderPermissions();
  }
  document.getElementById('ed-wrap').style.display = (editorish && !runner) ? '' : 'none';
  document.getElementById('ws-empty').style.display = t ? 'none' : 'flex';
  updateTang();
  if (!t) {
    document.getElementById('ed-body').style.display = 'none';
    document.getElementById('ed-preview').style.display = 'none';
    document.getElementById('ed-view').style.display = 'none';
    return;
  }
  // Source | Preview: previewable files (svg/image/html) can toggle to a
  // rendered view; everything else stays source-only.
  var s = splitId(t.file);
  var kind = previewKind(s.file);
  var view = (kind && t.view === 'preview') ? 'preview' : 'source';
  var vbar = document.getElementById('ed-view');
  vbar.style.display = kind ? '' : 'none';
  Array.prototype.forEach.call(vbar.querySelectorAll('.ed-vtab'), function(b) {
    b.classList.toggle('active', b.getAttribute('data-view') === view);
  });
  document.getElementById('ed-body').style.display = view === 'source' ? '' : 'none';
  var prev = document.getElementById('ed-preview');
  prev.style.display = view === 'preview' ? '' : 'none';
  if (view === 'preview') { FilePreview.render(prev, { name: s.file, text: t.text }); return; }
  var ta = document.getElementById('ed-ta');
  var hl = document.getElementById('ed-hl');
  ta.value = t.text;
  highlightInto(hl, t.text);
  ensureShiki().then(function() { highlightInto(hl, ta.value); });
  var deb = null;
  ta.oninput = function() {
    t.text = ta.value;
    if (!t.dirty) { t.dirty = true; renderTabs(); }
    clearTimeout(deb);
    deb = setTimeout(function() { highlightInto(hl, ta.value); }, 150);
  };
  ta.onscroll = function() {
    hl.scrollTop = ta.scrollTop;
    hl.scrollLeft = ta.scrollLeft;
  };
  ta.onkeydown = function(e) {
    if ((e.metaKey || e.ctrlKey) && e.key === 's') {
      e.preventDefault();
      saveFocused();
    }
    if (e.key === 'Tab') {
      e.preventDefault();
      var s = ta.selectionStart;
      ta.value = ta.value.slice(0, s) + '  ' + ta.value.slice(ta.selectionEnd);
      ta.selectionStart = ta.selectionEnd = s + 2;
      ta.oninput();
    }
  };
}
function saveFocused() {
  var t = focusedF() ? tabFor(focusedF()) : null;
  if (!t) return;
  var s = splitId(t.file);
  post('/src', { repo: selected, file: s.file, root: s.root, text: t.text }).then(function(r) {
    if (r.ok) {
      t.dirty = false;
      renderTabs();
      setTimeout(loadTools, 2000);
    } else {
      alert('save failed');
    }
  });
}

document.getElementById('ed-save').onclick = saveFocused;

// ── console panel chrome ──
function renderPanelTabs() {
  Array.prototype.forEach.call(document.querySelectorAll('.con-tab'), function(t) {
    t.classList.toggle('active', t.getAttribute('data-panel') === panel);
  });
  ['status', 'history'].forEach(function(p) {
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
document.getElementById('sb-toggle').onclick = function() {
  document.getElementById('body').toggle();  // <split-view> collapses the sidebar
};
document.getElementById('ed-view').addEventListener('click', function(e) {
  var b = e.target.closest('.ed-vtab');
  if (!b) return;
  var f = focusedF();
  var t = f ? tabFor(f) : null;
  if (!t) return;
  t.view = b.getAttribute('data-view');
  mountEditor();
});

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
      post('/action', { repo: selected, action: 'switch', text: b }).then(refreshSoon);
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
    post('/action', { repo: selected, action: 'branch', text: name }).then(refreshSoon);
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

function refreshSoon() {
  setTimeout(function() { loadTools(); loadDetail(); loadRepos(); }, 1200);
  setTimeout(function() { loadTools(); loadDetail(); }, 4000);
}

// ── boot ──
loadRepos();
applyUrl();
pushUrl(true);
setInterval(function() {
  if (selected) { loadDetail(); if (mode === 'tools') loadTools(); }
}, 8000);
