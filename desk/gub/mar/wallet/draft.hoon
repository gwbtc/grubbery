::  mark for transaction draft state
::
/<  drft  /lib/tx/draft.hoon
/<  fees  /lib/tx/fees.hoon
=,  format
|_  draft=transaction:drft
++  grab
  |%
  ++  noun  transaction:drft
  ++  json
    |=  jon=^json
    ^-  transaction:drft
    ?>  ?=([%o *] jon)
    =/  m  p.jon
    ::  parse inputs array
    ::
    =/  inputs=(list utxo-input:drft)
      =/  v  (~(get by m) 'inputs')
      ?~  v  ~
      ?.  ?=([%a *] u.v)  ~
      (turn p.u.v parse-input)
    ::  parse outputs array
    ::
    =/  outputs=(list output:drft)
      =/  v  (~(get by m) 'outputs')
      ?~  v  ~
      ?.  ?=([%a *] u.v)  ~
      (turn p.u.v parse-output)
    ::  parse change (unit)
    ::
    =/  change=(unit change-config:drft)
      =/  v  (~(get by m) 'change')
      ?~  v  ~
      ?.  ?=([%o *] u.v)  ~
      `(parse-change u.v)
    ::  parse auto-select (unit)
    ::
    =/  auto-select=(unit select-mode:drft)
      =/  v  (~(get by m) 'auto-select')
      ?~  v  ~
      ?.  ?=([%s *] u.v)  ~
      ?:  =(%'' p.u.v)  ~
      `;;(select-mode:drft (slav %tas p.u.v))
    ::  timestamps
    ::
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
  ++  mime
    |=  [p=mite q=octs]
    ^-  transaction:drft
    (json (need (de:json:html (@t q.q))))
  --
++  grow
  |%
  ++  noun  draft
  ++  json
    ^-  ^json
    %-  pairs:enjs
    :~  :-  'inputs'
        :-  %a
        %+  turn  inputs.draft
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
        %+  turn  outputs.draft
        |=  o=output:drft
        %-  pairs:enjs
        :~  ['address' s+address.o]
            ['amount' (numb:enjs amount.o)]
        ==
      ::
        :-  'change'
        ?~  change.draft  ~
        %-  pairs:enjs
        :~  ['fee-rate' (numb:enjs fee-rate.u.change.draft)]
            ['address' s+address.u.change.draft]
        ==
      ::
        :-  'auto-select'
        ?~  auto-select.draft  ~
        s+(scot %tas u.auto-select.draft)
      ::
        ['created' s+(scot %da created.draft)]
        ['modified' s+(scot %da modified.draft)]
    ==
  ++  mime  [/application/json (as-octs:mimes:html -:txt)]
  ++  txt   [(en:json:html json)]~
  --
::  helper parsers
::
++  parse-input
  |=  jon=json
  ^-  utxo-input:drft
  ?>  ?=([%o *] jon)
  =/  m  p.jon
  :*  (so:dejs:format (need (~(get by m) 'txid')))
      (ni:dejs:format (need (~(get by m) 'vout')))
      (ni:dejs:format (need (~(get by m) 'amount')))
      ;;(spend:fees (slav %tas (so:dejs:format (need (~(get by m) 'spend')))))
  ==
++  parse-output
  |=  jon=json
  ^-  output:drft
  ?>  ?=([%o *] jon)
  =/  m  p.jon
  :*  (so:dejs:format (need (~(get by m) 'address')))
      (ni:dejs:format (need (~(get by m) 'amount')))
  ==
++  parse-change
  |=  jon=json
  ^-  change-config:drft
  ?>  ?=([%o *] jon)
  =/  m  p.jon
  :*  (ni:dejs:format (need (~(get by m) 'fee-rate')))
      (so:dejs:format (need (~(get by m) 'address')))
  ==
--
