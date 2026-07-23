::  monthly-nth: the ord-th weekday of each month at a wall-clock
::  time (second tuesday, last friday).
::  args: {ord: 'second', day: 'tue', at: minutes}
::
/<  rules  /lib/rules.hoon
^-  kind:rules
|=  [args=(map @t json) start=@da idx=@ud]
^-  (unit @da)
=/  a  ~(. ja:rules args)
=/  ord=(unit ord:rules)  (rush (str:a 'ord') (perk %first %second %third %fourth %last ~))
=/  dow=(unit wkd:rules)  (rush (str:a 'day') (perk %mon %tue %wed %thu %fri %sat %sun ~))
?:  |(?=(~ ord) ?=(~ dow))  ~
=/  =date  (yore (day-floor:rules start))
=/  [y=@ud m=@ud]  (month-add:rules y.date m.date idx)
=/  day=(unit @da)  (nth-weekday:rules y m u.ord u.dow)
?~  day  ~
`(add u.day (mins:a 'at'))
