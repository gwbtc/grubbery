::  ships: a set of ship identities
::  text format: space-separated @p values, e.g. "~zod ~bus ~nec"
::  json: an array of @p strings, both ways
::
|_  ships=(set @p)
++  grab
  |%
  ++  noun  ,(set @p)
  ++  json
    |=  jon=^json
    ^-  (set @p)
    ?.  ?=([%a *] jon)  ~
    %-  ~(gas in *(set @p))
    %+  murn  p.jon
    |=  j=^json
    ^-  (unit @p)
    ?.  ?=([%s *] j)  ~
    (slaw %p p.j)
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
  ++  json
    ^-  ^json
    a+(turn (sort ~(tap in ships) aor) |=(s=@p s+(scot %p s)))
  ++  mime
    ^-  ^mime
    =/  parts=(list tape)  (turn ~(tap in ships) |=(s=@p (trip (scot %p s))))
    =/  txt=@t  (crip (zing (join " " parts)))
    [/text/plain (as-octs:mimes:html txt)]
  --
--
