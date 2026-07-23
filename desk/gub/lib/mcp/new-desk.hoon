/<  tools  /lib/nex/tools.hoon
::  new-desk: create a new desk with default provisions
::
!:
^-  tool:tools
|%
++  name  'new_desk'
++  description
  ^~  %-  crip
  ;:  weld
    "Create a new desk with a default agent, marks, and libraries. "
    "The desk will have a minimal Gall agent and standard imports "
    "(dbug, default-agent, skeleton, verb)."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  (malt ~[['desk' [%string 'Name of the desk to create (e.g. "my-app")']]])
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
  =/  desk=@t  p.parsed
  =/  dek=@tas  (slav %tas desk)
  ;<  ~  bind:m  (create-desk:io dek)
  (pure:m [%text (crip "Created desk %{(trip dek)}")])
--
