::  groundwire nexus: poll bitcoind RPC for block height, live web UI.
::  Uses the default /api/* surface — no custom HTTP binding.
::
/<  btc       /lib/sur/bitcoin.hoon
/<  urb       /lib/sur/urb.hoon
/<  btc-tx    /lib/btc-tx.hoon
/<  btc-rpc   /lib/btc-rpc.hoon
/<  urb-core  /lib/urb-core.hoon
/<  gw        /lib/groundwire.hoon
/<  unv       /lib/unv.hoon
/<  b173      /lib/bip/b173.hoon
/<  bip32     /lib/bip32.hoon
=,  btc
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  =ver:loader  (get-ver:loader ball)
      ?+  ver  !!
          ?(~ [~ %0])
        %+  spin:loader  ball
        :~  (ver-row:loader 0)
            [%fall %& [/ %'config.json'] [[/ %json] default-config]]
            [%fall %& [/ %'height.ud'] [[/ %ud] 0]]
            [%fall %& [/ %'urb-state.urb-state'] [[/ %urb-state] *state:urb]]
            [%fall %& [/ %'latest.json'] [[/ %json] (pairs:enjs:format ~)]]
            [%fall %& [/ %'udiffs.urb-udiffs'] [[/ %urb-udiffs] *udiffs:point:jael]]
            [%fall %| /events empty-dir:loader]
            [%fall %& [/events %'main.urb-event'] [[/ %urb-event] ~]]
            [%fall %| /events/ships empty-dir:loader]
            [%fall %& [/ %'trace.txt'] [[/ %txt] *wain]]
            [%fall %| /wallets empty-dir:loader]
            [%fall %| /points empty-dir:loader]
            [%over %& [/ %'rpc.sig'] [[/ %sig] ~]]
            [%over %& [/ %'reg-tester.sig'] [[/ %sig] ~]]
            [%fall %| /ui/sse empty-dir:loader]
            [%over %& [/ui/sse %'stats.html'] [[/ %html] (crip (en-xml:html ;div;))]]
            [%over %& [/ %'page.html'] [[/ %html] (crip (en-xml:html (btc-page "" ;div; ~ ~)))]]
        ==
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::  /height.ud: poll bitcoind every 2s, replace with latest block count
          ::
          [~ %'height.ud']
        ;<  ~  bind:m  (rise-wait:io prod "%groundwire /height: process failed")
        ::  Register as jael PKI source on startup
        ;<  our=@p  bind:m  get-our:io
        ;<  self=rail:tarball  bind:m  get-here-abs:io
        ;<  ~  bind:m
          %-  send-cards:io
          =/  src=rail:tarball  [path.self %'udiffs.urb-udiffs']
          [%pass /jael-src %agent [our dap:io] %poke %set-jael-source !>(src)]~
        ::
        ;<  cfg-seen=seen:nexus  bind:m
          (peek:io [%| 1 %& / %'config.json'] `[/ %json])
        =/  [url=@t auth=@t]  (read-config cfg-seen)
        |-
        =/  req=request:http
          (rpc-request:btc-rpc url auth 'getblockcount' '[]')
        ;<  ~  bind:m  (send-request:io req)
        ;<  =client-response:iris  bind:m  take-client-response:io
        ?.  ?=(%finished -.client-response)
          ;<  ~  bind:m  (sleep:io ~s2)
          $
        ?~  full-file.client-response
          ;<  ~  bind:m  (sleep:io ~s2)
          $
        =/  body=@t  q.data.u.full-file.client-response
        =/  jon=(unit json)  (de:json:html body)
        ?~  jon
          ;<  ~  bind:m  (sleep:io ~s2)
          $
        =/  h=(unit @ud)  (parse-height:btc-rpc u.jon)
        ?~  h
          ;<  ~  bind:m  (sleep:io ~s2)
          $
        ;<  ~  bind:m  (replace:io !>(u.h))
        ;<  ~  bind:m  (sleep:io ~s2)
        $
          ::  /urb-state.urb-state: block walker + PKI state machine.
          ::  Watches /height.ud for tip updates, fetches and processes
          ::  blocks through urb-core, and replace:io's its own state.
          ::  The cursor is num.block-id inside the state — no separate
          ::  processed.ud file needed. anything can keep:io this
          ::  file for live PKI updates.
          ::
          [~ %'urb-state.urb-state']
        ;<  ~  bind:m  (rise-wait:io prod "%groundwire /urb-state: failed")
        ;<  cfg-seen=seen:nexus  bind:m
          (peek:io (cord-to-road:tarball './config.json') `[/ %json])
        =/  [url=@t auth=@t]  (read-config cfg-seen)
        ;<  urb-state=state:urb  bind:m  (get-state-as:io ,state:urb)
        =/  processed=@ud  num.block-id.urb-state
        =/  height-road=road:tarball  (cord-to-road:tarball './height.ud')
        ;<  *  bind:m  (keep:io /t height-road ~)
        ;<  init-seen=seen:nexus  bind:m  (peek:io height-road ~)
        =/  tip=@ud
          ?.  ?=([%& %file *] init-seen)  0
          =/  res=(each @ud tang)  (mule |.(!<(@ud (need-vase:tarball sang.p.init-seen))))
          ?:(?=(%& -.res) p.res 0)
        |-
        ::  chain reset detection: if tip < processed, the chain was
        ::  blown away (e.g. regtest restart). reset our own state and
        ::  reprocess from 0. safe because we own this file.
        ?:  &((gth processed 0) (lth tip processed))
          ~&  >  [%groundwire-walker %chain-reset tip=tip processed=processed]
          =.  urb-state  *state:urb
          =.  processed  0
          ;<  ~  bind:m  (replace:io !>(urb-state))
          $
        ::  caught up — wait for the tip poller to advance
        ?:  (lte tip processed)
          ;<  *  bind:m  (take-news:io /t)
          ;<  upd-seen=seen:nexus  bind:m  (peek:io height-road ~)
          ?.  ?=([%& %file *] upd-seen)  $
          =/  new-tip=@ud  !<(@ud (need-vase:tarball sang.p.upd-seen))
          $(tip new-tip)
        ::  fetch the hash of the next block
        =/  next=@ud  +(processed)
        =/  params=@t  (en:json:html [%a ~[(numb:enjs:format next)]])
        =/  req=request:http
          (rpc-request:btc-rpc url auth 'getblockhash' params)
        ;<  ~  bind:m  (send-request:io req)
        ;<  =client-response:iris  bind:m  take-client-response:io
        ?.  ?=(%finished -.client-response)
          ~&  >  [%groundwire-walker %no-response next]
          ;<  ~  bind:m  (sleep:io ~s2)
          $
        ?~  full-file.client-response
          ~&  >  [%groundwire-walker %empty-response next]
          ;<  ~  bind:m  (sleep:io ~s2)
          $
        =/  body=@t  q.data.u.full-file.client-response
        =/  jon=(unit json)  (de:json:html body)
        ?~  jon
          ~&  >  [%groundwire-walker %bad-json next]
          ;<  ~  bind:m  (sleep:io ~s2)
          $
        =/  hash=(unit @t)  (parse-string-result:btc-rpc u.jon)
        ?~  hash
          ::  "Block height out of range" means the chain was reset
          ::  (e.g. regtest blown away). reset our state and restart.
          ?:  ?=(^ (find "out of range" (trip body)))
            ~&  >  [%groundwire-walker %chain-reset-detected next]
            =.  urb-state  *state:urb
            =.  processed  0
            ;<  ~  bind:m  (replace:io !>(urb-state))
            =/  height-road=road:tarball
              (cord-to-road:tarball './height.ud')
            ;<  ~  bind:m  (over:io height-road [[/ %ud] `@ud`0])
            =.  tip  0
            $
          ~&  >  [%groundwire-walker %no-hash next body]
          ;<  ~  bind:m  (sleep:io ~s2)
          $
        ::  fetch the full block contents via getblock <hash> 2
        =/  blk-params=@t
          (rap 3 ~['["' u.hash '",2]'])
        =/  blk-req=request:http
          (rpc-request:btc-rpc url auth 'getblock' blk-params)
        ;<  ~  bind:m  (send-request:io blk-req)
        ;<  blk-resp=client-response:iris  bind:m  take-client-response:io
        ?.  ?=(%finished -.blk-resp)
          ~&  >  [%groundwire-walker %no-block-response next]
          ;<  ~  bind:m  (sleep:io ~s2)
          $
        ?~  full-file.blk-resp
          ~&  >  [%groundwire-walker %empty-block-response next]
          ;<  ~  bind:m  (sleep:io ~s2)
          $
        =/  blk-body=@t  q.data.u.full-file.blk-resp
        =/  blk-jon=(unit json)  (de:json:html blk-body)
        ?~  blk-jon
          ~&  >  [%groundwire-walker %bad-block-json next]
          ;<  ~  bind:m  (sleep:io ~s2)
          $
        =/  mblk=(unit block:btc)  (parse-block:btc-rpc u.blk-jon)
        ?~  mblk
          ~&  >  [%groundwire-walker %bad-block next]
          ;<  ~  bind:m  (sleep:io ~s2)
          $
        =/  blk  u.mblk
        ~&  >  :*  %groundwire-walker
                   %block
                   height.blk
                   hax.blk
                   reward=reward.blk
                   txs=(lent txs.blk)
               ==
        ::  run the block through urb-core pipeline
        ::
        =/  revs-and-block
          (find-block-reveals:(abed:urb-core:urb-core urb-state) blk)
        =/  init-reveals  -.revs-and-block
        =/  filtered-block=block:btc  +.revs-and-block
        ;<    reveals-and-block=[reveals=(map [txid:ord:urb vout:ord:urb] [sots=(list raw-sotx:urb) value=(unit @ud)]) blk=block:btc]
            bind:m
          (enrich-reveals url auth init-reveals filtered-block)
        =/  reveals    reveals.reveals-and-block
        =/  enriched=block:btc  blk.reveals-and-block
        ;<  ~  bind:m  (append-trace blk ~(wyt by reveals))
        =/  ublk=urb-block:urb
          %-  apply-prevouts-and-urbify:(abed:urb-core:urb-core urb-state)
          [enriched reveals]
        ;<    precommits=(map [txid:ord:urb vout:ord:urb] [commit=urb-tx:urb precommit=urb-tx:urb])
            bind:m
          (find-precommits url auth ublk)
        =/  [fx=(list [id:block:btc effect:urb]) new-urb-state=state:urb]
          =<  abet
          (handle-block:(abed:urb-core:urb-core urb-state) ublk precommits)
        =.  hax.block-id.new-urb-state  hax.blk
        ~&  >  [%groundwire-walker %urb-state num.block-id.new-urb-state fx=(lent fx)]
        ::  write per-ship point files for any effects that touched points
        ::
        ;<  ~  bind:m  (write-point-effects fx new-urb-state)
        ::  publish each observed sotx as a urb-event
        ::
        ;<  ~  bind:m  (emit-events ublk)
        ::  publish udiffs for subscribers
        ::
        =/  uds=udiffs:point:jael  (fx-to-udiffs fx)
        =/  udiffs-road=road:tarball  (cord-to-road:tarball './udiffs.urb-udiffs')
        ;<  ~  bind:m
          ?~  uds  (pure:m ~)
          (over:io udiffs-road [[/ %urb-udiffs] uds])
        ::  publish latest block summary
        ::
        =/  latest-road=road:tarball  (cord-to-road:tarball './latest.json')
        =/  latest-jon=json
          %-  pairs:enjs:format
          :~  ['height' (numb:enjs:format height.blk)]
              ['hash' s+(en:base16:mimes:html 32^hax.blk)]
              ['reward' (numb:enjs:format reward.blk)]
              ['txs' (numb:enjs:format (lent txs.blk))]
          ==
        ;<  ~  bind:m  (over:io latest-road [[/ %json] latest-jon])
        ::  update our own state — this is the cursor AND the PKI
        ::
        =.  urb-state  new-urb-state
        =.  processed  next
        ;<  ~  bind:m  (replace:io !>(urb-state))
        $
          ::  /rpc.sig: poke receiver for RPC proxy actions.
          ::  Action "mine" does getnewaddress → generatetoaddress 1.
          ::
          [~ %'rpc.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%groundwire /rpc: failed")
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        ?+    name.p.sage
            ~&  >  [%groundwire-main %unknown-mark name.p.sage]
            $
            %json
          =/  jon=json  !<(json q.sage)
          ?.  ?=([%o *] jon)  $
          $
        ==
          ::  /reg-tester.sig: poke receiver for sotx test batches.
          ::  Takes a noun poke or JSON. For noun:
          ::    [sed=@uw init-utxo=(unit utxo:unv) many=many:skim-sotx:urb]
          ::  For JSON: {"action":"spawn","sed":N} or
          ::    {"action":"keys","ship":"~sampel"} (seed looked up from /seeds/).
          ::  Walks through each single sotx, dispatching to the right
          ::  commit/reveal/mine/broadcast chain.
          ::
          [~ %'reg-tester.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%groundwire /reg-tester: failed")
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        =/  margs=(unit [sed=@uw acting=(unit @p) init-utxo=(unit utxo:unv) many=many:skim-sotx:urb])
          ?+  name.p.sage
            ~&  >>>  [%reg-tester %unknown-mark name.p.sage]
            ~
              %noun
            =/  raw  !<([sed=@uw init-utxo=(unit utxo:unv) many=many:skim-sotx:urb] q.sage)
            `[sed.raw ~ init-utxo.raw many.raw]
              %json
            (parse-reg-tester-json !<(json q.sage))
          ==
        ?~  margs  $
        =/  args  u.margs
        ::  resolve acting ship -> sed + utxo by peeking wallet file
        ;<  [resolved-sed=@uw resolved-twk=@ resolved-utxo=(unit utxo:unv)]  bind:m
          =/  m  (fiber:fiber:nexus ,[@uw @ (unit utxo:unv)])
          ^-  form:m
          ?~  acting.args  (pure:m [sed.args 0 init-utxo.args])
          =/  wal-road=road:tarball
            (cord-to-road:tarball (cat 3 './wallets/' (cat 3 (scot %p u.acting.args) '.urb-wallet')))
          ;<  wal-seen=seen:nexus  bind:m  (peek:io wal-road ~)
          ?.  ?=([%& %file *] wal-seen)
            ~&  >>>  [%reg-tester %no-wallet-for-ship u.acting.args]  !!
          =/  w  !<([seed=$%([%t =@t] [%uw =@uw] [%ux =@ux]) twk=@ utxo=(unit utxo:unv)] (need-vase:tarball sang.p.wal-seen))
          =/  sd=@uw  ?-(-.seed.w %uw uw.seed.w, %ux `@uw`ux.seed.w, %t `@uw`(need (rush t.seed.w dem)))
          (pure:m [sd twk.w utxo.w])
        =.  sed.args  resolved-sed
        ;<  cfg-seen=seen:nexus  bind:m
          (peek:io [%| 1 %& / %'config.json'] `[/ %json])
        =/  [url=@t auth=@t]  (read-config cfg-seen)
        =/  batch=(list single:skim-sotx:urb)
          ?:  ?=([%batch *] many.args)  bat.many.args
          ~[many.args]
        ~&  >  [%reg-tester %got-poke sed=resolved-sed acting=acting.args steps=(lent batch)]
        =|  cur-utxo=(unit utxo:unv)
        =.  cur-utxo  resolved-utxo
        |-  ^-  form:m
        ?~  batch
          ~&  >  [%reg-tester %batch-done cur-utxo]
          ::  save updated wallet utxo for attest actions
          ;<  ~  bind:m
            ?~  acting.args  (pure:m ~)
            ?~  cur-utxo     (pure:m ~)
            =/  wal-road=road:tarball
              (cord-to-road:tarball (cat 3 './wallets/' (cat 3 (scot %p u.acting.args) '.urb-wallet')))
            =/  wal-bask=bask:tarball  [[/ %urb-wallet] [[%uw sed.args] resolved-twk cur-utxo]]
            (over:io wal-road wal-bask)
          ^$
        =*  sot  i.batch
        ~&  >  [%reg-tester %dispatch -.sot]
        ::  derive wallet keypair from the seed, then the taproot
        ::  address we mine rewards to / confirm reveals against.
        ::
        =+  ^=  [kp i]
            %*(derive wallet:unv sed sed.args)
        =/  tw=keypair:gw
          ~(tweak-keypair p2tr:gw `x.pub.kp ~ `priv.kp)
        =/  address=@t
          (need (encode-taproot:b173 %regtest 32^x.pub.tw))
        ?-    -.sot
            %spawn
          ::  spawn flow — matching gw-onboard.py's 2-tx chain:
          ::    commit (key-path spend of funding) →
          ::    reveal (script-path spend exposing urb envelope)
          ::
          ::  key0 (i=0): funding — mine to this, sign commit
          ::  key1 (i=1): commit internal key — tapscript key, sign reveal
          ::  key2 (i=2): reveal destination
          ::
          =/  hd  (from-seed:bip32 32^sed.args)
          =/  key0=keypair:gw  [pub prv]:(derive-sequence:hd ~[0 0 0])
          =/  key1=keypair:gw  [pub prv]:(derive-sequence:hd ~[1 0 0])
          =/  key2=keypair:gw  [pub prv]:(derive-sequence:hd ~[2 0 0])
          =/  addr0=@t
            %-  need
            (encode-taproot:b173 %regtest 32^x.q:~(tweak-pubkey p2tr:gw `x.pub.key0 ~ ~))
          ::
          ::  mine 1 block to key0's address
          =/  gen1-params=@t  (rap 3 ~['[1,"' addr0 '"]'])
          =/  gen1-req=request:http
            (rpc-request:btc-rpc url auth 'generatetoaddress' gen1-params)
          ;<  ~  bind:m  (send-request:io gen1-req)
          ;<  gen1-resp=client-response:iris  bind:m  take-client-response:io
          ?.  ?=(%finished -.gen1-resp)
            ~&  >>>  [%reg-tester %spawn-mine1-fail]  !!
          ?~  full-file.gen1-resp
            ~&  >>>  [%reg-tester %spawn-mine1-empty]  !!
          =/  gen1-body=@t  q.data.u.full-file.gen1-resp
          =/  gen1-jon=(unit json)  (de:json:html gen1-body)
          ?~  gen1-jon
            ~&  >>>  [%reg-tester %spawn-mine1-bad-json]  !!
          =/  hashes=(unit (list @ux))  (parse-hash-list:btc-rpc u.gen1-jon)
          ?.  ?=([~ ^] hashes)
            ~&  >>>  [%reg-tester %spawn-mine1-no-hashes]  !!
          =/  block-hash=@ux  i.u.hashes
          ::
          ::  mine 100 for coinbase maturity
          ;<  ~  bind:m  (mine-n url auth addr0 100)
          ::
          ::  fetch funding block, parse coinbase output
          =/  blk-params=@t
            (rap 3 ~['["' (render-hex-octs:btc-rpc 32^block-hash) '",2]'])
          =/  blk-req=request:http
            (rpc-request:btc-rpc url auth 'getblock' blk-params)
          ;<  ~  bind:m  (send-request:io blk-req)
          ;<  blk-resp=client-response:iris  bind:m  take-client-response:io
          ?.  ?=(%finished -.blk-resp)
            ~&  >>>  [%reg-tester %spawn-getblock-fail]  !!
          ?~  full-file.blk-resp
            ~&  >>>  [%reg-tester %spawn-getblock-empty]  !!
          =/  blk-body=@t  q.data.u.full-file.blk-resp
          =/  blk-jon=(unit json)  (de:json:html blk-body)
          ?~  blk-jon
            ~&  >>>  [%reg-tester %spawn-getblock-bad-json]  !!
          =/  mblk=(unit block:btc)  (parse-block:btc-rpc u.blk-jon)
          ?~  mblk
            ~&  >>>  [%reg-tester %spawn-parse-failed]  !!
          =/  blk  u.mblk
          ?~  txs.blk
            ~&  >>>  [%reg-tester %spawn-no-txs]  !!
          =/  coinbase  i.txs.blk
          ?~  os.+.coinbase
            ~&  >>>  [%reg-tester %spawn-no-outs]  !!
          =/  cb-out  i.os.+.coinbase
          ~&  >  [%reg-tester %funding-spk wid.script-pubkey.cb-out dat.script-pubkey.cb-out]
          ~&  >  [%reg-tester %funding-value value.cb-out]
          ::
          ::  build walt for ed25519 sotx signing — uses PARSED
          ::  on-chain scriptpubkey so spkh matches what the reader sees
          =/  funding-out=output:gw
            =|  o=output:gw
            o(script-pubkey script-pubkey.cb-out, value value.cb-out, internal-keys key0)
          =/  funding-utxo=utxo:unv
            [`outpoint:gw`[id.coinbase 0] funding-out]
          =/  twk=@
            (rap 3 ~[%9 ~tyr %urb-watcher %btc %gw %9 id.coinbase 0 0])
          =/  wal
            (nu-twk:walt:unv 0 twk (nu:wallet:unv sed.args 3 funding-utxo))
          ::
          ::  build spawn sotx — walt signs with ed25519 identity
          =/  spawn-sot=sotx:urb
            (spawn:unv-tx:wal [*output:gw `0 0 0])
          ~&  >  [%reg-tester %ship fig:wal]
          ::
          ::  build urb envelope script + tapscript spend script
          =/  envelope-script
            (make-unv-script:unv spawn-sot ~)
          =/  spend-scr
            (make-spend-script:unv x.pub.key1 envelope-script)
          ::
          ::  commit output: tapscript(key1, spend-scr)
          =/  commit-spk=octs
            ~(scriptpubkey p2tr:gw `x.pub.key1 `spend-scr ~)
          =/  commit-value=@ud
            (sub value.cb-out 224)
          =/  commit-out=output:gw
            =|  o=output:gw
            %_  o
              script-pubkey  commit-spk
              value          commit-value
              spend-script   `spend-scr
              internal-keys  key1
            ==
          ::
          ::  build commit tx: key-path spend of coinbase → commit output
          =/  cb-prevout=outpoint:gw  [id.coinbase 0]
          =|  commit-tx=tx:gw
          =.  commit-tx
            (~(add-input-1 build:gw commit-tx) [cb-prevout funding-out] ~ ~)
          =.  commit-tx
            (~(add-output-1 build:gw commit-tx) commit-out)
          =/  eny=@  (shas %reg-tester-eny sed.args)
          =^  commit-tx  eny  (~(finalize build:gw commit-tx) eny)
          =/  commit-raw=octs  (txn:encode:gw commit-tx)
          =/  commit-txid=@ux  (txid:encode:gw commit-tx)
          ~&  >  [%reg-tester %commit-txid commit-txid]
          ::
          ::  reveal output: plain P2TR to key2
          =/  reveal-spk=octs
            ~(scriptpubkey p2tr:gw `x.pub.key2 ~ ~)
          =/  reveal-value=@ud
            (sub commit-value 600)
          =/  reveal-out=output:gw
            =|  o=output:gw
            o(script-pubkey reveal-spk, value reveal-value, internal-keys key2)
          ::
          ::  build reveal tx: script-path spend of commit → reveal output
          =/  cm-prevout=outpoint:gw  [commit-txid 0]
          =|  reveal-tx=tx:gw
          =.  reveal-tx
            (~(add-input-1 build:gw reveal-tx) [cm-prevout commit-out] ~ ~)
          =.  reveal-tx
            (~(add-output-1 build:gw reveal-tx) reveal-out)
          =^  reveal-tx  eny  (~(finalize build:gw reveal-tx) eny)
          =/  reveal-raw=octs  (txn:encode:gw reveal-tx)
          =/  reveal-txid=@ux  (txid:encode:gw reveal-tx)
          ~&  >  [%reg-tester %reveal-txid reveal-txid]
          ::
          ::  broadcast commit then reveal, mine 8 confirmations
          ;<  ~  bind:m  (broadcast-raw-tx url auth commit-raw)
          ;<  ~  bind:m  (broadcast-raw-tx url auth reveal-raw)
          ;<  ~  bind:m  (mine-n url auth addr0 8)
          ~&  >  [%reg-tester %spawn-done]
          ::  save wallet (seed + utxo) for this ship
          =/  spawn-ship=@p  fig:wal
          =/  final-utxo=utxo:unv  [`outpoint:gw`[reveal-txid 0] reveal-out]
          =/  wal-road=road:tarball
            (cord-to-road:tarball (cat 3 './wallets/' (cat 3 (scot %p spawn-ship) '.urb-wallet')))
          =/  wal-bask=bask:tarball  [[/ %urb-wallet] [[%uw sed.args] twk `final-utxo]]
          ;<  wal-seen=seen:nexus  bind:m  (peek:io wal-road ~)
          ;<  ~  bind:m
            ?:  ?=([%& %file *] wal-seen)
              (over:io wal-road wal-bask)
            (make:io wal-road [%| wal-bask ~])
          ~&  >  [%reg-tester %saved-wallet spawn-ship]
          $(batch t.batch, cur-utxo `final-utxo)
        ::
            %keys
          ?~  cur-utxo
            ~&  >>>  [%reg-tester %keys-needs-utxo]  !!
          =/  wal  (nu-twk:walt:unv 0 resolved-twk (nu:wallet:unv sed.args i u.cur-utxo))
          =^  keys-commit-out      wal  (keys:btc:wal breach.sot)
          =^  keys-reveal-tx       wal  (spend:btc:wal keys-commit-out)
          =^  keyspend-commit-out  wal  make-key-out:btc:wal
          =^  keyspend-reveal-tx   wal  (spend:btc:wal keyspend-commit-out)
          =/  final-utxo=utxo:unv  utxo:wal:wal
          ;<  ~  bind:m  (broadcast-raw-tx url auth keys-reveal-tx)
          ;<  ~  bind:m  (broadcast-raw-tx url auth keyspend-reveal-tx)
          ;<  ~  bind:m  (mine-n url auth address 8)
          ~&  >  [%reg-tester %keys-done]
          $(batch t.batch, cur-utxo `final-utxo)
        ::
            %adopt
          ?~  cur-utxo
            ~&  >>>  [%reg-tester %adopt-needs-utxo]  !!
          =/  wal  (nu-twk:walt:unv 0 resolved-twk (nu:wallet:unv sed.args i u.cur-utxo))
          =^  adopt-commit-out     wal  (adopt:btc:wal ship.sot)
          =^  adopt-reveal-tx      wal  (spend:btc:wal adopt-commit-out)
          =^  keyspend-commit-out  wal  make-key-out:btc:wal
          =^  keyspend-reveal-tx   wal  (spend:btc:wal keyspend-commit-out)
          =/  final-utxo=utxo:unv  utxo:wal:wal
          ;<  ~  bind:m  (broadcast-raw-tx url auth adopt-reveal-tx)
          ;<  ~  bind:m  (broadcast-raw-tx url auth keyspend-reveal-tx)
          ;<  ~  bind:m  (mine-n url auth address 8)
          ~&  >  [%reg-tester %adopt-done]
          $(batch t.batch, cur-utxo `final-utxo)
        ::
            %escape
          ?~  cur-utxo
            ~&  >>>  [%reg-tester %escape-needs-utxo]  !!
          =/  wal  (nu-twk:walt:unv 0 resolved-twk (nu:wallet:unv sed.args i u.cur-utxo))
          =^  escape-commit-out    wal  (escape:btc:wal parent.sot)
          =^  escape-reveal-tx     wal  (spend:btc:wal escape-commit-out)
          =^  keyspend-commit-out  wal  make-key-out:btc:wal
          =^  keyspend-reveal-tx   wal  (spend:btc:wal keyspend-commit-out)
          =/  final-utxo=utxo:unv  utxo:wal:wal
          ;<  ~  bind:m  (broadcast-raw-tx url auth escape-reveal-tx)
          ;<  ~  bind:m  (broadcast-raw-tx url auth keyspend-reveal-tx)
          ;<  ~  bind:m  (mine-n url auth address 8)
          ~&  >  [%reg-tester %escape-done]
          $(batch t.batch, cur-utxo `final-utxo)
        ::
            %fief
          ?~  cur-utxo
            ~&  >>>  [%reg-tester %fief-needs-utxo]  !!
          =/  wal  (nu-twk:walt:unv 0 resolved-twk (nu:wallet:unv sed.args i u.cur-utxo))
          =^  fief-commit-out      wal  (fief:btc:wal fief.sot)
          =^  fief-reveal-tx       wal  (spend:btc:wal fief-commit-out)
          =^  keyspend-commit-out  wal  make-key-out:btc:wal
          =^  keyspend-reveal-tx   wal  (spend:btc:wal keyspend-commit-out)
          =/  final-utxo=utxo:unv  utxo:wal:wal
          ;<  ~  bind:m  (broadcast-raw-tx url auth fief-reveal-tx)
          ;<  ~  bind:m  (broadcast-raw-tx url auth keyspend-reveal-tx)
          ;<  ~  bind:m  (mine-n url auth address 8)
          ~&  >  [%reg-tester %fief-done]
          $(batch t.batch, cur-utxo `final-utxo)
        ::
            %cancel-escape
          ?~  cur-utxo
            ~&  >>>  [%reg-tester %cancel-escape-needs-utxo]  !!
          =/  wal  (nu-twk:walt:unv 0 resolved-twk (nu:wallet:unv sed.args i u.cur-utxo))
          =/  cancel-sot=sotx:urb  (cancel-escape:unv-tx:wal parent.sot)
          =/  [cancel-commit-out=output:gw new-inner=_wal:wal]
            (build-output:wal:wal `(make-unv-script:unv cancel-sot ~))
          =.  wal  wal(wal new-inner)
          =^  cancel-reveal-tx      wal  (spend:btc:wal cancel-commit-out)
          =^  keyspend-commit-out   wal  make-key-out:btc:wal
          =^  keyspend-reveal-tx    wal  (spend:btc:wal keyspend-commit-out)
          =/  final-utxo=utxo:unv  utxo:wal:wal
          ;<  ~  bind:m  (broadcast-raw-tx url auth cancel-reveal-tx)
          ;<  ~  bind:m  (broadcast-raw-tx url auth keyspend-reveal-tx)
          ;<  ~  bind:m  (mine-n url auth address 8)
          ~&  >  [%reg-tester %cancel-escape-done]
          $(batch t.batch, cur-utxo `final-utxo)
        ::
            %reject
          ?~  cur-utxo
            ~&  >>>  [%reg-tester %reject-needs-utxo]  !!
          =/  wal  (nu-twk:walt:unv 0 resolved-twk (nu:wallet:unv sed.args i u.cur-utxo))
          =/  reject-sot=sotx:urb  (reject:unv-tx:wal ship.sot)
          =/  [reject-commit-out=output:gw new-inner=_wal:wal]
            (build-output:wal:wal `(make-unv-script:unv reject-sot ~))
          =.  wal  wal(wal new-inner)
          =^  reject-reveal-tx      wal  (spend:btc:wal reject-commit-out)
          =^  keyspend-commit-out   wal  make-key-out:btc:wal
          =^  keyspend-reveal-tx    wal  (spend:btc:wal keyspend-commit-out)
          =/  final-utxo=utxo:unv  utxo:wal:wal
          ;<  ~  bind:m  (broadcast-raw-tx url auth reject-reveal-tx)
          ;<  ~  bind:m  (broadcast-raw-tx url auth keyspend-reveal-tx)
          ;<  ~  bind:m  (mine-n url auth address 8)
          ~&  >  [%reg-tester %reject-done]
          $(batch t.batch, cur-utxo `final-utxo)
        ::
            %detach
          ?~  cur-utxo
            ~&  >>>  [%reg-tester %detach-needs-utxo]  !!
          =/  wal  (nu-twk:walt:unv 0 resolved-twk (nu:wallet:unv sed.args i u.cur-utxo))
          =/  detach-sot=sotx:urb  (detach:unv-tx:wal ship.sot)
          =/  [detach-commit-out=output:gw new-inner=_wal:wal]
            (build-output:wal:wal `(make-unv-script:unv detach-sot ~))
          =.  wal  wal(wal new-inner)
          =^  detach-reveal-tx      wal  (spend:btc:wal detach-commit-out)
          =^  keyspend-commit-out   wal  make-key-out:btc:wal
          =^  keyspend-reveal-tx    wal  (spend:btc:wal keyspend-commit-out)
          =/  final-utxo=utxo:unv  utxo:wal:wal
          ;<  ~  bind:m  (broadcast-raw-tx url auth detach-reveal-tx)
          ;<  ~  bind:m  (broadcast-raw-tx url auth keyspend-reveal-tx)
          ;<  ~  bind:m  (mine-n url auth address 8)
          ~&  >  [%reg-tester %detach-done]
          $(batch t.batch, cur-utxo `final-utxo)
        ::
            %set-mang
          ?~  cur-utxo
            ~&  >>>  [%reg-tester %set-mang-needs-utxo]  !!
          =/  wal  (nu-twk:walt:unv 0 resolved-twk (nu:wallet:unv sed.args i u.cur-utxo))
          =/  mang-sot=sotx:urb  (set-mang:unv-tx:wal mang.sot)
          =/  [mang-commit-out=output:gw new-inner=_wal:wal]
            (build-output:wal:wal `(make-unv-script:unv mang-sot ~))
          =.  wal  wal(wal new-inner)
          =^  mang-reveal-tx        wal  (spend:btc:wal mang-commit-out)
          =^  keyspend-commit-out   wal  make-key-out:btc:wal
          =^  keyspend-reveal-tx    wal  (spend:btc:wal keyspend-commit-out)
          =/  final-utxo=utxo:unv  utxo:wal:wal
          ;<  ~  bind:m  (broadcast-raw-tx url auth mang-reveal-tx)
          ;<  ~  bind:m  (broadcast-raw-tx url auth keyspend-reveal-tx)
          ;<  ~  bind:m  (mine-n url auth address 8)
          ~&  >  [%reg-tester %set-mang-done]
          $(batch t.batch, cur-utxo `final-utxo)
        ==
          ::  /ui/sse/stats.html: aggregated stats fragment served over
          ::  SSE to the dashboard. Watches all chain + urb files and
          ::  re-renders a single HTML fragment so the browser only
          ::  needs one event-stream connection.
          ::
          [[%ui %sse ~] %'stats.html']
        ;<  ~  bind:m  (rise-wait:io prod "%groundwire /ui/sse/stats: failed")
        =/  h-road=road:tarball  (cord-to-road:tarball '../../height.ud')
        =/  u-road=road:tarball  (cord-to-road:tarball '../../urb-state.urb-state')
        ;<  *  bind:m  (keep:io /h h-road ~)
        ;<  *  bind:m  (keep:io /u u-road ~)
        |-
        ;<  h-seen=seen:nexus  bind:m  (peek:io h-road ~)
        ;<  u-seen=seen:nexus  bind:m  (peek:io u-road ~)
        ;<  ~  bind:m
          %-  replace:io
          !>((crip (en-xml:html (stats-fragment (extract-ud h-seen) (extract-urb u-seen)))))
        ;<  *  bind:m  (take-stats-news /h /u)
        $
          ::  /page.html: static shell with reg-tester forms. Re-renders
          ::  when SSE fragments or seeds directory change.
          ::
          [~ %'page.html']
        ;<  ~  bind:m  (rise-wait:io prod "%groundwire /page: failed")
        ;<  here=rail:tarball  bind:m  get-here-abs:io
        =/  nexus-root=tape  (spud path.here)
        =/  sse-road=road:tarball  (cord-to-road:tarball './ui/sse/')
        =/  seeds-road=road:tarball  (cord-to-road:tarball './wallets/')
        =/  points-road=road:tarball  (cord-to-road:tarball './points/')
        ;<  *  bind:m  (keep:io /sse sse-road ~)
        ;<  *  bind:m  (keep:io /seeds seeds-road ~)
        ;<  *  bind:m  (keep:io /points points-road ~)
        |-
        ;<  sse-seen=seen:nexus  bind:m  (peek:io sse-road ~)
        ;<  seeds-seen=seen:nexus  bind:m  (peek:io seeds-road ~)
        ;<  points-seen=seen:nexus  bind:m  (peek:io points-road ~)
        ;<  ~  bind:m
          (replace:io !>((crip (en-xml:html (btc-page nexus-root (extract-sse-manx sse-seen 'stats.html') (extract-ships seeds-seen) (extract-points points-seen))))))
        ;<  *  bind:m  (take-any-news /sse /seeds /points)
        $
      ==
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'Subdirectory under the bitcoind nexus.'
            ~
          %-  crip
          """
          BITCOIND NEXUS — Bitcoin PKI state machine with live web UI

          Maintains urb protocol PKI state by scanning Bitcoin blocks.
          The walker fiber at /urb-state.urb-state owns the PKI state
          and uses replace:io — anything can keep:io it
          for live updates. Per-ship point files live under /points/.

          FILES:
            config.json              RPC connection settings (url, auth).
            height.ud                Tip poller — polls getblockcount every 2s.
            urb-state.urb-state      Walker + PKI state. Cursor is
                                     num.block-id inside the state.
                                     Gain on — subscribable.
            points/                  Per-ship point files. Gain on.
            latest.json              Last processed block summary.
            rpc.sig                  RPC proxy poke receiver.
            reg-tester.sig           Spawn/test poke receiver.
            page.html                Dashboard shell.

          Usage from the browser:
            GET  /grubbery/api/file/groundwire.groundwire/page.html
            SSE  /grubbery/api/keep/groundwire.groundwire/urb-state.urb-state?mark=json
            POKE /grubbery/api/poke/groundwire.groundwire/reg-tester.sig?mark=json
          """
        ==
          %|
        ?+  rail.p.mana  'File under the bitcoind nexus.'
          [~ %'ver.ud']                  'Schema version. Mark: ud.'
          [~ %'config.json']             'RPC connection settings (url, auth). Mark: json.'
          [~ %'height.ud']               'Tip poller. Mark: ud. Polls every 2s.'
          [~ %'urb-state.urb-state']     'Walker + PKI state. Gain on. Mark: urb-state.'
          [~ %'latest.json']             'Last processed block summary. Mark: json.'
          [~ %'rpc.sig']                 'RPC proxy poke receiver. Mark: sig.'
          [~ %'reg-tester.sig']          'Spawn/test poke receiver. Mark: sig.'
          [~ %'page.html']              'Dashboard shell. Mark: manx.'
        ==
      ==
    --
|%
::
::  Wait for news on either stats-fragment dependency (height or
::  urb state). Returns a tag indicating which file bumped.
::
++  take-stats-news
  |=  [h=wire u=wire]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %news * *]
    ?:  =(h wire.u.in)  [%done ~]
    ?:  =(u wire.u.in)  [%done ~]
    [%skip ~]
  ==
::
::  Extract a @ud from a kept file view, defaulting to 0 on missing
::  or mismatched shape.
::
++  extract-ud
  |=  =seen:nexus
  ^-  @ud
  ?.  ?=([%& %file *] seen)  0
  (fall (mole |.(!<(@ud (need-vase:tarball sang.p.seen)))) 0)
::
::  Extract a urb state:urb from a kept urb-state file view.
::
++  extract-urb
  |=  =seen:nexus
  ^-  state:urb
  ?.  ?=([%& %file *] seen)  *state:urb
  (fall (mole |.(!<(state:urb (need-vase:tarball sang.p.seen)))) *state:urb)
::
::  Extract a named manx fragment from a kept sse directory view,
::  defaulting to an empty div.
::
++  extract-sse-manx
  |=  [=seen:nexus name=@ta]
  ^-  manx
  ?.  ?=([%& %ball *] seen)  ;div;
  =/  =lump:tarball  (fall fil.ball.p.seen *lump:tarball)
  =/  ct=(unit sang:tarball)  (~(get by contents.lump) name)
  ?~  ct  ;div;
  (fall (mole |.((need (de-xml:html !<(@t (need-vase:tarball u.ct)))))) ;div;)
::
::  Extract ship names from a kept wallets directory view.
::
++  extract-ships
  |=  =seen:nexus
  ^-  (list @p)
  ?.  ?=([%& %ball *] seen)  ~
  =/  =lump:tarball  (fall fil.ball.p.seen *lump:tarball)
  %+  murn  ~(tap by contents.lump)
  |=  [name=@ta =sang:tarball]
  ?.  ?=(%urb-wallet name.p.sang)  ~
  =/  raw=tape  (trip name)
  =/  ext=tape  ".urb-wallet"
  (slaw %p (crip (scag (sub (lent raw) (lent ext)) raw)))
::
::  Extract ship names from a kept points directory view.
::
++  extract-points
  |=  =seen:nexus
  ^-  (list @p)
  ?.  ?=([%& %ball *] seen)  ~
  =/  =lump:tarball  (fall fil.ball.p.seen *lump:tarball)
  %+  murn  ~(tap by contents.lump)
  |=  [name=@ta =sang:tarball]
  ?.  ?=(%json name.p.sang)  ~
  =/  raw=tape  (trip name)
  =/  ext=tape  ".json"
  (slaw %p (crip (scag (sub (lent raw) (lent ext)) raw)))
::
::  Fiber: wait for news on /sse, /seeds, or /points wire.
::
++  take-any-news
  |=  [a=wire b=wire c=wire]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %news * *]
    ?:  =(a wire.u.in)  [%done ~]
    ?:  =(b wire.u.in)  [%done ~]
    ?:  =(c wire.u.in)  [%done ~]
    [%skip ~]
  ==
::
::  Default bitcoind connection: regtest on localhost, spvwallet creds.
::
++  default-config
  ^-  json
  %-  pairs:enjs:format
  :~  ['url' s+'http://localhost:18443/']
      ['auth' s+'Basic Yml0Y29pbnJwYzpiaXRjb2lucnBj']
  ==
::
::  Extract (url, auth) from a peeked config.json seen, falling back
::  to default values for any missing or malformed field.
::
++  read-config
  |=  =seen:nexus
  ^-  [url=@t auth=@t]
  =/  fallback  [url='http://localhost:18443/' auth='Basic Yml0Y29pbnJwYzpiaXRjb2lucnBj']
  ?.  ?=([%& %file *] seen)  fallback
  =/  jon  !<(json (need-vase:tarball sang.p.seen))
  ?.  ?=([%o *] jon)  fallback
  =/  url=@t
    =/  u=(unit json)  (~(get by p.jon) 'url')
    ?~  u  url.fallback
    ?.  ?=([%s *] u.u)  url.fallback
    p.u.u
  =/  auth=@t
    =/  a=(unit json)  (~(get by p.jon) 'auth')
    ?~  a  auth.fallback
    ?.  ?=([%s *] u.a)  auth.fallback
    p.u.a
  [url auth]
::
::  Parse a reg-tester json poke into the args shape.
::  Spawn:  {"action":"spawn","sed":N}
::  Others: {"action":"keys","ship":"~sampel"} — sed resolved from seeds dir.
::  escape adds "parent", adopt adds "adoptee", fief adds "ip"/"port".
::
++  parse-reg-tester-json
  |=  =json
  ^-  (unit [sed=@uw acting=(unit @p) init-utxo=(unit utxo:unv) many=many:skim-sotx:urb])
  ?.  ?=([%o *] json)  ~
  =/  act-j=(unit ^json)  (~(get by p.json) 'action')
  ?~  act-j  ~
  ?.  ?=([%s *] u.act-j)  ~
  ::  parse optional sed (required for spawn)
  =/  sed-j=(unit ^json)  (~(get by p.json) 'sed')
  =/  sed=@uw
    ?~  sed-j  `@uw`0
    ?:  ?=([%n *] u.sed-j)
      `@uw`(need (rush p.u.sed-j dem))
    ?:  ?=([%s *] u.sed-j)
      `@uw`(need (rush p.u.sed-j dem))
    `@uw`0
  ::  parse optional ship (required for non-spawn actions)
  =/  ship-j=(unit ^json)  (~(get by p.json) 'ship')
  =/  acting=(unit @p)
    ?~  ship-j  ~
    ?.  ?=([%s *] u.ship-j)  ~
    (slaw %p p.u.ship-j)
  ?+  p.u.act-j  ~
      %spawn
    ?:  =(sed `@uw`0)  ~  :: sed required for spawn
    `[sed ~ ~ [%spawn 0 ~ 0x0 ~ 0 0]]
  ::
      %keys
    `[`@uw`0 acting ~ [%keys *pass %.n]]
  ::
      %'keys-breach'
    `[`@uw`0 acting ~ [%keys *pass %.y]]
  ::
      %escape
    =/  parent-j=(unit ^json)  (~(get by p.json) 'parent')
    =/  parent=ship
      ?~  parent-j  ~tyr
      ?.  ?=([%s *] u.parent-j)  ~tyr
      (fall (slaw %p p.u.parent-j) ~tyr)
    `[`@uw`0 acting ~ [%escape parent ~]]
  ::
      %adopt
    =/  adoptee-j=(unit ^json)  (~(get by p.json) 'adoptee')
    ?~  adoptee-j  ~
    ?.  ?=([%s *] u.adoptee-j)  ~
    =/  adoptee=ship  (need (slaw %p p.u.adoptee-j))
    `[`@uw`0 acting ~ [%adopt adoptee]]
  ::
      %fief
    =/  type-j=(unit ^json)  (~(get by p.json) 'fief-type')
    =/  port-j=(unit ^json)  (~(get by p.json) 'port')
    =/  port=@ud
      ?~  port-j  8.080
      ?.  ?=([%n *] u.port-j)  8.080
      (fall (rush p.u.port-j dem) 8.080)
    =/  type=@t  ?~(type-j 'if' ?:(?=([%s *] u.type-j) p.u.type-j 'if'))
    ?+    type
        `[`@uw`0 acting ~ [%fief ~]]
    ::
        %if
      =/  ip-j=(unit ^json)  (~(get by p.json) 'addr')
      =/  ip=@if
        ?~  ip-j  .1.2.3.4
        ?.  ?=([%s *] u.ip-j)  .1.2.3.4
        (fall (slaw %if (cat 3 '.' p.u.ip-j)) .1.2.3.4)
      `[`@uw`0 acting ~ [%fief `[%if ip port]]]
    ::
        %is
      =/  ip-j=(unit ^json)  (~(get by p.json) 'addr')
      =/  ip=@is
        ?~  ip-j  `@is`1
        ?.  ?=([%s *] u.ip-j)  `@is`1
        (fall (slaw %is (cat 3 '.' p.u.ip-j)) `@is`1)
      `[`@uw`0 acting ~ [%fief `[%is ip port]]]
    ::
        %turf
      =/  dom-j=(unit ^json)  (~(get by p.json) 'addr')
      =/  dom=@t
        ?~  dom-j  'example.com'
        ?.  ?=([%s *] u.dom-j)  'example.com'
        p.u.dom-j
      ::  split domain on '.' and reverse for tld-first turf
      =/  parts=(list @t)
        %+  turn
          (flop (rash dom (more dot (cook crip (star ;~(less dot prn))))))
        |=(a=@t a)
      `[`@uw`0 acting ~ [%fief `[%turf ~[parts] port]]]
    ==
  ::
      %'cancel-escape'
    =/  parent-j=(unit ^json)  (~(get by p.json) 'parent')
    =/  parent=ship
      ?~  parent-j  ~tyr
      ?.  ?=([%s *] u.parent-j)  ~tyr
      (fall (slaw %p p.u.parent-j) ~tyr)
    `[`@uw`0 acting ~ [%cancel-escape parent]]
  ::
      %reject
    =/  ship-j=(unit ^json)  (~(get by p.json) 'rejectee')
    ?~  ship-j  ~
    ?.  ?=([%s *] u.ship-j)  ~
    =/  rej=^ship  (need (slaw %p p.u.ship-j))
    `[`@uw`0 acting ~ [%reject rej]]
  ::
      %detach
    =/  ship-j=(unit ^json)  (~(get by p.json) 'detachee')
    ?~  ship-j  ~
    ?.  ?=([%s *] u.ship-j)  ~
    =/  det=^ship  (need (slaw %p p.u.ship-j))
    `[`@uw`0 acting ~ [%detach det]]
  ::
      %'set-mang'
    =/  mang-type-j=(unit ^json)  (~(get by p.json) 'mang-type')
    =/  mang-type=@t  ?~(mang-type-j 'clear' ?:(?=([%s *] u.mang-type-j) p.u.mang-type-j 'clear'))
    ?+    mang-type
        `[`@uw`0 acting ~ [%set-mang ~]]
        %clear  `[`@uw`0 acting ~ [%set-mang ~]]
        %pass
      =/  pass-j=(unit ^json)  (~(get by p.json) 'mang-pass')
      ?~  pass-j  `[`@uw`0 acting ~ [%set-mang ~]]
      ?.  ?=([%s *] u.pass-j)  `[`@uw`0 acting ~ [%set-mang ~]]
      =/  p=(unit @ux)  (slaw %ux p.u.pass-j)
      ?~  p  `[`@uw`0 acting ~ [%set-mang ~]]
      `[`@uw`0 acting ~ [%set-mang `[%pass u.p]]]
    ::
        %sont
      =/  txid-j=(unit ^json)  (~(get by p.json) 'mang-txid')
      =/  vout-j=(unit ^json)  (~(get by p.json) 'mang-vout')
      =/  off-j=(unit ^json)   (~(get by p.json) 'mang-off')
      ?~  txid-j  `[`@uw`0 acting ~ [%set-mang ~]]
      ?.  ?=([%s *] u.txid-j)  `[`@uw`0 acting ~ [%set-mang ~]]
      =/  txid=(unit @ux)  (slaw %ux p.u.txid-j)
      ?~  txid  `[`@uw`0 acting ~ [%set-mang ~]]
      =/  vout=@ud
        ?~  vout-j  0
        ?.  ?=([%n *] u.vout-j)  0
        (fall (rush p.u.vout-j dem) 0)
      =/  off=@ud
        ?~  off-j  0
        ?.  ?=([%n *] u.off-j)  0
        (fall (rush p.u.off-j dem) 0)
      `[`@uw`0 acting ~ [%set-mang `[%sont u.txid vout off]]]
    ==
  ==
::
::  Fiber helper: POST sendrawtransaction with a raw tx (octs).
::  Crashes on network or RPC failure.
::
++  broadcast-raw-tx
  |=  [url=@t auth=@t raw=octs]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  params=@t
    (rap 3 ~['["' (render-hex-octs:btc-rpc raw) '"]'])
  =/  req=request:http
    (rpc-request:btc-rpc url auth 'sendrawtransaction' params)
  ;<  ~  bind:m  (send-request:io req)
  ;<  resp=client-response:iris  bind:m  take-client-response:io
  ?.  ?=(%finished -.resp)
    ~&  >>>  [%broadcast-raw-tx %no-response]  !!
  ?~  full-file.resp
    ~&  >>>  [%broadcast-raw-tx %empty-response]  !!
  =/  body=@t  q.data.u.full-file.resp
  =/  jon=(unit json)  (de:json:html body)
  ?~  jon
    ~&  >>>  [%broadcast-raw-tx %bad-json body]  !!
  =/  txid=(unit @t)  (parse-string-result:btc-rpc u.jon)
  ?~  txid
    ~&  >>>  [%broadcast-raw-tx %no-txid body]  !!
  ~&  >  [%broadcast-raw-tx %ok u.txid]
  (pure:m ~)
::
::  Fiber helper: getrawtransaction <txid> false → tx:btc.
::  Uses verbose=false so the result is a hex string which we
::  decode via decodew:txu:btc-tx.
::
++  get-raw-tx
  |=  [url=@t auth=@t =txid:ord:urb]
  =/  m  (fiber:fiber:nexus ,(unit tx:btc))
  ^-  form:m
  =/  params=@t
    (rap 3 ~['["' (render-hex-octs:btc-rpc 32^txid) '",false]'])
  =/  req=request:http
    (rpc-request:btc-rpc url auth 'getrawtransaction' params)
  ;<  ~  bind:m  (send-request:io req)
  ;<  resp=client-response:iris  bind:m  take-client-response:io
  ?.  ?=(%finished -.resp)  (pure:m ~)
  ?~  full-file.resp  (pure:m ~)
  =/  body=@t  q.data.u.full-file.resp
  =/  jon=(unit json)  (de:json:html body)
  ?~  jon  (pure:m ~)
  =/  hex=(unit @t)  (parse-string-result:btc-rpc u.jon)
  ?~  hex  (pure:m ~)
  =/  raw=hexb  (hex-cord-to-hexb:btc-rpc u.hex)
  (pure:m `[txid (decodew:txu:btc-tx raw)])
::
::  Fiber helper: enrich a reveals map by fetching the prev-tx
::  for each input whose reveal entry is missing its input value.
::  Ported from groundwire's urb-watcher +convert-block loop.
::
++  enrich-reveals
  |=  $:  url=@t
          auth=@t
          reveals=(map [txid:ord:urb vout:ord:urb] [sots=(list raw-sotx:urb) value=(unit @ud)])
          blk=block:btc
      ==
  =/  m
    %-  fiber:fiber:nexus
    ,[reveals=(map [txid:ord:urb vout:ord:urb] [sots=(list raw-sotx:urb) value=(unit @ud)]) blk=block:btc]
  ^-  form:m
  ?~  txs.blk  (pure:m [reveals blk])
  ::  skip the coinbase tx; it has no prevouts
  =/  txs  t.txs.blk
  |-  ^-  form:m
  ?~  txs  (pure:m [reveals blk])
  =/  inputs  is.i.txs
  |-  ^-  form:m
  ?~  inputs  ^$(txs t.txs)
  =/  rev  (~(get by reveals) [txid pos]:i.inputs)
  ?:  &(?=(^ rev) ?=(^ value.u.rev))
    $(inputs t.inputs)
  ;<  prev-tx=(unit tx:btc)  bind:m
    (get-raw-tx url auth txid.i.inputs)
  ?~  prev-tx
    ~&  >>>  [%enrich-reveals %prev-tx-missing txid.i.inputs]  !!
  =/  prev-outputs  os.u.prev-tx
  =|  pos=@ud
  |-  ^-  form:m
  ?~  prev-outputs  ^$(inputs t.inputs)
  =/  rev2  (~(get by reveals) [id.u.prev-tx pos])
  ?:  &(?=(^ rev2) ?=(^ value.u.rev2))
    $(prev-outputs t.prev-outputs, pos +(pos))
  =/  sots=(list raw-sotx:urb)  ?~(rev2 ~ sots.u.rev2)
  %=  $
    prev-outputs  t.prev-outputs
    pos           +(pos)
    reveals       (~(put by reveals) [id.u.prev-tx pos] [sots `value.i.prev-outputs])
  ==
::
::  Fiber helper: convert a tx:btc to urb-tx:urb by fetching
::  prevout values for each input via getrawtransaction.
::  Ported from groundwire's urb-watcher ++convert-tx.
::
++  convert-tx
  |=  [url=@t auth=@t old-tx=tx:btc]
  =/  m  (fiber:fiber:nexus ,urb-tx:urb)
  ^-  form:m
  =/  old-inputs  is.old-tx
  =|  new-inputs=(list input:urb-tx:urb)
  |-
  ^-  form:m
  ?~  old-inputs
    %-  pure:m
    ^-  urb-tx:urb
    :*  id.old-tx
        (flop new-inputs)
        os.old-tx
        locktime.old-tx
        nversion.old-tx
        segwit.old-tx
    ==
  ::  coinbase inputs (txid=0) can't be fetched; use sum of outputs
  ::  as the input value since input = output for coinbase txs.
  ?:  =(0x0 txid.i.old-inputs)
    =/  total-out=@ud  (roll os.old-tx |=([[* a=@] b=@] (add a b)))
    =/  new-input=input:urb-tx:urb  [[~ total-out] i.old-inputs]
    $(old-inputs t.old-inputs, new-inputs [new-input new-inputs])
  ;<  prev-tx=(unit tx:btc)  bind:m
    (get-raw-tx url auth txid.i.old-inputs)
  ?~  prev-tx
    ~&  >>>  [%convert-tx %prev-tx-missing txid.i.old-inputs]
    =/  new-input=input:urb-tx:urb  [[~ 0] i.old-inputs]
    $(old-inputs t.old-inputs, new-inputs [new-input new-inputs])
  =/  prev-outputs  os.u.prev-tx
  =|  pos=@ud
  |-
  ^-  form:m
  ?~  prev-outputs
    ^$(old-inputs t.old-inputs)
  ?.  ?&  =(id.u.prev-tx txid.i.old-inputs)
          =(pos pos.i.old-inputs)
      ==
    $(prev-outputs t.prev-outputs, pos +(pos))
  =/  new-input=input:urb-tx:urb  [[~ value.i.prev-outputs] i.old-inputs]
  %=  ^$
    old-inputs  t.old-inputs
    new-inputs  [new-input new-inputs]
  ==
::
::  Fiber helper: scan an urb-block for %spawn sotx and build
::  the precommits map by fetching commit and precommit txs.
::  Ported from groundwire's urb-watcher spawn detection loop.
::
++  find-precommits
  |=  [url=@t auth=@t ublk=urb-block:urb]
  =/  m
    %-  fiber:fiber:nexus
    ,(map [txid:ord:urb vout:ord:urb] [commit=urb-tx:urb precommit=urb-tx:urb])
  ^-  form:m
  =|  precommits=(map [txid:ord:urb vout:ord:urb] [commit=urb-tx:urb precommit=urb-tx:urb])
  =/  txs  txs.ublk
  ::  iterate all txs looking for %spawn sotx in inputs
  |-
  ^-  form:m
  ?~  txs  (pure:m precommits)
  =/  tx-inputs  is.i.txs
  |-
  ^-  form:m
  ?~  tx-inputs  ^$(txs t.txs)
  =/  sots  sots.i.tx-inputs
  ?~  sots  $(tx-inputs t.tx-inputs)
  =/  singles=(list single:skim-sotx:urb)
    ?:  ?=(%batch +<.sot.i.sots)
      bat.sot.i.sots
    ~[+.sot.i.sots]
  |-
  ^-  form:m
  ?~  singles  ^$(tx-inputs t.tx-inputs)
  ?.  ?=(%spawn -.i.singles)
    $(singles t.singles)
  ::  found a spawn — fetch the commit tx (created this input)
  ;<  commit-tx=(unit tx:btc)  bind:m
    (get-raw-tx url auth txid.i.tx-inputs)
  ?~  commit-tx
    ~&  >>>  [%find-precommits %commit-tx-missing txid.i.tx-inputs]
    $(singles t.singles)
  ;<  commit-urb-tx=urb-tx:urb  bind:m
    (convert-tx url auth u.commit-tx)
  ::  find the commit tx input matching the attested spkh
  =/  spkh  spkh.to.i.singles
  ~&  >>  [%find-precommits %looking-for-spkh spkh]
  =/  inputs  is.commit-urb-tx
  |-
  ^-  form:m
  ?~  inputs
    ~&  >>  [%find-precommits %no-matching-spkh]
    ^$(singles t.singles)
  ;<  precommit-tx=(unit tx:btc)  bind:m
    (get-raw-tx url auth txid.i.inputs)
  ?~  precommit-tx
    ~&  >>>  [%find-precommits %precommit-tx-missing txid.i.inputs]
    $(inputs t.inputs)
  =/  outputs  os.u.precommit-tx
  |-
  ^-  form:m
  ?~  outputs  ^$(inputs t.inputs)
  =/  en-out  (can 3 script-pubkey.i.outputs 8^value.i.outputs ~)
  =/  computed-spkh  (shay (add 8 wid.script-pubkey.i.outputs) en-out)
  ~&  >>  :*  %find-precommits
              %candidate
              computed=computed-spkh
              wanted=spkh
              value=value.i.outputs
              spk-wid=wid.script-pubkey.i.outputs
          ==
  ?.  =(spkh computed-spkh)
    $(outputs t.outputs)
  ::  found matching precommit output — convert and save
  ;<  precommit-urb-tx=urb-tx:urb  bind:m
    (convert-tx url auth u.precommit-tx)
  %=  ^^^$
    tx-inputs   t.tx-inputs
    precommits  %+  ~(put by precommits)
                  [txid.i.tx-inputs pos.i.tx-inputs]
                [commit-urb-tx precommit-urb-tx]
  ==
::
::  Fiber helper: peek /trace.txt, append trace-block output, over it
::  back. No-op on coinbase-only blocks.
::
++  append-trace
  |=  [blk=block:btc reveals-count=@ud]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  new-lines=wain  (trace-block:btc-rpc blk reveals-count)
  ?~  new-lines  (pure:m ~)
  =/  trace-road=road:tarball  (cord-to-road:tarball './trace.txt')
  ;<  prev-seen=seen:nexus  bind:m  (peek:io trace-road `[/ %txt])
  =/  prev-lines=wain
    ?:  ?=([%& %file *] prev-seen)  !<(wain (need-vase:tarball sang.p.prev-seen))
    ~
  =/  combined=wain  (weld prev-lines new-lines)
  ;<  ~  bind:m  (over:io trace-road [[/ %txt] combined])
  (pure:m ~)
::
::  Emit each sotx observed in an urb-block as a urb-event.
::  Writes to events/main.urb-event (global stream) and
::  events/ships/<ship>.urb-event (per-ship).
::  Iterates txs → inputs → sots in order.
::
++  emit-events
  |=  ublk=urb-block:urb
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  main-road=road:tarball  (cord-to-road:tarball './events/main.urb-event')
  =/  txs=(list urb-tx:urb)  txs.ublk
  |-  ^-  form:m
  ?~  txs  (pure:m ~)
  =/  tx=urb-tx:urb  i.txs
  =/  ins=(list input:urb-tx:urb)  is.tx
  ;<  ~  bind:m
    |-  ^-  form:m
    ?~  ins  (pure:m ~)
    =/  sots=(list raw-sotx:urb)  sots.i.ins
    ;<  ~  bind:m
      |-  ^-  form:m
      ?~  sots  (pure:m ~)
      =/  evt=(unit [height=@ud txid=@ux =ship =sotx:urb os=(list output:tx:btc)])
        `[height.ublk id.tx ship.sot.i.sots sot.i.sots os.tx]
      =/  evt-bask=bask:tarball  [[/ %urb-event] evt]
      ::  write to global stream
      ;<  ~  bind:m  (over:io main-road evt-bask)
      ::  write to per-ship file (create on first event)
      =/  ship-road=road:tarball
        (cord-to-road:tarball (cat 3 './events/ships/' (cat 3 (scot %p ship.sot.i.sots) '.urb-event')))
      ;<  ship-seen=seen:nexus  bind:m  (peek:io ship-road ~)
      ;<  ~  bind:m
        ?:  ?=([%& %file *] ship-seen)
          (over:io ship-road evt-bask)
        (make:io ship-road [%| evt-bask ~])
      $(sots t.sots)
    $(ins t.ins)
  $(txs t.txs)
::
::  Convert urb-core effects to jael-style udiffs.
::
++  fx-to-udiffs
  |=  fx=(list [id:block:btc effect:urb])
  ^-  udiffs:point:jael
  %+  murn  fx
  |=  [=id:block:btc eu=effect:urb]
  ^-  (unit [ship udiff:point:jael])
  ?.  ?=(%point -.eu)  ~
  =/  pdiff  (tail (tail eu))
  ?+    -.pdiff  ~
      %rift
    `[ship.eu id %rift rift.pdiff %.n]
  ::
      %sponsor
    `[ship.eu id %spon sponsor.pdiff]
  ::
      %keys
    `[ship.eu id %keys [life.pdiff (sub (end 3 pass.pdiff) 'a') pass.pdiff] %.y]
  ::
      %fief
    `[ship.eu id %fief fief.pdiff]
  ==
::
::  Fiber helper: write per-ship point files for any %point effects.
::  Each ship that was touched gets its own file under /points/.
::
++  write-point-effects
  |=  [fx=(list [id:block:btc effect:urb]) us=state:urb]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  ships=(list @p)
    %+  murn  fx
    |=  [* =effect:urb]
    ?.  ?=(%point -.effect)  ~
    `ship.effect
  |-
  ^-  form:m
  ?~  ships  (pure:m ~)
  =/  pt  (~(get by unv-ids.us) i.ships)
  ?~  pt  $(ships t.ships)
  =/  name=@ta  (crip "{(trip (scot %p i.ships))}.json")
  =/  road=road:tarball  (cord-to-road:tarball (crip "./points/{(trip name)}"))
  =/  pt-json=json
    %-  pairs:enjs:format
    :~  ['ship' s+(scot %p i.ships)]
        ['rift' (numb:enjs:format rift.net.u.pt)]
        ['life' (numb:enjs:format life.net.u.pt)]
        ['pass' s+(scot %ux pass.net.u.pt)]
        ['sponsor' ?.(has.sponsor.net.u.pt ~ s+(scot %p who.sponsor.net.u.pt))]
        ['escape' ?~(escape.net.u.pt ~ s+(scot %p u.escape.net.u.pt))]
        :-  'owner'
        %-  pairs:enjs:format
        :~  ['txid' s+(scot %ux txid.sont.own.u.pt)]
            ['vout' (numb:enjs:format vout.sont.own.u.pt)]
            ['off' (numb:enjs:format off.sont.own.u.pt)]
        ==
        :-  'mang'
        ?~  mang.own.u.pt  ~
        ?-  -.u.mang.own.u.pt
          %sont  %-  pairs:enjs:format
                 :~  ['type' s+'sont']
                     ['txid' s+(scot %ux txid.sont.u.mang.own.u.pt)]
                     ['vout' (numb:enjs:format vout.sont.u.mang.own.u.pt)]
                     ['off' (numb:enjs:format off.sont.u.mang.own.u.pt)]
                 ==
          %pass  %-  pairs:enjs:format
                 :~  ['type' s+'pass']
                     ['pass' s+(scot %ux pass.u.mang.own.u.pt)]
                 ==
        ==
        :-  'fief'
        ?~  fief.net.u.pt  ~
        ?-  -.u.fief.net.u.pt
          %turf  %-  pairs:enjs:format
                 :~  ['type' s+'turf']
                     :-  'domains'
                     :-  %a
                     %+  turn  p.u.fief.net.u.pt
                     |=(t=turf:urb [%a (turn t |=(d=@t s+d))])
                     ['port' (numb:enjs:format q.u.fief.net.u.pt)]
                 ==
          %if    %-  pairs:enjs:format
                 :~  ['type' s+'if']
                     ['ip' s+(scot %if p.u.fief.net.u.pt)]
                     ['port' (numb:enjs:format q.u.fief.net.u.pt)]
                 ==
          %is    %-  pairs:enjs:format
                 :~  ['type' s+'is']
                     ['ip' s+(scot %is p.u.fief.net.u.pt)]
                     ['port' (numb:enjs:format q.u.fief.net.u.pt)]
                 ==
        ==
    ==
  ;<  =seen:nexus  bind:m  (peek:io road ~)
  ;<  ~  bind:m
    ?:  ?=([%& %file *] seen)
      (over:io road [[/ %json] pt-json])
    (make:io road [%| [[/ %json] pt-json] ~])
  $(ships t.ships)
::
::  Fiber helper: generatetoaddress N <addr>, ignoring result.
::
++  mine-n
  |=  [url=@t auth=@t address=@t n=@ud]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  params=@t
    (rap 3 ~['[' (ud-to-cord:btc-rpc n) ',"' address '"]'])
  =/  req=request:http
    (rpc-request:btc-rpc url auth 'generatetoaddress' params)
  ;<  ~  bind:m  (send-request:io req)
  ;<  resp=client-response:iris  bind:m  take-client-response:io
  ?.  ?=(%finished -.resp)
    ~&  >>>  [%mine-n %no-response]  !!
  (pure:m ~)
::
::  Render HTML shell for the bitcoind dashboard. Everything that
::  changes with chain/urb state lives inside the stats fragment,
::  which is refreshed over a single SSE connection on the browser.
::
++  btc-page
  |=  [nexus-root=tape stats=manx ships=(list @p) known-points=(list @p)]
  ^-  manx
  =/  sse=tape       "/grubbery/api/keep{nexus-root}/ui/sse?mark=txt"
  =/  reg-poke=tape  "/grubbery/api/poke{nexus-root}/reg-tester.sig?mark=json"
  =/  sorted-ships=(list @p)  (sort ships lth)
  =/  sorted-points=(list @p)  (sort known-points lth)
  =/  point-options=(list manx)
    %+  turn  sorted-points
    |=  =ship
    =/  s=tape  (scow %p ship)
    ;option(value s): {s}
  ;html
    ;head
      ;title: Grubbery Bitcoind
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;style
        ;+  ;/  page-style
      ==
    ==
    ;body
      ;h1: bitcoind · regtest
      ;div#stats-container
        ;+  stats
      ==
      ::  reg-tester: top tabs (spawn / attest), attest has sub-tabs
      ::  todo: random seed, sponsor-targeted random seed
      ;div.label: reg-tester
      ;div.tabs
        ;button.tab.active(onclick "switchTop('spawn')"): spawn
        ;button.tab(onclick "switchTop('attest')"): attest
      ==
      ::  spawn panel
      ;div#panel-spawn.panel
        ;form.row(onsubmit "submitSpawn(event)")
          ;div.col
            ;input(type "number", name "sed", value "42", min "1", placeholder "seed");
            ;div.sublabel: wallet seed
          ==
          ;div.col
            ;button(type "submit"): spawn
          ==
        ==
      ==
      ::  attest panel
      ;div#panel-attest.panel(style "display:none")
        ;div.row
          ;div.col
            ;select#ship-select
              ;option(value ""): -- select ship --
              ;*  %+  turn  sorted-ships
                  |=  =ship
                  =/  s=tape  (scow %p ship)
                  ;option(value s): {s}
            ==
          ==
        ==
        ;div.subtabs
          ;button.subtab.active(onclick "switchSub('keys')"): keys
          ;button.subtab(onclick "switchSub('sponsor')"): sponsor
          ;button.subtab(onclick "switchSub('fief')"): fief
          ;button.subtab(onclick "switchSub('manager')"): manager
        ==
        ::  keys category
        ;div#sub-keys.subpanel
          ;div.row
            ;div.col
              ;form.action-form(onsubmit "submitAttest(event)")
                ;input(type "hidden", name "action", value "keys");
                ;button(type "submit"): rotate keys
              ==
            ==
            ;div.col
              ;form.action-form(onsubmit "submitAttest(event)")
                ;input(type "hidden", name "action", value "keys-breach");
                ;button(type "submit"): breach
              ==
            ==
          ==
        ==
        ::  sponsor category
        ;div#sub-sponsor.subpanel(style "display:none")
          ;form.action-form(onsubmit "submitAttest(event)")
            ;input(type "hidden", name "action", value "escape");
            ;div.row
              ;div.col
                ;select(name "parent")
                  ;option(value ""): -- select sponsor --
                  ;*  point-options
                ==
                ;div.sublabel: escape to
              ==
              ;div.col
                ;button(type "submit"): escape
              ==
            ==
          ==
          ;form.action-form(onsubmit "submitAttest(event)")
            ;input(type "hidden", name "action", value "cancel-escape");
            ;div.row
              ;div.col
                ;select(name "parent")
                  ;option(value ""): -- select sponsor --
                  ;*  point-options
                ==
                ;div.sublabel: cancel escape to
              ==
              ;div.col
                ;button(type "submit"): cancel escape
              ==
            ==
          ==
          ;form.action-form(onsubmit "submitAttest(event)")
            ;input(type "hidden", name "action", value "adopt");
            ;div.row
              ;div.col
                ;select(name "adoptee")
                  ;option(value ""): -- select ship --
                  ;*  point-options
                ==
                ;div.sublabel: ship to adopt
              ==
              ;div.col
                ;button(type "submit"): adopt
              ==
            ==
          ==
          ;form.action-form(onsubmit "submitAttest(event)")
            ;input(type "hidden", name "action", value "reject");
            ;div.row
              ;div.col
                ;select(name "rejectee")
                  ;option(value ""): -- select ship --
                  ;*  point-options
                ==
                ;div.sublabel: ship to reject
              ==
              ;div.col
                ;button(type "submit"): reject
              ==
            ==
          ==
          ;form.action-form(onsubmit "submitAttest(event)")
            ;input(type "hidden", name "action", value "detach");
            ;div.row
              ;div.col
                ;select(name "detachee")
                  ;option(value ""): -- select ship --
                  ;*  point-options
                ==
                ;div.sublabel: ship to detach
              ==
              ;div.col
                ;button(type "submit"): detach
              ==
            ==
          ==
        ==
        ::  fief category
        ;div#sub-fief.subpanel(style "display:none")
          ;form.action-form(onsubmit "submitAttest(event)")
            ;input(type "hidden", name "action", value "fief");
            ;input(type "hidden", name "fief-type", value "if");
            ;div.row
              ;div.col
                ;input(type "text", name "addr", value "1.2.3.4", placeholder "1.2.3.4");
                ;div.sublabel: ipv4 address
              ==
              ;div.col
                ;input(type "number", name "port", value "8080", placeholder "port");
                ;div.sublabel: port
              ==
              ;div.col
                ;button(type "submit"): set ipv4
              ==
            ==
          ==
          ;form.action-form(onsubmit "submitAttest(event)")
            ;input(type "hidden", name "action", value "fief");
            ;input(type "hidden", name "fief-type", value "is");
            ;div.row
              ;div.col
                ;input(type "text", name "addr", value "::1", placeholder "::1");
                ;div.sublabel: ipv6 address
              ==
              ;div.col
                ;input(type "number", name "port", value "8080", placeholder "port");
                ;div.sublabel: port
              ==
              ;div.col
                ;button(type "submit"): set ipv6
              ==
            ==
          ==
          ;form.action-form(onsubmit "submitAttest(event)")
            ;input(type "hidden", name "action", value "fief");
            ;input(type "hidden", name "fief-type", value "turf");
            ;div.row
              ;div.col
                ;input(type "text", name "addr", value "example.com", placeholder "example.com");
                ;div.sublabel: domain
              ==
              ;div.col
                ;input(type "number", name "port", value "8080", placeholder "port");
                ;div.sublabel: port
              ==
              ;div.col
                ;button(type "submit"): set turf
              ==
            ==
          ==
          ;form.action-form(onsubmit "submitAttest(event)")
            ;input(type "hidden", name "action", value "fief");
            ;input(type "hidden", name "fief-type", value "clear");
            ;button(type "submit"): clear fief
          ==
        ==
        ::  manager category
        ;div#sub-manager.subpanel(style "display:none")
          ;div.sublabel: set by public key
          ;form.action-form(onsubmit "submitAttest(event)")
            ;input(type "hidden", name "action", value "set-mang");
            ;input(type "hidden", name "mang-type", value "pass");
            ;div.row
              ;div.col
                ;input(type "text", name "mang-pass", placeholder "0x...", value "");
                ;div.sublabel: public key
              ==
              ;div.col
                ;button(type "submit"): set pass
              ==
            ==
          ==
          ;hr;
          ;div.sublabel: set by satpoint
          ;form.action-form(onsubmit "submitAttest(event)")
            ;input(type "hidden", name "action", value "set-mang");
            ;input(type "hidden", name "mang-type", value "sont");
            ;div.row
              ;div.col
                ;input(type "text", name "mang-txid", placeholder "0x...", value "");
                ;div.sublabel: txid
              ==
              ;div.col
                ;input(type "number", name "mang-vout", value "0", placeholder "0");
                ;div.sublabel: vout
              ==
              ;div.col
                ;input(type "number", name "mang-off", value "0", placeholder "0");
                ;div.sublabel: offset
              ==
              ;div.col
                ;button(type "submit"): set sont
              ==
            ==
          ==
          ;hr;
          ;div.sublabel: remove manager proxy
          ;form.action-form(onsubmit "submitAttest(event)")
            ;input(type "hidden", name "action", value "set-mang");
            ;input(type "hidden", name "mang-type", value "clear");
            ;button(type "submit"): clear manager
          ==
        ==
      ==
      ;pre#status: _
      ;div.footer: walker polls bitcoind via /height.ud every 2s
      ;script
        ;+  ;/  (page-script sse reg-poke)
      ==
    ==
  ==
::
::  Dynamic stats block rendered into the page shell (and into the
::  /ui/sse/stats.html fragment each time the underlying files change).
::
++  stats-fragment
  |=  [tip=@ud us=state:urb]
  ^-  manx
  =/  processed=@ud  num.block-id.us
  =/  gap=@ud  ?:((gte processed tip) 0 (sub tip processed))
  =/  gap-text=tape
    ?:  =(gap 0)  "synced"
    (weld (scow %ud gap) (weld " block" ?:(=(gap 1) " behind" "s behind")))
  =/  gap-class=tape
    ?:  =(gap 0)  "status synced"
    "status lagging"
  =/  last-hash-full=tape
    (trip (en:base16:mimes:html 32^hax.block-id.us))
  =/  last-hash-short=tape
    ?:  (lth (lent last-hash-full) 16)  last-hash-full
    %+  weld  (scag 8 last-hash-full)
    (weld "…" (slag (sub (lent last-hash-full) 8) last-hash-full))
  =/  pts  ~(tap by unv-ids.us)
  =/  urb-points=tape  (scow %ud (lent pts))
  =/  urb-sonts=tape   (scow %ud ~(wyt by sont-map.us))
  =/  urb-inscs=tape   (scow %ud ~(wyt by insc-ids.us))
  ;div
    ;div.label: chain
    ;div.row
      ;+  (num-col (scow %ud tip) "tip")
      ;+  (num-col (scow %ud processed) "processed")
    ==
    ;div
      ;span(class gap-class): {gap-text}
    ==
    ;div.label: last block
    ;div.hash(title last-hash-full): {last-hash-short}
    ;div.label: urb state
    ;div.row
      ;+  (num-col urb-points "points")
      ;+  (num-col urb-sonts "sonts")
      ;+  (num-col urb-inscs "inscriptions")
    ==
    ;div.label: points
    ;+  (points-table pts)
  ==
::
::  Render the points table, or a placeholder if unv-ids is empty.
::  Columns: ship, rift, life, sponsor, escape. One row per point.
::
++  points-table
  |=  pts=(list (pair @p point:urb))
  ^-  manx
  ?~  pts
    ;div.empty: (none yet)
  ;table.points
    ;thead
      ;tr
        ;th: ship
        ;th: rift
        ;th: life
        ;th: sponsor
        ;th: escape
        ;th: fief
        ;th: mang
      ==
    ==
    ;tbody
      ;*  %+  turn  pts
          |=  [her=@p =point:urb]
          ^-  manx
          (point-row her point)
    ==
  ==
::
::  Single point row. Dashes render for missing sponsor / escape.
::
++  point-row
  |=  [her=@p =point:urb]
  ^-  manx
  =/  spn=manx
    ?:  has.sponsor.net.point
      ;span: {(scow %p who.sponsor.net.point)}
    ;span.dash: -
  =/  esc=manx
    ?~  escape.net.point
      ;span.dash: -
    ;span: {(scow %p u.escape.net.point)}
  =/  fie=manx
    ?~  fief.net.point
      ;span.dash: -
    ?-  -.u.fief.net.point
      %if    ;span: {(scow %if p.u.fief.net.point)}:{(scow %ud q.u.fief.net.point)}
      %is    ;span: {(scow %is p.u.fief.net.point)}:{(scow %ud q.u.fief.net.point)}
      %turf  ;span: turf:{(scow %ud q.u.fief.net.point)}
    ==
  =/  mgr=manx
    ?~  mang.own.point
      ;span.dash: -
    ?-  -.u.mang.own.point
      %sont  ;span: sont
      %pass  ;span: pass
    ==
  ;tr
    ;td.ship: {(scow %p her)}
    ;td: {(scow %ud rift.net.point)}
    ;td: {(scow %ud life.net.point)}
    ;td
      ;+  spn
    ==
    ;td
      ;+  esc
    ==
    ;td
      ;+  fie
    ==
    ;td
      ;+  mgr
    ==
  ==
::
::  Single numeric column for stats-fragment: large value with a
::  small sublabel underneath.
::
++  num-col
  |=  [val=tape label=tape]
  ^-  manx
  ;div.col
    ;div.num: {val}
    ;div.sublabel: {label}
  ==
::
::  Inline CSS for the dashboard shell. Kept flat for readability.
::
++  page-style
  ^-  tape
  %-  zing
  :~  "body \{ font-family: monospace; max-width: 600px; margin: 2rem auto; padding: 2rem; color: #eee; background: #111; } "
      "h1 \{ font-weight: normal; font-size: 1rem; opacity: 0.6; margin: 0 0 2rem 0; text-transform: uppercase; letter-spacing: 0.15em; } "
      ".label \{ opacity: 0.4; font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.1em; margin-top: 2rem; } "
      ".row \{ display: flex; gap: 3rem; margin-top: 0.25rem; align-items: stretch; } "
      ".col \{ flex: 1; display: flex; flex-direction: column; } "
      ".num \{ font-size: 3rem; font-weight: bold; font-variant-numeric: tabular-nums; line-height: 1; } "
      ".hash \{ font-size: 1.25rem; font-weight: bold; font-variant-numeric: tabular-nums; line-height: 1; overflow: hidden; text-overflow: ellipsis; } "
      ".sublabel \{ opacity: 0.35; font-size: 0.65rem; text-transform: uppercase; letter-spacing: 0.1em; margin-top: 0.4rem; } "
      "hr \{ border: none; border-top: 1px solid #333; margin: 0.75rem 0; } "
      ".status \{ font-size: 0.85rem; margin-top: 1.25rem; letter-spacing: 0.05em; } "
      ".status.synced \{ color: #6f6; } "
      ".status.lagging \{ color: #fc6; } "
      "form \{ margin: 0; } "
      "input, select \{ font-family: inherit; background: #222; color: #eee; border: 1px solid #444; padding: 0.5rem; font-size: 0.8rem; width: 100%; box-sizing: border-box; } "
      "select \{ cursor: pointer; } "
      ".tabs, .subtabs \{ display: flex; gap: 0; margin-top: 0.5rem; border-bottom: 1px solid #333; } "
      ".tab, .subtab \{ font-family: inherit; background: none; color: #666; border: none; padding: 0.5rem 1rem; cursor: pointer; text-transform: uppercase; letter-spacing: 0.1em; font-size: 0.75rem; border-bottom: 2px solid transparent; margin-bottom: -1px; } "
      ".tab:hover, .subtab:hover \{ color: #aaa; } "
      ".tab.active, .subtab.active \{ color: #eee; border-bottom-color: #eee; } "
      ".subtabs \{ margin-top: 0.75rem; } "
      ".panel \{ margin-top: 0.5rem; } "
      ".subpanel \{ margin-top: 0.75rem; } "
      "button \{ font-family: inherit; background: #222; color: #eee; border: 1px solid #444; padding: 0.75rem 1.25rem; cursor: pointer; text-transform: uppercase; letter-spacing: 0.1em; font-size: 0.8rem; flex: 1; } "
      "button:hover:not(:disabled) \{ background: #333; border-color: #666; } "
      "button:disabled \{ opacity: 0.4; cursor: wait; } "
      "pre#status \{ background: #000; border: 1px solid #333; padding: 0.75rem; margin-top: 1.5rem; font-size: 0.75rem; white-space: pre-wrap; word-break: break-all; min-height: 1rem; opacity: 0.7; } "
      "table.points \{ width: 100%; margin-top: 0.5rem; border-collapse: collapse; font-size: 0.75rem; } "
      "table.points th \{ text-align: left; opacity: 0.35; text-transform: uppercase; letter-spacing: 0.1em; font-weight: normal; padding: 0.4rem 0.5rem; border-bottom: 1px solid #333; } "
      "table.points td \{ padding: 0.4rem 0.5rem; border-bottom: 1px solid #222; font-variant-numeric: tabular-nums; } "
      "table.points td.ship \{ font-weight: bold; } "
      "table.points .dash \{ opacity: 0.25; } "
      ".empty \{ opacity: 0.4; font-size: 0.75rem; margin-top: 0.5rem; font-style: italic; } "
      ".footer \{ margin-top: 3rem; opacity: 0.3; font-size: 0.7rem; }"
  ==
::
::  Inline JS for the dashboard shell. Mine/runSpawn fire pokes;
::  connectSSE subscribes to /ui/sse with proper cleanup via an
::  AbortController + beforeunload handler, so reloading the page
::  doesn't accumulate stale SSE connections.
::
++  page-script
  |=  [sse=tape reg-poke=tape]
  ^-  tape
  %-  zing
  :~  "var SSE='{sse}';"
      "var REG_POKE='{reg-poke}';"

      "async function submitSpawn(e)\{e.preventDefault();var r=document.getElementById('status');var btn=e.target.querySelector('button');var sed=parseInt(new FormData(e.target).get('sed'),10);if(!sed||sed<1)\{r.textContent='need a positive seed';return}btn.disabled=true;btn.textContent='running…';r.textContent='spawn sed='+sed+'…';try\{var res=await fetch(REG_POKE,\{method:'POST',headers:\{'Content-Type':'application/json'},body:JSON.stringify(\{action:'spawn',sed:sed})});r.textContent=res.ok?'ok — spawn running; watch the walker':('poke failed: '+res.status)}catch(x)\{r.textContent=String(x)}btn.disabled=false;btn.textContent='spawn'}"
      "async function submitAttest(e)\{e.preventDefault();var r=document.getElementById('status');var btn=e.target.querySelector('button');var ship=document.getElementById('ship-select').value;if(!ship)\{r.textContent='select a ship first';return}var data=\{ship:ship};new FormData(e.target).forEach(function(v,k)\{data[k]=v});var act=data.action;var orig=btn.textContent;btn.disabled=true;btn.textContent='running…';r.textContent=act+' '+ship+'…';try\{var res=await fetch(REG_POKE,\{method:'POST',headers:\{'Content-Type':'application/json'},body:JSON.stringify(data)});r.textContent=res.ok?'ok — '+act+' running; watch the walker':('poke failed: '+res.status)}catch(x)\{r.textContent=String(x)}btn.disabled=false;btn.textContent=orig}"
      "function switchTop(id)\{document.querySelectorAll('.panel').forEach(function(p)\{p.style.display='none'});document.getElementById('panel-'+id).style.display='';document.querySelectorAll('.tab').forEach(function(t)\{t.classList.remove('active')});event.target.classList.add('active')}"
      "function switchSub(id)\{document.querySelectorAll('.subpanel').forEach(function(p)\{p.style.display='none'});document.getElementById('sub-'+id).style.display='';document.querySelectorAll('.subtab').forEach(function(t)\{t.classList.remove('active')});event.target.classList.add('active')}"
      "var sseController=null;var sseReader=null;"
      "async function connectSSE()\{if(sseReader)try\{sseReader.cancel()}catch(e)\{}if(sseController)sseController.abort();sseController=new AbortController();try\{var r=await fetch(SSE,\{headers:\{Accept:'text/event-stream'},signal:sseController.signal});sseReader=r.body.getReader();var dec=new TextDecoder();var buf='';while(true)\{var chunk=await sseReader.read();if(chunk.done)break;buf+=dec.decode(chunk.value,\{stream:true});var evts=buf.split('\\n\\n');buf=evts.pop();for(var i=0;i<evts.length;i++)\{if(!evts[i].trim())continue;var ev='',data=[],lines=evts[i].split('\\n');for(var j=0;j<lines.length;j++)\{if(lines[j].indexOf('event: ')===0)ev=lines[j].slice(7);else if(lines[j].indexOf('data: ')===0)data.push(lines[j].slice(6))}if(!ev)continue;var sp=ev.indexOf(' ');if(sp<0)continue;var name=ev.slice(sp+2);var html=data.join('\\n');if(name==='stats.html')\{var el=document.getElementById('stats-container');if(el)el.innerHTML=html}}}}catch(e)\{if(e.name!=='AbortError')setTimeout(connectSSE,2000)}}"
      "window.addEventListener('beforeunload',function()\{if(sseReader)try\{sseReader.cancel()}catch(e)\{}if(sseController)sseController.abort()});"
      "connectSSE();"
  ==
--
