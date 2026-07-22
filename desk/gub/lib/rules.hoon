::  rules: typed recurrence rules
::
::  A rule is a clock: it ticks at moments. An event is a clock plus
::  how long each tick lasts (extent), in what time-frame (frame),
::  over what range (start..dom, except). Those four axes are
::  orthogonal — the kind knows nothing of them.
::
::  A kind lives as a file in the namespace (/lib/rules/<name>.hoon)
::  and is a pure point generator: [args start idx] -> the naive
::  local left-moment of occurrence idx, or ~ if that index has no
::  occurrence (april 31st, non-leap feb 29). start anchors idx 0.
::  Occurrence n is closed-form in n — no iterating, no materialized
::  schedules.
::
::  +instance dresses each tick into concrete UTC spans:
::    extent decides the right edge — %instant (a point), %dur (a
::      fixed real-time length), or %until (a wall-clock end time,
::      rolling overnight if at/before the left edge).
::    frame decides projection — %date is timezone-independent (the
::      moment is a calendar day, UTC-anchored, never zone-shifted);
::      %wall is a wall-clock instant realized through pytz (zone=~
::      is UTC), which can yield two UTC spans in a DST fall-back
::      overlap or none in a spring-forward gap.
::  Which realization to fire, and whether a past occurrence still
::  fires, is the caller's decision.
::
::  Skipping an occurrence adds its index to except=; moving one is a
::  skip plus a separate %once event. Editing the recurrence reshapes
::  the index space — clear except= when you do. Zone names are pytz
::  names ('America/New_York'); an unknown name crashes — validate at
::  write time.
::
/<  pytz  /lib/pytz.hoon
|%
+$  wkd   ?(%mon %tue %wed %thu %fri %sat %sun)
+$  ord   ?(%first %second %third %fourth %last)
+$  span  [l=@da r=@da]
::
::  a kind is a clock: idx -> a naive local moment, nothing else.
::  start anchors idx 0. ~ = this index has no occurrence (april
::  31st, non-leap feb 29). The event layer (lib/calendar) dresses
::  each moment with a shape (timed/allday) and bounds.
::
+$  kind  $-([args=* start=@da idx=@ud] (unit @da))
::
::  +realize: all UTC instants of a wall-clock instant. UTC (zone=~)
::  has exactly one; zoned gets every valid pytz conversion (none in
::  a DST gap, two in an overlap).
::
++  realize
  |=  [zone=(unit @t) local=@da]
  ^-  (list @da)
  ?~  zone  ~[local]
  (~(tz-to-utc-list zn:pytz u.zone) local)
::  +wkd-num / +num-wkd: monday-zero weekday numbering
::
++  wkd-num
  |=  w=wkd
  ^-  @ud
  ?-  w
    %mon  0
    %tue  1
    %wed  2
    %thu  3
    %fri  4
    %sat  5
    %sun  6
  ==
::
++  num-wkd
  |=  n=@ud
  ^-  wkd
  (snag (mod n 7) `(list wkd)`~[%mon %tue %wed %thu %fri %sat %sun])
::  +weekday: monday-zero weekday of a date (~2000.1.1 was a saturday)
::
++  weekday
  |=  d=@da
  ^-  @ud
  =/  raw=@ud
    %+  add  5
    ?:  (gte d ~2000.1.1)
      (mod (div (sub d ~2000.1.1) ~d1) 7)
    (sub 7 (mod +((div (sub ~2000.1.1 d) ~d1)) 7))
  (mod raw 7)
::
++  day-floor  |=(d=@da (sub d (mod d ~d1)))
::
++  days-in-month
  |=  [y=@ud m=@ud]
  ^-  @ud
  (snag (dec m) ?:((yelp y) moy:yo moh:yo))
::  +month-add: add n months to a 1-indexed [year month]
::
++  month-add
  |=  [y=@ud m=@ud n=@ud]
  ^-  [y=@ud m=@ud]
  =/  t=@ud  (add (dec m) n)
  [(add y (div t 12)) +((mod t 12))]
::  +on-date: midnight of a calendar date, ~ if it doesn't exist
::
++  on-date
  |=  [y=@ud m=@ud d=@ud]
  ^-  (unit @da)
  ?:  |(=(0 d) =(0 m) (gth m 12))  ~
  ?:  (gth d (days-in-month y m))  ~
  `(year [[%.y y] m d 0 0 0 ~])
::  +nth-weekday: the ord-th weekday of a month, ~ if absent
::
++  nth-weekday
  |=  [y=@ud m=@ud =ord w=wkd]
  ^-  (unit @da)
  =/  first=@da  (year [[%.y y] m 1 0 0 0 ~])
  =/  shift=@ud  (mod (sub (add (wkd-num w) 7) (weekday first)) 7)
  =/  dom=@ud  +(shift)
  =/  len=@ud  (days-in-month y m)
  =/  day=@ud
    ?-    ord
      %first   dom
      %second  (add dom 7)
      %third   (add dom 14)
      %fourth  (add dom 21)
    ::
        %last
      =/  d=@ud  (add dom 28)
      ?:((lte d len) d (sub d 7))
    ==
  ?:  (gth day len)  ~
  `(year [[%.y y] m day 0 0 0 ~])
--
