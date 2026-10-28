// PostViewer — the post popup: page 0 is the whole post (text, then its
// media expanded below), pages 1..N are one medium each on a dark canvas
// with drag-to-pan, wheel-zoom, dblclick, and a − / % / + / fit / 1:1 bar.
// Arrows and ← → step pages. Grew out of ghostprompter's post modal; the
// nostr page and ghostprompter both open it. Not a component of its own:
// one <modal-dialog> is created on first use and reused.
//
// USAGE (classic script or welded into components.js; needs <modal-dialog>
// and PostText from the same kit)
//   PostViewer.open({
//     post:  { id, pubkey, content, created_at },   // created_at unix seconds (or `at`)
//     profile: { name, picture },
//     page:  0,                                      // or 1..N to land on a medium
//     renderText: (el, text) => …,                   // optional; default PostText.render
//     onPerson: (pubkey) => …,                       // optional; name/avatar click
//   });
//   PostViewer.close();
//
// CSS vars on the dialog (theme in): --pv-accent (nav buttons, default #3d3a52).
(function () {
  'use strict';
  var CSS = '.pv-modal { --md-width: 760px; --md-radius: 18px; --md-pad: 0; --md-shadow: 0 24px 80px rgba(20,18,40,0.4); --md-backdrop: rgba(18,16,30,0.5); }\n' +
    '.pv-head { display: flex; align-items: center; gap: 13px; padding: 20px 24px 15px; border-bottom: 1px solid #eef0f3; min-width: 0; }\n' +
    '.pv-head avatar-pic { --av-size: 44px; }\n' +
    '.pv-head .pv-who { min-width: 0; }\n' +
    '.pv-head .pv-name { font-size: 16px; font-weight: 650; color: #1f2328; }\n' +
    '.pv-head .pv-name.pk { font-family: "SF Mono", Menlo, monospace; font-weight: 500; color: #57606a; }\n' +
    '.pv-head .pv-name.clickable, .pv-head avatar-pic.clickable { cursor: pointer; }\n' +
    '.pv-head .pv-name.clickable:hover { text-decoration: underline; }\n' +
    '.pv-head .pv-when { font-size: 12.5px; color: #9aa0a8; margin-top: 2px; }\n' +
    '.pv-body { padding: 20px 24px; font-size: 15px; line-height: 1.65; color: #1f2328; white-space: pre-wrap; word-break: break-word; max-height: 58vh; overflow-y: auto; }\n' +
    '.pv-body a { color: #6b3fd6; text-decoration: none; }\n' +
    '.pv-body a:hover { text-decoration: underline; }\n' +
    '.pv-body.media-page { padding: 0; max-height: none; overflow: hidden; white-space: normal; }\n' +
    '.pv-media { display: flex; align-items: center; justify-content: center; background: #0f0f16; min-height: 440px; padding: 14px; }\n' +
    '.pv-media video, .pv-media img { max-width: 100%; max-height: 64vh; border-radius: 8px; }\n' +
    '.pv-media.fp { position: relative; overflow: hidden; padding: 0; height: min(64vh, 560px); min-height: 0; }\n' +
    '.pv-media.fp img { max-width: 100%; max-height: 100%; border-radius: 0; cursor: grab; user-select: none; -webkit-user-drag: none; transform-origin: center center; }\n' +
    '.pv-media.fp.dragging img { cursor: grabbing; }\n' +
    '.pv-media.embed iframe { width: 100%; aspect-ratio: 16 / 9; height: auto; max-height: 64vh; border: 0; border-radius: 8px; }\n' +
    '.pv-bar { position: absolute; top: 10px; right: 12px; z-index: 2; display: inline-flex; align-items: center; gap: 2px; background: rgba(31,35,40,0.82); border-radius: 8px; padding: 2px 4px; box-shadow: 0 2px 8px rgba(0,0,0,0.3); }\n' +
    '.pv-bar button { all: unset; cursor: pointer; padding: 3px 9px; border-radius: 6px; color: #c9ced6; font: 12px Inter, -apple-system, sans-serif; }\n' +
    '.pv-bar button:hover { background: rgba(255,255,255,0.14); color: #fff; }\n' +
    '.pv-pct { padding: 2px 6px; color: #8b949e; min-width: 36px; text-align: center; font: 11px ui-monospace, Menlo, monospace; }\n' +
    '.pv-nav { display: flex; align-items: center; justify-content: center; gap: 16px; padding: 13px 24px; }\n' +
    '.pv-nav.hidden { display: none; }\n' +
    '.pv-nav button { width: 38px; height: 38px; border: none; border-radius: 50%; background: var(--pv-accent, #3d3a52); color: #fff; font-size: 19px; line-height: 1; cursor: pointer; transition: background .12s, transform .12s; }\n' +
    '.pv-nav button:hover:not(:disabled) { filter: brightness(1.15); transform: scale(1.06); }\n' +
    '.pv-nav button:disabled { opacity: .25; cursor: default; }\n' +
    '.pv-count { font-size: 12.5px; color: #9aa0a8; min-width: 110px; text-align: center; letter-spacing: .01em; }\n' +
    '.pv-id { padding: 0 24px 16px; font-family: ui-monospace, monospace; font-size: 11px; color: #c4c8cd; word-break: break-all; }\n';

  var dlg = null, els = null, st = null, isOpen = false;

  function ensure() {
    if (dlg) return;
    var style = document.createElement('style'); style.textContent = CSS; document.head.appendChild(style);
    dlg = document.createElement('modal-dialog'); dlg.className = 'pv-modal';
    dlg.innerHTML = '<div class="pv-head"></div><div class="pv-body"></div>' +
      '<div class="pv-nav hidden"><button class="pv-prev" title="Previous">&#8249;</button><span class="pv-count"></span><button class="pv-next" title="Next">&#8250;</button></div>' +
      '<div class="pv-id"></div>';
    document.body.appendChild(dlg);
    els = {
      head: dlg.querySelector('.pv-head'), body: dlg.querySelector('.pv-body'), nav: dlg.querySelector('.pv-nav'),
      count: dlg.querySelector('.pv-count'), prev: dlg.querySelector('.pv-prev'), next: dlg.querySelector('.pv-next'), id: dlg.querySelector('.pv-id'),
    };
    els.prev.onclick = function () { step(-1); };
    els.next.onclick = function () { step(1); };
    dlg.addEventListener('md-open', function () { isOpen = true; });
    dlg.addEventListener('md-close', function () { isOpen = false; els.body.textContent = ''; });  // stops video
    document.addEventListener('keydown', function (e) {
      if (!isOpen) return;
      if (e.key === 'ArrowLeft') step(-1);
      if (e.key === 'ArrowRight') step(1);
    });
  }

  function open(opts) {
    ensure();
    var post = opts.post || {};
    st = {
      post: post, profile: opts.profile || {},
      media: (window.PostText ? PostText.mediaOf(post.content || '') : []),
      page: opts.page || 0,
      renderText: opts.renderText || function (el, t) { if (window.PostText) PostText.render(el, t, { onPerson: opts.onPerson }); else el.textContent = t; },
      onPerson: opts.onPerson,
    };
    if (st.page > st.media.length) st.page = 0;
    render();
    dlg.show();
  }
  function close() { if (dlg) dlg.close(); }
  function step(d) {
    if (!isOpen || !st) return;
    var next = st.page + d;
    if (next < 0 || next > st.media.length) return;
    st.page = next; render();
  }

  function render() {
    var p = st.post, prof = st.profile;
    els.head.textContent = ''; els.body.textContent = '';
    var av = document.createElement('avatar-pic');
    av.setAttribute('name', prof.name || ''); av.setAttribute('seed', p.pubkey || ''); av.setAttribute('src', prof.picture || '');
    var who = document.createElement('div'); who.className = 'pv-who';
    var nm = document.createElement('div'); nm.className = 'pv-name' + (prof.name ? '' : ' pk');
    nm.textContent = prof.name || (p.pubkey || '').slice(0, 12);
    var at = p.created_at || p.at;
    var when = document.createElement('div'); when.className = 'pv-when';
    when.textContent = at ? new Date(at * 1000).toLocaleString() : '';
    who.append(nm, when);
    if (st.onPerson && p.pubkey) {
      var go = function () { st.onPerson(p.pubkey); };
      av.classList.add('clickable'); nm.classList.add('clickable'); av.onclick = go; nm.onclick = go;
    }
    els.head.append(av, who);

    els.body.classList.toggle('media-page', st.page > 0);
    if (st.page === 0) {
      var txt = document.createElement('div'); txt.className = 'pv-text';
      st.renderText(txt, p.content || '');
      if (txt.textContent.trim()) els.body.appendChild(txt);
      if (st.media.length && window.PostText) {
        els.body.appendChild(PostText.attachments(st.media, 'full', function (i) { st.page = i + 1; render(); }));
      }
    } else {
      var m = st.media[st.page - 1];
      var wrap = document.createElement('div'); wrap.className = 'pv-media';
      if (m.embed) {
        wrap.classList.add('embed'); wrap.appendChild(PostText.embedEl(m)); els.body.appendChild(wrap);
      } else if (m.video) {
        var v = document.createElement('video'); v.controls = true; v.preload = 'metadata'; v.src = m.url;
        wrap.appendChild(v); els.body.appendChild(wrap);
      } else {
        wrap.classList.add('fp'); els.body.appendChild(wrap); viewer(wrap, m.url);
      }
    }
    var pages = 1 + st.media.length;
    els.nav.classList.toggle('hidden', pages < 2);
    els.count.textContent = st.page === 0 ? 'post · ' + st.media.length + ' media' : st.page + ' / ' + st.media.length;
    els.prev.disabled = st.page === 0;
    els.next.disabled = st.page >= pages - 1;
    els.id.textContent = p.id ? 'event ' + p.id : '';
  }

  // image page: drag to pan, wheel to zoom toward the cursor, dblclick
  // to toggle, and the − / % / + / fit / 1:1 bar
  function viewer(wrap, url) {
    var img = document.createElement('img'); img.draggable = false; img.src = url; wrap.appendChild(img);
    var scale = 1, tx = 0, ty = 0, drag = null;
    var pct = document.createElement('span'); pct.className = 'pv-pct';
    function nat() { return img.naturalWidth || img.clientWidth || 1; }
    function apply() {
      img.style.transform = 'translate(' + tx + 'px,' + ty + 'px) scale(' + scale + ')';
      pct.textContent = Math.round(scale * (img.clientWidth / nat()) * 100) + '%';
    }
    function setScale(next, cx, cy) {
      next = Math.max(0.2, Math.min(12, next));
      if (next === scale) return;
      if (cx !== undefined) {
        var r = img.getBoundingClientRect();
        tx -= (cx - (r.left + r.width / 2)) * (next / scale - 1);
        ty -= (cy - (r.top + r.height / 2)) * (next / scale - 1);
      }
      if (next <= 1.001) { tx = 0; ty = 0; }
      scale = next; apply();
    }
    wrap.addEventListener('wheel', function (e) {
      e.preventDefault();
      var d = e.deltaY || e.deltaX;
      setScale(scale * (d < 0 ? 1.15 : 1 / 1.15), e.clientX, e.clientY);
    }, { passive: false });
    img.addEventListener('dblclick', function (e) { setScale(scale > 1.001 ? 1 : 2.5, e.clientX, e.clientY); });
    img.addEventListener('pointerdown', function (e) { e.preventDefault(); drag = { x: e.clientX - tx, y: e.clientY - ty }; wrap.classList.add('dragging'); img.setPointerCapture(e.pointerId); });
    img.addEventListener('pointermove', function (e) { if (!drag) return; tx = e.clientX - drag.x; ty = e.clientY - drag.y; apply(); });
    img.addEventListener('pointerup', function () { drag = null; wrap.classList.remove('dragging'); });
    var bar = document.createElement('div'); bar.className = 'pv-bar';
    function btn(label, title, fn) { var b = document.createElement('button'); b.textContent = label; b.title = title; b.onclick = fn; return b; }
    bar.append(btn('−', 'zoom out', function () { setScale(scale / 1.25); }), pct,
      btn('+', 'zoom in', function () { setScale(scale * 1.25); }),
      btn('fit', 'fit to view', function () { setScale(1); }),
      btn('1:1', 'actual size', function () { setScale(nat() / (img.clientWidth || 1)); }));
    wrap.appendChild(bar);
    if (img.complete) apply(); else img.addEventListener('load', apply, { once: true });
  }

  window.PostViewer = { open: open, close: close };
})();
