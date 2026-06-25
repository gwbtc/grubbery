/<  tools  /lib/nex/tools.hoon
/<  wt     /lib/wallet-types.hoon
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
  ::  extract network from labels
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
