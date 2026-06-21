::  wallet account IO helpers
::
::  Shared helpers for account address/tx file operations,
::  chain scanning, and address refresh processes.
::
/<  wt   /lib/wallet-types.hoon
/<  bip32  /lib/bip32.hoon
/<  bech32  /lib/bech32.hoon
/<  drft  /lib/tx/draft.hoon
/<  fees  /lib/tx/fees.hoon
=,  wt
|%
::  +addr-road: compute road to a chain's mop file
::
++  addr-road
  |=  [steps=@ud prefix=path network=?(%main %testnet3 %testnet4 %signet %regtest) chain=?(%recv %chng)]
  ^-  road:tarball
  [%| steps [%& (weld prefix `path`~[%addresses network chain]) %'wallet_addresses']]
::  +read-mop: fiber that reads a single mop file
::
++  read-mop
  |=  [steps=@ud prefix=path network=?(%main %testnet3 %testnet4 %signet %regtest) chain=?(%recv %chng)]
  =/  m  (fiber:fiber:nexus ,addr-mop)
  ^-  form:m
  =/  road=road:tarball  (addr-road steps prefix network chain)
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?.  exists  (pure:m *addr-mop)
  ;<  seen=seen:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%& %file *] seen)  (pure:m *addr-mop)
  (pure:m (fall (mole |.(!<(addr-mop (need-vase:tarball sang.p.seen)))) *addr-mop))
::  +write-mop: fiber that writes a mop file (creates dir structure if needed)
::
++  write-mop
  |=  [steps=@ud prefix=path network=?(%main %testnet3 %testnet4 %signet %regtest) chain=?(%recv %chng) mop=addr-mop]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  road=road:tarball  (addr-road steps prefix network chain)
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?:  exists
    (over:io road [[/wallet %addresses] mop])
  (make:io road |+[[[/wallet %addresses] mop] ~])
::  +txs-road: compute road to the tx-map file
::
++  txs-road
  |=  [steps=@ud prefix=path network=?(%main %testnet3 %testnet4 %signet %regtest)]
  ^-  road:tarball
  [%| steps [%& (weld prefix `path`~[%addresses network %txs]) %'wallet_txs']]
::  +read-txs: fiber that reads the tx-map file
::
++  read-txs
  |=  [steps=@ud prefix=path network=?(%main %testnet3 %testnet4 %signet %regtest)]
  =/  m  (fiber:fiber:nexus ,tx-map)
  ^-  form:m
  =/  road=road:tarball  (txs-road steps prefix network)
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?.  exists  (pure:m *tx-map)
  ;<  seen=seen:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%& %file *] seen)  (pure:m *tx-map)
  (pure:m (fall (mole |.(!<(tx-map (need-vase:tarball sang.p.seen)))) *tx-map))
::  +write-txs: fiber that writes the tx-map file
::
++  write-txs
  |=  [steps=@ud prefix=path network=?(%main %testnet3 %testnet4 %signet %regtest) txs=tx-map]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  road=road:tarball  (txs-road steps prefix network)
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?:  exists
    (over:io road [[/wallet %txs] txs])
  (make:io road |+[[[/wallet %txs] txs] ~])
