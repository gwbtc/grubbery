::  daily: every day at a wall-clock time. args: {at: minutes} (540 = 09:00).
::
/<  rules  /lib/rules.hoon
^-  kind:rules
|=  [args=(map @t json) start=@da idx=@ud]
^-  (unit @da)
=/  at=@dr  (mins:~(. ja:rules args) 'at')
`(add (add (day-floor:rules start) (mul idx ~d1)) at)
