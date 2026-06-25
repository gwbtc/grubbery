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
  ;<  lbl-seen=seen:nexus  bind:m
    (peek:io [%& %& /apps/'wallet.wallet_app' %'labels.wallet_labels'] ~)
  =/  lbls=labels:b329
    ?.  ?=([%& %file *] lbl-seen)  *labels:b329
    (fall (mole |.(!<(labels:b329 (need-vase:tarball sang.p.lbl-seen)))) *labels:b329)
  ::  load account-store
  ;<  as-seen=seen:nexus  bind:m
    (peek:io [%& %& /apps/'wallet.wallet_app' %'accounts.wallet_accounts'] ~)
  =/  acct-store=account-store
    ?.  ?=([%& %file *] as-seen)  *account-store
    (fall (mole |.(!<(account-store (need-vase:tarball sang.p.as-seen)))) *account-store)
  ?.  (~(has by acct-store) ref)
    (pure:m [%error 'Account not found'])
  ::  extract account metadata from labels
  =/  entries=(list label-entry:b329)
    ~(tap in (~(get la:b329 lbls) %xpub ref))
  =/  network=network
    =/  prefix=tape  "gwbtc:network:"
    =/  prefix-len=@ud  (lent prefix)
    |-
    ?~  entries  %testnet3
    =/  lbl=tape  (trip label.i.entries)
    ?.  =(prefix (scag prefix-len lbl))
      $(entries t.entries)
    ;;(network (slav %tas (crip (slag prefix-len lbl))))
  =/  og=(unit parsed-origin:b329)
    |-
    ?~  entries  ~
    ?^  origin.i.entries  origin.i.entries
    $(entries t.entries)
  =/  stype=script-type
    ?~  og  %p2wpkh
    (from-descriptor:b329 type.u.og)
  =/  xprv=@t  (fall (~(get by acct-store) ref) '')
  =/  network-ta=@ta  ;;(@ta network)
  ::  find unused change address
  ;<  addr-seen=seen:nexus  bind:m
    (peek:io [%& %& /apps/'wallet.wallet_app' %'addresses.wallet_addresses'] ~)
  =/  addrs=addresses
    ?.  ?=([%& %file *] addr-seen)  *addresses
    (fall (mole |.(!<(addresses (need-vase:tarball sang.p.addr-seen)))) *addresses)
  =/  mops=[recv=addr-mop chng=addr-mop]
    (fall (~(get by addrs) [ref network]) [*addr-mop *addr-mop])
  =/  chng=addr-mop  +.mops
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
  ;<  proc-seen=seen:nexus  bind:m  (peek:io proc-road ~)
  =/  proc-json=(unit json)
    ?.  ?=([%& %file *] proc-seen)  ~
    (mole |.(!<(json (need-vase:tarball sang.p.proc-seen))))
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
