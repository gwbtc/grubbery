/<  tools  /lib/nex/tools.hoon
::  remote-poke: poke a file on a remote ship's grubbery
::
!:
^-  tool:tools
|%
++  name  'remote_poke'
++  description
  ^~  %-  crip
  ;:  weld
    "Poke a file on a remote ship's grubbery. "
    "Sends a %grubbery-load %poke to the target ship."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['ship' [%string 'Target ship (e.g. "~nec")']]
      ['path' [%string 'Directory path of target file (e.g. "/hello")']]
      ['name' [%string 'Target filename (e.g. "world")']]
      ['blot' [%string 'Blot of the poke payload (e.g. "txt", "json")']]
      ['content' [%string 'Text content of the poke']]
  ==
++  required  ~['ship' 'path' 'name' 'blot' 'content']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  ship-raw=(unit @t)  (~(deg jo:json-utils [%o args.st]) /ship so:dejs:format)
  =/  path-raw=(unit @t)  (~(deg jo:json-utils [%o args.st]) /path so:dejs:format)
  =/  name-raw=(unit @t)  (~(deg jo:json-utils [%o args.st]) /name so:dejs:format)
  =/  mark-raw=(unit @t)  (~(deg jo:json-utils [%o args.st]) /blot so:dejs:format)
  =/  content-raw=(unit @t)  (~(deg jo:json-utils [%o args.st]) /content so:dejs:format)
  ?~  ship-raw    (pure:m [%error 'Missing required argument: ship'])
  ?~  path-raw    (pure:m [%error 'Missing required argument: path'])
  ?~  name-raw    (pure:m [%error 'Missing required argument: name'])
  ?~  mark-raw    (pure:m [%error 'Missing required argument: blot'])
  ?~  content-raw  (pure:m [%error 'Missing required argument: content'])
  =/  target=@p  (slav %p u.ship-raw)
  =/  pax-parsed=(each path @t)  (parse-path:tools u.path-raw)
  ?:  ?=(%| -.pax-parsed)
    (pure:m [%error p.pax-parsed])
  =/  pax=path  p.pax-parsed
  =/  nam=@ta  u.name-raw
  =/  =blot:tarball
    =/  mk-pax=path
      ?:  =('/' (end 3 u.mark-raw))  (stab u.mark-raw)
      (stab (cat 3 '/' u.mark-raw))
    ?~  mk-pax  [/ %noun]
    [(snip `path`mk-pax) (rear mk-pax)]
  =/  =noun  (to-wain:format u.content-raw)
  =/  =bask:tarball  [blot noun]
  =/  req=load:remote:nexus
    [[/remote-poke %& pax nam] %poke bask]
  ;<  ~  bind:m
    (gall-poke:io [target %grubbery] grubbery-load+req)
  (pure:m [%text (crip "Poked {(trip u.path-raw)}/{(trip nam)} on {(trip u.ship-raw)} with blot {(trip u.mark-raw)}")])
--
