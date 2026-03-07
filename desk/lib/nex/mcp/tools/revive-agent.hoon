::  revive-agent: revive (re-initialize) a nuked Gall agent
::
!:
^-  tool:tools
|%
++  name  'revive_agent'
++  description  'Revive (re-initialize) a nuked Gall agent'
++  parameters
  ^-  (map @t parameter-def:tools)
  (malt ~[['agent' [%string 'Agent name (e.g. "chat-store")']]])
++  required  ~['agent']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  agent=@t  (~(dog jo:json-utils [%o args.st]) /agent so:dejs:format)
  =/  agt=@tas  (slav %tas agent)
  ;<  ~  bind:m  (gall-poke-our:io %hood kiln-revive+!>(agt))
  (pure:m [%text (crip "Revived %{(trip agt)}")])
--
