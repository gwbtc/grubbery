::  lib/recipe: thought processes as step graphs, rendered at the tip
::
::  A recipe is a graph of steps. A step is a held intention with an aim
::  (commit convention: a title line, a blank, then the description) and
::  a set of arrows, each carrying the condition under which to take it.
::  The agent names the intention it adopts next; staying is re-choosing
::  the same step, so `self` is an ordinary arrow.
::
::  `done` is a reserved arrow target, never a step. `abort` is not in
::  the file at all: it means the same thing in every recipe, so the
::  system owns its text and guarantees it is always reachable.
::
::  Budgets live in levels, each a WHOLE budget rather than a scaling of
::  some other level. Three kinds: the run total, a per-step lifetime
::  (when spent the step becomes unreachable — not an error, you just
::  lose a destination), and a per-step dwell (one occupancy, reset on
::  leaving). A step absent from a level is unbudgeted; `life: 0` retires
::  it before the run starts. Budgets only subtract: they make a move
::  impossible, never mandatory.
::
::  Everything here is pure. The tip is assembled fresh per request and
::  never stored in the chat — see +tip's callers.
::
|%
+$  recipe
  $:  name=@t
      aim=(list @t)
      start=@t
      steps=(map @t step)
      levels=(map @t level)
  ==
::  a step's arrows: target -> the condition under which to take it.
::  targets are a step name, 'self', or 'done'.
::
+$  step  [aim=(list @t) next=(map @t @t)]
+$  level  [run=@ud caps=(map @t cap)]
+$  cap   [life=(unit @ud) dwell=(unit @ud)]
::  run state for one chat. `spent` is lifetime consumed per step,
::  `dwell` is consumed in the current occupancy, `run` is the total.
::
+$  state
  $:  name=@t
      level=@t
      step=@t
      spent=(map @t @ud)
      dwell=@ud
      run=@ud
  ==
::  +parse: a recipe file. ~ when it lacks a start or a steps object,
::  since a recipe without those cannot be entered.
::
++  parse
  |=  [nm=@t jon=json]
  ^-  (unit recipe)
  ?.  ?=([%o *] jon)  ~
  =/  start=@t  (jstr jon 'start')
  ?:  =('' start)  ~
  =/  sj=(unit json)  (~(get by p.jon) 'steps')
  ?.  ?=([~ %o *] sj)  ~
  :-  ~
  :*  nm
      (jlines (~(get by p.jon) 'aim'))
      start
      (steps-of u.sj)
      (levels-of (~(get by p.jon) 'levels'))
  ==
::  +enter: the state a fresh run starts in.
::
++  enter
  |=  [=recipe level=@t]
  ^-  state
  [name.recipe level start.recipe ~ 0 0]
::  +tick: spend one message. Called once per request, before the tip is
::  rendered, so what the agent reads is what it has left.
::
++  tick
  |=  =state
  ^-  ^state
  =/  used=@ud  (fall (~(get by spent.state) step.state) 0)
  %=  state
    run    +(run.state)
    dwell  +(dwell.state)
    spent  (~(put by spent.state) step.state +(used))
  ==
::  +move: adopt an intention. Refuses a target with no arrow from the
::  current step, and one whose budget is spent. Staying keeps the dwell
::  count; going anywhere else resets it.
::
++  move
  |=  [=recipe =state target=@t]
  ^-  (each ^state @t)
  =/  opts=(list arrow)  (open recipe state)
  |-  ^-  (each ^state @t)
  ?~  opts
    |+(crip "no arrow from {(trip step.state)} to {(trip target)}")
  ?.  =(target target.i.opts)  $(opts t.opts)
  ?.  ok.i.opts
    |+(crip "{(trip target)} is out of budget")
  ?:  =('self' target)  &+state
  &+state(step target, dwell 0)
::  +done: has the run reached its terminal.
::
++  done
  |=  =state
  ^-  ?
  =('done' step.state)
::  +stuck: nothing reachable and not finished — the graph ran out of
::  room, which is a failure exit rather than a halt.
::
++  stuck
  |=  [=recipe =state]
  ^-  ?
  ?:  (done state)  |
  ?:  =(0 (run-left recipe state))  &
  =(~ (skim (open recipe state) |=(a=arrow ok.a)))
::  an arrow as the renderer and +move see it: where, why, and whether
::  its budget leaves it open.
::
+$  arrow  [target=@t cond=@t ok=?]
::  +open: this step's arrows in a stable order — stay first, done last,
::  the rest alphabetical. Spent targets are included and marked, so a
::  caller can render them or drop them.
::
++  open
  |=  [=recipe =state]
  ^-  (list arrow)
  =/  st=(unit step)  (~(get by steps.recipe) step.state)
  ?~  st  ~
  %+  turn  (sort ~(tap by next.u.st) arrow-order)
  |=  [t=@t c=@t]
  ^-  arrow
  :+  t  c
  ?:  =('done' t)  &
  ?:  =('self' t)
    =/  d=(unit @ud)  (dwell-left recipe state)
    ?~(d & (gth u.d 0))
  =/  l=(unit @ud)  (life-left recipe state t)
  ?~(l & (gth u.l 0))
