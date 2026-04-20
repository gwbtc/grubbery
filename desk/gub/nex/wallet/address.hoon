::  per-address nexus: individual bitcoin address instance
::
::  Each address directory contains:
::    data.wallet_address   address-data (addr, chain, idx, info, utxos, txs)
::    page.html             rendered detail page (manx)
::
/<  feather       /lib/feather.hoon
/<  fi            /lib/feather-icons.hoon
/<  wt            /lib/wallet-types.hoon
=,  wt
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  [=sand:nexus =gain:nexus =ball:tarball]
      ^-  [sand:nexus gain:nexus ball:tarball]
      =/  =ver:loader  (get-ver:loader ball)
      ?+  ver  !!
          ?(~ [~ %0])
        %+  spin:loader  [sand gain ball]
        :~  (ver-row:loader 0)
            [%stay %& [/ %'data.wallet_address']]
            [%over %& [/ %'page.html'] %.n [~ [/ %manx] !>(;div;)]]
            [%over %& [/ %'refreshing.json'] %.n [~ [/ %json] !>(b+%.n)]]
            [%fall %| /ui [~ ~] [~ ~] empty-dir:loader]
            [%over %& [/ui %'sse-manager.sig'] %.n [~ [/ %sig] !>(~)]]
            [%fall %| /ui/sse [~ ~] [~ ~] empty-dir:loader]
        ==
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =mark]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::  /page.html: render address detail, watch data changes
          ::
          [~ %'page.html']
        ;<  ~  bind:m  (rise-wait:io prod "%address detail: failed")
        ;<  init=view:nexus  bind:m
          (keep:io /data (cord-to-road:tarball './') ~)
        =/  dat=(unit address-data)  (extract-address init)
        ?~  dat
          ::  wait for address data to appear
          |-
          ;<  upd=view:nexus  bind:m  (take-news:io /data)
          =/  dat=(unit address-data)  (extract-address upd)
          ?~  dat  $
          (replace:io !>((detail-page u.dat)))
        ::  render once — SSE handles all live updates
        (replace:io !>((detail-page u.dat)))
          ::  /ui/sse-manager.sig: SSE manager — watches data, writes live fragments
          ::
          [[%ui ~] %'sse-manager.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%address sse-manager: failed")
        ;<  init=view:nexus  bind:m
          (keep:io /data (cord-to-road:tarball '../') ~)
        =/  dat=(unit address-data)  (extract-address init)
        =/  rfsh=?  (extract-refreshing-state init)
        ?~  dat
          |-
          ;<  upd=view:nexus  bind:m  (take-news:io /data)
          =/  dat=(unit address-data)  (extract-address upd)
          =/  rfsh=?  (extract-refreshing-state upd)
          ?~  dat  $
          ;<  ~  bind:m  (sse-write-content u.dat rfsh)
          =/  prev=@  (mug [u.dat rfsh])
          |-
          ;<  upd=view:nexus  bind:m  (take-news:io /data)
          =/  dat=(unit address-data)  (extract-address upd)
          =/  rfsh=?  (extract-refreshing-state upd)
          ?~  dat  $
          =/  curr=@  (mug [u.dat rfsh])
          ?:  =(prev curr)  $
          ;<  ~  bind:m  (sse-write-content u.dat rfsh)
          $(prev curr)
        ;<  ~  bind:m  (sse-write-content u.dat rfsh)
        =/  prev=@  (mug [u.dat rfsh])
        |-
        ;<  upd=view:nexus  bind:m  (take-news:io /data)
        =/  dat=(unit address-data)  (extract-address upd)
        =/  rfsh=?  (extract-refreshing-state upd)
        ?~  dat  $
        =/  curr=@  (mug [u.dat rfsh])
        ?:  =(prev curr)  $
        ;<  ~  bind:m  (sse-write-content u.dat rfsh)
        $(prev curr)
          ::  /data.wallet_address: handle pokes (refresh)
          ::
          [~ %'data.wallet_address']
        ;<  ~  bind:m  (rise-wait:io prod "%address data: failed")
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        ?+    name.p.sage  $
            %json
          =/  jon=json  !<(json q.sage)
          ?.  ?=([%o *] jon)  $
          =/  act=@t  (~(dug jo:json-utils jon) /action so:dejs:format '')
          ?+    act  $
              %'refresh'
            ;<  dat=address-data  bind:m  (get-state-as:io address-data)
            ::  set refreshing marker
            =/  marker-road=road:tarball  (cord-to-road:tarball './refreshing.json')
            ;<  ~  bind:m  (over:io marker-road [[/ %json] !>(b+%.y)])
            ;<  ~  bind:m  (sleep:io `@dr`(div ~s1 1.000))
            ::  cancellable refresh
            ;<  result=(unit address-data)  bind:m  (do-refresh-cancel dat)
            ::  clear refreshing marker
            ;<  ~  bind:m  (over:io marker-road [[/ %json] !>(b+%.n)])
            ?~  result  $
            ;<  ~  bind:m  (replace:io !>(u.result))
            $
          ==
        ==
      ==
    ::
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'Subdirectory under this address.'
            ~
          'Individual Bitcoin address with UTXOs and transaction history.'
        ==
          %|
        ?+  rail.p.mana  'File under this address.'
          [~ %'data.wallet_address']  'Address data: address string, info, UTXOs, transactions.'
          [~ %'page.html']            'Rendered address detail page. Mark: manx.'
          [~ %'ver.ud']               'Schema version.'
        ==
      ==
    --
::  helpers and rendering
::
|%
++  extract-address
  |=  =view:nexus
  ^-  (unit address-data)
  ?.  ?=([%ball *] view)  ~
  =/  =lump:tarball  (fall fil.ball.view *lump:tarball)
  =/  ct=(unit content:tarball)  (~(get by contents.lump) 'data.wallet_address')
  ?~  ct  ~
  ?.  ?=(%address name.p.sage.u.ct)  ~
  (mole |.(!<(address-data q.sage.u.ct)))
::
++  extract-refreshing-state
  |=  =view:nexus
  ^-  ?
  ?.  ?=([%ball *] view)  %.n
  =/  =lump:tarball  (fall fil.ball.view *lump:tarball)
  =/  ct=(unit content:tarball)  (~(get by contents.lump) 'refreshing.json')
  ?~  ct  %.n
  =/  val=(unit json)  (mole |.(!<(json q.sage.u.ct)))
  =(`[%b %.y] val)
::
++  sse-write
  |=  [road=road:tarball sage=sage:tarball]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?:  exists
    (over:io road sage)
  (make:io road |+[%.n sage ~])
::
++  sse-write-content
  |=  [dat=address-data rfsh=?]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (sse-write (cord-to-road:tarball './sse/live-content.html') [[/ %manx] !>((live-content dat rfsh))])
::
++  live-content
  |=  [dat=address-data is-loading=?]
  ^-  manx
  =/  balance=@ud
    ?~  info.dat  0
    (sub funded.u.info.dat spent.u.info.dat)
  ;div#live-content.fc.g3
    ::  balance stats
    ;div.p4.b2.br2(style "flex-shrink: 0;")
      ;h2.s0.bold.mb2: Balance
      ;div(style "display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px;")
        ;div
          ;div.f3.s-2: Balance
          ;div.s0.bold.mono: {(format-sats balance)} sats
        ==
        ;div
          ;div.f3.s-2: Funded
          ;div.s-1.mono: {?~(info.dat "—" (format-sats funded.u.info.dat))}
        ==
        ;div
          ;div.f3.s-2: Spent
          ;div.s-1.mono: {?~(info.dat "—" (format-sats spent.u.info.dat))}
        ==
        ;div
          ;div.f3.s-2: Transactions
          ;div.s-1.mono: {?~(info.dat "—" (a-co:co tx-count.u.info.dat))}
        ==
      ==
      ;div(style "display: flex; justify-content: space-between; align-items: center; margin-top: 12px;")
        ;span.f3.s-2: {?~(info.dat "Never checked" "Last: {(scow %da last-check.u.info.dat)}")}
        ;+  ?:  is-loading
              ;div(style "display: flex; gap: 4px;")
                ;div.p2.b1.br1(style "background: rgba(100, 150, 255, 0.2); border: 1px solid var(--b3); color: var(--f3); display: flex; align-items: center; height: 32px; padding: 0 8px; justify-content: center;")
                  ;div(style "width: 16px; height: 16px; display: flex; align-items: center; justify-content: center; animation: spin 1s linear infinite;")
                    ;+  (make:fi 'loader')
                  ==
                ==
                ;button.p2.b1.br1.hover.pointer
                  =onclick  "cancelRefresh()"
                  =title  "Cancel refresh"
                  =style  "background: rgba(255, 80, 80, 0.2); border: 1px solid rgba(255, 80, 80, 0.4); color: #ff5050; display: flex; align-items: center; height: 32px; padding: 0 8px; justify-content: center; outline: none; gap: 6px;"
                  ;div(style "width: 14px; height: 14px; display: flex; align-items: center; justify-content: center;")
                    ;+  (make:fi 'x-circle')
                  ==
                  ;span.s-2: Cancel
                ==
              ==
            ;button.p2.b1.br1.hover.pointer
              =onclick  "doRefresh()"
              =style  "border: 1px solid var(--b3); color: var(--f2); display: flex; align-items: center; gap: 6px; outline: none;"
              ;div(style "width: 14px; height: 14px; display: flex; align-items: center; justify-content: center;")
                ;+  (make:fi 'refresh-cw')
              ==
              ;span.s-2: Refresh
            ==
      ==
    ==
    ::  UTXOs
    ;div.p4.b1.br2
      ;h2.s0.bold.mb2: UTXOs ({(a-co:co (lent utxos.dat))})
      ;+  ?:  =(~ utxos.dat)
            ;div.p3.b2.br2.tc.f3.s-1: No unspent outputs
          ;div.fc.g1(style "max-height: 300px; overflow-y: auto;")
            ;*  %+  turn  utxos.dat
                |=  =utxo
                ^-  manx
                ;div.p3.b2.br2(style "display: flex; justify-content: space-between; align-items: center;")
                  ;div(style "min-width: 0; flex: 1;")
                    ;div(style "display: flex; align-items: center; gap: 6px;")
                      ;code.mono.s-2.f2(style "white-space: nowrap; overflow: hidden; text-overflow: ellipsis;"): {(truncate-txid txid.utxo)}:{(a-co:co vout.utxo)}
                      ;+  ?-  -.tx-status.utxo
                              %confirmed
                            ;span.s-2(style "color: #10b981; font-size: 11px;"): ✓
                              %unconfirmed
                            ;span.s-2(style "color: #f59e0b; font-size: 11px;"): ○
                          ==
                    ==
                  ==
                  ;span.mono.s-1.bold: {(format-sats value.utxo)} sats
                ==
          ==
    ==
    ::  transactions
    ;div.p4.b1.br2
      ;h2.s0.bold.mb2: Transactions ({(a-co:co (lent txs.dat))})
      ;+  ?:  =(~ txs.dat)
            ;div.p3.b2.br2.tc.f3.s-1: No transactions
          ;div.fc.g1(style "max-height: 400px; overflow-y: auto;")
            ;*  %+  turn  txs.dat
                |=  =transaction
                ^-  manx
                =/  is-incoming=?
                  %+  lien  outputs.transaction
                  |=(=tx-output =(address.tx-output addr.dat))
                =/  is-outgoing=?
                  %+  lien  inputs.transaction
                  |=  =tx-input
                  ?~  prevout.tx-input  %.n
                  =(address.u.prevout.tx-input addr.dat)
                =/  direction=tape
                  ?:  &(is-incoming is-outgoing)  "↕ Self"
                  ?:(is-incoming "↓ Recv" "↑ Send")
                =/  dir-color=tape
                  ?:  &(is-incoming is-outgoing)  "#888"
                  ?:(is-incoming "#10b981" "#ef4444")
                =/  recv-amt=@ud
                  %+  roll  outputs.transaction
                  |=  [=tx-output total=@ud]
                  ?.  =(address.tx-output addr.dat)  total
                  (add total value.tx-output)
                =/  send-amt=@ud
                  %+  roll  inputs.transaction
                  |=  [=tx-input total=@ud]
                  ?~  prevout.tx-input  total
                  ?.  =(address.u.prevout.tx-input addr.dat)  total
                  (add total value.u.prevout.tx-input)
                =/  net-text=tape
                  ?:  (gte recv-amt send-amt)
                    "+{(format-sats (sub recv-amt send-amt))}"
                  "-{(format-sats (sub send-amt recv-amt))}"
                ;div.p3.b2.br2(style "display: flex; justify-content: space-between; align-items: center;")
                  ;div(style "min-width: 0; flex: 1;")
                    ;div(style "display: flex; align-items: center; gap: 8px;")
                      ;span.s-1.bold(style "color: {dir-color};"): {direction}
                      ;code.mono.s-2.f2(style "white-space: nowrap; overflow: hidden; text-overflow: ellipsis;"): {(truncate-txid txid.transaction)}
                      ;+  ?-  -.tx-status.transaction
                              %confirmed
                            ;span.s-2(style "color: #10b981; font-size: 11px;"): ✓ block {(a-co:co block-height.tx-status.transaction)}
                              %unconfirmed
                            ;span.s-2(style "color: #f59e0b; font-size: 11px;"): ○ pending
                          ==
                    ==
                    ;div.f3.s-2(style "display: flex; gap: 12px; margin-top: 2px;")
                      ;span: {(a-co:co (lent inputs.transaction))} in → {(a-co:co (lent outputs.transaction))} out
                      ;+  ?~  fee.transaction  ;span;
                          ;span: fee: {(format-sats u.fee.transaction)}
                    ==
                  ==
                  ;span.mono.s-1.bold(style "color: {dir-color}; white-space: nowrap;"): {net-text} sats
                ==
          ==
    ==
  ==
::
++  mempool-base
  |=  network=?(%main %testnet %regtest)
  ^-  tape
  ?-  network
    %main     "https://mempool.space/api/address/"
    %testnet  "https://mempool.space/testnet4/api/address/"
    %regtest  "http://localhost:3000/address/"
  ==
::
+$  refresh-event
  $%  [%http =client-response:iris]
      [%cancel ~]
  ==
::
++  take-refresh-event
  =/  m  (fiber:fiber:nexus ,refresh-event)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error:io dart.u.in)]
      [~ %arvo [%request ~] %iris %http-response %cancel *]
    [%done %cancel ~]
      [~ %arvo [%request ~] %iris %http-response %finished *]
    [%done %http client-response.sign.u.in]
      [~ %poke * *]
    =/  res=(unit json)  (mole |.(!<(json q.sage.u.in)))
    ?~  res  [%skip ~]
    ?.  ?=([%o *] u.res)  [%skip ~]
    =/  act=(unit json)  (~(get by p.u.res) 'action')
    ?:  =(`s+'cancel' act)  [%done %cancel ~]
    [%skip ~]
  ==
::
++  do-refresh-cancel
  |=  dat=address-data
  =/  m  (fiber:fiber:nexus ,(unit address-data))
  ^-  form:m
  ::  fetch address info
  =/  url=@t
    (crip (weld (mempool-base network.dat) (trip addr.dat)))
  =/  =request:http
    [%'GET' url ~[['Accept' 'application/json']] ~]
  ;<  ~  bind:m  (send-request:io request)
  ;<  evt=refresh-event  bind:m  take-refresh-event
  ?:  ?=(%cancel -.evt)  (pure:m ~)
  =/  =client-response:iris  client-response.evt
  ?.  ?=(%finished -.client-response)
    (pure:m `dat)
  ?~  full-file.client-response
    (pure:m `dat)
  =/  body=@t  q.data.u.full-file.client-response
  =/  parsed=(each json tang)  (mule |.((need (de:json:html body))))
  ?:  ?=(%| -.parsed)  (pure:m `dat)
  =/  data=json  p.parsed
  =/  tx-count=(unit @ud)
    (mole |.((ni:dejs:format (~(got jo:json-utils data) /'chain_stats'/'tx_count'))))
  =/  funded=(unit @ud)
    (mole |.((ni:dejs:format (~(got jo:json-utils data) /'chain_stats'/'funded_txo_sum'))))
  =/  spent=(unit @ud)
    (mole |.((ni:dejs:format (~(got jo:json-utils data) /'chain_stats'/'spent_txo_sum'))))
  ?~  tx-count  (pure:m `dat)
  ?~  funded    (pure:m `dat)
  ?~  spent     (pure:m `dat)
  ;<  =bowl:nexus  bind:m  get-bowl:io
  =/  new-info=address-info  [u.tx-count u.funded u.spent now.bowl]
  ::  fetch UTXOs
  =/  utxo-url=@t
    (crip (weld (weld (mempool-base network.dat) (trip addr.dat)) "/utxo"))
  =/  utxo-req=request:http
    [%'GET' utxo-url ~[['Accept' 'application/json']] ~]
  ;<  ~  bind:m  (send-request:io utxo-req)
  ;<  utxo-evt=refresh-event  bind:m  take-refresh-event
  ?:  ?=(%cancel -.utxo-evt)  (pure:m ~)
  =/  new-utxos=(list utxo)
    (parse-utxo-response client-response.utxo-evt)
  ::  fetch transactions
  =/  txs-url=@t
    (crip (weld (weld (mempool-base network.dat) (trip addr.dat)) "/txs"))
  =/  txs-req=request:http
    [%'GET' txs-url ~[['Accept' 'application/json']] ~]
  ;<  ~  bind:m  (send-request:io txs-req)
  ;<  txs-evt=refresh-event  bind:m  take-refresh-event
  ?:  ?=(%cancel -.txs-evt)  (pure:m ~)
  =/  new-txs=(list transaction)
    (parse-txs-response client-response.txs-evt)
  (pure:m `dat(info `new-info, utxos new-utxos, txs new-txs))
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
  ::  parse inputs
  =/  vin-json=(unit json)  (mole |.((~(got jo:json-utils tj) /vin)))
  =/  inputs=(list tx-input)
    ?~  vin-json  ~
    ?.  ?=(%a -.u.vin-json)  ~
    %+  murn  p.u.vin-json
    |=  ij=json
    ^-  (unit tx-input)
    =/  st=(unit @t)
      (mole |.((so:dejs:format (~(got jo:json-utils ij) /txid))))
    =/  sv=(unit @ud)
      (mole |.((ni:dejs:format (~(got jo:json-utils ij) /vout))))
    ?~  st  ~
    ?~  sv  ~
    =/  prevout=(unit tx-output)
      =/  pj=(unit json)  (mole |.((~(got jo:json-utils ij) /prevout)))
      ?~  pj  ~
      =/  pv=(unit @ud)
        (mole |.((ni:dejs:format (~(got jo:json-utils u.pj) /value))))
      =/  pa=(unit @t)
        (mole |.((so:dejs:format (~(got jo:json-utils u.pj) /'scriptpubkey_address'))))
      ?~  pv  ~
      ?~  pa  ~
      `[u.pv u.pa]
    `[u.st u.sv prevout]
  ::  parse outputs
  =/  vout-json=(unit json)  (mole |.((~(got jo:json-utils tj) /vout)))
  =/  outputs=(list tx-output)
    ?~  vout-json  ~
    ?.  ?=(%a -.u.vout-json)  ~
    %+  murn  p.u.vout-json
    |=  oj=json
    ^-  (unit tx-output)
    =/  v=(unit @ud)
      (mole |.((ni:dejs:format (~(got jo:json-utils oj) /value))))
    =/  a=(unit @t)
      (mole |.((so:dejs:format (~(got jo:json-utils oj) /'scriptpubkey_address'))))
    ?~  v  ~
    ?~  a  ~
    `[u.v u.a]
  ::  parse status
  =/  sj=(unit json)  (mole |.((~(got jo:json-utils tj) /status)))
  =/  status=tx-status
    ?~  sj  [%unconfirmed ~]
    (parse-tx-status u.sj)
  =/  fee=(unit @ud)
    (mole |.((ni:dejs:format (~(got jo:json-utils tj) /fee))))
  =/  size=(unit @ud)
    (mole |.((ni:dejs:format (~(got jo:json-utils tj) /size))))
  `[u.txid inputs outputs status fee size]
