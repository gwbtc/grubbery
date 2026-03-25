/<  tools  /lib/nex/tools.hoon
::  check-bin: check if a build artifact compiled or has errors
::
::  Looks up an artifact in bins via %code dart. Returns the
::  compilation error tang if it failed, or confirms success.
::
^-  tool:tools
|%
++  name  'check_bin'
++  description
  ^~  %-  crip
  ;:  weld
    "Check if a build artifact compiled successfully. "
    "Provide the bins path and name to look up. "
    "Example: path='/lib/mcp' name='echo' to check "
    "the compiled echo tool. Returns the error tang "
    "if compilation failed, or confirms success."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'Bins path (e.g. "/lib/mcp", "/mar", "/nex", "/das")']]
      ['name' [%string 'Artifact name without .hoon (e.g. "echo", "txt", "server")']]
  ==
++  required  ~['path' 'name']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  pax=@t  (~(dog jo:json-utils [%o args.st]) /path so:dejs:format)
  =/  nam=@t  (~(dog jo:json-utils [%o args.st]) /name so:dejs:format)
  =/  bin-path=path  (stab pax)
  =/  bin-name=@ta  (crip (trip nam))
  ;<  res=built:nexus  bind:m  (get-code-full:io /check bin-path bin-name)
  ?:  ?=(%vase -.res)
    (pure:m [%text (crip "OK: {(trip pax)}/{(trip nam)} compiled successfully")])
  ?.  ?=(%tang -.res)
    (pure:m [%text (crip "OK: {(trip pax)}/{(trip nam)} — non-vase artifact")])
  =/  rendered=tape
    %-  zing
    %+  turn  (flop tang.res)
    |=(=tank (weld ~(ram re tank) "\0a"))
  (pure:m [%error (crip "FAILED: {(trip pax)}/{(trip nam)}\0a{rendered}")])
--
