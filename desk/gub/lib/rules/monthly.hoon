::  monthly: day N of each month at a wall-clock time; dead index
::  when the month is too short. args: {day: N, at: minutes}
::
/<  rules  /lib/rules.hoon
^-  kind:rules
|=  [args=(map @t json) start=@da idx=@ud]
^-  (unit @da)
=/  a  ~(. ja:rules args)
=/  =date  (yore (day-floor:rules start))
=/  [y=@ud m=@ud]  (month-add:rules y.date m.date idx)
=/  day=(unit @da)  (on-date:rules y m (num:a 'day'))
?~  day  ~
`(add u.day (mins:a 'at'))
