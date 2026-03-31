/<  tools  /lib/nex/tools.hoon
::  call-tool: invoke any tool by name, including dynamically added ones
::
!:
^-  tool:tools
|%
++  name  'call_tool'
++  description
  ^~  %-  crip
  ;:  weld
    "Call any MCP tool by name, including dynamically added tools "
    "that are not in your cached tools/list. Use list_tools to "
    "discover available tools first. Pass the tool name and its "
    "arguments as a JSON object."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['tool_name' [%string 'Name of the tool to call (e.g. "echo", "my_custom_tool")']]
      ['tool_args' [%object 'Arguments to pass to the tool as a JSON object']]
  ==
++  required  ~['tool_name']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  parsed=(each @t tang)
    (mule |.((~(dog jo:json-utils [%o args.st]) /'tool_name' so:dejs:format)))
  ?:  ?=(%| -.parsed)
    (pure:m [%error 'Missing or invalid argument: tool_name'])
  =/  tool-name=@t  p.parsed
  =/  tool-args=(map @t json)
    =/  v  (~(get jo:json-utils [%o args.st]) /'tool_args')
    ?~  v  ~
    ?.  ?=([%o *] u.v)  ~
    p.u.v
  ::  Convert underscores to hyphens for filename lookup
  =/  file-name=@ta
    (crip (turn (trip tool-name) |=(c=@t ?:(=(c '_') '-' c))))
  ::  Look up compiled tool from bins
  ;<  res=built:nexus  bind:m  (get-code-full:io /tool [%& %& /code/lib/mcp file-name])
  ?.  ?=(%vase -.res)
    (pure:m [%error (crip "Tool not found: {(trip tool-name)}")])
  =/  got=(each tool:tools tang)
    (mule |.(!<(tool:tools vase.res)))
  ?.  ?=(%& -.got)
    (pure:m [%error (crip "Tool {(trip tool-name)} failed type check")])
  ::  Swap state to target tool's args and run handler
  =/  tl=tool:tools  p.got
  ;<  ~  bind:m
    (replace:io !>(`tool-state:tools`[tool-name tool-args %start *json ~]))
  handler.tl
--
