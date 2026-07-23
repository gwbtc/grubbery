::  weir: access control template (make/poke/peek road sets)
::  TODO: consolidate road-to-text/render-road/render-rules across
::  peers.hoon, explorer.hoon, read-weir.hoon, and this file
::
=<
|_  =weir:nexus
++  grab
  |%
  ++  noun  weir:nexus
  ++  mime
    |=  [=mite len=@ud tex=@t]
    ^-  weir:nexus
    =/  lines=(list tape)
      %+  murn  (to-wain:format tex)
      |=  l=@t
      =/  t=tape  (trip l)
      ?~  t  ~
      `t
    =|  acc=weir:nexus
    |-  ^-  weir:nexus
    ?~  lines  acc
    =/  line=tape  i.lines
    =/  words=(list @t)  (to-wain:format (crip `tape`(turn line |=(c=@tD ?:(=(c ' ') `@tD`10 c)))))
    ?~  words  $(lines t.lines)
    =/  cat=@t  i.words
    =/  roads=(list @t)  t.words
    =.  acc
      |-
      ?~  roads  acc
      =/  road=road:tarball  [%& %| (stab i.roads)]
      =.  acc
        ?+  cat  acc
          %'make'  acc(make (~(put in make.acc) road))
          %'poke'  acc(poke (~(put in poke.acc) road))
          %'peek'  acc(peek (~(put in peek.acc) road))
        ==
      $(roads t.roads)
    $(lines t.lines)
  --
++  grow
  |%
  ++  noun  weir
  ++  mime
    ^-  ^mime
    =/  lines=(list tape)
      %-  zing
      :~  (turn ~(tap in make.weir) |=(r=road:tarball "make {(render-road r)}"))
          (turn ~(tap in poke.weir) |=(r=road:tarball "poke {(render-road r)}"))
          (turn ~(tap in peek.weir) |=(r=road:tarball "peek {(render-road r)}"))
      ==
    =/  txt=@t  (of-wain:format (turn lines crip))
    [/text/plain (as-octs:mimes:html txt)]
  --
--
|%
++  render-road
  |=  r=road:tarball
  ^-  tape
  ?-  -.r
    %&  ?-(-.p.r %& "{(spud path.p.p.r)}/{(trip name.p.p.r)}", %| (spud p.p.r))
    %|  "{(zing (reap p.p.r "../"))}{?-(-.q.p.r %& "{(spud path.p.q.p.r)}/{(trip name.p.q.p.r)}", %| (spud p.q.p.r))}"
  ==
--
