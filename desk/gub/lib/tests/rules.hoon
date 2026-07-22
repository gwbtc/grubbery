::  tests/rules: kind gates against real calendar arithmetic.
::  Kinds are pure point generators (idx -> naive moment); these
::  test the moment math directly, independent of zone dressing.
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
::  +test-once: fires at the anchor, index 0 only
::
++  test-once
  |.  ^-  tang
  ;:  weld
    (expect-eq:test !>(`~2026.7.20..15.00.00) !>((k-once ~ ~2026.7.20..15.00.00 0)))
    (expect-eq:test !>(`(unit @da)`~) !>((k-once ~ ~2026.7.20..15.00.00 1)))
  ==
::  +test-every: anchor + idx * period
::
++  test-every
  |.  ^-  tang
  (expect-eq:test !>(`~2026.7.20..15.00.00) !>((k-every ~m90 ~2026.7.20..12.00.00 2)))
::  +test-daily: anchor day-floored + idx days + time-of-day
::
++  test-daily
  |.  ^-  tang
  ;:  weld
    (expect-eq:test !>(`~2026.7.20..09.00.00) !>((k-daily ~h9 ~2026.7.20 0)))
    (expect-eq:test !>(`~2026.7.25..09.00.00) !>((k-daily ~h9 ~2026.7.20 5)))
  ==
::  +test-weekly: mon/fri cycle from the anchor
::
++  test-weekly
  |.  ^-  tang
  =/  a  [~[%mon %fri] ~h9.m30]
  ;:  weld
    (expect-eq:test !>(`~2026.7.20..09.30.00) !>((k-weekly a ~2026.7.20 0)))  ::  mon
    (expect-eq:test !>(`~2026.7.24..09.30.00) !>((k-weekly a ~2026.7.20 1)))  ::  fri
    (expect-eq:test !>(`~2026.7.27..09.30.00) !>((k-weekly a ~2026.7.20 2)))  ::  mon
  ==
::  +test-monthly: day 31 dead in short months
::
++  test-monthly
  |.  ^-  tang
  =/  a  [31 ~h12]
  ;:  weld
    (expect-eq:test !>(`~2026.1.31..12.00.00) !>((k-monthly a ~2026.1.15 0)))  ::  jan
    (expect-eq:test !>(`(unit @da)`~) !>((k-monthly a ~2026.1.15 1)))           ::  feb dead
    (expect-eq:test !>(`~2026.3.31..12.00.00) !>((k-monthly a ~2026.1.15 2)))  ::  mar
  ==
::  +test-monthly-nth: second tuesday of july 2026 is the 14th
::
++  test-monthly-nth
  |.  ^-  tang
  (expect-eq:test !>(`~2026.7.14..10.00.00) !>((k-monthly-n [%second %tue ~h10] ~2026.7.1 0)))
::  +test-yearly-leap: feb 29 dead in 2027, alive in 2028
::
++  test-yearly-leap
  |.  ^-  tang
  =/  a  [2 29 ~h8]
  ;:  weld
    (expect-eq:test !>(`(unit @da)`~) !>((k-yearly a ~2027.1.1 0)))             ::  2027 dead
    (expect-eq:test !>(`~2028.2.29..08.00.00) !>((k-yearly a ~2027.1.1 1)))    ::  2028 leap
  ==
::  +test-yearly-anchor: an early anchor surfaces past years — a
::  birthday-style fixed date walks forward from any anchor
::
++  test-yearly-anchor
  |.  ^-  tang
  =/  a  [3 15 ~s0]
  ;:  weld
    (expect-eq:test !>(`~1970.3.15) !>((k-yearly a ~1970.1.1 0)))
    (expect-eq:test !>(`~2020.3.15) !>((k-yearly a ~1970.1.1 50)))
  ==
--
