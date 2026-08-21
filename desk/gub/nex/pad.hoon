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
/<  sh  /lib/shell.hoon
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
          [%over %& [/ %'alias.json'] [[/ %json] (pairs:enjs:format ~[['name' s+'pad'] ['description' s+'Cross-ship collaborative text pads']])]]
          [%over %& [/ %'weir.json'] [[/ %json] weir-json]]
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
        ;<  ~  bind:m  (grant-public rail)
        ;<  ~  bind:m  (bind-http-self:io [~ /grubbery/pad])
        (http-dispatch:io %pad)
          ::  /docs/<doc>/inbox.sig: the sequencer. Local and remote
          ::  editors poke a base64 update cord; arrival order here IS
          ::  the doc's order. Each poke lands as a fresh log grub.
          ::
          [[%docs @ ~] %'inbox.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%pad /inbox: failed")
        inbox-loop
          ::  /docs/<doc>/aware.sig: presence relay. Each editor pokes
          ::  its awareness blob; it lands as /aware/<ship>, overwritten
          ::  in place — lossy by design, no history worth keeping.
          ::
          [[%docs @ ~] %'aware.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%pad /aware: failed")
        aware-loop
          ::  /mirror/<host>/<doc>/sync.sig: live local mirror of a
          ::  remote doc's log and presence. All network traffic for
          ::  the doc lives in this fiber; an unreachable host blocks
          ::  nothing else.
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
::  +weir-json: pad's boundary crossings. Its /docs, /mirror, /log
::  and ui grubs are its own subtree (relative %| roads, not gated);
::  the cross-boundary reach is to other ships' pad instances.
::
::  TODO: /sys/ames/ships/ is broader than pad wants. Its real reach is
::  /sys/ames/ships/<host>/root/apps/pad.pad/ — "the pad app on any
::  ship" — but the host sits mid-path and the weir matcher is strict
::  prefix, so no road expresses it. We are NOT widening what a weir is;
::  think about how cross-ship apps get scoped without that (a broker
::  holding the broad grant? per-host grants issued as docs open?).
::  Related: a cross-ship ALIAS system — remote reaches want the same
::  @name -> path indirection local grants already have, so users
::  approve "pad on ~host", not a raw ames path.
::
++  weir-json
  ^-  json
  =/  line  |=([r=@t w=@t] `json`(pairs:enjs:format ~[['road' s+r] ['why' s+w]]))
  %-  pairs:enjs:format
  :~  :-  'poke'
      :-  %a
      :~  (line '/sys/bowl.sig' 'read the current time and our ship — get-time / get-our')
          (line '/sys/eyre/' 'bind its HTTP route and send page responses')
          (line '/sys/ames/ships/' 'remote-poke a host ship sequencer when editing a doc we do not own')
      ==
      :-  'peek'
      :-  %a
      :~  (line '/sys/ames/ships/' 'subscribe to and mirror remote docs from their host ships')
      ==
  ==
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
  |=  rail=rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  here=rail:tarball  bind:m  (here-abs:sh rail)
  ;<  ~  bind:m  (reg-register-at:io here)
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
::  +aware-loop: relay presence blobs into per-ship grubs, overwritten
::  in place. Bad input is skipped — presence is lossy by design.
::
++  aware-loop
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |-
  ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
  ;<  our=@p  bind:m  get-our:io
  =/  blob=(unit @t)  (mole |.((rear !<(wain q.sage))))
  ?~  blob  $
  ?:  (gth (met 3 u.blob) max-update-bytes)  $
  =/  src=@p  (fall (get-poke-src:io from) our)
  ;<  ~  bind:m
    (put:io [%| 0 %& /aware (scot %p src)] [[/ %txt] `wain`~[u.blob]])
  $
::  +sync-loop: subscribe to a remote doc dir and copy its log and
::  presence entries into our sibling dirs, where local browsers
::  watch them
::
++  sync-loop
  |=  [host=@ta doc=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  src-path=path  :(weld /sys/ames/ships/[host]/root nex-dir /docs/[doc])
  ;<  init=wave:nexus  bind:m  (keep:io /src [%& %| src-path] ~)
  ;<  ~  bind:m  (sync-changes src-path *wave:nexus init)
  =/  prev=wave:nexus  init
  |-
  ;<  next=wave:nexus  bind:m  (take-news:io /src)
  ;<  ~  bind:m  (sync-changes src-path prev next)
  $(prev next)
::  +sync-changes: mirror the changed remote entries. Only /log and
::  /aware lanes are data; the doc root holds sig grubs that must not
::  be copied (a mirrored sig would spawn its fiber here). One deep
::  peek of the doc dir serves every changed lane — a single snap
::  negotiation per wave instead of a round trip per entry.
::
++  sync-changes
  |=  [src-path=path prev=wave:nexus cur=wave:nexus]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  changed=(list [=rail:tarball =cass:clay])
    %+  murn  ~(tap by (diff-wave:nexus prev cur))
    |=  [=lane:tarball =cass:clay]
    ^-  (unit [rail:tarball cass:clay])
    ?.  ?=(%& -.lane)  ~
    ?.  ?|  ?=([%log *] path.p.lane)
            ?=([%aware *] path.p.lane)
        ==
      ~
    `[p.lane cass]
  ?~  changed  (pure:m ~)
  ;<  =view:nexus  bind:m  (peek:io [%& %| src-path] ~)
  ?.  ?=([%ball *] view)  (pure:m ~)
  =/  todo=(list [=rail:tarball =cass:clay])  changed
  |-
  ?~  todo  (pure:m ~)
  =/  =rail:tarball  rail.i.todo
  =/  dest=road:tarball  [%| 0 %& path.rail name.rail]
  =/  fil=(unit sang:tarball)  (ball-file ball.view rail)
  ?~  fil
    ;<  *  bind:m  (cull-soft:io dest)
    $(todo t.todo)
  ;<  ~  bind:m  (over:io dest [p.u.fil (sang-noun:tarball u.fil)])
  $(todo t.todo)
::  +ball-file: the sang at a rail inside a peeked ball, if present
::
++  ball-file
  |=  [b=ball:tarball =rail:tarball]
  ^-  (unit sang:tarball)
  =/  sub=(unit ball:tarball)  (~(dap ba:tarball b) path.rail)
  ?~  sub  ~
  ?~  fil.u.sub  ~
  =/  ent  (~(get by contents.u.fil.u.sub) name.rail)
  ?~  ent  ~
  `sang.u.ent
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
    [%api %update ~]  (serve-relay eyre-id src req 'update' %'inbox.sig')
    [%api %aware ~]   (serve-relay eyre-id src req 'aware' %'aware.sig')
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
  ;<  err=(unit tang)  bind:m  (create-mirror hostta doc-ta)
  ?^  err  (reply eyre-id 500 'Open failed')
  (reply eyre-id 201 'Created')
::  +serve-relay: relay one blob to a doc's sequencer sig — local poke
::  if we own the doc, remote poke through the gateway if not. The
::  same shape carries updates (to inbox.sig) and presence (to
::  aware.sig); only the body key and target file differ.
::
++  serve-relay
  |=  [eyre-id=@ta src=@p req=inbound-request:eyre key=@t target=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  our=@p  bind:m  get-our:io
  ?.  =(src our)  (reply eyre-id 403 'Forbidden')
  =/  jon=(unit json)  (post-json req)
  =/  host=(unit @p)  (biff (jstr jon 'host') (cury slaw %p))
  =/  doc=(unit @t)  (jstr jon 'doc')
  =/  blob=(unit @t)  (jstr jon key)
  ?:  |(?=(~ host) ?=(~ doc) ?=(~ blob) !(valid-name u.doc))
    (reply eyre-id 400 'Bad request')
  =/  doc-ta=@ta  `@ta`u.doc
  =/  sig=road:tarball
    ?:  =(u.host our)  [%| 1 %& /docs/[doc-ta] target]
    =/  hostta=@ta  (scot %p u.host)
    [%& %& :(weld /sys/ames/ships/[hostta]/root nex-dir /docs/[doc-ta]) target]
  ::  the deadline is ours, not the poke's: an HTTP request can't wait
  ::  forever on a dead host
  ;<  res=(unit (unit tang))  bind:m
    %^  (with-timeout:io ,(unit tang))  /deliver  ~s15
    (poke-soft:io sig [[/ %txt] `wain`~[u.blob]])
  =/  err=(unit tang)
    ?~(res `~[leaf+"delivery timed out after 15s"] u.res)
  ?^  err
    =/  why=tape  ?~(u.err "no detail" ~(ram re i.u.err))
    (reply eyre-id 502 (crip "Delivery failed: {why}"))
  (reply eyre-id 200 'OK')
::  +create-doc: dirs plus the two sequencer sigs. Idempotent — every
::  step is exists-guarded or soft, so calling it on an existing doc
::  repairs missing pieces (docs made before /aware existed).
::
++  create-doc
  |=  doc=@ta
  =/  m  (fiber:fiber:nexus ,(unit tang))
  ^-  form:m
  ;<  err=(unit tang)  bind:m  (ensure-dir /docs/[doc])
  ?^  err  (pure:m err)
  ;<  err=(unit tang)  bind:m  (ensure-dir /docs/[doc]/log)
  ?^  err  (pure:m err)
  ;<  err=(unit tang)  bind:m  (ensure-dir /docs/[doc]/aware)
  ?^  err  (pure:m err)
  ;<  ~  bind:m  (ensure-sig /docs/[doc] %'inbox.sig')
  ;<  ~  bind:m  (ensure-sig /docs/[doc] %'aware.sig')
  (pure:m ~)
::  +create-mirror: mirror dirs plus the sync.sig whose fiber runs
::  the remote subscription. Idempotent like +create-doc.
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
  ;<  err=(unit tang)  bind:m  (ensure-dir /mirror/[hostta]/[doc]/aware)
  ?^  err  (pure:m err)
  ;<  ~  bind:m  (ensure-sig /mirror/[hostta]/[doc] %'sync.sig')
  (pure:m ~)
::  +ensure-sig: create an empty sig grub if absent
::
++  ensure-sig
  |=  [pax=path name=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  exists=?  bind:m  (peek-exists:io [%| 1 %& pax name])
  ?:  exists  (pure:m ~)
  ;<  *  bind:m  (make-soft:io [%| 1 %& pax name] |+[[[/ %sig] ~] ~])
  (pure:m ~)
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
