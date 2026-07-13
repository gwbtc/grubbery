/<  tools  /lib/nex/tools.hoon
/<  wt     /lib/wallet-types.hoon
/<  b329   /lib/bip329.hoon
::  wallet-freeze: freeze or thaw a UTXO (set spendable flag)
::
=,  wt
^-  tool:tools
|%
++  name  'wallet_freeze'
++  description
  ^~  %-  crip
  ;:  weld
    "Freeze or thaw a UTXO by setting its BIP-329 spendable flag. "
    "Frozen UTXOs are excluded from coin selection when building transactions. "
    "Pass action='freeze' to freeze or action='thaw' to unfreeze."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  malt
  :~  ['txid' [%string 'Transaction ID of the UTXO']]
      ['vout' [%string 'Output index (vout) of the UTXO']]
      ['action' [%string 'freeze or thaw']]
  ==
++  required  ~['txid' 'vout' 'action']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  ?.  (~(has jo:json-utils [%o args.st]) /txid)
    (pure:m [%error 'Missing required parameter: txid (transaction ID)'])
  ?.  (~(has jo:json-utils [%o args.st]) /vout)
    (pure:m [%error 'Missing required parameter: vout (output index)'])
  ?.  (~(has jo:json-utils [%o args.st]) /action)
    (pure:m [%error 'Missing required parameter: action (freeze or thaw)'])
  =/  txid=@t
    (~(dog jo:json-utils [%o args.st]) /txid so:dejs:format)
  =/  vout=@t
    (~(dog jo:json-utils [%o args.st]) /vout so:dejs:format)
  =/  act=@t
    (~(dog jo:json-utils [%o args.st]) /action so:dejs:format)
  ?.  ?=(?(%freeze %thaw) act)
    (pure:m [%error 'action must be freeze or thaw'])
  =/  ref=@t  (rap 3 ~[txid ':' vout])
  ::  load labels
  ;<  lbl-view=view:nexus  bind:m
    (peek:io [%& %& /apps/'wallet.wallet_app' %'labels.wallet_labels'] ~)
  =/  lbls=labels:b329
    ?.  ?=([%file *] lbl-view)  *labels:b329
    (fall (mole |.(!<(labels:b329 (need-vase:tarball sang.lbl-view)))) *labels:b329)
  =/  new-lbls=labels:b329
    ?:  =(%freeze act)
      (~(freeze la:b329 lbls) ref)
    (~(thaw la:b329 lbls) ref)
  ::  save labels
  =/  lbl-road=road:tarball
    [%& %& /apps/'wallet.wallet_app' %'labels.wallet_labels']
  ;<  ~  bind:m
    (over:io lbl-road [[/wallet %labels] new-lbls])
  =/  status=@t  ?:(=(%freeze act) 'frozen (spendable=no)' 'thawed (spendable)')
  =/  out=wain
    :~  (rap 3 ~['output: ' ref])
        (rap 3 ~['status: ' status])
    ==
  (pure:m [%text (of-wain:format out)])
--
