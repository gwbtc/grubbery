::  open-loops: a context's flat store of open/closed loops
::
/<  ol  /lib/open-loops.hoon
|_  =loops:ol
++  grab
  |%
  ++  noun  ,loops:ol
  --
++  grow
  |%
  ++  noun  loops
  ++  json  (enjs-loops:ol loops)
  ++  mime
    =/  jon=^json  json
    [/application/json (as-octs:mimes:html (en:json:html jon))]
  --
--
