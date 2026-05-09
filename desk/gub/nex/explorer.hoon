::  explorer nexus: tarball tree browser
::
/<  feather  /lib/feather.hoon
/<  nex-server  /lib/nex/server.hoon
/<  iso-8601  /lib/iso-8601.hoon
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  [=sand:nexus =gain:nexus =ball:tarball]
      ^-  [sand:nexus gain:nexus ball:tarball]
      =/  =ver:loader  (get-ver:loader ball)
      ?+  ver  !!
          ?(~ [~ %0])
        %+  spin:loader  [sand gain ball]
        :~  (ver-row:loader 0)
            [%fall %& [/ %'main.sig'] %.n [~ [/ %sig] !>(~)]]
            [%fall %| /requests [~ ~] [~ ~] empty-dir:loader]
        ==
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =mark]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%explorer /main: failed, poke to restart")
        ~&  >  "%explorer /main: binding /grubbery/ball and /grubbery/split"
        ;<  ~  bind:m  (bind-http:nex-server [~ /grubbery/ball])
        ;<  ~  bind:m  (bind-http:nex-server [~ /grubbery/split])
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
        =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
        ?:  ?=([%grubbery %split *] site)
          =/  bod=octs  (manx-to-octs:server render-split)
          ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils [/text/html bod]))
          (pure:m ~)
        =/  raw-path=path
          ?.  ?=([%grubbery %ball *] site)  ~
          t.t.site

        ?:  ?=([%stream ~] raw-path)
          =/  watch-path=path
            =/  p=(unit @t)  (get-key:kv:html-utils 'path' args)
            ?~  p  ~
            (stab u.p)
          (handle-stream eyre-id req watch-path)
        ;<  root-seen=seen:nexus  bind:m  (peek:io [%& %| ~] ~)
        ?.  ?=([%& %ball *] root-seen)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[500 ~] `(as-octs:mimes:html 'Peek failed')])
          (pure:m ~)
        =/  root=ball:tarball  ball.p.root-seen
        =/  root-born=born:nexus  born.p.root-seen
        =/  root-sand=sand:nexus  sand.p.root-seen
        =/  tree-path=path  (resolve-url-path raw-path root)
        ?:  =('POST' method.request.req)
          (handle-post eyre-id tree-path root-sand req)
        (handle-get eyre-id tree-path root root-born root-sand args)
      ==
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'Subdirectory under the explorer nexus.'
            ~
          %-  crip
          """
          EXPLORER NEXUS — web-based tarball file browser

          Serves directory listings and file contents over HTTP with a
          full CRUD interface: create, delete, upload, rename, and symlink.
          Streams live directory changes via SSE so the browser updates
          without polling.

          FILES:
            main.sig            HTTP binding process. Registers /grubbery/
                                with the server nexus.
            ver.ud              Schema version.

          DIRECTORIES:
            requests/           Per-request fibers for active HTTP connections.
          """
            [%requests ~]
          'Active HTTP request fibers. Each inbound request spawns a fiber here; cleaned up on completion.'
        ==
          %|
        ?+  rail.p.mana  'File under the explorer nexus.'
          [~ %'main.sig']  'Explorer HTTP binding process. Mark: sig. Registers URL prefix with the server nexus and dispatches inbound requests to per-request fibers in /requests/.'
          [~ %'ver.ud']    'Schema version counter. Mark: ud.'
        ==
      ==
    --
::
|%
::  HTTP response door (road from /explorer.explorer/requests/* to /explorer.explorer/main.sig)
::
++  srv  ~(. res:nex-server [%| 1 %& ~ %'main.sig'])
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
      (serve-tarball eyre-id tree-path u.sub)
    ;<  now=@da  bind:m  get-time:io
    ;<  conversions=(map bars:tarball tube:clay)  bind:m
      (get-blot-conversions-shallow:io u.sub)
    ::  Resolve governing /code namespace for blot & nexus links.
    ::  get-font returns a bend relative to this fiber's location,
    ::  so we resolve it with our own `here` rail to get the absolute path.
    ;<  font=(unit bend:tarball)  bind:m
      (get-font:io [%& %| tree-path])
    ;<  here=rail:tarball  bind:m  get-here:io
    =/  code-namespace=(unit path)
      ?~  font  ~
      =/  ns=(unit lane:tarball)
        (lane-from-bend:tarball [%& here] u.font)
      ?~  ns  ~
      ?.  ?=(%| -.u.ns)  ~
      `p.u.ns
    ::  Get bang state for this directory
    ;<  bang-res=(each bangs:nexus (unit tang))  bind:m
      (get-bang:io [%& %| tree-path])
    =/  dir-bangs=bangs:nexus
      ?:(?=(%& -.bang-res) p.bang-res *bangs:nexus)
    =/  bod=octs  (manx-to-octs:server (render-dir tree-path root root-born root-sand now conversions code-namespace dir-bangs))
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
  =/  =sage:tarball  sage.u.content-data
  =/  pretty-param=(unit @t)  (get-key:kv:html-utils 'pretty' args)
  ?^  pretty-param
    ::  ?pretty: render noun as text instead of binary download
    =/  bod=octs  (as-octs:mimes:html (crip (noah q.sage)))
    ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils [/text/plain bod]))
    (pure:m ~)
  ;<  =mime  bind:m  (sage-to-mime:io sage)
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
    ::  cull road: up 3 from /explorer.explorer/requests/[id] to root, then file
    ;<  ~  bind:m  (cull:io [%& %& tree-path filename])
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ::
      %'delete-folder'
    =/  foldername=@t  (fall (get-key:kv:html-utils 'foldername' args) '')
    =/  folder-path=path  (snoc tree-path foldername)
    ;<  ~  bind:m  (cull:io [%& %| folder-path])
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ::
      %'create-folder'
    =/  foldername=@t  (fall (get-key:kv:html-utils 'foldername' args) '')
    =/  dir-name=@ta  foldername
    =/  dir-neck=(unit neck:tarball)
      (bind (parse-extension:tarball dir-name) ext-to-neck:tarball)
    =/  folder-path=path  (snoc tree-path dir-name)
    =/  new-ball=ball:tarball  [`[~ dir-neck ~] ~]
    ;<  ~  bind:m  (make:io [%& %| folder-path] &+[[~ ~] [~ ~] new-ball])
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
    ;<  ~  bind:m  (make:io [%& %& tree-path linkname] |+[%.n [[/ %symlink] !>(u.sym)] ~])
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
    ;<  ~  bind:m  (sand:io [%& %| tree-path] `new)
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
    ;<  ~  bind:m  (sand:io [%& %| tree-path] `new)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ::
      %'clear-weir'
    ;<  ~  bind:m  (sand:io [%& %| tree-path] ~)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ::
      %'reload-nexus'
    ;<  ~  bind:m  (reload:io [%& %| tree-path])
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ::
      %'rename-grub'
    =/  filename=@t  (fall (get-key:kv:html-utils 'filename' args) '')
    =/  newname=@t  (fall (get-key:kv:html-utils 'newname' args) '')
    ?:  |(=('' filename) =('' newname))
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing filename or newname')])
      (pure:m ~)
    ;<  ~  bind:m  (move-grub:io [%& %& tree-path filename] [%& %& tree-path newname])
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ::
      %'rename-folder'
    =/  foldername=@t  (fall (get-key:kv:html-utils 'foldername' args) '')
    =/  newname=@t  (fall (get-key:kv:html-utils 'newname' args) '')
    ?:  |(=('' foldername) =('' newname))
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing foldername or newname')])
      (pure:m ~)
    ;<  ~  bind:m  (move-fold:io [%& %| (snoc tree-path foldername)] [%& %| (snoc tree-path newname)])
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ::
      %'move-grub'
    =/  filename=@t  (fall (get-key:kv:html-utils 'filename' args) '')
    =/  dest=@t  (fall (get-key:kv:html-utils 'dest' args) '')
    ?:  |(=('' filename) =('' dest))
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing filename or dest')])
      (pure:m ~)
    =/  dest-path=path  (stab dest)
    ?~  dest-path
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Invalid dest path')])
      (pure:m ~)
    =/  dst-dir=path  (snip `path`dest-path)
    =/  dst-name=@ta  (rear dest-path)
    ;<  ~  bind:m  (move-grub:io [%& %& tree-path filename] [%& %& dst-dir dst-name])
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ::
      %'move-folder'
    =/  foldername=@t  (fall (get-key:kv:html-utils 'foldername' args) '')
    =/  dest=@t  (fall (get-key:kv:html-utils 'dest' args) '')
    ?:  |(=('' foldername) =('' dest))
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing foldername or dest')])
      (pure:m ~)
    =/  dest-path=path  (stab dest)
    ;<  ~  bind:m  (move-fold:io [%& %| (snoc tree-path foldername)] [%& %| dest-path])
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ::
      %'copy-grub'
    =/  filename=@t  (fall (get-key:kv:html-utils 'filename' args) '')
    =/  dest=@t  (fall (get-key:kv:html-utils 'dest' args) '')
    ?:  |(=('' filename) =('' dest))
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing filename or dest')])
      (pure:m ~)
    =/  dest-path=path  (stab dest)
    ?~  dest-path
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Invalid dest path')])
      (pure:m ~)
    =/  dst-dir=path  (snip `path`dest-path)
    =/  dst-name=@ta  (rear dest-path)
    ;<  ~  bind:m  (copy-grub:io [%& %& tree-path filename] [%& %& dst-dir dst-name])
    ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
    (pure:m ~)
  ::
      %'copy-folder'
    =/  foldername=@t  (fall (get-key:kv:html-utils 'foldername' args) '')
    =/  dest=@t  (fall (get-key:kv:html-utils 'dest' args) '')
    ?:  |(=('' foldername) =('' dest))
      ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing foldername or dest')])
      (pure:m ~)
    =/  dest-path=path  (stab dest)
    ;<  ~  bind:m  (copy-fold:io [%& %| (snoc tree-path foldername)] [%& %| dest-path])
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
      (make:io [%& %& tree-path name] |+[%.n sage.content ~])
    $(files t.files)
  =/  dirs=(list [@ta ball:tarball])  ~(tap by dir.new)
  |-
  ?^  dirs
    =/  [name=@ta sub=ball:tarball]  i.dirs
    ;<  ~  bind:m
      (make:io [%& %| (snoc tree-path name)] &+[[~ ~] [~ ~] sub])
    $(dirs t.dirs)
  =/  redirect-url=tape
    ?~(tree-path "/grubbery/ball" "/grubbery/ball{(trip (spat tree-path))}")
  ;<  ~  bind:m  (send-simple:srv eyre-id [[303 ~[['location' (crip redirect-url)]]] ~])
  (pure:m ~)
::  Serve a directory as a tarball download
::
++  serve-tarball
  |=  [eyre-id=@ta tree-path=path b=ball:tarball]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  ;<  conversions=(map bars:tarball tube:clay)  bind:m
    (get-blot-conversions:io b)
  =/  tar=tarball:tarball
    (~(make-tarball gen:tarball [now conversions]) tree-path b)
  =/  tar-data=octs  (encode-tarball:tarball tar)
  =/  dir-name=tape
    ?~(tree-path "root" (trip (rear tree-path)))
  =/  headers=header-list:http
    :~  ['content-type' 'application/x-tar']
        ['content-disposition' (crip "attachment; filename=\"{dir-name}.tar\"")]
    ==
  ;<  ~  bind:m  (send-simple:srv eyre-id [[200 headers] `tar-data])
  (pure:m ~)
