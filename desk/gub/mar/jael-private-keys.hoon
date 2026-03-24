::  private-keys: mark for jael private key state
::
|_  [=life vein=(map life ring)]
++  grab
  |%
  ++  noun  ,[^life (map ^life ring)]
  --
++  grow
  |%
  ++  noun  [life vein]
  ++  json
    ^-  ^json
    %-  pairs:enjs:format
    :~  ['life' (numb:enjs:format life)]
        ['keys' (numb:enjs:format ~(wyt by vein))]
    ==
  ++  mime  [/application/json (as-octs:mimes:html (en:json:html json))]
  --
++  grad  %noun
--
