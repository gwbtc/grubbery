::  Foundational mark  -- compiled at bootstrap and forced into every
::  /code nexus before build-code runs.  Do not remove or rename.
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
