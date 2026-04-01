::  mcp nexus: MCP JSON-RPC endpoint for grubbery
::
::  Tree layout:
::    /main.sig         bind HTTP path, dispatch requests
::    /requests/{id}    parse HTTP, route protocol vs tools/call
::    /tools/{id}       tool execution grub (mark %tool-state)
::
/<  nex-server  /lib/nex/server.hoon
/<  nex-mcp     /lib/nex/mcp.hoon
/<  nex-tools   /lib/nex/tools.hoon
=>  |%
    ++  srv  ~(. res:nex-server [%| 1 %& ~ %'main.sig'])
    ::  Strip .hoon suffix from grub name
    ::
    ++  strip-hoon
      |=  name=@ta
      ^-  @ta
      =/  t=tape  (trip name)
      =/  len=@ud  (lent t)
      ?.  (gth len 5)  name
      ?.  =(".hoon" (slag (sub len 5) t))  name
      (crip (scag (sub len 5) t))
    ::  Get all compiled tools from bins via %code darts.
    ::  Peeks ball mirror for source filenames, then looks up each.
    ::
    ++  get-dynamic-tools
      =/  m  (fiber:fiber:nexus ,(map @t tool:nex-tools))
      ^-  form:m
      ;<  src-seen=seen:nexus  bind:m
        (peek:io /src [%& %| /code/lib/mcp] ~)
      ?.  ?=([%& %ball *] src-seen)
        (pure:m ~)
      ?~  fil.ball.p.src-seen
        (pure:m ~)
      =/  names=(list @ta)
        %+  turn  ~(tap by contents.u.fil.ball.p.src-seen)
        |=([name=@ta *] (strip-hoon name))
      =/  result=(map @t tool:nex-tools)  ~
      |-
      ?~  names  (pure:m result)
      =/  name=@ta  i.names
      ;<  res=built:nexus  bind:m  (get-code-full:io /tool [%& %& /code/lib/mcp name])
      ?.  ?=(%vase -.res)  $(names t.names)
      =/  got=(each tool:nex-tools tang)
        (mule |.(!<(tool:nex-tools vase.res)))
      ?.  ?=(%& -.got)  $(names t.names)
      $(names t.names, result (~(put by result) name:p.got p.got))
    ::  +await-tool: look up a compiled tool handler by name
    ::
    ::    Converts underscores to hyphens (get_ship → get-ship) and
    ::    looks up the compiled artifact from bins via %code dart.
    ::
    ++  await-tool
      |=  tool-name=@t
      =/  m  (fiber:fiber:nexus ,(each tool:nex-tools tang))
      ^-  form:m
      =/  file-name=@ta
        (crip (turn (trip tool-name) |=(c=@t ?:(=(c '_') '-' c))))
      ;<  res=built:nexus  bind:m  (get-code-full:io /tool [%& %& /code/lib/mcp file-name])
      ?.  ?=(%vase -.res)
        (pure:m [%| ?:(?=(%tang -.res) tang.res ~[leaf+"not a vase"])])
      =/  got=(each tool:nex-tools tang)
        (mule |.(!<(tool:nex-tools vase.res)))
      ?:  ?=(%& -.got)
        (pure:m [%& p.got])
      (pure:m [%| p.got])
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
    :~  (ver-row:loader 1)
        [%fall %& [/ %'main.sig'] %.n [~ [/ %sig] !>(~)]]
        [%fall %| /requests [~ ~] [~ ~] empty-dir:loader]
        [%fall %| /tools [~ ~] [~ ~] empty-dir:loader]
    ==
      [~ %1]
    [sand gain ball]
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
      =/  tid=@ta  eyre-id
      =/  tool-road=road:tarball  [%| 1 %& /tools tid]
      ;<  exists=?  bind:m  (peek-exists:io /chk tool-road)
      ;<  =kept:nexus  bind:m  (get-kept:io /watch)
      ;<  ~  bind:m
        ?.  =(~ kept)
          (pure:m ~)
        ;<  *  bind:m
          (keep:io /watch tool-road ~)
        ?.  exists
          (make:io /make tool-road |+[%.n [[/ %tool-state] !>(ts)] ~])
        (pure:m ~)
      ::  Wait for tool to finish
      |-
      ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /watch)
      ?:  ?=(%wake -.nw)  $
      ?.  ?=(%file -.view.nw)  $
      =/  st=tool-state:nex-tools
        !<(tool-state:nex-tools q.sage.view.nw)
      ?.  =(%done step.st)  $
      ?~  update.st  $
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
      ::  /tools/{id}: tool process
      ::  Reads tool-state, looks up handler from bins, runs it, writes %done.
      ::
      [[%tools ~] @]
    ;<  ~  bind:m  (rise-wait:io prod "%mcp tool failed")
    ;<  st=tool-state:nex-tools  bind:m
      (get-state-as:io ,tool-state:nex-tools)
    ?:  =(%done step.st)  (pure:m ~)
    ::  Look up tool handler from bins
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
      the MCP JSON-RPC protocol. Tools are compiled by the standard
      build pipeline (gub/lib/mcp/) and looked up from bins at runtime.

      FILES:
        main.sig            HTTP binding process. Registers /grubbery/mcp
                            with the server, handles JSON-RPC dispatch.
        ver.ud              Schema version.

      DIRECTORIES:
        tools/              Running tool instances. Each active tool call
                            gets a fiber here (tool-state mark). Cleaned
                            up on completion.
        requests/           Per-request fibers for active HTTP connections.
      """
        [%tools ~]
      'Running tool instances. Each active tool call gets a fiber here with its state (tool-state mark). Cleaned up on completion.'
        [%requests ~]
      'Per-request fibers for active MCP HTTP connections.'
    ==
      %|
    ?+  rail.p.mana  'File under the MCP nexus.'
      [~ %'main.sig']     'MCP HTTP binding process. Mark: sig. Registers /grubbery/mcp with the server, parses JSON-RPC requests, dispatches to tool fibers in /tools/.'
      [~ %'ver.ud']       'Schema version counter. Mark: ud.'
    ==
  ==
--
