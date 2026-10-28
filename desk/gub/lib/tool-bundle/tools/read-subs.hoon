/<  tools  /lib/tools.hoon
::  read-subs: render the agent's internal subscription table legibly
::
^-  tool:tools
|%
++  name  'read_subs'
++  description
  ^~  %-  crip
  ;:  weld
    "List all internal grubbery subscriptions. Each line shows a "
    "watched target, the watcher grub, and the subscription wire. "
    "Reads the agent's subs state as of the last committed event."
  ==
++  parameters  *(map @t parameter-def:tools)
++  required  ~
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ::  fibers never scry; route the read through the runtime's scry
  ::  service (dotket belongs to the grubbery runtime alone)
  ;<  =subs:nexus  bind:m
    (typed-scry:io subs:nexus %noun /gx/grubbery/peek/subs/noun)
  =/  render-rail
    |=  r=rail:tarball
    ^-  tape
    (spud (snoc path.r name.r))
  =/  render-watchers
    |=  [target=tape sm=subscribers:nexus]
    ^-  (list tape)
    %+  turn  ~(tap by sm)
    |=  [w=rail:tarball v=[wir=wire blot=(unit blot:tarball)]]
    :(weld target "  <-  " (render-rail w) "  on " (spud wir.v))
  =/  lines=(list tape)
    %-  zing
    %+  turn  ~(tap of fwd.subs)
    |=  [pax=path node=[dir=subscribers:nexus fil=(map @ta subscribers:nexus)]]
    ^-  (list tape)
    %+  weld
      (render-watchers (weld "dir  " (spud pax)) dir.node)
    ^-  (list tape)
    %-  zing
    %+  turn  ~(tap by fil.node)
    |=  [nam=@ta sm=subscribers:nexus]
    (render-watchers (weld "file " (spud (snoc pax nam))) sm)
  =/  out=tape
    %+  weld  "subscriptions: {(scow %ud (lent lines))}\0a"
    `tape`(zing (turn lines |=(t=tape (weld t "\0a"))))
  (pure:m [%text (crip out)])
--
