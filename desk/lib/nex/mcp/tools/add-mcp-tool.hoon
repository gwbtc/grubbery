::  add-mcp-tool: add a custom MCP tool to /lib/cus/
::
::    Writes Hoon source to the MCP nexus custom tools directory.
::    Waits for the builder to compile it and returns the result.
::
=>  |%
    ++  await-compile
      |=  [tool-name=@ta sub-path=path]
      =/  m  (fiber:fiber:nexus ,tool-result:tools)
      ^-  form:m
      |-
      ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /await)
      ?:  ?=(%wake -.nw)  $
      ?.  ?=([%ball *] view.nw)  $
      ::  Look for our file in /bin/cus/
      =/  bin-ball=ball:tarball  ball.view.nw
      =/  cus=ball:tarball  (~(gut by dir.bin-ball) %cus *ball:tarball)
      =/  sub=ball:tarball  (~(dip ba:tarball cus) sub-path)
      ?~  fil.sub  $
      =/  ct=(unit content:tarball)
        (~(get by contents.u.fil.sub) tool-name)
      ?~  ct  $
      ?:  =(%temp p.cage.u.ct)
        (pure:m [%text (crip "Tool {(trip tool-name)} compiled and registered at /lib/cus{(spud sub-path)}")])
      ?.  =(%tang p.cage.u.ct)  $
      =/  err=tang  !<(tang q.cage.u.ct)
      =/  msg=@t
        %-  crip
        %-  zing
        %+  turn  (flop err)
        |=(=tank (weld ~(ram re tank) "\0a"))
      (pure:m [%error msg])
    --
!:
^-  tool:tools
|%
++  name  'add_mcp_tool'
++  description
  ^~  %-  crip
  ;:  weld
    "Add a custom MCP tool by writing Hoon source to the "
    "MCP nexus custom tools directory (/lib/cus/). The builder "
    "automatically compiles and registers it. "
    "Path is relative within cus/ (e.g. '/' for top-level, "
    "'/my-category' for nested). "
    "The source must produce a valid tool:tools. "
    "Returns compile errors if the source fails to build."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['name' [%string 'Tool filename without extension (e.g. "my-tool")']]
      ['source' [%string 'Hoon source code that produces a tool:tools']]
      ['path' [%string 'Path within cus/ (e.g. "/" for top-level, "/subdir" for nested). Defaults to "/".']]
  ==
++  required  ~['name' 'source']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  tool-name=@ta
    (~(dog jo:json-utils [%o args.st]) /name so:dejs:format)
  =/  source=@t
    (~(dog jo:json-utils [%o args.st]) /source so:dejs:format)
  =/  sub-path=path
    =/  raw=(unit @t)
      ?~  p=(~(get jo:json-utils [%o args.st]) /path)  ~
      ?.  ?=([%s *] u.p)  ~
      ?:  =('' p.u.p)  ~
      `p.u.p
    ?~  raw  /
    (stab u.raw)
  =/  full-path=path  (weld /lib/cus sub-path)
  =/  road=road:tarball  [%| 1 %& full-path tool-name]
  ::  Subscribe to /bin/ BEFORE writing source (no race with builder)
  ;<  init=view:nexus  bind:m  (keep:io /await [%| 1 %| /bin] ~)
  ::  Write source
  ;<  exists=?  bind:m  (peek-exists:io /chk road)
  ?:  exists
    ;<  ~  bind:m  (over:io /write road hoon+!>(source))
    (await-compile tool-name sub-path)
  ;<  ~  bind:m  (make:io /write road |+[%.n hoon+!>(source) ~])
  (await-compile tool-name sub-path)
--
