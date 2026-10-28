::  scry-yawn: cancel an outstanding %keen for [ship path]. ames
::  otherwise holds an unanswerable request forever.
::
|_  req=[who=@p pax=path]
++  grab
  |%
  ++  noun  ,[@p path]
  --
++  grow
  |%
  ++  noun  req
  --
--
