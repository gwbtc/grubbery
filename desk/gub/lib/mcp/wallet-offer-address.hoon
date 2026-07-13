/<  tools  /lib/nex/tools.hoon
/<  wt     /lib/wallet-types.hoon
/<  aio    /lib/wallet/account-io.hoon
/<  b329   /lib/bip329.hoon
::  wallet-offer-address: offer the next address to a ship
::
::  Labels the next unused address as offered to the given ship,
::  advances the last-offered counter, and returns the address.
::
=,  wt
^-  tool:tools
|%
++  name  'wallet_offer_address'
++  description
  ^~  %-  crip
  ;:  weld
    "Offer the next unused receive address to a ship. "
    "Labels the address as offered and advances the counter. "
    "Each call returns a fresh, never-reused address."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  malt
  :~  ['account' [%string 'Account key (from wallet_status output)']]
      ['ship' [%string 'Ship to offer the address to (e.g. ~zod)']]
  ==
++  required  ~['account' 'ship']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  ?.  (~(has jo:json-utils [%o args.st]) /account)
    (pure:m [%error 'Missing required parameter: account (account key from wallet_status)'])
  ?.  (~(has jo:json-utils [%o args.st]) /ship)
    (pure:m [%error 'Missing required parameter: ship (e.g. ~zod)'])
  =/  ref=@t
    (~(dog jo:json-utils [%o args.st]) /account so:dejs:format)
  =/  target=@t
    (~(dog jo:json-utils [%o args.st]) /ship so:dejs:format)
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
  ::  derive recv address list from labels
  =/  recv=(list [idx=@ud addr=@t])
    ?~  og  ~
    recv:(read-account-addrs:aio lbls u.og)
  ::  compute next offer index
  =/  offer-idx=@ud
    (get-next-offer-index:aio recv lbls ref)
  ::  derive address
  =/  addr=(unit @t)
    (derive-addr:aio xprv stype network 0 offer-idx)
  ?~  addr
    (pure:m [%error 'Address derivation failed'])
  ::  label address as offered to ship
  =/  lbl=@t  (rap 3 ~['gwbtc:offered:to:' target])
  =/  new-lbls=labels:b329
    (label-derived-addr:aio lbls u.addr lbl og 0 offer-idx ref)
  ::  advance last-offered counter
  =/  new-lbls=labels:b329
    (set-last-offered:aio new-lbls ref offer-idx)
  ::  save labels
  =/  lbl-road=road:tarball
    [%& %& /apps/'wallet.wallet_app' %'labels.wallet_labels']
  ;<  ~  bind:m
    (over:io lbl-road [[/wallet %labels] new-lbls])
  =/  out=wain
    :~  (rap 3 ~['offered: ' u.addr])
        (rap 3 ~['to: ' target])
        (rap 3 ~['index: ' (scot %ud offer-idx)])
        (rap 3 ~['account: ' ref])
        (rap 3 ~['network: ' (scot %tas network)])
    ==
  (pure:m [%text (of-wain:format out)])
--
