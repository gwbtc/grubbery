::  monthly-nth: the ord-th weekday of each month at a wall-clock
::  time (second tuesday, last friday). args: [=ord day=wkd at=@dr]
::
/<  rules  /lib/rules.hoon
^-  kind:rules
|=  [args=* start=@da idx=@ud]
^-  (unit @da)
=/  a  ;;([ord=ord:rules day=wkd:rules at=@dr] args)
=/  =date  (yore (day-floor:rules start))
=/  [y=@ud m=@ud]  (month-add:rules y.date m.date idx)
=/  day=(unit @da)  (nth-weekday:rules y m ord.a day.a)
?~  day  ~
`(add u.day at.a)
