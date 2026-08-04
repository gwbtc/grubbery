::  shell nexus: the home surface. Composes services — the launcher grid
::  (from the tiles store) and the notifications bell — over HTTP, and
::  owns the cross-ship discovery state: public.json, the derived
::  directory of this ship's shared desks, and /peers/, live mirrors
::  of other ships' directories.
::
/<  feather-icons  /lib/feather-icons.hoon
/<  app-js         shell/app.js
/<  app-css        shell/style.css
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
          [%over %& [/ %'app.js'] [[/ %mime] app-js]]
          [%over %& [/ %'style.css'] [[/ %mime] app-css]]
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
        ::  static assets: the shell's javascript and stylesheet
        ?:  |(?=([%'app.js' ~] suffix) ?=([%'style.css' ~] suffix))
          =/  fname=@ta  ?:(?=([%'app.js' ~] suffix) 'app.js' 'style.css')
          =/  ctype=@t   ?:(=('app.js' fname) 'text/javascript' 'text/css')
          ;<  fv=view:nexus  bind:m
            (peek:io (nex-road:io rail [%& ~ fname]) `[/ %mime])
          ?.  ?=([%file *] fv)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
            (pure:m ~)
          =/  =mime  !<(mime (need-vase:tarball sang.fv))
          ;<  ~  bind:m
            (send-simple:srv eyre-id [[200 ~[['content-type' ctype]]] `q.mime])
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
      ;link(rel "stylesheet", href "/grubbery/tiles/style.css");
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
              ;button#get-back.hdr-btn(onclick "instBack()"): back
              ;span#get-title: Get apps
              ;button.hdr-btn(onclick "closeGetNow()"): close
            ==
            ;div#get-slider
              ;div.get-screen
                ;div#get-search
                  ;input#peer-ship(type "text", placeholder "search ~ship", autocomplete "off");
                  ;button.hdr-btn(onclick "peerAdd()"): search
                  ;div#peer-suggest;
                ==
                ;div#peer-lists;
              ==
              ;div.get-screen
                ;div#inst-screen;
                ;div#inst-foot;
              ==
            ==
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
      ;script(src "/grubbery/tiles/app.js");
    ==
  ==
--
