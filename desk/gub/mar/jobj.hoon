::  jobj: json object mark
::
::  Stores (map @t json). Serializes as a JSON object.
::
=,  eyre
=,  format
|_  obj=(map @t json)
::
++  grow
  |%
  ++  json  [%o obj]
  ++  mime  [/application/json (as-octs:mimes:html -:txt)]
  ++  txt   [(en:json:html json)]~
  --
++  grab
  |%
  ++  json  |=(jon=^json ?>(?=([%o *] jon) p.jon))
  ++  mime  |=([p=mite q=octs] (json (need (de:json:html (@t q.q)))))
  ++  noun  (map @t ^json)
  --
--
