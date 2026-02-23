:: This library contains a collection of functions to parse
:: and convert to and from a subset of ISO-8601 datetime formats
:: which are standard for HTML date and time inputs.
::
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
    ::
    ++  monadic-parsing
      |%
      :: parser bind
      ::
      ++  bind  
        |*  =mold
        |*  [sef=rule gat=$-(mold rule)]
        |=  tub=nail
        =/  vex  (sef tub)
        ?~  q.vex  vex
        ((gat p.u.q.vex) q.u.q.vex)
      :: lookahead arbitrary rule
      ::
      ++  peek
        |*  sef=rule
        |=  tub=nail
        =+  vex=(sef tub)
        ?~  q.vex
          [p=p.vex q=[~ u=[p=~ q=tub]]]
        [p=p.vex q=[~ u=[p=[~ p.u.q.vex] q=tub]]]
      :: try to parse and advance only on success 
      ::
      ++  seek
        |*  sef=rule
        |=  tub=nail
        =+  vex=(sef tub)
        ?~  q.vex
          [p=p.vex q=[~ u=[p=~ q=tub]]]
        [p=p.vex q=[~ u=[p=[~ p.u.q.vex] q=q.u.q.vex]]]
      ::
      ++  exact-dem
        |=  n=@ud
        =|  digits=(list @ud)
        |-
        ?.  =(0 n)
          ;<  d=@ud  bind  dit
          $(n (dec n), digits [d digits])
        %-  easy
        %+  roll  (flop digits)
        =|([p=@ q=@] |.((add p (mul 10 q)))) :: code from +bass
      ::
      ++  at-least-dem
        |=  n=@ud
        =|  digits=(list @ud)
        |-
        ?.  =(0 n)
          ;<  d=@ud  bind  dit
          $(n (dec n), digits [d digits])
        ;<  rest=@ud  bind  dem
        %-  easy
        %+  add  rest
        %+  roll  (flop digits)
        =|([p=@ q=@] |.((add p (mul 10 q)))) :: code from +bass
      --
    --
|%
++  offset
  |%
  ++  en
    |=  =delta
    ^-  tape
    ?>  =(0 (mod d.delta ~m1))
    ;:  weld
      ?:(sign.delta "+" "-")
      (zfill 2 (numb (div d.delta ~h1)))
      ":"
      (zfill 2 (numb (div (mod d.delta ~h1) ~m1)))
    ==

  ++  de       |=(=@t `delta`(rash t parse))
  ++  de-soft  |=(=@t `(unit delta)`(rush t parse))
  ++  parse
    =,  monadic-parsing
    ;<  sign=?  bind  (cook |=(=@t =(t '+')) ;~(pose lus hep))
    ;<  h=@ud   bind  (exact-dem 2)
    ;<  *       bind  col
    ;<  m=@ud   bind  (exact-dem 2)
    (easy `delta`[sign (add (mul h ~h1) (mul m ~m1))])
  --
:: YYYY, -YYYY..., +YYYYY...
::
++  year-input
  |%
  ++  en
    |=  [a=? y=@ud]
    ^-  tape
    ?.  a
      ['-' (zfill 4 (numb (dec y)))] :: year 1 BC is year 0 in ISO-8601
    ?:  (lth y 10.000)
      (zfill 4 (numb y))
    ['+' (numb y)]
  ++  de       |=(=@t `[a=? y=@ud]`(rash t parse))
  ++  de-soft  |=(=@t `(unit [a=? y=@ud])`(rush t parse))
  ++  parse
    =,  monadic-parsing
    ;<  sign=(unit char)  bind  (seek ;~(pose hep lus))
    ?~  sign
      ;<  y=@ud  bind  (exact-dem 4)
      (easy [& y])
    ?^  (rush u.sign hep)
      ;<  y=@ud  bind  (at-least-dem 4)
      (easy [| +(y)])
    ;<  y=@ud  bind  (at-least-dem 5)
    (easy [& y])
  --
:: YYYY-MM
::
++  month-input
  |%
  ++  en
    |=  [[a=? y=@ud] m=@ud]
    ^-  tape
    %+  weld
      (en:year-input a y)
    "-{(zfill 2 (numb m))}"
  ++  de       |=(=@t `[[a=? y=@ud] m=@ud]`(rash t parse))
  ++  de-soft  |=(=@t `(unit [[a=? y=@ud] m=@ud])`(rush t parse))
  ++  parse
    =,  monadic-parsing
    ;<  [a=? y=@ud]  bind  parse:year-input
    ;<  *            bind  hep
    ;<  m=@ud        bind  (exact-dem 2)
    (easy [[a y] m])
  --
:: YYYY-MM-DD
::
++  date-input
  |%
  ++  en
    |=  [[a=? y=@ud] m=@ud d=@ud]
    ^-  tape
    %+  weld
      (en:month-input [a y] m)
    "-{(zfill 2 (numb d))}"
  ++  de       |=(=@t `[[a=? y=@ud] m=@ud d=@ud]`(rash t parse))
  ++  de-soft  |=(=@t `(unit [[a=? y=@ud] m=@ud d=@ud])`(rush t parse))
  ++  parse
    =,  monadic-parsing
    ;<  [[a=? y=@ud] m=@ud]  bind  parse:month-input
    ;<  *                    bind  hep
    ;<  d=@ud                bind  (exact-dem 2)
    (easy [[a y] m d])
  --
