var API='/grubbery/api';var BALL='apps/tiles.tiles';
  // inbox bell: landscape-style notifications panel over the tiles
  var NBALL = 'apps/notifications.notifications';
  var bellNotes = [];

  function bellFetch() {
    return fetch('/grubbery/ball/' + NBALL + '/inbox.inbox?blot=/json')
      .then(function(r) { return r.json(); })
      .then(function(ns) { bellNotes = ns || []; bellBadge(); })
      .catch(function() {});
  }

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
    var anyUnacked = bellNotes.some(function(n) { return n.mack == null; });
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
    var un = bellNotes.filter(function(n) { return n.mack == null; });
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

  function renderTiles(tiles) {
    tileData = {};
    tiles.forEach(function(t) { tileData[t.name] = t; });
    var loading = document.getElementById('loading-tile');
    tilesDiv.innerHTML = '';
    if (!tiles.length) {
      tilesDiv.innerHTML = '<div class="empty">no tiles yet</div>';
    } else {
      tiles.forEach(function(t) {
        var d = document.createElement('div');
        d.className = t.image ? 'tile has-img' : 'tile';
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
        tilesDiv.appendChild(d);
      });
      if (loading) tilesDiv.appendChild(loading);
    }
  }

  function loadTiles() {
    fetch('/grubbery/tiles/tiles.json')
      .then(function(r) { return r.json(); })
      .then(renderTiles)
      .catch(function() { tilesDiv.innerHTML = '<div class="empty">failed to load tiles</div>'; });
  }

  function addTile() {
    isNew = true;
    editName = 'tile-' + Date.now().toString(36);
    editTitle.textContent = 'New tile';
    editStatus.textContent = '';
    editJson.disabled = false;
    document.getElementById('edit-save').style.display = '';
    editJson.value = JSON.stringify({
      image: '',
      title: 'New tile',
      href: '',
      color: '#333',
      info: ''
    }, null, 2);
    editBack.classList.add('open');
  }

  function viewTile(el, name) {
    var t = tileData[name];
    if (!t) return;
    // header shows the human name; the identity key (<slug>.json,
    // synthetic for app-derived tiles) stays out of sight
    var disp = name.slice(-5) === '.json' ? name.slice(0, -5) : name;
    editTitle.textContent = t.title || disp;
    editStatus.textContent = '';
    // name is the tile's identity key (its filename), stapled on by the
    // /tiles.json API -- not part of the grub's content, so don't show it
    var content = Object.assign({}, t);
    delete content.name;
    editJson.value = JSON.stringify(content, null, 2);
    editJson.disabled = true;
    document.getElementById('edit-save').style.display = 'none';
    editBack.classList.add('open');
  }

  function deleteTile(name) {
    var el = document.querySelector('[data-tile="' + name + '"]');
    var title = el ? (el.querySelector('.tile-title') || {}).textContent || name : name;
    if (!confirm('Delete ' + title + '?')) return;
    fetch(API + '/file/' + BALL + '/tiles/' + name + '/tile', {method: 'DELETE'})
      .then(function() { loadTiles(); });
  }

  document.getElementById('edit-close').onclick = function() {
    editBack.classList.remove('open');
  };

  editBack.onclick = function(e) {
    if (e.target === editBack) editBack.classList.remove('open');
  };

  document.getElementById('edit-save').onclick = async function() {
    var parsed;
    try { parsed = JSON.parse(editJson.value); } catch(e) {
      editStatus.textContent = 'Invalid JSON';
      editStatus.style.color = '#f87171';
      return;
    }
    var method = isNew ? 'PUT' : 'POST';
    var endpoint = isNew ? '/file/' : '/over/';
    var r = await fetch(API + endpoint + BALL + '/tiles/' + editName + '/tile?blot=/json', {
      method: method,
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify(parsed)
    });
    if (r.ok) {
      editStatus.textContent = 'Saved';
      editStatus.style.color = '#4ade80';
      setTimeout(function() { editBack.classList.remove('open'); loadTiles(); }, 400);
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
  function openGet() {
    instBack();
    document.getElementById('get-backdrop').classList.add('open');
    peerSpin();
    loadContacts();
    loadPeers();
    document.getElementById('peer-ship').focus();
  }
  function closeGet(e) {
    if (e.target === document.getElementById('get-backdrop')) closeGetNow();
  }
  function closeGetNow() {
    document.getElementById('get-backdrop').classList.remove('open');
  }
  function peerPost(path, body) {
    return fetch('/grubbery/desks/' + path, {
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
  function installPeerApp(a, btn, name, weir) {
    btn.disabled = true;
    btn.textContent = 'installing...';
    var body = { name: name || a.name, type: 'cross-ship', source: a.source };
    if (weir !== undefined) body.weir = weir;
    peerPost('add', body)
      .then(function(r) {
        if (r.status === 409) {
          var alt = prompt('A desk named "' + (name || a.name) + '" already exists here. Install under a different name:');
          if (alt && alt.trim()) { installPeerApp(a, btn, alt.trim(), weir); return; }
          btn.textContent = 'Get';
          btn.disabled = false;
          return;
        }
        if (!r.ok) {
          btn.textContent = 'failed';
          btn.disabled = false;
          return;
        }
        btn.textContent = 'installed';
        setTimeout(loadTiles, 1200);
        setTimeout(loadPeers, 1500);
      });
  }
  function weirLines(v) {
    return v.split(String.fromCharCode(10)).map(function(s) { return s.trim(); })
      .filter(function(s) { return s.charAt(0) === '/' || s.slice(0, 2) === '..'; });
  }
  function openInstall(a, btn) {
    fetch('/grubbery/desks/taken')
      .then(function(r) { return r.json(); })
      .then(function(taken) { renderInstall(a, btn, taken); });
  }
  function instBack() {
    document.getElementById('get-panel').classList.remove('inst');
    document.getElementById('get-title').textContent = 'Get apps';
  }
  function renderInstall(a, btn, taken) {
    var ov = document.getElementById('inst-screen');
    var icon = a.icon
      ? '<img class="papp-icon" src="' + escP(a.icon) + '">'
      : '<div class="papp-icon" style="background:' + escP(a.color || '#8558b0') + '"></div>';
    ov.innerHTML =
      '<div class="inst-app">' + icon +
        '<div><div class="inst-app-title">' + escP(a.title || a.name) + '</div>' +
        '<div class="inst-app-sub">from ' + escP(a.source || '') + '</div></div></div>' +
      '<label class="inst-lab">install as</label>' +
        '<div class="inst-row"><span class="inst-pre">/apps/</span>' +
          '<input id="inst-name" spellcheck="false">' +
          '<span class="inst-pre">.desk</span></div>' +
        '<div id="inst-avail"></div>' +
        '<label class="inst-lab">permissions <span class="inst-wip">— templates are a work in progress</span></label>' +
        '<div class="inst-warn">' +
          '<b>Warning</b> — these permissions sandbox the app&#39;s backend (its ship-side ' +
          'processes). Two things they do not cover:' +
          '<ul>' +
            '<li><b>The frontend.</b> Opening the app&#39;s web page while logged in gives that ' +
              'page full access to your ship through your session, regardless of these settings.</li>' +
            '<li><b>Reads, even from the backend.</b> Until Arvo offers a +mule alternative that ' +
              'neutralizes dotket (.^), any grub can scry the entire namespace reachable via dotket, ' +
              'bypassing the read restrictions here — so %grubbery is not yet secure in that respect.</li>' +
          '</ul>' +
        '</div>' +
        '<label class="inst-opt"><input type="radio" name="inst-weir" value="standard" checked>' +
          '<span><b>trusted</b> — full access: can read and message anything on your ship; only creates, edits, or deletes files in its own directory</span></label>' +
        '<label class="inst-opt"><input type="radio" name="inst-weir" value="readonly">' +
          '<span><b>read-only</b> — headless: can compute, keep time, and read and write its own files, ' +
          'plus read anything on your ship; no interface, no network, no cross-ship, and messages nothing ' +
          'and changes nothing outside its own folder</span></label>' +
        '<label class="inst-opt"><input type="radio" name="inst-weir" value="sandboxed">' +
          '<span><b>sandboxed</b> — headless: can compute, keep time, and read and write its own files; ' +
          'no interface, no network, no cross-ship, and cannot read or touch anything else</span></label>' +
        '<label class="inst-opt"><input type="radio" name="inst-weir" value="open">' +
          '<span><b>unrestricted</b> — no sandbox at all; can also create files anywhere</span></label>' +
        '<label class="inst-opt"><input type="radio" name="inst-weir" value="custom">' +
          '<span><b>custom</b> — one path per line; ../ is relative to the app folder; empty = closed. ' +
          'Add /sys/iris for internet access, /sys/gall to message agents, etc.</span></label>' +
        '<div id="inst-roads">' +
          '<label class="inst-lab">create (make)</label>' +
          '<textarea id="inst-make" placeholder="(closed)"></textarea>' +
          '<label class="inst-lab">message (poke)</label>' +
          '<textarea id="inst-poke" placeholder="(closed)"></textarea>' +
          '<label class="inst-lab">read (peek)</label>' +
          '<textarea id="inst-peek" placeholder="(closed)"></textarea>' +
          '<div class="inst-hint">One path per line. A trailing slash means a whole directory ' +
            '(<code>/apps/notes/</code>); no slash means a single file (<code>/apps/notes/data.json</code>). ' +
            'Start with <code>../</code> to reach outside this app&#39;s own folder ' +
            '(<code>../weather/</code>, <code>../notes/config.json</code>). An empty box is closed.</div>' +
        '</div>' +
        '<div id="inst-unrestricted" style="display:none">no sandbox — this app can create, message, and read anywhere on your ship.</div>';
    document.getElementById('inst-foot').innerHTML =
      '<button id="inst-cancel">cancel</button>' +
      '<button class="go" id="inst-go">install</button>';
    document.getElementById('get-panel').classList.add('inst');
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
      avail.textContent = '/apps/' + dir + (bad ? ' is taken' : ' is available');
      avail.className = bad ? 'bad' : 'ok';
      go.disabled = bad;
    }
    nameInp.oninput = checkName;
    checkName();
    var LF = String.fromCharCode(10);
    var PRESET_ROADS = {
      standard: { make: '', poke: '/', peek: '/' },
      readonly: { make: '', poke: '/sys/bowl.sig' + LF + '/sys/behn/', peek: '/' },
      sandboxed: { make: '', poke: '/sys/bowl.sig' + LF + '/sys/behn/', peek: '' }
    };
    var lastPreset = 'standard';
    function applyPreset() {
      var mode = ov.querySelector('input[name=inst-weir]:checked').value;
      var open = mode === 'open';
      ov.querySelector('#inst-roads').style.display = open ? 'none' : 'block';
      ov.querySelector('#inst-unrestricted').style.display = open ? 'block' : 'none';
      if (open) return;
      ['make', 'poke', 'peek'].forEach(function(t) {
        var ta = ov.querySelector('#inst-' + t);
        if (mode === 'custom') {
          // editable, seeded from the last preset shown
          ta.value = PRESET_ROADS[lastPreset][t];
          ta.readOnly = false;
          ta.classList.remove('ro');
        } else {
          ta.value = PRESET_ROADS[mode][t];
          ta.readOnly = true;
          ta.classList.add('ro');
        }
      });
      if (mode !== 'custom') lastPreset = mode;
    }
    Array.prototype.forEach.call(ov.querySelectorAll('input[name=inst-weir]'), function(r) {
      r.onchange = applyPreset;
    });
    applyPreset();
    document.getElementById('inst-cancel').onclick = instBack;
    go.onclick = function() {
      var mode = ov.querySelector('input[name=inst-weir]:checked').value;
      var weir;
      if (mode === 'standard') weir = { preset: 'trusted' };
      if (mode === 'readonly') weir = { preset: 'readonly' };
      if (mode === 'sandboxed') weir = { preset: 'sandboxed' };
      if (mode === 'open') weir = 'open';
      if (mode === 'custom') weir = {
        make: weirLines(ov.querySelector('#inst-make').value),
        poke: weirLines(ov.querySelector('#inst-poke').value),
        peek: weirLines(ov.querySelector('#inst-peek').value)
      };
      instBack();
      installPeerApp(a, btn, nameInp.value.trim(), weir);
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
    fetch('/grubbery/desks/peers')
      .then(function(r) { return r.json(); })
      .then(function(groups) {
        peerGroups = groups;
        var box = document.getElementById('peer-lists');
        box.innerHTML = '';
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
                '<div class="papp-sub">' + escP(a.path) + (a.version ? ' - v' + escP(a.version) : '') + '</div>' +
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
