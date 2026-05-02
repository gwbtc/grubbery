::  github nexus: clone a public repo into the namespace
::
::  Config: /config.json with fields:
::    repo:   owner/repo (e.g. "urbit/urbit")
::    ref:    branch, tag, or commit sha (e.g. "main")
::
::  The sync process fetches a tarball from GitHub, decompresses it,
::  and writes each file into /tree/ as raw mime.
::
::  Poke sync.sig to trigger a re-fetch.
::
/<  zlib  /lib/zlib.hoon
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  [=sand:nexus =gain:nexus =ball:tarball]
      ^-  [sand:nexus gain:nexus ball:tarball]
      =/  =ver:loader  (get-ver:loader ball)
      =/  default-config=json
        %-  pairs:enjs:format
        :~  ['repo' s+'']
            ['ref' s+'main']
        ==
      ?+  ver  !!
          ?(~ [~ %0])
        %+  spin:loader  [sand gain ball]
        :~  (ver-row:loader 0)
            [%fall %& [/ %'config.json'] %.n [~ [/ %json] !>(default-config)]]
            [%fall %& [/ %'sync.sig'] %.n [~ [/ %sig] !>(~)]]
            [%over %& [/ %'page.html'] %.n [~ [/ %manx] !>((github-page '' '' 'main' ~))]]
            [%fall %| /tree [~ ~] [~ ~] empty-dir:loader]
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
          ::  /page.html: watches config + tree, re-renders
          ::
          [~ %'page.html']
        ;<  ~  bind:m  (rise-wait:io prod "%github /page: failed")
        ;<  here=rail:tarball  bind:m  get-here:io
        =/  api=@t
          (crip "/grubbery/api/file{(spud path.here)}")
        ;<  init-cfg=view:nexus  bind:m
          (keep:io /cfg (cord-to-road:tarball './config.json') `%json)
        ;<  init-tree=view:nexus  bind:m
          (keep:io /tree (cord-to-road:tarball './tree/') ~)
        =/  cfg=github-config  (view-to-config init-cfg)
        =/  files=(list @t)  (view-to-files init-tree)
        ;<  ~  bind:m  (replace:io !>((github-page api repo.cfg ref.cfg files)))
        |-
        ;<  evt=page-event  bind:m  take-page-event
        ?-    -.evt
            %fell  $
            %news
          =?  cfg  =(/cfg wire.evt)  (view-to-config view.evt)
          =?  files  =(/tree wire.evt)  (view-to-files view.evt)
          ;<  ~  bind:m  (replace:io !>((github-page api repo.cfg ref.cfg files)))
          $
        ==
          ::
          [~ %'sync.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%github sync: failed")
        ~&  >>  "%github: sync fiber started, waiting for poke"
        ::  on load/reload, just wait for a poke before syncing
        ;<  *  bind:m  take-poke:io
        ~&  >>  "%github: poke received, starting sync"
        |-
        ;<  cfg=github-config  bind:m  read-config
        ~&  >>  ["%github: config loaded" repo.cfg ref.cfg]
        ?:  =('' repo.cfg)
          ~&  >>>  "%github: no repo configured"
          ;<  *  bind:m  take-poke:io
          $
        ~&  >>  ["%github: syncing" repo.cfg ref.cfg]
        ::  fetch tarball from github API
        ~&  >>  "%github: fetching tarball..."
        ;<  tar-gz=octs  bind:m  (fetch-tarball repo.cfg ref.cfg)
        ~&  >>  ["%github: downloaded" p.tar-gz "bytes"]
        ::  decompress gzip
        ~&  >>  "%github: decompressing..."
        =/  tar=octs  (decompress-octs-gzip:zlib tar-gz)
        ~&  >>  ["%github: decompressed to" p.tar "bytes"]
        ::  parse tar archive
        ~&  >>  "%github: parsing tar..."
        =/  entries=tarball:tarball  (decode-tarball:tarball tar)
        ~&  >>  ["%github: found" (lent entries) "entries"]
        ::  clear existing tree
        ~&  >>  "%github: culling old tree..."
        ;<  ~  bind:m  (cull:io (cord-to-road:tarball './tree/'))
        ~&  >>  "%github: building ball from entries..."
        ::  build full ball from tar entries, write in one shot
        =/  tree=ball:tarball  (entries-to-ball entries)
        ~&  >>  "%github: writing ball to namespace..."
        ;<  ~  bind:m
          (make:io (cord-to-road:tarball './tree/') &+[*sand:nexus *gain:nexus tree])
        ~&  >>  "%github: sync complete"
        ;<  *  bind:m  take-poke:io
        ~&  >>  "%github: re-sync poke received"
        $
      ==
    ::
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'GitHub repo clone.'
            ~
          'Clone a public GitHub repo into the namespace. Config: repo, ref.'
        ==
          %|
        ?+  rail.p.mana  'File under github.'
          [~ %'config.json']  'GitHub config: repo (owner/repo), ref (branch/tag/sha).'
          [~ %'sync.sig']     'Poke to trigger sync.'
          [~ %'page.html']    'Dashboard page. Shows config, sync button, file tree.'
        ==
      ==
    --
::
|%
+$  github-config
  $:  repo=@t
      ref=@t
  ==
::
++  read-config
  =/  m  (fiber:fiber:nexus ,github-config)
  ^-  form:m
  =/  road=road:tarball  (cord-to-road:tarball './config.json')
  ;<  =seen:nexus  bind:m  (peek:io road `%json)
  ?.  ?=([%& %file *] seen)
    (pure:m ['' 'main'])
  =/  cfg=json  (fall (mole |.(!<(json q.sage.p.seen))) *json)
  ?.  ?=(%o -.cfg)
    (pure:m ['' 'main'])
  =/  get
    |=  [key=@t default=@t]
    ^-  @t
    =/  v  (~(get by p.cfg) key)
    ?.  ?=([~ %s *] v)  default
    ?:(=('' p.u.v) default p.u.v)
  (pure:m [(get 'repo' '') (get 'ref' 'main')])
