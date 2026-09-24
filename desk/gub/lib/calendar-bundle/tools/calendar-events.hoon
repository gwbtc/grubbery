/<  tools  /lib/tools.hoon
::  calendar-events: list a calendar instance's events. Reads the
::  calendar grub through its json mark, so the tool carries no
::  calendar library of its own.
::
=>  |%
    ++  jget
      |=  [j=json k=@t]
      ^-  (unit json)
      ?.(?=([%o *] j) ~ (~(get by p.j) k))
    ++  jstr
      |=  [j=json k=@t]
      ^-  @t
      =/  v  (jget j k)
      ?:(?=([~ %s *] v) p.u.v '')
    ++  jnum
      |=  [j=json k=@t]
      ^-  @ud
      =/  v  (jget j k)
      ?.  ?=([~ %n *] v)  0
      (fall (rush p.u.v dem) 0)
    ++  jarr
      |=  [j=json k=@t]
      ^-  (list json)
      =/  v  (jget j k)
      ?:(?=([~ %a *] v) p.u.v ~)
    ::  +da: an epoch-ms number as an urbit date
    ++  da
      |=  ms=@ud
      ^-  @da
      (add ~1970.1.1 (div (mul ms ~s1) 1.000))
    --
^-  tool:tools
|%
++  name  'calendar_events'
++  description
  'List every event of a calendar nexus instance: id, name, category, recurrence kind, start, zone. Occurrences in a date range are calendar_window.'
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
  =/  pax-parsed=(each path @t)  (parse-path:tools (jstr [%o args.st] 'path'))
  ?:  ?=(%| -.pax-parsed)
    (pure:m [%error p.pax-parsed])
  =/  road=road:tarball  [%& %& p.pax-parsed %'calendar.calendar']
  ;<  =view:nexus  bind:m  (peek:io road `[/ %json])
  ?.  ?=([%file *] view)
    (pure:m [%error 'No calendar at that path'])
  =/  c=json  (fall (mole |.(!<(json (need-vase:tarball sang.view)))) *json)
  =/  rows=(list json)  (jarr c 'events')
  ?~  rows
    (pure:m [%text 'No events.'])
  =/  out=tape
    %-  zing
    %+  turn  rows
    |=  e=json
    ^-  tape
    =/  meta=json  (fall (jget e 'meta') *json)
    =/  cat=@t  (jstr e 'cat')
    =/  detail=tape
      ?+    cat  (trip cat)
          %date
        "date {(scow %ud (jnum e 'month'))}/{(scow %ud (jnum e 'day'))}"
      ::
          %timed
        =/  k=tape  (trip (jstr e 'kind'))
        =/  z=@t  (jstr e 'zone')
        =/  start=tape  (scow %da (da (jnum e 'start_ms')))
        ?:  |(=('' z) =('none' z))  "{k} from {start}"
        "{k} from {start} ({(trip z)})"
      ::
          %allday
        "allday x{(scow %ud (jnum e 'span_days'))} {(trip (jstr e 'kind'))} from {(scow %da (da (jnum e 'start_ms')))}"
      ==
    "{(trip (jstr e 'id'))}: {(trip (jstr meta 'name'))}  [{detail}]\0a"
  (pure:m [%text (crip out)])
--