::  +cap-for: a step's budget at the run's level. Absent means
::  unbudgeted, which is not the same as zero.
::
++  cap-for
  |=  [=recipe =state nm=@t]
  ^-  cap
  =/  lv=(unit level)  (~(get by levels.recipe) level.state)
  ?~  lv  [~ ~]
  (fall (~(get by caps.u.lv) nm) [~ ~])
::  +life-left, +dwell-left: ~ when unbudgeted, else what remains.
::
++  life-left
  |=  [=recipe =state nm=@t]
  ^-  (unit @ud)
  =/  c=cap  (cap-for recipe state nm)
  ?~  life.c  ~
  =/  used=@ud  (fall (~(get by spent.state) nm) 0)
  `?:((gte used u.life.c) 0 (sub u.life.c used))
::
++  dwell-left
  |=  [=recipe =state]
  ^-  (unit @ud)
  =/  c=cap  (cap-for recipe state step.state)
  ?~  dwell.c  ~
  `?:((gte dwell.state u.dwell.c) 0 (sub u.dwell.c dwell.state))
::
++  run-left
  |=  [=recipe =state]
  ^-  @ud
  =/  lv=(unit level)  (~(get by levels.recipe) level.state)
  ?~  lv  0
  ?:((gte run.state run.u.lv) 0 (sub run.u.lv run.state))
::  +tip: what rides at the end of the request. Two registers on
::  purpose: the structural lines are facts about the run and read as
::  infrastructure, while an aim is the recipe author speaking and is
::  marked as quoted. The shape is identical every turn — anything that
::  varies in form reads as commentary rather than state.
::
++  tip
  |=  [=recipe =state]
  ^-  @t
  =/  st=(unit step)  (~(get by steps.recipe) step.state)
  %-  crip
  ;:  weld
    "<recipe-state>\0a"
    "RECIPE  "  (trip name.recipe)  "  (level "  (trip level.state)  ")\0a"
    (quoted aim.recipe)
    "\0a"
    (step-line recipe state)
    (quoted ?~(st ~ aim.u.st))
    "\0a"
    "FROM HERE  (name one to move; staying is naming 'stay')\0a"
    (arrows-block recipe state)
    "ALWAYS     abort — leave the recipe, saying what was settled and what stopped it\0a"
    "</recipe-state>\0a"
  ==
::  +step-line: the budget readout. A dash is unbudgeted, not zero.
::
++  step-line
  |=  [=recipe =state]
  ^-  tape
  ;:  weld
    "STEP  "  (trip step.state)
    "  [dwell "  (gauge (dwell-left recipe state))
    ", step "    (gauge (life-left recipe state step.state))
    ", run "     (a-co:co (run-left recipe state))
    "]\0a"
  ==
::  +arrows-block: the open arrows with their conditions. Spent ones are
::  left out rather than shown struck through: a destination you cannot
::  reach is not a choice, and listing it invites arguing with the
::  budget.
::
++  arrows-block
  |=  [=recipe =state]
  ^-  tape
  %-  zing
  %+  turn  (open recipe state)
  |=  =arrow
  ^-  tape
  ?.  ok.arrow  ""
  =/  label=tape  ?:(=('self' target.arrow) "stay" (trip target.arrow))
  ;:(weld "  " (pad label 11) " " (trip cond.arrow) "\0a")
::  +catalog: the recipes on offer, one line each. The aim's title line
::  is what sells a recipe before it has been entered, so it is all that
::  shows here.
::
++  catalog
  |=  rs=(list recipe)
  ^-  @t
  ?:  =(~ rs)  ''
  =/  body=tape
    %-  zing
    %+  turn  rs
    |=  r=recipe
    ;:(weld "  " (pad (trip name.r) 14) " " (trip (title aim.r)) "\0a")
  %-  crip
  ;:  weld
    "<recipes-available>\0a"
    body
    "</recipes-available>\0a"
  ==
::  run state as json, so it can live in an ordinary grub beside the
::  chat it belongs to. The only thing the protocol persists is where
::  you are and what you have spent.
::
++  state-to-json
  |=  =state
  ^-  json
  %-  pairs:enjs:format
  :~  ['recipe' s+name.state]
      ['level' s+level.state]
      ['step' s+step.state]
      ['dwell' (numb:enjs:format dwell.state)]
      ['run' (numb:enjs:format run.state)]
      :-  'spent'
      %-  pairs:enjs:format
      %+  turn  ~(tap by spent.state)
      |=([k=@t v=@ud] [k (numb:enjs:format v)])
  ==
