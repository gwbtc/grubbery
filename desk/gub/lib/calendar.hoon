::  calendar: events over the recurrence engine
::
::  An event is one of three shapes, not a rule with modifiers:
::
::    %timed   a recurrence in a zone; each tick lasts per `fin`
::             (a point, a duration, or a wall-clock end time).
::             meetings, calls.
::    %allday  a recurrence in date-space; each tick is N whole
::             days, timezone-independent. trips, conferences.
::    %rdate   a bare recurring calendar date [month day]. no clock,
::             no anchor, no bounds. birthdays, holidays.
::
::  %timed and %allday wrap a `recur` — a pure clock (idx -> moment)
::  living as a file in /lib/rules/. The recurrence is nested one
::  layer in and shared by both shapes: `weekly` is written once and
::  either shape wraps it. %rdate needs no clock at all.
::
::  The calendar grub is portable intent: config + events. The order
::  index (occurrence times -> refs) is derived state in a sibling
::  cache grub, reinflated on news, blow-away-able. Both span edges
::  are indexed so boundary-straddling occurrences are found; each
::  ref carries its full span so queries never re-evaluate.
::
/<  rules  /lib/rules.hoon
|%
+$  eid    @ta
+$  meta   [name=@t note=@t color=@t]
+$  span   span:rules
::  a clock placed in the world: a kind file + its args + the anchor
::  for idx 0. shared by %timed and %allday.
::
+$  recur  [kind=rail:tarball args=* start=@da]
::  optional clipping of the index space
::
+$  bound  [dom=(unit @ud) except=(set @ud)]
::  how a timed tick ends. %dur is the common case: start + a
::  duration (a dot is %dur ~s0), works with any recurrence. %to
::  names an absolute wall-clock end — a single event with both
::  endpoints given, never recurring.
::
+$  fin
  $%  [%dur d=@dr]
      [%to end=@da]
  ==
::
+$  event
  $%  [%timed =recur zone=(unit @t) =fin =bound =meta]
      [%allday =recur days=@ud =bound =meta]
      [%rdate month=@ud day=@ud =meta]
  ==
::
+$  calendar
  $:  title=@t
      zone=(unit @t)   ::  display zone for the UI
      horizon=@dr      ::  how far ahead the cache inflates
      events=(map eid event)
  ==
::
+$  ref    [=eid idx=@ud =span]
+$  order  ((mop @da (set ref)) lth)
+$  cache  [thru=@da =order]
++  on-order  ((on @da (set ref)) lth)
::
++  fresh-calendar  `calendar`['Calendar' ~ (mul 3 ~d365) ~]
::
::  dead-run stops rules gone quiet (once exhausted, unreachable
::  dates); fuel stops high-frequency rules exploding the index
::
++  max-dead  400
++  max-live  10.000
::
++  da-to-ms  |=(d=@da `@ud`(div (mul (sub d ~1970.1.1) 1.000) ~s1))
::
++  put-ref
  |=  [o=order at=@da r=ref]
  ^-  order
  =/  cur=(set ref)  (fall (get:on-order o at) ~)
  (put:on-order o at (~(put in cur) r))
::  +add-spans: index every realization of one occurrence, both edges
::
++  add-spans
  |=  [o=order id=eid idx=@ud spans=(list span)]
  ^-  order
  ?~  spans  o
  =.  o  (put-ref o l.i.spans [id idx i.spans])
  =?  o  !=(l.i.spans r.i.spans)
    (put-ref o r.i.spans [id idx i.spans])
  $(spans t.spans)
::  +dress-timed: a naive wall moment -> its UTC spans, per zone+fin.
::  A DST gap yields none; a fall-back overlap yields two.
::
++  dress-timed
  |=  [zone=(unit @t) =fin moment=@da]
  ^-  (list span)
  ?-    -.fin
      ::  end relative: each realized start + the duration
      %dur
    %+  turn  (realize:rules zone moment)
    |=(l=@da `span`[l (add l d.fin)])
  ::
      ::  end absolute: realize both wall-clock endpoints, pair the
      ::  earliest of each. single (non-recurring) events only.
      %to
    =/  ls=(list @da)  (realize:rules zone moment)
    =/  rs=(list @da)  (realize:rules zone end.fin)
    ?:  |(?=(~ ls) ?=(~ rs))  ~
    ~[[i.ls i.rs]]
  ==
