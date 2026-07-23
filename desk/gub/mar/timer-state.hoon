::  timer-state: timer service state
::
|_  st=timer-state:nexus
++  grab
  |%
  ++  noun  ,timer-state:nexus
  --
++  grow
  |%
  ++  noun  st
  ++  json
    ^-  ^json
    :-  %o
    %-  ~(gas by *(map @t ^json))
    :~  ['version' [%n '0']]
        :-  'timers'
        :-  %a
        %+  turn  ~(tap by timers.st)
        |=  [key=[=rail:tarball =wire] when=@da]
        %-  pairs:enjs:format
        :~  ['path' s+(spat (snoc path.rail.key name.rail.key))]
            ['wire' s+(spat wire.key)]
            ['when' s+(scot %da when)]
        ==
    ==
  ++  mime
    ^-  ^mime
    =/  txt=@t  (en:json:html json)
    [/application/json (as-octs:mimes:html txt)]
  --
--
