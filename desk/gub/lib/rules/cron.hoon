::  cron: classic five-field cron as a kind. args are the parsed
::  field VALUE LISTS, not the expression string — parse at write
::  time:  {mins: [...], hrs: [...], doms: [...],
::          mons: [...], dows: [...]}
::  dows use cron numbering (0=sunday). A "*" field is the full
::  range ((gulf 0 59), (gulf 1 31), ...). Standard cron dom/dow
::  semantics: when both are restricted, a day matches if EITHER
::  matches.
::
::  Index n is the n-th firing since (day-floor start): fires per
::  matching day = |mins| x |hrs|, chronological within the day.
::  Cost is O(days walked), not O(fires). Walking 4+ years without
::  a matching day returns ~ (the rule is effectively dead there).
::
/<  rules  /lib/rules.hoon
^-  kind:rules
|=  [args=(map @t json) start=@da idx=@ud]
^-  (unit @da)
=/  a  ~(. ja:rules args)
=/  mins=(set @ud)  (silt (nums:a 'mins'))
=/  hrs=(set @ud)   (silt (nums:a 'hrs'))
=/  doms=(set @ud)  (silt (nums:a 'doms'))
=/  mons=(set @ud)  (silt (nums:a 'mons'))
=/  dows=(set @ud)  (silt (nums:a 'dows'))
=/  fpd=@ud  (mul ~(wyt in mins) ~(wyt in hrs))
?:  =(0 fpd)  ~
=/  dom-star=?  (gte ~(wyt in doms) 31)
=/  dow-star=?  (gte ~(wyt in dows) 7)
=/  hrs-l=(list @ud)   (sort ~(tap in hrs) lth)
=/  mins-l=(list @ud)  (sort ~(tap in mins) lth)
=/  target=@ud  (div idx fpd)
=/  slot=@ud    (mod idx fpd)
=/  day=@da   (day-floor:rules start)
=/  seen=@ud  0
=/  gap=@ud   0
|-
?:  (gth gap 1.466)  ~
=/  match=?
  =/  dt=date  (yore day)
  ?.  (~(has in mons) m.dt)  |
  =/  dom-hit=?  (~(has in doms) d.t.dt)
  =/  dow-hit=?  (~(has in dows) (mod +((weekday:rules day)) 7))
  ?:  &(dom-star dow-star)  &
  ?:  dom-star  dow-hit
  ?:  dow-star  dom-hit
  |(dom-hit dow-hit)
?.  match
  $(day (add day ~d1), gap +(gap))
?:  (lth seen target)
  $(day (add day ~d1), seen +(seen), gap 0)
=/  h=@ud  (snag (div slot (lent mins-l)) hrs-l)
=/  m=@ud  (snag (mod slot (lent mins-l)) mins-l)
`:(add day (mul h ~h1) (mul m ~m1))
