::  every: fixed period from the anchor. args: {period: minutes}.
::  Use frame %wall zone=~ — the phase is real time, not wall-clock.
::
/<  rules  /lib/rules.hoon
^-  kind:rules
|=  [args=(map @t json) start=@da idx=@ud]
^-  (unit @da)
=/  a  ~(. ja:rules args)
=/  period=@dr  (mins:a 'period')
?:  =(0 period)  ~
`(add start (mul idx period))
