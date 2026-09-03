::  tools nexus: the tool registry + execution engine. A reusable
::  top-level nexus (neck [/ %tools]) that any nexus mounts an instance
::  of — mcp mounts one at /tools.tools and keeps the HTTP/JSON-RPC
::  shell, delegating discovery and execution here.
::
::  Tree layout:
::    /main.sig          supervisor: accept call/cull pokes
::    /code              this instance's own code nexus, seeded by the
::                       host with a tool bundle — the tools live here,
::                       compiled; discovery is just reading it
::    /runs/{id}         a tool execution grub (mark %tool-state)
::
::  Internal API (the calls/ pattern, same as the LLM proxies):
::    - list: the host reads /code/lib/tools directly (no cache)
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
    ::  +list-json: serialize a tool map into a protocol-neutral schema
    ::  array (name/description/parameters/required). The host reshapes
    ::  this into whatever wire format it speaks. Built fresh on each
    ::  %list poke from a live scan — not a stored cache.
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
    ++  list-json
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
    ::  /code/lib/tools and each /apps/*/desk/code/lib/tools.
    ::
    ::  +scan-own: scan this instance's OWN /code/lib/tools (relative),
    ::  compiling each tool where its seeded deps resolve.
    ::
    ++  scan-own
      |=  =rail:tarball
      =/  m  (fiber:fiber:nexus ,(map @t tool:nex-tools))
      ^-  form:m
      ;<  src-view=view:nexus  bind:m
        (peek:io (nex-road:io rail [%| /code/lib/tools]) ~)
      ?.  ?=([%ball *] src-view)  (pure:m ~)
      =/  pairs=(list [sub=path file=@ta])  (ball-code-files ~ ball.src-view)
      =/  result=(map @t tool:nex-tools)  ~
      |-
      ?~  pairs  (pure:m result)
      =/  [sub=path file=@ta]  i.pairs
      ;<  res=built:nexus  bind:m
        %-  get-code-full:io
        (nex-road:io rail [%& (weld /code/lib/tools sub) (strip-hoon:nex-tools file)])
      ?.  ?=(%vase -.res)  $(pairs t.pairs)
      =/  got=(each tool:nex-tools tang)  (mule |.(!<(tool:nex-tools vase.res)))
      ?.  ?=(%& -.got)  $(pairs t.pairs)
      $(pairs t.pairs, result (~(put by result) (derive-name:nex-tools sub file) p.got))
    ++  get-dynamic-tools
      |=  =rail:tarball
      =/  m  (fiber:fiber:nexus ,(map @t tool:nex-tools))
      ^-  form:m
      ::  a tools instance knows exactly one set of tools: its own seeded
      ::  /code (else the root /code). Scanning /apps for app-shipped tools
      ::  is an mcp affordance, not this engine's.
      ;<  own=(map @t tool:nex-tools)  bind:m  (scan-own rail)
      ?.  =(~ own)  (pure:m own)
      (scan-namespace /code/lib/tools)
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
    ::  +await-tool: look up a compiled tool handler by name (or by an
    ::  absolute /-prefixed source location in any code namespace).
    ::
    ++  await-tool
      |=  [=rail:tarball tool-name=@t]
      =/  m  (fiber:fiber:nexus ,(each tool:nex-tools tang))
      ^-  form:m
      ::  own seeded /code first (deps resolve there); else fall through.
      =/  [own-sub=path own-arm=@ta]  (name-to-place:nex-tools tool-name)
      ;<  own=built:nexus  bind:m
        %-  get-code-full:io
        (nex-road:io rail [%& (weld /code/lib/tools own-sub) own-arm])
      =/  own-tool=(unit tool:nex-tools)
        ?.  ?=(%vase -.own)  ~
        =/  g=(each tool:nex-tools tang)  (mule |.(!<(tool:nex-tools vase.own)))
        ?:(?=(%& -.g) `p.g ~)
      ?^  own-tool  (pure:m [%& u.own-tool])
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
        (try-compile (weld /code/lib/tools sub) arm)
      ?^  got  (pure:m [%& u.got])
      (pure:m [%| ~[leaf+"tool not found: {(trip tool-name)}"]])
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
    --
^-  nexus:nexus
|%
++  on-load
  |=  =ball:tarball
  ^-  bole:tarball
  ::  no alias.json / weir.json: a tools instance is a nested execution
  ::  engine, not an installable app. It is not discoverable, and its reach
  ::  is the weir its HOST sets on it at mount — never self-declared.
  %+  spin:loader  ball
  :~  (manifest:loader 0)
      [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
      [%fall %| /runs empty-dir:loader]
      ::  /code: this instance's own code nexus (seeded by the host with
      ::  a tool bundle). Scanned first; falls back to root /code if empty.
      [%fall %| /code [`[`[/ %code] ~ %.n ~] ~]]
  ==
::
++  on-file
  |=  [=rail:tarball =blot:tarball]
  ^-  spool:fiber:nexus
  |=  =prod:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  process:fiber:nexus
  ?+    rail  stay:m
      ::  supervisor: accept calls. a %call poke {id, name, arguments}
      ::  spawns a run grub; a %cull poke drops a finished run.
      ::
      [~ %'main.sig']
    ;<  ~  bind:m  (rise-wait:io prod "%tools /main: failed")
    |-
    ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
    ::  every command is a [/ %json] poke keyed by a "cmd" field —
    ::  reusing the json mark (no per-command marks to define, so the
    ::  queued poke stays hydrate-valid).
    ?.  =([/ %json] p.sage)
      ~&  >>>  ["%tools /main: non-json poke" p.sage]
      $
    =/  jon=json  !<(json q.sage)
    =/  cmd=@t  (~(dog jo:json-utils jon) /cmd so:dejs:format)
    ?:  =('list' cmd)
      ::  live listing: scan our own /code (relative, self-locating) and
      ::  poke the schema array straight back to whoever asked — a plain
      ::  request/response, no grub written anywhere.
      ;<  dynamic=(map @t tool:nex-tools)  bind:m  (get-dynamic-tools rail)
      =/  reply=road:tarball  [%| p.from [%& q.from]]
      ;<  ~  bind:m  (poke:io reply [[/ %json] (list-json dynamic)])
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
    ;<  got=(each tool:nex-tools tang)  bind:m  (await-tool rail tool.st)
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
