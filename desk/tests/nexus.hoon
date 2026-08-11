/+  *test, nexus, tarball
|%
::  ==========================================
::  +relativize-from tests
::  ==========================================
::
++  test-relativize-from-same-dir
  ::  Source in same directory - 0 steps
  =/  here=rail:tarball  [/a/b %dest]
  =/  =from:nexus  [/a/b %src]
  %+  expect-eq
    !>  `from:fiber:nexus`[0 [/ %src]]
  !>  (relativize-from:nexus here from)
::
++  test-relativize-from-sibling-dir
  ::  Source in sibling directory - 1 step up
  =/  here=rail:tarball  [/a/b %dest]
  =/  =from:nexus  [/a/c %src]
  %+  expect-eq
    !>  `from:fiber:nexus`[1 [/c %src]]
  !>  (relativize-from:nexus here from)
::
++  test-relativize-from-parent-dir
  ::  Source in parent directory - 2 steps up
  =/  here=rail:tarball  [/a/b/c %dest]
  =/  =from:nexus  [/a %src]
  %+  expect-eq
    !>  `from:fiber:nexus`[2 [/ %src]]
  !>  (relativize-from:nexus here from)
::
++  test-relativize-from-child-dir
  ::  Source in child directory - 0 steps (going down)
  =/  here=rail:tarball  [/a %dest]
  =/  =from:nexus  [/a/b/c %src]
  %+  expect-eq
    !>  `from:fiber:nexus`[0 [/b/c %src]]
  !>  (relativize-from:nexus here from)
::
++  test-relativize-from-distant
  ::  Source far away - multiple steps
  =/  here=rail:tarball  [/a/b/c %dest]
  =/  =from:nexus  [/x/y/z %src]
  %+  expect-eq
    !>  `from:fiber:nexus`[3 [/x/y/z %src]]
  !>  (relativize-from:nexus here from)
::
::  ==========================================
::  +raw-filter tests
::  ==========================================
::
++  test-raw-filter-dir-under-dir
  ::  Dest dir under allowed dir prefix returns true
  %+  expect-eq
    !>  %.y
  !>  (raw-filter:nexus |+/a/b/c |+/a/b)
::
++  test-raw-filter-file-under-dir
  ::  File under allowed dir prefix returns true
  %+  expect-eq
    !>  %.y
  !>  (raw-filter:nexus &+[/a/b %file] |+/a/b)
::
++  test-raw-filter-exact-dir-match
  ::  Dest dir exactly matches allowed dir returns true
  %+  expect-eq
    !>  %.y
  !>  (raw-filter:nexus |+/a/b |+/a/b)
::
++  test-raw-filter-exact-file-match
  ::  Dest file exactly matches allowed file returns true
  %+  expect-eq
    !>  %.y
  !>  (raw-filter:nexus &+[/a/b %file] &+[/a/b %file])
::
++  test-raw-filter-dir-not-allowed
  ::  Dest dir not under allowed prefix returns false
  %+  expect-eq
    !>  %.n
  !>  (raw-filter:nexus |+/a/b/c |+/x/y)
::
++  test-raw-filter-root-allows-all
  ::  Root dir prefix allows everything
  %+  expect-eq
    !>  %.y
  !>  (raw-filter:nexus |+/a/b/c |+/)
::
::  ==========================================
::  +filter-roads tests
::  ==========================================
::
++  test-filter-roads-absolute
  ::  Absolute road resolves and filters
  =/  here=fold:tarball  /somewhere
  =/  dest=lane:tarball  |+/a/b/c
  =/  roads=(list road:tarball)  ~[[%& [%| /a/b]]]
  %+  expect-eq
    !>  %.y
  !>  (filter-roads:nexus here dest roads)
