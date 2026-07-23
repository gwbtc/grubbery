::  tests/lib/aes-gcm: AES-128-GCM authenticated encryption
::
/+  *test, aes-gcm
|%
++  test-gcm-empty
  =/  key=@uxH  0x0
  =/  iv=@      0x0
  =/  result  (en:aes-gcm key iv [0 0] [0 0])
  ;:  weld
    %+  expect-eq
      !>(0)
    !>(p.ciphertext.result)
    %+  expect-eq
      !>(`@ux`0x58e2.fcce.fa7e.3061.367f.1d57.a4e7.455a)
    !>(`@ux`tag.result)
  ==
::
++  test-gcm-basic
  =/  key=@uxH  0x0
  =/  iv=@      0x0
  =/  result  (en:aes-gcm key iv [0 0] [16 0x0])
  ;:  weld
    %+  expect-eq
      !>(`@ux`0x388.dace.60b6.a392.f328.c2b9.71b2.fe78)
    !>(`@ux`q.ciphertext.result)
    %+  expect-eq
      !>(`@ux`0xab6e.47d4.2cec.13bd.f53a.67b2.1257.bddf)
    !>(`@ux`tag.result)
  ==
::
++  test-gcm-nonzero
  =/  key=@uxH  0xfeff.e992.8665.731c.6d6a.8f94.6730.8308
  =/  iv=@      0xcafe.babe.face.dbad.deca.f888
  =/  pt=octs
    :-  64
    0xd931.3225.f884.06e5.a559.09c5.aff5.269a.
      86a7.a953.1534.f7da.2e4c.303d.8a31.8a72.
      1c3c.0c95.9568.0953.2fcf.0e24.49a6.b525.
      b16a.edf5.aa0d.e657.ba63.7b39.1aaf.d255
  =/  result  (en:aes-gcm key iv [0 0] pt)
  =/  expected-ct=@
    0x4283.1ec2.2177.7424.4b72.21b7.84d0.d49c.
      e3aa.212f.2c02.a4e0.35c1.7e23.29ac.a12e.
      21d5.14b2.5466.931c.7d8f.6a5a.ac84.aa05.
      1ba3.0b39.6a0a.ac97.3d58.e091.473f.5985
  =/  expected-tag=@uxH
    0x4d5c.2af3.27cd.64a6.2cf3.5abd.2ba6.fab4
  ;:  weld
    %+  expect-eq
      !>(`@ux`expected-ct)
    !>(`@ux`q.ciphertext.result)
    %+  expect-eq
      !>(`@ux`expected-tag)
    !>(`@ux`tag.result)
  ==
::
++  test-gcm-with-aad
  =/  key=@uxH  0xfeff.e992.8665.731c.6d6a.8f94.6730.8308
  =/  iv=@      0xcafe.babe.face.dbad.deca.f888
  =/  pt=octs
    :-  60
    0xd931.3225.f884.06e5.a559.09c5.aff5.269a.
      86a7.a953.1534.f7da.2e4c.303d.8a31.8a72.
      1c3c.0c95.9568.0953.2fcf.0e24.49a6.b525.
      b16a.edf5.aa0d.e657.ba63.7b39
  =/  aad=octs
    [20 0xfeed.face.dead.beef.feed.face.dead.beef.abad.dad2]
  =/  result  (en:aes-gcm key iv aad pt)
  =/  expected-ct=@
    0x4283.1ec2.2177.7424.4b72.21b7.84d0.d49c.
      e3aa.212f.2c02.a4e0.35c1.7e23.29ac.a12e.
      21d5.14b2.5466.931c.7d8f.6a5a.ac84.aa05.
      1ba3.0b39.6a0a.ac97.3d58.e091
  =/  expected-tag=@uxH
    0x5bc9.4fbc.3221.a5db.94fa.e95a.e712.1a47
  ;:  weld
    %+  expect-eq
      !>(`@ux`expected-ct)
    !>(`@ux`q.ciphertext.result)
    %+  expect-eq
      !>(`@ux`expected-tag)
    !>(`@ux`tag.result)
  ==
::
++  test-gcm-nonaligned
  =/  key=@uxH  0xfeff.e992.8665.731c.6d6a.8f94.6730.8308
  =/  iv=@      0xcafe.babe.face.dbad.deca.f888
  =/  pt=octs   [7 0xd9.3132.25f8.8406]
  =/  result  (en:aes-gcm key iv [0 0] pt)
  ;:  weld
    %+  expect-eq  !>(7)  !>(p.ciphertext.result)
    =/  decrypted  (de:aes-gcm key iv [0 0] ciphertext.result tag.result)
    %+  expect-eq  !>(`pt)  !>(decrypted)
  ==
::
++  test-gcm-decrypt-roundtrip
  =/  key=@uxH  0xfeff.e992.8665.731c.6d6a.8f94.6730.8308
  =/  iv=@      0xcafe.babe.face.dbad.deca.f888
  =/  pt=octs   [16 0xd931.3225.f884.06e5.a559.09c5.aff5.269a]
  =/  result  (en:aes-gcm key iv [0 0] pt)
  =/  decrypted  (de:aes-gcm key iv [0 0] ciphertext.result tag.result)
  %+  expect-eq
    !>(`pt)
  !>(decrypted)
::
++  test-gcm-decrypt-bad-tag
  =/  key=@uxH  0xfeff.e992.8665.731c.6d6a.8f94.6730.8308
  =/  iv=@      0xcafe.babe.face.dbad.deca.f888
  =/  pt=octs   [16 0xd931.3225.f884.06e5.a559.09c5.aff5.269a]
  =/  result  (en:aes-gcm key iv [0 0] pt)
  =/  bad-tag=@uxH  (mix tag.result 1)
  =/  decrypted  (de:aes-gcm key iv [0 0] ciphertext.result bad-tag)
  %+  expect-eq
    !>(~)
  !>(decrypted)
--