::
::  fetch tarball, following one redirect
::
++  fetch-tarball
  |=  [repo=@t ref=@t]
  =/  m  (fiber:fiber:nexus ,octs)
  ^-  form:m
  =/  url=@t
    (rap 3 ~['https://api.github.com/repos/' repo '/tarball/' ref])
  =/  =request:http
    :^  %'GET'  url
      :~  ['Accept' 'application/vnd.github+json']
          ['User-Agent' 'grubbery']
      ==
    ~
  ;<  ~  bind:m  (send-request:io request)
  ;<  =client-response:iris  bind:m  take-client-response:io
  ?.  ?=(%finished -.client-response)
    ~|  "%github: fetch failed (not finished)"  !!
  =/  status  status-code.response-header.client-response
  ~&  >  ["%github: initial status" status]
  ?:  ?|  =(status 301)
          =(status 302)
          =(status 307)
      ==
    =/  location=(unit @t)
      %-  ~(get by (malt headers.response-header.client-response))
      'location'
    ?~  location
      ~|  "%github: redirect without location header"  !!
    ~&  >  ["%github: following redirect to" u.location]
    =/  =request:http
      :^  %'GET'  u.location
        ~[['User-Agent' 'grubbery']]
      ~
    ;<  ~  bind:m  (send-request:io request)
    ;<  =client-response:iris  bind:m  take-client-response:io
    ?.  ?=(%finished -.client-response)
      ~|  "%github: redirect fetch failed"  !!
    =/  redir-status  status-code.response-header.client-response
    ?.  =(200 redir-status)
      ~&  >>>  ["%github: redirect returned status" redir-status]
      ?~  full-file.client-response
        ~|  "%github: error (no body)"  !!
      ~&  >>>  ["%github: body" `@t`q.data.u.full-file.client-response]
      ~|  "%github: non-200 after redirect"  !!
    ?~  full-file.client-response
      ~|  "%github: empty response after redirect"  !!
    (pure:m data.u.full-file.client-response)
  ::  direct response (200)
  ?.  =(200 status)
    ~|  "%github: unexpected status {<status>}"  !!
  ?~  full-file.client-response
    ~|  "%github: empty response"  !!
  (pure:m data.u.full-file.client-response)
