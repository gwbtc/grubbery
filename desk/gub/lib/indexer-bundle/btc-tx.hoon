::  btc-tx.hoon
::  Raw Bitcoin transaction encoding/decoding utilities.
::  Minimal port of groundwire's lib/bitcoin.hoon ++txu arm — just
::  enough to decode a segwit-encoded raw tx hexb into a dataw:tx.
::
/<  sur  /lib/sur/bitcoin.hoon
/<  bcu  /lib/bitcoin-utils.hoon
=,  sur
=,  bcu
|%
++  txu
  |%
  ++  de
    |%
    ++  nversion
      |=  b=hexb
      ^-  [nversion=@ud rest=hexb]
      :-  dat:(flip:byt (take:byt 4 b))
      (drop:byt 4 b)
    ::
    ++  segwit
      |=  b=hexb
      ^-  [segwit=(unit @ud) rest=hexb]
      ?.  =(1^0x0 (take:byt 1 b))
        [~ b]
      :-  [~ dat:(take:byt 2 b)]
      (drop:byt 2 b)
    ::
    ++  script-sig
      |=  b=hexb
      ^-  [sig=hexb rest=hexb]
      =^  siglen=hexb  b  (de:csiz b)
      :-  (take:byt dat.siglen b)
      (drop:byt dat.siglen b)
    ::
    ++  sequence
      |=  b=hexb
      ^-  [seq=hexb rest=hexb]
      [(flip:byt (take:byt 4 b)) (drop:byt 4 b)]
    ::
    ++  inputs
      |=  b=hexb
      ^-  [is=(list input:tx) rest=hexb]
      |^
      =|  acc=(list input:tx)
      =^  count  b  (dea:csiz b)
      |-
      ?:  =(0 count)  [acc b]
      =^  i  b  (input b)
      $(acc (snoc acc i), count (dec count))
      ::
      ++  input
        |=  b=hexb
        ^-  [i=input:tx rest=hexb]
        =/  txid  dat:(flip:byt (take:byt 32 b))
        =/  pos   dat:(flip:byt (take:byt 4 (drop:byt 32 b)))
        =^  sig=hexb  b  (script-sig (drop:byt 36 b))
        =^  seq=hexb  b  (sequence b)
        :_  b
        [txid pos seq ?:((gth wid.sig 0) `sig ~) ~]
      --
    ::
    ++  outputs
      |=  b=hexb
      ^-  [os=(list output:tx) rest=hexb]
      =|  acc=(list output:tx)
      =^  count  b  (dea:csiz b)
      |-
      ?:  =(0 count)  [acc b]
      =/  value  (flip:byt (take:byt 8 b))
      =^  scriptlen  b  (dea:csiz (drop:byt 8 b))
      %=  $
          acc  %+  snoc  acc
               :-  (take:byt scriptlen b)
               dat.value
          b  (drop:byt scriptlen b)
          count  (dec count)
      ==
    --
  ::  +parse-witness: decode witness stack
  ::
  ++  parse-witness
    |=  b=hexb
    ^-  (pair (list hexb) hexb)
    =|  acc=witness:tx
    =+  i=0
    =^  n  b  (read-compact-size b)
    |-
    ?:  =(i n)  [acc b]
    =^  wid  b  (read-compact-size b)
    =^  dat  b  (read-bytes wid b)
    $(acc (snoc acc dat), i +(i))
  ::  +read-bytes: take n bytes, drop n bytes
  ::
  ++  read-bytes
    |=  [n=@ b=hexb]
    ^-  (pair hexb hexb)
    [(take:byt n b) (drop:byt n b)]
  ::  +read-compact-size: decode CompactSize
  ::
  ++  read-compact-size
    |=  b=hexb
    ^-  [a=@ rest=hexb]
    =^  s  b  (read-bytes 1 b)
    ?:  (lth +.s 0xfd)  [+.s b]
    ~|  %invalid-compact-size
    =/  len=bloq
      ?+  +.s  !!
        %0xfd  1
        %0xfe  2
        %0xff  3
      ==
    =^  k  b  (read-bytes (bex len) b)
    :_  b
    dat:(flip:byt k)
  ::
  ++  decodew
    |=  b=hexb
    ^-  dataw:tx
    =^  nversion  b
      (nversion:de b)
    =^  segwit  b
      (segwit:de b)
    =^  inputs  b
      (inputs:de b)
    =^  outputs  b
      (outputs:de b)
    =>  %=(. inputs `(list input:tx)`inputs)
    ?~  segwit
      =/  locktime=@ud
        dat:(take:byt 4 (flip:byt b))
      :-  (turn inputs |=(input:tx `inputw:tx`[~ +<]))
      [outputs locktime nversion segwit]
    ~|  %invalid-witness-section
    =|  inputsw=(list inputw:tx)
    |-  ^-  dataw:tx
    ?:  =(4 wid.b)
      ?>  ?=(~ inputs)
      [(flop inputsw) outputs dat:(flip:byt b) nversion segwit]
    ?>  ?=(^ inputs)
    =^  witness  b  (parse-witness b)
    $(inputs t.inputs, inputsw [witness i.inputs]^inputsw)
  --
--
