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
    =/  slot-list  ~(tap by slots.reg)
    :-  ?:(live.reg 'LIVE' 'HALTED')
    ?~  slot-list  ~['No active requests.']
    :-  'ACTIVE REQUESTS:'
    %+  turn  slot-list
    |=  [id=@ud act=@t pax=@t]
    (crip "  [{(a-co:co id)}] {(trip act)} {(trip pax)}")
  --
++  grad  %noun
--
