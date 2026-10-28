::  btc-rpc.hoon: groundwire JSON-RPC helpers
::
::  Shared between the groundwire nexus and MCP probe tools. Provides
::  request building, response parsing, block parsing from verbosity-2
::  getblock, and a pure trace-block renderer.
::
/<  btc     /lib/sur/bitcoin.hoon
/<  btc-tx  /lib/btc-tx.hoon
=,  btc
|%
::  Default regtest connection (localhost groundwire, spvwallet creds).
::
++  default-url   `@t`'http://localhost:18443/'
++  default-auth  `@t`'Basic Yml0Y29pbnJwYzpiaXRjb2lucnBj'
::
::  Build a groundwire JSON-RPC request.
::
++  rpc-request
  |=  [url=@t auth=@t method=@t params=@t]
  ^-  request:http
  :*  method=%'POST'
      url=url
      ^=  header-list
      :~  'Content-Type'^'application/json'
          'Authorization'^auth
      ==
      ^=  body
      %-  some
      %-  as-octs:mimes:html
      %+  rap  3
      :~  '{"jsonrpc":"1.0","id":"gub","method":"'
          method
          '","params":'
          params
          '}'
      ==
  ==
::
::  Parse a hex cord (no 0x prefix) into @ux.
::
++  parse-hex-cord
  |=  c=@t
  ^-  @ux
  =/  res=(unit octs)  (de:base16:mimes:html c)
  ?~  res  0x0
  `@ux`q.u.res
::
::  Parse a hex cord into a bitcoin hexb: [wid=@ dat=@ux].
::
++  hex-cord-to-hexb
  |=  c=@t
  ^-  hexb
  =/  res=(unit octs)  (de:base16:mimes:html c)
  ?~  res  0^0x0
  [p.u.res `@ux`q.u.res]
::
::  Compute the block reward at a given height (halves every 210k).
::
++  reward-from-height
  |=  h=@ud
  ^-  @ud
  (div 5.000.000.000 (bex (div h 210.000)))
::
::  Parse getblockcount JSON response: {"result":N,"error":null,"id":"..."}
::
++  parse-height
  |=  =json
  ^-  (unit @ud)
  ?.  ?=([%o *] json)  ~
  =/  result=(unit ^json)  (~(get by p.json) 'result')
  ?~  result  ~
  ?.  ?=([%n *] u.result)  ~
  (rush p.u.result dem)
::
::  Parse a JSON-RPC response whose result is a string: {"result":"...", ...}
::
++  parse-string-result
  |=  =json
  ^-  (unit @t)
  ?.  ?=([%o *] json)  ~
  =/  result=(unit ^json)  (~(get by p.json) 'result')
  ?~  result  ~
  ?.  ?=([%s *] u.result)  ~
  `p.u.result
::
::  Parse a generatetoaddress response: {"result":["hex1","hex2",...], ...}
::
++  parse-hash-list
  |=  =json
  ^-  (unit (list @ux))
  ?.  ?=([%o *] json)  ~
  =/  result=(unit ^json)  (~(get by p.json) 'result')
  ?~  result  ~
  ?.  ?=([%a *] u.result)  ~
  =/  hs  p.u.result
  ?.  (levy hs |=(j=^json ?=([%s *] j)))  ~
  :-  ~
  %+  turn  hs
  |=  j=^json
  ?>  ?=([%s *] j)
  (parse-hex-cord p.j)
::
::  Parse one tx from a getblock verbosity-2 response. Uses the
::  raw "hex" field and decodes it with btc-tx's decodew, so we
::  get full typed dataw:tx without touching the vin/vout JSON.
::
++  parse-tx
  |=  =json
  ^-  (unit tx:btc)
  ?.  ?=([%o *] json)  ~
  =/  txid-j=(unit ^json)  (~(get by p.json) 'txid')
  ?~  txid-j  ~
  ?.  ?=([%s *] u.txid-j)  ~
  =/  hex-j=(unit ^json)  (~(get by p.json) 'hex')
  ?~  hex-j  ~
  ?.  ?=([%s *] u.hex-j)  ~
  =/  txid=@ux  (parse-hex-cord p.u.txid-j)
  =/  raw=hexb  (hex-cord-to-hexb p.u.hex-j)
  `[txid (decodew:txu:btc-tx raw)]
