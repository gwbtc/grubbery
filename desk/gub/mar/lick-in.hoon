::  lick-in: inbound IPC message materialized at /sys/lick/<name>/in.
::  seq increments per message so identical payloads still fire a wave.
::
|_  msg=[seq=@ud =mark noun=*]
++  grab
  |%
  ++  noun  ,[@ud @tas *]
  --
++  grow
  |%
  ++  noun  msg
  --
--
