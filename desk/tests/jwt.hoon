::  tests/lib/jwt: JSON Web Tokens with ES256 signatures
::
/+  *test, jwt
|%
++  test-p256-generator
  =/  pub  (priv-to-pub:jwt 1)
  ;:  weld
    %+  expect-eq
      !>  0x6b17.d1f2.e12c.4247.f8bc.e6e5.63a4.40f2.
            7703.7d81.2deb.33a0.f4a1.3945.d898.c296
    !>(x.pub)
    %+  expect-eq
      !>  0x4fe3.42e2.fe1a.7f9b.8ee7.eb4a.7c0f.9e16.
            2bce.3357.6b31.5ece.cbb6.4068.37bf.51f5
    !>(y.pub)
  ==
::
++  test-p256-double-generator
  =/  pub  (priv-to-pub:jwt 2)
  ;:  weld
    %+  expect-eq
      !>  0x7cf2.7b18.8d03.4f7e.8a52.3803.04b5.1ac3.
            c089.69e2.77f2.1b35.a60b.48fc.4766.9978
    !>(x.pub)
    %+  expect-eq
      !>  0x777.5510.db8e.d040.293d.9ac6.9f74.30db.
            ba7d.ade6.3ce9.8229.9e04.b79d.2278.73d1
    !>(y.pub)
  ==
::
++  test-p256-serialize-roundtrip
  =/  priv  0xc9af.a9d8.45ba.75e6.b477.46a2.1ece.b8ec.
              769e.4539.7ea6.e407.1537.7892.a0e3.a8f5
  =/  pub  (priv-to-pub:jwt priv)
  =/  serialized  (serialize-point:jwt pub)
  =/  deserialized  (decompress-point:jwt (compress-point:jwt pub))
  ;:  weld
    %+  expect-eq
      !>(x.pub)
    !>(x.deserialized)
    %+  expect-eq
      !>(y.pub)
    !>(y.deserialized)
  ==
::
++  test-p256-ecdsa-sign
  =/  priv  0x1
  =/  hash  (rev 3 32 (shax 'example'))
  =/  sig  (ecdsa-raw-sign:jwt hash priv)
  =/  n  n.t:jwt
  ;:  weld
    (expect !>(&((gth r.sig 0) (lth r.sig n))))
    (expect !>(&((gth s.sig 0) (lth s.sig n))))
    (expect !>((lte (mul 2 s.sig) n)))
  ==
::
++  test-es256-sign-size
  =/  priv  0xc9af.a9d8.45ba.75e6.b477.46a2.1ece.b8ec.
              769e.4539.7ea6.e407.1537.7892.a0e3.a8f5
  =/  hash  (rev 3 32 (shax 'example'))
  =/  sig  (es256-sign:jwt hash priv)
  (expect !>((lte (met 3 sig) 64)))
::
++  test-cord-to-byts
  =/  result  (cord-to-byts:jwt 'abc')
  ;:  weld
    %+  expect-eq
      !>(3)
    !>(wid.result)
    %+  expect-eq
      !>(`@ux`0x61.6263)
    !>(`@ux`dat.result)
  ==
::
++  test-make-jwt
  =/  priv  0xc9af.a9d8.45ba.75e6.b477.46a2.1ece.b8ec.
              769e.4539.7ea6.e407.1537.7892.a0e3.a8f5
  =/  token
    %:  make-jwt:jwt
      'https://fcm.googleapis.com'
      1.700.000.000
      'mailto:test@example.com'
      priv
    ==
  =/  parts=(list @t)
    %+  turn
      %+  rash  token
      (more dot (cook crip (plus ;~(pose hig low nud hep cab))))
    |=(a=@t a)
  ;:  weld
    %+  expect-eq  !>(3)  !>((lent parts))
    =/  header-b64  (snag 0 parts)
    =/  header-octs  (de-base64url:jwt header-b64)
    ?~  header-octs
      (expect-eq !>(%header-decode-failed) !>(%should-succeed))
    =/  header-cord  (trip `@t`q.u.header-octs)
    (expect !>(!=((find "ES256" header-cord) ~)))
    =/  payload-b64  (snag 1 parts)
    =/  payload-octs  (de-base64url:jwt payload-b64)
    ?~  payload-octs
      (expect-eq !>(%payload-decode-failed) !>(%should-succeed))
    =/  payload-cord  (trip `@t`q.u.payload-octs)
    ;:  weld
      (expect !>(!=((find "fcm.googleapis.com" payload-cord) ~)))
      (expect !>(!=((find "1700000000" payload-cord) ~)))
      (expect !>(!=((find "test@example.com" payload-cord) ~)))
    ==
    =/  sig-b64  (snag 2 parts)
    =/  sig-octs  (de-base64url:jwt sig-b64)
    ?~  sig-octs
      (expect-eq !>(%sig-decode-failed) !>(%should-succeed))
    %+  expect-eq  !>(64)  !>(p.u.sig-octs)
  ==
