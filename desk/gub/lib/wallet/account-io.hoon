::  wallet account IO helpers
::
::  Pure helpers for address/tx operations, chain scanning,
::  and address refresh processes. No steps/prefix — callers
::  pass data directly or use ancestor-road for file access.
::
/<  wt   /lib/wallet-types.hoon
/<  bip32  /lib/bip32.hoon
/<  bip39  /lib/bip39.hoon
/<  bech32  /lib/bech32.hoon
/<  drft  /lib/tx/draft.hoon
/<  fees  /lib/tx/fees.hoon
/<  b329  /lib/bip329.hoon
=,  wt
|%
::  +num: render @ud as plain decimal cord (no dots)
::
++  num  |=(n=@ud (crip (a-co:co n)))
::  +has-account: check if an account ref exists in labels
::
++  has-account
  |=  [=labels:b329 ref=@t]
  ^-  ?
  ?|  ?=(^ (get-acct-origin labels ref))
      ?=(^ (~(read-kv la:b329 labels) %xpub ref 'gwbtc:account:'))
  ==
::  +derive-xprv: derive account xprv from secrets
::  checks standalone xprvs first, then derives from wallet seed
::
++  derive-xprv
  |=  [=labels:b329 =secrets ref=@t]
  ^-  (unit @t)
  ::  check standalone xprvs first
  =/  standalone=(unit @t)  (~(get by xprvs.secrets) ref)
  ?^  standalone  standalone
  ::  try deriving from wallet seed
  =/  og=(unit parsed-origin:b329)  (get-acct-origin labels ref)
  ?~  og  ~
  =/  =network  (get-acct-network labels ref)
  =/  wallet-xpub=(unit @t)  (fp-to-xpub labels fingerprint.u.og)
  ?~  wallet-xpub  ~
  =/  sd=(unit seed)  (~(get by seeds.secrets) u.wallet-xpub)
  ?~  sd  ~
  =/  seed-bytes=byts
    ?-  -.u.sd
      %t  64^(to-seed:bip39 (trip phrase.u.sd) "")
      %q  =/  val=@  `@`secret.u.sd  [(met 3 val) val]
    ==
  =/  master  (from-seed:bip32 seed-bytes)
  =/  path-str=tape
    %-  zing
    :-  "m"
    %+  turn  path.u.og
    |=  s=seg
    ^-  tape
    %+  weld  "/"
    %+  weld  (a-co:co q.s)
    ?:(p.s "'" ~)
  =/  derived  (derive-path:master path-str)
  `(crip (prv-extended:derived (to-bip-network network)))
::  +derive-key: get best available key for address derivation
::  returns xprv if available, else the xpub ref (for watch-only)
::
++  derive-key
  |=  [=labels:b329 =secrets ref=@t]
  ^-  (unit @t)
  =/  xprv=(unit @t)  (derive-xprv labels secrets ref)
  ?^  xprv  xprv
  ::  watch-only: use the xpub ref itself for public derivation
  ?.  (has-account labels ref)  ~
  `ref
::  +build-addr-data: enrich address list with info/utxos from labels
::
++  build-addr-data
  |=  [addrs=(list [idx=@ud addr=@t]) =labels:b329]
  ^-  (list [idx=@ud address-data])
  %+  turn  addrs
  |=  [idx=@ud addr=@t]
  =/  info=(unit address-info)  (read-addr-info labels addr)
  =/  utxos=(list utxo)  (read-utxos labels addr)
  [idx [addr info utxos]]
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
::  +label-derived-addr: add a BIP-329 addr label with origin for a derived address
::  for standalone accounts (no origin), tags with gwbtc:derived-from:{ref}
::
++  label-derived-addr
  |=  $:  =labels:b329
          addr=@t
          lbl=@t
          acct-og=(unit parsed-origin:b329)
          chain=@ud
          index=@ud
          acct-ref=@t
      ==
  ^-  labels:b329
  =/  addr-og=(unit parsed-origin:b329)
    (bind acct-og |=(og=parsed-origin:b329 (addr-origin:b329 og chain index)))
  =.  labels  (~(put la:b329 labels) [%addr addr lbl addr-og ~ ~])
  ?.  ?=(~ acct-og)  labels
  =/  chain-tag=@t  ?:(=(0 chain) 'recv' 'chng')
  =/  df-lbl=@t  (rap 3 ~['gwbtc:derived-from:' acct-ref ':' chain-tag ':' (crip (a-co:co index))])
  (~(put la:b329 labels) [%addr addr df-lbl ~ ~ ~])
::  +label-addr-info: write addr labels for mempool.space address info
::
++  label-addr-info
  |=  [=labels:b329 addr=@t info=address-info]
  ^-  labels:b329
  =/  l  labels
  =.  l  (~(put-kv la:b329 l) [%addr addr (rap 3 ~['gwbtc:funded:' (num funded.info)]) ~ ~ ~])
  =.  l  (~(put-kv la:b329 l) [%addr addr (rap 3 ~['gwbtc:spent:' (num spent.info)]) ~ ~ ~])
  =.  l  (~(put-kv la:b329 l) [%addr addr (rap 3 ~['gwbtc:tx-count:' (num tx-count.info)]) ~ ~ ~])
  =.  l  (~(put-kv la:b329 l) [%addr addr (rap 3 ~['gwbtc:mempool:funded:' (num mem-funded.info)]) ~ ~ ~])
  =.  l  (~(put-kv la:b329 l) [%addr addr (rap 3 ~['gwbtc:mempool:spent:' (num mem-spent.info)]) ~ ~ ~])
  =.  l  (~(put-kv la:b329 l) [%addr addr (rap 3 ~['gwbtc:mempool:tx-count:' (num mem-tx-count.info)]) ~ ~ ~])
  ?~  last-check.info  l
  (~(put-kv la:b329 l) [%addr addr (rap 3 ~['gwbtc:last-checked:' (num (unt:chrono:userlib u.last-check.info))]) ~ ~ ~])
