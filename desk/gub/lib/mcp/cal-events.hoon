/<  tools  /lib/nex/tools.hoon
/<  cal    /lib/cal.hoon
::  cal-events: list a calendar instance's events
::
^-  tool:tools
|%
++  name  'cal_events'
++  description
  'List all events in a calendar nexus instance: id, name, kind, start, zone.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'Calendar instance dir (e.g. "/apps/calendar.calendar")']]
  ==
++  required  ~['path']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  gs
    |=  k=@t
    ^-  @t
    =/  j=(unit json)  (~(get by args.st) k)
    ?~  j  ''
    ?.  ?=(%s -.u.j)  ''
    p.u.j
  =/  pax-parsed=(each path @t)  (parse-path:tools (gs 'path'))
  ?:  ?=(%| -.pax-parsed)
    (pure:m [%error p.pax-parsed])
  =/  road=road:tarball  [%& %& p.pax-parsed %'calendar.calendar']
  ;<  =view:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%file *] view)
    (pure:m [%error 'No calendar at that path'])
  =/  c=(unit calendar:cal)
    (mole |.(!<(calendar:cal (need-vase:tarball sang.view))))
  ?~  c
    (pure:m [%error 'Grub is not a calendar'])
  =/  rows=(list [id=@ta e=event:cal])  ~(tap by events.u.c)
  ?~  rows
    (pure:m [%text 'No events.'])
  =/  out=tape
    %-  zing
    %+  turn  `(list [id=@ta e=event:cal])`rows
    |=  [id=@ta e=event:cal]
    ^-  tape
    ;:  weld
      "{(trip id)}: {(trip name.meta.e)}"
      " [{(trip name.kind.rule.e)}]"
      " start {(scow %da start.rule.e)}"
      ?~  zone.rule.e  ""
      " ({(trip u.zone.rule.e)})"
      "\0a"
    ==
  (pure:m [%text (crip out)])
--
