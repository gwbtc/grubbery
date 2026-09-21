// <FileManager> — a file manager fenced to one directory, mounted into any
// element. The explorer's browse app scrapped for parts: same kit components
// (<file-table>, <file-grid>, <drop-menu>, <modal-dialog>), same server —
// every read is `<dir>?list=1`, every action is a POST to the dir URL, exactly
// as the explorer does it. Nothing new on the Hoon side, ever: a nexus that
// wants a file surface gives it a directory.
//
// USAGE (classic script; load AFTER the kit components' module script and
// file-preview.js, BEFORE your app.js):
//
//   <div id="files"></div>
//   <script src=".../file-preview.js"></script>
//   <script src=".../file-manager.js"></script>
//   var fm = FileManager.mount(document.getElementById('files'), {
//     root: '/grubbery/ball/apps/foo/library',   // the fenced dir URL
//     rootLabel: 'library',                       // crumb label (default: last segment)
//     persist: 'foo-files-view',                  // localStorage key for list|grid
//     explorerLink: true,                         // "open in explorer" row action
//     lazy: false,                                // true = don't load until .load()
//   });
//   fm.setRoot(url)   // re-fence (e.g. when the host switches documents)
//   fm.load()         // (re)fetch the listing
//   fm.open(path, {from, to})   // viewer, scrolled to + highlighting lines
//   fm.open(path, {edit: true}) // viewer in edit mode
//
// The fence is client-side by construction: nav() never climbs above root,
// move/copy destinations are relative to it. The root dir itself is created
// lazily under its parent on the first write, so an empty surface costs no
// grub. Files open in a viewer modal: Source|Preview (markdown via
// window.marked if the host loaded it, csv as a table, svg/html/json/image/
// pdf via window.FilePreview), Edit toggles a textarea, Save posts
// action=write-text so the grub's own blot validates the edit.
//
// Styling is injected once, scoped under .files-panel and the two modals.
// The host sizes the mount element; everything inside is the lib's.
(function () {
  'use strict';
  var CSS = '/* file-manager: the browse surface */\n.files-panel {\n  font: 13px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;\n  color: #1f2328;\n  height: 100%;\n  display: flex;\n  flex-direction: column;\n  overflow: hidden;\n  position: relative;\n  background: #fff;\n}\n.files-bar {\n  display: flex;\n  align-items: center;\n  gap: 6px;\n  padding: 6px 10px;\n  border-bottom: 1px solid #eee;\n  min-height: 38px;\n}\n.files-bar .grow { flex: 1; }\n.files-crumbs {\n  display: flex;\n  align-items: center;\n  gap: 1px;\n  font: 600 12px ui-monospace, SFMono-Regular, Menlo, monospace;\n  white-space: nowrap;\n  overflow: hidden;\n  text-overflow: ellipsis;\n}\n.files-crumbs a { color: #57606a; padding: 2px 3px; border-radius: 5px; text-decoration: none; }\n.files-crumbs a:hover { color: #24292f; background: #eaeef2; }\n.files-crumbs .here { color: #24292f; padding: 2px 3px; }\n.files-view { display: inline-flex; gap: 2px; }\n.files-view button,\n.files-add {\n  all: unset;\n  cursor: pointer;\n  padding: 3px 9px;\n  border-radius: 6px;\n  font-size: 12px;\n  color: #57606a;\n  border: 1px solid #ddd;\n  background: #fff;\n  line-height: 1.4;\n}\n.files-view button:hover, .files-add:hover { background: #f5f5f5; color: #24292f; }\n.files-view button.on { background: #f0f0f0; color: #1a1a1a; border-color: #ccc; }\n.files-menu button:not([slot]), .files-ctx button:not([slot]) {\n  display: block;\n  width: 100%;\n  text-align: left;\n  padding: 7px 14px;\n  border: none;\n  background: none;\n  font-size: 13px;\n  font-family: inherit;\n  color: #333;\n  cursor: pointer;\n  border-radius: 6px;\n  white-space: nowrap;\n}\n.files-menu button:not([slot]):hover, .files-ctx button:not([slot]):hover { background: #f5f5f5; }\n.files-ctx button.danger { color: #cf222e; }\n.files-body { flex: 1; overflow: auto; position: relative; min-height: 0; }\n.files-body file-table { --ft-header-top: 0; font-size: 12px; }\n.files-body file-grid { padding: 6px; }\n.files-empty {\n  padding: 28px 16px;\n  text-align: center;\n  color: #9aa0a6;\n  font-size: 13px;\n}\n.files-drop {\n  position: absolute;\n  inset: 6px;\n  display: flex;\n  align-items: center;\n  justify-content: center;\n  border: 2px dashed #1a1a1a;\n  border-radius: 10px;\n  background: rgba(255,255,255,0.85);\n  color: #1a1a1a;\n  font-weight: 600;\n  font-size: 14px;\n  pointer-events: none;\n  z-index: 3;\n}\n.files-status {\n  display: none;\n  position: absolute;\n  left: 10px;\n  bottom: 10px;\n  padding: 6px 12px;\n  border-radius: 8px;\n  background: #1a1a1a;\n  color: #fff;\n  font-size: 12px;\n  z-index: 4;\n  box-shadow: 0 4px 14px rgba(0,0,0,0.18);\n}\n.files-status.err { background: #cf222e; }\n.files-ask-modal input { width: 100%; }\n\n/* file-manager: the viewer modal */\n.file-modal { --md-width: min(1000px, 94vw); --md-pad: 0; }\n.fm-wrap { display: flex; flex-direction: column; height: min(80vh, 760px); }\n.fm-bar {\n  display: flex;\n  align-items: center;\n  gap: 8px;\n  padding: 8px 12px;\n  border-bottom: 1px solid #eee;\n  background: #fafafa;\n  min-height: 42px;\n}\n.fm-bar .grow { flex: 1; }\n.fm-tabs { display: inline-flex; gap: 2px; }\n.fm-tabs button {\n  all: unset;\n  cursor: pointer;\n  padding: 3px 10px;\n  border-radius: 6px;\n  font-size: 12px;\n  color: #57606a;\n}\n.fm-tabs button:hover { background: #eef0f2; color: #24292f; }\n.fm-tabs button.on { background: #1a1a1a; color: #fff; }\n.fm-name {\n  font: 600 13px ui-monospace, SFMono-Regular, Menlo, monospace;\n  color: #24292f;\n  white-space: nowrap;\n  overflow: hidden;\n  text-overflow: ellipsis;\n  margin-left: 6px;\n}\n.fm-chip { display: inline-flex; align-items: center; gap: 4px; padding: 1px 7px; border-radius: 6px; background: #eef1f4; border: 1px solid #e2e7ee; font: 11px ui-monospace, Menlo, monospace; color: #57606a; white-space: nowrap; }\n.fm-chip:empty { display: none; }\n.fm-status { font-size: 12px; color: #57606a; max-width: 40%; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }\n.fm-status.err { color: #cf222e; }\n.fm-tool {\n  all: unset;\n  cursor: pointer;\n  padding: 3px 10px;\n  border-radius: 6px;\n  font-size: 12px;\n  color: #24292f;\n  border: 1px solid #ddd;\n  background: #fff;\n  line-height: 1.4;\n  text-decoration: none;\n}\n.fm-tool:hover { background: #f5f5f5; }\n.fm-tool.on { background: #1a1a1a; color: #fff; border-color: #1a1a1a; }\n.fm-tool[disabled] { opacity: .4; cursor: default; }\n.fm-close { font-size: 16px; padding: 1px 8px; }\n.fm-body { flex: 1; min-height: 0; position: relative; display: flex; flex-direction: column; }\n.fm-src, .fm-ed {\n  flex: 1;\n  min-height: 0;\n  margin: 0;\n  padding: 14px 18px;\n  overflow: auto;\n  font: 12.5px/1.55 ui-monospace, SFMono-Regular, Menlo, monospace;\n  color: #24292f;\n  white-space: pre-wrap;\n  overflow-wrap: anywhere;\n  background: #fff;\n}\n.fm-src { padding-left: 0; }\n.fm-line { display: flex; }\n.fm-line .ln { flex: 0 0 52px; padding-right: 12px; text-align: right; color: #c4c8cd; user-select: none; }\n.fm-line .lt { flex: 1; min-width: 0; padding-right: 18px; white-space: pre-wrap; overflow-wrap: anywhere; }\n.fm-line.hit { background: #fff8c5; }\n.fm-line.hit .ln { color: #6a5c00; }\n.fm-src.plain { padding-left: 18px; }\n.fm-ed {\n  border: none;\n  outline: none;\n  resize: none;\n  white-space: pre;\n  box-shadow: inset 0 0 0 2px #e8f0fe;\n}\n.fm-prev { flex: 1; min-height: 0; overflow: auto; }\n.fm-prev .fm-md { max-width: 74ch; padding: 20px 28px; line-height: 1.65; font-size: 14px; color: #24292f; }\n.fm-prev .fm-md h1, .fm-prev .fm-md h2, .fm-prev .fm-md h3 { border-bottom: 1px solid #e2e7ee; padding-bottom: .3em; }\n.fm-prev .fm-md code { background: #f2f4f7; padding: 1px 5px; border-radius: 5px; font: 12px ui-monospace, monospace; }\n.fm-prev .fm-md pre { background: #f6f8fa; border-radius: 8px; padding: 10px 12px; overflow: auto; }\n.fm-prev .fm-md pre code { background: none; padding: 0; }\n.fm-prev .fm-md table { border-collapse: collapse; }\n.fm-prev .fm-md th, .fm-prev .fm-md td { border: 1px solid #d0d7de; padding: 4px 10px; }\n.fm-prev .fm-md blockquote { border-left: 3px solid #d0d7de; margin-left: 0; padding-left: 14px; color: #57606a; }\n.fm-prev .fm-csv { border-collapse: collapse; margin: 20px; font: 12px ui-monospace, monospace; }\n.fm-prev .fm-csv th, .fm-prev .fm-csv td { border: 1px solid #d0d7de; padding: 5px 12px; text-align: left; }\n.fm-prev .fm-csv th { background: #f6f8fa; }\n\n.files-panel .hidden { display: none !important; }\n.files-panel .grow { flex: 1; }\n.files-ask-modal { --md-width: 420px; }\n.fm-ask-head { font-weight: 600; font-size: 14px; margin-bottom: 10px; }\n.files-ask-modal input { width: 100%; box-sizing: border-box; padding: 8px 10px; border: 1px solid #ddd; border-radius: 8px; font: 13px ui-monospace, Menlo, monospace; }\n.fm-ask-actions { display: flex; justify-content: flex-end; gap: 8px; margin-top: 12px; }\n';
  var MARKUP = '<div class="files-panel">\n  <div class="files-bar">\n    <span class="files-crumbs" id="files-crumbs"></span>\n    <span class="grow"></span>\n    <span class="files-view">\n      <button id="fv-list" class="on" title="list view">&#9776;</button>\n      <button id="fv-grid" title="grid view">&#9638;</button>\n    </span>\n    <drop-menu align="end" class="files-menu">\n      <button slot="trigger" class="files-add" title="add">+ &#9662;</button>\n      <button class="mi" data-fm="new-file">New file&hellip;</button>\n      <button class="mi" data-fm="upload">Upload files&hellip;</button>\n      <button class="mi" data-fm="upload-dir">Upload directory&hellip;</button>\n      <button class="mi" data-fm="folder">New folder&hellip;</button>\n      <button class="mi" data-fm="download">Download all</button>\n    </drop-menu>\n  </div>\n  <div class="files-body" id="files-body">\n    <file-table id="files-ft"></file-table>\n    <file-grid id="files-fg" style="display:none"></file-grid>\n    <div class="files-empty hidden" id="files-empty">No files yet. Drop files here or use +.</div>\n    <div class="files-drop hidden" id="files-drop">Drop to upload</div>\n  </div>\n  <div class="files-status" id="files-status"></div>\n  <drop-menu class="files-ctx" id="files-ctx" style="position:fixed; display:none; z-index:50;">\n    <button slot="trigger" style="display:none"></button>\n    <button class="mi" data-fm="new-file">New file&hellip;</button>\n    <button class="mi" data-fm="upload">Upload files&hellip;</button>\n    <button class="mi" data-fm="upload-dir">Upload directory&hellip;</button>\n    <button class="mi" data-fm="folder">New folder&hellip;</button>\n  </drop-menu>\n  <modal-dialog class="files-ask-modal" id="files-ask-modal">\n    <div class="fm-ask-head" id="files-ask-title"></div>\n    <input id="files-ask-input" type="text" autocomplete="off" spellcheck="false">\n    <div class="fm-ask-actions">\n      <button data-close class="fm-tool">Cancel</button>\n      <button id="files-ask-go" class="fm-tool on">OK</button>\n    </div>\n  </modal-dialog>\n  <modal-dialog class="file-modal" id="file-modal" no-x>\n    <div class="fm-wrap">\n      <div class="fm-bar">\n        <span class="fm-tabs">\n          <button id="fm-tab-src">Source</button>\n          <button id="fm-tab-prev">Preview</button>\n        </span>\n        <span class="fm-name" id="fm-name"></span>\n        <span class="fm-chip" id="fm-blot" title="blot (the grub\'s type)"></span>\n        <span class="fm-chip" id="fm-mime" title="mime type"></span>\n        <span class="grow"></span>\n        <span class="fm-status" id="fm-status"></span>\n        <button id="fm-edit" class="fm-tool">Edit</button>\n        <button id="fm-save" class="fm-tool" disabled>Save</button>\n        <a id="fm-ext" class="fm-tool" target="_blank" rel="noopener" title="open in the explorer">&#8599;</a>\n        <button class="fm-tool fm-close" data-close title="close">&times;</button>\n      </div>\n      <div class="fm-body">\n        <pre class="fm-src" id="fm-src"></pre>\n        <textarea class="fm-ed hidden" id="fm-ed" spellcheck="false"></textarea>\n        <div class="fm-prev hidden" id="fm-prev"></div>\n      </div>\n    </div>\n  </modal-dialog>\n  <input type="file" id="files-pick" multiple hidden>\n  <input type="file" id="files-pick-dir" webkitdirectory directory hidden>\n</div>';
  var styled = false;
  var seq = 0;

  function mount(el, opts) {
    opts = opts || {};
    if (!styled) {
      var st = document.createElement('style');
      st.textContent = CSS;
      document.head.appendChild(st);
      styled = true;
    }
    // ids must be unique per mount; suffix them and resolve via $()
    var sfx = '-' + (++seq);
    el.innerHTML = MARKUP.replace(/ id="([a-z-]+)"/g, ' id="$1' + sfx + '"');
    var $ = function (id) { return el.querySelector('#' + id + sfx); };
    var handle = { el: el, load: null, setRoot: null };
    var ready = Promise.all([
      customElements.whenDefined('file-table'),
      customElements.whenDefined('file-grid'),
      customElements.whenDefined('drop-menu'),
      customElements.whenDefined('modal-dialog'),
    ]).then(function () { wire(el, $, opts, handle); });
    handle.ready = ready;
    return handle;
  }

  function wire(el, $, opts, handle) {

    var ft = $('files-ft');
    var fg = $('files-fg');
    var panel = el.querySelector('.files-panel');
    var body = $('files-body');
    var missing = false;

    var root = null;      // the fenced directory URL
    var here = null;      // current dir URL (root or deeper)
    var data = null;      // last ?list=1 payload
    var view = 'list';
    try { view = localStorage.getItem(opts.persist || 'file-manager-view') || 'list'; } catch (_) {}

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
      if (item.kind !== 'dir') return opts.explorerLink === false ? ACTS.filter(function (a) { return a.action !== 'explorer'; }) : ACTS;
      return ACTS.filter(function (a) { return a.action !== 'open' && a.action !== 'explorer'; });
    };
    fg.actions = ft.actions;
    fg.icon = function (item) { return isImage(item) ? join(here, item.name) + '?raw=1' : null; };

    function setView(v) {
      view = v;
      try { localStorage.setItem(opts.persist || 'file-manager-view', v); } catch (_) {}
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
      a.textContent = (opts.rootLabel || root.split('/').pop()) + '/';
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
      if (url !== here) return;   // root switched mid-flight
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
    // the fenced dir may not exist yet: create it under its parent on first write
    async function ensureRoot() {
      if (!missing) return true;
      var cut = root.lastIndexOf('/');
      var r = await fetch(root.slice(0, cut), {
        method: 'POST',
        headers: { 'content-type': 'application/x-www-form-urlencoded' },
        redirect: 'manual',
        body: new URLSearchParams({ action: 'create-folder', foldername: root.slice(cut + 1) }),
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
        if (r.status >= 400) { toast(await r.text() || 'failed (' + r.status + ')', true); throw new Error('failed'); }
        toast('done ✓');
        await load();
      } catch (e) { toast('failed: ' + e, true); throw e; }
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
        case 'new-file':
          ask('New file', 'untitled.md', function (n) {
            if (!n) return;
            post({ action: 'create-file', filename: n }).then(function () {
              openViewer({ name: n, kind: 'file' }, { edit: true });
            });
          });
          break;
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
    var vf = null;   // { url, name, ext, editable, clean, editing, tab, mite, src }
    // the read view is a numbered row per line, so lines are addressable
    // (scroll-to, highlight). A plain string (binary note) has no gutter.
    function setSrc(text, plain) {
      if (vf) vf.src = text;
      fmSrc.textContent = '';
      fmSrc.classList.toggle('plain', !!plain);
      if (plain) { fmSrc.textContent = text; return; }
      var frag = document.createDocumentFragment();
      var lines = text.split('\n');
      for (var i = 0; i < lines.length; i++) {
        var row = document.createElement('div');
        row.className = 'fm-line';
        row.dataset.n = String(i + 1);
        var ln = document.createElement('span'); ln.className = 'ln'; ln.textContent = String(i + 1);
        var lt = document.createElement('span'); lt.className = 'lt'; lt.textContent = lines[i];
        row.append(ln, lt);
        frag.appendChild(row);
      }
      fmSrc.appendChild(frag);
    }
    function goToLine(from, to) {
      if (!vf || !from) return;
      to = to || from;
      fmSrc.querySelectorAll('.fm-line.hit').forEach(function (r) { r.classList.remove('hit'); });
      var first = null;
      for (var n = from; n <= to; n++) {
        var r = fmSrc.querySelector('.fm-line[data-n="' + n + '"]');
        if (!r) continue;
        r.classList.add('hit');
        if (!first) first = r;
      }
      if (first) first.scrollIntoView({ block: 'center' });
    }

    function extOf(name) {
      var m = /\.([a-z0-9]+)$/i.exec(name || '');
      return m ? m[1].toLowerCase() : '';
    }
    // the rendering kind. The MIME TYPE is the stored truth and wins; the
    // extension only decides when the mime says nothing useful (a bare
    // /mime blot, application/octet-stream). Mislabeled data gets fixed
    // at the data, not papered over here.
    function kindOf(name, mite) {
      var m = mite || '';
      if (/markdown/.test(m)) return 'md';
      if (/text\/csv/.test(m)) return 'csv';
      if (/^\/?text\//.test(m)) return null;          // plain text: one pane
      var byName = window.FilePreview && FilePreview.kind(name);
      if (byName) return byName;
      var ext = extOf(name);
      if (ext === 'md' || ext === 'markdown') return 'md';
      if (ext === 'csv') return 'csv';
      return null;
    }
    function hasPreview(name, mite) { return !!kindOf(name, mite); }
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

    async function openViewer(item, opts) {
      opts = opts || {};
      var startEditing = !!opts.edit;
      var url = join(here, item.name);
      vf = { url: url, name: item.name, ext: extOf(item.name), editable: false,
             clean: '', editing: false, tab: 'src', mite: item.mime || '' };
      $('fm-name').textContent = item.name;
      $('fm-blot').textContent = '';
      $('fm-mime').textContent = '';
      $('fm-ext').href = url;
      setSrc('', true);
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
      $('fm-blot').textContent = info.blot || '';
      $('fm-mime').textContent = vf.mite || '';
      vf.editable = !!info.texty && !info.jammed;
      if (vf.editable) {
        try {
          vf.clean = present(await (await fetch(url + '?raw=1')).text(), vf.ext);
        } catch (e) { fmSetStatus('could not read file', true); return; }
        if (!vf || vf.url !== url) return;
        fmEd.value = vf.clean;
        setSrc(vf.clean);
      } else if (info.jammed) {
        setSrc(info.text || '');
      } else {
        setSrc('binary content — ' + vf.mite, true);
      }
      fmSetStatus('');
      fmEdit.disabled = !vf.editable;
      fmSave.disabled = true;
      var prev = hasPreview(vf.name, vf.mite);
      fmTabSrc.classList.toggle('hidden', !prev);
      fmTabPrev.classList.toggle('hidden', !prev);
      if (startEditing && vf.editable) { vf.editing = true; fmEdit.classList.add('on'); fmShow('src'); fmEd.focus(); return; }
      if (opts.from) { fmShow('src'); goToLine(opts.from, opts.to); return; }
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
      var kind = kindOf(vf.name, vf.mite);
      var text = vf.editable ? fmEd.value : (vf.src || '');
      var rawUrl = vf.url + '?raw=1';
      fmPrev.textContent = '';
      fmPrev.removeAttribute('style');
      if (kind === 'md') {
        var d = document.createElement('div');
        d.className = 'fm-md';
        try { d.innerHTML = window.marked ? marked.parse(text) : text; }
        catch (_) { d.textContent = text; }
        fmPrev.appendChild(d);
        return;
      }
      if (kind === 'csv') {
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
      if (!vf.editing) setSrc(fmEd.value);
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
        setSrc(fmEd.value);
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


    // ---- host-facing handle ----
    function setRoot(url) {
      root = url || null;
      missing = false;
      if (!root) { here = null; ft.items = []; fg.items = []; return; }
      here = root;
      renderCrumbs();
      if (!opts.lazy) nav(root);
    }
    handle.setRoot = setRoot;
    handle.load = function () { if (root) nav(root); };
    // open a file (path relative to root) in the viewer modal — for hosts
    // that cite files from elsewhere in their UI
    // opts: { edit } to open in edit mode, { from, to } to scroll to and
    // highlight a 1-based line range on the source view
    handle.open = function (relPath, opts) {
      if (!root) return;
      var parts = String(relPath).replace(/^\/+/, '').split('/');
      var name = parts.pop();
      here = parts.length ? join(root, parts.join('/')) : root;
      openViewer({ name: name, kind: 'file' }, opts === true ? { edit: true } : (opts || {}));
    };
    handle.goToLine = goToLine;
    if (opts.root) setRoot(opts.root);
  }

  window.FileManager = { mount: mount };
})();