::  +label-utxos: write output labels for UTXOs
::
++  label-utxos
  |=  [=labels:b329 addr=@t utxos=(list utxo)]
  ^-  labels:b329
  ?~  utxos  labels
  =/  ref=@t  (rap 3 ~[txid.i.utxos ':' (num vout.i.utxos)])
  =.  labels  (~(put-kv la:b329 labels) [%output ref (rap 3 ~['gwbtc:value:' (num value.i.utxos)]) ~ ~ ~])
  =.  labels  (~(put-kv la:b329 labels) [%output ref (rap 3 ~['gwbtc:addr:' addr]) ~ ~ ~])
  =.  labels
    ?-  -.tx-status.i.utxos
        %unconfirmed
      (~(put-kv la:b329 labels) [%output ref 'gwbtc:confirmed:~' ~ ~ ~])
        %confirmed
      (~(put-kv la:b329 labels) [%output ref (rap 3 ~['gwbtc:confirmed:' (num block-height.tx-status.i.utxos)]) ~ ~ ~])
    ==
  $(utxos t.utxos)
::  +label-txs: write tx labels for transactions
::
++  label-txs
  |=  [=labels:b329 txs=(list transaction)]
  ^-  labels:b329
  =/  l  labels
  |-
  ?~  txs  l
  =/  tx  i.txs
  =.  l
    ?-  -.tx-status.tx
        %unconfirmed
      (~(put-kv la:b329 l) [%tx txid.tx 'gwbtc:confirmed:~' ~ ~ ~])
        %confirmed
      =.  l  (~(put-kv la:b329 l) [%tx txid.tx (rap 3 ~['gwbtc:confirmed:' (num block-height.tx-status.tx)]) ~ ~ ~])
      (~(put-kv la:b329 l) [%tx txid.tx (rap 3 ~['gwbtc:block-hash:' block-hash.tx-status.tx]) ~ ~ ~])
    ==
  =.  l  ?~(fee.tx l (~(put-kv la:b329 l) [%tx txid.tx (rap 3 ~['gwbtc:fee:' (num u.fee.tx)]) ~ ~ ~]))
  =.  l  ?~(size.tx l (~(put-kv la:b329 l) [%tx txid.tx (rap 3 ~['gwbtc:size:' (num u.size.tx)]) ~ ~ ~]))
  ::  label inputs
  =.  l
    =/  ins=(list tx-input)  inputs.tx
    |-
    ?~  ins  l
    =/  in-ref=@t  (rap 3 ~[spent-txid.i.ins ':' (num spent-vout.i.ins)])
    =.  l  (~(put-kv la:b329 l) [%input in-ref (rap 3 ~['gwbtc:tx:' txid.tx]) ~ ~ ~])
    =.  l
      ?~  prevout.i.ins  l
      =.  l  (~(put-kv la:b329 l) [%input in-ref (rap 3 ~['gwbtc:value:' (num value.u.prevout.i.ins)]) ~ ~ ~])
      (~(put-kv la:b329 l) [%input in-ref (rap 3 ~['gwbtc:addr:' address.u.prevout.i.ins]) ~ ~ ~])
    $(ins t.ins)
  ::  label outputs
  =.  l
    =/  outs=(list tx-output)  outputs.tx
    =/  vout=@ud  0
    |-
    ?~  outs  l
    =/  out-ref=@t  (rap 3 ~[txid.tx ':' (num vout)])
    =.  l  (~(put-kv la:b329 l) [%output out-ref (rap 3 ~['gwbtc:value:' (num value.i.outs)]) ~ ~ ~])
    =.  l  (~(put-kv la:b329 l) [%output out-ref (rap 3 ~['gwbtc:addr:' address.i.outs]) ~ ~ ~])
    $(outs t.outs, vout +(vout))
  $(txs t.txs)
::  +read-addr-info: reconstruct address-info from labels
::
++  read-addr-info
  |=  [=labels:b329 addr=@t]
  ^-  (unit address-info)
  =/  funded=(unit @t)  (~(read-kv la:b329 labels) %addr addr 'gwbtc:funded:')
  =/  spent=(unit @t)   (~(read-kv la:b329 labels) %addr addr 'gwbtc:spent:')
  =/  tc=(unit @t)      (~(read-kv la:b329 labels) %addr addr 'gwbtc:tx-count:')
  ?:  |(?=(~ funded) ?=(~ spent) ?=(~ tc))  ~
  =/  funded-ud=(unit @ud)  (rush u.funded dem)
  =/  spent-ud=(unit @ud)   (rush u.spent dem)
  =/  tc-ud=(unit @ud)      (rush u.tc dem)
  ?:  |(?=(~ funded-ud) ?=(~ spent-ud) ?=(~ tc-ud))  ~
  =/  lc=(unit @t)      (~(read-kv la:b329 labels) %addr addr 'gwbtc:last-checked:')
  =/  lc-ud=(unit @ud)  (biff lc |=(v=@t (rush v dem)))
  =/  lc-da=(unit @da)
    ?~  lc-ud  ~
    `(from-unix:chrono:userlib u.lc-ud)
  =/  mf=(unit @t)  (~(read-kv la:b329 labels) %addr addr 'gwbtc:mempool:funded:')
  =/  ms=(unit @t)  (~(read-kv la:b329 labels) %addr addr 'gwbtc:mempool:spent:')
  =/  mt=(unit @t)  (~(read-kv la:b329 labels) %addr addr 'gwbtc:mempool:tx-count:')
  =/  mf-ud=@ud  (fall (biff mf |=(v=@t (rush v dem))) 0)
  =/  ms-ud=@ud  (fall (biff ms |=(v=@t (rush v dem))) 0)
  =/  mt-ud=@ud  (fall (biff mt |=(v=@t (rush v dem))) 0)
  `[u.tc-ud u.funded-ud u.spent-ud mt-ud mf-ud ms-ud lc-da]
