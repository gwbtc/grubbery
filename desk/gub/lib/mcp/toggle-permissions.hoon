/<  tools  /lib/nex/tools.hoon
::  toggle-permissions: make Clay nodes public or private
::
!:
^-  tool:tools
|%
++  name  'toggle_permissions'
++  description  'Make Clay nodes public or private (for publishing desks as apps)'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['desk' [%string 'Desk name']]
      ['path' [%string 'Path within desk (e.g. "/")']]
      ['public' [%boolean 'Whether to make public (true) or private (false)']]
  ==
++  required  ~['desk' 'path' 'public']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  parsed=(each [@t @t ?] tang)
    %-  mule  |.
    :+  (~(dog jo:json-utils [%o args.st]) /desk so:dejs:format)
      (~(dog jo:json-utils [%o args.st]) /path so:dejs:format)
    (~(dog jo:json-utils [%o args.st]) /public bo:dejs:format)
  ?:  ?=(%| -.parsed)
    (pure:m [%error 'Missing or invalid required arguments (desk, path, public)'])
  =/  [desk=@t path-text=@t pub=?]  p.parsed
  =/  dek=@tas  (slav %tas desk)
  =/  pax=path  (stab path-text)
  ;<  ~  bind:m
    (gall-poke-our:io %hood kiln-permission+!>([dek pax pub]))
  =/  status=tape  ?:(pub "public" "private")
  (pure:m [%text (crip "Set %{(trip dek)}{(spud pax)} to {status}")])
--
