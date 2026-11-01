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
// A group's files are derived by the shell from your record and from what
// granted apps declare; this pane edits your part. The raw files stay one
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
    '.pe .contrib{display:flex;gap:12px;align-items:flex-start;padding:7px 0;border-top:1px solid #f0f2f4;font-size:12px}' +
    '.pe .contrib .by{flex:0 0 220px;color:#57606a;font-family:ui-monospace,SFMono-Regular,Menlo,monospace;word-break:break-all}' +
    '.pe .contrib .bits{display:flex;flex-wrap:wrap;gap:6px}' +
    '.pe .contrib code{background:#f6f8fa;border:1px solid #e5e8eb;border-radius:5px;padding:1px 6px;font-size:11.5px}' +
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
        memTa = el('textarea'); memTa.value = ((g.mine && g.mine.members) || []).join('\n'); memTa.spellcheck = false;
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
      // roads: your own part. What apps, names and desks contribute is
      // listed below, read-only, with its contributor.
      var perm = el('div', 'sec');
      perm.appendChild(el('h4', null, 'roads the shell declares'));
      perm.appendChild(el('div', 'note', 'comma-separated: a /dir/ covers its subtree, a /dir/file.ext one grub. What the shell derives from a desk you published or a name you shared is listed below instead.'));
      var inputs = {};
      ['make', 'poke', 'peek'].forEach(function (k) {
        perm.appendChild(el('label', null, k));
        var inp = el('input'); inp.value = ((g.mine && g.mine[k]) || []).join(','); inp.spellcheck = false; inp.placeholder = '/path/, /path/file.ext';
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
      // everyone's contributions, each with who made it
      var rank = function (b) { return b === 'manual' ? 0 : b === 'shell' ? 1 : 2; };
      var others = (g.contributions || []).slice().sort(function (a, b) { return rank(a.by) - rank(b.by) || a.by.localeCompare(b.by); });
      var all = el('div', 'sec');
      all.appendChild(el('h4', null, 'opened to this group, by whom'));
      // a contributor with nothing in force is not a row
      others = others.filter(function (c) { return (c.members || []).length || (c.make || []).length || (c.poke || []).length || (c.peek || []).length; });
      if (!others.length) all.appendChild(el('div', 'note', 'nothing yet'));
      others.forEach(function (c) {
        // an app is named by its desk and nexus; the full root sits in the title
        var who = c.by === 'manual' ? 'shell (declared)' : c.by === 'shell' ? 'shell (derived)' : c.by;
        if (who.charAt(0) === '/') {
          var m = who.match(/^\/apps\/shell\/desks\/([^/]+)\/desk\/data\/([^/]+)$/);
          who = m ? m[1] + ' \u203a ' + m[2] : who;
        }
        var bits = [];
        (c.members || []).forEach(function (m) { bits.push('member ' + m); });
        ['make', 'poke', 'peek'].forEach(function (k) { (c[k] || []).forEach(function (r) { bits.push(k + ' ' + r); }); });
        var row = el('div', 'contrib');
        var byEl = el('span', 'by', who); if (c.by.charAt(0) === '/') byEl.title = c.by;
        row.appendChild(byEl);
        var list = el('span', 'bits');
        bits.forEach(function (b) { list.appendChild(el('code', null, b)); });
        row.appendChild(list);
        all.appendChild(row);
      });
      body.appendChild(all);
      var foot = el('div', 'sec');
      foot.appendChild(el('div', 'note', "the group's who.ships and how.weir are the union of the rows above. The shell declares what you write in this pane and derives the rest from the desks you publish and the names you share. An app declares its own row in its groups.json, within what you approved on Permits."));
      if (!isPublic) {
        var dbtn = el('button', 'btn', 'drop this group');
        var dstat = el('span', 'ok', '');
        dbtn.addEventListener('click', function () {
          dbtn.disabled = true; dstat.textContent = '';
          post('delete', { group: name })
            .then(function () { body.innerHTML = ''; body.appendChild(el('div', 'empty', 'dropped from your record; the group stays only while an app still names it')); })
            .catch(function (e) { dstat.textContent = 'failed: ' + e.message; dstat.className = 'err'; dbtn.disabled = false; });
        });
        foot.appendChild(dbtn); foot.appendChild(dstat);
      }
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
