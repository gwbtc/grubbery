::  dill-blit: mark for dill terminal output (list blit:dill)
::
|_  blits=(list blit:dill)
++  grab
  |%
  ++  noun  (list blit:dill)
  --
++  grow
  |%
  ++  noun  blits
  ++  json
    ^-  ^json
    a+(turn blits blit-to-json)
  ++  txt
    ^-  wain
    (zing (turn blits blit-to-wain))
  ++  mime  [/application/json (as-octs:mimes:html (en:json:html json))]
  --
++  grad  %noun
::
++  blit-to-json
  |=  =blit:dill
  ^-  json
  ?-  -.blit
      %bel  (pairs:enjs:format ['type' s+%bel]~)
      %clr  (pairs:enjs:format ['type' s+%clr]~)
      %nel  (pairs:enjs:format ['type' s+%nel]~)
      %wyp  (pairs:enjs:format ['type' s+%wyp]~)
      %url  (pairs:enjs:format ~[['type' s+%url] ['url' s+p.blit]])
    ::
      %hop
    %-  pairs:enjs:format
    :~  ['type' s+%hop]
        :-  'pos'
        ?@  p.blit
          (numb:enjs:format p.blit)
        %-  pairs:enjs:format
        :~  ['x' (numb:enjs:format x.p.blit)]
            ['y' (numb:enjs:format y.p.blit)]
        ==
    ==
    ::
      %put
    %-  pairs:enjs:format
    :~  ['type' s+%put]
        ['text' s+(crip (tufa p.blit))]
    ==
    ::
      %klr
    %-  pairs:enjs:format
    :~  ['type' s+%klr]
        ['stub' a+(turn p.blit stye-to-json)]
    ==
    ::
      %mor
    %-  pairs:enjs:format
    :~  ['type' s+%mor]
        ['blits' a+(turn p.blit blit-to-json)]
    ==
    ::
      %sag
    %-  pairs:enjs:format
    :~  ['type' s+%sag]
        ['path' s+(spat p.blit)]
    ==
    ::
      %sav
    %-  pairs:enjs:format
    :~  ['type' s+%sav]
        ['path' s+(spat p.blit)]
    ==
  ==
::
++  stye-to-json
  |=  [=stye text=(list @c)]
  ^-  json
  %-  pairs:enjs:format
  :~  ['text' s+(crip (tufa text))]
  ==
::
++  blit-to-wain
  |=  =blit:dill
  ^-  wain
  ?+  -.blit  ~
    %put  [(crip (tufa p.blit))]~
    %nel  ['']~
    %klr  (turn p.blit |=([=stye t=(list @c)] (crip (tufa t))))
  ==
--
