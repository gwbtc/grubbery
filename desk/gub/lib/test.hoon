::  build-time test runner
::
::  test files should look like:
::
::    /<  test  /lib/test.hoon
::    /<  goals  /lib/goals.hoon
::    %-  run-tests:test
::    !>
::    |%
::    ++  test-whatever
::      |.  ^-  tang
::      (expect-eq:test !>(%foo) !>(%foo))
::    --
::
::  the file compiles to (list [name=term ok=?]).
::  %.y: assertions passed.  %.n: assertion failure.
::  if a test crashes, the build fails normally.
::
|%
++  expect-eq
  |=  [expected=vase actual=vase]
  ^-  tang
  =|  result=tang
  =?  result  !=(q.expected q.actual)
    %+  weld  result
    ^-  tang
    :~  [%palm [": " ~ ~ ~] [leaf+"expected" (sell expected) ~]]
        [%palm [": " ~ ~ ~] [leaf+"actual  " (sell actual) ~]]
    ==
  =?  result  !(~(nest ut p.actual) | p.expected)
    %+  weld  result
    ^-  tang
    :~  :+  %palm  [": " ~ ~ ~]
        :~  [%leaf "failed to nest"]
            (~(dunk ut p.actual) %actual)
            (~(dunk ut p.expected) %expected)
    ==  ==
  result
::
++  expect
  |=  actual=vase
  (expect-eq !>(%.y) actual)
::
++  expect-fail
  |=  a=(trap)
  ^-  tang
  =/  b  (mule a)
  ?-  -.b
    %|  ~
    %&  ['expected failure - succeeded' ~]
  ==
::
++  expect-success
  |=  a=(trap)
  ^-  tang
  =/  b  (mule a)
  ?-  -.b
    %&  ~
    %|  ['expected success - failed' p.b]
  ==
::
++  run-tests
  |=  cor=vase
  ^-  (list [name=term ok=?])
  =/  arms=(list term)
    (skim (sloe p.cor) |=(a=term =((end [3 5] a) 'test-')))
  %+  turn  arms
  |=  name=term
  =/  res=vase  (slap (slap cor [%limb name]) [%limb %$])
  [name =(~ ;;(tang q.res))]
--
