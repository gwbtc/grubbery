::  put-members: replace entire group membership
::
|_  ships=(set @p)
++  grab
  |%
  ++  noun  ,(set @p)
  ++  mime
    |=  [=mite len=@ud tex=@t]
    ^-  (set @p)
    =/  txt=tape  (trip tex)
    =|  acc=(list @p)
    =|  cur=tape
    |-  ^-  (set @p)
    ?~  txt
      ?~  cur  (sy acc)
      (sy [(slav %p (crip cur)) acc])
    ?:  =(i.txt ' ')
      ?~  cur  $(txt t.txt)
      $(txt t.txt, acc [(slav %p (crip cur)) acc], cur ~)
    $(txt t.txt, cur (snoc cur i.txt))
  --
++  grow
  |%
  ++  noun  ships
  ++  mime
    ^-  ^mime
    =/  parts=(list tape)  (turn ~(tap in ships) |=(s=@p (trip (scot %p s))))
    =/  txt=@t  (crip (zing (join " " parts)))
    [/text/plain (as-octs:mimes:html txt)]
  --
++  grad  %noun
--
