::  iris-state: HTTP client service state
::
|_  st=iris-state:nexus
++  grab
  |%
  ++  noun  ,iris-state:nexus
  --
++  grow
  |%
  ++  noun  st
  ++  json
    ^-  ^json
    :-  %o
    %-  ~(gas by *(map @t ^json))
    :~  ['version' [%n '0']]
        :-  'requests'
        :-  %a
        %+  turn  ~(tap by requests.st)
        |=  [=wire [sender=rail:tarball url=@t]]
        %-  pairs:enjs:format
        :~  ['wire' s+(spat wire)]
            ['sender' s+(spat (snoc path.sender name.sender))]
            ['url' s+url]
        ==
    ==
  ++  mime
    ^-  ^mime
    =/  txt=@t  (en:json:html json)
    [/application/json (as-octs:mimes:html txt)]
  --
--
