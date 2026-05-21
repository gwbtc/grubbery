::  lib/jwt: JSON Web Token (ES256) library
::
::  Byte conventions: byts/crypto are MSB-first, octs/HTTP are LSB-first
::
::  P-256 (secp256r1) curve
::
=/  secp256r1
  |%
  ++  t
    ^-  domain:secp:crypto
    :*  0xffff.ffff.0000.0001.0000.0000.0000.0000.
          0000.0000.ffff.ffff.ffff.ffff.ffff.ffff
        0xffff.ffff.0000.0001.0000.0000.0000.0000.
          0000.0000.ffff.ffff.ffff.ffff.ffff.fffc
        0x5ac6.35d8.aa3a.93e7.b3eb.bd55.7698.86bc.
          651d.06b0.cc53.b0f6.3bce.3c3e.27d2.604b
        :-  0x6b17.d1f2.e12c.4247.f8bc.e6e5.63a4.40f2.
              7703.7d81.2deb.33a0.f4a1.3945.d898.c296
            0x4fe3.42e2.fe1a.7f9b.8ee7.eb4a.7c0f.9e16.
              2bce.3357.6b31.5ece.cbb6.4068.37bf.51f5
        0xffff.ffff.0000.0000.ffff.ffff.ffff.ffff.
          bce6.faad.a717.9e84.f3b9.cac2.fc63.2551
    ==
  ++  point             point:secp:crypto
  ++  curve             ~(. secp:secp:crypto 32 t)
  ++  serialize-point   serialize-point:curve
  ++  compress-point    compress-point:curve
  ++  decompress-point  decompress-point:curve
  ++  add-points        add-points:curve
  ++  mul-point-scalar  mul-point-scalar:curve
  ++  priv-to-pub
    |=  private-key=@
    (priv-to-pub:curve private-key)
  ++  ecdsa-raw-sign
    |=  [hash=@ private-key=@]
    ^-  [r=@ s=@]
    =/  c  curve
    =+  (ecdsa-raw-sign.c hash private-key)
    =?  s  (gte (mul 2 s) n.domain.c)  ::  low-s normalization
      (sub n.domain.c s)
    [r s]
  ++  ecdsa-raw-verify
    |=  [hash=@ public-key=point r=@ s=@]
    ^-  ?
    =/  c  curve
    =/  fon  field-n:c
    =+  [fmul finv]=[pro.fon inv.fon]
    ?.  &((gth r 0) (lth r n.domain.c))  %.n
    ?.  &((gth s 0) (lth s n.domain.c))  %.n
    =/  w  (finv s)
    =/  u1  (fmul hash w)
    =/  u2  (fmul r w)
    =/  p1  (mul-point-scalar g.domain.c u1)
    =/  p2  (mul-point-scalar public-key u2)
    =/  rp  (add-points p1 p2)
    =(r (mod x.rp n.domain.c))
  --
=,  secp256r1
|%
++  en-base64url
  ~(en base64:mimes:html | &)
++  de-base64url
  ~(de base64:mimes:html | &)
++  cord-to-byts
  |=  =cord
  ^-  byts
  =/  len  (met 3 cord)
  [len (rev 3 len cord)]
::  +cord-to-byts-null: cord to MSB-first byts with null terminator
::
++  cord-to-byts-null
  |=  =cord
  ^-  byts
  =/  len  (met 3 cord)
  [+(len) (lsh [3 1] (rev 3 len cord))]
++  es256-sign
  |=  [hash=@ private-key=@]
  ^-  @
  =/  sig  (ecdsa-raw-sign hash private-key)
  (can 3 ~[[32 s.sig] [32 r.sig]])
::  +encode-jwt: sign a JSON payload as an ES256 JWT
::
++  encode-jwt
  |=  [payload=json private-key=@]
  ^-  @t
  =/  header=@t
    %-  en-base64url
    (as-octs:mimes:html '{"alg":"ES256","typ":"JWT"}')
  =/  payload-cord=@t
    (en:json:html payload)
  =/  payload-b64=@t
    %-  en-base64url
    (as-octs:mimes:html payload-cord)
  =/  signing-input=@t
    (rap 3 ~[header '.' payload-b64])
  =/  hash=@  (rev 3 32 (shax signing-input))
  =/  sig=@  (es256-sign hash private-key)
  =/  sig-b64=@t  (en-base64url [64 (rev 3 64 sig)])
  (rap 3 ~[signing-input '.' sig-b64])