::  Find a grub by exact name in a lump
::
++  find-grub
  |=  [seg=@ta =lump:tarball]
  ^-  (unit content:tarball)
  (~(get by contents.lump) seg)
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
  ;<  initial-seen=seen:nexus  bind:m  (peek:io [%& %| ~] ~)
  =/  prev-born=born:nexus
    ?.  ?&(?=(%& -.initial-seen) ?=(%ball -.p.initial-seen))
      *born:nexus
    born.p.initial-seen
  =/  prev-weir=(unit weir:nexus)
    ?.  ?&(?=(%& -.initial-seen) ?=(%ball -.p.initial-seen))
      ~
    =/  s  (~(dip of sand.p.initial-seen) watch-path)
    fil.s
  ;<  *  bind:m  (keep:io /ball [%& %| ~] ~)
  ;<  now=@da  bind:m  get-time:io
  ;<  ~  bind:m  (send-wait:io (add now ~s30))
  |-
  ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /ball)
  ?-    -.nw
      %wake
    ;<  ~  bind:m  (send-data:srv eyre-id `sse-keep-alive:http-utils)
    ;<  now=@da  bind:m  get-time:io
    ;<  ~  bind:m  (send-wait:io (add now ~s30))
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
    =/  url-prefix=tape  (build-url watch-path)
    ::  Resolve governing /code namespace so SSE-pushed rows get
    ::  the same blot & nexus links as the initial page render.
    ::  The bend is relative to this fiber, so resolve with `here`.
    ;<  font=(unit bend:tarball)  bind:m
      (get-font:io [%& %| watch-path])
    ;<  here=rail:tarball  bind:m  get-here:io
    =/  code-namespace=(unit path)
      ?~  font  ~
      =/  ns=(unit lane:tarball)
        (lane-from-bend:tarball [%& here] u.font)
      ?~  ns  ~
      ?.  ?=(%| -.u.ns)  ~
      `p.u.ns
    ;<  now=@da  bind:m  get-time:io
    ::  Only build tubes for marks of files that changed in watched dir
    =/  changed-blots=(set blot:tarball)
      %-  ~(gas in *(set blot:tarball))
      %+  murn  ~(tap in what)
      |=  =lane:tarball
      ^-  (unit blot:tarball)
      ?.  ?=(%& -.lane)  ~
      ?.  =(path.p.lane watch-path)  ~
      ?~  fil.par  ~
      =/  ct=(unit content:tarball)  (~(get by contents.u.fil.par) name.p.lane)
      ?~  ct  ~
      `p.sage.u.ct
    ;<  conversions=(map bars:tarball tube:clay)  bind:m
      (build-blot-conversions:io changed-blots)
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
          (en-xml:html (render-grub-row item u.ct url-prefix watch-path par-born now conversions code-namespace ~))
        =/  sub=(unit ball:tarball)  (~(get by dir.par) item)
        ?~  sub  ""
        (en-xml:html (render-dir-row item u.sub url-prefix ~))
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
::  Resolve URL path — direct match only
::
++  resolve-url-path
  |=  [raw=path root=ball:tarball]
  ^-  path
  =/  current=ball:tarball  root
  =/  result=path  ~
  |-
  ?~  raw  result
  =/  child=(unit ball:tarball)  (~(get by dir.current) i.raw)
  ?^  child
    $(raw t.raw, result (snoc result i.raw), current u.child)
  ::  No match — keep segment as-is
  $(raw t.raw, result (snoc result i.raw))
::  Build URL path from segments
::
++  build-url
  |=  pax=path
  ^-  tape
  =/  acc=tape  "/grubbery/ball"
  |-
  ?~  pax  acc
  $(pax t.pax, acc (weld acc "/{(trip i.pax)}"))
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
      ; .breadcrumb { margin-bottom: 10px; }
      ; .breadcrumb a { margin: 0 2px; }
      ; .info { margin: 10px 0; padding: 10px; background: #f6f8fa; border-radius: 6px; }
      ; .info dt { font-weight: bold; float: left; width: 100px; }
      ; .info dd { margin-left: 110px; margin-bottom: 4px; }
      ; button { padding: 2px 8px; cursor: pointer; font-family: monospace; font-size: 12px; }
      ; .del-form { display: inline; }
      ; .symlink-target { color: #6a737d; }
      ; .mark-mismatch { color: #cb2431; font-weight: bold; }
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
      ; .boom-banner { margin: 10px 0; padding: 10px; background: #ffeef0; border: 1px solid #cb2431; border-radius: 6px; cursor: pointer; }
      ; .boom-banner:hover { background: #fdd; }
      ; .boom-icon { color: #cb2431; font-weight: bold; cursor: pointer; margin-left: 4px; display: inline; }
      ; .boom-icon:hover { text-decoration: underline; }
      ; .boom-modal-overlay { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.4); z-index: 1000; }
      ; .boom-modal-overlay.active { display: flex; align-items: center; justify-content: center; }
      ; .boom-modal { background: #fff; border: 2px solid #cb2431; border-radius: 8px; padding: 16px; max-width: 80vw; max-height: 80vh; overflow: auto; min-width: 400px; }
      ; .boom-modal h3 { color: #cb2431; margin: 0 0 8px; }
      ; .boom-modal pre { white-space: pre-wrap; font-size: 12px; margin: 0; max-height: 60vh; overflow: auto; background: #ffeef0; padding: 8px; border-radius: 4px; }
    ==
  ==
::
++  breadcrumb
  |=  pax=path
  ^-  manx
  =/  seg-data=(list [seg=@ta url=tape])
    =/  built=path  ~
    =/  acc=(list [seg=@ta url=tape])  ~
    =/  rem=path  pax
    |-
    ?~  rem  (flop acc)
    =.  built  (snoc built i.rem)
    =/  url=tape  (build-url built)
    $(rem t.rem, acc [[i.rem url] acc])
  =/  crumbs=(list manx)
    :~  ;a/"/grubbery/ball": /
    ==
  =.  crumbs
    %+  weld  crumbs
    %+  turn  seg-data
    |=  [seg=@ta url=tape]
    ^-  manx
    ;a/"{url}": {(trip seg)}/
  ;div.breadcrumb
    ;*  crumbs
  ==
::
++  dir-info
  |=  [b=ball:tarball url-prefix=tape dir-weir=(unit weir:nexus) pax=path neck-url=(unit tape)]
  ^-  manx
  =/  neck-display=tape
    ?~  fil.b  "-"
    ?~  neck.u.fil.b  "-"
    (trip (spat (rail-to-path:tarball u.neck.u.fil.b)))
  =/  nkids=@ud
    %+  add
      ~(wyt by dir.b)
    ?~(fil.b 0 ~(wyt by contents.u.fil.b))
  =/  download-url=tape  "{url-prefix}?download=tar"
  ;div.info
    ;dl
      ;dt: nexus
      ;dd
        ;*  ?~  neck-url
              :~  ;span: {neck-display}
              ==
            :~  ;a/"{u.neck-url}": {neck-display}
            ==
      ==
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
    ;*  ?.  ?&(?=(^ fil.b) ?=(^ neck.u.fil.b))  ~
        :~  ;div.action-row
              ;form.inline-form(method "POST", action url-prefix)
                ;label: Nexus:
                ;input(type "hidden", name "action", value "reload-nexus");
                ;button(type "submit"): Reload
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
    =/  ups=tape  ?:(=(0 p.p.road) "./" (zing (reap p.p.road "../")))
    =/  lane=tape  (render-lane q.p.road)
    ::  strip leading / since ups already provides the prefix
    =/  trimmed=tape  ?:(&(?=(^ lane) =(i.lane '/')) t.lane lane)
    "{ups}{trimmed}"
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
          conversions=(map bars:tarball tube:clay)
          code-namespace=(unit path)
          =bangs:nexus
      ==
  ^-  manx
  =/  b=ball:tarball  (~(dip ba:tarball root) pax)
  =/  b-born=born:nexus  (~(dip of root-born) pax)
  =/  dir-sand=sand:nexus  (~(dip of root-sand) pax)
  =/  dir-weir=(unit weir:nexus)  fil.dir-sand
  ::  Nexus source link: combines the governing /code namespace
  ::  with the directory's neck rail to form a URL to the .hoon source.
  ::  e.g. /grubbery/ball/code/nex/wallet/account.hoon
  =/  neck-url=(unit tape)
    ?~  code-namespace  ~
    ?~  fil.b  ~
    ?~  neck.u.fil.b  ~
    `"/grubbery/ball{(trip (spat (weld u.code-namespace /nex)))}{(trip (spat (rail-to-path:tarball u.neck.u.fil.b)))}.hoon"
  =/  path-display=tape
    ?~  pax  "/"
    (trip (spat pax))
  =/  kids  dir.b
  =/  file-contents=(map @ta content:tarball)
    ?~  fil.b  ~
    contents.u.fil.b
  =/  subdirs=(list @ta)  ~(tap in ~(key by kids))
  =/  files=(list @ta)  ~(tap in ~(key by file-contents))
  =/  url-prefix=tape  (build-url pax)
  ::  Error state at this level
  =/  nexus-bang=(unit tang)  bang.bangs
  =/  file-bangs=(map @ta (unit tang))  err.bangs
  ;html
    ;+  (page-head "Index of {path-display}")
    ;body
      ;+  (breadcrumb pax)
      ;h1: Index of {path-display}
      ;+  (dir-info b url-prefix dir-weir pax neck-url)
      ;*  ?~  nexus-bang  ~
          =/  rendered=tape  (render-tang u.nexus-bang)
          :~  ;div.boom-banner(data-tang rendered, onclick "showBoom(this)")
                nexus crashed — click for details
              ==
          ==
      ;table#listing(data-path (trip (spat pax)))
        ;tr
          ;th.sortable(data-col "0", onclick "sortTable(0)"): Name
          ;th.sortable(data-col "1", onclick "sortTable(1)"): Blot
          ;th.sortable(data-col "2", onclick "sortTable(2)"): Mime Type
          ;th.sortable(data-col "3", onclick "sortTable(3)"): Size
          ;th.sortable(data-col "4", onclick "sortTable(4)"): Modified
          ;th: Actions
        ==
        ;*
        =/  rows=(list manx)  ~
        ::  Parent link
        =?  rows  ?=(^ pax)
          =/  parent=path  (snip `path`pax)
          =/  parent-url=tape  (build-url parent)
          %+  snoc  rows
          ;tr
            ;td
              ;a/"{parent-url}": ../
            ==
            ;td: -
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
          ::  TODO: query sub-directory bang state
          (render-dir-row name sub url-prefix ~)
        ::  Grubs
        =.  rows
          %+  weld  rows
          %+  turn  files
          |=  name=@ta
          ^-  manx
          =/  =content:tarball  (~(got by file-contents) name)
          =/  file-bang=(unit tang)  (fall (~(get by file-bangs) name) ~)
          (render-grub-row name content url-prefix pax b-born now conversions code-namespace file-bang)
        rows
      ==
      ;div#boom-overlay.boom-modal-overlay
        ;div.boom-modal
          ;h3: Error
          ;pre;
        ==
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
    if (col === 3) return parseInt(row.dataset.size || '0') || 0;
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
  function doAction(action, params) {
    var form = document.createElement('form');
    form.method = 'POST';
    form.action = location.pathname;
    var a = document.createElement('input');
    a.type = 'hidden'; a.name = 'action'; a.value = action;
    form.appendChild(a);
    for (var k in params) {
      var i = document.createElement('input');
      i.type = 'hidden'; i.name = k; i.value = params[k];
      form.appendChild(i);
    }
    document.body.appendChild(form);
    form.submit();
  }
  function renameItem(type, name) {
    var n = prompt('New name for ' + name + ':', name);
    if (!n || n === name) return;
    doAction('rename-' + type, type === 'grub' ? {filename: name, newname: n} : {foldername: name, newname: n});
  }
  function moveItem(type, name) {
    var cur = location.pathname.replace('/grubbery/ball', '') || '/';
    var d = prompt('Move ' + name + ' to (full path):', cur + (cur === '/' ? '' : '/') + name);
    if (!d) return;
    doAction('move-' + type, type === 'grub' ? {filename: name, dest: d} : {foldername: name, dest: d});
  }
  function copyItem(type, name) {
    var cur = location.pathname.replace('/grubbery/ball', '') || '/';
    var d = prompt('Copy ' + name + ' to (full path):', cur + (cur === '/' ? '' : '/') + name);
    if (!d) return;
    doAction('copy-' + type, type === 'grub' ? {filename: name, dest: d} : {foldername: name, dest: d});
  }
  function showBoom(el) {
    var pre = el.dataset.tang;
    var ov = document.getElementById('boom-overlay');
    ov.querySelector('pre').textContent = pre;
    ov.classList.add('active');
  }
  document.addEventListener('click', function(e) {
    var ov = document.getElementById('boom-overlay');
    if (e.target === ov) ov.classList.remove('active');
  });
  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') document.getElementById('boom-overlay').classList.remove('active');
  });
  '''
::
++  render-split
  ^-  manx
  ;html
    ;head
      ;title: grubbery split view
      ;meta(charset "utf-8");
      ;link(rel "icon", href "data:,");
      ;style
        ; * { box-sizing: border-box; margin: 0; padding: 0; }
        ; html, body { height: 100%; font-family: monospace; }
        ; .split-header { display: flex; height: 32px; background: #f6f8fa; border-bottom: 1px solid #ccc; }
        ; .pane-bar { display: flex; align-items: center; padding: 0 6px; gap: 4px; }
        ; .pane-bar.left { flex: 1; border-right: 1px solid #ccc; }
        ; .pane-bar.right { flex: 1; }
        ; .pane-bar input { flex: 1; font-family: monospace; font-size: 12px; border: 1px solid #ccc; padding: 2px 6px; min-width: 0; }
        ; .pane-bar button { background: none; border: 1px solid #ccc; cursor: pointer; font-family: monospace; font-size: 12px; padding: 2px 6px; }
        ; .pane-bar button:hover { background: #e1e4e8; }
        ; .split-container { display: flex; height: calc(100% - 32px); }
        ; .split-container iframe { border: none; height: 100%; }
        ; #left-frame { flex: 1; border-right: 1px solid #ccc; }
        ; #right-frame { flex: 1; }
      ==
    ==
    ;body
      ;div.split-header
        ;div.pane-bar.left
          ;button(onclick "goBack('left-frame')"): ←
          ;button(onclick "goFwd('left-frame')"): →
          ;input#left-url(type "text", value "/grubbery/ball", placeholder "/grubbery/ball/...", onkeydown "if(event.key==='Enter')navLeft()");
          ;button(onclick "navLeft()"): go
          ;button(onclick "mirrorRight()"): mirror →
        ==
        ;div.pane-bar.right
          ;button(onclick "goBack('right-frame')"): ←
          ;button(onclick "goFwd('right-frame')"): →
          ;input#right-url(type "text", value "/grubbery/ball", placeholder "/grubbery/ball/...", onkeydown "if(event.key==='Enter')navRight()");
          ;button(onclick "navRight()"): go
          ;button(onclick "mirrorLeft()"): mirror ←
        ==
      ==
      ;div#split.split-container
        ;iframe#left-frame(src "/grubbery/ball");
        ;iframe#right-frame(src "/grubbery/ball");
      ==
      ;script: {(trip split-script)}
    ==
  ==
::
++  split-script
  ^-  @t
  '''
  var hist = { 'left-frame': [], 'right-frame': [] };
  var fwd  = { 'left-frame': [], 'right-frame': [] };
  function navTo(id, inputId, url) {
    var f = document.getElementById(id);
    try { var cur = f.contentWindow.location.href; if (cur && cur !== 'about:blank') hist[id].push(cur); } catch(e) {}
    fwd[id] = [];
    f.src = url;
    document.getElementById(inputId).value = url;
  }
  function navLeft() {
    var url = document.getElementById('left-url').value.trim();
    if (url) navTo('left-frame', 'left-url', url);
  }
  function navRight() {
    var url = document.getElementById('right-url').value.trim();
    if (url) navTo('right-frame', 'right-url', url);
  }
  function mirrorLeft() {
    try {
      var loc = document.getElementById('left-frame').contentWindow.location.href;
      navTo('right-frame', 'right-url', loc);
    } catch(e) {}
  }
  function mirrorRight() {
    try {
      var loc = document.getElementById('right-frame').contentWindow.location.href;
      navTo('left-frame', 'left-url', loc);
    } catch(e) {}
  }
  function goBack(id) {
    if (!hist[id].length) return;
    var inputId = id === 'left-frame' ? 'left-url' : 'right-url';
    var f = document.getElementById(id);
    try { var cur = f.contentWindow.location.href; if (cur && cur !== 'about:blank') fwd[id].push(cur); } catch(e) {}
    var prev = hist[id].pop();
    f.src = prev;
    document.getElementById(inputId).value = prev;
  }
  function goFwd(id) {
    if (!fwd[id].length) return;
    var inputId = id === 'left-frame' ? 'left-url' : 'right-url';
    var f = document.getElementById(id);
    try { var cur = f.contentWindow.location.href; if (cur && cur !== 'about:blank') hist[id].push(cur); } catch(e) {}
    var next = fwd[id].pop();
    f.src = next;
    document.getElementById(inputId).value = next;
  }
  function trackFrame(id, inputId) {
    var frame = document.getElementById(id);
    frame.addEventListener('load', function() {
      try {
        var loc = frame.contentWindow.location.href;
        if (loc && loc !== 'about:blank') {
          document.getElementById(inputId).value = loc;
        }
      } catch(e) {}
    });
  }
  trackFrame('left-frame', 'left-url');
  trackFrame('right-frame', 'right-url');
  '''
::
++  render-tang
  |=  =tang
  ^-  tape
  %-  zing
  %+  turn  (flop tang)
  |=(=tank (weld ~(ram re tank) "\0a"))
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
  |=  [name=@ta sub=ball:tarball url-prefix=tape nexus-bang=(unit tang)]
  ^-  manx
  =/  dir-url=tape  "{url-prefix}/{(trip name)}"
  ;tr(data-name (trip name), data-type "dir")
    ;td
      ;a/"{dir-url}": {(trip name)}/
      ;*  ?~  nexus-bang  ~
          =/  rendered=tape  (render-tang u.nexus-bang)
          :~  ;span.boom-icon(data-tang rendered, onclick "showBoom(this)"): !
          ==
    ==
    ;td: -
    ;td: -
    ;td: -
    ;td: -
    ;td
      ;a/"{dir-url}?download=tar"
        ;button(type "button"): Download
      ==
      ;button(type "button", onclick "renameItem('folder','{(trip name)}')"): Rename
      ;button(type "button", onclick "moveItem('folder','{(trip name)}')"): Move
      ;button(type "button", onclick "copyItem('folder','{(trip name)}')"): Copy
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
          conversions=(map bars:tarball tube:clay)
          code-namespace=(unit path)
          file-bang=(unit tang)
      ==
  ^-  manx
  =/  mtime-display=tape
    =/  node=(unit [=tote:nexus bags=(map @ta sack:nexus)])
      (~(get of dir-born) ~)
    ?~  node  "-"
    =/  sk=(unit sack:nexus)  (~(get by bags.u.node) name)
    ?~  sk  "-"
    (en:datetime-local:iso-8601 da.file.u.sk)
  =/  sag=sage:tarball  sage.content
  ?:  =(%symlink name.p.sag)
    =/  sym  !<(symlink:tarball q.sag)
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
  =/  display-name=tape  (trip name)
  =/  file-url=tape  "{url-prefix}/{display-name}"
  =/  mark-name=tape  (spud (rail-to-path:tarball p.sag))
  =/  ext=(unit @ta)  (parse-extension:tarball name)
  =/  rail-ext=@ta
    %-  crip  %-  zing
    %+  join  "_"
    (turn (rail-to-path:tarball p.sag) trip)
  =/  mark-matches=?
    ?~  ext  %.n
    =(u.ext rail-ext)
  =/  mark-class=tape  ?:(mark-matches "" " mark-mismatch")
  =/  =mime
    ?:  =(%mime name.p.sag)
      !<(mime q.sag)
    (~(sage-to-mime gen:tarball [now conversions]) sag)
  =/  mime-raw=tape  (trip (spat p.mime))
  =/  mime-display=tape  ?~(mime-raw "" (tail mime-raw))
  =/  is-binary=?  =(p.mime /application/x-urb-jam)
  =/  view-url=tape  ?:(is-binary "{file-url}?pretty" file-url)
  ;tr(data-name (trip name), data-type "grub", data-size (scow %ud p.q.mime))
    ;td
      ;a/"{view-url}": {display-name}
      ;*  ?~  file-bang  ~
          =/  rendered=tape  (render-tang u.file-bang)
          :~  ;span.boom-icon(data-tang rendered, onclick "showBoom(this)"): !
          ==
    ==
    ::  Blot link: governing /code namespace + /mar/ + blot rail
    ;td(class mark-class)
      ;*  =/  mark-url=(unit tape)
            ?~  code-namespace  ~
            =/  mar-path=path  (weld u.code-namespace (weld /mar (rail-to-path:tarball p.sag)))
            `"/grubbery/ball{(trip (spat mar-path))}.hoon"
          ?~  mark-url
            :~  ;span: {mark-name}
            ==
          :~  ;a/"{u.mark-url}": {mark-name}
          ==
    ==
    ;td: {mime-display}
    ;td: {(format-size p.q.mime)}
    ;td: {mtime-display}
    ;td
      ;button(type "button", onclick "renameItem('grub','{display-name}')"): Rename
      ;button(type "button", onclick "moveItem('grub','{display-name}')"): Move
      ;button(type "button", onclick "copyItem('grub','{display-name}')"): Copy
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
