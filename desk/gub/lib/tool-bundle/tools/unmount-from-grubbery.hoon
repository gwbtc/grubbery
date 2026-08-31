/<  tools  /lib/tools.hoon
::  unmount-from-grubbery: remove a Clay desk mirror from the grubbery ball
::
!:
^-  tool:tools
|%
++  name  'unmount_from_grubbery'
++  description
  ^~  %-  crip
  ;:  weld
    "Unmount a Clay desk from the grubbery ball. "
    "Removes /sys/clay/desks/[desk] and cancels the Clay subscription."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  (malt ~[['desk' [%string 'Desk name (e.g. "test")']]])
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
  ;<  ~  bind:m
    (poke:io &+&+[/sys/clay %'main.clay-state'] [[/ %unmount-desk] dek])
  (pure:m [%text (crip "Unmounted %{(trip dek)} from /sys/clay/desks/{(trip dek)}")])
--
