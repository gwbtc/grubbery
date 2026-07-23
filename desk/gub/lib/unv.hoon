::  lib/unv.hoon
::
::  urb wallet/walt cores: derives a wallet from a seed, builds
::  commit/reveal outputs for each sotx kind, and signs them.
::
::  The reg-tester grub uses this to mint taproot outputs with
::  urb envelopes so the groundwire walker + urb-core can observe
::  them end-to-end.
::
::  Ported from groundwire's tests/unv.hoon (live wallet/walt
::  cores only — commented test scaffolding is dropped).
::
/<  urb          /lib/sur/urb.hoon
/<  ord          /lib/sur/ord.hoon
/<  scr          /lib/btc-script.hoon
/<  urb-encoder  /lib/urb-encoder.hoon
/<  gw           /lib/groundwire.hoon
/<  b173         /lib/bip/b173.hoon
/<  bip32        /lib/bip32.hoon
=*  raws  raws:gw
=>  |%
++  make-unv-script
  |=  sots=(list sotx:urb)
  ^-  script:scr
  =/  en-sots  (encode:urb-encoder sots)
  =/  tscr  (unv-to-script:en:urb-encoder en-sots)
  =/  wit   (en:scr tscr)
  =/  de-wit  (need (de:scr wit))
  ?>  =(de-wit tscr)
  =/  de-unv  (unv:de:urb-encoder de-wit)
  ?>  ?=([* ~] de-unv)
  =/  rol  (parse-roll:urb-encoder i.de-unv)
  ~|  %failed-to-parse-the-same
  ?>  =((turn rol |=([* sotx:urb] +<+)) sots)
  tscr
::
::  +make-spend-script: wrap a unv script in a taproot script-path leaf.
::
::  ORDER MATTERS: the envelope (rest) comes FIRST, then the key-checksig.
::  This matches the canonical format from gw-onboard.py:
::    OP_FALSE OP_IF "urb" <data> OP_ENDIF  <key> OP_CHECKSIG
::
::  The old (broken) order was key-checksig BEFORE the envelope, which
::  caused find-block-reveals to fail the quick-check (it looks for the
::  urb envelope marker at the start of the script).
::
++  make-spend-script
  |=  [int-key=@ rest=script:scr]
  ^-  script:scr:gw
  (snoc (snoc rest [%op-push ~ (flipb:gw 32^int-key)]) %op-checksig)
::
++  make-output
  |=  $:  int-key=keypair:gw
          val=(unit @ud)
          scr=(unit script:scr)
      ==
  ^-  output:tx:gw
  =|  out=output:tx:gw
  =?  spend-script.out  ?=(^ scr)
    `(make-spend-script x.pub.int-key u.scr)
  =.  script-pubkey.out
    ~(scriptpubkey p2tr:gw `x.pub.int-key spend-script.out ~)
  =?  value.out  ?=(^ val)  u.val
  %_  out
    internal-keys      int-key
  ==
::
+$  utxo  [outpoint:gw output:gw]
::
++  wallet
  |_  [sed=@ i=@ =utxo eny=@]
  +*  cor  .
  ++  nu
    |=  [sed=@ i=@ =^utxo]
    ^+  cor
    cor(sed sed, i i, utxo utxo, eny (shas %urb-test-wal-sed sed))
  ::
  ++  derive
    ^-  [keypair:gw _i]
    :_  +(i)
    [pub prv]:(derive-sequence:(from-seed:bip32 32^sed) ~[i 0 0])
  ::
  ++  build-output
    |=  scr=(unit script:scr)
    ^-  [output:gw _cor]
    =^  kp  i  derive
    :_  cor
    (make-output kp ~ scr)
  ::
  ++  spend
    |=  [out=output:gw]
    ^-  [byts _cor]
    =|  =tx:gw
    =.  tx  (~(add-input-1 build:gw tx) utxo ~ ~)
        :: by passing ~ we default to SIGHASH_DEFAULT, equivalent to
        :: SIGHASH_ALL, so when we sign this input later we'll commit
        :: to all and only the inputs and outputs we've added up to
        :: that point
    =/  new-value
      ?~  spend-script.utxo  (sub value.utxo 150)
      (sub value.utxo (add (lent u.spend-script.utxo) 400))
    =.  value.out  new-value
    =.  tx  (~(add-output-1 build:gw tx) out)
    =^  tx  eny  (~(finalize build:gw tx) eny)
    =/  raw=octs  (txn:encode:gw tx)
    =/  txid=@ux  (txid:encode:gw tx)
    =.  utxo  [[txid 0] out]
    [raw cor]
  --
