/<  tools  /lib/nex/tools.hoon
/<  wt     /lib/wallet-types.hoon
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
  =/  acct-key=@ta
    (~(dog jo:json-utils [%o args.st]) /account so:dejs:format)
  =/  acct-key=@ta  (cat 3 acct-key '.wallet_account')
  ::  verify account exists
  ;<  acct-seen=seen:nexus  bind:m
    (peek:io [%& %& /apps/'wallet.wallet_app'/accounts/[acct-key] %'data.wallet_account'] ~)
  ?.  ?=([%& %file *] acct-seen)
    (pure:m [%error 'Account not found'])
  =/  acct=account-data
    !<(account-data (need-vase:tarball sang.p.acct-seen))
  ::  generate uuid for the scan proc
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  uuid=@ta  (scot %uv eny)
  ~&  >  [%mcp-scan %start acct-key uuid]
  =/  proc-road=road:tarball
    [%& %& /apps/'wallet.wallet_app'/proc (cat 3 uuid '.json')]
  ::  subscribe FIRST
  ;<  *  bind:m  (keep:io /scan-proc proc-road ~)
  ~&  >  [%mcp-scan %subscribed]
  ::  poke the account to start the scan with our uuid
  =/  acct-road=road:tarball
    [%& %& /apps/'wallet.wallet_app'/accounts/[acct-key] %'data.wallet_account']
  ;<  ~  bind:m
    %:  poke:io  acct-road
      :-  [/ %json]
      %-  pairs:enjs:format
      :~  ['action' s+'full-scan']
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
    =/  net=@ta  active-network.acct
    ;<  recv-seen=seen:nexus  bind:m
      (peek:io [%& %& /apps/'wallet.wallet_app'/accounts/[acct-key]/addresses/[net]/recv %'wallet_addresses'] ~)
    =/  recv=addr-mop
      ?.  ?=([%& %file *] recv-seen)  *addr-mop
      (fall (mole |.(!<(addr-mop (need-vase:tarball sang.p.recv-seen)))) *addr-mop)
    ;<  chng-seen=seen:nexus  bind:m
      (peek:io [%& %& /apps/'wallet.wallet_app'/accounts/[acct-key]/addresses/[net]/chng %'wallet_addresses'] ~)
    =/  chng=addr-mop
      ?.  ?=([%& %file *] chng-seen)  *addr-mop
      (fall (mole |.(!<(addr-mop (need-vase:tarball sang.p.chng-seen)))) *addr-mop)
    =/  recv-count=@ud  (lent (tap:((on @ud address-data) gth) recv))
    =/  chng-count=@ud  (lent (tap:((on @ud address-data) gth) chng))
    =/  out=wain
      :~  'Scan complete.'
          (rap 3 ~['  account: ' acct-key])
          (rap 3 ~['  network: ' net])
          (rap 3 ~['  receive addresses: ' (scot %ud recv-count)])
          (rap 3 ~['  change addresses: ' (scot %ud chng-count)])
      ==
    (pure:m [%text (of-wain:format out)])
--
