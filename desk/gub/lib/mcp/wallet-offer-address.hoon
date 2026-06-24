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
  =/  acct-key=@ta
    (~(dog jo:json-utils [%o args.st]) /account so:dejs:format)
  =/  acct-key=@ta  (cat 3 acct-key '.wallet_account')
  =/  target=@t
    (~(dog jo:json-utils [%o args.st]) /ship so:dejs:format)
  ::  load account data
  ;<  acct-seen=seen:nexus  bind:m
    (peek:io [%& %& /apps/'wallet.wallet_app'/accounts/[acct-key] %'data.wallet_account'] ~)
  ?.  ?=([%& %file *] acct-seen)
    (pure:m [%error 'Account not found'])
  =/  acct=account-data
    !<(account-data (need-vase:tarball sang.p.acct-seen))
  =/  network=@ta  ;;(@ta active-network.acct)
  ::  load recv addr-mop
  ;<  recv-seen=seen:nexus  bind:m
    (peek:io [%& %& /apps/'wallet.wallet_app'/accounts/[acct-key]/addresses/[network]/recv %'wallet_addresses'] ~)
  =/  recv=addr-mop
    ?.  ?=([%& %file *] recv-seen)  *addr-mop
    (fall (mole |.(!<(addr-mop (need-vase:tarball sang.p.recv-seen)))) *addr-mop)
  ::  load labels
  ;<  lbl-seen=seen:nexus  bind:m
    (peek:io [%& %& /apps/'wallet.wallet_app' %'labels.wallet_labels'] ~)
  =/  lbls=labels:b329
    ?.  ?=([%& %file *] lbl-seen)  *labels:b329
    (fall (mole |.(!<(labels:b329 (need-vase:tarball sang.p.lbl-seen)))) *labels:b329)
  ::  compute next offer index
  =/  offer-idx=@ud
    (get-next-offer-index:aio recv lbls xprv.acct)
  ::  derive address
  =/  addr=(unit @t)
    (derive-addr:aio xprv.acct script-type.acct active-network.acct 0 offer-idx)
  ?~  addr
    (pure:m [%error 'Address derivation failed'])
  ::  label address as offered to ship
  =/  lbl=@t  (rap 3 ~['gwbtc:offered:to:' target])
  =/  new-lbls=labels:b329
    (~(put la:b329 lbls) [%addr u.addr lbl ~ ~ ~])
  ::  advance last-offered counter
  =/  new-lbls=labels:b329
    (set-last-offered:aio new-lbls xprv.acct offer-idx)
  ::  save labels
  =/  lbl-road=road:tarball
    [%& %& /apps/'wallet.wallet_app' %'labels.wallet_labels']
  ;<  ~  bind:m
    (over:io lbl-road [[/wallet %labels] new-lbls])
  =/  out=wain
    :~  (rap 3 ~['offered: ' u.addr])
        (rap 3 ~['to: ' target])
        (rap 3 ~['index: ' (scot %ud offer-idx)])
        (rap 3 ~['account: ' acct-key])
        (rap 3 ~['network: ' (scot %tas active-network.acct)])
    ==
  (pure:m [%text (of-wain:format out)])
--
