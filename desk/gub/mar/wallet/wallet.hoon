::  mark for wallet-data: stored bitcoin wallet
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
    =/  accts-jon=(unit ^json)  (~(get by p.jon) 'accounts')
    =/  accts=(map account @ux)
      ?~  accts-jon  ~
      ?>  ?=([%a *] u.accts-jon)
      %-  ~(gas by *(map account @ux))
      %+  turn  p.u.accts-jon
      |=  ej=^json
      ?>  ?=([%o *] ej)
      =/  pur=@ud  (rash (so:dejs (~(got by p.ej) 'purpose')) dem)
      =/  ct=@ud   (rash (so:dejs (~(got by p.ej) 'coin-type')) dem)
      =/  ai=@ud   (rash (so:dejs (~(got by p.ej) 'account')) dem)
      =/  pk=@ux   (slav %ux (so:dejs (~(got by p.ej) 'pubkey')))
      [[[%.y pur] [%.y ct] [%.y ai]] pk]
    [p.name seed fingerprint accts]
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
        :-  'accounts'
        :-  %a
        %+  turn  ~(tap by accounts.wal)
        |=  [=account:wt pubkey=@ux]
        %-  pairs:enjs
        :~  ['purpose' (numb:enjs q.purpose.account)]
            ['coin-type' (numb:enjs q.coin-type.account)]
            ['account' (numb:enjs q.account.account)]
            ['pubkey' s+(scot %ux pubkey)]
        ==
    ==
  ++  mime  [/application/json (as-octs:mimes:html -:txt)]
  ++  txt   [(en:json:html json)]~
  --
--
