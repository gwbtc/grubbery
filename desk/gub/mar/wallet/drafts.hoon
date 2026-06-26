::  mark for drafts: flat map of acct-ref to transaction draft
::
/<  drft  /lib/tx/draft.hoon
=,  format
|_  dat=(map @t transaction:drft)
++  grab
  |%
  ++  noun  (map @t transaction:drft)
  ++  json
    |=  jon=^json
    ^-  (map @t transaction:drft)
    ?>  ?=([%o *] jon)
    %-  malt
    %+  turn  ~(tap by p.jon)
    |=  [k=@t v=^json]
    [k (transaction-from-json v)]
  ++  mime
    |=  [p=mite q=octs]
    ^-  (map @t transaction:drft)
    (json (need (de:json:html (@t q.q))))
  --
++  grow
  |%
  ++  noun  dat
  ++  json
    ^-  ^json
    :-  %o
    %-  malt
    %+  turn  ~(tap by dat)
    |=  [k=@t v=transaction:drft]
    [k (transaction-to-json v)]
  ++  mime  [/application/json (as-octs:mimes:html -:txt)]
  ++  txt   [(en:json:html json)]~
  --
++  transaction-to-json
  |=  tx=transaction:drft
  ^-  json
  %-  pairs:enjs
  :~  :-  'inputs'
      :-  %a
      %+  turn  inputs.tx
      |=  i=utxo-input:drft
      %-  pairs:enjs
      :~  ['txid' s+txid.i]
          ['vout' (numb:enjs vout.i)]
          ['amount' (numb:enjs amount.i)]
          ['spend' s+(scot %tas spend.i)]
      ==
    ::
      :-  'outputs'
      :-  %a
      %+  turn  outputs.tx
      |=  o=output:drft
      %-  pairs:enjs
      :~  ['address' s+address.o]
          ['amount' (numb:enjs amount.o)]
      ==
    ::
      :-  'change'
      ?~  change.tx  ~
      %-  pairs:enjs
      :~  ['fee-rate' (numb:enjs fee-rate.u.change.tx)]
          ['address' s+address.u.change.tx]
      ==
    ::
      :-  'auto-select'
      ?~  auto-select.tx  ~
      s+(scot %tas u.auto-select.tx)
    ::
      ['created' s+(scot %da created.tx)]
      ['modified' s+(scot %da modified.tx)]
  ==
++  transaction-from-json
  |=  jon=json
  ^-  transaction:drft
  ?>  ?=([%o *] jon)
  =/  m  p.jon
  =/  inputs=(list utxo-input:drft)
    =/  v  (~(get by m) 'inputs')
    ?~  v  ~
    ?.  ?=([%a *] u.v)  ~
    %+  turn  p.u.v
    |=  ij=json
    ?>  ?=([%o *] ij)
    :*  (so:dejs:format (need (~(get by p.ij) 'txid')))
        (ni:dejs:format (need (~(get by p.ij) 'vout')))
        (ni:dejs:format (need (~(get by p.ij) 'amount')))
        ;;(spend:fees:drft (slav %tas (so:dejs:format (need (~(get by p.ij) 'spend')))))
    ==
  =/  outputs=(list output:drft)
    =/  v  (~(get by m) 'outputs')
    ?~  v  ~
    ?.  ?=([%a *] u.v)  ~
    %+  turn  p.u.v
    |=  oj=json
    ?>  ?=([%o *] oj)
    :*  (so:dejs:format (need (~(get by p.oj) 'address')))
        (ni:dejs:format (need (~(get by p.oj) 'amount')))
    ==
  =/  change=(unit change-config:drft)
    =/  v  (~(get by m) 'change')
    ?~  v  ~
    ?.  ?=([%o *] u.v)  ~
    :-  ~
    :*  (ni:dejs:format (need (~(get by p.u.v) 'fee-rate')))
        (so:dejs:format (need (~(get by p.u.v) 'address')))
    ==
  =/  auto-select=(unit select-mode:drft)
    =/  v  (~(get by m) 'auto-select')
    ?~  v  ~
    ?.  ?=([%s *] u.v)  ~
    ?:  =(%'' p.u.v)  ~
    `;;(select-mode:drft (slav %tas p.u.v))
  =/  created=@da
    =/  v  (~(get by m) 'created')
    ?~  v  *@da
    ?.  ?=([%s *] u.v)  *@da
    (slav %da p.u.v)
  =/  modified=@da
    =/  v  (~(get by m) 'modified')
    ?~  v  *@da
    ?.  ?=([%s *] u.v)  *@da
    (slav %da p.u.v)
  [inputs outputs change auto-select created modified]
--
