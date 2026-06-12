::  mar/urb-udiffs.hoon
::
::  Mark for urb PKI udiffs — non-invertible diffs emitted per block.
::  Stored in a file so subscribers get live updates.
::
|_  =udiffs:point:jael
++  grow
  |%
  ++  noun  udiffs
  ++  json
    ^-  ^json
    :-  %a
    %+  turn  udiffs
    |=  [=ship ud=udiff:point:jael]
    ^-  ^json
    =/  dif  +.ud
    %-  pairs:enjs:format
    :~  ['ship' s+(scot %p ship)]
        ['block' (numb:enjs:format number.id.ud)]
        :-  'diff'
        ?-  -.dif
          %rift      (pairs:enjs:format ~[['type' s+'rift'] ['rift' (numb:enjs:format rift.dif)] ['boot' b+boot.dif]])
          %keys      (pairs:enjs:format ~[['type' s+'keys'] ['life' (numb:enjs:format life.dif)] ['boot' b+boot.dif]])
          %spon      (pairs:enjs:format ~[['type' s+'spon'] ['sponsor' ?~(sponsor.dif ~ s+(scot %p u.sponsor.dif))]])
        ::  %fief      (pairs:enjs:format ~[['type' s+'fief'] ['fief' b+?=(^ fief.dif)]])
          %disavow   (pairs:enjs:format ~[['type' s+'disavow']])
        ==
    ==
  ++  mime
    =/  jon=^json  json
    [/application/json (as-octs:mimes:html (en:json:html jon))]
  --
++  grab
  |%
  ++  noun  udiffs:point:jael
  --
--
