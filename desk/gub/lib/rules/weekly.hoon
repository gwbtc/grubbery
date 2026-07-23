::  weekly: chosen weekdays at a wall-clock time.
::  args: {days: ['mon','wed','fri'], at: minutes}
::
/<  rules  /lib/rules.hoon
^-  kind:rules
|=  [args=(map @t json) start=@da idx=@ud]
^-  (unit @da)
=/  a  ~(. ja:rules args)
=/  wl=(list wkd:rules)  (wkds:a 'days')
=/  at=@dr  (mins:a 'at')
?~  wl  ~
=/  base=@da  (day-floor:rules start)
=/  shifts=(list @ud)
  %+  sort
    %+  turn  wl
    |=(w=wkd:rules (mod (sub (add (wkd-num:rules w) 7) (weekday:rules base)) 7))
  lth
=/  n=@ud  (lent shifts)
=/  days=@ud
  (add (mul 7 (div idx n)) (snag (mod idx n) shifts))
`(add (add base (mul days ~d1)) at)
