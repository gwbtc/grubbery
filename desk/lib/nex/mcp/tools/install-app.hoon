::  install-app: install a desk (local or from a remote ship)
::
!:
^-  tool:tools
|%
++  name  'install_app'
++  description  'Install a desk (local or from a remote ship)'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['desk' [%string 'Desk name to install']]
      ['ship' [%string 'Source ship (optional, defaults to own ship)']]
  ==
++  required  ~['desk']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  desk=@t  (~(dog jo:json-utils [%o args.st]) /desk so:dejs:format)
  =/  dek=@tas  (slav %tas desk)
  ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
  =/  src=@p
    ?~  ship-json=(~(get jo:json-utils [%o args.st]) /ship)
      our.bowl
    ?.  ?=([%s *] u.ship-json)  our.bowl
    (slav %p p.u.ship-json)
  ;<  ~  bind:m  (gall-poke-our:io %hood kiln-install+!>([dek src dek]))
  (pure:m [%text (crip "Installing %{(trip dek)} from {<src>}")])
--
