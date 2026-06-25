::  mark for account ref: pubkey-hex routing sentinel
::
=,  format
|_  ref=@t
++  grab
  |%
  ++  noun  @t
  ++  json
    |=  jon=^json
    ^-  @t
    ?>  ?=([%s *] jon)
    p.jon
  ++  mime
    |=  [p=mite q=octs]
    ^-  @t
    (json (need (de:json:html (@t q.q))))
  --
++  grow
  |%
  ++  noun  ref
  ++  json  ^-(^json s+ref)
  ++  mime  [/application/json (as-octs:mimes:html -:txt)]
  ++  txt   [(en:json:html json)]~
  --
--
