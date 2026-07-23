::  ames-peers: map of ships to peer status
::
|_  peers=(map ship ?(%alien %known))
++  grab
  |%
  ++  noun  ,(map ship ?(%alien %known))
  --
++  grow
  |%
  ++  noun  peers
  --
--