::
++  format-sats
  |=  n=@ud
  ^-  tape
  =/  digits=tape  (a-co:co n)
  =/  len=@ud  (lent digits)
  ?:  (lte len 3)  digits
  =/  rev=tape  (flop digits)
  =/  out=tape  ~
  =/  i=@ud  0
  |-
  ?~  rev  out
  =?  out  &((gth i 0) =(0 (mod i 3)))
    [',' out]
  $(rev t.rev, out [i.rev out], i +(i))
::
++  truncate-txid
  |=  txid=@t
  ^-  tape
  =/  full=tape  (trip txid)
  =/  len=@ud  (lent full)
  ?:  (lte len 16)  full
  :(weld (scag 8 full) "..." (slag (sub len 8) full))
::
++  detail-page
  |=  dat=address-data
  ^-  manx
  =/  addr-text=tape  (trip addr.dat)
  =/  chain-label=tape
    ?:(?=(%recv chain.dat) "Receiving" "Change")
  =/  network-label=tape
    ?-(network.dat %main "Mainnet", %testnet "Testnet", %regtest "Regtest")
  ;html
    ;head
      ;title: Address {(scag 12 addr-text)}...
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;+  feather:feather
      ;style
        ;+  ;/  style-text
      ==
    ==
    ;body
      ;div(style "min-width: 650px; height: 100%;")
        ;div.fc.g3.p5.ma.mw-page(style "height: 100%; overflow-y: auto;")
          ::  back link
          ;div(style "flex-shrink: 0;")
            ;a.hover.pointer(id "back-link", href "#", onclick "goBack(); return false;", style "color: var(--f3); text-decoration: none;"): ← Back to Account
          ==
          ::  header
          ;div.p4.b1.br2(style "flex-shrink: 0;")
            ;div(style "display: flex; align-items: center; gap: 8px; margin-bottom: 8px;")
              ;span.s-2.bold.f3(style "background: var(--b2); padding: 2px 8px; border-radius: 4px;"): {chain-label} #{(a-co:co idx.dat)}
              ;span.s-2.f3(style "background: var(--b2); padding: 2px 8px; border-radius: 4px;"): {network-label}
            ==
            ;div(style "display: flex; align-items: center; gap: 8px;")
              ;code.mono.s-1(style "word-break: break-all; flex: 1;"): {addr-text}
              ;button.p1.b0.br1.hover.pointer
                =data-addr  addr-text
                =onclick  "copyToClipboard(this.dataset.addr)"
                =style  "background: transparent; border: 1px solid var(--b3); color: var(--f3); display: flex; align-items: center; width: 28px; height: 28px; justify-content: center; outline: none; flex-shrink: 0;"
                ;div(style "width: 14px; height: 14px; display: flex; align-items: center; justify-content: center;")
                  ;+  (make:fi 'copy')
                ==
              ==
            ==
          ==
          ::  live content — replaced by SSE
          ;+  (live-content dat %.n)
        ==
      ==
      ;script
        ;+  ;/  script-text
      ==
    ==
  ==
