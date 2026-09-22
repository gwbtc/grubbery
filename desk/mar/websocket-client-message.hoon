::  a frame from a websocket we opened as a client. groundwire eyre
::  pokes this into the app named on %websocket-connect.
/+  nexus
|_  msg=[wid=@ud ws-message:nexus]
++  grab
  |%
  ++  noun  ,[wid=@ud ws-message:nexus]
  --
++  grow
  |%
  ++  noun  msg
  --
++  grad  %noun
--