::  +dress-allday: a naive moment -> one UTC-date span of N days
::
++  dress-allday
  |=  [days=@ud moment=@da]
  ^-  span
  =/  l=@da  (day-floor:rules moment)
  [l (add l (mul (max 1 days) ~d1))]
::  +inflate: build the order index for all events through thru
::
++  inflate
  |=  [events=(map eid event) kinds=(map rail:tarball kind:rules) thru=@da]
  ^-  order
  =/  out=order  ~
  =/  todo=(list [=eid =event])  ~(tap by events)
  |-
  ?~  todo  out
  =/  id=eid  eid.i.todo
  =/  ev=event  event.i.todo
  =.  out
    ?-    -.ev
        %rdate
      (inflate-rdate out id month.ev day.ev thru)
    ::
        %timed
      =/  k=(unit kind:rules)  (~(get by kinds) kind.recur.ev)
      ?~  k  out
      %^    walk-recur
          [out id recur.ev bound.ev u.k thru]
        idx=0  ^-  $-(@da (list span))
      |=(m=@da (dress-timed zone.ev fin.ev m))
    ::
        %allday
      =/  k=(unit kind:rules)  (~(get by kinds) kind.recur.ev)
      ?~  k  out
      %^    walk-recur
          [out id recur.ev bound.ev u.k thru]
        idx=0  ^-  $-(@da (list span))
      |=(m=@da ~[(dress-allday days.ev m)])
    ==
  $(todo t.todo)
::  +walk-recur: walk idx forward from the anchor, dressing each live
::  moment, until it passes thru or the dead/fuel guards trip
::
++  walk-recur
  |=  $:  [out=order id=eid =recur =bound k=kind:rules thru=@da]
          idx=@ud  dress=$-(@da (list span))
      ==
  ^-  order
  =/  dead=@ud  0
  =/  fuel=@ud  max-live
  |-
  ?:  |((gth dead max-dead) =(0 fuel))  out
  ?:  &(?=(^ dom.bound) (gte idx u.dom.bound))  out
  =/  moment=(unit @da)
    (fall (mole |.((k args.recur start.recur idx))) ~)
  ?~  moment  $(idx +(idx), dead +(dead))
  ?:  (gth u.moment thru)  out
  ?:  (~(has in except.bound) idx)
    $(idx +(idx), dead 0, fuel (dec fuel))
  =.  out  (add-spans out id idx (dress u.moment))
  $(idx +(idx), dead 0, fuel (dec fuel))
::  +inflate-rdate: a bare [month day] enumerated per year across
::  [1970, year-of-thru]. idx = year - 1970, a stable per-year handle.
::  Surfaces in past windows because it walks from 1970 forward.
::
++  inflate-rdate
  |=  [out=order id=eid month=@ud day=@ud thru=@da]
  ^-  order
  =/  y0=@ud  1.970
  =/  y1=@ud  y:(yore thru)
  =/  y=@ud  y0
  |-
  ?:  (gth y y1)  out
  =/  d=(unit @da)  (on-date:rules y month day)
  =?  out  ?=(^ d)
    (add-spans out id (sub y y0) ~[[u.d (add u.d ~d1)]])
  $(y +(y))
