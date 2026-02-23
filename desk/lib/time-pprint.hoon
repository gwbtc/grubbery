=>  |%
    +$  delta  [sign=? d=@dr]
    ++  numb :: adapted from numb:enjs:format
      |=  a=@u
      ^-  tape
      ?:  =(0 a)  "0"
      %-  flop
      |-  ^-  tape
      ?:(=(0 a) ~ [(add '0' (mod a 10)) $(a (div a 10))])
    ::
    ++  zfill
      |=  [w=@ud t=tape]
      ^-  tape
      ?:  (lte w (lent t))
        t
      $(t ['0' t])
    --
|%
++  timespan-description
  |=  [a=? d=@dr]
  ^-  tape
  =;  time=tape
    "{time} {?.(a "ago" "from now")}"
  ?:  (lth d ~s45)
    "a few seconds"
  ?:  (lth d ~m1.s30)
    "a minute"
  ?:  (lth d ~m45)
    "{(numb (div (add d ~s30) ~m1))} minutes"
  ?:  (lth d ~h1.m30)
    "an hour"
  ?:  (lth d ~h21)
    "{(numb (div (add d ~m30) ~h1))} hours"
  ?:  (lth d ~d1.h11)
    "a day"
  ?:  (lth d ~d25)
    "{(numb (div (add d ~h12) ~d1))} days"
  ?:  (lth d ~d45)
    "a month"
  ?:  (lth d ~d320)
    "{(numb (div (add d ~d15) ~d30))} months"
  ?:  (lth d ~d548)
    "a year"
  "{(numb (div (add d ~d182.h15) ~d365.h6))} years"
::
++  dr-format
  |=  [as=@t d=@dr]
  ^-  tape
  ?+    as  !!
      %'24'
    ?>  (lth d ~d1)
    :: unlike time-input (ISO-8601), no leading hour zero
    ::
    =/  =tape  (numb (div d ~h1))
    =.  d      (mod d ~h1)
    ?:  =(0 d)
      tape
    =.  tape   :(weld tape ":" (zfill 2 (numb (div d ~m1))))
    =.  d      (mod d ~m1)
    ?:  =(0 d)
      tape
    =.  tape  :(weld tape ":" (zfill 2 (numb (div d ~s1))))
    =.  d      (mod d ~s1)
    ?:  =(0 d)
      tape
    :(weld tape "." (zfill 3 (numb (div (mul d 1.000) ~s1))))
    ::
      %'12'
    ?:  (lth d ~h1)
      "{(dr-format '24' (add d ~h12))}am"
    ?:  (lth d ~h12)
      "{(dr-format '24' d)}am"
    ?:  (lth d ~h13)
      "{(dr-format '24' d)}pm"
    "{(dr-format '24' (sub d ~h12))}pm"
  ==
::
++  utc-relative-name
  |=  =delta
  ^-  tape
  ?:  =(0 d.delta)
    "UTC"
  =/  hours=@ud    (div (mod d.delta ~d1) ~h1)
  =/  minutes=@ud  (div (mod d.delta ~h1) ~m1)
  =/  start=tape  [?:(sign.delta '+' '-') (zfill 2 (numb hours))]
  ?:  =(0 minutes)
    start
  :(weld start ":" (zfill 2 (numb minutes)))
--
