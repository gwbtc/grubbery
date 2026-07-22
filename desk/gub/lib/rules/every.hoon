::  every: fixed period from the anchor. args: period=@dr.
::  Use frame %wall zone=~ — the phase is real time, not wall-clock.
::
/<  rules  /lib/rules.hoon
^-  kind:rules
|=  [args=* start=@da idx=@ud]
^-  (unit @da)
=/  period=@dr  ;;(@dr args)
?:  =(0 period)  ~
`(add start (mul idx period))
