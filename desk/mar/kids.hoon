::  kids: list of child names mark
::
!: :: turn on stack trace
|_  kids=(list @ta)
++  grad  %noun
++  grow
  |%
  ++  noun  kids
  ++  json  [%a (turn kids |=(k=@ta s+k))]
  --
++  grab
  |%
  ++  noun  (list @ta)
  --
--
