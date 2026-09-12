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
/+  tarball, nexus, marks
|%
+$  import
  $%  [%file name=@tas =road:tarball]       ::  /<  name  path
      [%bare =road:tarball]                  ::  /<  *  path
      [%mime name=@tas =road:tarball]        ::  /&  name  path
  ==
+$  resolved-import
  $%  [%file name=@tas =rail:tarball]
      [%bare =rail:tarball]
      [%mime name=@tas =lane:tarball]        ::  file rail or dir fold
  ==
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
::  +reverse-closure: seed plus everything transitively depending on it.
::
::    Walks the inverted deps graph from the seed set. Used to find
::    which rails an incremental build must recompute: a changed rail
::    invalidates its dependents, their dependents, and so on.
::
++  reverse-closure
  |=  [deps=(map rail:tarball (set rail:tarball)) seed=(set rail:tarball)]
  ^-  (set rail:tarball)
  =/  rev=(map rail:tarball (set rail:tarball))
    %+  roll  ~(tap by deps)
    |=  [[=rail:tarball ds=(set rail:tarball)] acc=(map rail:tarball (set rail:tarball))]
    %+  roll  ~(tap in ds)
    |=  [d=rail:tarball a=_acc]
    (~(put by a) d (~(put in (~(gut by a) d ~)) rail))
  =/  frontier=(list rail:tarball)  ~(tap in seed)
  =/  seen=(set rail:tarball)  seed
  |-
  ?~  frontier  seen
  =/  fresh=(list rail:tarball)
    %+  skim  ~(tap in (~(gut by rev) i.frontier ~))
    |=(r=rail:tarball !(~(has in seen) r))
  $(frontier (weld t.frontier fresh), seen (~(gas in seen) fresh))
