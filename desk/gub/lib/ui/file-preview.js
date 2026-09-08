// Shared file preview — renders svg / html / json / raster images into a container.
//
// Loaded as a classic script (sets window.FilePreview) rather than an ES
// module: both forge and desk drive their pages with a classic app.js, and a
// deferred module would run *after* app.js, so the global wouldn't exist yet.
// Include this with a plain <script src="…/file-preview.js"> before app.js.
//
// The visual surface (centering, checkerboard, image sizing) is applied inline
// here so every app looks identical with zero per-nexus CSS. Each app owns only
// where its container sits (position/size) and its own Source|Preview chrome.
(function () {
  var CHECKER =
    'background-color:#eef0f2;' +
    'background-image:' +
      'linear-gradient(45deg,#d7dbe0 25%,transparent 25%),' +
      'linear-gradient(-45deg,#d7dbe0 25%,transparent 25%),' +
      'linear-gradient(45deg,transparent 75%,#d7dbe0 75%),' +
      'linear-gradient(-45deg,transparent 75%,#d7dbe0 75%);' +
    'background-size:18px 18px;' +
    'background-position:0 0,0 9px,9px -9px,-9px 0;';
  var IMG = 'width:100%;max-width:420px;height:auto;object-fit:contain';

  // zoom chrome for image-ish previews: fit / 1:1 / stepped zoom.
  // fit constrains to the surface; zoom sets explicit width from the
  // image's natural size (or its rendered size when intrinsic is unknown,
  // e.g. dimensionless svg). double-click toggles fit <-> 1:1.
  function attachZoom(el, img) {
    // el becomes a fixed frame (checkerboard + pinned controls); the image
    // lives in an inner scroller so panning never moves the buttons.
    // auto margins center the image AND keep every edge scroll-reachable
    // (flex centering makes the overflow's start side unreachable).
    el.style.overflow = 'hidden';
    el.style.position = 'relative';
    el.style.padding = '0';
    var scroller = document.createElement('div');
    scroller.style.cssText = 'position:absolute;inset:0;overflow:auto;display:flex;padding:20px;box-sizing:border-box';
    scroller.appendChild(img);
    el.appendChild(scroller);
    img.style.cssText = '';
    var mode = 'fit';        // 'fit' | number (scale factor vs natural)
    function base() { return img.naturalWidth || img.clientWidth || 420; }
    function apply() {
      if (mode === 'fit') {
        img.style.cssText = 'margin:auto;max-width:100%;max-height:100%;width:auto;height:auto;object-fit:contain';
      } else {
        img.style.cssText = 'margin:auto;flex:none;max-width:none;max-height:none;height:auto;width:' +
          Math.round(base() * mode) + 'px';
      }
      pct.textContent = mode === 'fit' ? 'fit'
        : Math.round(mode * 100) + '%';
    }
    function effective() {
      return img.clientWidth / (base() || 1);
    }
    function step(dir) {
      var cur = mode === 'fit' ? effective() : mode;
      mode = Math.min(16, Math.max(0.05, cur * (dir > 0 ? 1.25 : 0.8)));
      apply();
    }
    var bar = document.createElement('div');
    bar.style.cssText = 'position:sticky;top:8px;margin-left:auto;align-self:flex-start;' +
      'display:inline-flex;align-items:center;gap:2px;background:#fff;' +
      'border:1px solid #d0d7de;border-radius:8px;padding:2px 4px;' +
      'box-shadow:0 2px 8px rgba(31,35,40,.12);z-index:3;order:2;' +
      'font:12px -apple-system,BlinkMacSystemFont,sans-serif;user-select:none';
    function btn(label, title, fn) {
      var b = document.createElement('button');
      b.textContent = label;
      b.title = title;
      b.style.cssText = 'all:unset;cursor:pointer;padding:2px 8px;border-radius:6px;color:#57606a';
      b.onmouseenter = function () { b.style.background = '#eaeef2'; b.style.color = '#24292f'; };
      b.onmouseleave = function () { b.style.background = ''; b.style.color = '#57606a'; };
      b.addEventListener('click', fn);
      return b;
    }
    var pct = document.createElement('span');
    pct.style.cssText = 'padding:2px 6px;color:#8b949e;font:11px ui-monospace,Menlo,monospace;min-width:34px;text-align:center';
    bar.appendChild(btn('\u2212', 'zoom out', function () { step(-1); }));
    bar.appendChild(pct);
    bar.appendChild(btn('+', 'zoom in', function () { step(1); }));
    bar.appendChild(btn('fit', 'fit to view', function () { mode = 'fit'; apply(); }));
    bar.appendChild(btn('1:1', 'actual size', function () { mode = 1; apply(); }));
    img.addEventListener('dblclick', function () {
      mode = mode === 'fit' ? 1 : 'fit';
      apply();
    });
    // wrap so the bar floats over the image area without joining the flex flow
    var wrap = document.createElement('div');
    wrap.style.cssText = 'position:absolute;top:8px;right:12px;z-index:3';
    wrap.appendChild(bar);
    bar.style.position = 'static';
    bar.style.order = '';
    bar.style.marginLeft = '';
    el.appendChild(wrap);
    if (img.complete) apply();
    else img.addEventListener('load', apply, { once: true });
    apply();
  }

  // which files can render, by extension. null = source-only.
  //  svg / html / json render from their text; image needs a raw-byte url.
  function kind(name) {
    var m = /\.([a-z0-9]+)$/i.exec(name || '');
    var ext = m ? m[1].toLowerCase() : '';
    if (ext === 'svg') return 'svg';
    if (ext === 'html' || ext === 'htm') return 'html';
    if (ext === 'json') return 'json';
    if (['png', 'jpg', 'jpeg', 'gif', 'webp', 'ico', 'bmp', 'avif'].indexOf(ext) >= 0) return 'image';
    if (ext === 'pdf') return 'pdf';
    return null;
  }

  // ---- json: a collapsible tree like the browser's native viewer ----
  //
  // tree view by default (every node toggles; collapsed nodes summarize
  // their size), a text view with the pretty-printed document for
  // select-and-copy, and expand/collapse-all. Colors follow the
  // github-light palette the source tab uses so the two tabs read as one.
  var J = {
    font: 'font:12.5px/1.55 ui-monospace,SFMono-Regular,Menlo,monospace',
    key: '#953800', str: '#0a3069', num: '#0550ae', bool: '#cf222e',
    nul: '#6e7781', punc: '#57606a', dim: '#8b949e', line: '#eaeef2'
  };
  var BIG = 400;  // nodes; above this, start with depth > 1 collapsed

  function countNodes(v, n) {
    n = n || { c: 0 };
    n.c++;
    if (v && typeof v === 'object') {
      var ks = Object.keys(v);
      for (var i = 0; i < ks.length && n.c <= BIG; i++) countNodes(v[ks[i]], n);
    }
    return n.c;
  }
  function span(text, color, extra) {
    var s = document.createElement('span');
    s.textContent = text;
    s.style.cssText = 'color:' + color + (extra ? ';' + extra : '');
    return s;
  }
  function scalar(v) {
    if (v === null) return span('null', J.nul);
    if (typeof v === 'string') return span(JSON.stringify(v), J.str, 'white-space:pre-wrap;word-break:break-word');
    if (typeof v === 'number') return span(String(v), J.num);
    if (typeof v === 'boolean') return span(String(v), J.bool);
    return span(String(v), J.punc);
  }
  function summary(v) {
    var arr = Array.isArray(v);
    var n = Object.keys(v).length;
    return (arr ? '[…] ' : '{…} ') + n + (arr ? (n === 1 ? ' item' : ' items') : (n === 1 ? ' key' : ' keys'));
  }
  // build one node: a row ([toggle] key: value-or-bracket) and, for
  // containers, a block holding the children and the closing bracket.
  // Indent comes from nesting: each block sits under its row's toggle with
  // a guide line, so no depth arithmetic anywhere. Returns a fragment.
  function node(key, v, depth, open) {
    var frag = document.createDocumentFragment();
    var row = document.createElement('div');
    row.style.cssText = 'display:flex;align-items:flex-start';
    var isObj = v && typeof v === 'object';
    var empty = isObj && Object.keys(v).length === 0;
    var tog = document.createElement('span');
    tog.style.cssText = 'display:inline-block;width:14px;flex:none;color:' + J.dim +
      ';user-select:none;text-align:center;' + (isObj && !empty ? 'cursor:pointer' : 'visibility:hidden');
    tog.textContent = '▾';
    row.appendChild(tog);
    var body = document.createElement('span');
    body.style.cssText = 'flex:1;min-width:0';
    if (key !== null) {
      body.appendChild(span(typeof key === 'number' ? String(key) : JSON.stringify(key),
                            typeof key === 'number' ? J.dim : J.key));
      body.appendChild(span(': ', J.punc));
    }
    row.appendChild(body);
    frag.appendChild(row);
    if (!isObj) { body.appendChild(scalar(v)); return frag; }
    var arr = Array.isArray(v);
    if (empty) { body.appendChild(span(arr ? '[]' : '{}', J.punc)); return frag; }
    var openB = span(arr ? '[' : '{', J.punc);
    var sum = span(summary(v), J.dim, 'cursor:pointer');
    body.appendChild(openB);
    body.appendChild(sum);
    var block = document.createElement('div');
    var kids = document.createElement('div');
    // guide line under the toggle glyph; children start past it
    kids.style.cssText = 'margin-left:7px;padding-left:7px;border-left:1px solid ' + J.line;
    var ks = Object.keys(v);
    for (var i = 0; i < ks.length; i++) {
      kids.appendChild(node(arr ? i : ks[i], v[ks[i]], depth + 1, open));
    }
    var close = document.createElement('div');
    close.style.cssText = 'padding-left:14px';
    close.appendChild(span(arr ? ']' : '}', J.punc));
    block.appendChild(kids);
    block.appendChild(close);
    frag.appendChild(block);
    function set(o) {
      block.style.display = o ? '' : 'none';
      sum.style.display = o ? 'none' : '';
      openB.style.display = o ? '' : 'none';
      tog.textContent = o ? '▾' : '▸';
      row.setAttribute('data-open', o ? '1' : '0');
    }
    function toggle() { set(row.getAttribute('data-open') !== '1'); }
    tog.addEventListener('click', toggle);
    sum.addEventListener('click', toggle);
    set(open(depth));
    return frag;
  }

  function renderJson(el, text) {
    el.style.cssText += ';overflow:auto;padding:0;background:#fff;box-sizing:border-box;position:relative;display:block';
    el.innerHTML = '';
    var data, err = null;
    try { data = JSON.parse(text); } catch (e) { err = e; }
    if (err) {
      var pe = document.createElement('pre');
      pe.style.cssText = J.font + ';margin:0;padding:16px;color:#cf222e;white-space:pre-wrap';
      pe.textContent = 'invalid JSON: ' + err.message + '\n\n';
      var raw = span(text, J.punc, 'white-space:pre-wrap;word-break:break-word');
      pe.appendChild(raw);
      el.appendChild(pe);
      return;
    }
    var big = countNodes(data) > BIG;
    var openAt = function (d) { return !big || d < 1; };

    // toolbar: pinned top-right like the image zoom chrome
    var bar = document.createElement('div');
    bar.style.cssText = 'position:sticky;top:8px;float:right;margin:8px 12px 0 0;' +
      'display:inline-flex;align-items:center;gap:2px;background:#fff;' +
      'border:1px solid #d0d7de;border-radius:8px;padding:2px 4px;' +
      'box-shadow:0 2px 8px rgba(31,35,40,.12);z-index:3;' +
      'font:12px -apple-system,BlinkMacSystemFont,sans-serif;user-select:none';
    function btn(label, title, fn) {
      var b = document.createElement('button');
      b.textContent = label;
      b.title = title;
      b.style.cssText = 'all:unset;cursor:pointer;padding:2px 8px;border-radius:6px;color:#57606a';
      b.onmouseenter = function () { b.style.background = '#eaeef2'; b.style.color = '#24292f'; };
      b.onmouseleave = function () { b.style.background = b.getAttribute('data-on') ? '#eaeef2' : ''; b.style.color = '#57606a'; };
      b.addEventListener('click', fn);
      return b;
    }
    function sep() {
      var s = document.createElement('span');
      s.style.cssText = 'width:1px;height:14px;background:#d0d7de;margin:0 3px';
      return s;
    }

    var tree = document.createElement('div');
    tree.style.cssText = J.font + ';padding:12px 16px 16px;color:#24292f';
    var pretty = document.createElement('pre');
    pretty.style.cssText = J.font + ';margin:0;padding:12px 16px 16px;color:#24292f;white-space:pre;display:none';
    pretty.textContent = JSON.stringify(data, null, 2);

    tree.appendChild(node(null, data, 0, openAt));
    // every container row carries data-open; its toggle is the first child
    var rows = Array.prototype.slice.call(tree.querySelectorAll('[data-open]'));
    function setAll(o) {
      rows.forEach(function (r) {
        if ((r.getAttribute('data-open') === '1') !== o) r.firstChild.click();
      });
    }

    var bTree = btn('tree', 'collapsible tree', function () { mode('tree'); });
    var bText = btn('text', 'pretty-printed text', function () { mode('text'); });
    function mode(m) {
      tree.style.display = m === 'tree' ? '' : 'none';
      pretty.style.display = m === 'text' ? '' : 'none';
      bTree.setAttribute('data-on', m === 'tree' ? '1' : '');
      bText.setAttribute('data-on', m === 'text' ? '1' : '');
      bTree.style.background = m === 'tree' ? '#eaeef2' : '';
      bText.style.background = m === 'text' ? '#eaeef2' : '';
      bExp.style.display = bCol.style.display = m === 'tree' ? '' : 'none';
      sp.style.display = m === 'tree' ? '' : 'none';
    }
    var bExp = btn('expand all', 'expand every node', function () { setAll(true); });
    var bCol = btn('collapse all', 'collapse every node', function () { setAll(false); });
    var bCopy = btn('copy', 'copy pretty-printed JSON', function () {
      if (navigator.clipboard) navigator.clipboard.writeText(pretty.textContent);
      bCopy.textContent = 'copied';
      setTimeout(function () { bCopy.textContent = 'copy'; }, 900);
    });
    var sp = sep();
    bar.appendChild(bExp);
    bar.appendChild(bCol);
    bar.appendChild(sp);
    bar.appendChild(bTree);
    bar.appendChild(bText);
    bar.appendChild(sep());
    bar.appendChild(bCopy);
    el.appendChild(bar);
    el.appendChild(tree);
    el.appendChild(pretty);
    mode('tree');
  }

  // dress the container as a centered, checkerboarded preview surface.
  function surface(el) {
    el.style.cssText += ';overflow:auto;display:flex;align-items:flex-start;' +
      'justify-content:center;padding:20px;box-sizing:border-box;' + CHECKER;
  }

  // render(el, {name, text, rawUrl}) → the kind rendered, or null if nothing.
  //  svg   : from text via a script-safe <img data:> ( <script> never runs )
  //  html  : from text via a sandboxed iframe ( no scripts / no same-origin )
  //  json  : from text as a collapsible tree ( or pretty-printed text )
  //  image : raster bytes from rawUrl ( the editor's text can't represent them )
  //  pdf   : raw bytes from rawUrl in a plain iframe ( browser's native viewer )
  function render(el, o) {
    var k = kind(o.name);
    if (k === 'json' && o.text != null) {
      renderJson(el, o.text);
    } else if (k === 'svg' && (o.text != null || o.rawUrl)) {
      surface(el);
      // from text when we have it (reflects unsaved edits); else the raw bytes.
      // <img> never executes a <script> inside the svg, so either way is safe.
      var src = (o.text != null)
        ? 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(o.text)
        : o.rawUrl;
      el.innerHTML = '<img style="' + IMG + '" src="' + src + '">';
      attachZoom(el, el.querySelector('img'));
    } else if (k === 'html' && o.text != null) {
      surface(el);
      el.innerHTML = '';
      var f = document.createElement('iframe');
      f.setAttribute('sandbox', '');
      f.style.cssText = 'width:100%;height:100%;border:none;background:#fff';
      f.srcdoc = o.text;
      el.appendChild(f);
    } else if (k === 'image' && o.rawUrl) {
      surface(el);
      el.innerHTML = '<img style="' + IMG + '" src="' + o.rawUrl + '">';
      attachZoom(el, el.querySelector('img'));
    } else if (k === 'pdf' && o.rawUrl) {
      el.innerHTML = '';
      var pf = document.createElement('iframe');
      pf.style.cssText = 'width:100%;height:100%;border:none';
      pf.src = o.rawUrl;
      el.appendChild(pf);
    } else {
      el.innerHTML = '';
      return null;
    }
    return k;
  }

  window.FilePreview = { kind: kind, render: render };
})();
