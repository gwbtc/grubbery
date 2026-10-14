// peers: usergroups + ships, as panes of the explorer mounted on /sys/ames
// (route /apps/grubbery/peers). Two dir panes under the explorer's viewer
// contract — mount(root, opts) -> { destroy() }, opts.url the directory's
// own /grubbery/ball url, opts.args what the shell's viewer gate handed
// over, opts.onNavigate(url, kind) to move this tab:
//   'groups'  on /sys/ames/usergroups: every group, with a create box
//   'group'   on one <name>.grp dir: its members and permission roads
// Reads come from /apps/grubbery/peers.json (the groups folded from their
// who.ships + how.weir); the three writes go to the shell's peers POSTs,
// since members are a ships mark and permissions are the registry's poke.
// Deleting a group is the explorer's own row menu. The raw files stay one
// click away in Source.
(function () {
  'use strict';
  var API = '/apps/grubbery';
  var CSS =
    '.pe{height:100%;display:flex;flex-direction:column;min-height:0;font:14px Inter,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:#1f2328;background:#fff}' +
    '.pe .head{flex:none;display:flex;align-items:center;gap:10px;padding:12px 16px;border-bottom:1px solid #d0d7de;background:#f6f8fa}' +
    '.pe .head .title{font-weight:600;font-size:13px;color:#57606a;flex:1;font-family:ui-monospace,SFMono-Regular,Menlo,monospace}' +
    '.pe .head input{width:220px;border:1px solid #d0d7de;border-radius:7px;padding:6px 10px;font:13px ui-monospace,SFMono-Regular,Menlo,monospace;outline:none;background:#fff}' +
    '.pe .head input:focus{border-color:#0969da;box-shadow:0 0 0 3px rgba(9,105,218,.15)}' +
    '.pe button.pri{height:31px;padding:0 13px;border-radius:7px;border:1px solid #0969da;background:#0969da;color:#fff;cursor:pointer;font:600 12px Inter,-apple-system,sans-serif}' +
    '.pe button.pri:disabled{background:#f6f8fa;border-color:#d0d7de;color:#8b949e;cursor:default}' +
    '.pe .body{flex:1;min-height:0;overflow-y:auto}' +
    '.pe .row{display:grid;grid-template-columns:200px 120px 1fr;gap:12px;align-items:center;padding:10px 16px;cursor:pointer;border-bottom:1px solid #f0f2f4}' +
    '.pe .row:hover{background:#f6f8fa}' +
    '.pe .name{font:600 13px ui-monospace,SFMono-Regular,Menlo,monospace;color:#0969da;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +
    '.pe .count{font:11px ui-monospace,SFMono-Regular,Menlo,monospace;color:#8b949e;white-space:nowrap}' +
    '.pe .roads{font:11px ui-monospace,SFMono-Regular,Menlo,monospace;color:#57606a;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +
    '.pe .sec{padding:14px 16px;border-bottom:1px solid #f0f2f4}' +
    '.pe .sec h4{margin:0 0 8px;font:600 10px Inter,-apple-system,sans-serif;text-transform:uppercase;letter-spacing:.05em;color:#8b949e}' +
    '.pe .sec label{display:block;font:11px ui-monospace,SFMono-Regular,Menlo,monospace;color:#57606a;margin:8px 0 3px}' +
    '.pe textarea,.pe .sec input{width:100%;max-width:640px;border:1px solid #d0d7de;border-radius:7px;padding:7px 10px;font:12.5px ui-monospace,SFMono-Regular,Menlo,monospace;outline:none;background:#fff;box-sizing:border-box}' +
    '.pe textarea{min-height:90px;resize:vertical}' +
    '.pe textarea:focus,.pe .sec input:focus{border-color:#0969da;box-shadow:0 0 0 3px rgba(9,105,218,.15)}' +
    '.pe .acts{display:flex;gap:8px;align-items:center;margin-top:10px}' +
    '.pe .note{font-size:12px;color:#8b949e}' +
    '.pe .empty{color:#8b949e;font-size:13px;text-align:center;margin:60px auto;max-width:360px;line-height:1.6}' +
    '.pe .err{color:#cf222e;font-size:12.5px;margin:12px 16px}' +
    '.pe .ok{color:#1a7f37;font-size:12px}';
  var styled = false;
  function injectStyle() {
    if (styled) return; styled = true;
    var s = document.createElement('style'); s.textContent = CSS; document.head.appendChild(s);
  }
  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  }
  function loadGroups() {
    return fetch(API + '/peers.json', { cache: 'no-store' }).then(function (r) { if (!r.ok) throw new Error(r.status); return r.json(); });
  }
  function post(path, body) {
    return fetch(API + '/peers/' + path, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) })
      .then(function (r) { if (!r.ok) return r.text().then(function (t) { throw new Error(t || r.status); }); return r; });
  }
  // the ball url of the mount's root (/sys/ames), from any dir url under it
  function amesRoot(url) {
    var u = (url || '').replace(/\?.*$/, '');
    var i = u.indexOf('/sys/ames');
    return i < 0 ? u : u.slice(0, i + '/sys/ames'.length);
  }
  function splitRoads(s) {
    return s.split(',').map(function (x) { return x.trim(); }).filter(Boolean);
  }

  // ---- groups: the list ----
  function mountGroups(root, opts) {
    injectStyle();
    root.innerHTML = '';
    root.classList.add('pe');
    var dead = false;
    var head = el('div', 'head');
    head.appendChild(el('span', 'title', 'usergroups'));
    var nameEl = el('input'); nameEl.placeholder = '/group/name'; nameEl.spellcheck = false;
    var newBtn = el('button', 'pri', 'new group');
    head.appendChild(nameEl); head.appendChild(newBtn);
    var body = el('div', 'body');
    root.appendChild(head); root.appendChild(body);
    var base = amesRoot(opts.url);
    function open(g) {
      var u = base + g.dir;
      if (opts.onNavigate) opts.onNavigate(u, 'dir'); else location.href = u;
    }
    function render(groups) {
      body.innerHTML = '';
      if (!groups.length) { body.appendChild(el('div', 'empty', 'No usergroups yet. Name one above to create it.')); return; }
      groups.forEach(function (g) {
        var r = el('div', 'row');
        r.appendChild(el('span', 'name', g.name));
        r.appendChild(el('span', 'count', g.public ? 'all ships' : g.members.length + (g.members.length === 1 ? ' member' : ' members')));
        var roads = ['make', 'poke', 'peek'].map(function (k) { return g[k].length ? k + ' ' + g[k].length : null; }).filter(Boolean).join(' · ');
        r.appendChild(el('span', 'roads', roads || 'no roads'));
        r.title = 'open ' + g.name;
        r.addEventListener('click', function () { open(g); });
        body.appendChild(r);
      });
    }
    function load() {
      if (dead) return;
      return loadGroups().then(function (gs) { if (!dead) render(gs); })
        .catch(function (e) { if (!dead) { body.innerHTML = ''; body.appendChild(el('div', 'err', 'groups failed to load: ' + e.message)); } });
    }
    function create() {
      var name = nameEl.value.trim();
      if (!name) { nameEl.focus(); return; }
      if (name[0] !== '/') name = '/' + name;
      newBtn.disabled = true;
      post('create', { name: name })
        .then(function () { nameEl.value = ''; return loadGroups(); })
        .then(function (gs) {
          var g = gs.find(function (x) { return x.name === name; });
          if (g) open(g); else render(gs);
        })
        .catch(function (e) { body.insertBefore(el('div', 'err', 'could not create the group: ' + e.message), body.firstChild); })
        .then(function () { newBtn.disabled = false; });
    }
    newBtn.addEventListener('click', create);
    nameEl.addEventListener('keydown', function (e) { if (e.key === 'Enter') { e.preventDefault(); create(); } });
    load();
    return { destroy: function () { dead = true; root.innerHTML = ''; root.classList.remove('pe'); } };
  }

  // ---- group: one group's members + roads ----
  function mountGroup(root, opts) {
    injectStyle();
    root.innerHTML = '';
    root.classList.add('pe');
    var dead = false;
    var name = opts.args && typeof opts.args.group === 'string' ? opts.args.group : null;
    if (!name) { root.appendChild(el('div', 'empty', 'no group here: the shell gave no {group} for ' + opts.url)); return { destroy: function () { root.innerHTML = ''; root.classList.remove('pe'); } }; }
    var head = el('div', 'head');
    head.appendChild(el('span', 'title', name));
    var body = el('div', 'body');
    root.appendChild(head); root.appendChild(body);
    function render(g) {
      body.innerHTML = '';
      var isPublic = !!g.public;
      // members
      var mem = el('div', 'sec');
      mem.appendChild(el('h4', null, 'members'));
      var memTa = null;
      if (isPublic) {
        mem.appendChild(el('div', 'note', 'the public group applies to every foreign ship; it has no member list'));
      } else {
        mem.appendChild(el('label', null, 'one ~ship per line'));
        memTa = el('textarea'); memTa.value = g.members.join('\n'); memTa.spellcheck = false;
        mem.appendChild(memTa);
        var macts = el('div', 'acts');
        var msave = el('button', 'pri', 'save members');
        var mstat = el('span', 'ok', '');
        macts.appendChild(msave); macts.appendChild(mstat);
        mem.appendChild(macts);
        msave.addEventListener('click', function () {
          var ships = memTa.value.split('\n').map(function (s) { return s.trim(); }).filter(Boolean);
          msave.disabled = true; mstat.textContent = '';
          post('members', { group: name, ships: ships })
            .then(function () { mstat.textContent = 'saved'; })
            .catch(function (e) { mstat.textContent = 'failed: ' + e.message; mstat.className = 'err'; })
            .then(function () { msave.disabled = false; });
        });
      }
      body.appendChild(mem);
      // roads. TODO: saving does nothing yet — the registry's %how only
      // takes roads from a registered sender, within its own prefix (see
      // +peers-write in shell.hoon). Read-only vs shell-as-broker is open.
      var perm = el('div', 'sec');
      perm.appendChild(el('h4', null, 'permissions'));
      perm.appendChild(el('div', 'note', 'roads the group may use, comma-separated: a /dir/ covers its subtree, a /dir/file.ext one grub'));
      var inputs = {};
      ['make', 'poke', 'peek'].forEach(function (k) {
        perm.appendChild(el('label', null, k));
        var inp = el('input'); inp.value = g[k].join(','); inp.spellcheck = false; inp.placeholder = '/path/, /path/file.ext';
        inputs[k] = inp; perm.appendChild(inp);
      });
      var pacts = el('div', 'acts');
      var psave = el('button', 'pri', 'save permissions');
      var pstat = el('span', 'ok', '');
      pacts.appendChild(psave); pacts.appendChild(pstat);
      perm.appendChild(pacts);
      psave.addEventListener('click', function () {
        psave.disabled = true; pstat.textContent = '';
        post('permissions', { group: name, make: splitRoads(inputs.make.value), poke: splitRoads(inputs.poke.value), peek: splitRoads(inputs.peek.value) })
          .then(function () { pstat.textContent = 'saved'; })
          .catch(function (e) { pstat.textContent = 'failed: ' + e.message; pstat.className = 'err'; })
          .then(function () { psave.disabled = false; });
      });
      body.appendChild(perm);
      var foot = el('div', 'sec');
      foot.appendChild(el('div', 'note', 'who.ships and how.weir are the files behind this pane (Source shows them); delete the group from its row menu in the tree'));
      body.appendChild(foot);
    }
    loadGroups().then(function (gs) {
      if (dead) return;
      var g = gs.find(function (x) { return x.name === name; });
      if (!g) { body.appendChild(el('div', 'err', 'no group named ' + name)); return; }
      render(g);
    }).catch(function (e) { if (!dead) body.appendChild(el('div', 'err', 'group failed to load: ' + e.message)); });
    return { destroy: function () { dead = true; root.innerHTML = ''; root.classList.remove('pe'); } };
  }

  window.Viewers = window.Viewers || {};
  window.Viewers['groups'] = { label: 'Groups', mount: mountGroups };
  window.Viewers['group'] = { label: 'Group', mount: mountGroup };
})();