::
++  compress-point  compress-point:secp256k1:secp:crypto
::
--
|%
++  walt
  |_  [sed=@uw lyf=_1 xtr=@ twk=(unit @) wal=_wallet]
  +*  cor  .
  ::
  ++  nu
    |=  [xtr=@ wal=_wallet]
    ^+  cor
    cor(sed sed:wal, xtr xtr, wal wal)
  ::
  ++  nu-twk
    |=  [xtr=@ twk=@ wal=_wallet]
    ^+  cor
    cor(sed sed:wal, xtr xtr, twk `twk, wal wal)
  ::
  ++  cac
    =<  ?>(&(?=(%c suite.+<) ?=(^ sek.+<)) .)
    =.  lyf  1
    =.  xtr  0
    %:  pit:nu:cric:crypto
        512
        sed
        %c
        ?^(twk u.twk (rap 3 ~[lyf %btc %ord %gw %test]))
        :: xtr
    ==
  ::
  ++  fig  `@p`fig:ex:cac(lyf 1)
  ++  unv-tx
    |%
    ++  skim
      |%
      ++  spawn
        |=  $:  out=[spk=output:gw vout=(unit vout:ord) =off:ord tej=off:ord]
            ==
        =/  utxo  utxo:wal
        ::  spkh = SHA-256(script-pubkey || value) of the FUNDING UTXO
        ::  (the precommit output). This matches gw-onboard.py's
        ::  compute_spkh(funding_address, funding_value_sats).
        =/  funding-out  +.utxo
        =/  en-out  (can 3 script-pubkey.funding-out 8^value.funding-out ~)
        =/  hax-out  (shay (add 8 p.script-pubkey.funding-out) en-out)
        ^-  single:skim-sotx:urb
        [%spawn pub:ex:cac ~ out(spk hax-out)]
      ::
      ++  keys
        |=  bec=?
        ^+  [*single:skim-sotx:urb cor]
        =.  cor  cor(lyf +(lyf))
        [%keys pub:ex:cac bec]^cor
      ::
      ++  escape
        |=  her=@p
        ^-  single:skim-sotx:urb
        [%escape her ~]
      ::
      ++  adopt
        |=  her=@p
        ^-  single:skim-sotx:urb
        [%adopt her]
      ::
      ++  fief
        |=  fef=(unit ^^fief)
        ^-  single:skim-sotx:urb
        [%fief fef]
      ::
      ++  batch
        |=  sots=(list single:skim-sotx:urb)
        ^-  skim-sotx:urb
        [%batch sots]
      --
::
    ++  sign-batch
      |=  sots=(list single:skim-sotx:urb)
      ^-  sotx:urb
      =/  sot  (batch:skim +<)
      =/  ent  (skim:encode:urb-encoder sot)
      =/  sig  (sign-octs-raw:ed:crypto 512^(shaz ent) [sgn.pub sgn.sek]:+<:cac)
      [fig^[~ sig] sot]
    ::
    ++  sign-skim
      |=  sot=skim-sotx:urb
      ^-  sotx:urb
      =/  ent  (skim:encode:urb-encoder sot)
      =/  sig  (sign-octs-raw:ed:crypto 512^(shaz ent) [sgn.pub sgn.sek]:+<:cac)
      [fig^[~ sig] sot]
    ::
    ++  spawn
      |=  $:  out=[spk=output:gw vout=(unit vout:ord) =off:ord tej=off:ord]
          ==
      ^-  sotx:urb
      =/  sot=skim-sotx:urb  (spawn:skim +<)
      (sign-skim sot)
    ::
    ++  keys
      |=  bec=?
      ^+  [*sotx:urb cor]
      =.  cor  cor(lyf +(lyf))
      =^  sot=skim-sotx:urb  cor  (keys:skim +<)
      (sign-skim sot)^cor
    ::
    ++  escape
      |=  her=@p
      ^-  sotx:urb
      [fig^~ (escape:skim +<)]
    ::
    ++  cancel-escape
      |=  her=@p
      ^-  sotx:urb
      [fig^~ [%cancel-escape her]]
    ::
    ++  adopt
      |=  her=@p
      ^-  sotx:urb
      [fig^~ (adopt:skim +<)]
    ::
    ++  reject
      |=  her=@p
      ^-  sotx:urb
      [fig^~ [%reject her]]
    ::
    ++  detach
      |=  her=@p
      ^-  sotx:urb
      [fig^~ [%detach her]]
    ::
    ++  fief
      |=  fef=(unit ^fief)
      ^-  sotx:urb
      [fig^~ (fief:skim +<)]
    ::
    ++  set-mang
      |=  man=(unit mang:urb)
      ^-  sotx:urb
      [fig^~ [%set-mang man]]
    --
  ++  btc
    |%
    ++  make-key-out
      =^  out  wal  (build-output:wal ~)
      out^cor
    ::
    ++  spend
      |=  [out=output:gw]
      ^-  [byts _cor]
      =^  res  wal  (spend:wal out)
      [res cor]
    ::
    ++  spawn
      |=  $:  out=[spk=output:gw vout=(unit vout:ord) =off:ord tej=off:ord]
          ==
      ^-  [output:gw _cor]
      =^  out  wal
        %-  build-output:wal
        `(make-unv-script (spawn:unv-tx +<) ~)
      out^cor
    ::
    ++  keys
      |=  bec=?
      ^-  [output:gw _cor]
      =^  sot  cor  (keys:unv-tx +<)
      =^  out  wal
        %-  build-output:wal
        `(make-unv-script sot ~)
      out^cor
    ::
    ++  escape
      |=  her=@p
      ^-  [output:gw _cor]
      =^  out  wal
        %-  build-output:wal
        `(make-unv-script (escape:unv-tx +<) ~)
      out^cor
    ::
    ++  adopt
      |=  her=@p
      ^-  [output:gw _cor]
      =^  out  wal
        %-  build-output:wal
        `(make-unv-script (adopt:unv-tx +<) ~)
      out^cor
    ::
    ++  fief
      |=  fef=(unit ^fief)
      ^-  [output:gw _cor]
      =^  out  wal
        %-  build-output:wal
        `(make-unv-script (fief:unv-tx +<) ~)
      out^cor
    --
  --
--
