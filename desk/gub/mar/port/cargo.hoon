::  port/cargo: an authenticated inbound message at a /port endpoint.
::
::  (unit [from=rail mime]) — the unit decouples "endpoint exists" from
::  "endpoint has content": ~ is an endpoint that exists but nobody has
::  written to yet, so it can be opened, addressed, and subscribed before
::  the first message arrives. [~ [from mim]] holds a sender-stamped
::  message. History carries the whole stream + the made-by/modified-by
::  lineage; the current value is just its head.
::
::  `from` is the raw sender rail (stamped by the port nexus from the
::  authenticated poke) — NOT reduced to @p; a helper parses ship-origin
::  later if it matters. Grows down to %mime by dropping the sender.
::
|_  cargo=(unit [from=rail:tarball =mime])
++  grab
  |%
  ++  noun  ,(unit [from=rail:tarball =mime])
  --
++  grow
  |%
  ++  noun  cargo
  ++  mime  ?~(cargo [/application/octet-stream (as-octs:mimes:html '')] mime.u.cargo)
  ++  json
    ?~  cargo  ~
    (pairs:enjs:format ~[['bytes' (numb:enjs:format p.q.mime.u.cargo)]])
  --
--