::  +window: refs whose span overlaps [from to], deduplicated. Edges
::  inside the window are the fast path; spans reaching in from the
::  left (including ones containing the whole window) are found by
::  scanning entries before from and keeping those whose stored right
::  edge crosses into it. Exact — no length bound.
::
++  window
  |=  [o=order from=@da to=@da]
  ^-  (set ref)
  =/  hits=(set ref)
    %+  roll  (tap:on-order (lot:on-order o `(sub from 1) `(add to 1)))
    |=  [[@da refs=(set ref)] acc=(set ref)]
    (~(uni in acc) refs)
  =/  left=(list [@da (set ref)])  (tap:on-order (lot:on-order o ~ `from))
  |-
  ?~  left  hits
  =/  rs=(list ref)  ~(tap in +.i.left)
  |-
  ?~  rs  ^$(left t.left)
  =?  hits  (gte r.span.i.rs from)  (~(put in hits) i.rs)
  $(rs t.rs)
::  +all-day: does this event render in date-space (no zone)?
::
++  all-day  |=(e=event ?=(?(%allday %rdate) -.e))
::  +recur-json: kind + its args, decoded per kind name
::
++  recur-json
  |=  =recur
  ^-  (list [@t json])
  =/  kname=@t  name.kind.recur
  =/  base=(list [@t json])
    :~  ['kind' s+kname]
        ['start_ms' (numb:enjs:format (da-to-ms start.recur))]
    ==
  =/  extra=(list [@t json])
    ?:  =('every' kname)
      =/  p=(unit @dr)  (mole |.(;;(@dr args.recur)))
      ?~(p ~ ~[['period_min' (numb:enjs:format (div u.p ~m1))]])
    ?:  =('daily' kname)
      =/  a=(unit @dr)  (mole |.(;;(@dr args.recur)))
      ?~(a ~ ~[['at_min' (numb:enjs:format (div u.a ~m1))]])
    ?:  =('weekly' kname)
      =/  a=(unit [days=(list wkd:rules) at=@dr])
        (mole |.(;;([(list wkd:rules) @dr] args.recur)))
      ?~  a  ~
      :~  ['days' [%a (turn days.u.a |=(d=wkd:rules `json`s+d))]]
          ['at_min' (numb:enjs:format (div at.u.a ~m1))]
      ==
    ?:  =('monthly' kname)
      =/  a=(unit [day=@ud at=@dr])  (mole |.(;;([@ud @dr] args.recur)))
      ?~  a  ~
      :~  ['day' (numb:enjs:format day.u.a)]
          ['at_min' (numb:enjs:format (div at.u.a ~m1))]
      ==
    ?:  =('monthly-nth' kname)
      =/  a=(unit [o=ord:rules d=wkd:rules at=@dr])
        (mole |.(;;([ord:rules wkd:rules @dr] args.recur)))
      ?~  a  ~
      :~  ['ord' s+o.u.a]
          ['day' s+d.u.a]
          ['at_min' (numb:enjs:format (div at.u.a ~m1))]
      ==
    ?:  =('yearly' kname)
      =/  a=(unit [m=@ud d=@ud at=@dr])  (mole |.(;;([@ud @ud @dr] args.recur)))
      ?~  a  ~
      :~  ['month' (numb:enjs:format m.u.a)]
          ['day' (numb:enjs:format d.u.a)]
          ['at_min' (numb:enjs:format (div at.u.a ~m1))]
      ==
    ~
  (weld base extra)
::  +event-json: full event breakdown for the edit form — the
::  reverse of the nexus parser, per category.
::
++  event-json
  |=  [id=@ta e=event]
  ^-  json
  =/  m=meta  ?-(-.e %timed meta.e, %allday meta.e, %rdate meta.e)
  =/  common=(list [@t json])
    :~  ['id' s+id]
        ['cat' s+-.e]
        ['name' s+name.m]
        ['note' s+note.m]
        ['color' s+color.m]
    ==
  =/  rest=(list [@t json])
    ?-    -.e
        %rdate
      :~  ['month' (numb:enjs:format month.e)]
          ['day' (numb:enjs:format day.e)]
      ==
    ::
        %timed
      =/  fin-fields=(list [@t json])
        ?-  -.fin.e
          %dur  ~[['fin' s+'dur'] ['dur_min' (numb:enjs:format (div d.fin.e ~m1))]]
          %to   ~[['fin' s+'to'] ['end_ms' (numb:enjs:format (da-to-ms end.fin.e))]]
        ==
      ;:  weld
        (recur-json recur.e)
        ^-  (list [@t json])
        :~  ['zone' `json`?~(zone.e s+'none' s+u.zone.e)]
            ['count' (numb:enjs:format (fall dom.bound.e 0))]
        ==
        fin-fields
      ==
    ::
        %allday
      %+  weld  (recur-json recur.e)
      :~  ['span_days' (numb:enjs:format days.e)]
          ['count' (numb:enjs:format (fall dom.bound.e 0))]
      ==
    ==
  [%o (~(gas by *(map @t json)) (weld common rest))]
::  +calendar-json: whole-calendar display codec for the mark
::
++  calendar-json
  |=  c=calendar
  ^-  json
  %-  pairs:enjs:format
  :~  ['title' s+title.c]
      ['zone' ?~(zone.c ~ s+u.zone.c)]
      ['horizon_days' (numb:enjs:format (div horizon.c ~d1))]
      :-  'events'
      :-  %a
      %+  turn  ~(tap by events.c)
      |=([id=@ta e=event] (event-json id e))
  ==
--
