::  build: parse and compile hoon source with informative errors
::
::    Provides Clay-style error reporting: parse errors show the
::    offending source line with a caret pointer, compile errors
::    include file path and line numbers via %dbug annotations.
::
::    Import syntax:  /<  name  path
::
::    Paths:
::      /lib/foo.hoon         absolute
::      ./local/bar.hoon      relative (0 up)
::      local/bar.hoon        relative (0 up, same as ./)
::      ../../lib/baz.hoon    relative (2 up)
::
/+  tarball
|%
+$  import  [name=@tas =road:tarball]
+$  resolved-import  [name=@tas =rail:tarball]
+$  source-map  (map rail:tarball @t)
+$  file-info
  $:  src=@t
      src-hash=@uv
      imports=(list resolved-import)
      body=@t
  ==
+$  build-result  (each vase tang)
+$  build-cache  (map @uv vase)
+$  build-out
  $:  results=(map rail:tarball build-result)
      cache=build-cache
      deps=(map rail:tarball (set rail:tarball))
      keys=(map rail:tarball @uv)
  ==
::  +parse-imports: extract /<  imports from source text
::
::    Returns list of imports and remaining source (as cord).
::    Import lines must appear at the top of the file before any
::    hoon code. Blank lines and :: comments between imports are
::    skipped.
::
++  parse-imports
  |=  src=@t
  ^-  (each [imports=(list import) body=@t] tang)
  =/  lines=wain  (to-wain:format src)
  =/  imports=(list import)  ~
  |-
  ?~  lines
    [%& [(flop imports) '']]
  =/  line=tape  (trip i.lines)
  ::  Skip blank lines and comments between imports
  ?:  |(=(~ line) =("" (strip line)) (is-comment line))
    $(lines t.lines)
  ::  Try to parse an import line
  =/  parsed=(unit import)  (rust line import-rule)
  ?~  parsed
    ::  Not an import — rest is body
    [%& [(flop imports) (of-wain:format lines)]]
  $(imports [u.parsed imports], lines t.lines)
::
++  strip
  |=  t=tape
  ^-  tape
  (skip t |=(c=@t =(c ' ')))
::
++  is-comment
  |=  t=tape
  ^-  ?
  ?~  t  |
  ?~  t.t  |
  &(=(i.t ':') =(i.t.t ':'))
::  +import-rule: parse a single /<  name  path line
::
::    /lib/foo.hoon       → [%& %& /lib %foo.hoon]
::    ./foo/bar.hoon      → [%| 0 %& /foo %bar.hoon]
::    foo/bar.hoon        → [%| 0 %& /foo %bar.hoon]
::    ../../foo/bar.hoon  → [%| 2 %& /foo %bar.hoon]
::
++  seg  (cook crip (plus ;~(pose aln hep dot)))
::
++  import-rule
  ;~  pfix
    ;~(plug fas gal gap)
    ;~(plug sym ;~(pfix gap ;~(pose abs-path rel-path)))
  ==
::
++  abs-path
  %+  cook
    |=  pax=path
    ^-  road:tarball
    [%& %& (snip `path`pax) (rear pax)]
  ;~(pfix fas (most fas seg))
::
++  rel-path
  %+  cook
    |=  [ups=@ud =lane:tarball]
    ^-  road:tarball
    [%| ups lane]
  ;~  plug
    ;~  pose
      (cook lent (plus ;~(sfix (jest '..') fas)))
      (cold 0 ;~(plug dot fas))
      (easy 0)
    ==
    %+  cook
      |=  pax=path
      ^-  lane:tarball
      [%& (snip `path`pax) (rear pax)]
    (most fas seg)
  ==
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
::  +resolve-import: resolve an import road to an absolute rail
::
++  resolve-import
  |=  [here=rail:tarball =import]
  ^-  (unit resolved-import)
  =/  res=(unit lane:tarball)
    (lane-from-road:tarball [%& here] road.import)
  ?~  res  ~
  ?.  ?=(%& -.u.res)  ~
  `[name.import p.u.res]
::  +find-hoon-sources: extract source text from all %hoon files in a ball
::
++  find-hoon-sources
  |=  =ball:tarball
  ^-  source-map
  %-  ~(gas by *source-map)
  %+  murn  ~(tap ba:tarball ball)
  |=  [=rail:tarball =content:tarball]
  ?.  =(%hoon p.cage.content)  ~
  ?.  (has-hoon-ext name.rail)  ~
  `[rail !<(@t q.cage.content)]
::  +has-hoon-ext: check if filename ends in .hoon
::
++  has-hoon-ext
  |=  name=@ta
  ^-  ?
  =/  t=tape  (trip name)
  =/  len=@ud  (lent t)
  ?.  (gth len 5)  |
  =(".hoon" (slag (sub len 5) t))
::  +strip-hoon: remove .hoon suffix from filename
::
++  strip-hoon
  |=  name=@ta
  ^-  @ta
  =/  t=tape  (trip name)
  =/  len=@ud  (lent t)
  ?.  (gth len 5)  name
  ?.  =(".hoon" (slag (sub len 5) t))  name
  (crip (scag (sub len 5) t))
