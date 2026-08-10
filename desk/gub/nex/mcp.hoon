::  mcp nexus: MCP JSON-RPC endpoint for grubbery
::
::  Tree layout:
::    /main.sig         bind HTTP path, dispatch requests
::    /requests/{id}    parse HTTP, route protocol vs tools/call
::    /tools/{id}       tool execution grub (mark %tool-state)
::
/<  nex-mcp     /lib/nex/mcp.hoon
/<  nex-tools   /lib/nex/tools.hoon
/&  man  ../man/mcp/readme.md
=>  |%
    ++  srv  ~(. http-res:io [%| 1 %& ~ %'main.sig'])
    ::  On crash, write error to tool state so MCP returns it.
    ::  On normal startup, continue.
    ::
    ++  rise-tool
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  form:m
      ?~  prod  (pure:m ~)
      %-  (slog leaf+"%mcp tool crashed" u.prod)
      ;<  st=tool-state:nex-tools  bind:m
        (get-state-as:io ,tool-state:nex-tools)
      =/  err-msg=@t  (render-tang:build u.prod)
      =/  result-data=json
        (pairs:enjs:format ~[['type' s+'error'] ['message' s+(crip "crash\0a{(trip err-msg)}")]])
      (replace:io `tool-state:nex-tools`[tool.st args.st %done data.st `result-data])
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
    ::  Scans root /code/lib/mcp and each /apps/*/desk/code/lib/mcp.
    ::
    ++  get-dynamic-tools
      =/  m  (fiber:fiber:nexus ,(map @t tool:nex-tools))
      ^-  form:m
      ;<  result=(map @t tool:nex-tools)  bind:m
        (scan-namespace /code/lib/mcp)
      ;<  app-paths=(list path)  bind:m  get-app-mcp-paths
      |-
      ?~  app-paths  (pure:m result)
      ;<  more=(map @t tool:nex-tools)  bind:m
        (scan-namespace i.app-paths)
      $(app-paths t.app-paths, result (~(uni by result) more))
    ::
    ++  scan-namespace
      |=  code-path=path
      =/  m  (fiber:fiber:nexus ,(map @t tool:nex-tools))
      ^-  form:m
      ;<  src-view=view:nexus  bind:m
        (peek:io [%& %| code-path] ~)
      ?.  ?=([%ball *] src-view)
        (pure:m ~)
      ?~  fil.ball.src-view
        (pure:m ~)
      =/  names=(list @ta)
        %+  turn  ~(tap by contents.u.fil.ball.src-view)
        |=([name=@ta [=sang:tarball gain=? bang=(unit tang)]] (strip-hoon name))
      =/  result=(map @t tool:nex-tools)  ~
      |-
      ?~  names  (pure:m result)
      =/  name=@ta  i.names
      ;<  res=built:nexus  bind:m  (get-code-full:io [%& %& code-path name])
      ?.  ?=(%vase -.res)  $(names t.names)
      =/  got=(each tool:nex-tools tang)
        (mule |.(!<(tool:nex-tools vase.res)))
      ?.  ?=(%& -.got)  $(names t.names)
      $(names t.names, result (~(put by result) name:p.got p.got))
    ::
    ++  get-app-mcp-paths
      =/  m  (fiber:fiber:nexus ,(list path))
      ^-  form:m
      ;<  apps-view=view:nexus  bind:m
        (peek:io [%& %| /apps] ~)
      ?.  ?=([%ball *] apps-view)
        (pure:m ~)
      %-  pure:m
      %+  turn  ~(tap by dir.ball.apps-view)
      |=  [nam=@ta *]
      (welp ~[%apps nam] /desk/code/lib/mcp)
    ::  +await-tool: look up a compiled tool handler by name
    ::
    ::    Converts underscores to hyphens (get_ship → get-ship).
    ::    Checks root code namespace, then each app's code namespace.
    ::
    ++  await-tool
      |=  tool-name=@t
      =/  m  (fiber:fiber:nexus ,(each tool:nex-tools tang))
      ^-  form:m
      =/  file-name=@ta
        (crip (turn (trip tool-name) |=(c=@t ?:(=(c '_') '-' c))))
      ;<  got=(unit tool:nex-tools)  bind:m
        (try-compile /code/lib/mcp file-name)
      ?^  got  (pure:m [%& u.got])
      ;<  app-paths=(list path)  bind:m  get-app-mcp-paths
      |-
      ?~  app-paths
        (pure:m [%| ~[leaf+"tool not found: {(trip tool-name)}"]])
      ;<  got=(unit tool:nex-tools)  bind:m
        (try-compile i.app-paths file-name)
      ?^  got  (pure:m [%& u.got])
      $(app-paths t.app-paths)
    ::
    ++  try-compile
      |=  [code-path=path file-name=@ta]
      =/  m  (fiber:fiber:nexus ,(unit tool:nex-tools))
      ^-  form:m
      ;<  res=built:nexus  bind:m  (get-code-full:io [%& %& code-path file-name])
      ?.  ?=(%vase -.res)
        (pure:m ~)
      =/  got=(each tool:nex-tools tang)
        (mule |.(!<(tool:nex-tools vase.res)))
      ?.  ?=(%& -.got)
        (pure:m ~)
      (pure:m `p.got)
    ::  +weir-json: mcp is broad by nature — it's a system tool runner that
    ::  scans every app for tools and builds their code. /tools grubs are its
    ::  own subtree (not gated).
    ::
    ::    Lives in this helper core, not in the +nexus core below: that
    ::    core is cast to nexus:nexus, whose $_ mold nests only on an
    ::    exact arm count (on-load, on-file). A third arm there is a
    ::    nest-fail, and +build-nexus's tang is swallowed by
    ::    +spawn-all-files-in — the nexus just silently never starts.
    ::
    ++  weir-json
      ^-  json
      =/  line  |=([r=@t w=@t] `json`(pairs:enjs:format ~[['road' s+r] ['why' s+w]]))
      %-  pairs:enjs:format
      :~  :-  'poke'
          :-  %a
          :~  (line '/sys/bowl.sig' 'read the current time and our ship — get-time / get-our')
              (line '/sys/eyre/' 'bind its HTTP route and send responses')
          ==
          :-  'peek'
          :-  %a
          :~  (line '/code/lib/mcp/' 'discover and build the root dynamic tools')
              (line '/apps/' 'scan every installed app for its own tools and build them')
          ==
      ==
    --
^-  nexus:nexus
|%
++  on-load
  |=  =ball:tarball
  ^-  bole:tarball
  %+  spin:loader  ball
  :~  (manifest:loader 0)
      [%over %& [/ %'alias.json'] [[/ %json] (pairs:enjs:format ~[['name' s+'mcp'] ['description' s+'MCP JSON-RPC endpoint for tools']])]]
      [%over %& [/ %'weir.json'] [[/ %json] weir-json]]
      [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
      [%fall %| /requests empty-dir:loader]
      [%fall %| /tools empty-dir:loader]
      [%over %& [/ %'README.md'] [[/ %mime] man]]
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
    ;<  ~  bind:m  (rise-wait:io prod "%mcp /main: failed")
    ;<  ~  bind:m  (bind-http-self:io [~ /grubbery/mcp])
    (http-dispatch:io %mcp)
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
      ;<  exists=?  bind:m  (peek-exists:io tool-road)
      ;<  =kept:nexus  bind:m  get-kept:io
      ;<  ~  bind:m
        ?.  =(~ kept)
          (pure:m ~)
        ;<  *  bind:m
          (keep:io /watch tool-road ~)
        ?.  exists
          ;<  ~  bind:m  (make:io tool-road |+[[[/ %tool-state] ts] ~])
          (gain:io tool-road %.y)
        (pure:m ~)
      ::  Wait for tool to finish
      |-
      ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /watch)
      ?:  ?=(%wake -.nw)  $
      =/  cas=(unit cass:clay)
        ?~  fil.wave.nw  ~
        (~(get by file.u.fil.wave.nw) tid)
      ?~  cas  $
      ;<  =view:nexus  bind:m  (peek-at:io tool-road ~ [%ud ud.u.cas])
      ?.  ?=([%file *] view)  $
      =/  st=tool-state:nex-tools
        !<(tool-state:nex-tools (need-vase:tarball sang.view))
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
      ;<  ~  bind:m
        %-  send-simple:srv
        [eyre-id [[200 ~[['content-type' 'application/json']]] `json-bytes]]
      (pure:m ~)
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
    ;<  ~  bind:m  (rise-tool prod)
    ;<  st=tool-state:nex-tools  bind:m
      (get-state-as:io ,tool-state:nex-tools)
    ?:  =(%done step.st)  (pure:m ~)
    ::  Look up tool handler from bins
    ;<  got=(each tool:nex-tools tang)  bind:m  (await-tool tool.st)
    ?:  ?=(%| -.got)
      =/  err-msg=@t  (render-tang:build p.got)
      =/  result-data=json
        (pairs:enjs:format ~[['type' s+'error'] ['message' s+err-msg]])
      (replace:io `tool-state:nex-tools`[tool.st args.st %done data.st `result-data])
    =/  tl=tool:nex-tools  p.got
    ;<  result=tool-result:nex-tools  bind:m  handler.tl
    =/  result-json=json
      ?-  -.result
        %text   (pairs:enjs:format ~[['type' s+'text'] ['text' s+text.result]])
        %error  (pairs:enjs:format ~[['type' s+'error'] ['message' s+message.result]])
        %mime
      =/  media-type=@t  (mite-to-cord:nex-tools p.mime.result)
      =/  b64=@t  (en:base64:mimes:html q.mime.result)
      %-  pairs:enjs:format
      :~  ['type' s+'mime']
          ['media_type' s+media-type]
          ['data' s+b64]
      ==
      ==
    (replace:io `tool-state:nex-tools`[tool.st args.st %done data.st `result-json])
  ==
--
