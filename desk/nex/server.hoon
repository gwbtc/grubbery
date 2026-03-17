::  server nexus: HTTP bindings manager
::
::  Central HTTP gateway between eyre and the rest of the tree.
::  Other nexuses poke to register/unregister URL path bindings,
::  receive forwarded requests, and poke back with responses.
::  Server authorizes every response to ensure it came from the
::  process that owns the binding.
::
::  /server.server/
::    /main.server-state    binding registry + request router + response proxy
::
::  State (server-state in nex-server):
::    bindings:     (map binding:eyre rail) — URL prefix → handler location
::    connections:  (map @ta binding:eyre) — eyre-id → owning binding
::
::  Request flow:
::    1. Eyre sends %handle-http-request to grubbery
::    2. Grubbery forwards to /server.server/main.server-state
::    3. Server finds longest-prefix binding match
::    4. Records connection (eyre-id → binding), forwards to handler rail
::    5. Handler pokes back %server-action [%send eyre-id update]
::    6. Server verifies sender matches handler rail, sends to eyre
::    7. On %kick or %simple, connection is cleaned up
::
::  Cancel flow:
::    1. Eyre on-leave sends %handle-http-cancel
::    2. Server removes connection, forwards cancel to handler rail
::
::
/+  nexus, tarball, io=fiberio, server, http-utils, html-utils, nex-server, multipart, loader
!: :: turn on stack trace
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  [=sand:nexus =gain:nexus =ball:tarball]
      ^-  [sand:nexus gain:nexus ball:tarball]
      =/  =ver:loader  (get-ver:loader ball)
      ?+  ver  !!
          ?(~ [~ %0])  :: no version or version 0
        %+  spin:loader  [sand gain ball]
        :~  (ver-row:loader 0)
            [%fall %& [/ %'main.server-state'] %.n [~ %server-state !>(`server-state:nex-server`[%0 ~ ~])]]
            [%fall %| /requests [~ ~] [~ ~] [`[~ ~ ~] ~]]
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
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%server /requests: failed")
        =/  eyre-id=@ta  name.rail
        ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
        =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
        (handle-ball-api eyre-id src req site args)
      ::
          [~ %'main.server-state']
      ;<  ~  bind:m  (rise-wait:io prod "%server /main: failed, poke to restart")
      ~&  >  "%server /main: binding /grubbery/api"
      ;<  =dude:gall  bind:m  get-agent:io
      ;<  ~  bind:m
        %-  send-cards:io
        [%pass /eyre-api %arvo %e %connect [~ /grubbery/api] dude]~
      ~&  >  "%server /main: ready"
      |-
      ;<  [=from:fiber:nexus =cage]  bind:m  take-poke-from:io
      ;<  st=server-state:nex-server  bind:m  (get-state-as:io server-state:nex-server)
      ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
      ?+    p.cage  $
          ::  Server action: bind, unbind, reset, send
          ::
          %server-action
        =+  !<(act=server-action:nex-server q.cage)
        ?-    -.act
            %bind
          ?.  ?=(%& -.from)  $
          ::  Resolve the target to an absolute rail.
          ::  If target is ~, the sender itself is the handler.
          ::  Otherwise, resolve the target bend relative to the sender.
          ::
          =/  sender-rail=rail:tarball
            (resolve-rail:nex-server here.bowl p.from)
          =/  handler-rail=rail:tarball
            ?~  target.act  sender-rail
            (resolve-rail:nex-server sender-rail u.target.act)
          ~&  >  [%server-bind binding.act handler-rail]
          =.  bindings.st  (~(put by bindings.st) binding.act handler-rail)
          ;<  ~  bind:m  (replace:io !>(st))
          ::  Register with eyre
          ;<  =dude:gall  bind:m  get-agent:io
          ;<  ~  bind:m
            %-  send-cards:io
            [%pass /eyre-bind %arvo %e %connect binding.act dude]~
          $
          ::
            %unbind
          ~&  >  [%server-unbind binding.act]
          ::  Kick orphaned connections for this binding
          =/  orphans=(list @ta)
            %+  murn  ~(tap by connections.st)
            |=  [eid=@ta =binding:eyre]
            ?.  =(binding binding.act)  ~
            `eid
          ;<  ~  bind:m
            %-  send-cards:io
            %+  turn  orphans
            |=  eid=@ta
            [%give %kick ~[/http-response/[eid]] ~]
          =.  connections.st
            %-  ~(gas by *(map @ta binding:eyre))
            %+  skip  ~(tap by connections.st)
            |=  [eid=@ta =binding:eyre]
            =(binding binding.act)
          =.  bindings.st  (~(del by bindings.st) binding.act)
          ;<  ~  bind:m  (replace:io !>(st))
          $
          ::
            %reset
          ~&  >  "%server: resetting all connections"
          =/  conns=(list [@ta binding:eyre])  ~(tap by connections.st)
          ;<  ~  bind:m
            %-  send-cards:io
            %+  turn  conns
            |=  [eid=@ta =binding:eyre]
            [%give %kick ~[/http-response/[eid]] ~]
          ;<  ~  bind:m
            |-
            ?~  conns  (pure:m ~)
            =/  [eid=@ta =binding:eyre]  i.conns
            =/  handler=rail:tarball
              (fall (~(get by bindings.st) binding) *rail:tarball)
            =/  =road:tarball  [%& %& handler]
            ;<  ~  bind:m  (poke:io /cancel road handle-http-cancel+!>(eid))
            $(conns t.conns)
          =.  connections.st  ~
          ;<  ~  bind:m  (replace:io !>(st))
          $
          ::
            %send
          ::  Authorize: sender must be the handler that owns this binding.
          ::  Resolve sender's from to an absolute rail and compare to the
          ::  stored handler rail.
          ::
          =/  conn-binding=(unit binding:eyre)  (~(get by connections.st) eyre-id.act)
          ?~  conn-binding
            ~&  >  [%server-unknown-connection eyre-id.act]
            ::  Forward cancel to sender so it can clean up
            ?.  ?=(%& -.from)  $
            =/  sender-rail=rail:tarball
              (resolve-rail:nex-server here.bowl p.from)
            =/  =road:tarball  [%& %& sender-rail]
            ;<  ~  bind:m  (poke:io /cancel road handle-http-cancel+!>(eyre-id.act))
            $
          =/  expected-rail=(unit rail:tarball)  (~(get by bindings.st) u.conn-binding)
          ?~  expected-rail
            ~&  >  [%server-binding-gone u.conn-binding]
            $
          ?.  ?=(%& -.from)
            ~&  >  [%server-external-from eyre-id.act]
            $
          =/  sender-rail=rail:tarball
            (resolve-rail:nex-server here.bowl p.from)
          ?.  =(sender-rail u.expected-rail)
            ~&  >  [%server-unauthorized eyre-id.act sender-rail u.expected-rail]
            $
          =/  cards=(list card:agent:gall)  (eyre-update-cards eyre-id.act eyre-update.act)
          ?:  ?=(?(%kick %simple) -.eyre-update.act)
            =.  connections.st  (~(del by connections.st) eyre-id.act)
            ;<  ~  bind:m  (replace:io !>(st))
            ;<  ~  bind:m  (send-cards:io cards)
            $
          ;<  ~  bind:m  (send-cards:io cards)
          $
        ==
          ::  Incoming HTTP request from eyre
          ::
          %handle-http-request
        =/  [eyre-id=@ta src=@p req=inbound-request:eyre]
          !<([eyre-id=@ta @p inbound-request:eyre] q.cage)
        ~&  >  [%server-request eyre-id url.request.req]
        =/  site=path  site:(parse-url:http-utils url.request.req)
        ::  Ball API: dispatch to /requests/{eyre-id} fiber
        ::
        ?:  ?=([%grubbery %api *] site)
          ;<  ~  bind:m
            (make:io /api [%| 0 %& /requests eyre-id] |+[%.n http-request+!>([src req]) ~])
          $
        =/  match=(unit [=binding:eyre handler=rail:tarball])
          (find-binding bindings.st site)
        ?~  match
          ~&  >  [%server-no-binding site]
          ;<  ~  bind:m
            %-  send-cards:io
            (give-simple-payload:app:server eyre-id [[404 ~] `(as-octs:mimes:html 'Not Found')])
          $
        ~&  >  [%server-found-binding binding.u.match handler.u.match]
        =.  connections.st  (~(put by connections.st) eyre-id binding.u.match)
        ;<  ~  bind:m  (replace:io !>(st))
        ::  Forward request to handler via absolute road
        =/  =road:tarball  [%& %& handler.u.match]
        ;<  ~  bind:m  (poke:io /forward road handle-http-request+!>([eyre-id src req]))
        $
          ::  Client disconnected (eyre on-leave)
          ::
          %handle-http-cancel
        =/  eyre-id=@ta  !<(@ta q.cage)
        ~&  >  [%server-cancel eyre-id]
        =/  conn-binding=(unit binding:eyre)  (~(get by connections.st) eyre-id)
        =.  connections.st  (~(del by connections.st) eyre-id)
        ;<  ~  bind:m  (replace:io !>(st))
        ::  Forward cancel to handler
        ::  Ball API requests don't use the binding system — cull the
        ::  request fiber directly so SSE loops terminate on disconnect.
        ?~  conn-binding
          ;<  ~  bind:m  (cull:io /cancel [%| 0 %& /requests eyre-id])
          $
        =/  handler=rail:tarball
          (fall (~(get by bindings.st) u.conn-binding) *rail:tarball)
        =/  =road:tarball  [%& %& handler]
        ;<  ~  bind:m  (poke:io /cancel road handle-http-cancel+!>(eyre-id))
        $
      ==
      ==
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'Subdirectory under the server nexus.'
            ~
          %-  crip
          """
          HTTP SERVER NEXUS — eyre request gateway

          Routes inbound HTTP requests to handler processes via URL prefix
          bindings. Other nexuses register their URL prefixes here (e.g.
          claude registers /grubbery/claude/, explorer registers /grubbery/).

          FILES:
            main.server-state   Active bindings and connection state.
            ver.ud              Schema version.

          DIRECTORIES:
            requests/           Per-request fibers. Each inbound HTTP request
                                spawns a short-lived fiber here. Cleaned up
                                on response or client disconnect.

          PROCESS:
            main.server-state listens for eyre %request events, matches the
            URL against registered bindings, and forwards the request to
            the bound handler nexus. It also manages eyre %connect/%disconnect
            lifecycle and tracks open connections for cleanup.
          """
            [%requests ~]
          'Active HTTP request fibers. Each inbound request spawns a fiber here; cleaned up on completion or client disconnect.'
        ==
          %|
        ?+  rail.p.mana  'File under the server nexus.'
            [~ %'main.server-state']
          %-  crip
          """
          main.server-state — Server process + binding registry. Mark: server-state.

          TYPE: [%0 bindings=(map path rail:tarball) connections=(map @ud duct)]
            bindings:    URL prefix -> handler rail. Set by child nexuses on load.
            connections: Open eyre connection IDs. Tracked for cleanup.

          This is the only process. It multiplexes all HTTP events:
          inbound requests, response completions, and connection lifecycle.
          """
            [~ %'ver.ud']
          'Schema version counter. Mark: ud.'
        ==
      ==
    --
|%
::  +handle-ball-api: route /grubbery/api requests by HTTP method
::
++  handle-ball-api
  |=  [eyre-id=@ta src=@p req=inbound-request:eyre site=path args=quay:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  our=@p  bind:m  get-our:io
  ?.  =(src our)
    (send-error eyre-id 403 'Forbidden')
  ?>  ?=([%grubbery %api *] site)
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
  ::  POST /diff/... — same-mark diff, notify process
      [%'POST' %diff]   (serve-post eyre-id api-path args body.request.req %diff)
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
  |=  [eyre-id=@ta =cage mark-param=(unit @t)]
  =/  m  (fiber:fiber:nexus ,(unit ^cage))
  ^-  form:m
  ?~  mark-param  (pure:m `cage)
  =/  target-mark=@tas  u.mark-param
  ?:  =(p.cage target-mark)  (pure:m `cage)
  ;<  tube=(unit tube:clay)  bind:m  (get-tube:io [p.cage target-mark])
  ?~  tube
    ;<  ~  bind:m  (send-error eyre-id 400 'No tube for mark conversion')
    (pure:m ~)
  =/  result=(each vase tang)  (mule |.((u.tube q.cage)))
  ?:  ?=(%| -.result)
    ;<  ~  bind:m  (send-error eyre-id 500 'Mark conversion failed')
    (pure:m ~)
  (pure:m `[target-mark p.result])
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
  ;<  root-seen=seen:nexus  bind:m  (peek:io /peek [%& %| ~] ~)
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
  =/  =cage  cage.u.content-data
  =/  mark-param=(unit @t)  (get-key:kv:html-utils 'mark' args)
  ;<  converted=(unit ^cage)  bind:m  (maybe-convert eyre-id cage mark-param)
  ?~  converted  (pure:m ~)
  ;<  =mime  bind:m  (cage-to-mime:io u.converted)
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
  ;<  root-seen=seen:nexus  bind:m  (peek:io /peek [%& %| ~] ~)
  ?.  ?=([%& %ball *] root-seen)
    (send-error eyre-id 500 'Peek failed')
  =/  root=ball:tarball  ball.p.root-seen
  =/  sub=(unit ball:tarball)  (~(dap ba:tarball root) api-path)
  ?~  sub
    (send-error eyre-id 404 'Not found')
  =/  sub-born=born:nexus  (~(dip of born.p.root-seen) api-path)
  =/  stamped=ball:tarball  (stamp-mtimes:nexus sub-born u.sub)
  ;<  now=@da  bind:m  get-time:io
  ;<  conversions=(map mars:clay tube:clay)  bind:m
    (get-mark-conversions:io stamped)
  =/  tar=tarball:tarball
    (~(make-tarball gen:tarball [now conversions]) api-path stamped)
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
  ;<  exists=?  bind:m  (peek-exists:io /check road)
  ?:  exists
    (send-error eyre-id 409 'Already exists')
  =/  mark-param=(unit @t)  (get-key:kv:html-utils 'mark' args)
  =/  gain=?  =('true' (fall (get-key:kv:html-utils 'gain' args) ''))
  =/  mime-cage=cage  [%mime !>(`mime`[/application/octet-stream u.body])]
  ;<  converted=(unit cage)  bind:m  (maybe-convert eyre-id mime-cage mark-param)
  ?~  converted  (pure:m ~)
  ;<  ~  bind:m  (make:io /make road [%| gain u.converted ~])
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
  ;<  exists=?  bind:m  (peek-exists:io /check road)
  ?:  exists
    (send-error eyre-id 409 'Already exists')
  =/  init-ball=ball:tarball  [`[~ ~ ~] ~]
  ;<  ~  bind:m  (make:io /make road &+[[~ ~] [~ ~] init-ball])
  (send-created eyre-id)
::  +serve-post: POST /poke, /over, /diff — send dart to file
::
++  serve-post
  |=  [eyre-id=@ta api-path=path args=(list [key=@t value=@t]) body=(unit octs) op=?(%poke %over %diff)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  api-path
    (send-error eyre-id 400 'File path required')
  ?~  body
    (send-error eyre-id 400 'Missing body')
  =/  =road:tarball  [%& %& (snip `path`api-path) (rear api-path)]
  ;<  exists=?  bind:m  (peek-exists:io /check road)
  ?.  exists
    (send-error eyre-id 404 'Not found')
  =/  mark-param=(unit @t)  (get-key:kv:html-utils 'mark' args)
  =/  mime-cage=cage  [%mime !>(`mime`[/application/octet-stream u.body])]
  ;<  converted=(unit cage)  bind:m  (maybe-convert eyre-id mime-cage mark-param)
  ?~  converted  (pure:m ~)
  ;<  ~  bind:m
    ?-  op
      %poke  (poke:io /post road u.converted)
      %over  (over:io /post road u.converted)
      %diff  (diff:io /post road u.converted)
    ==
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
  ;<  exists=?  bind:m  (peek-exists:io /check road)
  ?.  exists
    (send-error eyre-id 404 'Not found')
  ;<  ~  bind:m  (cull:io /cull road)
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
  ;<  exists=?  bind:m  (peek-exists:io /check road)
  ?.  exists
    (send-error eyre-id 404 'Not found')
  ;<  ~  bind:m  (cull:io /cull road)
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
  ;<  exists=?  bind:m  (peek-exists:io /chk dir-road)
  ?.  exists
    ;<  ~  bind:m
      (make:io /upload dir-road &+[[~ ~] [~ ~] `[~ ~ ~] ~])
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
  ::  Build mime→mark tubes for uploaded file extensions
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
      (get-tube:io mars)
    =?  convs  ?=(^ tube)
      (~(put by convs) mars u.tube)
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
  =/  mime-cage=cage  [%mime !>(file-mime)]
  =/  ext=(unit @ta)  (parse-extension:tarball file-name)
  =/  final-cage=cage
    ?~  ext  mime-cage
    =/  =mars:clay  [%mime u.ext]
    =/  tube=(unit tube:clay)  (~(get by conversions) mars)
    ?~  tube  mime-cage
    =/  result=(each vase tang)  (mule |.((u.tube q.mime-cage)))
    ?:  ?=(%| -.result)  mime-cage
    [u.ext p.result]
  ::  Ensure parent dirs exist
  ;<  ~  bind:m  (ensure-parents tree-path file-parent)
  ::  Create or overwrite file — keep full filename
  =/  =road:tarball  [%& %& full-path file-name]
  ;<  exists=?  bind:m  (peek-exists:io /chk road)
  ?:  exists
    ;<  ~  bind:m  (over:io /upload road final-cage)
    $(remaining t.remaining, created [filename-raw created])
  ;<  ~  bind:m  (make:io /upload road |+[%.n final-cage ~])
  $(remaining t.remaining, created [filename-raw created])
::  +serve-sand-peek: GET /sand — directory permissions as JSON
::
++  serve-sand-peek
  |=  [eyre-id=@ta api-path=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  dir-seen=seen:nexus  bind:m  (peek:io /sand [%& %| api-path] ~)
  ?.  ?=([%& %ball *] dir-seen)
    (send-error eyre-id 404 'Not found')
  (send-json eyre-id (sand-to-json:nexus sand.p.dir-seen))
::  +serve-weir-peek: GET /weir — single directory weir as JSON
::
++  serve-weir-peek
  |=  [eyre-id=@ta api-path=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  dir-seen=seen:nexus  bind:m  (peek:io /weir [%& %| api-path] ~)
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
  ;<  ~  bind:m  (sand:io /weir [%& %| api-path] `p.parsed)
  (send-ok eyre-id 'OK')
::  +serve-weir-del: DELETE /weir — clear weir
::
++  serve-weir-del
  |=  [eyre-id=@ta api-path=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  ~  bind:m  (sand:io /weir [%& %| api-path] ~)
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
    (peek-exists:io /manu-chk u.file-road)
  =/  =road:tarball
    ?:  is-file  (need file-road)
    [%& %| api-path]
  ;<  text=@t  bind:m  (manu:io /manu |+road)
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
    (peek-exists:io /check u.file-road)
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
      ;<  body=@t  bind:m  (cage-to-txt cage.init mark-param)
      =/  data=wain  (to-wain:format body)
      =/  =sse-event:http-utils  [`id `event-name data]
      (send-cards:io [(give-sse-event:http-utils eyre-id sse-event) ~])
    ::  Directory — send "old" for each file
        [%ball *]
      =/  root=ball:tarball  ball.init
      (send-old-dir eyre-id root born.init / mark-param)
    ==
  ::  Start keep-alive timer
  ;<  =bowl:nexus  bind:m  (get-bowl:io /sse)
  ;<  ~  bind:m  (send-wait:io (add now.bowl ~s30))
  ::  Event loop
  |-
  ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /keep)
  ?-    -.nw
      %wake
    ;<  ~  bind:m
      (send-cards:io [(give-sse-keep-alive:http-utils eyre-id) ~])
    ;<  =bowl:nexus  bind:m  (get-bowl:io /sse)
    ;<  ~  bind:m  (send-wait:io (add now.bowl ~s30))
    $
  ::
      %news
    ?+    view.nw  $
    ::  Single file changed
        [%file *]
      =/  =cage  cage.view.nw
      =/  id=@t  (scot %ud ud.file.sack.view.nw)
      =/  file-name=@t
        ?~  api-path  '/'
        (rear api-path)
      =/  event-name=@t  (crip "upd {(trip file-name)}")
      ;<  body=@t  bind:m  (cage-to-txt cage mark-param)
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
      =/  =cage  cage.u.ct
      ;<  body=@t  bind:m  (cage-to-txt cage mark-param)
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
    ;<  body=@t  bind:m  (cage-to-txt cage.content mark-param)
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
::  +cage-to-txt: convert cage to text for SSE data
::
::    With mark param: cage → target mark → txt
::    Without: cage → txt directly
::    Falls back to mime body extraction if no txt tube exists.
::
++  cage-to-txt
  |=  [=cage mark-param=(unit @t)]
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  ::  Step 1: optionally convert to intermediate mark
  ?~  mark-param
    (cage-to-txt-raw cage)
  =/  target-mark=@tas  u.mark-param
  ?:  =(p.cage target-mark)
    (cage-to-txt-raw cage)
  ;<  tube=(unit tube:clay)  bind:m  (get-tube:io [p.cage target-mark])
  ?~  tube
    (cage-to-txt-raw cage)
  =/  result=(each vase tang)  (mule |.((u.tube q.cage)))
  ?:  ?=(%| -.result)
    (cage-to-txt-raw cage)
  (cage-to-txt-raw [target-mark p.result])
::  +cage-to-txt-raw: convert a single cage to @t
::
++  cage-to-txt-raw
  |=  =cage
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  ?:  =(%txt p.cage)
    (pure:m (of-wain:format !<(wain q.cage)))
  ;<  tube=(unit tube:clay)  bind:m  (get-tube:io [p.cage %txt])
  ?~  tube
    ::  Fallback: convert to mime and extract body as text
    ;<  =mime  bind:m  (cage-to-mime:io cage)
    (pure:m `@t`(end [3 p.q.mime] q.q.mime))
  =/  result=(each vase tang)  (mule |.((u.tube q.cage)))
  ?:  ?=(%| -.result)
    ;<  =mime  bind:m  (cage-to-mime:io cage)
    (pure:m `@t`(end [3 p.q.mime] q.q.mime))
  (pure:m (of-wain:format !<(wain p.result)))
::  +find-suffix: returns [~ /tail] if :full is (weld :prefix /tail)
::
++  find-suffix
  |=  [prefix=path full=path]
  ^-  (unit path)
  ?~  prefix  `full
  ?~  full    ~
  ?.  =(i.prefix i.full)  ~
  $(prefix t.prefix, full t.full)
::  +eyre-update-cards: build eyre response cards for an update
::
++  eyre-update-cards
  |=  [eyre-id=@ta upd=eyre-update:nex-server]
  ^-  (list card:agent:gall)
  ?-    -.upd
      %header
    :~  :^  %give  %fact  ~[/http-response/[eyre-id]]
        http-response-header+!>(response-header.upd)
    ==
      %data
    :~  [%give %fact ~[/http-response/[eyre-id]] http-response-data+!>(data.upd)]
    ==
      %kick
    :~  [%give %kick ~[/http-response/[eyre-id]] ~]
    ==
      %simple
    (give-simple-payload:app:server eyre-id simple-payload.upd)
  ==
::  +find-binding: longest-prefix match against registered bindings
::
++  find-binding
  |=  [bindings=(map binding:eyre rail:tarball) site=path]
  ^-  (unit [=binding:eyre handler=rail:tarball])
  =|  best=(unit [=binding:eyre handler=rail:tarball])
  =/  entries=(list [=binding:eyre handler=rail:tarball])
    ~(tap by bindings)
  |-
  ?~  entries  best
  ?~  (find-suffix path.binding.i.entries site)
    $(entries t.entries)
  ?~  best  $(best `i.entries, entries t.entries)
  ?:  (gth (lent path.binding.i.entries) (lent path.binding.u.best))
    $(best `i.entries, entries t.entries)
  $(entries t.entries)
--
