::  shell nexus: the home surface. Composes services — the launcher grid
::  (from the tiles store) and the notifications bell — over HTTP, and
::  owns the cross-ship discovery state: public.json, the derived
::  directory of this ship's shared desks, and /peers/, live mirrors
::  of other ships' directories.
::
/<  feather-icons  /lib/feather-icons.hoon
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'public.json'] [[/ %json] [%a ~]]]
          [%fall %& [/ %'peers.json'] [[/ %json] [%a ~]]]
          [%fall %| /peers empty-dir:loader]
          [%fall %| /requests empty-dir:loader]
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
        ;<  ~  bind:m  (rise-wait:io prod "%shell main: failed")
        ;<  ~  bind:m  (bind-http:io [~ /apps/grubbery])
        ;<  ~  bind:m  (bind-http:io [~ /grubbery/tiles])
        (http-dispatch:io %shell)
          ::  public.json: this ship's public desk directory — a json
          ::  array of desk paths, peekable by anyone. The bootstrap
          ::  for cross-ship discovery: peek this, then peek each desk
          ::  for its version and tile through its own public grants.
          ::
          ::  Derived, never pushed: the directory is computed from
          ::  the /public group's grants, the ground truth for what is
          ::  followable. Rescans on any poke (desks nudge after their
          ::  grants change) and on a timer, so it cannot go stale.
          ::
          [~ %'public.json']
        ;<  ~  bind:m  (rise-wait:io prod "%shell public: failed")
        ;<  ~  bind:m  reg-register:io
        ;<  here=rail:tarball  bind:m  get-here-abs:io
        =/  nex-dir=path  path.here
        ;<  ~  bind:m
          %-  reg-how:io
          :-  /public
          [~ ~ (sy `(list road:tarball)`~[[%& %& nex-dir %'public.json']])]
        |-
        ;<  ~  bind:m  (reg-poke:io [%gc ~])
        ;<  paths=(list @t)  bind:m  scan-public
        ;<  cur=json  bind:m  (get-state-as:io ,json)
        =/  next=json  a+(turn paths |=(p=@t s+p))
        ;<  ~  bind:m
          ?:  =(next cur)  (pure:(fiber:fiber:nexus ,~) ~)
          (replace:io next)
        ;<  now=@da  bind:m  get-time:io
        ;<  ~  bind:m  (set-timer:io /rescan (add now ~m30))
        ;<  *  bind:m  take-poke:io
        $
          ::  peers.json: poke target for managing which ships' public
          ::  desk directories we mirror. {"add": "~ship"} makes the
          ::  mirror grub, {"del": "~ship"} culls it. Pure local CRUD:
          ::  each mirror grub runs its own fiber and owns its own
          ::  network traffic, so an unreachable ship can never block
          ::  this loop.
          ::
          [~ %'peers.json']
        ;<  ~  bind:m  (rise-wait:io prod "%shell peers: failed")
        |-
        ;<  =sage:tarball  bind:m  take-poke:io
        =/  cmd=json  (fall (mole |.(!<(json q.sage))) *json)
        =/  add=(unit @t)  (jget cmd 'add')
        =/  del=(unit @t)  (jget cmd 'del')
        ?^  add
          ?~  (slaw %p u.add)
            ~&  >>>  [%shell-peers-bad-ship u.add]
            $
          =/  =road:tarball  (nex-road:io rail [%& /peers (peer-file u.add)])
          ;<  has=?  bind:m  (peek-exists:io road)
          ?:  has  $
          ;<  err=(unit tang)  bind:m
            (make-soft:io road |+[[[/ %json] `json`[%a ~]] ~])
          ~?  >>>  ?=(^ err)  [%shell-peer-make-failed u.add]
          $
        ?^  del
          ;<  err=(unit tang)  bind:m
            (cull-soft:io (nex-road:io rail [%& /peers (peer-file u.del)]))
          ~?  >>>  ?=(^ err)  [%shell-peer-cull-failed u.del]
          $
        $
          ::  /peers/<ship>.json: live mirror of one ship's public desk
          ::  directory, held current by subscription. All network
          ::  traffic for the ship happens here; if the ship is
          ::  unreachable, only this fiber waits.
          ::
          [[%peers ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%shell mirror: failed")
        =/  s=@t  (mirror-ship name.rail)
        ?~  (slaw %p s)  (pure:m ~)
        ;<  *  bind:m  (keep:io /pub (peer-pub-road s) ~)
        ;<  ~  bind:m  (refresh-mirror s)
        |-
        ;<  *  bind:m  (take-news:io /pub)
        ;<  ~  bind:m  (refresh-mirror s)
        $
          ::
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%shell request: failed")
        =/  eyre-id=@ta  name.rail
        ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
        ;<  our=@p  bind:m  get-our:io
        ?.  =(src our)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
          (pure:m ~)
        =/  prefix=path  /grubbery/tiles
        =/  site=path  site:(parse-url:http-utils url.request.req)
        =/  suffix=path  (slag (lent prefix) site)
        ::  tile store, served from the tiles data ball over the namespace
        ::  /grubbery/tiles/tiles.json → all tile data
        ?:  ?=([%'tiles.json' ~] suffix)
          ;<  tiles=(list tile)  bind:m  read-all-tiles
          =/  =json  (tiles-to-json tiles)
          =/  body=octs  (as-octs:mimes:html (en:json:html json))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ['content-type' 'application/json'] ~] `body])
          (pure:m ~)
        ::  /grubbery/tiles/icon/<app> → serve an app's icon file,
        ::  looked up by full app name
        ?:  ?=([%icon @ ~] suffix)
          =/  app=@ta  i.t.suffix
          ;<  kid-root=view:nexus  bind:m
            (peek:io [%& %| /apps/[app]] ~)
          =/  icon-file=(unit [name=@ta sang=sang:tarball])
            ?.  ?=([%ball *] kid-root)  ~
            =/  =lump:tarball  (fall fil.ball.kid-root *lump:tarball)
            %-  ~(rep by contents.lump)
            |=  [[n=@ta s=sang:tarball g=? b=(unit tang)] out=(unit [name=@ta sang=sang:tarball])]
            ?^  out  out
            =/  nam=tape  (trip n)
            ?.  =("icon." (scag 5 nam))  out
            ?:  (is-boom:tarball s)  out
            `[n s]
          ?~  icon-file
            ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
            (pure:m ~)
          =/  =mime  !<(mime (need-vase:tarball sang.u.icon-file))
          ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils mime))
          (pure:m ~)
        ::  /icon.svg → the shell's favicon
        ?:  ?=([%'icon.svg' ~] suffix)
          =/  bod=octs  (as-octs:mimes:html shell-icon)
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' 'image/svg+xml']]] `bod])
          (pure:m ~)
        ::  default → serve the home page
        =/  page=@t  (crip (en-xml:html shell-page))
        =/  =mime  [/text/html (as-octs:mimes:html page)]
        ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils mime))
        (pure:m ~)
      ==
    --
