::  multipart: multipart/form-data request decoding
::
::  NOTE: Rewritten from upstream parser-combinator version.
::  The original used (rush body ...) which converts the entire payload
::  to a tape and matches content byte-by-byte with +star/+less, causing
::  out-of-memory on large uploads (40MB+). This version finds boundary
::  positions via atom slicing (cut 3) so body content never becomes a
::  tape. Only small header sections are parsed as tapes.
::
|%
+$  part
  $:  file=(unit @t)                   ::  filename
      type=(unit mite)                 ::  content-type
      code=(unit @t)                   ::  content-transfer-encoding
      body=octs                        ::  content, LENGTH PRESERVED — a
  ==                                   ::  bare atom silently drops
                                       ::  trailing zero bytes (real webp
                                       ::  uploads died of this)
::
++  de-request
  |=  [=header-list:http body=(unit octs)]
  ^-  (unit (list [@t part]))
  ?~  body  ~
  ?~  cot=(get-header:http 'content-type' header-list)      ~
  ?.  =('multipart/form-data; boundary=' (end 3^30 u.cot))  ~
  =/  del=@t  (rsh 3^30 u.cot)
  (de-parts q.u.body p.u.body del)
::
::  Find boundaries via atom byte scanning, extract content with cut.
::
++  de-parts
  |=  [raw=@ len=@ud del=@t]
  ^-  (unit (list [@t part]))
  =/  bnd=@  (cat 3 '--' del)
  =/  bnd-len=@ud  (met 3 bnd)
  =/  crlf-bnd=@  (cat 3 '\0d\0a' bnd)
  =/  crlf-bnd-len=@ud  (add 2 bnd-len)
  ::  Find first boundary
  =/  first=(unit @ud)  (find-in bnd bnd-len raw len 0)
  ?~  first  ~
  ::  Start after first boundary + \r\n
  =/  cur=@ud  (add u.first (add bnd-len 2))
  =|  acc=(list [@t part])
  |-
  ?:  (gte cur len)  `(flop acc)
  ::  Find next boundary (\r\n--boundary)
  =/  nxt=(unit @ud)  (find-in crlf-bnd crlf-bnd-len raw len cur)
  ?~  nxt  `(flop acc)
  ::  Find header/body separator (\r\n\r\n) within this part
  =/  sep=(unit @ud)
    (find-in (cat 3 '\0d\0a' '\0d\0a') 4 raw u.nxt cur)
  ?~  sep  `(flop acc)
  ::  Extract header (small, tape is fine) and body (atom slice)
  =/  hdr=@t  (cut 3 [cur (sub u.sep cur)] raw)
  =/  body-off=@ud  (add u.sep 4)
  =/  body-len=@ud  (sub u.nxt body-off)
  =/  bod=octs  [body-len (cut 3 [body-off body-len] raw)]
  ::  Parse part headers
  =/  parsed=(unit [@t part])  (de-part-header hdr bod)
  ::  Advance past \r\n--boundary
  =/  after=@ud  (add u.nxt crlf-bnd-len)
  ::  Check for end marker (--)
  ?:  &((lte (add after 2) len) =((cut 3 [after 2] raw) '--'))
    ?~  parsed  `(flop acc)
    `(flop [u.parsed acc])
  ::  More parts: skip \r\n after boundary
  =?  acc  ?=(^ parsed)  [u.parsed acc]
  $(cur (add after 2))
::
::  Find byte pattern in atom, starting at offset.
::  Uses first-byte filter to skip most positions.
::
++  find-in
  |=  [pat=@ pat-len=@ud hay=@ hay-len=@ud off=@ud]
  ^-  (unit @ud)
  =/  fb=@  (end 3^1 pat)
  |-
  ?:  (gth (add off pat-len) hay-len)  ~
  ?.  =((cut 3 [off 1] hay) fb)
    $(off +(off))
  ?:  =((cut 3 [off pat-len] hay) pat)  `off
  $(off +(off))
::
::  Parse a part's header lines to extract name, filename, type, encoding.
::
++  de-part-header
  |=  [hdr=@t bod=octs]
  ^-  (unit [@t part])
  =/  hed=tape  (trip hdr)
  =/  lines=wall  (split-crlf hed)
  ?~  lines  ~
  ::  First line: Content-Disposition — extract name="..."
  =/  disp=tape  i.lines
  =/  np=(unit @ud)  (find "name=\"" disp)
  ?~  np  ~
  =/  nr=tape  (slag (add u.np 6) disp)
  =/  ne=(unit @ud)  (find "\"" nr)
  ?~  ne  ~
  =/  name=@t  (crip (scag u.ne nr))
  ::  Extract filename="..." (optional)
  =/  file=(unit @t)
    =/  fp=(unit @ud)  (find "filename=\"" disp)
    ?~  fp  ~
    =/  fr=tape  (slag (add u.fp 10) disp)
    =/  fe=(unit @ud)  (find "\"" fr)
    ?~  fe  ~
    `(crip (scag u.fe fr))
  ::  Remaining lines: content-type, encoding
  =|  typ=(unit mite)
  =|  cod=(unit @t)
  =/  rest=wall  t.lines
  |-
  ?~  rest  `[name file typ cod bod]
  =/  line=tape  i.rest
  =?  typ  &(?=(~ typ) ?=(^ (find "Content-Type: " line)))
    (rush (crip (slag 14 line)) (more fas (cook (cury rap 3) (plus qit))))
  =?  cod  &(?=(~ cod) ?=(^ (find "Content-Transfer-Encoding: " line)))
    `(crip (slag 27 line))
  $(rest t.rest)
::
++  split-crlf
  |=  t=tape
  ^-  wall
  =|  acc=wall
  =|  cur=tape
  |-
  ?~  t
    ?~  cur  (flop acc)
    (flop [(flop cur) acc])
  ?:  &(=(i.t '\0d') ?=(^ t.t) =(i.t.t '\0a'))
    $(t t.t.t, acc [(flop cur) acc], cur ~)
  $(t t.t, cur [i.t cur])
--
