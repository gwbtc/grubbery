::  zlib: compression library (inflate only)
::
::  Ported from hoon-git. Supports gzip and zlib decompression.
::
/<  bs  /lib/bytestream.hoon
=,  bs
::
|%
+$  input  bits
+$  output  octs
+$  blocks-output  (list output)
+$  values  (map @ud @ud)
+$  codes  (map [size=@ud code=@ub] literal=@ud)
::
::
::
::
::
++  swp-bits
  |=  bits=[size=@ud data=@ub]
  ^-  [size=@ud data=@ub]
  =/  original-data-length  (met 0 data.bits)
  =/  original-leading-zeros  (sub size.bits original-data-length)
  =/  data  (swp 0 data.bits)
  =.  data  (lsh [0 original-leading-zeros] data)
  [size.bits data]
::
++  cut-bytes
  |=  [index=@ud length=@ud bytes=octs]
  ^-  octs
  [length (cut 3 [index length] q.bytes)]
::
++  cat-bytes
  |=  [target=octs literals=octs]
  ^-  octs
  ?:  =(q.literals 0)
    [(add p.target p.literals) q.target]
  =/  target-lz  (sub p.target (met 3 q.target))
  =?  q.literals  (gth target-lz 0)
    (lsh [3 target-lz] q.literals)
  [(add p.target p.literals) (cat 3 q.target q.literals)]
::
::
++  get-fixed-table
  |=  $:  litlen-codes=codes
          literal-start=@ud
          range-size=@ud
          code-start=@ub
          code-size=@ud
      ==
  ^-  codes
  =/  i  0
  |-
  ?:  =(i range-size)  litlen-codes
  =/  code  (swp-bits [code-size `@ub`(add code-start i)])
  =/  literal  (add literal-start i)
  $(litlen-codes (~(put by litlen-codes) code literal), i +(i))
::
++  get-code
  |=  [=input =codes]
  ^-  [code=@ud bits]
  =/  code-size  1
  |-
  ?:  =(code-size 50)
    ~|  "too many length or distance symbols"  !!
  =.  input  (need-bits code-size input)
  =/  bits  (peek-bits code-size input)
  =/  code  (~(get by codes) [code-size bits])
  ?~  code  $(code-size +(code-size))
  :_  (skip-bits code-size input)
  u.code
::
++  get-cl-table-components
  |=  [hclen=@ud input=bits]
  ^-  [[cl-lengths=values cl-lengths-count=values] input=bits]
  =/  code-lengths  `(list @ud)`[16 17 18 0 8 7 9 6 10 5 11 4 12 3 13 2 14 1 15 ~]
  =/  cl-lengths  `values`~
  =/  cl-lengths-count  `values`~
  =/  j  0
  |-
  ?:  =(j hclen)
    :_  input
    [cl-lengths cl-lengths-count]
  =^  bits  input  (read-need-bits 3 input)
  ?:  =(bits 0)  $(j +(j))
  =*  length  bits
  =/  count  (~(get by cl-lengths-count) length)
  =.  cl-lengths-count
    ?~  count
      (~(put by cl-lengths-count) length 1)
    (~(put by cl-lengths-count) length +(u.count))
  %=  $
    cl-lengths  (~(put by cl-lengths) (snag j code-lengths) length)
    j  +(j)
  ==
::
++  get-table-components
  |=  [=input =codes codes-amount=@ud]
  ^-  [[code-lengths=values cl-count=values] bits]
  =/  code-lengths  `values`~
  =/  cl-count  `values`~
  =/  j  0
  |-
  ?:  =(j codes-amount)
    :_  input
    [code-lengths cl-count]
  ?<  (gth j 285)
  =^  code  input  (get-code input codes)
  ?:  =(code.code 0)  $(j +(j))
  ?:  =(code.code 16)
    =^  bits  input  (read-need-bits 2 input)
    =/  repeat  (add bits 3)
    =/  previous  (~(got by code-lengths) (sub j 1))
    =/  count  (~(got by cl-count) previous)
    =/  l  0
    =.  code-lengths
      |-
      ?:  =(l repeat)  code-lengths
      $(code-lengths (~(put by code-lengths) j previous), j +(j), l +(l))
    %=  $
      cl-count  (~(put by cl-count) previous (add count repeat))
      j  (add j repeat)
    ==
  ?:  =(code.code 17)
    =^  bits  input  (read-need-bits 3 input)
    $(j (add j (add bits 3)))
  ?:  =(code.code 18)
    =^  bits  input  (read-need-bits 7 input)
    $(j (add j (add bits 11)))
  =.  cl-count
    =/  count  (~(get by cl-count) code.code)
    ?~  count
      (~(put by cl-count) code.code 1)
    (~(put by cl-count) code.code +(u.count))
  $(code-lengths (~(put by code-lengths) j code.code), j +(j))
