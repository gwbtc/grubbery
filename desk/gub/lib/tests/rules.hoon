::  tests/rules: recurrence rules against real calendar arithmetic
::
::  US DST in 2026: spring-forward sun mar 8 (2am -> 3am),
::  fall-back sun nov 1 (2am EDT -> 1am EST).
::  New York: EDT = UTC-4, EST = UTC-5.
::
/<  test         /lib/test.hoon
/<  rules        /lib/rules.hoon
/<  k-once       /lib/rules/once.hoon
/<  k-every      /lib/rules/every.hoon
/<  k-daily      /lib/rules/daily.hoon
/<  k-weekly     /lib/rules/weekly.hoon
/<  k-monthly    /lib/rules/monthly.hoon
/<  k-monthly-n  /lib/rules/monthly-nth.hoon
/<  k-yearly     /lib/rules/yearly.hoon
/<  k-cron       /lib/rules/cron.hoon
%-  run-tests:test
!>
|%
++  ny  `(unit @t)`[~ 'America/New_York']
::  bare rule: instants, unbounded, no exceptions
::
++  mk
  |=  [args=* zone=(unit @t) start=@da]
  ^-  rule:rules
  [[/lib/rules %test] args zone start ~ ~ ~]
::
++  spans
  |=  ls=(list @da)
  ^-  (list span:rules)
  (turn ls |=(d=@da [d d]))
::
::  +test-once: fires at start, index 0 only
::
++  test-once
  |.  ^-  tang
  =/  r  (mk ~ ~ ~2026.7.20..15.00.00)
  ;:  weld
    %+  expect-eq:test
      !>((spans ~[~2026.7.20..15.00.00]))
    !>((instance:rules r k-once 0))
  ::
    %+  expect-eq:test
      !>(`(list span:rules)`~)
    !>((instance:rules r k-once 1))
  ==
::
::  +test-every: start + idx * period, absolute
::
++  test-every
  |.  ^-  tang
  =/  r  (mk ~m90 ~ ~2026.7.20..12.00.00)
  %+  expect-eq:test
    !>((spans ~[~2026.7.20..15.00.00]))
  !>((instance:rules r k-every 2))
::
::  +test-daily-utc: plain daily, no zone
::
++  test-daily-utc
  |.  ^-  tang
  =/  r  (mk ~h9 ~ ~2026.7.20)
  ;:  weld
    %+  expect-eq:test
      !>((spans ~[~2026.7.20..09.00.00]))
    !>((instance:rules r k-daily 0))
  ::
    %+  expect-eq:test
      !>((spans ~[~2026.7.25..09.00.00]))
    !>((instance:rules r k-daily 5))
  ==
::
::  +test-weekly-dst: mon/fri 9:30 NY across the november fall-back.
::  9:30 EDT = 13:30 UTC before; 9:30 EST = 14:30 UTC after.
::
++  test-weekly-dst
  |.  ^-  tang
  =/  r  (mk [~[%mon %fri] ~h9.m30] ny ~2026.10.26)
  ;:  weld
    %+  expect-eq:test                      ::  mon oct 26, EDT
      !>((spans ~[~2026.10.26..13.30.00]))
    !>((instance:rules r k-weekly 0))
  ::
    %+  expect-eq:test                      ::  fri oct 30, EDT
      !>((spans ~[~2026.10.30..13.30.00]))
    !>((instance:rules r k-weekly 1))
  ::
    %+  expect-eq:test                      ::  mon nov 2, EST
      !>((spans ~[~2026.11.2..14.30.00]))
    !>((instance:rules r k-weekly 2))
  ==