::  +ensure-net-dir: create network dir + empty mop files if needed
::
++  ensure-net-dir
  |=  [steps=@ud prefix=path network=?(%main %testnet3 %testnet4 %signet %regtest)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  recv-road=road:tarball  (addr-road steps prefix network %recv)
  ;<  exists=?  bind:m  (peek-exists:io recv-road)
  ?:  exists  (pure:m ~)
  ;<  ~  bind:m  (write-mop steps prefix network %recv *addr-mop)
  ;<  ~  bind:m  (write-mop steps prefix network %chng *addr-mop)
  (write-txs steps prefix network *tx-map)
::  +mop-to-list: tap mop to indexed list (ascending by index)
::
++  mop-to-list
  |=  mop=addr-mop
  ^-  (list [@ud address-data])
  (flop (tap:((on @ud address-data) gth) mop))
::  +extract-account: pull account-data from a ball view
::
++  extract-account
  |=  =seen:nexus
  ^-  (unit account-data)
  ?.  ?=([%& %ball *] seen)  ~
  =/  =lump:tarball  (fall fil.ball.p.seen *lump:tarball)
  =/  ct=(unit [=sang:tarball gain=? bang=(unit tang)])  (~(get by contents.lump) 'data.wallet_account')
  ?~  ct  ~
  ?.  ?=(%account name.p.sang.u.ct)  ~
  (mole |.(!<(account-data (need-vase:tarball sang.u.ct))))
::  +extract-mops: pull recv and chng addr-mops from a ball view
::
++  extract-mops
  |=  [=seen:nexus network=?(%main %testnet3 %testnet4 %signet %regtest)]
  ^-  [recv=addr-mop chng=addr-mop]
  ?.  ?=([%& %ball *] seen)  [*addr-mop *addr-mop]
  =/  addrs-ball=(unit ball:tarball)  (~(get by dir.ball.p.seen) 'addresses')
  ?~  addrs-ball  [*addr-mop *addr-mop]
  =/  net-ball=(unit ball:tarball)  (~(get by dir.u.addrs-ball) ;;(@ta network))
  ?~  net-ball  [*addr-mop *addr-mop]
  ?~  fil.u.net-ball  [*addr-mop *addr-mop]
  =/  recv=addr-mop
    =/  ct=(unit [=sang:tarball gain=? bang=(unit tang)])  (~(get by contents.u.fil.u.net-ball) 'recv.wallet_addresses')
    ?~  ct  *addr-mop
    (fall (mole |.(!<(addr-mop (need-vase:tarball sang.u.ct)))) *addr-mop)
  =/  chng=addr-mop
    =/  ct=(unit [=sang:tarball gain=? bang=(unit tang)])  (~(get by contents.u.fil.u.net-ball) 'chng.wallet_addresses')
    ?~  ct  *addr-mop
    (fall (mole |.(!<(addr-mop (need-vase:tarball sang.u.ct)))) *addr-mop)
  [recv chng]
::  +derive-addr: derive a bitcoin address
::
++  derive-addr
  |=  [xprv=@t =script-type network=?(%main %testnet3 %testnet4 %signet %regtest) chain=@ud index=@ud]
  ^-  (unit @t)
  =/  acct-key  (from-extended:bip32 (trip xprv))
  =/  chain-key  (derive:acct-key chain)
  =/  addr-key  (derive:chain-key index)
  =/  pubkey=@  public-key:addr-key
  =/  bip-net  (to-bip-network:wt network)
  ?-  script-type
    %p2wpkh      (encode-pubkey:bech32 bip-net [33 pubkey])
    %p2tr        (encode-taproot:bech32 bip-net [32 (end [3 32] pubkey)])
    %p2pkh       ~
    %p2sh-p2wpkh  ~
  ==
::
+$  scan-progress  [phase=@t idx=@ud gap=@ud]
::
++  parse-scan-progress
  |=  jon=json
  ^-  scan-progress
  ?.  ?=([%o *] jon)  ['' 0 0]
  =/  phase=(unit json)  (~(get by p.jon) 'phase')
  =/  idx-j=(unit json)  (~(get by p.jon) 'idx')
  =/  gap-j=(unit json)  (~(get by p.jon) 'gap')
  ?.  &(?=([~ %s *] phase) ?=([~ %n *] idx-j) ?=([~ %n *] gap-j))
    ['' 0 0]
  =/  idx=(unit @ud)  (rush p.u.idx-j dem)
  =/  gap=(unit @ud)  (rush p.u.gap-j dem)
  ?:  |(?=(~ idx) ?=(~ gap))  ['' 0 0]
  [p.u.phase u.idx u.gap]
::
+$  scan-event
  $%  [%http =client-response:iris]
      [%pause ~]
      [%resume ~]
  ==
::
++  take-scan-event
  =/  m  (fiber:fiber:nexus ,scan-event)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error:io dart.u.in)]
      [~ %poke * *]
    ?:  =([/ %http-response] p.sage.u.in)
      =/  resp=client-response:iris  !<(client-response:iris q.sage.u.in)
      ?:  ?=(%cancel -.resp)
        [%fail leaf+"http-request-cancelled" ~]
      [%done %http resp]
    =/  res=(unit json)  (mole |.(!<(json q.sage.u.in)))
    ?~  res  [%skip ~]
    ?.  ?=([%o *] u.res)  [%skip ~]
    =/  act=(unit json)  (~(get by p.u.res) 'action')
    ?:  =(`s+'pause' act)   [%done %pause ~]
    ?:  =(`s+'resume' act)  [%done %resume ~]
    [%skip ~]
  ==
