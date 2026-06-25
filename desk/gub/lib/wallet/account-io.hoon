::  wallet account IO helpers
::
::  Pure helpers for address/tx operations, chain scanning,
::  and address refresh processes. No steps/prefix — callers
::  pass data directly or use ancestor-road for file access.
::
/<  wt   /lib/wallet-types.hoon
/<  bip32  /lib/bip32.hoon
/<  bech32  /lib/bech32.hoon
/<  drft  /lib/tx/draft.hoon
/<  fees  /lib/tx/fees.hoon
/<  b329  /lib/bip329.hoon
=,  wt
|%
::  +mop-to-list: tap mop to indexed list (ascending by index)
::
++  mop-to-list
  |=  mop=addr-mop
  ^-  (list [@ud address-data])
  (flop (tap:((on @ud address-data) gth) mop))
::  +get-mops: look up recv/chng mops for an account+network
::
++  get-mops
  |=  [=addresses ref=@t =network]
  ^-  [recv=addr-mop chng=addr-mop]
  (fall (~(get by addresses) [ref network]) [*addr-mop *addr-mop])
::  +put-mop: update a single chain mop in addresses
::
++  put-mop
  |=  [=addresses ref=@t =network chain=?(%recv %chng) mop=addr-mop]
  ^-  ^addresses
  =/  cur=[recv=addr-mop chng=addr-mop]
    (fall (~(get by addresses) [ref network]) [*addr-mop *addr-mop])
  %+  ~(put by addresses)  [ref network]
  ?-  chain
    %recv  cur(recv mop)
    %chng  cur(chng mop)
  ==
::  +get-txs: look up tx-map for an account+network
::
++  get-txs
  |=  [=txs ref=@t =network]
  ^-  tx-map
  (fall (~(get by txs) [ref network]) *tx-map)
::  +put-txs: update tx-map for an account+network
::
++  put-txs
  |=  [=txs ref=@t =network tm=tx-map]
  ^-  ^txs
  (~(put by txs) [ref network] tm)
::  +derive-addr: derive a bitcoin address
::
++  derive-addr
  |=  [xprv=@t =script-type =network chain=@ud index=@ud]
  ^-  (unit @t)
  =/  acct-key  (from-extended:bip32 (trip xprv))
  =/  chain-key  (derive:acct-key chain)
  =/  addr-key  (derive:chain-key index)
  =/  pubkey=@  public-key:addr-key
  =/  bip-net  (to-bip-network network)
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
  |=  =network
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
  |=  [paused-road=road:tarball address=@t =network]
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
::  +load-addr-file: load addresses from a road
::
++  load-addr-file
  |=  rd=road:tarball
  =/  m  (fiber:fiber:nexus ,addresses)
  ^-  form:m
  ;<  exists=?  bind:m  (peek-exists:io rd)
  ?.  exists  (pure:m *addresses)
  ;<  =seen:nexus  bind:m  (peek:io rd ~)
  ?.  ?=([%& %file *] seen)  (pure:m *addresses)
  (pure:m (fall (mole |.(!<(addresses (need-vase:tarball sang.p.seen)))) *addresses))
::  +save-addr-file: save addresses to a road
::
++  save-addr-file
  |=  [rd=road:tarball =addresses]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  exists=?  bind:m  (peek-exists:io rd)
  ?:  exists
    (over:io rd [[/wallet %addresses] addresses])
  (make:io rd |+[[[/wallet %addresses] addresses] ~])
