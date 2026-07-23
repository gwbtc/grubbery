::  push-state: push notification service state
::
|_  st=push-state:nexus
++  grab
  |%
  ++  noun  ,push-state:nexus
  --
++  grow
  |%
  ++  noun  st
  ++  json
    ^-  ^json
    %-  pairs:enjs:format
    :~  ['version' [%n '0']]
        ['has_config' [%b ?=(^ config.st)]]
        ['sub_count' [%n (crip (a-co:co ~(wyt by subs.st)))]]
        :-  'subs'
        :-  %a
        %+  turn  ~(tap by subs.st)
        |=  [id=@ta sub=push-sub:nexus]
        %-  pairs:enjs:format
        :~  ['id' s+id]
            ['ship' s+(scot %p ship.sub)]
            ['endpoint' s+endpoint.subscription.sub]
        ==
        :-  'inflight_count'
        [%n (crip (a-co:co ~(wyt by inflight.st)))]
    ==
  ++  mime
    ^-  ^mime
    =/  txt=@t  (en:json:html json)
    [/application/json (as-octs:mimes:html txt)]
  --
--