::  +has-new-broadcast: check if address has broadcast notification newer than last-check
::
++  has-new-broadcast
  |=  [=labels:b329 addr=@t]
  ^-  ?
  =/  info=(unit address-info)  (read-addr-info labels addr)
  =/  last-checked=@ud
    ?~  info  0
    ?~  last-check.u.info  0
    (unt:chrono:userlib u.last-check.u.info)
  =/  entries=(list label-entry:b329)
    ~(tap in (~(get la:b329 labels) %addr addr))
  =/  prefix=tape  "gwbtc:broadcast:"
  =/  prefix-len=@ud  (lent prefix)
  |-
  ?~  entries  %.n
  =/  lbl=tape  (trip label.i.entries)
  ?.  =(prefix (scag prefix-len lbl))
    $(entries t.entries)
  ::  extract trailing unix timestamp after last ':'
  =/  rest=tape  (slag prefix-len lbl)
  =/  parts=(list tape)  (split-on-colon rest)
  =/  ts=(unit @ud)
    ?~  parts  ~
    (rush (crip (rear parts)) dem)
  ?~  ts  $(entries t.entries)
  ?:  (gth u.ts last-checked)  %.y
  $(entries t.entries)
::  +split-on-colon: split tape on ':' character
::
++  split-on-colon
  |=  t=tape
  ^-  (list tape)
  =/  acc=tape  ~
  =/  out=(list tape)  ~
  |-
  ?~  t
    ?~  acc  (flop out)
    (flop [(flop acc) out])
  ?:  =(i.t ':')
    $(t t.t, acc ~, out [(flop acc) out])
  $(t t.t, acc [i.t acc])
::  +read-utxos: reconstruct UTXOs for an address from output labels
::
++  read-utxos
  |=  [=labels:b329 addr=@t]
  ^-  (list utxo)
  =/  all-outputs=(list [@t (set label-entry:b329)])
    ~(tap by output.labels)
  %+  murn  all-outputs
  |=  [ref=@t entries=(set label-entry:b329)]
  ^-  (unit utxo)
  ::  check if this output belongs to our address
  =/  out-addr=(unit @t)  (~(read-kv la:b329 labels) %output ref 'gwbtc:addr:')
  ?.  &(?=(^ out-addr) =(addr u.out-addr))  ~
  ::  skip if spent (input label exists for this outpoint)
  ?.  =(~ (~(get la:b329 labels) %input ref))  ~
  ::  parse ref as txid:vout
  =/  colon=(unit @ud)  (find ":" (trip ref))
  ?~  colon  ~
  =/  txid=@t  (crip (scag u.colon (trip ref)))
  =/  vout-t=@t  (crip (slag +(u.colon) (trip ref)))
  =/  vout=(unit @ud)  (rush vout-t dem)
  ?~  vout  ~
  =/  value=(unit @t)  (~(read-kv la:b329 labels) %output ref 'gwbtc:value:')
  ?~  value  ~
  =/  value-ud=(unit @ud)  (rush u.value dem)
  ?~  value-ud  ~
  =/  status=tx-status
    =/  conf=(unit @t)  (~(read-kv la:b329 labels) %output ref 'gwbtc:confirmed:')
    ?~  conf  [%unconfirmed ~]
    ?:  =('~' u.conf)  [%unconfirmed ~]
    =/  bh=(unit @ud)  (rush u.conf dem)
    ?~  bh  [%unconfirmed ~]
    [%confirmed '' u.bh]
  `[txid u.vout u.value-ud status]
::  +read-tx: reconstruct a transaction from tx/input/output labels
::
++  read-tx
  |=  [=labels:b329 txid=@t]
  ^-  (unit transaction)
  =/  entries=(set label-entry:b329)
    (~(get la:b329 labels) %tx txid)
  ?:  =(~ entries)  ~
  =/  status=tx-status
    =/  conf=(unit @t)  (~(read-kv la:b329 labels) %tx txid 'gwbtc:confirmed:')
    ?~  conf  [%unconfirmed ~]
    ?:  =('~' u.conf)  [%unconfirmed ~]
    =/  bh=(unit @ud)  (rush u.conf dem)
    ?~  bh  [%unconfirmed ~]
    =/  block-hash=(unit @t)  (~(read-kv la:b329 labels) %tx txid 'gwbtc:block-hash:')
    [%confirmed (fall block-hash '') u.bh]
  =/  fee=(unit @ud)
    =/  f=(unit @t)  (~(read-kv la:b329 labels) %tx txid 'gwbtc:fee:')
    ?~  f  ~
    (rush u.f dem)
  =/  size=(unit @ud)
    =/  s=(unit @t)  (~(read-kv la:b329 labels) %tx txid 'gwbtc:size:')
    ?~  s  ~
    (rush u.s dem)
  ::  find inputs: scan all input labels for gwbtc:tx:<our-txid>
  =/  inputs=(list tx-input)
    =/  all-inputs=(list [@t (set label-entry:b329)])
      ~(tap by input.labels)
    %+  murn  all-inputs
    |=  [ref=@t *]
    ^-  (unit tx-input)
    =/  in-tx=(unit @t)  (~(read-kv la:b329 labels) %input ref 'gwbtc:tx:')
    ?.  &(?=(^ in-tx) =(txid u.in-tx))  ~
    ::  parse ref as spent-txid:spent-vout
    =/  colon=(unit @ud)  (find ":" (trip ref))
    ?~  colon  ~
    =/  st=@t  (crip (scag u.colon (trip ref)))
    =/  sv=(unit @ud)  (rush (crip (slag +(u.colon) (trip ref))) dem)
    ?~  sv  ~
    =/  pv=(unit @t)  (~(read-kv la:b329 labels) %input ref 'gwbtc:value:')
    =/  pa=(unit @t)  (~(read-kv la:b329 labels) %input ref 'gwbtc:addr:')
    =/  prevout=(unit tx-output)
      ?:  |(?=(~ pv) ?=(~ pa))  ~
      =/  pvud=(unit @ud)  (rush u.pv dem)
      ?~  pvud  ~
      `[u.pvud u.pa]
    `[st u.sv prevout]
  ::  find outputs: scan output labels for this txid prefix
  =/  outputs=(list tx-output)
    =/  all-outputs=(list [@t (set label-entry:b329)])
      ~(tap by output.labels)
    =/  txid-prefix=tape  (weld (trip txid) ":")
    =/  txid-prefix-len=@ud  (lent txid-prefix)
    %+  murn  all-outputs
    |=  [ref=@t *]
    ^-  (unit tx-output)
    ?.  =(txid-prefix (scag txid-prefix-len (trip ref)))  ~
    =/  v=(unit @t)  (~(read-kv la:b329 labels) %output ref 'gwbtc:value:')
    =/  a=(unit @t)  (~(read-kv la:b329 labels) %output ref 'gwbtc:addr:')
    ?:  |(?=(~ v) ?=(~ a))  ~
    =/  vud=(unit @ud)  (rush u.v dem)
    ?~  vud  ~
    `[u.vud u.a]
  `[txid inputs outputs status fee size]
::  +read-account-addrs: enumerate addresses for an account from labels
::  Scans addr labels matching the account's origin prefix
::
++  read-account-addrs
  |=  [=labels:b329 acct-og=parsed-origin:b329]
  ^-  [recv=(list [idx=@ud addr=@t]) chng=(list [idx=@ud addr=@t])]
  =/  acct-plen=@ud  (lent path.acct-og)
  =/  all=(list [@t (set label-entry:b329)])  ~(tap by addr.labels)
  =/  recv=(list [idx=@ud addr=@t])  ~
  =/  chng=(list [idx=@ud addr=@t])  ~
  |-
  ?~  all
    :_  (sort chng |=([[a=@ud *] [b=@ud *]] (lth a b)))
    (sort recv |=([[a=@ud *] [b=@ud *]] (lth a b)))
  =/  [addr=@t entries=(set label-entry:b329)]  i.all
  =/  og=(unit parsed-origin:b329)
    =/  el=(list label-entry:b329)  ~(tap in entries)
    |-
    ?~  el  ~
    ?^  origin.i.el  origin.i.el
    $(el t.el)
  ?~  og  $(all t.all)
  ?.  =(type.acct-og type.u.og)  $(all t.all)
  ?.  =(fingerprint.acct-og fingerprint.u.og)  $(all t.all)
  ?.  =(path.acct-og (scag acct-plen path.u.og))  $(all t.all)
  =/  suffix=(list seg:wt)  (slag acct-plen path.u.og)
  ?.  ?=([^ ^ ~] suffix)  $(all t.all)
  =/  chain=@ud  q.i.suffix
  =/  idx=@ud  q.i.t.suffix
  ?:  =(0 chain)
    $(all t.all, recv [[idx addr] recv])
  $(all t.all, chng [[idx addr] chng])
::  +read-standalone-addrs: find addresses for standalone accounts
::  scans addr labels for gwbtc:derived-from:{ref}:{chain}:{idx}
::
++  read-standalone-addrs
  |=  [=labels:b329 acct-ref=@t]
  ^-  [recv=(list [idx=@ud addr=@t]) chng=(list [idx=@ud addr=@t])]
  =/  prefix=tape  (trip (rap 3 ~['gwbtc:derived-from:' acct-ref ':']))
  =/  prefix-len=@ud  (lent prefix)
  =/  all=(list [@t (set label-entry:b329)])  ~(tap by addr.labels)
  =/  recv=(list [idx=@ud addr=@t])  ~
  =/  chng=(list [idx=@ud addr=@t])  ~
  |-
  ?~  all
    :_  (sort chng |=([[a=@ud *] [b=@ud *]] (lth a b)))
    (sort recv |=([[a=@ud *] [b=@ud *]] (lth a b)))
  =/  [addr=@t entries=(set label-entry:b329)]  i.all
  =/  el=(list label-entry:b329)  ~(tap in entries)
  =/  found=(unit [chain=@t idx=@ud])
    |-
    ?~  el  ~
    =/  ltape=tape  (trip label.i.el)
    ?.  =(prefix (scag prefix-len ltape))
      $(el t.el)
    =/  suffix=tape  (slag prefix-len ltape)
    =/  col=(unit @ud)  (find ":" suffix)
    ?~  col  $(el t.el)
    =/  chain=@t  (crip (scag u.col suffix))
    =/  idx=@ud  (rash (crip (slag +(u.col) suffix)) dem)
    `[chain idx]
  ?~  found  $(all t.all)
  ?:  =(chain.u.found 'recv')
    $(all t.all, recv [[idx.u.found addr] recv])
  $(all t.all, chng [[idx.u.found addr] chng])