::  +scan-chain: derive addresses and scan chain for activity
::
++  scan-chain
  |=  $:  acct-ref=@t
          paused-road=road:tarball
          xprv=@t
          stype=script-type
          chain=?(%receiving %change)
          =network
          start-idx=@ud
          start-gap=@ud
          addr-road=road:tarball
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
      xprv
      stype
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
    :~  ['account' s+acct-ref]
        ['phase' s+phase-tape]
        ['idx' (numb:enjs:format scan-idx)]
        ['gap' (numb:enjs:format gap)]
    ==
  ;<  ~  bind:m  (replace:io scan-prog)
  ::  write address with loading flag before fetch
  =/  loading-dat=address-data  [u.new-addr %.y ~ ~ ~]
  ;<  cur-addrs=addresses  bind:m  (load-addr-file addr-road)
  =/  pre-updated=addresses
    (put-mop cur-addrs acct-ref network chain-tag (put:((on @ud address-data) gth) recv:(get-mops cur-addrs acct-ref network) scan-idx loading-dat))
  ;<  ~  bind:m  (save-addr-file addr-road pre-updated)
  ;<  ~  bind:m  (sleep:io `@dr`(div ~s1 1.000))
  ::  fetch address info
  ;<  new-info=(unit address-info)  bind:m
    (scan-fetch paused-road u.new-addr network)
  ::  clear loading, write results
  =/  addr-dat=address-data  [u.new-addr %.n ~ new-info ~]
  ;<  post-addrs=addresses  bind:m  (load-addr-file addr-road)
  =/  [recv=addr-mop chng=addr-mop]
    (get-mops post-addrs acct-ref network)
  =/  post-mop=addr-mop
    ?:(is-change chng recv)
  =/  updated=addr-mop
    (put:((on @ud address-data) gth) post-mop scan-idx addr-dat)
  =/  post-updated=addresses
    (put-mop post-addrs acct-ref network chain-tag updated)
  ;<  ~  bind:m  (save-addr-file addr-road post-updated)
  ::  check gap
  ?~  new-info
    $(scan-idx +(scan-idx), gap +(gap))
  ?:  =(0 tx-count.u.new-info)
    $(scan-idx +(scan-idx), gap +(gap))
  $(scan-idx +(scan-idx), gap 0)
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
::  +get-next-unused-index: find first unused address index in an addr-mop
::
++  get-next-unused-index
  |=  mop=addr-mop
  ^-  @ud
  =/  top=(unit [idx=@ud address-data])
    (pry:((on @ud address-data) gth) mop)
  ?~  top  0
  +(idx.u.top)
::
++  read-wallet-name
  |=  [=labels:b329 wallet-fp=@ux]
  ^-  @t
  =/  xpub=@t  (crip (hexn:http-utils wallet-fp))
  =/  entries=(list label-entry:b329)
    ~(tap in (~(get la:b329 labels) %xpub xpub))
  =/  prefix=tape  "gwbtc:wallet:"
  =/  prefix-len=@ud  (lent prefix)
  |-
  ?~  entries  ''
  =/  lbl=tape  (trip label.i.entries)
  ?.  =(prefix (scag prefix-len lbl))
    $(entries t.entries)
  (crip (slag prefix-len lbl))
::  +get-last-offered: read last-offered index from xpub labels
::
++  get-last-offered
  |=  [=labels:b329 xpub=@t]
  ^-  (unit @ud)
  =/  entries=(list label-entry:b329)
    ~(tap in (~(get la:b329 labels) %xpub xpub))
  =/  prefix=tape  "gwbtc:last-offered:"
  =/  prefix-len=@ud  (lent prefix)
  |-
  ?~  entries  ~
  =/  lbl=tape  (trip label.i.entries)
  ?.  =(prefix (scag prefix-len lbl))
    $(entries t.entries)
  (rush (crip (slag prefix-len lbl)) dem)
::  +set-last-offered: write last-offered index as xpub label
::
++  set-last-offered
  |=  [=labels:b329 xpub=@t idx=@ud]
  ^-  labels:b329
  =/  entries=(list label-entry:b329)
    ~(tap in (~(get la:b329 labels) %xpub xpub))
  =/  prefix=tape  "gwbtc:last-offered:"
  =/  prefix-len=@ud  (lent prefix)
  =.  labels
    |-
    ?~  entries  labels
    =/  lbl=tape  (trip label.i.entries)
    ?:  =(prefix (scag prefix-len lbl))
      $(entries t.entries, labels (~(del la:b329 labels) %xpub xpub label.i.entries))
    $(entries t.entries)
  (~(put la:b329 labels) [%xpub xpub (crip "gwbtc:last-offered:{((d-co:co 1) idx)}") ~ ~ ~])
::  +get-next-offer-index: next address index to offer
::
++  get-next-offer-index
  |=  [mop=addr-mop =labels:b329 xpub=@t]
  ^-  @ud
  =/  unused-idx=@ud
    (get-next-unused-index mop)
  =/  last=(unit @ud)  (get-last-offered labels xpub)
  ?~  last  unused-idx
  (max unused-idx +(u.last))
--