::
::  Parse a getblock verbosity-2 response into a typed block:btc.
::  Shape: {"result":{"hash":"...","height":N,"tx":[...], ...}, ...}
::
++  parse-block
  |=  =json
  ^-  (unit block:btc)
  ?.  ?=([%o *] json)  ~
  =/  result=(unit ^json)  (~(get by p.json) 'result')
  ?~  result  ~
  ?.  ?=([%o *] u.result)  ~
  =/  rmap  p.u.result
  =/  hash-j=(unit ^json)  (~(get by rmap) 'hash')
  ?~  hash-j  ~
  ?.  ?=([%s *] u.hash-j)  ~
  =/  height-j=(unit ^json)  (~(get by rmap) 'height')
  ?~  height-j  ~
  ?.  ?=([%n *] u.height-j)  ~
  =/  txs-j=(unit ^json)  (~(get by rmap) 'tx')
  ?~  txs-j  ~
  ?.  ?=([%a *] u.txs-j)  ~
  =/  hax=@ux  (parse-hex-cord p.u.hash-j)
  =/  height=(unit @ud)  (rush p.u.height-j dem)
  ?~  height  ~
  =/  mtxs=(list (unit tx:btc))  (turn p.u.txs-j parse-tx)
  ?.  (levy mtxs |=(m=(unit tx:btc) ?=(^ m)))  ~
  =/  txs=(list tx:btc)  (turn mtxs need)
  `[hax (reward-from-height u.height) u.height txs]
::
::  Render an octs as a lowercase hex cord (no 0x prefix, no dots).
::
++  render-hex-octs
  |=  a=octs
  ^-  @t
  (crip ((x-co:co (mul 2 p.a)) q.a))
::
::  Render a @ud as a cord.
::
++  ud-to-cord
  |=  n=@ud
  ^-  @t
  (crip ((d-co:co 1) n))
::
::  Pure helper: build a wain tracing one block's non-coinbase txs
::  with every input's full witness stack rendered as lowercase hex.
::  Returns ~ for coinbase-only blocks so callers can skip them.
::
++  trace-block
  |=  [blk=block:btc reveals-count=@ud]
  ^-  wain
  =/  non-cb=(list tx:btc)  ?~(txs.blk ~ t.txs.blk)
  ?~  non-cb  ~
  =/  hash-hex=@t  (render-hex-octs 32^hax.blk)
  =/  hdr=@t
    %+  rap  3
    :~  '=== block '
        (ud-to-cord height.blk)
        ' hash=0x'
        hash-hex
        ' txs='
        (ud-to-cord (lent txs.blk))
        ' reveals='
        (ud-to-cord reveals-count)
    ==
  :-  hdr
  %-  zing
  %+  turn  non-cb
  |=  t=tx:btc
  ^-  wain
  =/  txid-hex=@t  (render-hex-octs 32^id.t)
  =/  tx-hdr=@t
    %+  rap  3
    :~  '  tx 0x'
        txid-hex
        ' ins='
        (ud-to-cord (lent is.t))
        ' outs='
        (ud-to-cord (lent os.t))
    ==
  :-  tx-hdr
  %-  zing
  =|  in-idx=@ud
  |-  ^-  (list wain)
  ?~  is.t  ~
  =/  iw=inputw:tx:btc  i.is.t
  =/  wit-count=@ud  (lent witness.iw)
  =/  in-hdr=@t
    %+  rap  3
    :~  '    in '
        (ud-to-cord in-idx)
        ' prev=0x'
        (render-hex-octs 32^txid.iw)
        ':'
        (ud-to-cord pos.iw)
        ' wits='
        (ud-to-cord wit-count)
    ==
  =/  wit-lines=wain
    %+  turn  `(list hexb)`witness.iw
    |=  h=hexb
    ^-  @t
    %+  rap  3
    :~  '      '
        (ud-to-cord wid.h)
        'b 0x'
        (render-hex-octs [wid.h dat.h])
    ==
  :-  [in-hdr wit-lines]
  $(is.t t.is.t, in-idx +(in-idx))
--