|%
++  srv  ~(. http-res:io [%| 1 %& ~ %'main.sig'])
::  the home favicon: the launcher grid itself
::
++  shell-icon
  ^-  @t
  '''
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
    <rect width="64" height="64" rx="14" fill="#7a5ac0"/>
    <rect x="12" y="12" width="17" height="17" rx="5" fill="#fff"/>
    <rect x="35" y="12" width="17" height="17" rx="5" fill="#fff"/>
    <rect x="12" y="35" width="17" height="17" rx="5" fill="#fff"/>
    <rect x="35" y="35" width="17" height="17" rx="5" fill="#ede7fa" opacity="0.75"/>
  </svg>
  '''
::  +scan-public: derive the public desk directory from the /public
::  group's grants. A desk shared to /public grants peeks on its root
::  version.* files; the directories those grants sit in ARE the
::  public desks.
::
++  scan-public
  =/  m  (fiber:fiber:nexus ,(list @t))
  ^-  form:m
  ;<  =view:nexus  bind:m
    (peek:io [%& %& /sys/ames/usergroups/'public.grp' %'how.weir'] `[/ %weir])
  ?.  ?=([%file *] view)  (pure:m ~)
  ?:  (is-boom:tarball sang.view)  (pure:m ~)
  =/  =weir:tarball  !<(weir:tarball (need-vase:tarball sang.view))
  =/  dirs=(set path)
    %+  roll  ~(tap in peek.weir)
    |=  [r=road:tarball acc=(set path)]
    ?.  ?=([%& %& *] r)  acc
    ?.  =('version.' (end [3 8] name.p.p.r))  acc
    (~(put in acc) path.p.p.r)
  %-  pure:m
  (sort (turn ~(tap in dirs) |=(p=path (crip (spud p)))) aor)
::  peer directory mirroring
::
++  peer-file  |=(s=@t `@ta`(cat 3 s '.json'))
::
::  +mirror-ship: a mirror grub's ship, from its file name
::
++  mirror-ship
  |=  n=@ta
  ^-  @t
  =/  t=tape  (trip n)
  ?:  (lth (lent t) 5)  n
  (crip (scag (sub (lent t) 5) t))
::
++  peer-pub-road
  |=  s=@t
  ^-  road:tarball
  [%& %& /sys/ames/ships/[s]/root/apps/'shell.shell' %'public.json']
::
++  jget
  |=  [j=json k=@t]
  ^-  (unit @t)
  ?.  ?=(%o -.j)  ~
  =/  v  (~(get by p.j) k)
  ?.(?=([~ %s *] v) ~ `p.u.v)