::
++  test-encode-jwt
  =/  priv  0xc9af.a9d8.45ba.75e6.b477.46a2.1ece.b8ec.
              769e.4539.7ea6.e407.1537.7892.a0e3.a8f5
  =/  payload=json
    %-  pairs:enjs:format
    :~  ['iss' [%s 'test-issuer']]
        ['custom' [%s 'value']]
    ==
  =/  token  (encode-jwt:jwt payload priv)
  =/  decoded  (decode-jwt:jwt token)
  ?~  decoded
    (expect-eq !>(%decode-failed) !>(%should-succeed))
  ?.  ?=(%o -.payload.u.decoded)
    (expect-eq !>(%not-object) !>(%should-be-object))
  ;:  weld
    %+  expect-eq
      !>(`[%s 'test-issuer'])
    !>((~(get by p.payload.u.decoded) 'iss'))
    %+  expect-eq
      !>(`[%s 'value'])
    !>((~(get by p.payload.u.decoded) 'custom'))
  ==
::
++  test-decode-jwt-malformed
  ;:  weld
    %+  expect-eq  !>(~)  !>((decode-jwt:jwt 'abc.def'))
    %+  expect-eq  !>(~)  !>((decode-jwt:jwt 'a.b.c.d'))
    %+  expect-eq  !>(~)  !>((decode-jwt:jwt ''))
    %+  expect-eq  !>(~)  !>((decode-jwt:jwt 'nodots'))
  ==
::
++  test-decode-jwt
  =/  priv  0xc9af.a9d8.45ba.75e6.b477.46a2.1ece.b8ec.
              769e.4539.7ea6.e407.1537.7892.a0e3.a8f5
  =/  token  (make-jwt:jwt 'https://example.com' 1.700.000.000 'mailto:test@test.com' priv)
  =/  decoded  (decode-jwt:jwt token)
  ?~  decoded
    (expect-eq !>(%decode-failed) !>(%should-succeed))
  ?.  ?=(%o -.header.u.decoded)
    (expect-eq !>(%not-object) !>(%should-be-object))
  ;:  weld
    %+  expect-eq
      !>(`[%s 'ES256'])
    !>((~(get by p.header.u.decoded) 'alg'))
    %+  expect-eq  !>(64)  !>(p.signature.u.decoded)
  ==
::
++  test-verify-jwt
  =/  priv  0xc9af.a9d8.45ba.75e6.b477.46a2.1ece.b8ec.
              769e.4539.7ea6.e407.1537.7892.a0e3.a8f5
  =/  pub  (priv-to-pub:jwt priv)
  =/  token  (make-jwt:jwt 'https://example.com' 1.700.000.000 'mailto:test@test.com' priv)
  =/  result  (verify-jwt:jwt token pub)
  ?~  result
    (expect-eq !>(%verify-failed) !>(%should-succeed))
  ?.  ?=(%o -.payload.u.result)
    (expect-eq !>(%not-object) !>(%should-be-object))
  %+  expect-eq
    !>(`[%s 'https://example.com'])
  !>((~(get by p.payload.u.result) 'aud'))
::
++  test-verify-jwt-wrong-key
  =/  priv  0xc9af.a9d8.45ba.75e6.b477.46a2.1ece.b8ec.
              769e.4539.7ea6.e407.1537.7892.a0e3.a8f5
  =/  wrong-pub  (priv-to-pub:jwt 0x2)
  =/  token  (make-jwt:jwt 'https://example.com' 1.700.000.000 'mailto:test@test.com' priv)
  =/  result  (verify-jwt:jwt token wrong-pub)
  %+  expect-eq  !>(~)  !>(result)
::
++  test-validate-exp
  =/  payload=json
    %-  pairs:enjs:format
    :~  ['exp' [%n '1700000000']]
    ==
  ;:  weld
    (expect !>((validate-exp:jwt payload 1.699.999.999)))
    (expect !>((validate-exp:jwt payload 1.700.000.000)))
    %+  expect-eq  !>(%.n)  !>((validate-exp:jwt payload 1.700.000.001))
  ==
::
++  test-validate-nbf
  =/  payload=json
    %-  pairs:enjs:format
    :~  ['nbf' [%n '1700000000']]
    ==
  ;:  weld
    (expect !>((validate-nbf:jwt payload 1.700.000.001)))
    (expect !>((validate-nbf:jwt payload 1.700.000.000)))
    %+  expect-eq  !>(%.n)  !>((validate-nbf:jwt payload 1.699.999.999))
  ==
--
