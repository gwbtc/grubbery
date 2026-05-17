/+  *test, nexus, tarball
|%
::  ==========================================
::  +relativize-from tests
::  ==========================================
::
++  test-relativize-from-external-passthrough
  ::  External source passes through unchanged
  =/  here=rail:tarball  [/a/b %file]
  =/  =from:nexus  [%| [src=~zod sap=/some/path]]
  %+  expect-eq
    !>  `from:fiber:nexus`[%| [src=~zod sap=/some/path]]
  !>  (relativize-from:nexus here from)
::
++  test-relativize-from-same-dir
  ::  Source in same directory - 0 steps
  =/  here=rail:tarball  [/a/b %dest]
  =/  =from:nexus  [%& [/a/b %src]]
  %+  expect-eq
    !>  `from:fiber:nexus`[%& [0 [/ %src]]]
  !>  (relativize-from:nexus here from)
::
++  test-relativize-from-sibling-dir
  ::  Source in sibling directory - 1 step up
  =/  here=rail:tarball  [/a/b %dest]
  =/  =from:nexus  [%& [/a/c %src]]
  %+  expect-eq
    !>  `from:fiber:nexus`[%& [1 [/c %src]]]
  !>  (relativize-from:nexus here from)
::
++  test-relativize-from-parent-dir
  ::  Source in parent directory - 2 steps up
  =/  here=rail:tarball  [/a/b/c %dest]
  =/  =from:nexus  [%& [/a %src]]
  %+  expect-eq
    !>  `from:fiber:nexus`[%& [2 [/ %src]]]
  !>  (relativize-from:nexus here from)
::
++  test-relativize-from-child-dir
  ::  Source in child directory - 0 steps (going down)
  =/  here=rail:tarball  [/a %dest]
  =/  =from:nexus  [%& [/a/b/c %src]]
  %+  expect-eq
    !>  `from:fiber:nexus`[%& [0 [/b/c %src]]]
  !>  (relativize-from:nexus here from)
::
++  test-relativize-from-distant
  ::  Source far away - multiple steps
  =/  here=rail:tarball  [/a/b/c %dest]
  =/  =from:nexus  [%& [/x/y/z %src]]
  %+  expect-eq
    !>  `from:fiber:nexus`[%& [3 [/x/y/z %src]]]
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
  ~(. bo:nexus now [*born:nexus *ball:tarball])
::
::  Helper to create bo with existing born
::
++  make-bo-with
  |=  [now=@da =born:nexus]
  ~(. bo:nexus now [born *ball:tarball])
::
++  test-bo-get-empty
  ::  Get from empty born returns ~
  =/  b  (make-bo ~2024.1.1)
  %+  expect-eq
    !>  `(unit sack:nexus)`~
  !>  (get:b [/a/b %file])
::
++  test-bo-init-creates-zero-sack
  ::  Init creates [0 0] sack for new file
  =/  now=@da  ~2024.1.1
  =/  b  (make-bo now)
  =/  new-born=born:nexus  (init:b [/a/b %file])
  =/  b2  (make-bo-with now new-born)
  %+  expect-eq
    !>  `(unit sack:nexus)``[[0 now] [0 now] [0 now] ~]
  !>  (get:b2 [/a/b %file])
::
++  test-bo-bump-proc-increments
  ::  bump-proc increments proc cass
  =/  now=@da  ~2024.1.1
  =/  b  (make-bo now)
  =/  born1=born:nexus  (init:b [/a %file])
  =/  b2  (make-bo-with now born1)
  =/  born2=born:nexus  (bump-proc:b2 [/a %file])
  =/  b3  (make-bo-with now born2)
  =/  sok=(unit sack:nexus)  (get:b3 [/a %file])
  %+  expect-eq
    !>  `@ud`1
  !>  ud.proc:(need sok)
::
++  test-bo-bump-file-increments
  ::  bump-file increments file cass
  =/  now=@da  ~2024.1.1
  =/  b  (make-bo now)
  =/  born1=born:nexus  (init:b [/a %file])
  =/  b2  (make-bo-with now born1)
  =/  born2=born:nexus  (bump-file:b2 [/a %file])
  =/  b3  (make-bo-with now born2)
  =/  sok=(unit sack:nexus)  (get:b3 [/a %file])
  %+  expect-eq
    !>  `@ud`1
  !>  ud.file:(need sok)
::
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
++  test-bo-is-empty-dir-true
  ::  is-empty-dir returns true for empty dir
  =/  b  (make-bo ~2024.1.1)
  ::  ball is [fil=(unit lump) dir=(map @ta ball)]
  ::  lump is [=metadata neck=(unit neck) contents=(map @ta content)]
  =/  empty-ball=ball:tarball  [`[~ ~ ~] ~]  :: lump with no contents, no subdirs
  %+  expect-eq
    !>  %.y
  !>  (is-empty-dir:b empty-ball)
::
++  test-bo-is-empty-dir-false-has-files
  ::  is-empty-dir returns false if has files
  =/  b  (make-bo ~2024.1.1)
  =/  has-file=ball:tarball  [`[~ ~ (~(put by *(map @ta content:tarball)) %foo [~ [[/ %txt] !>('hi')]])] ~]
  %+  expect-eq
    !>  %.n
  !>  (is-empty-dir:b has-file)
::
++  test-bo-is-empty-dir-false-has-subdirs
  ::  is-empty-dir returns false if has subdirectories
  =/  b  (make-bo ~2024.1.1)
  =/  has-subdir=ball:tarball  [`[~ ~ ~] (~(put by *(map @ta ball:tarball)) %sub *ball:tarball)]
  %+  expect-eq
    !>  %.n
  !>  (is-empty-dir:b has-subdir)
