::  poke-agent: poke a Gall agent with data of a specified mark
::
!:
^-  tool:tools
|%
++  name  'poke_agent'
++  description  'Poke a Gall agent with data of a specified mark'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['agent' [%string 'Agent name (e.g. "hood")']]
      ['mark' [%string 'Poke mark (e.g. "helm-pass")']]
      ['data' [%string 'Hoon expression for the poke data (e.g. "\'my-password\'")']]
  ==
++  required  ~['agent' 'mark' 'data']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  agent=@t  (~(dog jo:json-utils [%o args.st]) /agent so:dejs:format)
  =/  mark=@t  (~(dog jo:json-utils [%o args.st]) /mark so:dejs:format)
  =/  data=@t  (~(dog jo:json-utils [%o args.st]) /data so:dejs:format)
  =/  agt=@tas  (slav %tas agent)
  =/  mar=@tas  (slav %tas mark)
  =/  res=(each vase tang)
    (mule |.((slap !>(..zuse) (ream data))))
  ?:  ?=(%| -.res)
    =/  lines=wall  (zing (turn (flop p.res) |=(=tank (wash [0 80] tank))))
    (pure:m [%error (crip "Bad hoon expression:\0a{(of-wall:format lines)}")])
  ;<  err=(unit tang)  bind:m
    (gall-poke-or-nack:io agt mar^p.res)
  ?^  err
    =/  lines=wall  (zing (turn (flop u.err) |=(=tank (wash [0 80] tank))))
    (pure:m [%error (crip "Poke nacked:\0a{(of-wall:format lines)}")])
  (pure:m [%text (crip "Poked %{(trip agt)} with %{(trip mar)}")])
--
