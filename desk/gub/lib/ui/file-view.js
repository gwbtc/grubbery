// <FileView> — the explorer's file page, extracted as a mountable component.
// One file's Source | Preview | Build panes, an Edit/Save/Live/Wrap toolbar, a
// mime field, and the shared FilePreview + marked renderers — driven entirely
// by a file's own /grubbery/ball URL (?info=1 says what it is, ?raw=1 gives the
// bytes, POST action=write-text saves through the grub's blot). The explorer
// file page, the browse finder preview, and forge tabs all mount this.
//
// USAGE (classic script; load AFTER file-preview.js, BEFORE your app.js):
//   <div id="fv" class="fv" style="height:100vh"></div>
//   var fv = FileView.mount(document.getElementById('fv'), {
//     url: '/grubbery/ball/apps/foo/data/tree/readme.md',  // the file's own URL
//     wrapKey: 'explorer-wrap',   // localStorage key for the wrap toggle
//     crumbBase: '/grubbery/ball/apps/some/internal/storage/root',
//       // optional — the breadcrumb normally shows `url` relative to the
//       // namespace root (/grubbery/ball). A host whose file lives several
//       // levels inside its own internal storage layout (a repo's working
//       // tree, say) can pass that storage root here so the crumb shows the
//       // host-relative path instead of the internal plumbing in between.
//       // "/" still links to crumbBase itself, same as any other crumb link.
//   });
//   fv.setUrl(url)   // re-point at a different file (re-fetches, re-renders)
//
// marked (window.marked) renders markdown when the host has loaded it; shiki is
// imported on demand for source highlighting. Styling is injected once, scoped
// under .fv; the host sizes the mount element.
(function () {
  'use strict';

  var CSS =
    '.fv{background:#fff;color:#1f2328;display:flex;flex-direction:column;font:13px/1.5 -apple-system,BlinkMacSystemFont,sans-serif;min-height:0;min-width:0;width:100%;overflow:hidden}' +
    '.fv #bar{flex:none;display:flex;align-items:center;gap:8px;padding:8px 12px;background:#f6f8fa;border-bottom:1px solid #d0d7de;min-width:0;overflow:hidden}' +
    '.fv #crumbs{display:flex;align-items:center;gap:2px;font:600 12px ui-monospace,SFMono-Regular,Menlo,monospace;margin-left:4px;min-width:0;overflow:hidden;flex-shrink:1}' +
    '.fv #crumbs a{color:#57606a;padding:2px 4px;border-radius:5px;text-decoration:none}' +
    '.fv #crumbs a:hover{color:#24292f;background:#eaeef2}' +
    '.fv #fname{font-weight:600}' +
    '.fv .chip{display:inline-flex;align-items:center;gap:5px;background:#eef1f4;border:1px solid #e2e7ee;border-radius:6px;padding:2px 8px}' +
    '.fv .chip .k{font-size:10px;text-transform:uppercase;letter-spacing:.05em;color:#8b949e}' +
    '.fv .chip .v{font:11px ui-monospace,SFMono-Regular,Menlo,monospace;color:#24292f}' +
    '.fv .chip.bang{background:#fff8f8;border-color:#ffcecb;cursor:pointer}' +
    '.fv .chip.bang .k,.fv .chip.bang .v{color:#cf222e}' +
    '.fv .grow{flex:1}' +
    '.fv #bar button{all:unset;cursor:pointer;padding:4px 12px;border-radius:7px;font-size:12px;color:#57606a}' +
    '.fv #bar button:hover{color:#24292f;background:#eaeef2}' +
    '.fv #bar button.on{color:#24292f;background:#fff;border:1px solid #d0d7de;font-weight:600;padding:3px 11px}' +
    '.fv #tools{flex:none;display:flex;align-items:center;gap:8px;padding:6px 12px;background:#fff;border-bottom:1px solid #e2e7ee}' +
    '.fv #tools button{all:unset;cursor:pointer;padding:3px 12px;border-radius:7px;font-size:12px;border:1px solid #d0d7de;color:#24292f}' +
    '.fv #tools button:hover{background:#f6f8fa}' +
    '.fv #tools button.on{background:#ddf4ff;border-color:#54aeff;color:#0969da;font-weight:600}' +
    '.fv #save:not([disabled]){background:#0969da;border-color:#0969da;color:#fff}' +
    '.fv #save:not([disabled]):hover{background:#0857b8}' +
    '.fv #save[disabled]{color:#8b949e;cursor:default}' +
    '.fv #tools button[disabled]{color:#8b949e;cursor:default;background:none}' +
    '.fv #mime-row{display:flex;align-items:center;gap:8px;padding:4px 12px;background:#f6f8fa;border-bottom:1px solid #e2e7ee}' +
    '.fv #mime-row .tool-label{font:10px/1 -apple-system,sans-serif;text-transform:uppercase;letter-spacing:.05em;color:#8b949e}' +
    '.fv #mime-input{font:11px ui-monospace,SFMono-Regular,Menlo,monospace;padding:2px 6px;border:1px solid transparent;border-radius:5px;width:200px;outline:none;background:transparent;color:#57606a}' +
    '.fv #mime-input:not([readonly]){border-color:#d0d7de;background:#fff;color:#24292f}' +
    '.fv #mime-input:not([readonly]):focus{border-color:#0969da}' +
    '.fv #status{font:11px ui-monospace,monospace;color:#57606a;max-width:40ch;overflow:hidden;text-overflow:ellipsis;white-space:pre}' +
    '.fv #status.err{color:#cf222e;white-space:pre-wrap}' +
    '.fv #text-view,.fv #mime-view{flex:1;min-height:0;min-width:0;overflow:auto}' +
    '.fv .edwrap,.fv #src-display{height:100%;min-width:0;overflow:auto}' +
    // the Wrap toggle drives the editor AND the highlighted display identically
    '.fv.wrap #ed,.fv.wrap #text-view pre,.fv.wrap #text-view code{white-space:pre-wrap!important;overflow-wrap:anywhere}' +
    '.fv:not(.wrap) #ed,.fv:not(.wrap) #text-view pre,.fv:not(.wrap) #text-view code{white-space:pre!important}' +
    // nowrap: scroll horizontally inside the pane, never the window
    '.fv:not(.wrap) #ed{overflow-x:auto}' +
    '.fv pre{margin:0;padding:18px;font:12px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace;overflow:auto;box-sizing:border-box;min-height:100%}' +
    '.fv pre.dim{color:#8b949e}' +
    '.fv pre.boom{color:#cf222e;background:#fff8f8}' +
    '.fv code{font:inherit}' +
    '.fv #ed{width:100%;height:100%;box-sizing:border-box;background:#fff;color:#1f2328;border:none;outline:none;resize:none;padding:18px;font:12px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace}' +
    '.fv #ed[readonly]{background:#fbfcfd;color:#3b434b}' +
    '.fv #missing{padding:40px 32px;color:#57606a}' +
    '.fv #missing h1{font-size:18px;margin:0 0 8px;color:#1f2328}' +
    '.fv #missing a{color:#0969da;text-decoration:none}' +
    '.fv .md{max-width:74ch;padding:24px 32px;line-height:1.65}' +
    '.fv .md h1,.fv .md h2,.fv .md h3{border-bottom:1px solid #e2e7ee;padding-bottom:.3em}' +
    '.fv .md code{background:#f2f4f7;padding:1px 5px;border-radius:5px;font:12px ui-monospace,monospace}' +
    '.fv .md pre{background:#f6f8fa;border-radius:8px;min-height:0}' +
    '.fv .md pre code{background:none;padding:0}' +
    '.fv .md a{color:#0969da}' +
    '.fv .md blockquote{border-left:3px solid #d0d7de;margin-left:0;padding-left:14px;color:#57606a}' +
    '.fv table.csv{border-collapse:collapse;margin:20px;font:12px ui-monospace,monospace}' +
    '.fv table.csv th,.fv table.csv td{border:1px solid #d0d7de;padding:5px 12px;text-align:left}' +
    '.fv table.csv th{background:#f6f8fa}' +
    '.fv table.csv tr:nth-child(even) td{background:#fbfcfd}' +
    '.fv #build-view{flex:1;min-height:0;overflow:auto;margin:0;padding:18px;font:12px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace}' +
    '.fv #build-badge{display:inline-flex;align-items:center;gap:6px;padding:4px 12px;border-radius:7px;font-size:12px;font-weight:600;margin-bottom:14px}' +
    '.fv #build-badge.ok{background:#dafbe1;color:#116329}' +
    '.fv #build-badge.err{background:#ffebe9;color:#cf222e}' +
    '.fv #build-badge.raw{background:#fff8c5;color:#6a5c00}' +
    '.fv-err-overlay{position:fixed;inset:0;background:rgba(0,0,0,.35);z-index:100;display:flex;align-items:center;justify-content:center}' +
    '.fv-err-box{background:#fff;border-radius:12px;box-shadow:0 16px 48px rgba(0,0,0,.2);width:min(640px,90vw);max-height:80vh;display:flex;flex-direction:column}' +
    '.fv-err-bar{display:flex;align-items:center;justify-content:space-between;padding:10px 16px;border-bottom:1px solid #ffcecb}' +
    '.fv-err-title{font:600 14px -apple-system,sans-serif;color:#cf222e}' +
    '.fv-err-close{all:unset;cursor:pointer;font-size:18px;color:#57606a;padding:2px 8px;border-radius:6px}' +
    '.fv-err-close:hover{background:#f2f4f7}' +
    '.fv-err-body{flex:1;overflow:auto;margin:0;padding:14px 16px;font:12px/1.6 ui-monospace,SFMono-Regular,Menlo,monospace;white-space:pre-wrap;color:#cf222e}';

  var MARKUP =
    '<div id="bar">' +
      '<button id="tab-text" style="display:none">Source</button>' +
      '<button id="tab-mime" style="display:none">Preview</button>' +
      '<button id="tab-build" style="display:none">Build</button>' +
      '<span id="crumbs"></span>' +
      '<span id="fname"></span>' +
      '<span class="chip" id="chip-blot" style="display:none"><span class="k">blot</span><span class="v"></span></span>' +
      '<span class="chip" id="chip-mime" style="display:none"><span class="k">mime</span><span class="v"></span></span>' +
      '<span class="chip bang" id="bang-chip" style="display:none" title="click for the crash tang"><span class="k">bang</span><span class="v">fiber crashed</span></span>' +
      '<span class="grow"></span>' +
    '</div>' +
    '<div id="tools" style="display:none">' +
      '<button id="edit">Edit</button>' +
      '<button id="save" disabled>Save</button>' +
      '<button id="live">Live</button>' +
      '<button id="wrap">Wrap</button>' +
      '<span id="status"></span>' +
    '</div>' +
    '<div id="mime-row" style="display:none">' +
      '<label class="tool-label" for="mime-input">mime type</label>' +
      '<input id="mime-input" type="text" spellcheck="false" readonly>' +
    '</div>' +
    '<div id="sandbox-banner" style="display:none;margin:8px 12px;padding:10px 12px;border:1px solid #f0d9a8;background:#fff8ec;border-radius:8px;font:12px/1.5 -apple-system,BlinkMacSystemFont,sans-serif;color:#7a5900"></div>' +
    '<div id="text-view">' +
      '<div class="edwrap" id="edwrap" style="display:none">' +
        '<div id="src-display"></div>' +
        '<textarea id="ed" spellcheck="false" style="display:none"></textarea>' +
      '</div>' +
      '<pre id="src" style="display:none"></pre>' +
      '<div id="missing" style="display:none">' +
        '<h1>nothing here</h1>' +
        '<p id="missing-path"></p>' +
        '<p><a id="missing-up" href="/grubbery/ball">back</a></p>' +
      '</div>' +
    '</div>' +
    '<div id="mime-view" style="display:none"></div>' +
    '<pre id="build-view" style="display:none"></pre>';

  var styled = false;
  function injectStyle() {
    if (styled) return;
    styled = true;
    var s = document.createElement('style');
    s.textContent = CSS;
    document.head.appendChild(s);
  }

  // one shared highlighter across all instances; hoon grammar loads on demand
  var shikiP = null;
  function getShiki(lang) {
    if (!shikiP) {
      shikiP = (async function () {
        var mod = await import('https://esm.sh/shiki@1.24.0');
        return mod.createHighlighter({ themes: ['github-light'], langs: [] });
      })();
    }
    return shikiP.then(async function (hl) {
      if (!hl.getLoadedLanguages().includes(lang)) {
        if (lang === 'hoon') {
          var grammar = await (await fetch('/grubbery/ball/apps/explorer.explorer/hoon-grammar.json')).json();
          await hl.loadLanguage(grammar);
        } else {
          await hl.loadLanguage(lang);
        }
      }
      return hl;
    });
  }
  function loadScript(src) {
    return new Promise(function (res, rej) {
      var sc = document.createElement('script');
      sc.src = src; sc.onload = res; sc.onerror = rej;
      document.head.appendChild(sc);
    });
  }

  var SHIKI_LANG = { js: 'javascript', mjs: 'javascript', ts: 'typescript',
                     json: 'json', css: 'css', hoon: 'hoon' };

  function mount(root, opts) {
    opts = opts || {};
    injectStyle();
    root.classList.add('fv');
    root.innerHTML = MARKUP;
    var wrapKey = opts.wrapKey || 'explorer-wrap';
    var $ = function (id) { return root.querySelector('#' + id); };

    var here = opts.url;
    var name = decodeURIComponent((here.split('/').filter(Boolean).pop()) || '');
    var ext = (name.match(/\.([a-z0-9]+)$/i) || [, ''])[1].toLowerCase();
    // mime-first kind detection — a mime type the server actually resolved
    // (via its marc) is more trustworthy than a filename's extension, which
    // a grub needn't even have (e.g. a mark path's own grub, "run.git-action"
    // style names with no .ext at all). Falls back to extension-based
    // FilePreview.kind() when the mime doesn't say anything specific.
    function mimeKind() {
      if (/json/i.test(mite)) return 'json';
      if (/svg/i.test(mite)) return 'svg';
      if (/(^|\/)html/i.test(mite)) return 'html';
      if (/^text\/(x-)?markdown/i.test(mite)) return 'md';
      if (/csv/i.test(mite)) return 'csv';
      if (/^image\//i.test(mite)) return 'image';
      if (/pdf/i.test(mite)) return 'pdf';
      return null;
    }
    function effectiveKind() {
      return mimeKind() || (window.FilePreview && FilePreview.kind(name)) || null;
    }

    var ed = $('ed'), edwrap = $('edwrap'), display = $('src-display'), src = $('src');
    var textView = $('text-view'), mimeView = $('mime-view'), buildView = $('build-view');
    var tabText = $('tab-text'), tabMime = $('tab-mime'), tabBuild = $('tab-build');
    var editBtn = $('edit'), saveBtn = $('save'), liveBtn = $('live'), wrapBtn = $('wrap');
    var status = $('status'), tools = $('tools'), mimeInput = $('mime-input');

    // the one error overlay (per instance), appended to <body> so it centers
    var errOverlay = document.createElement('div');
    errOverlay.className = 'fv-err-overlay';
    errOverlay.style.display = 'none';
    errOverlay.innerHTML =
      '<div class="fv-err-box"><div class="fv-err-bar">' +
      '<span class="fv-err-title">save failed</span>' +
      '<button class="fv-err-close">&times;</button></div>' +
      '<pre class="fv-err-body"></pre></div>';
    document.body.appendChild(errOverlay);
    var errBody = errOverlay.querySelector('.fv-err-body');
    errOverlay.querySelector('.fv-err-close').addEventListener('click', function () { errOverlay.style.display = 'none'; });
    errOverlay.addEventListener('click', function (e) { if (e.target === errOverlay) errOverlay.style.display = 'none'; });
    function showErr(title, text) {
      errOverlay.querySelector('.fv-err-title').textContent = title;
      errBody.textContent = text;
      errOverlay.style.display = '';
    }

    $('fname').textContent = name;
    (function crumbs() {
      var wrap = $('crumbs');
      var base = opts.crumbBase || '/grubbery/ball';
      var rel = here.indexOf(base) === 0 ? here.slice(base.length) : here.replace('/grubbery/ball', '');
      var parts = rel.split('/').filter(Boolean);
      var mk = function (t, href) { var a = document.createElement('a'); a.href = href; a.textContent = t; return a; };
      var acc = base;
      wrap.appendChild(mk('/', acc));
      parts.slice(0, -1).forEach(function (s) { acc += '/' + s; wrap.appendChild(mk(s + '/', acc)); });
    })();
    function chip(id, text) { var c = $(id); c.querySelector('.v').textContent = text; c.style.display = ''; }

    var info = null, mite = '', texty = false, editable = false, buildStatus = '';
    var mimeRendered = false, buildRendered = false, sandboxed = false;
    // a grub whose mite is runnable in a browser — the only kinds the kernel
    // serve-sandbox ever downgrades, so the only ones worth a header check
    function runnableMite(m) {
      return /(^|\/)html/i.test(m) || /javascript|ecmascript/i.test(m) ||
        /svg/i.test(m) || /wasm/i.test(m) || /xhtml/i.test(m);
    }
    function showSandboxBanner() {
      var b = $('sandbox-banner');
      b.innerHTML = '<strong>Sandboxed</strong> — this file’s directory isn’t granted <code>/sys/eyre</code> access, so grubbery serves it as inert <code>text/plain</code> (with <code>nosniff</code>): it cannot run as code in your browser. The real type is still <code>' + (mite || '?') + '</code>; the bytes just aren’t delivered as it.';
      b.style.display = '';
    }

    (async function boot() {
      try {
        info = await (await fetch(here + '?info=1', { headers: { accept: 'application/json' } })).json();
      } catch (e) { showErr('explorer', 'could not load file info: ' + e); return; }
      if (info.bang) {
        var b = $('bang-chip'); b.style.display = '';
        b.addEventListener('click', function () { showErr('fiber crashed', info.bang); });
      }
      if (info.kind === 'missing') return renderMissing();
      if (info.kind === 'boom') return renderBoom();
      await renderFile();
    })();

    function renderMissing() {
      var parent = here.replace(/\/[^/]*$/, '') || '/grubbery/ball';
      $('missing-path').textContent = 'There is no file or directory at ' + (info.path || here.replace('/grubbery/ball', '') || '/') + '.';
      var up = $('missing-up');
      up.href = parent;
      up.textContent = 'back to ' + (parent.replace('/grubbery/ball', '') || '/');
      $('missing').style.display = '';
    }
    function renderBoom() {
      chip('chip-blot', info.blot || '');
      chip('chip-mime', 'boomed');
      src.className = 'boom'; src.textContent = info.boom || 'validation failed'; src.style.display = '';
    }

    async function renderFile() {
      mite = info.mite || '';
      texty = !!info.texty;
      editable = texty && !info.jammed;
      buildStatus = (info.build && info.build.status) || '';
      chip('chip-blot', info.blot || '');
      chip('chip-mime', mite);
      mimeInput.value = mite;
      tools.style.display = '';
      $('mime-row').style.display = '';
      // only runnable types can be downgraded; one header check tells us if
      // the kernel serve-sandbox fired for this file, from any pane
      if (runnableMite(mite)) {
        try {
          var hr = await fetch(here + '?raw=1');
          if (hr.headers.get('x-content-type-options') === 'nosniff') { sandboxed = true; showSandboxBanner(); }
        } catch (_) {}
      }
      if (buildStatus) tabBuild.style.display = '';
      if (editable) {
        ed.value = present(await readRaw());
        edwrap.style.display = '';
      } else if (info.jammed) {
        src.textContent = info.text || ''; src.style.display = '';
      } else {
        src.className = 'dim'; src.textContent = 'binary content'; src.style.display = '';
      }
      setupPanes(); setupWrap(); setupEditor(); renderSource();
    }

    function readRaw() { return fetch(here + '?raw=1').then(function (r) { return r.text(); }); }
    function present(text) {
      if (effectiveKind() === 'json') { try { return JSON.stringify(JSON.parse(text), null, 2); } catch (_) {} }
      return text;
    }

    function show(which) {
      textView.style.display = which === 'text' ? '' : 'none';
      mimeView.style.display = which === 'mime' ? '' : 'none';
      buildView.style.display = which === 'build' ? '' : 'none';
      tabText.classList.toggle('on', which === 'text');
      tabMime.classList.toggle('on', which === 'mime');
      tabBuild.classList.toggle('on', which === 'build');
      tools.style.display = which === 'text' ? '' : 'none';
      if (which === 'mime' && !mimeRendered) { renderMime(); mimeRendered = true; }
      if (which === 'build' && !buildRendered) { renderBuild(); buildRendered = true; }
    }
    function setupPanes() {
      var previewable = !!effectiveKind() || !texty;
      tabText.addEventListener('click', function () { show('text'); });
      tabMime.addEventListener('click', function () { show('mime'); });
      tabBuild.addEventListener('click', function () { show('build'); });
      var showTabs = previewable || buildStatus;
      tabText.style.display = showTabs ? '' : 'none';
      tabMime.style.display = showTabs ? '' : 'none';
      if (!previewable) show('text'); else show('mime');
    }

    function setupWrap() {
      var wrap = true;
      try { wrap = (localStorage.getItem(wrapKey) == null ? '1' : localStorage.getItem(wrapKey)) === '1'; } catch (_) {}
      var applyWrap = function () {
        root.classList.toggle('wrap', wrap);
        wrapBtn.classList.toggle('on', wrap);
        // a textarea wraps by its `wrap` attribute, not CSS white-space —
        // drive it so the editor matches the highlighted display exactly.
        ed.setAttribute('wrap', wrap ? 'soft' : 'off');
      };
      wrapBtn.addEventListener('click', function () {
        wrap = !wrap;
        try { localStorage.setItem(wrapKey, wrap ? '1' : '0'); } catch (_) {}
        applyWrap();
      });
      applyWrap();
    }

    async function renderSource() {
      if (!editable) return;
      var text = ed.value;
      display.textContent = '';
      var p = document.createElement('pre'); p.textContent = text; display.appendChild(p);
      if (SHIKI_LANG[ext]) {
        try {
          var hl = await getShiki(SHIKI_LANG[ext]);
          p.outerHTML = hl.codeToHtml(text, { lang: SHIKI_LANG[ext], theme: 'github-light' });
        } catch (_) {}
      }
    }

    function setupEditor() {
      if (!editable) {
        editBtn.setAttribute('disabled', ''); saveBtn.setAttribute('disabled', ''); liveBtn.setAttribute('disabled', '');
        return;
      }
      var editing = false;
      editBtn.addEventListener('click', function () {
        editing = !editing;
        editBtn.classList.toggle('on', editing);
        ed.style.display = editing ? '' : 'none';
        display.style.display = editing ? 'none' : '';
        mimeInput.readOnly = !editing;
        if (editing) { show('text'); ed.focus(); } else renderSource();
      });
      var clean = ed.value, live = false, liveTimer = null, miteChanged = false;
      liveBtn.addEventListener('click', function () {
        live = !live; liveBtn.classList.toggle('on', live); syncSaveBtn();
        if (live && ed.value !== clean) scheduleLive();
      });
      function syncSaveBtn() {
        if (live || (ed.value === clean && !miteChanged)) saveBtn.setAttribute('disabled', '');
        else saveBtn.removeAttribute('disabled');
      }
      function scheduleLive() {
        clearTimeout(liveTimer);
        liveTimer = setTimeout(function () { if (ed.value !== clean) save(); }, 800);
      }
      ed.addEventListener('input', function () { syncSaveBtn(); if (live) scheduleLive(); });
      mimeInput.addEventListener('input', function () { miteChanged = mimeInput.value.trim() !== mite; syncSaveBtn(); });
      async function save() {
        status.textContent = 'saving…'; status.className = '';
        var sent = ed.value;
        try {
          var res = await fetch(here, {
            method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' },
            body: new URLSearchParams(Object.assign({ action: 'write-text', content: sent }, miteChanged ? { mite: mimeInput.value.trim() } : {})),
          });
          var body = await res.text();
          if (res.ok) {
            var stored = present(await readRaw());
            clean = stored;
            if (ed.value === sent && stored !== sent) {
              var s = ed.selectionStart, epos = ed.selectionEnd;
              ed.value = stored;
              ed.setSelectionRange(Math.min(s, stored.length), Math.min(epos, stored.length));
              if (!editing) renderSource();
            }
            mite = mimeInput.value.trim(); miteChanged = false; syncSaveBtn();
            status.textContent = 'saved ✓';
            mimeRendered = false; mimeView.textContent = '';
            setTimeout(function () { if (status.textContent === 'saved ✓') status.textContent = ''; }, 2500);
          } else {
            ed.value = clean; syncSaveBtn(); status.textContent = '';
            showErr('save failed', body || ('save failed (' + res.status + ')'));
          }
        } catch (e) {
          ed.value = clean; syncSaveBtn(); status.textContent = ''; showErr('save failed', 'save failed: ' + e);
        }
      }
      saveBtn.addEventListener('click', function () { if (!saveBtn.hasAttribute('disabled')) save(); });
      root.addEventListener('keydown', function (e) {
        if ((e.metaKey || e.ctrlKey) && e.key === 's') { e.preventDefault(); if (ed.value !== clean) save(); }
      });
      ed.addEventListener('keydown', function (e) {
        if (e.key !== 'Tab') return;
        e.preventDefault();
        var s = ed.selectionStart, epos = ed.selectionEnd;
        ed.setRangeText('  ', s, epos, 'end');
        ed.dispatchEvent(new Event('input'));
      });
    }

    async function renderMime() {
      var rawUrl = here + '?raw=1';
      var text = editable ? ed.value : (src.textContent || '');
      mimeView.textContent = '';
      var k = effectiveKind();
      // kernel serve-sandbox (detected at boot): a runnable grub whose
      // directory can't reach /sys/eyre is served inert — rendering a live
      // preview would just show that inert text or a broken image, so show
      // the source; the banner up top explains why.
      if (sandboxed) {
        var spre = document.createElement('pre'); spre.className = 'dim';
        spre.style.cssText = 'margin:0;white-space:pre-wrap;overflow-wrap:anywhere;';
        spre.textContent = text;
        mimeView.appendChild(spre);
        return;
      }
      if (k === 'md' && !window.marked) {
        try { await loadScript('/grubbery/ball/apps/explorer.explorer/marked.min.js'); } catch (_) {}
      }
      if (window.FilePreview && k) {
        FilePreview.render(mimeView, { name: name, text: text, rawUrl: rawUrl, kind: k });
        return;
      }
      var p = document.createElement('pre'); p.className = 'dim';
      var a = document.createElement('a'); a.href = rawUrl; a.textContent = 'download raw bytes';
      p.textContent = 'binary — '; p.appendChild(a);
      mimeView.appendChild(p);
    }

    function renderBuild() {
      if (!buildStatus) return;
      var detail = (info.build && info.build.detail) || '';
      buildView.textContent = '';
      var badge = document.createElement('div'); badge.id = 'build-badge';
      if (buildStatus === 'vase') { badge.className = 'ok'; badge.textContent = 'compiled'; }
      else if (buildStatus === 'tang') { badge.className = 'err'; badge.textContent = 'build error'; }
      else { badge.className = 'raw'; badge.textContent = 'raw ' + buildStatus; }
      buildView.appendChild(badge);
      if (detail) {
        var pre = document.createElement('pre');
        pre.style.cssText = 'margin:0;white-space:pre-wrap;overflow-wrap:anywhere;';
        pre.textContent = detail; buildView.appendChild(pre);
      }
    }

    return {
      setUrl: function (u) { mount(root, Object.assign({}, opts, { url: u })); },
      destroy: function () { errOverlay.remove(); root.innerHTML = ''; }
    };
  }

  window.FileView = { mount: mount };
})();
