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

  // which files can render, by extension. null = source-only.
  //  svg / html render from their text; image needs a raw-byte url.
  function kind(name) {
    var m = /\.([a-z0-9]+)$/i.exec(name || '');
    var ext = m ? m[1].toLowerCase() : '';
    if (ext === 'svg') return 'svg';
    if (ext === 'html' || ext === 'htm') return 'html';
    if (['png', 'jpg', 'jpeg', 'gif', 'webp', 'ico', 'bmp', 'avif'].indexOf(ext) >= 0) return 'image';
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
    } else {
      el.innerHTML = '';
      return null;
    }
    return k;
  }

  window.FilePreview = { kind: kind, render: render };
})();
