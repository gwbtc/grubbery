::  bytestream: read and write sequences of bytes
::
::  Ported from hoon-git. A bytestream is a pair of a cursor and octs data.
::  The cursor points at the next byte to be read or written.
::
|%
::  $bays: bytestream
::
::    .pos: relative cursor into .data
::    .data: octs stream
::
+$  bays  $+  bays
          $:  pos=@ud
              data=octs
          ==
::  $bits: bitstream
::
::    .num: number of bits in the accumulator
::    .bit: accumulator
::    .bays: bytestream
::
+$  bits  $+  bits
          $:  num=@ud
              bit=@ub
              =bays
          ==
::
::
++  rip-octs
  |=  a=octs
  ^-  (list @)
  ?:  =(p.a 0)  ~
  =|  hun=(list @)
  =+  i=p.a
  |-
  ?:  =(i 0)  hun
  $(i (dec i), hun :_(hun (cut 3 [(dec i) 1] q.a)))
::
++  cat-octs
  |=  [a=octs b=octs]
  :-  (add p.a p.b)
  (can 3 ~[a b])
::
++  cut-octs
  |=  [pin=@ud len=@ud data=octs]
  ^-  octs
  [len (cut 3 [pin len] q.data)]
::
++  can-octs
  |=  a=(list octs)
  ^-  octs
  ?:  =(~ a)  [0 0]
  =-  [- (can 3 a)]
  %+  reel  a
  |=  [=octs size=@ud]
  (add size p.octs)
::
++  as-octs  as-octs:mimes:html
++  as-octt  as-octt:mimes:html
::
::
++  from-octs
  |=  =octs
  ^-  bays
  [0 octs]
::
++  to-octs
  |=  sea=bays
  ^-  octs
  data.sea
::
++  at-octs
  |=  [n=@ud =octs]
  ^-  bays
  [n octs]
::
++  from-txt
  |=  txt=@t
  (from-octs [(met 3 txt) txt])
::
::
++  exceed
  |=  sea=bays
  ^-  ?
  (gte pos.sea p.data.sea)
::
++  exceed-at
  |=  [pos=@ud sea=bays]
  ^-  ?
  (gte pos p.data.sea)
::
++  still-by
  |=  [n=@ud sea=bays]
  ^-  ?
  (lte (add pos.sea n) p.data.sea)
::
++  still-byte
  |=  sea=bays
  ^-  ?
  (lte +(pos.sea) p.data.sea)
::
++  is-empty
  |=  sea=bays
  (gte pos.sea p.data.sea)
::
++  size
  |=  sea=bays
  ^-  @ud
  p.data.sea
::
++  out-size
  |=  sea=bays
  ^-  @ud
  pos.sea
::
++  in-size
  |=  sea=bays
  ^-  @ud
  (sub p.data.sea pos.sea)
::
::
++  rewind
  |=  sea=bays
  ^-  bays
  sea(pos 0)
::
++  seek-to
  |=  [pos=@ud sea=bays]
  ^-  bays
  sea(pos pos)
::
++  seek-end
  |=  sea=bays
  ^-  bays
  sea(pos p.data.sea)
::
++  skip-by
  |=  [n=@ud sea=bays]
  ^-  bays
  ?>  (lte (add pos.sea n) p.data.sea)
  sea(pos (add pos.sea n))
::
++  skip-byte
  |=  sea=bays
  (skip-by 1 sea)
::
++  back-by
  |=  [n=@ud sea=bays]
  ^-  bays
  ?<  (lth pos.sea n)
  sea(pos (sub pos.sea n))
::
++  find-byte
  |=  [bat=@D sea=bays]
  ^-  (unit @ud)
  =+  i=pos.sea
  |-
  ?:  (exceed-at i sea)  ~
  ?:  =(bat (cut 3 [i 1] q.data.sea))
    (some i)
  $(i +(i))
::
::
++  read-byte
  |=  sea=bays
  ^-  [@D bays]
  ?>  (still-byte sea)
  :_  sea(pos +(pos.sea))
  (cut 3 [pos.sea 1] q.data.sea)
::
++  peek-byte
  |=  sea=bays
  ^-  @D
  ?>  (still-byte sea)
  (cut 3 [pos.sea 1] q.data.sea)
::
::
++  read-octs
  |=  [n=@ud sea=bays]
  ^-  [octs bays]
  ?>  (still-by n sea)
  :_  (skip-by n sea)
  [n (cut 3 [pos.sea n] q.data.sea)]