::
::  +test-dst-gap: 2:30am NY on spring-forward day doesn't exist
::
++  test-dst-gap
  |.  ^-  tang
  =/  r  (mk ~h2.m30 ny ~2026.3.7)
  ;:  weld
    %+  expect-eq:test                      ::  mar 7, EST: 7:30 UTC
      !>((spans ~[~2026.3.7..07.30.00]))
    !>((instance:rules r k-daily 0))
  ::
    %+  expect-eq:test                      ::  mar 8: erased by the gap
      !>(`(list span:rules)`~)
    !>((instance:rules r k-daily 1))
  ==
::
::  +test-dst-overlap: 1:30am NY on fall-back day happens twice
::
++  test-dst-overlap
  |.  ^-  tang
  =/  r  (mk ~h1.m30 ny ~2026.11.1)
  %+  expect-eq:test
    !>((spans ~[~2026.11.1..05.30.00 ~2026.11.1..06.30.00]))
  !>((instance:rules r k-daily 0))
::
::  +test-monthly-short: day 31 is dead in short months
::
++  test-monthly-short
  |.  ^-  tang
  =/  r  (mk [31 ~h12] ~ ~2026.1.15)
  ;:  weld
    %+  expect-eq:test                      ::  jan 31
      !>((spans ~[~2026.1.31..12.00.00]))
    !>((instance:rules r k-monthly 0))
  ::
    %+  expect-eq:test                      ::  feb: dead
      !>(`(list span:rules)`~)
    !>((instance:rules r k-monthly 1))
  ::
    %+  expect-eq:test                      ::  mar 31
      !>((spans ~[~2026.3.31..12.00.00]))
    !>((instance:rules r k-monthly 2))
  ::
    %+  expect-eq:test                      ::  apr: dead
      !>(`(list span:rules)`~)
    !>((instance:rules r k-monthly 3))
  ==
::
::  +test-monthly-nth: second tuesday of july 2026 is the 14th
::
++  test-monthly-nth
  |.  ^-  tang
  =/  r  (mk [%second %tue ~h10] ~ ~2026.7.1)
  %+  expect-eq:test
    !>((spans ~[~2026.7.14..10.00.00]))
  !>((instance:rules r k-monthly-n 0))
::
::  +test-yearly-leap: feb 29 exists in 2028, dead in 2027
::
++  test-yearly-leap
  |.  ^-  tang
  =/  r  (mk [2 29 ~h8] ~ ~2027.1.1)
  ;:  weld
    %+  expect-eq:test                      ::  2027: dead
      !>(`(list span:rules)`~)
    !>((instance:rules r k-yearly 0))
  ::
    %+  expect-eq:test                      ::  2028: leap
      !>((spans ~[~2028.2.29..08.00.00]))
    !>((instance:rules r k-yearly 1))
  ==
::
::  +test-except: a skipped index yields nothing
::
++  test-except
  |.  ^-  tang
  =/  r  (mk ~h9 ~ ~2026.7.20)
  =.  except.r  (sy ~[1])
  ;:  weld
    %+  expect-eq:test
      !>(`(list span:rules)`~)
    !>((instance:rules r k-daily 1))
  ::
    %+  expect-eq:test                      ::  neighbours unaffected
      !>((spans ~[~2026.7.22..09.00.00]))
    !>((instance:rules r k-daily 2))
  ==
