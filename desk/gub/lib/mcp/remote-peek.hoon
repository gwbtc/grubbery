/<  tools  /lib/nex/tools.hoon
::  remote-peek: peek a file or directory on a remote grubbery.
::  Emits a local %peek dart with the ship parameter set.
::  The grubbery handles cross-ship negotiation (snap/want/data)
::  and the fiber suspends until the peek is discharged.
::
!:
^-  tool:tools
|%
++  name  'remote_peek'
++  description  'Peek a file or directory on a remote grubbery. Fetches content-addressed data via have/want negotiation.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['ship' [%string 'Target ship (e.g. "~nec")']]
      ['path' [%string 'Directory path (e.g. "/logbook")']]
      ['name' [%string 'Filename for file peek. Omit for directory peek.']]
      ['case' [%string 'Version number (e.g. "3"). Omit for latest.']]
  ==
++  required  ~['ship' 'path']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  ship-raw=(unit @t)  (~(deg jo:json-utils [%o args.st]) /ship so:dejs:format)
  =/  path-raw=(unit @t)  (~(deg jo:json-utils [%o args.st]) /path so:dejs:format)
  =/  name-raw=(unit @t)  (~(deg jo:json-utils [%o args.st]) /name so:dejs:format)
  =/  case-raw=(unit @t)  (~(deg jo:json-utils [%o args.st]) /case so:dejs:format)
  ?~  ship-raw  (pure:m [%error 'Missing required argument: ship'])
  ?~  path-raw  (pure:m [%error 'Missing required argument: path'])
  =/  target=@p  (slav %p u.ship-raw)
  =/  pax-parsed=(each path @t)  (parse-path:tools u.path-raw)
  ?:  ?=(%| -.pax-parsed)
    (pure:m [%error p.pax-parsed])
  =/  pax=path  p.pax-parsed
  =/  cas=(unit case:nexus)
    ?~  case-raw  ~
    `[%ud (rash u.case-raw dem)]
  =/  road=road:tarball
    ?~  name-raw  [%& %| pax]
    [%& %& pax u.name-raw]
  ;<  =seen:nexus  bind:m
    (peek-remote:io road target cas)
  =/  msg=tape
    ?~  name-raw  "Peeked {(trip u.path-raw)}/ on {(trip u.ship-raw)}"
    "Peeked {(trip u.path-raw)}/{(trip u.name-raw)} on {(trip u.ship-raw)}"
  (pure:m [%text (crip msg)])
--
