/<  tools  /lib/nex/tools.hoon
/<  wt     /lib/wallet-types.hoon
/<  aio    /lib/wallet/account-io.hoon
/<  b329   /lib/bip329.hoon
::  wallet-send: build, sign, and broadcast a bitcoin transaction
::
=,  wt
^-  tool:tools
|%
++  name  'wallet_send'
++  description
  ^~  %-  crip
  ;:  weld
    "Send bitcoin from a wallet account. "
    "Builds a transaction, signs it, and broadcasts via mempool.space. "
    "Amount is in satoshis. Fee rate is in sat/vB (default 2). "
    "Pass the account key from wallet_status."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  malt
  :~  ['account' [%string 'Account key (from wallet_status output)']]
      ['address' [%string 'Destination bitcoin address']]
      ['amount' [%string 'Amount in satoshis']]
      ['fee-rate' [%string 'Optional: fee rate in sat/vB (default 2)']]
  ==
++  required  ~['account' 'address' 'amount']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  acct-key=@ta
    (~(dog jo:json-utils [%o args.st]) /account so:dejs:format)
  =/  acct-key=@ta  (cat 3 acct-key '.wallet_account')
  =/  dest-addr=@t
    (~(dog jo:json-utils [%o args.st]) /address so:dejs:format)
  =/  amount-raw=@t
    (~(dog jo:json-utils [%o args.st]) /amount so:dejs:format)
  =/  fee-rate-raw=@t
    (~(dug jo:json-utils [%o args.st]) /fee-rate so:dejs:format '2')
  =/  amount=@ud  (fall (rush amount-raw dem) 0)
  =/  fee-rate=@ud  (fall (rush fee-rate-raw dem) 2)
  ?:  |(=('' dest-addr) =(0 amount))
    (pure:m [%error 'Missing address or amount'])
  ::  load account data
  ;<  acct-seen=seen:nexus  bind:m
    (peek:io [%& %& /apps/'wallet.wallet_app'/accounts/[acct-key] %'data.wallet_account'] ~)
  ?.  ?=([%& %file *] acct-seen)
    (pure:m [%error 'Account not found'])
  =/  acct=account-data
    !<(account-data (need-vase:tarball sang.p.acct-seen))
  =/  network=@ta  ;;(@ta active-network.acct)
  ::  find unused change address
  ;<  chng-seen=seen:nexus  bind:m
    (peek:io [%& %& /apps/'wallet.wallet_app'/accounts/[acct-key]/addresses/[network]/chng %'wallet_addresses'] ~)
  =/  chng=addr-mop
    ?.  ?=([%& %file *] chng-seen)  *addr-mop
    (fall (mole |.(!<(addr-mop (need-vase:tarball sang.p.chng-seen)))) *addr-mop)
  =/  change-addr=(unit @t)
    =/  leaves=(list [@ud address-data])
      (tap:((on @ud address-data) gth) chng)
    |-
    ?~  leaves  ~
    =/  [* dat=address-data]  i.leaves
    ?~  info.dat  `addr.dat
    ?:  =(0 tx-count.u.info.dat)  `addr.dat
    $(leaves t.leaves)
  =/  change-addr=@t
    ?^  change-addr  u.change-addr
    =/  next-idx=@ud
      =/  top=(unit [@ud address-data])
        (pry:((on @ud address-data) gth) chng)
      ?~  top  0
      +(-.u.top)
    %-  need
    (derive-addr:aio xprv.acct script-type.acct active-network.acct 1 next-idx)
  ::  poke account to build and broadcast
  =/  acct-road=road:tarball
    [%& %& /apps/'wallet.wallet_app'/accounts/[acct-key] %'data.wallet_account']
  =/  poke-jon  |=(=json [[/ %json] json])
  ;<  ~  bind:m
    (poke:io acct-road (poke-jon (pairs:enjs:format ~[['action' s+'clear-draft']])))
  ;<  ~  bind:m
    %:  poke:io  acct-road
      %-  poke-jon
      %-  pairs:enjs:format
      :~  ['action' s+'add-output']
          ['address' s+dest-addr]
          ['amount' (numb:enjs:format amount)]
      ==
    ==
  ;<  ~  bind:m
    %:  poke:io  acct-road
      %-  poke-jon
      %-  pairs:enjs:format
      :~  ['action' s+'set-change-config']
          ['fee-rate' (numb:enjs:format fee-rate)]
          ['change-address' s+change-addr]
      ==
    ==
  ;<  ~  bind:m
    (poke:io acct-road (poke-jon (pairs:enjs:format ~[['action' s+'run-auto-select']])))
  ;<  ~  bind:m
    (poke:io acct-road (poke-jon (pairs:enjs:format ~[['action' s+'build-transaction']])))
  =/  out=wain
    :~  'Transaction built, signed, and broadcast.'
        (rap 3 ~['  to: ' dest-addr])
        (rap 3 ~['  amount: ' (scot %ud amount) ' sats'])
        (rap 3 ~['  fee rate: ' (scot %ud fee-rate) ' sat/vB'])
        (rap 3 ~['  network: ' (scot %tas active-network.acct)])
        (rap 3 ~['  change: ' change-addr])
    ==
  (pure:m [%text (of-wain:format out)])
--
