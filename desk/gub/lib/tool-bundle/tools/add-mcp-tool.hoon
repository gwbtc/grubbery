/<  tools  /lib/tools.hoon
::  add-mcp-tool: add a custom MCP tool
::
::    Writes Hoon source to the ball mirror at /code/lib/tools/
::    so build-code compiles it into bins. The name may carry
::    directories: "temp/cull-paths" lands at
::    /code/lib/tools/temp/cull-paths.hoon and is the tool temp__cull_paths,
::    the way the scanner names every nested tool. Missing directories
::    are made on the way.
::
!:
^-  tool:tools
|%
++  name  'add_mcp_tool'
++  description
  ^~  %-  crip
  ;:  weld
    "Add a custom MCP tool by writing Hoon source to the "
    "build pipeline at /code/lib/tools/. The source is "
    "compiled by build-code and made available via bins. "
    "The source must produce a valid tool:tools. "
    "A name with directories (temp/my-tool) nests the file and "
    "names the tool temp__my_tool. "
    "Use check_bin to verify compilation status."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['name' [%string 'Tool filename without extension, directories allowed (e.g. "my-tool", "temp/my-tool")']]
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
  =/  [tool-name=@t source=@t]  p.parsed
  ::  the name as a path: its directories, then the file
  =/  full=(unit path)  (rush (cat 3 '/' tool-name) stap)
  ?:  |(?=(~ full) ?=(~ u.full))
    (pure:m [%error (crip "bad tool name: {(trip tool-name)}")])
  =/  sub=path  (snip `path`u.full)
  =/  file-name=@ta  (cat 3 (rear u.full) '.hoon')
  =/  dir=path  (weld /code/lib/tools sub)
  ::  write into our own nexus /code, addressed by nex-road from this
  ::  file's rail (placement-independent).
  =/  road=road:tarball  [%| 1 [%& dir file-name]]
  =/  told=@t
    %-  crip
    ;:  weld
      "Source written: {(spud (snoc dir file-name))}, tool "
      (trip (derive-name:tools sub file-name))
      ". Use check_bin to verify compilation."
    ==
  ::  each directory on the way, made if missing (soft: an existing one
  ::  is not an error)
  =/  n=@ud  1
  |-  ^-  form:m
  ?:  (lte n (lent sub))
    ;<  *  bind:m
      %+  make-soft:io  [%| 1 [%| (weld /code/lib/tools (scag n sub))]]
      &+`bole:tarball`[`[~ ~ %.n ~] ~]
    $(n +(n))
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?:  exists
    ;<  ~  bind:m  (over:io road [[/ %hoon] source])
    (pure:m [%text told])
  ;<  ~  bind:m  (make:io road |+[[[/ %hoon] source] ~])
  (pure:m [%text told])
--
