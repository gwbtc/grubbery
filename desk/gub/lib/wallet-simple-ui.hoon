::  wallet-simple-ui: simple bitcoin wallet page rendering
::
::  Dead simple vanilla bitcoin wallet. No coin control, no UTXO
::  management, no derivation paths. Just a balance, a way to
::  receive bitcoin (show address + QR), and a way to send it.
::
/<  wt            /lib/wallet-types.hoon
/<  feather       /lib/feather.hoon
/<  seed-phrases  /lib/seed-phrases.hoon
=,  wt
|%
+$  tx-entry  [dir=?(%sent %received) amt=@ud conf=? =transaction]
::
++  text
  |=  t=tape
  ^-  manx
  [[%$ [%$ t] ~] ~]
::
++  format-btc
  |=  sats=@ud
  ^-  tape
  =/  raw=tape  (a-co:co sats)
  =/  len=@ud  (lent raw)
  ?:  (lte len 3)  raw
  =/  rev=tape  (flop raw)
  =/  out=tape  ~
  =/  i=@ud  0
  |-
  ?~  rev  out
  =?  out  &((gth i 0) =(0 (mod i 3)))
    [',' out]
  $(rev t.rev, out [i.rev out], i +(i))
::
++  seed-to-cord
  |=  =seed
  ^-  @t
  ?-  -.seed
    %t  phrase.seed
    %q  (scot %q secret.seed)
  ==
::
++  mask-seed
  |=  =seed
  ^-  tape
  ?-    -.seed
      %t
    =/  words=(list tape)  (split-words:seed-phrases (trip phrase.seed))
    =/  shown=(list tape)  (scag 3 words)
    =/  rest=@ud  (sub (lent words) (min 3 (lent words)))
    =/  stars=(list tape)  (reap rest "****")
    =/  all=(list tape)  (weld shown stars)
    =/  out=tape  ~
    |-
    ?~  all  out
    ?~  out  $(all t.all, out i.all)
    $(all t.all, out (weld out (weld " " i.all)))
      %q
    =/  txt=tape  (scow %q secret.seed)
    (weld (scag 12 txt) "...")
  ==
::
++  compute-balance
  |=  [recv=(list [@ud address-data]) chng=(list [@ud address-data])]
  ^-  @ud
  =/  all=(list [@ud address-data])
    (weld recv chng)
  %+  roll  all
  |=  [[* ad=address-data] sum=@ud]
  %+  add  sum
  %+  roll  utxos.ad
  |=  [u=utxo acc=@ud]
  (add acc value.u)
::
++  collect-addrs
  |=  [recv=(list [@ud address-data]) chng=(list [@ud address-data])]
  ^-  (set @t)
  =/  all=(list [@ud address-data])
    (weld recv chng)
  %-  ~(gas in *(set @t))
  (turn all |=([* ad=address-data] addr.ad))
::
++  build-tx-list
  |=  [txs=tx-map our=(set @t)]
  ^-  (list tx-entry)
  =/  pairs=(list [@t transaction])  ~(tap by txs)
  =/  acc=(list tx-entry)  ~
  |-
  ?~  pairs  acc
  =/  tx=transaction  +.i.pairs
  =/  in-val=@ud
    %+  roll  outputs.tx  |=  [o=tx-output s=@ud]
    ?:((~(has in our) address.o) (add s value.o) s)
  =/  out-val=@ud
    %+  roll  inputs.tx  |=  [i=tx-input s=@ud]
    ?~  prevout.i  s
    ?:((~(has in our) address.u.prevout.i) (add s value.u.prevout.i) s)
  =/  conf=?  ?=([%confirmed *] tx-status.tx)
  =/  entries=(list tx-entry)
    ?:  (gth out-val in-val)
      =/  gross=@ud  (sub out-val in-val)
      =/  net=@ud  ?~(fee.tx gross ?:((gth u.fee.tx gross) gross (sub gross u.fee.tx)))
      ~[[%sent net conf tx]]
    ?:  (gth in-val out-val)
      ~[[%received (sub in-val out-val) conf tx]]
    ~
  $(pairs t.pairs, acc (weld entries acc))
::
++  sort-tx-list
  |=  entries=(list tx-entry)
  ^-  (list tx-entry)
  =/  unconf  (skim entries |=(e=tx-entry !conf.e))
  =/  conf
    %+  sort  (skim entries |=(e=tx-entry conf.e))
    |=  [a=tx-entry b=tx-entry]
    =/  ha=@ud
      ?.  ?=([%confirmed *] tx-status.transaction.a)  0
      block-height.tx-status.transaction.a
    =/  hb=@ud
      ?.  ?=([%confirmed *] tx-status.transaction.b)  0
      block-height.tx-status.transaction.b
    (gth ha hb)
  (weld unconf conf)
::
++  compute-pending
  |=  entries=(list tx-entry)
  ^-  [pin=@ud pout=@ud]
  =/  pin=@ud  0
  =/  pout=@ud  0
  |-
  ?~  entries  [pin pout]
  ?:  conf.i.entries  $(entries t.entries)
  ?:  ?=(%received dir.i.entries)
    $(entries t.entries, pin (add pin amt.i.entries))
  $(entries t.entries, pout (add pout amt.i.entries))
::
:::
++  next-unused-addr
  |=  addrs=(list [@ud address-data])
  ^-  (unit @t)
  =/  leaves=(list [@ud address-data])  (flop addrs)
  |-
  ?~  leaves  ~
  =/  [* ad=address-data]  i.leaves
  ?~  info.ad  `addr.ad
  ?:  &(=(0 (add tx-count.u.info.ad mem-tx-count.u.info.ad)) =(0 (add funded.u.info.ad mem-funded.u.info.ad)))
    `addr.ad
  $(leaves t.leaves)
::  +simple-page: render the full simple wallet HTML page
::
++  simple-page
  |=  $:  wal=(unit wallet-data)
          wal-name=@t
          active-net=(unit tape)
          recv=(list [@ud address-data])
          chng=(list [@ud address-data])
          txs=tx-map
          post-url=tape
          saved=?
          available-nets=(list tape)
          fee-rate=@ud
          last-offered=(unit @ud)
          last-change=(unit @ud)
          ships=(map @t @t)
      ==
  ^-  manx
  =/  wal-name=tape
    ?~  wal  "Wallet"
    (trip wal-name)
  =/  wal-seed=tape
    ?~  wal  ""
    (trip (seed-to-cord seed.u.wal))
  =/  wal-seed-masked=tape
    ?~  wal  ""
    (mask-seed seed.u.wal)
  =/  bal=@ud  (compute-balance recv chng)
  =/  bal-tape=tape  (format-btc bal)
  =/  bal-sats=tape  (a-co:co bal)
  =/  our=(set @t)  (collect-addrs recv chng)
  =/  tx-list=(list tx-entry)  (sort-tx-list (build-tx-list txs our))
  =/  [pending-in=@ud pending-out=@ud]  (compute-pending tx-list)
  =/  is-mainnet=?
    ?~  active-net  %.n
    =("main" u.active-net)
  =/  net-label=tape
    (fall active-net "unknown")
  =/  accent=tape  ?:(is-mainnet "#f7931a" "#6496ff")
  =/  accent-hover=tape  ?:(is-mainnet "#e8850f" "#5080e0")
  =/  accent-bg=tape  ?:(is-mainnet "rgba(247, 147, 26, 0.1)" "rgba(100, 150, 255, 0.1)")
  =/  accent-border=tape  ?:(is-mainnet "rgba(247, 147, 26, 0.25)" "rgba(100, 150, 255, 0.25)")
  =/  tx-items=(list manx)  (render-tx-items tx-list our ships)
  =/  recv-rows=(list manx)  (render-addr-rows (flop recv) %recv)
  =/  chng-rows=(list manx)  (render-addr-rows (flop chng) %chng)
  ;html
    ;head
      ;title: Wallet
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;+  feather:feather
      ;+  render-css
    ==
    ;body
      ;div.wallet-shell(style "--accent: {accent}; --accent-hover: {accent-hover}; --accent-bg: {accent-bg}; --accent-border: {accent-border};", data-net net-label, data-post-url post-url)
        ;+  (render-header wal-name net-label available-nets)
        ;+  (render-backup-banner saved)
        ;+  (render-balance-section bal-tape bal-sats pending-in pending-out)
        ;+  render-actions
        ;+  (render-tab-panel tx-items recv-rows chng-rows last-offered last-change)
        ;+  (render-send-popup bal fee-rate)
        ;+  (render-info-popup wal-seed wal-seed-masked saved fee-rate)
        ;+  render-tx-detail-popup
      ==
      ;script(src "https://cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js");
      ;+  render-js
    ==
  ==