::
::  strip the top-level directory github adds to tarballs
::  (e.g. "owner-repo-abc1234/src/foo.hoon" -> "src/foo.hoon")
::
++  strip-prefix
  |=  name=@t
  ^-  @t
  =/  =tape  (trip name)
  ::  find first '/'
  =/  idx=@ud  0
  |-
  ?~  tape  name
  ?:  =(i.tape '/')
    ?~  t.tape  ''
    (crip t.tape)
  $(tape t.tape, idx +(idx))
::
::  build a ball tree from tar entries (pure data, no darts)
::
++  entries-to-ball
  |=  entries=tarball:tarball
  ^-  ball:tarball
  =|  tree=ball:tarball
  |-
  ?~  entries  tree
  =/  header  header.i.entries
  =/  name=@t  (strip-prefix name.header)
  ::  skip empty names and the root directory itself
  ?:  |(=('' name) =(0 (met 3 name)))
    $(entries t.entries)
  ::  skip directories (typeflag '5') and non-regular files
  =/  tf=@t  typeflag.header
  ?:  ?|  =(tf '5')
          =(tf 'g')
          =(tf 'x')
      ==
    $(entries t.entries)
  ::  skip entries with no data
  ?~  data.i.entries
    $(entries t.entries)
  =/  content-type=path  (guess-mime name)
  =/  =mime  [content-type u.data.i.entries]
  =/  =content:tarball  [*metadata:tarball [/ %mime] !>(mime)]
  =/  segs=(list @t)  (segments name)
  =.  tree  (insert-file tree segs content)
  $(entries t.entries)
::
++  segments
  |=  name=@t
  ^-  (list @ta)
  =/  =tape  (trip name)
  =|  acc=(list @ta)
  =|  seg=^tape
  |-
  ?~  tape
    ?~  seg  (flop acc)
    (flop [(crip (flop seg)) acc])
  ?:  =(i.tape '/')
    ?~  seg  $(tape t.tape)
    $(tape t.tape, acc [(crip (flop seg)) acc], seg ~)
  $(tape t.tape, seg [i.tape seg])
