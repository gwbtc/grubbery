::  inbox: the notification service's mop of notifications
::
/<  inbox  /lib/inbox.hoon
|_  =inbox:inbox
++  grab
  |%
  ++  noun  ,inbox:^inbox
  --
++  grow
  |%
  ++  noun  inbox
  ++  json  (inbox-json:^inbox inbox)
  ++  mime
    =/  jon=^json  json
    [/application/json (as-octs:mimes:html (en:json:html jon))]
  --
--
