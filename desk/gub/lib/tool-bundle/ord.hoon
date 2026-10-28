::  lib/ord.hoon
::
::  Ord metaprotocol encoder/decoder and sat-pointer (sont) map ops.
::  Ported from groundwire's lib/ord.hoon.
::
/<  bitcoin  /lib/sur/bitcoin.hoon
/<  ord      /lib/sur/ord.hoon
/<  bscr     /lib/btc-script.hoon
=*  sha  ..shax
=|  lac=_|
|%
::
++  en
  |%
  ++  mails-to-script
    |=  mails=(list mail:ord)
    ^-  script:bscr
    (zing (turn mails mail-to-script))
  ::
  ++  mail-to-script
    |=  =mail:ord
    ^-  script:bscr
    (draft-to-script (mail-to-draft mail))
  ::
  ++  mail-to-draft
    |=  =mail:ord
    |^  ^-  draft:ord
    %-  ~(gas by *draft:ord)
    %-  zing
    ^-  (list (list (pair @ud octs)))
    :~  ?~(mime.mail ~ [1 p.mime.mail p.+.mime.mail]^~)
        ?~(code.mail ~ [9 p.code.mail p.+.code.mail]^~)
        ?~(pntr.mail ~ [2 p.pntr.mail p.+.pntr.mail]^~)
        ?~(rent.mail ~ [3 (insc rent.mail)]^~)
        ?~(gate.mail ~ [11 (insc gate.mail)]^~)
        ?~(meta.mail ~ [5 meta.mail]^~)
        ?~(prot.mail ~ [7 prot.mail]^~)
        ?~(data.mail ~ [0 data.mail]^~)
    ==
    ::
    ++  insc
      |=  [p=@ud oid=(each insc:ord @)]
      ^-  octs
      :-  p
      ?.  ?=(%& -.oid)  p.oid
      (con (lsh [3 (sub p 32)] txid.p.oid) idx.p.oid)
    --
  ::
  ++  rip-octs
    |=  octs
    ^-  (list octs)
    =/  met-q  (met 3 q)
    ?>  (lte met-q p)
    =/  ripped  (rip [3 520] q)
    |-  ^-  (list octs)
    ?~  ripped  ~
    ?~  t.ripped  [(met 3 i.ripped) i.ripped]^~
    [520 i.ripped]^$(ripped t.ripped)
  ::
  ++  push-data
    |=  data=octs
    =/  ripped  (rip-octs data)
    ?:  =(ripped ~)  !!
    |-  ^-  script:bscr
    ?~  ripped  ~
    :-  (push-one-data i.ripped)
    $(ripped t.ripped)
  ::
  ++  push-one-data
    |=  octs
    ^-  op:bscr
    ?>  (lte (met 3 q) p)
    ?>  !=(0 p)
    ?>  (lte p 520)
    ?:  (lte p 0x4b)  op-push+~+p^q
    ?:  (lte p 0xff)  op-push+1+p^q
    ?>  (lte p 520)
    op-push+2+p^q
  ::
  ++  draft-to-script
    |=  =draft:ord
    ^-  script:bscr
    =/  data  (~(get by draft) 0)
    =/  meta  (~(get by draft) 5)
    =.  draft  (~(del by (~(del by draft) 0)) 5)
    =/  tags  (sort ~(tap by draft) |=([[a=@ *] [b=@ *]] (lth a b)))
    =-  [op-push+num+1+0 %op-if op-push+~+3+'ord' -]
    |^  ^-  script:bscr
    ?~  tags  push-meta
    :+  op-push+num+1+p.i.tags
      (push-one-data q.i.tags)
    $(tags t.tags)
    ::
    ++  push-meta
      ^-  script:bscr
      ?~  meta  push-data
      =/  ripped  (rip-octs u.meta)
      |-  ^-  script:bscr
      ?~  ripped  push-data
      :+  op-push+num+1+5
        (push-one-data i.ripped)
      $(ripped t.ripped)
    ::
    ++  push-data
      ^-  script:bscr
      ?~  data  [%op-endif ~]
      =-  [op-push+num+1+0 -]
      (^push-data u.data)
    --
  --