::
++  take-pause-event
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error:io dart.u.in)]
      [~ %poke * *]
    =/  res=(unit json)  (mole |.(!<(json q.sage.u.in)))
    ?~  res  [%skip ~]
    ?.  ?=([%o *] u.res)  [%skip ~]
    =/  act=(unit json)  (~(get by p.u.res) 'action')
    ?:  =(`s+'resume' act)  [%done %.y]
    [%skip ~]
  ==
::
++  pause-loop
  |=  paused-road=road:tarball
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  marker-json=json  (pairs:enjs:format ~[['paused' b+%.y]])
  ;<  ~  bind:m
    (make:io paused-road |+[[[/ %json] marker-json] ~])
  |-
  ;<  resumed=?  bind:m  take-pause-event
  ?.  resumed  $
  ;<  *  bind:m  (cull-soft:io paused-road)
  (pure:m ~)
::
++  mempool-base-url
  |=  network=?(%main %testnet3 %testnet4 %signet %regtest)
  ^-  tape
  ?-  network
    %main      "https://mempool.space/api/address/"
    %testnet3  "https://mempool.space/testnet/api/address/"
    %testnet4  "https://mempool.space/testnet4/api/address/"
    %signet    "https://mempool.space/signet/api/address/"
    %regtest   "http://localhost:3000/address/"
  ==
::  +scan-fetch: like fetch-address-info but pausable during HTTP wait
::
++  scan-fetch
  |=  [paused-road=road:tarball address=@t network=?(%main %testnet3 %testnet4 %signet %regtest)]
  =/  m  (fiber:fiber:nexus ,(unit address-info))
  ^-  form:m
  =/  url=@t
    (crip (weld (mempool-base-url network) (trip address)))
  =/  =request:http
    [%'GET' url ~[['Accept' 'application/json']] ~]
  ;<  ~  bind:m  (send-request:io request)
  |-
  ;<  evt=scan-event  bind:m  take-scan-event
  ?-    -.evt
      %pause   ;<  ~  bind:m  (pause-loop paused-road)  $
      %resume  $
      %http    (parse-address-response client-response.evt)
  ==
::  +parse-address-response: extract address-info from HTTP response
::
++  parse-address-response
  |=  =client-response:iris
  =/  m  (fiber:fiber:nexus ,(unit address-info))
  ^-  form:m
  ?.  ?=(%finished -.client-response)
    (pure:m ~)
  ?~  full-file.client-response
    (pure:m ~)
  =/  body=@t  q.data.u.full-file.client-response
  =/  parsed=(each json tang)  (mule |.((need (de:json:html body))))
  ?:  ?=(%| -.parsed)  (pure:m ~)
  =/  data=json  p.parsed
  =/  tx-count=(unit @ud)
    (mole |.((ni:dejs:format (~(got jo:json-utils data) /'chain_stats'/'tx_count'))))
  =/  funded=(unit @ud)
    (mole |.((ni:dejs:format (~(got jo:json-utils data) /'chain_stats'/'funded_txo_sum'))))
  =/  spent=(unit @ud)
    (mole |.((ni:dejs:format (~(got jo:json-utils data) /'chain_stats'/'spent_txo_sum'))))
  ?~  tx-count  (pure:m ~)
  ?~  funded    (pure:m ~)
  ?~  spent     (pure:m ~)
  ;<  now=@da  bind:m  get-time:io
  (pure:m `[u.tx-count u.funded u.spent now])
