::  every: fixed period from the rule's start. args: period=@dr.
::  Use with zone=~ — "every 90 minutes" means 90 real minutes.
::
/<  rules  /lib/rules.hoon
^-  kind:rules
|=  [args=* start=@da idx=@ud]
^-  (unit [l=@da r=(unit @da)])
=/  period=@dr  ;;(@dr args)
?:  =(0 period)  ~
`[(add start (mul idx period)) ~]
