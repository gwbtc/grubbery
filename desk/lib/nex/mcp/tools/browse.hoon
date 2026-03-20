::  browse: list files and subdirectories at a path in the grubbery ball
::
!:
^-  tool:tools
|%
++  name  'browse'
++  description  'List files and subdirectories at a path in the grubbery ball'
++  parameters
  ^-  (map @t parameter-def:tools)
  (malt ~[['path' [%string 'Directory path (e.g. "/" or "/config/creds")']]])
++  required  ~['path']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  dir-path=@t  (~(dog jo:json-utils [%o args.st]) /path so:dejs:format)
  =/  pax=path  (stab dir-path)
  ;<  =seen:nexus  bind:m  (peek:io /browse [%& %| pax] ~)
  ?.  ?=([%& %ball *] seen)
    (pure:m [%error (crip "Directory not found: {(trip dir-path)}")])
  =/  neck-text=tape
    ?~  fil.ball.p.seen  ""
    ?~  neck.u.fil.ball.p.seen  ""
    "\0aNexus: {(trip u.neck.u.fil.ball.p.seen)}"
  =/  sub-dirs=(list @ta)  ~(tap in ~(key by dir.ball.p.seen))
  =/  files=(list [@ta @tas])
    ?~  fil.ball.p.seen  ~
    %+  turn  ~(tap by contents.u.fil.ball.p.seen)
    |=([n=@ta c=content:tarball] [n p.cage.c])
  =/  dir-text=tape
    ?~  sub-dirs  ""
    %-  zing
    %+  turn  sub-dirs
    |=(d=@ta "\0a  {(trip d)}/")
  =/  file-text=tape
    ?~  files  ""
    %-  zing
    %+  turn  files
    |=([n=@ta m=@tas] "\0a  {(trip n)}")
  (pure:m [%text (crip "{(trip dir-path)}{neck-text}{dir-text}{file-text}")])
--
