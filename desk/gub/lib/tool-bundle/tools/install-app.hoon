/<  tools  /lib/tools.hoon
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
  =/  parsed=(each @t tang)
    (mule |.((~(dog jo:json-utils [%o args.st]) /desk so:dejs:format)))
  ?:  ?=(%| -.parsed)
    (pure:m [%error 'Missing or invalid argument: desk'])
  =/  desk=@t  p.parsed
  =/  dek=@tas  (slav %tas desk)
  ;<  our=@p  bind:m  get-our:io
  =/  src=@p
    ?~  ship-json=(~(get jo:json-utils [%o args.st]) /ship)
      our
    ?.  ?=([%s *] u.ship-json)  our
    (slav %p p.u.ship-json)
  ;<  ~  bind:m  (gall-poke-our:io %hood kiln-install+[dek src dek])
  (pure:m [%text (crip "Installing %{(trip dek)} from {<src>}")])
--
