::  tiles nexus: customizable launcher grid
::
::  Each tile is a json file under /tiles/ with fields:
::    title, info, color, image, href
::  href can be absolute (https://...) or relative (/grubbery/ball/...)
::
/&  man  ../man/tiles/readme.md
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  landscape-tile=json
        %-  pairs:enjs:format
        :~  title+s+'Landscape'
            info+s+'Tlon'
            color+s+'#1a1a1a'
            href+s+'/apps/landscape'
        ==
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%fall %| /tiles empty-dir:loader]
          [%fall %& [/tiles %'landscape.json'] [[/ %json] landscape-tile]]
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %| /requests empty-dir:loader]
          [%over %& [/ %'README.md'] [[/ %mime] man]]
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%tiles main: failed")
        ;<  here=rail:tarball  bind:m  get-here-abs:io
        =/  ball-id=tape  (path-to-ball-id path.here)
        ;<  ~  bind:m  (bind-http:io [~ /apps/grubbery])
        ;<  ~  bind:m  (bind-http:io [~ /grubbery/tiles])
        (http-dispatch:io %tiles)
          ::
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%tiles request: failed")
        =/  eyre-id=@ta  name.rail
        ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
        ;<  our=@p  bind:m  get-our:io
        ?.  =(src our)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
          (pure:m ~)
        ;<  here=rail:tarball  bind:m  get-here-abs:io
        =/  ball-id=tape  (path-to-ball-id (snip path.here))
        =/  prefix=path  /grubbery/tiles
        =/  site=path  site:(parse-url:http-utils url.request.req)
        =/  suffix=path  (slag (lent prefix) site)
        ::  /tiles.json → all tile data
        ?:  ?=([%'tiles.json' ~] suffix)
          ;<  tiles=(list tile)  bind:m  (read-all-tiles rail)
          =/  =json  (tiles-to-json tiles)
          =/  body=octs  (as-octs:mimes:html (en:json:html json))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ['content-type' 'application/json'] ~] `body])
          (pure:m ~)
        ::  /icon/<slug> → serve icon from sibling app
        ?:  ?=([%icon @ ~] suffix)
          =/  slug=@ta  i.t.suffix
          ;<  apps=view:nexus  bind:m  (peek:io [%& %| /apps] ~)
          =/  kid=(unit @ta)
            ?.  ?=([%ball *] apps)  ~
            (find-app-by-slug slug dir.ball.apps)
          ?~  kid
            ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
            (pure:m ~)
          ;<  kid-root=view:nexus  bind:m
            (peek:io [%& %| /apps/[u.kid]] ~)
          =/  icon-file=(unit [name=@ta sang=sang:tarball])
            ?.  ?=([%ball *] kid-root)  ~
            =/  =lump:tarball  (fall fil.ball.kid-root *lump:tarball)
            %-  ~(rep by contents.lump)
            |=  [[n=@ta s=sang:tarball g=? b=(unit tang)] out=(unit [name=@ta sang=sang:tarball])]
            ?^  out  out
            =/  nam=tape  (trip n)
            ?.  =("icon." (scag 5 nam))  out
            `[n s]
          ?~  icon-file
            ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
            (pure:m ~)
          =/  =mime  !<(mime (need-vase:tarball sang.u.icon-file))
          ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils mime))
          (pure:m ~)
        ::  default → serve tiles page
        =/  page=@t  (crip (en-xml:html (tiles-page ball-id)))
        =/  =mime  [/text/html (as-octs:mimes:html page)]
        ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils mime))
        (pure:m ~)
      ==
    --
|%
+$  tile
  $:  name=@ta
      title=@t
      info=@t
      color=@t
      image=@t
      href=@t
  ==
::
++  srv  ~(. http-res:io [%| 1 %& ~ %'main.sig'])
::
++  path-to-ball-id
  |=  =path
  ^-  tape
  (zing (join "/" ^-((list tape) (turn path trip))))
::
++  read-tiles
  |=  =view:nexus
  ^-  (list tile)
  ?.  ?=([%ball *] view)  ~
  =/  =lump:tarball  (fall fil.ball.view *lump:tarball)
  %+  murn  ~(tap by contents.lump)
  |=  [name=@ta =sang:tarball gain=? bang=(unit tang)]
  ^-  (unit tile)
  ?.  ?=(%json name.p.sang)  ~
  (json-to-tile name sang)
