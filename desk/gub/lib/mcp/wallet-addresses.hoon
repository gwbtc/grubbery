/<  tools  /lib/nex/tools.hoon
/<  wt     /lib/wallet-types.hoon
/<  b329   /lib/bip329.hoon
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
  =/  ref=@t
    (~(dog jo:json-utils [%o args.st]) /account so:dejs:format)
  ::  load account-store
  ;<  as-seen=seen:nexus  bind:m
    (peek:io [%& %& /apps/'wallet.wallet_app' %'accounts.wallet_accounts'] ~)
  =/  acct-store=account-store
    ?.  ?=([%& %file *] as-seen)  *account-store
    (fall (mole |.(!<(account-store (need-vase:tarball sang.p.as-seen)))) *account-store)
  ?.  (~(has by acct-store) ref)
    (pure:m [%error 'Account not found'])
  ::  load labels
  ;<  lbl-seen=seen:nexus  bind:m
    (peek:io [%& %& /apps/'wallet.wallet_app' %'labels.wallet_labels'] ~)
  =/  lbls=labels:b329
    ?.  ?=([%& %file *] lbl-seen)  *labels:b329
    (fall (mole |.(!<(labels:b329 (need-vase:tarball sang.p.lbl-seen)))) *labels:b329)
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
  ::  load addresses flat store
  ;<  addr-seen=seen:nexus  bind:m
    (peek:io [%& %& /apps/'wallet.wallet_app' %'addresses.wallet_addresses'] ~)
  =/  addrs=addresses
    ?.  ?=([%& %file *] addr-seen)  *addresses
    (fall (mole |.(!<(addresses (need-vase:tarball sang.p.addr-seen)))) *addresses)
  =/  mops=[recv=addr-mop chng=addr-mop]
    (fall (~(get by addrs) [ref network]) [*addr-mop *addr-mop])
  =/  recv=addr-mop  recv.mops
  =/  chng=addr-mop  chng.mops
  ::  format output
  =/  recv-entries=(list [key=@ud val=address-data])
    (tap:((on @ud address-data) gth) recv)
  =/  chng-entries=(list [key=@ud val=address-data])
    (tap:((on @ud address-data) gth) chng)
  =/  out=wain
    ;:  weld
      :~  (rap 3 ~['account: ' ref])
          (rap 3 ~['network: ' (scot %tas network)])
          (rap 3 ~['script: ' (scot %tas stype)])
          ''
          'receive addresses:'
      ==
      (format-addrs recv-entries)
      ~['' 'change addresses:']
      (format-addrs chng-entries)
    ==
  (pure:m [%text (of-wain:format out)])
--
