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
    '.fv #crumbrow{flex:none;padding:6px 12px 0;background:#f6f8fa;overflow-x:auto;overflow-y:hidden;white-space:nowrap}' +
    '.fv #bar{flex:none;display:flex;align-items:center;gap:8px;padding:8px 12px;background:#f6f8fa;border-bottom:1px solid #d0d7de;min-width:0;overflow:hidden}' +
    '.fv #crumbs{display:inline-flex;align-items:center;gap:2px;font:600 12px ui-monospace,SFMono-Regular,Menlo,monospace;white-space:nowrap}' +
    '.fv #crumbs a{color:#57606a;padding:2px 4px;border-radius:5px;text-decoration:none}' +
    '.fv #crumbs a:hover{color:#24292f;background:#eaeef2}' +
    '.fv #fname{font:600 12px ui-monospace,SFMono-Regular,Menlo,monospace;color:#24292f;padding:2px 4px}' +
    '.fv #fname.unnamed{color:#8b949e;font-style:italic;font-weight:400}' +
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
    '.fv #view-pane{flex:1;min-height:0;min-width:0;overflow:auto;display:flex;flex-direction:column}' +
    '.fv .edwrap,.fv #src-display{height:100%;min-width:0;overflow:auto}' +
    // the Wrap toggle drives the highlighted display; the editor drives its
    // own CodeMirror lineWrapping option (set alongside this, see setupWrap)
    '.fv.wrap #text-view pre,.fv.wrap #text-view code{white-space:pre-wrap!important;overflow-wrap:anywhere}' +
    '.fv:not(.wrap) #text-view pre,.fv:not(.wrap) #text-view code{white-space:pre!important}' +
    '.fv pre{margin:0;padding:18px;font:12px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace;overflow:auto;box-sizing:border-box;min-height:100%}' +
    '.fv pre.dim{color:#8b949e}' +
    '.fv pre.boom{color:#cf222e;background:#fff8f8}' +
    '.fv code{font:inherit}' +
    '.fv #ed{width:100%;height:100%;box-sizing:border-box}' +
    '.fv #ed .CodeMirror{height:100%;font:12px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace}' +
    '.fv #missing{padding:40px 32px;color:#57606a}' +
    '.fv #missing h1{font-size:18px;margin:0 0 8px;color:#1f2328}' +
    '.fv #missing a{color:#0969da;text-decoration:none}' +
    '.fv #unviewable{padding:40px 32px;color:#57606a}' +
    '.fv #unviewable h1{font-size:18px;margin:0 0 8px;color:#1f2328}' +
    '.fv #unviewable p{margin:0;max-width:68ch;white-space:pre-wrap}' +
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
    // sub-tabs inside the Build pane: the same idiom as #bar one level
    // up, so two levels of tabs read as one mechanism
    '.fv .bsub{display:flex;gap:6px;margin:0 0 12px}' +
    '.fv .bsub button{all:unset;cursor:pointer;padding:4px 12px;border-radius:7px;font-size:12px;color:#57606a}' +
    '.fv .bsub button:hover{color:#24292f;background:#eaeef2}' +
    '.fv .bsub button.on{color:#24292f;background:#fff;border:1px solid #d0d7de;font-weight:600;padding:3px 11px}' +
    '.fv .trow{display:flex;align-items:flex-start;gap:8px;padding:4px 8px;border:1px solid #e3e3e0;border-radius:5px;font:12px ui-monospace,SFMono-Regular,Menlo,monospace}' +
    '.fv .trow.bad{background:#ffebe9;border-color:#ffcecb}' +
    '.fv .tdot{flex:0 0 auto;width:7px;height:7px;border-radius:50%;margin-top:5px}' +
    '.fv .tnam{overflow-wrap:anywhere}' +
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
    '<div id="crumbrow"><span id="crumbs"></span><span id="fname"></span></div>' +
    '<div id="bar">' +
      '<button id="tab-view" style="display:none"></button>' +
      '<button id="tab-text" style="display:none">Source</button>' +
      '<button id="tab-mime" style="display:none">Preview</button>' +
      '<button id="tab-build" style="display:none">Build</button>' +
      '<span class="chip" id="chip-blot" style="display:none"><span class="k">blot</span><span class="v"></span></span>' +
      '<span class="chip" id="chip-mime" style="display:none"><span class="k">mime</span><span class="v"></span></span>' +
      '<span class="chip bang" id="bang-chip" style="display:none" title="click for the crash tang"><span class="k">bang</span><span class="v">fiber crashed</span></span>' +
      '<span class="grow"></span>' +
      '<button id="more" style="display:none" title="this file\'s actions">⋯</button>' +
    '</div>' +
    '<div id="tools" style="display:none">' +
      '<button id="edit">Edit</button>' +
      '<button id="save" disabled>Save</button>' +
      '<button id="live">Live</button>' +
      '<button id="wrap">Wrap</button>' +
      '<button id="vimbtn" title="vim keybindings in the editor">Vim</button>' +
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
        '<div id="ed" style="display:none"></div>' +
      '</div>' +
      '<pre id="src" style="display:none"></pre>' +
      '<div id="missing" style="display:none">' +
        '<h1>nothing here</h1>' +
        '<p id="missing-path"></p>' +
        '<p><a id="missing-up" href="/grubbery/ball">back</a></p>' +
      '</div>' +
      '<div id="unviewable" style="display:none">' +
        '<h1 id="unviewable-title"></h1>' +
        '<p id="unviewable-why"></p>' +
      '</div>' +
    '</div>' +
    '<div id="mime-view" style="display:none"></div>' +
    '<pre id="build-view" style="display:none"></pre>' +
    // the host's own pane for this file's mark (opts.viewer): a chat log's
    // chat, a run's trace. The file stays one click away in Source.
    '<div id="view-pane" style="display:none"></div>';

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
          var grammar = await (await fetch('/grubbery/ball/apps/shell.shell/ui/explorer/hoon-grammar.json')).json();
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
    // opts.readOnly — show the file but never let it be written (past versions)
    var $ = function (id) { return root.querySelector('#' + id); };

    var here = opts.url;
    // opts.at: a ?case= (or any extra query) that must ride along on EVERY
    // fetch this view makes -- otherwise a past version shows the present
    // file's content under a past label, which is worse than failing.
    var at = opts.at ? String(opts.at) : '';
    // `here` may already carry a query, so pick the separator per call
    var q = function (suffix) { return here + (here.indexOf('?') >= 0 ? '&' : '?') + suffix + at; };
    // A grub may have NO NAME -- dill's default session is the empty one,
    // and /sys/dill/sessions/ IS that file. Its path ends in the separator,
    // so filter(Boolean) drops the empty segment and the view would name
    // itself after its own parent directory. An unnamed grub is named for
    // the reader instead, the same way a listing names one.
    var segs = here.replace(/\?.*$/, '').split('/');
    var unnamed = segs[segs.length - 1] === '';
    var name = unnamed ? '' : decodeURIComponent(segs[segs.length - 1] || '');
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
    // the text actually on disk / last saved; the VimEditor instance (mounted
    // lazily on first Edit click, see setupEditor) is the live source of truth
    // for unsaved edits once it exists
    var edText = '', ve = null;
    var textView = $('text-view'), mimeView = $('mime-view'), buildView = $('build-view'), viewPane = $('view-pane');
    var tabText = $('tab-text'), tabMime = $('tab-mime'), tabBuild = $('tab-build'), tabView = $('tab-view');
    // the keyboard lands on the root when the pane is chosen by keyboard
    // (the host focuses the content element, which this is mounted on);
    // the reader keys scroll whichever body is showing: ↓ ↑ j k a line,
    // PageDown PageUp / space a screen, Home End the ends. Typing in the
    // editor is the editor's.
    if (root.tabIndex < 0 && !root.hasAttribute('tabindex')) root.tabIndex = -1;
    root.addEventListener('keydown', function (e) {
      if (e.metaKey || e.ctrlKey || e.altKey) return;
      var t = e.target, tag = t && t.tagName;
      if (tag === 'TEXTAREA' || tag === 'INPUT' || tag === 'SELECT' || (t && t.isContentEditable)) return;
      var scroller = [textView, mimeView, buildView, viewPane, edwrap, display].find(function (x) { return x && x.offsetParent !== null && x.scrollHeight > x.clientHeight; });
      if (!scroller) return;
      var line = 40, page = Math.max(line, scroller.clientHeight * 0.9), k = e.key, used = true;
      if (k === 'ArrowDown' || k === 'j') scroller.scrollTop += line;
      else if (k === 'ArrowUp' || k === 'k') scroller.scrollTop -= line;
      else if (k === 'PageDown' || k === ' ') scroller.scrollTop += page;
      else if (k === 'PageUp') scroller.scrollTop -= page;
      else if (k === 'Home') scroller.scrollTop = 0;
      else if (k === 'End') scroller.scrollTop = scroller.scrollHeight;
      else used = false;
      if (used) { e.preventDefault(); e.stopPropagation(); }
    });
    // opts.viewer = { label, mount(root, opts) -> { destroy() } }: a pane the
    // host adds for this file's mark, shown first; mounted on first show
    var viewer = opts.viewer || null, viewerHandle = null;
    var editBtn = $('edit'), saveBtn = $('save'), liveBtn = $('live'), wrapBtn = $('wrap'), vimBtn = $('vimbtn');
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

    if (unnamed) { $('fname').textContent = '[unnamed]'; $('fname').classList.add('unnamed'); }
    else $('fname').textContent = name;
    (function crumbs() {
      var wrap = $('crumbs');
      var base = opts.crumbBase || '/grubbery/ball';
      var rel = here.indexOf(base) === 0 ? here.slice(base.length) : here.replace('/grubbery/ball', '');
      var parts = rel.split('/').filter(Boolean);
      var mk = function (t, href) {
        var a = document.createElement('a'); a.href = href; a.textContent = t;
        // a host (e.g. an explorer tab) can take over crumb clicks to navigate
        // in place + in its own history instead of a full page load
        if (opts.onNavigate) a.addEventListener('click', function (e) { e.preventDefault(); opts.onNavigate(href); });
        return a;
      };
      var acc = base;
      wrap.appendChild(mk('/', acc));
      // slice(0,-1) drops the FILENAME. An unnamed grub has none -- its
      // path ends in the separator -- so its last segment is its parent
      // directory and must stay, or the crumb loses a level.
      (unnamed ? parts : parts.slice(0, -1)).forEach(function (s) { acc += '/' + s; wrap.appendChild(mk(s + '/', acc)); });
    })();
    // opts.menu(x, y) — the host's actions for this file (History, Download,
    // move/copy...). A host that has none leaves the button hidden. The same
    // menu is on right-click, which a phone cannot reach.
    if (opts.menu) {
      var more = $('more'); more.style.display = '';
      more.addEventListener('click', function (e) {
        e.stopPropagation();
        var r = more.getBoundingClientRect();
        opts.menu(r.left, r.bottom + 4);
      });
    }
    function chip(id, text) { var c = $(id); c.querySelector('.v').textContent = text; c.style.display = ''; }

    var info = null, mite = '', texty = false, editable = false, writable = false, buildStatus = '';
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
        var ir = await fetch(q('info=1'), { headers: { accept: 'application/json' } });
        if (!ir.ok) { renderUnviewable('nothing to show', (await ir.text()) || ('http ' + ir.status)); return; }
        info = await ir.json();
      } catch (e) { showErr('explorer', 'could not load file info: ' + e); return; }
      if (info.bang) {
        var b = $('bang-chip'); b.style.display = '';
        b.addEventListener('click', function () { showErr('fiber crashed', info.bang); });
      }
      if (info.kind === 'missing') return renderMissing();
      if (info.kind === 'boom') return renderBoom();
      await renderFile();
    })();

    // A file that cannot be shown is a STATE OF THE PANE, not an alert over
    // it. A modal gets dismissed and leaves the viewer looking like it holds
    // the file; this replaces the viewer and says why.
    function renderUnviewable(title, why) {
      // ALL of the file chrome goes. A blot, a mime type, Source/Preview
      // tabs, an edit toolbar and an actions menu are claims about a file
      // that is not here -- rendering them around an error message makes
      // the error look like the file's contents.
      ['bar', 'tools', 'mime-row', 'mime-view', 'build-view', 'src', 'missing', 'view-pane'].forEach(function (id) {
        try { var e = $(id); if (e) e.style.display = 'none'; } catch (_) {}
      });
      try { $('edwrap').style.display = 'none'; } catch (_) {}
      try { $('src-display').style.display = 'none'; } catch (_) {}
      try { $('text-view').style.display = ''; } catch (_) {}   // holds #unviewable
      $('unviewable-title').textContent = title;
      $('unviewable-why').textContent = why || '';
      $('unviewable').style.display = '';
    }
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
      // opts.readOnly: a host showing a PAST version. The editor would
      // otherwise offer to save an old version back as the present, which
      // is the one genuinely dangerous thing this component can do.
      //
      // WRITABLE, not editable: `editable` also decides whether the text is
      // rendered at all, so folding read-only into it showed "binary
      // content" instead of the file. The content is shown either way; only
      // saving is withheld.
      writable = editable && !opts.readOnly;
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
          var hr = await fetch(q('raw=1'));
          if (hr.headers.get('x-content-type-options') === 'nosniff') { sandboxed = true; showSandboxBanner(); }
        } catch (_) {}
      }
      if (buildStatus) tabBuild.style.display = '';
      if (editable) {
        try { edText = present(await readRaw()); }
        catch (e) { renderUnviewable('nothing to show', (e && e.message) || String(e)); return; }
        edwrap.style.display = '';
      } else if (info.jammed) {
        src.textContent = info.text || ''; src.style.display = '';
      } else {
        src.className = 'dim'; src.textContent = 'binary content'; src.style.display = '';
      }
      setupPanes(); setupWrap(); setupEditor(); renderSource();
    }

    // a failed read is an ERROR, never content: without the status check the
    // server's message ("that version is not there") lands in the editor and
    // reads as the file's own text
    function readRaw() {
      return fetch(q('raw=1')).then(function (r) {
        return r.text().then(function (t) {
          if (!r.ok) throw new Error(t || ('http ' + r.status));
          return t;
        });
      });
    }
    function present(text) {
      if (effectiveKind() === 'json') { try { return JSON.stringify(JSON.parse(text), null, 2); } catch (_) {} }
      return text;
    }

    function show(which) {
      textView.style.display = which === 'text' ? '' : 'none';
      mimeView.style.display = which === 'mime' ? '' : 'none';
      buildView.style.display = which === 'build' ? '' : 'none';
      viewPane.style.display = which === 'view' ? '' : 'none';
      tabText.classList.toggle('on', which === 'text');
      tabMime.classList.toggle('on', which === 'mime');
      tabBuild.classList.toggle('on', which === 'build');
      tabView.classList.toggle('on', which === 'view');
      tools.style.display = which === 'text' ? '' : 'none';
      $('mime-row').style.display = which === 'view' ? 'none' : '';
      if (which === 'mime' && !mimeRendered) { renderMime(); mimeRendered = true; }
      if (which === 'build' && !buildRendered) { renderBuild(); buildRendered = true; }
      if (which === 'view' && viewer && !viewerHandle) {
        try { viewerHandle = viewer.mount(viewPane, { url: here, onNavigate: opts.onNavigate }) || { destroy: function () {} }; }
        catch (e) { viewPane.textContent = 'viewer failed: ' + e; }
      }
    }
    function setupPanes() {
      var previewable = !!effectiveKind() || !texty;
      tabText.addEventListener('click', function () { show('text'); });
      tabMime.addEventListener('click', function () { show('mime'); });
      tabBuild.addEventListener('click', function () { show('build'); });
      tabView.addEventListener('click', function () { show('view'); });
      var showTabs = previewable || buildStatus || viewer;
      tabText.style.display = showTabs ? '' : 'none';
      tabMime.style.display = showTabs ? '' : 'none';
      if (viewer) { tabView.textContent = viewer.label || 'View'; tabView.style.display = ''; }
      if (viewer) show('view'); else if (!previewable) show('text'); else show('mime');
    }

    function setupWrap() {
      var wrap = true;
      try { wrap = (localStorage.getItem(wrapKey) == null ? '1' : localStorage.getItem(wrapKey)) === '1'; } catch (_) {}
      var applyWrap = function () {
        root.classList.toggle('wrap', wrap);
        wrapBtn.classList.toggle('on', wrap);
        // CodeMirror wraps via its own lineWrapping option, not CSS
        // white-space — drive it so the editor matches the highlighted
        // display exactly. Read at mount time too (see ensureEditor).
        if (ve) ve.setLineWrapping(wrap);
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
      var text = ve ? ve.getValue() : edText;
      display.textContent = '';
      var p = document.createElement('pre'); p.textContent = text; display.appendChild(p);
      if (SHIKI_LANG[ext]) {
        try {
          var hl = await getShiki(SHIKI_LANG[ext]);
          p.outerHTML = hl.codeToHtml(text, { lang: SHIKI_LANG[ext], theme: 'github-light' });
        } catch (_) {}
      }
    }

    // vim keybindings default on, except on a touch/narrow device where a
    // physical Escape and chorded motions aren't really available — unless
    // the person has explicitly toggled it before, which always wins.
    function vimPref() {
      try {
        var v = localStorage.getItem('explorer-vim');
        if (v != null) return v === '1';
      } catch (_) {}
      try { return !(window.matchMedia('(pointer: coarse)').matches || window.innerWidth < 760); }
      catch (_) { return true; }
    }

    function setupEditor() {
      if (!writable) {
        editBtn.setAttribute('disabled', ''); saveBtn.setAttribute('disabled', ''); liveBtn.setAttribute('disabled', '');
        vimBtn.setAttribute('disabled', '');
        return;
      }
      var editing = false, clean = edText, live = false, liveTimer = null, miteChanged = false;
      var vimOn = vimPref();
      vimBtn.classList.toggle('on', vimOn);
      vimBtn.addEventListener('click', function () {
        vimOn = !vimOn;
        vimBtn.classList.toggle('on', vimOn);
        try { localStorage.setItem('explorer-vim', vimOn ? '1' : '0'); } catch (_) {}
        if (ve) ve.setVim(vimOn);
      });
      // VimEditor mounts on first Edit click, not at boot — a file that's
      // only ever read never pays to load CodeMirror.
      function ensureEditor() {
        if (ve) return ve;
        ve = VimEditor.mount(ed, {
          value: clean,
          mime: mite,
          vim: vimOn,
          lineWrapping: root.classList.contains('wrap'),
          onChange: function () { syncSaveBtn(); if (live) scheduleLive(); }
        });
        return ve;
      }
      editBtn.addEventListener('click', function () {
        editing = !editing;
        editBtn.classList.toggle('on', editing);
        ed.style.display = editing ? '' : 'none';
        display.style.display = editing ? 'none' : '';
        mimeInput.readOnly = !editing;
        if (editing) {
          show('text');
          ensureEditor().ready.then(function () { ve.refresh(); ve.focus(); });
        } else renderSource();
      });
      liveBtn.addEventListener('click', function () {
        live = !live; liveBtn.classList.toggle('on', live); syncSaveBtn();
        if (live && ve && ve.getValue() !== clean) scheduleLive();
      });
      function syncSaveBtn() {
        var cur = ve ? ve.getValue() : clean;
        if (live || (cur === clean && !miteChanged)) saveBtn.setAttribute('disabled', '');
        else saveBtn.removeAttribute('disabled');
      }
      function scheduleLive() {
        clearTimeout(liveTimer);
        liveTimer = setTimeout(function () { if (ve.getValue() !== clean) save(); }, 800);
      }
      mimeInput.addEventListener('input', function () { miteChanged = mimeInput.value.trim() !== mite; syncSaveBtn(); });
      async function save() {
        if (!ve) return;
        status.textContent = 'saving…'; status.className = '';
        var sent = ve.getValue();
        try {
          var res = await fetch(here, {
            method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' },
            body: new URLSearchParams(Object.assign({ action: 'write-text', content: sent }, miteChanged ? { mite: mimeInput.value.trim() } : {})),
          });
          var body = await res.text();
          if (res.ok) {
            var stored = present(await readRaw());
            clean = stored; edText = stored;
            if (ve.getValue() === sent && stored !== sent) {
              var cur = ve.getCursor();
              ve.setValue(stored);
              if (cur) ve.setCursor(cur);
              if (!editing) renderSource();
            }
            mite = mimeInput.value.trim(); miteChanged = false; syncSaveBtn();
            status.textContent = 'saved ✓';
            mimeRendered = false; mimeView.textContent = '';
            setTimeout(function () { if (status.textContent === 'saved ✓') status.textContent = ''; }, 2500);
          } else {
            ve.setValue(clean); syncSaveBtn(); status.textContent = '';
            showErr('save failed', body || ('save failed (' + res.status + ')'));
          }
        } catch (e) {
          ve.setValue(clean); syncSaveBtn(); status.textContent = ''; showErr('save failed', 'save failed: ' + e);
        }
      }
      saveBtn.addEventListener('click', function () { if (!saveBtn.hasAttribute('disabled')) save(); });
      root.addEventListener('keydown', function (e) {
        if ((e.metaKey || e.ctrlKey) && e.key === 's') { e.preventDefault(); if (ve && ve.getValue() !== clean) save(); }
      });
    }

    async function renderMime() {
      var rawUrl = q('raw=1');
      var text = editable ? (ve ? ve.getValue() : edText) : (src.textContent || '');
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
        try { await loadScript('/grubbery/ball/apps/shell.shell/ui/explorer/marked.min.js'); } catch (_) {}
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
      // a product the server read as test results: a grid rather than a
      // wall of printed noun. Three states, not two — a file that did not
      // compile carries no `tests` at all and still falls through to the
      // error detail below.
      var tests = (info.build && Array.isArray(info.build.tests)) ? info.build.tests : null;
      var suite = (tests && tests.length) ? tests : null;
      if (suite) {
        var bad = suite.filter(function (t) { return !t.ok; });
        var good = suite.filter(function (t) { return t.ok; });
        badge.className = bad.length ? 'err' : 'ok';
        badge.textContent = bad.length
          ? (suite.length - bad.length) + ' of ' + suite.length + ' passing, ' + bad.length + ' failing'
          : 'all ' + suite.length + ' passing';
        buildView.appendChild(badge);
        // failures stacked full-width because you read them; passes in a
        // dense grid because you glance at them. Two blocks, so the
        // boundary between them is not mid-row.
        var rendered = document.createElement('div');
        if (bad.length) rendered.appendChild(testList(bad, false));
        if (good.length) rendered.appendChild(testList(good, true));
        // the grid is a reading of the product, never a replacement for
        // it, so the raw noun is a sibling tab rather than gone
        var raw = document.createElement('pre');
        raw.style.cssText = 'margin:0;white-space:pre-wrap;overflow-wrap:anywhere;';
        raw.textContent = detail;
        buildView.appendChild(subTabs([['Tests', rendered], ['Raw', raw]]));
        buildView.appendChild(rendered);
        buildView.appendChild(raw);
        return;
      }
      buildView.appendChild(badge);
      if (detail) {
        var pre = document.createElement('pre');
        pre.style.cssText = 'margin:0;white-space:pre-wrap;overflow-wrap:anywhere;';
        pre.textContent = detail; buildView.appendChild(pre);
      }
    }

    // testList: one block of results. Failures get their own full-width
    // column, passes a dense grid. The `test-` prefix is on every arm and
    // carries nothing, so it is stripped; names wrap rather than
    // truncate, since half a test name is worse than a taller row.
    function testList(items, ok) {
      var box = document.createElement('div');
      box.style.cssText = ok
        ? 'display:grid;grid-template-columns:repeat(auto-fill,minmax(15rem,1fr));gap:4px;'
        : 'display:flex;flex-direction:column;gap:4px;margin-bottom:12px;';
      items.forEach(function (t) {
        var row = document.createElement('div');
        row.className = ok ? 'trow' : 'trow bad';
        var dot = document.createElement('span');
        dot.className = 'tdot';
        dot.style.background = ok ? '#116329' : '#cf222e';
        var nm = document.createElement('span');
        nm.className = 'tnam';
        nm.textContent = String(t.name || '').replace(/^test-/, '');
        row.appendChild(dot); row.appendChild(nm);
        box.appendChild(row);
      });
      return box;
    }

    // subTabs: the pane-tab idiom from #bar, one level down. Panes are
    // shown by display rather than [hidden], since a pane carrying an
    // inline display would otherwise win over the UA rule.
    function subTabs(entries) {
      var bar = document.createElement('div');
      bar.className = 'bsub';
      var btns = [];
      entries.forEach(function (e, i) {
        var b = document.createElement('button');
        b.type = 'button';
        b.textContent = e[0];
        b.className = i === 0 ? 'on' : '';
        e[1].style.display = i === 0 ? '' : 'none';
        b.addEventListener('click', function () {
          entries.forEach(function (o, j) {
            o[1].style.display = j === i ? '' : 'none';
            btns[j].className = j === i ? 'on' : '';
          });
        });
        btns.push(b);
        bar.appendChild(b);
      });
      return bar;
    }

    return {
      setUrl: function (u) { mount(root, Object.assign({}, opts, { url: u })); },
      destroy: function () {
        if (viewerHandle && viewerHandle.destroy) { try { viewerHandle.destroy(); } catch (_) {} }
        if (ve) { try { ve.destroy(); } catch (_) {} }
        errOverlay.remove(); root.innerHTML = '';
      }
    };
  }

  window.FileView = { mount: mount };
})();
