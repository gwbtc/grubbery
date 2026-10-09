/<  tools  /lib/tools.hoon
::  call-tool: invoke any tool by name, including dynamically added ones
::
!:
=<  ^-  tool:tools
    |%
++  name  'call_tool'
++  description
  ^~  %-  crip
  ;:  weld
    "Call any MCP tool by name, including dynamically added tools "
    "that are not in your cached tools/list. Use list_tools to "
    "discover available tools first. Pass the tool name and its "
    "arguments as a JSON object. A tool that lives in another tools "
    "nexus (an app's, e.g. /apps/nostr/tools) is called by naming that "
    "nexus in path. Nothing is scanned; the address is the name."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['tool_name' [%string 'Name of the tool to call (e.g. "echo", "my_custom_tool")']]
      ['tool_args' [%object 'Arguments to pass to the tool as a JSON object']]
      ['path' [%string 'A tools nexus to call into, e.g. "/apps/nostr/tools" (its tools live at <path>/code/lib/tools). Omit for this nexus\'s own tools. Apps say where theirs is in their readme.']]
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
  =/  at=(unit path)
    =/  v  (~(get by args.st) 'path')
    ?.  ?=([~ %s *] v)  ~
    ?:  =('' p.u.v)  ~
    (rush p.u.v stap)
  ::  Convert underscores to hyphens for filename lookup
  =/  file-name=@ta
    (crip (turn (trip tool-name) |=(c=@t ?:(=(c '_') '-' c))))
  ::  Look up compiled tool from bins — try our own nexus /code first,
  ::  addressed by nex-road from this file's rail (placement-independent).
  ;<  res=built:nexus  bind:m
    ?^  at  (pure:(fiber:fiber:nexus ,built:nexus) [%tang ~])
    (get-code-full:io [%| 1 [%& /code/lib/tools file-name]])
  =/  root-got=(unit tool:tools)
    ?.  ?=(%vase -.res)  ~
    =/  r=(each tool:tools tang)  (mule |.(!<(tool:tools vase.res)))
    ?:(?=(%& -.r) `p.r ~)
  ?^  root-got
    ;<  ~  bind:m
      (replace:io `tool-state:tools`[tool-name tool-args %start *json ~])
    handler.u.root-got
  ::  a tool that lives in another tools nexus RUNS THERE: the call is
  ::  relayed through that nexus's own run protocol (poke its main.sig,
  ::  await the run grub it makes, read the result), so the tool sees its
  ::  own nexus around it (a tool that finds its app by walking up, under
  ::  that app's weir), not this one. Running its compiled gate here, as
  ::  this once did, put every such tool in the wrong place.
  ?~  at
    (pure:m [%error (crip "Tool not found: {(trip tool-name)} (not one of this nexus's tools; a tool that lives elsewhere is called with path=/apps/<app>/tools)")])
  (relay u.at tool-name [%o tool-args])
--
|%
::  +relay: one run of `name` in the tools nexus at `nex` (absolute).
++  relay
  |=  [nex=path name=@t args=json]
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  id=@t  (scot %da now)
  =/  run-name=@ta  `@ta`id
  =/  main-road=road:tarball  [%& %& nex %'main.sig']
  =/  run-road=road:tarball  [%& %& (snoc nex %runs) run-name]
  ;<  *  bind:m  (keep:io /relay run-road ~)
  ;<  err=(unit tang)  bind:m
    %^  poke-soft:io  main-road  [/ %json]
    (pairs:enjs:format ~[['cmd' s+'call'] ['id' s+id] ['name' s+name] ['arguments' args]])
  ?^  err
    ;<  ~  bind:m  (drop:io /relay run-road)
    =/  why=tape  (trip (of-wain:format (turn (flop u.err) |=(t=tank (crip ~(ram re t))))))
    (pure:m [%error (crip "the tools nexus at {(spud nex)} refused the call: {why}")])
  ::  the run's %done, by its change notices, re-read every few seconds
  ::  in case a notice is lost; a run that never appears is given up on
  =/  misses=@ud  0
  ;<  res=(unit json)  bind:m
    =/  mr  (fiber:fiber:nexus ,(unit json))
    |-  ^-  form:mr
    ;<  *  bind:mr
      %^  (with-timeout:io ,wave:nexus)  /relay-poll  ~s5
      (take-news:io /relay)
    ;<  v=view:nexus  bind:mr  (peek:io run-road ~)
    ?.  ?=([%file *] v)
      ?:  (gte misses 24)  (pure:mr ~)
      $(misses +(misses))
    =/  got  (mule |.(!<(tool-state:tools (need-vase:tarball sang.v))))
    ?:  ?=(%| -.got)  $(misses +(misses))
    ?.  =(%done step.p.got)  $
    (pure:mr update.p.got)
  ;<  ~  bind:m  (drop:io /relay run-road)
  ?~  res  (pure:m [%error (crip "no result from {(trip name)} at {(spud nex)} (the run never finished)")])
  ?.  ?=([%o *] u.res)  (pure:m [%error 'the run finished without a result'])
  =/  type=@t  =/(v (~(get by p.u.res) 'type') ?:(?=([~ %s *] v) p.u.v ''))
  =/  str  |=(k=@t ^-(@t =/(v (~(get by p.u.res) k) ?:(?=([~ %s *] v) p.u.v ''))))
  ?:  =('error' type)  (pure:m [%error (str 'message')])
  ?:  =('mime' type)
    (pure:m [%text (crip "{(trip (str 'media_type'))} result, {(a-co:co (met 3 (str 'data')))} base64 bytes (view it in that nexus's runs)")])
  (pure:m [%text (str 'text')])
--
