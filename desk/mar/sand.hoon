::  sand: sandbox filter tree mark
::
/+  nexus, tarball
!: :: turn on stack trace
|_  =sand:nexus
++  grad  %noun
++  grow
  |%
  ++  noun  sand
  ++  json  (sand-to-json sand)
  --
++  grab
  |%
  ++  noun  sand:nexus
  --
++  road-to-json
  |=  =road:tarball
  ^-  json
  ?-    -.road
      %&
    ?-  -.p.road
      %&  s+(crip (spud (snoc path.p.p.road name.p.p.road)))
      %|  s+(crip (spud p.p.road))
    ==
      %|
    %-  pairs:enjs:format
    :~  ['up' (numb:enjs:format p.p.road)]
        :-  'dest'
        ?-  -.q.p.road
          %&  s+(crip (spud (snoc path.p.q.p.road name.p.q.p.road)))
          %|  s+(crip (spud p.q.p.road))
        ==
    ==
  ==
++  weir-to-json
  |=  =weir:nexus
  ^-  json
  %-  pairs:enjs:format
  :~  ['make' [%a (turn ~(tap in make.weir) road-to-json)]]
      ['poke' [%a (turn ~(tap in poke.weir) road-to-json)]]
      ['peek' [%a (turn ~(tap in peek.weir) road-to-json)]]
  ==
++  sand-to-json
  |=  s=sand:nexus
  ^-  json
  =/  subdirs=json  [%o (~(run by dir.s) sand-to-json)]
  ?~  fil.s
    (pairs:enjs:format ~[['dirs' subdirs]])
  %-  pairs:enjs:format
  :~  ['weir' (weir-to-json u.fil.s)]
      ['dirs' subdirs]
  ==
--
