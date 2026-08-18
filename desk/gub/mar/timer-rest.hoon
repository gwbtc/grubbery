::  timer-rest: poke to cancel a timer previously set with %timer-set
::
::  Sample is named `rest`, NOT `wire`: a top-level `=wire` sample face shadows
::  the kernel `wire` type, so `,wire` in +grab resolves to the sample leg and
::  +build-vale (marks.hoon: slap of `noun:grab`) crashes -find.$. Mirrors
::  %timer-set, whose sample is `req` for the same reason.
::
|_  rest=wire
++  grab
  |%
  ++  noun  ,wire
  --
++  grow
  |%
  ++  noun  rest
  --
--
