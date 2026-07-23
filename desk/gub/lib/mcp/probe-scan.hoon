/<  tools    /lib/nex/tools.hoon
/<  btc-rpc  /lib/btc-rpc.hoon
::  probe-scan: walk back N blocks from the current tip and return
::  a one-line-per-block summary of heights, hashes, and tx counts.
::  Blocks with txs>1 are flagged with '*' (non-coinbase txs present).
::
!:
=>  |%
    ::  Fiber helper: read groundwire config.json and return [url auth],
    ::  falling back to btc-rpc defaults.
    ::
    ++  read-groundwire-config
      =/  m  (fiber:fiber:nexus ,[url=@t auth=@t])
      ^-  form:m
      =/  fallback=[url=@t auth=@t]
        [default-url:btc-rpc default-auth:btc-rpc]
      ;<  =view:nexus  bind:m
        (peek:io [%& %& /'groundwire.groundwire' %'config.json'] ~)
      ?.  ?=([%file *] view)  (pure:m fallback)
      =/  jon  !<(json (need-vase:tarball sang.view))
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
    ::  Fiber helper: read groundwire height.ud and return current tip,
    ::  or ~ if missing.
    ::
    ++  read-tip-height
      =/  m  (fiber:fiber:nexus ,(unit @ud))
      ^-  form:m
      ;<  =view:nexus  bind:m
        (peek:io [%& %& /'groundwire.groundwire' %'height.ud'] ~)
      ?.  ?=([%file *] view)  (pure:m ~)
      (pure:m `!<(@ud (need-vase:tarball sang.view)))
    ::
    ::  Fiber helper: walk heights [from..to] calling getblockhash +
    ::  getblock verbosity=1, accumulate one line per block.
    ::
    ++  scan-range
      |=  [url=@t auth=@t from=@ud to=@ud]
      =/  m  (fiber:fiber:nexus ,wain)
      ^-  form:m
      =|  lines=wain
      =.  lines
        :_  lines
        %+  rap  3
        :~  '# probe_scan from='  (ud-to-cord:btc-rpc from)
            ' to='  (ud-to-cord:btc-rpc to)
        ==
      =/  h=@ud  from
      |-  ^-  form:m
      ?:  (gth h to)  (pure:m (flop lines))
      =/  hash-params=@t  (en:json:html [%a ~[(numb:enjs:format h)]])
      =/  hash-req=request:http
        (rpc-request:btc-rpc url auth 'getblockhash' hash-params)
      ;<  ~  bind:m  (send-request:io hash-req)
      ;<  hash-resp=client-response:iris  bind:m  take-client-response:io
      ?.  ?=(%finished -.hash-resp)  $(h +(h))
      ?~  full-file.hash-resp  $(h +(h))
      =/  hbody=@t  q.data.u.full-file.hash-resp
      =/  hjon=(unit json)  (de:json:html hbody)
      ?~  hjon  $(h +(h))
      =/  mhash=(unit @t)  (parse-string-result:btc-rpc u.hjon)
      ?~  mhash  $(h +(h))
      =/  hcord=@t  u.mhash
      =/  blk-params=@t
        %+  rap  3
        :~  '["'  hcord  '",1]'  ==
      =/  blk-req=request:http
        (rpc-request:btc-rpc url auth 'getblock' blk-params)
      ;<  ~  bind:m  (send-request:io blk-req)
      ;<  blk-resp=client-response:iris  bind:m  take-client-response:io
      ?.  ?=(%finished -.blk-resp)  $(h +(h))
      ?~  full-file.blk-resp  $(h +(h))
      =/  bbody=@t  q.data.u.full-file.blk-resp
      =/  bjon=(unit json)  (de:json:html bbody)
      ?~  bjon  $(h +(h))
      =/  ntx=@ud
        ?.  ?=([%o *] u.bjon)  0
        =/  result=(unit json)  (~(get by p.u.bjon) 'result')
        ?~  result  0
        ?.  ?=([%o *] u.result)  0
        =/  txs-j=(unit json)  (~(get by p.u.result) 'tx')
        ?~  txs-j  0
        ?.  ?=([%a *] u.txs-j)  0
        (lent p.u.txs-j)
      =/  flag=@t  ?:((gth ntx 1) ' *' '')
      =/  line=@t
        %+  rap  3
        :~  (ud-to-cord:btc-rpc h)
            '  0x'  hcord
            '  txs='  (ud-to-cord:btc-rpc ntx)
            flag
        ==
      $(h +(h), lines [line lines])
    --
^-  tool:tools
|%
++  name  'probe_scan'
++  description
  ^~  %-  crip
  ;:  weld
    "Walk back N blocks from the current groundwire tip and return a "
    "one-line-per-block summary (height, hash, tx count). Blocks with "
    "txs>1 are flagged with '*' (non-coinbase present — candidate "
    "witness-block). Defaults to 30 blocks."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  malt
  :~  ['count' [%string 'Number of blocks to scan back from tip (default 30)']]
      ['url' [%string 'Override RPC url. Optional.']]
      ['auth' [%string 'Override RPC auth header. Optional.']]
  ==
++  required  *(list @t)
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  arg-count=(unit @t)
    (~(deg jo:json-utils [%o args.st]) /count so:dejs:format)
  =/  arg-url=(unit @t)
    (~(deg jo:json-utils [%o args.st]) /url so:dejs:format)
  =/  arg-auth=(unit @t)
    (~(deg jo:json-utils [%o args.st]) /auth so:dejs:format)
  =/  count=@ud
    ?~  arg-count  30
    (fall (rush u.arg-count dem) 30)
  ;<  [cfg-url=@t cfg-auth=@t]  bind:m  read-groundwire-config
  =/  url=@t   ?~(arg-url cfg-url u.arg-url)
  =/  auth=@t  ?~(arg-auth cfg-auth u.arg-auth)
  ;<  mtip=(unit @ud)  bind:m  read-tip-height
  ?~  mtip
    (pure:m [%error '/groundwire.groundwire/height.ud missing — walker not running?'])
  =/  tip=@ud  u.mtip
  ?:  =(0 tip)
    (pure:m [%error 'tip height is 0 — walker has not polled yet'])
  =/  start=@ud  ?:((gte count tip) 1 +((sub tip count)))
  ;<  lines=wain  bind:m  (scan-range url auth start tip)
  (pure:m [%text (of-wain:format lines)])
--