::  +take-http: simple HTTP response handler
::
++  take-http
  =/  m  (fiber:fiber:nexus ,client-response:iris)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %poke * *]
    ?.  =([/ %http-response] p.sage.u.in)  [%skip ~]
    =/  resp=client-response:iris  !<(client-response:iris q.sage.u.in)
    [%done resp]
  ==
::  +parse-info-response: extract address-info from HTTP response
::
++  parse-info-response
  |=  [=client-response:iris now=@da]
  ^-  (unit address-info)
  ?.  ?=(%finished -.client-response)  ~
  ?~  full-file.client-response  ~
  =/  body=@t  q.data.u.full-file.client-response
  =/  parsed=(each json tang)  (mule |.((need (de:json:html body))))
  ?:  ?=(%| -.parsed)  ~
  =/  data=json  p.parsed
  =/  tc=(unit @ud)  (mole |.((ni:dejs:format (~(got jo:json-utils data) /'chain_stats'/'tx_count'))))
  =/  funded=(unit @ud)  (mole |.((ni:dejs:format (~(got jo:json-utils data) /'chain_stats'/'funded_txo_sum'))))
  =/  spent=(unit @ud)  (mole |.((ni:dejs:format (~(got jo:json-utils data) /'chain_stats'/'spent_txo_sum'))))
  ?:  |(?=(~ tc) ?=(~ funded) ?=(~ spent))  ~
  `[u.tc u.funded u.spent now]
::  +parse-utxo-response: extract UTXOs from HTTP response
::
++  parse-utxo-response
  |=  =client-response:iris
  ^-  (list utxo)
  ?.  ?=(%finished -.client-response)  ~
  ?~  full-file.client-response  ~
  =/  body=@t  q.data.u.full-file.client-response
  =/  parsed=(each json tang)  (mule |.((need (de:json:html body))))
  ?:  ?=(%| -.parsed)  ~
  ?.  ?=(%a -.p.parsed)  ~
  %+  murn  p.p.parsed
  |=  j=json
  ^-  (unit utxo)
  =/  txid=(unit @t)
    (mole |.((so:dejs:format (~(got jo:json-utils j) /txid))))
  =/  vout=(unit @ud)
    (mole |.((ni:dejs:format (~(got jo:json-utils j) /vout))))
  =/  value=(unit @ud)
    (mole |.((ni:dejs:format (~(got jo:json-utils j) /value))))
  ?~  txid   ~
  ?~  vout   ~
  ?~  value  ~
  =/  status=tx-status
    =/  sj=(unit json)  (mole |.((~(got jo:json-utils j) /status)))
    ?~  sj  [%unconfirmed ~]
    (parse-tx-status u.sj)
  `[u.txid u.vout u.value status]
::
++  parse-tx-status
  |=  sj=json
  ^-  tx-status
  =/  conf=(unit ?)
    (mole |.((bo:dejs:format (~(got jo:json-utils sj) /confirmed))))
  ?~  conf  [%unconfirmed ~]
  ?.  u.conf  [%unconfirmed ~]
  =/  bh=(unit @t)
    (mole |.((so:dejs:format (~(got jo:json-utils sj) /'block_hash'))))
  =/  ht=(unit @ud)
    (mole |.((ni:dejs:format (~(got jo:json-utils sj) /'block_height'))))
  ?~  bh  [%unconfirmed ~]
  ?~  ht  [%unconfirmed ~]
  [%confirmed u.bh u.ht]
