/<  tools  /lib/nex/tools.hoon
/<  wt     /lib/wallet-types.hoon
/<  b329   /lib/bip329.hoon
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
  =/  fps=(list @ux)  (turn ~(tap by store) |=([fp=@ux *] fp))
  ?~  fps
    (pure:m [%text 'No wallets found.'])
  ::  read labels
  ;<  lbl-seen=seen:nexus  bind:m
    (peek:io [%& %& /apps/'wallet.wallet_app' %'labels.wallet_labels'] ~)
  =/  lbls=labels:b329
    ?.  ?=([%& %file *] lbl-seen)  *labels:b329
    (fall (mole |.(!<(labels:b329 (need-vase:tarball sang.p.lbl-seen)))) *labels:b329)
  ::  read accounts directory
  ;<  acct-seen=seen:nexus  bind:m
    (peek:io [%& %| /apps/'wallet.wallet_app'/accounts] ~)
  =/  accts=(list [key=@ta acct=account-data])
    ?.  ?=([%& %ball *] acct-seen)  ~
    %+  murn  ~(tap by dir.ball.p.acct-seen)
    |=  [dir-name=@ta sub=ball:tarball]
    =/  sub-lump=lump:tarball  (fall fil.sub *lump:tarball)
    =/  ct=(unit [=sang:tarball gain=? bang=(unit tang)])
      (~(get by contents.sub-lump) 'data.wallet_account')
    ?~  ct  ~
    ?.  ?=(%account name.p.sang.u.ct)  ~
    =/  acct=(unit account-data)
      (mole |.(!<(account-data (need-vase:tarball sang.u.ct))))
    ?~  acct  ~
    `[dir-name u.acct]
  ::  format output
  =/  out=wain
    %-  zing
    %+  turn  fps
    |=  fp=@ux
    ^-  wain
    =/  wal-name=@t
      =/  xpub=@t  (scot %ux fp)
      =/  entries=(list label-entry:b329)
        ~(tap in (~(get la:b329 lbls) %xpub xpub))
      =/  prefix=tape  "gwbtc:wallet:"
      =/  prefix-len=@ud  (lent prefix)
      |-
      ?~  entries  'Unnamed Wallet'
      =/  lbl=tape  (trip label.i.entries)
      ?.  =(prefix (scag prefix-len lbl))
        $(entries t.entries)
      (crip (slag prefix-len lbl))
    =/  header=@t
      (rap 3 ~['wallet: ' wal-name ' (fingerprint: ' (scot %ux fp) ')'])
    =/  wal-accts=(list [key=@ta acct=account-data])
      (skim accts |=([* a=account-data] =(wallet.a fp)))
    ?~  wal-accts
      ~[header '  (no accounts)' '']
    =/  acct-lines=wain
      %-  zing
      %+  turn  wal-accts
      |=  [key=@ta acct=account-data]
      ^-  wain
      =/  short-key=@ta
        =/  parts=(list @t)  (rash key (more dot (cook crip (star ;~(less dot prn)))))
        ?~(parts key i.parts)
      :~  (rap 3 ~['  account: ' short-key])
          (rap 3 ~['    network: ' (scot %tas active-network.acct)])
          (rap 3 ~['    script: ' (scot %tas script-type.acct)])
          (rap 3 ~['    xprv: ' (end [3 12] xprv.acct) '...'])
      ==
    [header acct-lines]
  (pure:m [%text (of-wain:format out)])
--
