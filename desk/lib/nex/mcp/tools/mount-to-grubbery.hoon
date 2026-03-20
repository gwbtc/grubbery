::  mount-to-grubbery: sync a Clay desk into the grubbery ball
::
!:
^-  tool:tools
|%
++  name  'mount_to_grubbery'
++  description
  ^~  %-  crip
  ;:  weld
    "Mount a Clay desk into the grubbery ball at /sys/clay/[desk]. "
    "Files are synced and kept up to date as the desk changes."
  ==
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
  ;<  ~  bind:m
    (gall-poke-our:io %grubbery mount-desk+!>(dek))
  (pure:m [%text (crip "Mounted %{(trip dek)} to /sys/clay/{(trip dek)}")])
--
