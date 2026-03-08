::  call-tool: invoke any tool by name, including dynamically added ones
::
=>  |%
    ++  find-tool
      |=  [tn=@t b=ball:tarball]
      ^-  (unit tool:tools)
      =/  dirs=(list @ta)  ~[%std %cus]
      |-
      ?~  dirs  ~
      =/  sub=ball:tarball  (~(gut by dir.b) i.dirs *ball:tarball)
      =/  found=(unit tool:tools)  (search tn sub)
      ?^  found  found
      $(dirs t.dirs)
    ::
    ++  search
      |=  [tn=@t b=ball:tarball]
      ^-  (unit tool:tools)
      =/  from-files=(unit tool:tools)
        ?.  ?=(^ fil.b)  ~
        =/  files=(list [@ta content:tarball])
          ~(tap by contents.u.fil.b)
        |-
        ?~  files  ~
        =/  [* =content:tarball]  i.files
        ?.  =(%temp p.cage.content)  $(files t.files)
        =/  got=(each tool:tools tang)
          (mule |.(!<(tool:tools q.cage.content)))
        ?.  ?=(%& -.got)  $(files t.files)
        ?:  =(tn name:p.got)  `p.got
        $(files t.files)
      ?^  from-files  from-files
      =/  dirs=(list [@ta ball:tarball])  ~(tap by dir.b)
      |-
      ?~  dirs  ~
      =/  [* sub=ball:tarball]  i.dirs
      =/  found=(unit tool:tools)  (search tn sub)
      ?^  found  found
      $(dirs t.dirs)
    --
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
  =/  tool-name=@t
    (~(dog jo:json-utils [%o args.st]) /'tool_name' so:dejs:format)
  =/  tool-args=(map @t json)
    =/  v  (~(get jo:json-utils [%o args.st]) /'tool_args')
    ?~  v  ~
    ?.  ?=([%o *] u.v)  ~
    p.u.v
  ::  Look up compiled tool from /bin/
  ;<  bin-seen=seen:nexus  bind:m  (peek:io /bin [%| 1 %| /bin] ~)
  ?.  ?=([%& %ball *] bin-seen)
    (pure:m [%error 'Could not read /bin/'])
  =/  found=(unit tool:tools)
    (find-tool tool-name ball.p.bin-seen)
  ?~  found
    (pure:m [%error (crip "Tool not found: {(trip tool-name)}")])
  ::  Swap state to target tool's args and update tool name
  ;<  ~  bind:m
    (replace:io !>(`tool-state:tools`[tool-name tool-args %start *json]))
  handler.u.found
--
