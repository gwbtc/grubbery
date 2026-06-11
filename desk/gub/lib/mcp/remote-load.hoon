/<  tools  /lib/nex/tools.hoon
::  remote-load: trigger on-load for a nexus on a remote grubbery
::
!:
^-  tool:tools
|%
++  name  'remote_load'
++  description  'Trigger on-load for a nexus on a remote grubbery. The destination must be a nexus directory.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['ship' [%string 'Target ship (e.g. "~nec")']]
      ['path' [%string 'Directory path (e.g. "/logbook")']]
      ['name' [%string 'Nexus directory name (e.g. "logbook")']]
  ==
++  required  ~['ship' 'path' 'name']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  ship-raw=(unit @t)  (~(deg jo:json-utils [%o args.st]) /ship so:dejs:format)
  =/  path-raw=(unit @t)  (~(deg jo:json-utils [%o args.st]) /path so:dejs:format)
  =/  name-raw=(unit @t)  (~(deg jo:json-utils [%o args.st]) /name so:dejs:format)
  ?~  ship-raw  (pure:m [%error 'Missing required argument: ship'])
  ?~  path-raw  (pure:m [%error 'Missing required argument: path'])
  ?~  name-raw  (pure:m [%error 'Missing required argument: name'])
  =/  target=@p  (slav %p u.ship-raw)
  =/  pax-parsed=(each path @t)  (parse-path:tools u.path-raw)
  ?:  ?=(%| -.pax-parsed)
    (pure:m [%error p.pax-parsed])
  =/  pax=path  p.pax-parsed
  =/  nam=@ta  u.name-raw
  =/  dir=path  (snoc pax nam)
  =/  req=load:remote:nexus
    [[/remote-load %| dir] %load ~]
  ;<  ~  bind:m
    (gall-poke:io [target %grubbery] grubbery-load+req)
  (pure:m [%text (crip "Triggered on-load for {(spud dir)} on {(trip u.ship-raw)}")])
--
