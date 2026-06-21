/<  tools  /lib/nex/tools.hoon
::  remote-sand: set weir on a remote grubbery path
::
!:
^-  tool:tools
|%
++  name  'remote_sand'
++  description  'Set or clear a weir (sandbox) on a remote grubbery path.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['ship' [%string 'Target ship (e.g. "~nec")']]
      ['path' [%string 'Directory path (e.g. "/hello")']]
      ['name' [%string 'Target name (e.g. "world")']]
      ['weir' [%string 'Weir as JSON object. Omit to clear weir.']]
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
  =/  weir-raw=(unit @t)  (~(deg jo:json-utils [%o args.st]) /weir so:dejs:format)
  ?~  ship-raw  (pure:m [%error 'Missing required argument: ship'])
  ?~  path-raw  (pure:m [%error 'Missing required argument: path'])
  ?~  name-raw  (pure:m [%error 'Missing required argument: name'])
  =/  target=@p  (slav %p u.ship-raw)
  =/  pax-parsed=(each path @t)  (parse-path:tools u.path-raw)
  ?:  ?=(%| -.pax-parsed)
    (pure:m [%error p.pax-parsed])
  =/  pax=path  p.pax-parsed
  =/  nam=@ta  u.name-raw
  =/  wer=(unit weir:nexus)
    ?~  weir-raw  ~
    =/  jon=(unit json)  (de:json:html u.weir-raw)
    ?~  jon  ~
    `(weir-from-json:nexus u.jon)
  =/  dir=path  (snoc pax nam)
  =/  req=load:remo:nexus
    [[/remote-sand %| dir] %sand wer]
  ;<  ~  bind:m
    (gall-poke:io [target %grubbery] grubbery-load+req)
  =/  msg=tape
    ?~  wer  "Cleared weir on {(spud dir)} on {(trip u.ship-raw)}"
    "Set weir on {(spud dir)} on {(trip u.ship-raw)}"
  (pure:m [%text (crip msg)])
--
