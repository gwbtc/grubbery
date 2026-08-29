::  tools nexus: the tool registry + execution engine. A reusable
::  top-level nexus (neck [/ %tools]) that any nexus mounts an instance
::  of — mcp mounts one at /tools.tools and keeps the HTTP/JSON-RPC
::  shell, delegating discovery and execution here.
::
::  Tree layout:
::    /main.sig          supervisor: build the registry, accept calls
::    /registry.json     cached tool list (name/description/schema),
::                       rebuilt on rise and on a %refresh poke
::    /runs/{id}         a tool execution grub (mark %tool-state)
::
::  Internal API (the calls/ pattern, same as the LLM proxies):
::    - list: peek /registry.json (a derived cache; %refresh to rebuild)
::    - call: subscribe to /runs/{id}, poke main.sig with
::            {id, name, arguments}; main.sig makes the run grub, the
::            run fiber executes the handler and overwrites itself with
::            the result at %done; the caller reads on news and culls.
::
::  Tools run under THIS nexus's weir. Contained by a host nexus, it is
::  bounded by the host's weir — so where you mount it IS the sandbox.
::
/<  nex-tools   /lib/tools.hoon
=>  |%
    ::  +weir-json: like mcp, this nexus runs ARBITRARY user tools that
    ::  may scry, poke, or make anything, so it declares wide reach. Its
    ::  host bounds it: mounted under a narrow nexus, the kernel's
    ::  ancestor walk clamps every tool to the host's weir.
    ::
    ++  weir-json
      ^-  json
      =/  line  |=([r=@t w=@t] `json`(pairs:enjs:format ~[['road' s+r] ['why' s+w]]))
      %-  pairs:enjs:format
      :~  :-  'poke'
          :-  %a
          :~  (line '/' 'runs arbitrary tools under its own weir — a tool may poke anything')
          ==
          :-  'peek'
          :-  %a
          :~  (line '/' 'a tool may read anything')
          ==
          :-  'make'
          :-  %a
          :~  (line '/' 'a tool may create grubs anywhere')
          ==
      ==
    ::  +registry-json: the cached tool list — an array of protocol-
    ::  neutral tool schemas (name/description/parameters/required). A
    ::  consumer (mcp) reshapes these into whatever wire format it
    ::  speaks; the engine stays protocol-agnostic.
    ::
    ++  param-type-json
      |=  type=parameter-type:nex-tools
      ^-  @t
      ?-  type
        %string   'string'
        %number   'number'
        %boolean  'boolean'
        %array    'array'
        %object   'object'
      ==
    ++  tool-schema
      |=  =tool:nex-tools
      ^-  json
      =/  properties=(map @t json)
        %-  ~(run by parameters:tool)
        |=  param=parameter-def:nex-tools
        %-  pairs:enjs:format
        :~  ['type' s+(param-type-json type.param)]
            ['description' s+description.param]
        ==
      %-  pairs:enjs:format
      :~  ['name' s+name:tool]
          ['description' s+description:tool]
          ['parameters' [%o properties]]
          ['required' [%a (turn required:tool |=(f=@t s+f))]]
      ==
    ++  registry-json
      |=  dynamic=(map @t tool:nex-tools)
      ^-  json
      [%a (turn ~(val by dynamic) tool-schema)]
    ::  +rise-tool: a crashed tool run reports the crash as its result
    ::  instead of dying, so the caller always sees a %done.
    ::
    ++  rise-tool
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  form:m
      ?~  prod  (pure:m ~)
      %-  (slog leaf+"%tools run crashed" u.prod)
      ;<  st=tool-state:nex-tools  bind:m
        (get-state-as:io ,tool-state:nex-tools)
      ?:  =(%done step.st)  (pure:m ~)
      =/  err-msg=@t  (render-tang:build u.prod)
      =/  result-data=json
        (pairs:enjs:format ~[['type' s+'error'] ['message' s+(crip "crash\0a{(trip err-msg)}")]])
      (replace:io `tool-state:nex-tools`[tool.st args.st %done data.st `result-data])
    ::  +get-dynamic-tools: every compiled tool, scanning root
    ::  /code/lib/mcp and each /apps/*/desk/code/lib/mcp.
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
      |=  root=path
      =/  m  (fiber:fiber:nexus ,(map @t tool:nex-tools))
      ^-  form:m
      ;<  src-view=view:nexus  bind:m
        (peek:io [%& %| root] ~)
      ?.  ?=([%ball *] src-view)
        (pure:m ~)
      =/  pairs=(list [sub=path file=@ta])
        (ball-code-files ~ ball.src-view)
      =/  result=(map @t tool:nex-tools)  ~
      |-
      ?~  pairs  (pure:m result)
      =/  [sub=path file=@ta]  i.pairs
      ;<  res=built:nexus  bind:m
        (get-code-full:io [%& %& (weld root sub) (strip-hoon:nex-tools file)])
      ?.  ?=(%vase -.res)  $(pairs t.pairs)
      =/  got=(each tool:nex-tools tang)
        (mule |.(!<(tool:nex-tools vase.res)))
      ?.  ?=(%& -.got)  $(pairs t.pairs)
      $(pairs t.pairs, result (~(put by result) (derive-name:nex-tools sub file) p.got))
    ::  +ball-code-files: every file in a ball, with its subpath
    ::
    ++  ball-code-files
      |=  [sub=path bal=ball:tarball]
      ^-  (list [path @ta])
      =/  here=(list [path @ta])
        ?~  fil.bal  ~
        (turn ~(tap by contents.u.fil.bal) |=([n=@ta *] [sub n]))
      %+  roll  ~(tap by dir.bal)
      |=  [[nam=@ta kid=ball:tarball] acc=_here]
      (weld acc (ball-code-files (snoc sub nam) kid))
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
    ::  +await-tool: look up a compiled tool handler by name (or by an
    ::  absolute /-prefixed source location in any code namespace).
    ::
    ++  await-tool
      |=  tool-name=@t
      =/  m  (fiber:fiber:nexus ,(each tool:nex-tools tang))
      ^-  form:m
      ?:  =('/' (end 3 tool-name))
        =/  pax=(unit path)  (rush tool-name stap)
        ?:  |(?=(~ pax) ?=(~ u.pax))
          (pure:m [%| ~[leaf+"bad tool path: {(trip tool-name)}"]])
        ;<  got=(unit tool:nex-tools)  bind:m
          (try-compile (snip `path`u.pax) (rear u.pax))
        ?^  got  (pure:m [%& u.got])
        (pure:m [%| ~[leaf+"no tool at {(trip tool-name)}"]])
      =/  [sub=path arm=@ta]  (name-to-place:nex-tools tool-name)
      ;<  got=(unit tool:nex-tools)  bind:m
        (try-compile (weld /code/lib/mcp sub) arm)
      ?^  got  (pure:m [%& u.got])
      ;<  app-paths=(list path)  bind:m  get-app-mcp-paths
      |-
      ?~  app-paths
        (pure:m [%| ~[leaf+"tool not found: {(trip tool-name)}"]])
      ;<  got=(unit tool:nex-tools)  bind:m
        (try-compile (weld i.app-paths sub) arm)
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
    ::  +build-registry: scan and write /registry.json (the cache).
    ::
    ++  build-registry
      |=  =rail:tarball
      =/  m  (fiber:fiber:nexus ,~)
      ^-  form:m
      ;<  dynamic=(map @t tool:nex-tools)  bind:m  get-dynamic-tools
      (over:io (nex-road:io rail [%& / %'registry.json']) [[/ %json] (registry-json dynamic)])
    --
^-  nexus:nexus
|%
++  on-load
  |=  =ball:tarball
  ^-  bole:tarball
  %+  spin:loader  ball
  :~  (manifest:loader 0)
      [%over %& [/ %'alias.json'] [[/ %json] (pairs:enjs:format ~[['name' s+'tools'] ['description' s+'tool registry & execution engine']])]]
      [%over %& [/ %'weir.json'] [[/ %json] weir-json]]
      [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
      [%fall %& [/ %'registry.json'] [[/ %json] [%a ~]]]
      [%fall %| /runs empty-dir:loader]
  ==
::
++  on-file
  |=  [=rail:tarball =blot:tarball]
  ^-  spool:fiber:nexus
  |=  =prod:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  process:fiber:nexus
  ?+    rail  stay:m
      ::  supervisor: build the registry on rise, then accept calls.
      ::  a %call poke {id, name, arguments} spawns a run grub; a
      ::  %refresh poke rebuilds the cached registry.
      ::
      [~ %'main.sig']
    ;<  ~  bind:m  (rise-wait:io prod "%tools /main: failed")
    ;<  ~  bind:m  (build-registry rail)
    |-
    ;<  =sage:tarball  bind:m  take-poke:io
    ::  every command is a [/ %json] poke keyed by a "cmd" field —
    ::  reusing the json mark (no per-command marks to define, so the
    ::  queued poke stays hydrate-valid).
    ?.  =([/ %json] p.sage)
      ~&  >>>  ["%tools /main: non-json poke" p.sage]
      $
    =/  jon=json  !<(json q.sage)
    =/  cmd=@t  (~(dog jo:json-utils jon) /cmd so:dejs:format)
    ?:  =('refresh' cmd)
      ;<  ~  bind:m  (build-registry rail)
      $
    ?:  =('cull' cmd)
      =/  cid=@t  (~(dog jo:json-utils jon) /id so:dejs:format)
      ;<  *  bind:m  (cull-soft:io (nex-road:io rail [%& /runs `@ta`cid]))
      $
    ?.  =('call' cmd)
      ~&  >>>  ["%tools /main: unknown cmd" cmd]
      $
    =/  id=@t   (~(dog jo:json-utils jon) /id so:dejs:format)
    =/  nam=@t  (~(dog jo:json-utils jon) /name so:dejs:format)
    =/  args=(map @t json)
      =/  a=(unit json)  (~(get jo:json-utils jon) /arguments)
      ?~  a  ~
      ?.  ?=([%o *] u.a)  ~
      p.u.a
    =/  ts=tool-state:nex-tools  [nam args %start ~ ~]
    =/  run-road=road:tarball  (nex-road:io rail [%& /runs `@ta`id])
    ;<  exists=?  bind:m  (peek-exists:io run-road)
    ?:  exists  $
    ;<  ~  bind:m  (make:io run-road |+[[[/ %tool-state] ts] ~])
    $
      ::  /runs/{id}: a tool execution grub. Reads its tool-state, looks
      ::  up the handler from the code namespace, runs it, writes %done.
      ::
      [[%runs ~] @]
    ?:  =(%'weir.json' name.rail)  stay:m
    ;<  ~  bind:m  (rise-tool prod)
    ;<  st=tool-state:nex-tools  bind:m
      (get-state-as:io ,tool-state:nex-tools)
    ?:  =(%done step.st)  stay:m
    ;<  got=(each tool:nex-tools tang)  bind:m  (await-tool tool.st)
    ?:  ?=(%| -.got)
      =/  err-msg=@t  (render-tang:build p.got)
      =/  result-data=json
        (pairs:enjs:format ~[['type' s+'error'] ['message' s+err-msg]])
      ;<  ~  bind:m
        (replace:io `tool-state:nex-tools`[tool.st args.st %done data.st `result-data])
      stay:m
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
    ;<  ~  bind:m
      (replace:io `tool-state:nex-tools`[tool.st args.st %done data.st `result-json])
    stay:m
  ==
--
