::  mark for address-data: per-address state with UTXOs and transactions
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
    %unconfirmed  (pairs:enjs ~[['confirmed' b+%.n]])
    %confirmed
      %-  pairs:enjs
      :~  ['confirmed' b+%.y]
          ['block-hash' s+block-hash.tx-status]
          ['block-height' (numb:enjs block-height.tx-status)]
      ==
  ==
::
++  status-from-json
  |=  jon=json
  ^-  tx-status
  ?>  ?=([%o *] jon)
  =/  conf=(unit json)  (~(get by p.jon) 'confirmed')
  ?~  conf  [%unconfirmed ~]
  ?.  ?=([%b %.y] u.conf)  [%unconfirmed ~]
  =/  bh=@t  (~(dog jo:json-utils jon) /block-hash so:dejs:format)
  =/  ht=@ud  (~(dog jo:json-utils jon) /block-height ni:dejs:format)
  [%confirmed bh ht]
--
|_  dat=address-data
++  grab
  |%
  ++  noun  address-data
  ++  json
    |=  jon=^json
    ^-  address-data
    ?>  ?=([%o *] jon)
    =/  info=(unit address-info)
      ?.  (~(has by p.jon) 'tx-count')  ~
      :-  ~
      :^    (~(dog jo:json-utils jon) /tx-count ni:dejs:format)
          (~(dog jo:json-utils jon) /funded ni:dejs:format)
        (~(dog jo:json-utils jon) /spent ni:dejs:format)
      (slav %da (~(dog jo:json-utils jon) /last-check so:dejs:format))
    :*  (~(dog jo:json-utils jon) /addr so:dejs:format)
        ;;(?(%recv %chng) (slav %tas (~(dog jo:json-utils jon) /chain so:dejs:format)))
        (~(dog jo:json-utils jon) /idx ni:dejs:format)
        ;;(?(%main %testnet3 %testnet4 %signet %regtest) (slav %tas (~(dog jo:json-utils jon) /network so:dejs:format)))
        info
        ~   :: utxos — not parsed from JSON for now
        ~   :: txs — not parsed from JSON for now
    ==
  ++  mime
    |=  [p=mite q=octs]
    ^-  address-data
    (json (need (de:json:html (@t q.q))))
  --
++  grow
  |%
  ++  noun  dat
  ++  json
    ^-  ^json
    %-  pairs:enjs
    :~  ['addr' s+addr.dat]
        ['chain' s+(scot %tas chain.dat)]
        ['idx' (numb:enjs idx.dat)]
        ['network' s+(scot %tas network.dat)]
        ?~  info.dat
          ['info' ~]
        :-  'info'
        %-  pairs:enjs
        :~  ['tx-count' (numb:enjs tx-count.u.info.dat)]
            ['funded' (numb:enjs funded.u.info.dat)]
            ['spent' (numb:enjs spent.u.info.dat)]
            ['last-check' s+(scot %da last-check.u.info.dat)]
        ==
        :-  'utxos'
        :-  %a
        %+  turn  utxos.dat
        |=  =utxo
        %-  pairs:enjs
        :~  ['txid' s+txid.utxo]
            ['vout' (numb:enjs vout.utxo)]
            ['value' (numb:enjs value.utxo)]
            ['status' (status-to-json tx-status.utxo)]
        ==
        :-  'txs'
        :-  %a
        %+  turn  txs.dat
        |=  =transaction
        %-  pairs:enjs
        :~  ['txid' s+txid.transaction]
            :-  'inputs'
            :-  %a
            %+  turn  inputs.transaction
            |=  =tx-input
            %-  pairs:enjs
            :~  ['txid' s+spent-txid.tx-input]
                ['vout' (numb:enjs spent-vout.tx-input)]
                :-  'prevout'
                ?~  prevout.tx-input  ~
                %-  pairs:enjs
                :~  ['value' (numb:enjs value.u.prevout.tx-input)]
                    ['address' s+address.u.prevout.tx-input]
                ==
            ==
            :-  'outputs'
            :-  %a
            %+  turn  outputs.transaction
            |=  =tx-output
            %-  pairs:enjs
            :~  ['value' (numb:enjs value.tx-output)]
                ['address' s+address.tx-output]
            ==
            ['status' (status-to-json tx-status.transaction)]
            :-  'fee'
            ?~(fee.transaction ~ (numb:enjs u.fee.transaction))
            :-  'size'
            ?~(size.transaction ~ (numb:enjs u.size.transaction))
        ==
    ==
  ++  mime  [/application/json (as-octs:mimes:html -:txt)]
  ++  txt   [(en:json:html json)]~
  --
--
