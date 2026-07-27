::  open-loops: flat commitments with labels and best-by dates
::
::  Ported from the pre-grubbery %master agent. A loop is a dangling
::  intention: text, namespaced labels (energy:high, time:30m,
::  domain:hoon, ...), and an optional best-by date instead of an
::  "urgent" flag. Closing archives; nothing is lost until delete.
::
/<  iso-8601  /lib/iso-8601.hoon
=,  iso-8601
|%
::  Types
::
+$  loop
  $:  text=@t
      labels=(set @t)
      created=@da
      updated=@da
      best-by=(unit @da)
  ==
::
+$  loops
  $:  next-id=@ud
      open=(map @ud loop)
      closed=(map @ud loop)
  ==
::  Core operations
::
++  lo
  |_  =loops
  ++  open
    |=  [text=@t labels=(set @t) now=@da best-by=(unit @da)]
    ^+  loops
    =/  =loop  [text labels now now best-by]
    :*  +(next-id.loops)
        (~(put by open.loops) next-id.loops loop)
        closed.loops
    ==
  ::
  ++  close
    |=  [id=@ud now=@da]
    ^+  loops
    =/  =loop  (~(got by open.loops) id)
    =.  updated.loop  now
    :*  next-id.loops
        (~(del by open.loops) id)
        (~(put by closed.loops) id loop)
    ==
  ::
  ++  reopen
    |=  [id=@ud now=@da]
    ^+  loops
    =/  =loop  (~(got by closed.loops) id)
    =.  updated.loop  now
    :*  next-id.loops
        (~(put by open.loops) id loop)
        (~(del by closed.loops) id)
    ==
  ::
  ++  update-text
    |=  [id=@ud new-text=@t now=@da]
    ^+  loops
    ?:  (~(has by open.loops) id)
      =/  existing=loop  (~(got by open.loops) id)
      loops(open (~(put by open.loops) id existing(text new-text, updated now)))
    =/  existing=loop  (~(got by closed.loops) id)
    loops(closed (~(put by closed.loops) id existing(text new-text, updated now)))
  ::
  ++  add-label
    |=  [id=@ud label=@t now=@da]
    ^+  loops
    ?:  (~(has by open.loops) id)
      =/  existing=loop  (~(got by open.loops) id)
      loops(open (~(put by open.loops) id existing(labels (~(put in labels.existing) label), updated now)))
    =/  existing=loop  (~(got by closed.loops) id)
    loops(closed (~(put by closed.loops) id existing(labels (~(put in labels.existing) label), updated now)))
  ::
  ++  remove-label
    |=  [id=@ud label=@t now=@da]
    ^+  loops
    ?:  (~(has by open.loops) id)
      =/  existing=loop  (~(got by open.loops) id)
      loops(open (~(put by open.loops) id existing(labels (~(del in labels.existing) label), updated now)))
    =/  existing=loop  (~(got by closed.loops) id)
    loops(closed (~(put by closed.loops) id existing(labels (~(del in labels.existing) label), updated now)))
  ::
  ++  delete-loop
    |=  id=@ud
    ^+  loops
    loops(closed (~(del by closed.loops) id))
  ::
  ++  update-best-by
    |=  [id=@ud new-best-by=(unit @da) now=@da]
    ^+  loops
    ?:  (~(has by open.loops) id)
      =/  existing=loop  (~(got by open.loops) id)
      loops(open (~(put by open.loops) id existing(best-by new-best-by, updated now)))
    =/  existing=loop  (~(got by closed.loops) id)
    loops(closed (~(put by closed.loops) id existing(best-by new-best-by, updated now)))
  ::  Query helpers
  ::
  ++  get-loop
    |=  id=@ud
    ^-  (unit [open=? =loop])
    ?^  in-open=(~(get by open.loops) id)
      `[%.y u.in-open]
    ?~  in-closed=(~(get by closed.loops) id)
      ~
    `[%.n u.in-closed]
  ::
  ++  list-open
    ^-  (list [@ud loop])
    %+  sort  ~(tap by open.loops)
    |=  [a=[@ud loop] b=[@ud loop]]
    (gth updated.+.a updated.+.b)
  ::
  ++  list-closed
    ^-  (list [@ud loop])
    %+  sort  ~(tap by closed.loops)
    |=  [a=[@ud loop] b=[@ud loop]]
    (gth updated.+.a updated.+.b)
  ::
  ++  filter-by-label
    |=  [loop-list=(list [@ud loop]) label=@t]
    ^-  (list [@ud loop])
    %+  skim  loop-list
    |=([id=@ud =loop] (~(has in labels.loop) label))
  ::
  ++  filter-past-best-by
    |=  [loop-list=(list [@ud loop]) now=@da]
    ^-  (list [@ud loop])
    %+  skim  loop-list
    |=  [id=@ud =loop]
    ?~  best-by.loop  %.n
    (gth now u.best-by.loop)
  ::
  ++  sort-by-urgency
    ::  nearest best-by first; overdue loops sort before everything
    ::  (the original subtracted dates unsigned and crashed on
    ::  overdue — compare via signed distance instead)
    |=  [loop-list=(list [@ud loop]) now=@da]
    ^-  (list [@ud loop])
    =/  with-best-by=(list [@ud loop])
      %+  skim  loop-list
      |=([id=@ud =loop] ?=(^ best-by.loop))
    %+  sort  with-best-by
    |=  [a=[@ud loop] b=[@ud loop]]
    (lth (fall best-by.+.a now) (fall best-by.+.b now))
  ::
  ++  search-text
    ::  case-insensitive substring match over loop text
    |=  [loop-list=(list [@ud loop]) query=@t]
    ^-  (list [@ud loop])
    =/  q=tape  (cass (trip query))
    %+  skim  loop-list
    |=([id=@ud =loop] ?=(^ (find q (cass (trip text.loop)))))
  --
::  JSON conversions
::
++  enjs-loop
  |=  lop=loop
  ^-  json
  :-  %o
  %-  ~(gas by *(map @t json))
  :~  ['text' [%s text.lop]]
      ['labels' [%a (turn ~(tap in labels.lop) |=(l=@t [%s l]))]]
      ['created' [%s (crip (en:datetime-local created.lop))]]
      ['updated' [%s (crip (en:datetime-local updated.lop))]]
      :-  'best_by'
      ?~  best-by.lop  ~
      [%s (crip (en:date-input [[%.y y] m d.t]:(yore u.best-by.lop)))]
  ==
::
++  enjs-loops
  |=  lops=loops
  ^-  json
  :-  %o
  %-  ~(gas by *(map @t json))
  :~  ['next_id' [%n (crip (a-co:co next-id.lops))]]
      :-  'open'
      :-  %o
      %-  ~(gas by *(map @t json))
      %+  turn  ~(tap by open.lops)
      |=([id=@ud lop=loop] [(crip (a-co:co id)) (enjs-loop lop)])
      :-  'closed'
      :-  %o
      %-  ~(gas by *(map @t json))
      %+  turn  ~(tap by closed.lops)
      |=([id=@ud lop=loop] [(crip (a-co:co id)) (enjs-loop lop)])
  ==
--
