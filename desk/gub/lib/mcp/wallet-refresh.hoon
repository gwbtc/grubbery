/<  tools  /lib/nex/tools.hoon
/<  wt     /lib/wallet-types.hoon
/<  aio    /lib/wallet/account-io.hoon
/<  b329   /lib/bip329.hoon
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
  ?.  (~(has jo:json-utils [%o args.st]) /account)
    (pure:m [%error 'Missing required parameter: account (key from wallet_status)'])
  =/  ref=@ta
    (~(dog jo:json-utils [%o args.st]) /account so:dejs:format)
  =/  chain=@t
    (~(dug jo:json-utils [%o args.st]) /chain so:dejs:format 'recv')
  =/  idx-raw=@t
    (~(dug jo:json-utils [%o args.st]) /index so:dejs:format '0')
  =/  idx=@ud  (fall (rush idx-raw dem) 0)
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
  ::  generate uuid and build proc road
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  uuid=@ta  (scot %uv eny)
  =/  proc-road=road:tarball
    [%& %& /apps/'wallet.wallet_app'/proc (cat 3 uuid '.json')]
  ::  subscribe FIRST
  ;<  *  bind:m  (keep:io /refresh-proc proc-road ~)
  ::  poke main.sig to start the refresh with our uuid
  =/  main-road=road:tarball
    [%& %& /apps/'wallet.wallet_app' %'main.sig']
  ;<  ~  bind:m
    %:  poke:io  main-road
      :-  [/ %json]
      %-  pairs:enjs:format
      :~  ['action' s+'refresh']
          ['account' s+ref]
          ['chain' s+chain]
          ['index' (numb:enjs:format idx)]
          ['uuid' s+uuid]
      ==
    ==
  ::  wait for proc to complete
  |-
  ;<  =wave:nexus  bind:m  (take-news:io /refresh-proc)
  ;<  proc-view=view:nexus  bind:m  (peek:io proc-road ~)
  =/  proc-done=?
    ?.  ?=([%file *] proc-view)  %.y
    =/  pj=json  (fall (mole |.(!<(json (need-vase:tarball sang.proc-view)))) *json)
    =((~(dug jo:json-utils pj) /status so:dejs:format '') 'done')
  ?.  proc-done  $
  ::  refresh complete
  ;<  ~  bind:m  (drop:io /refresh-proc proc-road)
    =/  chain-tag=?(%recv %chng)
      ?:(?=(%recv ;;(?(%recv %chng) (slav %tas chain))) %recv %chng)
    ::  reload labels (refresh wrote new data)
    ;<  lbl-view2=view:nexus  bind:m
      (peek:io [%& %& /apps/'wallet.wallet_app' %'labels.wallet_labels'] ~)
    =/  lbls2=labels:b329
      ?.  ?=([%file *] lbl-view2)  *labels:b329
      (fall (mole |.(!<(labels:b329 (need-vase:tarball sang.lbl-view2)))) *labels:b329)
    ::  get account origin
    =/  og-u=(unit parsed-origin:b329)  (get-acct-origin:aio lbls2 ref)
    ?~  og-u
      (pure:m [%error 'Account origin not found in labels'])
    =/  og=parsed-origin:b329  u.og-u
    ::  read recv/chng address lists
    =/  addr-lists=[recv=(list [idx=@ud addr=@t]) chng=(list [idx=@ud addr=@t])]
      (read-account-addrs:aio lbls2 og)
    =/  chain-list=(list [idx=@ud addr=@t])
      ?:(?=(%recv chain-tag) recv.addr-lists chng.addr-lists)
    ::  find address at idx
    =/  found=(unit @t)
      |-  ^-  (unit @t)
      ?~  chain-list  ~
      ?:  =(idx.i.chain-list idx)  `addr.i.chain-list
      $(chain-list t.chain-list)
    =/  out=wain
      :~  'Refresh complete.'
          (rap 3 ~['  account: ' ref])
          (rap 3 ~['  chain: ' chain])
          (rap 3 ~['  index: ' (scot %ud idx)])
          ?~  found  '  address not found at index'
          =/  info-u=(unit address-info)  (read-addr-info:aio lbls2 u.found)
          ?~  info-u  '  no chain data yet'
          (rap 3 ~['  funded: ' (scot %ud (add funded.u.info-u mem-funded.u.info-u)) ' sats'])
      ==
    (pure:m [%text (of-wain:format out)])
--
