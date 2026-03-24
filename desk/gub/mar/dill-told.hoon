::  dill-told: mark for dill system output (told:dill)
::
|_  =told:dill
++  grab
  |%
  ++  noun  told:dill
  --
++  grow
  |%
  ++  noun  told
  ++  json
    ^-  ^json
    ?-  -.told
        %crud
      =/  lines=wall
        (zing (turn (flop q.told) |=(=tank (wash [0 120] tank))))
      %-  pairs:enjs:format
      :~  ['type' s+%crud]
          ['tag' s+p.told]
          ['lines' a+(turn lines |=(t=tape s+(crip t)))]
      ==
        %talk
      =/  lines=wall
        (zing (turn p.told |=(=tank (wash [0 120] tank))))
      %-  pairs:enjs:format
      :~  ['type' s+%talk]
          ['lines' a+(turn lines |=(t=tape s+(crip t)))]
      ==
        %text
      %-  pairs:enjs:format
      :~  ['type' s+%text]
          ['text' s+(crip p.told)]
      ==
    ==
  ++  txt
    ^-  wain
    ?-  -.told
        %crud
      =/  lines=wall
        (zing (turn (flop q.told) |=(=tank (wash [0 120] tank))))
      [(crip "ERROR [{<p.told>}]:") (turn lines crip)]
        %talk
      =/  lines=wall
        (zing (turn p.told |=(=tank (wash [0 120] tank))))
      (turn lines crip)
        %text
      [(crip p.told)]~
    ==
  ++  mime  [/text/plain (as-octs:mimes:html (of-wain:format txt))]
  --
++  grad  %noun
--