::
++  get-longest-cl
  |=  cl-count=values
  ^-  @ud
  =/  j  1
  =/  result  0
  |-
  ?:  =(j 16)  result
  ?~  (~(get by cl-count) j)  $(j +(j))
  $(result j, j +(j))
::
++  get-smallest-codes
  |=  [cl-count=values longest-cl=@ud]
  ^-  values
  =/  result  `values`~
  =/  j  1
  |-
  ?:  (gth j longest-cl)  result
  ?~  (~(get by cl-count) j)  $(j +(j))
  ?~  =(result ~)
    $(result (~(put by result) j 0), j +(j))
  =/  k  1
  =/  previous  |-
    =/  temp  (~(get by result) (sub j k))
    ?~  temp  $(k +(k))
    [u.temp k]
  =.  k  +.previous
  =/  previous-count  (~(got by cl-count) (sub j k))
  =/  next  (lsh [0 k] (add -.previous previous-count))
  $(result (~(put by result) j next), j +(j))
::
++  make-code-table
  |=  [code-lengths=values max-cl=@ud smallest-codes=values codes-amount=@ud]
  ^-  codes
  =/  cl-count
    ^-  values
    =/  result  `values`~
    =/  j  1
    |-
    ?:  =(j max-cl)  result
    $(result (~(put by result) j 1), j +(j))
  =/  result  `codes`~
  =/  j  0
  |-
  ?:  =(j codes-amount)  result
  =/  length  (~(get by code-lengths) j)
  ?~  length  $(j +(j))
  =/  length-count  (~(got by cl-count) u.length)
  =/  code  `@ub`(~(got by smallest-codes) u.length)
  =?  code  !=(length-count 1)
    (sub (add code length-count) 1)
  =/  code  (swp-bits [u.length code])
  %=  $
    result  (~(put by result) code j)
    cl-count  (~(put by cl-count) u.length +(length-count))
    j  +(j)
  ==
::
++  get-length
  |=  [code=@ud input=bits]
  ^-  [code=@ud bits]
  ?:  (lth code 265)
    :_  input
    (sub code 254)
  ?:  (lth code 269)
    =^  extra-bits  input  (read-need-bits 1 input)
    :_  input
    (add (add 11 (mul (sub code 265) 2)) extra-bits)
  ?:  (lth code 273)
    =^  extra-bits  input  (read-need-bits 2 input)
    :_  input
    (add (add 19 (mul (sub code 269) 4)) extra-bits)
  ?:  (lth code 277)
    =^  extra-bits  input  (read-need-bits 3 input)
    :_  input
    (add (add 35 (mul (sub code 273) 8)) extra-bits)
  ?:  (lth code 281)
    =^  extra-bits  input  (read-need-bits 4 input)
    :_  input
    (add (add 67 (mul (sub code 277) 16)) extra-bits)
  ?:  (lth code 285)
    =^  extra-bits  input  (read-need-bits 5 input)
    :_  input
    (add (add 131 (mul (sub code 281) 32)) extra-bits)
  ?:  =(code 285)
    :_  input
    258
  !!
::
++  get-distance
  |=  [code=@ud input=bits]
  ^-  [code=@ud bits]
  ?:  (lth code 4)
    :_  input
    +(code)
  =/  divided  (dvr code 2)
  =/  extra-bits-amount  (sub p.divided 1)
  =/  j  1
  =/  distance  ?:  =(code 4)
    5
  =/  result  5
  |-
  ^-  @ud
  ?:  =(j extra-bits-amount)  result
  $(result (add result (mul (pow 2 j) 2)), j +(j))
  =^  extra-bits  input  (read-need-bits extra-bits-amount input)
  :_  input
  ?:  =(q.divided 0)
    (add distance extra-bits)
  (add (add distance (pow 2 extra-bits-amount)) extra-bits)
