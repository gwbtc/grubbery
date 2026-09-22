::  ws-connect: open a websocket to this url, under this key (a wire
::  the fiber chooses; a second connect on the same key replaces)
::
|_  req=[key=wire url=@t]
++  grab
  |%
  ++  noun  ,[key=wire url=@t]
  --
++  grow
  |%
  ++  noun  req
  --
--
