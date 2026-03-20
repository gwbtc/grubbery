::
::::  /hoon/tang/mar
  ::
/?    310
::
=,  format
|_  tan=(list tank)
++  grad  %noun
++  grow
  |%
  ++  noun  tan
  ++  json
    =/  result=(each (list ^json) tang)
      (mule |.((turn tan tank:enjs:format)))
    ?-  -.result
      %&  a+p.result
      %|  a+[a+[%s '[[output rendering error]]']~]~
    ==
  ++  txt
    ^-  wain
    %+  turn  (flop tan)
    |=(=tank (crip ~(ram re tank)))
  ++  mime
    ^-  ^mime
    =/  =wain  txt
    [/text/plain (as-octs:mimes:html (of-wain:format wain))]
  --
++  grab                                                ::  convert from
  |%
  ++  noun  (list ^tank)                                ::  clam from %noun
  ++  tank  |=(a=^tank [a]~)
  ++  txt   |=(=wain (flop (turn wain tank)))
  --
--
