::  lib/ball-api: HTTP API handlers for the grubbery namespace
::
::  Provides request fiber logic for /grubbery/api/* endpoints.
::  Used by root nexus on-file for /sys/eyre/requests/ fibers.
::
/+  nexus, tarball, server, multipart, http-utils, html-utils,
    json-utils, zlib, bytestream, io=fiberio
|%
::  +dispatch: entry point for request fibers
::
++  dispatch
  |=  [eyre-id=@ta src=@p req=inbound-request:eyre site=path args=quay:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  our=@p  bind:m  get-our:io
  ?.  =(src our)
    (send-error eyre-id 403 'Forbidden')
  ?>  ?=([%grubbery %api *] site)
  ~&  >>  ["%ball-api: dispatch" method.request.req site]
  =/  rest=path  t.t.site
  ::  Route by first segment: file, kids, tree, tar, dir
  ?~  rest
    (send-error eyre-id 400 'Missing endpoint: file, kids, tree, tar, dir')
  =/  endpoint=@tas  i.rest
  =/  api-path=path  t.rest
  ?+    [method.request.req endpoint]
      (send-error eyre-id 405 'Method Not Allowed')
  ::  GET /file/... — peek file, convert to mime
      [%'GET' %file]   (serve-file-peek eyre-id api-path args)
  ::  GET /kids/... — immediate children (files + subdirs)
      [%'GET' %kids]   (serve-kids eyre-id api-path)
  ::  GET /tree/... — recursive tree with marks
      [%'GET' %tree]   (serve-tree eyre-id api-path)
  ::  GET /tar/...  — tarball download
      [%'GET' %tar]    (serve-tar eyre-id api-path)
  ::  PUT /file/... — create file
      [%'PUT' %file]   (serve-file-make eyre-id api-path args body.request.req)
  ::  PUT /dir/...  — create directory
      [%'PUT' %dir]    (serve-dir-make eyre-id api-path)
  ::  POST /poke/... — poke file process
      [%'POST' %poke]   (serve-post eyre-id api-path args body.request.req %poke)
  ::  POST /over/... — overwrite file content
      [%'POST' %over]   (serve-post eyre-id api-path args body.request.req %over)
  ::  GET /keep/... — SSE stream of changes
      [%'GET' %keep]    (serve-keep eyre-id api-path args req)
  ::  DELETE /file/... — delete file
      [%'DELETE' %file]  (serve-file-cull eyre-id api-path)
  ::  DELETE /dir/...  — delete directory
      [%'DELETE' %dir]   (serve-dir-cull eyre-id api-path)
  ::  GET /sand/...    — get directory permissions as JSON
      [%'GET' %sand]     (serve-sand-peek eyre-id api-path)
  ::  GET /weir/...    — get single directory weir as JSON
      [%'GET' %weir]     (serve-weir-peek eyre-id api-path)
  ::  PUT /weir/...    — replace weir with JSON body
      [%'PUT' %weir]     (serve-weir-put eyre-id api-path body.request.req)
  ::  DELETE /weir/... — clear weir
      [%'DELETE' %weir]  (serve-weir-del eyre-id api-path)
  ::  POST /upload/... — multipart file/directory upload
      [%'POST' %upload]  (serve-upload eyre-id api-path req)
  ::  GET /manu/...  — documentation for a path
      [%'GET' %manu]     (serve-manu eyre-id api-path)
  ==
::  +send-error: respond with HTTP error
::
++  send-error
  |=  [eyre-id=@ta code=@ud msg=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  %-  send-cards:io
  (give-simple-payload:app:server eyre-id [[code ~] `(as-octs:mimes:html msg)])
::  +send-ok: respond with 200 and message
::
++  send-ok
  |=  [eyre-id=@ta msg=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  %-  send-cards:io
  (give-simple-payload:app:server eyre-id [[200 ~] `(as-octs:mimes:html msg)])
::  +send-created: respond with 201 Created
::
++  send-created
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  %-  send-cards:io
  (give-simple-payload:app:server eyre-id [[201 ~] `(as-octs:mimes:html 'Created')])
::  +send-mime: respond with 200 and mime body
::
++  send-mime
  |=  [eyre-id=@ta =mime]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  %-  send-cards:io
  (give-simple-payload:app:server eyre-id (mime-response:http-utils mime))
::  +maybe-convert: optionally convert cage through ?mark= param
::    Returns ~ on error (error response already sent).
::
++  maybe-convert
  |=  [eyre-id=@ta =sage:tarball mark-param=(unit @t)]
  =/  m  (fiber:fiber:nexus ,(unit sage:tarball))
  ^-  form:m
  ?~  mark-param  (pure:m `sage)
  =/  target-mark=@tas  u.mark-param
  ?:  =(name.p.sage target-mark)  (pure:m `sage)
  ;<  tube=(unit tube:clay)  bind:m  (get-tube:io [%& %| /code] [p.sage [/ target-mark]])
  ?~  tube
    ;<  ~  bind:m  (send-error eyre-id 400 'No tube for mark conversion')
    (pure:m ~)
  =/  result=(each vase tang)  (mule |.((u.tube q.sage)))
  ?:  ?=(%| -.result)
    ;<  ~  bind:m  (send-error eyre-id 500 'Mark conversion failed')
    (pure:m ~)
  (pure:m `[[/ target-mark] p.result])
::  +send-json: respond with JSON body
::
++  send-json
  |=  [eyre-id=@ta =json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  bod=octs  (as-octs:mimes:html (en:json:html json))
  %-  send-cards:io
  (give-simple-payload:app:server eyre-id (mime-response:http-utils [/application/json bod]))
::  +peek-root: peek the root ball
::
++  peek-root
  =/  m  (fiber:fiber:nexus ,(unit ball:tarball))
  ^-  form:m
  ;<  root-seen=seen:nexus  bind:m  (peek:io [%& %| ~] ~)
  ?.  ?=([%& %ball *] root-seen)
    (pure:m ~)
  (pure:m `ball.p.root-seen)
::  +serve-file-peek: GET /file — peek grub, convert to mime
::
++  serve-file-peek
  |=  [eyre-id=@ta api-path=path args=(list [key=@t value=@t])]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  api-path
    (send-error eyre-id 400 'File path required')
  ;<  root=(unit ball:tarball)  bind:m  peek-root
  ?~  root
    (send-error eyre-id 500 'Peek failed')
  =/  parent=path  (snip `path`api-path)
  =/  name=@ta  (rear api-path)
  =/  parent-ball=ball:tarball  (~(dip ba:tarball u.root) parent)
  =/  content-data=(unit content:tarball)
    ?~  fil.parent-ball  ~
    (~(get by contents.u.fil.parent-ball) name)
  ?~  content-data
    (send-error eyre-id 404 'Not found')
  =/  =sage:tarball  sage.u.content-data
  =/  mark-param=(unit @t)  (get-key:kv:html-utils 'mark' args)
  ;<  converted=(unit sage:tarball)  bind:m  (maybe-convert eyre-id sage mark-param)
  ?~  converted  (pure:m ~)
  ;<  =mime  bind:m  (sage-to-mime:io u.converted)
  (send-mime eyre-id mime)
::  +serve-kids: GET /kids — immediate children (files + subdirs)
::
++  serve-kids
  |=  [eyre-id=@ta api-path=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  root=(unit ball:tarball)  bind:m  peek-root
  ?~  root
    (send-error eyre-id 500 'Peek failed')
  =/  sub=(unit ball:tarball)  (~(dap ba:tarball u.root) api-path)
  ?~  sub
    (send-error eyre-id 404 'Not found')
  =/  files=(list @ta)  (~(lis ba:tarball u.sub) /)
  =/  subs=(list @ta)   (~(lss ba:tarball u.sub) /)
  %+  send-json  eyre-id
  %-  pairs:enjs:format
  :~  ['files' [%a (turn files |=(n=@ta s+n))]]
      ['dirs' [%a (turn subs |=(n=@ta s+n))]]
  ==
::  +serve-tree: GET /tree — recursive tree with marks
::
++  serve-tree
  |=  [eyre-id=@ta api-path=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  root=(unit ball:tarball)  bind:m  peek-root
  ?~  root
    (send-error eyre-id 500 'Peek failed')
  =/  sub=(unit ball:tarball)  (~(dap ba:tarball u.root) api-path)
  ?~  sub
    (send-error eyre-id 404 'Not found')
  (send-json eyre-id (tree-to-json:tarball (ball-to-tree:tarball u.sub)))
::  +serve-tar: GET /tar — tarball download
::
++  serve-tar
  |=  [eyre-id=@ta api-path=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  root-seen=seen:nexus  bind:m  (peek:io [%& %| ~] ~)
  ?.  ?=([%& %ball *] root-seen)
    (send-error eyre-id 500 'Peek failed')
  =/  root=ball:tarball  ball.p.root-seen
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
  %-  send-cards:io
  (give-simple-payload:app:server eyre-id [[200 headers] `tar-data])
::  +serve-file-make: PUT /file — create file
::
++  serve-file-make
  |=  [eyre-id=@ta api-path=path args=(list [key=@t value=@t]) body=(unit octs)]
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
  =/  mark-param=(unit @t)  (get-key:kv:html-utils 'mark' args)
  =/  gain=?  =('true' (fall (get-key:kv:html-utils 'gain' args) ''))
  =/  mime-sage=sage:tarball  [[/ %mime] !>(`mime`[/application/octet-stream u.body])]
  ;<  converted=(unit sage:tarball)  bind:m  (maybe-convert eyre-id mime-sage mark-param)
  ?~  converted  (pure:m ~)
  ;<  ~  bind:m  (make:io road [%| gain u.converted ~])
  (send-created eyre-id)
::  +serve-dir-make: PUT /dir — create directory
::
++  serve-dir-make
  |=  [eyre-id=@ta api-path=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  api-path
    (send-error eyre-id 400 'Directory path required')
  =/  dir-name=@ta  (rear api-path)
  =/  dir-path=path  (snoc (snip `path`api-path) dir-name)
  =/  =road:tarball  [%& %| dir-path]
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?:  exists
    (send-error eyre-id 409 'Already exists')
  =/  init-ball=ball:tarball  [`[~ ~ ~] ~]
  ;<  ~  bind:m  (make:io road &+[[~ ~] [~ ~] init-ball])
  (send-created eyre-id)
::  +serve-post: POST /poke, /over — send dart to file
::
++  serve-post
  |=  [eyre-id=@ta api-path=path args=(list [key=@t value=@t]) body=(unit octs) op=?(%poke %over)]
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
  =/  mark-param=(unit @t)  (get-key:kv:html-utils 'mark' args)
  =/  mime-sage=sage:tarball  [[/ %mime] !>(`mime`[/application/octet-stream u.body])]
  ;<  converted=(unit sage:tarball)  bind:m  (maybe-convert eyre-id mime-sage mark-param)
  ?~  converted  (pure:m ~)
  ~&  >>  ["%ball-api: serve-post" op road p.u.converted]
  ;<  ~  bind:m
    ?-  op
      %poke  (poke:io road u.converted)
      %over  (over:io road u.converted)
    ==
  ~&  >>  "%ball-api: serve-post done"
  (send-ok eyre-id 'OK')
::  +serve-file-cull: DELETE /file — delete file
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
::  +serve-dir-cull: DELETE /dir — delete directory
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
      (make:io dir-road &+[[~ ~] [~ ~] `[~ ~ ~] ~])
    (ensure-parents next t.segments)
  (ensure-parents next t.segments)
::  +serve-upload: POST /upload — multipart file/directory upload
::
++  serve-upload
  |=  [eyre-id=@ta tree-path=path req=inbound-request:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  parts=(unit (list [@t part:multipart]))
    (de-request:multipart header-list.request.req body.request.req)
  ?~  parts
    (send-error eyre-id 400 'Invalid multipart data')
  ::  Build mime->mark tubes for uploaded file extensions
  =/  exts=(set @ta)
    %-  ~(gas in *(set @ta))
    %+  murn  u.parts
    |=  [field-name=@t =part:multipart]
    ?.  =('file' field-name)  ~
    ?~  file.part  ~
    (parse-extension:tarball u.file.part)
  ;<  conversions=(map bars:tarball tube:clay)  bind:m
    =/  m  (fiber:fiber:nexus ,(map bars:tarball tube:clay))
    =/  ext-list=(list @ta)  ~(tap in exts)
    =|  convs=(map bars:tarball tube:clay)
    |-  ^-  form:m
    ?~  ext-list  (pure:m convs)
    =/  =bars:tarball  [[/ %mime] [/ i.ext-list]]
    ;<  tube=(unit tube:clay)  bind:m
      (get-tube:io [%& %| /code] bars)
    =?  convs  ?=(^ tube)
      (~(put by convs) bars u.tube)
    $(ext-list t.ext-list)
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
    %-  send-cards:io
    %+  give-simple-payload:app:server  eyre-id
    [[201 ~[['content-type' 'application/json']]] `bod]
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
    :_  (as-octs:mimes:html body.file-part)
    (fall type.file-part /application/octet-stream)
  =/  mime-sage=sage:tarball  [[/ %mime] !>(file-mime)]
  =/  ext=(unit @ta)  (parse-extension:tarball file-name)
  =/  final-sage=sage:tarball
    ?~  ext  mime-sage
    =/  =bars:tarball  [[/ %mime] [/ u.ext]]
    =/  tube=(unit tube:clay)  (~(get by conversions) bars)
    ?~  tube  mime-sage
    =/  result=(each vase tang)  (mule |.((u.tube q.mime-sage)))
    ?:  ?=(%| -.result)  mime-sage
    [[/ u.ext] p.result]
  ::  Ensure parent dirs exist
  ;<  ~  bind:m  (ensure-parents tree-path file-parent)
  ::  Create or overwrite file — keep full filename
  =/  =road:tarball  [%& %& full-path file-name]
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?:  exists
    ;<  ~  bind:m  (over:io road final-sage)
    $(remaining t.remaining, created [filename-raw created])
  ;<  ~  bind:m  (make:io road |+[%.n final-sage ~])
  $(remaining t.remaining, created [filename-raw created])
::  +serve-sand-peek: GET /sand — directory permissions as JSON
::
++  serve-sand-peek
  |=  [eyre-id=@ta api-path=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  dir-seen=seen:nexus  bind:m  (peek:io [%& %| api-path] ~)
  ?.  ?=([%& %ball *] dir-seen)
    (send-error eyre-id 404 'Not found')
  (send-json eyre-id (sand-to-json:nexus sand.p.dir-seen))
::  +serve-weir-peek: GET /weir — single directory weir as JSON
::
++  serve-weir-peek
  |=  [eyre-id=@ta api-path=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  dir-seen=seen:nexus  bind:m  (peek:io [%& %| api-path] ~)
  ?.  ?=([%& %ball *] dir-seen)
    (send-error eyre-id 404 'Not found')
  =/  =weir:nexus  (fall fil.sand.p.dir-seen *weir:nexus)
  (send-json eyre-id (weir-to-json:nexus weir))
::  +serve-weir-put: PUT /weir — replace weir from JSON body
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
::  +serve-weir-del: DELETE /weir — clear weir
::
++  serve-weir-del
  |=  [eyre-id=@ta api-path=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  ~  bind:m  (sand:io [%& %| api-path] ~)
  (send-ok eyre-id 'Deleted')
::  +serve-manu: GET /manu — documentation for a path
::
++  serve-manu
  |=  [eyre-id=@ta api-path=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  file-road=(unit road:tarball)
    ?~  api-path  ~
    `[%& %& (snip `path`api-path) (rear api-path)]
  ;<  is-file=?  bind:m
    ?~  file-road  (pure:(fiber:fiber:nexus ,?) %.n)
    (peek-exists:io u.file-road)
  =/  =road:tarball
    ?:  is-file  (need file-road)
    [%& %| api-path]
  ;<  text=@t  bind:m  (manu-road:io road)
  ?:  =('' text)
    (send-ok eyre-id 'No documentation')
  (send-ok eyre-id text)
::  +serve-keep: GET /keep — SSE stream of changes
::
++  serve-keep
  |=  [eyre-id=@ta api-path=path args=(list [key=@t value=@t]) req=inbound-request:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  (is-sse-request:http-utils req)
    (send-error eyre-id 400 'Requires Accept: text/event-stream')
  =/  mark-param=(unit @t)  (get-key:kv:html-utils 'mark' args)
  ::  Send SSE response header
  ;<  ~  bind:m
    (send-cards:io [(give-sse-header:http-utils eyre-id) ~])
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
  ::  Subscribe to changes — bond returns initial view
  ;<  init=view:nexus  bind:m  (keep:io /keep road ~)
  =/  prev-born=born:nexus
    ?.  ?=([%ball *] init)  *born:nexus
    born.init
  ::  Send "old" events for initial state
  ;<  ~  bind:m
    ?+  init  (pure:m ~)
    ::  Single file — send one "old" event
        [%file *]
      =/  file-name=@t
        ?~  api-path  '/'
        (rear api-path)
      =/  id=@t  (scot %ud ud.file.sack.init)
      =/  event-name=@t  (crip "old {(trip file-name)}")
      ;<  body=@t  bind:m  (sage-to-txt sage.init mark-param)
      =/  data=wain  (to-wain:format body)
      =/  =sse-event:http-utils  [`id `event-name data]
      (send-cards:io [(give-sse-event:http-utils eyre-id sse-event) ~])
    ::  Directory — send "old" for each file
        [%ball *]
      =/  root=ball:tarball  ball.init
      (send-old-dir eyre-id root born.init / mark-param)
    ==
  ::  Start keep-alive timer
  ;<  now=@da  bind:m  get-time:io
  ;<  ~  bind:m  (send-wait:io (add now ~s30))
  ::  Event loop
  |-
  ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /keep)
  ?-    -.nw
      %wake
    ;<  ~  bind:m
      (send-cards:io [(give-sse-keep-alive:http-utils eyre-id) ~])
    ;<  now=@da  bind:m  get-time:io
    ;<  ~  bind:m  (send-wait:io (add now ~s30))
    $
  ::
      %news
    ?+    view.nw  $
    ::  Single file changed
        [%file *]
      =/  =sage:tarball  sage.view.nw
      =/  id=@t  (scot %ud ud.file.sack.view.nw)
      =/  file-name=@t
        ?~  api-path  '/'
        (rear api-path)
      =/  event-name=@t  (crip "upd {(trip file-name)}")
      ;<  body=@t  bind:m  (sage-to-txt sage mark-param)
      =/  data=wain  (to-wain:format body)
      =/  =sse-event:http-utils  [`id `event-name data]
      ;<  ~  bind:m
        (send-cards:io [(give-sse-event:http-utils eyre-id sse-event) ~])
      $
    ::  Directory changed — diff born to find changed lanes
        [%ball *]
      =/  root=ball:tarball  ball.view.nw
      =/  root-born=born:nexus  born.view.nw
      =/  what=(set lane:tarball)  (diff-born-state:nexus prev-born root-born)
      =/  old-born=born:nexus  prev-born
      =.  prev-born  root-born
      =/  lanes=(list lane:tarball)  ~(tap in what)
      |-
      ?~  lanes  ^$
      ::  Skip directory lanes (TBD)
      ?:  ?=(%| -.i.lanes)
        $(lanes t.lanes)
      ::  Lanes are relative to the subscribed subtree
      =/  file-path=path  path.p.i.lanes
      =/  file-name=@ta  name.p.i.lanes
      =/  lane-path=@t  (spat (snoc file-path file-name))
      ::  Get file cass from new born for event ID
      =/  sub-born=born:nexus  (~(dip of root-born) file-path)
      =/  file-sack=(unit sack:nexus)
        ?~  fil.sub-born  ~
        (~(get by bags.u.fil.sub-born) file-name)
      =/  id=@t
        ?~  file-sack  '0'
        (scot %ud ud.file.u.file-sack)
      ::  Check if lane existed in old born
      =/  old-sub=born:nexus  (~(dip of old-born) file-path)
      =/  old-sack=(unit sack:nexus)
        ?~  fil.old-sub  ~
        (~(get by bags.u.fil.old-sub) file-name)
      ::  Get file content from the ball
      =/  sub=ball:tarball  (~(dip ba:tarball root) file-path)
      =/  ct=(unit content:tarball)
        ?~  fil.sub  ~
        (~(get by contents.u.fil.sub) file-name)
      ?~  ct
        ::  File gone — send delete event
        =/  event-name=@t  (crip "del {(trip lane-path)}")
        =/  =sse-event:http-utils  [`id `event-name ~['']]
        ;<  ~  bind:m
          (send-cards:io [(give-sse-event:http-utils eyre-id sse-event) ~])
        $(lanes t.lanes)
      ::  File exists — new or upd
      =/  action=@t  ?~(old-sack 'new' 'upd')
      =/  event-name=@t  (crip "{(trip action)} {(trip lane-path)}")
      =/  =sage:tarball  sage.u.ct
      ;<  body=@t  bind:m  (sage-to-txt sage mark-param)
      =/  data=wain  (to-wain:format body)
      =/  =sse-event:http-utils  [`id `event-name data]
      ;<  ~  bind:m
        (send-cards:io [(give-sse-event:http-utils eyre-id sse-event) ~])
      $(lanes t.lanes)
    ==
  ==
::  +send-old-dir: send "old" SSE events for all files in a ball
::
++  send-old-dir
  |=  [eyre-id=@ta b=ball:tarball =born:nexus here=path mark-param=(unit @t)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ::  Send "old" for files in this directory
  ;<  ~  bind:m
    ?~  fil.b  (pure:m ~)
    =/  files=(list [@ta content:tarball])  ~(tap by contents.u.fil.b)
    |-
    ?~  files  (pure:m ~)
    =/  [file-name=@ta =content:tarball]  i.files
    =/  lane-path=@t  (spat (snoc here file-name))
    =/  sub-born=born:nexus  (~(dip of born) here)
    =/  file-sack=(unit sack:nexus)
      ?~  fil.sub-born  ~
      (~(get by bags.u.fil.sub-born) file-name)
    =/  id=@t
      ?~  file-sack  '0'
      (scot %ud ud.file.u.file-sack)
    =/  event-name=@t  (crip "old {(trip lane-path)}")
    ;<  body=@t  bind:m  (sage-to-txt sage.content mark-param)
    =/  data=wain  (to-wain:format body)
    =/  =sse-event:http-utils  [`id `event-name data]
    ;<  ~  bind:m
      (send-cards:io [(give-sse-event:http-utils eyre-id sse-event) ~])
    $(files t.files)
  ::  Recurse into subdirectories
  =/  dirs=(list [@ta ball:tarball])  ~(tap by dir.b)
  |-
  ?~  dirs  (pure:m ~)
  =/  [dir-name=@ta sub=ball:tarball]  i.dirs
  ;<  ~  bind:m  (send-old-dir eyre-id sub born (snoc here dir-name) mark-param)
  $(dirs t.dirs)
::
::  +sage-to-txt: convert sage to text for SSE data
::
::    With mark param: sage -> target mark -> txt
::    Without: sage -> txt directly
::    Falls back to mime body extraction if no txt tube exists.
::
++  sage-to-txt
  |=  [=sage:tarball mark-param=(unit @t)]
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  ::  Step 1: optionally convert to intermediate mark
  ?~  mark-param
    (sage-to-txt-raw sage)
  =/  target-mark=@tas  u.mark-param
  ?:  =(name.p.sage target-mark)
    (sage-to-txt-raw sage)
  ;<  tube=(unit tube:clay)  bind:m  (get-tube:io [%& %| /code] [p.sage [/ target-mark]])
  ?~  tube
    (sage-to-txt-raw sage)
  =/  result=(each vase tang)  (mule |.((u.tube q.sage)))
  ?:  ?=(%| -.result)
    (sage-to-txt-raw sage)
  (sage-to-txt-raw [[/ target-mark] p.result])
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
