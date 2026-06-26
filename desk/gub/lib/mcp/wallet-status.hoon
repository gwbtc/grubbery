/<  tools  /lib/nex/tools.hoon
/<  wt     /lib/wallet-types.hoon
/<  aio    /lib/wallet/account-io.hoon
/<  b329   /lib/bip329.hoon
/<  bip32  /lib/bip32.hoon
::  wallet-status: list wallets and their accounts with balances
::
=,  wt
^-  tool:tools
|%
++  name  'wallet_status'
++  description
  ^~  %-  crip
  ;:  weld
    "Show wallet status: lists all wallets and their accounts "
    "with network, script type, and address count."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  *(map @t parameter-def:tools)
++  required  *(list @t)
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ::  read wallet store
  ;<  store-seen=seen:nexus  bind:m
    (peek:io [%& %& /apps/'wallet.wallet_app' %'wallets.wallet_wallets'] ~)
  =/  store=wallet-store
    ?.  ?=([%& %file *] store-seen)  *wallet-store
    (fall (mole |.(!<(wallet-store (need-vase:tarball sang.p.store-seen)))) *wallet-store)
  =/  fps=(list @t)  (turn ~(tap by store) |=([xp=@t *] xp))
  ?~  fps
    (pure:m [%text 'No wallets found.'])
  ::  read labels
  ;<  lbl-seen=seen:nexus  bind:m
    (peek:io [%& %& /apps/'wallet.wallet_app' %'labels.wallet_labels'] ~)
  =/  lbls=labels:b329
    ?.  ?=([%& %file *] lbl-seen)  *labels:b329
    (fall (mole |.(!<(labels:b329 (need-vase:tarball sang.p.lbl-seen)))) *labels:b329)
  ::  read account-store
  ;<  store-seen2=seen:nexus  bind:m
    (peek:io [%& %& /apps/'wallet.wallet_app' %'accounts.wallet_accounts'] ~)
  =/  acct-store=account-store
    ?.  ?=([%& %file *] store-seen2)  *account-store
    (fall (mole |.(!<(account-store (need-vase:tarball sang.p.store-seen2)))) *account-store)
  =/  accts=(list [key=@ta ref=@t])
    %+  turn  ~(tap by acct-store)
    |=  [ref=@t *]
    [(crip (trip ref)) ref]
  ::  format output
  =/  out=wain
    %-  zing
    %+  turn  fps
    |=  xpub=@t
    ^-  wain
    =/  wal-name=@t  (get-wallet-name:aio lbls xpub)
    =/  fp=@ux
      (fall (mole |.(fingerprint:(from-extended:bip32 (trip xpub)))) 0x0)
    =/  header=@t
      (rap 3 ~['wallet: ' wal-name ' (xpub: ' (end [3 12] xpub) '...)'])
    =/  wal-accts=(list [key=@ta ref=@t])
      %+  skim  accts
      |=  [* ref=@t]
      ::  check if this ref's origin fingerprint matches this wallet
      =/  og=(unit parsed-origin:b329)  (get-acct-origin:aio lbls ref)
      =/  ref-fp=@ux
        ?~  og  0x0
        fingerprint.u.og
      =(ref-fp fp)
    ?~  wal-accts
      ~[header '  (no accounts)' '']
    =/  acct-lines=wain
      %-  zing
      %+  turn  wal-accts
      |=  [key=@ta ref=@t]
      ^-  wain
      =/  short-key=@ta
        =/  parts=(list @t)  (rash key (more dot (cook crip (star ;~(less dot prn)))))
        ?~(parts key i.parts)
      ::  look up network and script-type from labels
      =/  network=network  (get-acct-network:aio lbls ref)
      =/  stype=script-type  (get-acct-script-type:aio lbls ref)
      ::  look up xprv
      =/  xprv=@t  (fall (~(get by acct-store) ref) '')
      :~  (rap 3 ~['  account: ' short-key])
          (rap 3 ~['    network: ' (scot %tas network)])
          (rap 3 ~['    script: ' (scot %tas stype)])
          (rap 3 ~['    xprv: ' (end [3 12] xprv) '...'])
      ==
    [header acct-lines]
  (pure:m [%text (of-wain:format out)])
--
