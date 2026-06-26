::  bip329: BIP-329 Wallet Labels
::  https://github.com/bitcoin/bips/blob/master/bip-0329.mediawiki
::
/<  wt  /lib/wallet-types.hoon
=,  wt
|%
+$  label-type  ?(%tx %addr %pubkey %input %output %xpub)
::
+$  label-entry
  $:  type=label-type
      ref=@t
      label=@t
      origin=(unit parsed-origin)
      spendable=(unit ?)
      more=(map @t json)
  ==
::
+$  labels
  $:  tx=(map @t (set label-entry))
      addr=(map @t (set label-entry))
      output=(map @t (set label-entry))
      input=(map @t (set label-entry))
      pubkey=(map @t (set label-entry))
      xpub=(map @t (set label-entry))
  ==
::
+$  parsed-origin
  $:  type=script-type
      fingerprint=@ux
      path=(list seg)
  ==
::
+$  script-type  ?(%wpkh %wsh %tr %sh %pkh %pk)
::
::  +to-descriptor: wallet script-type to BIP329 descriptor prefix
::
++  to-descriptor
  |=  st=script-type:wt
  ^-  script-type
  ?-  st
    %p2pkh       %pkh
    %p2sh-p2wpkh  %sh
    %p2wpkh      %wpkh
    %p2tr        %tr
  ==
::  +from-descriptor: BIP329 descriptor prefix to wallet script-type
::
++  from-descriptor
  |=  dt=script-type
  ^-  script-type:wt
  ?-  dt
    %pkh   %p2pkh
    %sh    %p2sh-p2wpkh
    %wpkh  %p2wpkh
    %tr    %p2tr
    %wsh   %p2wpkh
    %pk    %p2pkh
  ==
::  +addr-origin: extend account origin with chain + index for an address
::  e.g. wpkh([deadbeef]/84'/0'/0') + chain=0, idx=3 → wpkh([deadbeef]/84'/0'/0'/0/3)
::
++  addr-origin
  |=  [acct-og=parsed-origin chain=@ud idx=@ud]
  ^-  parsed-origin
  acct-og(path (weld path.acct-og `(list seg:wt)`~[[%.n chain] [%.n idx]]))
::  +render-origin: build origin string from parsed-origin
::
++  render-origin
  |=  og=parsed-origin
  ^-  @t
  =/  path-str=tape
    %-  zing
    %+  turn  path.og
    |=  s=seg
    "/{?:(p.s "{(scow %ud q.s)}'" (scow %ud q.s))}"
  (rap 3 ~[(scot %tas type.og) '([' (crip (hexn:http-utils fingerprint.og)) ']' (crip path-str) ')'])
::  +parse-origin: parse origin string to parsed-origin
::
++  parse-origin
  |=  raw=@t
  ^-  parsed-origin
  =/  txt=tape  (trip raw)
  =/  type-end=@ud  (need (find "(" txt))
  =/  stype=@ta  (crip (scag type-end txt))
  =/  inner=tape  (slag +(type-end) txt)
  =/  inner=tape  (scag (dec (lent inner)) inner)
  =/  parts=(list tape)
    |-
    =/  idx=(unit @ud)  (find "/" inner)
    ?~  idx  ~[inner]
    [(scag u.idx inner) $(inner (slag +(u.idx) inner))]
  ?>  ?=(^ parts)
  =/  fp-raw=tape  i.parts
  =/  fp-raw=tape
    ?:  &(=('[' (snag 0 fp-raw)) =(']' (rear fp-raw)))
      (slag 1 (scag (dec (lent fp-raw)) fp-raw))
    ?:  =('[' (snag 0 fp-raw))
      (slag 1 (scag (dec (lent fp-raw)) fp-raw))
    fp-raw
  =/  fp=@ux  (scan fp-raw hex)
  =/  segs=(list seg)
    %+  turn  t.parts
    |=  s=tape
    ^-  seg
    ?:  =(~ s)  [%.n 0]
    ?:  =("*" s)  [%.n 0]
    ?:  =('\'' (rear s))
      [%.y (slav %ud (crip (scag (dec (lent s)) s)))]
    [%.n (slav %ud (crip s))]
  [;;(script-type stype) fp segs]
::  +origin-ref: path-safe cord from parsed-origin
::  e.g. 'wpkh.deadbeef.84h.0h.0h'
::
++  origin-ref
  |=  og=parsed-origin
  ^-  @t
  =/  segs=tape
    %-  zing
    %+  turn  path.og
    |=  s=seg
    ".{(scow %ud q.s)}{?:(p.s "h" "")}"
  (rap 3 ~[(scot %tas type.og) '.' (crip (hexn:http-utils fingerprint.og)) (crip segs)])
