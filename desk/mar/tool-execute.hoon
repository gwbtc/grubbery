::  tool-execute: poke tools/main to start execution
::  [call-id tool-name args] — dispatcher creates /requests/{call-id}
::
|_  val=[call-id=@ta tool-name=@t args=(map @t json)]
++  grab
  |%
  ++  noun  [call-id=@ta tool-name=@t args=(map @t json)]
  --
++  grow
  |%
  ++  noun  val
  --
++  grad  %noun
--