::
++  render-header
  |=  [wal-name=tape net-label=tape available-nets=(list tape)]
  ^-  manx
  ;div.wallet-header
    ;div.wallet-header-left
      ;div.wallet-logo
        ;svg(xmlns "http://www.w3.org/2000/svg", viewBox "0 0 24 24", width "16", height "16", fill "white")
          ;path(d "M23.638,14.904c-1.602,6.43-8.113,10.34-14.542,8.736C2.67,22.05-1.244,15.525.362,9.105,1.962,2.67,8.475-1.243,14.9.358c6.43,1.605,10.342,8.115,8.738,14.546z");
          ;path(d "M17.204,10.296c0.239-1.596-0.977-2.453-2.64-3.025l0.54-2.163-1.317-0.328-0.525,2.107c-0.346-0.086-0.702-0.168-1.055-0.248l0.529-2.12-1.317-0.328-0.54,2.162c-0.286-0.065-0.567-0.13-0.84-0.198l0.001-0.007-1.816-0.453-0.35,1.407s0.977,0.224,0.957,0.238c0.533,0.133,0.63,0.486,0.614,0.766l-0.615,2.464c0.037,0.009,0.084,0.023,0.137,0.044l-0.139-0.035-0.862,3.453c-0.065,0.162-0.231,0.405-0.604,0.313,0.013,0.019-0.957-0.239-0.957-0.239l-0.654,1.508,1.714,0.427c0.319,0.08,0.631,0.164,0.939,0.243l-0.546,2.189,1.316,0.328,0.54-2.164c0.359,0.098,0.708,0.188,1.05,0.273l-0.538,2.155,1.317,0.328,0.546-2.186c2.245,0.425,3.933,0.253,4.643-1.778,0.572-1.635-0.028-2.578-1.21-3.194,0.861-0.199,1.509-0.764,1.681-1.933zm-3.009,4.22c-0.407,1.636-3.162,0.751-4.055,0.529l0.723-2.899c0.893,0.223,3.757,0.664,3.332,2.37zm0.407-4.243c-0.371,1.489-2.664,0.732-3.407,0.547l0.656-2.63c0.743,0.186,3.138,0.532,2.751,2.083z", fill "white");
        ==
      ==
      ;span#wallet-name.wallet-title(contenteditable "true", spellcheck "false"): {wal-name}
      ;+  ?:  (lth (lent available-nets) 2)
            ;span.net-badge: {net-label}
          ;div.net-dropdown
            ;button.net-badge.net-badge-toggle(onclick "toggleNetDropdown(event)")
              ;span: {net-label}
              ;span.net-arrow: ▾
            ==
            ;div#net-menu.net-menu
              ;*  %+  turn  available-nets
                  |=  net=tape
                  ;button.net-menu-item(onclick "switchNet('{net}')"): {net}
            ==
          ==
    ==
    ;button.info-btn(onclick "toggleInfo()")
      ;svg(xmlns "http://www.w3.org/2000/svg", viewBox "0 0 24 24", width "18", height "18", fill "none", stroke "currentColor", stroke-width "2", stroke-linecap "round", stroke-linejoin "round")
        ;circle(cx "12", cy "12", r "10");
        ;line(x1 "12", y1 "16", x2 "12", y2 "12");
        ;line(x1 "12", y1 "8", x2 "12.01", y2 "8");
      ==
    ==
  ==
::
++  render-balance-section
  |=  [bal-tape=tape bal-sats=tape pending-in=@ud pending-out=@ud]
  ^-  manx
  =/  has-pending=?  |(!=(0 pending-in) !=(0 pending-out))
  =/  pin-tape=tape  (format-btc pending-in)
  =/  pout-tape=tape  (format-btc pending-out)
  ;div
    ;div.balance-section
      ;div.balance-label-row
        ;span.balance-label: Total Balance
        ;button#sync-btn.sync-btn(onclick "refreshWallet()")
          ;svg(xmlns "http://www.w3.org/2000/svg", viewBox "0 0 24 24", width "14", height "14", fill "none", stroke "currentColor", stroke-width "2", stroke-linecap "round", stroke-linejoin "round")
            ;polyline(points "23 4 23 10 17 10");
            ;polyline(points "1 20 1 14 7 14");
            ;path(d "M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15");
          ==
        ==
      ==
      ;div.balance-amount: ฿{bal-tape}
      ;div.balance-fiat
        ;span#fiat-value(data-sats bal-sats): —
      ==
      ;div.balance-rate
        ;span#btc-rate: —
      ==
    ==
    ;+  ?.  has-pending
          ;div;
        ;div.unconf-balance
          ;div.unconf-label: Unconfirmed
          ;div.unconf-row
            ;+  ?:  =(0 pending-in)  ;span;
                ;div.unconf-in
                  ;span.unconf-amount-in: +฿{pin-tape}
                ==
            ;+  ?:  =(0 pending-out)  ;span;
                ;div.unconf-out
                  ;span.unconf-amount-out: -฿{pout-tape}
                ==
          ==
        ==
  ==
::
++  render-actions
  ^-  manx
  ;div.action-buttons
    ;button.action-btn.action-btn-primary(onclick "toggleSend()"): Send
  ==
::
++  render-tab-panel
  |=  [tx-items=(list manx) recv-rows=(list manx) chng-rows=(list manx) last-offered=(unit @ud) last-change=(unit @ud)]
  ^-  manx
  ;div.tab-panel
    ;div.tab-bar
      ;button.tab-btn.active(onclick "switchTab('activity', this)"): Activity
      ;button.tab-btn(onclick "switchTab('addresses', this)"): Addresses
    ==
    ;div#addr-subtabs.addr-tabs.hidden
      ;button.addr-tab.active(onclick "switchAddrTab('recv', this)"): Receiving
      ;button.addr-tab(onclick "switchAddrTab('chng', this)"): Change
    ==
    ;div#tab-activity.tab-content
      ;div.activity-list
        ;+  ?^  tx-items  ;span;
            ;div.activity-empty: No transactions yet
        ;*  tx-items
      ==
    ==
    ;div#tab-addresses.tab-content.hidden
      ;div#addr-recv.addr-list
        ;div.addr-last-offered: Last offered: {?~(last-offered "none" (weld "#" (a-co:co u.last-offered)))}
        ;+  ?^  recv-rows  ;span;
            ;div.addr-empty: No receiving addresses derived
        ;*  recv-rows
      ==
      ;div#addr-chng.addr-list.hidden
        ;div.addr-last-offered: Last change: {?~(last-change "none" (weld "#" (a-co:co u.last-change)))}
        ;+  ?^  chng-rows  ;span;
            ;div.addr-empty: No change addresses derived
        ;*  chng-rows
      ==
    ==
  ==
::
++  render-tx-items
  |=  [entries=(list tx-entry) our=(set @t) ships=(map @t @t)]
  ^-  (list manx)
  =/  items=(list manx)  ~
  |-
  ?~  entries  (flop items)
  =/  e=tx-entry  i.entries
  =/  amt-tape=tape  (format-btc amt.e)
  =/  dir-class=tape  ?:(?=(%sent dir.e) "tx-sent" "tx-received")
  =/  tx-time=tape  ""
  =/  status=tape
    ?.  conf.e  "Pending"
    ?.  ?=([%confirmed *] tx-status.transaction.e)  "Confirmed"
    "Block {(a-co:co block-height.tx-status.transaction.e)}"
  =/  counterparty-addr=tape
    ?:  ?=(%sent dir.e)
      =/  outs=(list tx-output)  outputs.transaction.e
      |-
      ?~  outs  ""
      ?.  (~(has in our) address.i.outs)
        (trip address.i.outs)
      $(outs t.outs)
    =/  ins=(list tx-input)  inputs.transaction.e
    |-
    ?~  ins  ""
    ?~  prevout.i.ins  $(ins t.ins)
    (trip address.u.prevout.i.ins)
  =/  ship-name=(unit @t)
    ?:  ?=(%sent dir.e)
      (~(get by ships) (crip counterparty-addr))
    =/  outs=(list tx-output)  outputs.transaction.e
    |-
    ?~  outs  ~
    ?.  (~(has in our) address.i.outs)  $(outs t.outs)
    =/  s=(unit @t)  (~(get by ships) address.i.outs)
    ?^  s  s
    $(outs t.outs)
  =/  counterparty=tape
    ?~  ship-name  counterparty-addr
    (trip u.ship-name)
  =/  ship-tape=tape  ?~(ship-name "" (trip u.ship-name))
  =/  addr-label=tape  ?:(?=(%sent dir.e) "To" "From")
  =/  txid-full=tape  (trip txid.transaction.e)
  =/  item=manx
    ;div.activity-tx(onclick "showTxDetail(this)", data-txid txid-full, data-addr counterparty-addr, data-ship ship-tape, data-addr-label addr-label, data-status status, data-time tx-time)
      ;div(class "activity-tx-icon {dir-class}")
        ;svg(xmlns "http://www.w3.org/2000/svg", viewBox "0 0 24 24", width "16", height "16", fill "none", stroke "currentColor", stroke-width "2.5", stroke-linecap "round", stroke-linejoin "round")
          ;+  ?:  ?=(%sent dir.e)
              ;polyline(points "5 12 12 5 19 12");
          ;polyline(points "19 12 12 19 5 12");
          ;line(x1 "12", y1 "19", x2 "12", y2 "5");
        ==
      ==
      ;div.activity-tx-body
        ;+  ?:  =(0 (lent counterparty))  ;span;
            ;div.activity-tx-addr: {counterparty}
        ;div.activity-tx-meta
          ;span.activity-tx-status(class ?:(conf.e "confirmed" "pending")): {status}
          ;+  ?:  =(0 (lent tx-time))  ;span;
              ;span.activity-tx-time: {tx-time}
        ==
      ==
      ;div.activity-tx-value
        ;div(class "activity-tx-amt {dir-class}")
          ;+  (text "{?:(?=(%sent dir.e) "-" "+")}฿{amt-tape}")
        ==
        ;div.activity-tx-fiat(data-sats "{(a-co:co amt.e)}"): ;
      ==
    ==
  $(entries t.entries, items [item items])
