::  yearly: a calendar date each year at a wall-clock time; dead
::  index on non-leap feb 29. args: [month=@ud day=@ud at=@dr]
::
/<  rules  /lib/rules.hoon
^-  kind:rules
|=  [args=* start=@da idx=@ud]
^-  (unit [l=@da r=(unit @da)])
=/  a  ;;([month=@ud day=@ud at=@dr] args)
=/  y=@ud  (add y:(yore (day-floor:rules start)) idx)
=/  day=(unit @da)  (on-date:rules y month.a day.a)
?~  day  ~
`[(add u.day at.a) ~]
