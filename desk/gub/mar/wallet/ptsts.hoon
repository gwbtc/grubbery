::  mark for ptsts: tapscript tree store
::
/<  taproot  /lib/taproot.hoon
=,  format
|_  sts=(map @t ptst:taproot)
++  grab
  |%
  ++  noun  (map @t ptst:taproot)
  ++  json
    |=  jon=^json
    ^-  (map @t ptst:taproot)
    ?.  ?=([%o *] jon)  ~
    %-  ~(gas by *(map @t ptst:taproot))
    %+  turn  ~(tap by p.jon)
    |=  [addr=@t tree-jon=^json]
    [addr (json-to-ptst:taproot tree-jon)]
  ++  mime
    |=  [p=mite q=octs]
    ^-  (map @t ptst:taproot)
    (json (need (de:json:html (@t q.q))))
  --
++  grow
  |%
  ++  noun  sts
  ++  json
    ^-  ^json
    :-  %o
    %-  ~(gas by *(map @t ^json))
    %+  turn  ~(tap by sts)
    |=  [addr=@t tree=ptst:taproot]
    [addr (ptst-to-json:taproot tree)]
  ++  mime  [/application/json (as-octs:mimes:html -:txt)]
  ++  txt   [(en:json:html json)]~
  --
--