::  +build-tx-map: reconstruct tx-map from labels for a set of addresses
::
++  build-tx-map
  |=  [=labels:b329 addrs=(set @t)]
  ^-  tx-map
  =/  txids=(set @t)  ~
  ::  find txids from output labels matching our addresses
  =/  all-outputs=(list [@t (set label-entry:b329)])
    ~(tap by output.labels)
  =.  txids
    |-
    ?~  all-outputs  txids
    =/  [ref=@t *]  i.all-outputs
    =/  out-addr=(unit @t)  (~(read-kv la:b329 labels) %output ref 'gwbtc:addr:')
    ?.  &(?=(^ out-addr) (~(has in addrs) u.out-addr))
      $(all-outputs t.all-outputs)
    =/  colon=(unit @ud)  (find ":" (trip ref))
    ?~  colon  $(all-outputs t.all-outputs)
    =/  txid=@t  (crip (scag u.colon (trip ref)))
    $(all-outputs t.all-outputs, txids (~(put in txids) txid))
  ::  also find txids from input labels matching our addresses
  =/  all-inputs=(list [@t (set label-entry:b329)])
    ~(tap by input.labels)
  =.  txids
    |-
    ?~  all-inputs  txids
    =/  [ref=@t *]  i.all-inputs
    =/  in-addr=(unit @t)  (~(read-kv la:b329 labels) %input ref 'gwbtc:addr:')
    ?.  &(?=(^ in-addr) (~(has in addrs) u.in-addr))
      $(all-inputs t.all-inputs)
    =/  in-tx=(unit @t)  (~(read-kv la:b329 labels) %input ref 'gwbtc:tx:')
    ?~  in-tx  $(all-inputs t.all-inputs)
    $(all-inputs t.all-inputs, txids (~(put in txids) u.in-tx))
  ::  build tx-map from found txids
  %-  ~(gas by *tx-map)
  %+  murn  ~(tap in txids)
  |=  txid=@t
  =/  tx=(unit transaction)  (read-tx labels txid)
  ?~  tx  ~
  `[txid u.tx]
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
  |=  progress=json
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  marker-json=json
    ?:  ?=([%o *] progress)
      [%o (~(put by p.progress) 'paused' b+%.y)]
    (pairs:enjs:format ~[['paused' b+%.y]])
  ;<  ~  bind:m  (replace:io marker-json)
  |-
  ;<  resumed=?  bind:m  take-pause-event
  ?.  resumed  $
  ::  remove paused flag on resume
  ;<  ~  bind:m  (replace:io (~(del jo:json-utils marker-json) /paused))
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
  |=  [progress=json address=@t =network]
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
      %pause   ;<  ~  bind:m  (pause-loop progress)  $
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
  =/  mem-tc=(unit @ud)
    (mole |.((ni:dejs:format (~(got jo:json-utils data) /'mempool_stats'/'tx_count'))))
  =/  mem-funded=(unit @ud)
    (mole |.((ni:dejs:format (~(got jo:json-utils data) /'mempool_stats'/'funded_txo_sum'))))
  =/  mem-spent=(unit @ud)
    (mole |.((ni:dejs:format (~(got jo:json-utils data) /'mempool_stats'/'spent_txo_sum'))))
  ?~  tx-count  (pure:m ~)
  ?~  funded    (pure:m ~)
  ?~  spent     (pure:m ~)
  ;<  now=@da  bind:m  get-time:io
  %:  pure:m  :-  ~
  :*  u.tx-count  u.funded  u.spent
      (fall mem-tc 0)  (fall mem-funded 0)  (fall mem-spent 0)
      `now
  ==  ==