::
::  +test-dom: indices at/past the cap yield nothing
::
++  test-dom
  |.  ^-  tang
  =/  r  (mk ~h9 ~ ~2026.7.20)
  =.  dom.r  `2
  ;:  weld
    %+  expect-eq:test
      !>((spans ~[~2026.7.21..09.00.00]))
    !>((instance:rules r k-daily 1))
  ::
    %+  expect-eq:test
      !>(`(list span:rules)`~)
    !>((instance:rules r k-daily 2))
  ==
::
::  +test-end-for: duration in real time
::
++  test-end-for
  |.  ^-  tang
  =/  r  (mk ~h9 ~ ~2026.7.20)
  =.  end.r  [%for ~h1]
  %+  expect-eq:test
    !>(`(list span:rules)`~[[~2026.7.20..09.00.00 ~2026.7.20..10.00.00]])
  !>((instance:rules r k-daily 0))
::
::  +test-end-until-overnight: 9pm until 2am rolls to the next day
::
++  test-end-until-overnight
  |.  ^-  tang
  =/  r  (mk ~h21 ~ ~2026.7.20)
  =.  end.r  [%until ~h2]
  %+  expect-eq:test
    !>(`(list span:rules)`~[[~2026.7.20..21.00.00 ~2026.7.21..02.00.00]])
  !>((instance:rules r k-daily 0))
::
::  cron star fields: full ranges
::
++  c-mins  (gulf 0 59)
++  c-hrs   (gulf 0 23)
++  c-doms  (gulf 1 31)
++  c-mons  (gulf 1 12)
++  c-dows  (gulf 0 6)
::
::  +test-cron-weekly: "30 9 * * 1,5" — mon/fri 9:30
::
++  test-cron-weekly
  |.  ^-  tang
  =/  r  (mk [~[30] ~[9] c-doms c-mons ~[1 5]] ~ ~2026.7.20)
  ;:  weld
    %+  expect-eq:test                      ::  mon jul 20
      !>((spans ~[~2026.7.20..09.30.00]))
    !>((instance:rules r k-cron 0))
  ::
    %+  expect-eq:test                      ::  fri jul 24
      !>((spans ~[~2026.7.24..09.30.00]))
    !>((instance:rules r k-cron 1))
  ==
::
::  +test-cron-slots: "0 0,6,12,18 * * *" — four fires a day,
::  chronological within the day
::
++  test-cron-slots
  |.  ^-  tang
  =/  r  (mk [~[0] ~[0 6 12 18] c-doms c-mons c-dows] ~ ~2026.7.20)
  ;:  weld
    %+  expect-eq:test
      !>((spans ~[~2026.7.20..06.00.00]))
    !>((instance:rules r k-cron 1))
  ::
    %+  expect-eq:test                      ::  wraps to day two
      !>((spans ~[~2026.7.21..06.00.00]))
    !>((instance:rules r k-cron 5))
  ==
::
::  +test-cron-dom-dow-or: "0 12 15 * 1" — both restricted, day
::  matches on EITHER the 15th or a monday
::
++  test-cron-dom-dow-or
  |.  ^-  tang
  =/  r  (mk [~[0] ~[12] ~[15] c-mons ~[1]] ~ ~2026.7.1)
  ;:  weld
    %+  expect-eq:test                      ::  mon jul 6
      !>((spans ~[~2026.7.6..12.00.00]))
    !>((instance:rules r k-cron 0))
  ::
    %+  expect-eq:test                      ::  mon jul 13
      !>((spans ~[~2026.7.13..12.00.00]))
    !>((instance:rules r k-cron 1))
  ::
    %+  expect-eq:test                      ::  wed jul 15 — dom hit
      !>((spans ~[~2026.7.15..12.00.00]))
    !>((instance:rules r k-cron 2))
  ::
    %+  expect-eq:test                      ::  mon jul 20
      !>((spans ~[~2026.7.20..12.00.00]))
    !>((instance:rules r k-cron 3))
  ==
::
::  +test-cron-zoned: "0 9 * * *" in NY across the fall-back —
::  9am EDT is 13:00 UTC, 9am EST is 14:00 UTC
::
++  test-cron-zoned
  |.  ^-  tang
  =/  r  (mk [~[0] ~[9] c-doms c-mons c-dows] ny ~2026.10.30)
  ;:  weld
    %+  expect-eq:test                      ::  fri oct 30, EDT
      !>((spans ~[~2026.10.30..13.00.00]))
    !>((instance:rules r k-cron 0))
  ::
    %+  expect-eq:test                      ::  sun nov 1, EST
      !>((spans ~[~2026.11.1..14.00.00]))
    !>((instance:rules r k-cron 2))
  ==
--
