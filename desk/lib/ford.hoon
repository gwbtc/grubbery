::  ford: synchronous build library with content-hash caching
::
::  Builds hoon files, marks (daises), and conversion gates (tubes)
::  from a file map, without scries. All computation is pure and
::  mule-safe since no dotket is involved.
::
::  Caching: every file lookup (hit or miss) is recorded. Cache keys
::  are content hashes of all files touched during a build. Both
::  successes and failures (%tang in soak) are cached uniformly.
::
::  Build functions return soak, never crash. Failures propagate:
::  if a dependency is a %tang, everything that depends on it is
::  also a %tang. Only slap is muled (it doesn't touch reads).
::
::  Lifted from /sys/vane/clay.hoon's ++fusion core.
::
::  TODO: persistence layout for app/grubbery integration
::
::    Managed from app/grubbery.hoon, not from a nexus.
::    Source files come from sys/clay/[desk]/src/.
::    Build results persist under sys/clay/[desk]/bin/,
::    organized by Clay care type:
::
::      bin/a/   file builds (%a care) — unwrap as vase
::      bin/b/   mark builds (%b care) — unwrap as dais
::      bin/c/   cast builds (%c care) — unwrap as tube
::
::    Successes stored as .temp (%temp mark), failures as
::    .tang (%tang mark). Examples:
::
::      bin/a/path/to/foo.temp   successful file build
::      bin/a/path/to/foo.tang   failed file build
::      bin/b/txt.temp           dais for %txt (wrapped in !>)
::      bin/c/txt-to-mime.temp   tube %txt -> %mime (wrapped in !>)
::
::    Cache metadata stored as single files:
::      keys.ford-keys           (map mist @uv)
::      deps.ford-deps           (map mist (set path))
::
::    On kelvin change, nuke all of bin/ and force full rebuild.
::
=,  clay
|%
::  +$  pile: parsed prelude of a hoon source file
::  (already defined in lull.hoon as pile:clay)
::
::  +$  taut: file import from /lib or /sur
::  (already defined in lull.hoon as taut:clay)
::
::  +$  mars: mark conversion request [a=mark b=mark]
::  (already defined in lull.hoon as mars:clay)
::
::  +$  mist: build target identity (already in lull.hoon via =, clay)
++  veb  %.y
::
+$  soak                                ::  build result (success or failure)
  $%  [%vase =vase]
      [%dais =dais]
      [%tube =tube]
      [%tang =tang]
  ==
+$  ford-cache  (map @uv soak)          ::  content-hash -> result
+$  ford-keys   (map mist @uv)          ::  target -> content hash
+$  ford-deps   (map mist (set path))   ::  target -> files looked up
::
+$  result
  $:  soaks=(map mist soak)
      cache=ford-cache
      keys=ford-keys
      deps=ford-deps
  ==
::  +bud: build the bud (base subject for compilation)
::
++  bud
  =/  zuse  !>(..zuse)
  :*  zuse=zuse
      nave=(slap zuse !,(*hoon nave:clay))
      cork=(slap zuse !,(*hoon cork))
      same=(slap zuse !,(*hoon same))
      mime=(slap zuse !,(*hoon mime))
      cass=(slap zuse !,(*hoon cass:clay))
  ==
::  +parse-pile: parse ford runes from hoon source
::
++  parse-pile
  |=  [pax=path txt=@t]
  ^-  pile
  =/  [=hair res=(unit [=pile =nail])]
    %-  road  |.
    =>  [pile-rule=pile-rule pax=pax txt=txt trip=trip]
    ~>  %memo./grubbery/lib/ford/pile
    ((pile-rule pax) [1 1] (trip txt))
  ?^  res  pile.u.res
  %-  mean
  =/  lyn  p.hair
  =/  col  q.hair
  ^-  (list tank)
  :~  leaf+"syntax error at [{<lyn>} {<col>}] in {<pax>}"
    ::
      =/  =wain  (to-wain:format txt)
      ?:  (gth lyn (lent wain))
        '<<end of file>>'
      (snag (dec lyn) wain)
    ::
      leaf+(runt [(dec col) '-'] "^")
  ==
::
++  pile-rule
  =>  ..lull
  =,  clay
  |=  pax=path
  %-  full
  %+  ifix
    :_  gay
    ::  parse optional /? and ignore
    ::
    ;~(plug gay (punt ;~(plug fas wut gap dem gap)))
  |^
  ;~  plug
    %+  cook  (bake zing (list (list taut)))
    %+  rune  hep
    (most ;~(plug com gaw) taut-rule)
  ::
    %+  cook  (bake zing (list (list taut)))
    %+  rune  lus
    (most ;~(plug com gaw) taut-rule)
  ::
    %+  rune  tis
    ;~(plug sym ;~(pfix gap stap))
  ::
    %+  rune  sig
    ;~((glue gap) sym wyde:vast stap)
  ::
    %+  rune  cen
    ;~(plug sym ;~(pfix gap ;~(pfix cen sym)))
  ::
    %+  rune  buc
    ;~  (glue gap)
      sym
      ;~(pfix cen sym)
      ;~(pfix cen sym)
    ==
  ::
    %+  rune  tar
    ;~  (glue gap)
      sym
      ;~(pfix cen sym)
      ;~(pfix stap)
    ==
  ::
    %+  stag  %tssg
    (most gap tall:(vang & pax))
  ==
  ::
  ++  pant
    |*  fel=^rule
    ;~(pose fel (easy ~))
  ::
  ++  mast
    |*  [bus=^rule fel=^rule]
    ;~(sfix (more bus fel) bus)
  ::
  ++  rune
    |*  [bus=^rule fel=^rule]
    %-  pant
    %+  mast  gap
    ;~(pfix fas bus gap fel)
  ::
  ++  taut-rule
    %+  cook  |=(taut +<)
    ;~  pose
      (stag ~ ;~(pfix tar sym))
      ;~(plug (stag ~ sym) ;~(pfix tis sym))
      (cook |=(a=term [`a a]) sym)
    ==
  --
::  +segments: split a term on hyphens for path fitting
::
++  segments
  |=  suffix=@tas
  ^-  (list path)
  =/  parser
    (most hep (cook crip ;~(plug ;~(pose low nud) (star ;~(pose low nud)))))
  =/  torn=(list @tas)  (fall (rush suffix parser) ~[suffix])
  %-  flop
  |-  ^-  (list (list @tas))
  ?<  ?=(~ torn)
  ?:  ?=([@ ~] torn)
    ~[torn]
  %-  zing
  %+  turn  $(torn t.torn)
  |=  s=(list @tas)
  ^-  (list (list @tas))
  ?>  ?=(^ s)
  ~[[i.torn s] [(crip "{(trip i.torn)}-{(trip i.s)}") t.s]]
::  +with-face: add a face to a vase
::
++  with-face  |=([face=@tas =vase] vase(p [%face face p.vase]))
::  +with-faces: combine a list of named vases into a subject
::
++  with-faces
  =|  res=(unit vase)
  |=  vaz=(list [face=@tas =vase])
  ^-  vase
  ?~  vaz  (need res)
  =/  faz  (with-face i.vaz)
  =.  res  `?~(res faz (slop faz u.res))
  $(vaz t.vaz)
::  +compute-key: hash all looked-up file contents into a cache key
::
::  Missing files hash to (sham ~), present files to (sham [~ page]).
::  This means a dep on absence invalidates when the file appears.
::
++  compute-key
  |=  [=mist files=(map path page) reads=(set path)]
  ^-  @uv
  =/  sorted=(list path)  (sort ~(tap in reads) aor)
  %-  sham
  :-  mist
  %+  turn  sorted
  |=(p=path (sham (~(get by files) p)))
::  +check-cache: check if a cached result is still valid
::
::  Recomputes the cache key from old deps against current files.
::  If the key matches, returns the cached soak.
::
++  check-cache
  |=  $:  =mist
          files=(map path page)
          cache=ford-cache
          keys=ford-keys
          deps=ford-deps
      ==
  ^-  (unit soak)
  =/  old-deps=(unit (set path))  (~(get by deps) mist)
  ?~  old-deps  ~
  =/  new-key=@uv  (compute-key mist files u.old-deps)
  =/  old-key=(unit @uv)  (~(get by keys) mist)
  ?.  =(`new-key old-key)  ~
  (~(get by cache) new-key)
::  +ford: the build core
::
::  Takes a file map, cache state, produces build arms.
::  All reads come from the file map. File lookups are recorded
::  in `reads` for cache key computation.
::
::  Build functions return soak, never crash. Tangs propagate
::  infectiously through dependencies.
::
++  ford
  !:
  =/  =_bud  bud
  =|  cycle=(set mist)
  =|  reads=(set path)
  |_  $:  files=(map path page)
          cache=ford-cache
          keys=ford-keys
          deps=ford-deps
      ==
  +*  this  .
  ::  +read-file: look up a file, recording the read
  ::
  ++  read-file
    |=  =path
    ^-  [(unit page) _this]
    =.  reads  (~(put in reads) path)
    [(~(get by files) path) this]
  ::  +save: store a build result in the cache
  ::
  ++  save
    |=  [=mist =soak]
    ^-  _this
    =/  ckey=@uv  (compute-key mist files reads)
    =.  cache  (~(put by cache) ckey soak)
    =.  keys   (~(put by keys) mist ckey)
    =.  deps   (~(put by deps) mist reads)
    this
  ::  +cached: check cache for a target, restoring reads on hit
  ::
  ++  cached
    |=  =mist
    ^-  [(unit soak) _this]
    =/  hit  (check-cache mist files cache keys deps)
    ?~  hit  [~ this]
    ::  restore old reads so parent sees our deps
    =/  old-deps=(set path)  (~(got by deps) mist)
    =.  reads  (~(uni in reads) old-deps)
    [hit this]
  ::  +build-file: build a hoon file at path
  ::
  ++  build-file
    |=  =path
    ^-  [soak _this]
    (build-dependency |+path)
  ::  +build-dependency: core file building logic
  ::
  ::  Returns soak, never crashes. Records all file reads.
  ::  Mules only the slap (pure computation, no reads).
  ::
  ++  build-dependency
    |=  dep=(each [dir=path fil=path] path)
    ^-  [soak _this]
    =/  =path
      ?:(?=(%| -.dep) p.dep fil.p.dep)
    ?:  (~(has in cycle) file+path)
      [[%tang ~[leaf+"circular dependency: {(spud path)}"]] this]
    ::  cache check: scope reads to this build for correct key
    =/  old-reads  reads
    =.  reads  ~
    =^  hit=(unit soak)  this  (cached file+path)
    ?^  hit
      =.  reads  (~(uni in old-reads) reads)
      [u.hit this]
    =.  cycle  (~(put in cycle) file+path)
    =^  out=soak  this
      ~?  >  veb  [%ford-build-dep path]
      =^  pg=(unit page)  this  (read-file path)
      ?~  pg
        [[%tang ~[leaf+"file not found: {(spud path)}"]] this]
      ?.  =(%hoon p.u.pg)
        [[%tang ~[leaf+"not a hoon file: {(spud path)}"]] this]
      =/  txt=@t  ;;(@t q.u.pg)
      ~?  >  veb  [%ford-parsing path]
      =/  pil=(each pile tang)
        (mule |.((parse-pile path txt)))
      ?:  ?=(%| -.pil)
        ~?  >  veb  [%ford-parse-fail path]
        [[%tang p.pil] this]
      ~?  >  veb  [%ford-prelude path]
      =^  pre=soak  this  (run-prelude p.pil)
      ?:  ?=(%tang -.pre)
        ~?  >  veb  [%ford-prelude-fail path]
        [[%tang [leaf+"while building {(spud path)}" tang.pre]] this]
      ?>  ?=(%vase -.pre)
      ~?  >  veb  [%ford-slap path]
      =/  res=(each vase tang)
        (mule |.((slap vase.pre hoon.p.pil)))
      ?:  ?=(%& -.res)
        ~?  >  veb  [%ford-built-ok path]
        [[%vase p.res] this]
      ~?  >  veb  [%ford-slap-fail path]
      [[%tang p.res] this]
    =.  this  (save file+path out)
    =.  cycle  (~(del in cycle) file+path)
    =.  reads  (~(uni in old-reads) reads)
    [out this]
  ::  +build-directory: build all .hoon files in top level of a directory
  ::
  ::  Returns tang if any file fails.
  ::
  ++  build-directory
    |=  =path
    ^-  [(each (map @ta vase) tang) _this]
    =/  len  (lent path)
    =/  entries=(list [pax=^path =page])  ~(tap by files)
    =|  fiz=(list @ta)
    ::  phase 1: scan for hoon files, recording reads
    |-
    ?~  entries
      ::  phase 2: build each file
      =|  rez=(map @ta vase)
      |-
      ?~  fiz
        [[%& rez] this]
      =*  nom=@ta    i.fiz
      =/  pax=^path  (weld path nom %hoon ~)
      =^  res=soak  this  (build-dependency &+[path pax])
      ?:  ?=(%tang -.res)  [[%| tang.res] this]
      ?>  ?=(%vase -.res)
      $(fiz t.fiz, rez (~(put by rez) nom vase.res))
    =/  pax  pax.i.entries
    ?.  =(path (scag len pax))
      $(entries t.entries)
    =.  reads  (~(put in reads) pax)
    =/  pat  (slag len pax)
    ?.  ?=([@ %hoon ~] pat)
      $(entries t.entries)
    $(entries t.entries, fiz [i.pat fiz])
  ::  +run-prelude: assemble subject from imports
  ::
  ::  Returns soak. Tang if any import fails.
  ::
  ++  run-prelude
    |=  =pile
    ^-  [soak _this]
    =/  sut=vase  zuse.bud
    =^  s1=soak  this  (run-tauts sut %sur sur.pile)
    ?:  ?=(%tang -.s1)  [s1 this]
    ?>  ?=(%vase -.s1)
    =^  s2=soak  this  (run-tauts vase.s1 %lib lib.pile)
    ?:  ?=(%tang -.s2)  [s2 this]
    ?>  ?=(%vase -.s2)
    =^  s3=soak  this  (run-raw vase.s2 raw.pile)
    ?:  ?=(%tang -.s3)  [s3 this]
    ?>  ?=(%vase -.s3)
    =^  s4=soak  this  (run-raz vase.s3 raz.pile)
    ?:  ?=(%tang -.s4)  [s4 this]
    ?>  ?=(%vase -.s4)
    =^  s5=soak  this  (run-maz vase.s4 maz.pile)
    ?:  ?=(%tang -.s5)  [s5 this]
    ?>  ?=(%vase -.s5)
    =^  s6=soak  this  (run-caz vase.s5 caz.pile)
    ?:  ?=(%tang -.s6)  [s6 this]
    ?>  ?=(%vase -.s6)
    (run-bar vase.s6 bar.pile)
  ::  +run-tauts: process /- and /+ imports
  ::
  ++  run-tauts
    |=  [sut=vase wer=?(%lib %sur) taz=(list taut)]
    ^-  [soak _this]
    ?~  taz  [[%vase sut] this]
    ~?  >  veb  [%ford-import wer pax.i.taz]
    =^  res=soak  this  (build-fit wer pax.i.taz)
    ?:  ?=(%tang -.res)
      [[%tang [leaf+"while importing /{(trip wer)}/{(trip pax.i.taz)}" tang.res]] this]
    ?>  ?=(%vase -.res)
    =/  pin=vase  vase.res
    =?  p.pin  ?=(^ face.i.taz)  [%face u.face.i.taz p.pin]
    $(sut (slop pin sut), taz t.taz)
  ::  +run-raw: process /= imports
  ::
  ++  run-raw
    |=  [sut=vase raw=(list [face=term =path])]
    ^-  [soak _this]
    ?~  raw  [[%vase sut] this]
    =^  res=soak  this  (build-file (snoc path.i.raw %hoon))
    ?:  ?=(%tang -.res)
      [[%tang [leaf+"while importing /= {(trip face.i.raw)} {(spud path.i.raw)}" tang.res]] this]
    ?>  ?=(%vase -.res)
    =/  pin=vase  vase.res
    =.  p.pin  [%face face.i.raw p.pin]
    $(sut (slop pin sut), raw t.raw)
  ::  +run-raz: process /~ directory imports
  ::
  ++  run-raz
    |=  [sut=vase raz=(list [face=term =spec =path])]
    ^-  [soak _this]
    ?~  raz  [[%vase sut] this]
    =^  dir=(each (map @ta vase) tang)  this
      (build-directory path.i.raz)
    ?:  ?=(%| -.dir)
      [[%tang [leaf+"while importing /~ {(trip face.i.raz)} {(spud path.i.raz)}" p.dir]] this]
    =/  res=(map @ta vase)  p.dir
    =/  =type  (~(play ut p.sut) [%kttr spec.i.raz])
    =/  pin=vase
      :-  %-  ~(play ut p.sut)
          [%kttr %make [%wing ~[%map]] ~[[%base %atom %ta] spec.i.raz]]
      |-
      ?~  res  ~
      ?.  (~(nest ut type) | p.q.n.res)
        ~|  [%nest-fail path.i.raz p.n.res]
        !!
      :-  [p.n.res q.q.n.res]
      [$(res l.res) $(res r.res)]
    =.  p.pin  [%face face.i.raz p.pin]
    $(sut (slop pin sut), raz t.raz)
  ::  +run-maz: process /% mark imports
  ::
  ++  run-maz
    |=  [sut=vase maz=(list [face=term =mark])]
    ^-  [soak _this]
    ?~  maz  [[%vase sut] this]
    =^  res=soak  this  (build-nave mark.i.maz)
    ?:  ?=(%tang -.res)
      [[%tang [leaf+"while importing /% {(trip face.i.maz)} %{(trip mark.i.maz)}" tang.res]] this]
    ?>  ?=(%vase -.res)
    =/  pin=vase  vase.res
    =.  p.pin  [%face face.i.maz p.pin]
    $(sut (slop pin sut), maz t.maz)
  ::  +run-caz: process /$ mark conversion imports
  ::
  ++  run-caz
    |=  [sut=vase caz=(list [face=term =mars])]
    ^-  [soak _this]
    ?~  caz  [[%vase sut] this]
    =^  res=soak  this  (build-cast mars.i.caz)
    ?:  ?=(%tang -.res)
      [[%tang [leaf+"while importing /$ {(trip face.i.caz)}" tang.res]] this]
    ?>  ?=(%vase -.res)
    =/  pin=vase  vase.res
    =.  p.pin  [%face face.i.caz p.pin]
    $(sut (slop pin sut), caz t.caz)
  ::  +run-bar: process /* file+cast imports
  ::
  ++  run-bar
    |=  [sut=vase bar=(list [face=term =mark =path])]
    ^-  [soak _this]
    ?~  bar  [[%vase sut] this]
    =^  res=soak  this  (cast-path [path mark]:i.bar)
    ?:  ?=(%tang -.res)
      [[%tang [leaf+"while importing /* {(trip face.i.bar)} {(spud path.i.bar)}" tang.res]] this]
    ?>  ?=(%vase -.res)
    =/  cag=vase  vase.res
    =.  p.cag  [%face face.i.bar p.cag]
    $(sut (slop cag sut), bar t.bar)
  ::  +build-fit: build file at path, maybe converting '-'s to '/'s
  ::
  ++  build-fit
    |=  [pre=@tas pax=@tas]
    ^-  [soak _this]
    =^  fp=soak  this  (fit-path pre pax)
    ?:  ?=(%tang -.fp)  [fp this]
    ?>  ?=(%vase -.fp)
    (build-file ;;(path q.vase.fp))
  ::  +fit-path: find path, maybe converting '-'s to '/'s
  ::
  ::  Records all attempted paths (hits and misses) as deps.
  ::  Returns the path as a vase, or tang if not found.
  ::
  ++  fit-path
    |=  [pre=@tas pax=@tas]
    ^-  [soak _this]
    =/  paz  (segments pax)
    |-
    ?~  paz
      [[%tang ~[leaf+"ford: no files match /{(trip pre)}/{(trip pax)}/hoon"]] this]
    =/  pux=path  pre^(snoc i.paz %hoon)
    =.  reads  (~(put in reads) pux)
    ?:  (~(has by files) pux)
      [[%vase !>(pux)] this]
    $(paz t.paz)
  ::  +build-nave: build a statically typed mark core
  ::
  ++  build-nave
    |=  mak=mark
    ^-  [soak _this]
    ?:  (~(has in cycle) nave+mak)
      [[%tang ~[leaf+"circular dependency: nave {<mak>}"]] this]
    =/  old-reads  reads
    =.  reads  ~
    =^  hit=(unit soak)  this  (cached nave+mak)
    ?^  hit
      =.  reads  (~(uni in old-reads) reads)
      [u.hit this]
    =.  cycle  (~(put in cycle) nave+mak)
    =^  out=soak  this
      ~?  >  veb  [%ford-build-nave mak]
      =^  cor-res=soak  this  (build-fit %mar mak)
      ?:  ?=(%tang -.cor-res)
        [[%tang [leaf+"while building nave for %{(trip mak)}" tang.cor-res]] this]
      ?>  ?=(%vase -.cor-res)
      =/  cor=vase  vase.cor-res
      =/  gad=(each vase tang)  (mule |.((slap cor limb/%grad)))
      ?:  ?=(%| -.gad)
        [[%tang p.gad] this]
      ?@  q.p.gad
        =/  mok-res=(each mark tang)  (mule |.(!<(mark p.gad)))
        ?:  ?=(%| -.mok-res)  [[%tang p.mok-res] this]
        =/  mok=mark  p.mok-res
        =^  deg=soak  this  $(mak mok)
        ?:  ?=(%tang -.deg)
          [[%tang [leaf+"while building nave for %{(trip mak)}: delegate %{(trip mok)} failed" tang.deg]] this]
        ?>  ?=(%vase -.deg)
        =^  tub=soak  this  (build-cast mak mok)
        ?:  ?=(%tang -.tub)
          [[%tang [leaf+"while building nave for %{(trip mak)}: cast to %{(trip mok)} failed" tang.tub]] this]
        ?>  ?=(%vase -.tub)
        =^  but=soak  this  (build-cast mok mak)
        ?:  ?=(%tang -.but)
          [[%tang [leaf+"while building nave for %{(trip mak)}: cast from %{(trip mok)} failed" tang.but]] this]
        ?>  ?=(%vase -.but)
        =/  res=(each vase tang)
          %-  mule  |.
          ^-  vase  ::  vase of nave
          %+  slap
            %-  with-faces
            :~  deg+vase.deg
                tub+vase.tub
                but+vase.but
                cor+cor
                nave+nave.bud
            ==
          !,  *hoon
          =/  typ  _+<.cor
          =/  dif  _*diff:deg
          ^-  (nave typ dif)
          |%
          ++  diff
            |=  [old=typ new=typ]
            ^-  dif
            (diff:deg (tub old) (tub new))
          ++  form  form:deg
          ++  join  join:deg
          ++  mash  mash:deg
          ++  pact
            |=  [v=typ d=dif]
            ^-  typ
            (but (pact:deg (tub v) d))
          ++  vale  noun:grab:cor
          --
        ?:  ?=(%& -.res)  [[%vase p.res] this]
        [[%tang p.res] this]
      =/  res=(each vase tang)
        %-  mule  |.
        ^-  vase  ::  vase of nave
        %+  slap  (slop (with-face cor+cor) zuse.bud)
        !,  *hoon
        =/  typ  _+<.cor
        =/  dif  _*diff:grad:cor
        ^-  (nave:clay typ dif)
        |%
        ++  diff  |=([old=typ new=typ] (diff:~(grad cor old) new))
        ++  form  form:grad:cor
        ++  join
          |=  [a=dif b=dif]
          ^-  (unit (unit dif))
          ?:  =(a b)
            ~
          `(join:grad:cor a b)
        ++  mash
          |=  [a=[=ship =desk =dif] b=[=ship =desk =dif]]
          ^-  (unit dif)
          ?:  =(dif.a dif.b)
            ~
          `(mash:grad:cor a b)
        ++  pact  |=([v=typ d=dif] (pact:~(grad cor v) d))
        ++  vale  noun:grab:cor
        --
      ?:  ?=(%& -.res)
        [[%vase p.res] this]
      [[%tang p.res] this]
    =.  this  (save nave+mak out)
    =.  cycle  (~(del in cycle) nave+mak)
    =.  reads  (~(uni in old-reads) reads)
    [out this]
  ::  +build-dais: build a dynamically typed mark definition
  ::
  ++  build-dais
    |=  mak=mark
    ^-  [soak _this]
    ?:  (~(has in cycle) dais+mak)
      [[%tang ~[leaf+"circular dependency: dais {<mak>}"]] this]
    =/  old-reads  reads
    =.  reads  ~
    =^  hit=(unit soak)  this  (cached dais+mak)
    ?^  hit
      =.  reads  (~(uni in old-reads) reads)
      [u.hit this]
    =.  cycle  (~(put in cycle) dais+mak)
    =^  out=soak  this
      ~?  >  veb  [%ford-build-dais mak]
      =^  nav=soak  this  (build-nave mak)
      ?:  ?=(%tang -.nav)
        [[%tang [leaf+"while building dais for %{(trip mak)}" tang.nav]] this]
      ?>  ?=(%vase -.nav)
      :_  this
      :-  %dais
    ^-  dais
    =>  [nav=vase.nav ..zuse]
    |_  sam=vase
    ++  diff
      |=  new=vase
      (slam (slap nav limb/%diff) (slop sam new))
    ++  form  !<(mark (slap nav limb/%form))
    ++  join
      |=  [a=vase b=vase]
      ^-  (unit (unit vase))
      =/  res=vase  (slam (slap nav limb/%join) (slop a b))
      ?~  q.res    ~
      ?~  +.q.res  [~ ~]
      ``(slap res !,(*hoon ?>(?=([~ ~ *] .) u.u)))
    ++  mash
      |=  [a=[=ship =desk diff=vase] b=[=ship =desk diff=vase]]
      ^-  (unit vase)
      =/  res=vase
        %+  slam  (slap nav limb/%mash)
        %+  slop
          :(slop [[%atom %p ~] ship.a] [[%atom %tas ~] desk.a] diff.a)
        :(slop [[%atom %p ~] ship.b] [[%atom %tas ~] desk.b] diff.b)
      ?~  q.res
        ~
      `(slap res !,(*hoon ?>((^ .) u)))
    ++  pact
      |=  diff=vase
      (slam (slap nav limb/%pact) (slop sam diff))
    ++  vale
      |:  noun=q:(slap nav !,(*hoon *vale))
      (slam (slap nav limb/%vale) noun/noun)
    --
    =.  this  (save dais+mak out)
    =.  cycle  (~(del in cycle) dais+mak)
    =.  reads  (~(uni in old-reads) reads)
    [out this]
  ::  +build-cast: produce gate to convert mark .a to .b, statically typed
  ::
  ++  build-cast
    |=  [a=mark b=mark]
    ^-  [soak _this]
    ~?  >  veb  [%ford-build-cast a b]
    ?:  (~(has in cycle) cast+[a b])
      [[%tang ~[leaf+"circular dependency: cast {<a>} {<b>}"]] this]
    ?:  =(a b)
      [[%vase same.bud] this]
    ?:  =([%mime %hoon] [a b])
      [[%vase =>(..zuse !>(|=(m=mime q.q.m)))] this]
    =/  old-reads  reads
    =.  reads  ~
    =^  hit=(unit soak)  this  (cached cast+[a b])
    ?^  hit
      =.  reads  (~(uni in old-reads) reads)
      [u.hit this]
    =.  cycle  (~(put in cycle) cast+[a b])
    =^  out=soak  this
      ::  try +grow; is there a +grow core with a .b arm?
      ::
      =^  old-res=soak  this  (build-fit %mar a)
      ?:  ?=(%tang -.old-res)
        [[%tang [leaf+"while building cast %{(trip a)} to %{(trip b)}" tang.old-res]] this]
      ?>  ?=(%vase -.old-res)
      =/  old=vase  vase.old-res
      ?:  (has-arm %grow b old)
        =/  res=(each vase tang)
          %-  mule  |.
          ^-  vase
          %+  slap  (with-faces cor+old ~)
          ^-  hoon
          :+  %brcl  !,(*hoon v=+<.cor)
          :+  %sggr
            [%spin %cltr [%sand %t (crip "grow-{<a>}->{<b>}")] ~]
          :+  %tsgl  limb/b
          !,(*hoon ~(grow cor v))
        ?:  ?=(%& -.res)  [[%vase p.res] this]
        [[%tang p.res] this]
      ::  try direct +grab
      ::
      =^  new-res=soak  this  (build-fit %mar b)
      ?:  ?=(%tang -.new-res)
        [[%tang [leaf+"while building cast %{(trip a)} to %{(trip b)}" tang.new-res]] this]
      ?>  ?=(%vase -.new-res)
      =/  new=vase  vase.new-res
      =/  arm=?  (has-arm %grab a new)
      =/  rab
        %-  mule  |.
        %+  slap  new
        ^-  hoon
        :+  %sggr
          [%spin %cltr [%sand %t (crip "grab-{<a>}->{<b>}")] ~]
        tsgl/[limb/a limb/%grab]
      ?:  &(arm ?=(%& -.rab) ?=(^ q.p.rab))
        [[%vase p.rab] this]
      ::  try +jump
      ::
      =/  jum  (mule |.((slap old tsgl/[limb/b limb/%jump])))
      ?:  &((has-arm %jump a old) ?=(%& -.jum))
        =/  via  !<(mark p.jum)
        (compose-casts a via b)
      ?:  &(arm ?=(%& -.rab))
        =/  via  !<(mark p.rab)
        (compose-casts a via b)
      ?:  ?=(%noun b)
        [[%vase same.bud] this]
      [[%tang ~[leaf+"no cast from {<a>} to {<b>}"]] this]
    =.  this  (save cast+[a b] out)
    =.  cycle  (~(del in cycle) cast+[a b])
    =.  reads  (~(uni in old-reads) reads)
    [out this]
  ::  +compose-casts: compose two mark conversions
  ::
  ++  compose-casts
    |=  [x=mark y=mark z=mark]
    ^-  [soak _this]
    =^  uno=soak  this  (build-cast x y)
    ?:  ?=(%tang -.uno)
      [[%tang [leaf+"while composing cast %{(trip x)} to %{(trip z)} via %{(trip y)}" tang.uno]] this]
    ?>  ?=(%vase -.uno)
    =^  dos=soak  this  (build-cast y z)
    ?:  ?=(%tang -.dos)
      [[%tang [leaf+"while composing cast %{(trip x)} to %{(trip z)} via %{(trip y)}" tang.dos]] this]
    ?>  ?=(%vase -.dos)
    =/  res=(each vase tang)
      %-  mule  |.
      %+  slap
        (with-faces uno+vase.uno dos+vase.dos ~)
      !,(*hoon |=(_+<.uno (dos (uno +<))))
    ?:  ?=(%& -.res)  [[%vase p.res] this]
    [[%tang p.res] this]
  ::  +has-arm: check if a core has a specific arm in a specific layer
  ::
  ++  has-arm
    |=  [arm=@tas =mark core=vase]
    ^-  ?
    =/  rib  (mule |.((slap core [%wing ~[arm]])))
    ?:  ?=(%| -.rib)  %.n
    =/  lab  (mule |.((slob mark p.p.rib)))
    ?:  ?=(%| -.lab)  %.n
    p.lab
  ::  +build-tube: produce a $tube mark conversion gate from .a to .b
  ::
  ++  build-tube
    |=  [a=mark b=mark]
    ^-  [soak _this]
    ?:  (~(has in cycle) tube+[a b])
      [[%tang ~[leaf+"circular dependency: tube {<a>} {<b>}"]] this]
    =/  old-reads  reads
    =.  reads  ~
    =^  hit=(unit soak)  this  (cached tube+[a b])
    ?^  hit
      =.  reads  (~(uni in old-reads) reads)
      [u.hit this]
    =.  cycle  (~(put in cycle) tube+[a b])
    =^  out=soak  this
      ~?  >  veb  [%ford-build-tube a b]
      =^  gat=soak  this  (build-cast a b)
      ?:  ?=(%tang -.gat)
        [[%tang [leaf+"while building tube %{(trip a)} to %{(trip b)}" tang.gat]] this]
      ?>  ?=(%vase -.gat)
      :_  this
      :-  %tube
      =>([gat=vase.gat ..zuse] |=(v=vase (slam gat v)))
    =.  this  (save tube+[a b] out)
    =.  cycle  (~(del in cycle) tube+[a b])
    =.  reads  (~(uni in old-reads) reads)
    [out this]
  ::  +validate-page: ensure file page has the correct mark
  ::
  ++  validate-page
    |=  [=path =page]
    ^-  [soak _this]
    =/  mak=mark  (head (flop path))
    ?:  =(mak p.page)
      (page-to-cage page)
    =^  src=soak  this  (page-to-cage page)
    ?:  ?=(%tang -.src)
      [[%tang [leaf+"while validating {(spud path)}" tang.src]] this]
    ?>  ?=(%vase -.src)
    =^  tub=soak  this  (build-tube p.page mak)
    ?:  ?=(%tang -.tub)
      [[%tang [leaf+"while validating {(spud path)}: tube %{(trip p.page)} to %{(trip mak)} failed" tang.tub]] this]
    ?>  ?=(%tube -.tub)
    =/  res=(each vase tang)
      (mule |.((tube.tub vase.src)))
    ?:  ?=(%& -.res)  [[%vase p.res] this]
    [[%tang p.res] this]
  ::  +page-to-cage: convert a page to a cage (returns vase soak)
  ::
  ++  page-to-cage
    |=  =page
    ^-  [soak _this]
    ?:  =(%hoon p.page)
      [[%vase [%atom %t ~] q.page] this]
    ?:  =(%mime p.page)
      [[%vase =>([;;(mime q.page) ..zuse] !>(-))] this]
    =^  dai=soak  this  (build-dais p.page)
    ?:  ?=(%tang -.dai)  [dai this]
    ?>  ?=(%dais -.dai)
    =/  res=(each vase tang)
      (mule |.((vale:dais.dai q.page)))
    ?:  ?=(%& -.res)  [[%vase p.res] this]
    [[%tang p.res] this]
  ::  +cast-path: read file and convert to mark
  ::
  ++  cast-path
    |=  [=path mak=mark]
    ^-  [soak _this]
    =/  mok  (head (flop path))
    =^  pg=(unit page)  this  (read-file path)
    ?~  pg
      [[%tang ~[leaf+"file not found: {(spud path)}"]] this]
    =^  cag=soak  this  (validate-page path u.pg)
    ?:  ?=(%tang -.cag)
      [[%tang [leaf+"while casting {(spud path)} to %{(trip mak)}" tang.cag]] this]
    ?:  =(mok mak)  [cag this]
    ?>  ?=(%vase -.cag)
    =^  tub=soak  this  (build-tube mok mak)
    ?:  ?=(%tang -.tub)
      [[%tang [leaf+"while casting {(spud path)} to %{(trip mak)}" tang.tub]] this]
    ?>  ?=(%tube -.tub)
    =/  res=(each vase tang)
      (mule |.((tube.tub vase.cag)))
    ?:  ?=(%& -.res)  [[%vase p.res] this]
    [[%tang p.res] this]
  ::  +build-all: build everything, collecting results
  ::
  ::  No mule — build functions return soak directly.
  ::  Each target gets its own reads scope for cache keying.
  ::
  ++  build-all
    |=  marks=(list mark)
    ^-  [result _this]
    =|  soaks=(map mist soak)
    ::  build all .hoon files
    ::
    =/  hoon-files=(list path)
      %+  murn  ~(tap by files)
      |=  [pax=path =page]
      ?.  =(%hoon p.page)  ~
      `pax
    ~?  >  veb  [%ford-phase-files count=(lent hoon-files)]
    |-
    ?~  hoon-files
      ::  build all daises
      ::
      ~?  >  veb  [%ford-phase-daises count=(lent marks)]
      =/  mark-list=_marks  marks
      |-
      ?~  mark-list
        ::  build all tubes between marks that built successfully
        ::
        =/  built-marks=(list mark)
          %+  murn  ~(tap by soaks)
          |=  [=mist =soak]
          ?.  ?=([%dais *] mist)  ~
          ?.  ?=(%dais -.soak)  ~
          `mark.mist
        ~?  >  veb  [%ford-phase-tubes count=(lent built-marks)]
        =/  aa=(list mark)  built-marks
        |-
        ?~  aa
          ~?  >  veb  [%ford-done soaks=~(wyt by soaks) cache=~(wyt by cache)]
          [[soaks cache keys deps] this]
        =/  bb=(list mark)  built-marks
        |-
        ?~  bb  ^$(aa t.aa)
        ?:  =(i.aa i.bb)  $(bb t.bb)
        =/  old-reads  reads
        =.  reads  ~
        =^  hit=(unit soak)  this  (cached tube+[i.aa i.bb])
        ?^  hit
          ~?  >  veb  [%ford-cache-hit %tube i.aa i.bb]
          =.  reads  (~(uni in old-reads) reads)
          $(bb t.bb, soaks (~(put by soaks) tube+[i.aa i.bb] u.hit))
        =^  res=soak  this  (build-tube i.aa i.bb)
        =.  this  (save tube+[i.aa i.bb] res)
        =.  reads  (~(uni in old-reads) reads)
        $(bb t.bb, soaks (~(put by soaks) tube+[i.aa i.bb] res))
      ::
      =/  old-reads  reads
      =.  reads  ~
      =^  hit=(unit soak)  this  (cached dais+i.mark-list)
      ?^  hit
        ~?  >  veb  [%ford-cache-hit %dais i.mark-list]
        =.  reads  (~(uni in old-reads) reads)
        %=  $
          mark-list  t.mark-list
          soaks      (~(put by soaks) dais+i.mark-list u.hit)
        ==
      =^  res=soak  this  (build-dais i.mark-list)
      =.  this  (save dais+i.mark-list res)
      =.  reads  (~(uni in old-reads) reads)
      %=  $
        mark-list  t.mark-list
        soaks      (~(put by soaks) dais+i.mark-list res)
      ==
    ::
    =/  pax=path  i.hoon-files
    =/  old-reads  reads
    =.  reads  ~
    =^  hit=(unit soak)  this  (cached file+pax)
    ?^  hit
      ~?  >  veb  [%ford-cache-hit %file pax]
      =.  reads  (~(uni in old-reads) reads)
      %=  $
        hoon-files  t.hoon-files
        soaks       (~(put by soaks) file+pax u.hit)
      ==
    =^  res=soak  this  (build-file pax)
    =.  this  (save file+pax res)
    =.  reads  (~(uni in old-reads) reads)
    $(hoon-files t.hoon-files, soaks (~(put by soaks) file+pax res))
  --
--
