// forge viewers: the explorer renders a repo's ui grubs through these.
// Served at /grubbery/forge/viewers.js; named by /grubbery/forge/api/viewers,
// which also declares what each instance FOLLOWS, so the explorer's stream
// hands these onUpdate the new grub body the moment it moves. Nothing here
// polls or opens a connection.
//
//   forge-log   data/ui/commits.json   a branch picker (checks out through
//                                      /api/run) over the log, HEAD marked
//
// mount(root, {url, args: {repo, api, base}, onNavigate}) -> {destroy, onUpdate(ev)}
// ev = {road, kind, path, body}; body is the grub as json for body:true follows.
(function () {
  window.Viewers = window.Viewers || {};
  var CSS = 'forge-viewers-css';
  function css() {
    if (document.getElementById(CSS)) return;
    var s = document.createElement('style'); s.id = CSS;
    s.textContent =
      '.fgv{font:13px -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:#24292f;height:100%;overflow:auto;background:#fff}' +
      '.fgv .mono{font:12px ui-monospace,SFMono-Regular,Menlo,monospace}' +
      '.fgv-head{display:flex;align-items:center;gap:10px;padding:8px 12px;border-bottom:1px solid #d0d7de;background:#f6f8fa}' +
      '.fgv-head select{font:inherit;padding:3px 6px;border:1px solid #d0d7de;border-radius:6px;background:#fff}' +
      '.fgv-head .hash{color:#57606a}.fgv-head .busy{color:#9a6700}' +
      '.fgv-log{list-style:none;margin:0;padding:0}' +
      '.fgv-log li{display:grid;grid-template-columns:64px 1fr auto;gap:10px;padding:6px 12px;border-bottom:1px solid #eaeef2;align-items:baseline}' +
      '.fgv-log li.head{background:#ddf4ff}' +
      '.fgv-log .short{color:#0969da}.fgv-log .msg{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +
      '.fgv-log .who{color:#57606a;font-size:12px;white-space:nowrap}' +
      '.fgv-log .ref{display:inline-block;margin-left:6px;padding:0 5px;border:1px solid #d0d7de;border-radius:10px;font-size:11px;color:#57606a}' +
      '.fgv-empty{padding:14px;color:#8b949e}' +
      '.fgv-st{padding:10px 12px}.fgv-st .st-head{margin-bottom:10px}.fgv-st .st-ahead{color:#9a6700;margin-left:8px}' +
      '.fgv-st .st-group{margin-bottom:10px}.fgv-st .st-title{font-weight:600;font-size:12px;text-transform:uppercase;letter-spacing:.04em;margin-bottom:4px}' +
      '.fgv-st .ok{color:#1a7f37}.fgv-st .warn{color:#9a6700}.fgv-st .muted{color:#57606a}' +
      '.fgv-st .st-file{display:flex;gap:8px;padding:2px 0}.fgv-st .st-mark{display:inline-block;width:16px;text-align:center;border-radius:4px;background:#eaeef2;font-size:11px}' +
      '.fgv-run{display:flex;flex-direction:column;height:100%}.fgv-run .lane-log{flex:1;overflow:auto;padding:8px 12px}' +
      '.fgv-run .lane-line{display:flex;gap:8px;padding:2px 0}.fgv-run .lane-line.err .lane-dot{color:#cf222e}.fgv-run .lane-line.ok .lane-dot{color:#1a7f37}.fgv-run .lane-line.running .lane-dot{color:#9a6700}' +
      '.fgv-run .lane-msg{color:#57606a}' +
      '.fgv-run .lane-row{flex:none;display:flex;align-items:center;gap:8px;padding:8px 12px;border-top:1px solid #d0d7de;background:#f6f8fa}' +
      '.fgv-run .lane-row input{flex:1;font:12px ui-monospace,SFMono-Regular,Menlo,monospace;padding:5px 8px;border:1px solid #d0d7de;border-radius:6px;background:#fff}' +
      // the repo selector: one row per repo, the clanker sidebar's shape
      // (name over the last commit, the branch at the right); a single
      // column at any width, never a grid that reflows
      '.fgv-repos{display:flex;flex-direction:column}' +
      '.fgv-repos .card{display:flex;align-items:center;gap:8px;padding:7px 12px;cursor:pointer;border-bottom:1px solid #eaeef2;min-width:0}.fgv-repos .card:hover{background:#f6f8fa}' +
      '.fgv-repos .main{flex:1;min-width:0}' +
      '.fgv-repos .name{font-weight:600;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +
      '.fgv-repos .last{color:#57606a;font-size:12px;margin-top:1px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.fgv-repos .last.none{color:#8b949e;font-style:italic}' +
      '.fgv-repos .meta{flex:none;color:#8b949e;font-size:11px;white-space:nowrap}' +
      '.fgv-set{padding:12px;max-width:560px}.fgv-set .sec{margin-bottom:16px}.fgv-set .sec-head{font-weight:600;font-size:12px;text-transform:uppercase;letter-spacing:.04em;margin-bottom:8px;color:#57606a}' +
      '.fgv-set label{display:block;margin-bottom:8px}.fgv-set label span{display:block;font-size:12px;color:#57606a;margin-bottom:2px}' +
      '.fgv-set input{width:100%;box-sizing:border-box;font:inherit;padding:5px 8px;border:1px solid #d0d7de;border-radius:6px;background:#fff}' +
      '.fgv-set button{font:inherit;padding:5px 12px;border:1px solid #0969da;border-radius:6px;background:#0969da;color:#fff;cursor:pointer}.fgv-set button:disabled{opacity:.5;cursor:default}' +
      '.fgv-set .note{margin-left:10px;color:#57606a;font-size:12px}';
    document.head.appendChild(s);
  }
  function get(url) { return fetch(url, { headers: { Accept: 'application/json' }, cache: 'no-store' }).then(function (r) { return r.ok ? r.json() : null; }); }
  function sibling(url, name) { return url.replace(/[^/]+$/, name); }
  function ends(p, name) { return typeof p === 'string' && p.slice(-name.length - 1) === '/' + name; }
  function el(tag, cls, text) { var e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; }

  // ---- forge-log: commits with HEAD marked ----
  window.Viewers['forge-log'] = { label: 'log', mount: function (root, opts) {
    css();
    var args = opts.args || {}, url = opts.url, api = args.api || '/grubbery/forge/api';
    var commits = [], cur = null, branches = [], busy = false;
    var box = el('div', 'fgv'), head = el('div', 'fgv-head'), list = el('ul', 'fgv-log');
    var sel = el('select'), hash = el('span', 'hash mono'), note = el('span', 'busy');
    head.appendChild(el('span', null, 'branch')); head.appendChild(sel); head.appendChild(hash); head.appendChild(note);
    box.appendChild(head); box.appendChild(list); root.appendChild(box);
    function drawHead() {
      sel.textContent = '';
      var seen = false;
      branches.forEach(function (b) { var o = el('option', null, b); o.value = b; if (cur && b === cur.branch) { o.selected = true; seen = true; } sel.appendChild(o); });
      if (cur && cur.branch && !seen) { var o = el('option', null, cur.branch); o.value = cur.branch; o.selected = true; sel.appendChild(o); }
      hash.textContent = cur && cur.hash ? cur.hash.slice(0, 7) : '';
      hash.title = cur && cur.hash ? cur.hash : '';
      // the stream says when the checkout lands: current.json moves
      if (busy && cur && cur.branch === sel.value) { busy = false; note.textContent = ''; }
      sel.disabled = busy;
    }
    sel.addEventListener('change', function () {
      var b = sel.value; if (!b || !args.repo || (cur && b === cur.branch)) return;
      busy = true; note.textContent = 'checking out ' + b + '...'; sel.disabled = true;
      fetch(api + '/run', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ repo: args.repo, command: 'checkout ' + b }) })
        .then(function (r) { if (!r.ok) throw new Error('run ' + r.status); })
        .catch(function (e) { busy = false; note.textContent = 'checkout failed: ' + e.message; drawHead(); });
    });
    function draw() {
      drawHead();
      list.textContent = '';
      if (!commits.length) { list.appendChild(el('li', 'fgv-empty', 'no commits')); return; }
      commits.forEach(function (c) {
        var li = el('li', (cur && cur.hash === c.hash) ? 'head' : null);
        li.appendChild(el('span', 'short mono', c.short || (c.hash || '').slice(0, 7)));
        var msg = el('span', 'msg', (c.message || '').split('\n')[0]); msg.title = c.body || c.message || '';
        (c.refs || []).forEach(function (r) { msg.appendChild(el('span', 'ref', r.replace(/^refs\/(heads|remotes)\//, ''))); });
        li.appendChild(msg);
        var when = c.commitDate ? new Date(c.commitDate).toLocaleDateString() : '';
        li.appendChild(el('span', 'who', (c.author || '') + (when ? ' - ' + when : '')));
        list.appendChild(li);
      });
    }
    Promise.all([get(url), get(sibling(url, 'current.json')), get(sibling(url, 'branches.json'))])
      .then(function (r) { commits = Array.isArray(r[0]) ? r[0] : commits; cur = r[1] || cur; branches = Array.isArray(r[2]) ? r[2] : branches; draw(); });
    return {
      destroy: function () { box.remove(); },
      onUpdate: function (ev) {
        if (ends(ev.path, 'commits.json') && Array.isArray(ev.body)) { commits = ev.body; draw(); }
        else if (ends(ev.path, 'current.json') && ev.body && typeof ev.body === 'object') { cur = ev.body; draw(); }
        else if (ends(ev.path, 'branches.json') && Array.isArray(ev.body)) { branches = ev.body; drawHead(); }
      }
    };
  } };

  // ---- forge-status: where HEAD sits, staged/unstaged/untracked, the stash ----
  window.Viewers['forge-status'] = { label: 'status', mount: function (root, opts) {
    css();
    var url = opts.url, st = {}, cur = {}, stash = [];
    var box = el('div', 'fgv'), pane = el('div', 'fgv-st'); box.appendChild(pane); root.appendChild(box);
    function draw() {
      pane.textContent = '';
      if (cur.hash) {
        var h = el('div', 'st-head');
        h.appendChild(document.createTextNode(cur.branch ? 'on ' : ''));
        h.appendChild(el('b', null, cur.branch || 'detached'));
        h.appendChild(document.createTextNode(' @ '));
        h.appendChild(el('code', 'mono', (cur.hash || '').slice(0, 7)));
        if (cur.remote && cur.remote !== cur.hash) h.appendChild(el('span', 'st-ahead', '↑ ahead of remote'));
        pane.appendChild(h);
      }
      var any = false;
      [['staged', st.staged || [], 'ok'], ['unstaged', st.unstaged || [], 'warn'], ['untracked', st.untracked || [], 'muted']].forEach(function (g) {
        if (!g[1].length) return; any = true;
        var grp = el('div', 'st-group'); grp.appendChild(el('div', 'st-title ' + g[2], g[0] + ' (' + g[1].length + ')'));
        g[1].forEach(function (f) {
          var p = typeof f === 'string' ? f : (f.path || JSON.stringify(f)), s = (f && typeof f === 'object' && f.status) ? f.status : '';
          var row = el('div', 'st-file'); if (s) { var m = el('span', 'st-mark', s.charAt(0).toUpperCase()); m.title = s; row.appendChild(m); }
          row.appendChild(el('span', 'st-path mono', p)); grp.appendChild(row);
        });
        pane.appendChild(grp);
      });
      if (!any) pane.appendChild(el('div', 'fgv-empty', 'working tree clean'));
      if (stash.length) {
        var sg = el('div', 'st-group'); sg.appendChild(el('div', 'st-title muted', 'stash (' + stash.length + ')'));
        stash.forEach(function (s) { var row = el('div', 'st-file'); row.appendChild(el('span', 'st-mark', '@' + s.index)); row.appendChild(el('span', 'st-path', (s.short || '') + ' ' + (s.message || ''))); sg.appendChild(row); });
        pane.appendChild(sg);
      }
    }
    Promise.all([get(url), get(sibling(url, 'current.json')), get(sibling(url, 'stash.json'))])
      .then(function (r) { st = r[0] || st; cur = r[1] || cur; stash = Array.isArray(r[2]) ? r[2] : stash; draw(); });
    return {
      destroy: function () { box.remove(); },
      onUpdate: function (ev) {
        if (!ev.body || typeof ev.body !== 'object') return;
        if (ends(ev.path, 'status.json')) st = ev.body;
        else if (ends(ev.path, 'current.json')) cur = ev.body;
        else if (ends(ev.path, 'stash.json') && Array.isArray(ev.body)) stash = ev.body;
        else return;
        draw();
      }
    };
  } };

  // ---- forge-run: the serial command lane — its log, and a prompt ----
  window.Viewers['forge-run'] = { label: 'run', mount: function (root, opts) {
    css();
    var args = opts.args || {}, url = opts.url, api = args.api || '/grubbery/forge/api';
    var lane = { queue: [], active: null, log: [] };
    var box = el('div', 'fgv fgv-run'), log = el('div', 'lane-log'), row = el('div', 'lane-row');
    var inp = el('input'); inp.type = 'text'; inp.spellcheck = false; inp.autocomplete = 'off'; inp.placeholder = 'type a git command - e.g. commit -m "message"';
    row.appendChild(el('span', 'mono', 'git ▸')); row.appendChild(inp);
    box.appendChild(log); box.appendChild(row); root.appendChild(box);
    function line(cls, dot, raw, msg) { var d = el('div', 'lane-line ' + cls); d.appendChild(el('span', 'lane-dot', dot)); d.appendChild(el('span', 'lane-cmd mono', raw)); d.appendChild(el('span', 'lane-msg', msg || '')); return d; }
    function draw() {
      log.textContent = '';
      (lane.log || []).slice().reverse().forEach(function (e) { log.appendChild(line(e.ok ? 'ok' : 'err', e.ok ? '✓' : '✕', e.raw, e.message)); });
      if (lane.active) log.appendChild(line('running', '▸', lane.active.raw, 'running...'));
      (lane.queue || []).forEach(function (q) { log.appendChild(line('queued', '·', q.raw, 'queued')); });
      log.scrollTop = log.scrollHeight;
    }
    inp.addEventListener('keydown', function (e) {
      if (e.key !== 'Enter') return;
      var cmd = inp.value.trim(); if (!cmd || !args.repo) return;
      inp.value = '';
      fetch(api + '/run', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ repo: args.repo, command: cmd }) })
        .catch(function (err) { log.appendChild(line('err', '✕', cmd, 'submit failed: ' + err.message)); });
      // the stream brings the lane's state back as it moves: nothing to poll
    });
    get(url + '?raw=1').then(function (r) { if (r && typeof r === 'object') { lane = r; draw(); } });
    return {
      destroy: function () { box.remove(); },
      onUpdate: function (ev) { if (ends(ev.path, 'run.git-action') && ev.body && typeof ev.body === 'object') { lane = ev.body; draw(); } }
    };
  } };

  // (forge-docs, the handbook pane, lives in docs-pane.js)

  // ---- forge-repos: the repo selector. One card per repo instance; a click
  // navigates the pane to the repo's dir, which forge opens as the workspace
  // layout rooted there. Follows the repos dir (fold): a repo added or
  // removed re-pulls the list. ----
  window.Viewers['forge-repos'] = { label: 'repos', mount: function (root, opts) {
    css();
    var args = opts.args || {}, url = opts.url, api = args.api || '/grubbery/forge/api';
    var repos = [];
    var box = el('div', 'fgv'), grid = el('div', 'fgv-repos'); box.appendChild(grid); root.appendChild(box);
    function draw() {
      grid.textContent = '';
      if (!repos.length) { grid.appendChild(el('div', 'fgv-empty', 'no repos')); return; }
      repos.forEach(function (r) {
        var card = el('div', 'card');
        var cur = r.current || {};
        var short = String(r.name || '').replace(/\.git_repo$/, '');
        var main = el('div', 'main');
        main.appendChild(el('div', 'name', short));
        var lastMsg = r.last && r.last.message ? (r.last.message || '').split('\n')[0] : '';
        main.appendChild(el('div', 'last' + (lastMsg ? '' : ' none'), lastMsg || (r.repo ? 'no commits yet' : 'empty')));
        card.appendChild(main);
        if (cur.branch) card.appendChild(el('span', 'meta mono', cur.branch + ' @ ' + String(cur.hash || '').slice(0, 7)));
        // the click names the tab it opens: the row the user picked is called this;
        // relative to the repos dir this pane shows, however it is spelled
        // (under @forge it stays under @forge)
        card.addEventListener('click', function () { if (opts.onNavigate) opts.onNavigate('./' + r.name, 'dir', { name: short }); });
        grid.appendChild(card);
      });
    }
    function load() { get(api + '/list').then(function (r) { repos = Array.isArray(r) ? r : repos; draw(); }); }
    load();
    return { destroy: function () { box.remove(); }, onUpdate: function () { load(); } };
  } };

  // ---- forge-settings: the repo's config.json + poll.json as a form, saved
  // through /api/config. The stream brings both back when they move; a
  // field you are editing is left alone until you save or blur. ----
  window.Viewers['forge-settings'] = { label: 'settings', mount: function (root, opts) {
    css();
    var args = opts.args || {}, url = opts.url, api = args.api || '/grubbery/forge/api';
    var cfg = {}, poll = null, dirty = false;
    var box = el('div', 'fgv'), form = el('div', 'fgv-set'); box.appendChild(form); root.appendChild(box);
    var fields = {};
    function field(sec, key, label, hint, type) {
      var l = el('label'); var s = el('span', null, label + (hint ? ' (' + hint + ')' : '')); l.appendChild(s);
      var i = el('input'); i.type = type || 'text'; if (type === 'number') i.min = '0';
      i.addEventListener('input', function () { dirty = true; });
      l.appendChild(i); sec.appendChild(l); fields[key] = i;
    }
    var s1 = el('div', 'sec'); s1.appendChild(el('div', 'sec-head', 'origin'));
    field(s1, 'repo', 'repository', 'owner/repo'); field(s1, 'ref', 'ref'); field(s1, 'account', 'account', 'github login to push as; empty = none'); field(s1, 'poll', 'poll', 'minutes between fetches; 0 = only on demand', 'number');
    var s2 = el('div', 'sec'); s2.appendChild(el('div', 'sec-head', 'author'));
    field(s2, 'author_name', 'name', 'stamped into commits you make'); field(s2, 'author_email', 'email');
    var save = el('button', null, 'save config'), note = el('span', 'note');
    var s3 = el('div', 'sec'); s3.appendChild(save); s3.appendChild(note);
    form.appendChild(s1); form.appendChild(s2); form.appendChild(s3);
    function fill() {
      if (dirty) return;
      ['repo', 'ref', 'account', 'author_name', 'author_email'].forEach(function (k) { fields[k].value = cfg[k] || ''; });
      fields.poll.value = (poll == null) ? '' : String(poll);
    }
    save.addEventListener('click', function () {
      if (!args.repo) return;
      var body = { repo: args.repo, origin: fields.repo.value.trim(), ref: fields.ref.value.trim(), account: fields.account.value.trim(), author_name: fields.author_name.value.trim(), author_email: fields.author_email.value.trim() };
      var p = fields.poll.value.trim(); if (p !== '' && !isNaN(Number(p))) body.poll = Number(p);
      save.disabled = true; note.textContent = 'saving...';
      fetch(api + '/config', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) })
        .then(function (r) { save.disabled = false; note.textContent = r.ok ? 'saved' : 'save failed: ' + r.status; if (r.ok) dirty = false; })
        .catch(function (e) { save.disabled = false; note.textContent = 'save failed: ' + e.message; });
    });
    Promise.all([get(url), get(sibling(url, 'poll.json'))]).then(function (r) { cfg = r[0] || cfg; poll = (r[1] && typeof r[1] === 'object') ? r[1].minutes : poll; fill(); });
    return {
      destroy: function () { box.remove(); },
      onUpdate: function (ev) {
        if (!ev.body || typeof ev.body !== 'object') return;
        if (ends(ev.path, 'config.json')) cfg = ev.body;
        else if (ends(ev.path, 'poll.json')) poll = ev.body.minutes;
        else return;
        fill();
      }
    };
  } };
})();
