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
    selected = st.repo;
    tabsBy = { files: [] };
    focusBy = { files: null };
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
  // settings is a full-bleed view outside the split nest: swap #main out for it.
  var settingsOn = has && mode === 'settings';
  document.getElementById('settings-pane').style.display = settingsOn ? '' : 'none';
  document.getElementById('main').style.display = settingsOn ? 'none' : '';
  // no console outside files (transient, doesn't touch the saved layout).
  document.getElementById('main').toggleAttribute('hide-primary', !(has && mode === 'files'));
  Array.prototype.forEach.call(document.querySelectorAll('.mode-tab'), function(t) {
    t.classList.toggle('active', t.getAttribute('data-mode') === mode);
  });
  document.getElementById('sb-head').textContent = 'files';
  document.getElementById('ft-new').style.display = editorish ? 'flex' : 'none';
  document.getElementById('ft-new-name').placeholder = 'path/to/new-file.md';
  if (mode === 'settings') { renderSettings(); }
  renderFiles();
  renderTabs();
  mountEditor();
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
    '<div class="set-section danger-zone"><div class="run-head">danger</div>' +
    '<div class="set-act"><button class="hdr-btn red" id="set-delete">delete repo</button><span>permanently removes the instance and its working tree</span></div></div>';
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
  pane.querySelector('#set-delete').onclick = function() {
    var word = prompt('CAREFUL: this permanently deletes ' + selected + '. Type "' + shortName(selected) + '" to confirm:');
    if (word !== shortName(selected)) return;
    post('/delete', { repo: selected }).then(function() {
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
    renderRepoMenu();
    renderTopbar();
  });
}
function enterRepo(name) {
  if (name === selected) return;
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
    document.getElementById('sb-list').innerHTML = '';
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

// ── file tree (sidebar) ──
function treeRows(paths, root) {
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
  box.innerHTML = treeRows(tree, 'tree');
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
          loadDetail();
        });
        return;
      }
      openFile(id);
    };
  });
}
document.getElementById('ft-create').onclick = function() {
  var name = document.getElementById('ft-new-name').value.trim();
  if (!name || !selected) return;
  var root = 'tree';
  var seed = '';
  post('/src', { repo: selected, file: name, root: root, text: seed })
    .then(function() {
      document.getElementById('ft-new-name').value = '';
      loadDetail();
      openFile(root + ':' + name);
    });
};

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
    renderStatus(d.status || {});
    renderHistory(d.commits || []);
    renderLane();
    renderFiles();
  });
}
// ── command lane: type git commands, they run through /actions/run ──
function renderLane() {
  var log = document.getElementById('lane-log');
  var entries = (lane && lane.log) || [];
  if (lane && lane.active) {
    log.innerHTML = '<div class="lane-line running"><span class="lane-dot">▸</span>' +
      esc(lane.active.raw) + ' <span class="lane-msg">running…</span></div>';
  } else {
    log.innerHTML = '';
  }
  log.innerHTML += entries.map(function(e) {
    var cls = e.ok ? 'ok' : 'err';
    return '<div class="lane-line ' + cls + '"><span class="lane-dot">' + (e.ok ? '✓' : '✕') + '</span>' +
      '<span class="lane-cmd">' + esc(e.raw) + '</span> <span class="lane-msg">' + esc(e.message || '') + '</span></div>';
  }).join('');
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
        var s = (typeof f === 'object' && f.status) ? f.status : '';
        var mark = s
          ? '<span class="st-mark st-mark-' + esc(s) + '" title="' + esc(s) + '">' + esc(s.charAt(0).toUpperCase()) + '</span>'
          : '';
        return '<div class="st-file">' + mark + '<span class="st-path">' + esc(p) + '</span></div>';
      }).join('') + '</div>';
  }).join('');
  if (!html) html = '<div class="empty">working tree clean</div>';
  pane.innerHTML = html;
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
function openFile(id, fromUrl) {
  if (id.indexOf(':') < 0) id = 'tree:' + id;
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
  document.getElementById('ed-tang').style.display = 'none';
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
  document.getElementById('ed-bar').style.display = editorish ? 'flex' : 'none';
  document.getElementById('ed-wrap').style.display = editorish ? '' : 'none';
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
      setTimeout(loadDetail, 2000);
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
