::  ws-send: one text frame down an open socket
::
|_  msg=[wid=@ud text=@t]
++  grab
  |%
  ++  noun  ,[wid=@ud text=@t]
  --
++  grow
  |%
  ++  noun  msg
  --
--
