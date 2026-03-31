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
      ['name' [%string 'Artifact name (e.g. "echo", "txt", "server")']]
      ['code' [%string 'Code namespace path (default: "/code"). e.g. "/my/custom/code"']]
      ['show' [%boolean 'Show the compiled noun via +sell (default: false)']]
  ==
++  required  ~['path' 'name']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  parsed=(each [@t @t] tang)
    %-  mule  |.
    :-  (~(dog jo:json-utils [%o args.st]) /path so:dejs:format)
    (~(dog jo:json-utils [%o args.st]) /name so:dejs:format)
  ?:  ?=(%| -.parsed)
    (pure:m [%error 'Missing or invalid required arguments (path, name)'])
  =/  [pax=@t nam=@t]  p.parsed
  =/  code-ns=path
    =/  raw=(unit @t)
      ?~  p=(~(get jo:json-utils [%o args.st]) /code)  ~
      ?.  ?=([%s *] u.p)  ~
      ?:  =('' p.u.p)  ~
      `p.u.p
    ?~  raw  /code
    (stab u.raw)
  =/  show=?
    =/  p  (~(get jo:json-utils [%o args.st]) /show)
    ?~  p  %.n
    ?+  u.p  %.n
      [%b *]  p.u.p
    ==
  =/  bin-path=path  (stab pax)
  =/  bin-name=@ta  (crip (trip nam))
  ;<  res=built:nexus  bind:m  (get-code-full:io /check [%& %& (weld code-ns bin-path) bin-name])
  ?:  ?=(%vase -.res)
    =/  msg=tape  "OK: {(trip pax)}/{(trip nam)} compiled successfully"
    ?.  show
      (pure:m [%text (crip msg)])
    =/  printed=tape
      ~(ram re (sell vase.res))
    (pure:m [%text (crip "{msg}\0a\0a{printed}")])
  ?.  ?=(%tang -.res)
    (pure:m [%text (crip "OK: {(trip pax)}/{(trip nam)} — non-vase artifact")])
  =/  rendered=tape
    %-  zing
    %+  turn  (flop tang.res)
    |=(=tank (weld ~(ram re tank) "\0a"))
  (pure:m [%text (crip "FAILED: {(trip pax)}/{(trip nam)}\0a{rendered}")])
--
