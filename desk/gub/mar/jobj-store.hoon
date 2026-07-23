::  jobj-store: map of named jobj entries
::
::  Stores (map @t (map @t json)). Serializes as a nested JSON object.
::
=,  eyre
=,  format
|_  store=(map @t (map @t json))
::
++  grow
  |%
  ++  json  [%o (~(run by store) |=((map @t ^json) [%o +<]))]
  ++  mime  [/application/json (as-octs:mimes:html -:txt)]
  ++  txt   [(en:json:html json)]~
  --
++  grab
  |%
  ++  json
    |=  jon=^json
    ?>  ?=([%o *] jon)
    %-  ~(run by p.jon)
    |=(j=^json ?>(?=([%o *] j) p.j))
  ++  mime  |=([p=mite q=octs] (json (need (de:json:html (@t q.q)))))
  ++  noun  (map @t (map @t ^json))
  --
--
