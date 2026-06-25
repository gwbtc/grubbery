/<  tools  /lib/nex/tools.hoon
/<  wt     /lib/wallet-types.hoon
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
  =/  ref=@ta
    (~(dog jo:json-utils [%o args.st]) /account so:dejs:format)
  =/  chain=@t
    (~(dug jo:json-utils [%o args.st]) /chain so:dejs:format 'recv')
  =/  idx-raw=@t
    (~(dug jo:json-utils [%o args.st]) /index so:dejs:format '0')
  =/  idx=@ud  (fall (rush idx-raw dem) 0)
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
  ;<  proc-seen=seen:nexus  bind:m  (peek:io proc-road ~)
  =/  proc-done=?
    ?.  ?=([%& %file *] proc-seen)  %.y
    =/  pj=json  (fall (mole |.(!<(json (need-vase:tarball sang.p.proc-seen)))) *json)
    =((~(dug jo:json-utils pj) /status so:dejs:format '') 'done')
  ?.  proc-done  $
  ::  refresh complete
  ;<  ~  bind:m  (drop:io /refresh-proc proc-road)
    =/  chain-tag=?(%recv %chng)
      ?:(?=(%recv ;;(?(%recv %chng) (slav %tas chain))) %recv %chng)
    ;<  addr-seen=seen:nexus  bind:m
      (peek:io [%& %& /apps/'wallet.wallet_app' %'addresses.wallet_addresses'] ~)
    =/  addrs=addresses
      ?.  ?=([%& %file *] addr-seen)  *addresses
      (fall (mole |.(!<(addresses (need-vase:tarball sang.p.addr-seen)))) *addresses)
    =/  mops=[recv=addr-mop chng=addr-mop]
      (fall (~(get by addrs) [ref network]) [*addr-mop *addr-mop])
    =/  mop=addr-mop  ?:(?=(%recv chain-tag) -.mops +.mops)
    =/  dat=(unit address-data)
      (get:((on @ud address-data) gth) mop idx)
    =/  out=wain
      :~  'Refresh complete.'
          (rap 3 ~['  account: ' ref])
          (rap 3 ~['  chain: ' chain])
          (rap 3 ~['  index: ' (scot %ud idx)])
          ?~  dat  '  address data not found'
          ?~  info.u.dat  '  no chain data yet'
          (rap 3 ~['  funded: ' (scot %ud funded.u.info.u.dat) ' sats'])
      ==
    (pure:m [%text (of-wain:format out)])
--
