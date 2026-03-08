::  add-mcp-tool: add a custom MCP tool to /lib/cus/
::
::    Writes Hoon source to the MCP nexus custom tools directory.
::    The builder automatically compiles it and makes it available.
::
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
    "The source must produce a valid tool:tools."
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
  ;<  exists=?  bind:m  (peek-exists:io /chk road)
  ?:  exists
    ;<  ~  bind:m  (over:io /write road hoon+!>(source))
    (pure:m [%text (crip "Updated custom tool {(trip tool-name)} at /lib/cus{(spud sub-path)}")])
  ;<  ~  bind:m  (make:io /write road |+[hoon+!>(source) ~])
  (pure:m [%text (crip "Created custom tool {(trip tool-name)} at /lib/cus{(spud sub-path)}")])
--