::
++  test-filter-roads-relative
  ::  Relative road resolves from here
  =/  here=fold:tarball  /a/b
  =/  dest=lane:tarball  |+/a/c/d
  ::  From /a/b, go up 1 to /a, then /c allows /a/c/*
  =/  roads=(list road:tarball)  ~[[%| [1 [%| /c]]]]
  %+  expect-eq
    !>  %.y
  !>  (filter-roads:nexus here dest roads)
::
++  test-filter-roads-not-allowed
  ::  Dest not under any resolved road
  =/  here=fold:tarball  /a/b
  =/  dest=lane:tarball  |+/x/y/z
  =/  roads=(list road:tarball)  ~[[%& [%| /a]]]
  %+  expect-eq
    !>  %.n
  !>  (filter-roads:nexus here dest roads)
::
++  test-filter-roads-file-exact-match
  ::  File (rail) requires exact match - dest equals file path
  =/  here=fold:tarball  /somewhere
  =/  dest=lane:tarball  &+[/a/b %file]
  =/  roads=(list road:tarball)  ~[[%& [%& [/a/b %file]]]]
  %+  expect-eq
    !>  %.y
  !>  (filter-roads:nexus here dest roads)
::
++  test-filter-roads-file-no-prefix-match
  ::  File (rail) does NOT allow prefix matching - child path rejected
  =/  here=fold:tarball  /somewhere
  =/  dest=lane:tarball  |+/a/b/file/child
  =/  roads=(list road:tarball)  ~[[%& [%& [/a/b %file]]]]
  %+  expect-eq
    !>  %.n
  !>  (filter-roads:nexus here dest roads)
::
++  test-filter-roads-file-not-exact
  ::  File (rail) rejects different file in same dir
  =/  here=fold:tarball  /somewhere
  =/  dest=lane:tarball  &+[/a/b %other]
  =/  roads=(list road:tarball)  ~[[%& [%& [/a/b %file]]]]
  %+  expect-eq
    !>  %.n
  !>  (filter-roads:nexus here dest roads)
::
++  test-filter-roads-dir-prefix-match
  ::  Directory (fold) allows prefix matching
  =/  here=fold:tarball  /somewhere
  =/  dest=lane:tarball  |+/a/b/c/d/e
  =/  roads=(list road:tarball)  ~[[%& [%| /a/b]]]
  %+  expect-eq
    !>  %.y
  !>  (filter-roads:nexus here dest roads)
::
::  ==========================================
::  +filter tests
::  ==========================================
::
++  test-filter-no-weir
  ::  No weir means no filter (permissive)
  %+  expect-eq
    !>  `filt:nexus`~
  !>  (filter:nexus %poke /here |+/a/b/c ~)
::
::
++  test-filter-poke-allowed
  ::  Poke to allowed destination
  =/  =weir:nexus  [make=~ poke=(sy ~[[%& [%| /a/b]]]) peek=~]
  %+  expect-eq
    !>  `filt:nexus`[~ &]
  !>  (filter:nexus %poke /here |+/a/b/c `weir)
::
++  test-filter-poke-blocked
  ::  Poke to disallowed destination
  =/  =weir:nexus  [make=~ poke=(sy ~[[%& [%| /x/y]]]) peek=~]
  %+  expect-eq
    !>  `filt:nexus`[~ |]
  !>  (filter:nexus %poke /here |+/a/b/c `weir)
::
++  test-filter-make-allowed
  ::  Make to allowed destination
  =/  =weir:nexus  [make=(sy ~[[%& [%| /a]]]) poke=~ peek=~]
  %+  expect-eq
    !>  `filt:nexus`[~ &]
  !>  (filter:nexus %make /here |+/a/b/c `weir)
::
++  test-filter-peek-blocked
  ::  Peek to disallowed destination
  =/  =weir:nexus  [make=~ poke=~ peek=(sy ~[[%& [%| /other]]])]
  %+  expect-eq
    !>  `filt:nexus`[~ |]
  !>  (filter:nexus %peek /here |+/a/b/c `weir)
::
::  ==========================================
::  +next-filt tests
::  ==========================================
::
++  test-next-filt-both-permissive
  ::  Both ~ returns ~
  %+  expect-eq
    !>  `filt:nexus`~
  !>  (next-filt:nexus ~ ~)
::
++  test-next-filt-first-permissive
  ::  First ~ returns second
  %+  expect-eq
    !>  `filt:nexus`[~ &]
  !>  (next-filt:nexus ~ [~ &])
::
++  test-next-filt-second-permissive
  ::  Second ~ returns first
  %+  expect-eq
    !>  `filt:nexus`[~ &]
  !>  (next-filt:nexus [~ &] ~)
::
++  test-next-filt-first-veto
  ::  First veto wins
  %+  expect-eq
    !>  `filt:nexus`[~ |]
  !>  (next-filt:nexus [~ |] [~ &])
::
++  test-next-filt-second-veto
  ::  Second veto wins
  %+  expect-eq
    !>  `filt:nexus`[~ |]
  !>  (next-filt:nexus [~ &] [~ |])
::
++  test-next-filt-both-allow
  ::  Both allow returns allow
  %+  expect-eq
    !>  `filt:nexus`[~ &]
  !>  (next-filt:nexus [~ &] [~ &])
::
++  test-next-filt-both-veto
  ::  Both veto returns veto
  %+  expect-eq
    !>  `filt:nexus`[~ |]
  !>  (next-filt:nexus [~ |] [~ |])
::
::  ==========================================
::  +bo door tests (version tracking)
::  ==========================================
::
::  Helper to create a bo door with empty state
::
++  make-bo
  |=  now=@da
  ~(. bo:nexus now *born:nexus)
::
::  Helper to create bo with existing born
::
++  make-bo-with
  |=  [now=@da =born:nexus]
  ~(. bo:nexus now born)
::
++  test-bo-get-empty
  ::  Get from empty born returns ~
  =/  b  (make-bo ~2024.1.1)
  %+  expect-eq
    !>  `(unit hist:nexus)`~
  !>  (get:b [/a/b %file])
::
++  test-bo-init-creates-zero-hist
  ::  Init creates hist seeded with [[%temp ~] ~] at [0 now]
  =/  now=@da  ~2024.1.1
  =/  b  (make-bo now)
  =/  new-born=born:nexus  (init:b [/a/b %file])
  =/  b2  (make-bo-with now new-born)
  =/  sok=(unit hist:nexus)  (get:b2 [/a/b %file])
  ;:  weld
    %+  expect-eq  !>(%.y)  !>(?=(^ sok))
    %+  expect-eq  !>(`@ud`0)  !>((ver:hist:nexus (need sok)))
    %+  expect-eq  !>(`@ud`1)  !>((lent (tap:hon:hist:nexus (need sok))))
    %+  expect-eq
      !>  `(unit pace:hist:nexus)`[~ %temp ~]
    !>  (get-pace:hist:nexus (need sok) [0 now])
  ==
::
::
++  test-bo-next-cass-increments-ud
  ::  next-cass increments ud
  =/  now=@da  ~2024.1.1
  =/  b  (make-bo now)
  =/  old=cass:clay  [5 ~2023.1.1]
  =/  new=cass:clay  (next-cass:b old)
  %+  expect-eq
    !>  `@ud`6
  !>  ud.new
::
++  test-bo-next-cass-updates-da
  ::  next-cass updates da to now if old da < now
  =/  now=@da  ~2024.1.1
  =/  b  (make-bo now)
  =/  old=cass:clay  [5 ~2023.1.1]
  =/  new=cass:clay  (next-cass:b old)
  %+  expect-eq
    !>  now
  !>  da.new
::
++  test-bo-two-files-independent
  ::  Two files in same dir have independent sacks
  =/  now=@da  ~2024.1.1
  =/  b  (make-bo now)
  =/  born1=born:nexus  (init:b [/a %file1])
  =/  b2  (make-bo-with now born1)
  =/  born2=born:nexus  (init:b2 [/a %file2])
  =/  b3  (make-bo-with now born2)
  ::  Both files init'd, both at ver 0
  =/  sok1=(unit hist:nexus)  (get:b3 [/a %file1])
  =/  sok2=(unit hist:nexus)  (get:b3 [/a %file2])
  ;:  weld
    %+  expect-eq  !>(`@ud`0)  !>((ver:hist:nexus (need sok1)))
    %+  expect-eq  !>(`@ud`0)  !>((ver:hist:nexus (need sok2)))
  ==
::
::
++  test-bo-next-cass-future-da
  ::  next-cass uses +(da.cass) when da.cass >= now
  =/  now=@da  ~2024.1.1
  =/  b  (make-bo now)
  =/  future=@da  ~2025.1.1
  =/  old=cass:clay  [5 future]
  =/  new=cass:clay  (next-cass:b old)
  ::  da should be +(future), not now
  %+  expect-eq
    !>  +(future)
  !>  da.new
::
::  ==========================================
::  +si (silo) tests
::  ==========================================
::
++  make-cage
  |=  [=mark data=@t]
  ^-  cage
  [mark !>(data)]
::
::
++  test-si-put-new
  ::  put stores noun at refs=0 (leaf jects manage refs)
  =/  s  ~(. si:nexus *silo:nexus)
  =/  =noun  'hello'
  =/  [=nobe:nexus new-silo=silo:nexus]  (put:s noun)
  =/  s2  ~(. si:nexus new-silo)
  =/  got  (need (get:s2 nobe))
  ;:  weld
    %+  expect-eq
      !>  `@ud`0
    !>  refs:(~(got by nouns.new-silo) nobe)
  ::
    %+  expect-eq
      !>  noun
    !>  got
  ==
::
++  test-si-put-duplicate-is-noop
  ::  Inserting the same noun twice is a no-op (refs unchanged)
  =/  s  ~(. si:nexus *silo:nexus)
  =/  =noun  'hello'
  =/  [lobe1=nobe:nexus silo1=silo:nexus]  (put:s noun)
  =/  s2  ~(. si:nexus silo1)
  =/  [lobe2=nobe:nexus silo2=silo:nexus]  (put:s2 noun)
  ;:  weld
    %+  expect-eq
      !>  lobe1
    !>  lobe2
  ::
    %+  expect-eq
      !>  `@ud`0
    !>  refs:(~(got by nouns.silo2) lobe1)
  ==
::
++  test-si-drop-decrements-refs
  ::  Dropping with refs>1 decrements
  =/  s  ~(. si:nexus *silo:nexus)
  =/  =noun  'hello'
  =/  [=nobe:nexus silo1=silo:nexus]  (put:s noun)
  ::  bump via leaf ject to get refs=2
  =/  silo2=silo:nexus  (~(bump-ref si:nexus silo1) nobe)
  =/  silo3=silo:nexus  (~(bump-ref si:nexus silo2) nobe)
  ::  refs=2, drop once -> refs=1
  =/  silo4=silo:nexus  (~(drop si:nexus silo3) nobe)
  %+  expect-eq
    !>  `@ud`1
  !>  refs:(~(got by nouns.silo4) nobe)
::
++  test-si-drop-deletes-at-zero
  ::  Dropping with refs=1 removes from silo
  =/  s  ~(. si:nexus *silo:nexus)
  =/  =noun  'hello'
  =/  [=nobe:nexus silo1=silo:nexus]  (put:s noun)
  ::  bump to refs=1 via leaf ject ownership
  =/  silo2=silo:nexus  (~(bump-ref si:nexus silo1) nobe)
  =/  silo3=silo:nexus  (~(drop si:nexus silo2) nobe)
  %+  expect-eq
    !>  ~
  !>  (~(get by nouns.silo3) nobe)
::
++  test-si-drop-missing-is-noop
  ::  Dropping a nonexistent lobe is a no-op
  =/  s  ~(. si:nexus *silo:nexus)
  =/  fake-lobe=nobe:nexus  `@uvI`(sham 'fake')
  %+  expect-eq
    !>  *silo:nexus
  !>  (drop:s fake-lobe)
::
++  test-si-get-missing
  ::  Getting a nonexistent lobe returns ~
  =/  s  ~(. si:nexus *silo:nexus)
  =/  fake-lobe=nobe:nexus  `@uvI`(sham 'fake')
  %+  expect-eq
    !>  `(unit noun)`~
  !>  (get:s fake-lobe)
::
++  test-si-different-content-different-lobe
  ::  Different content produces different lobes
  =/  s  ~(. si:nexus *silo:nexus)
  =/  [lobe1=nobe:nexus silo1=silo:nexus]  (put:s 'hello')
  =/  s2  ~(. si:nexus silo1)
  =/  [lobe2=nobe:nexus silo2=silo:nexus]  (put:s2 'world')
  ;:  weld
    %+  expect-eq
      !>  %.n
    !>  =(lobe1 lobe2)
  ::
    %+  expect-eq
      !>  `@ud`2
    !>  ~(wyt by nouns.silo2)
  ==
::
++  test-si-same-noun-same-lobe
  ::  Same noun always produces same lobe regardless of blot
  =/  s  ~(. si:nexus *silo:nexus)
  =/  [lobe1=nobe:nexus *]  (put:s 'hello')
  =/  [lobe2=nobe:nexus *]  (put:s 'hello')
  %+  expect-eq
    !>  lobe1
  !>  lobe2
::
++  test-si-hash-deterministic
  ::  Same noun always produces the same hash
  =/  s  ~(. si:nexus *silo:nexus)
  %+  expect-eq
    !>  (hash:s 'hello')
  !>  (hash:s 'hello')
::
++  test-si-record-accumulates
  ::  firm records accumulate in history and silo
  =/  page1=bask:tarball  [[/ %txt] 'first']
  =/  page2=bask:tarball  [[/ %txt] 'second']
  =/  page3=bask:tarball  [[/ %txt] 'third']
  =/  cass1=cass:clay  [1 ~2024.1.1]
  =/  cass2=cass:clay  [2 ~2024.1.2]
  =/  cass3=cass:clay  [3 ~2024.1.3]
  =/  hist=hist:nexus  ~
  =/  [lobe1=nobe:nexus silo1=silo:nexus hist1=_hist]
    (~(record si:nexus *silo:nexus) q.page1 p.page1 0v0 / %.y cass1 [0 ~2024.1.1] hist)
  =/  [lobe2=nobe:nexus silo2=silo:nexus hist2=_hist]
    (~(record si:nexus silo1) q.page2 p.page2 0v0 / %.y cass2 cass1 hist1)
  =/  [lobe3=nobe:nexus silo3=silo:nexus hist3=_hist]
    (~(record si:nexus silo2) q.page3 p.page3 0v0 / %.y cass3 cass2 hist2)
  ;:  weld
    ::  All 3 entries in hist
    %+  expect-eq
      !>  `@ud`3
    !>  (lent (tap:hon:hist:nexus hist3))
  ::  All 3 in silo with refs=1
    %+  expect-eq
      !>  `@ud`3
    !>  ~(wyt by nouns.silo3)
  ::  Oldest entry has a live firm pace with an ject-lobe
    =/  oldest-pace=(unit pace:hist:nexus)  (get-pace:hist:nexus hist3 cass1)
    %+  expect-eq  !>(%.y)  !>(?=([~ %firm [~ @]] oldest-pace))
  ==
::
++  test-si-record-two-versions
  ::  two firm versions both stay in silo
  =/  page1=bask:tarball  [[/ %txt] 'first']
  =/  page2=bask:tarball  [[/ %txt] 'second']
  =/  cass1=cass:clay  [1 ~2024.1.1]
  =/  cass2=cass:clay  [2 ~2024.1.2]
  =/  hist=hist:nexus  ~
  =/  [lobe1=nobe:nexus silo1=silo:nexus hist1=_hist]
    (~(record si:nexus *silo:nexus) q.page1 p.page1 0v0 / %.y cass1 [0 ~2024.1.1] hist)
  =/  [lobe2=nobe:nexus silo2=silo:nexus hist2=_hist]
    (~(record si:nexus silo1) q.page2 p.page2 0v0 / %.y cass2 cass1 hist1)
  ;:  weld
    ::  2 entries in hist (both live)
    %+  expect-eq
      !>  `@ud`2
    !>  (lent (tap:hon:hist:nexus hist2))
  ::  Both pages in silo
    %+  expect-eq
      !>  %.y
    !>  ?=(^ (~(get by nouns.silo2) lobe1))
    %+  expect-eq
      !>  %.y
    !>  ?=(^ (~(get by nouns.silo2) lobe2))
  ==
::
++  test-si-record-same-content-deduplicates
  ::  record with same content: same lobe, noun refcounted
  =/  =bask:tarball  [[/ %txt] 'same']
  =/  cass1=cass:clay  [1 ~2024.1.1]
  =/  cass2=cass:clay  [2 ~2024.1.2]
  =/  hist=hist:nexus  ~
  =/  [lobe1=nobe:nexus silo1=silo:nexus hist1=_hist]
    (~(record si:nexus *silo:nexus) q.bask p.bask 0v0 / %.n cass1 [0 ~2024.1.1] hist)
  =/  [lobe2=nobe:nexus silo2=silo:nexus hist2=_hist]
    (~(record si:nexus silo1) q.bask p.bask 0v0 / %.n cass2 cass1 hist1)
  ;:  weld
    ::  Same lobe (content-addressed)
    %+  expect-eq
      !>  lobe1
    !>  lobe2
  ::  Still in silo with refs
    %+  expect-eq
      !>  %.y
    !>  ?=(^ (~(get by nouns.silo2) lobe1))
  ==
::
++  test-si-drop-hist-all-refs
  ::  drop-hist removes all firm refs from silo
  =/  page1=bask:tarball  [[/ %txt] 'aaa']
  =/  page2=bask:tarball  [[/ %txt] 'bbb']
  =/  page3=bask:tarball  [[/ %txt] 'ccc']
  =/  hist=hist:nexus  ~
  =/  [* silo1=silo:nexus hist1=_hist]
    (~(record si:nexus *silo:nexus) q.page1 p.page1 0v0 / %.y [1 ~2024.1.1] [0 ~2024.1.1] hist)
  =/  [* silo2=silo:nexus hist2=_hist]
    (~(record si:nexus silo1) q.page2 p.page2 0v0 / %.y [2 ~2024.1.2] [1 ~2024.1.1] hist1)
  =/  [* silo3=silo:nexus hist3=_hist]
    (~(record si:nexus silo2) q.page3 p.page3 0v0 / %.y [3 ~2024.1.3] [2 ~2024.1.2] hist2)
  ::  3 entries in silo
  ?>  =(3 ~(wyt by nouns.silo3))
  ::  Drop all
  =/  silo4=silo:nexus  (~(drop-hist si:nexus silo3) hist3)
  %+  expect-eq
    !>  `@ud`0
  !>  ~(wyt by nouns.silo4)
::
++  test-si-drop-hist-shared-refs
  ::  drop-hist with shared content only decrements, doesn't delete
  =/  =bask:tarball  [[/ %txt] 'shared']
  =/  hist=hist:nexus  ~
  ::  Record same page twice with keep (2 hist entries, same lobe, refs=2)
  =/  [=nobe:nexus silo1=silo:nexus hist1=_hist]
    (~(record si:nexus *silo:nexus) q.bask p.bask 0v0 / %.n [1 ~2024.1.1] [0 ~2024.1.1] hist)
  =/  [* silo2=silo:nexus hist2=_hist]
    (~(record si:nexus silo1) q.bask p.bask 0v0 / %.n [2 ~2024.1.2] [1 ~2024.1.1] hist1)
  ::  Drop all hist refs
  =/  silo3=silo:nexus  (~(drop-hist si:nexus silo2) hist2)
  ::  Lobe gone (ject drops to 0, cascades to noun)
  %+  expect-eq
    !>  `@ud`0
  !>  ~(wyt by nouns.silo3)
++  test-si-record-temp-tombs-previous
  ::  temp entries get tombed on next write — only latest survives
  =/  page1=bask:tarball  [[/ %txt] 'alpha']
  =/  page2=bask:tarball  [[/ %txt] 'bravo']
  =/  cass1=cass:clay  [1 ~2024.1.1]
  =/  cass2=cass:clay  [2 ~2024.1.2]
  =/  hist=hist:nexus  ~
  =/  [lobe1=nobe:nexus silo1=silo:nexus hist1=_hist]
    (~(record si:nexus *silo:nexus) q.page1 p.page1 0v0 / %.n cass1 [0 ~2024.1.1] hist)
  =/  [lobe2=nobe:nexus silo2=silo:nexus hist2=_hist]
    (~(record si:nexus silo1) q.page2 p.page2 0v0 / %.n cass2 cass1 hist1)
  ;:  weld
    ::  Hist still has 2 entries (tomb + live)
    %+  expect-eq
      !>  `@ud`2
    !>  (lent (tap:hon:hist:nexus hist2))
    ::  First entry is tombed
    =/  old-pace=(unit pace:hist:nexus)  (get-pace:hist:nexus hist2 cass1)
    %+  expect-eq  !>(%.y)  !>(?=([~ %tomb *] old-pace))
    ::  Second entry is live temp
    =/  new-pace=(unit pace:hist:nexus)  (get-pace:hist:nexus hist2 cass2)
    %+  expect-eq  !>(%.y)  !>(?=([~ %temp [~ @]] new-pace))
    ::  Only latest noun in silo
    %+  expect-eq  !>(`@ud`1)  !>(~(wyt by nouns.silo2))
    ::  Old lobe gone
    %+  expect-eq  !>(%.n)  !>(?=(^ (~(get by nouns.silo2) lobe1)))
    ::  New lobe present
    %+  expect-eq  !>(%.y)  !>(?=(^ (~(get by nouns.silo2) lobe2)))
  ==
::
++  test-si-record-firm-survives-next-write
  ::  firm entries are NOT tombed on next write
  =/  page1=bask:tarball  [[/ %txt] 'keep-me']
  =/  page2=bask:tarball  [[/ %txt] 'also-keep']
  =/  cass1=cass:clay  [1 ~2024.1.1]
  =/  cass2=cass:clay  [2 ~2024.1.2]
  =/  hist=hist:nexus  ~
  =/  [lobe1=nobe:nexus silo1=silo:nexus hist1=_hist]
    (~(record si:nexus *silo:nexus) q.page1 p.page1 0v0 / %.y cass1 [0 ~2024.1.1] hist)
  =/  [lobe2=nobe:nexus silo2=silo:nexus hist2=_hist]
    (~(record si:nexus silo1) q.page2 p.page2 0v0 / %.y cass2 cass1 hist1)
  ;:  weld
    ::  Both paces are firm (not tombed)
    =/  p1=(unit pace:hist:nexus)  (get-pace:hist:nexus hist2 cass1)
    %+  expect-eq  !>(%.y)  !>(?=([~ %firm [~ @]] p1))
    =/  p2=(unit pace:hist:nexus)  (get-pace:hist:nexus hist2 cass2)
    %+  expect-eq  !>(%.y)  !>(?=([~ %firm [~ @]] p2))
    ::  Both nouns survive
    %+  expect-eq  !>(`@ud`2)  !>(~(wyt by nouns.silo2))
  ==
::
++  test-si-record-temp-three-versions
  ::  three temp versions: only latest survives each step
  =/  page1=bask:tarball  [[/ %txt] 'one']
  =/  page2=bask:tarball  [[/ %txt] 'two']
  =/  page3=bask:tarball  [[/ %txt] 'three']
  =/  hist=hist:nexus  ~
  =/  [* silo1=silo:nexus hist1=_hist]
    (~(record si:nexus *silo:nexus) q.page1 p.page1 0v0 / %.n [1 ~2024.1.1] [0 ~2024.1.1] hist)
  =/  [* silo2=silo:nexus hist2=_hist]
    (~(record si:nexus silo1) q.page2 p.page2 0v0 / %.n [2 ~2024.1.2] [1 ~2024.1.1] hist1)
  =/  [lobe3=nobe:nexus silo3=silo:nexus hist3=_hist]
    (~(record si:nexus silo2) q.page3 p.page3 0v0 / %.n [3 ~2024.1.3] [2 ~2024.1.2] hist2)
  ;:  weld
    ::  3 hist entries total (2 tombs + 1 live)
    %+  expect-eq  !>(`@ud`3)  !>((lent (tap:hon:hist:nexus hist3)))
    ::  Only 1 noun in silo (the latest)
    %+  expect-eq  !>(`@ud`1)  !>(~(wyt by nouns.silo3))
    ::  drop-hist on the 1 live entry cleans up
    =/  silo4=silo:nexus  (~(drop-hist si:nexus silo3) hist3)
    %+  expect-eq  !>(`@ud`0)  !>(~(wyt by nouns.silo4))
  ==
::
::  ==========================================
::  +resolve-case tests
::  ==========================================
::
++  make-hist
  |=  entries=(list [ud=@ud da=@da =jobe:nexus =blot:tarball])
  ^-  hist:nexus
  =/  =hist:nexus  ~
  |-
  ?~  entries  hist
  $(entries t.entries, hist (put-pace:hist:nexus hist [ud.i.entries da.i.entries] [%temp `jobe.i.entries]))
::
++  test-resolve-case-ud-exact
  ::  %ud finds exact revision number
  =/  lobe1=jobe:nexus  `@uvI`(sham 'aaa')
  =/  lobe2=jobe:nexus  `@uvI`(sham 'bbb')
  =/  lobe3=jobe:nexus  `@uvI`(sham 'ccc')
  =/  hist  (make-hist ~[[1 ~2024.1.1 lobe1 [/ %txt]] [2 ~2024.1.2 lobe2 [/ %txt]] [3 ~2024.1.3 lobe3 [/ %txt]]])
  %+  expect-eq
    !>  `[[2 ~2024.1.2] [%temp `lobe2]]
  !>  (resolve-case:nexus [%ud 2] hist)
::
++  test-resolve-case-ud-first
  ::  %ud finds first entry
  =/  lobe1=jobe:nexus  `@uvI`(sham 'aaa')
  =/  lobe2=jobe:nexus  `@uvI`(sham 'bbb')
  =/  hist  (make-hist ~[[1 ~2024.1.1 lobe1 [/ %txt]] [2 ~2024.1.2 lobe2 [/ %txt]]])
  %+  expect-eq
    !>  `[[1 ~2024.1.1] [%temp `lobe1]]
  !>  (resolve-case:nexus [%ud 1] hist)
::
++  test-resolve-case-ud-last
  ::  %ud finds last entry
  =/  lobe1=jobe:nexus  `@uvI`(sham 'aaa')
  =/  lobe2=jobe:nexus  `@uvI`(sham 'bbb')
  =/  lobe3=jobe:nexus  `@uvI`(sham 'ccc')
  =/  hist  (make-hist ~[[1 ~2024.1.1 lobe1 [/ %txt]] [2 ~2024.1.2 lobe2 [/ %txt]] [3 ~2024.1.3 lobe3 [/ %txt]]])
  %+  expect-eq
    !>  `[[3 ~2024.1.3] [%temp `lobe3]]
  !>  (resolve-case:nexus [%ud 3] hist)
::
++  test-resolve-case-ud-not-found
  ::  %ud returns ~ on missing revision
  =/  lobe1=jobe:nexus  `@uvI`(sham 'aaa')
  =/  hist  (make-hist ~[[1 ~2024.1.1 lobe1 [/ %txt]]])
  %+  expect-eq
    !>  %.y
  !>  =(~ (resolve-case:nexus [%ud 99] hist))
::
++  test-resolve-case-da-exact
  ::  %da exact date match
  =/  lobe1=jobe:nexus  `@uvI`(sham 'aaa')
  =/  lobe2=jobe:nexus  `@uvI`(sham 'bbb')
  =/  hist  (make-hist ~[[1 ~2024.1.1 lobe1 [/ %txt]] [2 ~2024.1.2 lobe2 [/ %txt]]])
  %+  expect-eq
    !>  `[[2 ~2024.1.2] [%temp `lobe2]]
  !>  (resolve-case:nexus [%da ~2024.1.2] hist)
::
++  test-resolve-case-da-between
  ::  %da falls back to nearest previous date
  =/  lobe1=jobe:nexus  `@uvI`(sham 'aaa')
  =/  lobe2=jobe:nexus  `@uvI`(sham 'bbb')
  =/  lobe3=jobe:nexus  `@uvI`(sham 'ccc')
  =/  hist  (make-hist ~[[1 ~2024.1.1 lobe1 [/ %txt]] [2 ~2024.3.1 lobe2 [/ %txt]] [3 ~2024.6.1 lobe3 [/ %txt]]])
  ::  Date between entry 1 and 2 should return lobe1
  %+  expect-eq
    !>  `[[1 ~2024.1.1] [%temp `lobe1]]
  !>  (resolve-case:nexus [%da ~2024.2.1] hist)
::
++  test-resolve-case-da-after-all
  ::  %da after all entries returns latest
  =/  lobe1=jobe:nexus  `@uvI`(sham 'aaa')
  =/  lobe2=jobe:nexus  `@uvI`(sham 'bbb')
  =/  hist  (make-hist ~[[1 ~2024.1.1 lobe1 [/ %txt]] [2 ~2024.3.1 lobe2 [/ %txt]]])
  %+  expect-eq
    !>  `[[2 ~2024.3.1] [%temp `lobe2]]
  !>  (resolve-case:nexus [%da ~2025.1.1] hist)
::
++  test-resolve-case-da-before-all
  ::  %da before all entries returns ~
  =/  lobe1=jobe:nexus  `@uvI`(sham 'aaa')
  =/  hist  (make-hist ~[[1 ~2024.6.1 lobe1 [/ %txt]]])
  %+  expect-eq
    !>  %.y
  !>  =(~ (resolve-case:nexus [%da ~2024.1.1] hist))
::
++  test-resolve-case-da-empty
  ::  %da on empty hist returns ~
  =/  =hist:nexus  ~
  %+  expect-eq
    !>  %.y
  !>  =(~ (resolve-case:nexus [%da ~2024.1.1] hist))
::
++  test-resolve-case-ud-empty
  ::  %ud on empty hist returns ~
  =/  =hist:nexus  ~
  %+  expect-eq
    !>  %.y
  !>  =(~ (resolve-case:nexus [%ud 1] hist))
::
::  ==========================================
::  +record-trees tests
::  ==========================================
::
::  Helper: get node from born at path
::
++  get-node
  |=  [=born:nexus dir=path]
  ^-  (unit [fold=hist:nexus file=(map @ta hist:nexus)])
  =/  sub=born:nexus  (~(dip of born) dir)
  fil.sub
::
::  Helper: build a born with a single grub that has a hist entry
::
++  make-grub-born
  |=  [dir=path name=@ta =jobe:nexus =blot:tarball file-cass=cass:clay]
  ^-  born:nexus
  =/  sok=hist:nexus
    (put-pace:hist:nexus ~ file-cass [%temp `jobe])
  =/  zero=cass:clay  [0 ~2024.1.1]
  =/  node=[fold=hist:nexus file=(map @ta hist:nexus)]
    [(put-pace:hist:nexus ~ zero [%temp ~]) (~(put by *(map @ta hist:nexus)) name sok)]
  (~(put of *born:nexus) dir node)
::
++  test-record-trees-single-file
  ::  record-trees creates a tree with the grub's lobe in fil
  =/  now=@da  ~2024.1.1
  =/  =jobe:nexus  `@uvI`(sham 'hello')
  =/  =blot:tarball  [/ %txt]
  =/  =born:nexus  (make-grub-born / %myfile jobe blot [1 now])
  =/  [new-born=born:nexus new-silo=silo:nexus]
    (record-trees:nexus born *silo:nexus *code:nexus now /)
  ::  Fold should have bumped
  =/  node  (need (get-node new-born /))
  ;:  weld
    %+  expect-eq  !>(`@ud`1)  !>((ver:hist:nexus fold.node))
  ::  Tree should be in silo
    %+  expect-eq  !>(`@ud`1)  !>(~(wyt by jects.new-silo))
  ::  Tree's fil should have our grub's lobe
    =/  tree-lobe=jobe:nexus
      =/  pv=pace:hist:nexus  (need (get-pace:hist:nexus fold.node (need (top:hist:nexus fold.node))))
      ?>(?=(%temp -.pv) (need p.pv))
    =/  tree-entry=ject:nexus  ject:(~(got by jects.new-silo) tree-lobe)
    ?>  ?=(%tree -.tree-entry)
    %+  expect-eq
      !>  `(unit jobe:nexus)``jobe
    !>  (~(get by fil.tree.tree-entry) %myfile)
  ==
::
++  test-record-trees-no-change-no-bump
  ::  Calling record-trees twice with no changes doesn't bump fold
  =/  now=@da  ~2024.1.1
  =/  =jobe:nexus  `@uvI`(sham 'hello')
  =/  =born:nexus  (make-grub-born / %myfile jobe [/ %txt] [1 now])
  =/  [born1=born:nexus silo1=silo:nexus]
    (record-trees:nexus born *silo:nexus *code:nexus now /)
  ::  Call again — nothing changed
  =/  [born2=born:nexus silo2=silo:nexus]
    (record-trees:nexus born1 silo1 *code:nexus now /)
  ::  Fold should still be 1, not 2
  =/  node  (need (get-node born2 /))
  ;:  weld
    %+  expect-eq  !>(`@ud`1)  !>((ver:hist:nexus fold.node))
  ::  Still only 1 tree in silo (not duplicated)
    %+  expect-eq  !>(`@ud`1)  !>(~(wyt by jects.silo2))
  ==
::
++  test-record-trees-change-bumps-fold
  ::  Changing a grub's hist then re-recording bumps fold
  =/  now=@da  ~2024.1.1
  =/  lobe1=jobe:nexus  `@uvI`(sham 'first')
  =/  =born:nexus  (make-grub-born / %myfile lobe1 [/ %txt] [1 now])
  =/  [born1=born:nexus silo1=silo:nexus]
    (record-trees:nexus born *silo:nexus *code:nexus now /)
  ::  Simulate file change: update hist with new lobe at new cass
  =/  lobe2=jobe:nexus  `@uvI`(sham 'second')
  =/  new-cass=cass:clay  [2 ~2024.1.2]
  =/  born1-node  (need (get-node born1 /))
  =/  sok=hist:nexus  (~(got by file.born1-node) %myfile)
  =/  new-sok=hist:nexus
    (put-pace:hist:nexus sok new-cass [%temp `lobe2])
  =/  born2=born:nexus
    (~(put of born1) / born1-node(file (~(put by file.born1-node) %myfile new-sok)))
  =/  [born3=born:nexus silo2=silo:nexus]
    (record-trees:nexus born2 silo1 *code:nexus now /)
  ::  Fold should now be 2
  =/  node  (need (get-node born3 /))
  ;:  weld
    %+  expect-eq  !>(`@ud`2)  !>((ver:hist:nexus fold.node))
  ::  1 tree in silo (old tree tombed by tomb-temp)
    %+  expect-eq  !>(`@ud`1)  !>(~(wyt by jects.silo2))
  ==
::
++  test-record-trees-propagates-to-parent
  ::  record-trees at /a propagates tree to root /
  =/  now=@da  ~2024.1.1
  =/  =jobe:nexus  `@uvI`(sham 'hello')
  =/  =born:nexus  (make-grub-born /a %myfile jobe [/ %txt] [1 now])
  =/  [new-born=born:nexus new-silo=silo:nexus]
    (record-trees:nexus born *silo:nexus *code:nexus now /a)
  ::  /a should have fold=1
  =/  a-node  (need (get-node new-born /a))
  ::  / should also have fold=1 (parent got a tree too)
  =/  root-node  (need (get-node new-born /))
  ;:  weld
    %+  expect-eq  !>(`@ud`1)  !>((ver:hist:nexus fold.a-node))
    %+  expect-eq  !>(`@ud`1)  !>((ver:hist:nexus fold.root-node))
  ::  Root's tree should have /a's tree lobe in its dir map
    =/  root-tree-lobe=jobe:nexus
      =/  pv=pace:hist:nexus  (need (get-pace:hist:nexus fold.root-node (need (top:hist:nexus fold.root-node))))
      ?>(?=(%temp -.pv) (need p.pv))
    =/  root-tree  =+(jt=ject:(~(got by jects.new-silo) root-tree-lobe) ?>(?=(%tree -.jt) tree.jt))
    =/  a-tree-lobe=jobe:nexus
      =/  pv=pace:hist:nexus  (need (get-pace:hist:nexus fold.a-node (need (top:hist:nexus fold.a-node))))
      ?>(?=(%temp -.pv) (need p.pv))
    %+  expect-eq
      !>  a-tree-lobe
    !>  lobe:(~(got by dir.root-tree) %a)
  ==
::
::
::  Helper: add a grub to an existing born
::
++  add-grub
  |=  [=born:nexus dir=path name=@ta =jobe:nexus =blot:tarball file-cass=cass:clay]
  ^-  born:nexus
  =/  sok=hist:nexus
    (put-pace:hist:nexus ~ file-cass [%temp `jobe])
  =/  sub=born:nexus  (~(dip of born) dir)
  =/  node=[fold=hist:nexus file=(map @ta hist:nexus)]
    =/  zero=cass:clay  [0 ~2024.1.1]
    (fall fil.sub [(put-pace:hist:nexus ~ zero [%temp ~]) ~])
  (~(put of born) dir node(file (~(put by file.node) name sok)))
::
++  test-record-trees-multi-file
  ::  Tree captures multiple grubs in same dir
  =/  now=@da  ~2024.1.1
  =/  lobe1=jobe:nexus  `@uvI`(sham 'aaa')
  =/  lobe2=jobe:nexus  `@uvI`(sham 'bbb')
  =/  lobe3=jobe:nexus  `@uvI`(sham 'ccc')
  =/  =born:nexus  (make-grub-born / %alpha lobe1 [/ %txt] [1 now])
  =.  born  (add-grub born / %beta lobe2 [/ %hoon] [1 now])
  =.  born  (add-grub born / %gamma lobe3 [/ %json] [1 now])
  =/  [new-born=born:nexus new-silo=silo:nexus]
    (record-trees:nexus born *silo:nexus *code:nexus now /)
  =/  node  (need (get-node new-born /))
  =/  tree-lobe=jobe:nexus
    =/  pv=pace:hist:nexus  (need (get-pace:hist:nexus fold.node (need (top:hist:nexus fold.node))))
    ?>(?=(%temp -.pv) (need p.pv))
  =/  =tree:nexus  =+(jt=ject:(~(got by jects.new-silo) tree-lobe) ?>(?=(%tree -.jt) tree.jt))
  ;:  weld
    ::  All 3 grubs in tree's fil
    %+  expect-eq  !>(`@ud`3)  !>(~(wyt by fil.tree))
    %+  expect-eq
      !>  `(unit jobe:nexus)``lobe1
    !>  (~(get by fil.tree) %alpha)
    %+  expect-eq
      !>  `(unit jobe:nexus)``lobe2
    !>  (~(get by fil.tree) %beta)
    %+  expect-eq
      !>  `(unit jobe:nexus)``lobe3
    !>  (~(get by fil.tree) %gamma)
  ==
::
++  test-record-trees-mixed-files-and-dirs
  ::  Dir with both grubs and child directories
  =/  now=@da  ~2024.1.1
  =/  lobe1=jobe:nexus  `@uvI`(sham 'root-file')
  =/  lobe2=jobe:nexus  `@uvI`(sham 'child-file')
  ::  / has a grub, /sub has a grub
  =/  =born:nexus  (make-grub-born / %rootfile lobe1 [/ %txt] [1 now])
  =.  born  (add-grub born /sub %childfile lobe2 [/ %txt] [1 now])
  ::  Record from /sub up
  =/  [new-born=born:nexus new-silo=silo:nexus]
    (record-trees:nexus born *silo:nexus *code:nexus now /sub)
  =/  root-node  (need (get-node new-born /))
  =/  root-tree-lobe=jobe:nexus
    =/  pv=pace:hist:nexus  (need (get-pace:hist:nexus fold.root-node (need (top:hist:nexus fold.root-node))))
    ?>(?=(%temp -.pv) (need p.pv))
  =/  root-tree  =+(jt=ject:(~(got by jects.new-silo) root-tree-lobe) ?>(?=(%tree -.jt) tree.jt))
  ;:  weld
    ::  Root tree has the root grub in fil
    %+  expect-eq
      !>  `(unit jobe:nexus)``lobe1
    !>  (~(get by fil.root-tree) %rootfile)
    ::  Root tree has /sub in dir
    %+  expect-eq  !>(%.y)  !>((~(has by dir.root-tree) %sub))
    ::  /sub's tree has the child grub
    =/  sub-node  (need (get-node new-born /sub))
    =/  sub-tree-lobe=jobe:nexus
      =/  pv=pace:hist:nexus  (need (get-pace:hist:nexus fold.sub-node (need (top:hist:nexus fold.sub-node))))
      ?>(?=(%temp -.pv) (need p.pv))
    =/  sub-tree  =+(jt=ject:(~(got by jects.new-silo) sub-tree-lobe) ?>(?=(%tree -.jt) tree.jt))
    %+  expect-eq
      !>  `(unit jobe:nexus)``lobe2
    !>  (~(get by fil.sub-tree) %childfile)
  ==
::
::  ==========================================
::  +si ject store tests (put-ject, drop-ject, drop-hist)
::  ==========================================
::
++  test-si-put-ject-new
  ::  Inserting a new tree returns lobe and silo with refs=1
  =/  s  ~(. si:nexus *silo:nexus)
  =/  =tree:nexus  [~ %.n ~ ~ ~]
  =/  [=jobe:nexus new-silo=silo:nexus]  (put-ject:s [%tree tree])
  ;:  weld
    %+  expect-eq
      !>  `@ud`1
    !>  refs:(~(got by jects.new-silo) jobe)
  ::
    %+  expect-eq
      !>  tree
    !>  =+(jt=ject:(~(got by jects.new-silo) jobe) ?>(?=(%tree -.jt) tree.jt))
  ==
::
++  test-si-put-ject-bumps-leaf-refs
  ::  Inserting a tree that references leaf jects increments their refcounts
  =/  s  ~(. si:nexus *silo:nexus)
  =/  [noun-lobe=nobe:nexus silo1=silo:nexus]  (put:s 'hello')
  =/  [leaf-lobe=jobe:nexus silo2=silo:nexus]
    (~(put-ject si:nexus silo1) [%leaf noun-lobe [[/ %txt] 0v0 /] %.n ~])
  =/  =tree:nexus
    [~ %.n ~ (~(put by *(map @ta jobe:nexus)) %foo leaf-lobe) ~]
  =/  [* silo3=silo:nexus]  (~(put-ject si:nexus silo2) [%tree tree])
  ::  leaf started at refs=1, tree put-ject should bump to 2
  %+  expect-eq  !>(`@ud`2)  !>(refs:(~(got by jects.silo3) leaf-lobe))
::
++  test-si-put-ject-bumps-child-tree-refs
  ::  Inserting a tree that references child trees increments their refcounts
  =/  s  ~(. si:nexus *silo:nexus)
  =/  child=tree:nexus  [~ %.n ~ ~ ~]
  =/  [child-lobe=jobe:nexus silo1=silo:nexus]  (put-ject:s [%tree child])
  =/  parent=tree:nexus
    [~ %.n ~ ~ (~(put by *(map @ta [jobe:nexus weir=(unit weir:nexus)])) %sub [child-lobe ~])]
  =/  s2  ~(. si:nexus silo1)
  =/  [* silo2=silo:nexus]  (put-ject:s2 [%tree parent])
  ::  child started at refs=1, parent should bump to 2
  %+  expect-eq  !>(`@ud`2)  !>(refs:(~(got by jects.silo2) child-lobe))
::
++  test-si-put-ject-duplicate-no-extra-bumps
  ::  Inserting the same tree twice does NOT re-bump child refs
  =/  s  ~(. si:nexus *silo:nexus)
  =/  [noun-lobe=nobe:nexus silo1=silo:nexus]  (put:s 'hello')
  =/  [leaf-lobe=jobe:nexus silo2=silo:nexus]
    (~(put-ject si:nexus silo1) [%leaf noun-lobe [[/ %txt] 0v0 /] %.n ~])
  =/  =tree:nexus
    [~ %.n ~ (~(put by *(map @ta jobe:nexus)) %foo leaf-lobe) ~]
  =/  [=jobe:nexus silo3=silo:nexus]  (~(put-ject si:nexus silo2) [%tree tree])
  =/  [* silo4=silo:nexus]  (~(put-ject si:nexus silo3) [%tree tree])
  ;:  weld
    ::  tree refs=2
    %+  expect-eq  !>(`@ud`2)  !>(refs:(~(got by jects.silo4) jobe))
    ::  leaf refs still 2 (not 3) — only first insert bumps children
    %+  expect-eq  !>(`@ud`2)  !>(refs:(~(got by jects.silo4) leaf-lobe))
  ==
::
++  test-si-put-ject-duplicate-increments-refs
  ::  Inserting the same tree twice increments refcount
  =/  s  ~(. si:nexus *silo:nexus)
  =/  =tree:nexus  [~ %.n ~ ~ ~]
  =/  [lobe1=jobe:nexus silo1=silo:nexus]  (put-ject:s [%tree tree])
  =/  s2  ~(. si:nexus silo1)
  =/  [lobe2=jobe:nexus silo2=silo:nexus]  (put-ject:s2 [%tree tree])
  ;:  weld
    %+  expect-eq  !>(lobe1)  !>(lobe2)
    %+  expect-eq  !>(`@ud`2)  !>(refs:(~(got by jects.silo2) lobe1))
  ==
::
++  test-si-put-ject-different-content-different-lobe
  ::  Different trees produce different lobes
  =/  s  ~(. si:nexus *silo:nexus)
  =/  tree1=tree:nexus  [~ %.n ~ ~ ~]
  =/  tree2=tree:nexus
    [~ %.n ~ (~(put by *(map @ta jobe:nexus)) %foo `@uvI`(sham 'x')) ~]
  =/  [lobe1=jobe:nexus silo1=silo:nexus]  (put-ject:s [%tree tree1])
  =/  s2  ~(. si:nexus silo1)
  =/  [lobe2=jobe:nexus silo2=silo:nexus]  (put-ject:s2 [%tree tree2])
  ;:  weld
    %+  expect-eq  !>(%.n)  !>(=(lobe1 lobe2))
    %+  expect-eq  !>(`@ud`2)  !>(~(wyt by jects.silo2))
  ==
::
++  test-si-drop-ject-decrements-refs
  =/  s  ~(. si:nexus *silo:nexus)
  =/  =tree:nexus  [~ %.n ~ ~ ~]
  =/  [=jobe:nexus silo1=silo:nexus]  (put-ject:s [%tree tree])
  =/  s2  ~(. si:nexus silo1)
  =/  [* silo2=silo:nexus]  (put-ject:s2 [%tree tree])
  =/  s3  ~(. si:nexus silo2)
  =/  silo3=silo:nexus  (drop-ject:s3 jobe)
  %+  expect-eq  !>(`@ud`1)  !>(refs:(~(got by jects.silo3) jobe))
::
++  test-si-drop-ject-deletes-at-zero
  =/  s  ~(. si:nexus *silo:nexus)
  =/  =tree:nexus  [~ %.n ~ ~ ~]
  =/  [=jobe:nexus silo1=silo:nexus]  (put-ject:s [%tree tree])
  =/  s2  ~(. si:nexus silo1)
  =/  silo2=silo:nexus  (drop-ject:s2 jobe)
  %+  expect-eq  !>(~)  !>((~(get by jects.silo2) jobe))
::
++  test-si-drop-ject-cascades-leaves
  ::  Dropping a tree at zero decrements leaf ject refs
  =/  s  ~(. si:nexus *silo:nexus)
  =/  [noun-lobe=nobe:nexus silo1=silo:nexus]  (put:s 'hello')
  =/  [leaf-lobe=jobe:nexus silo2=silo:nexus]
    (~(put-ject si:nexus silo1) [%leaf noun-lobe [[/ %txt] 0v0 /] %.n ~])
  =/  =tree:nexus
    [~ %.n ~ (~(put by *(map @ta jobe:nexus)) %foo leaf-lobe) ~]
  =/  [tree-lobe=jobe:nexus silo3=silo:nexus]
    (~(put-ject si:nexus silo2) [%tree tree])
  ::  leaf is at refs=2 (own + tree bump). Drop tree → leaf refs=1
  =/  silo4=silo:nexus  (~(drop-ject si:nexus silo3) tree-lobe)
  ;:  weld
    %+  expect-eq  !>(~)  !>((~(get by jects.silo4) tree-lobe))
    %+  expect-eq  !>(`@ud`1)  !>(refs:(~(got by jects.silo4) leaf-lobe))
  ==
::
++  test-si-drop-ject-cascades-child-trees
  ::  Dropping a parent tree at zero cascades to child trees
  =/  s  ~(. si:nexus *silo:nexus)
  =/  child=tree:nexus  [~ %.n ~ ~ ~]
  =/  [child-lobe=jobe:nexus silo1=silo:nexus]  (put-ject:s [%tree child])
  =/  parent=tree:nexus
    [~ %.n ~ ~ (~(put by *(map @ta [jobe:nexus weir=(unit weir:nexus)])) %sub [child-lobe ~])]
  =/  s2  ~(. si:nexus silo1)
  =/  [parent-lobe=jobe:nexus silo2=silo:nexus]  (put-ject:s2 [%tree parent])
  ::  child is at refs=2. Drop parent → child refs=1
  =/  silo3=silo:nexus  (~(drop-ject si:nexus silo2) parent-lobe)
  ;:  weld
    %+  expect-eq  !>(~)  !>((~(get by jects.silo3) parent-lobe))
    %+  expect-eq  !>(`@ud`1)  !>(refs:(~(got by jects.silo3) child-lobe))
  ==
::
++  test-si-drop-ject-deep-cascade
  ::  Dropping a tree cascades through child tree to leaf ject
  =/  s  ~(. si:nexus *silo:nexus)
  =/  [noun-lobe=nobe:nexus silo1=silo:nexus]  (put:s 'data')
  =/  [leaf-lobe=jobe:nexus silo2=silo:nexus]
    (~(put-ject si:nexus silo1) [%leaf noun-lobe [[/ %txt] 0v0 /] %.n ~])
  =/  child=tree:nexus
    [~ %.n ~ (~(put by *(map @ta jobe:nexus)) %f leaf-lobe) ~]
  =/  [child-lobe=jobe:nexus silo3=silo:nexus]
    (~(put-ject si:nexus silo2) [%tree child])
  =/  parent=tree:nexus
    [~ %.n ~ ~ (~(put by *(map @ta [jobe:nexus weir=(unit weir:nexus)])) %sub [child-lobe ~])]
  =/  [parent-lobe=jobe:nexus silo4=silo:nexus]
    (~(put-ject si:nexus silo3) [%tree parent])
  ::  leaf: own(1) + child-put-ject(1) = 2
  ::  child: own(1) + parent-put-ject(1) = 2
  ::  Drop parent → child goes to 1 (not zero, so no further cascade)
  =/  silo5=silo:nexus  (~(drop-ject si:nexus silo4) parent-lobe)
  ;:  weld
    %+  expect-eq  !>(~)  !>((~(get by jects.silo5) parent-lobe))
    %+  expect-eq  !>(`@ud`1)  !>(refs:(~(got by jects.silo5) child-lobe))
    %+  expect-eq  !>(`@ud`2)  !>(refs:(~(got by jects.silo5) leaf-lobe))
  ==
::
++  test-si-drop-ject-full-cascade-deletes-all
  ::  When child tree is only referenced by parent, full cascade cleans everything
  =/  s  ~(. si:nexus *silo:nexus)
  =/  [noun-lobe=nobe:nexus silo1=silo:nexus]  (put:s 'data')
  =/  [leaf-lobe=jobe:nexus silo2=silo:nexus]
    (~(put-ject si:nexus silo1) [%leaf noun-lobe [[/ %txt] 0v0 /] %.n ~])
  =/  child=tree:nexus
    [~ %.n ~ (~(put by *(map @ta jobe:nexus)) %f leaf-lobe) ~]
  =/  [child-lobe=jobe:nexus silo3=silo:nexus]
    (~(put-ject si:nexus silo2) [%tree child])
  =/  parent=tree:nexus
    [~ %.n ~ ~ (~(put by *(map @ta [jobe:nexus weir=(unit weir:nexus)])) %sub [child-lobe ~])]
  =/  [parent-lobe=jobe:nexus silo4=silo:nexus]
    (~(put-ject si:nexus silo3) [%tree parent])
  ::  Drop child's extra ref so it's only held by parent
  =/  silo5=silo:nexus  (~(drop-ject si:nexus silo4) child-lobe)
  ::  Drop leaf's extra ref so it's only held by child tree
  =/  silo6=silo:nexus  (~(drop-ject si:nexus silo5) leaf-lobe)
  ::  Now drop parent — should cascade and clean everything
  =/  silo7=silo:nexus  (~(drop-ject si:nexus silo6) parent-lobe)
  ;:  weld
    %+  expect-eq  !>(`@ud`0)  !>(~(wyt by jects.silo7))
    %+  expect-eq  !>(`@ud`0)  !>(~(wyt by nouns.silo7))
  ==
::
++  test-si-drop-ject-missing-is-noop
  =/  s  ~(. si:nexus *silo:nexus)
  %+  expect-eq
    !>  *silo:nexus
  !>  (drop-ject:s `@uvI`(sham 'fake'))
::
++  test-si-drop-hist-all-ject-refs
  ::  drop-hist removes all ject refs from silo
  =/  s  ~(. si:nexus *silo:nexus)
  =/  tree1=tree:nexus  [~ %.n ~ ~ ~]
  =/  tree2=tree:nexus
    [~ %.n ~ (~(put by *(map @ta jobe:nexus)) %a `@uvI`(sham 'y')) ~]
  =/  [lobe1=jobe:nexus silo1=silo:nexus]  (put-ject:s [%tree tree1])
  =/  s2  ~(. si:nexus silo1)
  =/  [lobe2=jobe:nexus silo2=silo:nexus]  (put-ject:s2 [%tree tree2])
  =/  =hist:nexus
    %-  put-pace:hist:nexus
    [(put-pace:hist:nexus ~ [1 ~2024.1.1] [%temp `lobe1]) [2 ~2024.1.2] [%temp `lobe2]]
  =/  silo3=silo:nexus  (~(drop-hist si:nexus silo2) hist)
  %+  expect-eq  !>(`@ud`0)  !>(~(wyt by jects.silo3))
--