::
::
++  render-addr-rows
  |=  [leaves=(list [@ud address-data]) chain=?(%recv %chng)]
  ^-  (list manx)
  =/  chain-tape=tape  ?:(?=(%recv chain) "recv" "chng")
  =/  items=(list manx)  ~
  |-
  ?~  leaves  (flop items)
  =/  [idx=@ud ad=address-data]  i.leaves
  =/  a=tape  (trip addr.ad)
  =/  short=tape
    ?:  (lth (lent a) 20)  a
    (weld (scag 10 a) (weld "..." (slag (sub (lent a) 6) a)))
  =/  bal=@ud
    %+  roll  utxos.ad  |=([u=utxo s=@ud] (add s value.u))
  =/  bal-tape=tape  (format-btc bal)
  =/  has-pending=?
    %+  lien  utxos.ad
    |=(u=utxo ?=([%unconfirmed ~] tx-status.u))
  =/  last-title=tape
    ?~  info.ad  "Never refreshed"
    ?~  last-check.u.info.ad  "Never refreshed"
    =/  d=date  (yore u.last-check.u.info.ad)
    "Last refreshed: {(a-co:co m.d)}/{(a-co:co d.t.d)} {(a-co:co h.t.d)}:{?:((lth m.t.d 10) "0" "")}{(a-co:co m.t.d)}"
  =/  item=manx
    ;div.addr-item
      ;div.addr-item-left
        ;span.addr-idx: #{(a-co:co idx)}
        ;span.addr-short: {short}
        ;button.tx-copy-btn(onclick "copyAddr(this, event)", data-txid a)
          ;svg(xmlns "http://www.w3.org/2000/svg", viewBox "0 0 24 24", width "11", height "11", fill "none", stroke "currentColor", stroke-width "2", stroke-linecap "round", stroke-linejoin "round")
            ;rect(x "9", y "9", width "13", height "13", rx "2", ry "2");
            ;path(d "M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1");
          ==
        ==
        ;+  ?~  info.ad  ;span.addr-txc: ?
            ;span.addr-txc: {(a-co:co tx-count.u.info.ad)}tx
        ;+  ?.  has-pending  ;span;
            ;span.addr-pending: pending
      ==
      ;div.addr-item-right
        ;span.addr-bal: {bal-tape}
        ;span.addr-clock(title last-title)
          ;svg(xmlns "http://www.w3.org/2000/svg", viewBox "0 0 24 24", width "12", height "12", fill "none", stroke "currentColor", stroke-width "2", stroke-linecap "round", stroke-linejoin "round")
            ;circle(cx "12", cy "12", r "10");
            ;polyline(points "12 6 12 12 16 14");
          ==
        ==
        ;button.addr-refresh(onclick "refreshAddr('{chain-tape}', {(a-co:co idx)})", title "Refresh address")
          ;svg(xmlns "http://www.w3.org/2000/svg", viewBox "0 0 24 24", width "12", height "12", fill "none", stroke "currentColor", stroke-width "2", stroke-linecap "round", stroke-linejoin "round")
            ;polyline(points "23 4 23 10 17 10");
            ;polyline(points "1 20 1 14 7 14");
            ;path(d "M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15");
          ==
        ==
      ==
    ==
  $(leaves t.leaves, items [item items])
::
++  render-send-popup
  |=  [bal=@ud fee-rate=@ud]
  ^-  manx
  =/  est-fee=@ud  220
  =/  est-max=@ud  ?:((lth bal est-fee) 0 (sub bal est-fee))
  =/  est-max-tape=tape  (format-btc est-max)
  =/  fee-rate-tape=tape  (a-co:co fee-rate)
  ;div
    ;div#contact-picker.cp-overlay(onclick "closePicker(event)")
      ;div.cp-modal
        ;div.cp-header
          ;a.cp-manage(href "/grubbery/contacts", title "Manage Contacts")
            ;svg(xmlns "http://www.w3.org/2000/svg", viewBox "0 0 24 24", width "14", height "14", fill "none", stroke "currentColor", stroke-width "2", stroke-linecap "round", stroke-linejoin "round")
              ;path(d "M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2");
              ;circle(cx "9", cy "7", r "4");
              ;path(d "M23 21v-2a4 4 0 0 0-3-3.87");
              ;path(d "M16 3.13a4 4 0 0 1 0 7.75");
            ==
          ==
          ;span.cp-title: Select Contact
          ;button.cp-close(onclick "closePicker()"): ×
        ==
        ;input#cp-search.cp-search(type "text", placeholder "Search...", autocomplete "off", oninput "filterContacts()");
        ;div#cp-list.cp-list
          ;div.cp-empty: Loading contacts...
        ==
      ==
    ==
    ;div#send-overlay.send-overlay(onclick "closeSend(event)")
    ;div.send-modal
      ;button.send-close(onclick "toggleSend()"): ×
      ;div.send-title: Send Bitcoin
      ;div.send-field
        ;div.send-to-tabs
          ;button.send-to-tab.active(onclick "switchToTab('address', this)"): Address
          ;button.send-to-tab(onclick "switchToTab('contact', this)"): Contact
        ==
        ;div#to-address
          ;input#send-to.send-input(type "text", placeholder "bc1q...", autocomplete "off");
        ==
        ;div#to-contact.hidden
          ;div.to-contact-row
            ;input#send-to-ship.send-input(type "text", placeholder "~sampel-palnet", autocomplete "off");
            ;button.to-contact-btn(onclick "openPicker()"): Contacts
          ==
        ==
      ==
      ;div.send-field
        ;label.send-label: Amount (sats)
        ;input#send-amount.send-input(type "text", placeholder "0", autocomplete "off");
      ==
      ;div.send-field
        ;label.send-label: Fee rate (sat/vB)
        ;input#send-fee-rate.send-input.send-input-short(type "number", min "1", value fee-rate-tape, autocomplete "off");
      ==
      ;div.send-balance: Est. max: ฿{est-max-tape}
      ;div#send-status.send-status;
      ;button#send-btn.send-btn(onclick "sendBitcoin()"): Send
    ==
  ==
  ==
::
++  render-backup-banner
  |=  saved=?
  ^-  manx
  ;div(class "backup-banner {?:(saved "hidden" "")}", onclick "toggleInfo()")
    ;span.backup-banner-text: Back up your recovery phrase!
  ==
::
++  render-saved-checkbox
  |=  saved=?
  ^-  manx
  ;label.info-saved-row
    ;input#info-saved.info-checkbox(type "checkbox", onchange "toggleSaved(this)", data-checked "{?:(saved "true" "false")}");
    ;span.info-saved-text: I've saved my recovery phrase
  ==
::
++  render-info-popup
  |=  [wal-seed=tape wal-seed-masked=tape saved=? fee-rate=@ud]
  ^-  manx
  =/  fee-tape=tape  (a-co:co fee-rate)
  ;div#info-overlay.info-overlay(onclick "closeInfo(event)")
    ;div.info-modal
      ;button.info-close(onclick "toggleInfo()"): ×
      ;div.info-title: Wallet Info
      ;div.info-section
        ;div.info-label: Recovery Phrase
        ;div.info-seed-row
          ;span.info-seed: {wal-seed-masked}
          ;button.info-copy(onclick "copySeed(this)", data-seed "{wal-seed}")
            ;svg(xmlns "http://www.w3.org/2000/svg", viewBox "0 0 24 24", width "16", height "16", fill "none", stroke "currentColor", stroke-width "2", stroke-linecap "round", stroke-linejoin "round")
              ;rect(x "9", y "9", width "13", height "13", rx "2", ry "2");
              ;path(d "M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1");
            ==
          ==
        ==
        ;div.info-warning: Anyone with this phrase can access your funds. Store it somewhere safe.
        ;+  (render-saved-checkbox saved)
      ==
      ;div.info-title: Account Settings
      ;div.info-section
        ;div.info-label: Fee Rate (sat/vB)
        ;div.info-fee-row
          ;input#info-fee.info-fee-input(type "number", min "1", value fee-tape);
          ;button#info-fee-save.info-fee-save(onclick "saveFeeRate()"): Save
        ==
      ==
      ;div.info-title: Receive Address
      ;div.info-section
        ;div#info-addr-spinner.info-addr-spinner
          ;div.spinner;
        ==
        ;div#info-addr-content.info-addr-content
          ;div#info-addr-qr.info-addr-qr;
          ;div.info-addr-row
            ;span#info-addr-text.info-addr-text;
            ;button#info-addr-copy.receive-copy(onclick "copyInfoAddr(this)")
              ;svg(xmlns "http://www.w3.org/2000/svg", viewBox "0 0 24 24", width "16", height "16", fill "none", stroke "currentColor", stroke-width "2", stroke-linecap "round", stroke-linejoin "round")
                ;rect(x "9", y "9", width "13", height "13", rx "2", ry "2");
                ;path(d "M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1");
              ==
            ==
          ==
        ==
        ;div#info-addr-error.info-addr-error;
      ==
    ==
  ==
