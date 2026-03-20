::  public-keys-result: mark for jael public key updates
::
|_  =public-keys-result:jael
++  grab
  |%
  ++  noun  public-keys-result:jael
  --
++  grow
  |%
  ++  noun  public-keys-result
  ++  json
    ^-  ^json
    ?-    -.public-keys-result
        %full
      %-  pairs:enjs:format
      :~  ['type' s+%full]
          ['ships' (numb:enjs:format ~(wyt by points.public-keys-result))]
      ==
        %diff
      %-  pairs:enjs:format
      :~  ['type' s+%diff]
          ['who' s+(scot %p who.public-keys-result)]
      ==
        %breach
      %-  pairs:enjs:format
      :~  ['type' s+%breach]
          ['who' s+(scot %p who.public-keys-result)]
      ==
    ==
  ++  mime  [/application/json (as-octs:mimes:html (en:json:html json))]
  --
++  grad  %noun
--
