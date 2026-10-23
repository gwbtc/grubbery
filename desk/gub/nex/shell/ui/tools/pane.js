// tools panes: a tools nexus and one of its tools, as explorer viewers.
// mount(root, {url, args, open, onNavigate}) -> {destroy, onUpdate}.
//
//   tools-nexus  one tools nexus: its tools (click one: it opens as a
//                tab) and the runs in flight. args {at}: the nexus's
//                absolute path
//   tool         one tool, opened on its source file: description,
//                schema, a form to run it, the source. args {at, file}:
//                the nexus and the file's path under code/lib/tools
//
// Every read is the shell's tools endpoint, /grubbery/tools/api/*?path=,
// which reads any tools nexus by path. A run is a JSON-RPC tools/call to
// the same endpoint, the request every MCP client makes: the shell's own
// tools by name, another nexus's through call_tool with its path.
(function () {
  'use strict';
  var API = '/grubbery/tools';
  var CSS_ID = 'tools-panes-css';
  function css() {
    if (document.getElementById(CSS_ID)) return;
    var s = document.createElement('style'); s.id = CSS_ID;
    s.textContent =
      '.tn{height:100%;display:flex;flex-direction:column;min-height:0;font:13px -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:#24292f;background:#fff}' +
      '.tn .mono{font:12px ui-monospace,SFMono-Regular,Menlo,monospace}' +
      '.tn-head{flex:none;display:flex;align-items:center;gap:8px;padding:8px 10px;border-bottom:1px solid #d0d7de;background:#f6f8fa}' +
      '.tn-head input{flex:1;min-width:0;font:inherit;padding:4px 7px;border:1px solid #d0d7de;border-radius:6px;background:#fff;color:#24292f}' +
      '.tn-head input:focus{outline:none;border-color:#0969da;box-shadow:0 0 0 2px rgba(9,105,218,.15)}' +
      '.tn-head .count{flex:none;font-size:11px;color:#8b949e;white-space:nowrap}' +
      '.tn-tabs{flex:none;display:flex;gap:0;border-bottom:1px solid #d0d7de;background:#fff}' +
      '.tn-tabs button{all:unset;cursor:pointer;padding:6px 12px;font-size:12px;color:#57606a;border-bottom:2px solid transparent;margin-bottom:-1px}' +
      '.tn-tabs button.on{color:#24292f;font-weight:600;border-bottom-color:#24292f}' +
      '.tn-list{flex:1;min-height:0;overflow:auto}' +
      '.tn-row{display:flex;flex-direction:column;gap:2px;padding:7px 12px;cursor:pointer;border-bottom:1px solid #eaeef2;min-width:0}' +
      '.tn-row:hover{background:#f6f8fa}' +
      '.tn-row .name{font:600 12px ui-monospace,SFMono-Regular,Menlo,monospace;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +
      '.tn-row .sub{color:#57606a;font-size:12px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +
      '.tn-row .sub.err{color:#cf222e}' +
      '.tn-row .chips{display:flex;gap:4px;flex-wrap:wrap;margin-top:2px}' +
      '.tn-chip{font:10.5px ui-monospace,monospace;color:#57606a;background:#f0f2f4;border:1px solid #e4e7eb;border-radius:999px;padding:0 6px}' +
      '.tn-chip.req{color:#4b2ca8;background:#f1ecfb;border-color:#c9b8f2}' +
      '.tn-chip.step{color:#116329;background:#dafbe1;border-color:#aceebb}.tn-chip.step.start{color:#9a6700;background:#fff8c5;border-color:#eed888}' +
      '.tn-empty{padding:14px 12px;color:#8b949e}.tn-err{padding:10px 12px;color:#cf222e}' +
      '.tn-tool{flex:1;min-height:0;overflow:auto;padding:14px 18px;max-width:900px;box-sizing:border-box;width:100%}' +
      '.tn-tool h2{font:600 15px ui-monospace,SFMono-Regular,Menlo,monospace;margin:0 0 2px}' +
      '.tn-tool .where{color:#8b949e;font-size:12px;margin:0 0 12px;overflow-wrap:anywhere}' +
      '.tn-tool .desc{white-space:pre-wrap;line-height:1.5;margin:0 0 14px}' +
      '.tn-tool h3{font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:.04em;color:#57606a;margin:14px 0 6px}' +
      '.tn-tool table{border-collapse:collapse;font-size:12.5px;width:100%}' +
      '.tn-tool th,.tn-tool td{text-align:left;padding:4px 8px;border-bottom:1px solid #eaeef2;vertical-align:top}' +
      '.tn-tool th{font-size:11px;color:#8b949e;font-weight:600}' +
      '.tn-tool td.type{color:#8250df;font:12px ui-monospace,monospace}.tn-tool td.req{color:#4b2ca8;font-size:11px}' +
      '.tn-form{display:flex;flex-direction:column;gap:8px;max-width:640px}' +
      '.tn-form label{display:flex;flex-direction:column;gap:3px;font-size:12px;color:#57606a}' +
      '.tn-form label.check{flex-direction:row;align-items:center;gap:8px}' +
      '.tn-form input,.tn-form textarea{font:12px ui-monospace,SFMono-Regular,Menlo,monospace;padding:5px 8px;border:1px solid #d0d7de;border-radius:6px;background:#fff;color:#24292f;width:100%;box-sizing:border-box}' +
      '.tn-form input[type=checkbox]{width:auto}' +
      '.tn-form input:focus,.tn-form textarea:focus{outline:none;border-color:#0969da;box-shadow:0 0 0 2px rgba(9,105,218,.15)}' +
      '.tn-form .acts{display:flex;align-items:center;gap:10px}' +
      '.tn-form button{font:inherit;padding:5px 12px;border:1px solid #0969da;border-radius:6px;background:#0969da;color:#fff;cursor:pointer}.tn-form button:disabled{opacity:.5;cursor:default}' +
      '.tn-form .note{color:#57606a;font-size:12px}.tn-form .note.err{color:#cf222e}' +
      '.tn-out{margin:8px 0 0;padding:8px 10px;max-height:360px;overflow:auto;background:#f6f8fa;border:1px solid #eaeef2;border-radius:6px;font:11.5px/1.45 ui-monospace,SFMono-Regular,Menlo,monospace;white-space:pre-wrap;word-break:break-word}' +
      '.tn-out.err{background:#fff8f8;border-color:#ffcecb}' +
      '.tn-src{margin:0;padding:10px 12px;background:#f6f8fa;border:1px solid #eaeef2;border-radius:6px;font:11.5px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace;white-space:pre;overflow:auto;color:#24292f}' +
      '.tn-src .com{color:#8b949e}.tn-src .str{color:#0a3069}.tn-src .term{color:#953800}.tn-src .rune{color:#0550ae}' +
      '.tn-tool details summary{cursor:pointer;font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:.04em;color:#57606a;margin:14px 0 6px}';
    document.head.appendChild(s);
  }
  function el(tag, cls, text) { var e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; }
  function get(url) { return fetch(url, { cache: 'no-store' }).then(function (r) { if (!r.ok) return r.text().then(function (t) { throw new Error(r.status + ' ' + t); }); return r.json(); }); }
  function withPath(route, at) { return API + route + (route.indexOf('?') >= 0 ? '&' : '?') + 'path=' + encodeURIComponent(at); }
  // a tool's name and its file are one bijection: dirs joined by __,
  // hyphens as underscores (lib/tools +derive-name / +name-to-place)
  function fileOf(name) { var segs = name.split('__').map(function (s) { return s.replace(/_/g, '-'); }); return segs.join('/') + '.hoon'; }
  function nameOf(file) { return file.replace(/\.hoon$/, '').split('/').filter(Boolean).map(function (s) { return s.replace(/-/g, '_'); }).join('__'); }
  function flatten(node) { var out = (node.tools || []).slice(); (node.dirs || []).forEach(function (d) { out = out.concat(flatten(d)); }); return out; }
  function props(t) { return (t.inputSchema && t.inputSchema.properties) || {}; }
  function required(t) { return (t.inputSchema && t.inputSchema.required) || []; }
  var rpcId = 0;
  function rpc(name, args) {
    return fetch(API, { method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ jsonrpc: '2.0', id: ++rpcId, method: 'tools/call', params: { name: name, arguments: args } }) })
      .then(function (r) { if (!r.ok) return r.text().then(function (t) { throw new Error(r.status + ' ' + t); }); return r.json(); });
  }
  // comments, strings, %terms, rune digraphs: enough to read by
  function highlight(src) {
    var pre = el('pre', 'tn-src');
    var re = /(::[^\n]*)|('[^'\n]*'|"[^"\n]*")|(%[a-z][a-z0-9-]*)|([|$%:.^~;=?!_+][|$%:.^~;=?!_+*@&<>#-])/g;
    var last = 0, m;
    while ((m = re.exec(src)) !== null) {
      if (m.index > last) pre.appendChild(document.createTextNode(src.slice(last, m.index)));
      pre.appendChild(el('span', m[1] ? 'com' : m[2] ? 'str' : m[3] ? 'term' : 'rune', m[0]));
      last = m.index + m[0].length;
    }
    if (last < src.length) pre.appendChild(document.createTextNode(src.slice(last)));
    return pre;
  }
  // what a run came back with, in a line
  function runSummary(r) {
    if (r.result == null) return '';
    if (r.result.type === 'error') return r.result.message || 'error';
    if (typeof r.result.text === 'string') return r.result.text.replace(/\s+/g, ' ').trim();
    return r.result.type || 'result';
  }

  // ---- tools-nexus: the tools of one nexus, and its runs ----
  function mountToolsNexus(root, opts) {
    css();
    var at = opts.args && typeof opts.args.at === 'string' ? opts.args.at : null;
    root.innerHTML = ''; root.classList.add('tn');
    var dead = false, timer = null;
    var handle = { destroy: function () { dead = true; clearTimeout(timer); root.innerHTML = ''; root.classList.remove('tn'); }, onUpdate: function () { if (timer) return; timer = setTimeout(function () { timer = null; load(); }, 300); } };
    if (!at) { root.appendChild(el('div', 'tn-err', 'no tools nexus here')); return handle; }
    var head = el('div', 'tn-head'), filter = el('input'), count = el('span', 'count');
    filter.placeholder = 'filter tools…'; filter.spellcheck = false; filter.setAttribute('data-focus', '');
    head.appendChild(filter); head.appendChild(count);
    var tabs = el('div', 'tn-tabs'), tTools = el('button', 'on', 'tools'), tRuns = el('button', null, 'runs');
    tabs.appendChild(tTools); tabs.appendChild(tRuns);
    var list = el('div', 'tn-list');
    root.appendChild(head); root.appendChild(tabs); root.appendChild(list);
    var tools = [], runs = [], mode = 'tools', err = null;
    function go(u, name) { if (opts.open) opts.open(u, { name: name }); else if (opts.onNavigate) opts.onNavigate(u, 'file'); }
    function render() {
      list.innerHTML = '';
      tTools.classList.toggle('on', mode === 'tools'); tRuns.classList.toggle('on', mode === 'runs');
      tRuns.textContent = runs.length ? 'runs · ' + runs.length : 'runs';
      if (err) { list.appendChild(el('div', 'tn-err', err)); return; }
      if (mode === 'runs') {
        count.textContent = runs.length ? runs.length + ' in flight' : '';
        if (!runs.length) { list.appendChild(el('div', 'tn-empty', 'No runs in flight.')); return; }
        runs.forEach(function (r) {
          var row = el('div', 'tn-row');
          row.appendChild(el('div', 'name', r.tool));
          var sum = runSummary(r);
          row.appendChild(el('div', 'sub' + (r.result && r.result.type === 'error' ? ' err' : ''), sum || r.id));
          var chips = el('div', 'chips'); chips.appendChild(el('span', 'tn-chip step ' + (r.step || ''), r.step || '')); chips.appendChild(el('span', 'tn-chip', r.id)); row.appendChild(chips);
          row.addEventListener('click', function () { go('./runs/' + encodeURIComponent(r.id), r.id); });
          list.appendChild(row);
        });
        return;
      }
      var q = filter.value.trim().toLowerCase();
      var shown = tools.filter(function (t) { return !q || t.name.toLowerCase().indexOf(q) >= 0 || (t.description || '').toLowerCase().indexOf(q) >= 0; });
      count.textContent = q ? shown.length + ' of ' + tools.length : tools.length + ' tools';
      if (!tools.length) { list.appendChild(el('div', 'tn-empty', 'No tools compiled at ' + at + '/code/lib/tools.')); return; }
      if (!shown.length) { list.appendChild(el('div', 'tn-empty', 'nothing matches')); return; }
      shown.forEach(function (t) {
        var row = el('div', 'tn-row');
        row.appendChild(el('div', 'name', t.name));
        row.appendChild(el('div', 'sub', (t.description || '').replace(/\s+/g, ' ')));
        var ps = props(t), rq = required(t), keys = Object.keys(ps);
        if (keys.length) { var chips = el('div', 'chips'); keys.forEach(function (k) { chips.appendChild(el('span', 'tn-chip' + (rq.indexOf(k) >= 0 ? ' req' : ''), k)); }); row.appendChild(chips); }
        var u = './code/lib/tools/' + fileOf(t.name).split('/').map(encodeURIComponent).join('/');
        row.addEventListener('click', function () { go(u, t.name); });
        row._nk = { open: function () { go(u, t.name); } };
        list.appendChild(row);
      });
    }
    function load() {
      if (dead) return;
      Promise.all([
        get(withPath('/api/tools-tree', at)).then(function (tree) { tools = flatten(tree).sort(function (a, b) { return a.name < b.name ? -1 : a.name > b.name ? 1 : 0; }); err = null; }, function (e) { tools = []; err = 'could not read the tools nexus at ' + at + ': ' + e.message; }),
        get(withPath('/api/runs', at)).then(function (r) { runs = Array.isArray(r) ? r : []; }, function () { runs = []; })
      ]).then(function () { if (!dead) render(); });
    }
    filter.addEventListener('input', render);
    tTools.addEventListener('click', function () { mode = 'tools'; render(); });
    tRuns.addEventListener('click', function () { mode = 'runs'; render(); });
    load();
    return handle;
  }

  // ---- tool: one tool, on its source file ----
  function mountTool(root, opts) {
    css();
    var at = opts.args && typeof opts.args.at === 'string' ? opts.args.at : null;
    var file = opts.args && typeof opts.args.file === 'string' ? opts.args.file : null;
    root.innerHTML = ''; root.classList.add('tn');
    var dead = false;
    var handle = { destroy: function () { dead = true; root.innerHTML = ''; root.classList.remove('tn'); }, onUpdate: function () { loadSource(); } };
    if (!at || !file) { root.appendChild(el('div', 'tn-err', 'no tool here')); return handle; }
    var name = nameOf(file);
    var box = el('div', 'tn-tool'); root.appendChild(box);
    var title = el('h2', null, name), where = el('div', 'where', file.replace(/^\//, '') + ' in ' + at);
    var desc = el('div', 'desc', ''), schemaBox = el('div'), runBox = el('div'), srcBox = el('div');
    box.appendChild(title); box.appendChild(where); box.appendChild(desc); box.appendChild(schemaBox); box.appendChild(runBox);
    var det = el('details'); det.open = true; det.appendChild(el('summary', null, 'source')); det.appendChild(srcBox); box.appendChild(det);
    var own = true;
    function schema(t) {
      schemaBox.innerHTML = '';
      schemaBox.appendChild(el('h3', null, 'parameters'));
      var ps = props(t), rq = required(t), keys = Object.keys(ps);
      if (!keys.length) { schemaBox.appendChild(el('div', 'tn-empty', 'No parameters.')); return; }
      var table = el('table'), hr = table.insertRow();
      ['parameter', 'type', '', 'description'].forEach(function (h) { var th = document.createElement('th'); th.textContent = h; hr.appendChild(th); });
      keys.forEach(function (k) {
        var tr = table.insertRow();
        tr.insertCell().appendChild(el('code', 'mono', k));
        var td = tr.insertCell(); td.className = 'type'; td.textContent = ps[k].type || '';
        var rc = tr.insertCell(); rc.className = 'req'; rc.textContent = rq.indexOf(k) >= 0 ? 'required' : '';
        tr.insertCell().textContent = ps[k].description || '';
      });
      schemaBox.appendChild(table);
    }
    // the form is an MCP client: tools/call to the endpoint, the request
    // Claude makes, so a run here is exactly a run there
    function form(t) {
      runBox.innerHTML = '';
      runBox.appendChild(el('h3', null, 'run'));
      var f = el('form', 'tn-form'), ps = props(t), rq = required(t), fields = [];
      Object.keys(ps).forEach(function (k) {
        var def = ps[k], label = el('label'), input;
        if (def.type === 'boolean') { input = el('input'); input.type = 'checkbox'; label.className = 'check'; label.appendChild(input); label.appendChild(document.createTextNode(k)); }
        else {
          label.appendChild(document.createTextNode(k + (rq.indexOf(k) >= 0 ? ' *' : '')));
          if (def.type === 'object' || def.type === 'array') { input = el('textarea'); input.rows = 3; input.placeholder = def.type === 'array' ? '[…]' : '{…}'; }
          else { input = el('input'); input.type = 'text'; input.placeholder = def.description || def.type || ''; }
          input.spellcheck = false; label.appendChild(input);
        }
        label.title = def.description || '';
        f.appendChild(label); fields.push({ k: k, def: def, input: input });
      });
      if (!own) f.appendChild(el('div', 'note', 'called as call_tool with path=' + at));
      var acts = el('div', 'acts'), btn = el('button', null, 'run'), note = el('span', 'note', '');
      btn.type = 'submit'; acts.appendChild(btn); acts.appendChild(note); f.appendChild(acts);
      var out = el('pre', 'tn-out'); out.hidden = true; f.appendChild(out);
      f.addEventListener('submit', function (e) {
        e.preventDefault();
        var args = {};
        try {
          fields.forEach(function (fd) {
            if (fd.def.type === 'boolean') { if (fd.input.checked) args[fd.k] = true; return; }
            var raw = fd.input.value.trim();
            if (!raw) { if (rq.indexOf(fd.k) >= 0) throw new Error(fd.k + ' is required'); return; }
            if (fd.def.type === 'number') { var n = Number(raw); if (isNaN(n)) throw new Error(fd.k + ' must be a number'); args[fd.k] = n; }
            else if (fd.def.type === 'object' || fd.def.type === 'array') args[fd.k] = JSON.parse(raw);
            else args[fd.k] = raw;
          });
        } catch (err) { note.className = 'note err'; note.textContent = err.message; return; }
        btn.disabled = true; note.className = 'note'; note.textContent = 'running…'; out.hidden = true;
        (own ? rpc(t.name, args) : rpc('call_tool', { tool_name: t.name, path: at, tool_args: args }))
          .then(function (res) {
            var bad = !!res.error;
            note.className = 'note' + (bad ? ' err' : ''); note.textContent = bad ? 'error' : 'done';
            var text = bad ? res.error.message : ((res.result && res.result.content) || []).map(function (c) { return c.text !== undefined ? c.text : JSON.stringify(c); }).join('\n');
            out.className = 'tn-out' + (bad ? ' err' : ''); out.textContent = text || JSON.stringify(res, null, 2); out.hidden = false;
          }, function (err) { note.className = 'note err'; note.textContent = err.message; })
          .then(function () { btn.disabled = false; });
      });
      runBox.appendChild(f);
    }
    function loadSource() {
      if (dead) return;
      get(withPath('/api/src?tool=' + encodeURIComponent(name), at)).then(function (res) {
        if (dead) return;
        srcBox.innerHTML = ''; srcBox.appendChild(highlight(res.text || ''));
      }, function (e) { if (!dead) { srcBox.innerHTML = ''; srcBox.appendChild(el('div', 'tn-err', 'no source: ' + e.message)); } });
    }
    function load() {
      get(withPath('/api/tools-tree', at)).then(function (tree) {
        if (dead) return;
        own = !!tree.own;
        var t = flatten(tree).filter(function (x) { return x.name === name; })[0];
        if (!t) { desc.textContent = ''; schemaBox.innerHTML = ''; runBox.innerHTML = ''; runBox.appendChild(el('div', 'tn-err', 'not a compiled tool: ' + name + ' is not among the tools at ' + at + ' (it may not build; see the source below)')); return; }
        desc.textContent = t.description || '';
        schema(t); form(t);
      }, function (e) { if (!dead) { runBox.innerHTML = ''; runBox.appendChild(el('div', 'tn-err', 'could not read the tools nexus at ' + at + ': ' + e.message)); } });
      loadSource();
    }
    load();
    return handle;
  }

  window.Viewers = window.Viewers || {};
  window.Viewers['tools-nexus'] = { label: 'Tools', mount: mountToolsNexus };
  window.Viewers['tool'] = { label: 'Tool', mount: mountTool };
})();
