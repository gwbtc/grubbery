::  lib/nex/clurd: blit rendering for terminal tools
::
::  Provides a VT100-style blit renderer that converts
::  dill blits into readable text at a given terminal width.
::
|%
::  +render-blits: render a list of blits into text
::
::  Simulates a terminal buffer of configurable width.
::  Processes %put, %nel, %hop, %clr, %klr, %mor, %bel, %wyp.
::  Returns rendered text as a cord.
::
++  render-blits
  |=  [blits=(list blit:dill) wid=@ud]
  ^-  @t
  =/  lines=(list tape)  ~[~]
  =/  col=@ud  0
  =|  bells=@ud
  |-
  ?~  blits
    =/  out=wall
      %+  turn  (flop lines)
      |=(line=tape (scag wid line))
    (of-wain:format (turn out crip))
  =/  b=blit:dill  i.blits
  ?+    -.b
      $(blits t.blits)
    ::
      %put
    =/  txt=tape  (turn p.b teff)
    =/  cur=tape  ?~(lines ~ i.lines)
    =/  padded=tape
      ?.  (gth col (lent cur))  cur
      (weld cur (reap (sub col (lent cur)) ' '))
    =/  pre=tape  (scag col padded)
    =/  post=tape  (slag (add col (lent txt)) padded)
    =/  new-line=tape  :(weld pre txt post)
    =.  col  (add col (lent txt))
    $(blits t.blits, lines ?~(lines ~[new-line] [new-line t.lines]))
    ::
      %nel
    $(blits t.blits, lines [~ lines], col 0)
    ::
      %hop
    ?@  p.b
      $(blits t.blits, col p.b)
    $(blits t.blits, col x.p.b)
    ::
      %clr
    $(blits t.blits, lines ~[~], col 0)
    ::
      %bel
    $(blits t.blits, bells +(bells))
    ::
      %klr
    =/  txt=tape
      %-  zing
      %+  turn  p.b
      |=  [* text=(list @c)]
      (turn text teff)
    =/  cur=tape  ?~(lines ~ i.lines)
    =/  padded=tape
      ?.  (gth col (lent cur))  cur
      (weld cur (reap (sub col (lent cur)) ' '))
    =/  pre=tape  (scag col padded)
    =/  post=tape  (slag (add col (lent txt)) padded)
    =/  new-line=tape  :(weld pre txt post)
    =.  col  (add col (lent txt))
    $(blits t.blits, lines ?~(lines ~[new-line] [new-line t.lines]))
    ::
      %mor
    $(blits (weld p.b t.blits))
    ::
      %wyp
    =/  cur=tape  ?~(lines ~ i.lines)
    =/  new-line=tape  (scag col cur)
    $(blits t.blits, lines ?~(lines ~[new-line] [new-line t.lines]))
  ==
::  +teff: convert @c to @tD (drop high bits for ASCII)
::
++  teff
  |=  c=@c
  ^-  @tD
  ?:((lth c 128) `@tD`c ' ')
--
