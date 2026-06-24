/<  tools  /lib/nex/tools.hoon
/<  wt     /lib/wallet-types.hoon
::  wallet-addresses: list derived addresses for an account
::
=,  wt
=/  format-addrs
  |=  entries=(list [key=@ud val=address-data])
  ^-  wain
  ?~  entries  ~['  (none)']
  %+  turn  entries
  |=  [idx=@ud ad=address-data]
  ^-  @t
  =/  bal=@ud
    ?~  info.ad  0
    (sub funded.u.info.ad spent.u.info.ad)
  =/  utxo-count=@ud  (lent utxos.ad)
  %+  rap  3
  :~  '  #'  (scot %ud idx)  ' '  addr.ad
      ' bal='  (scot %ud bal)
      ' utxos='  (scot %ud utxo-count)
      ?:(loading.ad ' [loading]' '')
  ==
^-  tool:tools
|%
++  name  'wallet_addresses'
++  description
  ^~  %-  crip
  ;:  weld
    "List derived addresses for a wallet account. "
    "Shows address, balance (funded - spent), UTXO count, "
    "and last check time. Pass the account key from wallet_status."
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
  =/  acct-path=road:tarball
    [%& %& /apps/'wallet.wallet_app'/accounts/[acct-key] %'data.wallet_account']
  ;<  acct-seen=seen:nexus  bind:m  (peek:io acct-path ~)
  ?.  ?=([%& %file *] acct-seen)
    (pure:m [%error 'Account not found'])
  =/  acct=account-data
    !<(account-data (need-vase:tarball sang.p.acct-seen))
  =/  network=@ta  ;;(@ta active-network.acct)
  ::  load recv addresses
  =/  recv-path=road:tarball
    [%& %& /apps/'wallet.wallet_app'/accounts/[acct-key]/addresses/[network]/recv %'wallet_addresses']
  ;<  recv-seen=seen:nexus  bind:m  (peek:io recv-path ~)
  =/  recv=addr-mop
    ?.  ?=([%& %file *] recv-seen)  *addr-mop
    (fall (mole |.(!<(addr-mop (need-vase:tarball sang.p.recv-seen)))) *addr-mop)
  ::  load chng addresses
  =/  chng-path=road:tarball
    [%& %& /apps/'wallet.wallet_app'/accounts/[acct-key]/addresses/[network]/chng %'wallet_addresses']
  ;<  chng-seen=seen:nexus  bind:m  (peek:io chng-path ~)
  =/  chng=addr-mop
    ?.  ?=([%& %file *] chng-seen)  *addr-mop
    (fall (mole |.(!<(addr-mop (need-vase:tarball sang.p.chng-seen)))) *addr-mop)
  ::  format output
  =/  recv-entries=(list [key=@ud val=address-data])
    (tap:((on @ud address-data) gth) recv)
  =/  chng-entries=(list [key=@ud val=address-data])
    (tap:((on @ud address-data) gth) chng)
  =/  out=wain
    ;:  weld
      :~  (rap 3 ~['account: ' acct-key])
          (rap 3 ~['network: ' (scot %tas active-network.acct)])
          (rap 3 ~['script: ' (scot %tas script-type.acct)])
          ''
          'receive addresses:'
      ==
      (format-addrs recv-entries)
      ~['' 'change addresses:']
      (format-addrs chng-entries)
    ==
  (pure:m [%text (of-wain:format out)])
--
