// tree-viewer: a reusable VIEWER WIDGET (not part of the explorer core). An app
// declares it in a view.json — `{view:"tree", script:<this file>, args:{root}}` —
// and any pane-split pane (or explorer tab) that opens the declaring path mounts
// it through the standard viewer system. Zero changes to pane-split/explorer.
//
// Contract (window.Viewers[name], same as FileView):
//   mount(host, { url, args, onNavigate }) -> { destroy }
// args.root  — the NAMESPACE path to show the tree of (default '/').
// onNavigate — called with a namespace path when a row is opened; the host
//              routes it (in pane-split: through the pane's openTo).
//
// It leans on <tree-view> (kit): one ?tree=1 fetch feeds getChildren
// synchronously; clicks fire onOpenFile/onOpenDir. A compact strip carries the
// finder's two sidebar affordances: expand/collapse all and show/hide badges
// (badges via the shared window.attachBadges from lib/ui/badges.js).
(function () {
  const PREFIX = '/grubbery/ball';
  const urlOf = (ns) => (ns === '/' || !ns) ? PREFIX : PREFIX + ns;

  function mount(host, opts) {
    opts = opts || {};
    const root = (opts.args && opts.args.root) || '/';
    const onNav = typeof opts.onNavigate === 'function' ? opts.onNavigate : () => {};
    let tv = null, badgesOn = true;

    const wrap = document.createElement('div');
    wrap.style.cssText = 'display:flex;flex-direction:column;height:100%;min-height:0';
    const strip = document.createElement('div');
    strip.style.cssText = 'flex:0 0 auto;display:flex;align-items:center;gap:6px;padding:4px 8px;border-bottom:1px solid #e2e7ee;background:#f6f8fa';
    const btn = (t) => { const b = document.createElement('button'); b.textContent = t; b.style.cssText = 'all:unset;cursor:pointer;padding:2px 7px;border-radius:5px;color:#57606a;font:13px -apple-system,sans-serif'; b.addEventListener('mouseover', () => b.style.background = '#eaeef2'); b.addEventListener('mouseout', () => b.style.background = ''); return b; };
    const foldBtn = btn('expand all');
    const badgeBtn = btn('hide badges');
    const sp = document.createElement('span'); sp.style.flex = '1';
    strip.append(foldBtn, sp, badgeBtn);
    const body = document.createElement('div');
    body.style.cssText = 'flex:1 1 auto;min-height:0;overflow:auto';
    wrap.append(strip, body);
    host.appendChild(wrap);

    fetch(urlOf(root) + '?tree=1').then((r) => r.ok ? r.json() : Promise.reject('t')).then((doc) => {
      const rootSegs = root.split('/').filter(Boolean);
      const nodeAt = (p) => { let n = doc; for (const s of p.split('/').filter(Boolean).slice(rootSegs.length)) n = n && n.dirs && n.dirs[s]; return n; };
      const kids = (p) => {
        const n = nodeAt(p); if (!n) return [];
        const dirs = Object.keys(n.dirs || {}).map((name) => { const sub = n.dirs[name]; return { name, isDir: true, kind: 'dir', hasWeir: !!(sub && sub.weir), neck: (sub && sub.neck) || null }; });
        const files = (n.files || []).map((f) => ({ name: f.name, isDir: false, kind: 'file', blot: f.blot || null }));
        return dirs.concat(files);
      };
      tv = document.createElement('tree-view');
      tv.style.cssText = 'display:block';
      tv.root = root;
      tv.persistKey = 'tree-viewer:' + root;
      tv.getChildren = kids;
      tv.onOpenFile = (item, p) => onNav(p);
      tv.onOpenDir = (item, p) => onNav(p);
      tv.decorateRow = (row, item, p) => {
        // the row carries its item (with the url of the dir it lives in), so a
        // host's context menu finds what was clicked the same way it does in a
        // file-table or file-grid row
        const parent = p.slice(0, p.lastIndexOf('/')) || '/';
        row.__item = Object.assign({}, item, { __dir: urlOf(parent) });
        if (typeof window.attachBadges !== 'function') return;
        // the weir shield opens the dir's weir view (where the host opens links); neck and blot open the path
        window.attachBadges(row, item, { enabled: badgesOn, onWeir: () => onNav(p + '?view=weir', 'dir'), onNeck: () => onNav(p), onBlot: () => onNav(p) });
      };
      body.appendChild(tv);
      tv.render(kids(root));

      const syncFold = () => { foldBtn.textContent = tv.anyOpen ? 'collapse all' : 'expand all'; };
      syncFold();
      foldBtn.addEventListener('click', async () => { if (tv.anyOpen) tv.collapseAll(); else await tv.expandAll(); syncFold(); });
      badgeBtn.addEventListener('click', () => { badgesOn = !badgesOn; badgeBtn.textContent = badgesOn ? 'hide badges' : 'show badges'; tv.render(kids(root)); syncFold(); });
    }).catch(() => { body.textContent = 'tree unavailable: ' + root; });

    return { destroy() { try { wrap.remove(); } catch (_) {} } };
  }

  window.Viewers = window.Viewers || {};
  window.Viewers.tree = { label: 'tree', mount };
})();