::  +bins-to-cache: reconstruct the build-cache from a lode's keys —
::  a key is both the cache address and the bins address. Rails with no
::  artifact (the subject node, mimes) simply miss.
::
++  bins-to-cache
  |=  [=keys:nexus =bins:nexus]
  ^-  build-cache
  %+  roll  ~(tap by keys)
  |=  [[=rail:tarball key=@uv] acc=build-cache]
  ?:  (~(has by acc) key)  acc
  =/  entry=(unit [refs=@ud =built:nexus])  (~(get by bins) key)
  ?~  entry  acc
  ?.  ?=(%vase -.built.u.entry)  acc
  (~(put by acc) key vase.built.u.entry)
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
  ::  Try each import rune: /<  /&  /$  /%
  =/  parsed=(unit import)
    =/  try  (rust line import-rule)
    ?^  try  try
    (rust line mime-rule)
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
::  +import parsers
::
::    /<  name  path       file import with face
::    /<  *  path          file import without face (bare)
::    /&  name  path       mime import (file or directory)
::    /*  name  %mark  path  import file as mark type
::    /$  name  %a  %b     tube import (mark conversion gate)
::
++  seg  (cook crip (plus ;~(pose aln hep dot)))
::
++  import-rule
  ;~  pose
    bare-rule
    named-import-rule
  ==
::  /<  name  path — named file import
::
++  named-import-rule
  %+  cook  |=(i=[name=@tas =road:tarball] [%file i])
  ;~  pfix
    ;~(plug fas gal gap)
    ;~(plug sym ;~(pfix gap ;~(pose abs-path rel-path)))
  ==
::  /<  *  path — bare file import (no face)
::
++  bare-rule
  %+  cook  |=(r=road:tarball [%bare r])
  ;~  pfix
    ;~(plug fas gal gap tar gap)
    ;~(pose abs-path rel-path)
  ==
::  /&  name  path — mime import (file or directory)
::
::    /&  name  /assets/logo.png   → file: single mime
::    /&  name  /assets/images/    → directory: (axal (map @ta mime))
::    Trailing / distinguishes directory from file.
::
++  mime-rule
  %+  cook  |=(i=[name=@tas =road:tarball] [%mime i])
  ;~  pfix
    ;~(plug fas pam gap)
    ;~(plug sym ;~(pfix gap ;~(pose abs-dir rel-dir abs-path rel-path)))
  ==
::
++  abs-dir
  %+  cook
    |=  pax=path
    ^-  road:tarball
    [%& %| pax]
  ;~(pfix fas ;~(sfix (most fas seg) fas))
::
++  rel-dir
  %+  cook
    |=  [ups=@ud =path]
    ^-  road:tarball
    [%| ups %| path]
  ;~  plug
    ;~  pose
      (cook lent (plus ;~(sfix (jest '..') fas)))
      (cold 0 ;~(plug dot fas))
      (easy 0)
    ==
    ;~(sfix (most fas seg) fas)
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
  |=  [pax=path src=@t line-offset=@ud]
  ^-  (each hoon tang)
  =/  vaz  (vang & pax)
  =/  vex=(like hoon)
    ((full (ifix [gay gay] tall:vaz)) [(add 1 line-offset) 1] (trip src))
  ?^  q.vex  [%& p.u.q.vex]
  =/  lyn=@ud  p.p.vex
  =/  col=@ud  q.p.vex
  =/  =wain  (to-wain:format src)
  =/  body-lyn=@ud  (sub lyn line-offset)
  :-  %|
  :~  [%leaf (runt [(dec col) '-'] "^")]
      ?:  (gth body-lyn (lent wain))
        [%leaf "<<end of file>>"]
      [%leaf (trip (snag (dec body-lyn) wain))]
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
  |=  [sut=vase pax=path src=@t line-offset=@ud]
  ^-  (each vase tang)
  =/  parsed  (parse-hoon pax src line-offset)
  ?:  ?=(%| -.parsed)  parsed
  (compile-hoon sut pax p.parsed)
::  +extract-src: extract source text from a sage
::
::    Handles %hoon and %txt marks.
::
++  extract-src
  |=  =sage:tarball
  ^-  @t
  ?+  name.p.sage  !!
    %hoon  !<(@t q.sage)
    %txt   (of-wain:format !<(wain q.sage))
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
  ?-  -.import
    %file
      =/  res=(unit lane:tarball)
        (lane-from-road:tarball [%& here] road.import)
      ?~  res  ~
      ?.  ?=(%& -.u.res)  ~
      `[%file name.import p.u.res]
    %bare
      =/  res=(unit lane:tarball)
        (lane-from-road:tarball [%& here] road.import)
      ?~  res  ~
      ?.  ?=(%& -.u.res)  ~
      `[%bare p.u.res]
    %mime
      =/  res=(unit lane:tarball)
        (lane-from-road:tarball [%& here] road.import)
      ?~  res  ~
      `[%mime name.import u.res]
  ==
::  +find-hoon-sources: extract source text from all %hoon files in a ball
::
++  find-hoon-sources
  |=  =ball:tarball
  ^-  source-map
  %-  ~(gas by *source-map)
  %+  murn  ~(tap ba:tarball ball)
  |=  [=rail:tarball =sang:tarball]
  ?.  =([/ %hoon] p.sang)  ~
  ?.  (has-hoon-ext name.rail)  ~
  `[rail ;;(@t (sang-noun:tarball sang))]
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
::    Cache keys are content-based: hash of (source + path + sorted dep
::    cache keys), where the subject is one of the deps. Same inputs =
::    same key = cache hit.
::
::    Every file gets a key regardless of compilation outcome — parse
::    errors, cycle errors, dep failures, and compile failures all
::    produce deterministic keys from their inputs. This ensures the
::    reload-changed-nexuses invariant holds: same key <-> same artifact.
::
++  build-all
  |=  [sut=vase =ball:tarball =build-cache]
  ^-  build-out
  (build-inc sut ball build-cache ~ ~)
::  +grub-mime: a [/ %mime] grub as its mime; anything else is not a
::  mime. The only way a grub enters a build as data — by file import or
::  under a /& directory. Source that other namespaces will compile
::  (tool bundles) is mirrored into the namespace as %mime for exactly
::  this reason; the build never reads a noun through a marc.
::
++  grub-mime
  |=  =sang:tarball
  ^-  (unit mime)
  ?.  =([/ %mime] p.sang)  ~
  ?:  (is-boom:tarball sang)  ~
  (mole |.(!<(mime (need-vase:tarball sang))))
::  +build-inc: build-all, reusing prior results for unchanged rails.
::
::    reuse maps each reusable rail to its prior cache key and result
::    ("reuse", not "skip" — the stdlib skip gate is used below);
::    reuse-deps carries those rails' prior graph edges so the stored
::    deps stay complete. Reused rails are never read, parsed, or
::    hashed. The caller owns the correctness argument: a rail may be
::    reused only if it and its transitive deps are unchanged
::    (reverse closure of the changed set over the prior deps graph).
::    Mimes must never be in reuse.
::
::    Phases, each an arm below: sources -> parse -> mimes -> graph ->
::    seed -> compile. The compile loop closes over the phase products.
::
++  build-inc
  |=  $:  sut=vase
          =ball:tarball
          =build-cache
          reuse=(map rail:tarball [key=@uv res=build-result])
          reuse-deps=(map rail:tarball (set rail:tarball))
      ==
  ^-  build-out
  ~&  >  "build-all: {<~(wyt by build-cache)>} cached, {<~(wyt by reuse)>} reused"
  =/  sources=source-map  (sources-to-build ball ~(key by reuse))
  =/  plain=(map rail:tarball vase)  (mime-grubs ball)
  =/  known=(set rail:tarball)
    %-  ~(uni in ~(key by sources))
    (~(uni in ~(key by plain)) ~(key by reuse))
  =/  [files=(map rail:tarball file-info) errors=(map rail:tarball tang)]
    (parse-sources sources known)
  =/  mimes=(map rail:tarball vase)
    (~(uni by plain) (fold-mimes ball files))
  =/  deps=(map rail:tarball (set rail:tarball))
    (dep-graph files mimes reuse-deps)
  =/  sorted  (topo-sort deps)
  =/  [results=(map rail:tarball build-result) keys=(map rail:tarball @uv)]
    (seed-results sut mimes errors deps cycle.sorted reuse)
  |^  (compile-loop order.sorted results keys build-cache)
  ::  +compile-loop: walk the topological order; reused and given
  ::  inputs are already in results, everything else is keyed and then
  ::  cache-hit or compiled
  ::
  ++  compile-loop
    |=  $:  order=(list rail:tarball)
            results=(map rail:tarball build-result)
            keys=(map rail:tarball @uv)
            cache=(map @uv vase)
        ==
    ^-  build-out
    =/  given=(set rail:tarball)  (~(put in ~(key by mimes)) sut-rail:nexus)
    |-
    ?~  order
      ::  the subject is an input: it has a key (so it can be checked
      ::  like any dep) but no result to index or store
      [(~(del by results) sut-rail:nexus) cache deps keys]
    =/  =rail:tarball  i.order
    ?:  |((~(has by reuse) rail) (~(has in given) rail))
      $(order t.order)
    =/  fi=file-info  (~(got by files) rail)
    =/  my-deps=(list rail:tarball)  ~(tap in (~(gut by deps) rail ~))
    =/  key=@uv
      =/  dep-keys=(list @uv)  (turn my-deps |=(d=rail:tarball (~(got by keys) d)))
      (sham [src-hash.fi (snoc path.rail name.rail) (sort dep-keys lth)])
    =/  bad=(list rail:tarball)
      (skim my-deps |=(d=rail:tarball !?=([~ %& *] (~(get by results) d))))
    ?^  bad
      =/  err=tang
        :-  leaf+"dep failed in {(spud (snoc path.rail name.rail))}:"
        (turn bad |=(d=rail:tarball leaf+"{(spud (snoc path.d name.d))}"))
      $(order t.order, results (~(put by results) rail [%| err]), keys (~(put by keys) rail key))
    ?^  hit=(~(get by cache) key)
      ~&  >  "build: cache hit {(spud (snoc path.rail name.rail))}"
      $(order t.order, results (~(put by results) rail [%& u.hit]), keys (~(put by keys) rail key))
    ~&  >>  "build: cache MISS {(spud (snoc path.rail name.rail))}"
    =/  res=build-result  (compile-one rail fi results)
    %=  $
      order    t.order
      results  (~(put by results) rail res)
      keys     (~(put by keys) rail key)
      cache    ?:(?=(%& -.res) (~(put by cache) key p.res) cache)
    ==
  ::  +compile-one: augment the subject with the file's imports, compile,
  ::  and for a mark turn the raw door into a marc
  ::
  ++  compile-one
    |=  [=rail:tarball fi=file-info results=(map rail:tarball build-result)]
    ^-  build-result
    =/  aug=vase  (augment imports.fi results)
    =/  import-lines=@ud
      (sub (lent (to-wain:format src.fi)) (lent (to-wain:format body.fi)))
    =/  res=build-result
      ~>  %bout.[1 (crip "compile {(spud (snoc path.rail name.rail))}")]
      =/  r  (mule |.((build-hoon aug (snoc path.rail name.rail) body.fi import-lines)))
      ?:(?=(%& -.r) p.r [%| ~[leaf+"crash compiling {(spud (snoc path.rail name.rail))}"]])
    ?.  &(?=(%& -.res) ?=([%mar *] path.rail))  res
    =/  marc-res=(each marc:tarball tang)  (mule |.((build-marc:marks p.res)))
    ?:(?=(%| -.marc-res) [%| p.marc-res] [%& !>(p.marc-res)])
  ::  +augment: the compilation subject — sut plus one named face per
  ::  import. A file import is its vase; a bare import splops it in; a
  ::  mime file import is its mime; a mime directory import is an
  ::  (axal (map @ta mime)) of everything gathered under the fold — read
  ::  from the same mimes the graph keyed, so compile inputs and key
  ::  inputs are the same set by construction.
  ::
  ++  augment
    |=  [imports=(list resolved-import) results=(map rail:tarball build-result)]
    ^-  vase
    %+  roll  imports
    |=  [r=resolved-import acc=_sut]
    =/  face  |=([n=@ta v=vase] (slop [[%face n p.v] q.v] acc))
    ?-    -.r
        %file  (face name.r (need-built rail.r results))
        %bare  (slop (need-built rail.r results) acc)
        %mime
      ?-    -.lane.r
          %&
        ?~  got=(~(get by results) p.lane.r)
          ~|  %mime-not-found
          ~|  "  /& {(trip name.r)} {(spud (snoc path.p.lane.r name.p.lane.r))}"
          ~|  "  file does not exist (for a directory, add trailing /)"
          !!
        ?>  ?=(%& -.u.got)
        (face name.r p.u.got)
          %|
        (face name.r !>((fold-axal p.lane.r mimes)))
      ==
    ==
  ::
  ++  need-built
    |=  [=rail:tarball results=(map rail:tarball build-result)]
    ^-  vase
    =/  got=build-result  (~(got by results) rail)
    ?>  ?=(%& -.got)
    p.got
  --
::  +sources-to-build: every %hoon source in the ball minus the rails
::  being reused from a prior build
::
++  sources-to-build
  |=  [=ball:tarball reused=(set rail:tarball)]
  ^-  source-map
  %+  roll  ~(tap in reused)
  |=  [=rail:tarball acc=_(find-hoon-sources ball)]
  (~(del by acc) rail)
::  +mime-grubs: every [/ %mime] grub in the ball — self-compiled
::  artifacts, available to import by file
::
++  mime-grubs
  |=  =ball:tarball
  ^-  (map rail:tarball vase)
  %-  ~(gas by *(map rail:tarball vase))
  %+  murn  ~(tap ba:tarball ball)
  |=  [=rail:tarball =sang:tarball]
  ^-  (unit [rail:tarball vase])
  ?~  m=(grub-mime sang)  ~
  `[rail !>(u.m)]
::  +parse-sources: parse every source's imports and resolve them.
::  known is every rail an import may name: sources, mimes, reused
::  rails (removed from sources but still present — without them a
::  rebuilt file importing an unchanged one dies with a phantom
::  "missing import"). A file that fails here gets an error, not a
::  file-info.
::
++  parse-sources
  |=  [sources=source-map known=(set rail:tarball)]
  ^-  [(map rail:tarball file-info) (map rail:tarball tang)]
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
    %+  skip  resolved
    |=  r=resolved-import
    ?-  -.r
      %file  (~(has in known) rail.r)
      %bare  (~(has in known) rail.r)
      %mime  %.y  :: resolved at compile time from the gathered mimes
    ==
  ?.  =(~ missing)
    =/  miss-paths=tape
      %-  zing
      ^-  (list tape)
      %+  join  ", "
      %+  turn  missing
      |=  r=resolved-import
      ?-  -.r
        %file  (spud (snoc path.rail.r name.rail.r))
        %bare  (spud (snoc path.rail.r name.rail.r))
        %mime  "mime"
      ==
    [files (~(put by errors) rail ~[leaf+"missing import in {(spud (snoc path.rail name.rail))}: {miss-paths}"])]
  ::  src-hash is (sham src). The silo already holds exactly this
  ::  number as the grub's noun lobe (nobe = sham noun, and a %hoon
  ::  grub's noun is its source cord), so this is a second hash of
  ::  content the namespace hashed at write. Not reused: the ball the
  ::  build receives carries sangs, not lobes. Worth threading through
  ::  if builds get slow; one sham per file per build until then.
  [(~(put by files) rail [src (sham src) resolved body.p.res]) errors]
::  +fold-mimes: every mime grub under any /& directory import. These
::  are compile inputs (the importer receives them), so they must be
::  keyed and edged like any input — otherwise an edit under the fold
::  never changed the importer's cache key and a stale vase was reused.
::  Non-mime grubs under the fold are not imported.
::
++  fold-mimes
  |=  [=ball:tarball files=(map rail:tarball file-info)]
  ^-  (map rail:tarball vase)
  =/  folds=(list path)
    %-  zing
    %+  turn  ~(val by files)
    |=  fi=file-info
    %+  murn  imports.fi
    |=  r=resolved-import
    ^-  (unit path)
    ?.  ?=(%mime -.r)  ~
    ?.  ?=(%| -.lane.r)  ~
    `p.lane.r
  %-  ~(gas by *(map rail:tarball vase))
  %+  murn  ~(tap ba:tarball ball)
  |=  [=rail:tarball =sang:tarball]
  ^-  (unit [rail:tarball vase])
  ?.  (lien folds |=(f=path =(f (scag (lent f) path.rail))))  ~
  ?~  m=(grub-mime sang)  ~
  `[rail !>(u.m)]
::  +fold-axal: a directory import's value — the gathered mimes under
::  the fold as (axal (map @ta mime)), paths relative to the fold
::
++  fold-axal
  |=  [fold=path mimes=(map rail:tarball vase)]
  ^-  (axal (map @ta mime))
  %+  roll  ~(tap by mimes)
  |=  [[=rail:tarball v=vase] acc=(axal (map @ta mime))]
  ?.  =(fold (scag (lent fold) path.rail))  acc
  =/  rel=path  (slag (lent fold) path.rail)
  =/  nod=(map @ta mime)  (fall (~(get of acc) rel) *(map @ta mime))
  (~(put of acc) rel (~(put by nod) name.rail !<(mime v)))
::  +dep-graph: every file's edges — imports by file or bare, a mime
::  file, or every gathered mime under an imported fold — plus the prior
::  edges of reused rails (deps is stored, so it must stay complete),
::  plus the subject: a dependency of every file, a node with no deps of
::  its own, whose key is the subject hash. A changed subject is then a
::  changed dep like any other.
::
++  dep-graph
  |=  $:  files=(map rail:tarball file-info)
          mimes=(map rail:tarball vase)
          reuse-deps=(map rail:tarball (set rail:tarball))
      ==
  ^-  (map rail:tarball (set rail:tarball))
  =/  deps=(map rail:tarball (set rail:tarball))
    %-  ~(uni by (~(run by mimes) |=(* *(set rail:tarball))))
    %-  ~(run by files)
    |=  fi=file-info
    %-  ~(gas in *(set rail:tarball))
    %-  zing
    %+  turn  imports.fi
    |=  r=resolved-import
    ^-  (list rail:tarball)
    ?-  -.r
      %file  ~[rail.r]
      %bare  ~[rail.r]
      %mime
    ?-  -.lane.r
      %&  ~[p.lane.r]
        %|
      %+  murn  ~(tap by mimes)
      |=  [=rail:tarball *]
      ?.  =(p.lane.r (scag (lent p.lane.r) path.rail))  ~
      `rail
    ==
    ==
  =.  deps  (~(uni by deps) reuse-deps)
  %+  ~(put by (~(run by deps) |=(s=(set rail:tarball) (~(put in s) sut-rail:nexus))))
    sut-rail:nexus
  ~
::  +seed-results: what the compile loop starts from — the inputs that
::  need no compiling (the subject, mimes, parse errors, cycle errors),
::  each with its key (a content hash, or the reused key), plus the
::  reused rails' prior results and keys
::
++  seed-results
  |=  $:  sut=vase
          mimes=(map rail:tarball vase)
          errors=(map rail:tarball tang)
          deps=(map rail:tarball (set rail:tarball))
          cycle=(set rail:tarball)
          reuse=(map rail:tarball [key=@uv res=build-result])
      ==
  ^-  [(map rail:tarball build-result) (map rail:tarball @uv)]
  =/  results=(map rail:tarball build-result)
    %-  ~(uni by `(map rail:tarball build-result)`(~(run by mimes) |=(v=vase `build-result`[%& v])))
    %-  ~(put by `(map rail:tarball build-result)`(~(run by errors) |=(t=tang `build-result`[%| t])))
    [sut-rail:nexus [%& sut]]
  =/  all-known=(set rail:tarball)  ~(key by deps)
  =.  results
    %+  roll  ~(tap in cycle)
    |=  [r=rail:tarball acc=_results]
    =/  my-deps=(set rail:tarball)  (~(gut by deps) r ~)
    =/  missing=(set rail:tarball)  (~(dif in my-deps) all-known)
    =/  names  |=(s=(set rail:tarball) (zing (join ", " (turn ~(tap in s) |=(d=rail:tarball (spud (snoc path.d name.d)))))))
    =/  err=tang
      ?:  ?=(^ ~(tap in missing))
        ~[leaf+"unresolved dependency in {(spud (snoc path.r name.r))}: {(names missing)}"]
      ~[leaf+"circular dependency in {(spud (snoc path.r name.r))} on {(names (~(int in my-deps) cycle))}"]
    (~(put by acc) r [%| err])
  ::  keys: a content hash for every seeded result (the subject's is the
  ::  subject hash by construction), then the reused rails' prior keys
  =/  keys=(map rail:tarball @uv)
    %+  roll  ~(tap by results)
    |=  [[=rail:tarball =build-result] acc=(map rail:tarball @uv)]
    ?:  ?=(%& -.build-result)
      (~(put by acc) rail (sham q.p.build-result))
    (~(put by acc) rail (sham p.build-result))
  :-  (~(uni by results) (~(run by reuse) |=(v=[key=@uv res=build-result] res.v)))
  (~(uni by keys) (~(run by reuse) |=(v=[key=@uv res=build-result] key.v)))
--
