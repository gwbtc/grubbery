/<  tools  /lib/nex/tools.hoon
::  cal-add-event: add an event to a calendar instance
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
    "'rdate' (a bare recurring date [month day] — birthdays, holidays). "
    "timed/allday need kind + start + its args: once, every (period_min), "
    "daily (at_min), weekly (days='mon,wed,fri' + at_min), monthly "
    "(day=N + at_min), monthly-nth (ord + day=weekday + at_min), yearly "
    "(month=N + day=N + at_min). at_min is minutes after local midnight "
    "(570 = 09:30). count ends the series after N occurrences. rdate needs "
    "only month + day."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'Calendar instance dir (e.g. "/apps/calendar.calendar")']]
      ['name' [%string 'Event name']]
      ['cat' [%string 'timed | allday | rdate (default timed)']]
      ['kind' [%string 'timed/allday: once|every|daily|weekly|monthly|monthly-nth|yearly']]
      ['start' [%string 'timed/allday anchor date, urbit format (e.g. "~2026.7.21..18.30.00")']]
      ['zone' [%string 'timed: optional IANA timezone (e.g. "America/New_York")']]
      ['at_min' [%string 'Minutes after local midnight for wall-clock kinds']]
      ['dur_min' [%string 'timed: duration in minutes (0 = a point)']]
      ['span_days' [%string 'allday: number of whole days (default 1)']]
      ['days' [%string 'weekly: comma list of weekdays (mon,wed,fri)']]
      ['day' [%string 'monthly/yearly/rdate: day number; monthly-nth: weekday name']]
      ['ord' [%string 'monthly-nth: first|second|third|fourth|last']]
      ['month' [%string 'yearly/rdate: month number 1-12']]
      ['period_min' [%string 'every: period in minutes']]
      ['count' [%string 'Optional: end the series after N occurrences']]
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
    ?.  ?=(%s -.u.j)  ''
    p.u.j
  =/  pax-parsed=(each path @t)  (parse-path:tools (gs 'path'))
  ?:  ?=(%| -.pax-parsed)
    (pure:m [%error p.pax-parsed])
  =/  cat=@t  =/(c (gs 'cat') ?:(=('' c) 'timed' c))
  =/  num
    |=  k=@t
    ^-  (unit @ud)
    (rush (gs k) dem)
  =/  split-comma
    |=  txt=@t
    ^-  (list @t)
    =/  chars=tape  (trip txt)
    =/  out=(list @t)  ~
    =/  buf=tape  ~
    |-
    ?~  chars
      ?~  buf  (flop out)
      (flop [(crip (flop buf)) out])
    ?:  =(i.chars ',')
      ?~  buf  $(chars t.chars)
      $(chars t.chars, out [(crip (flop buf)) out], buf ~)
    $(chars t.chars, buf [i.chars buf])
  =/  common=(list [@t json])
    :~  ['action' s+'add-event']
        ['cat' s+cat]
        ['name' s+(gs 'name')]
        ['note' s+(gs 'note')]
        ['color' s+(gs 'color')]
    ==
  =/  fields=(list [@t json])
    ?:  =('rdate' cat)
      ;:  weld  common
        ?~((num 'month') ~ ~[['month' (numb:enjs:format (need (num 'month')))]])
        ?~((num 'day') ~ ~[['day' (numb:enjs:format (need (num 'day')))]])
      ==
    ::  timed / allday need a start-anchored recurrence
    =/  start=(unit @da)  (slaw %da (gs 'start'))
    ?~  start  common  ::  handler errors below
    =/  ms=@ud  (div (mul (sub u.start ~1970.1.1) 1.000) ~s1)
    =/  opt
      |=  [k=@t v=(unit @ud)]
      ^-  (list [@t json])
      ?~(v ~ ~[[k (numb:enjs:format u.v)]])
    =/  kind-args=(list [@t json])
      ;:  weld
        ^-  (list [@t json])
        ~[['kind' s+(gs 'kind')] ['start_ms' (numb:enjs:format ms)]]
        (opt 'at_min' (num 'at_min'))
        (opt 'period_min' (num 'period_min'))
        (opt 'month' (num 'month'))
        (opt 'count' (num 'count'))
        ^-  (list [@t json])
        ?:(=('' (gs 'ord')) ~ ~[['ord' s+(gs 'ord')]])
        ^-  (list [@t json])
        ?:  =('' (gs 'days'))  ~
        ~[['days' %a (turn (split-comma (gs 'days')) |=(d=@t `json`s+d))]]
        ^-  (list [@t json])
        ?:  =('' (gs 'day'))  ~
        :~  :-  'day'
            ?~((rush (gs 'day') dem) s+(gs 'day') (numb:enjs:format (need (rush (gs 'day') dem))))
        ==
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
  ?:  &(!=('rdate' cat) ?=(~ (slaw %da (gs 'start'))))
    (pure:m [%error 'Bad or missing start; use e.g. ~2026.7.21..09.00.00'])
  =/  road=road:tarball  [%& %& p.pax-parsed %'calendar.calendar']
  ;<  ~  bind:m  (poke:io road [[/ %json] [%o (~(gas by *(map @t json)) fields)]])
  (pure:m [%text (crip "Event '{(trip (gs 'name'))}' added to {(trip (gs 'path'))}")])
--
