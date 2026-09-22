::  nostr: the protocol's cryptography and encodings, nothing else.
::
::  A nostr identity is one secp256k1 keypair. The public half is the
::  x coordinate alone (bip-340 "x-only", 32 bytes, shown as 64 hex
::  chars); it IS the account name on the network. The private half is
::  a 32-byte scalar; whoever holds it can sign as that identity, so
::  it never leaves the ship. npub/nsec are the same two numbers in
::  bech32 for humans to copy.
::
::  An event's id is the sha256 of its NIP-01 serialization
::  [0, pubkey, created_at, kind, tags, content]; its sig is a
::  bip-340 schnorr signature over that id. Both are hex strings on
::  the wire. Kinds used here: 0 profile metadata, 1 a text note,
::  3 a contact list.
::
/<  b32  /lib/bech32.hoon
/<  bcu  /lib/bitcoin-utils.hoon
|%
+$  keys  [pub=@ux priv=@ux]
::  +gen-keys: a fresh keypair from entropy
++  gen-keys
  |=  eny=@
  ^-  keys
  =,  secp256k1:secp:crypto
  =/  priv=@
    =/  k=@  (~(rad og eny) (bex 256))
    |-
    ?:  &((gth k 0) (lth k n.t))  k
    $(k (~(rad og (mix eny k)) (bex 256)))
  [x:(priv-to-pub priv) priv]
::  +to-hex: an atom as zero-padded lowercase hex, n digits (64 for keys
::  and ids, 128 for signatures)
++  to-hex
  |=  [n=@ud a=@]
  ^-  @t
  (crip ((x-co:co n) a))
++  parse-hex
  |=  t=@t
  ^-  (unit @ux)
  (rush t hex)
::  +npub / +nsec: bech32 with the nostr prefixes (NIP-19)
++  npub  |=(pub=@ux (bech 'npub' pub))
++  nsec  |=(priv=@ux (bech 'nsec' priv))
++  bech
  |=  [hrp=@t a=@ux]
  ^-  @t
  (encode-raw:b32 (trip hrp) %.n (to-atoms:bit:bcu 5 [256 `@ub`a]))
::  +from-bech: the 32-byte payload of an npub/nsec (NIP-19), if the
::  string is bech32 with that prefix and a 256-bit body
++  from-bech
  |=  [hrp=@t body=@t]
  ^-  (unit @ux)
  =/  d=(unit raw-decoded:b32)  (decode-raw:b32 body)
  ?~  d  ~
  ?.  =((trip hrp) hrp.u.d)  ~
  =/  bs=bits:bcu  (from-atoms:bit:bcu 5 data.u.d)
  ?.  (gte wid.bs 256)  ~
  `dat:(take:bit:bcu 256 bs)
::  +parse-key: a private or public key as hex (64) or bech32 (nsec/npub)
++  parse-key
  |=  [hrp=@t t=@t]
  ^-  (unit @ux)
  =/  s=@t  (crip (cass (trip t)))
  ?:  =(64 (met 3 s))  (parse-hex s)
  (from-bech hrp s)
::  +serial: the NIP-01 id preimage
++  serial
  |=  [pub=@ux at=@ud kind=@ud tags=(list (list @t)) content=@t]
  ^-  @t
  %-  en:json:html
  :-  %a
  :~  [%n '0']
      s+(to-hex 64 pub)
      (numb:enjs:format at)
      (numb:enjs:format kind)
      [%a (turn tags |=(t=(list @t) [%a (turn t |=(x=@t s+x))]))]
      s+content
  ==
::  +event-id: sha256 of the serialization, as the big-endian atom the
::  wire hex spells
++  event-id
  |=  [pub=@ux at=@ud kind=@ud tags=(list (list @t)) content=@t]
  ^-  @ux
  (swp 3 (shax (serial pub at kind tags content)))
::  +sign: bip-340 schnorr over an id; aux is 32 bytes of entropy
++  sign
  |=  [priv=@ux id=@ux aux=@]
  ^-  @ux
  (sign:schnorr:secp256k1:secp:crypto priv id (end [3 32] aux))
++  verify
  |=  [pub=@ux id=@ux sig=@ux]
  ^-  ?
  (verify:schnorr:secp256k1:secp:crypto pub id sig)
::  +make-event: a complete signed event as the json a relay accepts
++  make-event
  |=  [=keys at=@ud kind=@ud tags=(list (list @t)) content=@t eny=@]
  ^-  json
  =/  id=@ux  (event-id pub.keys at kind tags content)
  =/  sig=@ux  (sign priv.keys id eny)
  %-  pairs:enjs:format
  :~  ['id' s+(to-hex 64 id)]
      ['pubkey' s+(to-hex 64 pub.keys)]
      ['created_at' (numb:enjs:format at)]
      ['kind' (numb:enjs:format kind)]
      ['tags' [%a (turn tags |=(t=(list @t) [%a (turn t |=(x=@t s+x))]))]]
      ['content' s+content]
      ['sig' s+(to-hex 128 sig)]
  ==
::  +check-event: does a received event's id match its body and its
::  sig its pubkey? (what a client should ask before trusting a relay)
++  check-event
  |=  ev=json
  ^-  ?
  ?.  ?=([%o *] ev)  |
  =/  g  |=(k=@t ^-(@t =/(v (~(get by p.ev) k) ?:(?=([~ %s *] v) p.u.v ''))))
  =/  n  |=(k=@t ^-(@ud =/(v (~(get by p.ev) k) ?:(?=([~ %n *] v) (fall (rush p.u.v dem) 0) 0))))
  =/  tags=(list (list @t))
    =/  v  (~(get by p.ev) 'tags')
    ?.  ?=([~ %a *] v)  ~
    %+  turn  p.u.v
    |=(t=json ?.(?=([%a *] t) ~ (murn p.t |=(x=json ?:(?=([%s *] x) `p.x ~)))))
  =/  pub=(unit @ux)  (parse-hex (g 'pubkey'))
  =/  id=(unit @ux)  (parse-hex (g 'id'))
  =/  sig=(unit @ux)  (parse-hex (g 'sig'))
  ?:  |(?=(~ pub) ?=(~ id) ?=(~ sig))  |
  ?.  =(u.id (event-id u.pub (n 'created_at') (n 'kind') tags (g 'content')))  |
  (verify u.pub u.id u.sig)
--