::
++  test-bo-dir-exists-with-lump
  ::  dir-exists returns true if has lump
  =/  b  (make-bo ~2024.1.1)
  =/  has-lump=ball:tarball  [`[~ ~ ~] ~]
  %+  expect-eq
    !>  %.y
  !>  (dir-exists:b has-lump)
::
++  test-bo-dir-exists-with-children
  ::  dir-exists returns true if has children
  =/  b  (make-bo ~2024.1.1)
  =/  has-kids=ball:tarball  [~ (~(put by *(map @ta ball:tarball)) %sub *ball:tarball)]
  %+  expect-eq
    !>  %.y
  !>  (dir-exists:b has-kids)
::
++  test-bo-dir-exists-false
  ::  dir-exists returns false for empty ball
  =/  b  (make-bo ~2024.1.1)
  %+  expect-eq
    !>  %.n
  !>  (dir-exists:b *ball:tarball)
::
++  test-bo-multiple-bumps-increment
  ::  Multiple bump-file calls increment cass each time
  =/  now=@da  ~2024.1.1
  =/  b  (make-bo now)
  =/  born1=born:nexus  (init:b [/a %file])
  =/  b2  (make-bo-with now born1)
  =/  born2=born:nexus  (bump-file:b2 [/a %file])
  =/  b3  (make-bo-with now born2)
  =/  born3=born:nexus  (bump-file:b3 [/a %file])
  =/  b4  (make-bo-with now born3)
  =/  born4=born:nexus  (bump-file:b4 [/a %file])
  =/  b5  (make-bo-with now born4)
  =/  sok=(unit sack:nexus)  (get:b5 [/a %file])
  %+  expect-eq
    !>  `@ud`3
  !>  ud.file:(need sok)
::
++  test-bo-two-files-independent
  ::  Two files in same dir have independent sacks
  =/  now=@da  ~2024.1.1
  =/  b  (make-bo now)
  =/  born1=born:nexus  (init:b [/a %file1])
  =/  b2  (make-bo-with now born1)
  =/  born2=born:nexus  (init:b2 [/a %file2])
  =/  b3  (make-bo-with now born2)
  =/  born3=born:nexus  (bump-file:b3 [/a %file1])
  =/  b4  (make-bo-with now born3)
  ::  file1 was bumped, file2 wasn't
  =/  sok1=(unit sack:nexus)  (get:b4 [/a %file1])
  =/  sok2=(unit sack:nexus)  (get:b4 [/a %file2])
  ;:  weld
    %+  expect-eq  !>(`@ud`1)  !>(ud.file:(need sok1))
    %+  expect-eq  !>(`@ud`0)  !>(ud.file:(need sok2))
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
::
::  Helper to make a ball with files (same content)
::
++  make-ball-with-files
  |=  files=(list @ta)
  ^-  ball:tarball
  =/  contents=(map @ta content:tarball)
    %-  ~(gas by *(map @ta content:tarball))
    %+  turn  files
    |=(f=@ta [f [~ [/ %txt] !>('test')]])
  [`[~ ~ contents] ~]
