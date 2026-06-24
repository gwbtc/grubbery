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
  =/  acct-key=@ta
    (~(dog jo:json-utils [%o args.st]) /account so:dejs:format)
  =/  acct-key=@ta  (cat 3 acct-key '.wallet_account')
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
  ::  derive address at that index
  =/  addr=(unit @t)
    (derive-addr:aio xprv.acct script-type.acct active-network.acct 0 offer-idx)
  =/  last=(unit @ud)  (get-last-offered:aio lbls xprv.acct)
  ::  format output
  =/  out=wain
    :~  (rap 3 ~['account: ' acct-key])
        (rap 3 ~['network: ' (scot %tas active-network.acct)])
        (rap 3 ~['next offer index: ' (scot %ud offer-idx)])
        (rap 3 ~['address: ' (fall addr 'derivation failed')])
        (rap 3 ~['last offered: ' ?~(last 'never' (scot %ud u.last))])
    ==
  (pure:m [%text (of-wain:format out)])
--
