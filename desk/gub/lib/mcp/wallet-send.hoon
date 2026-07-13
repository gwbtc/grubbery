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
  ?.  (~(has jo:json-utils [%o args.st]) /account)
    (pure:m [%error 'Missing required parameter: account (account key from wallet_status)'])
  ?.  (~(has jo:json-utils [%o args.st]) /address)
    (pure:m [%error 'Missing required parameter: address (destination bitcoin address)'])
  ?.  (~(has jo:json-utils [%o args.st]) /amount)
    (pure:m [%error 'Missing required parameter: amount (amount in satoshis)'])
  =/  ref=@ta
    (~(dog jo:json-utils [%o args.st]) /account so:dejs:format)
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
  ::  load labels
  ;<  lbl-view=view:nexus  bind:m
    (peek:io [%& %& /apps/'wallet.wallet_app' %'labels.wallet_labels'] ~)
  =/  lbls=labels:b329
    ?.  ?=([%file *] lbl-view)  *labels:b329
    (fall (mole |.(!<(labels:b329 (need-vase:tarball sang.lbl-view)))) *labels:b329)
  ?.  (has-account:aio lbls ref)
    (pure:m [%error 'Account not found'])
  ::  load secrets for xprv derivation
  ;<  ws-view=view:nexus  bind:m
    (peek:io [%& %& /apps/'wallet.wallet_app' %'secrets.wallet_secrets'] ~)
  =/  wstore=secrets
    ?.  ?=([%file *] ws-view)  *secrets
    (fall (mole |.(!<(secrets (need-vase:tarball sang.ws-view)))) *secrets)
  ::  extract account metadata from labels
  =/  network=network  (get-acct-network:aio lbls ref)
  =/  og=(unit parsed-origin:b329)  (get-acct-origin:aio lbls ref)
  =/  stype=script-type  (get-acct-script-type:aio lbls ref)
  =/  xprv=(unit @t)  (derive-xprv:aio lbls wstore ref)
  ?~  xprv  (pure:m [%error 'Could not derive account key'])
  =/  xprv=@t  u.xprv
  =/  network-ta=@ta  ;;(@ta network)
  ::  find unused change address from labels
  ?~  og
    (pure:m [%error 'Account origin not found in labels'])
  =/  acct-addrs  (read-account-addrs:aio lbls u.og)
  =/  chng=(list [idx=@ud addr=@t])  chng.acct-addrs
  =/  change-addr=(unit @t)
    |-
    ?~  chng  ~
    =/  info=(unit address-info:aio)  (read-addr-info:aio lbls addr.i.chng)
    ?~  info  `addr.i.chng
    ?:  =(0 tx-count.u.info)  `addr.i.chng
    $(chng t.chng)
  =/  change-addr=@t
    ?^  change-addr  u.change-addr
    =/  next-idx=@ud
      ?~  chng  0
      +((roll (turn chng |=([idx=@ud *] idx)) max))
    %-  need
    (derive-addr:aio xprv stype network 1 next-idx)
  ::  generate uuid and build proc road
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  uuid=@ta  (scot %uv eny)
  =/  proc-road=road:tarball
    [%& %& /apps/'wallet.wallet_app'/proc (cat 3 uuid '.json')]
  ::  subscribe FIRST
  ;<  *  bind:m  (keep:io /send-proc proc-road ~)
  ::  poke main.sig with send action
  =/  main-road=road:tarball
    [%& %& /apps/'wallet.wallet_app' %'main.sig']
  ;<  ~  bind:m
    %:  poke:io  main-road
      :-  [/ %json]
      %-  pairs:enjs:format
      :~  ['action' s+'send']
          ['account' s+ref]
          ['address' s+dest-addr]
          ['amount' (numb:enjs:format amount)]
          ['fee-rate' (numb:enjs:format fee-rate)]
          ['change-address' s+change-addr]
          ['uuid' s+uuid]
      ==
    ==
  ::  wait for proc to complete
  |-
  ;<  =wave:nexus  bind:m  (take-news:io /send-proc)
  ;<  proc-view=view:nexus  bind:m  (peek:io proc-road ~)
  =/  proc-json=(unit json)
    ?.  ?=([%file *] proc-view)  ~
    (mole |.(!<(json (need-vase:tarball sang.proc-view))))
  =/  proc-status=@t
    ?~  proc-json  ''
    (~(dug jo:json-utils u.proc-json) /status so:dejs:format '')
  ?:  =('' proc-status)  $
  ::  proc finished — clean up subscription
  ;<  ~  bind:m  (drop:io /send-proc proc-road)
  ?:  =('error' proc-status)
    =/  err=@t
      ?~  proc-json  'Unknown error'
      (~(dug jo:json-utils u.proc-json) /error so:dejs:format 'Unknown error')
    (pure:m [%error err])
  =/  out=wain
    :~  'Transaction built, signed, and broadcast.'
        (rap 3 ~['  to: ' dest-addr])
        (rap 3 ~['  amount: ' (scot %ud amount) ' sats'])
        (rap 3 ~['  fee rate: ' (scot %ud fee-rate) ' sat/vB'])
        (rap 3 ~['  network: ' (scot %tas network)])
        (rap 3 ~['  change: ' change-addr])
    ==
  (pure:m [%text (of-wain:format out)])
--