::  +fetch-address-data: full address fetch — info, UTXOs, txs
::  returns fetched data for the caller to label and save
::
++  fetch-address-data
  |=  [addr=@t =network]
  =/  m  (fiber:fiber:nexus ,[(unit address-info) (list utxo) (list transaction)])
  ^-  form:m
  =/  base-url=tape  (mempool-base-url network)
  ::  fetch address info
  =/  info-url=@t  (crip (weld base-url (trip addr)))
  ;<  ~  bind:m  (send-request:io [%'GET' info-url ~[['Accept' 'application/json']] ~])
  ;<  info-resp=client-response:iris  bind:m  take-http
  ;<  now=@da  bind:m  get-time:io
  =/  new-info=(unit address-info)  (parse-info-response info-resp now)
  ::  fetch UTXOs
  =/  utxo-url=@t  (crip :(weld base-url (trip addr) "/utxo"))
  ;<  ~  bind:m  (send-request:io [%'GET' utxo-url ~[['Accept' 'application/json']] ~])
  ;<  utxo-resp=client-response:iris  bind:m  take-http
  =/  utxos=(list utxo)  (parse-utxo-response utxo-resp)
  ::  fetch transactions
  =/  txs-url=@t  (crip :(weld base-url (trip addr) "/txs"))
  ;<  ~  bind:m  (send-request:io [%'GET' txs-url ~[['Accept' 'application/json']] ~])
  ;<  txs-resp=client-response:iris  bind:m  take-http
  =/  txs=(list transaction)  (parse-txs-response txs-resp)
  (pure:m [new-info utxos txs])
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
  =/  mem-tc=(unit @ud)  (mole |.((ni:dejs:format (~(got jo:json-utils data) /'mempool_stats'/'tx_count'))))
  =/  mem-funded=(unit @ud)  (mole |.((ni:dejs:format (~(got jo:json-utils data) /'mempool_stats'/'funded_txo_sum'))))
  =/  mem-spent=(unit @ud)  (mole |.((ni:dejs:format (~(got jo:json-utils data) /'mempool_stats'/'spent_txo_sum'))))
  ?:  |(?=(~ tc) ?=(~ funded) ?=(~ spent))  ~
  `[u.tc u.funded u.spent (fall mem-tc 0) (fall mem-funded 0) (fall mem-spent 0) `now]
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
::  +scan-chain: derive addresses and scan chain for activity
::
++  scan-chain
  |=  $:  acct-ref=@t
          chain=?(%receiving %change)
          =network
          start-idx=@ud
          start-gap=@ud
          main-road=road:tarball
      ==
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  is-change=?  =(chain %change)
  =/  gap-limit=@ud  20
  =/  scan-idx=@ud  start-idx
  =/  gap=@ud  start-gap
  |-
  ?:  (gte gap gap-limit)
    ~&  [%scan-chain %done chain scan-idx gap]
    (pure:m ~)
  ~&  [%scan-chain chain scan-idx gap=gap]
  ;<  ~  bind:m
    %:  poke:io  main-road
      :-  [/ %json]
      %-  pairs:enjs:format
      :~  ['action' s+'derive-address']
          ['account' s+acct-ref]
          ['chain' s+?:(is-change 'change' 'receiving')]
          ['index' (numb:enjs:format scan-idx)]
      ==
    ==
  ::  read back the derived address from labels
  ;<  lbls=labels:b329  bind:m
    =/  lm  (fiber:fiber:nexus ,labels:b329)
    =/  lbl-road=road:tarball  [%& %& /apps/'wallet.wallet_app' %'labels.wallet_labels']
    ;<  lbl-view=view:nexus  bind:lm  (peek:io lbl-road ~)
    ?.  ?=([%file *] lbl-view)  (pure:lm *labels:b329)
    (pure:lm (fall (mole |.(!<(labels:b329 (need-vase:tarball sang.lbl-view)))) *labels:b329))
  =/  og=(unit parsed-origin:b329)  (get-acct-origin lbls acct-ref)
  ?~  og  (pure:m ~)
  =/  addrs  (read-account-addrs lbls u.og)
  =/  chain-addrs=(list [idx=@ud addr=@t])
    ?:(is-change chng.addrs recv.addrs)
  =/  addr=(unit @t)
    |-
    ?~  chain-addrs  ~
    ?:  =(idx.i.chain-addrs scan-idx)  `addr.i.chain-addrs
    $(chain-addrs t.chain-addrs)
  ?~  addr
    ~&  [%scan-chain %addr-not-found scan-idx]
    $(scan-idx +(scan-idx), gap +(gap))
  ::  update scan progress in proc file
  =/  phase-tape=@t  ?:(is-change 'chng' 'recv')
  ;<  cur=json  bind:m  (get-state-as:io json)
  =/  scan-prog=json
    %-  ~(gas jo:json-utils cur)
    :~  [/phase s+phase-tape]
        [/idx (numb:enjs:format scan-idx)]
        [/gap (numb:enjs:format gap)]
    ==
  ;<  ~  bind:m  (replace:io scan-prog)
  ;<  ~  bind:m  (sleep:io `@dr`(div ~s1 1.000))
  ::  full refresh: fetch info + UTXOs + txs
  ;<  [new-info=(unit address-info) utxos=(list utxo) txs=(list transaction)]  bind:m
    (fetch-address-data u.addr network)
  ::  check gap
  ?~  new-info
    ~&  [%scan-chain %no-info u.addr]
    $(scan-idx +(scan-idx), gap +(gap))
  ~&  [%scan-chain %fetched u.addr tx-count=tx-count.u.new-info]
  ?:  =(0 tx-count.u.new-info)
    $(scan-idx +(scan-idx), gap +(gap))
  ::  active address — label and save
  ;<  fresh-lbls=labels:b329  bind:m
    =/  lm  (fiber:fiber:nexus ,labels:b329)
    =/  lbl-road=road:tarball  [%& %& /apps/'wallet.wallet_app' %'labels.wallet_labels']
    ;<  lbl-view=view:nexus  bind:lm  (peek:io lbl-road ~)
    ?.  ?=([%file *] lbl-view)  (pure:lm *labels:b329)
    (pure:lm (fall (mole |.(!<(labels:b329 (need-vase:tarball sang.lbl-view)))) *labels:b329))
  =/  fresh-lbls=labels:b329  (label-addr-info fresh-lbls u.addr u.new-info)
  =/  fresh-lbls=labels:b329  (label-utxos fresh-lbls u.addr utxos)
  =/  fresh-lbls=labels:b329  (label-txs fresh-lbls txs)
  =/  lbl-road=road:tarball  [%& %& /apps/'wallet.wallet_app' %'labels.wallet_labels']
  ;<  ~  bind:m  (over:io lbl-road [[/wallet %labels] fresh-lbls])
  $(scan-idx +(scan-idx), gap 0)
::
++  collect-utxo-inputs
  |=  [recv=(list [@ud address-data]) chng=(list [@ud address-data]) =script-type]
  ^-  (list utxo-input:drft)
  =/  spend=spend:fees  script-type
  =/  all=(list [@ud address-data])  (weld recv chng)
  %-  zing
  %+  turn  all
  |=  [idx=@ud a=address-data]
  %+  turn  utxos.a
  |=  u=utxo
  ^-  utxo-input:drft
  [txid.u vout.u value.u spend]
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
  (~(put la:b329 labels) [%xpub xpub (rap 3 ~['gwbtc:last-offered:' (num idx)]) ~ ~ ~])
::  +get-next-offer-index: next address index to offer
::
++  get-next-offer-index
  |=  [recv=(list [idx=@ud addr=@t]) =labels:b329 xpub=@t]
  ^-  @ud
  =/  unused-idx=@ud
    ?~  recv  0
    +(idx:(rear recv))
  =/  last=(unit @ud)  (get-last-offered labels xpub)
  ?~  last  unused-idx
  (max unused-idx +(u.last))
::  +addr-to-ship: resolve address to ship from offered labels
::
++  addr-to-ship
  |=  [=labels:b329 addr=@t]
  ^-  (unit @t)
  =/  entries=(list label-entry:b329)
    ~(tap in (~(get la:b329 labels) %addr addr))
  |-
  ?~  entries  ~
  =/  lbl=tape  (trip label.i.entries)
  ?:  =("gwbtc:offered:to:" (scag 17 lbl))
    `(crip (slag 17 lbl))
  ?:  =("gwbtc:offered:from:" (scag 19 lbl))
    `(crip (slag 19 lbl))
  $(entries t.entries)
::  +get-last-change: read last-change index from xpub labels
::
++  get-last-change
  |=  [=labels:b329 xpub=@t]
  ^-  (unit @ud)
  =/  entries=(list label-entry:b329)
    ~(tap in (~(get la:b329 labels) %xpub xpub))
  =/  prefix=tape  "gwbtc:last-change:"
  =/  prefix-len=@ud  (lent prefix)
  |-
  ?~  entries  ~
  =/  lbl=tape  (trip label.i.entries)
  ?.  =(prefix (scag prefix-len lbl))
    $(entries t.entries)
  (rush (crip (slag prefix-len lbl)) dem)
::  +set-last-change: write last-change index as xpub label
::
++  set-last-change
  |=  [=labels:b329 xpub=@t idx=@ud]
  ^-  labels:b329
  =/  entries=(list label-entry:b329)
    ~(tap in (~(get la:b329 labels) %xpub xpub))
  =/  prefix=tape  "gwbtc:last-change:"
  =/  prefix-len=@ud  (lent prefix)
  =.  labels
    |-
    ?~  entries  labels
    =/  lbl=tape  (trip label.i.entries)
    ?:  =(prefix (scag prefix-len lbl))
      $(entries t.entries, labels (~(del la:b329 labels) %xpub xpub label.i.entries))
    $(entries t.entries)
  (~(put la:b329 labels) [%xpub xpub (rap 3 ~['gwbtc:last-change:' (num idx)]) ~ ~ ~])
::  +get-next-change-index: next change address index
::
++  get-next-change-index
  |=  [chng=(list [idx=@ud addr=@t]) =labels:b329 xpub=@t]
  ^-  @ud
  =/  unused-idx=@ud
    ?~  chng  0
    +(idx:(rear chng))
  =/  last=(unit @ud)  (get-last-change labels xpub)
  ?~  last  unused-idx
  (max unused-idx +(u.last))
::  +get-wallet-name: read gwbtc:wallet:X label for wallet xpub
::
++  get-wallet-name
  |=  [=labels:b329 xpub=@t]
  ^-  @t
  =/  entries=(list label-entry:b329)
    ~(tap in (~(get la:b329 labels) %xpub xpub))
  =/  prefix=tape  "gwbtc:wallet:"
  =/  prefix-len=@ud  (lent prefix)
  |-
  ?~  entries  'Unnamed Wallet'
  =/  lbl=tape  (trip label.i.entries)
  ?.  =(prefix (scag prefix-len lbl))
    $(entries t.entries)
  (crip (slag prefix-len lbl))
::  +get-acct-network: read gwbtc:network:X label for account ref
::
++  get-acct-network
  |=  [=labels:b329 ref=@t]
  ^-  network
  =/  entries=(list label-entry:b329)
    ~(tap in (~(get la:b329 labels) %xpub ref))
  =/  prefix=tape  "gwbtc:network:"
  =/  prefix-len=@ud  (lent prefix)
  |-
  ?~  entries  %testnet3
  =/  lbl=tape  (trip label.i.entries)
  ?.  =(prefix (scag prefix-len lbl))
    $(entries t.entries)
  ;;(network (slav %tas (crip (slag prefix-len lbl))))
::  +get-acct-name: read gwbtc:account:X label for account ref
::
++  get-acct-name
  |=  [=labels:b329 ref=@t]
  ^-  @t
  =/  entries=(list label-entry:b329)
    ~(tap in (~(get la:b329 labels) %xpub ref))
  =/  prefix=tape  "gwbtc:account:"
  =/  prefix-len=@ud  (lent prefix)
  |-
  ?~  entries  'Unnamed Account'
  =/  lbl=tape  (trip label.i.entries)
  ?.  =(prefix (scag prefix-len lbl))
    $(entries t.entries)
  (crip (slag prefix-len lbl))
::  +get-acct-origin: read parsed-origin from label entries for account ref
::
++  get-acct-origin
  |=  [=labels:b329 ref=@t]
  ^-  (unit parsed-origin:b329)
  =/  entries=(list label-entry:b329)
    ~(tap in (~(get la:b329 labels) %xpub ref))
  |-
  ?~  entries  ~
  ?^  origin.i.entries  origin.i.entries
  $(entries t.entries)
::  +get-acct-script-type: derive script-type from origin or label
::
++  get-acct-script-type
  |=  [=labels:b329 ref=@t]
  ^-  script-type
  =/  og=(unit parsed-origin:b329)  (get-acct-origin labels ref)
  ?^  og  (from-descriptor:b329 type.u.og)
  ::  standalone account: check gwbtc:script-type: label
  =/  st=(unit @t)  (~(read-kv la:b329 labels) %xpub ref 'gwbtc:script-type:')
  ?~  st  %p2wpkh
  ?+  u.st  %p2wpkh
    %p2pkh        %p2pkh
    %p2sh-p2wpkh  %p2sh-p2wpkh
    %p2wpkh       %p2wpkh
    %p2tr         %p2tr
  ==
::  +get-acct-wallet: derive wallet fingerprint from origin
::
++  get-acct-wallet
  |=  [=labels:b329 ref=@t]
  ^-  @ux
  =/  og=(unit parsed-origin:b329)  (get-acct-origin labels ref)
  ?~  og  0x0
  fingerprint.u.og
::  +fp-to-xpub: find wallet xpub label ref matching a fingerprint
::
++  fp-to-xpub
  |=  [=labels:b329 fp=@ux]
  ^-  (unit @t)
  =/  xpubs=(list [@t (set label-entry:b329)])
    ~(tap by xpub.labels)
  |-
  ?~  xpubs  ~
  =/  [ref=@t *]  i.xpubs
  =/  key  (mole |.((from-extended:bip32 (trip ref))))
  ?~  key  $(xpubs t.xpubs)
  ?.  =(fp fingerprint:u.key)  $(xpubs t.xpubs)
  `ref
