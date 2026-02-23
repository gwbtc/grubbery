::  poke-in: inbound poke from foreign ship, routed through /peers/main
::
::  Destination rail + untyped payload (page = [mark noun]).
::  The gateway at /peers/ships/~ship/main converts the page
::  to a cage and forwards to the destination.
::
/+  tarball
!: :: turn on stack trace
|_  [dest=rail:tarball =page]
++  grab
  |%
  ++  noun  ,[rail:tarball ^page]
  --
++  grow
  |%
  ++  noun  [dest page]
  --
++  grad  %noun
--
