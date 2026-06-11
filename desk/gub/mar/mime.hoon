::  Bootstrap mark — compiled into the runtime before build-code runs.
::  This file exists for reference only; the runtime uses a hardcoded
::  version and build-code skips it.
::
|_  own=mime
++  grow
  ^?
  |%
  ++  jam  `@`q.q.own
  --
::
++  grab                                                ::  convert from
  ^?
  |%
  ++  noun  mime                                  ::  clam from %noun
  ++  tape
    |=(a=_"" [/application/x-urb-unknown (as-octt:mimes:html a)])
  --
--