::
++  de
  |%
  ++  mails
    |=  =script:bscr
    (turn (drafts script) draft-to-mail)
  ::
  ++  draft-to-mail
    |=  =draft:ord
    ^-  mail:ord
    :*  (biff (~(get by draft) 1) ascii)
        (biff (~(get by draft) 9) ascii)
        (biff (~(get by draft) 2) pntr)
        (biff (~(get by draft) 3) insc)
        (biff (~(get by draft) 11) insc)
        (fall (~(get by draft) 5) ~)
        (fall (~(get by draft) 7) ~)
        (fall (~(get by draft) 0) ~)
    ==
  ::
  ++  ascii
    |=  octs
    ^-  [p=@ud (each @t @)]
    ?.  (levy (rip 3 q) |=(@ (lth +< 128)))  [p |+q]
    [p &+q]
  ::
  ++  pntr
    |=  octs
    ^-  [p=@ud (each @ud @)]
    ?.  &((lte p 5) (lte q 0xffff.ffff))  [p |+q]
    [p &+q]
  ::
  ++  insc
    |=  octs
    ^-  [p=@ud (each insc:ord @)]
    ?.  (lth p 33)  [p |+q]
    =/  tx  (cut 3 [(sub p 32) 32] q)
    =/  ilen  (sub p 32)
    [p &+[tx (cut 3 [0 ilen] q)]]
  ::
  ++  drafts
    |=  =script:bscr
    ^-  (list draft:ord)
    ?~  script  ~
    ?.  ?=([[%op-push * * %0] %op-if [%op-push * * %'ord'] *] script)  $(script t.script)
    =>  .(script t.t.t.script)
    |^  ^-  (list draft:ord)
    =^  tags  script  fetch-tags
    ?~  tags  ^$  [u.tags ^$]
    ::
    ++  fetch-tags
      ^-  [(unit draft:ord) script:bscr]
      ?>  ?=(^ script)
      =|  tags=(map @ud (list octs))
      |-  ^+  fetch-tags
      ?:  ?=(%op-endif i.script)
        :_  t.script
        `(~(run by tags) |=((list octs) (roll +< |=([a=octs b=octs] (add p.a p.b)^(cat 3 q.a q.b)))))
      ?>  ?=(^ t.script)
      ?.  ?=([[%op-push *] [%op-push *] * *] script)
        =>  .(script `(lest op:script:bscr)`t.script)
        |-  ^+  fetch-tags
        ?:  ?=(%op-endif -.script)  ~^t.script
        ?>  ?=(^ t.script)
        $(script t.script)
      =*  tag  q.octs.i.script
      =*  dat  octs.i.t.script
      ?.  =(tag 0)
        %_  $
          script  t.t.script
          tags
            ?~  d=(~(get by tags) tag)  (~(put by tags) tag dat^~)
            ?.  =(tag 5)  tags
            (~(put by tags) tag dat^u.d)
        ==
      =|  dats=(list octs)
      =>  .(script `(lest op:script:bscr)`t.script)
      |-  ^+  fetch-tags
      ?.  ?=(%op-endif i.script)
        ?>  ?=([[%op-push *] ^] script)
        $(dats octs.i.script^dats, script t.script)
      :_  t.script
      :-  ~
      %-  ~(run by (~(put by tags) 0 dats))
      |=((list octs) (roll +< |=([a=octs b=octs] (add p.a p.b)^(cat 3 q.a q.b))))
    --
  ::
  --
::
++  shan
  |=  a=*
  ?@  a  (shax:sha (cat 3 %atom a))
  (shax:sha (rep 3 %cell $(a -.a) $(a +.a) ~))
::
++  si
  |%
  ++  get
    |=  [a=sont-map:ord =txid:ord =vout:ord =off:ord]
    ^-  (unit sont-val:ord)
    ?~  b=(~(get by a) txid vout)  ~
    (~(get by sats.u.b) off)
  ::
  ++  get-com
    |=  [a=sont-map:ord =txid:ord =vout:ord =off:ord]
    ^-  (unit @p)
    ?~(b=(get +<) ~ com.u.b)
  ::
  ++  get-vout
    |=  [a=sont-map:ord =txid:ord =vout:ord]
    ^-  (unit vout-map:ord)
    (~(get by a) txid vout)
  ::
  ++  put-all
    |=  [a=sont-map:ord =txid:ord =vout:ord =off:ord val=@ud com=(unit @p) ins=(set insc:ord)]
    ^-  sont-map:ord
    %+  ~(put by a)  [txid vout]
    =/  b=vout-map:ord  (~(gut by a) [txid vout] [0 ~])
    =/  c=sont-val:ord  (~(gut by sats.b) off [~ ~])
    val^(~(put by sats.b) off c(com com, ins (~(uni in ins.c) ins)))
  ::
  ++  put-ins
    |=  [a=sont-map:ord =txid:ord =vout:ord =off:ord val=@ud ins=(set insc:ord)]
    ^-  sont-map:ord
    %+  ~(put by a)  [txid vout]
    =/  b=vout-map:ord  (~(gut by a) [txid vout] [0 ~])
    =/  c=sont-val:ord  (~(gut by sats.b) off [~ ~])
    val^(~(put by sats.b) off c(ins (~(uni in ins.c) ins)))
  ::
  ++  put-com
    |=  [a=sont-map:ord =txid:ord =vout:ord =off:ord val=@ud com=@p]
    ^-  sont-map:ord
    %+  ~(put by a)  [txid vout]
    =/  b=vout-map:ord  (~(gut by a) [txid vout] [0 ~])
    =/  c=sont-val:ord  (~(gut by sats.b) off [~ ~])
    val^(~(put by sats.b) off c(com `com))
  ::
  ++  del
    |=  [a=sont-map:ord =txid:ord =vout:ord =off:ord]
    ^-  sont-map:ord
    ?~  b=(~(get by a) [txid vout])  a
    =/  c  (~(del by sats.u.b) off)
    ?:  =(c ~)  (~(del by a) txid off)
    (~(put by a) [txid vout] u.b(sats c))
  --
--
