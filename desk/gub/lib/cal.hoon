::  cal: calendar types and inflation
::
::  A calendar grub is portable intent: config + events, nothing
::  else. The order index (instance times -> refs) is derived state
::  living in a sibling cache grub, rebuilt by that grub's fiber —
::  it can be blown away and reinflated at any time.
::
::  The order mop is the calendar's answer to time->index inversion:
::  the scheduler owns a cursor and never inverts; the calendar
::  inflates events forward once and answers window queries with a
::  +lot subrange. Both edges of every span are indexed, so spans
::  straddling a window boundary are still found; each ref carries
::  its full span, so queries never re-evaluate rules.
::
/<  rules  /lib/rules.hoon
|%
+$  eid   @ta
+$  meta  [name=@t note=@t color=@t]
+$  event  [=rule:rules =meta]
+$  calendar
  $:  title=@t
      zone=(unit @t)   ::  display zone for the UI
      horizon=@dr      ::  how far ahead the cache inflates
      events=(map eid event)
  ==
::
+$  ref    [=eid idx=@ud =span:rules]
+$  order  ((mop @da (set ref)) lth)
+$  cache  [thru=@da =order]
++  on-order  ((on @da (set ref)) lth)
::
++  fresh-calendar  `calendar`['Calendar' ~ ~d370 ~]
::
::  bounds per event: dead-run stops rules that have gone quiet
::  (%once exhausted, unreachable dates); fuel stops high-frequency
::  rules from exploding the index
::
++  max-dead  400
++  max-live  10.000
::
++  put-ref
  |=  [o=order at=@da r=ref]
  ^-  order
  =/  cur=(set ref)  (fall (get:on-order o at) ~)
  (put:on-order o at (~(put in cur) r))
::  +inflate: build the order index for all events through thru.
::  kinds maps each event's kind rail to its resolved gate; events
::  whose kind is missing or whose rule crashes are skipped.
::
++  inflate
  |=  [events=(map eid event) kinds=(map rail:tarball kind:rules) thru=@da]
  ^-  order
  =/  out=order  ~
  =/  todo=(list [=eid =event])  ~(tap by events)
  |-
  ?~  todo  out
  =/  kind=(unit kind:rules)  (~(get by kinds) kind.rule.event.i.todo)
  ?~  kind  $(todo t.todo)
  =/  id=eid  eid.i.todo
  =/  ru=rule:rules  rule.event.i.todo
  =/  idx=@ud  0
  =/  dead=@ud  0
  =/  fuel=@ud  max-live
  |-
  ?:  |((gth dead max-dead) =(0 fuel))  ^$(todo t.todo)
  =/  spans=(list span:rules)
    (fall (mole |.((instance:rules ru u.kind idx))) ~)
  ?~  spans
    $(idx +(idx), dead +(dead))
  ?:  (gth l.i.spans thru)  ^$(todo t.todo)
  =.  out  (add-spans out id idx spans)
  $(idx +(idx), dead 0, fuel (dec fuel))
::  +add-spans: index every realization of one instance, both edges
::
++  add-spans
  |=  [o=order id=eid idx=@ud spans=(list span:rules)]
  ^-  order
  ?~  spans  o
  =.  o  (put-ref o l.i.spans [id idx i.spans])
  =?  o  !=(l.i.spans r.i.spans)
    (put-ref o r.i.spans [id idx i.spans])
  $(spans t.spans)
::  +window: refs with any edge in [from to], deduplicated
::
++  window
  |=  [o=order from=@da to=@da]
  ^-  (set ref)
  =/  slice  (tap:on-order (lot:on-order o `(sub from 1) `(add to 1)))
  %+  roll  slice
  |=  [[@da refs=(set ref)] acc=(set ref)]
  (~(uni in acc) refs)
--
