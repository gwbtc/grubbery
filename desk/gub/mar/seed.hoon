::  mar/seed.hoon
::
::  Mark for a ship's identity seed. The seed is the master
::  secret from which all keys (networking, signing) derive.
::
|_  sed=$%([%t =@t] [%uw =@uw] [%ux =@ux])
++  grow
  |%
  ++  noun  sed
  ++  json
    ^-  ^json
    ?-  -.sed
      %t   (pairs:enjs:format ~[['type' s+'text'] ['seed' s+t.sed]])
      %uw  (pairs:enjs:format ~[['type' s+'uw'] ['seed' s+(scot %uw uw.sed)]])
      %ux  (pairs:enjs:format ~[['type' s+'ux'] ['seed' s+(scot %ux ux.sed)]])
    ==
  ++  mime
    =/  jon=^json  json
    [/application/json (as-octs:mimes:html (en:json:html jon))]
  --
++  grab
  |%
  +$  noun  $%([%t =@t] [%uw =@uw] [%ux =@ux])
  --
--
