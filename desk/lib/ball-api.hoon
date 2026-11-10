::  lib/ball-api: HTTP API handlers for the grubbery namespace
::
::  Provides request fiber logic for /grubbery/api/* endpoints.
::  Used by root nexus on-file for /sys/eyre/requests/ fibers.
::
::  The endpoints are the darts: peek, poke, make, cull, sand, keep,
::  born. A path's trailing slash names the fold at it, its absence the
::  grub. Every read but the tarball is answered inline by
::  +serve-api-read-sync in the kernel; what remains here is the half
::  that needs a fiber — writes, pokes, uploads and the keep stream.
::
/+  nexus, tarball, server, multipart, http-utils, html-utils,
    json-utils, zlib, bytestream, io=fiberio
|%
::  HTTP response helper — pokes /sys/eyre/main.server-state
::
::  +dispatch: entry point for request fibers
::
++  dispatch
  |=  [eyre-id=@ta src=@p req=inbound-request:eyre site=path args=quay:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ::  No src == our check. Authority was decided in +route-http from the
  ::  asker's own position (+asker-rail) before this request grub existed,
  ::  and it cannot be re-decided here: a request grub lives at
  ::  /sys/eyre/requests, so these darts originate under eyre's authority,
  ::  not the asker's. A blanket 403 here makes every foreign weir dead
  ::  code.
  ?>  ?=([%grubbery %api *] site)
  =/  rest=path  t.t.site
  ::  one endpoint per dart: peek, poke, make, cull, sand, keep, born
  ?~  rest
    (send-error eyre-id 400 'Missing endpoint: peek, poke, make, cull, sand, keep, born')
  =/  endpoint=@tas  i.rest
  ::  the trailing slash names the fold at that path
  =/  raw-path=path  t.rest
  =/  slashed=?  ?&(?=(^ raw-path) =('' (rear raw-path)))
  =/  api-path=path  ?.(slashed raw-path (snip `path`raw-path))
  =/  as=@t  (fall (get-key:kv:html-utils 'as' args) '')
  =/  ct=(unit @t)  (get-header:http 'content-type' header-list.request.req)
  =/  multipart=?
    ?~(ct %.n ?=(^ (find "multipart/form-data" (trip u.ct))))
  ::  a mime grub's content type is the one the writer sent. Nothing is
  ::  inferred from the name: blot and neck are said outright, and a body
  ::  with no Content-Type is bytes, which is what octet-stream means.
  =/  content-type=path  (mime-type ct)
  ?+    [method.request.req endpoint]
      (send-error eyre-id 405 'Method Not Allowed')
  ::  GET /peek/... — every rendering but the tarball is answered inline by
  ::  +serve-api-read-sync, which gates runnable content-types behind
  ::  +serve-sandbox. There is deliberately no fiber-side twin of those: a
  ::  second serve arm is a second place for that gate to be forgotten.
      [%'GET' %peek]
    ?.  =('tar' as)  (send-error eyre-id 400 'Unknown rendering')
    (serve-tar eyre-id api-path)
  ::  POST /poke/... — poke a grub
      [%'POST' %poke]   (serve-post eyre-id api-path args body.request.req content-type %poke)
  ::  PUT /make/... — make a grub, a fold (trailing slash), or a whole
  ::  upload (multipart body); ?force=1 overwrites what is already there
      [%'PUT' %make]
    ?:  multipart  (serve-upload eyre-id api-path req)
    ?:  slashed    (serve-dir-make eyre-id api-path body.request.req)
    ?:  =('1' (fall (get-key:kv:html-utils 'force' args) ''))
      (serve-post eyre-id api-path args body.request.req content-type %over)
    (serve-file-make eyre-id api-path args body.request.req content-type)
  ::  DELETE /cull/... — cull a grub or a fold
      [%'DELETE' %cull]
    ?:  |(slashed ?=(~ api-path))  (serve-dir-cull eyre-id api-path)
    ;<  exists=?  bind:m  (peek-exists:io [%& %& (snip `path`api-path) (rear api-path)])
    ?:  exists  (serve-file-cull eyre-id api-path)
    (serve-dir-cull eyre-id api-path)
  ::  PUT /sand/... — set a fold's weir from a JSON body
      [%'PUT' %sand]     (serve-weir-put eyre-id api-path body.request.req)
  ::  DELETE /sand/... — clear a fold's weir
      [%'DELETE' %sand]  (serve-weir-del eyre-id api-path)
  ::  GET /keep/... — SSE stream of changes
      [%'GET' %keep]     (serve-keep eyre-id api-path args req)
  ==
::  +mime-type: the Content-Type a request sent, as a mime path.
::    Parameters (charset and friends) are dropped; an absent or
::    unreadable header is octet-stream, the honest answer for bytes
::    whose writer said nothing about them.
::
++  mime-type
  |=  ct=(unit @t)
  ^-  path
  ?~  ct  /application/octet-stream
  =/  txt=tape  (trip u.ct)
  =/  cut=(unit @ud)  (find ";" txt)
  =/  bare=tape  ?~(cut txt (scag u.cut txt))
  =/  slash=(unit @ud)  (find "/" bare)
  ?~  slash  /application/octet-stream
  =/  before=tape  (scag u.slash bare)
  =/  after=tape   (slag +(u.slash) bare)
  ?:  |(?=(~ before) ?=(~ after))  /application/octet-stream
  ~[(crip before) (crip after)]
::  +send-error: respond with HTTP error
::
++  send-error
  |=  [eyre-id=@ta code=@ud msg=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (send-simple:http-res:io eyre-id [[code ~] `(as-octs:mimes:html msg)])
::  +send-ok: respond with 200 and message
::
++  send-ok
  |=  [eyre-id=@ta msg=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (send-simple:http-res:io eyre-id [[200 ~] `(as-octs:mimes:html msg)])
::  +send-created: respond with 201 Created
::
++  send-created
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (send-simple:http-res:io eyre-id [[201 ~] `(as-octs:mimes:html 'Created')])
::  +send-mime: respond with 200 and mime body
::
++  send-mime
  |=  [eyre-id=@ta =mime]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (send-simple:http-res:io eyre-id (mime-response:http-utils mime))
::  +maybe-convert: optionally convert cage through ?blot= param
::    Returns ~ on error (error response already sent).
::    blot-param is a path-encoded blot, e.g. "/json" or "/wallet/wallet"
::
++  maybe-convert
  |=  [eyre-id=@ta =sage:tarball blot-param=(unit @t)]
  =/  m  (fiber:fiber:nexus ,(unit sage:tarball))
  ^-  form:m
  ?~  blot-param  (pure:m `sage)
  =/  target-path=path  (stab u.blot-param)
  ?~  target-path
    ;<  ~  bind:m  (send-error eyre-id 400 'Invalid blot path')
    (pure:m ~)
  =/  target-blot=blot:tarball
    [(snip `path`target-path) (rear target-path)]
  ?:  =(p.sage target-blot)  (pure:m `sage)
  ;<  tube=(unit tube:clay)  bind:m  (get-tube:io [%& %| /code] [p.sage target-blot])
  ?~  tube
    ;<  ~  bind:m  (send-error eyre-id 400 'No tube for mark conversion')
    (pure:m ~)
  =/  result=(each vase tang)
    (mule |.((u.tube q.sage)))
  ?:  ?=(%| -.result)
    ;<  ~  bind:m  (send-error eyre-id 500 'Mark conversion failed')
    (pure:m ~)
  (pure:m `[target-blot p.result])
::  +send-json: respond with JSON body
::
++  send-json
  |=  [eyre-id=@ta =json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  bod=octs  (as-octs:mimes:html (en:json:html json))
  (send-simple:http-res:io eyre-id (mime-response:http-utils [/application/json bod]))
::  +peek-root: peek the root ball
::
++  peek-root
  =/  m  (fiber:fiber:nexus ,(unit ball:tarball))
  ^-  form:m
  ;<  root-view=view:nexus  bind:m  (peek:io [%& %| ~] ~)
  ?.  ?=([%ball *] root-view)
    (pure:m ~)
  (pure:m `ball.root-view)
::  +serve-tar: GET /peek?as=tar — tarball download
::
++  serve-tar
  |=  [eyre-id=@ta api-path=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  root-view=view:nexus  bind:m  (peek:io [%& %| ~] ~)
  ?.  ?=([%ball *] root-view)
    (send-error eyre-id 500 'Peek failed')
  =/  root=ball:tarball  ball.root-view
  =/  sub=(unit ball:tarball)  (~(dap ba:tarball root) api-path)
  ?~  sub
    (send-error eyre-id 404 'Not found')
  ;<  now=@da  bind:m  get-time:io
  ;<  conversions=(map bars:tarball tube:clay)  bind:m
    (get-blot-conversions:io u.sub)
  =/  tar=tarball:tarball
    (~(make-tarball gen:tarball [now conversions]) api-path u.sub)
  =/  tar-data=octs  (encode-tarball:tarball tar)
  =/  dir-name=tape
    ?~(api-path "root" (trip (rear api-path)))
  =/  headers=header-list:http
    :~  ['content-type' 'application/x-tar']
        ['content-disposition' (crip "attachment; filename=\"{dir-name}.tar\"")]
    ==
  (send-simple:http-res:io eyre-id [[200 headers] `tar-data])
::  +serve-file-make: PUT /make — make a grub
::
++  serve-file-make
  |=  $:  eyre-id=@ta
          api-path=path
          args=(list [key=@t value=@t])
          body=(unit octs)
          content-type=path
      ==
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  api-path
    (send-error eyre-id 400 'File path required')
  ?~  body
    (send-error eyre-id 400 'Missing body')
  =/  =rail:tarball  [(snip `path`api-path) (rear api-path)]
  =/  =road:tarball  [%& %& rail]
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?:  exists
    (send-error eyre-id 409 'Already exists')
  =/  blot-param=(unit @t)  (get-key:kv:html-utils 'blot' args)
  =/  mime-sage=sage:tarball  [[/ %mime] !>(`mime`[content-type u.body])]
  ;<  converted=(unit sage:tarball)  bind:m  (maybe-convert eyre-id mime-sage blot-param)
  ?~  converted  (pure:m ~)
  ;<  ~  bind:m  (make:io road [%| [p.u.converted q.q.u.converted] ~])
  (send-created eyre-id)
::  +serve-dir-make: PUT /make/<dir>/ — make a fold, with its payload
::
++  serve-dir-make
  |=  [eyre-id=@ta api-path=path body=(unit octs)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  api-path
    (send-error eyre-id 400 'Directory path required')
  =/  =road:tarball  [%& %| api-path]
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?:  exists
    (send-error eyre-id 409 'Already exists')
  ::  a fold's payload is what the dart carries: which nexus runs here
  ::  (neck), the weir it runs under, and whether writes are kept (gain).
  ::  A mount and its sandbox are one dart, so a nexus never exists for
  ::  an event without the weir that confines it.
  =/  jon=json
    ?~  body  [%o ~]
    (fall (de:json:html q.u.body) [%o ~])
  =/  fields=(map @t json)  ?.(?=([%o *] jon) ~ p.jon)
  =/  neck=(unit neck:tarball)
    =/  n=(unit json)  (~(get by fields) 'neck')
    ?.  ?=([~ %s *] n)  ~
    =/  p=path  (stab p.u.n)
    ?~  p  ~
    `[(snip `path`p) (rear p)]
  =/  weir=(unit weir:nexus)
    =/  w=(unit json)  (~(get by fields) 'weir')
    ?~  w  ~
    =/  parsed=(each weir:nexus tang)  (mule |.((weir-from-json:nexus u.w)))
    ?:(?=(%| -.parsed) ~ `p.parsed)
  =/  gain=?
    =/  g=(unit json)  (~(get by fields) 'gain')
    ?=([~ %b %&] g)
  ;<  ~  bind:m  (make:io road &+[`[neck weir gain ~] ~])
  (send-created eyre-id)
::  +serve-post: POST /poke, PUT /make?force=1 — send the dart to a grub
::
++  serve-post
  |=  $:  eyre-id=@ta
          api-path=path
          args=(list [key=@t value=@t])
          body=(unit octs)
          content-type=path
          op=?(%poke %over)
      ==
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  api-path
    (send-error eyre-id 400 'File path required')
  ?~  body
    (send-error eyre-id 400 'Missing body')
  =/  =road:tarball  [%& %& (snip `path`api-path) (rear api-path)]
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?.  exists
    (send-error eyre-id 404 'Not found')
  =/  blot-param=(unit @t)  (get-key:kv:html-utils 'blot' args)
  =/  mime-sage=sage:tarball  [[/ %mime] !>(`mime`[content-type u.body])]
  ;<  converted=(unit sage:tarball)  bind:m  (maybe-convert eyre-id mime-sage blot-param)
  ?~  converted  (pure:m ~)
  ;<  ~  bind:m
    ?-  op
      %poke  (poke:io road [p.u.converted q.q.u.converted])
      %over  (over:io road [p.u.converted q.q.u.converted])
    ==
  (send-ok eyre-id 'OK')
::  +serve-file-cull: DELETE /cull — cull a grub
::
++  serve-file-cull
  |=  [eyre-id=@ta api-path=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  api-path
    (send-error eyre-id 400 'File path required')
  =/  =road:tarball  [%& %& (snip `path`api-path) (rear api-path)]
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?.  exists
    (send-error eyre-id 404 'Not found')
  ;<  ~  bind:m  (cull:io road)
  (send-ok eyre-id 'Deleted')
::  +serve-dir-cull: DELETE /cull/<dir>/ — cull a fold
::
++  serve-dir-cull
  |=  [eyre-id=@ta api-path=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  api-path
    (send-error eyre-id 400 'Directory path required')
  =/  =road:tarball  [%& %| api-path]
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?.  exists
    (send-error eyre-id 404 'Not found')
  ;<  ~  bind:m  (cull:io road)
  (send-ok eyre-id 'Deleted')
::  +ensure-parents: create parent directories if they don't exist
::
++  ensure-parents
  |=  [base=path segments=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  segments  (pure:m ~)
  =/  next=path  (snoc base i.segments)
  =/  dir-road=road:tarball  [%& %| next]
  ;<  exists=?  bind:m  (peek-exists:io dir-road)
  ?.  exists
    ;<  ~  bind:m
      (make:io dir-road &+[`[~ ~ %.n ~] ~])
    (ensure-parents next t.segments)
  (ensure-parents next t.segments)
::  +serve-upload: PUT /make with a multipart body — upload files or a tree
::
++  serve-upload
  |=  [eyre-id=@ta tree-path=path req=inbound-request:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  parts=(unit (list [@t part:multipart]))
    (de-request:multipart header-list.request.req body.request.req)
  ?~  parts
    (send-error eyre-id 400 'Invalid multipart data')
  ::  An upload is mime in, mime out. A name is not a declaration: a blot
  ::  is said outright with ?blot=, and converting by extension put marked
  ::  grubs where only mime belongs — a forge repo tree takes nothing else,
  ::  so uploads into one vanished with a 201 in hand.
  ::  Process each file part directly
  =|  created=(list @t)
  =/  remaining  u.parts
  |-
  ?~  remaining
    =/  response=json
      %-  pairs:enjs:format
      :~  ['path' s+?~(tree-path '/' (spat tree-path))]
          ['created' [%a (turn (flop created) |=(n=@t s+n))]]
      ==
    =/  bod=octs  (as-octs:mimes:html (en:json:html response))
    (send-simple:http-res:io eyre-id [[201 ~[['content-type' 'application/json']]] `bod])
  =/  [field-name=@t file-part=part:multipart]  i.remaining
  ?.  =('file' field-name)
    $(remaining t.remaining)
  =/  filename-raw=@t
    (fall file.file-part 'uploaded-file')
  ::  Parse filename — may include path for directory uploads
  =/  filename-path=path
    (fall (rush (crip (weld "/" (trip filename-raw))) stap) ~)
  ?~  filename-path
    $(remaining t.remaining)
  ::  Split into parent dirs and leaf filename
  =/  [file-parent=path file-name=@ta]
    ?~  t.filename-path
      [~ i.filename-path]
    [(snip `(list @ta)`filename-path) (rear filename-path)]
  =/  full-path=path  (weld tree-path file-parent)
  ::  Build mime cage and try mark conversion
  =/  file-mime=mime
    :_  body.file-part
    (fall type.file-part /application/octet-stream)
  =/  final-sage=sage:tarball  [[/ %mime] !>(file-mime)]
  ::  Ensure parent dirs exist
  ;<  ~  bind:m  (ensure-parents tree-path file-parent)
  ::  Create or overwrite file — keep full filename
  =/  =road:tarball  [%& %& full-path file-name]
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?:  exists
    ;<  ~  bind:m  (over:io road [p.final-sage q.q.final-sage])
    $(remaining t.remaining, created [filename-raw created])
  ;<  ~  bind:m  (make:io road |+[[p.final-sage q.q.final-sage] ~])
  $(remaining t.remaining, created [filename-raw created])
::  +serve-weir-put: PUT /sand — set a fold's weir from a JSON body
::
++  serve-weir-put
  |=  [eyre-id=@ta api-path=path body=(unit octs)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  body
    (send-error eyre-id 400 'Missing body')
  =/  jon=(unit json)  (de:json:html q.u.body)
  ?~  jon
    (send-error eyre-id 400 'Invalid JSON')
  =/  parsed=(each weir:nexus tang)
    (mule |.((weir-from-json:nexus u.jon)))
  ?:  ?=(%| -.parsed)
    (send-error eyre-id 400 'Invalid weir JSON')
  ;<  ~  bind:m  (sand:io [%& %| api-path] `p.parsed)
  (send-ok eyre-id 'OK')
::  +serve-weir-del: DELETE /sand — clear a fold's weir
::
++  serve-weir-del
  |=  [eyre-id=@ta api-path=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  ~  bind:m  (sand:io [%& %| api-path] ~)
  (send-ok eyre-id 'Deleted')
::  +serve-keep: GET /keep — SSE stream of changes at a road
::
++  serve-keep
  |=  [eyre-id=@ta api-path=path args=(list [key=@t value=@t]) req=inbound-request:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  (is-sse-request:http-utils req)
    (send-error eyre-id 400 'Requires Accept: text/event-stream')
  =/  blot-param=(unit @t)  (get-key:kv:html-utils 'blot' args)
  ::  Send SSE response header
  ;<  ~  bind:m
    (send-header:http-res:io eyre-id sse-header:http-utils)
  ::  Determine road: check if api-path points to a file
  =/  file-road=(unit road:tarball)
    ?~  api-path  ~
    `[%& %& (snip `path`api-path) (rear api-path)]
  ;<  is-file=?  bind:m
    ?~  file-road  (pure:(fiber:fiber:nexus ,?) %.n)
    (peek-exists:io u.file-road)
  =/  =road:tarball
    ?:  is-file  (need file-road)
    [%& %| api-path]
  ::  Base dir for reconstructing absolute roads from relative wave lanes.
  ::  For file subscriptions, api-path includes the filename — strip it.
  =/  base-dir=path  ?:(is-file (snip `path`api-path) api-path)
  ::  Subscribe to changes — bond returns initial wavefront
  ;<  init=wave:nexus  bind:m  (keep:io /keep road ~)
  ::  Send "old" events for initial state
  ;<  ~  bind:m
    =/  lanes=(list [=lane:tarball =cass:clay])  ~(tap by (diff-wave:nexus *wave:nexus init))
    |-
    ?~  lanes  (pure:m ~)
    ?:  ?=(%| -.lane.i.lanes)  $(lanes t.lanes)
    ::  wave lanes are relative to subscription — resolve to absolute for peek
    =/  file-road=road:tarball  [%& %& (weld base-dir path.p.lane.i.lanes) name.p.lane.i.lanes]
    ;<  =view:nexus  bind:m  (peek:io file-road ~)
    ?.  ?=([%file *] view)  $(lanes t.lanes)
    =/  lane-path=@t  (spat (snoc path.p.lane.i.lanes name.p.lane.i.lanes))
    =/  id=@t  (scot %ud ud.cass.i.lanes)
    =/  event-name=@t  (crip "old {(trip lane-path)}")
    ;<  body=(unit @t)  bind:m  (sage-to-txt (need-sage:tarball sang.view) blot-param)
    ?~  body  $(lanes t.lanes)
    =/  data=wain  (to-wain:format u.body)
    =/  =sse-event:http-utils  [`id `event-name data]
    ;<  ~  bind:m
      (send-data:http-res:io eyre-id `(sse-encode:http-utils ~[sse-event]))
    $(lanes t.lanes)
  ::  Track seen lanes for new vs upd detection
  =/  prev=wave:nexus  init
  ::  Start keep-alive timer
  ;<  now=@da  bind:m  get-time:io
  ;<  ~  bind:m  (send-wait:io (add now ~s30))
  ::  Event loop
  |-
  ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /keep)
  ?-    -.nw
      %wake
    ;<  ~  bind:m
      (send-data:http-res:io eyre-id `sse-keep-alive:http-utils)
    ;<  now=@da  bind:m  get-time:io
    ;<  ~  bind:m  (send-wait:io (add now ~s30))
    $
  ::
      %news
    =/  changes=(map lane:tarball cass:clay)  (diff-wave:nexus prev wave.nw)
    =.  prev  wave.nw
    =/  lanes=(list [=lane:tarball =cass:clay])  ~(tap by changes)
    |-
    ?~  lanes  ^$
    ?:  ?=(%| -.lane.i.lanes)  $(lanes t.lanes)
    ::  wave lanes are relative to subscription — resolve to absolute for peek
    =/  file-road=road:tarball  [%& %& (weld base-dir path.p.lane.i.lanes) name.p.lane.i.lanes]
    ;<  =view:nexus  bind:m  (peek:io file-road ~)
    =/  lane-path=@t  (spat (snoc path.p.lane.i.lanes name.p.lane.i.lanes))
    =/  id=@t  (scot %ud ud.cass.i.lanes)
    ?:  ?=([%file *] view)
      =/  was-known=?
        =/  node=(unit [fold=cass:clay file=(map @ta cass:clay)])
          (~(get of prev) path.p.lane.i.lanes)
        ?~  node  %.n
        (~(has by file.u.node) name.p.lane.i.lanes)
      =/  action=@t  ?:(was-known 'upd' 'new')
      =/  event-name=@t  (crip "{(trip action)} {(trip lane-path)}")
      ;<  body=(unit @t)  bind:m  (sage-to-txt (need-sage:tarball sang.view) blot-param)
      ?~  body  $(lanes t.lanes)
      =/  data=wain  (to-wain:format u.body)
      =/  =sse-event:http-utils  [`id `event-name data]
      ;<  ~  bind:m
        (send-data:http-res:io eyre-id `(sse-encode:http-utils ~[sse-event]))
      $(lanes t.lanes)
    ::  File gone — send delete event
    =/  event-name=@t  (crip "del {(trip lane-path)}")
    =/  =sse-event:http-utils  [`id `event-name ~['']]
    ;<  ~  bind:m
      (send-data:http-res:io eyre-id `(sse-encode:http-utils ~[sse-event]))
    $(lanes t.lanes)
  ==
::  +send-old-dir: send "old" SSE events for all files in a ball
::
++  send-old-dir
  |=  [eyre-id=@ta b=ball:tarball =born:nexus here=path blot-param=(unit @t)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ::  Send "old" for files in this directory
  ;<  ~  bind:m
    ?~  fil.b  (pure:m ~)
    =/  files=(list [@ta [=sang:tarball gain=? bang=(unit tang)]])  ~(tap by contents.u.fil.b)
    |-
    ?~  files  (pure:m ~)
    =/  [file-name=@ta =sang:tarball gain=? bang=(unit tang)]  i.files
    =/  lane-path=@t  (spat (snoc here file-name))
    =/  sub-born=born:nexus  (~(dip of born) here)
    =/  file-hist=(unit hist:nexus)
      ?~  fil.sub-born  ~
      (~(get by file.u.fil.sub-born) file-name)
    =/  id=@t
      ?~  file-hist  '0'
      (scot %ud (ver:hist:nexus u.file-hist))
    =/  event-name=@t  (crip "old {(trip lane-path)}")
    ;<  body=(unit @t)  bind:m  (sage-to-txt (need-sage:tarball sang) blot-param)
    ?~  body  $(files t.files)
    =/  data=wain  (to-wain:format u.body)
    =/  =sse-event:http-utils  [`id `event-name data]
    ;<  ~  bind:m
      (send-data:http-res:io eyre-id `(sse-encode:http-utils ~[sse-event]))
    $(files t.files)
  ::  Recurse into subdirectories
  =/  dirs=(list [@ta ball:tarball])  ~(tap by dir.b)
  |-
  ?~  dirs  (pure:m ~)
  =/  [dir-name=@ta sub=ball:tarball]  i.dirs
  ;<  ~  bind:m  (send-old-dir eyre-id sub born (snoc here dir-name) blot-param)
  $(dirs t.dirs)
::
::  +sage-to-txt: convert sage to text for SSE data
::
::    With blot param: sage -> target blot -> txt; a failed conversion
::    returns ~ so callers skip the event rather than send wrong data
::    (mirrors maybe-convert's strictness on the /file endpoint).
::    Without: sage -> txt directly.
::
++  sage-to-txt
  |=  [=sage:tarball blot-param=(unit @t)]
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  ?~  blot-param
    ;<  t=@t  bind:m  (sage-to-txt-raw sage)
    (pure:m `t)
  =/  target-path=path  (stab u.blot-param)
  ?~  target-path
    (pure:m ~)
  =/  target-blot=blot:tarball
    [(snip `path`target-path) (rear target-path)]
  ?:  =(p.sage target-blot)
    ;<  t=@t  bind:m  (sage-to-txt-raw sage)
    (pure:m `t)
  ;<  tube=(unit tube:clay)  bind:m  (get-tube:io [%& %| /code] [p.sage target-blot])
  ?~  tube
    (pure:m ~)
  =/  result=(each vase tang)  (mule |.((u.tube q.sage)))
  ?:  ?=(%| -.result)
    (pure:m ~)
  ;<  t=@t  bind:m  (sage-to-txt-raw [target-blot p.result])
  (pure:m `t)
::  +sage-to-txt-raw: convert a single sage to @t
::
++  sage-to-txt-raw
  |=  =sage:tarball
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  ?:  =(%txt name.p.sage)
    (pure:m (of-wain:format !<(wain q.sage)))
  ;<  tube=(unit tube:clay)  bind:m  (get-tube:io [%& %| /code] [p.sage [/ %txt]])
  ?~  tube
    ::  Fallback: convert to mime and extract body as text
    ;<  =mime  bind:m  (sage-to-mime:io sage)
    (pure:m `@t`(end [3 p.q.mime] q.q.mime))
  =/  result=(each vase tang)  (mule |.((u.tube q.sage)))
  ?:  ?=(%| -.result)
    ;<  =mime  bind:m  (sage-to-mime:io sage)
    (pure:m `@t`(end [3 p.q.mime] q.q.mime))
  (pure:m (of-wain:format !<(wain p.result)))
--
