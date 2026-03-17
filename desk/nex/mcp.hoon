::  mcp nexus: MCP JSON-RPC endpoint for grubbery
::
::  Tree layout:
::    /main.sig         bind HTTP path, dispatch requests
::    /requests/{id}    parse HTTP, route protocol vs tools/call
::    /tools/{id}       tool execution grub (mark %tool-state)
::    /cus/**        custom tool sources (user-managed, inert)
::    /bin/**            compiled tools (mark %temp on success, %tang on failure)
::    /builder.sig       watches ball mirror + /cus/, compiles to /bin/
::
/+  nexus, tarball, io=fiberio, server, nex-server, nex-mcp
/+  json-utils, nex-tools, nex-clurd, build, loader
!: :: turn on stack trace
=>  |%
    ++  srv  ~(. res:nex-server [%| 1 %& ~ %'main.sig'])
    ::  Subject vase for compiling user tools.
    ::  Includes standard library + grubbery libs.
    ::
    ++  tool-subject
      ^-  vase
      !>  :*  nexus=nexus
              tarball=tarball
              io=io
              json-utils=json-utils
              tools=nex-tools
              clurd=nex-clurd
              ..zuse
          ==
    ::  Ensure /bin/ subdirectory exists
    ::
    ++  ensure-bin-dir
      |=  bin-path=path
      =/  m  (fiber:fiber:nexus ,~)
      ^-  form:m
      ;<  exists=?  bind:m  (peek-exists:io /chk [%| 0 %| bin-path])
      ?:  exists  (pure:m ~)
      (make:io /mkd [%| 0 %| bin-path] &+[*sand:nexus *gain:nexus empty-dir:loader])
    ::  Cull a grub if it exists
    ::
    ++  cull-if-exists
      |=  =road:tarball
      =/  m  (fiber:fiber:nexus ,~)
      ^-  form:m
      ;<  exists=?  bind:m  (peek-exists:io /chk road)
      ?:  exists  (cull:io /cull road)
      (pure:m ~)
    ::  Compile a tool source file and write result to /bin/.
    ::  Success → mark %temp (compiled vase).
    ::  Failure → mark %tang (error trace).
    ::
    ++  compile-lib
      |=  [file-path=path file-name=@ta source=cage]
      =/  m  (fiber:fiber:nexus ,~)
      ^-  form:m
      =/  bin-path=path  (weld /bin file-path)
      =/  bin-road=road:tarball  [%| 0 %& bin-path file-name]
      =/  bon=path  (weld file-path /[file-name]/hoon)
      =/  src=@t  (extract-src:build source)
      =/  res=(each vase tang)
        (build-hoon:build tool-subject bon src)
      ?:  ?=(%| -.res)
        ~&  >  [%mcp-builder-fail bon]
        (write-bin bin-path bin-road tang+!>(p.res))
      ::  Validate as $tool
      =/  check=(each tool:nex-tools tang)
        (mule |.(!<(tool:nex-tools p.res)))
      ?:  ?=(%| -.check)
        =/  =tang  [[%leaf "does not nest against $tool:nex-tools"] p.check]
        ~&  >  [%mcp-builder-type-fail bon]
        (write-bin bin-path bin-road tang+!>(tang))
      ~&  >  [%mcp-builder-ok bon]
      (write-bin bin-path bin-road temp+p.res)
    ::  Write a cage to /bin/, creating dir if needed, overwriting if exists.
    ::
    ++  write-bin
      |=  [bin-path=path bin-road=road:tarball =cage]
      =/  m  (fiber:fiber:nexus ,~)
      ^-  form:m
      ;<  exists=?  bind:m  (peek-exists:io /chk bin-road)
      ?:  exists
        ::  Cull and recreate: mark may change (temp↔tang)
        ;<  ~  bind:m  (cull:io /build bin-road)
        (make:io /build bin-road |+[%.n cage ~])
      ;<  ~  bind:m  (ensure-bin-dir bin-path)
      (make:io /build bin-road |+[%.n cage ~])
    ::  Peek /bin/ and extract all successfully compiled tools.
    ::  Walks the ball tree recursively, collecting vase-marked grubs.
    ::
    ++  get-dynamic-tools
      =/  m  (fiber:fiber:nexus ,(map @t tool:nex-tools))
      ^-  form:m
      ;<  bin-seen=seen:nexus  bind:m  (peek:io /bin [%| 1 %| /bin] ~)
      ?.  ?=([%& %ball *] bin-seen)
        (pure:m ~)
      ::  Collect cus/ first, then std/ — std wins on name conflicts
      =/  cus-ball=ball:tarball
        (~(gut by dir.ball.p.bin-seen) %cus *ball:tarball)
      =/  std-ball=ball:tarball
        (~(gut by dir.ball.p.bin-seen) %std *ball:tarball)
      =/  cus-tools=(map @t tool:nex-tools)  (collect-tools cus-ball)
      =/  std-tools=(map @t tool:nex-tools)  (collect-tools std-ball)
      (pure:m (~(uni by cus-tools) std-tools))
    ::
    ++  collect-tools
      |=  b=ball:tarball
      ^-  (map @t tool:nex-tools)
      =/  result=(map @t tool:nex-tools)  ~
      ::  Collect files in this directory
      =?  result  ?=(^ fil.b)
        =/  files=(list [@ta content:tarball])
          ~(tap by contents.u.fil.b)
        |-
        ?~  files  result
        =/  [name=@ta =content:tarball]  i.files
        ?:  !=(p.cage.content %temp)
          $(files t.files)
        =/  got=(each tool:nex-tools tang)
          (mule |.(!<(tool:nex-tools q.cage.content)))
        ?.  ?=(%& -.got)
          $(files t.files)
        $(files t.files, result (~(put by result) name:p.got p.got))
      ::  Recurse into subdirectories
      =/  dirs=(list [@ta ball:tarball])  ~(tap by dir.b)
      |-
      ?~  dirs  result
      =/  [* sub=ball:tarball]  i.dirs
      $(dirs t.dirs, result (~(uni by result) (collect-tools sub)))
    ::  +extract-tool: try to pull a tool from a compiled .temp cage
    ::
    ++  extract-tool
      |=  =cage
      ^-  (unit tool:nex-tools)
      ?.  =(%temp p.cage)  ~
      =/  got=(each tool:nex-tools tang)
        (mule |.(!<(tool:nex-tools q.cage)))
      ?:(?=(%& -.got) `p.got ~)
    ::  +find-tool-in-ball: search std/ then cus/ in a /bin/ ball
    ::
    ::    Iterates all compiled files and matches by the tool's name
    ::    field, since filenames (get-ship) differ from tool names (get_ship).
    ::
    ++  find-tool-in-ball
      |=  [tool-name=@t b=ball:tarball]
      ^-  (unit tool:nex-tools)
      =/  dirs=(list @ta)  ~[%std %cus]
      |-
      ?~  dirs  ~
      =/  sub=ball:tarball  (~(gut by dir.b) i.dirs *ball:tarball)
      ?~  fil.sub  $(dirs t.dirs)
      =/  files=(list [@ta content:tarball])
        ~(tap by contents.u.fil.sub)
      |-
      ?~  files  ^$(dirs t.dirs)
      =/  tl=(unit tool:nex-tools)  (extract-tool cage.i.files)
      ?~  tl  $(files t.files)
      ?:  =(tool-name name:u.tl)  tl
      $(files t.files)
    ::  +find-tang-in-ball: search for a compile error by filename
    ::
    ::    Converts tool name underscores to hyphens to match filenames
    ::    (e.g. get_ship → get-ship). Returns tang if found.
    ::
    ++  find-tang-in-ball
      |=  [tool-name=@t b=ball:tarball]
      ^-  (unit tang)
      =/  file-name=@ta
        (crip (turn (trip tool-name) |=(c=@t ?:(=(c '_') '-' c))))
      =/  dirs=(list @ta)  ~[%std %cus]
      |-
      ?~  dirs  ~
      =/  sub=ball:tarball  (~(gut by dir.b) i.dirs *ball:tarball)
      ?~  fil.sub  $(dirs t.dirs)
      =/  ct=(unit content:tarball)
        (~(get by contents.u.fil.sub) file-name)
      ?~  ct  $(dirs t.dirs)
      ?.  =(%tang p.cage.u.ct)  $(dirs t.dirs)
      =/  got=(each tang tang)
        (mule |.(!<(tang q.cage.u.ct)))
      ?:(?=(%& -.got) `p.got `~[leaf+"tool {(trip tool-name)} failed to compile"])
    ::  +await-tool: load a compiled tool handler by name
    ::
    ::    Subscribes to /bin/ — the bond returns the initial view,
    ::    so there's no race with the builder. If the tool is already
    ::    compiled, we get it immediately. If it failed to compile
    ::    (tang), we fail with the error. Otherwise we wait for updates.
    ::
    ++  await-tool
      |=  tool-name=@t
      =/  m  (fiber:fiber:nexus ,(each tool:nex-tools tang))
      ^-  form:m
      ;<  init=view:nexus  bind:m  (keep:io /await-tool [%| 1 %| /bin] ~)
      ?:  ?=([%ball *] init)
        =/  found=(unit tool:nex-tools)
          (find-tool-in-ball tool-name ball.init)
        ?^  found  (pure:m [%& u.found])
        ::  No temp — check for compile error
        =/  err=(unit tang)  (find-tang-in-ball tool-name ball.init)
        ?^  err  (pure:m [%| u.err])
        ::  Neither — wait for builder
        |-
        ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /await-tool)
        ?:  ?=(%wake -.nw)  $
        ?.  ?=([%ball *] view.nw)  $
        =/  found=(unit tool:nex-tools)
          (find-tool-in-ball tool-name ball.view.nw)
        ?^  found  (pure:m [%& u.found])
        ::  No temp — check for fresh compile error
        =/  err=(unit tang)  (find-tang-in-ball tool-name ball.view.nw)
        ?^  err  (pure:m [%| u.err])
        $
      |-
      ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /await-tool)
      ?:  ?=(%wake -.nw)  $
      ?.  ?=([%ball *] view.nw)  $
      =/  found=(unit tool:nex-tools)
        (find-tool-in-ball tool-name ball.view.nw)
      ?^  found  (pure:m [%& u.found])
      =/  err=(unit tang)  (find-tang-in-ball tool-name ball.view.nw)
      ?^  err  (pure:m [%| u.err])
      $
    ::  Builder event: news from std or cus watch, or timer wake
    ::
    +$  builder-event
      $%  [%std =view:nexus]
          [%cus =view:nexus]
          [%wake ~]
      ==
    ::  Take news from either /std or /cus watch, or timer wake
    ::
    ++  take-builder-event
      =/  m  (fiber:fiber:nexus ,builder-event)
      ^-  form:m
      |=  input:fiber:nexus
      :+  ~  state
      ?+  in  [%skip ~]
          ~  [%wait ~]
          [~ %news * *]
        ?:  =(/std wire.u.in)  [%done %std view.u.in]
        ?:  =(/cus wire.u.in)  [%done %cus view.u.in]
        [%skip ~]
          [~ %arvo [%wait @ ~] %behn %wake *]
        ?~  error.sign.u.in  [%done %wake ~]
        [%fail %timer-error u.error.sign.u.in]
      ==
    ::  Strip .hoon suffix from grub name (ball mirror uses dotted names)
    ::
    ++  strip-hoon
      |=  name=@ta
      ^-  @ta
      =/  t=tape  (trip name)
      =/  len=@ud  (lent t)
      ?.  (gth len 5)  name
      ?.  =(".hoon" (slag (sub len 5) t))  name
      (crip (scag (sub len 5) t))
    ::  Compile all tool files from a ball snapshot
    ::
    ++  compile-ball-tools
      |=  [bin-prefix=path b=ball:tarball]
      =/  m  (fiber:fiber:nexus ,~)
      ^-  form:m
      ?~  fil.b  (pure:m ~)
      =/  files=(list [@ta content:tarball])
        ~(tap by contents.u.fil.b)
      |-
      ?~  files  (pure:m ~)
      =/  [file-name=@ta =content:tarball]  i.files
      =/  stem=@ta  (strip-hoon file-name)
      ~&  >  [%mcp-builder-compile stem]
      ;<  ~  bind:m  (compile-lib bin-prefix stem cage.content)
      $(files t.files)
    ::  Process born-diff changes: compile changed, cull deleted
    ::
    ++  process-changes
      |=  [bin-prefix=path root=ball:tarball changed=(set lane:tarball)]
      =/  m  (fiber:fiber:nexus ,~)
      ^-  form:m
      =/  lanes=(list lane:tarball)  ~(tap in changed)
      |-
      ?~  lanes  (pure:m ~)
      ?:  ?=(%| -.i.lanes)  $(lanes t.lanes)
      =/  file-path=path  path.p.i.lanes
      =/  file-name=@ta  name.p.i.lanes
      =/  stem=@ta  (strip-hoon file-name)
      ::  Check if file still exists (not a delete)
      =/  sub=ball:tarball  (~(dip ba:tarball root) file-path)
      =/  ct=(unit content:tarball)
        ?~  fil.sub  ~
        (~(get by contents.u.fil.sub) file-name)
      ?~  ct
        ~&  >  [%mcp-builder-delete bin-prefix stem]
        =/  bin-road=road:tarball
          [%| 0 %& (weld /bin (weld bin-prefix file-path)) stem]
        ;<  ~  bind:m  (cull-if-exists bin-road)
        $(lanes t.lanes)
      ~&  >  [%mcp-builder-compile bin-prefix stem]
      ;<  ~  bind:m
        (compile-lib (weld bin-prefix file-path) stem cage.u.ct)
      $(lanes t.lanes)
    --
^-  nexus:nexus
|%
++  on-load
  |=  [=sand:nexus =gain:nexus =ball:tarball]
  ^-  [sand:nexus gain:nexus ball:tarball]
  =/  =ver:loader  (get-ver:loader ball)
  ?+  ver  !!
      ?(~ [~ %0])
    %+  spin:loader  [sand gain ball]
    :~  (ver-row:loader 0)
        [%fall %& [/ %'main.sig'] %.n [~ %sig !>(~)]]
        [%fall %& [/ %'builder.sig'] %.n [~ %sig !>(~)]]
        [%fall %| /requests [~ ~] [~ ~] empty-dir:loader]
        [%fall %| /tools [~ ~] [~ ~] empty-dir:loader]
        [%fall %| /cus [~ ~] [~ ~] empty-dir:loader]
        [%fall %| /bin [~ ~] [~ ~] empty-dir:loader]
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
    ;<  ~  bind:m  (rise-wait:io prod "%mcp /main: failed")
    ;<  ~  bind:m  (bind-http:nex-server [~ /grubbery/mcp])
    ~&  >  "%mcp /main: ready, bound /grubbery/mcp"
    (http-dispatch:nex-server %mcp)
      ::  /requests/{eyre-id}: parse HTTP, dispatch
      ::
      [[%requests ~] @]
    ;<  ~  bind:m  (rise-wait:io prod "%mcp request failed")
    =/  eyre-id=@ta  name.rail
    ;<  [src=@p req=inbound-request:eyre]  bind:m
      (get-state-as:io ,[src=@p inbound-request:eyre])
    ;<  our=@p  bind:m  get-our:io
    ?.  =(src our)
      (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
    ::  Parse JSON body
    =/  bod=(unit octs)  body.request.req
    ?~  bod
      (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing body')])
    =/  parsed=(unit json)  (de:json:html q.u.bod)
    ?~  parsed
      (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Invalid JSON')])
    ::  tools/call: create tool grub, watch for result, respond
    =/  method=(unit json)  (~(get jo:json-utils u.parsed) /method)
    ?:  ?=([~ %s %'tools/call'] method)
      =/  id=(unit json)  (~(get jo:json-utils u.parsed) /id)
      =/  params=(unit json)  (~(get jo:json-utils u.parsed) /params)
      ?~  params
        (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing params')])
      =/  tool-name=(unit json)  (~(get jo:json-utils u.params) /name)
      =/  arguments=(unit json)  (~(get jo:json-utils u.params) /arguments)
      ?~  tool-name
        (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing tool name')])
      ?.  ?=([%s *] u.tool-name)
        (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Invalid tool name')])
      =/  tool-args=(map @t json)
        ?~  arguments  ~
        ?.  ?=([%o *] u.arguments)  ~
        p.u.arguments
      =/  ts=tool-state:nex-tools
        [p.u.tool-name tool-args %start ~ ~]
      ::  Create tool grub and subscribe
      ::  Use eyre-id as tool grub ID so it's stable across restarts
      =/  tid=@ta  eyre-id
      =/  tool-road=road:tarball  [%| 1 %& /tools tid]
      ;<  exists=?  bind:m  (peek-exists:io /chk tool-road)
      ;<  *  bind:m
        (keep:io /watch tool-road ~)
      ;<  ~  bind:m
        ?.  exists
          (make:io /make tool-road |+[%.n tool-state+!>(ts) ~])
        (pure:m ~)
      ::  Wait for tool to finish
      |-
      ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /watch)
      ?:  ?=(%wake -.nw)  $  :: timer, keep waiting
      ::  Got news — extract tool-state from view
      ?.  ?=(%file -.view.nw)  $  :: not a file update, keep waiting
      =/  st=tool-state:nex-tools
        !<(tool-state:nex-tools q.cage.view.nw)
      ?.  =(%done step.st)  $  :: not done yet
      ?~  update.st  $  :: done but no update — shouldn't happen, keep waiting
      ::  Done — build JSON-RPC response from update
      =/  result-type=(unit json)
        (~(get jo:json-utils u.update.st) /type)
      =/  rpc-result=json
        ?:  ?=([~ %s %'error'] result-type)
          =/  msg=@t
            (~(dog jo:json-utils u.update.st) /message so:dejs:format)
          (rpc-error:nex-mcp rpc-internal-error:nex-mcp msg id)
        =/  txt=@t
          (~(dog jo:json-utils u.update.st) /text so:dejs:format)
        (mcp-text-result:nex-mcp txt id)
      =/  json-bytes=octs
        (as-octs:mimes:html (en:json:html rpc-result))
      %-  send-simple:srv
      [eyre-id [[200 ~[['content-type' 'application/json']]] `json-bytes]]
    ::  Protocol methods (initialize, tools/list, etc.): handle inline
    ;<  dynamic=(map @t tool:nex-tools)  bind:m  get-dynamic-tools
    ;<  response=(unit json)  bind:m  (handle-request:nex-mcp u.parsed dynamic)
    ?~  response
      (send-simple:srv eyre-id [[202 ~] ~])
    =/  json-bytes=octs  (as-octs:mimes:html (en:json:html u.response))
    %-  send-simple:srv
    [eyre-id [[200 ~[['content-type' 'application/json']]] `json-bytes]]
      ::  /builder.sig: watch ball mirror + /cus/, compile to /bin/
      ::
      [~ %'builder.sig']
    ;<  ~  bind:m  (rise-wait:io prod "%mcp /builder: failed")
    ~&  >  "%mcp /builder: starting"
    ::  Peek ball mirror for initial compile (hoon files survive clear-temp)
    ;<  std-init=seen:nexus  bind:m
      (peek:io /std-init [%& %| /sys/clay/grubbery/lib/nex/mcp/tools] ~)
    ;<  cus-init=seen:nexus  bind:m
      (peek:io /cus-init [%| 0 %| /cus] ~)
    ::  Initial compile from peek
    =/  std-born=born:nexus
      ?.  ?=([%& %ball *] std-init)  *born:nexus
      born.p.std-init
    =/  cus-born=born:nexus
      ?.  ?=([%& %ball *] cus-init)  *born:nexus
      born.p.cus-init
    ;<  ~  bind:m
      ?.  ?=([%& %ball *] std-init)  (pure:m ~)
      (compile-ball-tools /std ball.p.std-init)
    ;<  ~  bind:m
      ?.  ?&(?=([%& %ball *] cus-init) ?=(^ fil.ball.p.cus-init))
        (pure:m ~)
      (compile-ball-tools /cus ball.p.cus-init)
    ::  Subscribe for ongoing changes
    ;<  *  bind:m  (keep:io /std [%& %| /sys/clay/grubbery/lib/nex/mcp/tools] ~)
    ;<  *  bind:m  (keep:io /cus [%| 0 %| /cus] ~)
    ~&  >  "%mcp /builder: watching for changes"
    |-
    ;<  event=builder-event  bind:m  take-builder-event
    ?-    -.event
        %wake  $
        %std
      ?.  ?=([%ball *] view.event)  $
      =/  root=ball:tarball  ball.view.event
      =/  root-born=born:nexus  born.view.event
      =/  what=(set lane:tarball)
        (diff-born-state:nexus std-born root-born)
      =.  std-born  root-born
      ;<  ~  bind:m  (process-changes /std root what)
      $
        %cus
      ?.  ?=([%ball *] view.event)  $
      =/  root=ball:tarball  ball.view.event
      =/  root-born=born:nexus  born.view.event
      =/  what=(set lane:tarball)
        (diff-born-state:nexus cus-born root-born)
      =.  cus-born  root-born
      ;<  ~  bind:m  (process-changes /cus root what)
      $
    ==
      ::  /tools/{id}: tool process (mark %tool-state)
      ::  Reads tool-state, runs handler step machine, writes %done.
      ::  Knows nothing about HTTP — the request watcher handles that.
      ::
      [[%tools ~] @]
    ;<  ~  bind:m  (rise-wait:io prod "%mcp tool failed")
    ;<  st=tool-state:nex-tools  bind:m
      (get-state-as:io ,tool-state:nex-tools)
    ?:  =(%done step.st)  (pure:m ~)
    ::  Look up tool handler — waits for builder if needed
    ;<  got=(each tool:nex-tools tang)  bind:m  (await-tool tool.st)
    ?:  ?=(%| -.got)
      =/  err-msg=@t  (render-tang:build p.got)
      =/  result-data=json
        (pairs:enjs:format ~[['type' s+'error'] ['message' s+err-msg]])
      (replace:io !>(`tool-state:nex-tools`[tool.st args.st %done data.st `result-data]))
    =/  tl=tool:nex-tools  p.got
    ;<  result=tool-result:nex-tools  bind:m  handler.tl
    =/  result-json=json
      ?-  -.result
        %text   (pairs:enjs:format ~[['type' s+'text'] ['text' s+text.result]])
        %error  (pairs:enjs:format ~[['type' s+'error'] ['message' s+message.result]])
      ==
    (replace:io !>(`tool-state:nex-tools`[tool.st args.st %done data.st `result-json]))
  ==
++  on-manu
  |=  =mana:nexus
  ^-  @t
  ?-    -.mana
      %&
    ?+  p.mana  'Subdirectory under the MCP nexus.'
        ~
      %-  crip
      """
      MCP NEXUS — Model Context Protocol JSON-RPC tool server

      Exposes Hoon-defined tools to AI clients (Claude Code, etc.) via
      the MCP JSON-RPC protocol. Tools are compiled from source in /cus/
      into /bin/, then registered for dispatch.

      Built-in tools are loaded from /lib/nex/mcp/tools/. Custom tools
      in /cus/ extend the set. The builder watches /cus/ and recompiles
      on change.

      FILES:
        main.sig            HTTP binding process. Registers /grubbery/mcp
                            with the server, handles JSON-RPC dispatch.
        builder.sig         Tool compiler. Watches /cus/, compiles to /bin/,
                            registers tools in the live tool registry.
        ver.ud              Schema version.

      DIRECTORIES:
        cus/                Custom tool sources. Drop .hoon files here to
                            add tools. Must produce a valid tool:tools gate.
        bin/                Compiled tools. .temp = success (vase),
                            .tang = error. Auto-managed by builder.
        tools/              Running tool instances. Each active tool call
                            gets a fiber here (tool-state mark). Cleaned
                            up on completion.
        requests/           Per-request fibers for active HTTP connections.
      """
        [%cus ~]
      'Custom tool sources. Drop .hoon files here to add MCP tools. The builder auto-compiles them into /bin/. Source must produce a gate matching the tool:tools interface.'
        [%bin ~]
      'Compiled tools. .temp = successful build (executable vase), .tang = compile error (stack trace). Auto-managed by the builder — do not edit directly.'
        [%tools ~]
      'Running tool instances. Each active tool call gets a fiber here with its state (tool-state mark). Cleaned up on completion.'
        [%requests ~]
      'Per-request fibers for active MCP HTTP connections.'
    ==
      %|
    ?+  rail.p.mana  'File under the MCP nexus.'
      [~ %'main.sig']     'MCP HTTP binding process. Mark: sig. Registers /grubbery/mcp with the server, parses JSON-RPC requests, dispatches to tool fibers in /tools/.'
      [~ %'builder.sig']  'MCP tool builder. Mark: sig. Watches /cus/ for source changes, compiles to /bin/, registers tools in the live registry.'
      [~ %'ver.ud']       'Schema version counter. Mark: ud.'
    ==
  ==
--
