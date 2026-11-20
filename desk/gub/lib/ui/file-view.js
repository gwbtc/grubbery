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
// marked (window.marked) renders markdown when the host has loaded it; source
// highlighting is VimEditor's, the same one the editor uses. Styling is
// injected once, scoped under .fv; the host sizes the mount element.
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
    '.fv #tools button.icon{padding:3px 8px;display:inline-flex;align-items:center;color:#57606a}' +
    '.fv #tools button.icon:hover{color:#24292f}' +
    '.fv #tools button.icon.done{color:#1a7f37;border-color:#1a7f37}' +
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
    /* bare: the source alone, an editor and nothing else (opts.bare / onView) */
    '.fv.bare #versions,.fv.bare #crumbrow,.fv.bare #bar,.fv.bare #tools,.fv.bare #sandbox-banner{display:none!important}' +
    /* bare keeps one thin line: the blot and the mime type (:mime sets it) */
    '.fv.bare #mime-row{padding:2px 12px}' +
    '.fv #mime-blot{font:11px ui-monospace,SFMono-Regular,Menlo,monospace;color:#57606a;margin-right:6px}' +
    // the Wrap toggle drives the highlighted display; the editor drives its
    // own CodeMirror lineWrapping option (set alongside this, see setupWrap)
    '.fv.wrap #text-view pre,.fv.wrap #text-view code{white-space:pre-wrap!important;overflow-wrap:anywhere}' +
    '.fv:not(.wrap) #text-view pre,.fv:not(.wrap) #text-view code{white-space:pre!important}' +
    '.fv pre{margin:0;padding:18px;font:12px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace;overflow:auto;box-sizing:border-box;min-height:100%}' +
    '.fv pre.dim{color:#8b949e}' +
    '.fv pre.boom{color:#cf222e;background:#fff8f8}' +
    '.fv code{font:inherit}' +
    // Line numbers in Source: a CSS counter over the per-line spans the
    // highlighter emits, so the toggle costs nothing to render and leaves the
    // text selectable without the numbers coming along (user-select:none on
    // the ::before).
    '.fv.nums #src-display code{counter-reset:fvln}' +
    '.fv.nums #src-display .line{counter-increment:fvln}' +
    '.fv.nums #src-display .line::before{content:counter(fvln);display:inline-block;width:3ch;margin-right:16px;text-align:right;color:#8b949e;user-select:none}' +
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
    '<div id="versions"></div>' +     // the host's version bar (opts.versions), part of the chrome
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
      '<button id="numbtn" title="line numbers in Source and the editor">Lines</button>' +
      '<button id="vimbtn" title="vim keybindings in the editor">Vim</button>' +
      '<button id="copybtn" class="icon" title="copy the file\'s text">' +
        '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' +
          '<rect x="9" y="9" width="11" height="11" rx="2"/>' +
          '<path d="M5 15V5a2 2 0 0 1 2-2h10"/>' +
        '</svg>' +
      '</button>' +
      '<span id="status"></span>' +
    '</div>' +
    '<div id="mime-row" style="display:none">' +
      '<span id="mime-blot"></span>' +
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

  // Source and the editor are the same highlighter, so a file does not
  // change color when you start editing it. VimEditor owns it: see
  // +highlight there.
  function highlight(el, text, name) {
    return VimEditor.highlight(el, text, VimEditor.modeForName(name));
  }
  function loadScript(src) {
    return new Promise(function (res, rej) {
      var sc = document.createElement('script');
      sc.src = src; sc.onload = res; sc.onerror = rej;
      document.head.appendChild(sc);
    });
  }

  // +shared: one fetch per url at a time. Several views of the same file
  // mounting together (a restored session with the file in three panes)
  // join the request already in flight instead of each making its own.
  // Nothing is cached past the request: a later mount fetches afresh.
  var inflight = {};
  function shared(key, make) {
    if (inflight[key]) return inflight[key];
    var p = make().finally(function () { delete inflight[key]; });
    inflight[key] = p;
    return p;
  }

  function mount(root, opts) {
    opts = opts || {};
    injectStyle();
    root.classList.add('fv');
    // bare before the markup is on screen, not after boot: the chrome is in
    // the markup, so a class applied at the end of the sequence shows it and
    // then takes it away
    root.classList.toggle('bare', !!opts.bare);
    root.innerHTML = MARKUP;
    var wrapKey = opts.wrapKey || 'explorer-wrap';
    var numsKey = opts.numsKey || 'explorer-nums';
    // opts.view fixes the pane and takes the tabs away: the host mounts this
    // for one rendering and nothing else
    var FIXED_PANE = { source: 'text', preview: 'mime', build: 'build' };
    // opts.readOnly — show the file but never let it be written (past versions)
    var $ = function (id) { return root.querySelector('#' + id); };
    // opts.versions: the host's version bar (this path's history, the way
    // back to now). It sits above the crumbs, inside the chrome, so bare
    // hides it with everything else.
    if (opts.versions) $('versions').appendChild(opts.versions);

    var here = opts.url;
    // opts.at: a ?case= (or any extra query) that must ride along on EVERY
    // fetch this view makes -- otherwise a past version shows the present
    // file's content under a past label, which is worse than failing.
    var at = opts.at ? String(opts.at) : '';
    // `here` may already carry a query, so pick the separator per call
    var q = function (suffix) { return here + (here.indexOf('?') >= 0 ? '&' : '?') + suffix + at; };
    // A grub may have NO NAME -- dill's default session is the empty one.
    // It is spelled $ (hoon's %$) as the last segment, and named for the
    // reader, the same way a listing names one.
    var segs = here.replace(/\?.*$/, '').split('/');
    var unnamed = segs[segs.length - 1] === '$';
    var name = unnamed ? '' : decodeURIComponent(segs[segs.length - 1] || '');
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
    // the viewer's own keys, when the keyboard is on the viewer and not in
    // a field or the editor: e edit · F the bare editor view (Esc leaves it)
    // · 1 3 4 Source Build viewer · s save · w n v wrap numbers
    // vim · c copy · ? this list. Reader keys below scroll.
    // ---- the pane's commands ----
    // One table, two ways in: vim's `:` inside the editor and the pane's
    // own `:` prompt (the host asks handle.commands()). The editor extends
    // it with :w and the dirty-aware :q (see setupEditor).
    var exTable = null;
    function baseEx() {
      var host = opts.host || {};
      var target = function (args) {
        var p = (args[0] || '').trim();
        return !p ? here : /^(\/|@|\.\.?\/)/.test(p) ? p : './' + p;
      };
      return {
        q: function () { if (host.close) host.close(); },
        e: function (args) { if (args[0] && host.open) host.open(target(args)); },
        bare: function () { bareEditor(!bare); },
        mime: function () { say('mime type: ' + (mimeInput.value || mite)); },
        sp: function (args) { if (host.splitDown) host.splitDown(args[0] ? target(args) : null); },
        vs: function (args) { if (host.splitRight) host.splitRight(args[0] ? target(args) : null); }
      };
    }
    // a line to the person: vim's notification when the editor is up,
    // the status field otherwise
    function say(text) { status.textContent = text; if (ve && ve.notify) ve.notify(text); }
    var KEYS = ': command (:e :vs :sp :q :bare :mime, :w in the editor) · e edit · F bare editor (Esc leaves) · 1 3 4 source build viewer · s save · w wrap · n numbers · v vim · c copy · j k ␣ scroll · in the editor :w :q :q! :wq ZZ ZQ :e <path> :sp :vs :bare :mime <type>';
    function press(btn) { if (btn && !btn.hasAttribute('disabled') && btn.offsetParent !== null) btn.click(); }
    root.addEventListener('keydown', function (e) {
      if (e.metaKey || e.ctrlKey || e.altKey) return;
      var t = e.target, tag = t && t.tagName;
      if (tag === 'TEXTAREA' || tag === 'INPUT' || tag === 'SELECT' || (t && t.isContentEditable)) return;
      var k = e.key, used = true;
      if (k === 'e') press(editBtn);
      else if (k === 'F') bareEditor(!bare);
      else if (k === 'Escape' && bare) { if (opts.setBare) opts.setBare(false); else setBare(false); }
      else if (k === '1') press(tabText);
      else if (k === '3') press(tabBuild);
      else if (k === '4') press(tabView);
      else if (k === 's') press(saveBtn);
      else if (k === 'w') press(wrapBtn);
      else if (k === 'n') press(numBtn);
      else if (k === 'v') press(vimBtn);
      else if (k === 'c') press(copyBtn);
      else if (k === '?') { status.textContent = KEYS; setTimeout(function () { if (status.textContent === KEYS) status.textContent = ''; }, 4000); }
      else used = false;
      if (used) { e.preventDefault(); e.stopPropagation(); return; }
      var scroller = [textView, mimeView, buildView, viewPane, edwrap, display].find(function (x) { return x && x.offsetParent !== null && x.scrollHeight > x.clientHeight; });
      if (!scroller) return;
      var line = 40, page = Math.max(line, scroller.clientHeight * 0.9); used = true;
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
    var editBtn = $('edit'), saveBtn = $('save'), liveBtn = $('live'), wrapBtn = $('wrap'), numBtn = $('numbtn'), vimBtn = $('vimbtn');
    var copyBtn = $('copybtn');
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
      // slice(0,-1) drops the FILENAME ($ for the nameless grub)
      parts.slice(0, -1).forEach(function (s) { acc += '/' + s; wrap.appendChild(mk(s + '/', acc)); });
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

    // opts.prime = { url, info, text, sandboxed }: what another view of this
    // same file already holds (its snapshot()), so this one renders from
    // memory and skips the two fetches. Only taken for the same url.
    var prime = (opts.prime && opts.prime.url === here && opts.prime.info) ? opts.prime : null;
    // bare: the file alone -- no crumbs, tabs, tools or chips. Starts as the
    // host mounted it, and an onArgs arriving before the file is in writes
    // here, so whatever this holds at boot is what gets applied.
    var bare = !!opts.bare, booted = false;
    // the chrome goes, the file stays. The control is the host's -- the
    // pane's own View menu, beside rendered/raw -- because the state is the
    // moment's and not this component's (opts.setBare writes it).
    //
    // Chrome only. Bare is the resting state of a pane, so opening the
    // editor cannot ride along with it -- every file would arrive in an
    // editor, and CodeMirror would load for a file you only meant to read.
    // The F gesture asks for both; see +bareEditor.
    function setBare(on) {
      bare = !!on;
      root.classList.toggle('bare', bare);
      // asked before the file is in (the moment's args changed under a
      // view still fetching): remembered, applied once renderFile is done
      if (!booted) return;
      if (ve) ve.refresh();
    }
    // F: the file alone, in the editor -- the raw side's "just let me work on
    // this". On a pane showing a rendering there is nothing to edit, so it is
    // the chrome alone that moves.
    function bareEditor(on) {
      if (opts.setBare) opts.setBare(on); else setBare(on);
      if (!on || !booted) return;
      if (FIXED_PANE[opts.view] && opts.view !== 'source') return;
      show('text');
      if (writable && editBtn && !editBtn.classList.contains('on')) editBtn.click();
    }
    (async function boot() {
      if (prime) info = prime.info;
      else {
        try {
          var got = await shared(q('info=1'), function () {
            return fetch(q('info=1'), { headers: { accept: 'application/json' } }).then(function (ir) {
              return ir.ok ? ir.json().then(function (j) { return { ok: true, info: j }; })
                           : ir.text().then(function (t) { return { ok: false, why: t || ('http ' + ir.status) }; });
            });
          });
          if (!got.ok) { renderUnviewable('nothing to show', got.why); return; }
          info = got.info;
        } catch (e) { showErr('explorer', 'could not load file info: ' + e); return; }
      }
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
      $('mime-blot').textContent = info.blot ? 'blot ' + info.blot : '';
      mimeInput.value = mite;
      tools.style.display = '';
      $('mime-row').style.display = '';
      // only runnable types can be downgraded; one header check tells us if
      // the kernel serve-sandbox fired for this file, from any pane
      if (prime && prime.sandboxed != null) { if (prime.sandboxed) { sandboxed = true; showSandboxBanner(); } }
      else if (runnableMite(mite)) {
        try {
          var hr = await fetch(q('raw=1'));
          if (hr.headers.get('x-content-type-options') === 'nosniff') { sandboxed = true; showSandboxBanner(); }
        } catch (_) {}
      }
      if (buildStatus) tabBuild.style.display = '';
      if (editable) {
        try { edText = present(prime && typeof prime.text === 'string' ? prime.text : await readRaw()); }
        catch (e) { renderUnviewable('nothing to show', (e && e.message) || String(e)); return; }
        edwrap.style.display = '';
      } else if (info.jammed) {
        src.textContent = info.text || ''; src.style.display = '';
      } else {
        src.className = 'dim'; src.textContent = 'binary content'; src.style.display = '';
      }
      setupPanes(); setupWrap(); setupNums(); setupCopy(); setupEditor(); renderSource();
      booted = true;
      setBare(bare);
    }

    // a failed read is an ERROR, never content: without the status check the
    // server's message ("that version is not there") lands in the editor and
    // reads as the file's own text
    function readRaw() {
      return shared(q('raw=1'), function () {
        return fetch(q('raw=1')).then(function (r) {
          return r.text().then(function (t) {
            if (!r.ok) throw new Error(t || ('http ' + r.status));
            return t;
          });
        });
      });
    }
    function present(text) {
      if (effectiveKind() === 'json') { try { return JSON.stringify(JSON.parse(text), null, 2); } catch (_) {} }
      return text;
    }

    // +markFocus: data-focus says where gmux should put the keyboard. One
    // element carries it; nothing carrying it means the pane itself, which
    // is right for the reader (its keys are on the pane).
    function markFocus(el) {
      var had = root.querySelector('[data-focus]');
      if (had && had !== el) had.removeAttribute('data-focus');
      if (el) el.setAttribute('data-focus', '');
    }
    // +redrawPanes: the panes that render once and cache it, re-rendered if
    // they are the one on screen and dropped if they are not
    function redrawPanes() {
      mimeRendered = false; mimeView.textContent = '';
      buildRendered = false;
      if (mimeView.style.display !== 'none') { renderMime(); mimeRendered = true; }
      if (buildView.style.display !== 'none') { renderBuild(); buildRendered = true; }
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
      // the blot and the mime type are the raw side's: a rendering of the
      // file does not carry them
      var rendering = which === 'view' || which === 'mime';
      $('mime-row').style.display = rendering ? 'none' : '';
      if (which === 'mime' && !mimeRendered) { renderMime(); mimeRendered = true; }
      if (which === 'build' && !buildRendered) { renderBuild(); buildRendered = true; }
      if (which === 'view' && viewer && !viewerHandle) {
        try { viewerHandle = viewer.mount(viewPane, { url: here, onNavigate: opts.onNavigate }) || { destroy: function () {} }; }
        catch (e) { viewPane.textContent = 'viewer failed: ' + e; }
      }
    }
    // Preview is not in here: a rendering of the file is the OTHER side of
    // the pane's rendered/raw toggle, following the file so it redraws when
    // any pane saves it. What is left is the raw side — the source, and what
    // the grub built into.
    function setupPanes() {
      var fixed = FIXED_PANE[opts.view];
      tabText.addEventListener('click', function () { show('text'); });
      tabBuild.addEventListener('click', function () { show('build'); });
      tabView.addEventListener('click', function () { show('view'); });
      if (fixed) { show(fixed); return; }
      tabText.style.display = buildStatus || viewer ? '' : 'none';
      if (viewer) { tabView.textContent = viewer.label || 'View'; tabView.style.display = ''; }
      show(viewer ? 'view' : 'text');
    }

    // +currentText: what Source is showing right now — the editor's buffer
    // if one is mounted, the text we read otherwise, and for a file that
    // isn't editable the rendered <pre>.
    function currentText() {
      return editable ? (ve ? ve.getValue() : edText) : (src.textContent || '');
    }

    function setupCopy() {
      copyBtn.addEventListener('click', async function () {
        var text = currentText();
        var ok = true;
        try {
          await navigator.clipboard.writeText(text);
        } catch (_) {
          // no clipboard permission (or no secure context): the old way
          var ta = document.createElement('textarea');
          ta.value = text;
          ta.style.cssText = 'position:fixed;top:-1000px';
          document.body.appendChild(ta);
          ta.select();
          try { ok = document.execCommand('copy'); } catch (e) { ok = false; }
          document.body.removeChild(ta);
        }
        copyBtn.classList.toggle('done', ok);
        status.textContent = ok ? 'copied' : 'could not copy';
        setTimeout(function () {
          copyBtn.classList.remove('done');
          if (status.textContent === 'copied' || status.textContent === 'could not copy') status.textContent = '';
        }, 1400);
      });
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

    // Line numbers, toggled together for Source (CSS counter over the .line
    // spans) and the editor (CodeMirror's own lineNumbers), so the two panes
    // always agree. Default on — the editor already numbered by default.
    function setupNums() {
      var nums = true;
      try { nums = (localStorage.getItem(numsKey) == null ? '1' : localStorage.getItem(numsKey)) === '1'; } catch (_) {}
      var applyNums = function () {
        root.classList.toggle('nums', nums);
        numBtn.classList.toggle('on', nums);
        if (ve) ve.setLineNumbers(nums);
      };
      numBtn.addEventListener('click', function () {
        nums = !nums;
        try { localStorage.setItem(numsKey, nums ? '1' : '0'); } catch (_) {}
        applyNums();
      });
      applyNums();
    }

    function renderSource() {
      if (!editable) return;
      // the editor is showing: highlighting the whole file into a hidden
      // element is the file's length in work for nothing
      if (display.style.display === 'none') return;
      var text = ve ? ve.getValue() : edText;
      return highlight(display, text, name);
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
          mode: VimEditor.modeForName(name),
          mime: mite,
          vim: vimOn,
          lineNumbers: root.classList.contains('nums'),
          lineWrapping: root.classList.contains('wrap'),
          onChange: function () { syncSaveBtn(); if (live) scheduleLive(); },
          ex: exTable
        });
        return ve;
      }
      // vim's command line, bound to this file and its pane: :w saves, :q
      // closes the tab (:bare is the way out of bare), :wq both, :e
      // <path> opens a path (relative to this file's dir, like vim's; :e
      // alone re-reads the file), :sp / :vs <path> split the pane (the host's
      // opts.host = { open(path), close(), splitDown(path), splitRight(path) }).
      function exCommands() {
        var host = opts.host || {};
        var base = baseEx();
        // :q refuses to drop unsaved text, like vim; :q! (and ZQ) drops it.
        // This vim passes no bang flag: the `!` arrives as the argument.
        var banged = function (args, params) { return (args[0] === '!') || !!(params && params.bang) || /^\s*!/.test((params && params.argString) || ''); };
        var dirty = function () { return !!(ve && writable && ve.getValue() !== clean); };
        var quit = function (args, params) {
          if (dirty() && !banged(args || [], params)) {
            say('unsaved changes: :w, :wq, or :q! to drop them');
            return;
          }
          if (ve && dirty()) { ve.setValue(clean); syncSaveBtn(); }
          if (host.close) host.close();
        };
        // the pane's own :e, kept before the editor's :e is laid over it
        // (a bare :e re-reads the buffer; one with a path is the pane's)
        var baseOpen = base.e;
        var open = function (args) {
          if (!args[0]) { if (ve) ve.setValue(clean); return; }
          baseOpen(args);
        };
        var mimeCmd = function (args) {
          var v = (args[0] || '').trim();
          if (!v) { say('mime type: ' + (mimeInput.value || mite)); return; }
          mimeInput.value = v; miteChanged = v !== mite; syncSaveBtn();
          say('mime type ' + v + (miteChanged ? ' — :w to save' : ''));
        };
        exTable = Object.assign({}, base, {
          w: function () { if (writable) save(); },
          mime: mimeCmd,
          q: quit,
          wq: function () { if (writable && ve && ve.getValue() !== clean) save().then(quit); else quit(); },
          x: function () { if (writable && ve && ve.getValue() !== clean) save().then(quit); else quit(); },
          e: open
        });
        return exTable;
      }
      exCommands();
      // +setEditing: which surface the text pane shows. The editor is the
      // one you land on: with vim on, reading IS its resting state, and the
      // two render the same way anyway. The reader stays for the cases the
      // editor is worse at -- no vim, and the browser's own find, which
      // CodeMirror's viewport does not answer.
      function setEditing(on, focus) {
        editing = !!on;
        editBtn.classList.toggle('on', editing);
        ed.style.display = editing ? '' : 'none';
        display.style.display = editing ? 'none' : '';
        mimeInput.readOnly = !editing;
        if (!editing) { markFocus(null); renderSource(); return; }
        show('text');
        ensureEditor().ready.then(function () {
          ve.refresh();
          // where the keyboard goes when the host hands this pane focus: the
          // editor's own input. Without it gmux focuses the pane element and
          // vim never sees a key, so arriving by Ctrl-B needs a click first.
          markFocus(ve.inputField ? ve.inputField() : null);
          if (focus) ve.focus();
        });
      }
      editBtn.addEventListener('click', function () { setEditing(!editing, true); });
      // which surface the pane opens on: opts.surface, 'editor' unless the
      // host says 'reader'. Not when there is nothing to edit (a rendering,
      // an unwritable file), and not when the app declared a view of its
      // own -- setupPanes already chose that, and the editor must not steal it
      if (opts.surface !== 'reader' && writable && !viewer && !FIXED_PANE[opts.view]) setEditing(true, false);
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
            // the mime the grub serves as NOW: the mark may have kept the
            // one typed, or not (txt keeps text, drops the mite)
            try {
              var ir2 = await fetch(q('info=1'), { headers: { accept: 'application/json' } });
              if (ir2.ok) { var i2 = await ir2.json(); if (i2 && i2.mite) mite = i2.mite; }
            } catch (_) {}
            mimeInput.value = mite; chip('chip-mime', mite); miteChanged = false; syncSaveBtn();
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
      var text = currentText();
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
        try { await loadScript('/grubbery/ball/apps/shell/ui/explorer/marked.min.js'); } catch (_) {}
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
      // the file moved under us — someone saved it, here or in another pane.
      // Re-read and redraw, which is how a preview pane shows a save made in
      // an editor pane beside it.
      //
      // Unsaved text is never thrown away: a pane holding edits keeps them
      // and says the file changed, because the alternative is losing work to
      // a write nobody in this pane asked for.
      onUpdate: function () {
        if (!booted) return;
        if (ve && writable && ve.getValue() !== clean) {
          status.textContent = 'changed on disk';
          return;
        }
        if (!editable) { redrawPanes(); return; }
        readRaw().then(function (t) {
          var text = present(t);
          clean = text; edText = text;
          if (ve) ve.setValue(text);
          renderSource();
          redrawPanes();
        }).catch(function () {});
      },
      // the pane's `:` prompt runs these; vim's `:` inside the editor runs the same
      commands: function () { return exTable || baseEx(); },
      // what another view of this file can start from: see opts.prime
      snapshot: function () { return { url: here, info: info, text: currentText(), sandboxed: sandboxed }; },
      // the moment's ?args changed under this element. ?bare is taken in
      // place, in either direction. Any other change of args is not ours
      // to take.
      onArgs: function (args) {
        // the host decides what an ABSENT bare means (its own default), so
        // absence here is "nobody touched it" and the state stands. Only an
        // explicit value moves it -- and '0' is a truthy string, so it has
        // to be compared, never tested.
        var v = args ? args.bare : null;
        var want = v == null ? bare : v !== '0';
        var rest = Object.assign({}, args || {}); delete rest.bare;
        var mine = Object.assign({}, opts.query || {}); delete mine.bare;
        if (JSON.stringify(rest) !== JSON.stringify(mine)) return false;
        // taken in place either way: bare is the chrome and nothing else, so
        // neither direction changes which rendering the host would mount
        setBare(want);
        return true;
      },
      destroy: function () {
        if (viewerHandle && viewerHandle.destroy) { try { viewerHandle.destroy(); } catch (_) {} }
        if (ve) { try { ve.destroy(); } catch (_) {} }
        errOverlay.remove(); root.innerHTML = '';
      }
    };
  }

  // +prefetch: what a mount of `url` would fetch, fetched now and handed
  // back as a prime (see opts.prime): the info, and the text when the file
  // is text. Shares requests with any mount in flight. The sandbox header
  // is left to the mount (sandboxed: null means "check").
  function prefetch(url) {
    var sep = url.indexOf('?') >= 0 ? '&' : '?';
    return shared(url + sep + 'info=1', function () {
      return fetch(url + sep + 'info=1', { headers: { accept: 'application/json' } }).then(function (ir) {
        return ir.ok ? ir.json().then(function (j) { return { ok: true, info: j }; })
                     : ir.text().then(function (t) { return { ok: false, why: t || ('http ' + ir.status) }; });
      });
    }).then(function (got) {
      if (!got.ok) return null;
      var info = got.info;
      if (!info || !info.texty || info.jammed || info.kind === 'missing' || info.kind === 'boom') return { url: url, info: info, text: null, sandboxed: null };
      return shared(url + sep + 'raw=1', function () {
        return fetch(url + sep + 'raw=1').then(function (r) {
          return r.text().then(function (t) { if (!r.ok) throw new Error(t || ('http ' + r.status)); return t; });
        });
      }).then(function (text) { return { url: url, info: info, text: text, sandboxed: null }; });
    }).catch(function () { return null; });
  }

  window.FileView = { mount: mount, prefetch: prefetch };
})();