::  +parse-origin-ref: path-safe cord back to parsed-origin
::  e.g. 'wpkh.deadbeef.84h.0h.0h' → [%wpkh 0xdead.beef ~[[%.y 84] [%.y 0] [%.y 0]]]
::
++  parse-origin-ref
  |=  ref=@t
  ^-  parsed-origin
  =/  txt=tape  (trip ref)
  =/  idx=@ud  (need (find "." txt))
  =/  stype=@ta  (crip (scag idx txt))
  =/  rest=tape  (slag +(idx) txt)
  =/  parts=(list tape)
    |-
    =/  dot=(unit @ud)  (find "." rest)
    ?~  dot  ~[rest]
    [(scag u.dot rest) $(rest (slag +(u.dot) rest))]
  ?>  ?=(^ parts)
  =/  fp=@ux  (scan i.parts hex)
  =/  segs=(list seg)
    %+  turn  t.parts
    |=  s=tape
    ^-  seg
    ?:  =('h' (rear s))
      [%.y (slav %ud (crip (scag (dec (lent s)) s)))]
    [%.n (slav %ud (crip s))]
  [;;(script-type stype) fp segs]
::  +la: CRUD core for labels structure
::  Usage: (~(get la my-labels) %output 'txid:0')
::
++  la
  |_  =labels
  ++  get
    |=  [typ=label-type ref=@t]
    ^-  (set label-entry)
    =/  type-map=(map @t (set label-entry))
      ?-  typ
        %tx      tx.labels
        %addr    addr.labels
        %output  output.labels
        %input   input.labels
        %pubkey  pubkey.labels
        %xpub    xpub.labels
      ==
    (fall (~(get by type-map) ref) ~)
  ::
  ++  texts
    |=  [typ=label-type ref=@t]
    ^-  (list @t)
    =/  entries=(set label-entry)  (get typ ref)
    %+  sort
      (turn ~(tap in entries) |=(e=label-entry label.e))
    |=([a=@t b=@t] (aor a b))
  ::
  ::  +read-kv: read value for a gwbtc: prefixed label
  ::  e.g. (read-kv %addr 'bc1q...' 'gwbtc:funded:') → `'50000'`
  ::
  ++  read-kv
    |=  [typ=label-type ref=@t prefix=@t]
    ^-  (unit @t)
    =/  entries=(list label-entry)
      ~(tap in (get typ ref))
    =/  prefix-tape=tape  (trip prefix)
    =/  prefix-len=@ud  (lent prefix-tape)
    |-
    ?~  entries  ~
    =/  lbl=tape  (trip label.i.entries)
    ?.  =(prefix-tape (scag prefix-len lbl))
      $(entries t.entries)
    `(crip (slag prefix-len lbl))
  ::
  ++  frozen
    |=  ref=@t
    ^-  ?
    =/  entries=(set label-entry)  (get %output ref)
    %+  lien  ~(tap in entries)
    |=(e=label-entry =([~ %.n] spendable.e))
  ::
  ++  put
    |=  entry=label-entry
    ^-  ^labels
    =/  type-map=(map @t (set label-entry))
      ?-  type.entry
        %tx      tx.labels
        %addr    addr.labels
        %output  output.labels
        %input   input.labels
        %pubkey  pubkey.labels
        %xpub    xpub.labels
      ==
    =/  existing=(set label-entry)
      (fall (~(get by type-map) ref.entry) ~)
    =/  filtered=(set label-entry)
      %-  sy
      %+  skip  ~(tap in existing)
      |=(e=label-entry =(label.e label.entry))
    =/  updated=(set label-entry)
      (~(put in filtered) entry)
    =/  new-type-map=(map @t (set label-entry))
      (~(put by type-map) ref.entry updated)
    ?-  type.entry
      %tx      labels(tx new-type-map)
      %addr    labels(addr new-type-map)
      %output  labels(output new-type-map)
      %input   labels(input new-type-map)
      %pubkey  labels(pubkey new-type-map)
      %xpub    labels(xpub new-type-map)
    ==
  ::
  ::  +put-kv: put a label, replacing any existing label with the same prefix
  ::  e.g. putting 'gwbtc:funded:60000' removes 'gwbtc:funded:50000' first
  ::  prefix is everything up to and including the last ':'
  ::
  ++  put-kv
    |=  entry=label-entry
    ^-  ^labels
    =/  lbl-tape=tape  (trip label.entry)
    =/  colon-idx=(unit @ud)
      =/  i=@ud  (dec (lent lbl-tape))
      |-
      ?:  =(':' (snag i lbl-tape))  `i
      ?:  =(0 i)  ~
      $(i (dec i))
    ?~  colon-idx  (put entry)
    =/  prefix=tape  (scag +(u.colon-idx) lbl-tape)
    =/  prefix-len=@ud  (lent prefix)
    =/  type-map=(map @t (set label-entry))
      ?-  type.entry
        %tx      tx.labels
        %addr    addr.labels
        %output  output.labels
        %input   input.labels
        %pubkey  pubkey.labels
        %xpub    xpub.labels
      ==
    =/  existing=(set label-entry)
      (fall (~(get by type-map) ref.entry) ~)
    =/  filtered=(set label-entry)
      %-  sy
      %+  skip  ~(tap in existing)
      |=  e=label-entry
      =(prefix (scag prefix-len (trip label.e)))
    =/  updated=(set label-entry)
      (~(put in filtered) entry)
    =/  new-type-map=(map @t (set label-entry))
      (~(put by type-map) ref.entry updated)
    ?-  type.entry
      %tx      labels(tx new-type-map)
      %addr    labels(addr new-type-map)
      %output  labels(output new-type-map)
      %input   labels(input new-type-map)
      %pubkey  labels(pubkey new-type-map)
      %xpub    labels(xpub new-type-map)
    ==
  ::
  ++  del
    |=  [typ=label-type ref=@t lbl=@t]
    ^-  ^labels
    =/  type-map=(map @t (set label-entry))
      ?-  typ
        %tx      tx.labels
        %addr    addr.labels
        %output  output.labels
        %input   input.labels
        %pubkey  pubkey.labels
        %xpub    xpub.labels
      ==
    =/  existing=(set label-entry)
      (fall (~(get by type-map) ref) ~)
    =/  filtered=(set label-entry)
      %-  sy
      %+  skip  ~(tap in existing)
      |=(e=label-entry =(label.e lbl))
    =/  new-type-map=(map @t (set label-entry))
      ?:  =(~ filtered)
        (~(del by type-map) ref)
      (~(put by type-map) ref filtered)
    ?-  typ
      %tx      labels(tx new-type-map)
      %addr    labels(addr new-type-map)
      %output  labels(output new-type-map)
      %input   labels(input new-type-map)
      %pubkey  labels(pubkey new-type-map)
      %xpub    labels(xpub new-type-map)
    ==
  ::
  ++  del-all
    |=  [typ=label-type ref=@t]
    ^-  ^labels
    =/  type-map=(map @t (set label-entry))
      ?-  typ
        %tx      tx.labels
        %addr    addr.labels
        %output  output.labels
        %input   input.labels
        %pubkey  pubkey.labels
        %xpub    xpub.labels
      ==
    =/  new-type-map=(map @t (set label-entry))
      (~(del by type-map) ref)
    ?-  typ
      %tx      labels(tx new-type-map)
      %addr    labels(addr new-type-map)
      %output  labels(output new-type-map)
      %input   labels(input new-type-map)
      %pubkey  labels(pubkey new-type-map)
      %xpub    labels(xpub new-type-map)
    ==
  ::
  ++  freeze
    |=  ref=@t
    ^-  ^labels
    =/  existing=(set label-entry)  (get %output ref)
    ?:  =(~ existing)
      (put [%output ref '' ~ `%.n ~])
    =/  updated=(list label-entry)
      (turn ~(tap in existing) |=(e=label-entry e(spendable `%.n)))
    =/  new-set=(set label-entry)  (sy updated)
    labels(output (~(put by output.labels) ref new-set))
  ::
  ++  thaw
    |=  ref=@t
    ^-  ^labels
    =/  existing=(set label-entry)  (get %output ref)
    ?:  =(~ existing)
      labels
    =/  updated=(list label-entry)
      %+  murn  ~(tap in existing)
      |=  e=label-entry
      ?:  =('' label.e)
        ~
      `e(spendable ~)
    ?:  =(~ updated)
      labels(output (~(del by output.labels) ref))
    labels(output (~(put by output.labels) ref (sy updated)))
  ::
  ++  export
    ^-  (list label-entry)
    %-  zing
    ^-  (list (list label-entry))
    :~  (zing (turn ~(val by tx.labels) |=(s=(set label-entry) ~(tap in s))))
        (zing (turn ~(val by addr.labels) |=(s=(set label-entry) ~(tap in s))))
        (zing (turn ~(val by output.labels) |=(s=(set label-entry) ~(tap in s))))
        (zing (turn ~(val by input.labels) |=(s=(set label-entry) ~(tap in s))))
        (zing (turn ~(val by pubkey.labels) |=(s=(set label-entry) ~(tap in s))))
        (zing (turn ~(val by xpub.labels) |=(s=(set label-entry) ~(tap in s))))
    ==
  ::
  ++  import
    |=  entries=(list label-entry)
    ^-  ^labels
    %+  roll  entries
    |=  [entry=label-entry acc=_labels]
    (~(put la acc) entry)
  --
--
