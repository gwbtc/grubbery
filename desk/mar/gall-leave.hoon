::  gall-leave: unsubscribe grubbery from a gall agent's path
::
::  Tears down the /sys/gall/subs materialization the matching watch created.
::  This is the cure for a stuck subscription: gall's book says live, the far
::  agent kicked while grubbery dozed, re-watching crashes %watch-not-unique,
::  and facts go nowhere. Leave, then watch.
::
|_  w=[ship=@p dude=@tas pax=path]
++  grab
  |%
  ++  noun  ,[ship=@p dude=@tas pax=path]
  --
++  grad  %noun
++  grow
  |%
  ++  noun  w
  --
--
