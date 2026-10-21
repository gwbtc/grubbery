/<  test  /lib/test.hoon
/<  rec   /lib/recipe.hoon
::  tests for lib/recipe: parse, budget arithmetic, transitions, render
::
::  The demo recipe is two steps. `a` may stay (dwell 2, life 4) or go
::  to `b`; `b` may finish. `a` is budgeted both ways and `b` has no
::  dwell, so the unbudgeted-vs-zero distinction gets exercised. The
::  file also declares a `done` step, which parse must drop.
::
::  rcp and st0 are =/ legs rather than core arms on purpose: a face
::  looked up through an arm reference does not carry the arm's mold,
::  so `aim.rcp` fails where `aim` on a declared leg resolves. The chk
::  gates exist for the same class of reason — expect-eq compares types
::  as well as values, so the expected side needs a declared sample
::  rather than a bare literal.
::
=/  src=@t
  '{"aim":["Test recipe","","A description."],"start":"a","steps":{"a":{"aim":["Step A"],"next":{"self":"more to do","b":"a is settled"}},"b":{"aim":["Step B"],"next":{"done":"finished"}},"done":{"aim":["must be dropped"]}},"levels":{"normal":{"run":10,"steps":{"a":{"life":4,"dwell":2},"b":{"life":3}}}}}'
=/  rcp=recipe:rec  (need (parse:rec 'demo' (need (de:json:html src))))
=/  st0=state:rec   (enter:rec rcp 'normal')
%-  run-tests:test
!>
|%
::  +tik: spend n messages
::
++  tik
  |=  [n=@ud s=state:rec]
  ^-  state:rec
  ?:(=(0 n) s $(n (dec n), s (tick:rec s)))
::  +won: the state out of a move that must have succeeded
::
++  won
  |=  e=(each state:rec @t)
  ^-  state:rec
  ?>(?=(%& -.e) p.e)
::  +fail: did a move get refused
::
++  fail
  |=  e=(each state:rec @t)
  ^-  ?
  ?=(%| -.e)
::  +has: does a rendered block contain this text
::
++  has
  |=  [nedl=tape hstk=@t]
  ^-  ?
  ?=(^ (find nedl (trip hstk)))
::  typed comparisons
::
++  chk-ud   |=([want=@ud got=@ud] (expect-eq:test !>(want) !>(got)))
++  chk-t    |=([want=@t got=@t] (expect-eq:test !>(want) !>(got)))
++  chk-lo   |=([want=? got=?] (expect-eq:test !>(want) !>(got)))
++  chk-unit  |=([want=(unit @ud) got=(unit @ud)] (expect-eq:test !>(want) !>(got)))
++  chk-list  |=([want=(list @t) got=(list @t)] (expect-eq:test !>(want) !>(got)))
++  chk-rcp
  |=  [want=(unit recipe:rec) got=(unit recipe:rec)]
  (expect-eq:test !>(want) !>(got))
::  parse
::
++  test-parse-start
  |.((chk-t 'a' start.rcp))
++  test-parse-aim-lines
  |.((chk-ud 3 (lent aim.rcp)))
::  'done' is a reserved arrow target, so a step by that name is dropped
++  test-parse-drops-done-step
  |.((chk-ud 2 ~(wyt by steps.rcp)))
++  test-parse-rejects-startless
  |.((chk-rcp ~ (parse:rec 'x' (need (de:json:html '{"steps":{}}')))))
::  entry
::
++  test-enter-step
  |.((chk-t 'a' step.st0))
++  test-enter-unspent
  |.((chk-ud 0 (add run.st0 dwell.st0)))
::  budgets: ~ is unbudgeted, which is not zero
::
++  test-life-fresh
  |.((chk-unit `4 (life-left:rec rcp st0 'a')))
++  test-dwell-fresh
  |.((chk-unit `2 (dwell-left:rec rcp st0)))
++  test-run-fresh
  |.((chk-ud 10 (run-left:rec rcp st0)))
++  test-tick-spends-run
  |.((chk-ud 8 (run-left:rec rcp (tik 2 st0))))
++  test-tick-spends-life
  |.((chk-unit `2 (life-left:rec rcp (tik 2 st0) 'a')))
++  test-tick-spends-dwell
  |.((chk-unit `0 (dwell-left:rec rcp (tik 2 st0))))
::  a step with no dwell in the level is unbudgeted, not spent
++  test-dwell-absent-is-unbudgeted
  |.  =/  s=state:rec  (won (move:rec rcp (tik 1 st0) 'b'))
      (chk-unit ~ (dwell-left:rec rcp s))
