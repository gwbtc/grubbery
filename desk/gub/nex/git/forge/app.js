var BASE = '/grubbery/forge';
var API = BASE + '/api';

// ── state ──
var repos = [];            // repo cards from /api/list
var selected = null;       // full instance name, e.g. contacts.git_repo
var lane = null;           // command lane state {queue, active, log} for selected repo
var branches = [];         // local branch names for selected repo
var mode = 'files';        // workspace mode: files (repo) | settings
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
function shortName(n) {
  return n && n.slice(-9) === '.git_repo' ? n.slice(0, -9) : n;
}
function fullName(n) {
  return n && n.slice(-9) !== '.git_repo' ? n + '.git_repo' : n;
}

// ── the working tree: the explorer ──
// Browsing and editing a repo's files is the explorer's job. The selected
// repo gets one <namespace-explorer> (the explorer's browse.js as a web
// component) mounted in #repo-explorer, rooted at the repo's data/tree, in the
// finder view: tree on the left, location tabs with FileView on the right,
// the explorer's own row menu (new file, rename, delete…), its manage menu
// and its sandbox chip. page:false — forge owns the url, the title and the
// layout; the explorer keeps its tabs and tree state under its own storage
// prefix, per repo (its keys carry the root). A repo switch replaces the
// element: an explorer mounts once.
var explorerEl = null;
function treeRoot(name) { return '/apps/forge.git_forge/repos/' + name + '/data/tree'; }
function mountExplorer(name) {
  unmountExplorer();
  var host = document.getElementById('repo-explorer');
  explorerEl = document.createElement('namespace-explorer');
  host.appendChild(explorerEl);
  explorerEl.mount({
    url: '/grubbery/ball' + treeRoot(name),
    mount: { route: BASE + '/repo/' + encodeURIComponent(shortName(name)), root: treeRoot(name), title: shortName(name) },
    page: false,
    storageKey: 'forge',
    view: 'cols'
  });
}
function unmountExplorer() {
  if (explorerEl) { explorerEl.remove(); explorerEl = null; }
}

// ── url routing: /repo/<short>/<mode>?panel=.. ──
// (the open files are the explorer's own tabs, kept in its storage, not the url)
function urlState() {
  var m = location.pathname.match(/\/forge\/repo\/([^\/]+)(?:\/(files|settings))?/);
  var q = new URLSearchParams(location.search);
  return {
    repo: m ? fullName(decodeURIComponent(m[1])) : null,
    mode: (m && m[2]) || 'files',
    panel: q.get('panel') || 'status'
  };
}
function pushUrl(replace) {
  var u = BASE;
  if (selected) {
    u += '/repo/' + encodeURIComponent(shortName(selected)) + '/' + mode;
  }
  var q = new URLSearchParams();
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
    onRepoChanged();
  }
  renderMode();
}
function renderMode() {
  var has = !!selected;
  var editorish = has && mode !== 'settings';
  document.getElementById('landing').style.display = has ? 'none' : '';
  document.getElementById('repo-explorer').style.display = editorish ? '' : 'none';
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
  // a Docs link to the per-repo handbook reader (a real page, path-segment
  // scoped: /repo/<short>/docs) — sits in the mode-tabs bar beside files/settings
  var dl = document.getElementById('mode-docs-link');
  if (has) {
    if (!dl) {
      dl = document.createElement('a');
      dl.id = 'mode-docs-link'; dl.className = 'mode-tab'; dl.textContent = 'docs';
      document.getElementById('mode-tabs').appendChild(dl);
    }
    dl.href = '/grubbery/forge/repo/' + encodeURIComponent(shortName(selected)) + '/docs';
    dl.style.display = '';
  } else if (dl) { dl.style.display = 'none'; }
  if (mode === 'settings') { renderSettings(); }
  // the explorer for this repo, mounted once per selection
  if (editorish && (!explorerEl || explorerEl.dataset.repo !== selected)) {
    mountExplorer(selected);
    explorerEl.dataset.repo = selected;
  }
  if (!has) unmountExplorer();
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
      unmountExplorer();
      selected = null;
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
  selected = name;
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

// ── detail: status + history panes ──
function loadDetail() {
  if (!selected) return;
  get('/detail?repo=' + encodeURIComponent(selected)).then(function(d) {
    var r = repos.find(function(x) { return x.name === selected; });
    if (r) r.current = d.current || r.current;
    branches = d.branches || [];
    lane = d.lane || null;
    renderTopbar();
    renderStatus(d.status || {}, d.current || {}, d.stash || []);
    renderHistory(d.commits || []);
    renderLane();
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
  // the explorer's own sidebar split (its tree); nothing to toggle without a repo
  var sv = explorerEl && explorerEl.querySelector('#finder');
  if (sv) sv.toggle();
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
// browse.js is a module (deferred): the explorer element exists only after it
// runs, so the first render waits for the definition.
customElements.whenDefined('namespace-explorer').then(function() {
  loadRepos();
  applyUrl();
  pushUrl(true);
  setInterval(function() {
    if (selected) { loadDetail(); }
  }, 8000);
});
