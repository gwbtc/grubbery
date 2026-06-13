::  tiles nexus: customizable launcher grid
::
::  Each tile is a json file under /tiles/ with fields:
::    title, info, color, image, href
::  href can be absolute (https://...) or relative (/grubbery/ball/...)
::
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  =ver:loader  (get-ver:loader ball)
      ?+  ver  !!
          ?(~ [~ %0])
        =/  explorer-tile=json
          %-  pairs:enjs:format
          :~  title+s+'Explorer'
              info+s+'Browse the tarball'
              color+s+'#4a9de5'
              image+s+''
              href+s+'/grubbery/ball'
          ==
        %+  spin:loader  ball
        :~  (ver-row:loader 0)
            [%fall %| /tiles empty-dir:loader]
            [%over %& [/tiles %'explorer.json'] [[/ %json] explorer-tile]]
            [%over %& [/ %'page.html'] [[/ %html] (crip (en-xml:html (tiles-page "" ~)))]]
            [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
            [%fall %| /requests empty-dir:loader]
        ==
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::  page.html: render tile grid, re-render on changes
          ::
          [~ %'page.html']
        ;<  ~  bind:m  (rise-wait:io prod "%tiles page: failed")
        ;<  here=rail:tarball  bind:m  get-here-abs:io
        =/  ball-id=tape  (path-to-ball-id path.here)
        ;<  *  bind:m  (keep:io /tiles (cord-to-road:tarball './tiles/') ~)
        |-
        ;<  =seen:nexus  bind:m  (peek:io (cord-to-road:tarball './tiles/') ~)
        =/  tiles=(list tile)  (read-tiles seen)
        ;<  ~  bind:m  (replace:io (crip (en-xml:html (tiles-page ball-id tiles))))
        ;<  *  bind:m  (take-news:io /tiles)
        $
          ::  main.sig: bind HTTP and dispatch
          ::
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%tiles main: failed")
        ;<  ~  bind:m  (bind-http:io [~ /apps/grubbery])
        ;<  ~  bind:m  (bind-http:io [~ /grubbery/tiles])
        (http-dispatch:io %tiles)
          ::  /ui/requests/*: HTTP request handlers
          ::
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%tiles request: failed")
        =/  eyre-id=@ta  name.rail
        ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
        ;<  our=@p  bind:m  get-our:io
        ?.  =(src our)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
          (pure:m ~)
        ::  Serve tiles page
        ;<  =seen:nexus  bind:m  (peek:io [%| 1 %& / %'page.html'] `[/ %mime])
        ?.  ?=([%& %file *] seen)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[500 ~] `(as-octs:mimes:html 'Page not ready')])
          (pure:m ~)
        =/  =mime  !<(mime (need-vase:tarball sang.p.seen))
        ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils mime))
        (pure:m ~)
      ==
    ::
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'Directory under the tiles nexus.'
            ~
          %-  crip
          """
          TILES - customizable launcher grid

          Each tile is a JSON file under /tiles/ with fields:
            title, info, color, image, href

          Edit tiles through the web UI or directly as JSON files.
          """
            [%tiles ~]
          'Tile definitions. Each file is a JSON object with title, info, color, image, href.'
            [%requests ~]
          'Per-request fibers for HTTP connections.'
        ==
          %|
        ?+  rail.p.mana  'File under the tiles nexus.'
            [~ %'main.sig']  'HTTP binding process. Serves the tile grid UI.'
            [~ %'page.html']  'Rendered tile grid page. Re-rendered on tile changes.'
        ==
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
  |=  =seen:nexus
  ^-  (list tile)
  ?.  ?=([%& %ball *] seen)  ~
  =/  =lump:tarball  (fall fil.ball.p.seen *lump:tarball)
  %+  murn  ~(tap by contents.lump)
  |=  [name=@ta =sang:tarball gain=? bang=(unit tang)]
  ^-  (unit tile)
  ?.  ?=(%json name.p.sang)  ~
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
++  tiles-page
  |=  [ball-id=tape tiles=(list tile)]
  ^-  manx
  =/  sorted=(list tile)  (sort tiles |=([a=tile b=tile] (aor name.a name.b)))
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
          ;button#add-btn.hdr-btn(onclick "addTile()"): + new
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
          ;*  ?~  sorted
                =/  empty=manx  ;div.empty: no tiles yet
                ~[empty]
              (turn sorted |=(t=tile (tile-card ball-id t)))
        ==
      ==
      ;script
        ;+  ;/  (script-text ball-id)
      ==
    ==
  ==
::
++  tile-card
  |=  [ball-id=tape t=tile]
  ^-  manx
  =/  n=tape  (trip name.t)
  =/  ttl=tape  (trip title.t)
  =/  inf=tape  (trip info.t)
  =/  col=tape  (trip color.t)
  =/  img=tape  (trip image.t)
  =/  lnk=tape  (trip href.t)
  =/  cls=tape  ?:(=(~ img) "tile" "tile has-img")
  ;div(class cls, data-tile n)
    ;div.tile-bg(style "background:{col}");
    ;+  ?:  =(~ img)
          ;div;
        ;img.tile-img(src img, onerror "this.style.display='none'");
    ;div.tile-label
      ;div.tile-title: {ttl}
      ;+  ?:  =(~ inf)
            ;div;
          ;div.tile-desc: {inf}
    ==
    ;div.tile-actions
      ;button.tile-edit(onclick "event.preventDefault();event.stopPropagation();editTile('{n}')"): edit
      ;button.tile-del(onclick "event.preventDefault();event.stopPropagation();deleteTile('{n}')"):  ✕
    ==
    ;+  ?:  =(~ lnk)
          ;div;
        ;a.tile-link(href lnk, target "_blank");
  ==
::
++  style-text
  ^-  tape
  """
  * \{ margin: 0; padding: 0; box-sizing: border-box; }
  body \{ font-family: Inter, sans-serif; background: white; min-height: 100vh; }
  #app \{ width: 100%; max-width: 800px; margin: 0 auto; padding: 40px 24px; }
  #header \{ display: flex; justify-content: flex-end; margin-bottom: 32px; }
  .hdr-btn \{ font-size: 13px; padding: 8px 16px; border-radius: 8px; border: 1px solid #ddd; background: white; color: #555; cursor: pointer; font-family: inherit; }
  .hdr-btn:hover \{ background: #f5f5f5; }
  #tiles \{ display: flex; flex-wrap: wrap; gap: 20px; }
  #tiles \{ justify-content: center; }
  .tile \{ position: relative; width: 256px; height: 256px; border-radius: 16px; overflow: hidden; flex-shrink: 0; }
  .tile-bg \{ position: absolute; inset: 0; }
  .tile-img \{ position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; z-index: 1; }
  .tile-label \{ position: absolute; bottom: 0; left: 0; right: 0; padding: 20px 24px; z-index: 2; }
  .tile.has-img .tile-label \{ padding: 20px 24px; background: linear-gradient(transparent, rgba(0,0,0,0.5)); }
  .tile-title \{ font-size: 18px; font-weight: 600; color: rgba(255,255,255,0.85); }
  .tile-desc \{ font-size: 11px; color: rgba(255,255,255,0.7); margin-top: 4px; display: none; }
  .tile:hover .tile-desc \{ display: block; }
  .tile-actions \{ position: absolute; top: 16px; right: 20px; z-index: 4; display: none; gap: 4px; }
  .tile:hover .tile-actions \{ display: flex; }
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
    .tile \{ width: calc(50% - 10px); height: auto; aspect-ratio: 1; min-width: 140px; }
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
  var editBack = document.getElementById('edit-backdrop');
  var editTitle = document.getElementById('edit-title');
  var editJson = document.getElementById('edit-json');
  var editStatus = document.getElementById('edit-status');
  var editName = '';
  var isNew = false;

  function addTile() \{
    isNew = true;
    editName = 'tile-' + Date.now().toString(36);
    editTitle.textContent = 'New tile';
    editStatus.textContent = '';
    editJson.value = JSON.stringify(\{
      title: 'New tile',
      info: '',
      color: '#333',
      image: '',
      href: ''
    }, null, 2);
    editBack.classList.add('open');
  }

  function editTile(name) \{
    isNew = false;
    editName = name;
    var el = document.querySelector('[data-tile="' + name + '"]');
    var title = el ? (el.querySelector('.tile-title') || \{}).textContent || name : name;
    editTitle.textContent = 'Edit ' + title;
    editStatus.textContent = '';
    fetch(API + '/file/' + BALL + '/tiles/' + name + '?mark=json')
      .then(function(r) \{ return r.json() })
      .then(function(j) \{ editJson.value = JSON.stringify(j, null, 2) })
      .catch(function() \{ editJson.value = '\{}' });
    editBack.classList.add('open');
  }

  function deleteTile(name) \{
    var el = document.querySelector('[data-tile="' + name + '"]');
    var title = el ? (el.querySelector('.tile-title') || \{}).textContent || name : name;
    if (!confirm('Delete ' + title + '?')) return;
    fetch(API + '/file/' + BALL + '/tiles/' + name, \{method: 'DELETE'});
    var el = document.querySelector('[data-tile="' + name + '"]');
    if (el) el.remove();
    if (!document.querySelector('.tile')) \{
      document.getElementById('tiles').innerHTML = '<div class="empty">no tiles \\u2014 click + new to add one</div>';
    }
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
    var r = await fetch(API + endpoint + BALL + '/tiles/' + editName + '?mark=json', \{
      method: method,
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(parsed)
    });
    if (r.ok) \{
      editStatus.textContent = 'Saved';
      editStatus.style.color = '#4ade80';
      setTimeout(function() \{ editBack.classList.remove('open'); }, 400);
    } else \{
      editStatus.textContent = 'Save failed';
      editStatus.style.color = '#f87171';
    }
  };

  // SSE for live updates
  var SSE_URL = API + '/keep/' + BALL + '?mark=txt';
  async function connectSSE() \{
    try \{
      var r = await fetch(SSE_URL, \{headers: \{Accept: 'text/event-stream'}});
      var rdr = r.body.getReader();
      var dec = new TextDecoder();
      var buf = '';
      while (true) \{
        var chunk = await rdr.read();
        if (chunk.done) break;
        buf += dec.decode(chunk.value, \{stream: true});
        if (buf.indexOf('\\n') >= 0) \{
          window.location.reload();
          return;
        }
      }
    } catch(e) \{}
    setTimeout(connectSSE, 3000);
  }
  connectSSE();
  """
--
