|%
+$  anum  [a=? y=@ud]               :: a signed year
+$  munt  [[a=? y=@ud] m=@ud]       :: month of year
+$  fuld  [[a=? y=@ud] m=@ud d=@ud] :: date by day of month
+$  week  [[a=? y=@ud] w=@ud]       :: week of year
+$  dawk  [[a=? y=@ud] w=@ud d=@ud] :: date by day of week
+$  nord  [[a=? y=@ud] n=@ud]       :: ordinal date (nth day of year)
::
++  shift-anum
  |=  [[a=? y=@ud] sign=? n=@ud]
  ^-  anum
  ?:  =(a sign)
    [a (add y n)]
  ?:  (lth n y)
    [a (sub y n)]
  [!a +((sub n y))] :: .+ because year 0 does not exist
:: ordinal numbers for weekday in a month
::
+$  ord  ?(%first %second %third %fourth %last)
:: days of the week
::
+$  wkd      ?(%mon %tue %wed %thu %fri %sat %sun)
+$  wkd-num  ?(%0 %1 %2 %3 %4 %5 %6)
:: months of year
::
+$  mnt      ?(%jan %feb %mar %apr %may %jun %jul %aug %sep %oct %nov %dec)
+$  mnt-num  ?(%1 %2 %3 %4 %5 %6 %7 %8 %9 %10 %11 %12)
::
++  wkd-to-num
  |=(=wkd `wkd-num`?-(wkd %mon %0, %tue %1, %wed %2, %thu %3, %fri %4, %sat %5, %sun %6))
::
++  mnt-to-num
  |=  =mnt
  ^-  @ud
  ?-  mnt
    %jan  1
    %feb  2
    %mar  3
    %apr  4
    %may  5
    %jun  6
    %jul  7
    %aug  8
    %sep  9
    %oct  10
    %nov  11
    %dec  12
  ==
::
++  num-to-wkd
  |=  num=@ud
  ^-  wkd
  ?:  =(0 num)  %mon
  ?:  =(1 num)  %tue
  ?:  =(2 num)  %wed
  ?:  =(3 num)  %thu
  ?:  =(4 num)  %fri
  ?:  =(5 num)  %sat
  ?:  =(6 num)  %sun
  !!
:: ~2000.1.1 was a saturday
:: 0, 1, 2, 3, 4, 5, 6
:: m, t, w, t, f, s, s
::
++  get-weekday
  |=  d=@da
  ;;  wkd-num
  %-  (curr mod 7)
  %+  add  5  :: center on saturday
  ?:  (gth d ~2000.1.1)
    (mod (div (sub d ~2000.1.1) ~d1) 7)
  (sub 7 (mod (div (sub ~2000.1.1 d) ~d1) 7))
::
++  get-prev-monday  |=(d=@da (sub d (mul ~d1 (get-weekday d))))
++  get-next-monday
  |=  d=@da
  %+  add  d
  %+  mul  ~d1
  =/  w=@  (get-weekday d)
  ?:(=(0 w) 7 w)
:: days from weekday a to the last weekday b
:: i.e. days between wednesday and last monday: 2
::      days between wednesday and last thursday: 6
::
++  sub-wkd
  |=  [a=@ud b=@ud]
  ^-  @ud
  ?>  &((lth a 7) (lth b 7))
  ?:  (gte a b)
    (sub a b)
  (add a (sub 7 b))
:: first day of week is monday
:: first week is the week containing first thursday of the year
:: (according to ISO-8601)
::
++  first-day-first-week
  |=  [a=? y=@ud]
  ^-  @da
  =/  f=@da  (year [a y] 1 1 0 0 0 ~)
  =/  w=@    (get-weekday f)
  ?:  (lte w 3)
    (sub f (mul w ~d1))
  (add f (mul (sub 7 w) ~d1))
::
++  week-to-first-da
  |=  [[a=? y=@ud] w=@ud]
  ^-  @da
  (add (mul ~d7 (dec w)) (first-day-first-week a y))
:: nth ($ord) weekday in month
::
++  get-ordinal-weekday
  |=  d=@da
  ^-  ord
  ?+  (div (dec d.t:(yore d)) 7)
    %last
    %0  %first
    %1  %second
    %2  %third
    %3  %fourth
  ==
::
++  days-in-month
  |=  [[a=? y=@ud] m=@ud]
  :: m is in range 1-12 (not zero-indexed)
  ::
  ?>  &((gte m 1) (lte m 12))
  `@ud`(snag (dec m) ?:((yelp y) moy:yo moh:yo))
::
++  days-left-in-year
  |=  =time
  ^-  @ud
  (div (sub (year [a +(y)]:(yore time) 1 1 0 0 0 ~) time) ~d1)
::
++  is-leap-year  yelp
:: check date existence/correctness
::
++  valid-date  |=(=date `?`=(date (yore (year date))))
++  valid-fuld  |=(fuld `?`(valid-date [[a y] m d 0 0 0 ~]))
::
++  da-to-anum
  |=  d=@da
  ^-  anum
  [a y]:(yore d)
::
++  da-to-munt
  |=  d=@da
  ^-  munt
  [[a y] m]:(yore d)
::
++  da-to-fuld
  |=  d=@da
  ^-  fuld
  [[a y] m d.t]:(yore d)
::
++  fuld-to-da
  |=  [[a=? y=@ud] m=@ud d=@ud]
  ^-  @da
  (year [a y] m d 0 0 0 ~)
::
++  da-to-week
  |=  d=@da
  ^-  week
  =/  =date  (yore d)
  =/  dof=@da  (first-day-first-week [a y]:date)
  =/  dol=@da  (first-day-first-week (shift-anum [a y]:date | 1))
  ?:  (lth d dof)
    [(shift-anum [a y]:date | 1) +((div (sub d dol) ~d7))]
  =/  don=@da  (first-day-first-week (shift-anum [a y]:date & 1))
  ?:  (gte d don)
    [(shift-anum [a y]:date & 1) 1]
  [[a y]:date +((div (sub d dof) ~d7))]
:: week value is 0-indexed in contrast to ISO-8601
::
++  da-to-dawk
  |=  d=@da
  ^-  dawk
  =/  [[a=? y=@ud] w=@ud]  (da-to-week d)
  [[a y] w (get-weekday d)]
::
++  da-to-nord
  |=  d=@da
  ^-  nord
  =+  (yore d)
  :-  [a y]
  +((div (sub d (year [a y] 1 1 0 0 0 ~)) ~d1))
--
