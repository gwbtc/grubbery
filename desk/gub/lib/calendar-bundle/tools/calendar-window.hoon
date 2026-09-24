/<  tools  /lib/tools.hoon
::  calendar-window: materialized occurrences in a time window. Reads
::  the order cache and the calendar through their json marks, so the
::  tool carries no calendar library of its own.
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
    ++  da
      |=  ms=@ud
      ^-  @da
      (add ~1970.1.1 (div (mul ms ~s1) 1.000))
    ++  ms
      |=  d=@da
      ^-  @ud
      (div (mul (sub d ~1970.1.1) 1.000) ~s1)
    --
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
  =/  args=json  [%o args.st]
  =/  pax-parsed=(each path @t)  (parse-path:tools (jstr args 'path'))
  ?:  ?=(%| -.pax-parsed)
    (pure:m [%error p.pax-parsed])
  =/  pax=path  p.pax-parsed
  =/  from=(unit @da)  (slaw %da (jstr args 'from'))
  =/  to=(unit @da)    (slaw %da (jstr args 'to'))
  ?:  |(?=(~ from) ?=(~ to))
    (pure:m [%error 'Bad from/to; use urbit dates like ~2026.7.21'])
  ;<  cache-view=view:nexus  bind:m
    (peek:io [%& %& pax %'order.calendar-cache'] `[/ %json])
  ;<  cal-view=view:nexus  bind:m
    (peek:io [%& %& pax %'calendar.calendar'] `[/ %json])
  ?.  &(?=([%file *] cache-view) ?=([%file *] cal-view))
    (pure:m [%error 'No calendar (or cache) at that path'])
  =/  ca=json  (fall (mole |.(!<(json (need-vase:tarball sang.cache-view)))) *json)
  =/  c=json   (fall (mole |.(!<(json (need-vase:tarball sang.cal-view)))) *json)
  ::  names by event id
  =/  names=(map @t @t)
    %-  ~(gas by *(map @t @t))
    %+  turn  (jarr c 'events')
    |=(e=json [(jstr e 'id') (jstr (fall (jget e 'meta') *json) 'name')])
  ::  refs overlapping [from, to]; the cache lists them sorted by start
  =/  lo=@ud  (ms u.from)
  =/  hi=@ud  (ms u.to)
  ::  the order indexes a ref under both ends of its span, so it can
  ::  appear twice in the flat list; keep the first
  =/  hits=(list json)
    =|  seen=(set [@t @ud])
    =|  acc=(list json)
    =/  refs=(list json)  (jarr ca 'refs')
    |-
    ?~  refs  (flop acc)
    =/  r=json  i.refs
    =/  key=[@t @ud]  [(jstr r 'id') (jnum r 'idx')]
    ?:  (~(has in seen) key)  $(refs t.refs)
    ?.  &((lte (jnum r 'l_ms') hi) (gte (jnum r 'r_ms') lo))  $(refs t.refs)
    $(refs t.refs, seen (~(put in seen) key), acc [r acc])
  ?~  hits
    (pure:m [%text 'Nothing in that window.'])
  =/  out=tape
    %-  zing
    %+  turn  hits
    |=  r=json
    ^-  tape
    =/  id=@t  (jstr r 'id')
    =/  l=@ud  (jnum r 'l_ms')
    =/  rr=@ud  (jnum r 'r_ms')
    ;:  weld
      (scow %da (da l))
      ?:  =(l rr)  ""
      " -> {(scow %da (da rr))}"
      "  {(trip (fall (~(get by names) id) '?'))} ({(trip id)} #{(scow %ud (jnum r 'idx'))})"
      "\0a"
    ==
  (pure:m [%text (crip out)])
--
