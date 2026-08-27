::  gall-watch: subscribe grubbery to a gall agent's path
::
::  The agent already accepts this poke and materializes the resulting facts
::  under /sys/gall/subs. Without a mark the poke has nothing to convert
::  through, so a watch driven from a fiber or from the dojo crashes
::  marc-not-found at the gall service.
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
