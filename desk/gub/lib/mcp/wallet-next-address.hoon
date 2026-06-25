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
  =/  xprv=@t  (fall (~(get by acct-store) ref) '')
  ::  load recv addr-mop from flat store
  ;<  addr-seen=seen:nexus  bind:m
    (peek:io [%& %& /apps/'wallet.wallet_app' %'addresses.wallet_addresses'] ~)
  =/  addrs=addresses
    ?.  ?=([%& %file *] addr-seen)  *addresses
    (fall (mole |.(!<(addresses (need-vase:tarball sang.p.addr-seen)))) *addresses)
  =/  mops=[recv=addr-mop chng=addr-mop]
    (fall (~(get by addrs) [ref network]) [*addr-mop *addr-mop])
  =/  recv=addr-mop  recv.mops
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
