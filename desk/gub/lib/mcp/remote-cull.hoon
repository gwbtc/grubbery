/<  tools  /lib/nex/tools.hoon
::  remote-cull: delete a file or directory on a remote ship's grubbery
::
!:
^-  tool:tools
|%
++  name  'remote_cull'
++  description  'Delete a file or directory on a remote grubbery.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['ship' [%string 'Target ship (e.g. "~nec")']]
      ['path' [%string 'Directory path (e.g. "/hello")']]
      ['name' [%string 'Filename or subdirectory name to delete (e.g. "world")']]
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
  =/  req=load:remote:nexus
    [[/remote-cull %& pax nam] %cull ~]
  ;<  ~  bind:m
    (gall-poke:io [target %grubbery] grubbery-load+req)
  (pure:m [%text (crip "Deleted {(trip u.path-raw)}/{(trip nam)} on {(trip u.ship-raw)}")])
--
