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
  ::  read secrets
  ;<  sec-view=view:nexus  bind:m
    (peek:io [%& %& /apps/'wallet.wallet_app' %'secrets.wallet_secrets'] ~)
  =/  sec=secrets
    ?.  ?=([%file *] sec-view)  *secrets
    (fall (mole |.(!<(secrets (need-vase:tarball sang.sec-view)))) *secrets)
  =/  fps=(list @t)  (turn ~(tap by seeds.sec) |=([xp=@t *] xp))
  ?~  fps
    (pure:m [%text 'No wallets found.'])
  ::  read labels
  ;<  lbl-view=view:nexus  bind:m
    (peek:io [%& %& /apps/'wallet.wallet_app' %'labels.wallet_labels'] ~)
  =/  lbls=labels:b329
    ?.  ?=([%file *] lbl-view)  *labels:b329
    (fall (mole |.(!<(labels:b329 (need-vase:tarball sang.lbl-view)))) *labels:b329)
  ::  enumerate all accounts from labels (xpub entries with account name)
  =/  all-refs=(list @t)
    %+  murn  ~(tap by xpub.lbls)
    |=  [ref=@t *]
    ^-  (unit @t)
    ?.  (has-account:aio lbls ref)  ~
    `ref
  ::  split into wallet-derived and standalone
  =/  wallet-accts=(list @t)
    (skim all-refs |=(ref=@t ?=(^ (get-acct-origin:aio lbls ref))))
  =/  standalone-accts=(list @t)
    (skip all-refs |=(ref=@t ?=(^ (get-acct-origin:aio lbls ref))))
  ::  helper: format one account
  =/  fmt-acct
    |=  ref=@t
    ^-  wain
    =/  network=network  (get-acct-network:aio lbls ref)
    =/  stype=script-type  (get-acct-script-type:aio lbls ref)
    =/  xprv=@t  (fall (derive-xprv:aio lbls sec ref) '')
    =/  acct-name=@t  (get-acct-name:aio lbls ref)
    =/  mode=@t
      ?:  !=('' xprv)  'signing'
      'watch-only'
    :~  (rap 3 ~['  account: ' ref])
        (rap 3 ~['    name: ' acct-name])
        (rap 3 ~['    network: ' (scot %tas network)])
        (rap 3 ~['    script: ' (scot %tas stype)])
        (rap 3 ~['    mode: ' mode])
        ?:  =('' xprv)  '    xprv: (none)'
        (rap 3 ~['    xprv: ' (end [3 12] xprv) '...'])
    ==
  ::  format wallet sections
  =/  wallet-out=wain
    %-  zing
    %+  turn  fps
    |=  xpub=@t
    ^-  wain
    =/  wal-name=@t  (get-wallet-name:aio lbls xpub)
    =/  fp=@ux
      (fall (mole |.(fingerprint:(from-extended:bip32 (trip xpub)))) 0x0)
    =/  header=@t
      (rap 3 ~['wallet: ' wal-name ' (xpub: ' (end [3 12] xpub) '...)'])
    =/  wal-refs=(list @t)
      %+  skim  wallet-accts
      |=  ref=@t
      =/  og=(unit parsed-origin:b329)  (get-acct-origin:aio lbls ref)
      ?~  og  %.n
      =(fingerprint.u.og fp)
    ?~  wal-refs
      ~[header '  (no accounts)' '']
    [header (zing (turn wal-refs fmt-acct))]
  ::  format standalone section
  =/  standalone-out=wain
    ?~  standalone-accts  ~
    ['standalone accounts:' (zing (turn standalone-accts fmt-acct))]
  (pure:m [%text (of-wain:format (weld wallet-out standalone-out))])
--
