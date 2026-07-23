/<  tools  /lib/nex/tools.hoon
/<  cal    /lib/calendar.hoon
::  cal-window: materialized occurrences in a time window
::
^-  tool:tools
|%
++  name  'calendar_window'
++  description
  ^~  %-  crip
  ;:  weld
    "List a calendar's occurrences between two dates, from the "
    "inflated order cache. Times shown in UTC. Dates use urbit "
    "format (e.g. from='~2026.7.21' to='~2026.7.28')."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'Calendar instance dir (e.g. "/apps/calendar.calendar")']]
      ['from' [%string 'Window start, urbit date']]
      ['to' [%string 'Window end, urbit date']]
  ==
++  required  ~['path' 'from' 'to']
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
  =/  pax=path  p.pax-parsed
  =/  from=(unit @da)  (slaw %da (gs 'from'))
  =/  to=(unit @da)    (slaw %da (gs 'to'))
  ?:  |(?=(~ from) ?=(~ to))
    (pure:m [%error 'Bad from/to; use urbit dates like ~2026.7.21'])
  ;<  cache-view=view:nexus  bind:m
    (peek:io [%& %& pax %'order.calendar-cache'] ~)
  ;<  cal-view=view:nexus  bind:m
    (peek:io [%& %& pax %'calendar.calendar'] ~)
  ?.  &(?=([%file *] cache-view) ?=([%file *] cal-view))
    (pure:m [%error 'No calendar (or cache) at that path'])
  =/  ca=(unit cache:cal)
    (mole |.(!<(cache:cal (need-vase:tarball sang.cache-view))))
  =/  c=(unit calendar:cal)
    (mole |.(!<(calendar:cal (need-vase:tarball sang.cal-view))))
  ?:  |(?=(~ ca) ?=(~ c))
    (pure:m [%error 'Grubs are not calendar/cache'])
  =/  refs=(list ref:cal)  ~(tap in (window:cal order.u.ca u.from u.to))
  =/  sorted=(list ref:cal)
    (sort refs |=([a=ref:cal b=ref:cal] (lth l.span.a l.span.b)))
  ?~  sorted
    (pure:m [%text 'Nothing in that window.'])
  =/  out=tape
    %-  zing
    %+  turn  `(list ref:cal)`sorted
    |=  r=ref:cal
    ^-  tape
    =/  ev=(unit event:cal)  (~(get by events.u.c) eid.r)
    =/  nm=tape
      ?~  ev  "?"
      (trip (meta-str:cal ?-(-.u.ev %timed meta.u.ev, %allday meta.u.ev, %date meta.u.ev) 'name'))
    ;:  weld
      (scow %da l.span.r)
      ?:  =(l.span.r r.span.r)  ""
      " -> {(scow %da r.span.r)}"
      "  {nm} ({(trip eid.r)} #{(scow %ud idx.r)})"
      "\0a"
    ==
  (pure:m [%text (crip out)])
--
