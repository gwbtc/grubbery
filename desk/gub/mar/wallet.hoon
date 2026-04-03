::  mark for wallet-data: stored bitcoin wallet
::
=,  format
=>  |%
    +$  seed  $%([%t phrase=@t] [%q secret=@q])
    +$  wallet-data  [name=@t =seed fingerprint=@ux]
    --
|_  wal=wallet-data
++  grab
  |%
  ++  noun  wallet-data
  ++  json
    |=  jon=^json
    ^-  wallet-data
    ?>  ?=([%o *] jon)
    =/  name=^json      (~(got by p.jon) 'name')
    ?>  ?=([%s *] name)
    =/  fp=^json        (~(got by p.jon) 'fingerprint')
    ?>  ?=([%s *] fp)
    =/  seed-jon=^json  (~(got by p.jon) 'seed')
    ?>  ?=([%o *] seed-jon)
    =/  stype=^json  (~(got by p.seed-jon) 'type')
    ?>  ?=([%s *] stype)
    =/  sval=^json   (~(got by p.seed-jon) 'value')
    ?>  ?=([%s *] sval)
    =/  =seed
      ?:  =('bip39' p.stype)  [%t p.sval]
      [%q (slav %q p.sval)]
    =/  fingerprint=@ux  (scan (trip p.fp) hex)
    [p.name seed fingerprint]
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
    :~  ['name' s+name.wal]
        ['fingerprint' s+(crip (hexn:http-utils fingerprint.wal))]
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