::  +state-from-json: ~ unless both the recipe name and the step are
::  present, since a run that doesn't know either of those is not a run.
::
++  state-from-json
  |=  jon=json
  ^-  (unit state)
  ?.  ?=([%o *] jon)  ~
  =/  nm=@t  (jstr jon 'recipe')
  ?:  =('' nm)  ~
  =/  sp=@t  (jstr jon 'step')
  ?:  =('' sp)  ~
  :-  ~
  :*  nm
      (jstr jon 'level')
      sp
      (spent-of (~(get by p.jon) 'spent'))
      (jnum jon 'dwell' 0)
      (jnum jon 'run' 0)
  ==
::
++  spent-of
  |=  v=(unit json)
  ^-  (map @t @ud)
  ?.  ?=([~ %o *] v)  ~
  %-  ~(gas by *(map @t @ud))
  %+  murn  ~(tap by p.u.v)
  |=  [k=@t j=json]
  ^-  (unit [@t @ud])
  =/  n=(unit @ud)  (mole |.((ni:dejs:format j)))
  ?~(n ~ `[k u.n])
::  helpers
::
++  title
  |=  ls=(list @t)
  ^-  @t
  ?~(ls '' i.ls)
::  +quoted: an aim as the author wrote it, indented so it reads as
::  quotation rather than as instruction from the harness.
::
++  quoted
  |=  ls=(list @t)
  ^-  tape
  ?~  ls  ""
  %-  zing
  %+  turn  ls
  |=(l=@t ?:(=('' l) "\0a" (weld (weld "| " (trip l)) "\0a")))
::
++  gauge
  |=  u=(unit @ud)
  ^-  tape
  ?~(u "-" (a-co:co u.u))
::
++  pad
  |=  [t=tape n=@ud]
  ^-  tape
  ?:  (gte (lent t) n)  t
  (weld t (reap (sub n (lent t)) ' '))
::  +arrow-order: stay first, done last, the rest alphabetical. JSON
::  objects are unordered, so the render order is imposed here rather
::  than taken from the file.
::
++  arrow-order
  |=  [a=[t=@t c=@t] b=[t=@t c=@t]]
  ^-  ?
  ?:  =('self' t.a)  &
  ?:  =('self' t.b)  |
  ?:  =('done' t.a)  |
  ?:  =('done' t.b)  &
  (lth t.a t.b)
::
++  steps-of
  |=  jon=json
  ^-  (map @t step)
  ?.  ?=([%o *] jon)  ~
  %-  ~(gas by *(map @t step))
  %+  murn  ~(tap by p.jon)
  |=  [k=@t v=json]
  ^-  (unit [@t step])
  ?.  ?=([%o *] v)  ~
  ?:  |(=('done' k) =('abort' k))  ~
  `[k [(jlines (~(get by p.v) 'aim')) (jarrows (~(get by p.v) 'next'))]]
::
++  levels-of
  |=  v=(unit json)
  ^-  (map @t level)
  ?.  ?=([~ %o *] v)  ~
  %-  ~(gas by *(map @t level))
  %+  murn  ~(tap by p.u.v)
  |=  [k=@t j=json]
  ^-  (unit [@t level])
  ?.  ?=([%o *] j)  ~
  `[k [(jnum j 'run' 0) (caps-of (~(get by p.j) 'steps'))]]
::
++  caps-of
  |=  v=(unit json)
  ^-  (map @t cap)
  ?.  ?=([~ %o *] v)  ~
  %-  ~(gas by *(map @t cap))
  %+  murn  ~(tap by p.u.v)
  |=  [k=@t j=json]
  ^-  (unit [@t cap])
  ?.  ?=([%o *] j)  ~
  `[k [(jopt j 'life') (jopt j 'dwell')]]
::
++  jarrows
  |=  v=(unit json)
  ^-  (map @t @t)
  ?.  ?=([~ %o *] v)  ~
  %-  ~(gas by *(map @t @t))
  %+  murn  ~(tap by p.u.v)
  |=  [k=@t j=json]
  ^-  (unit [@t @t])
  ?:(?=([%s *] j) `[k p.j] ~)
::
++  jlines
  |=  v=(unit json)
  ^-  (list @t)
  ?.  ?=([~ %a *] v)  ~
  %+  murn  p.u.v
  |=  j=json
  ^-  (unit @t)
  ?:(?=([%s *] j) `p.j ~)
::
++  jstr
  |=  [jon=json key=@t]
  ^-  @t
  ?.  ?=([%o *] jon)  ''
  =/  v=(unit json)  (~(get by p.jon) key)
  ?:(?=([~ %s *] v) p.u.v '')
::
++  jnum
  |=  [jon=json key=@t def=@ud]
  ^-  @ud
  ?.  ?=([%o *] jon)  def
  =/  v=(unit json)  (~(get by p.jon) key)
  ?~  v  def
  (fall (mole |.((ni:dejs:format u.v))) def)
::
++  jopt
  |=  [jon=json key=@t]
  ^-  (unit @ud)
  ?.  ?=([%o *] jon)  ~
  =/  v=(unit json)  (~(get by p.jon) key)
  ?~  v  ~
  (mole |.((ni:dejs:format u.v)))
--
