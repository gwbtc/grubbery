::  glob: search for files in the grubbery ball by path, name, and/or mark
::
!:
^-  tool:tools
|%
++  name  'glob'
++  description
  ^~  %-  crip
  ;:  weld
    "Search for files in the grubbery ball by path, name, and/or mark. "
    "All patterns support * wildcards. All filters are optional; "
    "omitted filters match everything."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'Directory path pattern (e.g. "/tools/*", "/config")']]
      ['name' [%string 'Filename pattern without extension (e.g. "config*", "*test*")']]
      ['mark' [%string 'Mark/extension pattern (e.g. "hoon", "pdf", "mime")']]
  ==
++  required  ~
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  pat-path=(unit @t)
    ?~  p=(~(get jo:json-utils [%o args.st]) /path)  ~
    ?.  ?=([%s *] u.p)  ~
    ?:  =('' p.u.p)  ~
    `p.u.p
  =/  pat-name=(unit @t)
    ?~  n=(~(get jo:json-utils [%o args.st]) /name)  ~
    ?.  ?=([%s *] u.n)  ~
    ?:  =('' p.u.n)  ~
    `p.u.n
  =/  pat-mark=(unit @t)
    ?~  mk=(~(get jo:json-utils [%o args.st]) /mark)  ~
    ?.  ?=([%s *] u.mk)  ~
    ?:  =('' p.u.mk)  ~
    `p.u.mk
  ::  Browse root to get entire ball
  ;<  =seen:nexus  bind:m  (peek:io /browse [%& %| ~] ~)
  ?.  ?=([%& %ball *] seen)
    (pure:m [%error 'Could not read ball'])
  ::  Flatten ball to list of [rail content] pairs
  =/  all-files=(list [rail:tarball content:tarball])
    ~(tap ba:tarball ball.p.seen)
  ::  Filter by patterns
  =/  matches=(list [rail:tarball @tas])
    %+  murn  all-files
    |=  [=rail:tarball =content:tarball]
    =/  file-path=tape  ?~(path.rail "/" (trip (spat path.rail)))
    =/  file-name=tape  (trip name.rail)
    =/  file-mark=tape  (trip p.cage.content)
    =/  path-ok=?
      ?~  pat-path  %.y
      (glob-match:tools (trip u.pat-path) file-path)
    =/  name-ok=?
      ?~  pat-name  %.y
      (glob-match:tools (trip u.pat-name) file-name)
    =/  mark-ok=?
      ?~  pat-mark  %.y
      (glob-match:tools (trip u.pat-mark) file-mark)
    ?.  ?&(path-ok name-ok mark-ok)  ~
    `[rail p.cage.content]
  ?~  matches
    (pure:m [%text 'No matches found'])
  =/  result=tape
    %-  zing
    %+  turn  matches
    |=  [=rail:tarball mark=@tas]
    =/  pax=tape  ?~(path.rail "/" (trip (spat path.rail)))
    "\0a{pax}/{(trip name.rail)}"
  (pure:m [%text (crip "Found {<(lent matches)>} matches:{result}")])
--
