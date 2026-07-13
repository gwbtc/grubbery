/<  tools  /lib/nex/tools.hoon
::  read-weir: show sandbox rules on a directory
::
!:
=<  ^-  tool:tools
    |%
    ++  name  'read_weir'
    ++  description  'Read sandbox (weir) rules from a directory. Shows make/poke/peek rules.'
    ++  parameters
      ^-  (map @t parameter-def:tools)
      %-  ~(gas by *(map @t parameter-def:tools))
      :~  ['path' [%string 'Directory to read weir from (e.g. "/claw.claw_app/agents/test/")']]
      ==
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
      =/  weir-path=@t  p.parsed
      =/  dir-pax=path
        =/  t=tape  (trip weir-path)
        =/  clean=tape  ?:(&(!=(~ t) =('/' (rear t))) (snip t) t)
        ?~  clean  /
        (stab (crip clean))
      ?~  dir-pax
        (pure:m [%text 'Cannot read weir on root'])
      =/  parent=path  (snip `path`dir-pax)
      =/  child-name=@ta  (rear dir-pax)
      ;<  parent-seen=seen:nexus  bind:m  (peek:io [%& %| parent] ~)
      ?.  ?=([%& %ball *] parent-seen)
        (pure:m [%text 'No parent directory found'])
      =/  child-ball=(unit ball:tarball)  (~(get by dir.ball.p.parent-seen) child-name)
      ?~  child-ball
        (pure:m [%text 'No directory found at that path'])
      =/  weir-here=(unit weir:nexus)  ?~(fil.u.child-ball ~ weir.u.fil.u.child-ball)
      ?~  weir-here
        (pure:m [%text (crip "Weir at {(trip weir-path)}: NONE (unrestricted)")])
      =/  w=weir:nexus  u.weir-here
      =/  out=tape
        ;:  weld
          "Weir at {(trip weir-path)}:\0a"
          "  make (write): {(render-rules make.w)}\0a"
          "  poke: {(render-rules poke.w)}\0a"
          "  peek (read): {(render-rules peek.w)}"
        ==
      (pure:m [%text (crip out)])
    --
::
|%
++  render-rules
  |=  rules=(set road:tarball)
  ^-  tape
  ?:  =(~ rules)  "BLOCKED (empty set)"
  %-  zing
  %+  join  ", "
  ^-  (list tape)
  %+  turn  ~(tap in rules)
  |=  r=road:tarball
  ?-  -.r
      %&
    =/  =lane:tarball  p.r
    ?-  -.lane
      %&  "{(spud path.p.lane)}/{(trip name.p.lane)}"
      %|  "{(spud p.lane)}/"
    ==
      %|
    =/  =bend:tarball  p.r
    =/  ups=tape
      ?:  =(0 p.bend)  "./"
      (zing (turn (gulf 1 p.bend) |=(* "../")))
    =/  =lane:tarball  q.bend
    ?-  -.lane
      %&  "{ups}{(spud path.p.lane)}/{(trip name.p.lane)}"
      %|  "{ups}{(spud p.lane)}/"
    ==
  ==
--
