::  cron: reusable cron expression parser
::
::  pure functions for parsing cron expressions and computing
::  next fire times. no agent dependencies.
::
|%
::
::  +split-on-space: split cord on spaces into list of cords
::
++  split-on-space
  |=  txt=@t
  ^-  (list @t)
  =/  chars=tape  (trip txt)
  =/  out=(list @t)  ~
  =/  buf=tape  ~
  |-
  ?~  chars
    ?~  buf  (flop out)
    (flop [(crip (flop buf)) out])
  ?:  =(i.chars ' ')
    ?~  buf  $(chars t.chars)
    $(chars t.chars, out [(crip (flop buf)) out], buf ~)
  $(chars t.chars, buf [i.chars buf])
::
::  +split-on-comma: split cord on commas into list of cords
::
++  split-on-comma
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
::
::  +parse-cron-field: parse one cron field into a set of matching values
::    field: one of the 5 cron fields (e.g. '*', '*/5', '3', '1,15')
::    lo: minimum value for this field (e.g. 0 for minutes)
::    hi: maximum value for this field (e.g. 59 for minutes)
::
++  parse-cron-field
  |=  [field=@t lo=@ud hi=@ud]
  ^-  (set @ud)
  ::  wildcard: all values
  ?:  =(field '*')
    (silt (gulf lo hi))
  ::  step: */N
  =/  flen=@ud  (met 3 field)
  ?:  &((gte flen 3) =((end [3 2] field) '*/'))
    =/  step-cord=@t  (rsh [3 2] field)
    =/  step=@ud  (fall (rush step-cord dem) 1)
    ?:  =(0 step)  (silt (gulf lo hi))
    =/  vals=(list @ud)
      =/  n=@ud  0
      =/  acc=(list @ud)  ~
      |-
      =/  v=@ud  (add lo (mul n step))
      ?:  (gth v hi)  (flop acc)
      $(n +(n), acc [v acc])
    (silt vals)
  ::  comma-separated list or single number
  =/  parts=(list @t)  (split-on-comma field)
  =/  vals=(list @ud)
    %+  murn  parts
    |=  p=@t
    (rush p dem)
  (silt vals)
::
::  +next-cron-fire: compute next fire time from cron expression
::    cron format: "min hour dom month dow" (5 fields)
::    each field: * (any), */N (every N), N (specific), N,M (list)
::    dow: 0=Sunday, 1=Monday, ..., 6=Saturday
::
++  next-cron-fire
  |=  [expr=@t now=@da]
  ^-  (unit @da)
  =/  fields=(list @t)  (split-on-space expr)
  ?.  =((lent fields) 5)  ~
  =/  f-min=(set @ud)   (parse-cron-field (snag 0 fields) 0 59)
  =/  f-hour=(set @ud)  (parse-cron-field (snag 1 fields) 0 23)
  =/  f-dom=(set @ud)   (parse-cron-field (snag 2 fields) 1 31)
  =/  f-mon=(set @ud)   (parse-cron-field (snag 3 fields) 1 12)
  =/  f-dow=(set @ud)   (parse-cron-field (snag 4 fields) 0 6)
  ::  start from now + 1 minute, check each minute for up to 1 year
  =/  candidate=@da  (add now ~m1)
  ::  zero out seconds: rebuild with s=0 f=~
  =/  d=date  (yore candidate)
  =.  s.t.d  0
  =.  f.t.d  ~
  =.  candidate  (year d)
  =/  limit=@ud  525.600  ::  minutes in a year
  =/  idx=@ud  0
  |-
  ?:  =(idx limit)  ~
  =/  d=date  (yore candidate)
  ::  compute day of week (0=Sunday)
  ::  use the Zeller-like approach: convert to days and mod 7
  ::  epoch: ~2000.1.1 is a Saturday (dow=6)
  =/  epoch=@da  ~2000.1.1
  =/  day-diff=@ud
    ?:  (gte candidate epoch)
      (div (sub candidate epoch) ~d1)
    0
  =/  dow=@ud  (mod (add 6 day-diff) 7)
  ::  check all 5 fields
  ?.  (~(has in f-min) m.t.d)
    $(idx +(idx), candidate (add candidate ~m1))
  ?.  (~(has in f-hour) h.t.d)
    $(idx +(idx), candidate (add candidate ~m1))
  ?.  (~(has in f-dom) d.t.d)
    $(idx +(idx), candidate (add candidate ~m1))
  ?.  (~(has in f-mon) m.d)
    $(idx +(idx), candidate (add candidate ~m1))
  ?.  (~(has in f-dow) dow)
    $(idx +(idx), candidate (add candidate ~m1))
  `candidate
--
