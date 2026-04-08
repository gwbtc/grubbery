::  per-account nexus: individual BIP44 account instance
::
::  Each account directory contains:
::    data.account   account-data (name, xprv, script-type, addresses)
::    main.sig       poke handler for derive-next
::    page.html      rendered detail page (manx)
::
/<  feather       /lib/feather.hoon
/<  fi            /lib/feather-icons.hoon
/<  wt            /lib/wallet-types.hoon
/<  bip32         /lib/bip32.hoon
/<  bech32        /lib/bech32.hoon
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
            [%stay %& [/ %'data.wallet_account']]
            [%over %& [/ %'main.sig'] %.n [~ [/ %sig] !>(~)]]
            [%fall %| /ui [~ ~] [~ ~] empty-dir:loader]
            [%over %& [/ui %'sse-manager.sig'] %.n [~ [/ %sig] !>(~)]]
            [%fall %| /ui/sse [~ ~] [~ ~] empty-dir:loader]
            [%over %& [/ %'page.html'] %.n [~ [/ %manx] !>(;div;)]]
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
          ::  /page.html: render account detail, watch for data changes
          ::
          [~ %'page.html']
        ;<  ~  bind:m  (rise-wait:io prod "%account detail: failed")
        ::  watch entire dir for full initial state (scan, refreshing)
        ;<  init=view:nexus  bind:m
          (keep:io /data (cord-to-road:tarball './') ~)
        =/  acct=(unit account-data)  (extract-account init)
        ?~  acct
          |-
          ;<  upd=view:nexus  bind:m  (take-news:io /data)
          =/  acct=(unit account-data)  (extract-account upd)
          ?~  acct  $
          =/  pst  (extract-proc-state upd)
          ;<  =bowl:nexus  bind:m  get-bowl:io
          ;<  ~  bind:m  (replace:io !>((detail-page u.acct now.bowl scan.pst progress.pst refreshing.pst)))
          ::  hash on data + scan state + refreshing (not progress)
          =/  prev-hash=@  (mug [u.acct scan.pst refreshing.pst])
          |-
          ;<  upd=view:nexus  bind:m  (take-news:io /data)
          =/  acct=(unit account-data)  (extract-account upd)
          ?~  acct  $
          =/  pst  (extract-proc-state upd)
          =/  curr-hash=@  (mug [u.acct scan.pst refreshing.pst])
          ?:  =(prev-hash curr-hash)  $
          ;<  =bowl:nexus  bind:m  get-bowl:io
          ;<  ~  bind:m  (replace:io !>((detail-page u.acct now.bowl scan.pst progress.pst refreshing.pst)))
          $(prev-hash curr-hash)
        =/  pst  (extract-proc-state init)
        ;<  =bowl:nexus  bind:m  get-bowl:io
        ;<  ~  bind:m  (replace:io !>((detail-page u.acct now.bowl scan.pst progress.pst refreshing.pst)))
        =/  prev-hash=@  (mug [u.acct scan.pst refreshing.pst])
        |-
        ;<  upd=view:nexus  bind:m  (take-news:io /data)
        =/  acct=(unit account-data)  (extract-account upd)
        ?~  acct  $
        =/  pst  (extract-proc-state upd)
        =/  curr-hash=@  (mug [u.acct scan.pst refreshing.pst])
        ?:  =(prev-hash curr-hash)  $
        ;<  =bowl:nexus  bind:m  get-bowl:io
        ;<  ~  bind:m  (replace:io !>((detail-page u.acct now.bowl scan.pst progress.pst refreshing.pst)))
        $(prev-hash curr-hash)
          ::  /ui/sse-manager.sig: SSE manager process
          ::  watches account root, diffs state, writes targeted fragments to sse/
          ::
          [[%ui ~] %'sse-manager.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%account /ui/sse-manager: failed")
        ;<  init=view:nexus  bind:m
          (keep:io /data (cord-to-road:tarball '../') ~)
        =/  acct=(unit account-data)  (extract-account init)
        ?~  acct
          ::  no account data yet — wait
          |-
          ;<  upd=view:nexus  bind:m  (take-news:io /data)
          =/  acct=(unit account-data)  (extract-account upd)
          ?~  acct  $
          =/  pst  (extract-proc-state upd)
          ;<  =bowl:nexus  bind:m  get-bowl:io
          ;<  ~  bind:m  (sse-init u.acct now.bowl pst)
          =/  prev=sse-prev  (make-sse-prev u.acct pst)
          |-
          ;<  upd=view:nexus  bind:m  (take-news:io /data)
          =/  acct=(unit account-data)  (extract-account upd)
          ?~  acct  $
          =/  pst  (extract-proc-state upd)
          =/  curr=sse-prev  (make-sse-prev u.acct pst)
          ;<  =bowl:nexus  bind:m  get-bowl:io
          ;<  ~  bind:m  (sse-diff u.acct now.bowl prev curr)
          $(prev curr)
        ::  have account — initialize SSE files
        =/  pst  (extract-proc-state init)
        ;<  =bowl:nexus  bind:m  get-bowl:io
        ;<  ~  bind:m  (sse-init u.acct now.bowl pst)
        =/  prev=sse-prev  (make-sse-prev u.acct pst)
        |-
        ;<  upd=view:nexus  bind:m  (take-news:io /data)
        =/  acct=(unit account-data)  (extract-account upd)
        ?~  acct  $
        =/  pst  (extract-proc-state upd)
        =/  curr=sse-prev  (make-sse-prev u.acct pst)
        ;<  =bowl:nexus  bind:m  get-bowl:io
        ;<  ~  bind:m  (sse-diff u.acct now.bowl prev curr)
        $(prev curr)
          ::  /main.sig: handle pokes — dispatches to process files
          ::
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%account /main: failed")
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        ?+    name.p.sage  $
            %json
          =/  jon=json  !<(json q.sage)
          ?.  ?=([%o *] jon)  $
          =/  act=@t  (~(dug jo:json-utils jon) /action so:dejs:format '')
          ?+    act  $
              %'derive-next'
            =/  chain=@t
              (~(dug jo:json-utils jon) /chain so:dejs:format 'receiving')
            ;<  cur=view:nexus  bind:m
              (keep:io /acct-read (cord-to-road:tarball './') ~)
            =/  acct=(unit account-data)  (extract-account cur)
            ?~  acct  $
            =/  is-change=?  =(chain 'change')
            =/  addrs=(list address-entry)
              ?:(is-change change.u.acct receiving.u.acct)
            =/  next-idx=@ud  (lent addrs)
            =/  new-addr=(unit @t)
              %:  derive-addr
                xprv.u.acct
                script-type.u.acct
                network.u.acct
                ?:(is-change 1 0)
                next-idx
              ==
            ?~  new-addr  $
            =/  new-entry=address-entry  [u.new-addr ~]
            =/  new-addrs=(list address-entry)  (snoc addrs new-entry)
            =/  updated=account-data
              ?:  is-change
                u.acct(change new-addrs)
              u.acct(receiving new-addrs)
            ;<  ~  bind:m
              (over:io (cord-to-road:tarball './data.wallet_account') [[/wallet %account] !>(updated)])
            $
          ::
              %'refresh-address'
            =/  chain=@t
              (~(dug jo:json-utils jon) /chain so:dejs:format 'receiving')
            =/  idx=@ud
              (rash (~(dug jo:json-utils jon) /index so:dejs:format '0') dem)
            =/  chain-seg=@ta  ?:(=(chain 'change') %chng %recv)
            =/  proc-road=road:tarball
              %-  cord-to-road:tarball
              (crip "./proc/refresh/{(trip chain-seg)}/{(scow %ud idx)}.json")
            =/  proc-json=json
              (pairs:enjs:format ~[['status' s+'active']])
            ;<  ~  bind:m  (make:io proc-road |+[%.n [[/ %json] !>(proc-json)] ~])
            $
          ::
              %'full-scan'
            =/  proc-json=json
              %-  pairs:enjs:format
              :~  ['phase' s+'recv']
                  ['idx' (numb:enjs:format 0)]
                  ['gap' (numb:enjs:format 0)]
              ==
            ;<  ~  bind:m
              (make:io (cord-to-road:tarball './proc/scan.json') |+[%.n [[/ %json] !>(proc-json)] ~])
            $
          ::
              %'pause-scan'
            =/  pause-json=json
              (pairs:enjs:format ~[['action' s+'pause']])
            ;<  ~  bind:m
              (poke:io (cord-to-road:tarball './proc/scan.json') [[/ %json] !>(pause-json)])
            $
          ::
              %'resume-scan'
            =/  resume-json=json
              (pairs:enjs:format ~[['action' s+'resume']])
            ;<  ~  bind:m
              (poke:io (cord-to-road:tarball './proc/scan.json') [[/ %json] !>(resume-json)])
            $
          ::
              %'cancel-scan'
            ;<  *  bind:m
              (cull-soft:io (cord-to-road:tarball './proc/scan.json'))
            ;<  *  bind:m
              (cull-soft:io (cord-to-road:tarball './scan-paused.json'))
            $
          ::
              %'cancel-refresh'
            =/  chain=@t
              (~(dug jo:json-utils jon) /chain so:dejs:format 'receiving')
            =/  idx=@ud
              (rash (~(dug jo:json-utils jon) /index so:dejs:format '0') dem)
            =/  chain-seg=@ta  ?:(=(chain 'change') %chng %recv)
            =/  proc-road=road:tarball
              %-  cord-to-road:tarball
              (crip "./proc/refresh/{(trip chain-seg)}/{(scow %ud idx)}.json")
            ;<  *  bind:m  (cull-soft:io proc-road)
            $
          ==
        ==
      ::
          ::  /proc/scan.json: full scan process
          ::
          [[%proc ~] %'scan.json']
        ;<  ~  bind:m  (rise-wait:io prod "%scan: failed")
        =/  data-road=road:tarball  (cord-to-road:tarball '../data.wallet_account')
        ;<  cur=view:nexus  bind:m
          (keep:io /acct (cord-to-road:tarball '../') ~)
        =/  acct=(unit account-data)  (extract-account cur)
        ?~  acct  (pure:m ~)
        ::  scan receiving then change
        ;<  recv-result=account-data  bind:m
          (scan-chain u.acct %receiving network.u.acct data-road)
        ;<  chng-result=account-data  bind:m
          (scan-chain recv-result %change network.recv-result data-road)
        (pure:m ~)
      ::
          ::  /proc/refresh/recv/*.json: refresh a receiving address
          ::
          [[%proc %refresh %recv ~] *]
        ;<  ~  bind:m  (rise-wait:io prod "%refresh recv: failed")
        =/  idx=@ud
          (rash (crip (scag (sub (lent (trip name.rail)) 5) (trip name.rail))) dem)
        ;<  cur=view:nexus  bind:m
          (keep:io /acct (cord-to-road:tarball '../../../') ~)
        =/  acct=(unit account-data)  (extract-account cur)
        ?~  acct  (pure:m ~)
        ?:  (gte idx (lent receiving.u.acct))
          (pure:m ~)
        =/  entry=address-entry  (snag idx receiving.u.acct)
        ;<  new-info=(unit address-info)  bind:m
          (fetch-address-info addr.entry network.u.acct)
        ?~  new-info  (pure:m ~)
        =/  updated-entry=address-entry  [addr.entry `u.new-info]
        =/  new-recv=(list address-entry)
          (snap receiving.u.acct idx updated-entry)
        =/  updated=account-data  u.acct(receiving new-recv)
        ;<  ~  bind:m
          (over:io (cord-to-road:tarball '../../../data.wallet_account') [[/wallet %account] !>(updated)])
        (pure:m ~)
      ::
          ::  /proc/refresh/chng/*.json: refresh a change address
          ::
          [[%proc %refresh %chng ~] *]
        ;<  ~  bind:m  (rise-wait:io prod "%refresh chng: failed")
        =/  idx=@ud
          (rash (crip (scag (sub (lent (trip name.rail)) 5) (trip name.rail))) dem)
        ;<  cur=view:nexus  bind:m
          (keep:io /acct (cord-to-road:tarball '../../../') ~)
        =/  acct=(unit account-data)  (extract-account cur)
        ?~  acct  (pure:m ~)
        ?:  (gte idx (lent change.u.acct))  (pure:m ~)
        =/  entry=address-entry  (snag idx change.u.acct)
        ;<  new-info=(unit address-info)  bind:m
          (fetch-address-info addr.entry network.u.acct)
        ?~  new-info  (pure:m ~)
        =/  updated-entry=address-entry  [addr.entry `u.new-info]
        =/  new-chng=(list address-entry)
          (snap change.u.acct idx updated-entry)
        =/  updated=account-data  u.acct(change new-chng)
        ;<  ~  bind:m
          (over:io (cord-to-road:tarball '../../../data.wallet_account') [[/wallet %account] !>(updated)])
        (pure:m ~)
      ==
    ::
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'Subdirectory under this account.'
            ~
          'Individual BIP44 account. Derives and displays Bitcoin addresses.'
            [%ui %sse ~]
          'SSE streams for live UI updates.'
        ==
          %|
        ?+  rail.p.mana  'File under this account.'
          [~ %'data.wallet_account']  'Account data: name, xprv, script-type, addresses. Mark: account.'
          [~ %'main.sig']      'Poke handler for account actions. Mark: sig.'
          [~ %'page.html']     'Rendered account detail page. Mark: manx.'
          [~ %'ver.ud']        'Schema version.'
        ==
      ==
    --
::  types and rendering
::
|%
++  data-to-page
  |=  [gn=? ct=content:tarball]
  ^-  [? content:tarball]
  ?:  =(ct *content:tarball)  [%.n ct]
  ?:  =([/ %boom] p.sage.ct)  [%.n ct]
  =/  acct=account-data  !<(account-data q.sage.ct)
  [%.n [~ [/ %manx] !>((detail-page acct *@da %none ~ ~))]]
::
++  extract-account
  |=  =view:nexus
  ^-  (unit account-data)
  ?.  ?=([%ball *] view)  ~
  =/  =lump:tarball  (fall fil.ball.view *lump:tarball)
  =/  ct=(unit content:tarball)  (~(get by contents.lump) 'data.wallet_account')
  ?~  ct  ~
  ?.  ?=(%account name.p.sage.u.ct)  ~
  (mole |.(!<(account-data q.sage.u.ct)))
::
+$  scan-progress  [phase=@t idx=@ud gap=@ud]
::
++  extract-proc-state
  |=  =view:nexus
  ^-  [scan=?(%active %paused %none) progress=(unit scan-progress) refreshing=(set [?(%recv %chng) @ud])]
  ?.  ?=([%ball *] view)  [%none ~ ~]
  ::  check for scan-paused.json marker at account root
  =/  root-lump=(unit lump:tarball)  fil.ball.view
  =/  is-paused=?
    ?~  root-lump  %.n
    (~(has by contents.u.root-lump) 'scan-paused.json')
  ::  check for scan proc file and extract progress
  =/  proc-dir=(unit ball:tarball)  (~(get by dir.ball.view) 'proc')
  =/  has-scan=?
    ?~  proc-dir  %.n
    ?~  fil.u.proc-dir  %.n
    (~(has by contents.u.fil.u.proc-dir) 'scan.json')
  =/  progress=(unit scan-progress)
    ?.  has-scan  ~
    =/  pd=ball:tarball  (need proc-dir)
    =/  lp=lump:tarball  (need fil.pd)
    =/  ct=(unit content:tarball)
      (~(get by contents.lp) 'scan.json')
    ?~  ct  ~
    =/  res=(unit json)  (mole |.(!<(json q.sage.u.ct)))
    ?~  res  ~
    ?.  ?=([%o *] u.res)  ~
    =/  phase=(unit json)  (~(get by p.u.res) 'phase')
    =/  idx-j=(unit json)  (~(get by p.u.res) 'idx')
    =/  gap-j=(unit json)  (~(get by p.u.res) 'gap')
    ?.  &(?=([~ %s *] phase) ?=([~ %n *] idx-j) ?=([~ %n *] gap-j))  ~
    =/  idx=(unit @ud)  (rush p.u.idx-j dem)
    =/  gap=(unit @ud)  (rush p.u.gap-j dem)
    ?~  idx  ~
    ?~  gap  ~
    `[p.u.phase u.idx u.gap]
  =/  scan=?(%active %paused %none)
    ?:  is-paused  %paused
    ?:(has-scan %active %none)
  ::  check for refreshes
  ?~  proc-dir  [scan progress ~]
  =/  refresh-dir=(unit ball:tarball)  (~(get by dir.u.proc-dir) 'refresh')
  ?~  refresh-dir  [scan progress ~]
  =/  refreshing=(set [?(%recv %chng) @ud])  ~
  ::  check recv
  =/  recv-dir=(unit ball:tarball)  (~(get by dir.u.refresh-dir) 'recv')
  =.  refreshing
    ?~  recv-dir  refreshing
    ?~  fil.u.recv-dir  refreshing
    =/  names=(list @ta)  ~(tap in ~(key by contents.u.fil.u.recv-dir))
    |-
    ?~  names  refreshing
    =/  name-tape=tape  (trip i.names)
    =/  idx=(unit @ud)
      (rush (crip (scag (sub (lent name-tape) 5) name-tape)) dem)
    =?  refreshing  ?=(^ idx)
      (~(put in refreshing) [%recv u.idx])
    $(names t.names)
  ::  check chng
  =/  chng-dir=(unit ball:tarball)  (~(get by dir.u.refresh-dir) 'chng')
  =.  refreshing
    ?~  chng-dir  refreshing
    ?~  fil.u.chng-dir  refreshing
    =/  names=(list @ta)  ~(tap in ~(key by contents.u.fil.u.chng-dir))
    |-
    ?~  names  refreshing
    =/  name-tape=tape  (trip i.names)
    =/  idx=(unit @ud)
      (rush (crip (scag (sub (lent name-tape) 5) name-tape)) dem)
    =?  refreshing  ?=(^ idx)
      (~(put in refreshing) [%chng u.idx])
    $(names t.names)
  [scan progress refreshing]
::
++  derive-addr
  |=  [xprv=@t =script-type network=?(%main %testnet %regtest) chain=@ud index=@ud]
  ^-  (unit @t)
  =/  acct-key  (from-extended:bip32 (trip xprv))
  =/  chain-key  (derive:acct-key chain)
  =/  addr-key  (derive:chain-key index)
  =/  pubkey=@  public-key:addr-key
  ?-  script-type
    %p2wpkh      (encode-pubkey:bech32 network [33 pubkey])
    %p2tr        (encode-taproot:bech32 network [32 (end [3 32] pubkey)])
    %p2pkh       ~
    %p2sh-p2wpkh  ~
  ==
::
++  format-account-path
  |=  [purpose=seg coin-type=seg account-idx=seg]
  ^-  tape
  =/  [ph=? pi=@ud]  purpose
  =/  [ch=? ci=@ud]  coin-type
  =/  [ah=? ai=@ud]  account-idx
  %+  welp  "m/"
  %+  welp  (scow %ud pi)
  %+  welp  ?:(ph "'" "")
  %+  welp  "/"
  %+  welp  (scow %ud ci)
  %+  welp  ?:(ch "'" "")
  %+  welp  "/"
  %+  welp  (scow %ud ai)
  ?:(ah "'" "")
::
++  purpose-badge
  |=  purpose=seg
  ^-  manx
  =/  [hardened=? index=@ud]  purpose
  =/  tooltip=tape
    ?+  index  (scow %ud index)
        %86  "Taproot (BIP86) - 86"
        %84  "Native SegWit (BIP84) - 84"
        %49  "Wrapped SegWit (BIP49) - 49"
        %44  "Legacy (BIP44) - 44"
    ==
  =/  [color=tape label=tape]
    ?+  index  ["#888" (scow %ud index)]
        %86  ["#9333ea" "86"]
        %84  ["#10b981" "84"]
        %49  ["#f59e0b" "49"]
        %44  ["#6b7280" "44"]
    ==
  ;div(title "{tooltip}", style "display: inline-flex; align-items: center; justify-content: center; width: 18px; height: 18px; border-radius: 50%; background: {color}; color: white; font-size: 10px; font-weight: bold; font-family: monospace; cursor: default;"): {label}
::
++  coin-type-badge
  |=  coin-type=seg
  ^-  manx
  =/  [hardened=? index=@ud]  coin-type
  =/  tooltip=tape
    ?+  index  (scow %ud index)
        %0  "Bitcoin Mainnet - 0"
        %1  "Bitcoin Testnet - 1"
    ==
  =/  badge=manx
    ?+  index
      %-  need  %-  de-xml:html
      '<svg xmlns="http://www.w3.org/2000/svg" height="16" width="16" viewBox="0 0 64 64"><circle cx="32" cy="32" r="30" fill="#9ca3af"/></svg>'
    ::
        %0
      %-  need  %-  de-xml:html
      '<svg xmlns="http://www.w3.org/2000/svg" height="16" width="16" viewBox="0 0 64 64"><g transform="translate(0.00630876,-0.00301984)"><path fill="#f7931a" d="m63.033,39.744c-4.274,17.143-21.637,27.576-38.782,23.301-17.138-4.274-27.571-21.638-23.295-38.78,4.272-17.145,21.635-27.579,38.775-23.305,17.144,4.274,27.576,21.64,23.302,38.784z"/><path fill="#FFF" d="m46.103,27.444c0.637-4.258-2.605-6.547-7.038-8.074l1.438-5.768-3.511-0.875-1.4,5.616c-0.923-0.23-1.871-0.447-2.813-0.662l1.41-5.653-3.509-0.875-1.439,5.766c-0.764-0.174-1.514-0.346-2.242-0.527l0.004-0.018-4.842-1.209-0.934,3.75s2.605,0.597,2.55,0.634c1.422,0.355,1.679,1.296,1.636,2.042l-1.638,6.571c0.098,0.025,0.225,0.061,0.365,0.117-0.117-0.029-0.242-0.061-0.371-0.092l-2.296,9.205c-0.174,0.432-0.615,1.08-1.609,0.834,0.035,0.051-2.552-0.637-2.552-0.637l-1.743,4.019,4.569,1.139c0.85,0.213,1.683,0.436,2.503,0.646l-1.453,5.834,3.507,0.875,1.439-5.772c0.958,0.26,1.888,0.5,2.798,0.726l-1.434,5.745,3.511,0.875,1.453-5.823c5.987,1.133,10.489,0.676,12.384-4.739,1.527-4.36-0.076-6.875-3.226-8.515,2.294-0.529,4.022-2.038,4.483-5.155zm-8.022,11.249c-1.085,4.36-8.426,2.003-10.806,1.412l1.928-7.729c2.38,0.594,10.012,1.77,8.878,6.317zm1.086-11.312c-0.99,3.966-7.1,1.951-9.082,1.457l1.748-7.01c1.982,0.494,8.365,1.416,7.334,5.553z"/></g></svg>'
    ::
        %1
      %-  need  %-  de-xml:html
      '<svg xmlns="http://www.w3.org/2000/svg" height="16" width="16" viewBox="0 0 64 64"><g transform="translate(0.00630876,-0.00301984)"><path fill="#6b8fd8" d="m63.033,39.744c-4.274,17.143-21.637,27.576-38.782,23.301-17.138-4.274-27.571-21.638-23.295-38.78,4.272-17.145,21.635-27.579,38.775-23.305,17.144,4.274,27.576,21.64,23.302,38.784z"/><path fill="#FFF" d="m46.103,27.444c0.637-4.258-2.605-6.547-7.038-8.074l1.438-5.768-3.511-0.875-1.4,5.616c-0.923-0.23-1.871-0.447-2.813-0.662l1.41-5.653-3.509-0.875-1.439,5.766c-0.764-0.174-1.514-0.346-2.242-0.527l0.004-0.018-4.842-1.209-0.934,3.75s2.605,0.597,2.55,0.634c1.422,0.355,1.679,1.296,1.636,2.042l-1.638,6.571c0.098,0.025,0.225,0.061,0.365,0.117-0.117-0.029-0.242-0.061-0.371-0.092l-2.296,9.205c-0.174,0.432-0.615,1.08-1.609,0.834,0.035,0.051-2.552-0.637-2.552-0.637l-1.743,4.019,4.569,1.139c0.85,0.213,1.683,0.436,2.503,0.646l-1.453,5.834,3.507,0.875,1.439-5.772c0.958,0.26,1.888,0.5,2.798,0.726l-1.434,5.745,3.511,0.875,1.453-5.823c5.987,1.133,10.489,0.676,12.384-4.739,1.527-4.36-0.076-6.875-3.226-8.515,2.294-0.529,4.022-2.038,4.483-5.155zm-8.022,11.249c-1.085,4.36-8.426,2.003-10.806,1.412l1.928-7.729c2.38,0.594,10.012,1.77,8.878,6.317zm1.086-11.312c-0.99,3.966-7.1,1.951-9.082,1.457l1.748-7.01c1.982,0.494,8.365,1.416,7.334,5.553z"/></g></svg>'
    ==
  ;span(title "{tooltip}", style "cursor: default;")
    ;+  badge
  ==
::
++  mempool-base-url
  |=  network=?(%main %testnet %regtest)
  ^-  tape
  ?-  network
    %main     "https://mempool.space/api/address/"
    %testnet  "https://mempool.space/testnet4/api/address/"
    %regtest  "http://localhost:3000/address/"
  ==
::
++  fetch-address-info
  |=  [address=@t network=?(%main %testnet %regtest)]
  =/  m  (fiber:fiber:nexus ,(unit address-info))
  ^-  form:m
  =/  url=@t
    (crip (weld (mempool-base-url network) (trip address)))
  =/  =request:http
    [%'GET' url ~[['Accept' 'application/json']] ~]
  ;<  ~  bind:m  (send-request:io request)
  ;<  =client-response:iris  bind:m  take-client-response:io
  (parse-address-response client-response)
::
::  SSE manager state tracking
::
+$  sse-prev
  $:  scan=?(%active %paused %none)
      progress=(unit scan-progress)
      refreshing=(set [?(%recv %chng) @ud])
      n-recv=@ud
      n-chng=@ud
      recv-hashes=(map @ud @)
      chng-hashes=(map @ud @)
  ==
::
++  make-sse-prev
  |=  [acct=account-data pst=[scan=?(%active %paused %none) progress=(unit scan-progress) refreshing=(set [?(%recv %chng) @ud])]]
  ^-  sse-prev
  :*  scan.pst
      progress.pst
      refreshing.pst
      (lent receiving.acct)
      (lent change.acct)
      (hash-entries receiving.acct)
      (hash-entries change.acct)
  ==
::
++  hash-entries
  |=  addrs=(list address-entry)
  ^-  (map @ud @)
  =/  idx=@ud  0
  =/  hashes=(map @ud @)  ~
  |-
  ?~  addrs  hashes
  $(addrs t.addrs, idx +(idx), hashes (~(put by hashes) idx (mug i.addrs)))
::  write or create an SSE file
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
::  create initial SSE files
::
++  sse-init
  |=  [acct=account-data now=@da pst=[scan=?(%active %paused %none) progress=(unit scan-progress) refreshing=(set [?(%recv %chng) @ud])]]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  ~  bind:m
    (sse-write (cord-to-road:tarball './sse/scan-status.html') [[/ %manx] !>((scan-status-ui scan.pst progress.pst))])
  ;<  ~  bind:m
    (sse-init-chain receiving.acct now %recv "receiving" refreshing.pst)
  ;<  ~  bind:m
    (sse-init-chain change.acct now %chng "change" refreshing.pst)
  (pure:m ~)
::
++  sse-init-chain
  |=  [addrs=(list address-entry) now=@da chain-tag=?(%recv %chng) chain=tape refreshing=(set [?(%recv %chng) @ud])]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  n=@ud  (lent addrs)
  =/  idx=@ud  0
  |-
  ?:  =(idx n)  (pure:m ~)
  =/  entry=address-entry  (snag idx addrs)
  =/  is-loading=?  (~(has in refreshing) [chain-tag idx])
  =/  row=manx  (address-row idx entry now chain chain-tag is-loading)
  =/  road=road:tarball
    (cord-to-road:tarball (crip "./sse/addr-{(trip chain-tag)}-{(scow %ud idx)}.html"))
  ;<  ~  bind:m  (sse-write road [[/ %manx] !>(row)])
  $(idx +(idx))
::
::  diff previous vs current state, write only changed fragments
::
++  sse-diff
  |=  [acct=account-data now=@da prev=sse-prev curr=sse-prev]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ::  scan status or progress changed?
  ;<  ~  bind:m
    ?:  &(=(scan.prev scan.curr) =(progress.prev progress.curr))
      (pure:m ~)
    (over:io (cord-to-road:tarball './sse/scan-status.html') [[/ %manx] !>((scan-status-ui scan.curr progress.curr))])
  ::  diff address rows
  ;<  ~  bind:m
    (sse-diff-chain receiving.acct now %recv "receiving" refreshing.curr prev curr)
  ;<  ~  bind:m
    (sse-diff-chain change.acct now %chng "change" refreshing.curr prev curr)
  (pure:m ~)
::
++  sse-diff-chain
  |=  $:  addrs=(list address-entry)
          now=@da
          chain-tag=?(%recv %chng)
          chain=tape
          refreshing=(set [?(%recv %chng) @ud])
          prev=sse-prev
          curr=sse-prev
      ==
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  prev-hashes=(map @ud @)
    ?:(?=(%recv chain-tag) recv-hashes.prev chng-hashes.prev)
  =/  curr-hashes=(map @ud @)
    ?:(?=(%recv chain-tag) recv-hashes.curr chng-hashes.curr)
  =/  prev-n=@ud  ?:(?=(%recv chain-tag) n-recv.prev n-chng.prev)
  =/  curr-n=@ud  ?:(?=(%recv chain-tag) n-recv.curr n-chng.curr)
  =/  idx=@ud  0
  |-
  ?:  =(idx curr-n)  (pure:m ~)
  =/  entry=address-entry  (snag idx addrs)
  =/  is-loading=?  (~(has in refreshing) [chain-tag idx])
  =/  prev-hash=@  (fall (~(get by prev-hashes) idx) 0)
  =/  curr-hash=@  (fall (~(get by curr-hashes) idx) 0)
  =/  prev-loading=?  (~(has in refreshing.prev) [chain-tag idx])
  =/  changed=?  |(!=(prev-hash curr-hash) !=(prev-loading is-loading))
  ?.  changed  $(idx +(idx))
  =/  row=manx  (address-row idx entry now chain chain-tag is-loading)
  =/  road=road:tarball
    (cord-to-road:tarball (crip "./sse/addr-{(trip chain-tag)}-{(scow %ud idx)}.html"))
  ;<  ~  bind:m  (sse-write road [[/ %manx] !>(row)])
  $(idx +(idx))
::
::  scan event: either an HTTP response or a pause/resume poke
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
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error:io dart.u.in)]
      [~ %arvo [%request ~] %iris %http-response %cancel *]
    [%fail leaf+"http-request-cancelled" ~]
      [~ %arvo [%request ~] %iris %http-response %finished *]
    [%done %http client-response.sign.u.in]
      [~ %poke * *]
    =/  res=(unit json)  (mole |.(!<(json q.sage.u.in)))
    ?~  res  [%skip ~]
    ?.  ?=([%o *] u.res)  [%skip ~]
    =/  act=(unit json)  (~(get by p.u.res) 'action')
    ?:  =(`s+'pause' act)   [%done %pause ~]
    ?:  =(`s+'resume' act)  [%done %resume ~]
    [%skip ~]
  ==
::  +scan-fetch: like fetch-address-info but pausable during HTTP wait
::
++  scan-fetch
  |=  [address=@t network=?(%main %testnet %regtest)]
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
      %pause   ;<  ~  bind:m  pause-loop  $
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
  ;<  =bowl:nexus  bind:m  get-bowl:io
  (pure:m `[u.tx-count u.funded u.spent now.bowl])
::
::  +pause-loop: block until resumed, managing marker file
::
++  take-pause-event
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  state
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
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  marker-json=json  (pairs:enjs:format ~[['paused' b+%.y]])
  ;<  ~  bind:m
    (make:io (cord-to-road:tarball '../scan-paused.json') |+[%.n [[/ %json] !>(marker-json)] ~])
  |-
  ;<  resumed=?  bind:m  take-pause-event
  ?.  resumed  $
  ;<  *  bind:m  (cull-soft:io (cord-to-road:tarball '../scan-paused.json'))
  (pure:m ~)
::
++  scan-chain
  |=  [acct=account-data chain=?(%receiving %change) network=?(%main %testnet %regtest) data-road=road:tarball]
  =/  m  (fiber:fiber:nexus ,account-data)
  ^-  form:m
  =/  is-change=?  =(chain %change)
  =/  addrs=(list address-entry)
    ?:(is-change change.acct receiving.acct)
  =/  gap-limit=@ud  20
  ::  refresh all existing addresses first
  =/  idx=@ud  0
  =/  updated-addrs=(list address-entry)  addrs
  |-
  ?:  =(idx (lent addrs))
    ::  done refreshing existing, now scan beyond with gap limit
    =/  scan-idx=@ud  (lent updated-addrs)
    =/  gap=@ud  0
    |-
    ?:  (gte gap gap-limit)
      ::  hit gap limit, done
      =/  result=account-data
        ?:  is-change
          acct(change updated-addrs)
        acct(receiving updated-addrs)
      (pure:m result)
    ::  derive next address
    =/  new-addr=(unit @t)
      %:  derive-addr
        xprv.acct
        script-type.acct
        network
        ?:(is-change 1 0)
        scan-idx
      ==
    ?~  new-addr
      ::  derivation failed, done
      =/  result=account-data
        ?:  is-change
          acct(change updated-addrs)
        acct(receiving updated-addrs)
      (pure:m result)
    ::  update scan progress in proc file
    =/  phase-tape=@t  ?:(is-change 'chng' 'recv')
    =/  scan-prog=json
      %-  pairs:enjs:format
      :~  ['phase' s+phase-tape]
          ['idx' (numb:enjs:format scan-idx)]
          ['gap' (numb:enjs:format gap)]
      ==
    ;<  ~  bind:m  (replace:io !>(scan-prog))
    ;<  new-info=(unit address-info)  bind:m
      (scan-fetch u.new-addr network)
    =/  new-entry=address-entry
      [u.new-addr new-info]
    =.  updated-addrs  (snoc updated-addrs new-entry)
    ::  save progress after each address
    =/  progress=account-data
      ?:  is-change
        acct(change updated-addrs)
      acct(receiving updated-addrs)
    ;<  ~  bind:m
      (over:io data-road [[/wallet %account] !>(progress)])
    ?~  new-info
      $(scan-idx +(scan-idx), gap +(gap))
    ?:  =(0 tx-count.u.new-info)
      $(scan-idx +(scan-idx), gap +(gap))
    $(scan-idx +(scan-idx), gap 0)
  ::  refresh existing address at idx — update progress
  =/  phase-tape=@t  ?:(is-change 'chng' 'recv')
  =/  scan-prog=json
    %-  pairs:enjs:format
    :~  ['phase' s+phase-tape]
        ['idx' (numb:enjs:format idx)]
        ['gap' (numb:enjs:format 0)]
    ==
  ;<  ~  bind:m  (replace:io !>(scan-prog))
  =/  entry=address-entry  (snag idx addrs)
  ;<  new-info=(unit address-info)  bind:m
    (scan-fetch addr.entry network)
  =/  updated-entry=address-entry
    ?~  new-info  entry
    [addr.entry `u.new-info]
  =.  updated-addrs  (snap updated-addrs idx updated-entry)
  ::  save progress
  =/  progress=account-data
    ?:  is-change
      acct(change updated-addrs)
    acct(receiving updated-addrs)
  ;<  ~  bind:m
    (over:io data-road [[/wallet %account] !>(progress)])
  $(idx +(idx))
::
++  compute-total-balance
  |=  acct=account-data
  ^-  @ud
  =/  all=(list address-entry)  (weld receiving.acct change.acct)
  %+  roll  all
  |=  [entry=address-entry total=@ud]
  ?~  info.entry  total
  (add total (sub funded.u.info.entry spent.u.info.entry))
::
++  network-badge
  |=  network=?(%main %testnet %regtest)
  ^-  manx
  ?-  network
      %main
    %-  need  %-  de-xml:html
    '<svg xmlns="http://www.w3.org/2000/svg" height="16" width="16" viewBox="0 0 64 64"><g transform="translate(0.00630876,-0.00301984)"><path fill="#f7931a" d="m63.033,39.744c-4.274,17.143-21.637,27.576-38.782,23.301-17.138-4.274-27.571-21.638-23.295-38.78,4.272-17.145,21.635-27.579,38.775-23.305,17.144,4.274,27.576,21.64,23.302,38.784z"/><path fill="#FFF" d="m46.103,27.444c0.637-4.258-2.605-6.547-7.038-8.074l1.438-5.768-3.511-0.875-1.4,5.616c-0.923-0.23-1.871-0.447-2.813-0.662l1.41-5.653-3.509-0.875-1.439,5.766c-0.764-0.174-1.514-0.346-2.242-0.527l0.004-0.018-4.842-1.209-0.934,3.75s2.605,0.597,2.55,0.634c1.422,0.355,1.679,1.296,1.636,2.042l-1.638,6.571c0.098,0.025,0.225,0.061,0.365,0.117-0.117-0.029-0.242-0.061-0.371-0.092l-2.296,9.205c-0.174,0.432-0.615,1.08-1.609,0.834,0.035,0.051-2.552-0.637-2.552-0.637l-1.743,4.019,4.569,1.139c0.85,0.213,1.683,0.436,2.503,0.646l-1.453,5.834,3.507,0.875,1.439-5.772c0.958,0.26,1.888,0.5,2.798,0.726l-1.434,5.745,3.511,0.875,1.453-5.823c5.987,1.133,10.489,0.676,12.384-4.739,1.527-4.36-0.076-6.875-3.226-8.515,2.294-0.529,4.022-2.038,4.483-5.155zm-8.022,11.249c-1.085,4.36-8.426,2.003-10.806,1.412l1.928-7.729c2.38,0.594,10.012,1.77,8.878,6.317zm1.086-11.312c-0.99,3.966-7.1,1.951-9.082,1.457l1.748-7.01c1.982,0.494,8.365,1.416,7.334,5.553z"/></g></svg>'
  ::
      %testnet
    %-  need  %-  de-xml:html
    '<svg xmlns="http://www.w3.org/2000/svg" height="16" width="16" viewBox="0 0 64 64"><g transform="translate(0.00630876,-0.00301984)"><path fill="#6b8fd8" d="m63.033,39.744c-4.274,17.143-21.637,27.576-38.782,23.301-17.138-4.274-27.571-21.638-23.295-38.78,4.272-17.145,21.635-27.579,38.775-23.305,17.144,4.274,27.576,21.64,23.302,38.784z"/><path fill="#FFF" d="m46.103,27.444c0.637-4.258-2.605-6.547-7.038-8.074l1.438-5.768-3.511-0.875-1.4,5.616c-0.923-0.23-1.871-0.447-2.813-0.662l1.41-5.653-3.509-0.875-1.439,5.766c-0.764-0.174-1.514-0.346-2.242-0.527l0.004-0.018-4.842-1.209-0.934,3.75s2.605,0.597,2.55,0.634c1.422,0.355,1.679,1.296,1.636,2.042l-1.638,6.571c0.098,0.025,0.225,0.061,0.365,0.117-0.117-0.029-0.242-0.061-0.371-0.092l-2.296,9.205c-0.174,0.432-0.615,1.08-1.609,0.834,0.035,0.051-2.552-0.637-2.552-0.637l-1.743,4.019,4.569,1.139c0.85,0.213,1.683,0.436,2.503,0.646l-1.453,5.834,3.507,0.875,1.439-5.772c0.958,0.26,1.888,0.5,2.798,0.726l-1.434,5.745,3.511,0.875,1.453-5.823c5.987,1.133,10.489,0.676,12.384-4.739,1.527-4.36-0.076-6.875-3.226-8.515,2.294-0.529,4.022-2.038,4.483-5.155zm-8.022,11.249c-1.085,4.36-8.426,2.003-10.806,1.412l1.928-7.729c2.38,0.594,10.012,1.77,8.878,6.317zm1.086-11.312c-0.99,3.966-7.1,1.951-9.082,1.457l1.748-7.01c1.982,0.494,8.365,1.416,7.334,5.553z"/></g></svg>'
  ::
      %regtest
    %-  need  %-  de-xml:html
    '<svg xmlns="http://www.w3.org/2000/svg" height="16" width="16" viewBox="0 0 64 64"><circle cx="32" cy="32" r="30" fill="#9ca3af"/></svg>'
  ==
::
++  network-label
  |=  network=?(%main %testnet %regtest)
  ^-  tape
  ?-  network
    %main     "Mainnet"
    %testnet  "Testnet"
    %regtest  "Regtest"
  ==
::
++  address-list-section
  |=  [acct=account-data chain=tape chain-tag=?(%recv %chng) addrs=(list address-entry) now=@da refreshing=(set [?(%recv %chng) @ud])]
  ^-  manx
  =/  next-idx=@ud  (lent addrs)
  ;div.fc.g2(style "flex: 1; min-height: 0;")
    ;div.p3.b2.br2.hover.pointer
      =onclick  "deriveNext('{chain}')"
      =style  "display: flex; align-items: center; justify-content: center; gap: 8px; border: 2px dashed var(--b3);"
      ;div(style "font-size: 24px; color: var(--f-3);"): +
      ;span.f2.bold.f-3: Derive Next Address (Index {(scow %ud next-idx)})
    ==
    ;div.fc.g2(style "flex: 1; min-height: 0; overflow-y: auto;")
      ;*  ?:  =(0 (lent addrs))
            :~  ;div.p4.b1.br2.tc
                  ;div.s0.f2.mb2: No addresses yet
                  ;div.f3.s-1: Click above to derive your first address
                ==
            ==
          %+  turn  (flop (gulf 0 (dec (lent addrs))))
          |=  idx=@ud
          =/  entry=address-entry  (snag idx addrs)
          =/  is-loading=?  (~(has in refreshing) [chain-tag idx])
          (address-row idx entry now chain chain-tag is-loading)
    ==
  ==
::
++  address-row
  |=  [idx=@ud entry=address-entry now=@da chain=tape chain-tag=?(%recv %chng) is-loading=?]
  ^-  manx
  =/  addr-text=tape  (trip addr.entry)
  =/  row-id=tape  "addr-{(trip chain-tag)}-{(scow %ud idx)}"
  =/  has-txs=?
    ?~  info.entry  %.n
    (gth tx-count.u.info.entry 0)
  ::  staleness color for refresh button
  =/  bg-color=tape
    ?~  info.entry
      "rgba(200, 80, 80, 0.2)"
    ?:  (lth now last-check.u.info.entry)  "var(--b2)"
    =/  time-since=@dr  (sub now last-check.u.info.entry)
    ?:  (lth time-since ~h1)   "var(--b2)"
    ?:  (lth time-since ~h6)   "rgba(200, 180, 80, 0.15)"
    ?:  (lth time-since ~d1)   "rgba(220, 140, 80, 0.2)"
    "rgba(200, 80, 80, 0.2)"
  =/  last-check-text=tape
    ?~  info.entry  "Never checked"
    "Last checked: {(scow %da last-check.u.info.entry)}"
  =/  row-classes=tape
    ?:(has-txs "p3 b1 br2 hover" "p3 b1 br2 hover empty-address")
  ;div(id row-id, class row-classes, style "display: flex; justify-content: space-between; align-items: center; gap: 12px;")
    ;div(style "flex: 1; min-width: 0;")
      ;div(style "display: flex; align-items: center; gap: 8px;")
        ;span.f3.s-2.mono: Index {(scow %ud idx)}
        ;+  ?~  info.entry  ;span;
            =/  tx-count=@ud  tx-count.u.info.entry
            =/  balance=@ud
              (sub funded.u.info.entry spent.u.info.entry)
            ;div(style "display: flex; gap: 8px;")
              ;span.f3.s-2(style "opacity: 0.8;")
                ; • {(scow %ud tx-count)} txs
              ==
              ;span.f3.s-2(style "opacity: 0.8;")
                ; • {(scow %ud balance)} sats
              ==
            ==
      ==
      ;div(style "display: flex; align-items: center; gap: 8px;")
        ;button.p1.b0.br1.hover.pointer
          =data-addr  addr-text
          =onclick  "copyAddr(this)"
          =title  "Copy address"
          =style  "background: transparent; border: 1px solid var(--b3); color: var(--f3); display: flex; align-items: center; width: 24px; height: 24px; justify-content: center; outline: none;"
          ;div.copy-icon(style "width: 12px; height: 12px; display: flex; align-items: center; justify-content: center;")
            ;+  (make:fi 'copy')
          ==
          ;div.check-icon(style "width: 12px; height: 12px; display: none; align-items: center; justify-content: center; color: #10b981;")
            ;+  (make:fi 'check')
          ==
        ==
        ;span.mono.f2.s-1(style "white-space: nowrap; overflow: hidden; text-overflow: ellipsis; color: var(--f3);"): {addr-text}
      ==
    ==
    ;div(style "display: flex; gap: 4px;")
      ;+  ?:  is-loading
            ::  loading: spinner + cancel button
            ;div(style "display: flex; gap: 4px;")
              ;div.p2.b1.br1(style "background: rgba(100, 150, 255, 0.2); border: 1px solid var(--b3); color: var(--f3); display: flex; align-items: center; width: 32px; height: 32px; justify-content: center;")
                ;div(style "width: 16px; height: 16px; display: flex; align-items: center; justify-content: center; animation: spin 1s linear infinite;")
                  ;+  (make:fi 'loader')
                ==
              ==
              ;button.p2.b1.br1.hover.pointer
                =title  "Cancel this refresh"
                =onclick  "cancelRefresh('{chain}', '{(scow %ud idx)}')"
                =style  "background: rgba(255, 80, 80, 0.2); border: 1px solid rgba(255, 80, 80, 0.4); color: #ff5050; display: flex; align-items: center; width: 32px; height: 32px; justify-content: center; outline: none;"
                ;div(style "width: 16px; height: 16px; display: flex; align-items: center; justify-content: center;")
                  ;+  (make:fi 'x-circle')
                ==
              ==
            ==
          ::  normal: refresh button
          ;button.p2.b1.br1.hover.pointer
            =title  last-check-text
            =onclick  "refreshAddress('{(scow %ud idx)}')"
            =style  "background: {bg-color}; border: 1px solid var(--b3); color: var(--f3); display: flex; align-items: center; width: 32px; height: 32px; justify-content: center; outline: none;"
            ;div(style "width: 16px; height: 16px; display: flex; align-items: center; justify-content: center;")
              ;+  (make:fi 'refresh-cw')
            ==
          ==
    ==
  ==
::
++  scan-status-ui
  |=  [scan=?(%active %paused %none) progress=(unit scan-progress)]
  ^-  manx
  ?-    scan
      %active
    =/  border-color=tape  "rgba(100, 150, 255, 0.4)"
    =/  bg-color=tape  "rgba(100, 150, 255, 0.1)"
    ;div#scan-status.p3.b2.br2(style "display: flex; align-items: center; justify-content: space-between; gap: 12px; border: 2px solid {border-color}; background: {bg-color};")
      ;div(style "display: flex; align-items: center; gap: 12px; flex: 1;")
        ;div(style "width: 20px; height: 20px; display: flex; align-items: center; justify-content: center; animation: spin 1s linear infinite;")
          ;+  (make:fi 'loader')
        ==
        ;div(style "display: flex; flex-direction: column; gap: 4px;")
          ;+  ?~  progress
                ;span.f2.bold: Scanning...
              ;span.f2.bold: {?:(=('recv' phase.u.progress) "Receiving" "Change")}
          ;+  ?~  progress
                ;span;
              ;span.f3.s-1: Index: {(scow %ud idx.u.progress)} • Gap: {(scow %ud gap.u.progress)}/20
        ==
      ==
      ;div(style "display: flex; gap: 4px;")
        ;button.p2.b1.br1.hover.pointer
          =title  "Pause full scan"
          =onclick  "pauseScan()"
          =style  "background: rgba(255, 180, 50, 0.2); border: 1px solid rgba(255, 180, 50, 0.4); color: #ffb432; display: flex; align-items: center; width: 32px; height: 32px; justify-content: center; outline: none;"
          ;div(style "width: 16px; height: 16px; display: flex; align-items: center; justify-content: center;")
            ;+  (make:fi 'pause')
          ==
        ==
        ;button.p2.b1.br1.hover.pointer
          =title  "Cancel full scan"
          =onclick  "cancelScan()"
          =style  "background: rgba(255, 80, 80, 0.2); border: 1px solid rgba(255, 80, 80, 0.4); color: #ff5050; display: flex; align-items: center; width: 32px; height: 32px; justify-content: center; outline: none;"
          ;div(style "width: 16px; height: 16px; display: flex; align-items: center; justify-content: center;")
            ;+  (make:fi 'x-circle')
          ==
        ==
      ==
    ==
  ::
      %paused
    =/  border-color=tape  "rgba(150, 150, 150, 0.4)"
    =/  bg-color=tape  "rgba(150, 150, 150, 0.1)"
    ;div#scan-status.p3.b2.br2(style "display: flex; align-items: center; justify-content: space-between; gap: 12px; border: 2px solid {border-color}; background: {bg-color};")
      ;div(style "display: flex; align-items: center; gap: 12px; flex: 1;")
        ;div(style "width: 20px; height: 20px; display: flex; align-items: center; justify-content: center;")
          ;+  (make:fi 'pause-circle')
        ==
        ;div(style "display: flex; flex-direction: column; gap: 4px;")
          ;+  ?~  progress
                ;span.f2.bold: Scan Paused
              ;span.f2.bold: Paused — {?:(=('recv' phase.u.progress) "Receiving" "Change")}
          ;+  ?~  progress
                ;span;
              ;span.f3.s-1: Index: {(scow %ud idx.u.progress)} • Gap: {(scow %ud gap.u.progress)}/20
        ==
      ==
      ;div(style "display: flex; gap: 4px;")
        ;button.p2.b1.br1.hover.pointer
          =title  "Resume full scan"
          =onclick  "resumeScan()"
          =style  "background: rgba(50, 200, 100, 0.2); border: 1px solid rgba(50, 200, 100, 0.4); color: #32c864; display: flex; align-items: center; width: 32px; height: 32px; justify-content: center; outline: none;"
          ;div(style "width: 16px; height: 16px; display: flex; align-items: center; justify-content: center;")
            ;+  (make:fi 'play')
          ==
        ==
        ;button.p2.b1.br1.hover.pointer
          =title  "Cancel full scan"
          =onclick  "cancelScan()"
          =style  "background: rgba(255, 80, 80, 0.2); border: 1px solid rgba(255, 80, 80, 0.4); color: #ff5050; display: flex; align-items: center; width: 32px; height: 32px; justify-content: center; outline: none;"
          ;div(style "width: 16px; height: 16px; display: flex; align-items: center; justify-content: center;")
            ;+  (make:fi 'x-circle')
          ==
        ==
      ==
    ==
  ::
      %none
    ;div#scan-status.p3.b2.br2.hover.pointer
      =onclick  "fullScan()"
      =style  "display: flex; align-items: center; justify-content: center; gap: 8px; border: 2px solid var(--b3); background: var(--b2);"
      ;div(style "font-size: 24px; color: var(--f-3);"): ↻
      ;span.f2.bold.f-3: Full Scan
    ==
  ==
::
++  addresses-fragment
  |=  [acct=account-data now=@da scan=?(%active %paused %none) progress=(unit scan-progress) refreshing=(set [?(%recv %chng) @ud])]
  ^-  manx
  =/  n-recv=@ud  (lent receiving.acct)
  =/  n-chng=@ud  (lent change.acct)
  ;div.fc.g2
    ;+  (scan-status-ui scan progress)
    ;div(style "display: flex; border-bottom: 1px solid var(--b3);")
      ;button.tab-btn(data-tab "receiving", onclick "showTab('receiving')", style "flex: 1; padding: 8px 16px; background: transparent; border: none; border-bottom: 2px solid var(--f1); color: var(--f1); font-weight: bold; cursor: pointer; outline: none;")
        ; Receiving ({(scow %ud n-recv)})
      ==
      ;button.tab-btn(data-tab "change", onclick "showTab('change')", style "flex: 1; padding: 8px 16px; background: transparent; border: none; border-bottom: 2px solid transparent; color: var(--f3); cursor: pointer; outline: none;")
        ; Change ({(scow %ud n-chng)})
      ==
    ==
    ;div#receiving-addresses
      ;+  (address-list-section acct "receiving" %recv receiving.acct now refreshing)
    ==
    ;div#change-addresses(style "display: none;")
      ;+  (address-list-section acct "change" %chng change.acct now refreshing)
    ==
  ==
::
++  detail-page
  |=  [acct=account-data now=@da scan=?(%active %paused %none) progress=(unit scan-progress) refreshing=(set [?(%recv %chng) @ud])]
  ^-  manx
  =/  total-balance=@ud  (compute-total-balance acct)
  ;html
    ;head
      ;title: {(trip name.acct)}
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;+  feather:feather
      ;style
        ;+  ;/  style-text
      ==
    ==
    ;body
      ;input(type "hidden", id "wallet-fp", value (hexn:http-utils wallet.acct));
      ;div(style "min-width: 650px; height: 100%;")
        ;div#account-page.fc.g3.p5.ma.mw-page(style "height: 100%;")
          ;div(style "flex-shrink: 0; display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;")
            ;a.hover.pointer(id "back-link", href "#", onclick "goBack(); return false;", style "color: var(--f3); text-decoration: none;"): ← Back to Wallet
          ==
          ;div.p4.b1.br2(style "flex-shrink: 0; position: relative;")
            ;button#empty-toggle.hover.pointer
              =onclick  "toggleEmptyAddresses()"
              =title  "Hide addresses without transactions"
              =style  "position: absolute; top: 16px; right: 16px; background: transparent; border: 1px solid var(--b3); color: var(--f3); display: flex; align-items: center; justify-content: center; width: 32px; height: 32px; border-radius: 4px; cursor: pointer; outline: none;"
              ;div#eye-icon(style "width: 16px; height: 16px; display: flex; align-items: center; justify-content: center;")
                ;+  (make:fi 'eye')
              ==
            ==
            ;h1.s2.bold.mb2: {(trip name.acct)}
            ;div(style "display: flex; gap: 8px; align-items: center; flex-wrap: wrap;")
              ;+  (purpose-badge purpose.acct)
              ;code.mono.s-2.p1.b2.br1: {(format-account-path purpose.acct coin-type.acct account-idx.acct)}
              ;+  (coin-type-badge coin-type.acct)
            ==
            ;div(style "display: flex; align-items: center; gap: 8px; margin-top: 12px;")
              ;div.p2.br1(style "display: flex; align-items: center; gap: 8px; background: var(--b2);")
                ;div.p2.b1.br2(style "display: flex; align-items: center; gap: 6px;")
                  ;+  (network-badge network.acct)
                  ;span.f2.s-1: {(network-label network.acct)}
                ==
              ==
            ==
          ==
          ;div.p4.b2.br2(style "flex-shrink: 0;")
            ;h2.s1.bold.mb2: Account Summary
            ;div#account-summary(style "display: flex; justify-content: space-between; align-items: baseline;")
              ;span.f2(style "opacity: 0.8;"): Total Balance
              ;span.s0.bold.mono: {(scow %ud total-balance)} sats
            ==
          ==
          ;div#live-content.fc.g3(style "flex: 1; min-height: 0; overflow-y: auto;")
            ;+  (addresses-fragment acct now scan progress refreshing)
          ==
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
  #account-page.hide-empty .empty-address \{
    display: none !important;
  }
  """
::
++  script-text
  ^-  tape
  """
  var path = window.location.pathname;
  var m = path.match(/^(\\/\\w+)\\/(?:api\\/file|ball)\\/(.*?)\\/page\\.html/);
  var API = m ? m[1] + '/api' : '/grubbery/api';
  var acctBase = m ? m[2] : '';
  var activeTab = 'receiving';

  function goBack() \{
    var walletFp = document.getElementById('wallet-fp').value;
    var parts = path.split('/');
    var base = parts.slice(0, parts.indexOf('wallet.wallet_app') + 1).join('/');
    window.location.href = base + '/wallets/' + walletFp + '.wallet_wallet/page.html';
  }

  function deriveNext(chain) \{
    var url = API + '/poke/' + acctBase + '/main.sig?mark=json';
    fetch(url, \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(\{action: 'derive-next', chain: chain})
    }).then(function(r) \{
      if (!r.ok) return r.text().then(function(t) \{ console.error('derive-next error', t) });
    }).catch(function(e) \{ console.error('derive-next failed', e) });
  }

  function refreshAddress(index) \{
    var url = API + '/poke/' + acctBase + '/main.sig?mark=json';
    fetch(url, \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(\{action: 'refresh-address', chain: activeTab, index: index})
    }).catch(function(e) \{ console.error('refresh failed', e) });
  }

  function fullScan() \{
    var url = API + '/poke/' + acctBase + '/main.sig?mark=json';
    fetch(url, \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(\{action: 'full-scan'})
    }).catch(function(e) \{ console.error('scan failed', e) });
  }

  function pauseScan() \{
    var url = API + '/poke/' + acctBase + '/main.sig?mark=json';
    fetch(url, \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(\{action: 'pause-scan'})
    }).catch(function(e) \{ console.error('pause-scan failed', e) });
  }

  function resumeScan() \{
    var url = API + '/poke/' + acctBase + '/main.sig?mark=json';
    fetch(url, \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(\{action: 'resume-scan'})
    }).catch(function(e) \{ console.error('resume-scan failed', e) });
  }

  function cancelScan() \{
    var url = API + '/poke/' + acctBase + '/main.sig?mark=json';
    fetch(url, \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(\{action: 'cancel-scan'})
    }).catch(function(e) \{ console.error('cancel-scan failed', e) });
  }

  function cancelRefresh(chain, index) \{
    var url = API + '/poke/' + acctBase + '/main.sig?mark=json';
    fetch(url, \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(\{action: 'cancel-refresh', chain: chain, index: index})
    }).catch(function(e) \{ console.error('cancel-refresh failed', e) });
  }

  function toggleEmptyAddresses() \{
    var page = document.getElementById('account-page');
    var button = document.getElementById('empty-toggle');
    var iconContainer = document.getElementById('eye-icon');
    var isHiding = page.classList.contains('hide-empty');
    if (isHiding) \{
      page.classList.remove('hide-empty');
      button.setAttribute('title', 'Hide addresses without transactions');
      iconContainer.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path><circle cx="12" cy="12" r="3"></circle></svg>';
    } else \{
      page.classList.add('hide-empty');
      button.setAttribute('title', 'Show addresses without transactions');
      iconContainer.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"></path><line x1="1" y1="1" x2="23" y2="23"></line></svg>';
    }
  }

  function copyAddr(btn) \{
    navigator.clipboard.writeText(btn.dataset.addr);
    var ci = btn.querySelector('.copy-icon');
    var ki = btn.querySelector('.check-icon');
    if (ci) ci.style.display = 'none';
    if (ki) ki.style.display = 'flex';
    setTimeout(function() \{
      if (ci) ci.style.display = 'flex';
      if (ki) ki.style.display = 'none';
    }, 1500);
  }

  function showTab(tab) \{
    activeTab = tab;
    applyTab();
  }

  function applyTab() \{
    var r = document.getElementById('receiving-addresses');
    var c = document.getElementById('change-addresses');
    if (r) r.style.display = activeTab === 'receiving' ? '' : 'none';
    if (c) c.style.display = activeTab === 'change' ? '' : 'none';
    document.querySelectorAll('.tab-btn').forEach(function(btn) \{
      var active = btn.dataset.tab === activeTab;
      btn.style.borderBottomColor = active ? 'var(--f1)' : 'transparent';
      btn.style.color = active ? 'var(--f1)' : 'var(--f3)';
      btn.style.fontWeight = active ? 'bold' : 'normal';
    });
  }

  var SSE = API + '/keep/' + acctBase + '/ui/sse?mark=txt';
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
          var name = ev.slice(sp + 2);
          console.log('[SSE]', act, name, data.length + ' lines');
          if ((act === 'upd' || act === 'old') && data.length) \{
            var tmp = document.createElement('div');
            tmp.innerHTML = data.join('\\n');
            var el = tmp.firstElementChild;
            if (el && el.id) \{
              var existing = document.getElementById(el.id);
              if (existing) \{
                existing.replaceWith(el);
              } else if (act === 'old') \{
                var container = null;
                if (el.id.indexOf('addr-recv-') === 0) container = document.getElementById('receiving-addresses');
                else if (el.id.indexOf('addr-chng-') === 0) container = document.getElementById('change-addresses');
                if (container) container.appendChild(el);
              }
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