::  +origin-to-xpub: find account xpub matching a fingerprint + derivation path
::
++  origin-to-xpub
  |=  [=labels:b329 fp=@ux segs=(list seg:wt)]
  ^-  (unit @t)
  =/  xpubs=(list [@t (set label-entry:b329)])
    ~(tap by xpub.labels)
  |-
  ?~  xpubs  ~
  =/  [ref=@t entries=(set label-entry:b329)]  i.xpubs
  =/  el=(list label-entry:b329)  ~(tap in entries)
  =/  match=?
    |-
    ?~  el  %.n
    ?~  origin.i.el  $(el t.el)
    ?&  =(fp fingerprint.u.origin.i.el)
        =(segs path.u.origin.i.el)
    ==
  ?.  match  $(xpubs t.xpubs)
  `ref
::  +make-acct-labels: create labels for a new account
::
++  make-acct-labels
  |=  $:  =labels:b329
          ref=@t
          name=@t
          =network
          og=parsed-origin:b329
      ==
  ^-  labels:b329
  =/  name-lbl=@t  (rap 3 ~['gwbtc:account:' name])
  =/  net-lbl=@t  (rap 3 ~['gwbtc:network:' ;;(@t network)])
  =.  labels  (~(put la:b329 labels) [%xpub ref name-lbl `og ~ ~])
  (~(put la:b329 labels) [%xpub ref net-lbl ~ ~ ~])