::
::  Helper to make a ball with a file with specific content
::
++  make-ball-with-content
  |=  [name=@ta content=@t]
  ^-  ball:tarball
  =/  contents=(map @ta content:tarball)
    (~(put by *(map @ta content:tarball)) name [~ [[/ %txt] !>(content)]])
  [`[~ ~ contents] ~]
::
++  test-bo-diff-balls-new-file
  ::  diff-balls: new file gets init + bump
  =/  now=@da  ~2024.1.1
  =/  b  (make-bo now)
  =/  old-ball=ball:tarball  *ball:tarball
  =/  new-ball=ball:tarball  (make-ball-with-files ~[%newfile])
  =/  pre=born:nexus  *born:nexus
  =/  born1=born:nexus  (diff-balls:b / old-ball new-ball)
  =/  bumped=(set lane:tarball)  (diff-born:nexus pre born1)
  =/  b2  (make-bo-with now born1)
  ::  File should be init'd and bumped
  =/  sok=(unit sack:nexus)  (get:b2 [/ %newfile])
  ;:  weld
    %+  expect-eq  !>(%.y)  !>(?=(^ sok))
    %+  expect-eq  !>(`@ud`1)  !>(ud.file:(need sok))
    %+  expect-eq  !>(%.y)  !>((~(has in bumped) &+[/ %newfile]))
  ==
::
++  test-bo-diff-balls-deleted-file
  ::  diff-balls: deleted file gets bumped
  =/  now=@da  ~2024.1.1
  =/  b  (make-bo now)
  ::  Pre-init the file that will be "deleted"
  =/  born1=born:nexus  (init:b [/ %oldfile])
  =/  b2  (make-bo-with now born1)
  =/  old-ball=ball:tarball  (make-ball-with-files ~[%oldfile])
  =/  new-ball=ball:tarball  *ball:tarball
  =/  born2=born:nexus  (diff-balls:b2 / old-ball new-ball)
  =/  bumped=(set lane:tarball)  (diff-born:nexus born1 born2)
  =/  b3  (make-bo-with now born2)
  ::  File should be bumped
  =/  sok=(unit sack:nexus)  (get:b3 [/ %oldfile])
  ;:  weld
    %+  expect-eq  !>(`@ud`1)  !>(ud.file:(need sok))
    %+  expect-eq  !>(%.y)  !>((~(has in bumped) &+[/ %oldfile]))
  ==
::
++  test-bo-diff-balls-changed-file
  ::  diff-balls: changed file gets bumped
  =/  now=@da  ~2024.1.1
  =/  b  (make-bo now)
  ::  Pre-init the file
  =/  born1=born:nexus  (init:b [/ %file])
  =/  b2  (make-bo-with now born1)
  =/  old-ball=ball:tarball  (make-ball-with-content %file 'old content')
  =/  new-ball=ball:tarball  (make-ball-with-content %file 'new content')
  =/  born2=born:nexus  (diff-balls:b2 / old-ball new-ball)
  =/  bumped=(set lane:tarball)  (diff-born:nexus born1 born2)
  =/  b3  (make-bo-with now born2)
  ::  File should be bumped
  =/  sok=(unit sack:nexus)  (get:b3 [/ %file])
  ;:  weld
    %+  expect-eq  !>(`@ud`1)  !>(ud.file:(need sok))
    %+  expect-eq  !>(%.y)  !>((~(has in bumped) &+[/ %file]))
  ==
::
++  test-bo-diff-balls-unchanged-file
  ::  diff-balls: unchanged file not bumped
  =/  now=@da  ~2024.1.1
  =/  b  (make-bo now)
  ::  Pre-init the file
  =/  born1=born:nexus  (init:b [/ %file])
  =/  b2  (make-bo-with now born1)
  =/  ball=ball:tarball  (make-ball-with-content %file 'same content')
  =/  born2=born:nexus  (diff-balls:b2 / ball ball)
  =/  bumped=(set lane:tarball)  (diff-born:nexus born1 born2)
  =/  b3  (make-bo-with now born2)
  ::  File should NOT be bumped
  =/  sok=(unit sack:nexus)  (get:b3 [/ %file])
  ;:  weld
    %+  expect-eq  !>(`@ud`0)  !>(ud.file:(need sok))
    %+  expect-eq  !>(%.n)  !>((~(has in bumped) &+[/ %file]))
  ==
::
++  test-bo-diff-balls-mixed
  ::  diff-balls: mix of new, deleted, changed, unchanged
  =/  now=@da  ~2024.1.1
  =/  b  (make-bo now)
  ::  Pre-init files that exist in old
  =/  born1=born:nexus  (init:b [/ %deleted])
  =/  b2  (make-bo-with now born1)
  =/  born2=born:nexus  (init:b2 [/ %changed])
  =/  b3  (make-bo-with now born2)
  =/  born3=born:nexus  (init:b3 [/ %unchanged])
  =/  b4  (make-bo-with now born3)
  ::  Old: deleted, changed, unchanged
  =/  old-contents=(map @ta content:tarball)
    %-  ~(gas by *(map @ta content:tarball))
    :~  [%deleted [~ [[/ %txt] !>('del')]]]
        [%changed [~ [[/ %txt] !>('old')]]]
        [%unchanged [~ [[/ %txt] !>('same')]]]
    ==
  =/  old-ball=ball:tarball  [`[~ ~ old-contents] ~]
  ::  New: new, changed, unchanged
  =/  new-contents=(map @ta content:tarball)
    %-  ~(gas by *(map @ta content:tarball))
    :~  [%new [~ [[/ %txt] !>('new')]]]
        [%changed [~ [[/ %txt] !>('different')]]]
        [%unchanged [~ [[/ %txt] !>('same')]]]
    ==
  =/  new-ball=ball:tarball  [`[~ ~ new-contents] ~]
  =/  born4=born:nexus  (diff-balls:b4 / old-ball new-ball)
  =/  bumped=(set lane:tarball)  (diff-born:nexus born3 born4)
  =/  b5  (make-bo-with now born4)
  ;:  weld
    ::  new: init'd and bumped
    %+  expect-eq  !>(`@ud`1)  !>(ud.file:(need (get:b5 [/ %new])))
    %+  expect-eq  !>(%.y)  !>((~(has in bumped) &+[/ %new]))
    ::  deleted: bumped
    %+  expect-eq  !>(`@ud`1)  !>(ud.file:(need (get:b5 [/ %deleted])))
    %+  expect-eq  !>(%.y)  !>((~(has in bumped) &+[/ %deleted]))
    ::  changed: bumped
    %+  expect-eq  !>(`@ud`1)  !>(ud.file:(need (get:b5 [/ %changed])))
    %+  expect-eq  !>(%.y)  !>((~(has in bumped) &+[/ %changed]))
    ::  unchanged: NOT bumped
    %+  expect-eq  !>(`@ud`0)  !>(ud.file:(need (get:b5 [/ %unchanged])))
    %+  expect-eq  !>(%.n)  !>((~(has in bumped) &+[/ %unchanged]))
  ==
::
++  test-bo-diff-balls-nested
  ::  diff-balls: recurses into subdirectories
  =/  now=@da  ~2024.1.1
  =/  b  (make-bo now)
  ::  Pre-init file in subdir
  =/  born1=born:nexus  (init:b [/sub %oldfile])
  =/  b2  (make-bo-with now born1)
  ::  Old: /sub/oldfile
  =/  old-sub=ball:tarball  (make-ball-with-files ~[%oldfile])
  =/  old-ball=ball:tarball  [~ (~(put by *(map @ta ball:tarball)) %sub old-sub)]
  ::  New: /sub/newfile (oldfile deleted, newfile added)
  =/  new-sub=ball:tarball  (make-ball-with-files ~[%newfile])
  =/  new-ball=ball:tarball  [~ (~(put by *(map @ta ball:tarball)) %sub new-sub)]
  =/  born2=born:nexus  (diff-balls:b2 / old-ball new-ball)
  =/  bumped=(set lane:tarball)  (diff-born:nexus born1 born2)
  =/  b3  (make-bo-with now born2)
  ;:  weld
    ::  oldfile: bumped (deleted)
    %+  expect-eq  !>(`@ud`1)  !>(ud.file:(need (get:b3 [/sub %oldfile])))
    %+  expect-eq  !>(%.y)  !>((~(has in bumped) &+[/sub %oldfile]))
    ::  newfile: init'd and bumped
    %+  expect-eq  !>(`@ud`1)  !>(ud.file:(need (get:b3 [/sub %newfile])))
    %+  expect-eq  !>(%.y)  !>((~(has in bumped) &+[/sub %newfile]))
  ==
::
++  test-bo-diff-balls-empty-dir-appears
  ::  diff-balls: empty dir appearing gets bumped
  =/  now=@da  ~2024.1.1
  =/  b  (make-bo now)
  =/  old-ball=ball:tarball  *ball:tarball
  =/  new-ball=ball:tarball  [`[~ ~ ~] ~]  :: empty dir (lump, no contents)
  =/  born1=born:nexus  (diff-balls:b / old-ball new-ball)
  =/  bumped=(set lane:tarball)  (diff-born:nexus *born:nexus born1)
  ::  Root dir should be bumped
  %+  expect-eq
    !>  %.y
  !>  (~(has in bumped) |+/)
