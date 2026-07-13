/<  tools  /lib/nex/tools.hoon
/<  wt     /lib/wallet-types.hoon
/<  aio    /lib/wallet/account-io.hoon
/<  b329   /lib/bip329.hoon
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
  ::  extract network from labels
  =/  network=network  (get-acct-network:aio lbls ref)
  ::  get account origin from labels
  =/  og=(unit parsed-origin:b329)  (get-acct-origin:aio lbls ref)
  ?~  og
    (pure:m [%error 'Account origin not found in labels'])
  ::  read addresses from labels
  =/  acct-addrs  (read-account-addrs:aio lbls u.og)
  =/  all-addrs=(list @t)
    (weld (turn recv.acct-addrs |=([* a=@t] a)) (turn chng.acct-addrs |=([* a=@t] a)))
  ::  sum balances from labels
  =/  total-funded=@ud   0
  =/  total-spent=@ud    0
  =/  total-utxo-value=@ud  0
  =/  num-utxos=@ud      0
  =/  num-addrs=@ud      (lent all-addrs)
  =.  total-funded
    %+  roll  all-addrs
    |=  [a=@t acc=@ud]
    =/  info  (read-addr-info:aio lbls a)
    (add acc ?~(info 0 (add funded.u.info mem-funded.u.info)))
  =.  total-spent
    %+  roll  all-addrs
    |=  [a=@t acc=@ud]
    =/  info  (read-addr-info:aio lbls a)
    (add acc ?~(info 0 (add spent.u.info mem-spent.u.info)))
  =.  total-utxo-value
    %+  roll  all-addrs
    |=  [a=@t acc=@ud]
    =/  utxos  (read-utxos:aio lbls a)
    (add acc (roll utxos |=([u=utxo a=@ud] (add a value.u))))
  =.  num-utxos
    %+  roll  all-addrs
    |=  [a=@t acc=@ud]
    (add acc (lent (read-utxos:aio lbls a)))
  =/  out=wain
    :~  (rap 3 ~['account: ' ref])
        (rap 3 ~['network: ' (scot %tas network)])
        (rap 3 ~['addresses: ' (scot %ud num-addrs)])
        (rap 3 ~['total funded: ' (scot %ud total-funded) ' sats'])
        (rap 3 ~['total spent: ' (scot %ud total-spent) ' sats'])
        (rap 3 ~['balance: ' (scot %ud (sub total-funded total-spent)) ' sats'])
        (rap 3 ~['utxos: ' (scot %ud num-utxos) ' (value: ' (scot %ud total-utxo-value) ' sats)'])
    ==
  (pure:m [%text (of-wain:format out)])
--