::  +make-standalone-labels: create labels for a standalone account
::  (no origin/parent wallet — watch-only or imported signing)
::
++  make-standalone-labels
  |=  $:  =labels:b329
          ref=@t
          name=@t
          =network
          =script-type
      ==
  ^-  labels:b329
  =/  name-lbl=@t  (rap 3 ~['gwbtc:account:' name])
  =/  net-lbl=@t  (rap 3 ~['gwbtc:network:' ;;(@t network)])
  =/  st-lbl=@t  (rap 3 ~['gwbtc:script-type:' ;;(@t script-type)])
  =.  labels  (~(put la:b329 labels) [%xpub ref name-lbl ~ ~ ~])
  =.  labels  (~(put la:b329 labels) [%xpub ref net-lbl ~ ~ ~])
  (~(put la:b329 labels) [%xpub ref st-lbl ~ ~ ~])
::  +get-tapscript-addrs: find all tapscript addresses for a parent address
::
++  get-tapscript-addrs
  |=  [=labels:b329 parent-addr=@t]
  ^-  (list @t)
  =/  prefix=tape  (trip (rap 3 ~['gwbtc:tapscript-of:' parent-addr]))
  =/  all=(list [@t (set label-entry:b329)])  ~(tap by addr.labels)
  =/  result=(list @t)  ~
  |-
  ?~  all  result
  =/  [addr=@t entries=(set label-entry:b329)]  i.all
  =/  el=(list label-entry:b329)  ~(tap in entries)
  =/  found=?
    |-
    ?~  el  %.n
    ?:  =(prefix (trip label.i.el))  %.y
    $(el t.el)
  ?:  found
    $(all t.all, result [addr result])
  $(all t.all)
