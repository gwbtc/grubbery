/<  tools  /lib/nex/tools.hoon
::  remote-peek: peek a file or directory on a remote grubbery.
::  Routes via /sys/ames/ships/[ship]/root/[path] namespace.
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
  =/  label=tape
    ?~  name-raw  "{(trip u.path-raw)}/ on {(trip u.ship-raw)}"
    "{(trip u.path-raw)}/{(trip u.name-raw)} on {(trip u.ship-raw)}"
  ?:  ?=(%| -.seen)
    (pure:m [%error (crip "Peek blocked: {label}")])
  ?+  -.p.seen
    (pure:m [%text (crip "Peeked {label}: {<-.p.seen>}")])
      %none
    (pure:m [%text (crip "Nothing at {label}")])
      %veto
    (pure:m [%error (crip "Blocked: no permission to peek {label}")])
      %tomb
    (pure:m [%error (crip "Tombstoned: data at {label} has been removed")])
      %file
    =/  [* * =sang:tarball]  p.seen
    =/  res=(each tape tang)
      (mule |.((trip q.q:;;(mime (sang-noun:tarball sang)))))
    ?:  ?=(%& -.res)
      (pure:m [%text (crip p.res)])
    (pure:m [%text (crip "Peeked {label} ({<p.sang>})")])
      %ball
    =/  [* * b=ball:tarball]  p.seen
    =/  files=(list @ta)
      ?~(fil.b ~ ~(tap in ~(key by contents.u.fil.b)))
    =/  dirs=(list @ta)  ~(tap in ~(key by dir.b))
    (pure:m [%text (crip "Peeked {label}:\0a  dirs: {<dirs>}\0a  files: {<files>}")])
  ==
--