::  +topo-sort: topological sort of dependency graph (leaves first)
::
::    Repeatedly selects nodes whose deps are all resolved.
::    Returns sorted order and the set of nodes stuck in cycles.
::
++  topo-sort
  |=  deps=(map rail:tarball (set rail:tarball))
  ^-  [order=(list rail:tarball) cycle=(set rail:tarball)]
  =/  remaining=(set rail:tarball)  ~(key by deps)
  =/  done=(set rail:tarball)  ~
  =/  result=(list rail:tarball)  ~
  |-
  ?:  =(~ remaining)  [result ~]
  =/  ready=(list rail:tarball)
    %+  murn  ~(tap in remaining)
    |=  r=rail:tarball
    =/  my-deps=(set rail:tarball)  (~(gut by deps) r ~)
    ?.  (~(all in my-deps) |=(d=rail:tarball (~(has in done) d)))
      ~
    `r
  ?~  ready  [result remaining]
  =/  ready-set=(set rail:tarball)  (~(gas in *(set rail:tarball)) ready)
  %=  $
    result     (weld result ready)
    done       (~(uni in done) ready-set)
    remaining  (~(dif in remaining) ready-set)
  ==
::  +build-all: compile all hoon sources in a ball
::
::    Walks the ball, finds %hoon sources, parses imports, resolves
::    paths, topologically sorts, and compiles bottom-up. Each file's
::    imports are added as named faces in its compilation subject.
::
::    Cache keys are content-based: hash of (source hash + sorted dep
::    cache keys). Same content + same deps = cache hit regardless of path.
::
++  build-all
  |=  [sut=vase =ball:tarball =build-cache]
  ^-  build-out
  =/  sut-hash=@uv  (sham q.sut)
  =/  sources=source-map  (find-hoon-sources ball)
  ::  Phase 1: Parse and resolve all sources
  ::
  =/  prep
    %+  roll  ~(tap by sources)
    |=  $:  [=rail:tarball src=@t]
            [files=(map rail:tarball file-info) errors=(map rail:tarball tang)]
        ==
    =/  res  (parse-imports src)
    ?:  ?=(%| -.res)
      [files (~(put by errors) rail p.res)]
    =/  raw=(list import)  imports.p.res
    =/  resolved=(list resolved-import)
      (murn raw |=(=import (resolve-import rail import)))
    ?.  =((lent raw) (lent resolved))
      [files (~(put by errors) rail ~[leaf+"unresolved import in {(spud (snoc path.rail name.rail))}"])]
    =/  missing=(list resolved-import)
      (skip resolved |=(r=resolved-import (~(has by sources) rail.r)))
    ?.  =(~ missing)
      [files (~(put by errors) rail ~[leaf+"missing import in {(spud (snoc path.rail name.rail))}"])]
    [(~(put by files) rail [src (sham src) resolved body.p.res]) errors]
  =/  files=(map rail:tarball file-info)  files.prep
  =/  errors=(map rail:tarball tang)  errors.prep
  ::  Phase 2: Topological sort
  ::
  =/  deps=(map rail:tarball (set rail:tarball))
    %-  ~(run by files)
    |=  fi=file-info
    (~(gas in *(set rail:tarball)) (turn imports.fi |=(r=resolved-import rail.r)))
  =/  sort-res  (topo-sort deps)
  ::  Phase 3: Compile in topological order
  ::
  =/  results=(map rail:tarball build-result)
    (~(run by errors) |=(t=tang [%| t]))
  ::  Add cycle errors
  =.  results
    %+  roll  ~(tap in cycle.sort-res)
    |=  [r=rail:tarball acc=_results]
    =/  my-deps=(set rail:tarball)  (~(gut by deps) r ~)
    =/  cycle-deps=(set rail:tarball)  (~(int in my-deps) cycle.sort-res)
    =/  dep-paths=tape
      %-  zing
      ^-  (list tape)
      %+  join  ", "
      %+  turn  ~(tap in cycle-deps)
      |=(d=rail:tarball (spud (snoc path.d name.d)))
    (~(put by acc) r [%| ~[leaf+"circular dependency in {(spud (snoc path.r name.r))} on {dep-paths}"]])
  =|  key-map=(map rail:tarball @uv)
  |-
  ?~  order.sort-res  [results build-cache deps key-map]
  =/  =rail:tarball  i.order.sort-res
  =/  fi=file-info  (~(got by files) rail)
  ::  Check if any dep failed
  =/  dep-failed=?
    %+  lien  imports.fi
    |=  r=resolved-import
    !?=([~ %& *] (~(get by results) rail.r))
  ?:  dep-failed
    %=  $
      order.sort-res  t.order.sort-res
      results  (~(put by results) rail [%| ~[leaf+"dep failed in {(spud (snoc path.rail name.rail))}"]])
    ==
  ::  Compute cache key: own hash + sorted dep cache keys
  =/  dep-keys=(list @uv)
    (turn imports.fi |=(r=resolved-import (~(got by key-map) rail.r)))
  =/  ckey=@uv  (sham [sut-hash src-hash.fi (snoc path.rail name.rail) (sort dep-keys lth)])
  ::  Cache hit → reuse
  ?:  (~(has by build-cache) ckey)
    %=  $
      order.sort-res  t.order.sort-res
      results  (~(put by results) rail [%& (~(got by build-cache) ckey)])
      key-map  (~(put by key-map) rail ckey)
    ==
  ::  Build augmented subject with named dep faces
  =/  aug=vase
    %+  roll  imports.fi
    |=  [r=resolved-import acc=_sut]
    =/  dep-res=build-result  (~(got by results) rail.r)
    ?>  ?=(%& -.dep-res)
    =/  dep=vase  p.dep-res
    (slop [[%face name.r p.dep] q.dep] acc)
  ::  Compile
  =/  res=build-result  (build-hoon aug (snoc path.rail name.rail) body.fi)
  %=  $
    order.sort-res  t.order.sort-res
    results      (~(put by results) rail res)
    key-map      ?:(?=(%& -.res) (~(put by key-map) rail ckey) key-map)
    build-cache  ?:(?=(%& -.res) (~(put by build-cache) ckey p.res) build-cache)
  ==
--
