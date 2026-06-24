/<  tools  /lib/nex/tools.hoon
/<  wt     /lib/wallet-types.hoon
::  wallet-refresh: refresh address data from mempool.space
::
=,  wt
^-  tool:tools
|%
++  name  'wallet_refresh'
++  description
  ^~  %-  crip
  ;:  weld
    "Refresh a single address from mempool.space. "
    "Subscribes to the refresh process and waits for completion. "
    "Pass account key, chain (recv/chng), and address index."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  malt
  :~  ['account' [%string 'Account key (from wallet_status output)']]
      ['chain' [%string 'Chain: recv or chng (default: recv)']]
      ['index' [%string 'Address index (default: 0)']]
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
  =/  chain=@t
    (~(dug jo:json-utils [%o args.st]) /chain so:dejs:format 'recv')
  =/  idx-raw=@t
    (~(dug jo:json-utils [%o args.st]) /index so:dejs:format '0')
  =/  idx=@ud  (fall (rush idx-raw dem) 0)
  ::  verify account exists
  ;<  acct-seen=seen:nexus  bind:m
    (peek:io [%& %& /apps/'wallet.wallet_app'/accounts/[acct-key] %'data.wallet_account'] ~)
  ?.  ?=([%& %file *] acct-seen)
    (pure:m [%error 'Account not found'])
  =/  acct=account-data
    !<(account-data (need-vase:tarball sang.p.acct-seen))
  ::  generate uuid and build proc road
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  uuid=@ta  (scot %uv eny)
  =/  proc-road=road:tarball
    [%& %& /apps/'wallet.wallet_app'/proc (cat 3 uuid '.json')]
  ::  subscribe FIRST
  ;<  *  bind:m  (keep:io /refresh-proc proc-road ~)
  ::  poke the account to start the refresh with our uuid
  =/  acct-road=road:tarball
    [%& %& /apps/'wallet.wallet_app'/accounts/[acct-key] %'data.wallet_account']
  ;<  ~  bind:m
    %:  poke:io  acct-road
      :-  [/ %json]
      %-  pairs:enjs:format
      :~  ['action' s+'refresh']
          ['chain' s+chain]
          ['index' (numb:enjs:format idx)]
          ['uuid' s+uuid]
      ==
    ==
  ::  wait for proc to complete
  |-
  ;<  =wave:nexus  bind:m  (take-news:io /refresh-proc)
  ;<  proc-seen=seen:nexus  bind:m  (peek:io proc-road ~)
  =/  proc-done=?
    ?.  ?=([%& %file *] proc-seen)  %.y
    =/  pj=json  (fall (mole |.(!<(json (need-vase:tarball sang.p.proc-seen)))) *json)
    =((~(dug jo:json-utils pj) /status so:dejs:format '') 'done')
  ?.  proc-done  $
  ::  refresh complete
  ;<  ~  bind:m  (drop:io /refresh-proc proc-road)
    =/  net=@ta  active-network.acct
    =/  chain-tag=?(%recv %chng)
      ?:(?=(%recv ;;(?(%recv %chng) (slav %tas chain))) %recv %chng)
    ;<  addr-seen=seen:nexus  bind:m
      (peek:io [%& %& /apps/'wallet.wallet_app'/accounts/[acct-key]/addresses/[net]/[chain-tag] %'wallet_addresses'] ~)
    =/  mop=addr-mop
      ?.  ?=([%& %file *] addr-seen)  *addr-mop
      (fall (mole |.(!<(addr-mop (need-vase:tarball sang.p.addr-seen)))) *addr-mop)
    =/  dat=(unit address-data)
      (get:((on @ud address-data) gth) mop idx)
    =/  out=wain
      :~  'Refresh complete.'
          (rap 3 ~['  account: ' acct-key])
          (rap 3 ~['  chain: ' chain])
          (rap 3 ~['  index: ' (scot %ud idx)])
          ?~  dat  '  address data not found'
          ?~  info.u.dat  '  no chain data yet'
          (rap 3 ~['  funded: ' (scot %ud funded.u.info.u.dat) ' sats'])
      ==
    (pure:m [%text (of-wain:format out)])
--
