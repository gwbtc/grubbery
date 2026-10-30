var API='/grubbery/api';var BALL='apps/shell'; // local tiles live in the shell's own root
  // inbox bell: landscape-style notifications panel over the tiles
  var NBALL = 'apps/shell/notifications';
  var bellNotes = [];

  // Pending permission requests belong in the bell too. An app that has asked
  // for roads and not been answered is exactly the thing this panel exists to
  // draw the user to. The bell reads the permissions caches directly and
  // lists each unanswered ask as an item that opens the permissions page on
  // that app, beside the inbox's own notes. They are not read or dismissed
  // here; they resolve by being granted.
  function sameRoads(a, b) { a = (a || []).slice().sort(); b = (b || []).slice().sort(); return a.length === b.length && a.every(function(x, i) { return x === b[i]; }); }
  function roadsOf(x) { return (x || []).map(function(r) { return typeof r === 'string' ? r : r.road; }); }
  function pendingAsks() {
    return Promise.all([
      fetch('/apps/grubbery/asks.json').then(function(r) { return r.json(); }).catch(function() { return []; }),
      fetch('/apps/grubbery/approved.json').then(function(r) { return r.json(); }).catch(function() { return {}; })
    ]).then(function(res) {
      var asks = res[0] || [], approved = res[1] || {};
      return asks.filter(function(a) {
        var ap = approved[a.app], dec = ap && ap.declared;
        return !ap || !(dec && sameRoads(roadsOf(a.poke), roadsOf(dec.poke)) && sameRoads(roadsOf(a.peek), roadsOf(dec.peek)) && sameRoads(roadsOf(a.make), roadsOf(dec.make)));
      }).map(function(a) {
        var n = roadsOf(a.poke).length + roadsOf(a.peek).length + roadsOf(a.make).length;
        var leaf = a.app.split('/').pop();
        return { id: 'ask:' + a.app, app: leaf, created_ms: 0, mack: null, ask: true,
                 metadata: { title: 'wants ' + n + ' permission' + (n === 1 ? '' : 's'),
                             body: 'Open to review and grant.',
                             url: '/apps/grubbery/permits?app=' + encodeURIComponent(a.app) } };
      });
    });
  }
  function bellFetch() {
    return Promise.all([
      fetch('/grubbery/ball/' + NBALL + '/inbox.inbox?blot=/json').then(function(r) { return r.json(); }).catch(function() { return []; }),
      pendingAsks()
    ]).then(function(res) { bellNotes = (res[1] || []).concat(res[0] || []); bellBadge(); })
      .catch(function() {});
  }
  // asks change when a user grants or an app installs; keep the pip honest
  setInterval(function() { bellFetch().then(function() { if (document.getElementById('bell-backdrop').classList.contains('open')) bellRender(); }); }, 60000);

  function bellBadge() {
    var n = bellNotes.filter(function(x) { return x.mack == null; }).length;
    var c = document.getElementById('bell-count');
    c.textContent = n > 99 ? '99+' : n;
    c.style.display = n ? 'flex' : 'none';
    document.getElementById('bell').classList.toggle('live', n > 0);
  }

  function bellAgo(ms) {
    var s = Math.floor((Date.now() - ms) / 1000);
    if (s < 60) return 'now';
    if (s < 3600) return Math.floor(s / 60) + 'm';
    if (s < 86400) return Math.floor(s / 3600) + 'h';
    return Math.floor(s / 86400) + 'd';
  }

  function bellRender() {
    var el = document.getElementById('bell-notes');
    el.innerHTML = '';
    var anyUnacked = bellNotes.some(function(n) { return n.mack == null && !n.ask; });
    document.getElementById('bell-ack-all').style.display = anyUnacked ? '' : 'none';
    if (!bellNotes.length) {
      el.innerHTML = '<div class="bn-empty">nothing here — a quiet ship</div>';
      return;
    }
    bellNotes.slice().sort(function(a, b) { return b.created_ms - a.created_ms; })
      .forEach(function(n) {
        var md = n.metadata || {};
        var acked = n.mack != null;
        var d = document.createElement('div');
        d.className = 'bn' + (acked ? ' acked' : '');
        d.innerHTML =
          '<div style="min-width:0;flex:1">' +
            '<span class="bn-app">' + esc(n.app) + '</span> ' +
            '<span class="bn-time">' + bellAgo(n.created_ms) + '</span>' +
            '<div class="bn-title">' + esc(md.title || '(untitled)') + '</div>' +
            (md.body ? '<div class="bn-body">' + esc(md.body) + '</div>' : '') +
          '</div>';
        var acts = document.createElement('div');
        acts.className = 'bn-acts';
        if (n.ask) {
          var g = document.createElement('button');
          g.className = 'hdr-btn';
          g.textContent = 'Review';
          g.onclick = function(e) { e.stopPropagation(); location.href = md.url; };
          acts.appendChild(g);
          d.appendChild(acts);
          d.style.cursor = 'pointer';
          d.onclick = function() { location.href = md.url; };
          el.appendChild(d);
          return;
        }
        if (!acked) {
          var b = document.createElement('button');
          b.className = 'hdr-btn';
          b.textContent = 'Mark as read';
          b.onclick = function(e) { e.stopPropagation(); bellAck(n.id); };
          acts.appendChild(b);
        }
        var t = document.createElement('button');
        t.className = 'bn-del';
        t.textContent = '✕';
        t.title = 'Delete';
        t.onclick = function(e) { e.stopPropagation(); bellClear(n.id); };
        acts.appendChild(t);
        d.appendChild(acts);
        if (md.url || !acked) {
          d.style.cursor = 'pointer';
          d.onclick = function() {
            if (!acked) bellAck(n.id);
            if (md.url) window.open(md.url, '_blank');
          };
        }
        el.appendChild(d);
      });
  }

  function bellPoke(body, cb) {
    fetch(API + '/poke/' + NBALL + '/main.sig?blot=/json', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    }).then(function() { if (cb) cb(); });
  }

  function openBell(e) {
    e.preventDefault();
    document.getElementById('bell-backdrop').classList.add('open');
    bellRender();
    bellFetch().then(bellRender);
  }
  function closeBell(e) {
    if (e.target === document.getElementById('bell-backdrop')) closeBellNow();
  }
  function closeBellNow() {
    document.getElementById('bell-backdrop').classList.remove('open');
  }
  function bellClear(id) {
    bellPoke({ action: 'clear', id: id }, function() {
      setTimeout(function() { bellFetch().then(bellRender); }, 350);
    });
  }

  function bellAck(id) {
    bellPoke({ action: 'ack', id: id }, function() {
      setTimeout(function() { bellFetch().then(bellRender); }, 350);
    });
  }
  function bellAckAll() {
    var un = bellNotes.filter(function(n) { return n.mack == null && !n.ask; });
    var left = un.length;
    if (!left) return;
    un.forEach(function(n) {
      bellPoke({ action: 'ack', id: n.id }, function() {
        if (--left <= 0) setTimeout(function() { bellFetch().then(bellRender); }, 350);
      });
    });
  }
  function esc(s) {
    var d = document.createElement('div');
    d.textContent = s == null ? '' : String(s);
    return d.innerHTML;
  }
  bellFetch();

  var tilesDiv = document.getElementById('tiles');
  var editBack = document.getElementById('edit-backdrop');
  var editTitle = document.getElementById('edit-title');
  var editJson = document.getElementById('edit-json');
  var editStatus = document.getElementById('edit-status');
  var editName = '';
  var isNew = false;
  var tileData = {};

  function buildTile(t) {
    var d = document.createElement('div');
    d.className = t.image ? 'tile has-img' : 'tile';
    if (!t.root) d.classList.add('pinned'); // a link you pinned, not an app's tile
    d.dataset.tile = t.name;
    var bg = document.createElement('div');
    bg.className = 'tile-bg';
    bg.style.background = t.color || '#333';
    d.appendChild(bg);
    if (t.image) {
      var img = document.createElement('img');
      img.className = 'tile-img';
      img.src = t.image;
      img.onload = function() { this.closest('.tile').classList.add('loaded'); };
      img.onerror = function() { this.style.display='none'; this.closest('.tile').classList.add('loaded'); };
      d.appendChild(img);
    }
    var lbl = document.createElement('div');
    lbl.className = 'tile-label';
    var ttl = document.createElement('div');
    ttl.className = 'tile-title';
    ttl.textContent = t.title || '';
    lbl.appendChild(ttl);
    if (!t.root) {
      var pin = document.createElement('span');
      pin.className = 'tile-pin';
      pin.title = 'pinned link';
      pin.textContent = '□';
      ttl.appendChild(pin);
    }
    if (t.info) {
      var desc = document.createElement('div');
      desc.className = 'tile-desc';
      desc.textContent = t.info;
      lbl.appendChild(desc);
    }
    d.appendChild(lbl);
    var acts = document.createElement('div');
    acts.className = 'tile-actions';
    var btn = document.createElement('button');
    btn.className = 'tile-edit';
    btn.textContent = 'view';
    btn.onclick = function(e) { e.preventDefault(); e.stopPropagation(); viewTile(d, t.name); };
    acts.appendChild(btn);
    d.appendChild(acts);
    if (t.href) {
      var a = document.createElement('a');
      a.className = 'tile-link';
      a.href = t.href;
      a.target = '_blank';
      d.appendChild(a);
    }
    return d;
  }

  // hidden tiles are kept entirely out of the home grid. A header "Hidden · N"
  // button switches the grid to a hidden-only view, where each tile's view
  // modal offers "unhide". The button hides itself when nothing is hidden.
  var showingHidden = false;
  var allTiles = [];
  function toggleHiddenView() { showingHidden = !showingHidden; paintTiles(); }
  function updateHiddenBtn(n) {
    var b = document.getElementById('hidden-btn');
    if (!b) return;
    b.style.display = (n || showingHidden) ? '' : 'none';
    b.textContent = showingHidden ? '← Home' : ('Hidden · ' + n);
    b.classList.toggle('active', showingHidden);
  }
  function paintTiles() {
    var loading = document.getElementById('loading-tile');
    var visible = allTiles.filter(function(t) { return !t.hidden; });
    var hidden = allTiles.filter(function(t) { return t.hidden; });
    if (showingHidden && !hidden.length) showingHidden = false;
    var list = showingHidden ? hidden : visible;
    tilesDiv.innerHTML = '';
    if (!list.length) {
      tilesDiv.innerHTML = '<div class="empty">' + (showingHidden ? 'no hidden tiles' : 'no tiles yet') + '</div>';
    } else {
      list.forEach(function(t) { tilesDiv.appendChild(buildTile(t)); });
      if (loading && !showingHidden) tilesDiv.appendChild(loading);
    }
    updateHiddenBtn(hidden.length);
  }
  function renderTiles(tiles) {
    tileData = {};
    tiles.forEach(function(t) { tileData[t.name] = t; });
    allTiles = tiles;
    paintTiles();
  }

  function loadTiles() {
    fetch('/grubbery/tiles/tiles.json')
      .then(function(r) { return r.json(); })
      .then(renderTiles)
      .catch(function() { tilesDiv.innerHTML = '<div class="empty">failed to load tiles</div>'; });
  }

  // the modal has three faces: a read-only card ('view'), a fields form
  // ('form') and a raw JSON editor ('json'). The two editors show the same
  // tile; switching between them carries the current values across.
  var FIELDS = ['title', 'href', 'info', 'color', 'image'];
  var mode = 'view';
  function show(id, on) { document.getElementById(id).style.display = on ? '' : 'none'; }
  // the card modal shows one tile; a pinned link also offers edit, which
  // opens the Manage Desks panel on its pin screen
  function modalMode(m, t) {
    show('edit-edit', t && !t.root);
  }
  // the pin screen's two faces: the fields form or the raw json
  function pinMode(m) {
    mode = m;
    show('edit-form', m === 'form');
    show('edit-json', m === 'json');
    document.getElementById('edit-raw').textContent = m === 'json' ? 'fields' : 'raw json';
  }
  // the pin screen, inside the Manage Desks panel, behind a back button
  function openPin(title, t) {
    editBack.classList.remove('open');
    var panel = document.getElementById('get-panel');
    if (!document.getElementById('get-backdrop').classList.contains('open')) openAdd('mine');
    panel.classList.remove('inst');
    panel.classList.add('pin');
    document.getElementById('get-title').textContent = title;
    openEditor(t);
    document.getElementById('f-title').focus();
  }
  function formFill(t) {
    FIELDS.forEach(function(k) { document.getElementById('f-' + k).value = t[k] || ''; });
    pickFromHex();
  }
  function formRead() {
    var t = {};
    FIELDS.forEach(function(k) { t[k] = document.getElementById('f-' + k).value.trim(); });
    return t;
  }
  // the colour chip and the hex box are one value
  function pickFromHex() {
    var hex = document.getElementById('f-color').value.trim();
    if (/^#[0-9a-f]{6}$/i.test(hex)) document.getElementById('f-color-pick').value = hex;
  }
  document.getElementById('f-color').oninput = pickFromHex;
  document.getElementById('f-color-pick').oninput = function() {
    document.getElementById('f-color').value = this.value;
  };
  // the editor's current content, whichever face is up. null = invalid JSON.
  function editorRead() {
    if (mode === 'form') return formRead();
    try { return JSON.parse(editJson.value); } catch(e) { return null; }
  }
  function openEditor(t) {
    editStatus.textContent = '';
    formFill(t);
    editJson.value = JSON.stringify(t, null, 2);
    pinMode('form');
  }
  document.getElementById('edit-raw').onclick = function() {
    if (mode === 'form') {
      editJson.value = JSON.stringify(formRead(), null, 2);
      pinMode('json');
      return;
    }
    var t = editorRead();
    if (!t) {
      editStatus.textContent = 'Invalid JSON';
      editStatus.style.color = '#f87171';
      return;
    }
    editStatus.textContent = '';
    formFill(t);
    pinMode('form');
  };

  function addTile() {
    isNew = true;
    editName = 'tile-' + Date.now().toString(36);
    openPin('Pin a link', { title: '', href: '', info: '', color: '#333333', image: '' });
  }

  // the read-only card: a preview of the tile as it sits on the grid, then
  // its fields as labelled rows. Empty fields are left out.
  function fillCard(t) {
    var pv = document.getElementById('edit-preview');
    pv.style.background = t.color || '#333';
    var old = pv.querySelector('img');
    if (old) old.remove();
    if (t.image) {
      var im = document.createElement('img');
      im.src = t.image;
      im.onerror = function() { this.remove(); };
      pv.insertBefore(im, pv.firstChild);
    }
    document.getElementById('edit-preview-title').textContent = t.title || '';
    var dl = document.getElementById('edit-fields');
    dl.innerHTML = '';
    function row(label, node) {
      var dt = document.createElement('dt');
      dt.textContent = label;
      var dd = document.createElement('dd');
      dd.appendChild(node);
      dl.appendChild(dt);
      dl.appendChild(dd);
    }
    function text(s) { return document.createTextNode(s); }
    function mono(s) {
      var c = document.createElement('code');
      c.textContent = s;
      return c;
    }
    if (t.info) row('About', text(t.info));
    if (t.href) {
      var a = document.createElement('a');
      a.href = t.href;
      a.target = '_blank';
      a.textContent = t.href;
      row('Opens', a);
    }
    if (t.root) {
      row('App', mono(t.root));
    } else {
      row('Kind', text('pinned link, not tied to a desk'));
    }
    if (t.color) {
      var sw = document.createElement('span');
      sw.className = 'swatch';
      sw.style.background = t.color;
      var wrap = document.createElement('span');
      wrap.appendChild(sw);
      wrap.appendChild(mono(t.color));
      row('Color', wrap);
    }
    // an app's icon is served by the shell itself; only a pinned link's
    // image is something you chose
    if (t.image && t.image.indexOf('/grubbery/tiles/icon/') !== 0) row('Image', mono(t.image));
    if (t.hidden) row('Shown', text('hidden from the home grid'));
  }

  function viewTile(el, name) {
    var t = tileData[name];
    if (!t) return;
    // header shows the human name; the identity key (<slug>.json,
    // synthetic for app-derived tiles) stays out of sight
    var disp = name.slice(-5) === '.json' ? name.slice(0, -5) : name;
    editTitle.textContent = t.title || disp;
    editStatus.textContent = '';
    modalMode('view', t);
    fillCard(t);
    // a pinned link is yours to change; an app's tile comes from its desk
    document.getElementById('edit-edit').onclick = function() {
      isNew = false;
      editName = name;
      var content = {};
      FIELDS.forEach(function(k) { content[k] = t[k] || ''; });
      openPin('Edit ' + (t.title || name), content);
    };
    // an app comes and goes with its desk, which is removed from the
    // Installed tab; only a pinned link is deleted here
    var un = document.getElementById('edit-uninstall');
    un.style.display = t.root ? 'none' : '';
    un.textContent = 'delete tile';
    un.onclick = function() {
      editBack.classList.remove('open');
      deleteTile(name);
    };
    // hide / unhide this tile from the home grid (a user preference, stored
    // ship-side in hidden-tiles.json — any tile can be toggled)
    var hb = document.getElementById('edit-hide');
    hb.textContent = t.hidden ? 'unhide' : 'hide';
    hb.onclick = function() {
      editBack.classList.remove('open');
      fetch('/grubbery/tiles/visibility', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ name: name, hidden: !t.hidden })
      }).then(function() { loadTiles(); });
    };
    editBack.classList.add('open');
  }

  function deleteTile(name) {
    var el = document.querySelector('[data-tile="' + name + '"]');
    var title = el ? (el.querySelector('.tile-title') || {}).textContent || name : name;
    if (!confirm('Delete ' + title + '?')) return;
    fetch(API + '/file/' + BALL + '/tiles/' + name + '/tile.json', {method: 'DELETE'})
      .then(function() { loadTiles(); });
  }

  document.getElementById('edit-close').onclick = function() {
    editBack.classList.remove('open');
  };

  editBack.onclick = function(e) {
    if (e.target === editBack) editBack.classList.remove('open');
  };

  document.getElementById('edit-save').onclick = async function() {
    var parsed = editorRead();
    if (!parsed) {
      editStatus.textContent = 'Invalid JSON';
      editStatus.style.color = '#f87171';
      return;
    }
    if (!parsed.title) {
      editStatus.textContent = 'A title is needed';
      editStatus.style.color = '#f87171';
      return;
    }
    var method = isNew ? 'PUT' : 'POST';
    var endpoint = isNew ? '/file/' : '/over/';
    var r = await fetch(API + endpoint + BALL + '/tiles/' + editName + '/tile.json?blot=/json', {
      method: method,
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify(parsed)
    });
    if (r.ok) {
      editStatus.textContent = 'Saved';
      editStatus.style.color = '#4ade80';
      setTimeout(function() { instBack(); loadTiles(); }, 400);
    } else {
      editStatus.textContent = 'Save failed';
      editStatus.style.color = '#f87171';
    }
  };

  loadTiles();

  // -- get apps from ships --
  var peerGroups = [];
  function escP(s) {
    var d = document.createElement('div');
    d.textContent = (s == null) ? '' : String(s);
    return d.innerHTML;
  }
  function peerSpin() {
    document.getElementById('peer-lists').innerHTML =
      '<div class="peer-spin"><div class="spinner"></div></div>';
  }
  // one panel for getting apps: three tabs (a ship's published desks,
  // the recommended desks that ship with grubbery, what is installed) and
  // a footer for the thing that is not an app at all, a pinned link
  function openAdd(which) {
    instBack();
    document.getElementById('get-backdrop').classList.add('open');
    addTab(which || 'ships');
  }
  function addTab(which) {
    var tabs = document.querySelectorAll('#add-tabs .dtab');
    for (var i = 0; i < tabs.length; i++) {
      tabs[i].classList.toggle('active', tabs[i].getAttribute('data-tab') === which);
    }
    var views = document.querySelectorAll('.add-view');
    for (var j = 0; j < views.length; j++) {
      views[j].style.display = views[j].id === which + '-view' ? '' : 'none';
    }
    if (which === 'ships') {
      subTab('ship');
    } else {
      document.getElementById('pub-sheet').style.display = 'none';
      document.getElementById('desks-list').style.display = '';
      loadDesks();
    }
  }
  // the Install tab's three ways in: a ship's published desks, the forge's
  // repos, or a source typed by hand
  function subTab(which) {
    var tabs = document.querySelectorAll('#sub-tabs .stab');
    for (var i = 0; i < tabs.length; i++) {
      tabs[i].classList.toggle('active', tabs[i].getAttribute('data-sub') === which);
    }
    var views = document.querySelectorAll('.sub-view');
    for (var j = 0; j < views.length; j++) {
      views[j].style.display = views[j].id === 'sub-' + which ? '' : 'none';
    }
    if (which === 'ship') {
      peerSpin();
      loadContacts();
      loadPeers();
      document.getElementById('peer-ship').focus();
    } else if (which === 'forge') {
      loadForgeRepos();
    } else if (which === 'stock') {
      loadStock();
    } else {
      document.getElementById('src-name').focus();
    }
  }
  // a button the user just clicked can vanish under a re-render (Get,
  // remove, publishing); the browser then scrolls the overflow-hidden
  // panel sideways to chase the focus. Every re-render settles it.
  function settlePanel() {
    if (document.activeElement && document.activeElement !== document.body) document.activeElement.blur();
    var p = document.getElementById('get-panel');
    if (p) p.scrollLeft = 0;
  }
  function closeGet(e) {
    if (e.target === document.getElementById('get-backdrop')) closeGetNow();
  }
  function closeGetNow() {
    document.getElementById('get-backdrop').classList.remove('open');
  }
  function loadStock() {
    var box = document.getElementById('stock-list');
    box.innerHTML = '<div class="peer-spin"><div class="spinner"></div></div>';
    fetch('/grubbery/tiles/desks/stock')
      .then(function(r) { return r.json(); })
      .then(function(items) {
        box.innerHTML = '';
        settlePanel();
        if (!items.length) { box.innerHTML = '<div class="papp-none">nothing recommended.</div>'; return; }
        items.forEach(function(it) {
          var row = document.createElement('div');
          row.className = 'papp';
          row.innerHTML =
            '<div class="papp-body">' +
              '<div class="papp-title">' + escP(it.name) + '</div>' +
              '<div class="papp-sub">' + escP(it.repo) + ' · ' + escP(it.ref) + '</div>' +
            '</div>' +
            (it.synced
              ? '<button class="papp-get" disabled>Installed</button>'
              : '<button class="papp-get" data-name="' + escP(it.name) + '" onclick="syncOne(this)">Install</button>');
          box.appendChild(row);
        });
        if (items.some(function(it) { return !it.synced; })) {
          var foot = document.createElement('div');
          foot.className = 'stock-foot';
          foot.innerHTML = '<button class="hdr-btn primary" onclick="syncDefaults(this)">Install all</button>';
          box.appendChild(foot);
        }
      })
      .catch(function(e) {
        box.innerHTML = '<div class="papp-none">failed to load stock: ' + escP(String((e && e.message) || e)) + '</div>';
      });
  }
  function loadDesks() {
    var box = document.getElementById('desks-list');
    box.innerHTML = '<div class="peer-spin"><div class="spinner"></div></div>';
    fetch('/grubbery/tiles/desks/list')
      .then(function(r) { return r.json(); })
      .then(function(desks) {
        box.innerHTML = '';
        settlePanel();
        if (!desks.length) { box.innerHTML = '<div class="papp-none">no desks yet.</div>'; return; }
        desks.forEach(function(d) {
          var src = d.source || '';
          var srcLabel = src ? ((src[0] === '~' ? 'foreign source: ' : 'local source: ') + src) : 'no source';
          var url = d.url || ('/grubbery/desk/' + String(d.name).split('.')[0]);
          var row = document.createElement('div');
          row.className = 'papp';
          var share = d.share || [];
          var badge = '<span class="stock-badge ' + (share.length ? 'ok' : 'no') + '">' + escP(shareLabel(share)) + '</span>';
          row.innerHTML =
            '<div class="papp-body">' +
              '<div class="papp-title">' + escP(d.name) + ' ' + badge + '</div>' +
              '<div class="papp-sub">' + escP(srcLabel) + '</div>' +
            '</div>' +
            '<button class="papp-pub" data-pub="' + escP(d.name) + '">publishing</button>' +
            '<a class="papp-get" href="' + escP(url) + '">Open</a>' +
            '<button class="papp-un" data-desk="' + escP(d.name) + '">remove</button>';
          box.appendChild(row);
        });
        Array.prototype.forEach.call(box.querySelectorAll('[data-desk]'), function(b) {
          b.onclick = function() { removeDesk(b.getAttribute('data-desk'), b); };
        });
        Array.prototype.forEach.call(box.querySelectorAll('[data-pub]'), function(b) {
          b.onclick = function() {
            var name = b.getAttribute('data-pub');
            var d = desks.filter(function(x) { return x.name === name; })[0];
            openPublish(d);
          };
        });
      })
      .catch(function(e) {
        box.innerHTML = '<div class="papp-none">failed to load desks: ' + escP(String((e && e.message) || e)) + '</div>';
      });
  }
  // what a desk's publish button says: who may follow it
  function shareLabel(share) {
    if (!share.length) return 'private';
    if (share.indexOf('/public') >= 0) return 'public';
    return share.length === 1 ? share[0] : share.length + ' groups';
  }
  // the publish sheet: every usergroup on this ship with a tick for the
  // ones this desk is open to; a tick posts the share command and the
  // follower rebuilds the public listing behind it
  var pubDesk = null;
  function openPublish(d) {
    pubDesk = d;
    document.getElementById('pub-title').textContent = 'Publish ' + d.name.replace(/\.desk$/, '');
    document.getElementById('desks-list').style.display = 'none';
    document.getElementById('pub-sheet').style.display = '';
    settlePanel();
    var box = document.getElementById('pub-groups');
    box.innerHTML = '<div class="peer-spin"><div class="spinner"></div></div>';
    fetch('/apps/grubbery/peers.json')
      .then(function(r) { return r.json(); })
      .then(function(groups) {
        box.innerHTML = '';
        groups.sort(function(a, b) { return a.public ? -1 : b.public ? 1 : a.name < b.name ? -1 : 1; });
        groups.forEach(function(g) {
          var on = (d.share || []).indexOf(g.name) >= 0;
          var row = document.createElement('label');
          row.className = 'pub-row';
          var who = g.public ? 'every ship' : (g.members.length + ' ship' + (g.members.length === 1 ? '' : 's'));
          row.innerHTML =
            '<input type="checkbox"' + (on ? ' checked' : '') + '>' +
            '<span class="pub-name">' + escP(g.name) + '</span>' +
            '<span class="pub-who">' + escP(who) + '</span>';
          var cb = row.querySelector('input');
          cb.onchange = function() {
            cb.disabled = true;
            var cmd = { name: d.name.replace(/\.desk$/, '') };
            cmd[cb.checked ? 'add' : 'remove'] = g.name;
            fetch('/grubbery/tiles/desks/share', {
              method: 'POST',
              headers: { 'content-type': 'application/json' },
              body: JSON.stringify(cmd)
            }).then(function(r) {
              cb.disabled = false;
              if (!r.ok) { cb.checked = !cb.checked; return; }
              d.share = (d.share || []).filter(function(x) { return x !== g.name; });
              if (cb.checked) d.share.push(g.name);
            });
          };
          box.appendChild(row);
        });
        if (!groups.length) box.innerHTML = '<div class="papp-none">no usergroups on this ship.</div>';
      })
      .catch(function(e) {
        box.innerHTML = '<div class="papp-none">failed to load groups: ' + escP(String((e && e.message) || e)) + '</div>';
      });
  }
  function closePublish() {
    pubDesk = null;
    document.getElementById('pub-sheet').style.display = 'none';
    document.getElementById('desks-list').style.display = '';
    loadDesks();
  }
  // remove a whole desk and every app it ships, from the Installed tab
  function removeDesk(name, btn) {
    var word = name.replace(/\.desk$/, '');
    var msg = 'CAREFUL: this removes the whole desk "' + word + '" and every app it ships. '
      + 'All their data is permanently deleted. Type "' + word + '" to confirm:';
    if (prompt(msg) !== word) return;
    btn.disabled = true; btn.textContent = 'removing…';
    fetch('/grubbery/tiles/uninstall', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ root: '/apps/shell/desks/' + name })
    }).then(function(r) {
      // a refused uninstall used to land here unread: the button said
      // "removing…", the list reloaded unchanged, and the desk was still
      // there with nothing said. Say what happened instead.
      if (!r.ok) {
        return r.text().then(function(t) {
          btn.disabled = false;
          btn.textContent = 'remove';
          alert('remove failed (' + r.status + '): ' + (t || 'no reason given'));
        });
      }
      setTimeout(loadDesks, 800);
      setTimeout(loadTiles, 1000);
    });
  }
  function syncOne(btn) {
    var name = btn.getAttribute('data-name');
    var orig = btn.textContent;
    btn.disabled = true; btn.textContent = 'Installing…';
    fetch('/grubbery/tiles/desks/sync', {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ name: name })
    })
      .then(function() { loadStock(); })
      .catch(function(e) {
        alert('sync failed: ' + String((e && e.message) || e));
        btn.disabled = false; btn.textContent = orig;
      });
  }
  function syncDefaults(btn) {
    if (btn) { btn.disabled = true; btn.textContent = 'Installing…'; }
    fetch('/grubbery/tiles/desks/sync-defaults', {
      method: 'POST', headers: { 'content-type': 'application/json' }, body: '{}'
    })
      .then(function() { loadStock(); })
      .catch(function(e) { alert('install failed: ' + String((e && e.message) || e)); })
      .then(function() { if (btn) { btn.disabled = false; btn.textContent = 'Install all'; } });
  }
  // the typed source: any spelling the desk nexus takes. The name and
  // permissions screen is the same one a picked app gets.
  function installFromForm() {
    var name = document.getElementById('src-name').value.trim();
    var code = document.getElementById('src-code').value.trim();
    if (!code) { document.getElementById('src-code').focus(); return; }
    if (!name) {
      // the source's last real segment is a fair default name
      name = code.replace(/\/+$/, '').split('/').filter(function(s) { return s && s !== 'code'; }).pop() || '';
      name = name.replace(/\.(git_repo|desk)$/, '');
    }
    openInstall({ name: name, code: code, title: name, source: code }, null);
  }
  // the forge's repos: each one a source a desk can follow
  function loadForgeRepos() {
    var box = document.getElementById('forge-list');
    box.innerHTML = '<div class="peer-spin"><div class="spinner"></div></div>';
    fetch('/grubbery/tiles/desks/forge-repos')
      .then(function(r) { return r.json(); })
      .then(function(repos) {
        box.innerHTML = '';
        settlePanel();
        if (!repos.length) { box.innerHTML = '<div class="papp-none">no repos in your forge yet.</div>'; return; }
        repos.forEach(function(rp) {
          var row = document.createElement('div');
          row.className = 'papp';
          row.innerHTML =
            '<div class="papp-body">' +
              '<div class="papp-title">' + escP(rp.name) + '</div>' +
              '<div class="papp-sub">' + escP(rp.code) + '</div>' +
            '</div>' +
            (rp.ready
              ? '<button class="papp-get">Get</button>'
              : '<button class="papp-get" disabled title="this repo has no /code yet">no code</button>');
          var b = row.querySelector('button');
          if (rp.ready) b.onclick = function() {
            openInstall({ name: rp.name, code: rp.code, title: rp.name, source: 'your forge' }, b);
          };
          box.appendChild(row);
        });
      })
      .catch(function(e) {
        box.innerHTML = '<div class="papp-none">failed to load forge repos: ' + escP(String((e && e.message) || e)) + '</div>';
      });
  }
  function peerPost(path, body) {
    return fetch('/grubbery/tiles/desks/' + path, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body)
    });
  }
  function peerAdd() {
    var inp = document.getElementById('peer-ship');
    var s = inp.value.trim();
    if (!s) return;
    if (s[0] !== '~') s = '~' + s;
    peerSpin();
    peerPost('peers', { add: s }).then(function() {
      inp.value = '';
      setTimeout(loadPeers, 1500);
    });
  }
  function peerDel(s) {
    peerPost('peers', { del: s }).then(function() { setTimeout(loadPeers, 500); });
  }
  // btn is the picker row's button when there is one; a typed source has
  // none, and its outcome shows in the Installed tab and the grid
  function installPeerApp(a, btn, name) {
    function say(text, enabled) { if (btn) { btn.textContent = text; btn.disabled = !enabled; } }
    say('installing...', false);
    var body = { name: name || a.name, code: a.code };
    peerPost('add', body)
      .then(function(r) {
        if (r.status === 409) {
          var alt = prompt('A desk named "' + (name || a.name) + '" already exists here. Install under a different name:');
          if (alt && alt.trim()) { installPeerApp(a, btn, alt.trim()); return; }
          say('Get', true);
          return;
        }
        if (!r.ok) {
          say('failed', true);
          if (!btn) alert('install failed: ' + r.status);
          return;
        }
        say('installed', false);
        if (!btn) {
          document.getElementById('src-name').value = '';
          document.getElementById('src-code').value = '';
          addTab('mine');
        }
        setTimeout(loadTiles, 1200);
        setTimeout(loadPeers, 1500);
      });
  }
  function weirLines(v) {
    return v.split(String.fromCharCode(10)).map(function(s) { return s.trim(); })
      .filter(function(s) { return s.charAt(0) === '/' || s.slice(0, 2) === '..'; });
  }
  function openInstall(a, btn) {
    fetch('/grubbery/tiles/desks/taken')
      .then(function(r) { return r.json(); })
      .then(function(taken) { renderInstall(a, btn, taken); });
  }
  function instBack() {
    var panel = document.getElementById('get-panel');
    panel.classList.remove('inst');
    panel.classList.remove('pin');
    document.getElementById('get-title').textContent = 'Install';
    settlePanel();
  }
  function renderInstall(a, btn, taken) {
    var ov = document.getElementById('inst-screen');
    var icon = a.icon
      ? '<img class="papp-icon" src="' + escP(a.icon) + '">'
      : '<div class="papp-icon" style="background:' + escP(a.color || '#8558b0') + '"></div>';
    ov.innerHTML =
      '<div class="inst-app">' + icon +
        '<div><div class="inst-app-title">' + escP(a.title || a.name) + '</div>' +
        '<div class="inst-app-sub">from ' + escP(a.ship || a.source || '') + '</div></div></div>' +
      '<label class="inst-lab">install as</label>' +
        '<div class="inst-row"><span class="inst-pre">/apps/shell/desks/</span>' +
          '<input id="inst-name" spellcheck="false">' +
          '<span class="inst-pre">.desk</span></div>' +
        '<div id="inst-avail"></div>' +
        '<label class="inst-lab">permissions</label>' +
      '<div class="inst-note">Installs <b>fully sandboxed</b> — the app cannot read, message, ' +
        'or write anything outside its own folder. If it needs more, it declares each path it ' +
        'wants and you review and grant them in <a href="/apps/grubbery/permits">Sandbox ' +
        'Settings</a> after install.</div>' +
      '';
    document.getElementById('inst-foot').innerHTML =
      '<button id="inst-cancel">cancel</button>' +
      '<button class="go" id="inst-go">install</button>';
    document.getElementById('get-panel').classList.add('inst');
    settlePanel();
    document.getElementById('get-title').textContent = 'Install ' + (a.title || a.name);
    var nameInp = ov.querySelector('#inst-name');
    var avail = ov.querySelector('#inst-avail');
    var go = document.getElementById('inst-go');
    nameInp.value = a.name;
    function checkName() {
      var n = nameInp.value.trim();
      if (!n) { avail.textContent = ''; go.disabled = true; return; }
      var dir = n + '.desk';
      var bad = taken.indexOf(dir) >= 0;
      avail.textContent = '/apps/shell/desks/' + dir + (bad ? ' is taken' : ' is available');
      avail.className = bad ? 'bad' : 'ok';
      go.disabled = bad;
    }
    nameInp.oninput = checkName;
    checkName();
    document.getElementById('inst-cancel').onclick = instBack;
    go.onclick = function() {
      instBack();
      installPeerApp(a, btn, nameInp.value.trim());
    };
  }
  function uninstallPeerApp(a, btn) {
    var word = prompt('CAREFUL: this permanently deletes ' + a.local + ' and all its data. Type "' + a.local + '" to confirm:');
    if (word !== a.local) return;
    btn.disabled = true;
    btn.textContent = 'removing...';
    peerPost('delete', { app: a.local })
      .then(function() {
        setTimeout(loadPeers, 800);
        setTimeout(loadTiles, 1000);
      });
  }
  function loadPeers() {
    fetch('/grubbery/tiles/desks/peers')
      .then(function(r) { return r.json(); })
      .then(function(groups) {
        peerGroups = groups;
        var box = document.getElementById('peer-lists');
        box.innerHTML = '';
        settlePanel();
        if (!groups.length) {
          box.innerHTML = '<div class="papp-none">no ships yet. search for one above.</div>';
          return;
        }
        groups.forEach(function(g, gi) {
          var div = document.createElement('div');
          var apps = (g.apps || []).map(function(a, ai) {
            var icon = a.icon
              ? '<img class="papp-icon" src="' + escP(a.icon) + '">'
              : '<div class="papp-icon" style="background:' + escP(a.color || '#8558b0') + '"></div>';
            return '<div class="papp">' + icon +
              '<div class="papp-body">' +
                '<div class="papp-title">' + escP(a.title || a.name) + '</div>' +
                '<div class="papp-sub">' + escP(a.path) + '</div>' +
              '</div>' +
              (a.installed
                ? '<button class="papp-get" disabled>Installed</button>' +
                  '<button class="papp-un" data-ug="' + gi + '" data-ua="' + ai + '">uninstall</button>'
                : '<button class="papp-get" data-g="' + gi + '" data-a="' + ai + '">Get</button>') +
            '</div>';
          }).join('');
          div.innerHTML =
            '<div class="peer-head"><b>' + escP(g.ship) + '</b>' +
            '<button class="peer-rm" data-ship="' + escP(g.ship) + '">remove</button></div>' +
            (apps || '<div class="papp-none">nothing published</div>');
          box.appendChild(div);
        });
        Array.prototype.forEach.call(box.querySelectorAll('[data-g]'), function(b) {
          b.onclick = function() {
            openInstall(peerGroups[+b.getAttribute('data-g')].apps[+b.getAttribute('data-a')], b);
          };
        });
        Array.prototype.forEach.call(box.querySelectorAll('[data-ug]'), function(b) {
          b.onclick = function() {
            uninstallPeerApp(peerGroups[+b.getAttribute('data-ug')].apps[+b.getAttribute('data-ua')], b);
          };
        });
        Array.prototype.forEach.call(box.querySelectorAll('[data-ship]'), function(b) {
          b.onclick = function() { peerDel(b.getAttribute('data-ship')); };
        });
      })
      .catch(function(e) {
        document.getElementById('peer-lists').innerHTML =
          '<div class="papp-none">failed to load peers: ' + escP(String((e && e.message) || e)) + '</div>';
      });
  }
  var peerContacts = [];
  function loadContacts() {
    fetch('/grubbery/contacts/api/overlays')
      .then(function(r) { return r.json(); })
      .then(function(data) {
        peerContacts = Object.keys(data).map(function(ship) {
          var f = data[ship] || {};
          var nick = (f.nickname && f.nickname.s) || f.nickname || '';
          if (typeof nick !== 'string') nick = '';
          return { ship: ship, nick: nick, sort: nick ? nick.toLowerCase() : ship };
        });
        peerContacts.sort(function(a, b) { return a.sort < b.sort ? -1 : a.sort > b.sort ? 1 : 0; });
      })
      .catch(function() { peerContacts = []; });
  }
  function hideSuggest() {
    document.getElementById('peer-suggest').classList.remove('open');
  }
  function renderSuggest() {
    var box = document.getElementById('peer-suggest');
    var raw = document.getElementById('peer-ship').value.trim();
    if (!raw) { hideSuggest(); return; }
    var q = raw.toLowerCase().replace(/^~/, '');
    var have = {};
    peerGroups.forEach(function(g) { have[g.ship] = true; });
    var matches = peerContacts.filter(function(c) {
      if (have[c.ship]) return false;
      if (!q) return true;
      return c.ship.replace('~', '').indexOf(q) >= 0 || c.nick.toLowerCase().indexOf(q) >= 0;
    }).slice(0, 8);
    if (!matches.length) { hideSuggest(); return; }
    box.innerHTML = matches.map(function(c) {
      return '<div class="psug" data-ship="' + escP(c.ship) + '">' +
        (c.nick ? '<span class="psug-nick">' + escP(c.nick) + '</span>' : '') +
        '<span class="psug-ship">' + escP(c.ship) + '</span></div>';
    }).join('');
    Array.prototype.forEach.call(box.querySelectorAll('.psug'), function(row) {
      row.onmousedown = function(e) {
        e.preventDefault();
        document.getElementById('peer-ship').value = row.getAttribute('data-ship');
        hideSuggest();
        peerAdd();
      };
    });
    box.classList.add('open');
  }
  var peerInp = document.getElementById('peer-ship');
  peerInp.addEventListener('keydown', function(e) {
    if (e.key === 'Enter') { hideSuggest(); peerAdd(); }
    if (e.key === 'Escape') hideSuggest();
  });
  peerInp.addEventListener('input', renderSuggest);
  peerInp.addEventListener('focus', renderSuggest);
  peerInp.addEventListener('blur', function() { setTimeout(hideSuggest, 150); });
