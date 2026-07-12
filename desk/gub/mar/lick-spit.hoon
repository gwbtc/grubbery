::  lick-spit: poke to send [mark noun] out a local IPC port
::
|_  req=[name=path =mark noun=*]
++  grab
  |%
  ++  noun  ,[path @tas *]
  --
++  grow
  |%
  ++  noun  req
  --
--
