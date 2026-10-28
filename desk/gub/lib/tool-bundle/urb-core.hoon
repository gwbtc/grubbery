::  %urb-core
::
::  This is where most of the heavy block processing in %urb-watcher happens.
::  Before engaging with this codebase, make sure that you understand
::  Taproot script-path spends and ordinal inscriptions.
::  See lib/sur/urb and lib/urb-encoder for more details on the types at play here.
::  The main ones to be aware of are:
::  - sont, a satpoint
::  - sotx, a comet attestation
::  - a list of sotx is often called a "sots." be warned that
::    this same name can appear on multiple parsing layers.
::
::  The state of urb-core is an index
::  of urb-relevant transactions with their
::  associated prevouts and inscriptions.
::
::  The logic flow here is:
::  1. %urb-watcher receives a block from RPC and then
::     calls ++find-block-reveals, which filters it
::     down to txs containing urb reveals.
::  2. %urb-watcher asynchronously fetches the prevout
::     values for each tx in the filtered block.
::  3. %urb-watcher checks each tx for %spawn sotx.
::     If it finds one, it fetches a commit and
::     precommit transaction. See the %spawn case
::     down below for extensive detail on how and why
::     we do this.
::  4. %urb-watcher calls ++apply-prevouts-and-urbify
::     on the block. This converts it to an urb-block.
::  5. %urb-watcher calls ++handle-block on the
::     urb-block, which processes its txs for sotx and
::     returns an updated state and a list of fx.
::  6. %urb-watcher turns these fx into udiffs and
::     gives them to Jael.
::
::  Ported from groundwire's lib/urb-core.hoon.
::
/<  bitcoin      /lib/sur/bitcoin.hoon
/<  ord          /lib/sur/ord.hoon
/<  urb          /lib/sur/urb.hoon
/<  bscr         /lib/btc-script.hoon
/<  ol           /lib/ord.hoon
/<  urb-encoder  /lib/urb-encoder.hoon
|%
++  urb-core
  =|  state:urb
  =*  state  -
  |_  $+  urb-core-sample
      $:  fx=(list [id:block:bitcoin effect:urb])
          cb-tx=[value=@ud urb-tx:urb]
      ==
  +*  cor  .
  ++  abed
    |=  =state:urb
    ^+  cor
    cor(state state)
  ::
  ++  emit
    |=  fc=effect:urb
    ^+  cor
    cor(fx :-([block-id fc] fx))
  ::
  ++  emil
    |=  fy=(list effect:urb)
    ^+  cor
    ?~  fy  cor
    =.  cor  (emit i.fy)
    $(fy t.fy)
  ::
  ++  abet
    ^+  [fx state]
    [(flop fx) state]
  ::
  ::  Given a block, return its "reveals" (aka a map
  ::  of spent utxo to raw-sotx) and the block filtered
  ::  down to urb-relevant txs. A tx is relevant either
  ::  if we had saved one of its inputs previously,
  ::  or if its witness contains an urb reveal.
  ++  find-block-reveals
    |=  =block:bitcoin
    =|  reveals=(map [txid:ord vout:ord] [sots=(list raw-sotx:urb) value=(unit @ud)])
    ^+  [reveals block]
    ::
    ::  Set aside this block's coinbase transaction.
    ?~  txs.block
      ~&  >>>  ["%urb-core: This block has no transactions:" block]  !!
    =/  cb-tx  i.txs.block
    =/  txs    t.txs.block
    ::
    ::  Loop through this block's transactions
    ::  and filter down to tx containing reveals.
    =|  saved-txs=(list tx:bitcoin)
    |-
    ^+  [reveals block]
    ?~  txs
      :-  reveals
      block(txs [cb-tx (flop saved-txs)])
    ::
    ::  Loop through this transaction's inputs
    ::  and, if any contain sots, save the whole tx.
    =/  is  is.i.txs
    =|  need-tx=_|
    |^
    ^+  ^$
    ?~  is
      %=  ^$
        txs        t.txs
        saved-txs  ?.  need-tx
                     saved-txs
                   [i.txs saved-txs]
      ==
    ::
    ::  If this input had been saved as an output in our state,
    ::  then that means it was relevant to urb, and
    ::  we for sure need to save this tx to track where
    ::  all the sats end up.
    =/  value=(unit @ud)
      =/  vout  (get-vout:si:ol sont-map [txid pos]:i.is)
      ?~(vout ~ `value.u.vout)
    =.  need-tx  |(need-tx ?=(^ value))
    ::
    ::  Similarly, if this input came from a transaction we've
    ::  already saved in this block, we save this tx too.
    =.  need-tx
      ?|  need-tx
          %+  lien
            saved-txs
          |=  =tx:bitcoin
          =(id.tx txid.i.is)
      ==
    ::
    ::  Parse the witness for sots. If no sots, just
    ::  preserve our potential saved value and recurse.
    =/  raw-script=(unit octs)
      =/  rwit  (flop witness.i.is)
      ?.  ?=([* ^] rwit)  ~
      =/  first-byte  =+(i.rwit (cut 3 [(dec wid) 1] dat))
      ?.  |(=(0xc0 first-byte) =(0xc1 first-byte))  ~
      ?.  =+  i.rwit
          &(!=(0 wid) =(0x50 (cut 3 [(dec wid) 1] dat)))
        `i.t.rwit
      ?~  t.t.rwit  ~
      `i.t.t.rwit
    ?~  raw-script
      (add-to-reveals ~ value)
    ::  Quick check: skip scripts that don't start with the urb envelope.
    ::  Envelope is OP_0 OP_IF PUSH3 "urb" = bytes 00 63 03 75 72 62.
    ::  In octs, the first script byte is the MSB of the atom.
    ::  We check the top 5 bytes (skipping the leading 0x00 which
    ::  vanishes in the atom) for OP_IF PUSH3 "urb" = 0x6303757262.
    ?.  ?&  (gte p.u.raw-script 6)
            =(0x63.0375.7262 (cut 3 [(sub p.u.raw-script 6) 5] q.u.raw-script))
        ==
      (add-to-reveals ~ value)
    ~&  >  "%urb-core: urb envelope detected! parsing..."
    =/  descr  (de:bscr u.raw-script)
    ?~  descr
      ~&  >>>  "%urb-core: de:bscr failed on urb script"
      (add-to-reveals ~ value)
    ~|  [=+(u.raw-script [p `@ux`q]) =+((en:bscr u.descr) [p `@ux`q])]
    ?.  =(u.raw-script (en:bscr u.descr))
      ~&  >>>  "%urb-core: round-trip mismatch in witness parsing"  !!
    ~&  >  "%urb-core: script parsed successfully, extracting unvs..."
    =/  unvs=(unit (list @))  (some (unv:de:urb-encoder u.descr))
    ?~  unvs
      ~&  >>>  "%urb-core: no unvs found in parsed script"
      (add-to-reveals ~ value)
    ::
    ::  If there is sots, get it, add it to reveals,
    ::  flag this tx as needed, and recurse.
    =/  sots=(list raw-sotx:urb)
      (zing (turn u.unvs parse-roll:urb-encoder))
    (add-to-reveals(need-tx &) sots value)
    ::
    ++  add-to-reveals
      |=  [sots=(list raw-sotx:urb) value=(unit @ud)]
      ^+  ^$
      ?>  ?=(^ is)
      ?:  ?&  =(~ sots)
              =(~ value)
          ==
        ^$(is t.is)
      %=  ^$
        is  t.is
        reveals  (~(put by reveals) [txid pos]:i.is sots value)
      ==
    --
  ::
  ::  Fill in a block's txs with prevouts
  ::  given in a reveals map and restructure it
  ::  to an urb-block. Unlike a block:bitcoin, an
  ::  urb-block tracks prevout values within inputs,
  ::  because we aren't indexing every previous block.
  ++  apply-prevouts-and-urbify
    |=  $:  block:bitcoin
            reveals=(map [txid:ord vout:ord] [sots=(list raw-sotx:urb) value=(unit @ud)])
        ==
    ^-  urb-block:urb
    =*  block  +<-
    =>  ?>(?=(^ txs) [cb-tx=i.txs .(txs t.txs)])
    =-  %=  block
          txs  ^-  (list urb-tx:urb)
               %+  welp
                 ^-  (list urb-tx:urb)
                 :~  ^-  urb-tx:urb
                     %=  cb-tx
                       is  %+  turn
                             is.cb-tx
                           |=  inputw:tx:bitcoin
                           ^-  input:urb-tx:urb
                           [[~ 0] +<]
                     ==
                 ==
               ^-  (list urb-tx:urb)
               -
        ==
    |-
    ^-  (list tx:urb-tx:urb)
    ?~  txs  ~
    =/  is  is.i.txs
    =-  [i.txs(is -) $(txs t.txs)]
    |-
    ^-  (list input:urb-tx:urb)
    ?~  is
      ~
    =/  rev
      (~(get by reveals) [txid pos]:i.is)
    ?~  rev
      ~
    :-  [u.rev(value (need value.u.rev)) i.is]
    $(is t.is)
  ::
  ::  Given an urb-block, update state and emit fx.
  ++  handle-block
    |=  $:  =urb-block:urb
            precommits=(map [txid:ord vout:ord] [commit=urb-tx:urb precommit=urb-tx:urb])
        ==
    ^+  cor
    =.  num.block-id.state  +(num.block-id.state)
    ?~  txs.urb-block
      cor
    =>  %=  .
          txs.urb-block  t.txs.urb-block
          cb-tx         [reward.urb-block i.txs.urb-block]
        ==
    |-
    ^+  cor
    ?~  txs.urb-block
      cor
    =.  cor  (handle-tx i.txs.urb-block precommits)
    $(txs.urb-block t.txs.urb-block)
  ::
  ++  handle-tx
    =|  running-value=@ud
    |=  $:  tx=urb-tx:urb
            precommits=(map [txid:ord vout:ord] [commit=urb-tx:urb precommit=urb-tx:urb])
        ==
    ^+  cor
    =/  sum-out  (roll os.tx |=([[* a=@] b=@] (add a b)))
    =/  sum-in  (roll is.tx |=([a=input:urb-tx:urb b=@] (add value.a b)))
    =/  inputs  is.tx
    ?~  inputs  cor
    |^
    ^+  cor
    =.  cor  process-unv
    =.  cor  update-sonts
    ::  Excess inputs get added to coinbase fee,
    ::  which we calculate iteratively because we need
    ::  its per-input value for math in ++update-sonts.
    =<  ?~(t.inputs cor $(inputs t.inputs))
    =/  new-val  (add running-value value.i.inputs)
    ?:  (lth new-val sum-out)
      .(running-value new-val)
    %=  .
      running-value  sum-out
      value.cb-tx    (add value.cb-tx (sub new-val sum-out))
    ==
    ::
    ++  process-unv
      ^+  cor
      =/  sots  sots.i.inputs
      |-
      ?~  sots
        cor
      =*  raw  raw.i.sots
      =*  who  ship.sot.i.sots
      =-  $.+(cor -, sots t.sots)
      =/  sots=(list single:skim-sotx:urb)
        ?:  ?=(%batch +<.sot.i.sots)
          bat.sot.i.sots
        ~[+.sot.i.sots]
      |^
      ^+  cor
      =/  point  (~(get by unv-ids) who)
      =|  bat-cnt=@
      =.  bat-cnt  +(bat-cnt)
      ?~  sots  cor
      =*  sot  i.sots
      ?:  ?=(%spawn -.sot)
        ?.  =(1 bat-cnt)  cor
        ?^  point  cor
        ?:  (~(has by unv-ids) who)  cor
        =/  cac  (com:nu:cric:crypto pass.sot)
        ?.  ?=(%c suite.+<.cac)  cor
        ?.  =(who fig:ex:cac)  cor
        ::
        ::  A Groundwire user must choose the sat they want to own their comet
        ::  prior to boot-time and pass in its satpoint to Vere on first boot.
        ::  However, within their commit attestation, they must include their
        ::  ship's networking key, which is only knowable after boot.
        ::  Because of this, we have an additional "pre-commit" transaction
        ::  in addition to the typical ordinal protocol. A client will:
        ::
        ::  1. Pre-commit to a sat inside a precommit transaction.
        ::  2. Boot their comet using a satpoint within the precommit transaction.
        ::  3. Submit the commit transaction containing their precommit satpoint and ship networking key.
        ::  4. Submit the reveal transaction.
        ::
        ::  When processing a %spawn sotx then, rather than just checking
        ::  whether the sont is in this input, we need to check if it carried
        ::  through from *two* transactions back.
        ::
        =/  pcmtx  (~(get by precommits) [txid.i.inputs pos.i.inputs])
        ?~  pcmtx
          ~&  >>  "%urb-core: Couldn't find precommit tx."  cor
        =/  precommit-tx  precommit.u.pcmtx
        =/  commit-tx  commit.u.pcmtx
        ?~  precommit-sat=(calc-precommit-sont precommit-tx to.sot)
          cor
        ::  tweak = [%version payload]
        ::  payload = [pki-agent-source-ship pki-agent pki-data]
        ::  pki-data = [%src-name %protocol-name %protocol-version crypto-data]
        =/  tweak
          %+  rap
            3
          :~  %9
              ~tyr
              %urb-watcher
              %btc
              %gw
              %9
              txid=txid.u.precommit-sat
              vout=vout.u.precommit-sat
              off=off.u.precommit-sat
          ==
        ::
        ::  Check that the given comet networking key encodes the tweak
        ::  that corresponds to the attestation.
        ?.  =(dat.tw.pub:+<:cac tweak)
          ~&  >>>  ["%urb-core: provided pass's networking key does not match tweak: " dat.tw.pub:+<:cac]
          cor
        ::
        ::  We now know that:
        ::  - the attested satpoint exists
        ::  - the attested satpoint is encoded in the attested comet's networking key
        ::  - the attested satpoint was in an input to the commit transaction
        ::
        =/  commit-sat=(unit sont:ord)
          (apply-tx-to-sont commit-tx u.precommit-sat)
        ?~  commit-sat
          cor
        ::
        ?.  (is-sont-in-input u.commit-sat)
          ~&  >>>  'The commit sat did not get spent in the reveal tx. Rejecting.'
          cor
        ::
        =.  sont-map
          %:  put-com:si:ol
              sont-map
              txid.u.commit-sat
              vout.u.commit-sat
              off.u.commit-sat
              value.i.inputs
              who
          ==
        =/  =point:urb
          :*  own=[u.commit-sat ~]
              rift=0
              life=1
              pass=pass.sot
              sponsor=[| who]
              escape=~
              fief=fief.sot
          ==
        =.  unv-ids  (~(put by unv-ids) who point)
        =/  reveal-sunt
          %-  index-to-sont-with-coinbase
          (add running-value off.u.commit-sat)
        =/  reveal-sat=sont:ord
          ?~  reveal-sunt  [0x0 0 0]
          u.reveal-sunt
        ~&  >  ["%urb-watcher found comet: " who]
        =.  cor
          %-  emil
          :~  [%point who %owner reveal-sat]
              [%point who %sponsor `who]
              [%point who %keys 1 pass.sot]
              [%point who %fief fief.sot]
          ==
        $(sots t.sots)
      ::
      ?~  point  cor
      ?.  (is-sont-in-input sont.own.u.point)
        ~&  >>>  'Input to this tx did not include the owner sont. Rejecting.'
        cor
      ?-    -.sot
          %set-mang
        !!
      ::
          %fief
        =.  fief.net.u.point  fief.sot
        =.  cor  (emit [%point who %fief fief.sot])
        %_    $
            sots     t.sots
            unv-ids   (~(put by unv-ids) who u.point)
        ==
      ::
          %escape
        ::  sponsoring self, update now
        ?:  =(parent.sot who)
          =.  sponsor.net.u.point  &/who
          =.  escape.net.u.point   ~
          =.  cor  (emit [%point who %sponsor `who])
          %_    $
              sots     t.sots
              unv-ids   (~(put by unv-ids) who u.point)
          ==
        ::  sponsor already signed the request off-chain, update now
        ?^  sig.sot
          =/  sponsor  (~(get by unv-ids) parent.sot)
          ?~  sponsor
            ~&  >>>  "%urb-core: sponsor {<parent.sot>} not found in unv-ids, dropping escape"
            cor
          =/  cac  (com:nu:cric:crypto pass.net.u.sponsor)
          =/  lower-bound
            ?:  (lth num.block-id.state 10)
              0
            (sub num.block-id.state 10)
          ?.  %+  lien
                (gulf lower-bound (add num.block-id.state 1))
              |=(h=@ud (veri-octs:ed:crypto u.sig.sot 512^(shaz (jam [who h])) sgn:ded:ex:cac))
            ~&  >>>  ["%urb-core: escape sig from {<parent.sot>} for {<who>} failed verification (checked block heights {<lower-bound>} to {<(add num.block-id.state 1)>})"]
            cor
          =.  sponsor.net.u.point  &/parent.sot
          =.  escape.net.u.point   ~
          =.  cor  (emit [%point who %sponsor `parent.sot])
          %_    $
              sots     t.sots
              unv-ids   (~(put by unv-ids) who u.point)
          ==
        ::  no signature, flag sponsorship as pending
        =.  escape.net.u.point  `parent.sot
        =.  cor  (emit [%point who %escape `parent.sot])
        %_    $
            sots     t.sots
            unv-ids   (~(put by unv-ids) who u.point)
        ==
      ::
          %cancel-escape
        ?.  =([~ parent.sot] escape.net.u.point)  cor
        =.  escape.net.u.point  ~
        =.  cor  (emit [%point who %escape ~])
        %_    $
            sots     t.sots
            unv-ids   (~(put by unv-ids) who u.point)
        ==
      ::
          %detach
        ?~  child=(~(get by unv-ids) ship.sot)  cor
        ?.  =([& who] sponsor.net.u.child)  cor
        =.  sponsor.net.u.child  |/who
        =.  cor  (emit [%point ship.sot %sponsor `who])
        %_    $
            sots     t.sots
            unv-ids   (~(put by unv-ids) ship.sot u.child)
        ==
      ::
          %adopt
        ?:  =(ship.sot who)
          =.  sponsor.net.u.point  &/who
          =.  escape.net.u.point   ~
          =.  cor  (emit [%point ship.sot %sponsor `who])
          %_    $
              sots     t.sots
              unv-ids   (~(put by unv-ids) who u.point)
          ==
        ?~  child=(~(get by unv-ids) ship.sot)  cor
        ?.  =([~ who] escape.net.u.child)  cor
        =.  escape.net.u.child  ~
        =.  sponsor.net.u.child  &/who
        =.  cor  (emit [%point ship.sot %sponsor `who])
        %_    $
            sots     t.sots
            unv-ids   (~(put by unv-ids) ship.sot u.child)
        ==
      ::
          %reject
        ?~  child=(~(get by unv-ids) ship.sot)  cor
        ?.  =([~ who] escape.net.u.child)  cor
        =.  escape.net.u.child  ~
        =.  cor  (emit [%point ship.sot %escape ~])
        %_    $
            sots     t.sots
            unv-ids   (~(put by unv-ids) ship.sot u.child)
        ==
      ::
          %keys
        =.  net.u.point
          net.u.point(pass pass.sot, life +(life.net.u.point))
        =?  rift.net.u.point  breach.sot  +(rift.net.u.point)
        =.  cor  %-  emil
          :*  [%point who %keys life.net.u.point pass.sot]
              ?.  breach.sot  ~
              [%point who %rift rift.net.u.point]^~
          ==
        %_    $
            sots     t.sots
            unv-ids   (~(put by unv-ids) who u.point)
        ==
      ==
      ::
      ::  Is this sont in the input that's being processed?
      ++  is-sont-in-input
        |=  sot=sont:ord
        ~|  [s=sot [txid pos value]:i.inputs]
        ?.  =([txid vout]:sot [txid pos]:i.inputs)  |
        ~|  %fatal-tracking-error
        ?>  (lth off.sot value.i.inputs)  &
      ::
      ::  Given a precommit tx and a [vout off tej],
      ::  check if the implied satpoint [txid vout off]
      ::  is a valid landing location within the tx outputs
      ::  and that off+tej doesn't exceed that output's value.
      ::  Additionally, check that the scriptPubkey hash of the
      ::  landing output matches the given spkh.
      ::  If both are true, return the implied satpoint,
      ::  otherwise return null.
      ++  calc-precommit-sont
        |=  $:  precommit=urb-tx:urb
                out=[spkh=@ux pos=(unit vout:ord) =off:ord tej=off:ord]
            ==
        ^-  (unit sont:ord)
        =|  out-pos=@ud
        =|  out-val=@ud
        =/  in-val
          (roll is.precommit |=([a=input:urb-tx:urb b=@] (add value.a b)))
        =/  outputs  os.precommit
        |-
        ^-  (unit sont:ord)
        ?~  outputs  ~
        ?~  pos.out
          ~
        ?:  (lth u.pos.out out-pos)
          ~
        ?:  (gth :(add out-val off.out tej.out) in-val)
          ~
        ?:  !=(out-pos u.pos.out)
          $(out-val (add out-val value.i.outputs), outputs t.outputs, out-pos +(out-pos))
        ?:  (gth (add off:out tej:out) value.i.outputs)
          ~
        =/  sat=sont:ord  [id.precommit u.pos.out off.out]
        =/  en-out  (can 3 script-pubkey.i.outputs 8^value.i.outputs ~)
        =/  hax-out  (shay (add 8 wid.script-pubkey.i.outputs) en-out)
        ?:  =(hax-out spkh.out)
          `sat
        ~
      --
    ::
    ::  Given the transaction input that's currently in
    ::  ++handle-tx's context, get every sont we're tracking
    ::  in sont-map within that input (typically one per
    ::  input) and:
    ::  - Update sont-map with new landing sonts
    ::  - Update insc-ids with new owner sont (mostly vestigial)
    ::  - Update unv-ids with new owner sont
    ::  - Emit %xfer event signalling point transfer to new owner sont
    ++  update-sonts
      ^+  cor
      ?~  input=(~(get by sont-map) [txid pos]:i.inputs)
        cor
      =.  sont-map  (~(del by sont-map) [txid pos]:i.inputs)
      =/  input-sonts  ~(tap by sats.u.input)
      |-
      ^+  cor
      ?~  input-sonts  cor
      =/  old-sont=sont:ord  [txid.i.inputs pos.i.inputs p.i.input-sonts]
      =/  new-sunt
        %-  index-to-sont-with-coinbase
        (add running-value p.i.input-sonts)
      =/  new-sont=sont:ord
        ?~  new-sunt
          [0x0 0 0]
        u.new-sunt
      =.  state  (update-ids state q.i.input-sonts new-sont)
      =.  cor  (emit [%xfer old-sont new-sont])
      %_  $
        input-sonts    t.input-sonts
        sont-map  ?~  new-sunt
                    sont-map
                  =/  out-value
                    ?:  =(txid.new-sont id.tx)
                      value:(snag vout.new-sont os.tx)
                    value:(snag vout.new-sont os.cb-tx)
                  %-  put-all:si:ol
                  :*  sont-map
                      txid.new-sont
                      vout.new-sont
                      off.new-sont
                      out-value
                      q.i.input-sonts
                  ==
      ==
    ::
    ::  A wrapper around ++index-to-sont which has
    ::  access to context from ++handle-tx. We use this
    ::  context to handle the case where a sont lands
    ::  in the mining fee, in which case we transfer
    ::  ownership to the miner.
    ++  index-to-sont-with-coinbase
      |=  index=@ud
      ^-  (unit sont:ord)
      ?:  (lth index sum-out)
        ?~  sont=(index-to-sont index os.tx)  ~
        `[id.tx vout.sont off.sont]
      =/  sont
        %-  index-to-sont
        :-  (add value.cb-tx (sub index sum-out))
        os.cb-tx
      ?:  ?|  =(~ sont)
              (lte sum-in index)
          ==
        ~
      ?>  ?=(^ sont)
      `[id.cb-tx vout.sont off.sont]
    ::
    ::  Arms for updating insc-ids and unv-ids.
    ++  update-ids
      |=  [=state:urb old=sont-val:ord =sont:ord]
      =.  state  (update-inscriptions state ins.old sont)
      ?~  com.old  state
      (update-comet state u.com.old sont)
    ::
    ++  update-inscriptions
      |=  [=state:urb oids=(set insc:ord) =sont:ord]
      ?:  =(~ oids)  state
      %-  ~(rep in oids)
      |:  [*=insc:ord state]
      =/  dat  (~(got by insc-ids) insc)
      state(insc-ids (~(put by insc-ids) insc dat(sont sont)))
    ::
    ++  update-comet
      |=  [=state:urb com=@p =sont:ord]
      =/  point  (~(got by unv-ids:state) com)
      state(unv-ids (~(put by unv-ids:state) com point(sont.own sont)))
    ::
    ::  Given a transaction and a satpoint that refers to one of its inputs,
    ::  compute where that same sat ends up in this tx's outputs.
    ++  apply-tx-to-sont
      |=  [tx=urb-tx:urb sot=sont:ord]
      ^-  (unit sont:ord)
      =/  inputs  is.tx
      =|  in-sum=@ud
      |-
      ^-  (unit sont:ord)
      ?~  inputs
        ~
      =/  inp  i.inputs
      ?:  =([txid vout]:sot [txid pos]:inp)
        ?.  (lth off.sot value.inp)
          ~
        =/  index=@ud
          (add in-sum off.sot)
        =/  out  (index-to-sont index os.tx)
        ?~  out
          ~
        `[[id.tx vout.out off.out]]
      $(inputs t.inputs, in-sum (add in-sum value.inp))
    --
  --
::
::  Take a list of outputs and a sat index across
::  those outputs, and return the output index
::  and relative sat offset.
++  index-to-sont
  =|  vout=@ud
  |=  [index=@ud outs=(list output:tx:bitcoin)]
  ^-  $@(~ [vout=@ud off=@ud])
  ?~  outs
    ~
  ?:  (lth index value.i.outs)
    [vout index]
  %=  $
    vout   +(vout)
    index  (sub index value.i.outs)
    outs   t.outs
  ==
--
