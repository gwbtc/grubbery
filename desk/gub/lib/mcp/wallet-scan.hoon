/<  tools  /lib/nex/tools.hoon
/<  wt     /lib/wallet-types.hoon
/<  aio    /lib/wallet/account-io.hoon
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
  ?.  (~(has jo:json-utils [%o args.st]) /account)
    (pure:m [%error 'Missing required parameter: account (key from wallet_status)'])
  =/  ref=@ta
    (~(dog jo:json-utils [%o args.st]) /account so:dejs:format)
  ::  load labels
  ;<  lbl-view=view:nexus  bind:m
    (peek:io [%& %& /apps/'wallet.wallet_app' %'labels.wallet_labels'] ~)
  =/  lbls=labels:b329
    ?.  ?=([%file *] lbl-view)  *labels:b329
    (fall (mole |.(!<(labels:b329 (need-vase:tarball sang.lbl-view)))) *labels:b329)
  ?.  (has-account:aio lbls ref)
    (pure:m [%error 'Account not found'])
  ::  extract network from labels
  =/  network=network  (get-acct-network:aio lbls ref)
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
  ;<  proc-view=view:nexus  bind:m  (peek:io proc-road ~)
  =/  proc-state=(unit json)
    ?.  ?=([%file *] proc-view)  ~
    (mole |.(!<(json (need-vase:tarball sang.proc-view))))
  =/  proc-done=?
    ?~  proc-state  %.y
    =((~(dug jo:json-utils u.proc-state) /status so:dejs:format '') 'done')
  ~&  >  [%mcp-scan %news done=proc-done]
  ?.  proc-done  $
  ::  scan complete
  ~&  >  [%mcp-scan %complete]
  ;<  ~  bind:m  (drop:io /scan-proc proc-road)
    =/  net=@ta  ;;(@ta network)
    ::  reload labels (scan may have written new ones)
    ;<  lbl-view2=view:nexus  bind:m
      (peek:io [%& %& /apps/'wallet.wallet_app' %'labels.wallet_labels'] ~)
    =/  lbls2=labels:b329
      ?.  ?=([%file *] lbl-view2)  *labels:b329
      (fall (mole |.(!<(labels:b329 (need-vase:tarball sang.lbl-view2)))) *labels:b329)
    =/  og=(unit parsed-origin:b329)  (get-acct-origin:aio lbls2 ref)
    =/  [recv-count=@ud chng-count=@ud]
      ?~  og  [0 0]
      =+  (read-account-addrs:aio lbls2 u.og)
      [(lent recv) (lent chng)]
    =/  out=wain
      :~  'Scan complete.'
          (rap 3 ~['  account: ' ref])
          (rap 3 ~['  network: ' net])
          (rap 3 ~['  receive addresses: ' (scot %ud recv-count)])
          (rap 3 ~['  change addresses: ' (scot %ud chng-count)])
      ==
    (pure:m [%text (of-wain:format out)])
--
