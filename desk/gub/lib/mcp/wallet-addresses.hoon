/<  tools  /lib/nex/tools.hoon
/<  wt     /lib/wallet-types.hoon
/<  aio    /lib/wallet/account-io.hoon
/<  b329   /lib/bip329.hoon
::  wallet-addresses: list derived addresses for an account
::
=,  wt
=/  format-addrs
  |=  [lbls=labels:b329 entries=(list [key=@ud addr=@t])]
  ^-  wain
  ?~  entries  ~['  (none)']
  %+  turn  entries
  |=  [idx=@ud addr=@t]
  ^-  @t
  =/  info=(unit address-info)  (read-addr-info:aio lbls addr)
  =/  bal=@ud
    ?~  info  0
    (sub (add funded.u.info mem-funded.u.info) (add spent.u.info mem-spent.u.info))
  =/  utxo-count=@ud  (lent (read-utxos:aio lbls addr))
  %+  rap  3
  :~  '  #'  (scot %ud idx)  ' '  addr
      ' bal='  (scot %ud bal)
      ' utxos='  (scot %ud utxo-count)
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
  ::  extract account metadata from labels
  =/  network=network  (get-acct-network:aio lbls ref)
  =/  og=(unit parsed-origin:b329)  (get-acct-origin:aio lbls ref)
  =/  stype=script-type  (get-acct-script-type:aio lbls ref)
  ::  read addresses via labels
  ?~  og
    (pure:m [%error 'Account origin not found in labels'])
  =/  addr-lists  (read-account-addrs:aio lbls u.og)
  ::  format output
  =/  out=wain
    ;:  weld
      :~  (rap 3 ~['account: ' ref])
          (rap 3 ~['network: ' (scot %tas network)])
          (rap 3 ~['script: ' (scot %tas stype)])
          ''
          'receive addresses:'
      ==
      (format-addrs lbls recv.addr-lists)
      ~['' 'change addresses:']
      (format-addrs lbls chng.addr-lists)
    ==
  (pure:m [%text (of-wain:format out)])
--
