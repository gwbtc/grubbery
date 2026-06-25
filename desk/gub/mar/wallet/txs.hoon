::  mark for txs: flat map of [origin-ref network] to tx-map
::
/<  wt  /lib/wallet-types.hoon
=,  wt
=,  format
=>
|%
++  status-to-json
  |=  =tx-status
  ^-  json
  ?-  -.tx-status
    %unconfirmed  s+'unconfirmed'
    %confirmed
      %-  pairs:enjs
      ~[['block-hash' s+block-hash.tx-status] ['block-height' (numb:enjs block-height.tx-status)]]
  ==
++  status-from-json
  |=  jon=json
  ^-  tx-status
  ?:  ?=([%s %'unconfirmed'] jon)  [%unconfirmed ~]
  ?>  ?=([%o *] jon)
  [%confirmed (so:dejs (~(got by p.jon) 'block-hash')) (ni:dejs (~(got by p.jon) 'block-height'))]
++  parse-network
  |=  net=@t
  ^-  network
  ?+  net  ~|("bad network: {(trip net)}" !!)
    %'main'       %main
    %'testnet3'   %testnet3
    %'testnet4'   %testnet4
    %'signet'     %signet
    %'regtest'    %regtest
  ==
--
|_  dat=txs
++  grab
  |%
  ++  noun  txs
  ++  json
    |=  jon=^json
    ^-  txs
    ?>  ?=([%o *] jon)
    %-  ~(gas by *txs)
    %+  turn  ~(tap by p.jon)
    |=  [key=@t entry=^json]
    ^-  [[@t network] tx-map]
    ?>  ?=([%o *] entry)
    =/  m  p.entry
    =/  ref=@t    (so:dejs (~(got by m) 'ref'))
    =/  =network  (parse-network (so:dejs (~(got by m) 'network')))
    =/  =tx-map   (parse-tx-map (~(got by m) 'txs'))
    [[ref network] tx-map]
  ++  mime
    |=  [p=mite q=octs]
    ^-  txs
    (json (need (de:json:html (@t q.q))))
  --
++  grow
  |%
  ++  noun  dat
  ++  json
    ^-  ^json
    :-  %o
    %-  ~(gas by *(map @t ^json))
    %+  turn  ~(tap by dat)
    |=  [[ref=@t =network] =tx-map]
    ^-  [@t ^json]
    :-  (crip "{(trip ref)}.{(trip (scot %tas network))}")
    %-  pairs:enjs
    :~  ['ref' s+ref]
        ['network' s+(scot %tas network)]
        ['txs' (tx-map-to-json tx-map)]
    ==
  ++  mime  [/application/json (as-octs:mimes:html -:txt)]
  ++  txt   [(en:json:html json)]~
  --
++  tx-map-to-json
  |=  =tx-map
  ^-  json
  :-  %o
  %-  ~(gas by *(map @t json))
  %+  turn  ~(tap by tx-map)
  |=  [txid=@t =transaction]
  ^-  [@t json]
  :-  txid
  %-  pairs:enjs
  :~  ['txid' s+txid.transaction]
      :-  'inputs'
      :-  %a
      %+  turn  inputs.transaction
      |=  =tx-input
      %-  pairs:enjs
      :~  ['spent-txid' s+spent-txid.tx-input]
          ['spent-vout' (numb:enjs spent-vout.tx-input)]
          :-  'prevout'
          ?~  prevout.tx-input  ~
          %-  pairs:enjs
          ~[['value' (numb:enjs value.u.prevout.tx-input)] ['address' s+address.u.prevout.tx-input]]
      ==
      :-  'outputs'
      :-  %a
      %+  turn  outputs.transaction
      |=  =tx-output
      %-  pairs:enjs
      ~[['value' (numb:enjs value.tx-output)] ['address' s+address.tx-output]]
      ['status' (status-to-json tx-status.transaction)]
      ['fee' ?~(fee.transaction ~ (numb:enjs u.fee.transaction))]
      ['size' ?~(size.transaction ~ (numb:enjs u.size.transaction))]
  ==
++  parse-tx-map
  |=  jon=json
  ^-  tx-map
  ?>  ?=([%o *] jon)
  %-  ~(gas by *tx-map)
  %+  turn  ~(tap by p.jon)
  |=  [txid=@t tx-jon=json]
  ^-  [@t transaction]
  ?>  ?=([%o *] tx-jon)
  =/  m  p.tx-jon
  =/  inputs=(list tx-input)
    =/  ij  (~(got by m) 'inputs')
    ?>  ?=([%a *] ij)
    %+  turn  p.ij
    |=  i=json
    ?>  ?=([%o *] i)
    =/  prevout=(unit tx-output)
      =/  pj  (~(got by p.i) 'prevout')
      ?:  =(~ pj)  ~
      ?>  ?=([%o *] pj)
      `[(ni:dejs (~(got by p.pj) 'value')) (so:dejs (~(got by p.pj) 'address'))]
    [(so:dejs (~(got by p.i) 'spent-txid')) (ni:dejs (~(got by p.i) 'spent-vout')) prevout]
  =/  outputs=(list tx-output)
    =/  oj  (~(got by m) 'outputs')
    ?>  ?=([%a *] oj)
    %+  turn  p.oj
    |=  o=json
    ?>  ?=([%o *] o)
    [(ni:dejs (~(got by p.o) 'value')) (so:dejs (~(got by p.o) 'address'))]
  =/  fee=(unit @ud)
    =/  fj  (~(got by m) 'fee')
    ?:(=(~ fj) ~ `(ni:dejs fj))
  =/  size=(unit @ud)
    =/  sj  (~(got by m) 'size')
    ?:(=(~ sj) ~ `(ni:dejs sj))
  [txid [txid inputs outputs (status-from-json (~(got by m) 'status')) fee size]]
--