::
++  insert-file
  |=  [tree=ball:tarball segs=(list @ta) =content:tarball]
  ^-  ball:tarball
  ?~  segs  tree
  ?~  t.segs
    ::  leaf: insert file into lump at this level
    =/  =lump:tarball
      (fall fil.tree [*metadata:tarball ~ ~])
    =.  contents.lump  (~(put by contents.lump) i.segs content)
    tree(fil `lump)
  ::  branch: recurse into subdirectory
  =/  kid=ball:tarball
    (fall (~(get by dir.tree) i.segs) [~ ~])
  =.  kid  $(tree kid, segs t.segs)
  tree(dir (~(put by dir.tree) i.segs kid))
::
+$  page-event
  $%  [%news =wire =view:nexus]
      [%fell =wire]
  ==
::
++  take-page-event
  =/  m  (fiber:fiber:nexus ,page-event)
  ^-  form:m
  |=  =input:fiber:nexus
  :+  ~  state.input
  ?+  in.input  [%skip ~]
      ~  [%wait ~]
      [~ %news * *]
    [%done %news [wire view]:u.in.input]
      [~ %fell *]
    [%done %fell wire.u.in.input]
  ==
::
++  view-to-config
  |=  =view:nexus
  ^-  github-config
  ?.  ?=([%file *] view)  ['' 'main']
  =/  cfg=json  (fall (mole |.(!<(json q.sage.view))) *json)
  ?.  ?=(%o -.cfg)  ['' 'main']
  =/  get
    |=  [key=@t default=@t]
    ^-  @t
    =/  v  (~(get by p.cfg) key)
    ?.  ?=([~ %s *] v)  default
    ?:(=('' p.u.v) default p.u.v)
  [(get 'repo' '') (get 'ref' 'main')]
::
++  view-to-files
  |=  =view:nexus
  ^-  (list @t)
  ?.  ?=([%ball *] view)  ~
  (collect-files '' ball.view)
::
++  collect-files
  |=  [prefix=@t =ball:tarball]
  ^-  (list @t)
  =/  file-names=(list @t)
    ?~  fil.ball  ~
    %+  turn  ~(tap by contents.u.fil.ball)
    |=  [name=@ta *]
    ?:(=('' prefix) name (crip "{(trip prefix)}/{(trip name)}"))
  =/  dir-files=(list @t)
    %-  zing
    %+  turn  ~(tap by dir.ball)
    |=  [name=@ta sub=ball:tarball]
    =/  sub-prefix=@t
      ?:(=('' prefix) name (crip "{(trip prefix)}/{(trip name)}"))
    (collect-files sub-prefix sub)
  (weld file-names dir-files)
::
++  guess-mime
  |=  filename=@t
  ^-  path
  =/  ext=@t
    =/  =tape  (trip filename)
    =/  idx=(unit @ud)  (find "." (flop tape))
    ?~  idx  ''
    (crip (slag (sub (lent tape) u.idx) tape))
  ?+  ext  /application/octet-stream
    %hoon  /text/plain
    %txt   /text/plain
    %md    /text/plain
    %json  /application/json
    %html  /text/html
    %css   /text/css
    %js    /application/javascript
    %ts    /text/plain
    %py    /text/plain
    %rs    /text/plain
    %c     /text/plain
    %h     /text/plain
    %go    /text/plain
    %toml  /text/plain
    %yaml  /text/plain
    %yml   /text/plain
    %xml   /text/xml
    %svg   /image/'svg+xml'
    %sh    /text/plain
    %nix   /text/plain
  ==
::
++  github-page
  |=  [api=@t repo=@t ref=@t files=(list @t)]
  ^-  manx
  ;html
    ;head
      ;title: GitHub Clone
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;style
        ;+  ;/  "body \{ font-family: monospace; max-width: 700px; margin: 0 auto; padding: 2rem; } .muted \{ opacity: 0.5; } .mb1 \{ margin-bottom: 0.5rem; } .mb2 \{ margin-bottom: 1rem; } .p2 \{ padding: 0.5rem; } .b1 \{ border: 1px solid #ccc; } .br1 \{ border-radius: 4px; } .hover:hover \{ background: #eee; } .pointer \{ cursor: pointer; } .s9 \{ font-size: 0.8rem; } .file \{ padding: 0.2rem 0; } .w100 \{ width: 100%; box-sizing: border-box; }"
      ==
    ==
    ;body
      ;h1: GitHub Clone
      ;div.mb2
        ;label: Repository (owner/repo)
        ;input#repo.w100.p2.b1.br1.mb1(type "text", value "{(trip repo)}", placeholder "urbit/urbit");
      ==
      ;div.mb2
        ;label: Ref (branch / tag / sha)
        ;input#ref.w100.p2.b1.br1.mb1(type "text", value "{(trip ref)}", placeholder "main");
      ==
      ;div.mb2
        ;button#save.p2.b1.br1.hover.pointer.mb1: Save Config
        ;+  ;/  " "
        ;button#sync.p2.b1.br1.hover.pointer.mb1: Sync Now
      ==
      ;h2: Files ({(scow %ud (lent files))})
      ;div#files
        ;*  ?~  files
              =/  empty=manx  ;span.muted: No files synced.
              ~[empty]
            %+  turn  files
            |=  name=@t
            ;div.file.s9: {(trip name)}
      ==
      ;script
        ;+  ;/
          ;:  weld
            "var S='{(trip api)}';"
            "document.getElementById('save').onclick=function()\{var r=document.getElementById('repo').value;var f=document.getElementById('ref').value;var j=JSON.stringify(\{repo:r,ref:f});var u=S.replace('/file/','/over/')+'/config.json?mark=json';fetch(u,\{method:'POST',headers:\{'Content-Type':'application/json'},body:j})};"
            "document.getElementById('sync').onclick=function()\{var u=S.replace('/file/','/poke/')+'/sync.sig';fetch(u,\{method:'POST',headers:\{'Content-Type':'text/plain'},body:'sync'})};"
          ==
      ==
    ==
  ==
--