::
++  render-tx-detail-popup
  ^-  manx
  ;div.tx-detail-overlay.hidden(id "tx-detail-overlay", onclick "closeTxDetail(event)")
    ;div.tx-detail-modal
      ;button.receive-close(onclick "closeTxDetail()"): ×
      ;div.tx-detail-row.hidden(id "tx-detail-ship")
        ;span.tx-detail-label(id "tx-detail-ship-label"): From
        ;div.tx-detail-value-row
          ;a.tx-detail-ship-link(id "tx-detail-ship-value", href "/grubbery/contacts")
            ;svg.tx-detail-contact-icon(xmlns "http://www.w3.org/2000/svg", viewBox "0 0 24 24", width "14", height "14", fill "none", stroke "currentColor", stroke-width "2", stroke-linecap "round", stroke-linejoin "round")
              ;path(d "M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2");
              ;circle(cx "12", cy "7", r "4");
            ==
            ;span(id "tx-detail-ship-name");
          ==
        ==
      ==
      ;div.tx-detail-row.hidden(id "tx-detail-addr")
        ;span.tx-detail-label(id "tx-detail-addr-label"): Address
        ;div.tx-detail-value-row
          ;span.tx-detail-value(id "tx-detail-addr-value");
          ;button.tx-copy-btn(onclick "copyAddr(this, event)")
            ;svg(xmlns "http://www.w3.org/2000/svg", viewBox "0 0 24 24", width "14", height "14", fill "none", stroke "currentColor", stroke-width "2", stroke-linecap "round", stroke-linejoin "round")
              ;rect(x "9", y "9", width "13", height "13", rx "2", ry "2");
              ;path(d "M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1");
            ==
          ==
          ;a.tx-explorer-link.hidden(id "tx-detail-addr-link", href "", target "_blank", rel "noopener"): mempool.space
        ==
      ==
      ;div.tx-detail-row
        ;span.tx-detail-label: Txid
        ;div.tx-detail-value-row
          ;span.tx-detail-value(id "tx-detail-txid");
          ;button.tx-copy-btn(onclick "copyAddr(this, event)")
            ;svg(xmlns "http://www.w3.org/2000/svg", viewBox "0 0 24 24", width "14", height "14", fill "none", stroke "currentColor", stroke-width "2", stroke-linecap "round", stroke-linejoin "round")
              ;rect(x "9", y "9", width "13", height "13", rx "2", ry "2");
              ;path(d "M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1");
            ==
          ==
          ;a.tx-explorer-link.hidden(id "tx-detail-txid-link", href "", target "_blank", rel "noopener"): mempool.space
        ==
      ==
      ;div.tx-detail-row
        ;span.tx-detail-label: Status
        ;span.tx-detail-value(id "tx-detail-status");
      ==
      ;div.tx-detail-row.hidden(id "tx-detail-time-row")
        ;span.tx-detail-label: Time
        ;span.tx-detail-value(id "tx-detail-time");
      ==
    ==
  ==
