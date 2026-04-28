/<  tools    /lib/nex/tools.hoon
/<  btc-rpc  /lib/btc-rpc.hoon
::  indexer-status: check the indexer's state — tip height, cached blocks,
::  and optionally dump a specific block's header + tx summary.
::
!:
^-  tool:tools
|%
++  name  'indexer_status'
++  description
  ^~  %-  crip
  ;:  weld
    "Check the bitcoin indexer's state. Shows current tip height and "
    "cached block count. Optionally pass a block height to see that "
    "block's header and transaction summary."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  malt
  :~  ['height' [%string 'Optional: specific block height to inspect']]
  ==
++  required  *(list @t)
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  arg-height=(unit @t)
    (~(deg jo:json-utils [%o args.st]) /height so:dejs:format)
  ::  read tip
  ;<  tip-seen=seen:nexus  bind:m
    (peek:io [%& %& /['indexer.indexer_app'] %'tip.ud'] ~)
  =/  tip=@ud
    ?.  ?=([%& %file *] tip-seen)  0
    =/  res  (mole |.(!<(@ud q.sage.p.tip-seen)))
    ?~  res  0
    u.res
  ::  read blocks directory
  ;<  blocks-seen=seen:nexus  bind:m
    (peek:io [%& %| /['indexer.indexer_app']/blocks] ~)
  =/  cached-heights=(list @ud)
    ?.  ?=([%& %ball *] blocks-seen)  ~
    %+  murn  ~(tap by dir.ball.p.blocks-seen)
    |=  [name=@ta *]
    (rush name dem)
  =/  sorted=(list @ud)
    (sort cached-heights lth)
  =/  num-cached=@ud  (lent sorted)
  ::  base status
  =/  range-line=@t
    ?~  sorted  'range: (none)'
    =/  last=@ud  (rear sorted)
    %+  rap  3
    :~  'range: '
        (crip ((d-co:co 1) i.sorted))
        ' - '
        (crip ((d-co:co 1) last))
    ==
  =/  status=wain
    :~  (rap 3 ~['indexer tip: ' (crip ((d-co:co 1) tip))])
        (rap 3 ~['cached blocks: ' (crip ((d-co:co 1) num-cached))])
        range-line
    ==
  ::  if specific height requested, show that block
  ?~  arg-height
    (pure:m [%text (of-wain:format status)])
  =/  h=(unit @ud)  (rush u.arg-height dem)
  ?~  h
    (pure:m [%error (crip "Invalid height: {(trip u.arg-height)}")])
  =/  height-dir=@ta  (crip ((d-co:co 1) u.h))
  ;<  header-seen=seen:nexus  bind:m
    (peek:io [%& %& /['indexer.indexer_app']/blocks/[height-dir] %'header.json'] ~)
  ?.  ?=([%& %file *] header-seen)
    %-  pure:m
    [%text (of-wain:format (snoc status (rap 3 ~['block ' (crip ((d-co:co 1) u.h)) ': not cached'])))]
  =/  header-json=json  !<(json q.sage.p.header-seen)
  ::  read txs dir
  ;<  txs-seen=seen:nexus  bind:m
    (peek:io [%& %| /['indexer.indexer_app']/blocks/[height-dir]/txs] ~)
  =/  tx-count=@ud
    ?.  ?=([%& %ball *] txs-seen)  0
    ?~  fil.ball.p.txs-seen  0
    ~(wyt by contents.u.fil.ball.p.txs-seen)
  =/  block-info=wain
    :~  ''
        (rap 3 ~['block ' (crip ((d-co:co 1) u.h)) ':'])
        (rap 3 ~['  header: ' (en:json:html header-json)])
        (rap 3 ~['  transactions: ' (crip ((d-co:co 1) tx-count))])
    ==
  (pure:m [%text (of-wain:format (weld status block-info))])
--
