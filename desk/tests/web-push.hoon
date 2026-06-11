::  tests/lib/web-push: Web Push encryption and VAPID authentication
::
/-  push
/+  *test, web-push, hkdf, aes-gcm
|%
++  test-extract-origin-https
  %+  expect-eq
    !>('https://fcm.googleapis.com')
  !>((extract-origin:web-push 'https://fcm.googleapis.com/fcm/send/abc123'))
::
++  test-extract-origin-with-port
  %+  expect-eq
    !>('https://push.example.com:8443')
  !>((extract-origin:web-push 'https://push.example.com:8443/push/v1/abc'))
::
++  test-generate-vapid-keypair
  =/  eny  0xdead.beef.cafe.babe.1234.5678.abcd.ef01.
            dead.beef.cafe.babe.1234.5678.abcd.ef01
  =/  config  (generate-vapid-keypair:web-push eny 'mailto:test@example.com')
  =/  pub-len  (met 3 public-key.config)
  =/  derived-pub  (serialize-point:web-push (priv-to-pub:web-push private-key.config))
  ;:  weld
    (expect !>(&((gte pub-len 64) (lte pub-len 65))))
    %+  expect-eq  !>(public-key.config)  !>(derived-pub)
    %+  expect-eq  !>('mailto:test@example.com')  !>(sub.config)
  ==
::
++  test-message-to-json
  =/  msg=push-message:push
    ['Test Title' 'Test Body' `'icon.png' `'https://example.com' `'tag1']
  =/  result  (message-to-json:web-push msg)
  =/  jon  (de:json:html q.result)
  ?~  jon  (expect-eq !>(%decode-failed) !>(%should-succeed))
  ?.  ?=(%o -.u.jon)
    (expect-eq !>(%not-object) !>(%should-be-object))
  =/  obj  p.u.jon
  ;:  weld
    %+  expect-eq  !>(`[%s 'Test Title'])  !>((~(get by obj) 'title'))
    %+  expect-eq  !>(`[%s 'Test Body'])   !>((~(get by obj) 'body'))
    %+  expect-eq  !>(`[%s 'icon.png'])    !>((~(get by obj) 'icon'))
    %+  expect-eq  !>(`[%s 'https://example.com'])  !>((~(get by obj) 'url'))
  ==
::
++  test-message-to-json-special-chars
  =/  title=@t  (rap 3 ~['He said ' '"' 'hello' '"'])
  =/  msg=push-message:push
    [title 'body with backslash \\' ~ ~ ~]
  =/  result  (message-to-json:web-push msg)
  =/  jon  (de:json:html q.result)
  (expect !>(?=(^ jon)))
::
++  test-encrypt-payload-structure
  =/  priv  0xc9af.a9d8.45ba.75e6.b477.46a2.1ece.b8ec.
              769e.4539.7ea6.e407.1537.7892.a0e3.a8f5
  =/  pub-point  (priv-to-pub:web-push priv)
  =/  pub  (serialize-point:web-push pub-point)
  =/  auth  0x1234.5678.9abc.def0.1234.5678.9abc.def0
  =/  plaintext=octs  (as-octs:mimes:html 'hello')
  =/  eph-priv  0x2
  =/  salt  0xaaaa.bbbb.cccc.dddd.eeee.ffff.0000.1111
  =/  result
    (encrypt-payload:web-push pub auth plaintext eph-priv salt)
  (expect !>((gte p.result 108)))
::
++  test-encrypt-payload-roundtrip
  =/  ua-priv  0xc9af.a9d8.45ba.75e6.b477.46a2.1ece.b8ec.
                769e.4539.7ea6.e407.1537.7892.a0e3.a8f5
  =/  ua-pub-point  (priv-to-pub:web-push ua-priv)
  =/  ua-pub  (serialize-point:web-push ua-pub-point)
  =/  ua-auth  0x1234.5678.9abc.def0.1234.5678.9abc.def0
  =/  plaintext=octs  (as-octs:mimes:html 'hello web push')
  =/  eph-priv  0x3
  =/  salt  0xdead.beef.cafe.babe.1234.5678.abcd.ef01
  =/  result
    (encrypt-payload:web-push ua-pub ua-auth plaintext eph-priv salt)
  =/  body  q.result
  =/  body-len  p.result
  =/  ct-len  (sub body-len 102)
  =/  tag-octs  (cut 3 [(sub body-len 16) 16] body)
  =/  tag  (rev 3 16 tag-octs)
  =/  ct-octs  (cut 3 [86 ct-len] body)
  =/  ct  (rev 3 ct-len ct-octs)
  =/  eph-pub-point  (priv-to-pub:web-push eph-priv)
  =/  eph-pub  (serialize-point:web-push eph-pub-point)
  =/  shared-point  (mul-point-scalar:web-push ua-pub-point eph-priv)
  =/  ecdh-secret  x.shared-point
  =/  info-label=byts  (cord-to-byts-null:web-push 'WebPush: info')
  =/  info-1
    %+  can  3
    :~  [65 eph-pub]
        [65 ua-pub]
        [wid.info-label dat.info-label]
    ==
  =/  prk-1  (extract:hkdf [16 ua-auth] [32 ecdh-secret])
  =/  ikm  (expand:hkdf prk-1 [144 info-1] 32)
  =/  prk-2  (extract:hkdf [16 salt] [32 ikm])
  =/  cek-info=byts  (cord-to-byts-null:web-push 'Content-Encoding: aes128gcm')
  =/  cek  (expand:hkdf prk-2 cek-info 16)
  =/  nonce-info=byts  (cord-to-byts-null:web-push 'Content-Encoding: nonce')
  =/  nonce  (expand:hkdf prk-2 nonce-info 12)
  =/  decrypted  (de:aes-gcm cek nonce [0 0] [ct-len ct] tag)
  ?~  decrypted
    (expect-eq !>(%decryption-failed) !>(%should-have-succeeded))
  =/  pt-padded  q.u.decrypted
  =/  pt-len  (dec p.u.decrypted)
  =/  delimiter  (end 3 pt-padded)
  =/  pt-byts  (rsh [3 1] pt-padded)
  =/  pt-recovered  (rev 3 pt-len pt-byts)
  ;:  weld
    %+  expect-eq  !>(0x2)  !>(delimiter)
    %+  expect-eq
      !>((as-octs:mimes:html 'hello web push'))
    !>([pt-len pt-recovered])
  ==
--