::  +parse-txs-response: extract transactions from HTTP response
::
++  parse-txs-response
  |=  =client-response:iris
  ^-  (list transaction)
  ?.  ?=(%finished -.client-response)  ~
  ?~  full-file.client-response  ~
  =/  body=@t  q.data.u.full-file.client-response
  =/  parsed=(each json tang)  (mule |.((need (de:json:html body))))
  ?:  ?=(%| -.parsed)  ~
  ?.  ?=(%a -.p.parsed)  ~
  %+  murn  p.p.parsed
  |=  tj=json
  ^-  (unit transaction)
  =/  txid=(unit @t)
    (mole |.((so:dejs:format (~(got jo:json-utils tj) /txid))))
  ?~  txid  ~
  =/  vin-json=(unit json)  (mole |.((~(got jo:json-utils tj) /vin)))
  =/  inputs=(list tx-input)
    ?~  vin-json  ~
    ?.  ?=(%a -.u.vin-json)  ~
    %+  murn  p.u.vin-json
    |=  ij=json
    ^-  (unit tx-input)
    =/  st=(unit @t)  (mole |.((so:dejs:format (~(got jo:json-utils ij) /txid))))
    =/  sv=(unit @ud)  (mole |.((ni:dejs:format (~(got jo:json-utils ij) /vout))))
    ?~  st  ~
    ?~  sv  ~
    =/  prevout=(unit tx-output)
      =/  pj=(unit json)  (mole |.((~(got jo:json-utils ij) /prevout)))
      ?~  pj  ~
      =/  pv=(unit @ud)  (mole |.((ni:dejs:format (~(got jo:json-utils u.pj) /value))))
      =/  pa=(unit @t)  (mole |.((so:dejs:format (~(got jo:json-utils u.pj) /'scriptpubkey_address'))))
      ?~  pv  ~
      ?~  pa  ~
      `[u.pv u.pa]
    `[u.st u.sv prevout]
  =/  vout-json=(unit json)  (mole |.((~(got jo:json-utils tj) /vout)))
  =/  outputs=(list tx-output)
    ?~  vout-json  ~
    ?.  ?=(%a -.u.vout-json)  ~
    %+  murn  p.u.vout-json
    |=  oj=json
    ^-  (unit tx-output)
    =/  v=(unit @ud)  (mole |.((ni:dejs:format (~(got jo:json-utils oj) /value))))
    =/  a=(unit @t)  (mole |.((so:dejs:format (~(got jo:json-utils oj) /'scriptpubkey_address'))))
    ?~  v  ~
    ?~  a  ~
    `[u.v u.a]
  =/  sj=(unit json)  (mole |.((~(got jo:json-utils tj) /status)))
  =/  status=tx-status
    ?~  sj  [%unconfirmed ~]
    (parse-tx-status u.sj)
  =/  fee=(unit @ud)  (mole |.((ni:dejs:format (~(got jo:json-utils tj) /fee))))
  =/  size=(unit @ud)  (mole |.((ni:dejs:format (~(got jo:json-utils tj) /size))))
  `[u.txid inputs outputs status fee size]