::
++  read-octs-until
  |=  [sop=@ud sea=bays]
  ^-  [octs bays]
  ?<  (exceed-at (dec sop) sea)
  =+  len=(sub sop pos.sea)
  :_  sea(pos sop)
  [len (cut 3 [pos.sea len] q.data.sea)]
::
++  read-octs-end
  |=  sea=bays
  ^-  [octs bays]
  =+  len=(in-size sea)
  :_  (seek-end sea)
  [len (cut 3 [pos.sea len] q.data.sea)]
::
++  peek-octs
  |=  [n=@ud sea=bays]
  ^-  octs
  ?>  (still-by n sea)
  [n (cut 3 [pos.sea n] q.data.sea)]
::
++  peek-octs-end
  |=  sea=bays
  ^-  octs
  =+  len=(in-size sea)
  [len (cut 3 [pos.sea len] q.data.sea)]
::
++  peek-octs-until
  |=  [pos=@ud sea=bays]
  ^-  octs
  ?:  =(pos 0)  [0 0]
  ?>  (lte pos p.data.sea)
  =+  len=(sub pos pos.sea)
  [len (cut 3 [pos.sea len] q.data.sea)]
::
::
++  read-lsb
  |=  [n=@ud sea=bays]
  ^-  [@ bays]
  =^  num  sea  (read-octs n sea)
  :_  sea
  q.num
::
++  read-msb
  |=  [n=@ud sea=bays]
  ^-  [@ bays]
  =^  num  sea  (read-octs n sea)
  :_  sea
  (rev 3 num)
::
++  read-txt  read-lsb
::
++  read-line
  |=  sea=bays
  ^-  [@t bays]
  =/  pin  (find-byte 0xa sea)
  ?~  pin
    =^  data  sea  (read-octs-end sea)
    :_  sea
    q.data
  =^  data  sea  (read-octs-until u.pin sea)
  :_  sea(pos +(u.pin))
  q.data
::
::
++  bits-from-bays
  |=  sea=bays
  ^-  bits
  [num=0 bit=0b0 sea]
::
++  bits-is-empty
  |=  pea=bits
  ^-  ?
  =(0 (bits-in-size pea))
::
++  bits-in-size
  |=  pea=bits
  ^-  @ud
  (add num.pea (mul 8 (in-size bays.pea)))
::
++  need-bits
  |=  [n=@ud pea=bits]
  ^-  bits
  ?:  (gte num.pea n)  pea
  =+  nib=(sub n num.pea)
  =/  neb=@ud  (div nib 8)
  =?  neb  !=(0 (mod nib 8))  +(neb)
  |-
  ?:  =(neb 0)  pea
  =^  bat  bays.pea  (read-byte bays.pea)
  %=  $
    num.pea  (add num.pea 8)
    bit.pea  (add bit.pea (lsh [0 num.pea] bat))
    neb  (dec neb)
  ==
::
++  drop-bits
  |=  [n=@ud pea=bits]
  ^-  bits
  ?:  =(n 0)  pea
  %=  pea
    bit  (rsh [0 n] bit.pea)
    num  ?:((gth num.pea n) (sub num.pea n) 0)
  ==
::
++  skip-bits
  |=  [n=@ud pea=bits]
  ^-  bits
  =.  pea  (need-bits n pea)
  (drop-bits n pea)
::
++  peek-bits
  |=  [n=@ud pea=bits]
  ^-  @
  ?>  (gte num.pea n)
  ?:  =(n 0)  0
  (dis bit.pea (sub (lsh [0 n] 1) 1))
::
++  read-bits
  |=  [n=@ud pea=bits]
  ^-  [@ bits]
  ?>  (gte num.pea n)
  :_  (drop-bits n pea)
  (dis bit.pea (sub (lsh [0 n] 1) 1))
::
++  read-need-bits
  |=  [n=@ud pea=bits]
  ^-  [@ bits]
  =?  pea  (lth num.pea n)  (need-bits n pea)
  :_  (drop-bits n pea)
  (dis bit.pea (sub (lsh [0 n] 1) 1))
::
++  byte-bits
  |=  pea=bits
  ^-  bits
  =+  rem=(dis num.pea 0x7)
  ?:  =(rem 0)  pea
  %=  pea
    num  (sub num.pea rem)
    bit  (rsh [0 rem] bit.pea)
  ==
--
