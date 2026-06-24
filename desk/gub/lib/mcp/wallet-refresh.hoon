/<  tools  /lib/nex/tools.hoon
/<  wt     /lib/wallet-types.hoon
/<  aio    /lib/wallet/account-io.hoon
::  wallet-refresh: refresh address data from mempool.space
::
=,  wt
^-  tool:tools
|%
++  name  'wallet_refresh'
++  description
  ^~  %-  crip
  ;:  weld
    "Refresh address data for a wallet account from mempool.space. "
    "Spawns refresh procs for all addresses, waits for completion, "
    "and returns updated balances. Pass the account key from wallet_status."
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
  =/  acct-key=@ta
    (~(dog jo:json-utils [%o args.st]) /account so:dejs:format)
  ::  load account data
  ;<  acct-seen=seen:nexus  bind:m
    (peek:io [%& %& /apps/'wallet.wallet_app'/accounts/[acct-key] %'data.wallet_account'] ~)
  ?.  ?=([%& %file *] acct-seen)
    (pure:m [%error 'Account not found'])
  =/  acct=account-data
    !<(account-data (need-vase:tarball sang.p.acct-seen))
  =/  network=@ta  ;;(@ta active-network.acct)
  ::  load addr-mops
  ;<  recv-seen=seen:nexus  bind:m
    (peek:io [%& %& /apps/'wallet.wallet_app'/accounts/[acct-key]/addresses/[network]/recv %'wallet_addresses'] ~)
  =/  recv=addr-mop
    ?.  ?=([%& %file *] recv-seen)  *addr-mop
    (fall (mole |.(!<(addr-mop (need-vase:tarball sang.p.recv-seen)))) *addr-mop)
  ;<  chng-seen=seen:nexus  bind:m
    (peek:io [%& %& /apps/'wallet.wallet_app'/accounts/[acct-key]/addresses/[network]/chng %'wallet_addresses'] ~)
  =/  chng=addr-mop
    ?.  ?=([%& %file *] chng-seen)  *addr-mop
    (fall (mole |.(!<(addr-mop (need-vase:tarball sang.p.chng-seen)))) *addr-mop)
  ::  collect addresses to refresh
  =/  recv-entries=(list [@ud address-data])
    (tap:((on @ud address-data) gth) recv)
  =/  chng-entries=(list [@ud address-data])
    (tap:((on @ud address-data) gth) chng)
  =/  refresh-list=(list [chain=?(%recv %chng) idx=@ud])
    %+  weld
      (turn recv-entries |=([idx=@ud *] [%recv idx]))
    (turn chng-entries |=([idx=@ud *] [%chng idx]))
  ?~  refresh-list
    (pure:m [%text 'No addresses to refresh.'])
  =/  count=@ud  (lent refresh-list)
  ::  create refresh procs
  ;<  now=@da  bind:m  get-time:io
  |-
  ?~  refresh-list
    ::  all procs spawned — wait for them to finish
    ::  each proc does 3 HTTP requests (info + utxo + txs)
    ::  allow ~s5 per address
    =/  wait-time=@dr  (mul ~s5 count)
    =/  wait-time=@dr  ?:((lth wait-time ~s10) ~s10 wait-time)
    ;<  ~  bind:m  (sleep:io wait-time)
    ::  re-read balances
    =/  recv-road=road:tarball
      [%& %& /apps/'wallet.wallet_app'/accounts/[acct-key]/addresses/[network]/recv %'wallet_addresses']
    ;<  r-seen=seen:nexus  bind:m  (peek:io recv-road ~)
    =/  r=addr-mop
      ?.  ?=([%& %file *] r-seen)  *addr-mop
      (fall (mole |.(!<(addr-mop (need-vase:tarball sang.p.r-seen)))) *addr-mop)
    =/  chng-road=road:tarball
      [%& %& /apps/'wallet.wallet_app'/accounts/[acct-key]/addresses/[network]/chng %'wallet_addresses']
    ;<  c-seen=seen:nexus  bind:m  (peek:io chng-road ~)
    =/  c=addr-mop
      ?.  ?=([%& %file *] c-seen)  *addr-mop
      (fall (mole |.(!<(addr-mop (need-vase:tarball sang.p.c-seen)))) *addr-mop)
    =/  all=(list address-data)
      %+  weld
        (turn (tap:((on @ud address-data) gth) r) |=([* v=address-data] v))
      (turn (tap:((on @ud address-data) gth) c) |=([* v=address-data] v))
    =/  total-funded=@ud
      (roll all |=([ad=address-data acc=@ud] (add acc ?~(info.ad 0 funded.u.info.ad))))
    =/  total-spent=@ud
      (roll all |=([ad=address-data acc=@ud] (add acc ?~(info.ad 0 spent.u.info.ad))))
    =/  num-utxos=@ud
      (roll all |=([ad=address-data acc=@ud] (add acc (lent utxos.ad))))
    =/  utxo-val=@ud
      (roll all |=([ad=address-data acc=@ud] (add acc (roll utxos.ad |=([u=utxo a=@ud] (add a value.u))))))
    =/  out=wain
      :~  'Refresh complete.'
          (rap 3 ~['  account: ' acct-key])
          (rap 3 ~['  network: ' (scot %tas active-network.acct)])
          (rap 3 ~['  addresses refreshed: ' (scot %ud count)])
          (rap 3 ~['  total funded: ' (scot %ud total-funded) ' sats'])
          (rap 3 ~['  total spent: ' (scot %ud total-spent) ' sats'])
          (rap 3 ~['  balance: ' (scot %ud (sub total-funded total-spent)) ' sats'])
          (rap 3 ~['  utxos: ' (scot %ud num-utxos) ' (value: ' (scot %ud utxo-val) ' sats)'])
      ==
    (pure:m [%text (of-wain:format out)])
  =/  [chain=?(%recv %chng) idx=@ud]  i.refresh-list
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  uuid=@ta  (scot %uv eny)
  =/  proc-road=road:tarball
    [%& %& /apps/'wallet.wallet_app'/proc (cat 3 uuid '.json')]
  =/  proc-json=json
    %-  pairs:enjs:format
    :~  ['type' s+'refresh']
        ['account' s+acct-key]
        ['network' s+network]
        ['chain' s+chain]
        ['index' (numb:enjs:format idx)]
    ==
  ;<  ~  bind:m  (make:io proc-road |+[[[/ %json] proc-json] ~])
  $(refresh-list t.refresh-list)
--
