::  routes nexus: draw running and cycling routes on a map
::
::  The on-the-go-map idea, namespace-flavored. The browser does the
::  actual routing — clicks become waypoints, the page calls public
::  routing APIs (BRouter for foot/bike, OSRM for driving) directly,
::  so the ship never proxies a routing request. The ship serves the
::  page and keeps saved routes as grubs: one route per file under
::  /routes, so every route carries its own version history.
::
::  /routes/<slug>.json  {name, profile, waypoints, geometry,
::                        distance, at}
::  /main.sig            HTTP at /grubbery/routes
::    GET  /list         all saved routes as a json array
::    POST /save         a full route object — upserts its grub
::    POST /del          {"name": "..."}
::
/<  index-html  routes/index.html
/<  app-js      routes/app.js
/<  icon        routes/icon.svg
/&  man  ../man/routes/readme.md
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'Routes'
            info+s+'Draw running and cycling routes'
            color+s+'#3d6b52'
            image+s+'/grubbery/tiles/icon/routes.routes'
            href+s+'/grubbery/routes'
        ==
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%over %& [/ %'tile.json'] [[/ %json] tile]]
          [%over %& [/ %'icon.svg'] [[/ %mime] icon]]
          [%over %& [/ %'index.html'] [[/ %mime] index-html]]
          [%over %& [/ %'app.js'] [[/ %mime] app-js]]
          [%over %& [/ %'README.md'] [[/ %mime] man]]
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %| /requests empty-dir:loader]
          [%fall %| /routes empty-dir:loader]
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
        ;<  ~  bind:m  (rise-wait:io prod "%routes /main: failed")
        ;<  ~  bind:m  (bind-http:io [~ /grubbery/routes])
        (http-dispatch:io %routes)
          ::
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%routes /requests: failed")
        (serve name.rail)
      ==
    --
|%
::  HTTP response door (road from /requests/* to /main.sig)
::
++  srv  ~(. http-res:io [%| 1 %& ~ %'main.sig'])
::  +serve: route one HTTP request
::
++  serve
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
  =/  prefix=path  /grubbery/routes
  =/  site=path  site:(parse-url:http-utils url.request.req)
  =/  suffix=path  (slag (lent prefix) site)
  ?+    suffix  (serve-static eyre-id suffix)
    [%list ~]  (serve-list eyre-id)
    [%save ~]  (serve-save eyre-id src req)
    [%del ~]   (serve-del eyre-id src req)
  ==
::  +serve-static: serve asset grubs; bare path gets index.html
::
++  serve-static
  |=  [eyre-id=@ta suffix=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  filename=@ta  ?~(suffix 'index.html' i.suffix)
  ;<  =view:nexus  bind:m  (peek:io [%| 1 %& ~ filename] `[/ %mime])
  ?.  ?=([%file *] view)
    (reply eyre-id 404 'Not found')
  =/  =mime  !<(mime (need-vase:tarball sang.view))
  (send-simple:srv eyre-id (mime-response:http-utils mime))
::  +serve-list: every saved route, as one json array
::
++  serve-list
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io [%| 1 %| /routes] ~)
  =/  routes=(list json)
    ?.  ?=([%ball *] view)  ~
    =/  =lump:tarball  (fall fil.ball.view *lump:tarball)
    %+  murn  ~(tap by contents.lump)
    |=  [name=@ta =sang:tarball gain=? bang=(unit tang)]
    ^-  (unit json)
    ?.  =([/ %json] p.sang)  ~
    `!<(json (need-vase:tarball sang))
  (send-json eyre-id a+routes)
::  +serve-save: upsert one route grub — re-saving a route revises it
::  in place, so a route's history is its own edit history
::
++  serve-save
  |=  [eyre-id=@ta src=@p req=inbound-request:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  our=@p  bind:m  get-our:io
  ?.  =(src our)  (reply eyre-id 403 'Forbidden')
  =/  jon=(unit json)  (post-json req)
  =/  name=(unit @t)  (jstr jon 'name')
  ?:  |(?=(~ jon) ?=(~ name) =('' u.name))
    (reply eyre-id 400 'Bad route')
  ;<  ~  bind:m
    (put:io [%| 1 %& /routes (route-file u.name)] [[/ %json] u.jon])
  (reply eyre-id 200 'OK')
::
++  serve-del
  |=  [eyre-id=@ta src=@p req=inbound-request:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  our=@p  bind:m  get-our:io
  ?.  =(src our)  (reply eyre-id 403 'Forbidden')
  =/  name=(unit @t)  (jstr (post-json req) 'name')
  ?~  name  (reply eyre-id 400 'Bad request')
  ;<  err=(unit tang)  bind:m
    (cull-soft:io [%| 1 %& /routes (route-file u.name)])
  ?^  err  (reply eyre-id 404 'Not found')
  (reply eyre-id 200 'OK')
::  +slug / +route-file: display name -> filename-safe @ta
::
++  slug
  |=  n=@t
  ^-  @ta
  %-  crip
  %+  murn  (trip n)
  |=  c=@tD
  ^-  (unit @tD)
  ?:  &((gte c 'a') (lte c 'z'))  `c
  ?:  &((gte c 'A') (lte c 'Z'))  `(add c 32)
  ?:  &((gte c '0') (lte c '9'))  `c
  ?:  |(=('-' c) =('_' c))  `c
  ?:  =(' ' c)  `'-'
  ~
::
++  route-file
  |=  n=@t
  ^-  @ta
  (rap 3 (slug n) '.json' ~)
::
++  post-json
  |=  req=inbound-request:eyre
  ^-  (unit json)
  ?.  =(%'POST' method.request.req)  ~
  ?~  body.request.req  ~
  (de:json:html q.u.body.request.req)
::
++  jstr
  |=  [jon=(unit json) key=@t]
  ^-  (unit @t)
  ?~  jon  ~
  ?.  ?=([%o *] u.jon)  ~
  =/  v  (~(get by p.u.jon) key)
  ?~  v  ~
  ?.  ?=([%s *] u.v)  ~
  `p.u.v
::
++  reply
  |=  [eyre-id=@ta code=@ud msg=@t]
  (send-simple:srv eyre-id [[code ~] `(as-octs:mimes:html msg)])
::
++  send-json
  |=  [eyre-id=@ta jon=json]
  =/  bod=octs  (as-octs:mimes:html (en:json:html jon))
  (send-simple:srv eyre-id [[200 ['content-type' 'application/json'] ~] `bod])
--
