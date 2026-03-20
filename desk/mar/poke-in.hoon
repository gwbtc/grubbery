::  poke-in: inbound poke from foreign ship, routed through /peers.peers/main.sig
::
::  Destination rail + untyped payload (page = [mark noun]).
::  The gateway at /peers.peers/ships/~ship/main.sig converts the page
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
