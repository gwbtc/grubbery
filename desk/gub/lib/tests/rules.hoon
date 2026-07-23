::  tests/rules: kind gates against real calendar arithmetic.
::  Kinds are pure point generators (idx -> naive moment); these
::  test the moment math directly, independent of zone dressing.
::  args are json objects, exactly as stored and sent by clients.
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
%-  run-tests:test
!>
|%
++  jm  |=(l=(list [@t json]) (~(gas by *(map @t json)) l))
++  jn  |=(n=@ud (numb:enjs:format n))
::  +test-once: fires at the anchor, index 0 only
::
++  test-once
  |.  ^-  tang
  ;:  weld
    (expect-eq:test !>(`~2026.7.20..15.00.00) !>((k-once (jm ~) ~2026.7.20..15.00.00 0)))
    (expect-eq:test !>(`(unit @da)`~) !>((k-once (jm ~) ~2026.7.20..15.00.00 1)))
  ==
::  +test-every: anchor + idx * period (minutes)
::
++  test-every
  |.  ^-  tang
  =/  a  (jm ~[['period' (jn 90)]])
  (expect-eq:test !>(`~2026.7.20..15.00.00) !>((k-every a ~2026.7.20..12.00.00 2)))
::  +test-daily: anchor day-floored + idx days + time-of-day
::
++  test-daily
  |.  ^-  tang
  =/  a  (jm ~[['at' (jn 540)]])
  ;:  weld
    (expect-eq:test !>(`~2026.7.20..09.00.00) !>((k-daily a ~2026.7.20 0)))
    (expect-eq:test !>(`~2026.7.25..09.00.00) !>((k-daily a ~2026.7.20 5)))
  ==
::  +test-weekly: mon/fri cycle from the anchor
::
++  test-weekly
  |.  ^-  tang
  =/  a  (jm ~[['days' [%a ~[s+'mon' s+'fri']]] ['at' (jn 570)]])
  ;:  weld
    (expect-eq:test !>(`~2026.7.20..09.30.00) !>((k-weekly a ~2026.7.20 0)))  ::  mon
    (expect-eq:test !>(`~2026.7.24..09.30.00) !>((k-weekly a ~2026.7.20 1)))  ::  fri
    (expect-eq:test !>(`~2026.7.27..09.30.00) !>((k-weekly a ~2026.7.20 2)))  ::  mon
  ==
::  +test-monthly: day 31 dead in short months
::
++  test-monthly
  |.  ^-  tang
  =/  a  (jm ~[['day' (jn 31)] ['at' (jn 720)]])
  ;:  weld
    (expect-eq:test !>(`~2026.1.31..12.00.00) !>((k-monthly a ~2026.1.15 0)))  ::  jan
    (expect-eq:test !>(`(unit @da)`~) !>((k-monthly a ~2026.1.15 1)))           ::  feb dead
    (expect-eq:test !>(`~2026.3.31..12.00.00) !>((k-monthly a ~2026.1.15 2)))  ::  mar
  ==
::  +test-monthly-nth: second tuesday of july 2026 is the 14th
::
++  test-monthly-nth
  |.  ^-  tang
  =/  a  (jm ~[['ord' s+'second'] ['day' s+'tue'] ['at' (jn 600)]])
  (expect-eq:test !>(`~2026.7.14..10.00.00) !>((k-monthly-n a ~2026.7.1 0)))
::  +test-yearly-leap: feb 29 dead in 2027, alive in 2028
::
++  test-yearly-leap
  |.  ^-  tang
  =/  a  (jm ~[['month' (jn 2)] ['day' (jn 29)] ['at' (jn 480)]])
  ;:  weld
    (expect-eq:test !>(`(unit @da)`~) !>((k-yearly a ~2027.1.1 0)))             ::  2027 dead
    (expect-eq:test !>(`~2028.2.29..08.00.00) !>((k-yearly a ~2027.1.1 1)))    ::  2028 leap
  ==
::  +test-yearly-anchor: an early anchor surfaces past years — a
::  birthday-style fixed date walks forward from any anchor
::
++  test-yearly-anchor
  |.  ^-  tang
  =/  a  (jm ~[['month' (jn 3)] ['day' (jn 15)]])
  ;:  weld
    (expect-eq:test !>(`~1970.3.15) !>((k-yearly a ~1970.1.1 0)))
    (expect-eq:test !>(`~2020.3.15) !>((k-yearly a ~1970.1.1 50)))
  ==
--
