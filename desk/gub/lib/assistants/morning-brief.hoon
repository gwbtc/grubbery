::  morning-brief: an intelligent morning summary of today's calendar,
::  shaped by ./context.md in the instance dir. Falls back to a plain
::  listing if the LLM call fails.
::
::  args: { "calendar": "/apps/calendar.calendar/calendar.calendar",
::          "model": "claude-sonnet-4-6",
::          "zone": "America/New_York" }              (display zone hint)
::
/<  cal    /lib/calendar.hoon
/<  rules  /lib/rules.hoon
/<  asst   /lib/assistant.hoon
=<  ^-  assistant:asst
    |=  [args=json now=@da]
    =/  m  (fiber:fiber:nexus ,output:asst)
    ^-  form:m
    =/  base=path   (cal-path args)
    =/  model=@t    (arg-or args 'model' 'claude-sonnet-4-6')
    =/  dz=@t       (arg-or args 'zone' 'America/New_York')
    =/  from=@da    (day-floor:rules now)
    ;<  ca=cache:cal       bind:m  (read-cache base)
    ;<  c=calendar:cal     bind:m  (read-calendar base)
    ;<  ctx=@t             bind:m  read-context:asst
    =/  digest=tape  (digest-window c ca from (add from ~d1))
    ;<  brief=(unit @t)    bind:m  (think:asst model 500 (system-prompt dz ctx) (user-prompt digest))
    ?^  brief  (pure:m `['Morning brief' u.brief])
    (pure:m `['Morning brief' (crip digest)])
|%
::  +arg-or: string arg with a default
::
++  arg-or
  |=  [args=json k=@t default=@t]
  ^-  @t
  ?.  ?=(%o -.args)  default
  =/  j=(unit json)  (~(get by p.args) k)
  ?.  ?=([~ %s *] j)  default
  ?:(=('' p.u.j) default p.u.j)
::  +cal-path: the calendar instance dir from args
::
++  cal-path
  |=  args=json
  ^-  path
  =/  s=@t  (arg-or args 'calendar' '')
  ?:  =('' s)  /apps/[%'calendar.calendar']/[%'calendar.calendar']
  (stab s)
::  +read-cache: the calendar's inflated order index
::
++  read-cache
  |=  base=path
  =/  m  (fiber:fiber:nexus ,cache:cal)
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io [%& %& (snip `path`base) %'order.calendar-cache'] ~)
  %-  pure:m
  ?.  ?=([%file *] view)  *cache:cal
  (fall (mole |.(!<(cache:cal (need-vase:tarball sang.view)))) *cache:cal)
::  +read-calendar: the calendar grub (config + events)
::
++  read-calendar
  |=  base=path
  =/  m  (fiber:fiber:nexus ,calendar:cal)
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io [%& %& (snip `path`base) (rear base)] ~)
  %-  pure:m
  ?.  ?=([%file *] view)  fresh-calendar:cal
  (fall (mole |.(!<(calendar:cal (need-vase:tarball sang.view)))) fresh-calendar:cal)
::  +digest-window: one line per event in [from to) — "13:30-14:00
::  UTC  Name", all-day as "all day  Name". "(nothing scheduled)"
::  when empty.
::
++  digest-window
  |=  [c=calendar:cal ca=cache:cal from=@da to=@da]
  ^-  tape
  =/  refs=(list ref:cal)
    %+  sort  ~(tap in (window:cal order.ca from to))
    |=([a=ref:cal b=ref:cal] (lth l.span.a l.span.b))
  =/  lines=(list tape)
    %+  murn  refs
    |=  r=ref:cal
    ^-  (unit tape)
    =/  ev=(unit event:cal)  (~(get by events.c) eid.r)
    ?~  ev  ~
    =/  nm=tape  (trip (meta-str:cal (get-meta u.ev) 'name'))
    ?.  (all-day:cal u.ev)
      `"{(fmt-hm l.span.r)}-{(fmt-hm r.span.r)} UTC  {nm}"
    ::  all-day: say where today falls in a multi-day span (spans
    ::  are [l r) with r exclusive — the last day is r - 1d)
    =/  days=@ud  (div (sub r.span.r l.span.r) ~d1)
    ?:  (lte days 1)  `"all day  {nm}"
    =/  last=tape  (fmt-ymd (sub r.span.r ~d1))
    ?:  (gte l.span.r from)
      `"begins today, through {last}  {nm}"
    ?:  (lte r.span.r to)
      `"last day  {nm}"
    `"ongoing (since {(fmt-ymd l.span.r)}, through {last})  {nm}"
  ?~  lines  "(nothing scheduled)"
  %+  roll  `(list tape)`lines
  |=  [l=tape acc=tape]
  ?~(acc l "{acc}\0a{l}")
::  +get-meta: an event's meta regardless of shape
::
++  get-meta
  |=  e=event:cal
  ^-  meta:cal
  ?-(-.e %timed meta.e, %allday meta.e, %date meta.e)
::  +fmt-ymd: "y.m.d" from a utc instant
::
++  fmt-ymd
  |=  d=@da
  ^-  tape
  =/  t  (yore d)
  "{(scow %ud y.t)}.{(scow %ud m.t)}.{(scow %ud d.t.t)}"
::  +fmt-hm: "HH:MM" from a utc instant
::
++  fmt-hm
  |=  d=@da
  ^-  tape
  =/  t  (yore d)
  "{?:((lth h.t.t 10) "0" "")}{(scow %ud h.t.t)}:{?:((lth m.t.t 10) "0" "")}{(scow %ud m.t.t)}"
::  +system-prompt: role + style + standing context
::
++  system-prompt
  |=  [dz=@t ctx=@t]
  ^-  @t
  %-  crip
  ;:  weld
    "You are a personal assistant writing a morning brief. "
    "Be terse and concrete: 2-4 sentences, no preamble, no lists, "
    "no headers. Convert times from UTC to {(trip dz)} and present "
    "them in local clock time. Note what matters most, tight "
    "transitions, and free stretches worth using."
    ?:  =('' ctx)  ""
    "\0a\0aContext about the user:\0a{(trip ctx)}"
  ==
::  +user-prompt: the day's data
::
++  user-prompt
  |=  digest=tape
  ^-  @t
  (crip "Today's calendar (times UTC):\0a{digest}")
--
