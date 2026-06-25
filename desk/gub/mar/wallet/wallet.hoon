::  mark for wallet-data: stored bitcoin wallet (seed + xpub)
::
/<  wt  /lib/wallet-types.hoon
=,  wt
=,  format
|_  wal=wallet-data
++  grab
  |%
  ++  noun  wallet-data
  ++  json
    |=  jon=^json
    ^-  wallet-data
    ?>  ?=([%o *] jon)
    =/  xp=^json        (~(got by p.jon) 'xpub')
    ?>  ?=([%s *] xp)
    =/  seed-jon=^json  (~(got by p.jon) 'seed')
    ?>  ?=([%o *] seed-jon)
    =/  stype=^json  (~(got by p.seed-jon) 'type')
    ?>  ?=([%s *] stype)
    =/  sval=^json   (~(got by p.seed-jon) 'value')
    ?>  ?=([%s *] sval)
    =/  =seed
      ?:  =('bip39' p.stype)  [%t p.sval]
      [%q (slav %q p.sval)]
    [seed p.xp]
  ++  mime
    |=  [p=mite q=octs]
    ^-  wallet-data
    (json (need (de:json:html (@t q.q))))
  --
++  grow
  |%
  ++  noun  wal
  ++  json
    ^-  ^json
    %-  pairs:enjs
    :~  ['xpub' s+xpub.wal]
        :-  'seed'
        %-  pairs:enjs
        ?-  -.seed.wal
          %t  ~[['type' s+'bip39'] ['value' s+phrase.seed.wal]]
          %q  ~[['type' s+'q'] ['value' s+(scot %q secret.seed.wal)]]
        ==
    ==
  ++  mime  [/application/json (as-octs:mimes:html -:txt)]
  ++  txt   [(en:json:html json)]~
  --
--
