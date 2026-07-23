/<  tools  /lib/nex/tools.hoon
::  gcal-read: fetch an ICS feed and list events in a date window
::
::  Windowed VEVENT slice for AI translation into the ship calendar
::  (calendar_add_event). No RRULE expansion: recurring events are listed
::  once at their DTSTART with a [recurs] marker — expand by hand or
::  skip. Times are raw ICS (UTC Z, TZID-local, or all-day dates).
::
^-  tool:tools
|%
++  name  'gcal_read'
++  description
  ^~  %-  crip
  ;:  weld
    "Fetch a named ICS feed (see gcal_feeds) and list its events "
    "between two dates. from/to are urbit dates (e.g. ~2026.7.21). "
    "Recurring events appear once, marked [recurs], not expanded."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['feed' [%string 'Feed name from gcal_feeds']]
      ['from' [%string 'Window start, urbit date']]
      ['to' [%string 'Window end, urbit date']]
  ==
++  required  ~['feed' 'from' 'to']
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
  =/  from=(unit @da)  (slaw %da (gs 'from'))
  =/  to=(unit @da)    (slaw %da (gs 'to'))
  ?:  |(?=(~ from) ?=(~ to))
    (pure:m [%error 'Bad from/to; use urbit dates like ~2026.7.21'])
  =/  day-num
    |=  d=@da
    ^-  @ud
    =/  =date  (yore d)
    :(add (mul y.date 10.000) (mul m.date 100) d.t.date)
  =/  lo=@ud  (day-num u.from)
  =/  hi=@ud  (day-num u.to)
  ::  look up the feed url
  =/  feeds-road=road:tarball  [%& %& /apps/[%'calendar.calendar'] %'gcal-feeds.json']
  ;<  =view:nexus  bind:m  (peek:io feeds-road ~)
  =/  url=@t
    ?.  ?=([%file *] view)  ''
    =/  j=json  (fall (mole |.(!<(json (need-vase:tarball sang.view)))) *json)
    ?.  ?=(%o -.j)  ''
    =/  v=(unit json)  (~(get by p.j) (gs 'feed'))
    ?~  v  ''
    ?.(?=(%s -.u.v) '' p.u.v)
  ?:  =('' url)
    (pure:m [%error (crip "No feed named '{(trip (gs 'feed'))}'; see gcal_feeds")])
  ~&  >  "%gcal-read: fetching {(trip (gs 'feed'))}"
  ;<  body=@t  bind:m  (fetch:io [%'GET' url ~ ~])
  ?:  =('' body)
    (pure:m [%error 'Fetch returned nothing'])
  ::  split lines, trim \0d, unfold continuations (leading space)
  =/  lines=(list @t)
    =/  raw=(list @t)  (to-wain:format body)
    =/  trimmed=(list @t)
      %+  turn  raw
      |=  l=@t
      =/  len=@ud  (met 3 l)
      ?:  =(0 len)  l
      ?.  =(13 (cut 3 [(dec len) 1] l))  l
      (cut 3 [0 (dec len)] l)
    =/  out=(list @t)  ~
    |-
    ?~  trimmed  (flop out)
    ?:  &(?=(^ out) =(' ' (cut 3 [0 1] i.trimmed)))
      %=  $
        trimmed  t.trimmed
        out  [(cat 3 i.out (cut 3 [1 (dec (met 3 i.trimmed))] i.trimmed)) t.out]
      ==
    $(trimmed t.trimmed, out [i.trimmed out])
  ::  walk lines collecting vevents in the window
  =/  rows=(list [key=@ud txt=tape])  ~
  =|  cur=(unit (map @t @t))
  |-
  ?~  lines
    =/  sorted=(list [key=@ud txt=tape])
      (sort rows |=([a=[key=@ud txt=tape] b=[key=@ud txt=tape]] (lth key.a key.b)))
    ?~  sorted  (pure:m [%text 'Nothing in that window.'])
    (pure:m [%text (crip (zing (turn sorted |=([@ud txt=tape] txt))))])
  =/  line=@t  i.lines
  ?:  =('BEGIN:VEVENT' line)
    $(lines t.lines, cur `~)
  ?:  =('END:VEVENT' line)
    ?~  cur  $(lines t.lines)
    =/  props=(map @t @t)  u.cur
    =/  gp
      |=  pfx=@t
      ^-  @t
      =/  hit=(unit @t)
        %-  ~(rep by props)
        |=  [[k=@t v=@t] out=(unit @t)]
        ?^  out  out
        ?:  =(pfx k)  `v
        ?:  =((cat 3 pfx ';') (end [3 +((met 3 pfx))] k))  `v
        ~
      (fall hit '')
    =/  dtstart=@t  (gp 'DTSTART')
    =/  key=(unit @ud)  (rush (cut 3 [0 8] dtstart) dem)
    ?:  |(?=(~ key) (lth u.key lo) (gth u.key hi))
      $(lines t.lines, cur ~)
    =/  all-day=?  =(8 (met 3 dtstart))
    =/  txt=tape
      ;:  weld
        (trip dtstart)
        =/  e=@t  (gp 'DTEND')
        ?:(=('' e) "" " -> {(trip e)}")
        "  {(trip (gp 'SUMMARY'))}"
        ?:(all-day " (all day)" "")
        ?:(=('' (gp 'RRULE')) "" " [recurs: {(trip (gp 'RRULE'))}]")
        ?:(=('' (gp 'LOCATION')) "" " @ {(trip (gp 'LOCATION'))}")
        "\0a"
      ==
    $(lines t.lines, cur ~, rows [[u.key txt] rows])
  ?~  cur  $(lines t.lines)
  =/  t=tape  (trip line)
  =/  i=(unit @ud)  (find ":" t)
  ?~  i  $(lines t.lines)
  =/  key=@t  (crip (scag u.i t))
  =/  val=@t  (crip (slag +(u.i) t))
  $(lines t.lines, cur `(~(put by u.cur) key val))
--