::
++  cut-backreference
  |=  [block-output=output =blocks-output length=@ud distance=@ud]
  ^-  octs
  =?  block-output  (gth distance p.block-output)
    =.  blocks-output  [block-output blocks-output]
    (can-octs (flop blocks-output))
  ?:  (gth distance p.block-output)
    ~|  "invalid distance too far back: d = {<distance>}, p = {<p.block-output>}"  !!
  =/  index  (sub p.block-output distance)
  ?:  (gth distance length)
    (cut-bytes index length block-output)
  =/  temp-length  length
  =/  temp-index  index
  |-
  ?:  (lte temp-length distance)
    =/  backreference  (cut-bytes temp-index temp-length block-output)
    =.  block-output  (cat-bytes block-output backreference)
    (cut-bytes index length block-output)
  =/  backreference  (cut-bytes temp-index distance block-output)
  %=  $
    block-output  (cat-bytes block-output backreference)
    temp-length  (sub temp-length distance)
    temp-index  (add temp-index distance)
  ==
::
++  parse-block
  |=  [=input =blocks-output litlen-codes=codes distance-codes=codes]
  ^-  [=output bits]
  =|  block-output=output
  |-
  =^  litlen-code  input  (get-code input litlen-codes)
  ?:  (bits-is-empty input)
    ~|  "invalid code -- missing end-of-block"  !!
  ?:  =(code.litlen-code 256)
    :_  input
    block-output
  ?:  (lth code.litlen-code 256)
    $(block-output (cat-octs block-output [1 code.litlen-code]))
  =^  length  input  (get-length code.litlen-code input)
  =^  distance-code=@ud  input
    ?^  distance-codes
      (get-code input distance-codes)
    =^  bits  input  (read-need-bits 5 input)
    :_  input
    =/  code  (swp-bits [5 bits])
    ;;(@ud data.code)
  =^  distance  input  (get-distance distance-code input)
  =/  backreference
    (cut-backreference block-output blocks-output code.length code.distance)
  $(block-output (cat-octs block-output backreference))
::
::
++  decompress-block-type-0
  |=  input=bits
  ^-  [=output =bits]
  =.  input  (byte-bits input)
  =^  len=@ud  input  (read-need-bits 16 input)
  =.  input  (skip-bits 16 input)
  =^  data  bays.input  (read-octs len bays.input)
  :_  input
  data
::
++  decompress-block-type-1
  |=  [=input =blocks-output]
  ^-  [=output bits]
  =/  litlen-codes  `codes`~
  =.  litlen-codes  (get-fixed-table litlen-codes 0 144 0b11.0000 8)
  =.  litlen-codes  (get-fixed-table litlen-codes 144 112 0b1.1001.0000 9)
  =.  litlen-codes  (get-fixed-table litlen-codes 256 24 0b0 7)
  =.  litlen-codes  (get-fixed-table litlen-codes 280 8 0b1100.0000 8)
  (parse-block input blocks-output litlen-codes ~)
::
++  decompress-block-type-2
  |=  [=input =blocks-output]
  ^-  [=output bits]
  =^  hlit  input  (read-need-bits 5 input)
  =^  bits  input  (read-need-bits 5 input)
  =/  hdist  (add 1 bits)
  =^  bits  input  (read-need-bits 4 input)
  =/  hclen  (add 4 bits)
  =^  cl-components  input  (get-cl-table-components hclen input)
  =/  longest-cl-cl  (get-longest-cl cl-lengths-count.cl-components)
  =/  smallest-codes
    (get-smallest-codes cl-lengths-count.cl-components longest-cl-cl)
  =/  cl-codes
    (make-code-table cl-lengths.cl-components 8 smallest-codes 19)
  =^  litlen-components  input
    (get-table-components input cl-codes (add 257 hlit))
  =/  longest-litlen-cl  (get-longest-cl cl-count.litlen-components)
  =/  litlen-smallest-codes
    (get-smallest-codes cl-count.litlen-components longest-litlen-cl)
  =/  litlen-codes
    %:  make-code-table
      code-lengths.litlen-components
      16
      litlen-smallest-codes
      (add 257 hlit)
    ==
  =^  distance-components  input
    (get-table-components input cl-codes hdist)
  =/  longest-distance-cl  (get-longest-cl cl-count.distance-components)
  =/  distance-smallest-codes
    (get-smallest-codes cl-count.distance-components longest-distance-cl)
  =/  distance-codes
    %:  make-code-table
      code-lengths.distance-components
      16
      distance-smallest-codes
      hdist
    ==
  (parse-block input blocks-output litlen-codes distance-codes)
