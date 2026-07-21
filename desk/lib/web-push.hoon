::  lib/web-push: VAPID Web Push (RFC 8291, RFC 8292)
::
::  Implements encrypted push message delivery using the Voluntary
::  Application Server Identification (VAPID) protocol.  Handles
::  ECDH key agreement on P-256, HKDF-based key derivation, and
::  AES-128-GCM content encryption per the Web Push standard.
::
::  Byte conventions: byts/crypto are MSB-first, octs/HTTP are LSB-first
::
/-  push
/+  jwt, hkdf, aes-gcm
=,  jwt
|%
++  extract-origin
  |=  url=@t
  ^-  @t
  =/  parsed  (rush url auri:de-purl:html)
  ?~  parsed  ~|(%bad-push-endpoint !!)  ::  endpoint must be a valid URL
  =/  ux=purl:eyre  u.parsed
  =/  scheme=@t  ?:(p.p.ux 'https' 'http')
  =/  hob=host:eyre  r.p.ux
  =/  host=@t
    ?-  -.hob
      %&  (en-turf:html p.hob)
      %|  (scot %if p.hob)
    ==
  =/  port-text=@t
    ?~  q.p.ux  ''
    ?:  &(p.p.ux =(443 u.q.p.ux))  ''
    ?:  &(!p.p.ux =(80 u.q.p.ux))  ''
    (rap 3 ~[':' (crip (a-co:co u.q.p.ux))])
  (rap 3 ~[scheme '://' host port-text])
++  make-vapid-headers
  |=  [endpoint=@t config=push-config:push exp=@ud]
  ^-  (list [key=@t value=@t])
  =/  origin=@t  (extract-origin endpoint)
  =/  jwt=@t
    (make-jwt origin exp sub.config private-key.config)
  =/  pub-b64=@t
    (en-base64url [65 (rev 3 65 public-key.config)])
  :~  ['Authorization' (rap 3 ~['vapid t=' jwt ', k=' pub-b64])]
      ['Content-Encoding' 'aes128gcm']
      ['Content-Type' 'application/octet-stream']
      ['TTL' '86400']
  ==
++  generate-vapid-keypair
  |=  [eny=@ sub=@t]
  ^-  push-config:push
  =/  raw=@  (shay 36 (can 3 ~[[32 eny] [4 'vpid']]))
  =/  priv=@  (mod raw (dec n.t))
  =.  priv  ?:(=(0 priv) 1 priv)
  =/  pub=@  (serialize-point (priv-to-pub priv))
  [priv pub sub]
++  deserialize-p256
  |=  pub=@
  ^-  point
  ?>  =(4 (rsh [3 64] pub))
  =/  x=@  (cut 3 [32 32] pub)
  =/  y=@  (end [3 32] pub)
  =/  fop  field-p:curve
  =+  [fadd fmul fpow]=[sum.fop pro.fop exp.fop]
  =/  lhs  (fpow 2 y)
  =/  rhs  %+  fadd  b.t
           %+  fadd  (fpow 3 x)
           (fmul a.t x)
  ?>  =(lhs rhs)
  [x y]
++  encrypt-payload
  |=  $:  ua-pub=@
          ua-auth=@
          plaintext=octs
          eph-priv=@
          salt=@
      ==
  ^-  octs
  ?>  (lte p.plaintext 3.993)              ::  max 4096 - overhead
  =/  eph-pub-point  (priv-to-pub eph-priv)
  =/  eph-pub=@  (serialize-point eph-pub-point)
  =/  ua-pub-point  (deserialize-p256 ua-pub)
  =/  shared-point  (mul-point-scalar ua-pub-point eph-priv)
  =/  ecdh-secret=@  x.shared-point
  =/  info-label=byts  (cord-to-byts-null 'WebPush: info')
  =/  info-1=@
    %+  can  3
    :~  [65 eph-pub]
        [65 ua-pub]
        [wid.info-label dat.info-label]
    ==
  =/  prk-1=@  (extract:hkdf [16 ua-auth] [32 ecdh-secret])
  =/  ikm=@  (expand:hkdf prk-1 [144 info-1] 32)
  =/  prk-2=@  (extract:hkdf [16 salt] [32 ikm])
  =/  cek-info=byts  (cord-to-byts-null 'Content-Encoding: aes128gcm')
  =/  cek=@  (expand:hkdf prk-2 cek-info 16)
  =/  nonce-info=byts  (cord-to-byts-null 'Content-Encoding: nonce')
  =/  nonce=@  (expand:hkdf prk-2 nonce-info 12)
  =/  pt-byts=@  (rev 3 p.plaintext q.plaintext)   ::  octs to MSB for crypto
  =/  padded-len=@ud  +(p.plaintext)
  =/  padded=@  (add (lsh [3 1] pt-byts) 2)       ::  plaintext || 0x02 delimiter
  =/  gcm-result  (en:aes-gcm cek nonce [0 0] [padded-len padded])
  =/  ct-len=@ud  p.ciphertext.gcm-result
  =/  rs=@ud  4.096
  ::  convert MSB-first crypto values to LSB-first wire format
  =/  salt-octs=@    (rev 3 16 salt)
  =/  rs-be=@        (rev 3 4 rs)
  =/  eph-pub-octs=@  (rev 3 65 eph-pub)
  =/  ct-octs=@      (rev 3 ct-len q.ciphertext.gcm-result)
  =/  tag-octs=@     (rev 3 16 tag.gcm-result)
  ::  aes128gcm payload: salt(16) || rs(4) || idlen(1) || keyid(65) || ct || tag(16)
  =/  body=@
    %+  can  3
    :~  [16 salt-octs]
        [4 rs-be]
        [1 65]
        [65 eph-pub-octs]
        [ct-len ct-octs]
        [16 tag-octs]
    ==
  =/  body-len=@ud  (add 102 ct-len)  ::  86 header + ct + 16 tag
  [body-len body]
++  message-to-json
  |=  msg=push-message:push
  ^-  octs
  =/  pairs=(list [@t json])
    :~  ['title' [%s title.msg]]
        ['body' [%s body.msg]]
    ==
  =?  pairs  ?=(^ icon.msg)
    (snoc pairs ['icon' [%s u.icon.msg]])
  =?  pairs  ?=(^ url.msg)
    (snoc pairs ['url' [%s u.url.msg]])
  =?  pairs  ?=(^ tag.msg)
    (snoc pairs ['tag' [%s u.tag.msg]])
  =/  jon=json  [%o (~(gas by *(map @t json)) pairs)]
  (as-octs:mimes:html (en:json:html jon))
++  send-notification
  |=  [sub=subscription:push config=push-config:push msg=octs exp=@ud eny=@]
  ^-  request:http
  =/  ep-len=@ud  (met 3 endpoint.sub)
  =/  eph-priv=@
    %+  mod
      (shay (add 36 ep-len) (can 3 ~[[32 eny] [4 'ekey'] [ep-len endpoint.sub]]))
    (dec n.t)
  =.  eph-priv  ?:(=(0 eph-priv) 1 eph-priv)
  =/  salt-raw=@
    %+  end  [3 16]
    (shay (add 36 ep-len) (can 3 ~[[32 eny] [4 'salt'] [ep-len endpoint.sub]]))
  =/  push-salt=@  (rev 3 16 salt-raw)
  =/  body=octs
    (encrypt-payload p256dh.sub auth.sub msg eph-priv push-salt)
  =/  hdrs=(list [key=@t value=@t])
    (make-vapid-headers endpoint.sub config exp)
  [%'POST' endpoint.sub hdrs `body]
--