::  +scan-chain: derive addresses and scan chain for activity
::
++  scan-chain
  |=  $:  steps=@ud
          prefix=path
          paused-road=road:tarball
          acct-path=@t
          acct=account-data
          chain=?(%receiving %change)
          network=?(%main %testnet3 %testnet4 %signet %regtest)
          start-idx=@ud
          start-gap=@ud
      ==
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  is-change=?  =(chain %change)
  =/  chain-tag=?(%recv %chng)  ?:(is-change %chng %recv)
  =/  gap-limit=@ud  20
  =/  scan-idx=@ud  start-idx
  =/  gap=@ud  start-gap
  |-
  ?:  (gte gap gap-limit)
    (pure:m ~)
  =/  new-addr=(unit @t)
    %:  derive-addr
      xprv.acct
      script-type.acct
      network
      ?:(is-change 1 0)
      scan-idx
    ==
  ?~  new-addr
    (pure:m ~)
  ::  update scan progress in proc file
  =/  phase-tape=@t  ?:(is-change 'chng' 'recv')
  =/  scan-prog=json
    %-  pairs:enjs:format
    :~  ['account' s+acct-path]
        ['phase' s+phase-tape]
        ['idx' (numb:enjs:format scan-idx)]
        ['gap' (numb:enjs:format gap)]
    ==
  ;<  ~  bind:m  (replace:io scan-prog)
  ::  write address with loading flag before fetch
  =/  loading-dat=address-data  [u.new-addr %.y ~ ~ ~]
  ;<  pre-mop=addr-mop  bind:m  (read-mop steps prefix network chain-tag)
  =/  pre-updated=addr-mop
    (put:((on @ud address-data) gth) pre-mop scan-idx loading-dat)
  ;<  ~  bind:m  (write-mop steps prefix network chain-tag pre-updated)
  ;<  ~  bind:m  (sleep:io `@dr`(div ~s1 1.000))
  ::  fetch address info
  ;<  new-info=(unit address-info)  bind:m
    (scan-fetch paused-road u.new-addr network)
  ::  clear loading, write results
  =/  addr-dat=address-data  [u.new-addr %.n ~ new-info ~]
  ;<  mop=addr-mop  bind:m  (read-mop steps prefix network chain-tag)
  =/  updated=addr-mop
    (put:((on @ud address-data) gth) mop scan-idx addr-dat)
  ;<  ~  bind:m  (write-mop steps prefix network chain-tag updated)
  ::  check gap
  ?~  new-info
    $(scan-idx +(scan-idx), gap +(gap))
  ?:  =(0 tx-count.u.new-info)
    $(scan-idx +(scan-idx), gap +(gap))
  $(scan-idx +(scan-idx), gap 0)
::
++  read-draft-file
  =/  m  (fiber:fiber:nexus ,(unit transaction:drft))
  ^-  form:m
  =/  draft-road=road:tarball
    (cord-to-road:tarball './data.wallet_draft')
  ;<  exists=?  bind:m  (peek-exists:io draft-road)
  ?.  exists  (pure:m ~)
  ;<  seen=seen:nexus  bind:m  (peek:io draft-road ~)
  ?.  ?=(%& -.seen)  (pure:m ~)
  ?.  ?=([%file *] p.seen)  (pure:m ~)
  (pure:m (mole |.(!<(transaction:drft (need-vase:tarball sang.p.seen)))))
::
++  write-draft
  |=  dr=transaction:drft
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  road=road:tarball  (cord-to-road:tarball './data.wallet_draft')
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?:  exists
    (over:io road [[/wallet %draft] dr])
  (make:io road |+[[[/wallet %draft] dr] ~])
::
++  read-wallet-name
  |=  [steps=@ud wallet-fp=@ux]
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  =/  fp-hex=tape  (hexn:http-utils wallet-fp)
  =/  wal-name=@ta  (crip "{fp-hex}.wallet_wallet")
  =/  wal-road=road:tarball  [%| steps [%& /wallets wal-name]]
  ;<  exists=?  bind:m  (peek-exists:io wal-road)
  ?.  exists  (pure:m '')
  ;<  seen=seen:nexus  bind:m  (peek:io wal-road ~)
  ?.  ?=(%& -.seen)  (pure:m '')
  ?.  ?=([%file *] p.seen)  (pure:m '')
  =/  wal=(unit wallet-data)  (mole |.(!<(wallet-data (need-vase:tarball sang.p.seen))))
  ?~  wal  (pure:m '')
  (pure:m name.u.wal)
::
++  collect-utxo-inputs
  |=  [recv=addr-mop chng=addr-mop =script-type]
  ^-  (list utxo-input:drft)
  =/  spend=spend:fees  script-type
  =/  all=(list [@ud address-data])
    (weld (mop-to-list recv) (mop-to-list chng))
  %-  zing
  %+  turn  all
  |=  [idx=@ud a=address-data]
  %+  turn  utxos.a
  |=  u=utxo
  ^-  utxo-input:drft
  [txid.u vout.u value.u spend]
--