::
++  decompress-blocks
  |=  sea=bays
  ^-  [output bays]
  =/  input=bits  (bits-from-bays sea)
  =|  =blocks-output
  |-
  =.  input  (need-bits 3 input)
  =^  last-block  input  (read-bits 1 input)
  =/  is-last-block  =(1 last-block)
  =^  block-type  input  (read-bits 2 input)
  =^  decompressed-block=octs  input
    ?:  =(block-type 0)  (decompress-block-type-0 input)
    ?:  =(block-type 1)  (decompress-block-type-1 input blocks-output)
    ?:  =(block-type 2)  (decompress-block-type-2 input blocks-output)
    ~|  "invalid block type {<block-type>}"  !!
  ?:  is-last-block
    =.  blocks-output  [decompressed-block blocks-output]
    =/  result=octs  (can-octs (flop blocks-output))
    :_  bays.input
    ?:  =(p.result 0)  decompressed-block
    result
  $(blocks-output [decompressed-block blocks-output])
::
::
++  decompress-gzip
  |=  sea=bays
  ^-  [octs bays]
  =+  start=pos.sea
  ::  parse gzip header
  =^  id1=@udD  sea  (read-byte sea)
  ?>  =(31 id1)
  =^  id2=@udD  sea  (read-byte sea)
  ?>  =(139 id2)
  =^  cm=@udD  sea  (read-byte sea)
  ?>  =(8 cm)
  =^  flg=@udD  sea  (read-byte sea)
  =^  mtime=@udF  sea  (read-lsb 4 sea)
  =^  xfl=@udD  sea  (read-byte sea)
  =^  os=@udD  sea  (read-byte sea)
  =/  fhcrc  (cut 0 [1 1] flg)
  =/  fextra  (cut 0 [2 1] flg)
  =/  fname  (cut 0 [3 1] flg)
  =/  fcomment  (cut 0 [4 1] flg)
  =^  xlen=(unit @udE)  sea
    ?:  =(fextra 0)  :_(sea ~)
    =^  num  sea  (read-lsb 2 sea)
    :_  sea  (some num)
  =?  sea  ?=(^ xlen)  (skip-by u.xlen sea)
  =^  file-name=(unit @t)  sea
    ?:  =(fname 0)  :_(sea ~)
    =+  pin=(find-byte 0x0 sea)
    ?>  ?=(^ pin)
    =^  octs  sea  (read-octs-until u.pin sea)
    :_  (skip-byte sea)
    (some q.octs)
  =^  comment=(unit @t)  sea
    ?:  =(fcomment 0)  :_(sea ~)
    =+  pin=(find-byte 0x0 sea)
    ?>  ?=(^ pin)
    =^  octs  sea  (read-octs-until u.pin sea)
    :_  (skip-byte sea)
    (some q.octs)
  =^  crc16=(unit @ud)  sea
    ?:  =(fhcrc 0)  :_(sea ~)
    =^  num  sea  (read-lsb 2 sea)
    :_  sea  (some num)
  ::  decompress data
  =^  data=octs  sea  (decompress-blocks sea)
  ::  parse footer
  =/  footer-length  (in-size sea)
  ?:  (lth footer-length 8)
    ~|  "incorrect data check"  !!
  =^  crc32  sea  (read-octs 4 sea)
  =^  isize  sea  (read-lsb 4 sea)
  ?.  =(q.crc32 (crc32:crc:checksum data))
    ~|  "incorrect crc32 data check"  !!
  :_  sea
  data
::
++  decompress-octs-gzip
  |=  data=octs
  ^-  octs
  -:(decompress-gzip (from-octs data))
::
++  decompress-zlib
  |=  sea=bays
  ^-  [octs bays]
  =+  start=pos.sea
  =^  cmf=@ubD  sea  (read-byte sea)
  =/  cm  (cut 0 [0 4] cmf)
  ?>  =(cm 8)
  =^  flg=@ubD  sea  (read-byte sea)
  =/  fdict  (cut 0 [5 1] flg)
  =^  dict=(unit @uxF)  sea
    ?:  =(fdict 1)
      =^  dict  sea  (read-lsb 4 sea)
      :_  sea  (some dict)
    :_(sea ~)
  ?>  =(0 (mod (add (lsh [3 1] cmf) flg) 31))
  =^  data  sea  (decompress-blocks sea)
  =/  footer-length  (in-size sea)
  ?:  (lth footer-length 4)
    ~|  "incorrect data check"  !!
  =^  adler32=@ux  sea  (read-msb 4 sea)
  ?:  =(adler32 (adler32:adler:checksum data))
    :_  sea
    data
  ~|  "incorrect adler32 data check"  !!
::
++  decompress-octs-zlib
  |=  data=octs
  ^-  octs
  -:(decompress-zlib (from-octs data))
--