::  +make-jwt: JWT with aud, exp, sub claims
::
++  make-jwt
  |=  [aud=@t exp=@ud sub=@t private-key=@]
  ^-  @t
  =/  payload=json
    %-  pairs:enjs:format
    :~  ['aud' [%s aud]]
        ['exp' [%n (crip (a-co:co exp))]]
        ['sub' [%s sub]]
    ==
  (encode-jwt payload private-key)
::  +decode-jwt: parse a JWT without verifying signature
::
++  decode-jwt
  |=  token=@t
  ^-  (unit [header=json payload=json signature=octs])
::  split on '.', segments are base64url charset [A-Za-z0-9_-]
  =/  parts=(list @t)
    %-  fall  :_  *(list @t)
    %-  rush  :_
      (more dot (cook crip (plus ;~(pose hig low nud hep cab))))
    token
  ?.  =(3 (lent parts))  ~
  =/  header-octs  (de-base64url (snag 0 parts))
  ?~  header-octs  ~
  =/  header-json  (de:json:html q.u.header-octs)
  ?~  header-json  ~
  =/  payload-octs  (de-base64url (snag 1 parts))
  ?~  payload-octs  ~
  =/  payload-json  (de:json:html q.u.payload-octs)
  ?~  payload-json  ~
  =/  sig-octs  (de-base64url (snag 2 parts))
  ?~  sig-octs  ~
  `[u.header-json u.payload-json u.sig-octs]
::  +verify-jwt: decode and verify an ES256 JWT
::
++  verify-jwt
  |=  [token=@t public-key=point]
  ^-  (unit [header=json payload=json])
  =/  decoded  (decode-jwt token)
  ?~  decoded  ~
  =/  parts=(list @t)
    %-  fall  :_  *(list @t)
    %-  rush  :_
      (more dot (cook crip (plus ;~(pose hig low nud hep cab))))
    token
  =/  signing-input=@t
    (rap 3 ~[(snag 0 parts) '.' (snag 1 parts)])
  =/  hash=@  (rev 3 32 (shax signing-input))
  =/  sig-dat  q.signature.u.decoded
  =/  sig-len  p.signature.u.decoded
  ?.  =(64 sig-len)  ~
  =/  sig-msb  (rev 3 64 sig-dat)       ::  octs to MSB-first
  =/  r=@  (rsh [3 32] sig-msb)
  =/  s=@  (end [3 32] sig-msb)
  ?.  (ecdsa-raw-verify hash public-key r s)  ~
  `[header.u.decoded payload.u.decoded]
::  +validate-exp: %.y if exp is absent or in the future
::  absent or non-numeric exp is treated as no constraint (%.y)
::
++  validate-exp
  |=  [payload=json now=@ud]
  ^-  ?
  ?.  ?=(%o -.payload)  %.y
  =/  exp-json  (~(get by p.payload) 'exp')
  ?~  exp-json  %.y
  ?.  ?=(%n -.u.exp-json)  %.y
  =/  exp  (rush p.u.exp-json dem)
  ?~  exp  %.y
  (gte u.exp now)
::  +validate-nbf: %.y if nbf is absent or not in the future
::  absent or non-numeric nbf is treated as no constraint (%.y)
::
++  validate-nbf
  |=  [payload=json now=@ud]
  ^-  ?
  ?.  ?=(%o -.payload)  %.y
  =/  nbf-json  (~(get by p.payload) 'nbf')
  ?~  nbf-json  %.y
  ?.  ?=(%n -.u.nbf-json)  %.y
  =/  nbf  (rush p.u.nbf-json dem)
  ?~  nbf  %.y
  (lte u.nbf now)
--
