// forge-docs: the repo handbook as a pane. The reader (docs-reader.js) ported
// to window.Viewers: one mount is one instance, scoped to its root (classes,
// not ids, so several can coexist), routed by the moment it sits on
// (?page=<doc> | coverage | coverage/<section>) instead of location.hash, so
// back/forward and layouts work and the host never knows what a page is.
//
//   mount(root, {url, args: {repo, api}, query: {page}, onNavigate})
//     -> { destroy, onUpdate }
//
// Data comes from forge's per-repo docs routes (nav.json, page, search,
// coverage.json, slice, chat) at /grubbery/forge/repo/<repo>/docs. Caches
// (nav, page text, resolved blocks, a pending scroll target) live at module
// level per repo, so a navigation (= a remount by the host) is cheap and a
// jump from coverage to a block survives it. The chat is a column inside the
// pane (clanker's own chat pane mounted on the repo clanker's docs log), not
// a floating window.
(function () {
  'use strict';
  window.Viewers = window.Viewers || {};

  var CSS_ID = 'forge-docs-css';
  function css() {
    if (document.getElementById(CSS_ID)) return;
    var s = document.createElement('style'); s.id = CSS_ID;
    s.textContent =
      '.forge-docs{--bg:#fff;--fg:#1a1a1a;--muted:#6b6b6b;--line:#e6e6e6;--accent:#3d3a45;--sidebar:#fafafa;--code-bg:#f4f4f5;' +
        'position:relative;height:100%;display:flex;flex-direction:column;overflow:hidden;background:var(--bg);color:var(--fg);' +
        'font:15px/1.65 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;container-type:inline-size}' +
      '.forge-docs *{box-sizing:border-box}' +
      '.forge-docs split-view:not(:defined){display:none!important}' +
      '.forge-docs .d-docs{flex:1 1 auto;min-height:0;--sv-border:var(--line)}' +
      '.forge-docs .d-sidebar{position:relative;height:100%;background:var(--sidebar);border-right:1px solid var(--line);padding:24px 0;overflow-y:auto;overflow-x:hidden;min-width:190px}' +
      '.forge-docs .d-sb-collapse{position:absolute;top:10px;right:8px;z-index:2;width:22px;height:22px;display:flex;align-items:center;justify-content:center;border:none;background:none;cursor:pointer;color:var(--muted);border-radius:5px;font-size:15px;line-height:1}' +
      '.forge-docs .d-sb-collapse:hover{background:#ececec;color:var(--fg)}' +
      '.forge-docs .d-sidebar h1{font-size:13px;text-transform:uppercase;letter-spacing:.08em;color:var(--muted);margin:0 0 12px;padding:0 24px}' +
      '.forge-docs .d-nav,.forge-docs .d-nav ul{list-style:none;margin:0;padding:0}' +
      '.forge-docs .d-nav a{display:block;padding:6px 24px;color:var(--fg);text-decoration:none;border-left:2px solid transparent;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}' +
      '.forge-docs .d-nav a:hover{background:#f0f0f0}' +
      '.forge-docs .d-nav a.active{border-left-color:var(--accent);font-weight:600;background:#f0f0f0}' +
      '.forge-docs .d-nav .sec-head{padding:8px 24px 4px;font-size:12px;text-transform:uppercase;letter-spacing:.06em;color:var(--muted);cursor:pointer;user-select:none;display:flex;align-items:center;gap:6px;white-space:nowrap;overflow:hidden}' +
      '.forge-docs .d-nav .sec-head::before{content:"▾";font-size:10px;transition:transform .1s}' +
      '.forge-docs .d-nav .sec.collapsed > .sec-head::before{transform:rotate(-90deg)}' +
      '.forge-docs .d-nav .sec.collapsed > ul{display:none}' +
      '.forge-docs .d-nav .sec ul a{padding-left:36px}' +
      '.forge-docs .d-nav .sec .sec > .sec-head{padding-left:36px;text-transform:none;letter-spacing:0;font-size:12.5px}' +
      '.forge-docs .d-nav .sec .sec ul a{padding-left:48px}' +
      '.forge-docs .nav-cov-pct{font:10px ui-monospace,monospace;flex:0 0 auto;text-align:right;padding:1px 24px 1px 8px;cursor:pointer}' +
      '.forge-docs .d-nav .sec-head .nav-cov-pct{padding-right:6px}' +
      '.forge-docs .nav-cov-pct:hover{text-decoration:underline}.forge-docs .nav-cov-pct.f{color:#1a7f37}.forge-docs .nav-cov-pct.d{color:#9a6700}' +
      '.forge-docs .d-nav .cov-toggle{display:flex;align-items:center;justify-content:space-between;gap:8px;padding:4px 24px 10px}' +
      '.forge-docs .d-nav .cov-toggle .nav-cov-pct{padding-right:0}' +
      '.forge-docs .d-nav .cov-toplink{font-size:13px;font-weight:600;color:var(--fg);text-decoration:none}.forge-docs .d-nav .cov-toplink:hover{text-decoration:underline}' +
      '.forge-docs .d-main{height:100%;min-width:0;display:flex;flex-direction:row}' +
      '.forge-docs .d-content{flex:1 1 auto;height:100%;min-width:0;display:flex;flex-direction:column;overflow-y:auto}' +
      '.forge-docs .d-topbar{position:sticky;top:0;z-index:20;background:rgba(255,255,255,.9);backdrop-filter:blur(6px);border-bottom:1px solid var(--line);display:flex;justify-content:flex-end;align-items:center;gap:10px;padding:12px 40px}' +
      '.forge-docs .d-search-wrap{position:relative;width:280px;max-width:100%}' +
      '.forge-docs .d-search-input{width:100%;background:#fff;border:1px solid var(--line);border-radius:8px;padding:8px 12px;font-size:13px;color:var(--fg);outline:none;transition:border-color .12s,box-shadow .12s}' +
      '.forge-docs .d-search-input:focus{border-color:var(--accent);box-shadow:0 0 0 3px rgba(61,58,69,.12)}' +
      '.forge-docs .d-search-results{position:absolute;top:calc(100% + 6px);right:0;width:380px;max-width:80cqw;list-style:none;margin:0;padding:6px;background:#fff;border:1px solid var(--line);border-radius:10px;box-shadow:0 12px 40px rgba(0,0,0,.14);max-height:60vh;overflow-y:auto;z-index:30}' +
      '.forge-docs .d-search-results.hidden{display:none}' +
      '.forge-docs .d-search-results .result{padding:9px 12px;border-radius:7px;cursor:pointer}.forge-docs .d-search-results .result.sel{background:#eef1ff}' +
      '.forge-docs .d-search-results .r-title{font-weight:600;font-size:13px}' +
      '.forge-docs .d-search-results .r-snip{font-size:12px;color:var(--muted);margin-top:2px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}' +
      '.forge-docs .d-search-results .no-hits{padding:14px;color:var(--muted);font-style:italic;text-align:center}' +
      '.forge-docs .d-doc-wrap{flex:1;display:flex;justify-content:center;align-items:flex-start;gap:24px}' +
      '.forge-docs .d-doc{max-width:720px;width:100%;min-width:0;padding:40px 40px 64px}' +
      '.forge-docs .d-otp{position:sticky;top:58px;align-self:flex-start;flex:0 0 190px;width:190px;padding:8px 24px 40px 0;max-height:calc(100vh - 78px);overflow-y:auto;font:12.5px/1.4 -apple-system,system-ui,sans-serif}' +
      '.forge-docs .d-otp[hidden]{display:none}' +
      '.forge-docs .d-otp .otp-h{text-transform:uppercase;letter-spacing:.05em;font-size:10.5px;font-weight:600;color:var(--muted);margin:0 0 10px 12px}' +
      '.forge-docs .d-otp a{display:block;color:var(--muted);text-decoration:none;padding:3px 0 3px 12px;border-left:2px solid var(--line);white-space:normal}' +
      '.forge-docs .d-otp a:hover{color:var(--fg)}.forge-docs .d-otp a.active{color:var(--fg);border-left-color:var(--accent)}' +
      '.forge-docs .d-otp a.lvl3{padding-left:24px;font-size:12px}.forge-docs .d-otp a.lvl4{padding-left:36px;font-size:11.5px}' +
      '@container (max-width:1080px){.forge-docs .d-otp{display:none!important}}' +
      '@container (max-width:900px){.forge-docs .d-topbar{padding:10px 16px}.forge-docs .d-doc{padding:24px 20px 48px}}' +
      '.forge-docs .d-doc h1,.forge-docs .d-doc h2,.forge-docs .d-doc h3,.forge-docs .d-doc h4{scroll-margin-top:72px}' +
      '.forge-docs .d-doc h1{font-size:30px;margin:0 0 8px}' +
      '.forge-docs .d-doc h2{font-size:21px;margin:36px 0 10px;border-bottom:1px solid var(--line);padding-bottom:6px}' +
      '.forge-docs .d-doc h3{font-size:17px;margin:28px 0 8px}.forge-docs .d-doc h4{font-size:15px;margin:22px 0 6px}' +
      '.forge-docs .d-doc p,.forge-docs .d-doc li{color:#2a2a2a}' +
      '.forge-docs .d-doc code{background:var(--code-bg);padding:2px 5px;border-radius:4px;font-size:.9em}' +
      '.forge-docs .d-doc pre{background:var(--code-bg);padding:16px;border-radius:8px;overflow-x:auto}.forge-docs .d-doc pre code{background:none;padding:0}' +
      '.forge-docs .d-doc a{color:#2b6cb0}' +
      '.forge-docs .d-doc blockquote{border-left:3px solid var(--line);margin:0;padding-left:16px;color:var(--muted)}' +
      '.forge-docs .d-doc .callout{border:1px solid;border-radius:8px;padding:12px 16px;margin:0 0 18px}' +
      '.forge-docs .d-doc .callout .callout-h{font-weight:600;font-size:12.5px;margin-bottom:5px}' +
      '.forge-docs .d-doc .callout > p{margin:6px 0 0}.forge-docs .d-doc .callout > p:first-of-type{margin-top:0}' +
      '.forge-docs .d-doc .callout-background{background:#f6f5fb;border-color:#e5e0f2}.forge-docs .d-doc .callout-background .callout-h{color:#6b5fa8}' +
      '.forge-docs .d-doc .callout-note{background:#eef4fb;border-color:#d6e3f2}.forge-docs .d-doc .callout-note .callout-h{color:#2b6cb0}' +
      '.forge-docs .d-doc .callout-tip{background:#eef7f0;border-color:#d4e8db}.forge-docs .d-doc .callout-tip .callout-h{color:#1a7f37}' +
      '.forge-docs .d-doc .callout-warn,.forge-docs .d-doc .callout-warning{background:#fff8ec;border-color:#f0dcae}' +
      '.forge-docs .d-doc .callout-warn .callout-h,.forge-docs .d-doc .callout-warning .callout-h{color:#9a6700}' +
      '.forge-docs .d-empty{color:var(--muted)}.forge-docs mark{background:#ffe9a8;color:inherit;border-radius:2px}' +
      '.forge-docs .doc-skeleton{animation:fd-sk-fade .2s ease}' +
      '.forge-docs .sk{height:15px;margin:13px 0;border-radius:6px;background:linear-gradient(90deg,#ececec 25%,#f6f6f6 37%,#ececec 63%);background-size:400% 100%;animation:fd-sk-shimmer 1.4s ease infinite}' +
      '.forge-docs .sk-title{height:30px;width:52%;margin:0 0 28px}.forge-docs .sk-sub{height:20px;width:34%;margin:30px 0 14px}.forge-docs .sk-short{width:42%}.forge-docs .sk-gap{height:26px;background:none;animation:none}' +
      '@keyframes fd-sk-shimmer{0%{background-position:100% 0}100%{background-position:0 0}}@keyframes fd-sk-fade{from{opacity:0}to{opacity:1}}' +
      '.forge-docs .code-sk{padding:14px 16px;animation:fd-sk-fade .2s ease}' +
      '.forge-docs .code-sk i{display:block;height:10px;margin:8px 0;border-radius:4px;background:linear-gradient(90deg,#ececec 25%,#f6f6f6 37%,#ececec 63%);background-size:400% 100%;animation:fd-sk-shimmer 1.4s ease infinite}' +
      '.forge-docs .d-foot{flex:0 0 auto;padding:8px 40px;color:var(--muted);font-size:12px;font-style:italic;text-align:center;background:var(--sidebar);border-top:1px solid var(--line);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}' +
      '.forge-docs .live-wrap{margin:18px 0;border:1px solid var(--line);border-radius:8px;overflow:hidden;scroll-margin-top:72px}' +
      '.forge-docs .live-wrap.live-focus{border-color:#d4a72c;box-shadow:0 0 0 3px #fff1c2}.forge-docs .live-wrap.live-focus > .live-head{background:#fff8dc}' +
      '.forge-docs .live-head{font:12px/1.4 ui-monospace,SFMono-Regular,Menlo,monospace;color:var(--muted);background:var(--sidebar);padding:7px 14px;border-bottom:1px solid var(--line)}' +
      '.forge-docs .live-body pre,.forge-docs .live-body .shiki{margin:0;padding:14px 16px;overflow-x:auto;font-size:13px;line-height:1.5}';
    document.head.appendChild(s);
  }

  var MARKUP =
    '<split-view class="d-docs" size="240px" min="190" max="420" persist="docs-sidebar">' +
      '<nav class="d-sidebar" slot="start">' +
        '<button class="d-sb-collapse" title="Collapse sidebar" aria-label="Collapse sidebar">‹</button>' +
        '<h1>Handbook</h1>' +
        '<ul class="d-nav"></ul>' +
      '</nav>' +
      '<div class="d-main" slot="end">' +
        '<main class="d-content">' +
          '<header class="d-topbar">' +
            '<div class="d-search-wrap">' +
              '<input class="d-search-input" type="text" placeholder="Search docs…  ⌘K" autocomplete="off" spellcheck="false">' +
              '<ul class="d-search-results hidden"></ul>' +
            '</div>' +
          '</header>' +
          '<div class="d-doc-wrap">' +
            '<article class="d-doc"></article>' +
            '<aside class="d-otp" hidden></aside>' +
          '</div>' +
        '</main>' +
      '</div>' +
    '</split-view>' +
    '<footer class="d-foot">This handbook began as an LLM-automated first pass and is being adapted by hand — treat specifics as provisional.</footer>';

  // per-repo state that outlives a mount: a navigation is a remount, and a
  // jump from coverage to a block (or back) has to land after it
  var SHARED = {};
  function sharedFor(repo) {
    return SHARED[repo] || (SHARED[repo] = { tree: null, leaves: [], textCache: {}, blocksCache: {}, pendingScroll: null, covFocus: null, covSecByName: null, covOverall: null, chatInfo: undefined });
  }
  var shikiP = null;
  function ensureShiki() {
    if (shikiP) return shikiP;
    shikiP = import('https://esm.sh/shiki@1.24.0').then(function (m) {
      return fetch('/grubbery/ball/apps/explorer.explorer/hoon-grammar.json').then(function (r) { return r.json(); })
        .then(function (grammar) { return m.createHighlighter({ themes: ['github-light'], langs: [grammar, 'javascript', 'css', 'json'] }); });
    }).catch(function () { return null; });
    return shikiP;
  }
  var markedP = null;
  function ensureMarked() {
    if (window.marked) return Promise.resolve(window.marked);
    if (markedP) return markedP;
    markedP = loadScript('/grubbery/forge/marked.min.js').then(function () { return window.marked || null; }).catch(function () { return null; });
    return markedP;
  }
  function loadScript(src) {
    return new Promise(function (res, rej) {
      var s = document.createElement('script'); s.src = src; s.onload = res; s.onerror = function () { rej(new Error('failed to load ' + src)); };
      document.head.appendChild(s);
    });
  }
  var covStylesDone = false;
  function coverageStyles() {
    if (covStylesDone) return; covStylesDone = true;
    var s = document.createElement('style');
    s.id = 'forge-docs-cov-style';
    s.textContent =
      '.cov h1{margin:0 0 4px}.cov .sub{color:#79808a;margin:0 0 20px}' +
      '.cov-head{display:flex;align-items:baseline;justify-content:space-between;gap:12px}' +
      '.cov-link{font-size:12px;color:#57606a;text-decoration:none;border:1px solid #e2e7ee;border-radius:7px;padding:4px 10px;white-space:nowrap}' +
      '.cov-link:hover{background:#fafbfc;color:#1f2328}' +
      '.cov-back{display:inline-block;font-size:12px;color:#79808a;text-decoration:none;margin:0 0 10px}' +
      '.cov-back:hover{color:#1f2328}' +
      '.cov-file-rng{color:#8a929c;font-weight:400}' +
      '.cov-target{display:flex;align-items:center;gap:12px;margin:0 0 20px;flex-wrap:wrap}' +
      '.cov-target-lab{font:10.5px -apple-system,sans-serif;text-transform:uppercase;letter-spacing:.05em;color:#9aa0a8}' +
      '.cov-target-path{font:12px ui-monospace,monospace;color:#57606a}' +
      '.cov-src-chip{display:inline-flex;align-items:center;gap:7px}' +
      '.cov-src-tag{font:11px ui-monospace,monospace;background:#eef2f7;color:#3a4149;border-radius:5px;padding:2px 7px}' +
      '.cov-src-path{font:12px ui-monospace,monospace;color:#8a929c}' +
      '.cov-seclist{display:flex;flex-direction:column;gap:8px}' +
      '.cov-secrow{display:grid;grid-template-columns:1fr 52px 120px 14px;gap:14px;align-items:center;padding:13px 14px;border:1px solid #eef0f3;border-radius:8px;text-decoration:none;background:#fff}' +
      '.cov-secrow:hover{background:#fafbfc;border-color:#e2e7ee}' +
      '.cov-secrow.dr{border-color:#f0dcae;background:#fffdf8}' +
      '.cov-secrow-main{min-width:0}' +
      '.cov-secrow-name{font:14px -apple-system,sans-serif;font-weight:600;color:#1f2328}' +
      '.cov-secrow-sub{font:11.5px ui-monospace,monospace;color:#8a929c;margin-top:2px}' +
      '.cov-secrow.dr .cov-secrow-sub{color:#9a6700}' +
      '.cov-secrow-pct{font:15px -apple-system,sans-serif;font-weight:600;color:#1f2328;text-align:right}' +
      '.cov-secrow-go{color:#b0b6bd;font-size:16px;text-align:center}' +
      '.cov-secgroup{font:11px -apple-system,sans-serif;text-transform:uppercase;letter-spacing:.05em;color:#9aa0a8;margin:12px 0 0}' +
      '.cov-row{display:grid;grid-template-columns:1fr 84px 108px 108px 20px;gap:12px;align-items:center;padding:9px 4px;border-bottom:1px solid #f2f4f6;cursor:pointer}' +
      '.cov-row:hover{background:#fafbfc}.cov-row.cov-gap{cursor:default}.cov-row.cov-gap .cov-file{color:#a40e26}' +
      '.cov-file{font:12.5px ui-monospace,monospace;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +
      '.cov-head{color:#8b949e}' +
      '.cov-act{color:#b0b6bd;text-align:center;font-size:14px;cursor:pointer;user-select:none}.cov-act:hover{color:#57606a}' +
      '.cov-tgt{display:flex;justify-content:space-between;align-items:center;padding:6px 4px;border-bottom:1px solid #f2f4f6;font:12.5px ui-monospace,monospace}' +
      '.cov-sec{margin:22px 0 2px;font-size:12px;text-transform:uppercase;letter-spacing:.05em;color:#57606a}' +
      '.cov-secsub{color:#9aa0a8;font-size:12px;margin:0 0 6px}' +
      '.cov-bar{height:7px;border-radius:4px;background:#eef0f3;overflow:hidden}.cov-bar>i{display:block;height:100%;background:#1a7f37}' +
      '.cov-pct{font:12px ui-monospace,monospace;color:#57606a;text-align:right}' +
      '.cov-flags{font:11px ui-monospace,monospace;display:flex;gap:6px;justify-content:flex-end}' +
      '.cov-flags .f{color:#1a7f37}.cov-flags .d{color:#9a6700}.cov-flags .g{color:#a40e26}.cov-flags .u{color:#79808a}' +
      '.cov-heat{margin:2px 0 18px}' +
      '.cov-slices{display:flex;flex-wrap:wrap;gap:6px;align-items:center;margin:0 0 8px}' +
      '.cov-slices-lab{font-size:10.5px;text-transform:uppercase;letter-spacing:.05em;color:#9aa0a8;margin-right:2px}' +
      '.cov-slice{font:11px ui-monospace,monospace;padding:3px 9px;border-radius:12px;background:#eef6f0;color:#1a7f37;border:1px solid #d4e8db;cursor:pointer}' +
      '.cov-slice:hover{background:#e0efe6}.cov-slice.dr{background:#fff4e0;color:#9a6700;border-color:#f0dcae}' +
      '.cov-src .ln[data-line]:hover{filter:brightness(0.97)}' +
      '.cov-src{margin:0;border:1px solid #eef0f3;border-radius:6px;overflow:auto;max-height:60vh}' +
      '.cov-src pre{margin:0;font:11.5px/1.5 ui-monospace,monospace}' +
      '.cov-src .ln{display:block;padding:0 10px;white-space:pre;color:#8a929c;border-left:2px solid transparent}' +
      '.cov-src .ln.on{background:#e6f4ea;color:#1f2328;box-shadow:inset 3px 0 #1a7f37}' +
      '.cov-src .ln.dr{background:#fff4e0;box-shadow:inset 3px 0 #9a6700}' +
      '.cov-src .ln.a-top{border-top:0}' +
      '.cov-src .ln.a-bot{border-bottom:1px solid #9ccfae}' +
      '.cov-src .ln.on.alt{background:#d9eee0}' +
      '.cov-src .ln.dr.a-top,.cov-src .ln.dr.a-bot{border-color:#e8c97a}' +
      '.cov-src .a-hdr{display:block;padding:4px 10px 3px 14px;background:#f3faf5;border-top:1px solid #9ccfae;white-space:normal;line-height:1.3}' +
      '.cov-src .a-hdr.dr{background:#fffaf0;border-top-color:#e8c97a}' +
      '.cov-src .a-lab{display:inline-block;font:10px/1.6 ui-monospace,monospace;color:#1a7f37;background:#fff;border:1px solid #bfe0c9;border-radius:4px;padding:0 6px;margin:0 6px 0 0;cursor:pointer}' +
      '.cov-src .a-lab:hover{background:#e6f4ea}' +
      '.cov-src .a-hdr.dr .a-lab{color:#9a6700;border-color:#f0dcae}' +
      '.cov-src .ln.sc-out{opacity:.32}' +
      '.cov-src .ln.sc{border-left-color:#8b93e6}' +
      '.cov-src .ln.sc-top{border-top:1px solid #8b93e6}' +
      '.cov-src .ln.sc-bot{border-bottom:1px solid #8b93e6}' +
      '.cov-scope-note{font:11px -apple-system,sans-serif;color:#5960b8;background:#f2f3ff;padding:5px 12px;border-bottom:1px solid #e3e5fb;position:sticky;top:0}' +
      /* the heatmap overlay sits inside the pane, not over the whole page */
      '.cov-modal{position:absolute;inset:0;z-index:100;background:rgba(20,22,26,.44);display:flex;align-items:center;justify-content:center;padding:4% 4%}' +
      '.cov-modal-panel{background:#fff;border-radius:10px;box-shadow:0 12px 48px rgba(0,0,0,.28);width:min(940px,100%);max-height:92%;display:flex;flex-direction:column;overflow:hidden}' +
      '.cov-modal-hdr{display:flex;align-items:center;gap:12px;padding:12px 16px;border-bottom:1px solid #eef0f3}' +
      '.cov-modal-file{font:12.5px ui-monospace,monospace;color:#1f2328;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;flex:1}' +
      '.cov-modal-meta{font:11.5px ui-monospace,monospace;color:#79808a;flex:0 0 auto;white-space:nowrap}' +
      '.cov-modal-x{flex:0 0 auto;font-size:22px;line-height:1;color:#9aa0a8;background:none;border:none;cursor:pointer;padding:0 2px}.cov-modal-x:hover{color:#1f2328}' +
      '.cov-modal-body{padding:14px 16px;overflow:auto}.cov-modal .cov-heat{margin:0}' +
      '.cov-modal .cov-src{max-height:none;border:none;border-radius:0;overflow:visible}' +
      '.cov-overall{display:flex;align-items:baseline;gap:10px;margin:0 0 18px;flex-wrap:wrap}.cov-overall b{font-size:26px}.cov-overall span{color:#79808a}' +
      '.cov-scroll{overflow-y:auto;border:1px solid #f2f4f6;border-radius:6px;margin-bottom:4px}' +
      '.cov-scroll-t{max-height:20vh}.cov-scroll-f{max-height:48vh}' +
      '.cov-scroll .cov-row,.cov-scroll .cov-tgt{padding-left:8px;padding-right:8px}' +
      '.cov-secbar{display:flex;flex-wrap:wrap;gap:6px;align-items:center;margin:0 0 16px}' +
      '.cov-secbar-lab{font-size:10.5px;text-transform:uppercase;letter-spacing:.05em;color:#9aa0a8;margin-right:2px}' +
      '.cov-secpill{font:12px -apple-system,sans-serif;padding:4px 11px;border-radius:13px;background:#fff;border:1px solid #e2e7ee;color:#57606a;cursor:pointer}' +
      '.cov-secpill:hover{background:#fafbfc}.cov-secpill.on{background:#1f2328;border-color:#1f2328;color:#fff}' +
      '.cov-secname{font:13px ui-monospace,monospace;font-weight:600;color:#1f2328}' +
      '.cov-secwarn{display:flex;align-items:center;gap:12px;padding:9px 12px;margin:0 0 16px;background:#fff8ec;border:1px solid #f0dcae;border-radius:8px;font-size:12.5px;color:#9a6700}' +
      '.cov-secwarn-txt{flex:1}' +
      '.cov-tabs{display:flex;gap:2px;border-bottom:1px solid #eceef1;margin:0 0 14px}' +
      '.cov-tab{font:12px -apple-system,sans-serif;color:#79808a;background:none;border:none;border-bottom:2px solid transparent;padding:7px 12px;margin-bottom:-1px;cursor:pointer}' +
      '.cov-tab:hover{color:#1f2328}.cov-tab.on{color:#1f2328;font-weight:600;border-bottom-color:#1f2328}' +
      '.cov-files-hdr{display:flex;align-items:baseline;justify-content:space-between;margin:0 0 4px}' +
      '.cov-tree-toggle{font-size:11px;color:#79808a;background:none;border:none;cursor:pointer;padding:0}.cov-tree-toggle:hover{color:#1f2328;text-decoration:underline}' +
      '.cov-dir-det>summary{list-style:none;cursor:pointer;display:flex;align-items:center;justify-content:space-between;padding:6px 8px;border-bottom:1px solid #f2f4f6;font:12.5px ui-monospace,monospace;color:#3a4149}' +
      '.cov-dir-det>summary::-webkit-details-marker{display:none}' +
      '.cov-dir-det>summary::before{content:"▸";display:inline-block;width:12px;color:#a6adb5;font-size:10px}' +
      '.cov-dir-det[open]>summary::before{content:"▾"}' +
      '.cov-dir-det>summary:hover{background:#fafbfc}' +
      '.cov-dir-nm{flex:1;margin-left:2px}.cov-dir-pct{color:#8a929c;font-size:11px}' +
      '.cov-kids{margin-left:13px;border-left:1px solid #f2f4f6}' +
      '.cov-leg{position:relative;display:inline-block;margin-left:2px}' +
      '.cov-leg-trig{font-size:11px;color:#9aa0a8;cursor:default;border-bottom:1px dotted #cbd0d6}' +
      '.cov-leg-pop{display:none;position:absolute;top:22px;right:0;z-index:20;width:320px;padding:10px 13px;background:#fff;border:1px solid #e4e7eb;border-radius:8px;box-shadow:0 6px 24px rgba(0,0,0,.12);color:#57606a}' +
      '.cov-leg:hover .cov-leg-pop{display:block}' +
      '.cov-leg-pop,.cov-leg-pop div,.cov-leg-pop b{font:11.5px/1.6 -apple-system,system-ui,sans-serif}' +
      '.cov-leg-pop b{font-weight:600}' +
      '.cov-leg-pop div{padding:1px 0}.cov-leg-pop div.n{margin-top:6px;padding-top:6px;border-top:1px solid #eef0f3;color:#9aa0a8}' +
      '.cov-leg-pop b.f{color:#1a7f37}.cov-leg-pop b.d{color:#9a6700}.cov-leg-pop b.g{color:#a40e26}.cov-leg-pop b.x{color:#8250df}' +
      '.cov-xc{font:10px ui-monospace,monospace;color:#8250df;background:#f5f0ff;border:1px solid #e6dcff;border-radius:9px;padding:1px 7px;vertical-align:1px}' +
      '.cov-extra .cov-bar>i{background:#8250df}' +
      '.cov-leg-pop .n{color:#9aa0a8;margin-top:5px;padding-top:5px;border-top:1px solid #eef0f3}' +
      '.cov-legend{font:11.5px/1.7 -apple-system,sans-serif;color:#79808a;margin:0 0 20px;padding:9px 12px;background:#fafbfc;border:1px solid #f2f4f6;border-radius:6px}' +
      '.cov-legend .f{color:#1a7f37;font-weight:600}.cov-legend .d{color:#9a6700;font-weight:600}.cov-legend .g{color:#a40e26;font-weight:600}.cov-legend .u{color:#57606a;font-weight:600}' +
      '.cov-legend>div{padding:1px 0}.cov-legend .f,.cov-legend .d,.cov-legend .g,.cov-legend .u{display:inline-block;min-width:82px}' +
      '.cov-legnote{margin-top:6px;padding-top:6px!important;border-top:1px solid #eef0f3;color:#9aa0a8}' +
      '.cov-load{display:flex;align-items:center;gap:11px;color:#79808a;font-size:13px;padding:26px 4px}' +
      '@keyframes cov-spin{to{transform:rotate(360deg)}}' +
      '.cov-load .spinner{display:inline-block;box-sizing:border-box;width:18px;height:18px;border:2px solid #d7dbe0;border-top-color:#57606a;border-radius:50%;animation:cov-spin 0.7s linear infinite;flex:0 0 auto}';
    document.head.appendChild(s);
  }

  // ---- helpers shared by every instance ----
  function escHtml(s) { return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }
  function el(tag, cls, text) { var e = document.createElement(tag); if (cls) e.className = cls; if (text !== undefined && text !== null) e.textContent = text; return e; }
  function codeSkeleton(n) {
    var widths = [46, 78, 62, 88, 40, 70, 54, 82, 34, 66], indents = [0, 14, 14, 28, 14, 0, 14, 28, 14, 0];
    var wrap = el('div', 'code-sk'); var rows = Math.max(3, Math.min(n || 6, 12));
    for (var i = 0; i < rows; i++) { var bar = el('i'); bar.style.width = widths[i % widths.length] + '%'; bar.style.marginLeft = indents[i % indents.length] + 'px'; wrap.appendChild(bar); }
    return wrap;
  }
  function highlight(text, q) { var out = escHtml(text); var re = new RegExp('(' + q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ')', 'ig'); return out.replace(re, '<mark>$1</mark>'); }
  function collectLeaves(items, out) { items.forEach(function (it) { if (it.path) out.push({ path: it.path, title: it.title }); if (it.kids) collectLeaves(it.kids, out); }); return out; }
  function calloutLabel(t) { return { background: 'Background', note: 'Note', tip: 'Tip', warn: 'Warning', warning: 'Warning' }[t] || (t.charAt(0).toUpperCase() + t.slice(1)); }
  function slugify(t) { return t.toLowerCase().replace(/[^\w]+/g, '-').replace(/^-+|-+$/g, ''); }
  function langFor(path) { if (/\.hoon$/.test(path)) return 'hoon'; if (/\.js$/.test(path)) return 'javascript'; if (/\.css$/.test(path)) return 'css'; if (/\.json$/.test(path)) return 'json'; return 'text'; }
  function parseRange(r) { if (!r) return null; var m = r.split('-'); var from = parseInt(m[0], 10); if (isNaN(from)) return null; var to = m.length > 1 ? parseInt(m[1], 10) : from; return { from: from, to: isNaN(to) ? from : to }; }
  function highlightInto(target, path, code) {
    return ensureShiki().then(function (hl) {
      if (!hl) { var p = document.createElement('pre'); p.textContent = code; target.innerHTML = ''; target.appendChild(p); return; }
      try { target.innerHTML = hl.codeToHtml(code, { lang: langFor(path), theme: 'github-light' }); }
      catch (e) { var pre = document.createElement('pre'); pre.textContent = code; target.innerHTML = ''; target.appendChild(pre); }
    });
  }
  function filePins(f) { var seen = {}, out = []; (f.anchors || []).forEach(function (a) { if (a.status === 'gone' || !a.commit) return; var s = a.commit.slice(0, 7); if (!seen[s]) { seen[s] = true; out.push(s); } }); return out; }
  function pinStamp(f) { var pins = filePins(f); var s = el('span', 'cov-head', pins.length ? pins[0] + (pins.length > 1 ? '+' + (pins.length - 1) : '') + ' ' : ''); if (pins.length) s.title = 'coverage pinned at ' + pins.join(', '); return s; }
  function rangeStr(r) { return (r && r.to) ? (r.from + '-' + r.to) : 'all'; }
  function flashEl(e) { var o = e.style.boxShadow; e.style.transition = 'box-shadow .2s'; e.style.boxShadow = '0 0 0 3px #ffd98a'; setTimeout(function () { e.style.boxShadow = o; }, 1400); }
  function delay(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }
  function pct(f) { return f.total ? f.covered / f.total : 0; }
  function rangeText(ranges) { return (ranges || []).map(function (r) { return r[0] === r[1] ? ('' + r[0]) : (r[0] + '–' + r[1]); }).join(', '); }
  function hasScopedDescendant(node) { if (node.cov) return true; return (node.kids || []).some(hasScopedDescendant); }
  function findNavByTitle(nodes, title) { for (var i = 0; i < (nodes || []).length; i++) { if (nodes[i].title === title) return nodes[i]; var k = nodes[i].kids && findNavByTitle(nodes[i].kids, title); if (k) return k; } return null; }
  function findNavParent(nodes, title, parent) { for (var i = 0; i < (nodes || []).length; i++) { if (nodes[i].title === title) return parent || null; var k = nodes[i].kids && findNavParent(nodes[i].kids, title, nodes[i]); if (k) return k; } return null; }
  function findNavByPath(nodes, path) { for (var i = 0; i < (nodes || []).length; i++) { if (nodes[i].path === path) return nodes[i]; var k = nodes[i].kids && findNavByPath(nodes[i].kids, path); if (k) return k; } return null; }
  function statusBadge(status, head, pin) {
    var b = document.createElement('span'); b.className = 'live-fresh';
    var vs = head ? ' · ' + head : '';
    var base = 'margin-left:auto;font:11px/1 ui-monospace,monospace;padding:2px 6px;border-radius:4px;';
    if (status === 'drifted') { b.textContent = '⚠ drifted' + vs; b.style.cssText = base + 'color:#9a6700;background:#fff8c5'; b.title = 'pinned at ' + (pin || '?') + '; the cited lines changed as of HEAD ' + (head || '?'); }
    else if (status === 'gone') { b.textContent = '⚠ gone' + vs; b.style.cssText = base + 'color:#a40e26;background:#fdecea'; b.title = 'the anchored file or range no longer resolves at HEAD ' + (head || '?'); }
    else { b.textContent = '✓ fresh' + vs; b.style.cssText = base + 'color:#1a7f37;background:#dafbe1'; b.title = 'the slice at ' + (pin || 'HEAD') + ' matches HEAD ' + (head || '?'); }
    return b;
  }
  function buildCovTree(files) {
    var root = { dirs: {}, files: [], total: 0, covered: 0 };
    files.forEach(function (f) {
      var segs = (f.file || '').split('/').filter(Boolean); segs.pop();
      var node = root; var counts = !f.extra;
      if (counts) { node.total += f.total; node.covered += f.covered; }
      var here = '';
      segs.forEach(function (s) { here += '/' + s; if (!node.dirs[s]) node.dirs[s] = { dirs: {}, files: [], total: 0, covered: 0, path: here }; node = node.dirs[s]; if (counts) { node.total += f.total; node.covered += f.covered; } });
      node.files.push(f);
    });
    return root;
  }
  function legendTrigger() {
    var w = el('span', 'cov-leg'); w.appendChild(el('span', 'cov-leg-trig', 'ⓘ flags'));
    var pop = el('div', 'cov-leg-pop');
    pop.innerHTML = '<div><b class="f">✓ fresh</b> — the span still matches its pin (mug, ship-side)</div>' +
      '<div><b class="d">⚠ drifted</b> — the span changed since it was pinned</div>' +
      '<div><b class="g">✗ gone</b> — a live block points at a file not under any target</div>' +
      '<div><b class="x">extra credit</b> — a documented file on an ignored path; shown, not counted</div>' +
      '<div class="n">the number after a flag counts the file\'s blocks in that state</div>';
    w.appendChild(pop); return w;
  }
  function covSpinner(body) { var load = el('div', 'cov-load'); load.append(el('span', 'spinner'), el('span', null, 'reading coverage…')); body.appendChild(load); }
  function fillOverall(overall, c, nFiles) {
    overall.innerHTML = '';
    if (c.totalLines) {
      overall.append(el('b', null, Math.round(100 * (c.coveredLines || 0) / c.totalLines) + '%'),
        el('span', null, (c.coveredLines || 0) + ' / ' + c.totalLines + ' lines · ' + nFiles + ' files · '),
        el('span', null, (c.fresh || 0) + ' fresh, ' + (c.drifted || 0) + ' drifted, ' + (c.gone || 0) + ' gone'),
        el('span', null, c.head ? ' · vs HEAD ' + c.head : ''));
    } else overall.append(el('span', null, 'No coverage yet.'));
    overall.appendChild(legendTrigger());
  }

  // ---- one instance ----
  function mount(root, opts) {
    opts = opts || {};
    css();
    var args = opts.args || {};
    var REPO = args.repo || '';
    var BASE = '/grubbery/forge/repo/' + encodeURIComponent(REPO) + '/docs';
    var S = sharedFor(REPO);
    var TAIL = (opts.query && typeof opts.query.page === 'string') ? opts.query.page : '';
    var nav = typeof opts.onNavigate === 'function' ? opts.onNavigate : function () {};
    var box = el('div', 'forge-docs');
    box.innerHTML = MARKUP;
    root.appendChild(box);
    var $ = function (c) { return box.querySelector('.' + c); };
    var NAV = $('d-nav'), DOC = $('d-doc'), OTP = $('d-otp'), WRAP = $('d-search-wrap'), INPUT = $('d-search-input'), RESULTS = $('d-search-results');
    var CONTENT = $('d-content');
    var tree = S.tree || [], leaves = S.leaves || [];
    var results = [], sel = -1, searchTimer = null;
    var CUR_SECTION = '';
    var cov = null, covLoaded = false;
    var otpObserver = null, alive = true;

    // a page change is a MOMENT: the host navigates this pane to the same path
    // with ?page=<tail>, which remounts the viewer at that tail. Same tail → a
    // settled scroll only (the jump arrived on the page already up).
    function go(tail) {
      tail = tail || '';
      if (tail === TAIL) { route(); return; }
      // the same moment with another page: relative to this pane as spelled
      // (under @forge it stays under @forge); the host hands it back via onArgs
      nav('./' + (tail ? '?page=' + encodeURIComponent(tail) : ''), 'file');
    }

    function render(md) {
      ensureMarked().then(function (mk) {
        if (!alive) return;
        DOC.innerHTML = mk ? mk.parse(md) : '<pre></pre>';
        if (!mk) DOC.querySelector('pre').textContent = md;
        upgradeCallouts(); runUpgrade(); upgradeStaticBlocks(); buildOnThisPage();
      });
    }
    function upgradeCallouts() {
      var bqs = DOC.querySelectorAll('blockquote');
      for (var i = 0; i < bqs.length; i++) {
        var bq = bqs[i]; var first = bq.querySelector('p'); if (!first) continue;
        var m = /^\s*\[!(\w+)\]\s*([\s\S]*)$/.exec(first.innerHTML); if (!m) continue;
        var type = m[1].toLowerCase();
        var cbox = document.createElement('div'); cbox.className = 'callout callout-' + type;
        var head = document.createElement('div'); head.className = 'callout-h'; head.innerHTML = m[2].trim() || calloutLabel(type);
        cbox.appendChild(head); first.remove();
        while (bq.firstChild) cbox.appendChild(bq.firstChild);
        bq.replaceWith(cbox);
      }
    }
    function clearOnThisPage() { if (otpObserver) { otpObserver.disconnect(); otpObserver = null; } OTP.innerHTML = ''; OTP.hidden = true; }
    function buildOnThisPage() {
      clearOnThisPage();
      var hs = DOC.querySelectorAll('h2, h3, h4');
      if (hs.length < 2) return;
      OTP.appendChild(el('div', 'otp-h', 'On this page'));
      var byId = {}, used = {};
      for (var i = 0; i < hs.length; i++) {
        var h = hs[i]; var base = slugify(h.textContent) || ('h' + i); var id = base, n = 2;
        while (used[id]) { id = base + '-' + n; n++; }
        used[id] = true; h.id = id;
        var cls = h.tagName === 'H4' ? 'lvl4' : h.tagName === 'H3' ? 'lvl3' : null;
        var a = el('a', cls, h.textContent); a.href = '#';
        (function (el2) { a.onclick = function (e) { e.preventDefault(); el2.scrollIntoView({ behavior: 'smooth', block: 'start' }); }; })(h);
        OTP.appendChild(a); byId[id] = a;
      }
      OTP.hidden = false;
      otpObserver = new IntersectionObserver(function (ents) {
        ents.forEach(function (en) { if (!en.isIntersecting) return; var links = OTP.querySelectorAll('a'); for (var j = 0; j < links.length; j++) links[j].classList.remove('active'); var a = byId[en.target.id]; if (a) a.classList.add('active'); });
      }, { root: CONTENT, rootMargin: '0px 0px -72% 0px', threshold: 0 });
      for (var k = 0; k < hs.length; k++) otpObserver.observe(hs[k]);
    }
    function upgradeStaticBlocks() {
      var blocks = DOC.querySelectorAll('pre > code[class*="language-"]');
      for (var i = 0; i < blocks.length; i++) {
        (function (code) {
          var cls = code.className || ''; if (cls.indexOf('language-live') > -1) return;
          var m = cls.match(/language-([\w-]+)/); if (!m) return;
          var lang = m[1] === 'js' ? 'javascript' : m[1]; if (['hoon', 'javascript', 'css', 'json'].indexOf(lang) < 0) return;
          var text = code.textContent; var pre = code.parentElement;
          ensureShiki().then(function (hl) { if (!hl || !alive) return; try { var tmp = document.createElement('div'); tmp.innerHTML = hl.codeToHtml(text, { lang: lang, theme: 'github-light' }); if (tmp.firstChild) pre.replaceWith(tmp.firstChild); } catch (e) {} });
        })(blocks[i]);
      }
    }

    // ---- coverage data ----
    function loadCoverage() {
      var u = BASE + '/coverage.json';
      if (CUR_SECTION) u += '?section=' + encodeURIComponent(CUR_SECTION);
      return fetch(u, { cache: 'no-store' }).then(function (r) { return r.ok ? r.json() : { files: [] }; })
        .then(function (c) { cov = c || { files: [] }; covLoaded = true; return cov; })
        .catch(function () { cov = { files: [] }; covLoaded = true; return cov; });
    }
    function ensureCovSummary(cb) {
      if (S.covSecByName) { if (cb) cb(); return; }
      fetch(BASE + '/coverage.json', { cache: 'no-store' }).then(function (r) { return r.ok ? r.json() : {}; })
        .then(function (c) {
          var secs = c.sections || []; S.covSecByName = {};
          secs.forEach(function (s) { S.covSecByName[s.name] = s; });
          var anyDrift = secs.some(function (s) { return s.status === 'drifted'; });
          var cvd = 0, tot = 0;
          (tree || []).forEach(function (n) { var s = n.cov && S.covSecByName[n.title]; if (s) { cvd += s.covered || 0; tot += s.total || 0; } });
          S.covOverall = { covered: cvd, total: tot, drifted: anyDrift ? 1 : 0 };
          if (cb) cb();
        }).catch(function () { S.covSecByName = {}; if (cb) cb(); });
    }
    function covFile(file) { if (!cov || !cov.files) return null; for (var i = 0; i < cov.files.length; i++) if (cov.files[i].file === file) return cov.files[i]; return null; }

    // ---- cross-navigation ----
    function scrollToBlock(settled) {
      var ps = S.pendingScroll; if (!ps) return;
      var ws = DOC.querySelectorAll('.live-wrap');
      for (var i = 0; i < ws.length; i++) {
        if (ws[i].dataset.file === ps.file && ws[i].dataset.range === ps.range) { ws[i].classList.add('live-focus'); ws[i].scrollIntoView({ block: 'start' }); if (settled) S.pendingScroll = null; return; }
      }
      if (settled) S.pendingScroll = null;
    }
    function goToDoc(doc, file, rstr) { closeHeatmapModal(); S.pendingScroll = { file: file, range: rstr }; if (TAIL === doc) scrollToBlock(true); else go(doc); }
    function goToCoverage(doc, file, range) {
      S.covFocus = { file: file, from: range ? range.from : 1 };
      var node = doc && findNavByPath(tree, doc);
      var tail = node ? 'coverage/' + encodeURIComponent(node.title) : 'coverage';
      if (TAIL === tail) { if (node) renderSection(node.title); else renderCoverage(); } else go(tail);
    }

    // ---- live blocks ----
    function runUpgrade() {
      var doc = TAIL;
      var resolved = S.blocksCache[doc] || [];
      var blocks = DOC.querySelectorAll('pre > code.language-live');
      var settles = [];
      for (var i = 0; i < blocks.length; i++) {
        (function (code, blk) {
          var parts = code.textContent.trim().split(/\s+/);
          var fileTok = parts[0], at = fileTok.indexOf('@');
          var path = blk ? blk.file : (at >= 0 ? fileTok.slice(0, at) : fileTok);
          var range = blk ? { from: blk.from, to: blk.to } : parseRange(parts[1]);
          var rLabel = range ? (range.to && range.to !== range.from ? range.from + '-' + range.to : '' + range.from) : '';
          var short = blk ? (blk.short || '') : (at >= 0 ? fileTok.slice(at + 1, at + 8) : '');
          var pre = code.parentElement;
          var host = document.createElement('div'); host.className = 'live-wrap'; host.dataset.file = path; host.dataset.range = rangeStr(range);
          var head = document.createElement('div'); head.className = 'live-head'; head.style.display = 'flex'; head.style.alignItems = 'center';
          var label = document.createElement('span'); label.textContent = path + (rLabel ? '  ' + rLabel : ''); head.appendChild(label);
          if (short) { var sc = document.createElement('span'); sc.textContent = short; sc.title = (blk && blk.commit) ? blk.commit : short; sc.style.cssText = 'margin-left:8px;color:#8b949e;font:11px/1 ui-monospace,monospace'; head.appendChild(sc); }
          var covLink = document.createElement('span'); covLink.textContent = ' ▤'; covLink.title = 'show this span in Coverage'; covLink.style.cssText = 'cursor:pointer;color:#b0b6bd;margin-left:6px;font-size:11px';
          covLink.onmouseenter = function () { covLink.style.color = '#57606a'; }; covLink.onmouseleave = function () { covLink.style.color = '#b0b6bd'; };
          (function (dc, p, r) { covLink.onclick = function () { goToCoverage(dc, p, r); }; })(doc, path, range);
          head.appendChild(covLink);
          var body = document.createElement('div'); body.className = 'live-body';
          host.appendChild(head); host.appendChild(body); pre.replaceWith(host);
          if (blk && blk.lines) { settles.push(highlightInto(body, path, blk.lines.join('\n'))); head.appendChild(statusBadge(blk.status, blk.head, short)); }
          else { body.textContent = 'could not load ' + path; head.appendChild(statusBadge('gone', blk ? blk.head : '', short)); }
        })(blocks[i], resolved[i]);
      }
      scrollToBlock(false);
      Promise.all(settles).then(function () { requestAnimationFrame(function () { if (alive) scrollToBlock(true); }); });
    }

    // ---- pages ----
    function markActive(path) {
      var links = NAV.querySelectorAll('a');
      for (var i = 0; i < links.length; i++) {
        var on = links[i].dataset.path === path; links[i].classList.toggle('active', on);
        if (on) { var sec = links[i].closest('.sec'); while (sec) { sec.classList.remove('collapsed'); sec = sec.parentElement.closest('.sec'); } }
      }
    }
    function showLoading() {
      clearOnThisPage();
      DOC.innerHTML = '<div class="doc-skeleton"><div class="sk sk-title"></div><div class="sk"></div><div class="sk"></div><div class="sk sk-short"></div><div class="sk-gap"></div><div class="sk sk-sub"></div><div class="sk"></div><div class="sk"></div><div class="sk"></div><div class="sk sk-short"></div></div>';
    }
    function openDoc(path) {
      if (!path) return;
      if (TAIL !== path) { go(path); return; }
      markActive(path);
      var sec = findNavByPath(tree, path); CUR_SECTION = (sec && sec.cov) ? sec.title : ''; covLoaded = false;
      if (S.textCache[path] != null) { render(S.textCache[path]); addDocTabs(path); return; }
      showLoading();
      fetch(BASE + '/page?path=' + encodeURIComponent(path)).then(function (r) { return r.ok ? r.json() : Promise.reject(r.status); })
        .then(function (obj) { if (!alive) return; S.textCache[path] = obj.markdown || ''; S.blocksCache[path] = obj.blocks || []; render(S.textCache[path]); addDocTabs(path); })
        .catch(function () { if (alive) DOC.innerHTML = '<p class="d-empty">Could not load this doc.</p>'; });
    }
    function addDocTabs(path) { var node = findNavByPath(tree, path); if (!node || !node.cov) return; coverageStyles(); DOC.insertBefore(nodeTabBar(node, 'text'), DOC.firstChild); }

    // ---- sidebar ----
    function docLink(it) { var a = document.createElement('a'); a.textContent = it.title; a.href = '#'; a.dataset.path = it.path; a.onclick = function (e) { e.preventDefault(); openDoc(it.path); }; return a; }
    function covPct(title) {
      var s = S.covSecByName && S.covSecByName[title]; if (!s) return null;
      var drift = s.status === 'drifted'; var p = s.total ? Math.round(100 * s.covered / s.total) : 0;
      var span = el('span', 'nav-cov-pct ' + (drift ? 'd' : 'f'), p + '%'); span.title = 'open ' + title + ' coverage';
      (function (nm) { span.onclick = function (e) { e.stopPropagation(); go('coverage/' + encodeURIComponent(nm)); }; })(title);
      return span;
    }
    function renderTree(items, container) {
      items.forEach(function (it) {
        if (it.path) {
          var li = document.createElement('li'); li.appendChild(docLink(it));
          var ppct = it.cov && covPct(it.title);
          if (ppct) { li.style.display = 'flex'; li.style.alignItems = 'center'; li.firstChild.style.flex = '1'; li.firstChild.style.overflow = 'hidden'; li.appendChild(ppct); }
          container.appendChild(li);
        } else {
          var sec = document.createElement('li'); sec.className = 'sec';
          var head = document.createElement('div'); head.className = 'sec-head';
          var lbl = document.createElement('span'); lbl.textContent = it.title; lbl.style.flex = '1'; lbl.style.overflow = 'hidden'; lbl.style.textOverflow = 'ellipsis';
          head.appendChild(lbl); head.onclick = function () { sec.classList.toggle('collapsed'); };
          var spct = it.cov && covPct(it.title); if (spct) head.appendChild(spct);
          var ul = document.createElement('ul'); sec.appendChild(head); sec.appendChild(ul);
          renderTree(it.kids || [], ul); container.appendChild(sec);
        }
      });
    }
    function showNav() {
      if (!alive) return;
      NAV.innerHTML = '';
      var idx = document.createElement('a'); idx.textContent = '‹ Handbook'; idx.href = '#'; idx.style.cssText = 'display:block;margin-bottom:10px;color:#79808a;font-size:12px';
      idx.onclick = function (e) { e.preventDefault(); go((leaves[0] && leaves[0].path) || ''); };
      NAV.appendChild(idx);
      var covRow = el('div', 'cov-toggle');
      var lnk = el('a', 'cov-toplink', 'Coverage'); lnk.href = '#'; lnk.onclick = function (e) { e.preventDefault(); go('coverage'); };
      covRow.appendChild(lnk);
      if (S.covOverall && S.covOverall.total) {
        var op = Math.round(100 * S.covOverall.covered / S.covOverall.total);
        var ospan = el('span', 'nav-cov-pct ' + (S.covOverall.drifted > 0 ? 'd' : 'f'), op + '%'); ospan.title = 'whole-collection coverage'; ospan.onclick = function () { go('coverage'); };
        covRow.appendChild(ospan);
      }
      NAV.appendChild(covRow);
      renderTree(tree, NAV);
      if (TAIL) markActive(TAIL);
      if (!S.covSecByName) ensureCovSummary(showNav);
    }

    // ---- search ----
    function hideResults() { RESULTS.classList.add('hidden'); }
    function showResults() { if (results.length || INPUT.value.trim()) RESULTS.classList.remove('hidden'); }
    function paintSel() { var items = RESULTS.querySelectorAll('.result'); for (var i = 0; i < items.length; i++) items[i].classList.toggle('sel', i === sel); if (sel >= 0 && items[sel]) items[sel].scrollIntoView({ block: 'nearest' }); }
    function choose(i) { var h = results[i]; if (!h) return; hideResults(); INPUT.blur(); openDoc(h.path); }
    function renderResults(q) {
      RESULTS.innerHTML = '';
      if (!results.length) { var none = document.createElement('li'); none.className = 'no-hits'; none.textContent = 'No matches'; RESULTS.appendChild(none); showResults(); return; }
      results.forEach(function (h, i) {
        var li = document.createElement('li'); li.className = 'result' + (i === sel ? ' sel' : '');
        li.onmouseenter = function () { sel = i; paintSel(); }; li.onclick = function () { choose(i); };
        var t = document.createElement('div'); t.className = 'r-title'; t.textContent = h.title; li.appendChild(t);
        if (h.snippet) { var s = document.createElement('div'); s.className = 'r-snip'; s.innerHTML = highlight(h.snippet, q); li.appendChild(s); }
        RESULTS.appendChild(li);
      });
      showResults();
    }
    function runSearch(q) {
      fetch(BASE + '/search?q=' + encodeURIComponent(q)).then(function (r) { return r.json(); })
        .then(function (hits) { if (!alive) return; results = Array.isArray(hits) ? hits : []; sel = results.length ? 0 : -1; renderResults(q); }).catch(function () {});
    }
    function onInput() { var q = INPUT.value.trim(); clearTimeout(searchTimer); if (!q) { results = []; sel = -1; RESULTS.innerHTML = ''; hideResults(); return; } searchTimer = setTimeout(function () { runSearch(q); }, 150); }

    // ---- coverage views ----
    var covTreeState = {};
    function loadCovTreeState() { try { covTreeState = JSON.parse(localStorage.getItem('docs-cov-tree')) || {}; } catch (e) { covTreeState = {}; } }
    function saveCovTreeState() { try { localStorage.setItem('docs-cov-tree', JSON.stringify(covTreeState)); } catch (e) {} }
    function updateCovToggle() { var tog = box.querySelector('.cov-tree-toggle'); var cbox = box.querySelector('.cov-tree'); if (tog && cbox) tog.textContent = cbox.querySelector('.cov-dir-det[open]') ? 'collapse all' : 'expand all'; }
    function renderCovNode(parent, node, here) {
      here = here || '';
      Object.keys(node.dirs).sort().forEach(function (name) {
        var d = node.dirs[name]; var dirPath = here + name + '/';
        var det = document.createElement('details'); det.className = 'cov-dir-det'; det.open = covTreeState[dirPath] === true;
        det.addEventListener('toggle', function () { covTreeState[dirPath] = det.open; saveCovTreeState(); updateCovToggle(); });
        var sum = document.createElement('summary'); sum.className = 'cov-dir';
        var p = d.total ? Math.round(100 * d.covered / d.total) : 0;
        sum.append(el('span', 'cov-dir-nm', name + '/')); sum.append(el('span', 'cov-dir-pct', p + '%  ' + d.covered + '/' + d.total));
        det.appendChild(sum);
        var kids = el('div', 'cov-kids'); renderCovNode(kids, d, dirPath); det.appendChild(kids); parent.appendChild(det);
      });
      node.files.slice().sort(function (a, b) { return (a.file || '').localeCompare(b.file || ''); }).forEach(function (f) { parent.appendChild(fileRow(f, f.file.split('/').pop())); });
    }
    function renderHeatmap(f, focusLine) {
      var wrap = el('div', 'cov-heat');
      var coveredSet = {}, driftSet = {}, lineAnchors = {};
      (f.ranges || []).forEach(function (r) { for (var n = r[0]; n <= r[1]; n++) coveredSet[n] = true; });
      var live = (f.anchors || []).filter(function (a) { return a.status !== 'gone'; });
      live.forEach(function (a, idx) { a._idx = idx; a._hi = a.to === 0 ? f.total : a.to; for (var n = a.from; n <= a._hi; n++) { if (a.status === 'drifted') driftSet[n] = true; (lineAnchors[n] = lineAnchors[n] || []).push(a); } });
      function ownerOf(n) { var as = lineAnchors[n] || []; var best = null; as.forEach(function (a) { if (!best || (a._hi - a.from) < (best._hi - best.from)) best = a; }); return best; }
      function jump(an) { var rs = an.to === 0 ? 'all' : (an.from + '-' + an.to); goToDoc(an.doc, f.file, rs); }
      var slices = el('div', 'cov-slices'); slices.appendChild(el('span', 'cov-slices-lab', 'Referenced by'));
      (f.anchors || []).forEach(function (a) {
        if (a.status === 'gone') return; var hi = a.to === 0 ? f.total : a.to;
        var chip = el('span', 'cov-slice' + (a.status === 'drifted' ? ' dr' : ''), 'lines ' + a.from + '–' + hi + ' · ' + a.doc); chip.title = 'go to this block in ' + a.doc;
        (function (an) { var rs = an.to === 0 ? 'all' : (an.from + '-' + an.to); chip.onclick = function () { goToDoc(an.doc, f.file, rs); }; })(a);
        slices.appendChild(chip);
      });
      wrap.appendChild(slices);
      var scopeSet = {}; (f.scope || []).forEach(function (r) { for (var n = r[0]; n <= r[1]; n++) scopeSet[n] = true; });
      var src = el('div', 'cov-src'); src.appendChild(codeSkeleton(10)); wrap.appendChild(src);
      var pins = filePins(f);
      var at = pins.length ? (f.anchors || []).filter(function (a) { return a.commit && a.commit.slice(0, 7) === pins[0]; })[0].commit : '';
      fetch(BASE + '/slice?file=' + encodeURIComponent(f.file) + (at ? '&commit=' + encodeURIComponent(at) : ''), { cache: 'no-store' })
        .then(function (r) { return r.ok ? r.text() : ''; })
        .then(function (text) {
          if (!alive) return;
          src.textContent = '';
          var nLines = text.split('\n').length; var scopeCount = Object.keys(scopeSet).length;
          var partial = (f.scope && f.scope.length) && scopeCount > 0 && scopeCount < nLines;
          if (partial) src.appendChild(el('div', 'cov-scope-note', '◈ outlined lines are this section’s scope'));
          var pre = document.createElement('pre');
          text.split('\n').forEach(function (line, i) {
            var n = i + 1; var cls = 'ln' + (driftSet[n] ? ' dr' : coveredSet[n] ? ' on' : '');
            if (partial) { if (scopeSet[n]) { cls += ' sc'; if (!scopeSet[n - 1]) cls += ' sc-top'; if (!scopeSet[n + 1]) cls += ' sc-bot'; } else cls += ' sc-out'; }
            var a = ownerOf(n);
            var starts = (lineAnchors[n] || []).filter(function (x) { return x.from === n; }); var ends = (lineAnchors[n] || []).filter(function (x) { return x._hi === n; });
            if (starts.length) cls += ' a-top'; if (ends.length) cls += ' a-bot'; if (a && (a._idx % 2)) cls += ' alt';
            var d = el('span', cls, (n + '  ').slice(0, 4) + '  ' + line); d.dataset.line = n;
            if (a) { d.style.cursor = 'pointer'; d.title = 'covered by ' + a.doc + ' (' + a.from + '–' + a._hi + ') — click to open'; (function (an) { d.onclick = function () { jump(an); }; })(a); }
            if (starts.length) {
              var hdr = el('span', 'a-hdr' + (a && a.status === 'drifted' ? ' dr' : ''));
              starts.forEach(function (an) { var lab = el('span', 'a-lab', an.doc + ' · ' + an.from + '–' + an._hi); lab.title = 'open this block in ' + an.doc; (function (x) { lab.onclick = function (e) { e.stopPropagation(); jump(x); }; })(an); hdr.appendChild(lab); });
              hdr.appendChild(document.createTextNode('\n')); pre.appendChild(hdr);
            }
            d.appendChild(document.createTextNode('\n')); pre.appendChild(d);
          });
          src.appendChild(pre);
          if (focusLine) { var ln = pre.querySelector('.ln[data-line="' + focusLine + '"]'); if (ln) { ln.scrollIntoView({ block: 'center' }); flashEl(ln); } }
        }).catch(function () { src.textContent = 'could not load mirrored source'; });
      return wrap;
    }
    var covModalEsc = null;
    function closeHeatmapModal() { var ov = box.querySelector('.cov-modal'); if (ov) ov.remove(); if (covModalEsc) { box.removeEventListener('keydown', covModalEsc); covModalEsc = null; } }
    function showHeatmapModal(f, focusLine) {
      closeHeatmapModal();
      var ov = el('div', 'cov-modal'); var panel = el('div', 'cov-modal-panel'); var hdr = el('div', 'cov-modal-hdr');
      var title = el('div', 'cov-modal-file'); title.title = f.file; title.appendChild(pinStamp(f)); title.appendChild(document.createTextNode(f.file));
      var meta = el('span', 'cov-modal-meta', (f.total ? Math.round(100 * pct(f)) + '%' : '—') + ' · ' + f.covered + '/' + f.total + ' lines' + (f.extra ? ' · extra credit' : ''));
      var close = el('button', 'cov-modal-x', '×'); close.title = 'close (Esc)'; close.onclick = closeHeatmapModal;
      hdr.append(title, meta, close);
      var body = el('div', 'cov-modal-body'); body.appendChild(renderHeatmap(f, focusLine));
      panel.append(hdr, body); ov.appendChild(panel);
      ov.onclick = function (e) { if (e.target === ov) closeHeatmapModal(); };
      covModalEsc = function (e) { if (e.key === 'Escape') closeHeatmapModal(); };
      box.addEventListener('keydown', covModalEsc);
      box.appendChild(ov);
    }
    function fileRow(f, label, showScope) {
      var gap = !f.covered && !f.extra;
      var row = el('div', 'cov-row' + (gap ? ' cov-gap' : '') + (f.extra ? ' cov-extra' : '')); row.dataset.file = f.file;
      var nm = el('div', 'cov-file'); nm.title = f.file; nm.appendChild(pinStamp(f)); nm.appendChild(document.createTextNode(label || f.file));
      if (showScope && f.scope && f.scope.length) { var rt = el('span', 'cov-file-rng', ' ' + rangeText(f.scope)); rt.title = 'in scope: lines ' + rangeText(f.scope); nm.appendChild(rt); }
      if (f.extra) { var xc = el('span', 'cov-xc', 'extra credit'); xc.title = 'documented but excluded from the count (ignored path)'; nm.append(document.createTextNode(' ')); nm.append(xc); }
      row.append(nm);
      var bar = el('div', 'cov-bar'); var fill = document.createElement('i'); fill.style.width = Math.round(100 * pct(f)) + '%'; if (gap) fill.style.background = '#d0555f'; bar.appendChild(fill); row.appendChild(bar);
      row.append(el('div', 'cov-pct', (f.total ? Math.round(100 * pct(f)) + '%' : '—') + '  ' + f.covered + '/' + f.total));
      var flags = el('div', 'cov-flags');
      function flag(cls, glyph, n, word) { var e = el('span', cls, glyph + n); e.title = n + ' live block' + (n > 1 ? 's' : '') + ' ' + word; return e; }
      if (f.fresh) flags.appendChild(flag('f', '✓', f.fresh, 'covering this file, fresh'));
      if (f.drifted) flags.appendChild(flag('d', '⚠', f.drifted, 'drifted (the code changed since pinned)'));
      if (f.gone) flags.appendChild(flag('g', '✗', f.gone, 'pointing at a span that is gone'));
      if (gap) { var u = el('span', 'u', 'no docs'); u.title = 'no live block covers this file'; flags.appendChild(u); }
      row.appendChild(flags);
      row.appendChild(el('span', 'cov-act', f.anchors && f.anchors.length ? '⤢' : ''));
      row.onclick = function () { if (!(f.anchors && f.anchors.length)) return; showHeatmapModal(f); };
      return row;
    }
    function nodeTabBar(node, active) {
      var bar = el('div', 'cov-tabs');
      if (node.path) { var t = el('button', 'cov-tab' + (active === 'text' ? ' on' : ''), 'Text'); (function (p) { t.onclick = function () { if (active !== 'text') go(p); }; })(node.path); bar.appendChild(t); }
      var c = el('button', 'cov-tab' + (active === 'coverage' ? ' on' : ''), 'Coverage');
      (function (nm) { c.onclick = function () { if (active !== 'coverage') go('coverage/' + encodeURIComponent(nm)); }; })(node.title);
      bar.appendChild(c); return bar;
    }
    function renderCovSections(nodes, container, depth, byName) {
      (nodes || []).forEach(function (node) {
        if (!hasScopedDescendant(node)) return;
        if (node.cov) container.appendChild(covSectionRow(node.title, byName[node.title], depth));
        else if (!node.path) { var h = el('div', 'cov-secgroup', node.title); h.style.marginLeft = (depth * 18) + 'px'; container.appendChild(h); }
        renderCovSections(node.kids, container, depth + 1, byName);
      });
    }
    function covSectionRow(name, s, depth) {
      s = s || { covered: 0, total: 0, status: 'fresh' };
      var p = s.total ? Math.round(100 * s.covered / s.total) : 0; var drift = s.status === 'drifted';
      var row = el('a', 'cov-secrow' + (drift ? ' dr' : '')); row.style.marginLeft = (depth * 18) + 'px'; row.href = '#';
      (function (nm) { row.onclick = function (e) { e.preventDefault(); go('coverage/' + encodeURIComponent(nm)); }; })(name);
      var main = el('div', 'cov-secrow-main'); main.appendChild(el('div', 'cov-secrow-name', name)); main.appendChild(el('div', 'cov-secrow-sub', s.covered + ' / ' + s.total + ' lines' + (drift ? '  ·  ⟳ drifted' : '')));
      var bar = el('div', 'cov-bar'); var fill = document.createElement('i'); fill.style.width = p + '%'; if (drift) fill.style.background = '#9a6700'; bar.appendChild(fill);
      row.append(main, el('div', 'cov-secrow-pct', p + '%'), bar, el('span', 'cov-secrow-go', '›'));
      return row;
    }
    function renderCoverage() {
      CUR_SECTION = ''; markActive('coverage'); DOC.innerHTML = ''; clearOnThisPage(); coverageStyles();
      var croot = el('div', 'cov');
      croot.appendChild(el('h1', null, 'Coverage'));
      croot.appendChild(el('p', 'sub', 'Each documented section and how much of the code it covers — measured against the repo at HEAD, each block at its pinned commit.'));
      var tgt = el('div', 'cov-target'); tgt.appendChild(el('span', 'cov-target-lab', 'Source')); tgt.appendChild(el('span', 'cov-target-path', REPO || '(none)')); croot.appendChild(tgt);
      var body = el('div', null); croot.appendChild(body); DOC.appendChild(croot);
      covSpinner(body);
      Promise.all([loadCoverage(), delay(300)]).then(function (r) {
        if (!alive) return;
        var c = r[0] || {}; body.textContent = '';
        var secs = c.sections || [];
        if (!secs.length) { body.appendChild(el('div', 'cov-secsub', 'No sections declare coverage yet. Give a nav section a "scope" in the target’s man/docs/docs.json to measure it.')); return; }
        var byName = {}; secs.forEach(function (s) { byName[s.name] = s; });
        var list = el('div', 'cov-seclist'); renderCovSections(tree, list, 0, byName); body.appendChild(list);
      });
    }
    function renderSection(name) {
      CUR_SECTION = name; DOC.innerHTML = ''; clearOnThisPage(); coverageStyles();
      var node = findNavByTitle(tree, name);
      markActive(node && node.path ? node.path : null);
      var grouping = !!(node && (node.kids || []).some(hasScopedDescendant));
      var croot = el('div', 'cov');
      var parent = node && findNavParent(tree, name);
      var up = el('a', 'cov-back'); up.href = '#';
      if (parent && parent.cov) { up.textContent = '‹ ' + parent.title; (function (pt) { up.onclick = function (e) { e.preventDefault(); go('coverage/' + encodeURIComponent(pt)); }; })(parent.title); }
      else { up.textContent = '‹ Coverage'; up.onclick = function (e) { e.preventDefault(); go('coverage'); }; }
      croot.appendChild(up);
      if (node && node.cov) croot.appendChild(nodeTabBar(node, 'coverage'));
      croot.appendChild(el('h1', null, name));
      croot.appendChild(el('p', 'sub', grouping ? 'Coverage across the sections this groups — each documenting its own code.' : 'Coverage of the code this section documents — its scope, and how much of it a live block embeds.'));
      var overall = el('div', 'cov-overall'); croot.appendChild(overall);
      var body = el('div', null); croot.appendChild(body); DOC.appendChild(croot);
      covSpinner(body);
      Promise.all([loadCoverage(), delay(300)]).then(function (r) {
        if (!alive) return;
        var c = r[0] || { files: [] }; body.textContent = '';
        var files = (c.files || []).slice().sort(function (a, b) { return pct(b) - pct(a); });
        fillOverall(overall, c, files.length);
        if (grouping) {
          ensureCovSummary(function () { if (!alive) return; var byName = S.covSecByName || {}; body.appendChild(el('div', 'cov-secsub', 'Sections')); var list = el('div', 'cov-seclist'); renderCovSections(node.kids, list, 0, byName); body.appendChild(list); });
          S.covFocus = null; return;
        }
        if (c.section && c.section.status === 'drifted') { var warn = el('div', 'cov-secwarn'); warn.appendChild(el('span', 'cov-secwarn-txt', '⟳ ' + name + ' changed since its blocks were pinned — worth a re-audit; re-pin in the page source when the prose still holds')); body.appendChild(warn); }
        var hdr = el('div', 'cov-files-hdr'); hdr.append(el('span', 'cov-secsub', 'Scope — ' + files.length + ' file' + (files.length === 1 ? '' : 's'))); body.appendChild(hdr);
        var fscroll = el('div', 'cov-scroll cov-scroll-f');
        if (!files.length) fscroll.appendChild(el('div', 'cov-secsub', 'This section declares no coverage scope.'));
        files.forEach(function (f) { fscroll.appendChild(fileRow(f, f.file, true)); });
        body.appendChild(fscroll);
        if (S.covFocus) { var ff = files.filter(function (x) { return x.file === S.covFocus.file; })[0]; var fline = S.covFocus.from; S.covFocus = null; if (ff) showHeatmapModal(ff, fline); }
      });
    }

    // the repo's docs chat is a pane of its own in the repo layout (beside
    // this one, folded by default), not a column in here

    // ---- boot ----
    var sb = $('d-sb-collapse'), sv = $('d-docs');
    if (sb && sv) sb.onclick = function () { if (sv.collapse) sv.collapse(); else sv.setAttribute('collapsed', ''); };
    function loadNav() {
      if (S.tree) { tree = S.tree; leaves = S.leaves; showNav(); return Promise.resolve(); }
      return fetch(BASE + '/nav.json').then(function (r) { return r.json(); })
        .then(function (list) { tree = Array.isArray(list) ? list : []; }).catch(function () { tree = []; })
        .then(function () { leaves = collectLeaves(tree, []); S.tree = tree; S.leaves = leaves; showNav(); });
    }
    function route() {
      if (TAIL === 'coverage') renderCoverage();
      else if (TAIL.indexOf('coverage/') === 0) renderSection(decodeURIComponent(TAIL.slice(9)));
      else if (TAIL) openDoc(TAIL);
      else if (leaves[0]) go(leaves[0].path);
    }
    INPUT.addEventListener('input', onInput);
    INPUT.addEventListener('focus', function () { if (INPUT.value.trim()) showResults(); });
    INPUT.addEventListener('keydown', function (e) {
      if (e.key === 'ArrowDown') { e.preventDefault(); if (results.length) { sel = (sel + 1) % results.length; paintSel(); } }
      else if (e.key === 'ArrowUp') { e.preventDefault(); if (results.length) { sel = (sel - 1 + results.length) % results.length; paintSel(); } }
      else if (e.key === 'Enter') { e.preventDefault(); if (sel >= 0) choose(sel); }
      else if (e.key === 'Escape') { e.preventDefault(); INPUT.value = ''; results = []; sel = -1; hideResults(); INPUT.blur(); }
    });
    box.addEventListener('keydown', function (e) {
      if ((e.metaKey || e.ctrlKey) && (e.key === 'k' || e.key === 'K')) { e.preventDefault(); e.stopPropagation(); INPUT.focus(); INPUT.select(); }
    });
    box.addEventListener('click', function (e) { if (!WRAP.contains(e.target)) hideResults(); });
    box.tabIndex = -1;
    loadCovTreeState();
    loadNav().then(function () { if (alive) route(); });

    return {
      destroy: function () {
        alive = false; clearOnThisPage(); clearTimeout(searchTimer);
        box.remove();
      },
      // the moment's ?args changed under us (a page link, back, forward):
      // turn the page in place, nav and caches kept, no remount
      onArgs: function (q) {
        TAIL = (q && typeof q.page === 'string') ? q.page : '';
        if (alive) route();
      },
      // the handbook was rebuilt (docs-nav.json moved): drop the caches and
      // redraw the nav and the current page from the ship
      onUpdate: function () {
        S.tree = null; S.leaves = []; S.textCache = {}; S.blocksCache = {}; S.covSecByName = null; S.covOverall = null;
        loadNav().then(function () { if (alive) route(); });
      }
    };
  }

  window.Viewers['forge-docs'] = { label: 'docs', mount: mount };
})();
