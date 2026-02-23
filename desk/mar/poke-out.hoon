::  poke-out: outbound poke to agent on remote ship
::
::  Target ship, agent, and untyped payload (page = [mark noun]).
::  Handled by /peers/main which has syscall access to send Gall pokes.
::
!: :: turn on stack trace
|_  [=ship =dude:gall =page]
++  grab
  |%
  ++  noun  ,[@p dude:gall ^page]
  --
++  grow
  |%
  ++  noun  [ship dude page]
  --
++  grad  %noun
--
