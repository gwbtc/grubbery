::  inbox: the notification service's core types
::
::  A notification is a human-addressed message: the service owns
::  delivery (push) and acknowledgment (mack); metadata is an opaque
::  jobj (title/body/url are conventions, not protocol).
::
::  The inbox is one mop, newest first, keyed by creation time
::  (bumped by a tick on collision).
::
|%
+$  notification
  $:  id=@uv
      app=@t                  ::  registered app name
      from=rail:tarball       ::  provenance of the sending grub
      created=@da
      push=?
      mack=(unit @da)         ::  manually acked, when
      metadata=(map @t json)
  ==
+$  inbox  ((mop @da notification) gth)
++  on-inbox  ((on @da notification) gth)
::
++  da-to-ms  |=(d=@da `@ud`(div (mul (sub d ~1970.1.1) 1.000) ~s1))
::
++  notification-json
  |=  n=notification
  ^-  json
  %-  pairs:enjs:format
  :~  ['id' s+(scot %uv id.n)]
      ['app' s+app.n]
      ['from' s+(crip "{(spud path.from.n)}/{(trip name.from.n)}")]
      ['created_ms' (numb:enjs:format (da-to-ms created.n))]
      ['push' b+push.n]
      ['mack' ?~(mack.n ~ (numb:enjs:format (da-to-ms u.mack.n)))]
      ['metadata' [%o metadata.n]]
  ==
::
++  inbox-json
  |=  =inbox
  ^-  json
  :-  %a
  %+  turn  (tap:on-inbox inbox)
  |=([@da n=notification] (notification-json n))
--
