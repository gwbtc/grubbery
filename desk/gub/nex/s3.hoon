::  s3: the ship's door to S3-compatible buckets, in the openrouter/
::  github proxy shape. Every operation is a call grub with its caller
::  recorded; the namespace surface is /mounts, where prefixes of the
::  buckets are mirrored as directories.
::
::    config.json   -- {buckets: {name: {access-key, secret-key, region,
::                     bucket, endpoint}}}; name is the local label
::    mounts.json   -- {bucket: [path, ...]}: the mirrored paths. A path is
::                     a folder ('a/b/', '' = whole bucket) or one key
::    mounts/<b>/<path> -- the local mirror; pulls land here, pushes read
::                     from here
::    activity.json -- caller-attributed op log
::    main.sig      -- poke {id, body: {op, ...}} to create a call
::    calls/        -- per-op lifecycle grubs (consumer culls)
::    tools/        -- this nexus's MCP tools (its own bundle, its own
::                     tools-nexus instance)
::
::  ops (the body of a call), every one naming a bucket:
::    list    {bucket, prefix?}  -> {keys, count}
::    delete  {bucket, key}      -> {key, ok, code}
::    pull    {bucket, path}     -> {pulled, failed}  path inside a mount
::    push    {bucket, path}     -> {pushed, failed}  path inside a mount
::
/<  s3l      /lib/s3.hoon
/<  nw       /lib/nexus-web.hoon
/<  nex-tools  /lib/tools.hoon
/&  bundle   /lib/s3-bundle/
/&  man      ../man/s3/readme.md
/<  ui-html  s3/index.html
/<  ui-js    s3/app.js
/<  ui-css   s3/style.css
/<  ui-icon  s3/icon.svg
::  shared web components from /lib/ui: the kit (module) plus the
::  classic file-preview script the explorer's viewer uses
/&  md-js    /lib/ui/modal-dialog.js
/&  ft-js    /lib/ui/file-table.js
/&  dm-js    /lib/ui/drop-menu.js
/&  fp-js    /lib/ui/file-preview.js
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      ::  weld the component modules into one served file, each wrapped
      ::  in { } so top-level consts don't collide
      =/  wrap
        |=  =mime  ^-  @
        (rap 3 ~[123 10 q.q.mime 10 125 10])
      =/  kit-js=mime
        :-  /application/javascript
        %-  as-octs:mimes:html
        (rap 3 ~[(wrap md-js) (wrap ft-js) (wrap dm-js)])
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'S3'
            info+s+'Buckets, mirrored into the namespace'
            color+s+'#e07a2f'
            image+s+'/grubbery/tiles/icon/s3'
            href+s+'/grubbery/s3'
        ==
      =/  default-config=json
        (pairs:enjs:format ~[['buckets' [%o ~]]])
      =/  default-activity=json
        (pairs:enjs:format ~[['requests' (numb:enjs:format 0)] ['log' [%a ~]]])
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%over %& [/ %'link.json'] [[/ %json] (pairs:enjs:format ~[['name' s+'s3'] ['description' s+'Local structured proxy for S3-compatible object storage']])]]
          [%over %& [/ %'weir.json'] [[/ %json] weir-json]]
          [%over %& [/ %'tile.json'] [[/ %json] tile]]
          [%over %& [/ %'icon.svg'] [[/ %mime] ui-icon]]
          [%over %& [/ %'index.html'] [[/ %mime] ui-html]]
          [%over %& [/ %'app.js'] [[/ %mime] ui-js]]
          [%over %& [/ %'style.css'] [[/ %mime] ui-css]]
          [%over %& [/ %'components.js'] [[/ %mime] kit-js]]
          [%over %& [/ %'file-preview.js'] [[/ %mime] fp-js]]
          [%over %& [/ %'README.md'] [[/ %mime] man]]
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'web.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'config.json'] [[/ %json] default-config]]
          [%fall %& [/ %'mounts.json'] [[/ %json] [%o ~]]]
          [%fall %& [/ %'activity.json'] [[/ %json] default-activity]]
          [%fall %| /mounts empty-dir:loader]
          [%fall %| /calls empty-dir:loader]
          [%fall %| /requests empty-dir:loader]
          [%over %| /tools (seed-tools:nex-tools bundle)]
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
        ;<  ~  bind:m  (rise-wait:io prod "%s3/main: failed")
        (main-loop rail)
          [~ %'web.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%s3/web: failed")
        ;<  ~  bind:m  (bind-http-self:io [~ /grubbery/s3])
        (http-dispatch:io %s3)
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%s3/req: failed")
        (serve rail name.rail)
          [[%calls ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%s3/call: failed")
        (run-call rail)
      ==
    --
|%
::  one bucket's credentials
+$  s3-config
  $:  access-key=@t
      secret-key=@t
      region=@t
      bucket=@t
      endpoint=@t
  ==
+$  buckets  (map @t s3-config)
::  the mirrored paths of each bucket. A path is an S3 prefix ('' for the
::  whole bucket, 'a/b/' for a folder) or a key ('a/b.txt' for one file);
::  it lives locally at mounts/<bucket>/<path>.
+$  mounts   (map @t (set @t))
++  weir-json
  ^-  json
  =/  line  |=([r=@t w=@t] `json`(pairs:enjs:format ~[['road' s+r] ['why' s+w]]))
  %-  pairs:enjs:format
  :~  :-  'poke'
      :-  %a
      :~  (line '/sys/bowl.sig' 'read the current time and our ship')
          (line '/sys/eyre/' 'bind the UI route and send page responses')
          (line '/sys/iris/' 'the only nexus that talks to the buckets over HTTP')
      ==
  ==
::  +at: a road to a lane of this nexus, from any grub in it
::
++  at
  |=  [=rail:tarball =lane:tarball]
  ^-  road:tarball
  (nex-road:io rail lane)
::  +main-loop: accept {id, body} pokes and create call grubs, with
::  the poke source recorded as the caller
::
++  main-loop
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  loc=here:nexus  bind:m  get-here:io
  |-
  ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
  =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
  ?.  ?=([%o *] jon)  $
  =/  id=@t  (jget jon 'id')
  =/  body=(unit json)  (~(get by p.jon) 'body')
  ?:  |(=('' id) ?=(~ body))
    ~&  >>>  "%s3: poke missing id or body"
    $
  =/  caller=@t  (caller-path loc from)
  =/  call-road=road:tarball  (at rail [%& /calls (crip "{(trip id)}.json")])
  =/  content=json
    %-  pairs:enjs:format
    :~  ['status' s+'pending']
        ['request' u.body]
        ['from' s+caller]
    ==
  ;<  ~  bind:m  (make:io call-road |+[[[/ %json] content] ~])
  ;<  ~  bind:m  (gain:io call-road %.y)
  $
::  +run-call: execute one op. The response always lands as
::  {status: done, response}; a failure is response.error.
::
++  run-call
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  own=json  bind:m  (get-state-as:io ,json)
  ?.  ?=([%o *] own)  stay:m
  ?.  =('pending' (jget own 'status'))  stay:m
  =/  request=(unit json)  (~(get by p.own) 'request')
  =/  caller=@t  (jget own 'from')
  ?~  request  stay:m
  ;<  resp=json  bind:m  (run-op rail u.request)
  ;<  ~  bind:m  (log-activity rail u.request resp caller)
  ;<  ~  bind:m
    (replace:io (pairs:enjs:format ~[['status' s+'done'] ['response' resp]]))
  stay:m
::
++  err
  |=  t=@t
  ^-  json
  (pairs:enjs:format ~[['error' s+t]])
::  +is-dir: a path names a folder (or the whole bucket)
::
++  is-dir
  |=  p=@t
  ^-  ?
  ?:  =('' p)  %.y
  =('/' (rear (trip p)))
::  +covered: some mounted path of the bucket contains this path
::
++  covered
  |=  [mts=mounts bucket=@t path=@t]
  ^-  ?
  =/  paths=(set @t)  (fall (~(get by mts) bucket) ~)
  %+  lien  ~(tap in paths)
  |=  m=@t
  ?:  (is-dir m)  =(m (end [3 (met 3 m)] path))
  =(m path)
::  +run-op: dispatch on body.op. Every op names a bucket; pull and push
::  name a path inside one of its mounts.
::
++  run-op
  |=  [=rail:tarball req=json]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  =/  op=@t  (jget req 'op')
  ;<  bks=buckets  bind:m  (read-buckets rail)
  =/  bucket-name=@t  (jget req 'bucket')
  =/  cfg=(unit s3-config)  (~(get by bks) bucket-name)
  ?~  cfg
    %-  pure:m
    %-  err
    ?:  =('' bucket-name)  'bucket required'
    (crip "unknown bucket: {(trip bucket-name)}")
  ?:  |(=('' access-key.u.cfg) =('' secret-key.u.cfg) =('' bucket.u.cfg) =('' endpoint.u.cfg))
    (pure:m (err (crip "bucket {(trip bucket-name)} is missing credentials")))
  ;<  mts=mounts  bind:m  (read-mounts rail)
  =/  path=@t  (jget req 'path')
  =/  base=^path  /mounts/[bucket-name]
  ?+    op  (pure:m (err (crip "unknown op: {(trip op)}")))
      %list
    ;<  keys=(each (list @t) @t)  bind:m  (list-keys u.cfg (jget req 'prefix'))
    ?:  ?=(%| -.keys)  (pure:m (err p.keys))
    %-  pure:m
    %-  pairs:enjs:format
    :~  ['keys' [%a (turn p.keys |=(k=@t s+k))]]
        ['count' (numb:enjs:format (lent p.keys))]
    ==
  ::
      %delete
    =/  key=@t  (jget req 'key')
    ?:  =('' key)  (pure:m (err 'key required'))
    ;<  resp=client-response:iris  bind:m  (s3-request u.cfg 'DELETE' key '' ~)
    ?.  ?=(%finished -.resp)  (pure:m (err 'delete failed'))
    =/  code=@ud  status-code.response-header.resp
    %-  pure:m
    %-  pairs:enjs:format
    :~  ['key' s+key]
        ['ok' b+(lth code 300)]
        ['code' (numb:enjs:format code)]
    ==
  ::  pull: the bucket's path into mounts/<bucket>/<path>. A file path
  ::  pulls one object; a folder path pulls everything under it.
      %pull
    ?.  (covered mts bucket-name path)
      (pure:m (err (crip "{(trip path)} is not inside a mount of {(trip bucket-name)}")))
    ?.  (is-dir path)
      ;<  got=(unit @t)  bind:m  (pull-one rail u.cfg base path path)
      ?~  got  (pure:m (err (crip "download failed: {(trip path)}")))
      (pure:m (pairs:enjs:format ~[['pulled' (numb:enjs:format 1)] ['failed' [%a ~]] ['file' s+u.got]]))
    ;<  keys=(each (list @t) @t)  bind:m  (list-keys u.cfg path)
    ?:  ?=(%| -.keys)  (pure:m (err p.keys))
    =/  todo=(list @t)  p.keys
    =|  pulled=@ud
    =|  failed=(list @t)
    |-
    ?~  todo
      %-  pure:m
      %-  pairs:enjs:format
      :~  ['pulled' (numb:enjs:format pulled)]
          ['failed' [%a (turn (flop failed) |=(k=@t s+k))]]
      ==
    ?:  (is-dir i.todo)  $(todo t.todo)
    ;<  got=(unit @t)  bind:m  (pull-one rail u.cfg base i.todo i.todo)
    ?~  got  $(todo t.todo, failed [i.todo failed])
    $(todo t.todo, pulled +(pulled))
  ::  push: mounts/<bucket>/<path> up to the bucket. A file path pushes
  ::  one file; a folder path pushes everything under it.
      %push
    ?.  (covered mts bucket-name path)
      (pure:m (err (crip "{(trip path)} is not inside a mount of {(trip bucket-name)}")))
    ?.  (is-dir path)
      =/  dirs=^path  (key-to-dirs path)
      =/  name=@ta  (extract-filename:s3l path)
      ;<  bad=(unit @t)  bind:m  (push-one rail u.cfg base dirs name path)
      ?^  bad  (pure:m (err u.bad))
      (pure:m (pairs:enjs:format ~[['pushed' (numb:enjs:format 1)] ['failed' [%a ~]] ['key' s+path]]))
    =/  sub=^path  (key-to-dirs (cat 3 path 'x'))
    ;<  dir=view:nexus  bind:m  (peek:io (at rail [%| (weld base sub)]) ~)
    ?.  ?=([%ball *] dir)  (pure:m (err 'nothing pulled there yet'))
    =/  todo=(list [^path @ta])
      %+  turn  (collect-files-recursive:s3l ball.dir ~)
      |=([p=^path n=@ta] [(weld sub p) n])
    =|  pushed=@ud
    =|  failed=(list @t)
    |-
    ?~  todo
      %-  pure:m
      %-  pairs:enjs:format
      :~  ['pushed' (numb:enjs:format pushed)]
          ['failed' [%a (turn (flop failed) |=(k=@t s+k))]]
      ==
    =/  [dirs=^path name=@ta]  i.todo
    =/  key=@t  (path-to-s3-key:s3l (snoc dirs name))
    ;<  bad=(unit @t)  bind:m  (push-one rail u.cfg base dirs name key)
    ?^  bad  $(todo t.todo, failed [key failed])
    $(todo t.todo, pushed +(pushed))
  ==
::  +list-keys: every object key under a prefix, or an error
::
++  list-keys
  |=  [cfg=s3-config prefix=@t]
  =/  m  (fiber:fiber:nexus ,(each (list @t) @t))
  ^-  form:m
  =/  qs=@t  (build-list-query:s3l prefix)
  ;<  resp=client-response:iris  bind:m  (s3-request cfg 'GET' '' qs ~)
  ?.  ?=(%finished -.resp)  (pure:m [%| 'list failed'])
  =/  code=@ud  status-code.response-header.resp
  ?.  (lth code 300)  (pure:m [%| (crip "list error: HTTP {<code>}")])
  ?~  full-file.resp  (pure:m [%& ~])
  (pure:m [%& (parse-list-response:s3l q.data.u.full-file.resp)])
::  +pull-one: GET a key into mounts/<mount>/<rel>. Returns the file's
::  nexus-relative path on success.
::
++  pull-one
  |=  [=rail:tarball cfg=s3-config base=path key=@t rel=@t]
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  ;<  resp=client-response:iris  bind:m  (s3-request cfg 'GET' key '' ~)
  ?.  ?=(%finished -.resp)  (pure:m ~)
  ?.  (lth status-code.response-header.resp 300)  (pure:m ~)
  ?~  full-file.resp  (pure:m ~)
  =/  ct=(unit @t)  (extract-content-type:s3l headers.response-header.resp)
  =/  filename=@ta  (extract-filename:s3l rel)
  =/  dirs=path  (weld base (key-to-dirs rel))
  =/  mtype=path  (determine-mime-type:tarball ct filename)
  =/  file-mime=mime  [mtype (as-octs:mimes:html q.data.u.full-file.resp)]
  =/  file-road=road:tarball  (at rail [%& dirs filename])
  ;<  ~  bind:m  (land-file file-road file-mime filename)
  (pure:m `(crip (spud (snoc dirs filename))))
::  +land-file: write a pulled object; over if present, else make with
::  the extension's mark, falling back to plain mime
::
++  land-file
  |=  [file-road=road:tarball file-mime=mime filename=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  exists=?  bind:m  (peek-exists:io file-road)
  ?:  exists
    (over:io file-road [[/ %mime] file-mime])
  =/  ext=(unit blot:tarball)  (bind (parse-extension:tarball filename) |=(e=@ta [/ e]))
  ;<  bad=(unit tang)  bind:m  (make-soft:io file-road |+[[[/ %mime] file-mime] ext])
  ?~  bad  (pure:m ~)
  (make:io file-road |+[[[/ %mime] file-mime] ~])
::  +push-one: PUT one mount file to a key. Returns an error text, or ~.
::
++  push-one
  |=  [=rail:tarball cfg=s3-config base=path dirs=path name=@ta key=@t]
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  =/  file-road=road:tarball  (at rail [%& (weld base dirs) name])
  ;<  v=view:nexus  bind:m  (peek:io file-road ~)
  ?.  ?=([%file *] v)
    (pure:m `(crip "not found in mount: {(spud (snoc dirs name))}"))
  ;<  =mime  bind:m  (sage-to-mime:io (need-sage:tarball sang.v))
  ;<  resp=client-response:iris  bind:m
    (s3-request cfg 'PUT' key '' `q.q.mime)
  ?.  ?=(%finished -.resp)  (pure:m `'upload failed')
  =/  code=@ud  status-code.response-header.resp
  ?.  (lth code 300)  (pure:m `(crip "upload error: HTTP {<code>}"))
  (pure:m ~)
::  +s3-request: one signed request to a bucket
::
++  s3-request
  |=  [cfg=s3-config method=@t key=@t qs=@t content=(unit @t)]
  =/  m  (fiber:fiber:nexus ,client-response:iris)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  [amz-date=@t payload-hash=@t authorization=@t]
    %:  build-signature:s3l
      method=method
      access-key=access-key.cfg
      secret-key=secret-key.cfg
      region=region.cfg
      endpoint=endpoint.cfg
      bucket=bucket.cfg
      object-key=key
      query-string=qs
      content=content
      now=now
    ==
  =/  url=@t  (build-url:s3l endpoint.cfg bucket.cfg key ?:(=('' qs) ~ `qs))
  =/  hed=(list [@t @t])  (build-headers:s3l method payload-hash amz-date authorization)
  =/  bod=(unit octs)  (bind content |=(c=@t (as-octs:mimes:html c)))
  =/  meth=method:http  ;;(method:http method)
  ;<  ~  bind:m  (send-request:io [meth url hed bod])
  take-client-response:io
::  +log-activity: one line per call into activity.json, capped at 500
::
++  log-activity
  |=  [=rail:tarball req=json resp=json caller=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  road=road:tarball  (at rail [%& / %'activity.json'])
  ;<  ucur=(unit json)  bind:m  (peek-as:io road ,json)
  =/  cur=json  (fall ucur [%o ~])
  ?.  ?=([%o *] cur)  (pure:m ~)
  =/  old=(list json)
    =/  l  (~(get by p.cur) 'log')
    ?.(?=([~ %a *] l) ~ p.u.l)
  ;<  now=@da  bind:m  get-time:io
  =/  target=@t
    =/  what=@t
      =/  key=@t  (jget req 'key')
      ?.  =('' key)  key
      =/  path=@t  (jget req 'path')
      ?.  =('' path)  path
      (jget req 'prefix')
    ?:  =('' what)  (jget req 'bucket')
    (rap 3 ~[(jget req 'bucket') ' ' what])
  =/  error=@t  (jget resp 'error')
  =/  entry=json
    %-  pairs:enjs:format
    :~  ['op' s+(jget req 'op')]
        ['target' s+target]
        ['ok' b+=('' error)]
        ['error' s+error]
        ['from' s+caller]
        ['time' (sect:enjs:format now)]
    ==
  =/  new=json
    %-  pairs:enjs:format
    :~  ['requests' (numb:enjs:format (add 1 (jnum cur 'requests' 0)))]
        ['log' [%a (scag 500 `(list json)`[entry old])]]
    ==
  (over:io road [[/ %json] new])
::  +read-buckets: config.json's buckets map
::
++  read-buckets
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,buckets)
  ^-  form:m
  ;<  ucfg=(unit json)  bind:m  (peek-as:io (at rail [%& / %'config.json']) ,json)
  (pure:m (buckets-of (fall ucfg [%o ~])))
::
++  buckets-of
  |=  jon=json
  ^-  buckets
  ?.  ?=([%o *] jon)  ~
  =/  b  (~(get by p.jon) 'buckets')
  ?.  ?=([~ %o *] b)  ~
  %-  ~(gas by *buckets)
  %+  murn  ~(tap by p.u.b)
  |=  [k=@t v=json]
  ^-  (unit [@t s3-config])
  ?.  ?=([%o *] v)  ~
  :-  ~
  :-  k
  :*  (jget v 'access-key')
      (jget v 'secret-key')
      (jget v 'region')
      (jget v 'bucket')
      (jget v 'endpoint')
  ==
::
++  bucket-json
  |=  cfg=s3-config
  ^-  json
  %-  pairs:enjs:format
  :~  ['access-key' s+access-key.cfg]
      ['secret-key' s+secret-key.cfg]
      ['region' s+region.cfg]
      ['bucket' s+bucket.cfg]
      ['endpoint' s+endpoint.cfg]
  ==
::
++  write-buckets
  |=  [=rail:tarball bks=buckets]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  entries=(list [@t json])
    (turn ~(tap by bks) |=([n=@t c=s3-config] [n (bucket-json c)]))
  %+  over:io  (at rail [%& / %'config.json'])
  [[/ %json] (pairs:enjs:format ~[['buckets' [%o (malt entries)]]])]
::
++  read-mounts
  |=  =rail:tarball
  =/  m  (fiber:fiber:nexus ,mounts)
  ^-  form:m
  ;<  ujon=(unit json)  bind:m  (peek-as:io (at rail [%& / %'mounts.json']) ,json)
  =/  jon=json  (fall ujon [%o ~])
  ?.  ?=([%o *] jon)  (pure:m *mounts)
  %-  pure:m
  %-  ~(gas by *mounts)
  %+  murn  ~(tap by p.jon)
  |=  [k=@t v=json]
  ^-  (unit [@t (set @t)])
  ?.  ?=([%a *] v)  ~
  `[k (sy (murn p.v |=(x=json ?:(?=([%s *] x) `p.x ~))))]
