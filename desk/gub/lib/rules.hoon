::  rules: typed recurrence rules
::
::  A rule is data referencing a kind by rail. Kinds live as files
::  in the namespace (/lib/rules/<name>.hoon) — adding a recurrence
::  pattern is adding a file, same as any code. A kind is a gate
::  from [args start idx] to the local edges of occurrence idx:
::
::    ~                the index doesn't exist (april 31st)
::    `[l ~]           left edge only; the rule's end= decides the right
::    `[l `r]          kind computes both edges (e.g. sunset to sunrise)
::
::  Occurrence n is closed-form in n — no iterating forward, no
::  materialized schedules. Skipping an occurrence is adding its
::  index to except=; moving one is a skip plus a separate %once
::  rule. Editing a rule's recurrence reshapes its index space —
::  clear except= when you do.
::
::  +instance turns kind output into concrete UTC spans:
::    ~[span]        the normal case
::    ~[span span]   ambiguous wall-clock time (DST fall-back overlap)
::    ~              dead index, in except=, past dom=, or a local
::                   time erased by a DST spring-forward gap
::  Which realization to fire, and whether a past occurrence still
::  fires, is entirely the caller's decision.
::
::  Kinds compute wall-clock time; zone=~ makes wall-clock and real
::  time coincide, which is what absolute kinds (once, every) want.
::  Zone names are pytz names ('America/New_York'); an unknown name
::  crashes, so validate at write time.
::
/<  pytz  /lib/pytz.hoon
|%
+$  wkd   ?(%mon %tue %wed %thu %fri %sat %sun)
+$  ord   ?(%first %second %third %fourth %last)
+$  span  [l=@da r=@da]
::
::  what /lib/rules/<name>.hoon evaluates to
::
+$  kind  $-([args=* start=@da idx=@ud] (unit [l=@da r=(unit @da)]))
::
::  the right edge of instances whose kind gives only a left edge:
::  ~ = instants (r = l); %for = fixed duration in real time;
::  %until = wall-clock time of day, rolling overnight if at/or
::  before the left edge (9pm until 2am works)
::
+$  end
  $@  ~
  $%  [%for dur=@dr]
      [%until at=@dr]
  ==
::
+$  rule
  $:  kind=rail:tarball               ::  e.g. [/lib/rules %weekly]
      args=*                          ::  kind-specific, kind-validated
      zone=(unit @t)                  ::  pytz zone name; ~ = UTC
      start=@da                       ::  anchor of the index space
      =end
      dom=(unit @ud)     ::  index cap; ~ = unbounded
      except=(set @ud)   ::  skipped indices; a moved occurrence is
  ==                     ::  a skip plus a separate %once rule
::  +instance: the UTC spans of occurrence idx. The caller resolves
::  kind.rule from the namespace and passes the compiled gate.
::
++  instance
  |=  [=rule =kind idx=@ud]
  ^-  (list span)
  ?:  &(?=(^ dom.rule) (gte idx u.dom.rule))  ~
  ?:  (~(has in except.rule) idx)  ~
  =/  got=(unit [l=@da r=(unit @da)])  (kind args.rule start.rule idx)
  ?~  got  ~
  %+  murn  (realize rule l.u.got)
  |=  l=@da
  ^-  (unit span)
  =/  r=(unit @da)  (right rule l l.u.got r.u.got)
  ?~  r  ~
  ?:  (lth u.r l)  ~
  `[l u.r]
::  +right: UTC right edge for one UTC realization of the left edge
::
++  right
  |=  [=rule l=@da local-l=@da kind-r=(unit @da)]
  ^-  (unit @da)
  ?^  kind-r  (first-after rule l u.kind-r)
  ?~  end.rule  `l
  ?-    -.end.rule
      %for
    `(add l dur.end.rule)
  ::
      %until
    =/  loc=@da  (add (day-floor local-l) at.end.rule)
    =?  loc  (lte loc local-l)  (add loc ~d1)
    (first-after rule l loc)
  ==
::  +realize: all UTC instants of a wall-clock instant. UTC rules
::  have exactly one; zoned rules get every valid conversion from
::  pytz (none in a DST gap, two in an overlap).
::
++  realize
  |=  [=rule local=@da]
  ^-  (list @da)
  ?~  zone.rule  ~[local]
  (~(tz-to-utc-list zn:pytz u.zone.rule) local)
::  +first-after: earliest UTC realization of local at/after l
::
++  first-after
  |=  [=rule l=@da local=@da]
  ^-  (unit @da)
  =/  cands=(list @da)  (realize rule local)
  |-
  ?~  cands  ~
  ?:  (gte i.cands l)  `i.cands
  $(cands t.cands)
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
