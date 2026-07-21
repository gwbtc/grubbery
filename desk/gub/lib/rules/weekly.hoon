::  weekly: chosen weekdays at a wall-clock time.
::  args: [days=(list wkd) at=@dr]
::
/<  rules  /lib/rules.hoon
^-  kind:rules
|=  [args=* start=@da idx=@ud]
^-  (unit [l=@da r=(unit @da)])
=/  a  ;;([days=(list wkd:rules) at=@dr] args)
?~  days.a  ~
=/  base=@da  (day-floor:rules start)
=/  shifts=(list @ud)
  %+  sort
    %+  turn  days.a
    |=(w=wkd:rules (mod (sub (add (wkd-num:rules w) 7) (weekday:rules base)) 7))
  lth
=/  n=@ud  (lent shifts)
=/  days=@ud
  (add (mul 7 (div idx n)) (snag (mod idx n) shifts))
`[(add (add base (mul days ~d1)) at.a) ~]
