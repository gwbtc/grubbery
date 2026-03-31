/<  tools  /lib/nex/tools.hoon
::  desk-version: get the current version of a desk
::
!:
^-  tool:tools
|%
++  name  'desk_version'
++  description  'Get the current version of a desk'
++  parameters
  ^-  (map @t parameter-def:tools)
  (malt ~[['desk' [%string 'Desk name (e.g. "base")']]])
++  required  ~['desk']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  parsed=(each @t tang)
    (mule |.((~(dog jo:json-utils [%o args.st]) /desk so:dejs:format)))
  ?:  ?=(%| -.parsed)
    (pure:m [%error 'Missing or invalid argument: desk'])
  =/  dek=@tas  p.parsed
  ;<  =cass:clay  bind:m  (do-scry:io cass:clay /scry /cw/[dek])
  =/  result=tape
    ;:  weld
      "Desk: {(trip dek)}\0a"
      "Version: {<ud.cass>}\0a"
      "Date: {(scow %da da.cass)}"
    ==
  (pure:m [%text (crip result)])
--
