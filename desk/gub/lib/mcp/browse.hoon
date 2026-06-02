/<  tools  /lib/nex/tools.hoon
::  browse: list files and subdirectories at a path in the grubbery ball
::
!:
^-  tool:tools
|%
++  name  'browse'
++  description  'List files and subdirectories at a path in the grubbery ball'
++  parameters
  ^-  (map @t parameter-def:tools)
  (malt ~[['path' [%string 'Directory path (e.g. "/" or "/mcp.mcp")']]])
++  required  ~['path']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  parsed=(each @t tang)
    (mule |.((~(dog jo:json-utils [%o args.st]) /path so:dejs:format)))
  ?:  ?=(%| -.parsed)
    (pure:m [%error 'Missing or invalid argument: path'])
  =/  dir-path=@t  p.parsed
  =/  pax=path
    =/  t=tape  (trip dir-path)
    =/  stripped=tape
      ?:  &((gth (lent t) 1) =('/' (rear t)))
        (snip `(list @)`t)
      t
    (stab (crip stripped))
  ;<  =seen:nexus  bind:m  (peek:io [%& %| pax] ~)
  ?.  ?=([%& %ball *] seen)
    (pure:m [%error (crip "Directory not found: {(trip dir-path)}")])
  =/  neck-text=tape
    ?~  fil.ball.p.seen  ""
    ?~  neck.u.fil.ball.p.seen  ""
    "\0aNexus: {(spud (snoc path.u.neck.u.fil.ball.p.seen name.u.neck.u.fil.ball.p.seen))}"
  =/  sub-dirs=(list @ta)  ~(tap in ~(key by dir.ball.p.seen))
  =/  files=(list [@ta @tas])
    ?~  fil.ball.p.seen  ~
    %+  turn  ~(tap by contents.u.fil.ball.p.seen)
    |=([n=@ta c=sang:tarball] [n name.p.c])
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
