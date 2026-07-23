::  yearly: a calendar date each year at a wall-clock time; dead
::  index on non-leap feb 29. args: {month: N, day: N, at: minutes}
::
/<  rules  /lib/rules.hoon
^-  kind:rules
|=  [args=(map @t json) start=@da idx=@ud]
^-  (unit @da)
=/  a  ~(. ja:rules args)
=/  y=@ud  (add y:(yore (day-floor:rules start)) idx)
=/  day=(unit @da)  (on-date:rules y (num:a 'month') (num:a 'day'))
?~  day  ~
`(add u.day (mins:a 'at'))
