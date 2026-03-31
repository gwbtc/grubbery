/<  tools  /lib/nex/tools.hoon
::  nuke-agent: permanently wipe the state of a Gall agent
::
!:
^-  tool:tools
|%
++  name  'nuke_agent'
++  description  'Permanently wipe the state of a Gall agent'
++  parameters
  ^-  (map @t parameter-def:tools)
  (malt ~[['agent' [%string 'Agent name (e.g. "chat-store")']]])
++  required  ~['agent']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  parsed=(each @t tang)
    (mule |.((~(dog jo:json-utils [%o args.st]) /agent so:dejs:format)))
  ?:  ?=(%| -.parsed)
    (pure:m [%error 'Missing or invalid argument: agent'])
  =/  agent=@t  p.parsed
  =/  agt=@tas  (slav %tas agent)
  ;<  ~  bind:m  (gall-poke-our:io %hood kiln-nuke+!>([agt %.y]))
  (pure:m [%text (crip "Nuked %{(trip agt)}")])
--