::  +render-css: all CSS for the simple wallet
::  uses CSS custom properties set on .wallet-shell for accent colors
::
++  render-css
  ^-  manx
  ;style
    ; @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');
    ; body {
    ;   font-family: 'Inter', -apple-system, sans-serif;
    ;   background: var(--b0);
    ;   color: var(--f0);
    ;   margin: 0;
    ;   min-height: 100vh;
    ; }
    ; *, *:focus, *:active, *:focus-visible {
    ;   outline: none !important;
    ;   -webkit-tap-highlight-color: transparent;
    ;   box-shadow: none !important;
    ; }
    ; .wallet-shell {
    ;   max-width: 480px;
    ;   margin: 0 auto;
    ;   display: flex;
    ;   flex-direction: column;
    ; }
    ; .wallet-header {
    ;   display: flex;
    ;   align-items: center;
    ;   justify-content: space-between;
    ;   padding: 20px 24px 12px;
    ; }
    ; .wallet-header-left {
    ;   display: flex;
    ;   align-items: center;
    ;   gap: 10px;
    ; }
    ; .wallet-logo {
    ;   width: 28px;
    ;   height: 28px;
    ;   border-radius: 6px;
    ;   background: var(--accent);
    ;   display: flex;
    ;   align-items: center;
    ;   justify-content: center;
    ; }
    ; .wallet-title {
    ;   font-size: 16px;
    ;   font-weight: 600;
    ;   letter-spacing: -0.01em;
    ;   cursor: text;
    ;   outline: none;
    ;   border-bottom: 1px dashed transparent;
    ; }
    ; .wallet-title:hover { border-bottom-color: var(--f4); }
    ; .wallet-title:focus { border-bottom-color: var(--accent); }
    ; .net-badge {
    ;   font-size: 11px;
    ;   padding: 3px 8px;
    ;   border-radius: 6px;
    ;   background: var(--b2);
    ;   color: var(--f3);
    ;   font-weight: 500;
    ; }
    ; .net-dropdown { position: relative; display: inline-block; }
    ; .net-badge-toggle { border: none; cursor: pointer; display: flex; align-items: center; gap: 4px; }
    ; .net-badge-toggle:hover { opacity: 0.8; }
    ; .net-arrow { font-size: 10px; }
    ; .net-menu { display: none; position: absolute; top: 100%; left: 0; margin-top: 4px; background: var(--b1); border: 1px solid var(--b3); border-radius: 6px; min-width: 120px; box-shadow: 0 4px 12px rgba(0,0,0,0.2); z-index: 100; overflow: hidden; }
    ; .net-menu.open { display: block; }
    ; .net-menu-item { display: block; width: 100%; border: none; background: none; color: var(--f1); padding: 8px 12px; text-align: left; cursor: pointer; font-size: 12px; }
    ; .net-menu-item:hover { background: var(--b2); }
    ; .balance-section {
    ;   text-align: center;
    ;   padding: 32px 24px 28px;
    ; }
    ; .balance-label-row {
    ;   display: flex;
    ;   align-items: center;
    ;   justify-content: center;
    ;   gap: 6px;
    ;   margin-bottom: 8px;
    ; }
    ; .balance-label {
    ;   font-size: 13px;
    ;   color: var(--f3);
    ;   text-transform: uppercase;
    ;   letter-spacing: 0.08em;
    ; }
    ; .balance-amount {
    ;   font-size: 40px;
    ;   font-weight: 700;
    ;   letter-spacing: -0.02em;
    ;   line-height: 1;
    ;   margin-bottom: 6px;
    ; }
    ; .balance-fiat {
    ;   margin-top: 8px;
    ;   font-size: 14px;
    ;   color: var(--f3);
    ;   display: flex;
    ;   align-items: center;
    ;   justify-content: center;
    ;   gap: 6px;
    ; }
    ; .balance-rate {
    ;   margin-top: 4px;
    ;   font-size: 11px;
    ;   color: var(--f4);
    ;   text-align: center;
    ; }
    ; .sync-btn {
    ;   background: none;
    ;   border: none;
    ;   color: var(--f4);
    ;   cursor: pointer;
    ;   padding: 2px;
    ;   display: flex;
    ;   align-items: center;
    ;   border-radius: 50%;
    ;   width: 22px;
    ;   height: 22px;
    ;   transition: background 0.15s;
    ; }
    ; .sync-btn:hover { background: var(--b3); color: var(--f2); }
    ; .sync-btn.spinning svg { animation: spin 0.6s linear infinite; }
    ; @keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
    ; .hidden { display: none; }
    ; .unconf-balance {
    ;   text-align: center;
    ;   padding: 0 24px 24px;
    ;   opacity: 0.5;
    ; }
    ; .unconf-label {
    ;   font-size: 11px;
    ;   color: var(--f4);
    ;   text-transform: uppercase;
    ;   letter-spacing: 0.05em;
    ;   margin-bottom: 6px;
    ; }
    ; .unconf-row { display: flex; justify-content: center; gap: 16px; }
    ; .unconf-amount-in { font-size: 20px; font-weight: 600; color: #22c55e; }
    ; .unconf-amount-out { font-size: 20px; font-weight: 600; color: #ef4444; }
    ; .action-buttons {
    ;   display: flex;
    ;   gap: 12px;
    ;   padding: 0 24px 28px;
    ;   justify-content: center;
    ; }
    ; .action-btn {
    ;   flex: 1;
    ;   max-width: 140px;
    ;   padding: 14px 0;
    ;   border-radius: 14px;
    ;   border: none;
    ;   font-size: 15px;
    ;   font-weight: 600;
    ;   cursor: pointer;
    ;   display: flex;
    ;   align-items: center;
    ;   justify-content: center;
    ;   transition: all 0.15s;
    ;   font-family: inherit;
    ; }
    ; .action-btn-primary { background: var(--accent); color: #fff; }
    ; .action-btn-primary:hover { background: var(--accent-hover); }
    ; .tab-panel {
    ;   display: flex;
    ;   flex-direction: column;
    ;   height: calc(100vh - 460px);
    ;   margin: 0 24px 48px;
    ;   background: var(--b1);
    ;   border: 1px solid var(--b3);
    ;   border-radius: 16px;
    ;   overflow: hidden;
    ; }
    ; .tab-bar {
    ;   display: flex;
    ;   background: var(--b2);
    ;   padding: 4px;
    ; }
    ; .tab-btn {
    ;   flex: 1;
    ;   background: transparent;
    ;   border: none;
    ;   border-radius: 12px;
    ;   color: var(--f4);
    ;   font-size: 13px;
    ;   font-weight: 500;
    ;   padding: 8px 0;
    ;   cursor: pointer;
    ;   font-family: inherit;
    ;   transition: all 0.15s;
    ; }
    ; .tab-btn:hover { color: var(--f2); }
    ; .tab-btn.active {
    ;   background: var(--accent-bg);
    ;   color: var(--accent);
    ;   font-weight: 600;
    ; }
    ; .tab-content {
    ;   flex: 1;
    ;   display: flex;
    ;   flex-direction: column;
    ;   min-height: 0;
    ;   overflow-y: auto;
    ;   padding: 12px 16px;
    ; }
    ; .tab-content.hidden { display: none; }
    ; .activity-empty {
    ;   text-align: center;
    ;   padding: 32px 0;
    ;   color: var(--f4);
    ;   font-size: 14px;
    ; }
    ; .activity-list { padding-bottom: 16px; }
    ; .activity-tx {
    ;   display: flex;
    ;   gap: 12px;
    ;   padding: 12px 0;
    ;   border-bottom: 1px solid var(--b2);
    ;   align-items: center;
    ;   cursor: pointer;
    ; }
    ; .activity-tx:hover { opacity: 0.8; }
    ; .activity-tx:last-child { border-bottom: none; }
    ; .activity-tx-icon {
    ;   width: 36px;
    ;   height: 36px;
    ;   border-radius: 8px;
    ;   display: flex;
    ;   align-items: center;
    ;   justify-content: center;
    ;   flex-shrink: 0;
    ; }
    ; .activity-tx-icon.tx-received { background: #10b981; color: #fff; }
    ; .activity-tx-icon.tx-sent { background: var(--b3); color: var(--f2); }
    ; .activity-tx-body {
    ;   display: flex;
    ;   flex-direction: column;
    ;   gap: 2px;
    ;   min-width: 0;
    ;   flex: 1;
    ; }
    ; .activity-tx-addr {
    ;   font-size: 13px;
    ;   font-family: monospace;
    ;   color: var(--f1);
    ;   white-space: nowrap;
    ;   overflow: hidden;
    ;   text-overflow: ellipsis;
    ; }
    ; .activity-tx-meta { display: flex; gap: 8px; align-items: center; }
    ; .activity-tx-value {
    ;   display: flex;
    ;   flex-direction: column;
    ;   align-items: flex-end;
    ;   flex-shrink: 0;
    ;   margin-left: auto;
    ; }
    ; .activity-tx-amt { font-size: 14px; font-weight: 600; white-space: nowrap; }
    ; .activity-tx-fiat { font-size: 11px; color: var(--f4); white-space: nowrap; }
    ; .activity-tx-amt.tx-sent { color: var(--f1); }
    ; .activity-tx-amt.tx-received { color: #10b981; }
    ; .activity-tx-status { font-size: 11px; color: var(--f4); }
    ; .activity-tx-status.pending { color: var(--accent); }
    ; .activity-tx-time { font-size: 11px; color: var(--f4); }
    ; .addr-tabs { display: flex; gap: 4px; padding: 12px 16px 0; }
    ; .addr-tabs.hidden { display: none; }
    ; .addr-tab {
    ;   flex: 1;
    ;   background: var(--b2);
    ;   border: 1px solid var(--b3);
    ;   border-radius: 6px;
    ;   color: var(--f4);
    ;   font-size: 12px;
    ;   font-weight: 500;
    ;   padding: 6px 0;
    ;   cursor: pointer;
    ;   font-family: inherit;
    ; }
    ; .addr-tab:hover { color: var(--f2); }
    ; .addr-tab.active {
    ;   background: var(--accent-bg);
    ;   border-color: var(--accent-border);
    ;   color: var(--accent);
    ; }
    ; .addr-list {
    ;   display: flex;
    ;   flex-direction: column;
    ;   gap: 4px;
    ;   padding-bottom: 16px;
    ; }
    ; .addr-item {
    ;   display: flex;
    ;   justify-content: space-between;
    ;   align-items: center;
    ;   padding: 6px 8px;
    ;   background: var(--b1);
    ;   border: 1px solid var(--b3);
    ;   border-radius: 6px;
    ;   gap: 8px;
    ; }
    ; .addr-item-left { display: flex; align-items: center; gap: 6px; min-width: 0; }
    ; .addr-idx { font-size: 11px; font-family: monospace; color: var(--f4); flex-shrink: 0; }
    ; .addr-short {
    ;   font-size: 12px;
    ;   font-family: monospace;
    ;   color: var(--f2);
    ;   white-space: nowrap;
    ;   overflow: hidden;
    ;   text-overflow: ellipsis;
    ; }
    ; .addr-txc { font-size: 10px; color: var(--f4); flex-shrink: 0; }
    ; .addr-pending { font-size: 9px; color: var(--accent); font-weight: 600; text-transform: uppercase; flex-shrink: 0; }
    ; .addr-item-right { display: flex; align-items: center; flex-shrink: 0; gap: 6px; }
    ; .addr-bal { font-size: 11px; font-weight: 500; font-family: monospace; color: var(--f3); }
    ; .addr-clock { display: flex; align-items: center; color: var(--f4); opacity: 0.3; cursor: default; transition: opacity 0.15s; }
    ; .addr-clock:hover { opacity: 0.8; }
    ; .addr-refresh {
    ;   background: none;
    ;   border: none;
    ;   color: var(--f4);
    ;   cursor: pointer;
    ;   padding: 2px;
    ;   display: flex;
    ;   align-items: center;
    ;   opacity: 0.5;
    ;   transition: opacity 0.15s;
    ; }
    ; .addr-refresh:hover { opacity: 1; }
    ; .addr-refresh.spinning svg { animation: spin 0.6s linear infinite; }
    ; .addr-empty { text-align: center; padding: 24px 0; font-size: 13px; color: var(--f4); }
    ; .addr-last-offered { font-size: 11px; color: var(--f4); padding: 6px 12px; font-family: monospace; }
    ; .tx-copy-btn {
    ;   background: none;
    ;   border: none;
    ;   color: var(--f4);
    ;   cursor: pointer;
    ;   padding: 1px;
    ;   display: flex;
    ;   align-items: center;
    ;   flex-shrink: 0;
    ;   opacity: 0.5;
    ;   transition: opacity 0.15s;
    ; }
    ; .tx-copy-btn:hover { opacity: 1; }
    ; .tx-detail-overlay {
    ;   position: fixed;
    ;   top: 0; left: 0; right: 0; bottom: 0;
    ;   background: rgba(0,0,0,0.6);
    ;   z-index: 100;
    ;   display: flex;
    ;   align-items: center;
    ;   justify-content: center;
    ; }
    ; .tx-detail-overlay.hidden { display: none; }
    ; .tx-detail-modal {
    ;   background: var(--b0);
    ;   border-radius: 20px;
    ;   padding: 24px;
    ;   max-width: 400px;
    ;   width: 90%;
    ;   position: relative;
    ; }
    ; .tx-detail-row { margin-bottom: 16px; }
    ; .tx-detail-row:last-child { margin-bottom: 0; }
    ; .tx-detail-label { font-size: 11px; color: var(--f4); display: block; margin-bottom: 4px; }
    ; .tx-detail-value {
    ;   font-size: 13px;
    ;   font-family: monospace;
    ;   color: var(--f1);
    ;   white-space: nowrap;
    ;   overflow: hidden;
    ;   text-overflow: ellipsis;
    ;   min-width: 0;
    ; }
    ; .tx-detail-value-row { display: flex; align-items: center; gap: 8px; min-width: 0; }
    ; .tx-detail-ship-link { display: flex; align-items: center; gap: 6px; color: var(--f1); text-decoration: none; font-size: 13px; font-weight: 500; }
    ; .tx-detail-ship-link:hover { color: var(--accent); }
    ; .tx-detail-contact-icon { flex-shrink: 0; color: var(--f4); }
    ; .tx-detail-ship-link:hover .tx-detail-contact-icon { color: var(--accent); }
    ; .tx-explorer-link { flex-shrink: 0; font-size: 11px; color: var(--accent); text-decoration: none; }
    ; .tx-explorer-link:hover { text-decoration: underline; }
    ; .receive-close {
    ;   position: absolute;
    ;   top: 16px;
    ;   right: 16px;
    ;   background: none;
    ;   border: none;
    ;   color: var(--f4);
    ;   font-size: 20px;
    ;   cursor: pointer;
    ; }
    ; .receive-copy {
    ;   color: var(--f3);
    ;   cursor: pointer;
    ;   background: none;
    ;   border: none;
    ;   padding: 4px;
    ;   display: flex;
    ;   align-items: center;
    ;   flex-shrink: 0;
    ; }
    ; .receive-copy:hover { color: var(--accent); }
    ; .spinner {
    ;   width: 28px;
    ;   height: 28px;
    ;   border: 3px solid var(--b3);
    ;   border-top-color: var(--accent);
    ;   border-radius: 50%;
    ;   animation: spin 0.7s linear infinite;
    ;   margin: 0 auto 12px;
    ; }
    ; .send-overlay {
    ;   display: none;
    ;   position: fixed;
    ;   top: 0; left: 0; right: 0; bottom: 0;
    ;   background: rgba(0,0,0,0.6);
    ;   z-index: 100;
    ;   align-items: center;
    ;   justify-content: center;
    ; }
    ; .send-overlay.open { display: flex; }
    ; .send-modal {
    ;   background: var(--b0);
    ;   border-radius: 20px;
    ;   padding: 28px 24px;
    ;   max-width: 360px;
    ;   width: 90%;
    ;   position: relative;
    ; }
    ; .send-close {
    ;   position: absolute;
    ;   top: 16px;
    ;   right: 16px;
    ;   background: none;
    ;   border: none;
    ;   color: var(--f4);
    ;   font-size: 20px;
    ;   cursor: pointer;
    ; }
    ; .send-title { font-size: 16px; font-weight: 600; margin-bottom: 16px; }
    ; .send-to-tabs { display: flex; gap: 0; margin-bottom: 8px; }
    ; .send-to-tab { padding: 4px 10px; border: none; background: none; cursor: pointer; font-size: 12px; color: var(--f4); border-bottom: 2px solid transparent; font-family: inherit; }
    ; .send-to-tab:hover { color: var(--f2); }
    ; .send-to-tab.active { color: var(--f0); font-weight: 600; border-bottom-color: var(--accent); }
    ; #to-contact.hidden, #to-address.hidden { display: none; }
    ; .to-contact-row { display: flex; align-items: center; gap: 8px; }
    ; .to-contact-row .send-input { flex: 1; }
    ; .to-contact-btn { padding: 8px 14px; border-radius: 8px; border: 1px solid var(--b3); background: var(--b1); color: var(--f2); font-size: 13px; cursor: pointer; font-family: inherit; flex-shrink: 0; }
    ; .to-contact-btn:hover { background: var(--b2); }
    ; .cp-overlay { display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.6); z-index: 200; align-items: center; justify-content: center; }
    ; .cp-overlay.open { display: flex; }
    ; .cp-modal { background: var(--b0); border-radius: 16px; padding: 20px; max-width: 340px; width: 90%; }
    ; .cp-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; }
    ; .cp-title { font-size: 15px; font-weight: 600; }
    ; .cp-manage { color: var(--f4); display: flex; align-items: center; padding: 4px; text-decoration: none; margin-right: 8px; }
    ; .cp-manage:hover { color: var(--f2); }
    ; .cp-close { background: none; border: none; color: var(--f4); font-size: 18px; cursor: pointer; }
    ; .cp-search { width: 100%; padding: 10px 12px; background: var(--b1); border: 1px solid var(--b3); border-radius: 8px; color: var(--f0); font-size: 14px; font-family: inherit; box-sizing: border-box; margin-bottom: 8px; }
    ; .cp-search::placeholder { color: var(--f4); }
    ; .cp-list { max-height: 240px; overflow-y: auto; }
    ; .cp-row { display: flex; align-items: baseline; gap: 8px; padding: 10px 12px; border-radius: 8px; cursor: pointer; }
    ; .cp-row:hover { background: var(--b1); }
    ; .cp-row.fil-hide { display: none; }
    ; .cp-name { font-size: 14px; font-weight: 500; color: var(--f0); }
    ; .cp-ship { font-size: 11px; color: var(--f4); font-family: monospace; }
    ; .cp-empty { font-size: 13px; color: var(--f4); text-align: center; padding: 20px 0; }
    ; .send-field { margin-bottom: 16px; }
    ; .send-label {
    ;   display: block;
    ;   font-size: 12px;
    ;   font-weight: 500;
    ;   color: var(--f3);
    ;   margin-bottom: 6px;
    ; }
    ; .send-input {
    ;   width: 100%;
    ;   padding: 12px 14px;
    ;   background: var(--b1);
    ;   border: 1px solid var(--b3);
    ;   border-radius: 10px;
    ;   color: var(--f0);
    ;   font-size: 15px;
    ;   font-family: monospace;
    ;   box-sizing: border-box;
    ; }
    ; .send-input::placeholder { color: var(--f4); }
    ; .send-input-short { width: 120px; }
    ; .send-balance { font-size: 12px; color: var(--f4); margin-bottom: 20px; }
    ; .send-btn {
    ;   width: 100%;
    ;   padding: 14px;
    ;   border-radius: 14px;
    ;   border: none;
    ;   background: var(--accent);
    ;   color: #fff;
    ;   font-size: 15px;
    ;   font-weight: 600;
    ;   cursor: pointer;
    ;   font-family: inherit;
    ; }
    ; .send-btn:hover { background: var(--accent-hover); }
    ; .send-btn:disabled { opacity: 0.5; cursor: not-allowed; }
    ; .send-status { font-size: 12px; text-align: center; margin-bottom: 8px; min-height: 16px; }
    ; .send-status.error { color: #ff3b30; }
    ; .send-status.success { color: #34c759; }
    ; .send-status.pending { color: var(--f4); }
    ; .info-btn {
    ;   background: none;
    ;   border: none;
    ;   color: var(--f4);
    ;   cursor: pointer;
    ;   padding: 4px;
    ;   display: flex;
    ;   align-items: center;
    ; }
    ; .info-btn:hover { color: var(--f2); }
    ; .info-overlay {
    ;   display: none;
    ;   position: fixed;
    ;   top: 0; left: 0; right: 0; bottom: 0;
    ;   background: rgba(0,0,0,0.6);
    ;   z-index: 100;
    ;   align-items: center;
    ;   justify-content: center;
    ; }
    ; .info-overlay.open { display: flex; }
    ; .info-modal {
    ;   background: var(--b0);
    ;   border-radius: 20px;
    ;   padding: 28px 24px;
    ;   max-width: 360px;
    ;   width: 90%;
    ;   position: relative;
    ; }
    ; .info-close {
    ;   position: absolute;
    ;   top: 16px;
    ;   right: 16px;
    ;   background: none;
    ;   border: none;
    ;   color: var(--f4);
    ;   font-size: 20px;
    ;   cursor: pointer;
    ; }
    ; .info-title { font-size: 16px; font-weight: 600; margin-bottom: 20px; }
    ; .info-section { margin-bottom: 20px; }
    ; .info-section:last-child { margin-bottom: 0; }
    ; .info-label { font-size: 12px; font-weight: 500; color: var(--f3); margin-bottom: 8px; }
    ; .info-seed-row {
    ;   display: flex;
    ;   align-items: flex-start;
    ;   gap: 8px;
    ;   padding: 12px 14px;
    ;   background: var(--b1);
    ;   border-radius: 10px;
    ;   margin-bottom: 10px;
    ; }
    ; .info-seed { flex: 1; font-family: monospace; font-size: 13px; word-break: break-all; line-height: 1.5; }
    ; .info-copy {
    ;   color: var(--f3);
    ;   cursor: pointer;
    ;   background: none;
    ;   border: none;
    ;   padding: 4px;
    ;   display: flex;
    ;   align-items: center;
    ;   flex-shrink: 0;
    ; }
    ; .info-copy:hover { color: var(--accent); }
    ; .info-warning { font-size: 12px; color: var(--f4); line-height: 1.4; }
    ; .info-addr-spinner { display: none; text-align: center; padding: 20px 0; }
    ; .info-addr-spinner.show { display: block; }
    ; .info-addr-content { display: none; text-align: center; }
    ; .info-addr-content.show { display: block; }
    ; .info-addr-qr { display: flex; justify-content: center; margin: 12px 0; }
    ; .info-addr-row { display: flex; align-items: center; justify-content: center; gap: 8px; margin-top: 8px; }
    ; .info-addr-text { font-family: monospace; font-size: 12px; word-break: break-all; color: var(--f1); }
    ; .info-addr-error { display: none; color: #ff3b30; font-size: 13px; padding: 12px 0; }
    ; .info-addr-error.show { display: block; }
    ; .backup-banner { margin: 0 24px 16px; padding: 14px 18px; background: var(--accent-bg); border: 1px solid var(--accent-border); border-radius: 12px; text-align: center; cursor: pointer; }
    ; .backup-banner:hover { opacity: 0.85; }
    ; .backup-banner-text { font-size: 13px; font-weight: 600; color: var(--accent); }
    ; .info-saved-row { display: flex; align-items: center; gap: 10px; cursor: pointer; padding: 10px 0; }
    ; .info-checkbox { width: 18px; height: 18px; accent-color: var(--accent); cursor: pointer; flex-shrink: 0; }
    ; .info-saved-text { font-size: 14px; color: var(--f1); cursor: pointer; }
    ; .info-fee-row { display: flex; align-items: center; gap: 8px; }
    ; .info-fee-input {
    ;   width: 80px; padding: 8px 10px; background: var(--b1);
    ;   border: 1px solid var(--b3); border-radius: 8px;
    ;   color: var(--f0); font-size: 14px; font-family: monospace;
    ; }
    ; .info-fee-save {
    ;   padding: 8px 16px; background: var(--accent); color: white;
    ;   border: none; border-radius: 8px; font-size: 13px;
    ;   font-weight: 600; cursor: pointer;
    ; }
    ; .info-fee-save:hover { background: var(--accent-hover); }
    ; @media (min-width: 768px) {
    ;   .wallet-shell { max-width: 900px; }
    ;   .wallet-header { padding: 24px 32px 16px; }
    ;   .balance-section { padding: 40px 32px 36px; }
    ;   .balance-amount { font-size: 52px; }
    ;   .action-buttons { padding: 0 32px 36px; gap: 16px; }
    ;   .action-btn { max-width: 160px; padding: 16px 0; font-size: 16px; }
    ; }
  ==
::  +render-js: all JavaScript for the simple wallet
::
++  render-js
  ^-  manx
  ;script
    ; function walletPost(params) {
    ;   var url = document.querySelector('.wallet-shell').dataset.postUrl;
    ;   return fetch(url, {
    ;     method: 'POST',
    ;     headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    ;     body: params
    ;   });
    ; }
    ; function toggleNetDropdown(e) {
    ;   e.stopPropagation();
    ;   document.getElementById('net-menu').classList.toggle('open');
    ; }
    ; function switchNet(net) {
    ;   window.location.search = '?net=' + net;
    ; }
    ; document.addEventListener('click', function() {
    ;   var m = document.getElementById('net-menu');
    ;   if (m) m.classList.remove('open');
    ; });
    ; function fetchPrice() {
    ;   var el = document.getElementById('fiat-value');
    ;   if (!el) return;
    ;   var sats = parseInt(el.dataset.sats, 10);
    ;   fetch('https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd')
    ;     .then(function(r) { return r.json(); })
    ;     .then(function(d) {
    ;       var price = d.bitcoin.usd;
    ;       var usd = (sats / 100000000) * price;
    ;       var fmt = {style: 'currency', currency: 'USD'};
    ;       el.textContent = usd.toLocaleString('en-US', fmt);
    ;       var rateEl = document.getElementById('btc-rate');
    ;       if (rateEl) {
    ;         var rfmt = {style: 'currency', currency: 'USD', maximumFractionDigits: 0};
    ;         rateEl.textContent = '1 BTC = ' + price.toLocaleString('en-US', rfmt);
    ;       }
    ;       var txFiats = document.querySelectorAll('.activity-tx-fiat');
    ;       for (var i = 0; i < txFiats.length; i++) {
    ;         var s = parseInt(txFiats[i].dataset.sats, 10);
    ;         if (isNaN(s)) continue;
    ;         txFiats[i].textContent = ((s / 100000000) * price).toLocaleString('en-US', fmt);
    ;       }
    ;     }).catch(function(err) { console.error('fetchPrice', err); });
    ; }
    ; document.addEventListener('DOMContentLoaded', function() {
    ;   fetchPrice();
    ;   loadContacts();
    ;   var cb = document.getElementById('info-saved');
    ;   if (cb) cb.checked = cb.dataset.checked === 'true';
    ; });
    ; function loadContacts() {
    ;   fetch('/grubbery/contacts/api/overlays')
    ;     .then(function(r) { return r.json(); })
    ;     .then(function(data) {
    ;       var list = document.getElementById('cp-list');
    ;       var entries = Object.keys(data).map(function(ship) {
    ;         var f = data[ship] || {};
    ;         var nick = f.nickname || '';
    ;         return { ship: ship, nick: nick, sort: nick ? nick.toLowerCase() : ship };
    ;       });
    ;       entries.sort(function(a, b) { return a.sort < b.sort ? -1 : a.sort > b.sort ? 1 : 0; });
    ;       if (!entries.length) { list.innerHTML = '<div class="cp-empty">No contacts</div>'; return; }
    ;       list.innerHTML = entries.map(function(e) {
    ;         var label = e.nick ? '<span class="cp-name">' + e.nick + '</span><span class="cp-ship">' + e.ship + '</span>'
    ;                            : '<span class="cp-ship">' + e.ship + '</span>';
    ;         return '<div class="cp-row" onclick="pickContact(\'' + e.ship + '\', \'' + (e.nick || '') + '\')" data-ship="' + e.ship + '" data-nick="' + e.nick + '">' + label + '</div>';
    ;       }).join('');
    ;       document.querySelectorAll('.activity-tx').forEach(function(el) {
    ;         var addr = el.dataset.addr;
    ;         if (!addr || addr.charAt(0) != String.fromCharCode(126)) return;
    ;         var contact = data[addr];
    ;         if (!contact || !contact.nickname) return;
    ;         var addrDiv = el.querySelector('.activity-tx-addr');
    ;         if (addrDiv) addrDiv.innerHTML = '<span class="cp-name">' + contact.nickname + '</span> <span class="cp-ship">' + addr + '</span>';
    ;       });
    ;     })
    ;     .catch(function() {
    ;       document.getElementById('cp-list').innerHTML = '<div class="cp-empty">Failed to load contacts</div>';
    ;     });
    ; }
    ; function flashCheck(btn) {
    ;   var orig = btn.innerHTML;
    ;   btn.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="#10b981" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>';
    ;   setTimeout(function() { btn.innerHTML = orig; }, 1500);
    ; }
    ; function copyAddr(btn, e) {
    ;   if (e) e.stopPropagation();
    ;   navigator.clipboard.writeText(btn.dataset.txid).then(function() { flashCheck(btn); });
    ; }
    ; function copySeed(btn) {
    ;   navigator.clipboard.writeText(btn.dataset.seed).then(function() { flashCheck(btn); });
    ; }
    ; function mempoolBase() {
    ;   var net = document.querySelector('.wallet-shell').dataset.net;
    ;   if (net === 'main') return 'https://mempool.space';
    ;   if (net === 'testnet3') return 'https://mempool.space/testnet';
    ;   if (net === 'testnet4') return 'https://mempool.space/testnet4';
    ;   if (net === 'signet') return 'https://mempool.space/signet';
    ;   return 'https://mempool.space';
    ; }
    ; function showTxDetail(row) {
    ;   var ov = document.getElementById('tx-detail-overlay');
    ;   var txid = row.dataset.txid;
    ;   var addr = row.dataset.addr;
    ;   var base = mempoolBase();
    ;   document.getElementById('tx-detail-txid').textContent = txid;
    ;   var txBtn = document.getElementById('tx-detail-txid').parentElement.querySelector('.tx-copy-btn');
    ;   if (txBtn) txBtn.dataset.txid = txid;
    ;   var txLink = document.getElementById('tx-detail-txid-link');
    ;   txLink.href = base + '/tx/' + txid;
    ;   txLink.classList.remove('hidden');
    ;   var ship = row.dataset.ship;
    ;   var addr = row.dataset.addr;
    ;   var shipRow = document.getElementById('tx-detail-ship');
    ;   if (ship) {
    ;     shipRow.classList.remove('hidden');
    ;     document.getElementById('tx-detail-ship-label').textContent = row.dataset.addrLabel;
    ;     document.getElementById('tx-detail-ship-name').textContent = ship;
    ;   } else {
    ;     shipRow.classList.add('hidden');
    ;   }
    ;   var addrRow = document.getElementById('tx-detail-addr');
    ;   var addrLink = document.getElementById('tx-detail-addr-link');
    ;   var addrLabel = document.getElementById('tx-detail-addr-label');
    ;   if (addr) {
    ;     addrRow.classList.remove('hidden');
    ;     addrLabel.textContent = ship ? 'Address' : row.dataset.addrLabel;
    ;     document.getElementById('tx-detail-addr-value').textContent = addr;
    ;     var aBtn = addrRow.querySelector('.tx-copy-btn');
    ;     if (aBtn) aBtn.dataset.txid = addr;
    ;     addrLink.href = base + '/address/' + addr;
    ;     addrLink.classList.remove('hidden');
    ;   } else {
    ;     addrRow.classList.add('hidden');
    ;     addrLink.classList.add('hidden');
    ;   }
    ;   document.getElementById('tx-detail-status').textContent = row.dataset.status;
    ;   var timeRow = document.getElementById('tx-detail-time-row');
    ;   if (row.dataset.time) {
    ;     timeRow.classList.remove('hidden');
    ;     document.getElementById('tx-detail-time').textContent = row.dataset.time;
    ;   } else {
    ;     timeRow.classList.add('hidden');
    ;   }
    ;   ov.classList.remove('hidden');
    ; }
    ; function closeTxDetail(e) {
    ;   var ov = document.getElementById('tx-detail-overlay');
    ;   if (!e || e.target === ov) ov.classList.add('hidden');
    ; }
    ; function switchTab(tab, btn) {
    ;   document.getElementById('tab-activity').classList.toggle('hidden', tab !== 'activity');
    ;   document.getElementById('tab-addresses').classList.toggle('hidden', tab !== 'addresses');
    ;   document.getElementById('addr-subtabs').classList.toggle('hidden', tab !== 'addresses');
    ;   var tabs = btn.parentElement.querySelectorAll('.tab-btn');
    ;   for (var i = 0; i < tabs.length; i++) tabs[i].classList.remove('active');
    ;   btn.classList.add('active');
    ; }
    ; function switchAddrTab(tab, btn) {
    ;   document.getElementById('addr-recv').classList.toggle('hidden', tab !== 'recv');
    ;   document.getElementById('addr-chng').classList.toggle('hidden', tab !== 'chng');
    ;   var tabs = btn.parentElement.querySelectorAll('.addr-tab');
    ;   for (var i = 0; i < tabs.length; i++) tabs[i].classList.remove('active');
    ;   btn.classList.add('active');
    ; }
    ; function toggleSend() {
    ;   document.getElementById('send-overlay').classList.toggle('open');
    ; }
    ; function closeSend(e) {
    ;   if (e.target === document.getElementById('send-overlay')) toggleSend();
    ; }
    ; function switchToTab(tab, btn) {
    ;   document.getElementById('to-address').classList.toggle('hidden', tab !== 'address');
    ;   document.getElementById('to-contact').classList.toggle('hidden', tab !== 'contact');
    ;   var tabs = btn.parentElement.querySelectorAll('.send-to-tab');
    ;   for (var i = 0; i < tabs.length; i++) tabs[i].classList.remove('active');
    ;   btn.classList.add('active');
    ;   if (offerPoll) { clearTimeout(offerPoll); offerPoll = null; }
    ;   selectedNick = '';
    ;   document.getElementById('send-btn').disabled = false;
    ;   var st = document.getElementById('send-status'); st.className = 'send-status'; st.textContent = '';
    ; }
    ; function openPicker() {
    ;   document.getElementById('contact-picker').classList.add('open');
    ;   document.getElementById('cp-search').value = '';
    ;   filterContacts();
    ;   document.getElementById('cp-search').focus();
    ; }
    ; function closePicker(e) {
    ;   if (e && e.target !== document.getElementById('contact-picker')) return;
    ;   document.getElementById('contact-picker').classList.remove('open');
    ; }
    ; function filterContacts() {
    ;   var q = document.getElementById('cp-search').value.toLowerCase();
    ;   var rows = document.querySelectorAll('.cp-row');
    ;   for (var i = 0; i < rows.length; i++) {
    ;     var ship = (rows[i].dataset.ship || '').toLowerCase();
    ;     var nick = (rows[i].dataset.nick || '').toLowerCase();
    ;     rows[i].classList.toggle('fil-hide', q && ship.indexOf(q) < 0 && nick.indexOf(q) < 0);
    ;   }
    ; }
    ; var selectedNick = '';
    ; var offerPoll = null;
    ; function pickContact(ship, nick) {
    ;   document.getElementById('send-to-ship').value = ship;
    ;   selectedNick = nick || '';
    ;   document.getElementById('contact-picker').classList.remove('open');
    ; }
    ; function pollForOffer(ship, nick, attempts) {
    ;   if (attempts >= 15) {
    ;     var status = document.getElementById('send-status');
    ;     status.className = 'send-status error';
    ;     status.textContent = (nick || ship) + ' did not respond';
    ;     document.getElementById('send-btn').disabled = false;
    ;     return;
    ;   }
    ;   offerPoll = setTimeout(function() {
    ;     walletPost('action=offer-status')
    ;       .then(function(res) { return res.json(); })
    ;       .then(function(data) {
    ;         if (data.status === 'ready' && data.address) {
    ;           sendToAddress(data.address, ship, nick);
    ;         } else {
    ;           pollForOffer(ship, nick, attempts + 1);
    ;         }
    ;       }).catch(function() {
    ;         pollForOffer(ship, nick, attempts + 1);
    ;       });
    ;   }, 2000);
    ; }
    ; function sendToAddress(addr, ship, nick) {
    ;   var amtStr = document.getElementById('send-amount').value.trim();
    ;   var sats = parseInt(amtStr, 10);
    ;   var feeRate = parseInt(document.getElementById('send-fee-rate').value) || 2;
    ;   var status = document.getElementById('send-status');
    ;   var btn = document.getElementById('send-btn');
    ;   var label = nick ? nick + ' (' + ship + ')' : ship;
    ;   status.className = 'send-status pending';
    ;   status.textContent = 'Building & broadcasting to ' + label + '...';
    ;   var net = document.querySelector('.wallet-shell').dataset.net;
    ;   walletPost('action=set-fee-rate&fee-rate=' + feeRate + '&net=' + net);
    ;   walletPost('action=send-bitcoin&address=' + encodeURIComponent(addr) + '&amount=' + sats + '&fee-rate=' + feeRate + '&net=' + net)
    ;     .then(function(res) {
    ;       if (!res.ok) throw new Error('HTTP ' + res.status);
    ;       status.className = 'send-status success';
    ;       status.textContent = 'Transaction broadcast!';
    ;       setTimeout(function() { location.reload(); }, 1500);
    ;     }).catch(function(err) {
    ;       status.className = 'send-status error';
    ;       status.textContent = 'Send failed: ' + err.message;
    ;       btn.disabled = false;
    ;     });
    ; }
    ; function sendBitcoin() {
    ;   var status = document.getElementById('send-status');
    ;   var btn = document.getElementById('send-btn');
    ;   status.className = 'send-status';
    ;   status.textContent = '';
    ;   var contactMode = !document.getElementById('to-contact').classList.contains('hidden');
    ;   var amtStr = document.getElementById('send-amount').value.trim();
    ;   var sats = parseInt(amtStr, 10);
    ;   if (isNaN(sats) || sats <= 0) {
    ;     status.className = 'send-status error';
    ;     status.textContent = 'Enter a valid amount';
    ;     return;
    ;   }
    ;   if (sats < 546) {
    ;     status.className = 'send-status error';
    ;     status.textContent = 'Amount below dust limit (546)';
    ;     return;
    ;   }
    ;   if (contactMode) {
    ;     var ship = document.getElementById('send-to-ship').value.trim();
    ;     if (!ship || ship.indexOf('~') !== 0) {
    ;       status.className = 'send-status error';
    ;       status.textContent = 'Enter a valid ~ship';
    ;       return;
    ;     }
    ;     var nick = selectedNick;
    ;     var label = nick ? nick + ' (' + ship + ')' : ship;
    ;     if (!confirm('Send ' + sats.toLocaleString() + ' sats to ' + label + '?')) return;
    ;     btn.disabled = true;
    ;     status.className = 'send-status pending';
    ;     status.textContent = 'Requesting address from ' + label + '...';
    ;     var net = document.querySelector('.wallet-shell').dataset.net;
    ;     walletPost('action=request-address&ship=' + encodeURIComponent(ship) + '&net=' + net)
    ;       .then(function(res) {
    ;         if (!res.ok) throw new Error('HTTP ' + res.status);
    ;         pollForOffer(ship, nick, 0);
    ;       }).catch(function(err) {
    ;         status.className = 'send-status error';
    ;         status.textContent = 'Request failed: ' + err.message;
    ;         btn.disabled = false;
    ;       });
    ;     return;
    ;   }
    ;   var addr = document.getElementById('send-to').value.trim();
    ;   if (!addr) {
    ;     status.className = 'send-status error';
    ;     status.textContent = 'Enter a destination address';
    ;     return;
    ;   }
    ;   var feeRate = parseInt(document.getElementById('send-fee-rate').value) || 2;
    ;   if (!confirm('Send ' + sats.toLocaleString() + ' sats to ' + addr + ' @ ' + feeRate + ' sat/vB?')) return;
    ;   btn.disabled = true;
    ;   status.className = 'send-status pending';
    ;   status.textContent = 'Building & broadcasting...';
    ;   var net = document.querySelector('.wallet-shell').dataset.net;
    ;   walletPost('action=set-fee-rate&fee-rate=' + feeRate + '&net=' + net);
    ;   walletPost('action=send-bitcoin&address=' + encodeURIComponent(addr) + '&amount=' + sats + '&fee-rate=' + feeRate + '&net=' + net)
    ;     .then(function(res) {
    ;       if (!res.ok) throw new Error('HTTP ' + res.status);
    ;       status.className = 'send-status success';
    ;       status.textContent = 'Transaction broadcast!';
    ;       setTimeout(function() { location.reload(); }, 1500);
    ;     }).catch(function(err) {
    ;       status.className = 'send-status error';
    ;       status.textContent = 'Send failed: ' + err.message;
    ;       btn.disabled = false;
    ;     });
    ; }
    ; function toggleSaved(cb) {
    ;   walletPost('action=toggle-saved');
    ;   var banner = document.querySelector('.backup-banner');
    ;   if (banner) banner.classList.toggle('hidden');
    ; }
    ; function refreshWallet() {
    ;   var btn = document.getElementById('sync-btn');
    ;   if (btn) btn.classList.add('spinning');
    ;   walletPost('action=refresh-wallet').then(function() {
    ;     setTimeout(function() { location.reload(); }, 5000);
    ;   }).catch(function(err) {
    ;     console.error('refreshWallet', err);
    ;     if (btn) btn.classList.remove('spinning');
    ;   });
    ; }
    ; function refreshAddr(chain, index) {
    ;   var btn = event.currentTarget;
    ;   btn.classList.add('spinning');
    ;   walletPost('action=refresh-address&chain=' + chain + '&index=' + index)
    ;     .then(function() {
    ;       setTimeout(function() { location.reload(); }, 5000);
    ;     })
    ;     .catch(function(err) {
    ;       console.error('refreshAddr', err);
    ;       btn.classList.remove('spinning');
    ;     });
    ; }
    ; var infoAddrLoaded = false;
    ; function toggleInfo() {
    ;   var ov = document.getElementById('info-overlay');
    ;   var opening = !ov.classList.contains('open');
    ;   ov.classList.toggle('open');
    ;   if (opening && !infoAddrLoaded) refreshNextAddr();
    ; }
    ; function closeInfo(e) {
    ;   if (e.target === document.getElementById('info-overlay')) toggleInfo();
    ; }
    ; function refreshNextAddr() {
    ;   infoAddrLoaded = false;
    ;   document.getElementById('info-addr-spinner').classList.add('show');
    ;   document.getElementById('info-addr-content').classList.remove('show');
    ;   document.getElementById('info-addr-error').classList.remove('show');
    ;   document.getElementById('info-addr-qr').innerHTML = '';
    ;   var net = document.querySelector('.wallet-shell').dataset.net;
    ;   walletPost('action=get-receive-address&net=' + net).then(function(r) {
    ;     return r.text();
    ;   }).then(function(addr) {
    ;     addr = addr.trim();
    ;     document.getElementById('info-addr-spinner').classList.remove('show');
    ;     if (!addr) {
    ;       document.getElementById('info-addr-error').textContent = 'No address available';
    ;       document.getElementById('info-addr-error').classList.add('show');
    ;       return;
    ;     }
    ;     document.getElementById('info-addr-text').textContent = addr;
    ;     document.getElementById('info-addr-copy').dataset.addr = addr;
    ;     new QRCode(document.getElementById('info-addr-qr'), {
    ;       text: 'bitcoin:' + addr, width: 160, height: 160
    ;     });
    ;     document.getElementById('info-addr-content').classList.add('show');
    ;     infoAddrLoaded = true;
    ;   }).catch(function() {
    ;     document.getElementById('info-addr-spinner').classList.remove('show');
    ;     document.getElementById('info-addr-error').textContent = 'Failed to fetch address';
    ;     document.getElementById('info-addr-error').classList.add('show');
    ;   });
    ; }
    ; function copyInfoAddr(btn) {
    ;   navigator.clipboard.writeText(btn.dataset.addr).then(function() { flashCheck(btn); });
    ; }
    ; var _wn = document.getElementById('wallet-name');
    ; var _lastWalletName = _wn.textContent.trim();
    ; _wn.addEventListener('focus', function() {
    ;   _lastWalletName = this.textContent.trim();
    ; });
    ; _wn.addEventListener('blur', function() {
    ;   var n = this.textContent.trim();
    ;   if (!n || n === _lastWalletName) return;
    ;   walletPost('action=rename-wallet&name=' + encodeURIComponent(n));
    ; });
    ; _wn.addEventListener('keydown', function(e) {
    ;   if (e.key === 'Enter') { e.preventDefault(); this.blur(); }
    ; });
    ; function saveFeeRate() {
    ;   var fee = parseInt(document.getElementById('info-fee').value) || 2;
    ;   var btn = document.getElementById('info-fee-save');
    ;   var net = document.querySelector('.wallet-shell').dataset.net;
    ;   walletPost('action=set-fee-rate&fee-rate=' + fee + '&net=' + net).then(function() {
    ;     btn.textContent = 'Saved';
    ;     setTimeout(function() { btn.textContent = 'Save'; }, 1200);
    ;     var sf = document.getElementById('send-fee-rate');
    ;     if (sf) sf.value = fee;
    ;   });
    ; }
  ==
--
