::  daily: every day at a wall-clock time. args: at=@dr (~h9 = 09:00).
::
/<  rules  /lib/rules.hoon
^-  kind:rules
|=  [args=* start=@da idx=@ud]
^-  (unit [l=@da r=(unit @da)])
=/  at=@dr  ;;(@dr args)
`[(add (add (day-floor:rules start) (mul idx ~d1)) at) ~]
