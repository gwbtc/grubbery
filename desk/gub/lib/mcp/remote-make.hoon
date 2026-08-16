/<  tools  /lib/nex/tools.hoon
::  remote-make: create a file on a remote ship's grubbery
::
!:
^-  tool:tools
|%
++  name  'remote_make'
++  description
  ^~  %-  crip
  ;:  weld
    "Create a file on a remote ship's grubbery. "
    "Sends a %grubbery-load %make poke to the target ship."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['ship' [%string 'Target ship (e.g. "~nec")']]
      ['path' [%string 'Directory path on remote (e.g. "/hello")']]
      ['name' [%string 'Filename (e.g. "world")']]
      ['content' [%string 'Text content to write']]
      ['blot' [%string 'Target blot (e.g. "hoon", "txt"). Omit to store as mime.']]
  ==
++  required  ~['ship' 'path' 'name' 'content']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  ship-raw=(unit @t)  (~(deg jo:json-utils [%o args.st]) /ship so:dejs:format)
  =/  path-raw=(unit @t)  (~(deg jo:json-utils [%o args.st]) /path so:dejs:format)
  =/  name-raw=(unit @t)  (~(deg jo:json-utils [%o args.st]) /name so:dejs:format)
  =/  content-raw=(unit @t)  (~(deg jo:json-utils [%o args.st]) /content so:dejs:format)
  ?~  ship-raw   (pure:m [%error 'Missing required argument: ship'])
  ?~  path-raw   (pure:m [%error 'Missing required argument: path'])
  ?~  name-raw   (pure:m [%error 'Missing required argument: name'])
  ?~  content-raw  (pure:m [%error 'Missing required argument: content'])
  =/  target=@p  (slav %p u.ship-raw)
  =/  pax-parsed=(each path @t)  (parse-path:tools u.path-raw)
  ?:  ?=(%| -.pax-parsed)
    (pure:m [%error p.pax-parsed])
  =/  pax=path  p.pax-parsed
  =/  nam=@ta  u.name-raw
  =/  dest-blot=(unit blot:tarball)
    ?~  mk=(~(get jo:json-utils [%o args.st]) /blot)  ~
    ?.  ?=([%s *] u.mk)  ~
    ?:  =('' p.u.mk)  ~
    =/  pax=path
      ?:  =('/' (end 3 p.u.mk))  (stab p.u.mk)
      (stab (cat 3 '/' p.u.mk))
    ?~  pax  ~
    `[(snip `path`pax) (rear pax)]
  =/  =mime  [/text/plain (as-octs:mimes:html u.content-raw)]
  =/  =make:remo:nexus  |+[[[/ %mime] mime] dest-blot]
  =/  req=load:remo:nexus
    [[/remote-make %& pax nam] %make %.n %.n make]
  ;<  ~  bind:m
    (gall-poke:io [target %grubbery] grubbery-load+req)
  (pure:m [%text (crip "Created {(trip u.path-raw)}/{(trip nam)} on {(trip u.ship-raw)}")])
--
