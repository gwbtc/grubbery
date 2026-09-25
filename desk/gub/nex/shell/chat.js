// Docs assistant widget. A floating, sandboxed chatbot bolted onto the docs
// reader. It can ONLY read/search the docs and the root /code nexus — its
// tools are scoped to exactly those two read-only namespaces, server-side.
//
// This file is the UI half: launcher + a draggable/resizable <float-window>,
// conversation state, and the wire protocol. It POSTs the running transcript to
// /apps/grubbery/docs/chat and renders the reply plus a trace of which tools the
// bot used. The backend (the actual model loop) is built separately; until it
// answers, the window degrades to a clear "not wired up yet" notice.
'use strict';

(function () {
  var ENDPOINT = '/apps/grubbery/docs/chat';
  var HISTORY = '/apps/grubbery/docs/history';

  // local mirror of the conversation, for rendering: [{role, content, trace}]
  var history = [];
  var busy = false;
  var currentCtrl = null;   // AbortController for the in-flight turn
  var cfgBack, cfgSys, cfgModel, cfgMax;   // config modal elements

  var SUGGESTIONS = [
    'What is a nexus?',
    'How do weirs scope reads?',
    'Explain the fiber monad',
  ];

  // ---- icons ----
  var I = {
    spark: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3l1.9 5.1L19 10l-5.1 1.9L12 17l-1.9-5.1L5 10l5.1-1.9z"/></svg>',
    min: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 12 15 18 9"/></svg>',
    trash: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>',
    gear: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>',
    send: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/></svg>',
    stop: '<svg viewBox="0 0 24 24" fill="currentColor" stroke="none"><rect x="6" y="6" width="12" height="12" rx="2"/></svg>',
    search: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="7"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>',
    file: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M13 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z"/><polyline points="13 2 13 9 20 9"/></svg>',
    reset: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="1 4 1 10 7 10"/><path d="M3.51 15a9 9 0 1 0 2.13-9.36L1 10"/></svg>',
  };

  // map a tool name → the glyph shown in its trace line
  function stepIcon(tool) {
    if (/search/.test(tool)) return I.search;
    return I.file;
  }

  // ---- element construction ----
  // The assistant lives in a <float-window> (draggable + resizable, geometry
  // persisted). `content` is the chat column; it's built once and moved into a
  // fresh window on reset, so the conversation survives a reset-to-default.
  var fab, win, content, log, input, sendBtn;

  var DEF = { w: 452, h: 620 };             // default window size

  function el(tag, cls, html) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (html != null) e.innerHTML = html;
    return e;
  }

  // default top-left: docked bottom-right, sitting ABOVE the launcher FAB (which
  // is ~68px tall at bottom:22) so the window never covers it. Clamped on-screen.
  function defaultPos() {
    var rightGap = 22, bottomGap = 88;
    return {
      x: Math.max(22, window.innerWidth - DEF.w - rightGap),
      y: Math.max(22, window.innerHeight - DEF.h - bottomGap),
    };
  }

  // build the chat column ONCE — toolbar (config / clear / reset) + log + input.
  function buildContent() {
    var toolbar = el('div', 'da-toolbar');
    var sub = el('div', 'da-sub', 'reads the docs &amp; /code — nothing else');
    var spacer = el('div', 'da-spacer');
    var cfgBtn = el('button', 'da-icon-btn', I.gear);
    cfgBtn.title = 'Configure';
    cfgBtn.addEventListener('click', openConfig);
    var clearBtn = el('button', 'da-icon-btn', I.trash);
    clearBtn.title = 'Clear conversation';
    clearBtn.addEventListener('click', clearChat);
    var resetBtn = el('button', 'da-icon-btn', I.reset);
    resetBtn.title = 'Reset window size & position';
    resetBtn.addEventListener('click', resetWindow);
    toolbar.append(sub, spacer, cfgBtn, clearBtn, resetBtn);

    log = el('div', 'da-log');

    var inputBar = el('div', 'da-input');
    input = el('textarea');
    input.rows = 1;
    input.placeholder = 'Ask about anything in the docs…';
    input.addEventListener('input', autosize);
    input.addEventListener('keydown', onKey);
    sendBtn = el('button', 'da-send', I.send);
    sendBtn.addEventListener('click', function () { if (busy) stop(); else submit(); });
    inputBar.append(input, sendBtn);

    var root = el('div', 'da-win');
    root.append(toolbar, log, inputBar);
    return root;
  }

  // a fresh <float-window> at the DEFAULT geometry, hosting the shared content
  // column. Deliberately NO `persist`: the window never remembers a moved or
  // resized geometry, so every open — and the reset button — starts at the
  // default size and position. The window exists in the DOM only while open.
  function makeWindow() {
    var w = document.createElement('float-window');
    w.setAttribute('title', 'Docs assistant');
    w.setAttribute('icon', '◆');
    var p = defaultPos();
    w.setAttribute('x', p.x + 'px');
    w.setAttribute('y', p.y + 'px');
    w.setAttribute('width', DEF.w);
    w.setAttribute('height', DEF.h);
    w.setAttribute('min-width', 320);
    w.setAttribute('min-height', 320);
    w.appendChild(content);
    // keep the FAB's active state honest when the window is closed/minimized via
    // its own titlebar chrome rather than the launcher.
    w.addEventListener('fw-close', function () { win = null; deactivateFab(); });
    w.addEventListener('fw-minimize', function (e) { if (e.detail && e.detail.minimized) deactivateFab(); });
    w.addEventListener('fw-focus', function () { fab.classList.add('da-active'); });
    return w;
  }
  function deactivateFab() { fab.classList.remove('da-active'); }

  function build() {
    fab = el('button', 'da-fab da-hidden', I.spark + '<span>Ask the docs… &#8984;J</span>');
    fab.title = 'Ask the docs assistant (⌘J)';
    fab.addEventListener('click', togglePanel);

    content = buildContent();
    buildConfig();
    document.body.append(fab, cfgBack);   // the window mounts on first open
    renderLog();
    loadHistory();
    // reveal the launcher once the reader has settled
    setTimeout(function () { fab.classList.remove('da-hidden'); }, 400);
    // cmd-J / ctrl-J toggles the chat open and closed
    document.addEventListener('keydown', function (e) {
      if ((e.metaKey || e.ctrlKey) && (e.key === 'j' || e.key === 'J')) {
        e.preventDefault();
        togglePanel();
      }
    });
  }

  // ---- window open/close ----
  // Each open builds a FRESH window at the default geometry — closing and
  // reopening always returns to the default size and position. The conversation
  // is preserved (the content column moves into each new window, not cleared).
  function isOpen() {
    return !!(win && win.isConnected && !win.hasAttribute('minimized'));
  }
  function togglePanel() {
    if (isOpen()) closePanel();
    else openPanel();
  }
  function openPanel() {
    if (win) win.remove();            // discard any prior window + its geometry
    win = makeWindow();               // fresh, at the default size/position
    document.body.appendChild(win);
    win.raise();
    fab.classList.add('da-active');
    setTimeout(function () { input.focus(); }, 120);
    scrollToEnd();
  }
  function closePanel() {
    if (win) { win.remove(); win = null; }
    fab.classList.remove('da-active');
  }

  // reset-to-default: identical to a fresh open — rebuild at the default
  // geometry, keeping the conversation.
  function resetWindow() { openPanel(); }
  function clearChat() {
    // archive the current conversation server-side, then reset locally
    fetch('/apps/grubbery/docs/clear', { method: 'POST' }).catch(function () {});
    if (currentCtrl) currentCtrl.abort();
    history = [];
    busy = false;
    sendBtn.innerHTML = I.send;
    renderLog();
  }

  // restore the conversation from the namespace-backed history
  function loadHistory() {
    fetch(HISTORY)
      .then(function (r) { return r.ok ? r.json() : []; })
      .then(function (arr) {
        if (!Array.isArray(arr) || !arr.length) return;
        history = arr.map(function (m) {
          return { role: m.role, content: m.content, trace: m.trace || [] };
        });
        renderLog();
        // an unanswered user message = a turn that stalled or is still
        // running — surface the pending state instead of a silent gap.
        if (history[history.length - 1].role === 'user') showTyping();
      })
      .catch(function () { /* no prior history */ });
  }

  // ---- config modal ----
  function buildConfig() {
    cfgBack = el('div', 'da-cfg-back da-hidden');
    cfgBack.addEventListener('click', function (e) {
      if (e.target === cfgBack) cfgBack.classList.add('da-hidden');
    });
    var card = el('div', 'da-cfg');
    card.appendChild(el('div', 'da-cfg-title', 'Chat config'));

    var f1 = el('label', 'da-cfg-field');
    f1.appendChild(el('span', 'da-cfg-label', 'System prompt'));
    cfgSys = el('textarea', 'da-cfg-textarea');
    cfgSys.rows = 7;
    cfgSys.setAttribute('wrap', 'off');
    cfgSys.setAttribute('spellcheck', 'false');
    f1.appendChild(cfgSys);

    var f2 = el('label', 'da-cfg-field');
    f2.appendChild(el('span', 'da-cfg-label', 'Model'));
    cfgModel = el('select', 'da-cfg-input da-cfg-select');
    f2.appendChild(cfgModel);

    var f3 = el('label', 'da-cfg-field');
    f3.appendChild(el('span', 'da-cfg-label', 'Max tokens'));
    cfgMax = el('input', 'da-cfg-input');
    cfgMax.type = 'number';
    cfgMax.min = '1';
    f3.appendChild(cfgMax);

    var foot = el('div', 'da-cfg-foot');
    var cancel = el('button', 'da-cfg-btn', 'Cancel');
    cancel.addEventListener('click', function () { cfgBack.classList.add('da-hidden'); });
    var save = el('button', 'da-cfg-btn da-cfg-save', 'Save');
    save.addEventListener('click', saveConfig);
    foot.append(cancel, save);

    card.append(f1, f2, f3, foot);
    cfgBack.appendChild(card);
  }

  function openConfig() {
    cfgBack.classList.remove('da-hidden');
    // model options come from the anthropic proxy's rate table (the real
    // list the ship meters), then load the agent's current config on top.
    fetch('/grubbery/anthropic/api/usage')
      .then(function (r) { return r.json(); })
      .then(function (u) {
        var models = Object.keys((u && u.rates) || {}).sort();
        cfgModel.innerHTML = '';
        models.forEach(function (mm) {
          var o = document.createElement('option');
          o.value = mm; o.textContent = mm;
          cfgModel.appendChild(o);
        });
      })
      .catch(function () {})
      .then(loadConfigValues);
  }

  function loadConfigValues() {
    fetch('/apps/grubbery/docs/config')
      .then(function (r) { return r.json(); })
      .then(function (d) {
        var c = (d && d.config) || {};
        cfgSys.value = (d && d.system) || '';
        cfgMax.value = c.max_tokens || 1024;
        var model = c.model || 'claude-sonnet-4-6';
        // keep the saved model selectable even if the proxy doesn't list it
        var has = Array.prototype.some.call(cfgModel.options, function (o) { return o.value === model; });
        if (!has) {
          var o = document.createElement('option');
          o.value = model; o.textContent = model;
          cfgModel.appendChild(o);
        }
        cfgModel.value = model;
      })
      .catch(function () {});
  }

  function saveConfig() {
    fetch('/apps/grubbery/docs/config', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        system: cfgSys.value,
        model: cfgModel.value.trim(),
        max_tokens: parseInt(cfgMax.value, 10) || 1024,
      }),
    })
      .then(function () { cfgBack.classList.add('da-hidden'); })
      .catch(function () {});
  }

  // ---- input handling ----
  function autosize() {
    input.style.height = 'auto';
    input.style.height = Math.min(input.scrollHeight, 120) + 'px';
  }
  function onKey(e) {
    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); submit(); }
  }
  function ask(text) { input.value = text; submit(); }

  function submit() {
    var text = input.value.trim();
    if (!text || busy) return;
    history.push({ role: 'user', content: text });
    input.value = '';
    autosize();
    renderLog();
    send(text);
  }

  // ---- server round-trip ----
  // POST just the new message + the conversation id; the sandboxed agent
  // loads history from the namespace, runs the turn, and persists it.
  function send(text) {
    busy = true;
    sendBtn.innerHTML = I.stop;
    sendBtn.title = 'Stop';
    var typing = showTyping();
    // never hang forever: abort the request after a ceiling and recover
    currentCtrl = new AbortController();
    var timer = setTimeout(function () { currentCtrl.abort(); }, 120000);
    fetch(ENDPOINT, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ message: text }),
      signal: currentCtrl.signal,
    })
      .then(function (r) {
        if (r.status === 404) return Promise.reject('nowire');
        if (!r.ok) return r.text().then(function (t) { return Promise.reject(t || ('HTTP ' + r.status)); });
        return r.json();
      })
      .then(function (data) {
        typing.remove();
        var reply = (data && data.reply) || '(no reply)';
        history.push({ role: 'assistant', content: reply, trace: (data && data.trace) || [] });
        renderLog();
      })
      .catch(function (err) {
        typing.remove();
        var msg = err === 'nowire'
          ? 'The assistant backend isn’t wired up yet — this is the UI.'
          : (err && err.name === 'AbortError')
            ? 'Stopped.'
            : ('Something went wrong: ' + err);
        showError(msg);
      })
      .then(function () {
        clearTimeout(timer);
        currentCtrl = null;
        busy = false;
        sendBtn.innerHTML = I.send;
        sendBtn.title = '';
      });
  }

  // manual interrupt: tell the agent to abort its current turn, and drop
  // our own in-flight request so the UI frees up immediately.
  function stop() {
    fetch('/apps/grubbery/docs/stop', { method: 'POST' }).catch(function () {});
    if (currentCtrl) currentCtrl.abort();
  }

  // ---- rendering ----
  function renderMarkdown(md) {
    if (window.marked) { try { return window.marked.parse(md); } catch (e) { /* fall through */ } }
    var pre = document.createElement('pre');
    pre.textContent = md;
    return pre.outerHTML;
  }

  function traceEl(trace) {
    var box = el('div', 'da-trace');
    trace.forEach(function (s) {
      var row = el('div', 'da-step');
      var ico = el('span', 'da-step-ico', stepIcon(s.tool || ''));
      var tool = el('span', 'da-step-tool', escText(s.tool || 'tool'));
      var arg = el('span', 'da-step-arg', escText(s.arg || ''));
      row.append(ico, tool, arg);
      if (s.note) row.append(el('span', 'da-step-note', escText(s.note)));
      box.appendChild(row);
    });
    return box;
  }

  function escText(s) {
    var d = document.createElement('div');
    d.textContent = String(s);
    return d.innerHTML;
  }

  function renderLog() {
    log.innerHTML = '';
    if (!history.length) { log.appendChild(emptyState()); return; }
    history.forEach(function (m) {
      if (m.role === 'user') {
        var u = el('div', 'da-msg da-user');
        u.appendChild(el('div', 'da-bubble', escText(m.content)));
        log.appendChild(u);
      } else {
        var b = el('div', 'da-msg da-bot');
        if (m.trace && m.trace.length) b.appendChild(traceEl(m.trace));
        b.appendChild(el('div', 'da-bubble', renderMarkdown(m.content)));
        log.appendChild(b);
      }
    });
    scrollToEnd();
  }

  function emptyState() {
    var wrap = el('div', 'da-hint');
    wrap.innerHTML = 'Ask me anything about Grubbery. I can <b>read and search the docs</b> ' +
      'and the root <b>/code</b> nexus — I answer only from what’s actually there.';
    var chips = el('div', 'da-chips');
    SUGGESTIONS.forEach(function (s) {
      var c = el('button', 'da-chip', escText(s));
      c.addEventListener('click', function () { ask(s); });
      chips.appendChild(c);
    });
    wrap.appendChild(chips);
    return wrap;
  }

  function showTyping() {
    var b = el('div', 'da-msg da-bot');
    b.appendChild(el('div', 'da-bubble', '<div class="da-typing"><span></span><span></span><span></span></div>'));
    log.appendChild(b);
    scrollToEnd();
    return b;
  }

  function showError(msg) {
    var e = el('div', 'da-err', escText(msg));
    log.appendChild(e);
    scrollToEnd();
  }

  function scrollToEnd() {
    requestAnimationFrame(function () { log.scrollTop = log.scrollHeight; });
  }

  // ---- boot ----
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', build);
  } else {
    build();
  }
})();
