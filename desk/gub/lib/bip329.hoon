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
