::  tests/lib/hkdf: HKDF-SHA-256 key derivation (RFC 5869)
::
/+  *test, hkdf
|%
++  test-extract-a1
  =/  ikm=byts   [22 (fil 3 22 0xb)]
  =/  salt=byts  [13 0x102.0304.0506.0708.090a.0b0c]
  =/  expected=@
    0x777.0936.2c2e.32df.0ddc.3f0d.c47b.ba63.
      90b6.c73b.b50f.9c31.22ec.844a.d7c2.b3e5
  %+  expect-eq
    !>(expected)
  !>((extract:hkdf salt ikm))
::
++  test-expand-a1
  =/  prk=@
    0x777.0936.2c2e.32df.0ddc.3f0d.c47b.ba63.
      90b6.c73b.b50f.9c31.22ec.844a.d7c2.b3e5
  =/  info=byts  [10 0xf0f1.f2f3.f4f5.f6f7.f8f9]
  =/  expected=@
    0x3cb2.5f25.faac.d57a.9043.4f64.d036.2f2a.
      2d2d.0a90.cf1a.5a4c.5db0.2d56.ecc4.c5bf.
      3400.7208.d5b8.8718.5865
  %+  expect-eq
    !>(expected)
  !>((expand:hkdf prk info 42))
::
++  test-extract-a2
  =/  ikm=byts
    :-  80
    0x1.0203.0405.0607.0809.0a0b.0c0d.0e0f.
      1011.1213.1415.1617.1819.1a1b.1c1d.1e1f.
      2021.2223.2425.2627.2829.2a2b.2c2d.2e2f.
      3031.3233.3435.3637.3839.3a3b.3c3d.3e3f.
      4041.4243.4445.4647.4849.4a4b.4c4d.4e4f
  =/  salt=byts
    :-  80
    0x6061.6263.6465.6667.6869.6a6b.6c6d.6e6f.
      7071.7273.7475.7677.7879.7a7b.7c7d.7e7f.
      8081.8283.8485.8687.8889.8a8b.8c8d.8e8f.
      9091.9293.9495.9697.9899.9a9b.9c9d.9e9f.
      a0a1.a2a3.a4a5.a6a7.a8a9.aaab.acad.aeaf
  =/  expected=@
    0x6a6.b88c.5853.361a.0610.4c9c.eb35.b45c.
      ef76.0014.9046.7101.4a19.3f40.c15f.c244
  %+  expect-eq
    !>(expected)
  !>((extract:hkdf salt ikm))
::
++  test-expand-a2
  =/  prk=@
    0x6a6.b88c.5853.361a.0610.4c9c.eb35.b45c.
      ef76.0014.9046.7101.4a19.3f40.c15f.c244
  =/  info=byts
    :-  80
    0xb0b1.b2b3.b4b5.b6b7.b8b9.babb.bcbd.bebf.
      c0c1.c2c3.c4c5.c6c7.c8c9.cacb.cccd.cecf.
      d0d1.d2d3.d4d5.d6d7.d8d9.dadb.dcdd.dedf.
      e0e1.e2e3.e4e5.e6e7.e8e9.eaeb.eced.eeef.
      f0f1.f2f3.f4f5.f6f7.f8f9.fafb.fcfd.feff
  =/  expected=@
    0xb11e.398d.c803.27a1.c8e7.f78c.596a.4934.
      4f01.2eda.2d4e.fad8.a050.cc4c.19af.a97c.
      5904.5a99.cac7.8272.71cb.41c6.5e59.0e09.
      da32.7560.0c2f.09b8.3677.93a9.aca3.db71.
      cc30.c581.79ec.3e87.c14c.01d5.c1f3.434f.
      1d87
  %+  expect-eq
    !>(expected)
  !>((expand:hkdf prk info 82))
::
++  test-extract-a3
  =/  ikm=byts   [22 (fil 3 22 0xb)]
  =/  salt=byts  [0 0]
  =/  expected=@
    0x19ef.24a3.2c71.7b16.7f33.a91d.6f64.8bdf.
      9659.6776.afdb.6377.ac43.4c1c.293c.cb04
  %+  expect-eq
    !>(expected)
  !>((extract:hkdf salt ikm))
::
++  test-expand-a3
  =/  prk=@
    0x19ef.24a3.2c71.7b16.7f33.a91d.6f64.8bdf.
      9659.6776.afdb.6377.ac43.4c1c.293c.cb04
  =/  info=byts  [0 0]
  =/  expected=@
    0x8da4.e775.a563.c18f.715f.802a.063c.5a31.
      b8a1.1f5c.5ee1.879e.c345.4e5f.3c73.8d2d.
      9d20.1395.faa4.b61a.96c8
  %+  expect-eq
    !>(expected)
  !>((expand:hkdf prk info 42))
--
