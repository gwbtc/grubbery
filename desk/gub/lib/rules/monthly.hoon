::  monthly: day N of each month at a wall-clock time; dead index
::  when the month is too short. args: [day=@ud at=@dr]
::
/<  rules  /lib/rules.hoon
^-  kind:rules
|=  [args=* start=@da idx=@ud]
^-  (unit [l=@da r=(unit @da)])
=/  a  ;;([day=@ud at=@dr] args)
=/  =date  (yore (day-floor:rules start))
=/  [y=@ud m=@ud]  (month-add:rules y.date m.date idx)
=/  day=(unit @da)  (on-date:rules y m day.a)
?~  day  ~
`[(add u.day at.a) ~]