::
++  style-text
  ^-  tape
  """
  html, body \{
    height: 100vh !important;
    overflow: hidden !important;
    margin: 0 !important;
  }
  @keyframes spin \{
    from \{ transform: rotate(0deg); }
    to \{ transform: rotate(360deg); }
  }
  """
::
++  script-text
  ^-  tape
  """
  var path = window.location.pathname;
  var m = path.match(/^(\\/\\w+)\\/(?:api\\/file|ball)\\/(.*?)\\/page\\.html/);
  var API = m ? m[1] + '/api' : '/grubbery/api';
  var addrBase = m ? m[2] : '';

  function goBack() \{
    var parts = path.split('/');
    // go up from the address directory to the account's page.html
    var addrDir = parts.slice(0, -2); // remove page.html and address dir
    // find the account dir (parent of addresses/)
    var idx = addrDir.lastIndexOf('addresses');
    if (idx >= 0) \{
      var acctParts = addrDir.slice(0, idx);
      window.location.href = acctParts.join('/') + '/page.html';
    } else \{
      history.back();
    }
  }

  function copyToClipboard(text) \{
    navigator.clipboard.writeText(text);
  }

  function doRefresh() \{
    var url = API + '/poke/' + addrBase + '/data.wallet_address?mark=json';
    fetch(url, \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(\{action: 'refresh'})
    }).then(function(r) \{
      if (!r.ok) return r.text().then(function(t) \{ console.error('refresh error', t) });
    }).catch(function(e) \{ console.error('refresh failed', e) });
  }

  function cancelRefresh() \{
    var url = API + '/poke/' + addrBase + '/data.wallet_address?mark=json';
    fetch(url, \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(\{action: 'cancel'})
    }).catch(function(e) \{ console.error('cancel failed', e) });
  }

  var SSE = API + '/keep/' + addrBase + '/ui/sse?mark=txt';
  var sseController = null;
  var sseReader = null;

  async function connectSSE() \{
    if (sseReader) try \{ sseReader.cancel(); } catch(e) \{}
    if (sseController) sseController.abort();
    sseController = new AbortController();
    try \{
      var r = await fetch(SSE, \{
        headers: \{Accept: 'text/event-stream'},
        signal: sseController.signal
      });
      sseReader = r.body.getReader();
      var dec = new TextDecoder();
      var buf = '';
      while (true) \{
        var chunk = await sseReader.read();
        if (chunk.done) break;
        buf += dec.decode(chunk.value, \{stream: true});
        var evts = buf.split('\\n\\n');
        buf = evts.pop();
        for (var i = 0; i < evts.length; i++) \{
          if (!evts[i].trim()) continue;
          var ev = '', data = [], lines = evts[i].split('\\n');
          for (var j = 0; j < lines.length; j++) \{
            if (lines[j].indexOf('event: ') === 0) ev = lines[j].slice(7);
            else if (lines[j].indexOf('data: ') === 0) data.push(lines[j].slice(6));
          }
          if (!ev) continue;
          var sp = ev.indexOf(' ');
          if (sp < 0) continue;
          var act = ev.slice(0, sp);
          if ((act === 'upd' || act === 'old' || act === 'new') && data.length) \{
            var tmp = document.createElement('div');
            tmp.innerHTML = data.join('\\n');
            var el = tmp.firstElementChild;
            if (el && el.id) \{
              var existing = document.getElementById(el.id);
              if (existing) existing.replaceWith(el);
            }
          }
        }
      }
    } catch (e) \{
      if (e.name !== 'AbortError') \{
        setTimeout(connectSSE, 2000);
      }
    }
  }
  window.addEventListener('beforeunload', function() \{
    if (sseReader) try \{ sseReader.cancel(); } catch(e) \{}
    if (sseController) sseController.abort();
  });
  connectSSE();
  """
--
