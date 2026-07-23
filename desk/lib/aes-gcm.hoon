::  lib/aes-gcm: AES-128-GCM authenticated encryption (NIST SP 800-38D)
::
|%
::  +gf-mul: GF(2^128) multiplication with GCM polynomial
::
++  gf-mul
  |=  [x=@uxH y=@uxH]
  ^-  @uxH
  =/  z=@uxH  0x0
  =/  v=@uxH  x
  =/  r=@uxH  0xe100.0000.0000.0000.0000.0000.0000.0000
  =/  i=@ud   0
  |-
  ?:  =(i 128)  z
  =?  z  !=((dis (rsh [0 (sub 127 i)] y) 1) 0)  ::  bit i of y set
    (mix z v)
  =/  lsb=?  !=((dis v 1) 0)
  =.  v  (rsh 0 v)
  =?  v  lsb  (mix v r)                          ::  XOR reduction poly
  $(i +(i))
::  +ghash: GHASH -- GF multiply-and-XOR over 16-byte blocks
::
++  ghash
  |=  [h=@uxH aad=octs ct=octs]
  ^-  @uxH
  =/  aad-padded=octs
    =/  pad-len=@ud  (mod (sub 16 (mod p.aad 16)) 16)
    [(add p.aad pad-len) (lsh [3 pad-len] q.aad)]
  =/  ct-padded=octs
    =/  pad-len=@ud  (mod (sub 16 (mod p.ct 16)) 16)
    [(add p.ct pad-len) (lsh [3 pad-len] q.ct)]
  =/  len-block=@uxH                              ::  64-bit lengths in bits
    %+  can  3
    :~  [8 (mul 8 p.ct)]
        [8 (mul 8 p.aad)]
    ==
  =/  data=octs                                   ::  aad || ct || lengths
    :-  (add (add p.aad-padded p.ct-padded) 16)
    %+  can  3
    :~  [16 len-block]
        [p.ct-padded q.ct-padded]
        [p.aad-padded q.aad-padded]
    ==
  =/  n-blocks=@ud  (div p.data 16)
  =/  x=@uxH  0x0
  =/  i=@ud   0
  |-
  ?:  =(i n-blocks)  x
  =/  block=@uxH
    %+  end  7
    (rsh [3 (mul 16 (sub (dec n-blocks) i))] q.data)
  =.  x  (gf-mul (mix x block) h)
  $(i +(i))
::  +en: AES-128-GCM encrypt
::
++  en
  |=  [key=@uxH iv=@ aad=octs txt=octs]
  ^-  [ciphertext=octs tag=@uxH]
  =/  h=@uxH  (~(en ecba:aes:crypto key) 0x0)     ::  hash subkey
  =/  j0=@uxH  (add (lsh [3 4] iv) 1)             ::  IV || 0x00000001
  =/  ctr0=@uxH  (inc:aes:crypto 5 j0)            ::  CTR starts at J0+1
  =/  ciphertext=@
    (~(en ctra:aes:crypto key 5 p.txt ctr0) q.txt)
  =/  ct=octs  [p.txt ciphertext]
  =/  ghash-val=@uxH  (ghash h aad ct)
  =/  tag=@uxH  (mix ghash-val (~(en ecba:aes:crypto key) j0))
  [ct tag]
::  +de: AES-128-GCM decrypt, ~ if tag mismatch
::
++  de
  |=  [key=@uxH iv=@ aad=octs ct=octs expected-tag=@uxH]
  ^-  (unit octs)
  =/  h=@uxH  (~(en ecba:aes:crypto key) 0x0)
  =/  j0=@uxH  (add (lsh [3 4] iv) 1)
  =/  ghash-val=@uxH  (ghash h aad ct)
  =/  tag=@uxH  (mix ghash-val (~(en ecba:aes:crypto key) j0))
  ?.  =(tag expected-tag)  ~
  =/  ctr0=@uxH  (inc:aes:crypto 5 j0)
  =/  plaintext=@
    (~(en ctra:aes:crypto key 5 p.ct ctr0) q.ct)
  (some [p.ct plaintext])
--