::
++  write-mounts
  |=  [=rail:tarball mts=mounts]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  entries=(list [@t json])
    %+  turn  ~(tap by mts)
    |=  [b=@t ps=(set @t)]
    [b [%a (turn (sort ~(tap in ps) aor) |=(p=@t s+p))]]
  (over:io (at rail [%& / %'mounts.json']) [[/ %json] [%o (malt entries)]])
::  +local-files: how many files a mounted path holds locally
::
++  local-files
  |=  [=rail:tarball bucket=@t path=@t]
  =/  m  (fiber:fiber:nexus ,@ud)
  ^-  form:m
  =/  base=^path  /mounts/[bucket]
  ?.  (is-dir path)
    ;<  there=?  bind:m
      (peek-exists:io (at rail [%& (weld base (key-to-dirs path)) (extract-filename:s3l path)]))
    (pure:m ?:(there 1 0))
  =/  sub=^path  (key-to-dirs (cat 3 path 'x'))
  ;<  dir=view:nexus  bind:m  (peek:io (at rail [%| (weld base sub)]) ~)
  %-  pure:m
  ?.  ?=([%ball *] dir)  0
  (lent (collect-files-recursive:s3l ball.dir ~))
::  key helpers. A prefix is stored as given; joining normalises the
::  single slash between prefix and the rest.
::
++  join-key
  |=  [prefix=@t rest=@t]
  ^-  @t
  ?:  =('' prefix)  rest
  ?:  =('/' (rear (trip prefix)))  (cat 3 prefix rest)
  (rap 3 ~[prefix '/' rest])