::
++  json-to-tile
  |=  [name=@ta =sang:tarball]
  ^-  (unit tile)
  =/  jon=(unit json)  (mole |.(!<(json (need-vase:tarball sang))))
  ?~  jon  ~
  ?.  ?=(%o -.u.jon)  ~
  =/  m  p.u.jon
  :-  ~
  :*  name
      (fall (bind (~(get by m) 'title') |=(=json ?>(?=(%s -.json) p.json))) '')
      (fall (bind (~(get by m) 'info') |=(=json ?>(?=(%s -.json) p.json))) '')
      (fall (bind (~(get by m) 'color') |=(=json ?>(?=(%s -.json) p.json))) '#333')
      (fall (bind (~(get by m) 'image') |=(=json ?>(?=(%s -.json) p.json))) '')
      (fall (bind (~(get by m) 'href') |=(=json ?>(?=(%s -.json) p.json))) '')
  ==
::
++  read-app-tiles
  =/  m  (fiber:fiber:nexus ,(list [tile @ta]))
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io [%& %| /apps] ~)
  ?.  ?=([%ball *] view)
    (pure:m ~)
  =/  kids=(list [@ta ball:tarball])  ~(tap by dir.ball.view)
  =|  acc=(list [tile @ta])
  |-
  ?~  kids  (pure:m (flop acc))
  ?:  =('tiles.tiles' -.i.kids)
    $(kids t.kids)
  =/  kid=@ta  -.i.kids
  =/  slug=@ta  (app-slug kid)
  ;<  kid-view=view:nexus  bind:m
    (peek:io [%& %& /apps/[kid] %'tile.json'] `[/ %json])
  ?.  ?=([%file *] kid-view)
    $(kids t.kids)
  =/  tile-name=@ta  (crip "{(trip slug)}.json")
  =/  tile=(unit tile)  (json-to-tile tile-name sang.kid-view)
  ?~  tile  $(kids t.kids)
  $(kids t.kids, acc [[u.tile kid] acc])
::
++  app-slug
  |=  name=@ta
  ^-  @ta
  =/  nam=tape  (trip name)
  =/  dix=(unit @ud)  (find "." nam)
  ?~  dix  name
  (crip (scag u.dix nam))
::
++  find-app-by-slug
  |=  [slug=@ta kids=(map @ta ball:tarball)]
  ^-  (unit @ta)
  ::  an exact folder name always wins — slugs (the part before the first
  ::  dot) are ambiguous across e.g. test.guestbook / test.desk, and
  ::  guestbook's own tile hardcodes the full name in its icon URL.
  ?:  (~(has by kids) slug)  `slug
  =/  entries=(list [@ta ball:tarball])  ~(tap by kids)
  |-
  ?~  entries  ~
  ?:  =(slug (app-slug -.i.entries))
    `-.i.entries
  $(entries t.entries)
::
++  read-all-tiles
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,(list tile))
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io (nex-road:io rail [%| /tiles]) ~)
  =/  local=(list tile)  (read-tiles view)
  =/  local-names=(set @ta)  (sy (turn local |=(t=tile name.t)))
  ;<  app-pairs=(list [tile @ta])  bind:m  read-app-tiles
  =/  app=(list tile)  (turn app-pairs head)
  =/  merged=(list tile)
    %+  weld  local
    (skip app |=(t=tile (~(has in local-names) name.t)))
  (pure:m (sort merged |=([a=tile b=tile] (aor name.a name.b))))
::
++  tiles-to-json
  |=  tiles=(list tile)
  ^-  json
  :-  %a
  %+  turn  tiles
  |=  t=tile
  %-  pairs:enjs:format
  :~  name+s+name.t
      title+s+title.t
      info+s+info.t
      color+s+color.t
      image+s+image.t
      href+s+href.t
  ==
::
++  tiles-page
  |=  ball-id=tape
  ^-  manx
  ;html
    ;head
      ;title: tiles
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;style
        ;+  ;/  style-text
      ==
    ==
    ;body
      ;div#app
        ;div#header
          ;a#bell(href "#", onclick "openBell(event)", title "Notifications")
            ;+  ;/  "🔔"
            ;span#bell-count(style "display:none");
          ==
          ;button#add-btn.hdr-btn(onclick "addTile()"): + new
        ==
        ;div#bell-backdrop(onclick "closeBell(event)")
          ;div#bell-panel
            ;div#bell-head
              ;span: Notifications
              ;div
                ;button#bell-ack-all.hdr-btn(onclick "bellAckAll()"): Mark all as read
                ;button.hdr-btn(onclick "closeBellNow()"): close
              ==
            ==
            ;div#bell-notes;
          ==
        ==
        ;div#edit-backdrop
          ;div#edit-modal
            ;div#edit-header
              ;span#edit-title: Edit tile
              ;div
                ;button#edit-save.hdr-btn: save
                ;button#edit-close.hdr-btn: close
              ==
            ==
            ;textarea#edit-json(rows "10", placeholder "\{}");
            ;div#edit-status;
          ==
        ==
        ;div#tiles
          ;div#loading-tile
            ;div.spinner;
          ==
        ==
      ==
      ;script
        ;+  ;/  (script-text ball-id)
      ==
    ==
  ==
::
++  style-text
  ^-  tape
  """
  * \{ margin: 0; padding: 0; box-sizing: border-box; }
  body \{ font-family: Inter, sans-serif; background: white; min-height: 100vh; }
  #app \{ width: 100%; max-width: 800px; margin: 0 auto; padding: 40px 24px; }
  #header \{ display: flex; justify-content: flex-end; align-items: center; gap: 10px; margin-bottom: 32px; }
  #bell \{ position: relative; font-size: 17px; text-decoration: none; padding: 6px 10px; border-radius: 8px; border: 1px solid #ddd; line-height: 1; filter: grayscale(1); opacity: 0.75; }
  #bell:hover \{ background: #f5f5f5; filter: none; opacity: 1; }
  #bell.live \{ filter: none; opacity: 1; }
  #bell-count \{ position: absolute; top: -6px; right: -6px; background: #7a5ac0; color: white; font-size: 10px; font-weight: 700; min-width: 16px; height: 16px; border-radius: 8px; display: flex; align-items: center; justify-content: center; padding: 0 4px; }
  #bell-backdrop \{ display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.25); z-index: 100; align-items: center; justify-content: center; }
  #bell-backdrop.open \{ display: flex; }
  #bell-panel \{ width: min(460px, calc(100vw - 32px)); max-height: 80vh; background: white; border: 1px solid #bbb; border-radius: 14px; box-shadow: 0 16px 48px rgba(0,0,0,0.28); display: flex; flex-direction: column; overflow: hidden; }
  #bell-head \{ display: flex; justify-content: space-between; align-items: center; padding: 14px 16px; border-bottom: 1px solid #ddd; }
  #bell-head > span \{ font-size: 15px; font-weight: 700; color: #111; }
  #bell-head > div \{ display: flex; gap: 6px; }
  #bell-notes \{ overflow-y: auto; padding: 8px; }
  .bn \{ display: flex; justify-content: space-between; align-items: flex-start; gap: 10px; padding: 12px 12px; border-radius: 10px; border-left: 3px solid transparent; }
  .bn:not(.acked) \{ border-left-color: #7a5ac0; background: #faf8fe; }
  .bn:hover \{ background: #f2f2f2; }
  .bn:not(.acked):hover \{ background: #f2edfb; }
  .bn.acked \{ opacity: 0.6; }
  .bn-app \{ font-size: 11px; font-weight: 700; color: #6947b8; background: #ede7fa; border-radius: 6px; padding: 2px 8px; font-family: monospace; }
  .bn-time \{ font-size: 11px; color: #888; }
  .bn-title \{ font-size: 14px; font-weight: 700; color: #111; margin-top: 4px; }
  .bn-body \{ font-size: 13px; color: #333; margin-top: 2px; white-space: pre-wrap; line-height: 1.45; }
  .bn-empty \{ padding: 24px; text-align: center; color: #888; font-size: 13px; }
  .bn-acts \{ display: flex; align-items: center; gap: 4px; flex-shrink: 0; }
  .bn-del \{ visibility: hidden; font-size: 11px; width: 24px; height: 24px; border-radius: 6px; border: none; background: none; color: #bbb; cursor: pointer; font-family: inherit; }
  .bn:hover .bn-del \{ visibility: visible; }
  .bn-del:hover \{ background: #fbe9e9; color: #c0392b; }
  .hdr-btn \{ font-size: 13px; padding: 8px 16px; border-radius: 8px; border: 1px solid #ddd; background: white; color: #555; cursor: pointer; font-family: inherit; }
  .hdr-btn:hover \{ background: #f5f5f5; }
  #tiles \{ display: flex; flex-wrap: wrap; gap: 20px; justify-content: center; }
  .tile \{ position: relative; width: 256px; height: 256px; border-radius: 16px; overflow: hidden; flex-shrink: 0; }
  .tile.has-img:not(.loaded) \{ display: none; }
  #loading-tile \{ display: none; width: 256px; height: 256px; border-radius: 16px; background: #f5f5f5; align-items: center; justify-content: center; flex-shrink: 0; }
  #tiles:has(.tile.has-img:not(.loaded)) #loading-tile \{ display: flex; }
  .spinner \{ width: 32px; height: 32px; border: 3px solid #ddd; border-top-color: #888; border-radius: 50%; animation: spin 0.8s linear infinite; }
  @keyframes spin \{ to \{ transform: rotate(360deg); } }
  .tile-bg \{ position: absolute; inset: 0; }
  .tile-img \{ position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; z-index: 1; }
  .tile-label \{ position: absolute; bottom: 0; left: 0; right: 0; padding: 20px 24px; z-index: 2; }
  .tile.has-img .tile-label \{ padding: 20px 24px; background: linear-gradient(transparent, rgba(0,0,0,0.5)); }
  .tile-title \{ font-size: 18px; font-weight: 600; color: rgba(255,255,255,0.85); }
  .tile-desc \{ font-size: 11px; color: rgba(255,255,255,0.7); margin-top: 4px; display: none; }
  .tile:hover .tile-desc \{ display: block; }
  .tile-actions \{ position: absolute; top: 16px; right: 20px; z-index: 4; display: none; gap: 4px; }
  .tile:hover .tile-actions \{ display: flex; }
  @media (hover: none) \{ .tile-actions \{ display: flex; } }
  .tile-edit, .tile-del \{ font-size: 12px; padding: 6px 12px; border-radius: 8px; border: none; background: rgba(0,0,0,0.45); color: white; cursor: pointer; backdrop-filter: blur(8px); font-family: inherit; }
  .tile-edit:hover \{ background: rgba(0,0,0,0.65); }
  .tile-del:hover \{ background: rgba(0,0,0,0.65); }
  .tile-link \{ position: absolute; inset: 0; z-index: 3; }
  .empty \{ color: #999; font-size: 14px; padding: 60px 0; text-align: center; width: 100%; }
  #edit-backdrop \{ display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.2); z-index: 100; backdrop-filter: blur(2px); }
  #edit-backdrop.open \{ display: flex; align-items: center; justify-content: center; }
  #edit-modal \{ background: white; border: 1px solid #e0e0e0; border-radius: 12px; width: 90%; max-width: 420px; padding: 24px; box-shadow: 0 8px 32px rgba(0,0,0,0.12); }
  #edit-header \{ display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
  #edit-header span \{ font-size: 14px; font-weight: 600; color: #333; }
  #edit-header div \{ display: flex; gap: 6px; }
  #edit-json \{ width: 100%; font-family: 'SF Mono', Monaco, monospace; font-size: 12px; border: 1px solid #e0e0e0; border-radius: 8px; padding: 12px; resize: vertical; background: #fafafa; color: #333; outline: none; }
  #edit-json:focus \{ border-color: #2563eb; box-shadow: 0 0 0 3px rgba(37,99,235,0.1); }
  #edit-status \{ margin-top: 10px; font-size: 12px; color: #16a34a; }
  @media (max-width: 500px) \{
    .tile, #loading-tile \{ width: calc(50% - 10px); height: auto; aspect-ratio: 1; min-width: 140px; }
    #app \{ padding: 20px 16px; }
  }
  """
::
++  script-text
  |=  ball-id=tape
  ^-  tape
  %+  weld
    "var API='/grubbery/api';var BALL='{ball-id}';\0a"
  """
  // inbox bell: landscape-style notifications panel over the tiles
  var NBALL = 'apps/notifications.notifications';
  var bellNotes = [];

  function bellFetch() \{
    return fetch('/grubbery/ball/' + NBALL + '/inbox.inbox?blot=/json')
      .then(function(r) \{ return r.json(); })
      .then(function(ns) \{ bellNotes = ns || []; bellBadge(); })
      .catch(function() \{});
  }

  function bellBadge() \{
    var n = bellNotes.filter(function(x) \{ return x.mack == null; }).length;
    var c = document.getElementById('bell-count');
    c.textContent = n > 99 ? '99+' : n;
    c.style.display = n ? 'flex' : 'none';
    document.getElementById('bell').classList.toggle('live', n > 0);
  }

  function bellAgo(ms) \{
    var s = Math.floor((Date.now() - ms) / 1000);
    if (s < 60) return 'now';
    if (s < 3600) return Math.floor(s / 60) + 'm';
    if (s < 86400) return Math.floor(s / 3600) + 'h';
    return Math.floor(s / 86400) + 'd';
  }

  function bellRender() \{
    var el = document.getElementById('bell-notes');
    el.innerHTML = '';
    var anyUnacked = bellNotes.some(function(n) \{ return n.mack == null; });
    document.getElementById('bell-ack-all').style.display = anyUnacked ? '' : 'none';
    if (!bellNotes.length) \{
      el.innerHTML = '<div class="bn-empty">nothing here — a quiet ship</div>';
      return;
    }
    bellNotes.slice().sort(function(a, b) \{ return b.created_ms - a.created_ms; })
      .forEach(function(n) \{
        var md = n.metadata || \{};
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
        if (!acked) \{
          var b = document.createElement('button');
          b.className = 'hdr-btn';
          b.textContent = 'Mark as read';
          b.onclick = function(e) \{ e.stopPropagation(); bellAck(n.id); };
          acts.appendChild(b);
        }
        var t = document.createElement('button');
        t.className = 'bn-del';
        t.textContent = '✕';
        t.title = 'Delete';
        t.onclick = function(e) \{ e.stopPropagation(); bellClear(n.id); };
        acts.appendChild(t);
        d.appendChild(acts);
        if (md.url || !acked) \{
          d.style.cursor = 'pointer';
          d.onclick = function() \{
            if (!acked) bellAck(n.id);
            if (md.url) window.open(md.url, '_blank');
          };
        }
        el.appendChild(d);
      });
  }

  function bellPoke(body, cb) \{
    fetch(API + '/poke/' + NBALL + '/main.sig?blot=/json', \{
      method: 'POST',
      headers: \{ 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    }).then(function() \{ if (cb) cb(); });
  }

  function openBell(e) \{
    e.preventDefault();
    document.getElementById('bell-backdrop').classList.add('open');
    bellRender();
    bellFetch().then(bellRender);
  }
  function closeBell(e) \{
    if (e.target === document.getElementById('bell-backdrop')) closeBellNow();
  }
  function closeBellNow() \{
    document.getElementById('bell-backdrop').classList.remove('open');
  }
  function bellClear(id) \{
    bellPoke(\{ action: 'clear', id: id }, function() \{
      setTimeout(function() \{ bellFetch().then(bellRender); }, 350);
    });
  }

  function bellAck(id) \{
    bellPoke(\{ action: 'ack', id: id }, function() \{
      setTimeout(function() \{ bellFetch().then(bellRender); }, 350);
    });
  }
  function bellAckAll() \{
    var un = bellNotes.filter(function(n) \{ return n.mack == null; });
    var left = un.length;
    if (!left) return;
    un.forEach(function(n) \{
      bellPoke(\{ action: 'ack', id: n.id }, function() \{
        if (--left <= 0) setTimeout(function() \{ bellFetch().then(bellRender); }, 350);
      });
    });
  }
  function esc(s) \{
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
  var tileData = \{};

  function renderTiles(tiles) \{
    tileData = \{};
    tiles.forEach(function(t) \{ tileData[t.name] = t; });
    var loading = document.getElementById('loading-tile');
    tilesDiv.innerHTML = '';
    if (!tiles.length) \{
      tilesDiv.innerHTML = '<div class="empty">no tiles yet</div>';
    } else \{
      tiles.forEach(function(t) \{
        var d = document.createElement('div');
        d.className = t.image ? 'tile has-img' : 'tile';
        d.dataset.tile = t.name;
        var bg = document.createElement('div');
        bg.className = 'tile-bg';
        bg.style.background = t.color || '#333';
        d.appendChild(bg);
        if (t.image) \{
          var img = document.createElement('img');
          img.className = 'tile-img';
          img.src = t.image;
          img.onload = function() \{ this.closest('.tile').classList.add('loaded'); };
          img.onerror = function() \{ this.style.display='none'; this.closest('.tile').classList.add('loaded'); };
          d.appendChild(img);
        }
        var lbl = document.createElement('div');
        lbl.className = 'tile-label';
        var ttl = document.createElement('div');
        ttl.className = 'tile-title';
        ttl.textContent = t.title || '';
        lbl.appendChild(ttl);
        if (t.info) \{
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
        btn.onclick = function(e) \{ e.preventDefault(); e.stopPropagation(); viewTile(d, t.name); };
        acts.appendChild(btn);
        d.appendChild(acts);
        if (t.href) \{
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

  function loadTiles() \{
    fetch('/grubbery/tiles/tiles.json')
      .then(function(r) \{ return r.json(); })
      .then(renderTiles)
      .catch(function() \{ tilesDiv.innerHTML = '<div class="empty">failed to load tiles</div>'; });
  }

  function addTile() \{
    isNew = true;
    editName = 'tile-' + Date.now().toString(36);
    editTitle.textContent = 'New tile';
    editStatus.textContent = '';
    editJson.disabled = false;
    document.getElementById('edit-save').style.display = '';
    editJson.value = JSON.stringify(\{
      title: 'New tile',
      info: '',
      color: '#333',
      image: '',
      href: ''
    }, null, 2);
    editBack.classList.add('open');
  }

  function viewTile(el, name) \{
    var t = tileData[name];
    if (!t) return;
    // header shows the human name; the identity key (<slug>.json,
    // synthetic for app-derived tiles) stays out of sight
    var disp = name.slice(-5) === '.json' ? name.slice(0, -5) : name;
    editTitle.textContent = t.title || disp;
    editStatus.textContent = '';
    // name is the tile's identity key (its filename), stapled on by the
    // /tiles.json API -- not part of the grub's content, so don't show it
    var content = Object.assign(\{}, t);
    delete content.name;
    editJson.value = JSON.stringify(content, null, 2);
    editJson.disabled = true;
    document.getElementById('edit-save').style.display = 'none';
    editBack.classList.add('open');
  }

  function deleteTile(name) \{
    var el = document.querySelector('[data-tile="' + name + '"]');
    var title = el ? (el.querySelector('.tile-title') || \{}).textContent || name : name;
    if (!confirm('Delete ' + title + '?')) return;
    fetch(API + '/file/' + BALL + '/tiles/' + name, \{method: 'DELETE'})
      .then(function() \{ loadTiles(); });
  }

  document.getElementById('edit-close').onclick = function() \{
    editBack.classList.remove('open');
  };

  editBack.onclick = function(e) \{
    if (e.target === editBack) editBack.classList.remove('open');
  };

  document.getElementById('edit-save').onclick = async function() \{
    var parsed;
    try \{ parsed = JSON.parse(editJson.value); } catch(e) \{
      editStatus.textContent = 'Invalid JSON';
      editStatus.style.color = '#f87171';
      return;
    }
    var method = isNew ? 'PUT' : 'POST';
    var endpoint = isNew ? '/file/' : '/over/';
    var r = await fetch(API + endpoint + BALL + '/tiles/' + editName + '?blot=/json', \{
      method: method,
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(parsed)
    });
    if (r.ok) \{
      editStatus.textContent = 'Saved';
      editStatus.style.color = '#4ade80';
      setTimeout(function() \{ editBack.classList.remove('open'); loadTiles(); }, 400);
    } else \{
      editStatus.textContent = 'Save failed';
      editStatus.style.color = '#f87171';
    }
  };

  loadTiles();
  """
--
