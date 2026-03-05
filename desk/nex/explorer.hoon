::  explorer nexus: tarball tree browser
::
/+  nexus, tarball, io=fiberio, server, http-utils, feather, nex-server, iso-8601, html-utils, multipart
!: :: turn on stack trace
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  [=sand:nexus =ball:tarball]
      ^-  [sand:nexus ball:tarball]
      =?  ball  =(~ (~(get ba:tarball ball) [/ %main]))
        (~(put ba:tarball ball) [/ %main] [~ %sig !>(~)])
      =?  ball  =(~ (~(get of ball) /requests))
        (~(put of ball) /requests [~ ~ ~])
      [sand ball]
    ::
    ++  on-file
      |=  [=rail:tarball =mark]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          [~ %main]
        ;<  ~  bind:m  (rise-wait:io prod "%explorer /main: failed, poke to restart")
        ~&  >  "%explorer /main: binding /grubbery/ball"
        ;<  ~  bind:m  (bind-http:nex-server [~ /grubbery/ball])
        ;<  ~  bind:m  (bind-http:nex-server [~ /grubbery/ball/stream])
        ~&  >  "%explorer /main: ready"
        (http-dispatch:nex-server %explorer)
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%explorer /requests: failed, poke to restart")
        =/  eyre-id=@ta  name.rail
        ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
        ;<  our=@p  bind:m  get-our:io
        ?.  =(src our)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
          (pure:m ~)
        ~&  >  [%explorer-request eyre-id url.request.req]
        =/  =request-line:server  (parse-request-line:server url.request.req)
        ::  Extract raw path, resolve through ball tree.
        ::  Re-append URL extension to last segment — apat strips
        ::  ".pdf" etc into ext, but grub names include it.
        =/  raw-path=path
          =/  segs=path
            ?.  ?=([%grubbery %ball *] site.request-line)  ~
            t.t.site.request-line
          ?.  &(?=(^ ext.request-line) ?=(^ segs))  segs
          (snoc (snip `path`segs) (crip "{(trip (rear segs))}.{(trip u.ext.request-line)}"))

        ?:  ?=([%stream ~] raw-path)
          =/  watch-path=path
            =/  p=(unit @t)  (get-key:kv:html-utils 'path' args.request-line)
            ?~  p  ~
            (stab u.p)
          (handle-stream eyre-id req watch-path)
        ;<  root-seen=seen:nexus  bind:m  (peek:io /peek [%& %| ~] ~)
        ?.  ?=([%& %ball *] root-seen)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[500 ~] `(as-octs:mimes:html 'Peek failed')])
          (pure:m ~)
        =/  root=ball:tarball  ball.p.root-seen
        =/  root-born=born:nexus  born.p.root-seen
        =/  root-sand=sand:nexus  sand.p.root-seen
        =/  tree-path=path  (resolve-url-path raw-path root)
        ?:  =('POST' method.request.req)
          (handle-post eyre-id tree-path root-sand req)
        (handle-get eyre-id tree-path root root-born root-sand args.request-line)
      ==
    --
::
|%
::  HTTP response door (road from /explorer/requests/* to /explorer/main)
::
++  srv  ~(. res:nex-server [%| 1 %& ~ %main])
::  Handle GET requests
::
++  handle-get
  |=  [eyre-id=@ta tree-path=path root=ball:tarball root-born=born:nexus root-sand=sand:nexus args=(list [key=@t value=@t])]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ~&  >  [%explorer-peek tree-path]
  =/  download-param=(unit @t)  (get-key:kv:html-utils 'download' args)
  =/  sub=(unit ball:tarball)  (~(dap ba:tarball root) tree-path)
  ?:  ?=(^ sub)
    ?:  ?&(?=(^ download-param) =(u.download-param 'tar'))
      (serve-tarball eyre-id tree-path u.sub (~(dip of root-born) tree-path))
    ;<  now=@da  bind:m  get-time:io
    ;<  conversions=(map mars:clay tube:clay)  bind:m
      (get-mark-conversions-shallow:io u.sub)
    =/  bod=octs  (manx-to-octs:server (render-dir tree-path root root-born root-sand now conversions))
    ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils [/text/html bod]))
    (pure:m ~)
  ::  Not a directory — try as grub
  ?~  tree-path
    ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
    (pure:m ~)
  =/  parent=path  (snip `path`tree-path)
  =/  name=@ta  (rear tree-path)
  =/  parent-ball=ball:tarball  (~(dip ba:tarball root) parent)
  =/  content-data=(unit content:tarball)
    ?~  fil.parent-ball  ~
    (find-grub name u.fil.parent-ball)
  ?~  content-data
    ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
    (pure:m ~)
  =/  =cage  cage.u.content-data
  ;<  =mime  bind:m  (cage-to-mime:io cage)
  ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils [p.mime q.mime]))
  (pure:m ~)
::  Handle POST requests (delete actions)
::
++  handle-post
  |=  [eyre-id=@ta tree-path=path root-sand=sand:nexus req=inbound-request:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ::  Check for multipart upload
  =/  content-type=(unit @t)
    (get-header:http 'content-type' header-list.request.req)
  ?:  ?&  ?=(^ content-type)
          =('multipart/form-data; boundary=' (end 3^30 u.content-type))
      ==
    (handle-upload eyre-id tree-path req)
  ::  Form-encoded POST
  =/  args=key-value-list:kv:html-utils  (parse-body:kv:html-utils body.request.req)
  =/  action=(unit @t)  (get-key:kv:html-utils 'action' args)
  =/  redirect-url=tape
    ?~(tree-path "/grubbery/ball" "/grubbery/ball{(trip (spat tree-path))}")
  ?~  action
    ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing action')])
    (pure:m ~)
  ?+    u.action
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Unknown action')])
      (pure:m ~)
  ::
      %'delete-grub'
    =/  filename=@t  (fall (get-key:kv:html-utils 'filename' args) '')
    ?:  =('' filename)
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing filename')])
      (pure:m ~)
    ::  cull road: up 3 from /explorer/requests/[id] to root, then file
    ;<  ~  bind:m  (cull:io /delete [%& %& tree-path filename])
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ::
      %'delete-folder'
    =/  foldername=@t  (fall (get-key:kv:html-utils 'foldername' args) '')
    ?:  =('' foldername)
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing foldername')])
      (pure:m ~)
    =/  folder-path=path  (snoc tree-path foldername)
    ;<  ~  bind:m  (cull:io /delete [%& %| folder-path])
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ::
      %'create-folder'
    =/  foldername=@t  (fall (get-key:kv:html-utils 'foldername' args) '')
    ?:  =('' foldername)
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing foldername')])
      (pure:m ~)
    =/  dir-ext=(unit @ta)  (parse-extension:tarball foldername)
    =/  [dir-name=@ta dir-neck=(unit neck:tarball)]
      ?~  dir-ext  [foldername ~]
      =/  ext-text=tape  (trip u.dir-ext)
      =/  full-text=tape  (trip foldername)
      =/  name-len=@ud  (sub (lent full-text) (add 1 (lent ext-text)))
      [(crip (scag name-len full-text)) `u.dir-ext]
    =/  folder-path=path  (snoc tree-path dir-name)
    =/  new-ball=ball:tarball  [`[~ dir-neck ~] ~]
    ;<  ~  bind:m  (make:io /mkd [%& %| folder-path] &+[*sand:nexus new-ball] ~)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ::
      %'create-symlink'
    =/  linkname=@t  (fall (get-key:kv:html-utils 'linkname' args) '')
    ?:  =('' linkname)
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing linkname')])
      (pure:m ~)
    =/  target=@t  (fall (get-key:kv:html-utils 'target' args) '')
    ?:  =('' target)
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing target')])
      (pure:m ~)
    =/  sym=(unit symlink:tarball)  (parse-symlink:tarball target)
    ?~  sym
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Invalid symlink target')])
      (pure:m ~)
    ;<  ~  bind:m  (make:io /make [%& %& tree-path linkname] |+[%symlink !>(u.sym)] ~)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ::
      %'add-weir-road'
    =/  category=@t  (fall (get-key:kv:html-utils 'category' args) '')
    =/  road-path=@t  (fall (get-key:kv:html-utils 'road-path' args) '')
    =/  road-type=@t  (fall (get-key:kv:html-utils 'road-type' args) '')
    ?:  |(=('' category) =('' road-path))
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing fields')])
      (pure:m ~)
    =/  pax=path  (stab road-path)
    =/  new-road=road:tarball
      ?:  =('file' road-type)
        ?~  pax
          [%& %| /]
        [%& %& (snip `path`pax) (rear pax)]
      [%& %| pax]
    =/  dir-sand=sand:nexus  (~(dip of root-sand) tree-path)
    =/  cur=weir:nexus  (fall fil.dir-sand [~ ~ ~])
    =/  new=weir:nexus
      ?+  category  cur
        %'write'  cur(make (~(put in make.cur) new-road))
        %'poke'   cur(poke (~(put in poke.cur) new-road))
        %'read'   cur(peek (~(put in peek.cur) new-road))
      ==
    ;<  ~  bind:m  (sand:io /sand [%& %| tree-path] `new)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ::
      %'del-weir-road'
    =/  category=@t  (fall (get-key:kv:html-utils 'category' args) '')
    =/  road-path=@t  (fall (get-key:kv:html-utils 'road-path' args) '')
    =/  road-type=@t  (fall (get-key:kv:html-utils 'road-type' args) '')
    ?:  =('' category)
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing category')])
      (pure:m ~)
    =/  pax=path  (stab road-path)
    =/  del-road=road:tarball
      ?:  =('file' road-type)
        ?~  pax
          [%& %| /]
        [%& %& (snip `path`pax) (rear pax)]
      [%& %| pax]
    =/  dir-sand=sand:nexus  (~(dip of root-sand) tree-path)
    =/  cur=weir:nexus  (fall fil.dir-sand [~ ~ ~])
    =/  new=weir:nexus
      ?+  category  cur
        %'write'  cur(make (~(del in make.cur) del-road))
        %'poke'   cur(poke (~(del in poke.cur) del-road))
        %'read'   cur(peek (~(del in peek.cur) del-road))
      ==
    ;<  ~  bind:m  (sand:io /sand [%& %| tree-path] `new)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ::
      %'clear-weir'
    ;<  ~  bind:m  (sand:io /sand [%& %| tree-path] ~)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ==
::  Handle multipart file upload
::
++  handle-upload
  |=  [eyre-id=@ta tree-path=path req=inbound-request:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  parts=(unit (list [@t part:multipart]))
    (de-request:multipart header-list.request.req body.request.req)
  ?~  parts
    ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Invalid multipart data')])
    (pure:m ~)
  ::  Build mime→mark tubes for uploaded file extensions
  ;<  now=@da  bind:m  get-time:io
  ;<  our=@p  bind:m  get-our:io
  ;<  =desk  bind:m  get-desk:io
  =/  exts=(set @ta)
    %-  ~(gas in *(set @ta))
    %+  murn  u.parts
    |=  [field-name=@t =part:multipart]
    ?.  =('file' field-name)  ~
    ?~  file.part  ~
    (parse-extension:tarball u.file.part)
  ;<  conversions=(map mars:clay tube:clay)  bind:m
    =/  m  (fiber:fiber:nexus ,(map mars:clay tube:clay))
    =/  ext-list=(list @ta)  ~(tap in exts)
    =|  convs=(map mars:clay tube:clay)
    |-  ^-  form:m
    ?~  ext-list  (pure:m convs)
    =/  =mars:clay  [%mime i.ext-list]
    ;<  tube=(unit tube:clay)  bind:m
      (try-build-tube:io our desk [%da now] mars)
    =?  convs  ?=(^ tube)
      (~(put by convs) mars u.tube)
    $(ext-list t.ext-list)
  ::  Build ball from multipart using from-parts
  =/  new=ball:tarball
    (from-parts:tarball *ball:tarball ~ u.parts now conversions)
  ~&  >  [%upload-result (ball-to-tree:tarball new)]
  ::  Make each top-level entry: files then directories
  =/  files=(list [@ta content:tarball])
    ?~  fil.new  ~
    ~(tap by contents.u.fil.new)
  |-
  ?^  files
    =/  [name=@ta =content:tarball]  i.files
    ;<  ~  bind:m
      (make:io /upload [%& %& tree-path name] |+cage.content ~)
    $(files t.files)
  =/  dirs=(list [@ta ball:tarball])  ~(tap by dir.new)
  |-
  ?^  dirs
    =/  [name=@ta sub=ball:tarball]  i.dirs
    ;<  ~  bind:m
      (make:io /upload [%& %| (snoc tree-path name)] &+[*sand:nexus sub] ~)
    $(dirs t.dirs)
  =/  redirect-url=tape
    ?~(tree-path "/grubbery/ball" "/grubbery/ball{(trip (spat tree-path))}")
  ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
  (pure:m ~)
::  Serve a directory as a tarball download
::
++  serve-tarball
  |=  [eyre-id=@ta tree-path=path b=ball:tarball sub-born=born:nexus]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  stamped=ball:tarball  (stamp-mtimes:nexus sub-born b)
  ;<  now=@da  bind:m  get-time:io
  ;<  conversions=(map mars:clay tube:clay)  bind:m
    (get-mark-conversions:io stamped)
  =/  tar=tarball:tarball
    (~(make-tarball gen:tarball [now conversions]) tree-path stamped)
  =/  tar-data=octs  (encode-tarball:tarball tar)
  =/  dir-name=tape
    ?~(tree-path "root" (trip (rear tree-path)))
  =/  headers=header-list:http
    :~  ['content-type' 'application/x-tar']
        ['content-disposition' (crip "attachment; filename=\"{dir-name}.tar\"")]
    ==
  ;<  ~  bind:m  (send-simple:srv eyre-id [[200 headers] `tar-data])
  (pure:m ~)
