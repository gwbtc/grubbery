/<  tools  /lib/nex/tools.hoon
/<  wt     /lib/wallet-types.hoon
/<  aio    /lib/wallet/account-io.hoon
/<  b329   /lib/bip329.hoon
::  wallet-next-address: show or offer the next unused receive address
::
=,  wt
^-  tool:tools
|%
++  name  'wallet_next_address'
++  description
  ^~  %-  crip
  ;:  weld
    "Show the next address to offer for a wallet account. "
    "Shows the next-offer index, the derived address, and "
    "the last-offered index. Optionally pass 'ship' to label "
    "the address as offered to that ship and advance the counter."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  malt
  :~  ['account' [%string 'Account key (from wallet_status output)']]
  ==
++  required  ~['account']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  ?.  (~(has jo:json-utils [%o args.st]) /account)
    (pure:m [%error 'Missing required parameter: account (key from wallet_status)'])
  =/  ref=@t
    (~(dog jo:json-utils [%o args.st]) /account so:dejs:format)
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
  ::  get recv address list from labels via account origin
  =/  recv=(list [idx=@ud addr=@t])
    ?~  og  ~
    recv:(read-account-addrs:aio lbls u.og)
  ::  compute next offer index
  =/  offer-idx=@ud
    (get-next-offer-index:aio recv lbls xprv)
  ::  derive address at that index
  =/  addr=(unit @t)
    (derive-addr:aio xprv stype network 0 offer-idx)
  =/  last=(unit @ud)  (get-last-offered:aio lbls xprv)
  ::  format output
  =/  out=wain
    :~  (rap 3 ~['account: ' ref])
        (rap 3 ~['network: ' (scot %tas network)])
        (rap 3 ~['next offer index: ' (scot %ud offer-idx)])
        (rap 3 ~['address: ' (fall addr 'derivation failed')])
        (rap 3 ~['last offered: ' ?~(last 'never' (scot %ud u.last))])
    ==
  (pure:m [%text (of-wain:format out)])
--
