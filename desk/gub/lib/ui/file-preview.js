// Shared file preview — renders svg / html / raster images into a container.
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
    el.style.position = 'relative';
    el.style.alignItems = 'center';
    img.style.cssText = '';
    var mode = 'fit';        // 'fit' | number (scale factor vs natural)
    function base() { return img.naturalWidth || img.clientWidth || 420; }
    function apply() {
      if (mode === 'fit') {
        img.style.cssText = 'max-width:100%;max-height:100%;width:auto;height:auto;object-fit:contain';
      } else {
        img.style.cssText = 'flex:none;max-width:none;max-height:none;height:auto;width:' +
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
  //  svg / html render from their text; image needs a raw-byte url.
  function kind(name) {
    var m = /\.([a-z0-9]+)$/i.exec(name || '');
    var ext = m ? m[1].toLowerCase() : '';
    if (ext === 'svg') return 'svg';
    if (ext === 'html' || ext === 'htm') return 'html';
    if (['png', 'jpg', 'jpeg', 'gif', 'webp', 'ico', 'bmp', 'avif'].indexOf(ext) >= 0) return 'image';
    if (ext === 'pdf') return 'pdf';
    return null;
  }

  // dress the container as a centered, checkerboarded preview surface.
  function surface(el) {
    el.style.cssText += ';overflow:auto;display:flex;align-items:flex-start;' +
      'justify-content:center;padding:20px;box-sizing:border-box;' + CHECKER;
  }

  // render(el, {name, text, rawUrl}) → the kind rendered, or null if nothing.
  //  svg   : from text via a script-safe <img data:> ( <script> never runs )
  //  html  : from text via a sandboxed iframe ( no scripts / no same-origin )
  //  image : raster bytes from rawUrl ( the editor's text can't represent them )
  //  pdf   : raw bytes from rawUrl in a plain iframe ( browser's native viewer )
  function render(el, o) {
    var k = kind(o.name);
    if (k === 'svg' && (o.text != null || o.rawUrl)) {
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
