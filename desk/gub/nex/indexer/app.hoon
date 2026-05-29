::  indexer nexus: bitcoind block cache
::
::  Polls bitcoind for the chain tip and caches blocks in the ball.
::  Pure cache — no script-hash awareness, no account logic.
::
::  Tree layout:
::    /config.json       bitcoind RPC connection (url, auth)
::    /tip.ud            current chain height
::    /poller.sig        poll loop process
::    /blocks/{height}/  cached block data (one dir per block)
::      header.json      block header fields
::      txs/             transaction directory
::        {txid}.json    parsed transaction data
::
/<  btc      /lib/sur/bitcoin.hoon
/<  btc-rpc  /lib/btc-rpc.hoon
=,  btc
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  =ver:loader  (get-ver:loader ball)
      ?+  ver  !!
          ?(~ [~ %0] [~ %1])
        =/  default-config=json
          %-  pairs:enjs:format
          :~  ['url' s+'http://localhost:18443/']
              ['auth' s+'Basic dXJiaXQ6dXJiaXQxMjM=']
              ['poll-interval' s+'~s5']
          ==
        %+  spin:loader  ball
        :~  (ver-row:loader 1)
            [%fall %& [/ %'config.json'] [[/ %json] default-config]]
            [%fall %& [/ %'tip.ud'] [[/ %ud] 0]]
            [%over %& [/ %'poller.sig'] [[/ %sig] ~]]
            [%fall %| /blocks empty-dir:loader]
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
          ::  /poller.sig: poll bitcoind for chain tip, fetch new blocks
          ::
          [~ %'poller.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%indexer /poller: failed")
        ::  read config
        ;<  cfg-seen=seen:nexus  bind:m
          (peek:io (cord-to-road:tarball './config.json') `[/ %json])
        =/  [url=@t auth=@t interval=@dr]  (read-config cfg-seen)
        |-
        ::  fetch current block count
        =/  req=request:http
          (rpc-request:btc-rpc url auth 'getblockcount' '[]')
        ;<  ~  bind:m  (send-request:io req)
        ;<  =client-response:iris  bind:m  take-client-response:io
        ?.  ?=(%finished -.client-response)
          ;<  ~  bind:m  (sleep:io interval)
          $
        ?~  full-file.client-response
          ;<  ~  bind:m  (sleep:io interval)
          $
        =/  body=@t  q.data.u.full-file.client-response
        =/  jon=(unit json)  (de:json:html body)
        ?~  jon
          ;<  ~  bind:m  (sleep:io interval)
          $
        =/  tip=(unit @ud)  (parse-height:btc-rpc u.jon)
        ?~  tip
          ;<  ~  bind:m  (sleep:io interval)
          $
        ::  update tip file
        =/  tip-road=road:tarball  (cord-to-road:tarball './tip.ud')
        ;<  ~  bind:m  (over:io tip-road [[/ %ud] u.tip])
        ::  check what we've already cached
        ;<  blocks-seen=seen:nexus  bind:m
          (peek:io (cord-to-road:tarball './blocks/') ~)
        =/  cached-heights=(list @ud)
          ?.  ?=([%& %ball *] blocks-seen)  ~
          %+  murn  ~(tap by dir.ball.p.blocks-seen)
          |=  [name=@ta *]
          (rush name dem)
        =/  max-cached=@ud
          (roll cached-heights |=([a=@ud b=@ud] (max a b)))
        ::  fetch any blocks we're missing from max-cached+1 to tip
        =/  next=@ud  ?:(=(0 max-cached) 1 +(max-cached))
        |-
        ?:  (gth next u.tip)
          ::  caught up — sleep and poll again
          ;<  ~  bind:m  (sleep:io interval)
          ^$
        ::  fetch block hash
        =/  hash-params=@t
          (en:json:html [%a ~[(numb:enjs:format next)]])
        =/  hash-req=request:http
          (rpc-request:btc-rpc url auth 'getblockhash' hash-params)
        ;<  ~  bind:m  (send-request:io hash-req)
        ;<  hash-resp=client-response:iris  bind:m  take-client-response:io
        ?.  ?=(%finished -.hash-resp)
          ~&  >  [%indexer %no-hash-response next]
          ;<  ~  bind:m  (sleep:io ~s2)
          ^$
        ?~  full-file.hash-resp
          ~&  >  [%indexer %empty-hash-response next]
          ;<  ~  bind:m  (sleep:io ~s2)
          ^$
        =/  hash-body=@t  q.data.u.full-file.hash-resp
        =/  hash-jon=(unit json)  (de:json:html hash-body)
        ?~  hash-jon
          ~&  >  [%indexer %bad-hash-json next]
          ;<  ~  bind:m  (sleep:io ~s2)
          ^$
        =/  hash=(unit @t)  (parse-string-result:btc-rpc u.hash-jon)
        ?~  hash
          ::  block height out of range — chain may have reset
          ?:  ?=(^ (find "out of range" (trip hash-body)))
            ~&  >  [%indexer %chain-reset-detected next]
            ;<  ~  bind:m  (over:io tip-road [[/ %ud] `@ud`0])
            ^$
          ~&  >  [%indexer %no-hash next]
          ;<  ~  bind:m  (sleep:io ~s2)
          ^$
        ::  fetch full block (verbosity 2)
        =/  blk-params=@t  (rap 3 ~['["' u.hash '",2]'])
        =/  blk-req=request:http
          (rpc-request:btc-rpc url auth 'getblock' blk-params)
        ;<  ~  bind:m  (send-request:io blk-req)
        ;<  blk-resp=client-response:iris  bind:m  take-client-response:io
        ?.  ?=(%finished -.blk-resp)
          ~&  >  [%indexer %no-block-response next]
          ;<  ~  bind:m  (sleep:io ~s2)
          ^$
        ?~  full-file.blk-resp
          ~&  >  [%indexer %empty-block-response next]
          ;<  ~  bind:m  (sleep:io ~s2)
          ^$
        =/  blk-body=@t  q.data.u.full-file.blk-resp
        =/  blk-jon=(unit json)  (de:json:html blk-body)
        ?~  blk-jon
          ~&  >  [%indexer %bad-block-json next]
          ;<  ~  bind:m  (sleep:io ~s2)
          ^$
        =/  mblk=(unit block:btc)  (parse-block:btc-rpc u.blk-jon)
        ?~  mblk
          ~&  >  [%indexer %bad-block-parse next]
          ;<  ~  bind:m  (sleep:io ~s2)
          ^$
        =/  blk  u.mblk
        ~&  >  [%indexer %cached-block height.blk txs=(lent txs.blk)]
        ::  write block into the ball
        ;<  ~  bind:m  (write-block next u.hash blk)
        $(next +(next))
      ==
    ::
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'Subdirectory under the indexer nexus.'
            ~
          %-  crip
          """
          INDEXER NEXUS — bitcoind block cache

          Polls a bitcoind node and caches block data in the ball namespace.
          Pure cache layer — no script-hash matching or account awareness.

          FILES:
            config.json       RPC connection settings (url, auth, poll-interval).
            tip.ud            Current chain height from bitcoind.
            poller.sig        Poll loop process.

          DIRECTORIES:
            blocks/           Cached block data keyed by height.
          """
            [%blocks ~]
          'Cached block data. Each subdirectory is a block height containing header.json and txs/.'
        ==
          %|
        ?+  rail.p.mana  'File under the indexer nexus.'
          [~ %'config.json']    'RPC connection: url, auth, poll-interval.'
          [~ %'tip.ud']         'Current chain height.'
          [~ %'poller.sig']     'Poll loop process.'
        ==
      ==
    --
::  indexer helpers
::
|%
++  read-config
  |=  =seen:nexus
  ^-  [url=@t auth=@t interval=@dr]
  =/  fallback=[url=@t auth=@t interval=@dr]  ['http://localhost:18443/' 'Basic dXJiaXQ6dXJiaXQxMjM=' ~s5]
  ?.  ?=([%& %file *] seen)  fallback
  =/  jon  !<(json q.sage.p.seen)
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
  =/  interval=@dr
    =/  i=(unit json)  (~(get by p.jon) 'poll-interval')
    ?~  i  interval.fallback
    ?.  ?=([%s *] u.i)  interval.fallback
    (fall (slaw %dr p.u.i) interval.fallback)
  [url auth interval]
::
++  write-block
  |=  [height=@ud hash-hex=@t blk=block:btc]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  height-dir=@ta  (crip ((d-co:co 1) height))
  =/  block-road  (cord-to-road:tarball (cat 3 './blocks/' height-dir))
  ::  build header json
  =/  header-json=json
    %-  pairs:enjs:format
    :~  ['hash' s+hash-hex]
        ['height' (numb:enjs:format height)]
        ['txCount' (numb:enjs:format (lent txs.blk))]
        ['reward' (numb:enjs:format reward.blk)]
    ==
  ::  build txs directory: lump with one json content entry per tx
  =/  tx-map=(map @ta content:tarball)
    %-  ~(gas by *(map @ta content:tarball))
    %+  turn  txs.blk
    |=  t=tx:btc
    ^-  [@ta content:tarball]
    =/  txid-hex=@t  (render-hex-octs:btc-rpc 32^id.t)
    =/  fname=@ta  (cat 3 txid-hex '.json')
    =/  tx-json=json  (tx-to-json t)
    [fname [[/ %json] !>(tx-json)]]
  =/  txs-lump=lump:tarball  [~ ~ tx-map]
  ::  assemble block ball: header.json in lump, txs/ as subdir
  =/  header-contents=(map @ta content:tarball)
    (~(put by *(map @ta content:tarball)) %'header.json' [[/ %json] !>(header-json)])
  =/  block-lump=lump:tarball  [~ ~ header-contents]
  =/  block-ball=ball:tarball
    [`block-lump (~(put by *(map @ta ball:tarball)) %txs [`txs-lump ~])]
  ;<  *  bind:m
    (make-soft:io (cord-to-road:tarball (cat 3 './blocks/' (cat 3 height-dir '/'))) &+block-ball)
  (pure:m ~)
::
++  tx-to-json
  |=  t=tx:btc
  ^-  json
  =/  txid-hex=@t  (render-hex-octs:btc-rpc 32^id.t)
  %-  pairs:enjs:format
  :~  ['txid' s+txid-hex]
      ['inputs' [%a (turn is.t input-to-json)]]
      ['outputs' [%a (turn os.t output-to-json)]]
  ==
::
++  input-to-json
  |=  iw=inputw:tx:btc
  ^-  json
  %-  pairs:enjs:format
  :~  ['prevTxid' s+(render-hex-octs:btc-rpc 32^txid.iw)]
      ['prevVout' (numb:enjs:format pos.iw)]
      ['sequence' s+(render-hex-octs:btc-rpc sequence.iw)]
  ==
::
++  output-to-json
  |=  o=output:tx:btc
  ^-  json
  %-  pairs:enjs:format
  :~  ['value' (numb:enjs:format value.o)]
      ['scriptPubKey' s+(render-hex-octs:btc-rpc script-pubkey.o)]
  ==
--
