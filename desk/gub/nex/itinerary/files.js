// Files tab — the explorer's browse app, scrapped for parts and fenced
// into one itinerary's attachment directory. Same kit components
// (<file-table>, <file-grid>, <drop-menu>, <modal-dialog>), same server:
// every read is `<dir>?list=1` and every action is a POST to the dir URL,
// exactly as the explorer does it. Nothing new on the Hoon side.
//
// The fence is client-side by construction: ROOT is the trip's own
// /grubbery/ball/apps/itinerary/itineraries/<id>/files and nav() never
// climbs above it; move/copy destinations are relative to it. files/ is
// created lazily on first upload/new-folder, so untouched trips cost nothing.
'use strict';

// This is a classic script; the kit components arrive via a module script
// that runs later. Setting columns/actions on a not-yet-upgraded element
// creates own properties that shadow the class setters, so wait for the
// upgrade before touching them.
Promise.all([
  customElements.whenDefined('file-table'),
  customElements.whenDefined('file-grid'),
  customElements.whenDefined('drop-menu'),
  customElements.whenDefined('modal-dialog'),
]).then(function () {
  var $ = function (id) { return document.getElementById(id); };
  var ITINS = '/grubbery/ball/apps/itinerary/itineraries';

  var ft = $('files-ft');
  var fg = $('files-fg');
  var panel = $('files-panel');
  var body = $('files-body');

  var root = null;      // ITINS + '/<id>/files'
  var here = null;      // current dir URL (root or deeper)
  var data = null;      // last ?list=1 payload
  var missing = false;  // root dir not created yet
  var view = 'list';
  try { view = localStorage.getItem('itin-files-view') || 'list'; } catch (_) {}

  function rel() { return here.slice(root.length) || '/'; }     // '/', '/sub'
  function join(base, name) { return base.replace(/\/$/, '') + '/' + name; }
  function fmtSize(n) {
    if (n == null) return '–';
    if (n < 1024) return n + ' B';
    if (n < 1024 * 1024) return Math.round(n / 1024) + ' KB';
    return (n / (1024 * 1024)).toFixed(1) + ' MB';
  }
  function isImage(item) { return item.kind === 'file' && /^image\//.test(item.mime || ''); }

  // ---- table / grid setup ----
  ft.columns = [
    {
      key: 'name', label: 'Name',
      format: function (v, item) { return item.kind === 'dir' ? v + '/' : v; },
      link: function (item) { return join(here, item.name); },
    },
    { key: 'size', label: 'Size', cls: 'mono',
      format: function (v, item) { return item.kind === 'file' ? fmtSize(v) : '–'; } },
    { key: 'modified', label: 'Modified', cls: 'mono' },
  ];
  var ACTS = [
    { label: 'Open', action: 'open' },
    { label: 'Open in explorer', action: 'explorer' },
    { label: 'Download', action: 'download' },
    { label: 'Rename', action: 'rename' },
    { label: 'Move', action: 'move' },
    { label: 'Copy', action: 'copy' },
    { label: 'Delete', action: 'delete', danger: true },
  ];
  ft.actions = function (item) {
    if (item.kind !== 'dir') return ACTS;
    return ACTS.filter(function (a) { return a.action !== 'open' && a.action !== 'explorer'; });
  };
  fg.actions = ft.actions;
  fg.icon = function (item) { return isImage(item) ? join(here, item.name) + '?raw=1' : null; };

  function setView(v) {
    view = v;
    try { localStorage.setItem('itin-files-view', v); } catch (_) {}
    ft.style.display = v === 'list' ? '' : 'none';
    fg.style.display = v === 'grid' ? '' : 'none';
    $('fv-list').classList.toggle('on', v === 'list');
    $('fv-grid').classList.toggle('on', v === 'grid');
  }
  $('fv-list').addEventListener('click', function () { setView('list'); });
  $('fv-grid').addEventListener('click', function () { setView('grid'); });
  setView(view);

  // ---- navigation, clamped to root ----
  function nav(url) {
    if (!root) return;
    if (url.indexOf(root) !== 0) url = root;
    here = url;
    renderCrumbs();
    if (view === 'list') ft.showLoading(); else fg.showLoading();
    load();
  }
  function onNavigate(e) {
    var item = e.detail.item, href = e.detail.href;
    if (!item || item.kind === 'dir') { nav(href); return; }
    openViewer(item);
  }
  ft.addEventListener('ft-navigate', onNavigate);
  fg.addEventListener('ft-navigate', onNavigate);

  function renderCrumbs() {
    var c = $('files-crumbs');
    c.textContent = '';
    var segs = rel() === '/' ? [] : rel().slice(1).split('/');
    var a = document.createElement('a');
    a.textContent = 'files/';
    a.href = '#';
    a.addEventListener('click', function (e) { e.preventDefault(); nav(root); });
    c.appendChild(a);
    var acc = root;
    segs.forEach(function (s, i) {
      acc = join(acc, s);
      if (i === segs.length - 1) {
        var sp = document.createElement('span');
        sp.className = 'here';
        sp.textContent = s + '/';
        c.appendChild(sp);
      } else {
        var l = document.createElement('a');
        var target = acc;
        l.textContent = s + '/';
        l.href = '#';
        l.addEventListener('click', function (e) { e.preventDefault(); nav(target); });
        c.appendChild(l);
      }
    });
  }

  // ---- load ----
  async function load() {
    if (!root) return;
    var url = here;
    var r;
    try {
      r = await fetch(url + '?list=1');
    } catch (e) { toast('listing failed: ' + e, true); return; }
    if (url !== here) return;   // itinerary switched mid-flight
    if (r.status === 404 && here === root) {
      missing = true;
      data = { children: [] };
    } else if (!r.ok) {
      toast('listing failed (' + r.status + ')', true); return;
    } else {
      missing = false;
      try { data = await r.json(); } catch (e) { toast('bad listing', true); return; }
    }
    ft.parentHref = here !== root ? here.split('/').slice(0, -1).join('/') : null;
    ft.items = data.children;
    fg.baseHref = here;
    fg.items = data.children;
    $('files-empty').classList.toggle('hidden', data.children.length > 0);
  }

  // ---- actions ----
  // make sure the trip's files/ exists: POST create-folder to the trip dir
  async function ensureRoot() {
    if (!missing) return true;
    var r = await fetch(root.slice(0, -'/files'.length), {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      redirect: 'manual',
      body: new URLSearchParams({ action: 'create-folder', foldername: 'files' }),
    });
    if (r.status >= 400) { toast(await r.text() || 'could not create folder', true); return false; }
    missing = false;
    return true;
  }

  async function post(params) {
    try {
      if (!(await ensureRoot())) return;
      var r = await fetch(here, {
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
    var fd = new FormData();
    for (var i = 0; i < files.length; i++) {
      var f = files[i];
      fd.append('file', f, (withPaths && f.webkitRelativePath) || f.name);
    }
    toast('uploading…');
    try {
      if (!(await ensureRoot())) return;
      var r = await fetch(here, { method: 'POST', redirect: 'manual', body: fd });
      if (r.status >= 400) { toast(await r.text() || 'upload failed', true); return; }
      toast('uploaded ✓');
      load();
    } catch (e) { toast('upload failed: ' + e, true); }
  }

  // dest paths are typed relative to the trip's files/ root and rewritten
  // to the namespace path the explorer expects
  function nsPath(relPath) {
    var p = relPath.trim();
    if (p.charAt(0) !== '/') p = '/' + p;
    return root.slice('/grubbery/ball'.length) + p;
  }

  function handleAction(e) {
    var action = e.detail.action, item = e.detail.item;
    var base = join(here, item.name);
    var relHere = rel() === '/' ? '' : rel();
    var isDir = item.kind === 'dir';
    switch (action) {
      case 'open': openViewer(item); break;
      case 'explorer': window.open(base, '_blank'); break;
      case 'download':
        if (isDir) { window.open(base + '?download=tar', '_blank'); break; }
        var l = document.createElement('a');
        l.href = base + '?raw=1'; l.download = item.name; l.click();
        break;
      case 'rename':
        ask('Rename ' + item.name, item.name, function (nn) {
          if (!nn || nn === item.name) return;
          post(isDir ? { action: 'rename-folder', foldername: item.name, newname: nn }
                     : { action: 'rename-grub', filename: item.name, newname: nn });
        });
        break;
      case 'move':
        ask('Move ' + item.name + ' to', relHere + '/' + item.name, function (d) {
          if (!d) return;
          post(isDir ? { action: 'move-folder', foldername: item.name, dest: nsPath(d) }
                     : { action: 'move-grub', filename: item.name, dest: nsPath(d) });
        });
        break;
      case 'copy':
        ask('Copy ' + item.name + ' to', relHere + '/' + (isDir ? item.name + '-copy' : item.name), function (d) {
          if (!d) return;
          post(isDir ? { action: 'copy-folder', foldername: item.name, dest: nsPath(d) }
                     : { action: 'copy-grub', filename: item.name, dest: nsPath(d) });
        });
        break;
      case 'delete':
        if (confirm('Delete ' + item.name + (isDir ? '/' : '') + '?'))
          post(isDir ? { action: 'delete-folder', foldername: item.name }
                     : { action: 'delete-grub', filename: item.name });
        break;
    }
  }
  ft.addEventListener('ft-action', handleAction);
  fg.addEventListener('ft-action', handleAction);

  // ---- dialogs ----
  function ask(title, initial, fn) {
    $('files-ask-title').textContent = title;
    var inp = $('files-ask-input');
    inp.value = initial;
    var done = function () { $('files-ask-modal').close(); fn(inp.value.trim()); };
    $('files-ask-go').onclick = done;
    inp.onkeydown = function (e) { if (e.key === 'Enter') done(); };
    $('files-ask-modal').show();
    inp.focus();
    inp.select();
  }

  // ---- menu (toolbar + context) ----
  function menuAction(k) {
    switch (k) {
      case 'upload': $('files-pick').click(); break;
      case 'upload-dir': $('files-pick-dir').click(); break;
      case 'folder':
        ask('New folder', '', function (n) { if (n) post({ action: 'create-folder', foldername: n }); });
        break;
      case 'download': window.open(here + '?download=tar', '_blank'); break;
    }
  }
  panel.querySelectorAll('[data-fm]').forEach(function (b) {
    b.addEventListener('click', function () { menuAction(b.dataset.fm); });
  });
  $('files-pick').addEventListener('change', function () {
    upload(Array.prototype.slice.call(this.files), false);
    this.value = '';
  });
  $('files-pick-dir').addEventListener('change', function () {
    upload(Array.prototype.slice.call(this.files), true);
    this.value = '';
  });

  var ctx = $('files-ctx');
  function showCtx(x, y) {
    ctx.style.display = '';
    ctx.style.left = x + 'px';
    ctx.style.top = y + 'px';
    ctx.removeAttribute('flip');
    ctx.open();
  }
  body.addEventListener('contextmenu', function (e) {
    e.preventDefault();
    ctx.querySelectorAll('[data-item-act]').forEach(function (b) { b.remove(); });
    var hit = e.composedPath().find(function (el) { return el && el.__item; });
    var target = view === 'list' ? ft : fg;
    if (hit) {
      ctx.querySelectorAll('[data-fm]').forEach(function (b) { b.style.display = 'none'; });
      ft.actions(hit.__item).forEach(function (a) {
        var b = document.createElement('button');
        b.className = 'mi' + (a.danger ? ' danger' : '');
        b.textContent = a.label;
        b.setAttribute('data-item-act', '');
        b.addEventListener('click', function () {
          target.dispatchEvent(new CustomEvent('ft-action', {
            bubbles: true, composed: true, detail: { action: a.action, item: hit.__item },
          }));
        });
        ctx.appendChild(b);
      });
    } else {
      ctx.querySelectorAll('[data-fm]').forEach(function (b) { b.style.display = ''; });
    }
    showCtx(e.clientX, e.clientY);
  });
  ctx.addEventListener('dm-close', function () {
    ctx.style.display = 'none';
    ctx.querySelectorAll('[data-item-act]').forEach(function (b) { b.remove(); });
    ctx.querySelectorAll('[data-fm]').forEach(function (b) { b.style.display = ''; });
  });

  // ---- drag & drop upload ----
  var dragDepth = 0;
  panel.addEventListener('dragenter', function (e) {
    if (!root) return;
    e.preventDefault();
    if (dragDepth++ === 0) $('files-drop').classList.remove('hidden');
  });
  panel.addEventListener('dragover', function (e) { e.preventDefault(); });
  panel.addEventListener('dragleave', function () {
    if (--dragDepth <= 0) { dragDepth = 0; $('files-drop').classList.add('hidden'); }
  });
  panel.addEventListener('drop', function (e) {
    e.preventDefault();
    dragDepth = 0;
    $('files-drop').classList.add('hidden');
    if (!root || !e.dataTransfer) return;
    upload(Array.prototype.slice.call(e.dataTransfer.files), false);
  });

  // ---- viewer / editor ----
  // The explorer's file page, folded into a modal: ?info=1 says what the
  // file is, ?raw=1 gives the bytes, action=write-text POSTed to the file
  // URL saves through the grub's own blot (the marc validates; a failed
  // parse comes back as a 422 tang we show in the status).
  var fm = $('file-modal');
  var fmSrc = $('fm-src'), fmEd = $('fm-ed'), fmPrev = $('fm-prev');
  var fmEdit = $('fm-edit'), fmSave = $('fm-save'), fmStatus = $('fm-status');
  var fmTabSrc = $('fm-tab-src'), fmTabPrev = $('fm-tab-prev');
  var vf = null;   // { url, name, ext, editable, clean, editing, tab, mite }

  function extOf(name) {
    var m = /\.([a-z0-9]+)$/i.exec(name || '');
    return m ? m[1].toLowerCase() : '';
  }
  function hasPreview(name) {
    var ext = extOf(name);
    return ext === 'md' || ext === 'markdown' || ext === 'csv' ||
      !!(window.FilePreview && FilePreview.kind(name));
  }
  function present(text, ext) {
    if (ext === 'json') {
      try { return JSON.stringify(JSON.parse(text), null, 2); } catch (_) {}
    }
    return text;
  }
  function fmSetStatus(msg, err) {
    fmStatus.textContent = msg || '';
    fmStatus.classList.toggle('err', !!err);
    fmStatus.title = err ? msg : '';
  }

  async function openViewer(item) {
    var url = join(here, item.name);
    vf = { url: url, name: item.name, ext: extOf(item.name), editable: false,
           clean: '', editing: false, tab: 'src', mite: item.mime || '' };
    $('fm-name').textContent = item.name;
    $('fm-ext').href = url;
    fmSrc.textContent = '';
    fmEd.value = '';
    fmPrev.textContent = '';
    fmEdit.classList.remove('on');
    fmSetStatus('loading…');
    fm.show();
    var info;
    try {
      info = await (await fetch(url + '?info=1', { headers: { accept: 'application/json' } })).json();
    } catch (e) { fmSetStatus('could not read file', true); return; }
    if (!vf || vf.url !== url) return;
    if (info.kind !== 'file') { fmSetStatus(info.kind === 'boom' ? 'file is broken' : 'not found', true); return; }
    vf.mite = info.mite || vf.mite;
    vf.editable = !!info.texty && !info.jammed;
    if (vf.editable) {
      try {
        vf.clean = present(await (await fetch(url + '?raw=1')).text(), vf.ext);
      } catch (e) { fmSetStatus('could not read file', true); return; }
      if (!vf || vf.url !== url) return;
      fmEd.value = vf.clean;
      fmSrc.textContent = vf.clean;
    } else if (info.jammed) {
      fmSrc.textContent = info.text || '';
    } else {
      fmSrc.textContent = 'binary content — ' + vf.mite;
    }
    fmSetStatus('');
    fmEdit.disabled = !vf.editable;
    fmSave.disabled = true;
    var prev = hasPreview(vf.name);
    fmTabSrc.classList.toggle('hidden', !prev);
    fmTabPrev.classList.toggle('hidden', !prev);
    fmShow(prev ? 'prev' : 'src');
  }

  function fmShow(tab) {
    if (!vf) return;
    vf.tab = tab;
    fmTabSrc.classList.toggle('on', tab === 'src');
    fmTabPrev.classList.toggle('on', tab === 'prev');
    fmPrev.classList.toggle('hidden', tab !== 'prev');
    var showEd = tab === 'src' && vf.editing;
    fmEd.classList.toggle('hidden', !showEd);
    fmSrc.classList.toggle('hidden', tab !== 'src' || showEd);
    if (tab === 'prev') renderPreview();
  }
  fmTabSrc.addEventListener('click', function () { fmShow('src'); });
  fmTabPrev.addEventListener('click', function () { fmShow('prev'); });

  function renderPreview() {
    var ext = vf.ext;
    var text = vf.editable ? fmEd.value : (fmSrc.textContent || '');
    var rawUrl = vf.url + '?raw=1';
    fmPrev.textContent = '';
    fmPrev.removeAttribute('style');
    if (ext === 'md' || ext === 'markdown') {
      var d = document.createElement('div');
      d.className = 'fm-md';
      try { d.innerHTML = window.marked ? marked.parse(text) : text; }
      catch (_) { d.textContent = text; }
      fmPrev.appendChild(d);
      return;
    }
    if (ext === 'csv') {
      var t = document.createElement('table');
      t.className = 'fm-csv';
      text.trim().split('\n').forEach(function (r, i) {
        var tr = document.createElement('tr');
        r.split(',').forEach(function (c) {
          var cell = document.createElement(i === 0 ? 'th' : 'td');
          cell.textContent = c.trim();
          tr.appendChild(cell);
        });
        t.appendChild(tr);
      });
      fmPrev.appendChild(t);
      return;
    }
    if (window.FilePreview && FilePreview.kind(vf.name)) {
      FilePreview.render(fmPrev, { name: vf.name, text: vf.editable ? text : null, rawUrl: rawUrl });
    }
  }

  fmEdit.addEventListener('click', function () {
    if (!vf || !vf.editable) return;
    vf.editing = !vf.editing;
    fmEdit.classList.toggle('on', vf.editing);
    if (!vf.editing) fmSrc.textContent = fmEd.value;
    fmShow('src');
    if (vf.editing) fmEd.focus();
  });
  fmEd.addEventListener('input', function () {
    if (vf) fmSave.disabled = fmEd.value === vf.clean;
  });
  fmEd.addEventListener('keydown', function (e) {
    if (e.key === 'Tab') {
      e.preventDefault();
      var s = fmEd.selectionStart, en = fmEd.selectionEnd;
      fmEd.setRangeText('  ', s, en, 'end');
      fmEd.dispatchEvent(new Event('input'));
    }
    if ((e.metaKey || e.ctrlKey) && e.key === 's') { e.preventDefault(); fmSaveNow(); }
  });
  fmSave.addEventListener('click', fmSaveNow);

  async function fmSaveNow() {
    if (!vf || !vf.editable || fmEd.value === vf.clean) return;
    var url = vf.url, sent = fmEd.value;
    fmSetStatus('saving…');
    try {
      var r = await fetch(url, {
        method: 'POST',
        headers: { 'content-type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ action: 'write-text', content: sent }),
      });
      var body = await r.text();
      if (!vf || vf.url !== url) return;
      if (!r.ok) { fmSetStatus(body || ('save failed (' + r.status + ')'), true); return; }
      var stored = present(await (await fetch(url + '?raw=1')).text(), vf.ext);
      vf.clean = stored;
      if (fmEd.value === sent && stored !== sent) fmEd.value = stored;
      fmSrc.textContent = fmEd.value;
      fmSave.disabled = fmEd.value === vf.clean;
      fmSetStatus('saved ✓');
      setTimeout(function () { if (fmStatus.textContent === 'saved ✓') fmSetStatus(''); }, 2500);
      load();
    } catch (e) { fmSetStatus('save failed: ' + e, true); }
  }
  fm.addEventListener('md-close', function () {
    if (vf && vf.editable && fmEd.value !== vf.clean &&
        !confirm('Discard unsaved changes to ' + vf.name + '?')) {
      // reopen: native dialog already closed; show it again with state intact
      fm.show();
      return;
    }
    vf = null;
    fmPrev.textContent = '';
  });

  // ---- toast ----
  var toastTimer = null;
  function toast(msg, err) {
    var s = $('files-status');
    s.textContent = msg;
    s.className = err ? 'err' : '';
    s.style.display = 'block';
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { s.style.display = 'none'; }, err ? 6000 : 2000);
  }

  // ---- itinerary binding ----
  // only fetch once the tab is actually visible; cheap tabs stay cheap
  var loaded = false;
  function visible() {
    var tg = $('side-tabs');
    return tg && !tg.hasAttribute('hidden') && panel.offsetParent !== null;
  }
  function bind() {
    var id = window.currentId;
    if (!id) { root = null; here = null; ft.items = []; fg.items = []; return; }
    root = ITINS + '/' + encodeURIComponent(id) + '/files';
    here = root;
    loaded = false;
    renderCrumbs();
    if (visible()) { loaded = true; nav(root); }
  }
  window.addEventListener('itin-changed', bind);
  $('side-tabs').addEventListener('tg-change', function (e) {
    if (e.detail.label === 'Files' && root && !loaded) { loaded = true; nav(root); }
  });
  if (window.currentId) bind();
});
