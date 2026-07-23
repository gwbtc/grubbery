::  ics: minimal RFC 5545 reading — unfolding, VEVENTs, datetimes
::
::  Enough to materialize external feeds (google calendar secret
::  addresses) into ship events. Not a full ICS implementation:
::  we parse the three datetime forms (UTC Z, TZID-local, date-only)
::  and carry RRULE as raw text for the caller to translate or skip.
::
|%
::  a parsed ICS datetime
::
+$  when
  $%  [%utc d=@da]              ::  ...Z
      [%local zone=@t d=@da]    ::  ;TZID=... naive local moment
      [%day d=@da]              ::  VALUE=DATE, day-floored
  ==
+$  vevent
  $:  uid=@t
      summary=@t
      location=@t
      start=(unit when)
      end=(unit when)
      rrule=@t                  ::  raw RRULE text; '' = single event
  ==
::  +events: the one-call entry — feed body to parsed vevents
::
++  events
  |=  body=@t
  ^-  (list vevent)
  (turn (vevents (unfold body)) parse-vevent)
::  +unfold: split lines, strip \0d, join continuation lines
::
++  unfold
  |=  body=@t
  ^-  (list @t)
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
::  +vevents: collect each BEGIN:VEVENT..END:VEVENT property map.
::  Keys keep their parameters ('DTSTART;TZID=...').
::
++  vevents
  |=  lines=(list @t)
  ^-  (list (map @t @t))
  =/  out=(list (map @t @t))  ~
  =|  cur=(unit (map @t @t))
  |-
  ?~  lines  (flop out)
  ?:  =('BEGIN:VEVENT' i.lines)
    $(lines t.lines, cur `~)
  ?:  =('END:VEVENT' i.lines)
    ?~  cur  $(lines t.lines)
    $(lines t.lines, cur ~, out [u.cur out])
  ?~  cur  $(lines t.lines)
  =/  t=tape  (trip i.lines)
  =/  i=(unit @ud)  (find ":" t)
  ?~  i  $(lines t.lines)
  %=  $
    lines  t.lines
    cur  `(~(put by u.cur) (crip (scag u.i t)) (crip (slag +(u.i) t)))
  ==
::  +get-prop: value + full key (with params) for a property name
::
++  get-prop
  |=  [props=(map @t @t) pfx=@t]
  ^-  (unit [key=@t val=@t])
  %-  ~(rep by props)
  |=  [[k=@t v=@t] out=(unit [@t @t])]
  ?^  out  out
  ?:  =(pfx k)  `[k v]
  ?:  =((cat 3 pfx ';') (end [3 +((met 3 pfx))] k))  `[k v]
  ~
::
++  parse-vevent
  |=  props=(map @t @t)
  ^-  vevent
  =/  gv  |=(k=@t (fall (bind (get-prop props k) |=([@t v=@t] v)) ''))
  :*  (gv 'UID')
      (gv 'SUMMARY')
      (gv 'LOCATION')
      (parse-when props 'DTSTART')
      (parse-when props 'DTEND')
      (gv 'RRULE')
  ==
::  +parse-when: a DTSTART/DTEND property to a typed moment
::
++  parse-when
  |=  [props=(map @t @t) pfx=@t]
  ^-  (unit when)
  =/  hit=(unit [key=@t val=@t])  (get-prop props pfx)
  ?~  hit  ~
  =/  dt=(unit [d=@da z=?])  (parse-dt val.u.hit)
  ?~  dt  ~
  ?:  =(8 (met 3 val.u.hit))  `[%day d.u.dt]
  ?:  z.u.dt  `[%utc d.u.dt]
  =/  zone=@t  (key-param key.u.hit 'TZID')
  ?:  =('' zone)  `[%utc d.u.dt]   ::  floating time: treat as UTC
  `[%local zone d.u.dt]
::  +key-param: extract ;PARAM=value from a property key
::
++  key-param
  |=  [key=@t param=@t]
  ^-  @t
  =/  t=tape  (trip key)
  =/  needle=tape  ";{(trip param)}="
  =/  i=(unit @ud)  (find needle t)
  ?~  i  ''
  =/  rest=tape  (slag (add u.i (lent needle)) t)
  =/  j=(unit @ud)  (find ";" rest)
  (crip ?~(j rest (scag u.j rest)))
::  +parse-dt: 'yyyymmdd' | 'yyyymmddThhmmss[Z]' -> [@da utc?]
::
++  parse-dt
  |=  v=@t
  ^-  (unit [d=@da z=?])
  =/  nu  |=([a=@ud b=@ud] (fall (rush (cut 3 [a b] v) dem) 0))
  =/  len=@ud  (met 3 v)
  =/  yy=@ud  (nu 0 4)
  =/  mm=@ud  (nu 4 2)
  =/  dd=@ud  (nu 6 2)
  ?:  |(=(0 yy) =(0 mm) =(0 dd) (gth mm 12) (gth dd 31))  ~
  ?:  =(8 len)
    `[(year [[%.y yy] mm [dd 0 0 0 ~]]) %.n]
  ?.  |(=(15 len) =(16 len))  ~
  ?.  =('T' (cut 3 [8 1] v))  ~
  =/  utc=?  &(=(16 len) =('Z' (cut 3 [15 1] v)))
  =/  d=@da
    (year [[%.y yy] mm [dd (nu 9 2) (nu 11 2) (nu 13 2) ~]])
  `[d utc]
--
