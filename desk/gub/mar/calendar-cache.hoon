::  calendar-cache: derived order index over a calendar — regenerable
::
::  The json grow lays the order out flat, so a reader that can't
::  carry the calendar library (a tool) can still window it:
::    {thru_ms, refs: [{id, idx, l_ms, r_ms}]} sorted by l_ms
::
/<  cal  /lib/calendar.hoon
|_  =cache:cal
++  grab
  |%
  ++  noun  ,cache:cal
  --
++  grow
  |%
  ++  noun  cache
  ++  json
    ^-  ^json
    =/  refs=(list ref:cal)
      %-  zing
      %+  turn  (tap:on-order:cal order.cache)
      |=([@da rs=(set ref:cal)] ~(tap in rs))
    %-  pairs:enjs:format
    :~  ['thru_ms' (numb:enjs:format (da-to-ms:cal thru.cache))]
        :-  'refs'
        :-  %a
        %+  turn  (sort refs |=([a=ref:cal b=ref:cal] (lth l.span.a l.span.b)))
        |=  r=ref:cal
        %-  pairs:enjs:format
        :~  ['id' s+eid.r]
            ['idx' (numb:enjs:format idx.r)]
            ['l_ms' (numb:enjs:format (da-to-ms:cal l.span.r))]
            ['r_ms' (numb:enjs:format (da-to-ms:cal r.span.r))]
        ==
    ==
  --
--