::  transitions
::
++  test-stay-keeps-dwell
  |.  =/  s=state:rec  (won (move:rec rcp (tik 1 st0) 'self'))
      (chk-ud 1 dwell.s)
++  test-stay-keeps-step
  |.  =/  s=state:rec  (won (move:rec rcp (tik 1 st0) 'self'))
      (chk-t 'a' step.s)
++  test-move-resets-dwell
  |.  =/  s=state:rec  (won (move:rec rcp (tik 1 st0) 'b'))
      (chk-ud 0 dwell.s)
++  test-move-changes-step
  |.  =/  s=state:rec  (won (move:rec rcp (tik 1 st0) 'b'))
      (chk-t 'b' step.s)
::  a target with no arrow from here is refused, not silently taken
++  test-no-such-arrow
  |.((chk-lo & (fail (move:rec rcp st0 'zzz'))))
::  dwell spent: staying is no longer on offer
++  test-stay-refused-when-dwell-spent
  |.((chk-lo & (fail (move:rec rcp (tik 2 st0) 'self'))))
++  test-done-is-terminal
  |.  =/  s=state:rec  (won (move:rec rcp st0 'b'))
      (chk-lo & (done:rec (won (move:rec rcp s 'done'))))
::  the open set, in render order: stay first, then the rest
::
++  test-open-order
  |.  %+  chk-list  ~['self' 'b']
      (turn (open:rec rcp st0) |=(a=arrow:rec target.a))
::  a spent arrow drops out of the open set rather than erroring
++  test-open-drops-spent-stay
  |.  %+  chk-list  ~['b']
      %+  turn
        (skim (open:rec rcp (tik 2 st0)) |=(a=arrow:rec ok.a))
      |=(a=arrow:rec target.a)
::  exhaustion
::
++  test-not-stuck-fresh
  |.((chk-lo | (stuck:rec rcp st0)))
++  test-stuck-when-run-spent
  |.((chk-lo & (stuck:rec rcp (tik 10 st0))))
++  test-done-is-not-stuck
  |.  =/  s=state:rec  (won (move:rec rcp st0 'b'))
      (chk-lo | (stuck:rec rcp (won (move:rec rcp s 'done'))))
::  render: the structural lines are facts, the aim is quoted
::
++  test-tip-names-step
  |.((chk-lo & (has "STEP  a" (tip:rec rcp st0))))
++  test-tip-shows-budgets
  |.((chk-lo & (has "[dwell 2, step 4, run 10]" (tip:rec rcp st0))))
::  an unbudgeted figure renders as a dash, never as 0
++  test-tip-dash-for-unbudgeted
  |.  =/  s=state:rec  (won (move:rec rcp (tik 1 st0) 'b'))
      (chk-lo & (has "[dwell -, step 3, run 9]" (tip:rec rcp s)))
++  test-tip-quotes-the-aim
  |.((chk-lo & (has "| Step A" (tip:rec rcp st0))))
++  test-tip-offers-abort-always
  |.((chk-lo & (has "abort" (tip:rec rcp st0))))
++  test-tip-lists-open-arrow
  |.((chk-lo & (has "a is settled" (tip:rec rcp st0))))
::  catalog: one line per recipe, title only
::
++  test-catalog-names-recipe
  |.((chk-lo & (has "demo" (catalog:rec ~[rcp]))))
++  test-catalog-shows-title
  |.((chk-lo & (has "Test recipe" (catalog:rec ~[rcp]))))
++  test-catalog-empty-is-empty
  |.((chk-t '' (catalog:rec *(list recipe:rec))))
::  state serialization: a run survives a trip through a grub
::
++  chk-state
  |=  [want=(unit state:rec) got=(unit state:rec)]
  (expect-eq:test !>(want) !>(got))
::
++  test-state-round-trip-fresh
  |.((chk-state `st0 (state-from-json:rec (state-to-json:rec st0))))
::  with a non-empty spent map and a dwell mid-step
++  test-state-round-trip-spent
  |.  =/  s=state:rec  (won (move:rec rcp (tik 2 st0) 'b'))
      =/  s=state:rec  (tik 3 s)
      (chk-state `s (state-from-json:rec (state-to-json:rec s)))
::  a run that knows neither where it is nor which recipe is not a run
++  test-state-rejects-stepless
  |.  %+  chk-state  ~
      (state-from-json:rec (need (de:json:html '{"recipe":"demo"}')))
++  test-state-rejects-nameless
  |.  %+  chk-state  ~
      (state-from-json:rec (need (de:json:html '{"step":"a"}')))
--
