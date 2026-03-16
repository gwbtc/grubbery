/-  *claude
|_  reg=registry
++  grab
  |%
  ++  noun  registry
  --
++  grow
  |%
  ++  noun  reg
  ++  txt
    ^-  wain
    =/  keep-list=(list [@t @ud])  ~(tap by keeps.reg)
    =/  flight-list=(list [@ud [action=@t path=@t]])  ~(tap by flights.reg)
    ?:  &(=(~ keep-list) =(~ flight-list))  ~['No active requests.']
    :-  'ACTIVE REQUESTS:'
    %+  weld
      %+  turn  keep-list
      |=  [pax=@t updates=@ud]
      (crip "  keep {(trip pax)}{?:(=(0 updates) "" " ({(a-co:co updates)} updates)")}")
    %+  turn  flight-list
    |=  [id=@ud action=@t path=@t]
    (crip "  {(trip action)} {(trip path)}")
  --
++  grad  %noun
--
