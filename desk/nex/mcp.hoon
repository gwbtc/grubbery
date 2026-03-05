::  mcp nexus: MCP JSON-RPC endpoint for grubbery
::  v2: tool-state step machine for restart survival
::
::  Binds /grubbery/mcp and handles JSON-RPC 2.0 requests.
::  Delegates tool execution to lib/nex/tools built-ins.
::
::  Tree layout:
::    /main             bind HTTP path, dispatch requests
::    /requests/{id}    parse HTTP, route protocol vs tools/call
::    /tools/{id}       tool process (mark %json, can replace:io)
::
/+  nexus, tarball, io=fiberio, server, http-utils, nex-server, nex-mcp
/+  json-utils, nex-tools
!: :: turn on stack trace
=>  |%
    ++  srv  ~(. res:nex-server [%| 1 %& ~ %main])
    ::  SSE keep-alive loop for Streamable HTTP transport.
    ::  On desk recompile, process restarts with %rise prod —
    ::  caller sends tools/list_changed before entering this loop.
    ::
    ++  sse-loop
      |=  eyre-id=@ta
      =/  m  (fiber:fiber:nexus ,~)
      ^-  form:m
      ;<  =bowl:nexus  bind:m  (get-bowl:io /sse)
      ;<  ~  bind:m  (send-wait:io (add now.bowl ~s30))
      |-
      ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /mcp-sse)
      ?:  ?=(%news -.nw)  $
      ::  Timer wake: send keep-alive
      ;<  ~  bind:m  (send-data:srv eyre-id `sse-keep-alive:http-utils)
      ;<  =bowl:nexus  bind:m  (get-bowl:io /sse)
      ;<  ~  bind:m  (send-wait:io (add now.bowl ~s30))
      $
    --
^-  nexus:nexus
|%
++  on-load
  |=  [=sand:nexus =ball:tarball]
  ^-  [sand:nexus ball:tarball]
  =?  ball  =(~ (~(get ba:tarball ball) [/ %main]))
    (~(put ba:tarball ball) [/ %main] [~ %sig !>(~)])
  =?  ball  =(~ (~(get of ball) /requests))
    (~(put of ball) /requests [~ ~ ~])
  =?  ball  =(~ (~(get of ball) /tools))
    (~(put of ball) /tools [~ ~ ~])
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
      ;<  ~  bind:m
        (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
      (pure:m ~)
    ::  SSE stream for server-initiated notifications (Streamable HTTP)
    ::  Client GETs with Accept: text/event-stream to open the channel.
    ::  On desk recompile, process restarts — send tools/list_changed.
    ::
    ?:  (is-sse-request:http-utils req)
      ?.  ?=(%rise -.prod)
        ::  Fresh connection: send SSE header, enter keep-alive loop
        ;<  ~  bind:m  (send-header:srv eyre-id sse-header:http-utils)
        (sse-loop eyre-id)
      ::  Restarted after desk recompile: notify tools changed
      =/  notify=json
        %-  pairs:enjs:format
        :~  ['jsonrpc' s+'2.0']
            ['method' s+'notifications/tools/list_changed']
        ==
      =/  ev=sse-event:http-utils  [~ ~ [(en:json:html notify)]~]
      ;<  ~  bind:m  (send-data:srv eyre-id `(sse-encode:http-utils ~[ev]))
      (sse-loop eyre-id)
    ::  Parse JSON body
    =/  bod=(unit octs)  body.request.req
    ?~  bod
      ;<  ~  bind:m
        (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing body')])
      (pure:m ~)
    =/  parsed=(unit json)  (de:json:html q.u.bod)
    ?~  parsed
      ;<  ~  bind:m
        (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Invalid JSON')])
      (pure:m ~)
    ::  tools/call: create tool grub, watch for result, respond
    =/  method=(unit json)  (~(get jo:json-utils u.parsed) /method)
    ?:  ?=([~ %s %'tools/call'] method)
      =/  id=(unit json)  (~(get jo:json-utils u.parsed) /id)
      =/  params=(unit json)  (~(get jo:json-utils u.parsed) /params)
      ?~  params
        ;<  ~  bind:m
          (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing params')])
        (pure:m ~)
      =/  tool-name=(unit json)  (~(get jo:json-utils u.params) /name)
      =/  arguments=(unit json)  (~(get jo:json-utils u.params) /arguments)
      ?~  tool-name
        ;<  ~  bind:m
          (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing tool name')])
        (pure:m ~)
      ?.  ?=([%s *] u.tool-name)
        ;<  ~  bind:m
          (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Invalid tool name')])
        (pure:m ~)
      ::  Build tool-state with _tool in args for handler lookup
      =/  tool-args=(map @t json)
        ?~  arguments  ~
        ?.  ?=([%o *] u.arguments)  ~
        p.u.arguments
      =/  ts=tool-state:nex-tools
        :+  (~(put by tool-args) '_tool' u.tool-name)
          %start
        ~
      ::  Create tool grub and subscribe
      ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
      =/  tid=@ta  (scot %da now.bowl)
      ;<  ~  bind:m
        (keep:io /watch [%| 1 %& /tools tid] ~)
      ;<  ~  bind:m
        (make:io /make [%| 1 %& /tools tid] |+[tool-state+!>(ts) ~])
      ::  Wait for tool to finish
      |-
      ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /watch)
      ?:  ?=(%wake -.nw)  $  :: timer, keep waiting
      ::  Got news — extract tool-state from view
      ?.  ?=(%file -.view.nw)  $  :: not a file update, keep waiting
      =/  st=tool-state:nex-tools
        !<(tool-state:nex-tools q.cage.view.nw)
      ?.  =(%done step.st)  $  :: not done yet
      ::  Done — build JSON-RPC response
      =/  result-type=(unit json)
        (~(get jo:json-utils data.st) /type)
      =/  rpc-result=json
        ?:  ?=([~ %s %'error'] result-type)
          =/  msg=@t
            (~(dog jo:json-utils data.st) /message so:dejs:format)
          (rpc-error:nex-mcp rpc-internal-error:nex-mcp msg id)
        =/  txt=@t
          (~(dog jo:json-utils data.st) /text so:dejs:format)
        (mcp-text-result:nex-mcp txt id)
      =/  json-bytes=octs
        (as-octs:mimes:html (en:json:html rpc-result))
      ;<  ~  bind:m
        %-  send-simple:srv
        [eyre-id [[200 ~[['content-type' 'application/json']]] `json-bytes]]
      (pure:m ~)
    ::  Protocol methods (initialize, tools/list, etc.): handle inline
    ;<  response=(unit json)  bind:m  (handle-request:nex-mcp u.parsed)
    ?~  response
      ;<  ~  bind:m  (send-simple:srv eyre-id [[202 ~] ~])
      (pure:m ~)
    =/  json-bytes=octs  (as-octs:mimes:html (en:json:html u.response))
    ;<  ~  bind:m
      %-  send-simple:srv
      [eyre-id [[200 ~[['content-type' 'application/json']]] `json-bytes]]
    (pure:m ~)
      ::  /tools/{id}: tool process (mark %tool-state)
      ::  Reads tool-state, runs handler step machine, writes %done.
      ::  Knows nothing about HTTP — the request watcher handles that.
      ::
      [[%tools ~] @]
    ;<  ~  bind:m  (rise-wait:io prod "%mcp tool failed")
    ;<  st=tool-state:nex-tools  bind:m
      (get-state-as:io ,tool-state:nex-tools)
    ?:  =(%done step.st)  (pure:m ~)
    ::  Look up handler by tool name stored in args
    =/  tool-json=json  (~(got by args.st) '_tool')
    ?.  ?=([%s *] tool-json)  !!
    =/  tool-name=@t  p.tool-json
    =/  tl=(unit tool:nex-tools)
      (~(get by built-ins:nex-tools) tool-name)
    ?~  tl
      =/  err-data=json
        %-  pairs:enjs:format
        :~  ['type' s+'error']
            ['message' s+(crip "Unknown tool: {(trip tool-name)}")]
        ==
      ;<  ~  bind:m
        (replace:io !>(`tool-state:nex-tools`[args.st %done err-data]))
      (pure:m ~)
    ::  Run handler — returns tool-result
    ;<  result=tool-result:nex-tools  bind:m  handler.u.tl
    ::  Write result as %done
    =/  result-data=json
      ?-  -.result
        %text   (pairs:enjs:format ~[['type' s+'text'] ['text' s+text.result]])
        %error  (pairs:enjs:format ~[['type' s+'error'] ['message' s+message.result]])
      ==
    ;<  ~  bind:m
      (replace:io !>(`tool-state:nex-tools`[args.st %done result-data]))
    (pure:m ~)
  ==
--
