/<  tools  /lib/nex/tools.hoon
/<  wt     /lib/wallet-types.hoon
::  wallet-balances: show balance summary for an account
::
=,  wt
^-  tool:tools
|%
++  name  'wallet_balances'
++  description
  ^~  %-  crip
  ;:  weld
    "Show balance for a wallet account. "
    "Sums funded, spent, and UTXO values across receive and change addresses. "
    "Pass the account key from wallet_status."
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
  ::  load chng addr-mop
  ;<  chng-seen=seen:nexus  bind:m
    (peek:io [%& %& /apps/'wallet.wallet_app'/accounts/[acct-key]/addresses/[network]/chng %'wallet_addresses'] ~)
  =/  chng=addr-mop
    ?.  ?=([%& %file *] chng-seen)  *addr-mop
    (fall (mole |.(!<(addr-mop (need-vase:tarball sang.p.chng-seen)))) *addr-mop)
  ::  sum balances
  =/  recv-entries=(list [key=@ud val=address-data])
    (tap:((on @ud address-data) gth) recv)
  =/  chng-entries=(list [key=@ud val=address-data])
    (tap:((on @ud address-data) gth) chng)
  =/  all-entries=(list address-data)
    (weld (turn recv-entries |=([* v=address-data] v)) (turn chng-entries |=([* v=address-data] v)))
  =/  total-funded=@ud
    (roll all-entries |=([ad=address-data acc=@ud] (add acc ?~(info.ad 0 funded.u.info.ad))))
  =/  total-spent=@ud
    (roll all-entries |=([ad=address-data acc=@ud] (add acc ?~(info.ad 0 spent.u.info.ad))))
  =/  total-utxo-value=@ud
    %+  roll  all-entries
    |=  [ad=address-data acc=@ud]
    (add acc (roll utxos.ad |=([u=utxo a=@ud] (add a value.u))))
  =/  num-addrs=@ud  (lent all-entries)
  =/  num-utxos=@ud
    (roll all-entries |=([ad=address-data acc=@ud] (add acc (lent utxos.ad))))
  =/  out=wain
    :~  (rap 3 ~['account: ' acct-key])
        (rap 3 ~['network: ' (scot %tas active-network.acct)])
        (rap 3 ~['addresses: ' (scot %ud num-addrs)])
        (rap 3 ~['total funded: ' (scot %ud total-funded) ' sats'])
        (rap 3 ~['total spent: ' (scot %ud total-spent) ' sats'])
        (rap 3 ~['balance: ' (scot %ud (sub total-funded total-spent)) ' sats'])
        (rap 3 ~['utxos: ' (scot %ud num-utxos) ' (value: ' (scot %ud total-utxo-value) ' sats)'])
    ==
  (pure:m [%text (of-wain:format out)])
--
