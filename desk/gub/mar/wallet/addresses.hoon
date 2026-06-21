::  mark for addr-mop: ordered map of address index to address-data
::
/<  wt  /lib/wallet-types.hoon
=,  wt
=,  format
|_  mop=addr-mop
++  on-addr  ((on @ud address-data) gth)
++  grab
  |%
  ++  noun  addr-mop
  ++  mime
    |=  [p=mite q=octs]
    ^-  addr-mop
    (json (need (de:json:html (@t q.q))))
  ++  json
    |=  jon=^json
    ^-  addr-mop
    ?>  ?=([%a *] jon)
    %+  roll  p.jon
    |=  [j=^json acc=addr-mop]
    ?>  ?=([%o *] j)
    =/  idx=@ud  (rash (so:dejs (~(got by p.j) 'index')) dem)
    =/  dat=address-data
      :*  (so:dejs (~(got by p.j) 'addr'))
          =('true' (so:dejs (~(got by p.j) 'loading')))
          ~
          =/  info-jon=^json  (~(got by p.j) 'info')
          ?:(=(~ info-jon) ~ `(parse-info info-jon))
          ~
      ==
    (put:on-addr acc idx dat)
  --
++  grow
  |%
  ++  noun  mop
  ++  json
    ^-  ^json
    :-  %a
    %+  turn  (tap:on-addr mop)
    |=  [idx=@ud dat=address-data]
    %-  pairs:enjs
    :~  ['index' (numb:enjs idx)]
        ['addr' s+addr.dat]
        ['loading' b+loading.dat]
        :-  'info'
        ?~  info.dat  ~
        %-  pairs:enjs
        :~  ['tx-count' (numb:enjs tx-count.u.info.dat)]
            ['funded' (numb:enjs funded.u.info.dat)]
            ['spent' (numb:enjs spent.u.info.dat)]
            ['last-check' s+(scot %da last-check.u.info.dat)]
        ==
        ['utxos' [%a (turn utxos.dat utxo-to-json)]]
    ==
  ++  mime  [/application/json (as-octs:mimes:html -:txt)]
  ++  txt   [(en:json:html json)]~
  --
++  utxo-to-json
  |=  u=utxo
  ^-  ^json
  %-  pairs:enjs
  :~  ['txid' s+txid.u]
      ['vout' (numb:enjs vout.u)]
      ['value' (numb:enjs value.u)]
      :-  'status'
      ?-  -.tx-status.u
        %unconfirmed  (pairs:enjs ~[['type' s+'unconfirmed']])
        %confirmed
          %-  pairs:enjs
          :~  ['type' s+'confirmed']
              ['block-hash' s+block-hash.tx-status.u]
              ['block-height' (numb:enjs block-height.tx-status.u)]
          ==
      ==
  ==
++  parse-info
  |=  jon=^json
  ^-  address-info
  ?>  ?=([%o *] jon)
  :*  (rash (so:dejs (~(got by p.jon) 'tx-count')) dem)
      (rash (so:dejs (~(got by p.jon) 'funded')) dem)
      (rash (so:dejs (~(got by p.jon) 'spent')) dem)
      (slav %da (so:dejs (~(got by p.jon) 'last-check')))
  ==
--