::  +strip-prefix: the part of key after prefix (and its slash); the
::  whole key if it does not start with prefix
::
++  strip-prefix
  |=  [prefix=@t key=@t]
  ^-  @t
  =/  pre=tape  (trip prefix)
  =/  k=tape  (trip key)
  ?:  =('' prefix)  key
  ?.  =(pre (scag (lent pre) k))  key
  =/  rest=tape  (slag (lent pre) k)
  ?:  ?=([%'/' *] rest)  (crip t.rest)
  (crip rest)
::  +key-to-dirs: the directory segments of a slash path, sans file
::
++  key-to-dirs
  |=  key=@t
  ^-  path
  =/  parts=(list @t)  (split-on (trip key) '/')
  =/  segs=(list @t)  (skip parts |=(s=@t =('' s)))
  ?:  (lte (lent segs) 1)  /
  (turn (snip `(list @t)`segs) |=(s=@t `@ta`s))
::
++  split-on
  |=  [t=tape del=@t]
  ^-  (list @t)
  =|  acc=(list @t)
  =|  cur=tape
  |-
  ?~  t  (flop [(crip (flop cur)) acc])
  ?:  =(i.t del)
    $(t t.t, acc [(crip (flop cur)) acc], cur ~)
  $(t t.t, cur [i.t cur])
