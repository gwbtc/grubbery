// <VimEditor> — a vim-keymapped text surface, mountable into any element. The
// one place CodeMirror 5 and vim.min.js are actually touched; every other
// viewer that wants vim-editing calls mount() and never sees either.
//
// USAGE:
//   var ve = VimEditor.mount(el, { value: text, mime: 'text/javascript' });
//   await ve.ready
//   ve.getValue() / ve.setValue(text) / ve.focus() / ve.refresh() / ve.destroy()
//
// VimEditor.highlight(el, text, mode) is the same highlighting without an
// editor, for a pane that only shows code, and VimEditor.modeForName(name)
// is the mode a filename implies. One highlighter for reading and editing,
// so a file does not change color when you start editing it.
//
// cm.js (CodeMirror + vim.min.js + language modes, welded into one file by
// explorer.hoon) is already vendored under /lib/cm and served from the ship —
// no CDN. It's loaded lazily, once, on first mount() or highlight(); callers
// that never show a text pane never pay for it.
//
// vim-editor.json (see /lib/ui/vim-editor-config.json) carries the palette,
// your own key mappings and vim options — edit that file, no code change
// needed. Shape:
//   { "theme":    "github-light",
//     "mappings": [{"lhs":"jj","rhs":"<Esc>","mode":"insert"}, ...],
//     "options":  {"ignorecase": true} }
// The theme names a block in cm.css ("github-light", or CodeMirror's own
// "default") and colors reading and editing alike. Mappings and options are
// applied once, globally, through CodeMirror.Vim's own map/setOption API —
// this is not a .vimrc parser, so Vimscript (functions, autocmds, plugins)
// isn't in scope.
(function () {
  'use strict';

  var CM_JS = '/grubbery/ball/apps/shell/ui/explorer/cm.js';
  var CM_CSS = '/grubbery/ball/apps/shell/ui/explorer/cm.css';
  var CONFIG_URL = '/grubbery/ball/apps/shell/ui/explorer/vim-editor.json';

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

  // the palette, for the editor and the read views alike. cm.css carries
  // this one and CodeMirror's own 'default'; a new one is a block in
  // /lib/cm and a line in the cm.css weld.
  var theme = 'github-light';

  function applyConfig() {
    var Vim = CodeMirror.Vim;
    // vim's own: ZZ writes and quits, ZQ quits without writing. Mapped
    // onto the Ex commands the host defines (see opts.ex), before the
    // person's own config so theirs wins.
    try { Vim.map('ZZ', ':x<CR>', 'normal'); Vim.map('ZQ', ':q!<CR>', 'normal'); } catch (_) {}
    return fetch(CONFIG_URL).then(function (r) { return r.ok ? r.json() : null; })
      .catch(function () { return null; })
      .then(function (cfg) {
        if (!cfg) return;
        if (cfg.theme) theme = cfg.theme;
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
  var MODE_FOR_EXT = {
    js: 'javascript', mjs: 'javascript', ts: 'javascript', jsx: 'javascript',
    json: { name: 'javascript', json: true },
    css: 'css', hoon: 'hoon', html: 'htmlmixed', htm: 'htmlmixed',
    xml: 'xml', svg: 'xml', md: 'markdown', markdown: 'markdown'
  };
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
  // the mode for a file's name, which is the signal a reader actually has:
  // a grub needn't carry a mime type, and no mime type spells hoon
  function modeForName(name) {
    var m = /\.([a-z0-9]+)$/i.exec(String(name || ''));
    return m ? (MODE_FOR_EXT[m[1].toLowerCase()] || null) : null;
  }

  // Highlighting without an editor, for every pane that only shows code.
  // CodeMirror tokenizes a line at a time through its public mode API, the
  // same call the editor itself makes, so a file reads identically whether
  // you are editing it or looking at it.
  //
  // The markup is a <pre><code> of one .line span per line, which is the
  // shape a caller's own line numbering and wrapping already expect, under
  // the cm-s-<theme> class that cm.css colors the tokens through.
  //
  // The lines a caller hands us are all the context there is: a mode that
  // asks to look ahead, or for the token around it, gets nothing and
  // tokenizes the line in front of it.
  var NO_ORACLE = { lookAhead: function () { return null; },
                    baseToken: function () { return null; } };
  function tokenize(text, mode) {
    var m = CodeMirror.getMode(CodeMirror.defaults, mode || 'null');
    var state = CodeMirror.startState(m);
    return String(text).split('\n').map(function (line) {
      var out = [], stream = new CodeMirror.StringStream(line, 2, NO_ORACLE);
      if (!line && m.blankLine) m.blankLine(state);
      while (!stream.eol()) {
        var style = m.token(stream, state) || null;
        // a mode that returned without consuming anything would spin here
        if (stream.pos === stream.start) stream.pos++;
        var tok = stream.current();
        stream.start = stream.pos;
        // a run of one style is one element: modes hand back whitespace and
        // punctuation a character at a time, and a span each is a lot of
        // elements for a long file
        var last = out[out.length - 1];
        if (last && last[1] === style) last[0] += tok;
        else out.push([tok, style]);
      }
      return out;
    });
  }
  function highlight(el, text, mode) {
    return loadCM().then(function () {
      var pre = document.createElement('pre');
      var code = document.createElement('code');
      tokenize(text, mode).forEach(function (toks, i) {
        if (i) code.appendChild(document.createTextNode('\n'));
        var line = document.createElement('span');
        line.className = 'line';
        toks.forEach(function (t) {
          // unstyled text needs no element of its own
          if (!t[1]) { line.appendChild(document.createTextNode(t[0])); return; }
          var s = document.createElement('span');
          s.className = 'cm-' + t[1].replace(/ +/g, ' cm-');
          s.textContent = t[0];
          line.appendChild(s);
        });
        code.appendChild(line);
      });
      pre.appendChild(code);
      el.textContent = '';
      el.classList.add('cm-s-' + theme);
      el.appendChild(pre);
      return el;
    });
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

  // Ex commands (:w, :q, :e <path>, ...). defineEx is global to the page,
  // so each name is defined once and dispatched to the editor the command
  // was typed in: opts.ex = { w: fn(args), q: fn, ... } is kept per cm and
  // looked up on the way through. A name with no handler on this editor
  // does nothing.
  var EX = {};                       // name -> [cm, handlers] (weak enough: destroy removes)
  var exDefined = {};
  function defineEx(name, cm, fn) {
    EX[name] = EX[name] || [];
    EX[name].push([cm, fn]);
    if (exDefined[name]) return;
    exDefined[name] = true;
    try {
      CodeMirror.Vim.defineEx(name, name, function (cm2, params) {
        var hit = EX[name].filter(function (p) { return p[0] === cm2; })[0];
        if (hit) hit[1](params.args || [], params);
      });
    } catch (_) {}
  }
  function dropEx(cm) {
    Object.keys(EX).forEach(function (n) { EX[n] = EX[n].filter(function (p) { return p[0] !== cm; }); });
  }

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
        theme: theme,
        keyMap: opts.vim === false ? 'default' : 'vim',
        lineNumbers: opts.lineNumbers !== false,
        lineWrapping: !!opts.lineWrapping,
        readOnly: !!opts.readOnly,
        indentWithTabs: false,
        indentUnit: 2,
        tabSize: 2,
      });
      handle.cm = cm;
      Object.keys(opts.ex || {}).forEach(function (n) { defineEx(n, cm, opts.ex[n]); });
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
      // the element that actually holds the keyboard: a host marking where
      // focus belongs (gmux reads data-focus) has to point at this, not at
      // the wrapper -- focusing the wrapper leaves the keys outside vim
      inputField: function () { return handle.cm ? handle.cm.getInputField() : null; },
      setReadOnly: function (b) { if (handle.cm) handle.cm.setOption('readOnly', !!b); },
      setLineWrapping: function (b) { if (handle.cm) handle.cm.setOption('lineWrapping', !!b); },
      setLineNumbers: function (b) { if (handle.cm) handle.cm.setOption('lineNumbers', !!b); },
      setVim: function (b) { if (handle.cm) handle.cm.setOption('keyMap', b ? 'vim' : 'default'); },
      getCursor: function () { return handle.cm ? handle.cm.getCursor() : null; },
      setCursor: function (c) { if (handle.cm && c) handle.cm.setCursor(c); },
      refresh: function () { if (handle.cm) handle.cm.refresh(); },
      // a line at the bottom of the editor, the way vim says "E37: No write
      // since last change": seen even when the host's chrome is hidden
      notify: function (text) {
        if (!handle.cm) return;
        if (handle.cm.openNotification) { var s = document.createElement('span'); s.textContent = text; handle.cm.openNotification(s, { duration: 4000, bottom: true }); }
      },
      destroy: function () { stopAllHolds(); if (handle.cm) dropEx(handle.cm); handle.cm = null; el.innerHTML = ''; }
    };
  }

  window.VimEditor = {
    mount: mount,
    highlight: highlight,      // code into an element, read-only
    modeForName: modeForName   // the mode a filename implies
  };
})();
