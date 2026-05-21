::  lib/hkdf: HKDF-SHA-256 (RFC 5869)
::
::  +extract outputs a bare atom (the PRK).
::  +expand accepts a bare atom for prk since its width is always 32.
::
|%
++  extract
  |=  [salt=byts ikm=byts]
  ^-  @
  (hmac-sha256l:hmac:crypto salt ikm)
::
++  expand
  |=  [prk=@ info=byts len=@ud]
  ^-  @
  ?>  (lte len 8.160)  ::  255 * 32
  =/  n=@ud  (add (div len 32) ?:(!=(0 (mod len 32)) 1 0))
  =/  t=@    0
  =/  t-wid=@ud  0
  =/  okm=@  0
  =/  okm-wid=@ud  0
  =/  i=@ud  1
  |-
  ?:  (gth i n)
    (rsh [3 (sub okm-wid len)] okm)
  =/  msg=@
    %+  can  3
    :~  [1 i]
        [wid.info dat.info]
        [t-wid t]
    ==
  =/  msg-wid=@ud  (add (add t-wid wid.info) 1)
  =.  t  (hmac-sha256l:hmac:crypto [32 prk] [msg-wid msg])
  =.  t-wid  32
  =.  okm  (add (lsh [3 32] okm) t)
  =.  okm-wid  (add okm-wid 32)
  $(i +(i))
--
