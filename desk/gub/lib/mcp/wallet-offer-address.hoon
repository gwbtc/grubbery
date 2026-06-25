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
  =/  ref=@t
    (~(dog jo:json-utils [%o args.st]) /account so:dejs:format)
  =/  target=@t
    (~(dog jo:json-utils [%o args.st]) /ship so:dejs:format)
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
  ::  derive address
  =/  addr=(unit @t)
    (derive-addr:aio xprv stype network 0 offer-idx)
  ?~  addr
    (pure:m [%error 'Address derivation failed'])
  ::  label address as offered to ship
  =/  lbl=@t  (rap 3 ~['gwbtc:offered:to:' target])
  =/  new-lbls=labels:b329
    (~(put la:b329 lbls) [%addr u.addr lbl ~ ~ ~])
  ::  advance last-offered counter
  =/  new-lbls=labels:b329
    (set-last-offered:aio new-lbls xprv offer-idx)
  ::  save labels
  =/  lbl-road=road:tarball
    [%& %& /apps/'wallet.wallet_app' %'labels.wallet_labels']
  ;<  ~  bind:m
    (over:io lbl-road [[/wallet %labels] new-lbls])
  =/  out=wain
    :~  (rap 3 ~['offered: ' u.addr])
        (rap 3 ~['to: ' target])
        (rap 3 ~['index: ' (scot %ud offer-idx)])
        (rap 3 ~['account: ' ref])
        (rap 3 ~['network: ' (scot %tas network)])
    ==
  (pure:m [%text (of-wain:format out)])
--
