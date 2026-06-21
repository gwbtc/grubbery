::  mark for tx-map: map of txid to transaction
::
/<  wt  /lib/wallet-types.hoon
=,  wt
=,  format
|_  txs=tx-map
++  grab
  |%
  ++  noun  tx-map
  ++  mime
    |=  [p=mite q=octs]
    ^-  tx-map
    (json (need (de:json:html (@t q.q))))
  ++  json
    |=  jon=^json
    ^-  tx-map
    ?>  ?=([%o *] jon)
    %-  ~(gas by *tx-map)
    %+  turn  ~(tap by p.jon)
    |=  [txid=@t v=^json]
    ?>  ?=([%o *] v)
    :-  txid
    :*  txid
        (parse-inputs (~(got by p.v) 'inputs'))
        (parse-outputs (~(got by p.v) 'outputs'))
        (parse-status (~(got by p.v) 'status'))
        (bind (~(get by p.v) 'fee') |=(j=^json (rash (so:dejs j) dem)))
        (bind (~(get by p.v) 'size') |=(j=^json (rash (so:dejs j) dem)))
    ==
  --
++  grow
  |%
  ++  noun  txs
  ++  json
    ^-  ^json
    :-  %o
    %-  ~(gas by *(map @t ^json))
    %+  turn  ~(tap by txs)
    |=  [txid=@t tx=transaction]
    :-  txid
    %-  pairs:enjs
    :~  ['txid' s+txid.tx]
        ['inputs' [%a (turn inputs.tx input-to-json)]]
        ['outputs' [%a (turn outputs.tx output-to-json)]]
        ['status' (status-to-json tx-status.tx)]
        ['fee' ?~(fee.tx ~ (numb:enjs u.fee.tx))]
        ['size' ?~(size.tx ~ (numb:enjs u.size.tx))]
    ==
  ++  mime  [/application/json (as-octs:mimes:html -:txt)]
  ++  txt   [(en:json:html json)]~
  --
++  input-to-json
  |=  i=tx-input
  ^-  ^json
  %-  pairs:enjs
  :~  ['spent-txid' s+spent-txid.i]
      ['spent-vout' (numb:enjs spent-vout.i)]
      :-  'prevout'
      ?~  prevout.i  ~
      (output-to-json u.prevout.i)
  ==
++  output-to-json
  |=  o=tx-output
  ^-  ^json
  %-  pairs:enjs
  :~  ['value' (numb:enjs value.o)]
      ['address' s+address.o]
  ==
++  status-to-json
  |=  s=tx-status
  ^-  ^json
  ?-  -.s
    %unconfirmed  (pairs:enjs ~[['type' s+'unconfirmed']])
    %confirmed
      %-  pairs:enjs
      :~  ['type' s+'confirmed']
          ['block-hash' s+block-hash.s]
          ['block-height' (numb:enjs block-height.s)]
      ==
  ==
++  parse-inputs
  |=  jon=^json
  ^-  (list tx-input)
  ?>  ?=([%a *] jon)
  %+  turn  p.jon
  |=  j=^json
  ?>  ?=([%o *] j)
  :*  (so:dejs (~(got by p.j) 'spent-txid'))
      (rash (so:dejs (~(got by p.j) 'spent-vout')) dem)
      =/  pv=^json  (~(got by p.j) 'prevout')
      ?:(=(~ pv) ~ `(parse-output pv))
  ==
++  parse-output
  |=  jon=^json
  ^-  tx-output
  ?>  ?=([%o *] jon)
  :*  (rash (so:dejs (~(got by p.jon) 'value')) dem)
      (so:dejs (~(got by p.jon) 'address'))
  ==
++  parse-outputs
  |=  jon=^json
  ^-  (list tx-output)
  ?>  ?=([%a *] jon)
  (turn p.jon parse-output)
++  parse-status
  |=  jon=^json
  ^-  tx-status
  ?>  ?=([%o *] jon)
  =/  typ=@t  (so:dejs (~(got by p.jon) 'type'))
  ?:  =('unconfirmed' typ)  [%unconfirmed ~]
  :*  %confirmed
      (so:dejs (~(got by p.jon) 'block-hash'))
      (rash (so:dejs (~(got by p.jon) 'block-height')) dem)
  ==
--
