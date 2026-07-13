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
          [%over %& [/ %'page.html'] [[/ %html] (crip (en-xml:html (tiles-page "" ~ ~ ~)))]]
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
          ::  page.html: render tile grid, re-render on changes
          ::
          [~ %'page.html']
        ;<  ~  bind:m  (rise-wait:io prod "%tiles page: failed")
        ;<  here=rail:tarball  bind:m  get-here-abs:io
        =/  ball-id=tape  (path-to-ball-id path.here)
        ;<  *  bind:m  (keep:io /tiles (cord-to-road:tarball './tiles/') ~)
        |-
        ;<  =view:nexus  bind:m  (peek:io (cord-to-road:tarball './tiles/') ~)
        =/  local=(list tile)  (read-tiles view)
        =/  local-names=(set @ta)  (sy (turn local |=(t=tile name.t)))
        ;<  app-pairs=(list [tile @ta])  bind:m  read-app-tiles
        =/  app=(list tile)  (turn app-pairs head)
        =/  app-dirs=(map @ta @ta)  (malt (turn app-pairs |=([t=tile d=@ta] [name.t d])))
        =/  tiles=(list tile)  (merge-tiles local app)
        ;<  ~  bind:m  (replace:io (crip (en-xml:html (tiles-page ball-id local-names app-dirs tiles))))
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
        =/  prefix=path  /grubbery/tiles
        =/  site=path  site:(parse-url:http-utils url.request.req)
        =/  suffix=path  (slag (lent prefix) site)
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
        ;<  =view:nexus  bind:m  (peek:io [%| 1 %& / %'page.html'] `[/ %mime])
        ?.  ?=([%file *] view)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[500 ~] `(as-octs:mimes:html 'Page not ready')])
          (pure:m ~)
        =/  =mime  !<(mime (need-vase:tarball sang.view))
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
  =/  entries=(list [@ta ball:tarball])  ~(tap by kids)
  |-
  ?~  entries  ~
  ?:  =(slug (app-slug -.i.entries))
    `-.i.entries
  $(entries t.entries)
::
++  merge-tiles
  |=  [local=(list tile) app=(list tile)]
  ^-  (list tile)
  =/  local-names=(set @ta)  (sy (turn local |=(t=tile name.t)))
  %+  weld  local
  (skip app |=(t=tile (~(has in local-names) name.t)))
::
++  tiles-page
  |=  [ball-id=tape local-names=(set @ta) app-dirs=(map @ta @ta) tiles=(list tile)]
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
          ;div#loading-tile
            ;div.spinner;
          ==
          ;*  ?~  sorted
                =/  empty=manx  ;div.empty: no tiles yet
                ~[empty]
              (turn sorted |=(t=tile (tile-card ball-id local-names app-dirs t)))
        ==
      ==
      ;script
        ;+  ;/  (script-text ball-id)
      ==
    ==
  ==
::
++  tile-card
  |=  [ball-id=tape local-names=(set @ta) app-dirs=(map @ta @ta) t=tile]
  ^-  manx
  =/  n=tape  (trip name.t)
  =/  ttl=tape  (trip title.t)
  =/  inf=tape  (trip info.t)
  =/  col=tape  (trip color.t)
  =/  img=tape  (trip image.t)
  =/  lnk=tape  (trip href.t)
  =/  is-local=?  (~(has in local-names) name.t)
  =/  cls=tape  ?:(=(~ img) "tile" "tile has-img")
  =/  app-dir=@ta  (fall (~(get by app-dirs) name.t) '')
  =/  jon=tape
    ?:  is-local  ""
    %-  trip
    %-  en:json:html
    %-  pairs:enjs:format
    :~  title+s+title.t
        info+s+info.t
        color+s+color.t
        image+s+image.t
        href+s+href.t
    ==
  =/  app-path=tape  ?:(is-local "" "/apps/{(trip app-dir)}")
  ;div(class cls, data-tile n, data-json jon, data-app app-path)
    ;div.tile-bg(style "background:{col}");
    ;+  ?:  =(~ img)
          ;div;
        ;img.tile-img(src img, onload "this.closest('.tile').classList.add('loaded')", onerror "this.style.display='none';this.closest('.tile').classList.add('loaded')");
    ;div.tile-label
      ;div.tile-title: {ttl}
      ;+  ?:  =(~ inf)
            ;div;
          ;div.tile-desc: {inf}
    ==
    ;+  ?:  is-local
          ;div.tile-actions
            ;button.tile-edit(onclick "event.preventDefault();event.stopPropagation();editTile('{n}')"): edit
            ;button.tile-del(onclick "event.preventDefault();event.stopPropagation();deleteTile('{n}')"):  ✕
          ==
        ;div.tile-actions
          ;button.tile-edit(onclick "event.preventDefault();event.stopPropagation();viewTile(this.closest('.tile'))"): view
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

  function viewTile(el) \{
    var json = el.dataset.json;
    var app = el.dataset.app;
    editTitle.textContent = app;
    editStatus.textContent = '';
    editJson.value = JSON.stringify(JSON.parse(json), null, 2);
    editJson.disabled = true;
    document.getElementById('edit-save').style.display = 'none';
    editBack.classList.add('open');
  }

  function editTile(name) \{
    isNew = false;
    editName = name;
    document.getElementById('edit-save').style.display = '';
    var el = document.querySelector('[data-tile="' + name + '"]');
    var title = el ? (el.querySelector('.tile-title') || \{}).textContent || name : name;
    editTitle.textContent = 'Edit ' + title;
    editStatus.textContent = '';
    editJson.value = '';
    editJson.disabled = true;
    editJson.placeholder = 'Loading...';
    editBack.classList.add('open');
    fetch(API + '/file/' + BALL + '/tiles/' + name + '?blot=/json')
      .then(function(r) \{ return r.json() })
      .then(function(j) \{ editJson.value = JSON.stringify(j, null, 2); })
      .catch(function() \{ editJson.value = '\{}'; })
      .finally(function() \{ editJson.disabled = false; editJson.placeholder = '\{}'; });
  }

  function deleteTile(name) \{
    var el = document.querySelector('[data-tile="' + name + '"]');
    var title = el ? (el.querySelector('.tile-title') || \{}).textContent || name : name;
    if (!confirm('Delete ' + title + '?')) return;
    fetch(API + '/file/' + BALL + '/tiles/' + name, \{method: 'DELETE'})
      .then(function() \{ reloadAfterSave(); });
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
      setTimeout(function() \{ editBack.classList.remove('open'); reloadAfterSave(); }, 400);
    } else \{
      editStatus.textContent = 'Save failed';
      editStatus.style.color = '#f87171';
    }
  };

  // Reload after save to pick up server-rendered changes
  function reloadAfterSave() \{
    setTimeout(function() \{ window.location.reload(); }, 600);
  }
  """
--
