::  ws-state: websocket client service table
::
|_  st=ws-state:nexus
++  grab
  |%
  ++  noun  ,ws-state:nexus
  --
++  grow
  |%
  ++  noun  st
  ++  json
    ^-  ^json
    =/  row
      |=  [id=[@t ^json] r=ws-row:nexus]
      %-  pairs:enjs:format
      :~  id
          ['owner' s+(spat (snoc path.owner.r name.owner.r))]
          ['key' s+(spat key.r)]
          ['url' s+url.r]
      ==
    :-  %o
    %-  ~(gas by *(map @t ^json))
    :~  ['version' [%n '0']]
        :-  'pending'
        :-  %a
        %+  turn  ~(tap by pending.st)
        |=  [=wire r=ws-row:nexus]
        (row ['wire' s+(spat wire)] r)
        :-  'open'
        :-  %a
        %+  turn  ~(tap by open.st)
        |=  [wid=@ud r=ws-row:nexus]
        (row ['wid' (numb:enjs:format wid)] r)
    ==
  ++  mime
    ^-  ^mime
    =/  txt=@t  (en:json:html json)
    [/application/json (as-octs:mimes:html txt)]
  --
--
