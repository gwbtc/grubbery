::  mark for addresses: flat map of [origin-ref network] to [recv chng]
::
/<  wt  /lib/wallet-types.hoon
=,  wt
=,  format
=>
|%
++  aon  ((on @ud address-data) gth)
++  mop-to-list
  |=  mop=addr-mop
  ^-  (list [@ud address-data])
  (tap:aon mop)
++  list-to-mop
  |=  items=(list [@ud address-data])
  ^-  addr-mop
  (gas:aon *addr-mop items)
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
|_  dat=addresses
++  grab
  |%
  ++  noun  addresses
  ++  json
    |=  jon=^json
    ^-  addresses
    ?>  ?=([%o *] jon)
    %-  ~(gas by *addresses)
    %+  turn  ~(tap by p.jon)
    |=  [key=@t entry=^json]
    ^-  [[@t network] [recv=addr-mop chng=addr-mop]]
    ?>  ?=([%o *] entry)
    =/  m  p.entry
    =/  ref=@t    (so:dejs (~(got by m) 'ref'))
    =/  =network  (parse-network (so:dejs (~(got by m) 'network')))
    =/  recv=addr-mop
      (list-to-mop (parse-addr-list (~(got by m) 'recv')))
    =/  chng=addr-mop
      (list-to-mop (parse-addr-list (~(got by m) 'chng')))
    [[ref network] recv chng]
  ++  mime
    |=  [p=mite q=octs]
    ^-  addresses
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
    |=  [[ref=@t =network] recv=addr-mop chng=addr-mop]
    ^-  [@t ^json]
    :-  (crip "{(trip ref)}.{(trip (scot %tas network))}")
    %-  pairs:enjs
    :~  ['ref' s+ref]
        ['network' s+(scot %tas network)]
        ['recv' (addr-list-to-json (mop-to-list recv))]
        ['chng' (addr-list-to-json (mop-to-list chng))]
    ==
  ++  mime  [/application/json (as-octs:mimes:html -:txt)]
  ++  txt   [(en:json:html json)]~
  --
++  addr-list-to-json
  |=  items=(list [@ud address-data])
  ^-  json
  :-  %a
  %+  turn  items
  |=  [idx=@ud ad=address-data]
  ^-  json
  %-  pairs:enjs
  :~  ['index' (numb:enjs idx)]
      ['addr' s+addr.ad]
      ['loading' b+loading.ad]
      :-  'info'
      ?~  info.ad  ~
      %-  pairs:enjs
      :~  ['tx-count' (numb:enjs tx-count.u.info.ad)]
          ['funded' (numb:enjs funded.u.info.ad)]
          ['spent' (numb:enjs spent.u.info.ad)]
          ['last-check' s+(scot %da last-check.u.info.ad)]
      ==
      :-  'utxos'
      :-  %a
      %+  turn  utxos.ad
      |=  =utxo
      ^-  json
      %-  pairs:enjs
      :~  ['txid' s+txid.utxo]
          ['vout' (numb:enjs vout.utxo)]
          ['value' (numb:enjs value.utxo)]
          ['status' (status-to-json tx-status.utxo)]
      ==
  ==
++  parse-addr-list
  |=  jon=json
  ^-  (list [@ud address-data])
  ?>  ?=([%a *] jon)
  %+  turn  p.jon
  |=  item=json
  ?>  ?=([%o *] item)
  =/  m  p.item
  =/  info=(unit address-info)
    =/  ij  (~(got by m) 'info')
    ?:  =(~ ij)  ~
    ?>  ?=([%o *] ij)
    :-  ~
    :*  (ni:dejs (~(got by p.ij) 'tx-count'))
        (ni:dejs (~(got by p.ij) 'funded'))
        (ni:dejs (~(got by p.ij) 'spent'))
        (slav %da (so:dejs (~(got by p.ij) 'last-check')))
    ==
  =/  utxos=(list utxo)
    =/  uj  (~(got by m) 'utxos')
    ?>  ?=([%a *] uj)
    %+  turn  p.uj
    |=  u=json
    ?>  ?=([%o *] u)
    :*  (so:dejs (~(got by p.u) 'txid'))
        (ni:dejs (~(got by p.u) 'vout'))
        (ni:dejs (~(got by p.u) 'value'))
        (status-from-json (~(got by p.u) 'status'))
    ==
  :-  (ni:dejs (~(got by m) 'index'))
  [(so:dejs (~(got by m) 'addr')) (bo:dejs (~(got by m) 'loading')) ~ info utxos]
--
