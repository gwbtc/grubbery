::  pad nexus: cross-ship collaborative text pads
::
::  Owner-authoritative CRDT relay in the namespace. A pad is a dir
::  of opaque yjs update blobs (base64 cords) under /docs/<doc>/log,
::  appended in arrival order by the doc's inbox fiber — the single
::  sequencing authority. Editors on other ships poke the owner's
::  inbox through the gateway and hold a live local mirror of the
::  log by remote subscription. Browsers only ever talk to their own
::  ship: updates go up as POSTs, the log comes down over the built-in
::  keep SSE. Yjs in the browser does all merging; the ship side
::  never inspects blob contents.
::
/<  index-html  pad/index.html
/<  pad-js  pad/pad.js
/<  icon  pad/icon.svg
/&  man  ../man/pad/readme.md
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'Pad'
            info+s+'Cross-ship live text pads'
            color+s+'#5b7f71'
            image+s+'/grubbery/tiles/icon/pad.pad'
            href+s+'/grubbery/pad'
        ==
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%over %& [/ %'tile.json'] [[/ %json] tile]]
          [%over %& [/ %'icon.svg'] [[/ %mime] icon]]
          [%over %& [/ %'index.html'] [[/ %mime] index-html]]
          [%over %& [/ %'pad.js'] [[/ %mime] pad-js]]
          [%over %& [/ %'README.md'] [[/ %mime] man]]
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %| /requests empty-dir:loader]
          [%fall %| /docs empty-dir:loader]
          [%fall %| /mirror empty-dir:loader]
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::  main.sig: grant /public access, bind HTTP, dispatch
          ::
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%pad /main: failed")
        ;<  ~  bind:m  grant-public
        ;<  ~  bind:m  (bind-http:io [~ /grubbery/pad])
        (http-dispatch:io %pad)
          ::  /docs/<doc>/inbox.sig: the sequencer. Local and remote
          ::  editors poke a base64 update cord; arrival order here IS
          ::  the doc's order. Each poke lands as a fresh log grub.
          ::
          [[%docs @ ~] %'inbox.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%pad /inbox: failed")
        inbox-loop
          ::  /mirror/<host>/<doc>/sync.sig: live local mirror of a
          ::  remote doc's log. All network traffic for the doc lives
          ::  in this fiber; an unreachable host blocks nothing else.
          ::
          [[%mirror @ @ ~] %'sync.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%pad /mirror: failed")
        (sync-loop i.t.path.rail i.t.t.path.rail)
          ::  /requests/<eyre-id>: one fiber per HTTP request
          ::
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%pad /requests: failed")
        (serve name.rail)
      ==
    --
|%
::  the instance directory as registered in root.hoon; used to build
::  remote roads into other ships' pad instances
::
++  nex-dir  `path`/apps/'pad.pad'
++  max-update-bytes  2.000.000
::  HTTP response door (road from /requests/* to /main.sig)
::
++  srv  ~(. http-res:io [%| 1 %& ~ %'main.sig'])
::  +grant-public: let any foreign ship poke doc inboxes and
::  subscribe to doc logs
::
++  grant-public
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  ~  bind:m  reg-register:io
  =/  docs=road:tarball  [%& %| (weld nex-dir /docs)]
  (reg-how:io /public [~ (sy ~[docs]) (sy ~[docs])])
::  +inbox-loop: sequence update pokes into log grubs. Bad input is
::  skipped, never crashed on — a crashed sequencer would drop edits.
::
++  inbox-loop
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |-
  ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
  =/  blob=(unit @t)  (mole |.((rear !<(wain q.sage))))
  ?~  blob
    ~&  >>>  %pad-bad-update
    $
  ?:  (gth (met 3 u.blob) max-update-bytes)
    ~&  >>>  %pad-update-too-big
    $
  ~&  >  [%pad-update src=(get-poke-src:io from)]
  ;<  now=@da  bind:m  get-time:io
  ;<  err=(unit tang)  bind:m
    (make-soft:io [%| 0 %& /log (scot %da now)] |+[[[/ %txt] `wain`~[u.blob]] ~])
  ~?  >>>  ?=(^ err)  %pad-log-make-failed
  $
::  +sync-loop: subscribe to a remote doc's log and copy new entries
::  into our sibling /log dir, where local browsers watch them
::
++  sync-loop
  |=  [host=@ta doc=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  src-path=path  :(weld /sys/ames/ships/[host]/root nex-dir /docs/[doc]/log)
  ;<  init=wave:nexus  bind:m  (keep:io /src [%& %| src-path] ~)
  ;<  ~  bind:m  (sync-changes src-path *wave:nexus init)
  =/  prev=wave:nexus  init
  |-
  ;<  next=wave:nexus  bind:m  (take-news:io /src)
  ;<  ~  bind:m  (sync-changes src-path prev next)
  $(prev next)
::  +sync-changes: peek each changed remote log entry and mirror it
::
++  sync-changes
  |=  [src-path=path prev=wave:nexus cur=wave:nexus]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  lanes=(list [=lane:tarball =cass:clay])  ~(tap by (diff-wave:nexus prev cur))
  |-
  ?~  lanes  (pure:m ~)
  =/  =lane:tarball  lane.i.lanes
  ?:  ?=(%| -.lane)  $(lanes t.lanes)
  =/  src=road:tarball  [%& %& (weld src-path path.p.lane) name.p.lane]
  =/  dest=road:tarball  [%| 0 %& (weld /log path.p.lane) name.p.lane]
  ;<  =view:nexus  bind:m  (peek:io src ~)
  ?.  ?=([%file *] view)
    ;<  *  bind:m  (cull-soft:io dest)
    $(lanes t.lanes)
  ;<  ~  bind:m  (over:io dest [p.sang.view (sang-noun:tarball sang.view)])
  $(lanes t.lanes)
::  +serve: route one HTTP request
::
++  serve
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
  =/  prefix=path  /grubbery/pad
  =/  site=path  site:(parse-url:http-utils url.request.req)
  =/  suffix=path  (slag (lent prefix) site)
  ?+    suffix  (serve-static eyre-id suffix)
    [%api %whoami ~]  (serve-whoami eyre-id src req)
    [%api %docs ~]    (serve-docs eyre-id)
    [%api %create ~]  (serve-create eyre-id src req)
    [%api %open ~]    (serve-open eyre-id src req)
    [%api %update ~]  (serve-update eyre-id src req)
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
::
++  serve-whoami
  |=  [eyre-id=@ta src=@p req=inbound-request:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  %+  send-json  eyre-id
  %-  pairs:enjs:format
  :~  ['ship' s+(scot %p src)]
      ['authenticated' b+authenticated.req]
  ==
::  +serve-docs: list local docs and mirrored docs
::
++  serve-docs
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  local=view:nexus  bind:m  (peek:io [%| 1 %| /docs] ~)
  ;<  mirror=view:nexus  bind:m  (peek:io [%| 1 %| /mirror] ~)
  %+  send-json  eyre-id
  %-  pairs:enjs:format
  :~  ['local' a+(turn (kid-names local) |=(d=@ta s+d))]
      ['mirror' (mirror-json mirror)]
  ==
::  +serve-create: make /docs/<doc>/{log/, inbox.sig} for a new pad
::
++  serve-create
  |=  [eyre-id=@ta src=@p req=inbound-request:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  our=@p  bind:m  get-our:io
  ?.  =(src our)  (reply eyre-id 403 'Forbidden')
  =/  doc=(unit @t)  (jstr (post-json req) 'doc')
  ?:  |(?=(~ doc) !(valid-name u.doc))
    (reply eyre-id 400 'Bad pad name')
  =/  doc-ta=@ta  `@ta`u.doc
  ;<  exists=?  bind:m  (peek-exists:io [%| 1 %& /docs/[doc-ta] %'inbox.sig'])
  ?:  exists  (reply eyre-id 200 'OK')
  ;<  err=(unit tang)  bind:m  (create-doc doc-ta)
  ?^  err  (reply eyre-id 500 'Create failed')
  (reply eyre-id 201 'Created')
::  +serve-open: ensure a mirror of a remote doc exists
::
++  serve-open
  |=  [eyre-id=@ta src=@p req=inbound-request:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  our=@p  bind:m  get-our:io
  ?.  =(src our)  (reply eyre-id 403 'Forbidden')
  =/  jon=(unit json)  (post-json req)
  =/  host=(unit @p)  (biff (jstr jon 'host') (cury slaw %p))
  =/  doc=(unit @t)  (jstr jon 'doc')
  ?:  |(?=(~ host) ?=(~ doc) !(valid-name u.doc))
    (reply eyre-id 400 'Bad host or pad name')
  =/  hostta=@ta  (scot %p u.host)
  =/  doc-ta=@ta  `@ta`u.doc
  ;<  exists=?  bind:m  (peek-exists:io [%| 1 %& /mirror/[hostta]/[doc-ta] %'sync.sig'])
  ?:  exists  (reply eyre-id 200 'OK')
  ;<  err=(unit tang)  bind:m  (create-mirror hostta doc-ta)
  ?^  err  (reply eyre-id 500 'Open failed')
  (reply eyre-id 201 'Created')
::  +serve-update: relay one update blob to the doc's inbox — local
::  poke if we own the doc, remote poke through the gateway if not
::
++  serve-update
  |=  [eyre-id=@ta src=@p req=inbound-request:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  our=@p  bind:m  get-our:io
  ?.  =(src our)  (reply eyre-id 403 'Forbidden')
  =/  jon=(unit json)  (post-json req)
  =/  host=(unit @p)  (biff (jstr jon 'host') (cury slaw %p))
  =/  doc=(unit @t)  (jstr jon 'doc')
  =/  update=(unit @t)  (jstr jon 'update')
  ?:  |(?=(~ host) ?=(~ doc) ?=(~ update) !(valid-name u.doc))
    (reply eyre-id 400 'Bad update')
  =/  doc-ta=@ta  `@ta`u.doc
  =/  inbox=road:tarball
    ?:  =(u.host our)  [%| 1 %& /docs/[doc-ta] %'inbox.sig']
    =/  hostta=@ta  (scot %p u.host)
    [%& %& :(weld /sys/ames/ships/[hostta]/root nex-dir /docs/[doc-ta]) %'inbox.sig']
  ;<  err=(unit tang)  bind:m  (poke-road-soft:io inbox [[/ %txt] `wain`~[u.update]])
  ?^  err  (reply eyre-id 502 'Delivery failed')
  (reply eyre-id 200 'OK')
::  +create-doc: dir, log dir, inbox — in order, first failure wins
::
++  create-doc
  |=  doc=@ta
  =/  m  (fiber:fiber:nexus ,(unit tang))
  ^-  form:m
  ;<  err=(unit tang)  bind:m  (ensure-dir /docs/[doc])
  ?^  err  (pure:m err)
  ;<  err=(unit tang)  bind:m  (ensure-dir /docs/[doc]/log)
  ?^  err  (pure:m err)
  (make-soft:io [%| 1 %& /docs/[doc] %'inbox.sig'] |+[[[/ %sig] ~] ~])
::  +create-mirror: mirror dirs plus the sync.sig whose fiber runs
::  the remote subscription
::
++  create-mirror
  |=  [hostta=@ta doc=@ta]
  =/  m  (fiber:fiber:nexus ,(unit tang))
  ^-  form:m
  ;<  err=(unit tang)  bind:m  (ensure-dir /mirror/[hostta])
  ?^  err  (pure:m err)
  ;<  err=(unit tang)  bind:m  (ensure-dir /mirror/[hostta]/[doc])
  ?^  err  (pure:m err)
  ;<  err=(unit tang)  bind:m  (ensure-dir /mirror/[hostta]/[doc]/log)
  ?^  err  (pure:m err)
  (make-soft:io [%| 1 %& /mirror/[hostta]/[doc] %'sync.sig'] |+[[[/ %sig] ~] ~])
::  +ensure-dir: create a nexus-relative dir if absent
::
++  ensure-dir
  |=  pax=path
  =/  m  (fiber:fiber:nexus ,(unit tang))
  ^-  form:m
  =/  =road:tarball  [%| 1 %| pax]
  =/  init=bole:tarball  [`[~ ~ %.n ~] ~]
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?:  exists  (pure:m ~)
  (make-soft:io road &+init)
::  +kid-names: subdirectory names of a dir view
::
++  kid-names
  |=  =view:nexus
  ^-  (list @ta)
  ?.  ?=([%ball *] view)  ~
  (turn ~(tap by dir.ball.view) head)
::  +mirror-json: [{host, docs}] for every mirrored doc
::
++  mirror-json
  |=  =view:nexus
  ^-  json
  ?.  ?=([%ball *] view)  a+~
  :-  %a
  %+  turn  ~(tap by dir.ball.view)
  |=  [host=@ta sub=ball:tarball]
  %-  pairs:enjs:format
  :~  ['host' s+host]
      ['docs' a+(turn (turn ~(tap by dir.sub) head) |=(d=@ta s+d))]
  ==
::  +post-json: parsed body of a POST request, ~ otherwise
::
++  post-json
  |=  req=inbound-request:eyre
  ^-  (unit json)
  ?.  =(%'POST' method.request.req)  ~
  ?~  body.request.req  ~
  (de:json:html q.u.body.request.req)
::  +jstr: string value at a key of a (unit json) object
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
::  +valid-name: pad names are 1-64 chars of [a-z0-9-]
::
++  valid-name
  |=  n=@t
  ^-  ?
  =/  t=tape  (trip n)
  ?&  !=(~ t)
      (lte (lent t) 64)
      %+  levy  t
      |=  c=@t
      ?|  &((gte c 'a') (lte c 'z'))
          &((gte c '0') (lte c '9'))
          =(c '-')
      ==
  ==
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
