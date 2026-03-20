::  mount-desk: mount a desk to the Unix filesystem
::
!:
^-  tool:tools
|%
++  name  'mount_desk'
++  description  'Mount a desk to the Unix filesystem'
++  parameters
  ^-  (map @t parameter-def:tools)
  (malt ~[['desk' [%string 'Desk name (e.g. "base")']]])
++  required  ~['desk']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  desk=@t  (~(dog jo:json-utils [%o args.st]) /desk so:dejs:format)
  =/  dek=@tas  (slav %tas desk)
  ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
  ;<  ~  bind:m
    (gall-poke-our:io %hood kiln-mount+!>([/(scot %p our.bowl)/[dek]/(scot %da now.bowl) dek]))
  (pure:m [%text (crip "Mounted %{(trip dek)}")])
--