::
++  test-bo-diff-balls-empty-dir-disappears
  ::  diff-balls: empty dir disappearing gets bumped
  =/  now=@da  ~2024.1.1
  =/  b  (make-bo now)
  =/  old-ball=ball:tarball  [`[~ ~ ~] ~]  :: empty dir
  =/  new-ball=ball:tarball  *ball:tarball
  =/  born1=born:nexus  (diff-balls:b / old-ball new-ball)
  =/  bumped=(set lane:tarball)  (diff-born:nexus *born:nexus born1)
  ::  Root dir should be bumped
  %+  expect-eq
    !>  %.y
  !>  (~(has in bumped) |+/)
::
++  test-bo-diff-balls-no-changes
  ::  diff-balls: identical balls produce no bumps
  =/  now=@da  ~2024.1.1
  =/  b  (make-bo now)
  =/  born1=born:nexus  (init:b [/ %file])
  =/  b2  (make-bo-with now born1)
  =/  ball=ball:tarball  (make-ball-with-files ~[%file])
  =/  born2=born:nexus  (diff-balls:b2 / ball ball)
  =/  bumped=(set lane:tarball)  (diff-born:nexus born1 born2)
  %+  expect-eq
    !>  `@ud`0
  !>  ~(wyt in bumped)
::
++  test-bo-is-empty-dir-no-lump
  ::  is-empty-dir returns false when no lump
  =/  b  (make-bo ~2024.1.1)
  =/  no-lump=ball:tarball  [~ ~]
  %+  expect-eq
    !>  %.n
  !>  (is-empty-dir:b no-lump)
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
  ::  Inserting a new page returns lobe and silo with refs=1
  =/  s  ~(. si:nexus *silo:nexus)
  =/  =noun  'hello'
  =/  [=lobe:clay new-silo=silo:nexus]  (put:s noun)
  =/  s2  ~(. si:nexus new-silo)
  =/  got  (need (get:s2 lobe))
  ;:  weld
    %+  expect-eq
      !>  `@ud`1
    !>  refs:(~(got by blobs.new-silo) lobe)
  ::
    %+  expect-eq
      !>  noun
    !>  got
  ==
::
++  test-si-put-duplicate-increments-refs
  ::  Inserting the same page twice increments refcount
  =/  s  ~(. si:nexus *silo:nexus)
  =/  =noun  'hello'
  =/  [lobe1=lobe:clay silo1=silo:nexus]  (put:s noun)
  =/  s2  ~(. si:nexus silo1)
  =/  [lobe2=lobe:clay silo2=silo:nexus]  (put:s2 noun)
  ;:  weld
    %+  expect-eq
      !>  lobe1
    !>  lobe2
  ::
    %+  expect-eq
      !>  `@ud`2
    !>  refs:(~(got by blobs.silo2) lobe1)
  ==
::
++  test-si-drop-decrements-refs
  ::  Dropping with refs>1 decrements
  =/  s  ~(. si:nexus *silo:nexus)
  =/  =noun  'hello'
  =/  [=lobe:clay silo1=silo:nexus]  (put:s noun)
  =/  s2  ~(. si:nexus silo1)
  =/  [* silo2=silo:nexus]  (put:s2 noun)
  ::  refs=2, drop once -> refs=1
  =/  s3  ~(. si:nexus silo2)
  =/  silo3=silo:nexus  (drop:s3 lobe)
  %+  expect-eq
    !>  `@ud`1
  !>  refs:(~(got by blobs.silo3) lobe)
::
++  test-si-drop-deletes-at-zero
  ::  Dropping with refs=1 removes from silo
  =/  s  ~(. si:nexus *silo:nexus)
  =/  =noun  'hello'
  =/  [=lobe:clay silo1=silo:nexus]  (put:s noun)
  =/  s2  ~(. si:nexus silo1)
  =/  silo2=silo:nexus  (drop:s2 lobe)
  %+  expect-eq
    !>  ~
  !>  (~(get by blobs.silo2) lobe)
::
++  test-si-drop-missing-is-noop
  ::  Dropping a nonexistent lobe is a no-op
  =/  s  ~(. si:nexus *silo:nexus)
  =/  fake-lobe=lobe:clay  `@uvI`(sham 'fake')
  %+  expect-eq
    !>  *silo:nexus
  !>  (drop:s fake-lobe)
::
++  test-si-get-missing
  ::  Getting a nonexistent lobe returns ~
  =/  s  ~(. si:nexus *silo:nexus)
  =/  fake-lobe=lobe:clay  `@uvI`(sham 'fake')
  %+  expect-eq
    !>  `(unit noun)`~
  !>  (get:s fake-lobe)
::
++  test-si-different-content-different-lobe
  ::  Different content produces different lobes
  =/  s  ~(. si:nexus *silo:nexus)
  =/  [lobe1=lobe:clay silo1=silo:nexus]  (put:s 'hello')
  =/  s2  ~(. si:nexus silo1)
  =/  [lobe2=lobe:clay silo2=silo:nexus]  (put:s2 'world')
  ;:  weld
    %+  expect-eq
      !>  %.n
    !>  =(lobe1 lobe2)
  ::
    %+  expect-eq
      !>  `@ud`2
    !>  ~(wyt by blobs.silo2)
  ==
::
++  test-si-same-noun-same-lobe
  ::  Same noun always produces same lobe regardless of blot
  =/  s  ~(. si:nexus *silo:nexus)
  =/  [lobe1=lobe:clay *]  (put:s 'hello')
  =/  [lobe2=lobe:clay *]  (put:s 'hello')
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
++  test-si-record-keep-accumulates
  ::  record with keep=%.y accumulates history entries
  =/  s  ~(. si:nexus *silo:nexus)
  =/  page1=bask:tarball  [[/ %txt] 'first']
  =/  page2=bask:tarball  [[/ %txt] 'second']
  =/  page3=bask:tarball  [[/ %txt] 'third']
  =/  cass1=cass:clay  [1 ~2024.1.1]
  =/  cass2=cass:clay  [2 ~2024.1.2]
  =/  cass3=cass:clay  [3 ~2024.1.3]
  =/  hist=_hist:*sack:nexus  ~
  =/  [lobe1=lobe:clay silo1=silo:nexus hist1=_hist]
    (~(record si:nexus *silo:nexus) q.page1 p.page1 cass1 %.y *cass:clay hist)
  =/  [lobe2=lobe:clay silo2=silo:nexus hist2=_hist]
    (~(record si:nexus silo1) q.page2 p.page2 cass2 %.y *cass:clay hist1)
  =/  [lobe3=lobe:clay silo3=silo:nexus hist3=_hist]
    (~(record si:nexus silo2) q.page3 p.page3 cass3 %.y *cass:clay hist2)
  ;:  weld
    ::  All 3 entries in hist
    %+  expect-eq
      !>  `@ud`3
    !>  (lent (tap:on-hist:sack:nexus hist3))
  ::  All 3 in silo with refs=1
    %+  expect-eq
      !>  `@ud`3
    !>  ~(wyt by blobs.silo3)
  ::  Oldest entry maps to lobe1
    %+  expect-eq
      !>  `(unit [lobe:clay blot:tarball])`(get:on-hist:sack:nexus hist3 cass1)
    !>  `(unit [lobe:clay blot:tarball])``[lobe1 [/ %txt]]
  ==
::
++  test-si-record-no-keep-replaces
  ::  record with gain=%.n replaces current live version, drops old ref
  =/  s  ~(. si:nexus *silo:nexus)
  =/  page1=bask:tarball  [[/ %txt] 'first']
  =/  page2=bask:tarball  [[/ %txt] 'second']
  =/  cass1=cass:clay  [1 ~2024.1.1]
  =/  cass2=cass:clay  [2 ~2024.1.2]
  =/  hist=_hist:*sack:nexus  ~
  =/  [lobe1=lobe:clay silo1=silo:nexus hist1=_hist]
    (~(record si:nexus *silo:nexus) q.page1 p.page1 cass1 %.n *cass:clay hist)
  =/  [lobe2=lobe:clay silo2=silo:nexus hist2=_hist]
    (~(record si:nexus silo1) q.page2 p.page2 cass2 %.n cass1 hist1)
  ;:  weld
    ::  Only 1 entry in hist (latest)
    %+  expect-eq
      !>  `@ud`1
    !>  (lent (tap:on-hist:sack:nexus hist2))
  ::  Old page dropped from silo
    %+  expect-eq
      !>  ~
    !>  (~(get by blobs.silo2) lobe1)
  ::  New page in silo
    %+  expect-eq
      !>  %.y
    !>  ?=(^ (~(get by blobs.silo2) lobe2))
  ==
::
++  test-si-record-no-keep-same-content
  ::  record with gain=%.n and same content: refcount stays at 1
  =/  =bask:tarball  [[/ %txt] 'same']
  =/  cass1=cass:clay  [1 ~2024.1.1]
  =/  cass2=cass:clay  [2 ~2024.1.2]
  =/  hist=_hist:*sack:nexus  ~
  =/  [lobe1=lobe:clay silo1=silo:nexus hist1=_hist]
    (~(record si:nexus *silo:nexus) q.bask p.bask cass1 %.n *cass:clay hist)
  =/  [lobe2=lobe:clay silo2=silo:nexus hist2=_hist]
    (~(record si:nexus silo1) q.bask p.bask cass2 %.n cass1 hist1)
  ;:  weld
    ::  Same lobe (content-addressed)
    %+  expect-eq
      !>  lobe1
    !>  lobe2
  ::  Still in silo (put incremented, drop decremented, net refs=1)
    %+  expect-eq
      !>  `@ud`1
    !>  refs:(~(got by blobs.silo2) lobe1)
  ==
::
++  test-si-drop-hist-all-refs
  ::  drop-hist removes all refs from silo
  =/  page1=bask:tarball  [[/ %txt] 'aaa']
  =/  page2=bask:tarball  [[/ %txt] 'bbb']
  =/  page3=bask:tarball  [[/ %txt] 'ccc']
  =/  hist=_hist:*sack:nexus  ~
  =/  [* silo1=silo:nexus hist1=_hist]
    (~(record si:nexus *silo:nexus) q.page1 p.page1 [1 ~2024.1.1] %.y *cass:clay hist)
  =/  [* silo2=silo:nexus hist2=_hist]
    (~(record si:nexus silo1) q.page2 p.page2 [2 ~2024.1.2] %.y *cass:clay hist1)
  =/  [* silo3=silo:nexus hist3=_hist]
    (~(record si:nexus silo2) q.page3 p.page3 [3 ~2024.1.3] %.y *cass:clay hist2)
  ::  3 entries in silo
  ?>  =(3 ~(wyt by blobs.silo3))
  ::  Drop all
  =/  silo4=silo:nexus  (~(drop-hist si:nexus silo3) hist3)
  %+  expect-eq
    !>  `@ud`0
  !>  ~(wyt by blobs.silo4)
::
++  test-si-drop-hist-shared-refs
  ::  drop-hist with shared content only decrements, doesn't delete
  =/  =bask:tarball  [[/ %txt] 'shared']
  =/  hist=_hist:*sack:nexus  ~
  ::  Record same page twice with keep (2 hist entries, same lobe, refs=2)
  =/  [=lobe:clay silo1=silo:nexus hist1=_hist]
    (~(record si:nexus *silo:nexus) q.bask p.bask [1 ~2024.1.1] %.y *cass:clay hist)
  =/  [* silo2=silo:nexus hist2=_hist]
    (~(record si:nexus silo1) q.bask p.bask [2 ~2024.1.2] %.y *cass:clay hist1)
  ?>  =(2 refs:(~(got by blobs.silo2) lobe))
  ::  Drop all hist refs
  =/  silo3=silo:nexus  (~(drop-hist si:nexus silo2) hist2)
  ::  Lobe gone (2 drops on refs=2)
  %+  expect-eq
    !>  `@ud`0
  !>  ~(wyt by blobs.silo3)
::
::  ==========================================
::  +resolve-case tests
::  ==========================================
::
++  make-hist
  |=  entries=(list [ud=@ud da=@da =lobe:clay =blot:tarball])
  ^-  ((mop cass:clay ,[lobe:clay blot:tarball]) cor:nexus)
  =/  hist=((mop cass:clay ,[lobe:clay blot:tarball]) cor:nexus)  ~
  |-
  ?~  entries  hist
  $(entries t.entries, hist (put:on-hist:sack:nexus hist [ud.i.entries da.i.entries] [lobe.i.entries blot.i.entries]))
::
++  test-resolve-case-ud-exact
  ::  %ud finds exact revision number
  =/  lobe1=lobe:clay  `@uvI`(sham 'aaa')
  =/  lobe2=lobe:clay  `@uvI`(sham 'bbb')
  =/  lobe3=lobe:clay  `@uvI`(sham 'ccc')
  =/  hist  (make-hist ~[[1 ~2024.1.1 lobe1 [/ %txt]] [2 ~2024.1.2 lobe2 [/ %txt]] [3 ~2024.1.3 lobe3 [/ %txt]]])
  %+  expect-eq
    !>  [lobe2 [/ %txt]]
  !>  (resolve-case:nexus [%ud 2] hist)
::
++  test-resolve-case-ud-first
  ::  %ud finds first entry
  =/  lobe1=lobe:clay  `@uvI`(sham 'aaa')
  =/  lobe2=lobe:clay  `@uvI`(sham 'bbb')
  =/  hist  (make-hist ~[[1 ~2024.1.1 lobe1 [/ %txt]] [2 ~2024.1.2 lobe2 [/ %txt]]])
  %+  expect-eq
    !>  [lobe1 [/ %txt]]
  !>  (resolve-case:nexus [%ud 1] hist)
::
++  test-resolve-case-ud-last
  ::  %ud finds last entry
  =/  lobe1=lobe:clay  `@uvI`(sham 'aaa')
  =/  lobe2=lobe:clay  `@uvI`(sham 'bbb')
  =/  lobe3=lobe:clay  `@uvI`(sham 'ccc')
  =/  hist  (make-hist ~[[1 ~2024.1.1 lobe1 [/ %txt]] [2 ~2024.1.2 lobe2 [/ %txt]] [3 ~2024.1.3 lobe3 [/ %txt]]])
  %+  expect-eq
    !>  [lobe3 [/ %txt]]
  !>  (resolve-case:nexus [%ud 3] hist)
::
++  test-resolve-case-ud-not-found
  ::  %ud crashes on missing revision
  =/  lobe1=lobe:clay  `@uvI`(sham 'aaa')
  =/  hist  (make-hist ~[[1 ~2024.1.1 lobe1 [/ %txt]]])
  =/  res=(each [lobe:clay blot:tarball] tang)
    (mule |.((resolve-case:nexus [%ud 99] hist)))
  %+  expect-eq
    !>  %.y
  !>  ?=(%| -.res)
::
++  test-resolve-case-da-exact
  ::  %da exact date match
  =/  lobe1=lobe:clay  `@uvI`(sham 'aaa')
  =/  lobe2=lobe:clay  `@uvI`(sham 'bbb')
  =/  hist  (make-hist ~[[1 ~2024.1.1 lobe1 [/ %txt]] [2 ~2024.1.2 lobe2 [/ %txt]]])
  %+  expect-eq
    !>  [lobe2 [/ %txt]]
  !>  (resolve-case:nexus [%da ~2024.1.2] hist)
::
++  test-resolve-case-da-between
  ::  %da falls back to nearest previous date
  =/  lobe1=lobe:clay  `@uvI`(sham 'aaa')
  =/  lobe2=lobe:clay  `@uvI`(sham 'bbb')
  =/  lobe3=lobe:clay  `@uvI`(sham 'ccc')
  =/  hist  (make-hist ~[[1 ~2024.1.1 lobe1 [/ %txt]] [2 ~2024.3.1 lobe2 [/ %txt]] [3 ~2024.6.1 lobe3 [/ %txt]]])
  ::  Date between entry 1 and 2 should return lobe1
  %+  expect-eq
    !>  [lobe1 [/ %txt]]
  !>  (resolve-case:nexus [%da ~2024.2.1] hist)
::
++  test-resolve-case-da-after-all
  ::  %da after all entries returns latest
  =/  lobe1=lobe:clay  `@uvI`(sham 'aaa')
  =/  lobe2=lobe:clay  `@uvI`(sham 'bbb')
  =/  hist  (make-hist ~[[1 ~2024.1.1 lobe1 [/ %txt]] [2 ~2024.3.1 lobe2 [/ %txt]]])
  %+  expect-eq
    !>  [lobe2 [/ %txt]]
  !>  (resolve-case:nexus [%da ~2025.1.1] hist)
::
++  test-resolve-case-da-before-all
  ::  %da before all entries crashes
  =/  lobe1=lobe:clay  `@uvI`(sham 'aaa')
  =/  hist  (make-hist ~[[1 ~2024.6.1 lobe1 [/ %txt]]])
  =/  res=(each [lobe:clay blot:tarball] tang)
    (mule |.((resolve-case:nexus [%da ~2024.1.1] hist)))
  %+  expect-eq
    !>  %.y
  !>  ?=(%| -.res)
::
++  test-resolve-case-da-empty
  ::  %da on empty hist crashes
  =/  hist=((mop cass:clay ,[lobe:clay blot:tarball]) cor:nexus)  ~
  =/  res=(each [lobe:clay blot:tarball] tang)
    (mule |.((resolve-case:nexus [%da ~2024.1.1] hist)))
  %+  expect-eq
    !>  %.y
  !>  ?=(%| -.res)
::
++  test-resolve-case-ud-empty
  ::  %ud on empty hist crashes
  =/  hist=((mop cass:clay ,[lobe:clay blot:tarball]) cor:nexus)  ~
  =/  res=(each [lobe:clay blot:tarball] tang)
    (mule |.((resolve-case:nexus [%ud 1] hist)))
  %+  expect-eq
    !>  %.y
  !>  ?=(%| -.res)
::
::  ==========================================
::  +record-trees tests
::  ==========================================
::
::  Helper: get node from born at path
::
++  get-node
  |=  [=born:nexus dir=path]
  ^-  (unit [=tote:nexus bags=(map @ta sack:nexus)])
  =/  sub=born:nexus  (~(dip of born) dir)
  fil.sub
::
::  Helper: build a born with a single grub that has a hist entry
::
++  make-grub-born
  |=  [dir=path name=@ta =lobe:clay =blot:tarball file-cass=cass:clay]
  ^-  born:nexus
  =/  hist=((mop cass:clay ,[lobe:clay blot:tarball]) cor:nexus)
    (put:on-hist:sack:nexus ~ file-cass [lobe blot])
  =/  sok=sack:nexus  [[0 ~2024.1.1] [0 ~2024.1.1] file-cass hist]
  =/  node=[tote:nexus (map @ta sack:nexus)]
    [[[0 ~2024.1.1] ~] (~(put by *(map @ta sack:nexus)) name sok)]
  (~(put of *born:nexus) dir node)
::
++  test-record-trees-single-file
  ::  record-trees creates a tree with the grub's lobe in fil
  =/  now=@da  ~2024.1.1
  =/  =lobe:clay  `@uvI`(sham 'hello')
  =/  =blot:tarball  [/ %txt]
  =/  =born:nexus  (make-grub-born / %myfile lobe blot [1 now])
  =/  [new-born=born:nexus new-silo=silo:nexus]
    (record-trees:nexus born *silo:nexus *sand:nexus *ball:tarball now /)
  ::  Fold should have bumped
  =/  node  (need (get-node new-born /))
  ;:  weld
    %+  expect-eq  !>(`@ud`1)  !>(ud.fold.tote.node)
  ::  Tree should be in silo
    %+  expect-eq  !>(`@ud`1)  !>(~(wyt by trees.new-silo))
  ::  Tree's fil should have our grub's lobe
    =/  tree-lobe=lobe:clay
      (need (get:on-hist:tote:nexus hist.tote.node fold.tote.node))
    =/  tree-entry  (~(got by trees.new-silo) tree-lobe)
    %+  expect-eq
      !>  `(unit [lobe:clay blot:tarball])``[lobe blot]
    !>  (~(get by fil.tree.tree-entry) %myfile)
  ==
::
++  test-record-trees-no-change-no-bump
  ::  Calling record-trees twice with no changes doesn't bump fold
  =/  now=@da  ~2024.1.1
  =/  =lobe:clay  `@uvI`(sham 'hello')
  =/  =born:nexus  (make-grub-born / %myfile lobe [/ %txt] [1 now])
  =/  [born1=born:nexus silo1=silo:nexus]
    (record-trees:nexus born *silo:nexus *sand:nexus *ball:tarball now /)
  ::  Call again — nothing changed
  =/  [born2=born:nexus silo2=silo:nexus]
    (record-trees:nexus born1 silo1 *sand:nexus *ball:tarball now /)
  ::  Fold should still be 1, not 2
  =/  node  (need (get-node born2 /))
  ;:  weld
    %+  expect-eq  !>(`@ud`1)  !>(ud.fold.tote.node)
  ::  Still only 1 tree in silo (not duplicated)
    %+  expect-eq  !>(`@ud`1)  !>(~(wyt by trees.silo2))
  ==
::
++  test-record-trees-change-bumps-fold
  ::  Changing a grub's hist then re-recording bumps fold
  =/  now=@da  ~2024.1.1
  =/  lobe1=lobe:clay  `@uvI`(sham 'first')
  =/  =born:nexus  (make-grub-born / %myfile lobe1 [/ %txt] [1 now])
  =/  [born1=born:nexus silo1=silo:nexus]
    (record-trees:nexus born *silo:nexus *sand:nexus *ball:tarball now /)
  ::  Simulate file change: update hist with new lobe at new cass
  =/  lobe2=lobe:clay  `@uvI`(sham 'second')
  =/  new-cass=cass:clay  [2 ~2024.1.2]
  =/  born1-node  (need (get-node born1 /))
  =/  sok=sack:nexus  (~(got by bags.born1-node) %myfile)
  =/  new-hist=((mop cass:clay ,[lobe:clay blot:tarball]) cor:nexus)
    (put:on-hist:sack:nexus hist.sok new-cass [lobe2 [/ %txt]])
  =/  born2=born:nexus
    (~(put of born1) / born1-node(bags (~(put by bags.born1-node) %myfile sok(file new-cass, hist new-hist))))
  =/  [born3=born:nexus silo2=silo:nexus]
    (record-trees:nexus born2 silo1 *sand:nexus *ball:tarball now /)
  ::  Fold should now be 2
  =/  node  (need (get-node born3 /))
  ;:  weld
    %+  expect-eq  !>(`@ud`2)  !>(ud.fold.tote.node)
  ::  2 trees in silo (old and new)
    %+  expect-eq  !>(`@ud`2)  !>(~(wyt by trees.silo2))
  ==
::
++  test-record-trees-propagates-to-parent
  ::  record-trees at /a propagates tree to root /
  =/  now=@da  ~2024.1.1
  =/  =lobe:clay  `@uvI`(sham 'hello')
  =/  =born:nexus  (make-grub-born /a %myfile lobe [/ %txt] [1 now])
  =/  [new-born=born:nexus new-silo=silo:nexus]
    (record-trees:nexus born *silo:nexus *sand:nexus *ball:tarball now /a)
  ::  /a should have fold=1
  =/  a-node  (need (get-node new-born /a))
  ::  / should also have fold=1 (parent got a tree too)
  =/  root-node  (need (get-node new-born /))
  ;:  weld
    %+  expect-eq  !>(`@ud`1)  !>(ud.fold.tote.a-node)
    %+  expect-eq  !>(`@ud`1)  !>(ud.fold.tote.root-node)
  ::  Root's tree should have /a's tree lobe in its dir map
    =/  root-tree-lobe=lobe:clay
      (need (get:on-hist:tote:nexus hist.tote.root-node fold.tote.root-node))
    =/  root-tree  tree:(~(got by trees.new-silo) root-tree-lobe)
    =/  a-tree-lobe=lobe:clay
      (need (get:on-hist:tote:nexus hist.tote.a-node fold.tote.a-node))
    %+  expect-eq
      !>  a-tree-lobe
    !>  lobe:(~(got by dir.root-tree) %a)
  ==
::
++  test-record-trees-weir-in-tree
  ::  record-trees captures weir from sand in tree's dir map
  =/  now=@da  ~2024.1.1
  =/  =lobe:clay  `@uvI`(sham 'hello')
  =/  =born:nexus  (make-grub-born /a %myfile lobe [/ %txt] [1 now])
  ::  Set up sand with a weir on /a
  =/  =weir:nexus  [make=~ poke=(sy ~[[%& [%| /a]]]) peek=~]
  =/  =sand:nexus  (~(put of *sand:nexus) /a weir)
  =/  [new-born=born:nexus new-silo=silo:nexus]
    (record-trees:nexus born *silo:nexus sand *ball:tarball now /)
  ::  Root's tree should have /a's weir
  =/  root-node  (need (get-node new-born /))
  =/  root-tree-lobe=lobe:clay
    (need (get:on-hist:tote:nexus hist.tote.root-node fold.tote.root-node))
  =/  root-tree  tree:(~(got by trees.new-silo) root-tree-lobe)
  %+  expect-eq
    !>  `weir:nexus`weir
  !>  (need weir:(~(got by dir.root-tree) %a))
::
::  Helper: add a grub to an existing born
::
++  add-grub
  |=  [=born:nexus dir=path name=@ta =lobe:clay =blot:tarball file-cass=cass:clay]
  ^-  born:nexus
  =/  hist=((mop cass:clay ,[lobe:clay blot:tarball]) cor:nexus)
    (put:on-hist:sack:nexus ~ file-cass [lobe blot])
  =/  sok=sack:nexus  [[0 ~2024.1.1] [0 ~2024.1.1] file-cass hist]
  =/  sub=born:nexus  (~(dip of born) dir)
  =/  node=[=tote:nexus bags=(map @ta sack:nexus)]
    (fall fil.sub [[[0 ~2024.1.1] ~] ~])
  (~(put of born) dir node(bags (~(put by bags.node) name sok)))
::
++  test-record-trees-multi-file
  ::  Tree captures multiple grubs in same dir
  =/  now=@da  ~2024.1.1
  =/  lobe1=lobe:clay  `@uvI`(sham 'aaa')
  =/  lobe2=lobe:clay  `@uvI`(sham 'bbb')
  =/  lobe3=lobe:clay  `@uvI`(sham 'ccc')
  =/  =born:nexus  (make-grub-born / %alpha lobe1 [/ %txt] [1 now])
  =.  born  (add-grub born / %beta lobe2 [/ %hoon] [1 now])
  =.  born  (add-grub born / %gamma lobe3 [/ %json] [1 now])
  =/  [new-born=born:nexus new-silo=silo:nexus]
    (record-trees:nexus born *silo:nexus *sand:nexus *ball:tarball now /)
  =/  node  (need (get-node new-born /))
  =/  tree-lobe=lobe:clay
    (need (get:on-hist:tote:nexus hist.tote.node fold.tote.node))
  =/  =tree:silo:nexus  tree:(~(got by trees.new-silo) tree-lobe)
  ;:  weld
    ::  All 3 grubs in tree's fil
    %+  expect-eq  !>(`@ud`3)  !>(~(wyt by fil.tree))
    %+  expect-eq
      !>  `(unit [lobe:clay blot:tarball])``[lobe1 [/ %txt]]
    !>  (~(get by fil.tree) %alpha)
    %+  expect-eq
      !>  `(unit [lobe:clay blot:tarball])``[lobe2 [/ %hoon]]
    !>  (~(get by fil.tree) %beta)
    %+  expect-eq
      !>  `(unit [lobe:clay blot:tarball])``[lobe3 [/ %json]]
    !>  (~(get by fil.tree) %gamma)
  ==
::
++  test-record-trees-mixed-files-and-dirs
  ::  Dir with both grubs and child directories
  =/  now=@da  ~2024.1.1
  =/  lobe1=lobe:clay  `@uvI`(sham 'root-file')
  =/  lobe2=lobe:clay  `@uvI`(sham 'child-file')
  ::  / has a grub, /sub has a grub
  =/  =born:nexus  (make-grub-born / %rootfile lobe1 [/ %txt] [1 now])
  =.  born  (add-grub born /sub %childfile lobe2 [/ %txt] [1 now])
  ::  Record from /sub up
  =/  [new-born=born:nexus new-silo=silo:nexus]
    (record-trees:nexus born *silo:nexus *sand:nexus *ball:tarball now /sub)
  =/  root-node  (need (get-node new-born /))
  =/  root-tree-lobe=lobe:clay
    (need (get:on-hist:tote:nexus hist.tote.root-node fold.tote.root-node))
  =/  root-tree  tree:(~(got by trees.new-silo) root-tree-lobe)
  ;:  weld
    ::  Root tree has the root grub in fil
    %+  expect-eq
      !>  `(unit [lobe:clay blot:tarball])``[lobe1 [/ %txt]]
    !>  (~(get by fil.root-tree) %rootfile)
    ::  Root tree has /sub in dir
    %+  expect-eq  !>(%.y)  !>((~(has by dir.root-tree) %sub))
    ::  /sub's tree has the child grub
    =/  sub-node  (need (get-node new-born /sub))
    =/  sub-tree-lobe=lobe:clay
      (need (get:on-hist:tote:nexus hist.tote.sub-node fold.tote.sub-node))
    =/  sub-tree  tree:(~(got by trees.new-silo) sub-tree-lobe)
    %+  expect-eq
      !>  `(unit [lobe:clay blot:tarball])``[lobe2 [/ %txt]]
    !>  (~(get by fil.sub-tree) %childfile)
  ==
::
::  ==========================================
::  +si tree store tests (put-tree, drop-tree, drop-tote-hist)
::  ==========================================
::
++  test-si-put-tree-new
  ::  Inserting a new tree returns lobe and silo with refs=1
  =/  s  ~(. si:nexus *silo:nexus)
  =/  =tree:silo:nexus  [~ ~ ~]
  =/  [=lobe:clay new-silo=silo:nexus]  (put-tree:s tree)
  ;:  weld
    %+  expect-eq
      !>  `@ud`1
    !>  refs:(~(got by trees.new-silo) lobe)
  ::
    %+  expect-eq
      !>  tree
    !>  tree:(~(got by trees.new-silo) lobe)
  ==
::
++  test-si-put-tree-duplicate-increments-refs
  ::  Inserting the same tree twice increments refcount
  =/  s  ~(. si:nexus *silo:nexus)
  =/  =tree:silo:nexus  [~ ~ ~]
  =/  [lobe1=lobe:clay silo1=silo:nexus]  (put-tree:s tree)
  =/  s2  ~(. si:nexus silo1)
  =/  [lobe2=lobe:clay silo2=silo:nexus]  (put-tree:s2 tree)
  ;:  weld
    %+  expect-eq  !>(lobe1)  !>(lobe2)
    %+  expect-eq  !>(`@ud`2)  !>(refs:(~(got by trees.silo2) lobe1))
  ==
::
++  test-si-put-tree-different-content-different-lobe
  ::  Different trees produce different lobes
  =/  s  ~(. si:nexus *silo:nexus)
  =/  tree1=tree:silo:nexus  [~ ~ ~]
  =/  tree2=tree:silo:nexus
    [~ (~(put by *(map @ta [lobe:clay blot:tarball])) %foo [`@uvI`(sham 'x') [/ %txt]]) ~]
  =/  [lobe1=lobe:clay silo1=silo:nexus]  (put-tree:s tree1)
  =/  s2  ~(. si:nexus silo1)
  =/  [lobe2=lobe:clay silo2=silo:nexus]  (put-tree:s2 tree2)
  ;:  weld
    %+  expect-eq  !>(%.n)  !>(=(lobe1 lobe2))
    %+  expect-eq  !>(`@ud`2)  !>(~(wyt by trees.silo2))
  ==
::
++  test-si-drop-tree-decrements-refs
  =/  s  ~(. si:nexus *silo:nexus)
  =/  =tree:silo:nexus  [~ ~ ~]
  =/  [=lobe:clay silo1=silo:nexus]  (put-tree:s tree)
  =/  s2  ~(. si:nexus silo1)
  =/  [* silo2=silo:nexus]  (put-tree:s2 tree)
  =/  s3  ~(. si:nexus silo2)
  =/  silo3=silo:nexus  (drop-tree:s3 lobe)
  %+  expect-eq  !>(`@ud`1)  !>(refs:(~(got by trees.silo3) lobe))
::
++  test-si-drop-tree-deletes-at-zero
  =/  s  ~(. si:nexus *silo:nexus)
  =/  =tree:silo:nexus  [~ ~ ~]
  =/  [=lobe:clay silo1=silo:nexus]  (put-tree:s tree)
  =/  s2  ~(. si:nexus silo1)
  =/  silo2=silo:nexus  (drop-tree:s2 lobe)
  %+  expect-eq  !>(~)  !>((~(get by trees.silo2) lobe))
::
++  test-si-drop-tree-missing-is-noop
  =/  s  ~(. si:nexus *silo:nexus)
  %+  expect-eq
    !>  *silo:nexus
  !>  (drop-tree:s `@uvI`(sham 'fake'))
::
++  test-si-drop-tote-hist-all-refs
  ::  drop-tote-hist removes all tree refs from silo
  =/  s  ~(. si:nexus *silo:nexus)
  =/  tree1=tree:silo:nexus  [~ ~ ~]
  =/  tree2=tree:silo:nexus
    [~ (~(put by *(map @ta [lobe:clay blot:tarball])) %a [`@uvI`(sham 'y') [/ %txt]]) ~]
  =/  [lobe1=lobe:clay silo1=silo:nexus]  (put-tree:s tree1)
  =/  s2  ~(. si:nexus silo1)
  =/  [lobe2=lobe:clay silo2=silo:nexus]  (put-tree:s2 tree2)
  =/  hist=((mop cass:clay lobe:clay) cor:nexus)
    %-  put:on-hist:tote:nexus
    [(put:on-hist:tote:nexus ~ [1 ~2024.1.1] lobe1) [2 ~2024.1.2] lobe2]
  =/  silo3=silo:nexus  (~(drop-tote-hist si:nexus silo2) hist)
  %+  expect-eq  !>(`@ud`0)  !>(~(wyt by trees.silo3))
--