::  +get-tapscript-name: get the name label for a tapscript address
::
++  get-tapscript-name
  |=  [=labels:b329 ts-addr=@t]
  ^-  @t
  =/  prefix=tape  "gwbtc:tapscript-name:"
  =/  prefix-len=@ud  (lent prefix)
  =/  entries=(unit (set label-entry:b329))  (~(get by addr.labels) ts-addr)
  ?~  entries  ''
  =/  el=(list label-entry:b329)  ~(tap in u.entries)
  |-
  ?~  el  ''
  =/  ltape=tape  (trip label.i.el)
  ?:  =(prefix (scag prefix-len ltape))
    (crip (slag prefix-len ltape))
  $(el t.el)
::  +find-addr-account: find the account ref that owns an address
::
::  Checks origin (wallet-derived) and derived-from (standalone) labels.
::
++  find-addr-account
  |=  [=labels:b329 addr=@t]
  ^-  (unit @t)
  =/  entries=(unit (set label-entry:b329))  (~(get by addr.labels) addr)
  ?~  entries  ~
  =/  el=(list label-entry:b329)  ~(tap in u.entries)
  ::  check for origin (wallet-derived address)
  =/  og-acct=(unit @t)
    |-
    ?~  el  ~
    ?~  origin.i.el  $(el t.el)
    ::  the account ref is the xpub with a matching origin prefix
    ::  scan xpub entries for matching fingerprint
    =/  fp=@ux  fingerprint.u.origin.i.el
    (fp-to-xpub labels fp)
  ?^  og-acct  og-acct
  ::  check for derived-from (standalone address)
  =/  df-prefix=tape  "gwbtc:derived-from:"
  =/  df-len=@ud  (lent df-prefix)
  =/  el=(list label-entry:b329)  ~(tap in u.entries)
  |-
  ?~  el  ~
  =/  ltape=tape  (trip label.i.el)
  ?.  =(df-prefix (scag df-len ltape))
    $(el t.el)
  ::  format: gwbtc:derived-from:{ref}:{chain}:{idx}
  ::  extract ref (everything between prefix and next colon after ref)
  =/  suffix=tape  (slag df-len ltape)
  =/  col=(unit @ud)  (find ":" suffix)
  ?~  col  $(el t.el)
  `(crip (scag u.col suffix))
::  +get-addr-derivation: get account, chain, and index for an address
::
::  Returns account ref + chain + index from origin or derived-from labels.
::
++  get-addr-derivation
  |=  [=labels:b329 addr=@t]
  ^-  (unit [acct=@t chain=?(%recv %chng) idx=@ud])
  =/  entries=(unit (set label-entry:b329))  (~(get by addr.labels) addr)
  ?~  entries  ~
  =/  el=(list label-entry:b329)  ~(tap in u.entries)
  ::  try origin path: last two segs are chain and index
  =/  from-origin=(unit [acct=@t chain=?(%recv %chng) idx=@ud])
    |-
    ?~  el  ~
    ?~  origin.i.el  $(el t.el)
    =/  segs=(list seg:wt)  path.u.origin.i.el
    =/  len=@ud  (lent segs)
    ?.  (gte len 2)  $(el t.el)
    =/  chain-seg=seg:wt  (snag (sub len 2) segs)
    =/  idx-seg=seg:wt    (snag (dec len) segs)
    =/  fp=@ux  fingerprint.u.origin.i.el
    ::  account path is address path minus last 2 segs (chain + index)
    =/  acct-path=(list seg:wt)  (scag (sub len 2) segs)
    =/  acct=(unit @t)  (origin-to-xpub labels fp acct-path)
    ?~  acct  $(el t.el)
    =/  chain=?(%recv %chng)  ?:(=(0 q.chain-seg) %recv %chng)
    `[u.acct chain q.idx-seg]
  ?^  from-origin  from-origin
  ::  try derived-from: gwbtc:derived-from:{ref}:{chain}:{idx}
  =/  df-prefix=tape  "gwbtc:derived-from:"
  =/  df-len=@ud  (lent df-prefix)
  =/  el=(list label-entry:b329)  ~(tap in u.entries)
  |-
  ?~  el  ~
  =/  ltape=tape  (trip label.i.el)
  ?.  =(df-prefix (scag df-len ltape))
    $(el t.el)
  ::  format: gwbtc:derived-from:{ref}:{chain}:{idx}
  =/  suffix=tape  (slag df-len ltape)
  =/  col1=(unit @ud)  (find ":" suffix)
  ?~  col1  $(el t.el)
  =/  ref=@t  (crip (scag u.col1 suffix))
  =/  rest=tape  (slag +(u.col1) suffix)
  =/  col2=(unit @ud)  (find ":" rest)
  ?~  col2  $(el t.el)
  =/  chain-t=tape  (scag u.col2 rest)
  =/  idx-t=tape  (slag +(u.col2) rest)
  =/  chain=?(%recv %chng)  ?:  =("recv" chain-t)  %recv  %chng
  =/  idx=@ud  (fall (rush (crip idx-t) dem) 0)
  `[ref chain idx]
--
