::  scry-keen: read a path from a remote ship's farm via remote scry
::
::  ret is the requesting fiber's wire, echoed back in the
::  keen-response so the fiber can correlate answers.
::
|_  req=[who=@p pax=path ret=path]
++  grab
  |%
  ++  noun  ,[@p path path]
  --
++  grow
  |%
  ++  noun  req
  --
--
