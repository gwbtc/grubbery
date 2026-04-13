/<  tools      /lib/nex/tools.hoon
/<  btc        /lib/sur/bitcoin.hoon
/<  urb        /lib/sur/urb.hoon
/<  urb-core   /lib/urb-core.hoon
/<  btc-rpc    /lib/btc-rpc.hoon
::  probe-block: fetch a bitcoind block and run it through the urb
::  detection pipeline at a chosen stage. Used for per-stage debugging
::  of the walker: isolate where reveals go missing.
::
!:
=,  btc
=>  |%
    ::  Fiber helper: HTTP-fetch a getblock verbosity-2 response and
    ::  return its parsed JSON body.
    ::
    ++  fetch-block-json
      |=  [url=@t auth=@t hash-hex=@t]
      =/  m  (fiber:fiber:nexus ,(each json @t))
      ^-  form:m
      =/  params=@t
        (rap 3 ~['["' hash-hex '",2]'])
      =/  req=request:http
        (rpc-request:btc-rpc url auth 'getblock' params)
      ;<  ~  bind:m  (send-request:io req)
      ;<  resp=client-response:iris  bind:m  take-client-response:io
      ?.  ?=(%finished -.resp)
        (pure:m [%| 'getblock: no finished response'])
      ?~  full-file.resp
        (pure:m [%| 'getblock: empty response body'])
      =/  body=@t  q.data.u.full-file.resp
      =/  jon=(unit json)  (de:json:html body)
      ?~  jon  (pure:m [%| 'getblock: invalid JSON body'])
      (pure:m [%& u.jon])
    ::
    ::  Fiber helper: read bitcoind config.json and return [url auth],
    ::  falling back to btc-rpc defaults on any failure.
    ::
    ++  read-bitcoind-config
      =/  m  (fiber:fiber:nexus ,[url=@t auth=@t])
      ^-  form:m
      =/  fallback=[url=@t auth=@t]  [default-url:btc-rpc default-auth:btc-rpc]
      ;<  =seen:nexus  bind:m
        (peek:io [%& %& /'bitcoind.bitcoind' %'config.json'] ~)
      ?.  ?=([%& %file *] seen)  (pure:m fallback)
      =/  jon  !<(json q.sage.p.seen)
      ?.  ?=([%o *] jon)  (pure:m fallback)
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
      (pure:m [url auth])
    ::
    ::  Fiber helper: read bitcoind latest.json and return the current
    ::  tip hash as a hex cord, or ~ if missing/malformed.
    ::
    ++  read-tip-hash
      =/  m  (fiber:fiber:nexus ,(unit @t))
      ^-  form:m
      ;<  =seen:nexus  bind:m
        (peek:io [%& %& /'bitcoind.bitcoind' %'latest.json'] ~)
      ?.  ?=([%& %file *] seen)  (pure:m ~)
      =/  jon  !<(json q.sage.p.seen)
      ?.  ?=([%o *] jon)  (pure:m ~)
      =/  h=(unit json)  (~(get by p.jon) 'hash')
      ?~  h  (pure:m ~)
      ?.  ?=([%s *] u.h)  (pure:m ~)
      (pure:m `p.u.h)
    --
^-  tool:tools
|%
++  name  'probe_block'
++  description
  ^~  %-  crip
  ;:  weld
    "Fetch a bitcoind block and inspect it at a given pipeline stage. "
    "Stage 'parse' dumps the witness-byte trace-block output for every "
    "non-coinbase tx. Additional stages (reveals/enrich/precommit/apply) "
    "exercise deeper parts of the urb walker pipeline. If no hash is "
    "given, reads /'bitcoind.bitcoind'/latest.json for the current tip."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  malt
  :~  ['hash' [%string 'Block hash hex (no 0x prefix). Optional — defaults to tip.']]
      ['stage' [%string 'Pipeline stage: parse (default) | reveals | enrich | precommit | apply']]
      ['url' [%string 'Override RPC url. Optional — defaults to config.json.']]
      ['auth' [%string 'Override RPC auth header. Optional — defaults to config.json.']]
  ==
++  required  *(list @t)
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  ::  Args
  =/  arg-hash=(unit @t)
    (~(deg jo:json-utils [%o args.st]) /hash so:dejs:format)
  =/  arg-stage=(unit @t)
    (~(deg jo:json-utils [%o args.st]) /stage so:dejs:format)
  =/  arg-url=(unit @t)
    (~(deg jo:json-utils [%o args.st]) /url so:dejs:format)
  =/  arg-auth=(unit @t)
    (~(deg jo:json-utils [%o args.st]) /auth so:dejs:format)
  =/  stage=@t  ?~(arg-stage 'parse' u.arg-stage)
  ::  Resolve url/auth (explicit args win over config.json)
  ;<  [cfg-url=@t cfg-auth=@t]  bind:m  read-bitcoind-config
  =/  url=@t   ?~(arg-url cfg-url u.arg-url)
  =/  auth=@t  ?~(arg-auth cfg-auth u.arg-auth)
  ::  Resolve hash (explicit arg wins over latest.json tip)
  ;<  tip-hash=(unit @t)  bind:m  read-tip-hash
  =/  mhash=(unit @t)
    ?^  arg-hash  arg-hash
    tip-hash
  ?~  mhash
    (pure:m [%error 'No hash given and /bitcoind.bitcoind/latest.json missing/empty'])
  =/  hash-hex=@t  u.mhash
  ::  Fetch the block
  ;<  fetched=(each json @t)  bind:m  (fetch-block-json url auth hash-hex)
  ?:  ?=(%| -.fetched)  (pure:m [%error p.fetched])
  ::  Parse the block
  =/  mblk=(unit block:btc)  (parse-block:btc-rpc p.fetched)
  ?~  mblk  (pure:m [%error 'parse-block: could not parse JSON into block:btc'])
  =/  blk=block:btc  u.mblk
  ::  Stage dispatch
  ?+  stage
    (pure:m [%error (crip "unknown stage: {(trip stage)} (try parse|reveals|enrich|precommit|apply)")])
  ::
      %parse
    =/  trace=wain  (trace-block:btc-rpc blk 0)
    =/  header=wain
      :~  (rap 3 ~['# probe_block stage=parse hash=' hash-hex])
          %+  rap  3
          :~  '# height='  (ud-to-cord:btc-rpc height.blk)
              ' txs='  (ud-to-cord:btc-rpc (lent txs.blk))
              ' reward='  (ud-to-cord:btc-rpc reward.blk)
          ==
          ''
      ==
    =/  body=wain
      ?~  trace
        ~['(coinbase-only; no non-coinbase txs to trace)']
      trace
    (pure:m [%text (of-wain:format (weld header body))])
  ::
      %reveals
    =/  revs-and-block
      (find-block-reveals:(abed:urb-core:urb-core *state:urb) blk)
    =/  reveals  -.revs-and-block
    =/  filtered=block:btc  +.revs-and-block
    =/  rev-count=@ud  ~(wyt by reveals)
    =/  filt-tx-count=@ud  (lent txs.filtered)
    =/  header=wain
      :~  (rap 3 ~['# probe_block stage=reveals hash=' hash-hex])
          %+  rap  3
          :~  '# height='  (ud-to-cord:btc-rpc height.blk)
              ' txs='  (ud-to-cord:btc-rpc (lent txs.blk))
              ' reveals='  (ud-to-cord:btc-rpc rev-count)
              ' filtered-txs='  (ud-to-cord:btc-rpc filt-tx-count)
          ==
          ''
      ==
    =/  body=wain
      ?:  =(0 rev-count)
        ~['NO REVEALS FOUND — find-block-reveals returned empty map']
      %-  zing
      %+  turn  ~(tap by reveals)
      |=  [[=txid:ord:urb =vout:ord:urb] sots=(list raw-sotx:urb) value=(unit @ud)]
      ^-  wain
      :~  %+  rap  3
          :~  '  outpoint 0x'
              (render-hex-octs:btc-rpc 32^txid)
              ':'
              (ud-to-cord:btc-rpc vout)
              ' sots='
              (ud-to-cord:btc-rpc (lent sots))
              ' value='
              ?~(value 'none' (ud-to-cord:btc-rpc u.value))
          ==
      ==
    (pure:m [%text (of-wain:format (weld header body))])
  ==
--