::  Find a grub by URL segment in a lump
::  Matches exact name first, then tries name.mark pattern
::
++  find-grub
  |=  [seg=@ta =lump:tarball]
  ^-  (unit content:tarball)
  =/  direct  (~(get by contents.lump) seg)
  ?^  direct  direct
  =/  entries=(list [@ta content:tarball])  ~(tap by contents.lump)
  |-
  ?~  entries  ~
  =/  [name=@ta =content:tarball]  i.entries
  ?:  =(seg (crip "{(trip name)}.{(trip p.cage.content)}"))
    `content
  $(entries t.entries)
::  Handle SSE stream: subscribe to root, push change events
::
++  handle-stream
  |=  [eyre-id=@ta req=inbound-request:eyre watch-path=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  (is-sse-request:http-utils req)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'SSE only')])
    (pure:m ~)
  ;<  ~  bind:m  (send-header:srv eyre-id sse-header:http-utils)
  ;<  initial-seen=seen:nexus  bind:m  (peek:io /initial [%& %| ~] ~)
  =/  prev-born=born:nexus
    ?.  ?&(?=(%& -.initial-seen) ?=(%ball -.p.initial-seen))
      *born:nexus
    born.p.initial-seen
  =/  prev-weir=(unit weir:nexus)
    ?.  ?&(?=(%& -.initial-seen) ?=(%ball -.p.initial-seen))
      ~
    =/  s  (~(dip of sand.p.initial-seen) watch-path)
    fil.s
  ;<  ~  bind:m  (keep:io /ball [%& %| ~] ~)
  ;<  =bowl:nexus  bind:m  (get-bowl:io /sse)
  ;<  ~  bind:m  (send-wait:io (add now.bowl ~s30))
  |-
  ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /ball)
  ?-    -.nw
      %wake
    ;<  ~  bind:m  (send-data:srv eyre-id `sse-keep-alive:http-utils)
    ;<  =bowl:nexus  bind:m  (get-bowl:io /sse)
    ;<  ~  bind:m  (send-wait:io (add now.bowl ~s30))
    $
      %news
    ?.  ?=([%ball *] view.nw)  $
    =/  root=ball:tarball  ball.view.nw
    =/  root-born=born:nexus  born.view.nw
    =/  root-sand=sand:nexus  sand.view.nw
    =/  watch-sand=sand:nexus  (~(dip of root-sand) watch-path)
    =/  new-weir=(unit weir:nexus)  fil.watch-sand
    =/  what=(set lane:tarball)  (diff-born-state:nexus prev-born root-born)
    =.  prev-born  root-born
    =/  par=ball:tarball  (~(dip ba:tarball root) watch-path)
    =/  par-born=born:nexus  (~(dip of root-born) watch-path)
    =/  necks=(map path @ta)  (get-necks watch-path root)
    =/  url-prefix=tape  (build-url watch-path necks)
    ;<  =bowl:nexus  bind:m  (get-bowl:io /sse)
    ::  Only build tubes for marks of files that changed in watched dir
    =/  changed-marks=(set mark)
      %-  ~(gas in *(set mark))
      %+  murn  ~(tap in what)
      |=  =lane:tarball
      ^-  (unit mark)
      ?.  ?=(%& -.lane)  ~
      ?.  =(path.p.lane watch-path)  ~
      ?~  fil.par  ~
      =/  ct=(unit content:tarball)  (~(get by contents.u.fil.par) name.p.lane)
      ?~  ct  ~
      `p.cage.u.ct
    ;<  conversions=(map mars:clay tube:clay)  bind:m
      (build-mark-conversions:io changed-marks)
    =/  lanes=(list lane:tarball)  ~(tap in what)
    |-
    ?~  lanes
      ::  Check if watched directory was deleted
      =/  still-exists=?
        ?|  =(~ watch-path)
            ?=(^ (~(dap ba:tarball root) watch-path))
        ==
      ?.  still-exists
        =/  =json
          (pairs:enjs:format ~[['action' s+'deleted']])
        =/  =sse-event:http-utils  [~ `'ball-change' [(en:json:html json)]~]
        =/  data=octs  (sse-encode:http-utils ~[sse-event])
        ;<  ~  bind:m  (send-data:srv eyre-id `data)
        (pure:m ~)
      ::  Check for weir change
      ?.  =(prev-weir new-weir)
        =.  prev-weir  new-weir
        =/  weir-html=tape
          (zing (turn (render-weir new-weir url-prefix) en-xml:html))
        =/  =json
          %-  pairs:enjs:format
          :~  ['action' s+'weir']
              ['html' s+(crip weir-html)]
          ==
        =/  =sse-event:http-utils  [~ `'ball-change' [(en:json:html json)]~]
        =/  data=octs  (sse-encode:http-utils ~[sse-event])
        ;<  ~  bind:m  (send-data:srv eyre-id `data)
        ^$
      ^$
    =/  [parent=path item=@ta is-file=?]
      ?-  -.i.lanes
        %&  [path.p.i.lanes name.p.i.lanes %.y]
        %|  ?~  p.i.lanes  [~ %$ %.n]
            [(snip `path`p.i.lanes) (rear p.i.lanes) %.n]
      ==
    ::  Skip lanes not matching watched directory
    ?.  =(parent watch-path)
      $(lanes t.lanes)
    =/  exists=?
      ?:  is-file
        ?~  fil.par  %.n
        (~(has by contents.u.fil.par) item)
      (~(has by dir.par) item)
    ?:  exists
      ::  Add: render full row HTML
      =/  row-html=tape
        ?:  is-file
          ?~  fil.par  ""
          =/  ct=(unit content:tarball)  (~(get by contents.u.fil.par) item)
          ?~  ct  ""
          (en-xml:html (render-grub-row item u.ct url-prefix watch-path par-born now.bowl conversions))
        =/  sub=(unit ball:tarball)  (~(get by dir.par) item)
        ?~  sub  ""
        (en-xml:html (render-dir-row item u.sub url-prefix))
      =/  =json
        %-  pairs:enjs:format
        :~  ['action' s+'add']
            ['name' s+item]
            ['html' s+(crip row-html)]
        ==
      =/  =sse-event:http-utils  [~ `'ball-change' [(en:json:html json)]~]
      =/  data=octs  (sse-encode:http-utils ~[sse-event])
      ;<  ~  bind:m  (send-data:srv eyre-id `data)
      $(lanes t.lanes)
    ::  Delete: send name
    =/  =json
      %-  pairs:enjs:format
      :~  ['action' s+'del']
          ['name' s+item]
      ==
    =/  =sse-event:http-utils  [~ `'ball-change' [(en:json:html json)]~]
    =/  data=octs  (sse-encode:http-utils ~[sse-event])
    ;<  ~  bind:m  (send-data:srv eyre-id `data)
    $(lanes t.lanes)
  ==
::  Walk root ball along path, collecting neck for each directory
::
++  get-necks
  |=  [pax=path root=ball:tarball]
  ^-  (map path @ta)
  =/  result=(map path @ta)
    ?~  fil.root  ~
    ?~  neck.u.fil.root  ~
    (~(put by *(map path @ta)) ~ u.neck.u.fil.root)
  =/  current=ball:tarball  root
  =/  built=path  ~
  =/  rem=path  pax
  |-
  ?~  rem  result
  =/  child=(unit ball:tarball)  (~(get by dir.current) i.rem)
  ?~  child  result
  =.  built  (snoc built i.rem)
  =?  result  ?&(?=(^ fil.u.child) ?=(^ neck.u.fil.u.child))
    (~(put by result) built u.neck.u.fil.u.child)
  $(rem t.rem, current u.child)
::  Resolve URL path by stripping neck extensions from segments
::
++  resolve-url-path
  |=  [raw=path root=ball:tarball]
  ^-  path
  =/  current=ball:tarball  root
  =/  result=path  ~
  |-
  ?~  raw  result
  ::  Try direct match in directory children
  =/  child=(unit ball:tarball)  (~(get by dir.current) i.raw)
  ?^  child
    $(raw t.raw, result (snoc result i.raw), current u.child)
  ::  Try stripping extension to match dir with neck
  =/  match=(unit [@ta ball:tarball])
    =/  dirs=(list [@ta ball:tarball])  ~(tap by dir.current)
    |-
    ?~  dirs  ~
    =/  [dn=@ta sub=ball:tarball]  i.dirs
    =/  nk=(unit @ta)
      ?~  fil.sub  ~
      neck.u.fil.sub
    ?~  nk  $(dirs t.dirs)
    ?:  =(i.raw (crip "{(trip dn)}.{(trip u.nk)}"))
      `[dn sub]
    $(dirs t.dirs)
  ?^  match
    =/  [dn=@ta sub=ball:tarball]  u.match
    $(raw t.raw, result (snoc result dn), current sub)
  ::  No match — keep segment as-is
  $(raw t.raw, result (snoc result i.raw))
::  Build URL path with neck extensions for each segment
::
++  build-url
  |=  [pax=path necks=(map path @ta)]
  ^-  tape
  =/  built=path  ~
  =/  acc=tape  "/grubbery/ball"
  |-
  ?~  pax  acc
  =.  built  (snoc built i.pax)
  =/  nk=(unit @ta)  (~(get by necks) built)
  =/  seg=tape
    ?~  nk  "/{(trip i.pax)}"
    "/{(trip i.pax)}.{(trip u.nk)}"
  $(pax t.pax, acc (weld acc seg))
::
++  page-head
  |=  title=tape
  ^-  manx
  ;head
    ;title: {title}
    ;meta(charset "utf-8");
    ;meta(name "viewport", content "width=device-width, initial-scale=1");
    ;link(rel "icon", href "data:,");
    ;style
      ; body { font-family: monospace; margin: 20px; }
      ; h1 { font-size: 18px; }
      ; table { border-collapse: collapse; width: 100%; }
      ; th, td { text-align: left; padding: 8px; }
      ; th { border-bottom: 1px solid #ccc; }
      ; a { color: #0366d6; text-decoration: none; }
      ; a:hover { text-decoration: underline; }
      ; .neck { color: #6a737d; font-style: italic; }
      ; .breadcrumb { margin-bottom: 10px; }
      ; .breadcrumb a { margin: 0 2px; }
      ; .info { margin: 10px 0; padding: 10px; background: #f6f8fa; border-radius: 6px; }
      ; .info dt { font-weight: bold; float: left; width: 100px; }
      ; .info dd { margin-left: 110px; margin-bottom: 4px; }
      ; button { padding: 2px 8px; cursor: pointer; font-family: monospace; font-size: 12px; }
      ; .del-form { display: inline; }
      ; .symlink-target { color: #6a737d; }
      ; .action-row { margin: 6px 0; display: flex; gap: 6px; align-items: center; }
      ; .action-row label { font-weight: bold; min-width: 110px; }
      ; .inline-form { display: flex; gap: 4px; align-items: center; }
      ; .inline-form input[type="text"] { padding: 2px 4px; font-family: monospace; font-size: 12px; width: 120px; }
      ; .weir-system { color: #e36209; font-weight: bold; }
      ; .weir-label { color: #6a737d; margin-right: 4px; }
      ; .weir-roads { color: #6f42c1; }
      ; .weir-road-item { margin-right: 8px; }
      ; .weir-del { font-size: 10px; padding: 0 4px; margin-left: 2px; color: #cb2431; cursor: pointer; }
      ; select { padding: 2px 4px; font-family: monospace; font-size: 12px; }
      ; .sortable { cursor: pointer; user-select: none; }
      ; .sortable:hover { background: #f0f0f0; }
      ; .sortable::after { content: ' \2195'; opacity: 0.3; }
      ; .sortable.asc::after { content: ' \2191'; opacity: 1; }
      ; .sortable.desc::after { content: ' \2193'; opacity: 1; }
    ==
  ==
::
++  breadcrumb
  |=  [pax=path necks=(map path @ta)]
  ^-  manx
  ::  Precompute segment data (need accumulation for built path)
  =/  seg-data=(list [seg=@ta url=tape neck-ext=tape])
    =/  built=path  ~
    =/  acc=(list [seg=@ta url=tape neck-ext=tape])  ~
    =/  rem=path  pax
    |-
    ?~  rem  (flop acc)
    =.  built  (snoc built i.rem)
    =/  url=tape  (build-url built necks)
    =/  nk=tape
      =/  got=(unit @ta)  (~(get by necks) built)
      ?~  got  ""
      ".{(trip u.got)}"
    $(rem t.rem, acc [[i.rem url nk] acc])
  =/  root-neck=tape
    =/  got=(unit @ta)  (~(get by necks) ~)
    ?~  got  ""
    ".{(trip u.got)}"
  =/  crumbs=(list manx)
    :~  ;a/"/grubbery/ball": {root-neck}/
    ==
  =.  crumbs
    %+  weld  crumbs
    %+  turn  seg-data
    |=  [seg=@ta url=tape neck-ext=tape]
    ^-  manx
    ;a/"{url}": {(trip seg)}{neck-ext}/
  ;div.breadcrumb
    ;*  crumbs
  ==
::
++  dir-info
  |=  [b=ball:tarball url-prefix=tape dir-weir=(unit weir:nexus) pax=path]
  ^-  manx
  =/  neck-display=tape
    ?~  fil.b  "-"
    ?~  neck.u.fil.b  "-"
    (trip u.neck.u.fil.b)
  =/  nkids=@ud
    %+  add
      ~(wyt by dir.b)
    ?~(fil.b 0 ~(wyt by contents.u.fil.b))
  =/  download-url=tape  "{url-prefix}?download=tar"
  ;div.info
    ;dl
      ;dt: nexus
      ;dd: {neck-display}
      ;dt: items
      ;dd: {(scow %ud nkids)}
      ;dt: sandbox
      ;dd#sandbox-value
        ;*  (render-sandbox dir-weir url-prefix pax)
      ==
    ==
    ;*  ?.  ?=(^ pax)  ~
        :~  ;div.action-row
              ;form.inline-form(method "POST", action url-prefix)
                ;label: Add to Weir:
                ;select(name "category")
                  ;option(value "write"): write
                  ;option(value "poke"): poke
                  ;option(value "read"): read
                ==
                ;select(name "road-type")
                  ;option(value "dir"): dir
                  ;option(value "file"): file
                ==
                ;input(type "text", name "road-path", placeholder "/path", required "");
                ;input(type "hidden", name "action", value "add-weir-road");
                ;button(type "submit"): Add
              ==
            ==
        ==
    ;div.action-row
      ;label: Download:
      ;a/"{download-url}"
        ;button(type "button"): Download as Tarball
      ==
    ==
    ;div.action-row
      ;form.inline-form(method "POST", action url-prefix)
        ;label: Create Folder:
        ;input(type "text", name "foldername", placeholder "folder-name", required "");
        ;input(type "hidden", name "action", value "create-folder");
        ;button(type "submit"): Create
      ==
    ==
    ;div.action-row
      ;form.inline-form(method "POST", action url-prefix)
        ;label: Create Symlink:
        ;input(type "text", name "linkname", placeholder "link-name", required "");
        ;input(type "text", name "target", placeholder "target-path", required "");
        ;input(type "hidden", name "action", value "create-symlink");
        ;button(type "submit"): Create
      ==
    ==
    ;div.action-row
      ;form.inline-form(method "POST", action url-prefix, enctype "multipart/form-data")
        ;label: Upload Grub:
        ;input(type "file", name "file");
        ;button(type "submit"): Upload
      ==
    ==
    ;div.action-row
      ;form.inline-form(method "POST", action url-prefix, enctype "multipart/form-data")
        ;label: Upload Grubs:
        ;input(type "file", name "file", multiple "");
        ;button(type "submit"): Upload All
      ==
    ==
    ;div.action-row
      ;form.inline-form(method "POST", action url-prefix, enctype "multipart/form-data")
        ;label: Upload Directory:
        ;input(type "file", name "file", webkitdirectory "", directory "");
        ;button(type "submit"): Upload Directory
      ==
    ==
  ==
::
++  render-sandbox
  |=  [dir-weir=(unit weir:nexus) url-prefix=tape pax=path]
  ^-  (list manx)
  ?.  ?=(^ pax)
    :~  ;span.weir-system: unrestricted
    ==
  (render-weir dir-weir url-prefix)
::
++  render-weir
  |=  [dir-weir=(unit weir:nexus) url-prefix=tape]
  ^-  (list manx)
  ?~  dir-weir
    :~  ;span.weir-system: unrestricted
    ==
  =/  items=(list manx)
    ;:  weld
      (render-weir-category "write" make.u.dir-weir url-prefix)
      (render-weir-category "poke" poke.u.dir-weir url-prefix)
      (render-weir-category "read" peek.u.dir-weir url-prefix)
    ==
  %+  snoc  items
  ;form.del-form(method "POST", action url-prefix)
    ;input(type "hidden", name "action", value "clear-weir");
    ;button.weir-del(type "submit", onclick "return confirm('Remove weir? This gives unrestricted access.')"): clear weir
  ==
::
++  render-weir-category
  |=  [label=tape roads=(set road:tarball) url-prefix=tape]
  ^-  (list manx)
  =/  road-items=(list manx)
    %+  turn  ~(tap in roads)
    |=  =road:tarball
    ^-  manx
    =/  display=tape  (render-road road)
    =/  [road-path=tape road-type=tape]  (road-to-form road)
    ;span.weir-road-item
      ;span.weir-roads: {display}
      ;form.del-form(method "POST", action url-prefix)
        ;input(type "hidden", name "action", value "del-weir-road");
        ;input(type "hidden", name "category", value label);
        ;input(type "hidden", name "road-path", value road-path);
        ;input(type "hidden", name "road-type", value road-type);
        ;button.weir-del(type "submit"): x
      ==
    ==
  %+  weld
    :~  ;span.weir-label: {label}:
    ==
  ?~  road-items
    :~  ;span.weir-roads: -
        ;br;
    ==
  (snoc road-items ;br;)
::
++  render-road
  |=  =road:tarball
  ^-  tape
  ?-    -.road
      %&  (render-lane p.road)
      %|
    =/  ups=tape  (reap p.p.road '^')
    "{ups}{(render-lane q.p.road)}"
  ==
::
++  road-to-form
  |=  =road:tarball
  ^-  [path=tape type=tape]
  ?-    -.road
      %&
    ?-  -.p.road
      %&  [(trip (spat (snoc path.p.p.road name.p.p.road))) "file"]
      %|  [(trip (spat p.p.road)) "dir"]
    ==
      %|
    ?-  -.q.p.road
      %&  [(trip (spat (snoc path.p.q.p.road name.p.q.p.road))) "file"]
      %|  [(trip (spat p.q.p.road)) "dir"]
    ==
  ==
::
++  render-lane
  |=  =lane:tarball
  ^-  tape
  ?-    -.lane
      %&
    =/  dir=tape  (trip (spat path.p.lane))
    "{dir}/{(trip name.p.lane)}"
      %|
    ?~(p.lane "/" (trip (spat p.lane)))
  ==
::
++  render-dir
  |=  $:  pax=path
          root=ball:tarball
          root-born=born:nexus
          root-sand=sand:nexus
          now=@da
          conversions=(map mars:clay tube:clay)
      ==
  ^-  manx
  =/  b=ball:tarball  (~(dip ba:tarball root) pax)
  =/  b-born=born:nexus  (~(dip of root-born) pax)
  =/  dir-sand=sand:nexus  (~(dip of root-sand) pax)
  =/  dir-weir=(unit weir:nexus)  fil.dir-sand
  =/  necks=(map path @ta)  (get-necks pax root)
  =/  neck-ext=tape
    ?~  fil.b  ""
    ?~  neck.u.fil.b  ""
    ".{(trip u.neck.u.fil.b)}"
  =/  path-display=tape
    ?~  pax  "/{neck-ext}"
    "{(trip (spat pax))}{neck-ext}"
  =/  kids  dir.b
  =/  file-contents=(map @ta content:tarball)
    ?~  fil.b  ~
    contents.u.fil.b
  =/  subdirs=(list @ta)  ~(tap in ~(key by kids))
  =/  files=(list @ta)  ~(tap in ~(key by file-contents))
  =/  url-prefix=tape  (build-url pax necks)
  ;html
    ;+  (page-head "Index of {path-display}")
    ;body
      ;+  (breadcrumb pax necks)
      ;h1: Index of {path-display}
      ;+  (dir-info b url-prefix dir-weir pax)
      ;table#listing(data-path (trip (spat pax)))
        ;tr
          ;th.sortable(data-col "0", onclick "sortTable(0)"): Name
          ;th.sortable(data-col "1", onclick "sortTable(1)"): Mime Type
          ;th.sortable(data-col "2", onclick "sortTable(2)"): Size
          ;th.sortable(data-col "3", onclick "sortTable(3)"): Modified
          ;th: Actions
        ==
        ;*
        =/  rows=(list manx)  ~
        ::  Parent link
        =?  rows  ?=(^ pax)
          =/  parent=path  (snip `path`pax)
          =/  parent-url=tape  (build-url parent necks)
          %+  snoc  rows
          ;tr
            ;td
              ;a/"{parent-url}": ../
            ==
            ;td: -
            ;td: -
            ;td: -
            ;td: -
          ==
        ::  Subdirectories
        =.  rows
          %+  weld  rows
          %+  turn  subdirs
          |=  name=@ta
          ^-  manx
          =/  sub=ball:tarball  (~(got by kids) name)
          (render-dir-row name sub url-prefix)
        ::  Grubs
        =.  rows
          %+  weld  rows
          %+  turn  files
          |=  name=@ta
          ^-  manx
          =/  =content:tarball  (~(got by file-contents) name)
          (render-grub-row name content url-prefix pax b-born now conversions)
        rows
      ==
      ;script: {(trip sse-script)}
    ==
  ==
::
++  sse-script
  ^-  @t
  '''
  var sortCol = 0, sortAsc = true;
  function getRows() {
    var tbl = document.getElementById('listing');
    return Array.from(tbl.querySelectorAll('tr[data-name]'));
  }
  function sortVal(row, col) {
    if (col === 2) return parseInt(row.dataset.size || '0') || 0;
    return (row.cells[col] && row.cells[col].textContent || '').toLowerCase();
  }
  function doSort() {
    var tbl = document.getElementById('listing');
    var tb = tbl.querySelector('tbody') || tbl;
    var rows = getRows();
    rows.sort(function(a, b) {
      var ta = a.dataset.type || '', tb2 = b.dataset.type || '';
      if (ta !== tb2) { var df = ta === 'dir' ? -1 : 1; return sortAsc ? df : -df; }
      var va = sortVal(a, sortCol), vb = sortVal(b, sortCol);
      var cmp = (typeof va === 'number') ? va - vb : (va < vb ? -1 : va > vb ? 1 : 0);
      return sortAsc ? cmp : -cmp;
    });
    rows.forEach(function(r) { tb.appendChild(r); });
    tbl.querySelectorAll('th.sortable').forEach(function(th) {
      th.classList.remove('asc', 'desc');
      if (parseInt(th.dataset.col) === sortCol) th.classList.add(sortAsc ? 'asc' : 'desc');
    });
  }
  function sortTable(col) {
    if (sortCol === col) { sortAsc = !sortAsc; }
    else { sortCol = col; sortAsc = true; }
    doSort();
  }
  (function() {
    doSort();
    var tbl = document.getElementById('listing');
    if (!tbl) return;
    var tb = tbl.querySelector('tbody') || tbl;
    var es = new EventSource('/grubbery/ball/stream?path=' + tbl.dataset.path);
    es.addEventListener('ball-change', function(e) {
      var d = JSON.parse(e.data);
      if (d.action === 'weir') {
        var sb = document.getElementById('sandbox-value');
        if (sb) sb.innerHTML = d.html;
        return;
      }
      if (d.action === 'deleted') {
        document.body.innerHTML = '<h1>Directory deleted</h1><p><a href="/grubbery/ball">Back to root</a></p>';
        es.close();
        return;
      }
      var row = tb.querySelector('tr[data-name="' + d.name + '"]');
      if (row) row.remove();
      if (d.action === 'add' && d.html) {
        tb.insertAdjacentHTML('beforeend', d.html);
        doSort();
      }
    });
    window.addEventListener('beforeunload', function() { es.close(); });
  })();
  '''
::
::
::
++  format-size
  |=  n=@ud
  ^-  tape
  ?:  (lth n 1.024)
    "{(scow %ud n)} B"
  ?:  (lth n 1.048.576)
    "{(scow %ud (div n 1.024))} KB"
  "{(scow %ud (div n 1.048.576))} MB"
::
++  render-dir-row
  |=  [name=@ta sub=ball:tarball url-prefix=tape]
  ^-  manx
  =/  sub-neck=tape
    ?~  fil.sub  ""
    ?~  neck.u.fil.sub  ""
    ".{(trip u.neck.u.fil.sub)}"
  =/  dir-url=tape  "{url-prefix}/{(trip name)}{sub-neck}"
  ;tr(data-name (trip name), data-type "dir")
    ;td
      ;a/"{dir-url}": {(trip name)}{sub-neck}/
    ==
    ;td: -
    ;td: -
    ;td: -
    ;td
      ;a/"{dir-url}?download=tar"
        ;button(type "button"): Download
      ==
      ;form.del-form(method "POST", action url-prefix)
        ;input(type "hidden", name "action", value "delete-folder");
        ;input(type "hidden", name "foldername", value (trip name));
        ;button(type "submit", onclick "return confirm('Delete folder {(trip name)} and all its contents?')"): Delete
      ==
    ==
  ==
::
++  render-grub-row
  |=  $:  name=@ta
          =content:tarball
          url-prefix=tape
          pax=path
          dir-born=born:nexus
          now=@da
          conversions=(map mars:clay tube:clay)
      ==
  ^-  manx
  =/  mtime-display=tape
    =/  node=(unit [=tote:nexus bags=(map @ta sack:nexus)])
      (~(get of dir-born) ~)
    ?~  node  "-"
    =/  sk=(unit sack:nexus)  (~(get by bags.u.node) name)
    ?~  sk  "-"
    (en:datetime-local:iso-8601 da.file.u.sk)
  =/  cag=cage  cage.content
  ?:  =(%symlink p.cag)
    =/  sym  !<(symlink:tarball q.cag)
    =/  target-display=tape  (trip (encode-symlink:tarball sym))
    =/  resolved-path=path  (resolve-symlink:tarball sym pax)
    =/  target-url=tape  "/grubbery/ball{(trip (spat resolved-path))}"
    ;tr(data-name (trip name), data-type "grub")
      ;td
        ;a/"{target-url}": {(trip name)}
        ;span.symlink-target:  -> {target-display}
      ==
      ;td: symlink
      ;td: -
      ;td: {mtime-display}
      ;td
        ;form.del-form(method "POST", action url-prefix)
          ;input(type "hidden", name "action", value "delete-grub");
          ;input(type "hidden", name "filename", value (trip name));
          ;button(type "submit", onclick "return confirm('Delete {(trip name)}?')"): Delete
        ==
      ==
    ==
  =/  display-name=tape
    ?:  =(%mime p.cag)
      (trip name)
    "{(trip name)}.{(trip p.cag)}"
  =/  file-url=tape  "{url-prefix}/{display-name}"
  =/  =mime
    ?:  =(%mime p.cag)
      !<(mime q.cag)
    ?:  =(%temp p.cag)
      [/text/plain (as-octs:mimes:html (crip (noah q.cag)))]
    (~(cage-to-mime gen:tarball [now conversions]) cag)
  =/  mime-raw=tape  (trip (spat p.mime))
  =/  mime-display=tape  ?~(mime-raw "" (tail mime-raw))
  ;tr(data-name (trip name), data-type "grub", data-size (scow %ud p.q.mime))
    ;td
      ;a/"{file-url}": {display-name}
    ==
    ;td: {mime-display}
    ;td: {(format-size p.q.mime)}
    ;td: {mtime-display}
    ;td
      ;a/"{file-url}"(download display-name)
        ;button(type "button"): Download
      ==
      ;form.del-form(method "POST", action url-prefix)
        ;input(type "hidden", name "action", value "delete-grub");
        ;input(type "hidden", name "filename", value (trip name));
        ;button(type "submit", onclick "return confirm('Delete {(trip name)}?')"): Delete
      ==
    ==
  ==
--
