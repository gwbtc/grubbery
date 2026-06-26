::  mark for secrets: wallet seeds + standalone xprvs
::
/<  wt  /lib/wallet-types.hoon
=,  wt
=,  format
|_  sec=secrets
++  grab
  |%
  ++  noun  secrets
  ++  json
    |=  jon=^json
    ^-  secrets
    ?>  ?=([%o *] jon)
    =/  seeds-jon  (~(get by p.jon) 'seeds')
    =/  xprvs-jon  (~(get by p.jon) 'xprvs')
    =/  sd=(map @t seed)
      ?~  seeds-jon  ~
      ?.  ?=([%o *] u.seeds-jon)  ~
      %-  ~(gas by *(map @t seed))
      %+  turn  ~(tap by p.u.seeds-jon)
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
    =/  xp=(map @t @t)
      ?~  xprvs-jon  ~
      ?.  ?=([%o *] u.xprvs-jon)  ~
      %-  ~(gas by *(map @t @t))
      %+  turn  ~(tap by p.u.xprvs-jon)
      |=  [acct-xpub=@t v=^json]
      ?>  ?=([%s *] v)
      [acct-xpub p.v]
    [sd xp]
  ++  mime
    |=  [p=mite q=octs]
    ^-  secrets
    (json (need (de:json:html (@t q.q))))
  --
++  grow
  |%
  ++  noun  sec
  ++  json
    ^-  ^json
    %-  pairs:enjs
    :~  :-  'seeds'
        :-  %o
        %-  ~(gas by *(map @t ^json))
        %+  turn  ~(tap by seeds.sec)
        |=  [xpub=@t =seed]
        ^-  [@t ^json]
        :-  xpub
        %-  pairs:enjs
        ?-  -.seed
          %t  ~[['type' s+'bip39'] ['value' s+phrase.seed]]
          %q  ~[['type' s+'q'] ['value' s+(scot %q secret.seed)]]
        ==
      ::
        :-  'xprvs'
        :-  %o
        %-  ~(gas by *(map @t ^json))
        %+  turn  ~(tap by xprvs.sec)
        |=  [acct-xpub=@t xprv=@t]
        ^-  [@t ^json]
        [acct-xpub s+xprv]
    ==
  ++  mime  [/application/json (as-octs:mimes:html -:txt)]
  ++  txt   [(en:json:html json)]~
  --
--
