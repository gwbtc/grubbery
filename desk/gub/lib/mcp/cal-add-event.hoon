/<  tools  /lib/nex/tools.hoon
::  cal-add-event: add an event to a calendar instance
::
^-  tool:tools
|%
++  name  'cal_add_event'
++  description
  ^~  %-  crip
  ;:  weld
    "Add an event to a calendar nexus instance. Kinds and their args: "
    "once (start is the moment), every (period_min), daily (at_min), "
    "weekly (days='mon,wed,fri' + at_min), monthly (day=N + at_min), "
    "monthly-nth (ord=first..last + day=mon..sun + at_min), "
    "yearly (month=N + day=N + at_min). at_min is minutes after local "
    "midnight (570 = 09:30). Optional zone is an IANA name; wall-clock "
    "kinds follow it through DST. dur_min makes spans; omit for instants."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['path' [%string 'Calendar instance dir (e.g. "/apps/calendar.calendar")']]
      ['name' [%string 'Event name']]
      ['kind' [%string 'Rule kind: once|every|daily|weekly|monthly|monthly-nth|yearly']]
      ['start' [%string 'Anchor date, urbit format (e.g. "~2026.7.21" or "~2026.7.21..18.30.00")']]
      ['zone' [%string 'Optional IANA timezone (e.g. "America/New_York")']]
      ['at_min' [%string 'Minutes after local midnight for wall-clock kinds']]
      ['dur_min' [%string 'Optional duration in minutes']]
      ['days' [%string 'weekly: comma list of weekdays (mon,wed,fri)']]
      ['day' [%string 'monthly/yearly: day number; monthly-nth: weekday name']]
      ['ord' [%string 'monthly-nth: first|second|third|fourth|last']]
      ['month' [%string 'yearly: month number 1-12']]
      ['period_min' [%string 'every: period in minutes']]
      ['note' [%string 'Optional note']]
      ['color' [%string 'Optional hex color']]
  ==
++  required  ~['path' 'name' 'kind' 'start']
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
  =/  start=(unit @da)  (slaw %da (gs 'start'))
  ?~  start
    (pure:m [%error 'Bad start date; use urbit format like ~2026.7.21..09.00.00'])
  =/  ms=@ud  (div (mul (sub u.start ~1970.1.1) 1.000) ~s1)
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
  =/  fields=(list [@t json])
    :~  ['action' s+'add-event']
        ['name' s+(gs 'name')]
        ['kind' s+(gs 'kind')]
        ['note' s+(gs 'note')]
        ['color' s+(gs 'color')]
        ['start_ms' (numb:enjs:format ms)]
    ==
  =?  fields  !=('' (gs 'zone'))  [['zone' s+(gs 'zone')] fields]
  =?  fields  ?=(^ (num 'at_min'))
    [['at_min' (numb:enjs:format (need (num 'at_min')))] fields]
  =?  fields  ?=(^ (num 'dur_min'))
    [['dur_min' (numb:enjs:format (need (num 'dur_min')))] fields]
  =?  fields  ?=(^ (num 'period_min'))
    [['period_min' (numb:enjs:format (need (num 'period_min')))] fields]
  =?  fields  ?=(^ (num 'month'))
    [['month' (numb:enjs:format (need (num 'month')))] fields]
  =?  fields  !=('' (gs 'ord'))  [['ord' s+(gs 'ord')] fields]
  =?  fields  !=('' (gs 'days'))
    :_  fields
    :-  'days'
    :-  %a
    %+  turn  (split-comma (gs 'days'))
    |=(d=@t `json`s+d)
  =?  fields  !=('' (gs 'day'))
    :_  fields
    :-  'day'
    ?~  (rush (gs 'day') dem)  s+(gs 'day')
    (numb:enjs:format (need (rush (gs 'day') dem)))
  =/  road=road:tarball  [%& %& p.pax-parsed %'calendar.calendar']
  ;<  ~  bind:m  (poke:io road [[/ %json] [%o (~(gas by *(map @t json)) fields)]])
  (pure:m [%text (crip "Event '{(trip (gs 'name'))}' added to {(trip (gs 'path'))}")])
--