::
::  +refresh-mirror: pull the peer's public.json into this mirror grub
::
++  refresh-mirror
  |=  s=@t
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  pv=view:nexus  bind:m  (peek:io (peer-pub-road s) ~)
  ?.  ?=([%file *] pv)
    ~&  >>  [%shell-peer-unreachable s]
    (pure:m ~)
  ?:  (is-boom:tarball sang.pv)  (pure:m ~)
  =/  res=(each json tang)
    (mule |.(!<(json (need-vase:tarball sang.pv))))
  ?:  ?=(%| -.res)  (pure:m ~)
  (replace:io p.res)
::
+$  tile
  $:  name=@ta
      title=@t
      info=@t
      color=@t
      image=@t
      href=@t
  ==
::
::  each local tile is its own subdir /tiles/<name>/ holding tile.json
::  (and optionally icon.svg); the tile's name is the subdir name.
++  read-local-tiles
  =/  m  (fiber:fiber:nexus ,(list tile))
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io [%& %| /apps/'tiles.tiles'/tiles] ~)
  ?.  ?=([%ball *] view)
    (pure:m ~)
  =/  subdirs=(list [@ta ball:tarball])  ~(tap by dir.ball.view)
  =|  acc=(list tile)
  |-
  ?~  subdirs  (pure:m (flop acc))
  =/  name=@ta  -.i.subdirs
  ;<  tv=view:nexus  bind:m
    (peek:io [%& %& /apps/'tiles.tiles'/tiles/[name] %'tile.json'] `[/ %json])
  ?.  ?=([%file *] tv)
    $(subdirs t.subdirs)
  =/  til=(unit tile)  (json-to-tile name sang.tv)
  ?~  til  $(subdirs t.subdirs)
  $(subdirs t.subdirs, acc [u.til acc])
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
  =/  made=(unit tile)  (json-to-tile tile-name sang.kid-view)
  ?~  made  $(kids t.kids)
  ::  an app that ships an icon file gets it as the tile image,
  ::  addressed by full app name
  ;<  kid-root=view:nexus  bind:m  (peek:io [%& %| /apps/[kid]] ~)
  =/  icon=(unit @ta)
    ?.  ?=([%ball *] kid-root)  ~
    =/  =lump:tarball  (fall fil.ball.kid-root *lump:tarball)
    %-  ~(rep by contents.lump)
    |=  [[n=@ta s=sang:tarball g=? b=(unit tang)] out=(unit @ta)]
    ?^  out  out
    ?.  =("icon." (scag 5 (trip n)))  out
    ?:  (is-boom:tarball s)  out
    `n
  =/  til=tile
    ?~  icon  u.made
    u.made(image (crip "/grubbery/tiles/icon/{(trip kid)}"))
  $(kids t.kids, acc [[til kid] acc])
::
++  app-slug
  |=  name=@ta
  ^-  @ta
  =/  nam=tape  (trip name)
  =/  dix=(unit @ud)  (find "." nam)
  ?~  dix  name
  (crip (scag u.dix nam))
::
++  read-all-tiles
  =/  m  (fiber:fiber:nexus ,(list tile))
  ^-  form:m
  ;<  local=(list tile)  bind:m  read-local-tiles
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
++  shell-page
  ^-  manx
  ;html
    ;head
      ;title: home
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;link(rel "icon", type "image/svg+xml", href "/apps/grubbery/icon.svg");
      ;style
        ;+  ;/  style-text
      ==
    ==
    ;body
      ;div#app
        ;div#header
          ;a#bell(href "#", onclick "openBell(event)", title "Notifications")
            ;+  (make:feather-icons 'bell')
            ;span#bell-count(style "display:none");
          ==
          ;button#add-btn.hdr-btn(onclick "addTile()"): + New
          ;button#get-btn.hdr-btn(onclick "openGet()"): Get Apps
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
        ;div#get-backdrop(onclick "closeGet(event)")
          ;div#get-panel
            ;div#get-head
              ;span: Get apps
              ;button.hdr-btn(onclick "closeGetNow()"): close
            ==
            ;div#get-search
              ;input#peer-ship(type "text", placeholder "search ~ship", autocomplete "off");
              ;button.hdr-btn(onclick "peerAdd()"): search
              ;div#peer-suggest;
            ==
            ;div#peer-lists;
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
        ;+  ;/  script-text
      ==
    ==
  ==
::
++  style-text
  ^-  tape
  """
  * \{ margin: 0; padding: 0; box-sizing: border-box; }
  body \{ font-family: Inter, sans-serif; background: white; min-height: 100vh; }
  #app \{ width: 100%; max-width: 1440px; margin: 0 auto; padding: 40px 24px; }
  #header \{ display: flex; justify-content: center; align-items: center; gap: 10px; margin-bottom: 32px; }
  #bell \{ position: relative; display: flex; align-items: center; text-decoration: none; padding: 7px 9px; border-radius: 8px; border: 1px solid #ddd; color: #555; }
  #bell svg \{ width: 16px; height: 16px; display: block; }
  #bell:hover \{ background: #f5f5f5; color: #111; }
  #bell.live \{ color: #7a5ac0; }
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
  #tiles \{ display: grid; grid-template-columns: repeat(auto-fit, 256px); gap: 20px; justify-content: center; }
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
  .empty \{ color: #999; font-size: 14px; padding: 60px 0; text-align: center; width: 100%; grid-column: 1 / -1; }
  #edit-backdrop \{ display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.2); z-index: 100; backdrop-filter: blur(2px); }
  #edit-backdrop.open \{ display: flex; align-items: center; justify-content: center; }
  #edit-modal \{ background: white; border: 1px solid #e0e0e0; border-radius: 12px; width: 90%; max-width: 420px; padding: 24px; box-shadow: 0 8px 32px rgba(0,0,0,0.12); }
  #edit-header \{ display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
  #edit-header span \{ font-size: 14px; font-weight: 600; color: #333; }
  #edit-header div \{ display: flex; gap: 6px; }
  #edit-json \{ width: 100%; font-family: 'SF Mono', Monaco, monospace; font-size: 12px; border: 1px solid #e0e0e0; border-radius: 8px; padding: 12px; resize: vertical; background: #fafafa; color: #333; outline: none; }
  #edit-json:focus \{ border-color: #2563eb; box-shadow: 0 0 0 3px rgba(37,99,235,0.1); }
  #edit-status \{ margin-top: 10px; font-size: 12px; color: #16a34a; }
  #get-backdrop \{ display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.25); z-index: 100; align-items: center; justify-content: center; }
  #get-backdrop.open \{ display: flex; }
  #get-panel \{ width: min(760px, calc(100vw - 32px)); height: min(80vh, 720px); background: white; border: 1px solid #bbb; border-radius: 14px; box-shadow: 0 16px 48px rgba(0,0,0,0.28); display: flex; flex-direction: column; overflow: hidden; }
  #get-head \{ display: flex; justify-content: space-between; align-items: center; padding: 14px 16px; border-bottom: 1px solid #ddd; }
  #get-head > span \{ font-size: 15px; font-weight: 700; color: #111; }
  #get-search \{ display: flex; gap: 8px; padding: 12px 16px; border-bottom: 1px solid #eee; }
  #peer-ship \{ flex: 1; font-size: 14px; padding: 9px 12px; border: 1px solid #ddd; border-radius: 8px; font-family: inherit; outline: none; }
  #peer-ship:focus \{ border-color: #7a5ac0; box-shadow: 0 0 0 3px rgba(122,90,192,0.12); }
  #peer-lists \{ overflow-y: auto; padding: 4px 16px 16px; }
  .peer-head \{ display: flex; justify-content: space-between; align-items: center; padding: 14px 0 6px; }
  .peer-head b \{ font-size: 12px; font-weight: 700; color: #6947b8; background: #ede7fa; border-radius: 6px; padding: 3px 10px; font-family: monospace; }
  .peer-rm \{ font-size: 11px; border: none; background: none; color: #bbb; cursor: pointer; font-family: inherit; }
  .peer-rm:hover \{ color: #c0392b; }
  .papp \{ display: flex; align-items: center; gap: 14px; padding: 10px 6px; border-radius: 12px; }
  .papp:hover \{ background: #f7f7f7; }
  .papp-icon \{ width: 56px; height: 56px; border-radius: 14px; object-fit: cover; flex-shrink: 0; }
  .papp-body \{ flex: 1; min-width: 0; }
  .papp-title \{ font-size: 14px; font-weight: 600; color: #111; }
  .papp-sub \{ font-size: 12px; color: #888; margin-top: 2px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .papp-get \{ font-size: 12px; font-weight: 600; padding: 7px 18px; border-radius: 16px; border: none; background: #ede7fa; color: #6947b8; cursor: pointer; font-family: inherit; }
  .papp-get:hover \{ background: #e0d4f7; }
  .papp-get:disabled \{ opacity: 0.6; cursor: default; }
  .papp-none \{ color: #999; font-size: 13px; padding: 10px 6px; }
  .papp-un \{ font-size: 11px; border: none; background: none; color: #bbb; cursor: pointer; font-family: inherit; }
  .papp-un:hover \{ color: #c0392b; }
  .peer-spin \{ display: flex; justify-content: center; padding: 32px 0; }
  #get-search \{ position: relative; }
  #peer-suggest \{ display: none; position: absolute; top: calc(100% - 8px); left: 16px; right: 16px; background: white; border: 1px solid #ddd; border-radius: 10px; box-shadow: 0 8px 24px rgba(0,0,0,0.15); height: 240px; overflow-y: auto; z-index: 10; }
  #peer-suggest.open \{ display: block; }
  .psug \{ display: flex; align-items: baseline; gap: 8px; padding: 9px 12px; cursor: pointer; }
  .psug:hover \{ background: #f5f2fb; }
  .psug-nick \{ font-size: 13px; font-weight: 600; color: #111; }
  .psug-ship \{ font-size: 12px; color: #888; font-family: monospace; }
    @media (max-width: 600px) \{
    #tiles \{ grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
    .tile, #loading-tile \{ width: 100%; height: auto; aspect-ratio: 1; min-width: 0; }
    #app \{ padding: 20px 16px; }
  }
  """
::
++  script-text
  ^-  tape
  %+  weld
    "var API='/grubbery/api';var BALL='apps/tiles.tiles';\0a"
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
      image: '',
      title: 'New tile',
      href: '',
      color: '#333',
      info: ''
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
    fetch(API + '/file/' + BALL + '/tiles/' + name + '/tile', \{method: 'DELETE'})
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
    var r = await fetch(API + endpoint + BALL + '/tiles/' + editName + '/tile?blot=/json', \{
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

  // -- get apps from ships --
  var peerGroups = [];
  function escP(s) \{
    var d = document.createElement('div');
    d.textContent = (s == null) ? '' : String(s);
    return d.innerHTML;
  }
  function peerSpin() \{
    document.getElementById('peer-lists').innerHTML =
      '<div class="peer-spin"><div class="spinner"></div></div>';
  }
  function openGet() \{
    document.getElementById('get-backdrop').classList.add('open');
    peerSpin();
    loadContacts();
    loadPeers();
    document.getElementById('peer-ship').focus();
  }
  function closeGet(e) \{
    if (e.target === document.getElementById('get-backdrop')) closeGetNow();
  }
  function closeGetNow() \{
    document.getElementById('get-backdrop').classList.remove('open');
  }
  function peerPost(path, body) \{
    return fetch('/grubbery/desks/' + path, \{
      method: 'POST',
      headers: \{ 'content-type': 'application/json' },
      body: JSON.stringify(body)
    });
  }
  function peerAdd() \{
    var inp = document.getElementById('peer-ship');
    var s = inp.value.trim();
    if (!s) return;
    if (s[0] !== '~') s = '~' + s;
    peerSpin();
    peerPost('peers', \{ add: s }).then(function() \{
      inp.value = '';
      setTimeout(loadPeers, 1500);
    });
  }
  function peerDel(s) \{
    peerPost('peers', \{ del: s }).then(function() \{ setTimeout(loadPeers, 500); });
  }
  function installPeerApp(a, btn, name) \{
    btn.disabled = true;
    btn.textContent = 'installing...';
    peerPost('add', \{ name: name || a.name, type: 'cross-ship', source: a.source })
      .then(function(r) \{
        if (r.status === 409) \{
          var alt = prompt('A desk named "' + (name || a.name) + '" already exists here. Install under a different name:');
          if (alt && alt.trim()) \{ installPeerApp(a, btn, alt.trim()); return; }
          btn.textContent = 'Get';
          btn.disabled = false;
          return;
        }
        if (!r.ok) \{
          btn.textContent = 'failed';
          btn.disabled = false;
          return;
        }
        btn.textContent = 'installed';
        setTimeout(loadTiles, 1200);
        setTimeout(loadPeers, 1500);
      });
  }
  function uninstallPeerApp(a, btn) \{
    var word = prompt('CAREFUL: this permanently deletes ' + a.local + ' and all its data. Type "' + a.local + '" to confirm:');
    if (word !== a.local) return;
    btn.disabled = true;
    btn.textContent = 'removing...';
    peerPost('delete', \{ app: a.local })
      .then(function() \{
        setTimeout(loadPeers, 800);
        setTimeout(loadTiles, 1000);
      });
  }
  function loadPeers() \{
    fetch('/grubbery/desks/peers')
      .then(function(r) \{ return r.json(); })
      .then(function(groups) \{
        peerGroups = groups;
        var box = document.getElementById('peer-lists');
        box.innerHTML = '';
        if (!groups.length) \{
          box.innerHTML = '<div class="papp-none">no ships yet. search for one above.</div>';
          return;
        }
        groups.forEach(function(g, gi) \{
          var div = document.createElement('div');
          var apps = (g.apps || []).map(function(a, ai) \{
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
        Array.prototype.forEach.call(box.querySelectorAll('[data-g]'), function(b) \{
          b.onclick = function() \{
            installPeerApp(peerGroups[+b.getAttribute('data-g')].apps[+b.getAttribute('data-a')], b);
          };
        });
        Array.prototype.forEach.call(box.querySelectorAll('[data-ug]'), function(b) \{
          b.onclick = function() \{
            uninstallPeerApp(peerGroups[+b.getAttribute('data-ug')].apps[+b.getAttribute('data-ua')], b);
          };
        });
        Array.prototype.forEach.call(box.querySelectorAll('[data-ship]'), function(b) \{
          b.onclick = function() \{ peerDel(b.getAttribute('data-ship')); };
        });
      });
  }
  var peerContacts = [];
  function loadContacts() \{
    fetch('/grubbery/contacts/api/overlays')
      .then(function(r) \{ return r.json(); })
      .then(function(data) \{
        peerContacts = Object.keys(data).map(function(ship) \{
          var f = data[ship] || \{};
          var nick = (f.nickname && f.nickname.s) || f.nickname || '';
          if (typeof nick !== 'string') nick = '';
          return \{ ship: ship, nick: nick, sort: nick ? nick.toLowerCase() : ship };
        });
        peerContacts.sort(function(a, b) \{ return a.sort < b.sort ? -1 : a.sort > b.sort ? 1 : 0; });
      })
      .catch(function() \{ peerContacts = []; });
  }
  function hideSuggest() \{
    document.getElementById('peer-suggest').classList.remove('open');
  }
  function renderSuggest() \{
    var box = document.getElementById('peer-suggest');
    var raw = document.getElementById('peer-ship').value.trim();
    if (!raw) \{ hideSuggest(); return; }
    var q = raw.toLowerCase().replace(/^~/, '');
    var have = \{};
    peerGroups.forEach(function(g) \{ have[g.ship] = true; });
    var matches = peerContacts.filter(function(c) \{
      if (have[c.ship]) return false;
      if (!q) return true;
      return c.ship.replace('~', '').indexOf(q) >= 0 || c.nick.toLowerCase().indexOf(q) >= 0;
    }).slice(0, 8);
    if (!matches.length) \{ hideSuggest(); return; }
    box.innerHTML = matches.map(function(c) \{
      return '<div class="psug" data-ship="' + escP(c.ship) + '">' +
        (c.nick ? '<span class="psug-nick">' + escP(c.nick) + '</span>' : '') +
        '<span class="psug-ship">' + escP(c.ship) + '</span></div>';
    }).join('');
    Array.prototype.forEach.call(box.querySelectorAll('.psug'), function(row) \{
      row.onmousedown = function(e) \{
        e.preventDefault();
        document.getElementById('peer-ship').value = row.getAttribute('data-ship');
        hideSuggest();
        peerAdd();
      };
    });
    box.classList.add('open');
  }
  var peerInp = document.getElementById('peer-ship');
  peerInp.addEventListener('keydown', function(e) \{
    if (e.key === 'Enter') \{ hideSuggest(); peerAdd(); }
    if (e.key === 'Escape') hideSuggest();
  });
  peerInp.addEventListener('input', renderSuggest);
  peerInp.addEventListener('focus', renderSuggest);
  peerInp.addEventListener('blur', function() \{ setTimeout(hideSuggest, 150); });
  """
--
