/<  tools  /lib/tools.hoon
::  calendar-add-event: add an event to a calendar instance
::
^-  tool:tools
|%
++  name  'calendar_add_event'
++  description
  ^~  %-  crip
  ;:  weld
    "Add an event to a calendar. cat picks the shape: "
    "'timed' (a recurrence in a zone, ending after dur_min minutes), "
    "'allday' (a recurrence in date-space lasting span_days whole days), "
    "'date' (a bare recurring date [month day] — birthdays, holidays; "
    "needs only month + day). timed/allday need kind + start + args. "
    "args is a JSON object read by the kind file: "
    "once \{}, every \{period: minutes}, daily \{at: minutes}, "
    "weekly \{days: ['mon','fri'], at: minutes}, monthly \{day: N, at: minutes}, "
    "monthly-nth \{ord: 'second', day: 'tue', at: minutes}, "
    "yearly \{month: N, day: N, at: minutes}. "
    "at is minutes after local midnight (570 = 09:30). "
    "count ends the series after N occurrences."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'Calendar instance dir (e.g. "/apps/calendar.calendar")']]
      ['name' [%string 'Event name']]
      ['cat' [%string 'the event shape. One of: timed | allday | date (default: timed).']]
      ['kind' [%string 'timed/allday: the recurrence kind. One of: once | every | daily | weekly | monthly | monthly-nth | yearly.']]
      ['start' [%string 'timed/allday: anchor date in urbit format (e.g. "~2026.7.21..18.30.00")']]
      ['args' [%string 'timed/allday: the kind\'s args as a JSON object, e.g. {"days":["mon","fri"],"at":570}']]
      ['zone' [%string 'timed: optional IANA timezone (e.g. "America/New_York")']]
      ['dur_min' [%number 'timed: duration in minutes (0 = a point in time)']]
      ['span_days' [%number 'allday: number of whole days. (default: 1)']]
      ['day' [%number 'date: day of the month, 1-31']]
      ['month' [%number 'date: month of the year, 1-12']]
      ['count' [%number 'end the recurring series after this many occurrences']]
      ['note' [%string 'Optional note']]
      ['color' [%string 'Optional hex color']]
  ==
++  required  ~['path' 'name']
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
    ::  accept a string (%s) or, for a %number param, a JSON number (%n)
    ?+  u.j  ''
      [%s *]  p.u.j
      [%n *]  p.u.j
    ==
  =/  pax-parsed=(each path @t)  (parse-path:tools (gs 'path'))
  ?:  ?=(%| -.pax-parsed)
    (pure:m [%error p.pax-parsed])
  =/  cat=@t  =/(c (gs 'cat') ?:(=('' c) 'timed' c))
  =/  num
    |=  k=@t
    ^-  (unit @ud)
    (rush (gs k) dem)
  =/  opt
    |=  [k=@t v=(unit @ud)]
    ^-  (list [@t json])
    ?~(v ~ ~[[k (numb:enjs:format u.v)]])
  =/  meta=json
    :-  %o
    %-  ~(gas by *(map @t json))
    ^-  (list [@t json])
    ;:  weld
      ^-  (list [@t json])
      ~[['name' s+(gs 'name')]]
      ^-  (list [@t json])
      ?:(=('' (gs 'note')) ~ ~[['note' s+(gs 'note')]])
      ^-  (list [@t json])
      ?:(=('' (gs 'color')) ~ ~[['color' s+(gs 'color')]])
    ==
  =/  common=(list [@t json])
    :~  ['action' s+'add-event']
        ['cat' s+cat]
        ['meta' meta]
    ==
  =/  fields=(list [@t json])
    ?:  =('date' cat)
      ;:  weld  common
        (opt 'month' (num 'month'))
        (opt 'day' (num 'day'))
      ==
    ::  timed / allday need a start-anchored recurrence
    =/  start=(unit @da)  (slaw %da (gs 'start'))
    ?~  start  common  ::  handler errors below
    =/  ms=@ud  (div (mul (sub u.start ~1970.1.1) 1.000) ~s1)
    =/  kargs=json
      =/  raw=@t  (gs 'args')
      ?:  =('' raw)  [%o ~]
      (fall (de:json:html raw) [%o ~])
    =/  kind-args=(list [@t json])
      ;:  weld
        ^-  (list [@t json])
        :~  ['kind' s+(gs 'kind')]
            ['start_ms' (numb:enjs:format ms)]
            ['args' kargs]
        ==
        (opt 'count' (num 'count'))
      ==
    =/  shape-args=(list [@t json])
      ?:  =('allday' cat)
        ~[['span_days' (numb:enjs:format (fall (num 'span_days') 1))]]
      ;:  weld
        ^-  (list [@t json])
        ?:(=('' (gs 'zone')) ~ ~[['zone' s+(gs 'zone')]])
        ^-  (list [@t json])
        ~[['fin' s+'dur'] ['dur_min' (numb:enjs:format (fall (num 'dur_min') 0))]]
      ==
    :(weld common kind-args shape-args)
  ?:  &(!=('date' cat) ?=(~ (slaw %da (gs 'start'))))
    (pure:m [%error 'Bad or missing start; use e.g. ~2026.7.21..09.00.00'])
  =/  road=road:tarball  [%& %& p.pax-parsed %'calendar.calendar']
  ;<  ~  bind:m  (poke:io road [[/ %json] [%o (~(gas by *(map @t json)) fields)]])
  (pure:m [%text (crip "Event '{(trip (gs 'name'))}' added to {(trip (gs 'path'))}")])
--
