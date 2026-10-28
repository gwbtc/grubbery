// <VimEditor> — a vim-keymapped text surface, mountable into any element. The
// one place CodeMirror 5 and vim.min.js are actually touched; every other
// viewer that wants vim-editing calls mount() and never sees either.
//
// USAGE:
//   var ve = VimEditor.mount(el, { value: text, mime: 'text/javascript' });
//   await ve.ready
//   ve.getValue() / ve.setValue(text) / ve.focus() / ve.refresh() / ve.destroy()
//
// cm.js (CodeMirror + vim.min.js + language modes, welded into one file by
// explorer.hoon) is already vendored under /lib/cm and served from the ship —
// no CDN. It's loaded lazily, once, on first mount(); callers that never show
// a text pane never pay for it.
//
// vim-editor.json (see /lib/ui/vim-editor-config.json) carries your own key
// mappings and vim options — edit that file, no code change needed. Shape:
//   { "mappings": [{"lhs":"jj","rhs":"<Esc>","mode":"insert"}, ...],
//     "options":  {"ignorecase": true} }
// Applied once, globally, through CodeMirror.Vim's own map/setOption API —
// this is not a .vimrc parser, so Vimscript (functions, autocmds, plugins)
// isn't in scope, just mappings and options.
(function () {
  'use strict';

  var CM_JS = '/grubbery/ball/apps/explorer.explorer/cm.js';
  var CM_CSS = '/grubbery/ball/apps/explorer.explorer/cm.css';
  var CONFIG_URL = '/grubbery/ball/apps/explorer.explorer/vim-editor.json';

  var cssLoaded = false;
  function loadCSS(href) {
    if (cssLoaded) return;
    cssLoaded = true;
    var l = document.createElement('link');
    l.rel = 'stylesheet'; l.href = href;
    document.head.appendChild(l);
  }
  function loadScript(src) {
    return new Promise(function (res, rej) {
      var sc = document.createElement('script');
      sc.src = src; sc.onload = res; sc.onerror = rej;
      document.head.appendChild(sc);
    });
  }

  function applyConfig() {
    var Vim = CodeMirror.Vim;
    return fetch(CONFIG_URL).then(function (r) { return r.ok ? r.json() : null; })
      .catch(function () { return null; })
      .then(function (cfg) {
        if (!cfg) return;
        (cfg.mappings || []).forEach(function (m) {
          try { Vim.map(m.lhs, m.rhs, m.mode); } catch (_) {}
        });
        Object.keys(cfg.options || {}).forEach(function (k) {
          try { Vim.setOption(k, cfg.options[k]); } catch (_) {}
        });
      });
  }

  var cmReady = null;
  function loadCM() {
    if (!cmReady) {
      loadCSS(CM_CSS);
      cmReady = loadScript(CM_JS).then(applyConfig);
    }
    return cmReady;
  }

  // the hoon mode (vendored as hoon-mode.js, welded into cm.js) registers
  // itself under 'hoon'; everything else is a stock CodeMirror mode name
  var MODE_FOR_MIME = {
    'text/javascript': 'javascript', 'application/javascript': 'javascript',
    'text/css': 'css', 'text/html': 'htmlmixed', 'application/xhtml+xml': 'htmlmixed',
    'application/json': { name: 'javascript', json: true },
    'text/markdown': 'markdown', 'text/x-markdown': 'markdown',
    'text/x-hoon': 'hoon', 'application/x-hoon': 'hoon',
    'image/svg+xml': 'xml', 'application/xml': 'xml', 'text/xml': 'xml'
  };
  function modeFor(mime) {
    return MODE_FOR_MIME[String(mime || '').split(';')[0].trim()] || null;
  }

  // Held-key repeat for normal-mode motions: neither vim.min.js nor the
  // CodeMirror core special-case keydown.repeat, so in principle holding a
  // key should "just work" via the OS's own auto-repeat — in practice it
  // doesn't reach the vim command dispatch reliably. Rather than chase that
  // upstream, we drive repeat ourselves: on a tracked key's first (non-
  // repeat) keydown, let vim handle it as always; after a short delay, fire
  // the same command again on an interval until keyup (or blur). Native
  // repeat keydowns are swallowed so we're the only thing re-firing.
  var REPEATABLE = { j: 1, k: 1, h: 1, l: 1 };
  var HOLD_DELAY = 350, HOLD_INTERVAL = 35;

  function mount(el, opts) {
    opts = opts || {};
    var handle = { cm: null };
    var held = {};
    function fireMotion(cm, key) {
      try { CodeMirror.Vim.handleKey(cm, key, 'user'); } catch (_) {}
    }
    function stopHold(key) {
      var h = held[key];
      if (!h) return;
      clearTimeout(h.timeout);
      if (h.interval) clearInterval(h.interval);
      delete held[key];
    }
    function stopAllHolds() { Object.keys(held).forEach(stopHold); }
    var ready = loadCM().then(function () {
      var cm = CodeMirror(el, {
        value: opts.value || '',
        mode: opts.mode || modeFor(opts.mime),
        keyMap: opts.vim === false ? 'default' : 'vim',
        lineNumbers: opts.lineNumbers !== false,
        lineWrapping: !!opts.lineWrapping,
        readOnly: !!opts.readOnly,
        indentWithTabs: false,
        indentUnit: 2,
        tabSize: 2,
      });
      handle.cm = cm;
      if (opts.onChange) cm.on('change', function () { opts.onChange(cm.getValue()); });
      if (opts.autofocus) cm.focus();
      cm.on('keydown', function (cm, e) {
        if (!REPEATABLE[e.key]) return;
        var vim = cm.state.vim;
        if (!vim || vim.insertMode) return;   // typing letters should just type
        if (e.repeat) { e.preventDefault(); return; }  // we drive repeats ourselves
        stopHold(e.key);
        held[e.key] = {
          timeout: setTimeout(function () {
            held[e.key].interval = setInterval(function () { fireMotion(cm, e.key); }, HOLD_INTERVAL);
          }, HOLD_DELAY)
        };
      });
      cm.on('keyup', function (cm, e) { if (REPEATABLE[e.key]) stopHold(e.key); });
      cm.on('blur', stopAllHolds);
    });
    return {
      ready: ready,
      getValue: function () { return handle.cm ? handle.cm.getValue() : (opts.value || ''); },
      setValue: function (v) { if (handle.cm) handle.cm.setValue(v); },
      focus: function () { if (handle.cm) handle.cm.focus(); },
      setReadOnly: function (b) { if (handle.cm) handle.cm.setOption('readOnly', !!b); },
      setLineWrapping: function (b) { if (handle.cm) handle.cm.setOption('lineWrapping', !!b); },
      setVim: function (b) { if (handle.cm) handle.cm.setOption('keyMap', b ? 'vim' : 'default'); },
      getCursor: function () { return handle.cm ? handle.cm.getCursor() : null; },
      setCursor: function (c) { if (handle.cm && c) handle.cm.setCursor(c); },
      refresh: function () { if (handle.cm) handle.cm.refresh(); },
      destroy: function () { stopAllHolds(); handle.cm = null; el.innerHTML = ''; }
    };
  }

  window.VimEditor = { mount: mount };
})();
