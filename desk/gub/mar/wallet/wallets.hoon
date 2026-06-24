::  mark for wallet-store: map of fingerprint to seed
::
/<  wt  /lib/wallet-types.hoon
=,  wt
=,  format
|_  store=wallet-store
++  grab
  |%
  ++  noun  wallet-store
  ++  json
    |=  jon=^json
    ^-  wallet-store
    ?>  ?=([%o *] jon)
    %-  ~(gas by *wallet-store)
    %+  turn  ~(tap by p.jon)
    |=  [fp-key=@t seed-jon=^json]
    ^-  [@ux seed]
    =/  fp=@ux  (scan (trip fp-key) hex)
    ?>  ?=([%o *] seed-jon)
    =/  stype=^json  (~(got by p.seed-jon) 'type')
    ?>  ?=([%s *] stype)
    =/  sval=^json   (~(got by p.seed-jon) 'value')
    ?>  ?=([%s *] sval)
    =/  =seed
      ?:  =('bip39' p.stype)  [%t p.sval]
      [%q (slav %q p.sval)]
    [fp seed]
  ++  mime
    |=  [p=mite q=octs]
    ^-  wallet-store
    (json (need (de:json:html (@t q.q))))
  --
++  grow
  |%
  ++  noun  store
  ++  json
    ^-  ^json
    :-  %o
    %-  ~(gas by *(map @t ^json))
    %+  turn  ~(tap by store)
    |=  [fp=@ux =seed]
    ^-  [@t ^json]
    :-  (crip (hexn:http-utils fp))
    %-  pairs:enjs
    ?-  -.seed
      %t  ~[['type' s+'bip39'] ['value' s+phrase.seed]]
      %q  ~[['type' s+'q'] ['value' s+(scot %q secret.seed)]]
    ==
  ++  mime  [/application/json (as-octs:mimes:html -:txt)]
  ++  txt   [(en:json:html json)]~
  --
--
