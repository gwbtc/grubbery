::  clay-state: Clay desk sync service state
::
|_  st=clay-state:nexus
++  grab
  |%
  ++  noun  ,clay-state:nexus
  --
++  grow
  |%
  ++  noun  st
  ++  json
    ^-  ^json
    :-  %o
    %-  ~(gas by *(map @t ^json))
    :~  ['version' [%n '0']]
        :-  'desks'
        :-  %a
        %+  turn  ~(tap in desks.st)
        |=(d=desk s+d)
    ==
  ++  mime
    ^-  ^mime
    =/  txt=@t  (en:json:html json)
    [/application/json (as-octs:mimes:html txt)]
  --
--