:: HH:MM[:SS[.SSS]]
::
++  time-input
  =|  sep=?(%',' %'.')
  =/  places=@ud  3
  |%
  ++  en
    |=  d=@dr
    ^-  tape
    =/  =tape  (weld (zfill 2 (numb (div d ~h1))) ":")
    =.  d      (mod d ~h1)
    =.  tape   (weld tape (zfill 2 (numb (div d ~m1))))
    =.  d      (mod d ~m1)
    ?:  =(0 d)
      tape
    =.  tape  :(weld tape ":" (zfill 2 (numb (div d ~s1))))
    =.  d      (mod d ~s1)
    ?:  =(0 d)
      tape
    ;:  weld
      tape
      (trip sep)
      (zfill places (numb (div (mul d (pow 10 places)) ~s1)))
    ==
  ++  de       |=(=@t `@dr`(rash t parse))
  ++  de-soft  |=(=@t `(unit @dr)`(rush t parse))
  ++  parse
    =,  monadic-parsing
    ;<  h=@ud  bind  (exact-dem 2)
    ;<  *      bind  col
    ;<  m=@ud  bind  (exact-dem 2)
    =/  d=@dr  (add (mul h ~h1) (mul m ~m1))
    ;<  col=(unit char)  bind  (seek col)
    ?~  col
      (easy d)
    ;<  s=@ud  bind  (exact-dem 2)
    =.  d      (add d (mul s ~s1))
    ;<  sep=(unit char)  bind  (seek ;~(pose dot com))
    ?~  sep
      (easy d)
    ;<  f=@ud  bind  (exact-dem places)
    (easy (add d (div (mul f ~s1) (pow 10 places))))
  --
:: YYYY-MM-DDTHH:MM[:SS[.SSS]]
::
++  datetime-local
  |%
  ++  en
    |=  d=@da
    ^-  tape
    =/  date=tape   (en:date-input [[a y] m d.t]:(yore d))
    =/  clock=tape  (en:time-input `@dr`(mod d ~d1))
    :(weld date "T" clock)
    ::
    ++  de       |=(=@t `@da`(rash t parse))
    ++  de-soft  |=(=@t `(unit @da)`(rush t parse))
    ++  parse
      =,  monadic-parsing
      ;<  [[a=? y=@ud] m=@ud d=@ud]  bind  parse:date-input
      ;<  *                          bind  (just 'T')
      ;<  clock=@dr                  bind  parse:time-input
      =/  d=@da  (year [a y] m d 0 0 0 ~)
      (easy (add d clock))
    --
:: YYYY-Www
::
++  week-input
  |%
  ++  en
    |=  [[a=? y=@ud] w=@ud]
    ^-  tape
    ;:  weld
      (en:year-input a y)
      "-W"
      (zfill 2 (numb w))
    ==
  ++  de       |=(=@t `[[a=? y=@ud] w=@ud]`(rash t parse))
  ++  de-soft  |=(=@t `(unit [[a=? y=@ud] w=@ud])`(rush t parse))
  ++  parse
    =,  monadic-parsing
    ;<  [a=? y=@ud]  bind  parse:year-input
    ;<  *            bind  ;~(plug hep (just 'W'))
    ;<  w=@ud        bind  (exact-dem 2)
    (easy [[a y] w])
  --
:: YYYY-Www-D
::
++  week-date
  |%
  ++  en
    |=  [[a=? y=@ud] w=@ud d=@ud]
    ^-  tape
    ;:  weld
      (en:week-input [a y] w)
      "-"
      (numb +(d)) :: d is 0-indexed on Urbit
    ==
  ++  de       |=(=@t `[[a=? y=@ud] w=@ud d=@ud]`(rash t parse))
  ++  de-soft  |=(=@t `(unit [[a=? y=@ud] w=@ud d=@ud])`(rush t parse))
  ++  parse
    =,  monadic-parsing
    ;<  [[a=? y=@ud] w=@ud]  bind  parse:week-input
    ;<  *                    bind  hep
    ;<  d=@ud                bind  (exact-dem 1)
    (easy [[a y] w (dec d)]) :: d is 0-indexed on Urbit
  --
:: YYYY-DDD
::
++  ordinal-date
  |%
  ++  en
    |=  [[a=? y=@ud] n=@ud]
    ^-  tape
    ;:  weld
      (en:year-input a y)
      "-"
      (zfill 3 (numb n))
    ==
  ++  de       |=(=@t `[[a=? y=@ud] n=@ud]`(rash t parse))
  ++  de-soft  |=(=@t `(unit [[a=? y=@ud] n=@ud])`(rush t parse))
  ++  parse
    =,  monadic-parsing
    ;<  [a=? y=@ud]  bind  parse:year-input
    ;<  *            bind  hep
    ;<  n=@ud        bind  (exact-dem 3)
    (easy [[a y] n])
  --
--
