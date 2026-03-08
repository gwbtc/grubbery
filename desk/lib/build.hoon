::  build: parse and compile hoon source with informative errors
::
::    Provides Clay-style error reporting: parse errors show the
::    offending source line with a caret pointer, compile errors
::    include file path and line numbers via %dbug annotations.
::
|%
::  +parse-hoon: parse source text into a hoon AST
::
::    Uses vang to set bug=& (debug always on) and wer=pax,
::    so all expressions get %dbug annotations with the file
::    path and line/column — just like Clay does.
::
::    Returns the parsed hoon on success, or a tang with the
::    source line and caret pointer on parse failure.
::
++  parse-hoon
  |=  [pax=path src=@t]
  ^-  (each hoon tang)
  =/  vaz  (vang & pax)
  =/  vex=(like hoon)
    ((full (ifix [gay gay] tall:vaz)) [1 1] (trip src))
  ?^  q.vex  [%& p.u.q.vex]
  =/  lyn=@ud  p.p.vex
  =/  col=@ud  q.p.vex
  =/  =wain  (to-wain:format src)
  :-  %|
  :~  [%leaf (runt [(dec col) '-'] "^")]
      ?:  (gth lyn (lent wain))
        [%leaf "<<end of file>>"]
      [%leaf (trip (snag (dec lyn) wain))]
      [%leaf "syntax error at [{<lyn>} {<col>}] in {(spud pax)}"]
  ==
::  +compile-hoon: compile a hoon AST against a subject vase
::
::    Wraps slap in mule with !. to suppress the caller's
::    debug traces — only the source's own %dbug annotations
::    appear in error output.
::
::    Returns the compiled vase on success, or a tang with
::    file path and line numbers on compile failure.
::
++  compile-hoon
  |=  [sut=vase pax=path gen=hoon]
  ^-  (each vase tang)
  =/  res=(each vase tang)
    !.  (mule |.((slap sut gen)))
  ?:  ?=(%& -.res)
    res
  [%| p.res]
::  +build-hoon: parse and compile source in one step
::
::    Convenience arm that chains +parse-hoon and +compile-hoon.
::
++  build-hoon
  |=  [sut=vase pax=path src=@t]
  ^-  (each vase tang)
  =/  parsed  (parse-hoon pax src)
  ?:  ?=(%| -.parsed)  parsed
  (compile-hoon sut pax p.parsed)
::  +extract-src: extract source text from a cage
::
::    Handles %hoon and %txt marks.
::
++  extract-src
  |=  =cage
  ^-  @t
  ?+  p.cage  !!
    %hoon  !<(@t q.cage)
    %txt   (of-wain:format !<(wain q.cage))
  ==
::  +render-tang: render a tang to text for display
::
::    Renders each tank and joins with newlines.
::
++  render-tang
  |=  =tang
  ^-  @t
  %-  crip
  %-  zing
  %+  turn  (flop tang)
  |=(=tank (weld ~(ram re tank) "\0a"))
--
