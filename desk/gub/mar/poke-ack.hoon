::  poke-ack: a poke's result keyed by the requester's wire — the
::  original wire plus ~ on ack, [~ tang] on nack. Wire-correlated so a
::  caller matches exactly its own ack.
::
|_  ack=[=wire err=(unit tang)]
++  grab
  |%
  ++  noun  ,[wire (unit tang)]
  --
++  grow
  |%
  ++  noun  ack
  --
--
