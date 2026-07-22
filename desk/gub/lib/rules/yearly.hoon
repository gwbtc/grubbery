::  yearly: a calendar date each year at a wall-clock time; dead
::  index on non-leap feb 29. args: [month=@ud day=@ud at=@dr]
::
::  A fixed annual date (birthday, holiday) is this kind with an
::  early anchor (start = 1970 or the birth year) and no dom cap —
::  idx walks forward from the anchor, so it surfaces in past
::  windows too. No separate "annual" kind needed.
::
/<  rules  /lib/rules.hoon
^-  kind:rules
|=  [args=* start=@da idx=@ud]
^-  (unit @da)
=/  a  ;;([month=@ud day=@ud at=@dr] args)
=/  y=@ud  (add y:(yore (day-floor:rules start)) idx)
=/  day=(unit @da)  (on-date:rules y month.a day.a)
?~  day  ~
`(add u.day at.a)
