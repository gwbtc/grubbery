::  mark for wallet-store: map of xpub to seed
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
    |=  [xpub-key=@t seed-jon=^json]
    ^-  [@t seed]
    ?>  ?=([%o *] seed-jon)
    =/  stype=^json  (~(got by p.seed-jon) 'type')
    ?>  ?=([%s *] stype)
    =/  sval=^json   (~(got by p.seed-jon) 'value')
    ?>  ?=([%s *] sval)
    =/  =seed
      ?:  =('bip39' p.stype)  [%t p.sval]
      [%q (slav %q p.sval)]
    [xpub-key seed]
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
    |=  [xpub=@t =seed]
    ^-  [@t ^json]
    :-  xpub
    %-  pairs:enjs
    ?-  -.seed
      %t  ~[['type' s+'bip39'] ['value' s+phrase.seed]]
      %q  ~[['type' s+'q'] ['value' s+(scot %q secret.seed)]]
    ==
  ++  mime  [/application/json (as-octs:mimes:html -:txt)]
  ++  txt   [(en:json:html json)]~
  --
--