::
++  jget          jget:nw
++  jnum          jnum:nw
++  post-json     post-json:nw
++  count-files   count-files:nw
++  file-entries  file-entries:nw
++  call-status   call-status:nw
++  caller-path   caller-path:nw
::  +serve: static shell + api:
::    GET  /api/status         {buckets, mounts, pending, requests}
::    GET  /api/buckets        {name: {access-key, secret-key, region, bucket, endpoint}}
::    POST /api/bucket-set     {name, ...fields} merge (secret only if non-empty)
::    POST /api/bucket-remove  {name}
::    GET  /api/mounts         [{bucket, path, files}]
::    POST /api/mount-add      {bucket, path}
::    POST /api/mount-remove   {bucket, path}   (the mapping; the files stay)
::    GET  /api/activity       activity.json verbatim
::    POST /api/call-new       {op, ...} -> {id} (caller = request grub)
::    GET  /api/call?id=
::    POST /api/call-cull      {id}
::    POST /api/sweep          cull finished call grubs
::
++  serve
  |=  [=rail:tarball eyre-id=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  web  ~(. web:nw (at rail [%& ~ %'web.sig']))
  =/  reply  reply:web
  =/  send-json  send-json:web
  ;<  [src=@p req=inbound-request:eyre]  bind:m
    (get-state-as:io ,[src=@p inbound-request:eyre])
  ;<  our=@p  bind:m  get-our:io
  ?.  =(src our)
    (reply eyre-id 403 'Forbidden')
  =/  prefix=path  /grubbery/s3
  =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
  =/  suffix=path  (slag (lent prefix) site)
  ?+    suffix  (serve-static:web eyre-id suffix)
      [%api %status ~]
    ;<  bks=buckets  bind:m  (read-buckets rail)
    ;<  mts=mounts  bind:m  (read-mounts rail)
    ;<  calls=view:nexus  bind:m  (peek:io (at rail [%| /calls]) ~)
    =/  pending=@ud
      %-  lent
      %+  skim  (file-entries calls)
      |=([nam=@ta =sang:tarball] =('pending' (call-status sang)))
    ;<  uact=(unit json)  bind:m  (peek-as:io (at rail [%& / %'activity.json']) ,json)
    =/  act=json  (fall uact [%o ~])
    %+  send-json  eyre-id
    %-  pairs:enjs:format
    :~  ['buckets' (numb:enjs:format ~(wyt by bks))]
        ['mounts' (numb:enjs:format (roll (turn ~(tap by mts) |=([* ps=(set @t)] ~(wyt in ps))) add))]
        ['pending' (numb:enjs:format pending)]
        ['requests' (numb:enjs:format (jnum act 'requests' 0))]
    ==
  ::
      [%api %buckets ~]
    ;<  bks=buckets  bind:m  (read-buckets rail)
    %+  send-json  eyre-id
    [%o (malt (turn ~(tap by bks) |=([n=@t c=s3-config] [n (bucket-json c)])))]
  ::
      [%api %bucket-set ~]
    =/  jon=(unit json)  (post-json req)
    ?~  jon  (reply eyre-id 400 'json body required')
    ?.  ?=([%o *] u.jon)  (reply eyre-id 400 'object required')
    =/  name=@t  (jget u.jon 'name')
    ?:  =('' name)  (reply eyre-id 400 'name required')
    ?~  (rush name sym)  (reply eyre-id 400 'name must be a lowercase term')
    ;<  bks=buckets  bind:m  (read-buckets rail)
    =/  cur=s3-config  (fall (~(get by bks) name) *s3-config)
    =/  pick  |=([k=@t old=@t] =/(v (jget u.jon k) ?:(=('' v) old v)))
    =/  new=s3-config
      :*  (pick 'access-key' access-key.cur)
          (pick 'secret-key' secret-key.cur)
          (pick 'region' region.cur)
          (pick 'bucket' bucket.cur)
          (pick 'endpoint' endpoint.cur)
      ==
    ;<  ~  bind:m  (write-buckets rail (~(put by bks) name new))
    (reply eyre-id 200 'ok')
  ::
      [%api %bucket-remove ~]
    =/  jon=(unit json)  (post-json req)
    ?~  jon  (reply eyre-id 400 'json body required')
    =/  name=@t  (jget u.jon 'name')
    ?:  =('' name)  (reply eyre-id 400 'name required')
    ;<  bks=buckets  bind:m  (read-buckets rail)
    ;<  ~  bind:m  (write-buckets rail (~(del by bks) name))
    (reply eyre-id 200 'ok')
  ::
      [%api %mounts ~]
    ;<  mts=mounts  bind:m  (read-mounts rail)
    =/  all=(list [b=@t p=@t])
      %-  zing
      %+  turn  ~(tap by mts)
      |=([b=@t ps=(set @t)] (turn (sort ~(tap in ps) aor) |=(p=@t [b p])))
    =|  out=(list json)
    |-
    ?~  all
      (send-json eyre-id [%a (flop out)])
    ;<  files=@ud  bind:m  (local-files rail b.i.all p.i.all)
    =/  entry=json
      %-  pairs:enjs:format
      :~  ['bucket' s+b.i.all]
          ['path' s+p.i.all]
          ['files' (numb:enjs:format files)]
      ==
    $(all t.all, out [entry out])
  ::
      [%api %mount-add ~]
    =/  jon=(unit json)  (post-json req)
    ?~  jon  (reply eyre-id 400 'json body required')
    ?.  ?=([%o *] u.jon)  (reply eyre-id 400 'object required')
    =/  bucket-name=@t  (jget u.jon 'bucket')
    =/  path=@t  (jget u.jon 'path')
    ;<  bks=buckets  bind:m  (read-buckets rail)
    ?.  (~(has by bks) bucket-name)  (reply eyre-id 400 'unknown bucket')
    ;<  mts=mounts  bind:m  (read-mounts rail)
    =/  cur=(set @t)  (fall (~(get by mts) bucket-name) ~)
    ;<  ~  bind:m  (write-mounts rail (~(put by mts) bucket-name (~(put in cur) path)))
    (reply eyre-id 200 'ok')
  ::
      [%api %mount-remove ~]
    =/  jon=(unit json)  (post-json req)
    ?~  jon  (reply eyre-id 400 'json body required')
    ?.  ?=([%o *] u.jon)  (reply eyre-id 400 'object required')
    =/  bucket-name=@t  (jget u.jon 'bucket')
    =/  path=@t  (jget u.jon 'path')
    ;<  mts=mounts  bind:m  (read-mounts rail)
    =/  cur=(set @t)  (fall (~(get by mts) bucket-name) ~)
    ;<  ~  bind:m  (write-mounts rail (~(put by mts) bucket-name (~(del in cur) path)))
    (reply eyre-id 200 'ok')
  ::
      [%api %activity ~]
    ;<  uact=(unit json)  bind:m  (peek-as:io (at rail [%& / %'activity.json']) ,json)
    (send-json eyre-id (fall uact *json))
  ::  one object's bytes, streamed through to the page for viewing.
  ::  Nothing lands in the namespace: this request grub is the only
  ::  place the bytes exist, and it is culled once the reply goes out.
      [%api %object ~]
    =/  qm=(map @t @t)  (malt args)
    =/  bucket-name=@t  (fall (~(get by qm) 'bucket') '')
    =/  key=@t  (fall (~(get by qm) 'key') '')
    ?:  |(=('' bucket-name) =('' key))  (reply eyre-id 400 'bucket and key required')
    ;<  bks=buckets  bind:m  (read-buckets rail)
    =/  cfg=(unit s3-config)  (~(get by bks) bucket-name)
    ?~  cfg  (reply eyre-id 404 'unknown bucket')
    ;<  resp=client-response:iris  bind:m  (s3-request u.cfg 'GET' key '' ~)
    ?.  ?=(%finished -.resp)  (reply eyre-id 502 'fetch failed')
    =/  code=@ud  status-code.response-header.resp
    ?.  (lth code 300)  (reply eyre-id code 'the bucket refused')
    ?~  full-file.resp  (reply eyre-id 502 'empty response')
    =/  ct=(unit @t)  (extract-content-type:s3l headers.response-header.resp)
    =/  mite=path
      ?~  ct  /application/octet-stream
      =/  parts=(list @t)  (split-on (trip u.ct) '/')
      ?.  ?=([@ @ ~] parts)  /application/octet-stream
      ~[`@ta`i.parts `@ta`i.t.parts]
    %-  send-simple:srv:web  :-  eyre-id
    (mime-response:http-utils [mite data.u.full-file.resp])
  ::
      [%api %call-new ~]
    =/  jon=(unit json)  (post-json req)
    ?~  jon  (reply eyre-id 400 'json body required')
    ?.  ?=([%o *] u.jon)  (reply eyre-id 400 'object required')
    ;<  eny=@uvJ  bind:m  get-entropy:io
    =/  id=@t  (crip ((x-co:co 16) (end 6 eny)))
    ::  through the front door: poke our own main.sig like any other
    ::  caller, so the kernel records this request grub as the caller
    ;<  bad=(unit tang)  bind:m
      %+  poke-soft:io  (at rail [%& / %'main.sig'])
      [[/ %json] (pairs:enjs:format ~[['id' s+id] ['body' u.jon]])]
    ?^  bad  (reply eyre-id 500 'could not create call')
    (send-json eyre-id (pairs:enjs:format ~[['id' s+id]]))
  ::
      [%api %call ~]
    =/  id=(unit @t)  (~(get by (malt args)) 'id')
    ?~  id  (reply eyre-id 400 'id required')
    ;<  res=(unit json)  bind:m
      (peek-as:io (at rail [%& /calls (crip "{(trip u.id)}.json")]) ,json)
    ?~  res  (reply eyre-id 404 'no such call')
    (send-json eyre-id u.res)
  ::
      [%api %call-cull ~]
    =/  jon=(unit json)  (post-json req)
    ?~  jon  (reply eyre-id 400 'json body required')
    =/  id=@t  (jget u.jon 'id')
    ?:  =('' id)  (reply eyre-id 400 'id required')
    ;<  *  bind:m  (cull-soft:io (at rail [%& /calls (crip "{(trip id)}.json")]))
    (reply eyre-id 200 'ok')
  ::
      [%api %sweep ~]
    ;<  calls=view:nexus  bind:m  (peek:io (at rail [%| /calls]) ~)
    =/  done=(list @ta)
      %+  murn  (file-entries calls)
      |=  [nam=@ta =sang:tarball]
      ?:(=('pending' (call-status sang)) ~ `nam)
    =/  n=@ud  (lent done)
    |-
    ?~  done
      (send-json eyre-id (pairs:enjs:format ~[['swept' (numb:enjs:format n)]]))
    ;<  *  bind:m  (cull-soft:io (at rail [%& /calls i.done]))
    $(done t.done)
  ==
--
