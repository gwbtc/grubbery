/<  tools  /lib/nex/tools.hoon
::  add-mcp-tool: add a custom MCP tool
::
::    Writes Hoon source to the ball mirror at /code/lib/mcp/
::    so build-code compiles it into bins. Then checks compilation
::    result via %code dart.
::
!:
^-  tool:tools
|%
++  name  'add_mcp_tool'
++  description
  ^~  %-  crip
  ;:  weld
    "Add a custom MCP tool by writing Hoon source to the "
    "build pipeline at /code/lib/mcp/. The source is "
    "compiled by build-code and made available via bins. "
    "The source must produce a valid tool:tools. "
    "Use check_bin to verify compilation status."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['name' [%string 'Tool filename without extension (e.g. "my-tool")']]
      ['source' [%string 'Hoon source code that produces a tool:tools']]
  ==
++  required  ~['name' 'source']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  parsed=(each [@t @t] tang)
    %-  mule  |.
    :-  (~(dog jo:json-utils [%o args.st]) /name so:dejs:format)
    (~(dog jo:json-utils [%o args.st]) /source so:dejs:format)
  ?:  ?=(%| -.parsed)
    (pure:m [%error 'Missing or invalid required arguments (name, source)'])
  =/  [tool-name=@ta source=@t]  p.parsed
  =/  file-name=@ta  (cat 3 tool-name '.hoon')
  =/  road=road:tarball
    [%& %& /code/lib/mcp file-name]
  ::  Write source to ball mirror
  ;<  exists=?  bind:m  (peek-exists:io /chk road)
  ?:  exists
    ;<  ~  bind:m  (over:io /write road [[/ %hoon] !>(source)])
    (pure:m [%text (crip "Source written: /code/lib/mcp/{(trip file-name)}. Use check_bin to verify compilation.")])
  ;<  ~  bind:m  (make:io /write road |+[%.n [[/ %hoon] !>(source)] ~])
  (pure:m [%text (crip "Source written: /code/lib/mcp/{(trip file-name)}. Use check_bin to verify compilation.")])
--
