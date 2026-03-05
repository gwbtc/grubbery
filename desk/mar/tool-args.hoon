::  tool-args: initial state for a tool request process
::  [tool-name args] — request process resolves + runs the tool
::
|_  val=[@t (map @t json)]
++  grab
  |%
  ++  noun  ,[@t (map @t json)]
  --
++  grow
  |%
  ++  noun  val
  --
++  grad  %noun
--
