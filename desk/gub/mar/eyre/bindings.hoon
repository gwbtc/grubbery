::  eyre-bindings: list of HTTP bindings for eyre
::
|_  bindings=(list binding:eyre)
++  grad  %noun
++  grow
  |%
  ++  noun  bindings
  ++  mime
    =/  jon=^json
      :-  %a
      %+  turn  bindings
      |=  =binding:eyre
      %-  pairs:enjs:format
      :~  :-  %site
          ?~  site.binding
            ~
          [%s u.site.binding]
          :-  %path
          [%s (spat path.binding)]
      ==
    =/  json-text=@t  (en:json:html jon)
    :-  /application/json
    (as-octs:mimes:html json-text)
  ++  json
    :-  %a
    %+  turn  bindings
    |=  =binding:eyre
    %-  pairs:enjs:format
    :~  :-  %site
        ?~  site.binding
          ~
        [%s u.site.binding]
        :-  %path
        [%s (spat path.binding)]
    ==
  --
++  grab
  |%
  ++  noun  (list binding:eyre)
  ++  mime
    |=  [=mite len=@ud dat=@]
    ^-  (list binding:eyre)
    =/  json-text=@t  (cut 3 [0 len] dat)
    =/  jon=json  (need (de:json:html json-text))
    =-  ((ar:dejs:format -) jon)
    |=  jon=json
    ^-  binding:eyre
    %.  jon
    %-  ot:dejs:format
    :~  :-  %site
        |=  j=json
        ?~  j  ~
        `(so:dejs:format j)
        :-  %path
        |=  j=json
        (stab (so:dejs:format j))
    ==
  --
--
