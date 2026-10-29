// window-manager.js — the page-global window manager behind <float-window>.
//
// NOT a component: no element, no shadow DOM. This is the shared state and
// geometry that make independent float-windows behave like one desktop —
// stacking order, the single `active` window, snap-region math, the drag
// preview and iframe shield, and the click-into-iframe focus hook. It was
// born inside float-window.js; it lives here so the widget stays a widget
// and window-manager concerns (keyboard shortcuts, workspaces, cycling)
// have an obvious home that isn't a component's private scope.
//
// The kit is served as plain concatenated files (no ES modules), so the
// manager publishes itself as a singleton at window.floatwm, created
// idempotently — double-loading is harmless. float-window.js requires it
// and must come AFTER this file in any bundle or page.
//
// CONTRACT (window.floatwm)
//   .active                the active <float-window> or null
//   .raise(win)            put win on top + move `active` to it
//   .forget(win)           drop win from manager state (close/minimize)
//   .area()                the tiling area {x,y,w,h}: the viewport minus any
//                          reserved inset (see below)
//   .snapRect(spec)        spec → pixel rect. spec is a name in .snaps or a
//                          grid cell {cols, rows, x, y, w, h} (w/h default 1)
//   .snaps                 named snap specs (left/right/top/bottom/full);
//                          extend it to add house layouts
//   .zoneAt(px, py)        which snap spec an edge-shoved pointer asks for,
//                          or null; tune via .config
//   .config                { edgeMargin: 12, cornerBand: 0.2 }
//   .preview(rect|null)    show/hide the translucent snap preview
//   .shield(on)            raise/drop the full-viewport drag shield that
//                          keeps iframes from swallowing pointer streams
//
// RESERVED SCREEN SPACE — the inset protocol
//   Anything that claims an edge of the screen (a taskbar, a dock) declares
//   it by setting a CSS variable on the document root:
//       --fw-area-inset-bottom: 44px;
//   .area() subtracts it. The manager never knows WHO reserved the space —
//   <desk-bar> sets this var about itself; so can anything else.

if (!window.floatwm) {
  window.floatwm = (() => {
    let z = 100;
    const wm = {
      active: null,
      config: { edgeMargin: 12, cornerBand: 0.2 },

      snaps: {
        left:   { cols: 2, rows: 1, x: 0, y: 0 },
        right:  { cols: 2, rows: 1, x: 1, y: 0 },
        top:    { cols: 1, rows: 2, x: 0, y: 0 },
        bottom: { cols: 1, rows: 2, x: 0, y: 1 },
        full:   { cols: 1, rows: 1, x: 0, y: 0 },
      },

      raise(win) {
        if (wm.active !== win) {
          if (wm.active && wm.active.isConnected) wm.active.removeAttribute('active');
          wm.active = win;
          win.setAttribute('active', '');
        }
        if (parseInt(win.style.zIndex || 0) !== z) win.style.zIndex = ++z;
      },

      forget(win) {
        if (wm.active === win) {
          win.removeAttribute('active');
          wm.active = null;
        }
      },

      area() {
        const inset = parseFloat(
          getComputedStyle(document.documentElement)
            .getPropertyValue('--fw-area-inset-bottom')) || 0;
        return { x: 0, y: 0, w: innerWidth, h: innerHeight - inset };
      },

      snapRect(spec) {
        const s = typeof spec === 'string' ? wm.snaps[spec] : spec;
        if (!s) return null;
        const a = wm.area();
        const cw = a.w / (s.cols || 1), ch = a.h / (s.rows || 1);
        return {
          x: a.x + cw * (s.x || 0),
          y: a.y + ch * (s.y || 0),
          w: cw * (s.w || 1),
          h: ch * (s.h || 1),
        };
      },

      zoneAt(px, py) {
        const { edgeMargin: m, cornerBand: band } = wm.config;
        const a = wm.area();
        const nearL = px < m, nearR = px > innerWidth - m;
        const nearT = py < m, nearB = py > a.h - m;
        if (nearL || nearR) {
          const col = nearL ? 0 : 1;
          if (nearT || py < a.h * band) return { cols: 2, rows: 2, x: col, y: 0 };
          if (nearB || py > a.h * (1 - band)) return { cols: 2, rows: 2, x: col, y: 1 };
          return nearL ? 'left' : 'right';
        }
        if (nearT) return 'full';
        return null;
      },

      // one shared translucent rectangle previewing an edge-drag snap target
      preview(rect) {
        if (!rect) {
          if (previewEl) previewEl.style.display = 'none';
          return;
        }
        if (!previewEl) {
          previewEl = document.createElement('div');
          previewEl.style.cssText =
            'position:fixed;pointer-events:none;border-radius:10px;' +
            'background:rgba(9,105,218,.10);border:2px solid rgba(9,105,218,.35);' +
            'box-sizing:border-box;transition:all .1s ease-out;';
          document.body.appendChild(previewEl);
        }
        previewEl.style.zIndex = z + 1;
        previewEl.style.left = rect.x + 'px';
        previewEl.style.top = rect.y + 'px';
        previewEl.style.width = rect.w + 'px';
        previewEl.style.height = rect.h + 'px';
        previewEl.style.display = 'block';
      },

      // full-viewport transparent shield raised during drags so iframes in
      // ANY window can't swallow the pointer stream (capture keeps events on
      // the handle, but only if no other browsing context becomes the target)
      shield(on) {
        if (on && !shieldEl) {
          shieldEl = document.createElement('div');
          shieldEl.style.cssText = 'position:fixed;inset:0;';
          document.body.appendChild(shieldEl);
        }
        if (shieldEl) {
          shieldEl.style.zIndex = z + 1;
          shieldEl.style.display = on ? 'block' : 'none';
        }
      },
    };

    let previewEl = null;
    let shieldEl = null;

    // clicking into an iframe raises its window too. The click never reaches
    // this document (separate browsing context), but focusing the iframe
    // blurs the parent page — and at that moment document.activeElement IS
    // the iframe. That's the whole hook.
    window.addEventListener('blur', () => {
      const ae = document.activeElement;
      if (ae && ae.tagName === 'IFRAME') {
        const win = ae.closest('float-window');
        if (win) win.raise();
      }
    });

    return wm;
  })();
}
