/<  tools  /lib/nex/tools.hoon
/<  wt     /lib/wallet-types.hoon
/<  b329   /lib/bip329.hoon
::  wallet-scan: run a full address scan on a wallet account
::
=,  wt
^-  tool:tools
|%
++  name  'wallet_scan'
++  description
  ^~  %-  crip
  ;:  weld
    "Run a full address scan on a wallet account. "
    "Discovers all used addresses on both receive and change chains. "
    "Subscribes to the scan process and reports progress. "
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
  =/  ref=@ta
    (~(dog jo:json-utils [%o args.st]) /account so:dejs:format)
  ::  verify account exists via flat store
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
  ::  generate uuid for the scan proc
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  uuid=@ta  (scot %uv eny)
  ~&  >  [%mcp-scan %start ref uuid]
  =/  proc-road=road:tarball
    [%& %& /apps/'wallet.wallet_app'/proc (cat 3 uuid '.json')]
  ::  subscribe FIRST
  ;<  *  bind:m  (keep:io /scan-proc proc-road ~)
  ~&  >  [%mcp-scan %subscribed]
  ::  poke main.sig to start the scan with our uuid
  =/  main-road=road:tarball
    [%& %& /apps/'wallet.wallet_app' %'main.sig']
  ;<  ~  bind:m
    %:  poke:io  main-road
      :-  [/ %json]
      %-  pairs:enjs:format
      :~  ['action' s+'full-scan']
          ['account' s+ref]
          ['uuid' s+uuid]
      ==
    ==
  ~&  >  [%mcp-scan %poked %waiting]
  ::  wait for scan to complete — check status field
  |-
  ;<  =wave:nexus  bind:m  (take-news:io /scan-proc)
  ;<  proc-seen=seen:nexus  bind:m  (peek:io proc-road ~)
  =/  proc-state=(unit json)
    ?.  ?=([%& %file *] proc-seen)  ~
    (mole |.(!<(json (need-vase:tarball sang.p.proc-seen))))
  =/  proc-done=?
    ?~  proc-state  %.y
    =((~(dug jo:json-utils u.proc-state) /status so:dejs:format '') 'done')
  ~&  >  [%mcp-scan %news done=proc-done]
  ?.  proc-done  $
  ::  scan complete
  ~&  >  [%mcp-scan %complete]
  ;<  ~  bind:m  (drop:io /scan-proc proc-road)
    =/  net=@ta  ;;(@ta network)
    ;<  addr-seen=seen:nexus  bind:m
      (peek:io [%& %& /apps/'wallet.wallet_app' %'addresses.wallet_addresses'] ~)
    =/  addrs=addresses
      ?.  ?=([%& %file *] addr-seen)  *addresses
      (fall (mole |.(!<(addresses (need-vase:tarball sang.p.addr-seen)))) *addresses)
    =/  mops=[recv=addr-mop chng=addr-mop]
      (fall (~(get by addrs) [ref network]) [*addr-mop *addr-mop])
    =/  recv-count=@ud  (lent (tap:((on @ud address-data) gth) -.mops))
    =/  chng-count=@ud  (lent (tap:((on @ud address-data) gth) +.mops))
    =/  out=wain
      :~  'Scan complete.'
          (rap 3 ~['  account: ' ref])
          (rap 3 ~['  network: ' net])
          (rap 3 ~['  receive addresses: ' (scot %ud recv-count)])
          (rap 3 ~['  change addresses: ' (scot %ud chng-count)])
      ==
    (pure:m [%text (of-wain:format out)])
--
