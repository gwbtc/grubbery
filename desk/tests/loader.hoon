::  tests for lib/loader
::
/+  *test, tarball, nexus, loader
|%
::  ==========================================
::  Helpers
::  ==========================================
::
++  mk-content
  |=  txt=@t
  ^-  content:tarball
  [~ [/ %txt] !>(txt)]
::
++  mk-ball-1
  ::  ball with one file at root
  |=  [name=@ta txt=@t]
  ^-  ball:tarball
  =/  contents=(map @ta content:tarball)
    (~(put by *(map @ta content:tarball)) name (mk-content txt))
  [`[~ ~ contents] ~]
::
++  mk-ball-2
  ::  ball with two files at root
  |=  [n1=@ta t1=@t n2=@ta t2=@t]
  ^-  ball:tarball
  =/  contents=(map @ta content:tarball)
    %-  ~(gas by *(map @ta content:tarball))
    ~[[n1 (mk-content t1)] [n2 (mk-content t2)]]
  [`[~ ~ contents] ~]
::
++  mk-sand-1
  ::  sand with a weir at root
  |=  =weir:nexus
  ^-  sand:nexus
  [`weir ~]
::
::  ==========================================
::  put-sand / put-ball tests
::  ==========================================
::
++  test-put-ball-root
  ::  put-ball at / replaces the ball
  =/  parent=ball:tarball  *ball:tarball
  =/  child=ball:tarball  (mk-ball-1 %foo 'hi')
  =/  result  (put-ball:loader parent / child)
  %+  expect-eq
    !>  child
  !>  result
::
++  test-put-ball-nested
  ::  put-ball at /sub places child in subdir
  =/  parent=ball:tarball  *ball:tarball
  =/  child=ball:tarball  (mk-ball-1 %foo 'hi')
  =/  result  (put-ball:loader parent /sub child)
  =/  got  (~(get ba:tarball result) /sub %foo)
  %+  expect-eq
    !>  `(mk-content 'hi')
  !>  got
::
++  test-put-sand-root
  ::  put-sand at / replaces the sand
  =/  parent=sand:nexus  *sand:nexus
  =/  =weir:nexus  [make=~ poke=~ peek=~]
  =/  child=sand:nexus  (mk-sand-1 weir)
  =/  result  (put-sand:loader parent / child)
  %+  expect-eq
    !>  child
  !>  result
::
++  test-put-sand-nested
  ::  put-sand at /sub places child in subdir
  =/  parent=sand:nexus  *sand:nexus
  =/  =weir:nexus  [make=~ poke=~ peek=~]
  =/  child=sand:nexus  (mk-sand-1 weir)
  =/  result  (put-sand:loader parent /sub child)
  =/  sub  (~(dip of result) /sub)
  %+  expect-eq
    !>  child
  !>  sub
::
::  ==========================================
::  spin: %over %& — always overwrite file
::  ==========================================
::
++  test-over-file-into-empty
  ::  over file into empty ball places file
  =/  old  [*sand:nexus *ball:tarball]
  =/  rows=(list row:loader)
    ~[[%over %& [/a %foo] (mk-content 'hello')]]
  =/  [=sand:nexus =ball:tarball]  (spin:loader old rows)
  %+  expect-eq
    !>  `(mk-content 'hello')
  !>  (~(get ba:tarball ball) /a %foo)
::
++  test-over-file-replaces
  ::  over file replaces existing content
  =/  old-ball=ball:tarball  (~(put ba:tarball *ball:tarball) [/a %foo] (mk-content 'old'))
  =/  old  [*sand:nexus old-ball]
  =/  rows=(list row:loader)
    ~[[%over %& [/a %foo] (mk-content 'new')]]
  =/  [=sand:nexus =ball:tarball]  (spin:loader old rows)
  %+  expect-eq
    !>  `(mk-content 'new')
  !>  (~(get ba:tarball ball) /a %foo)
::
::  ==========================================
::  spin: %over %| — always overwrite directory
::  ==========================================
::
++  test-over-dir-into-empty
  ::  over dir places sand and ball at path
  =/  =weir:nexus  [make=~ poke=~ peek=~]
  =/  child-sand=sand:nexus  (mk-sand-1 weir)
  =/  child-ball=ball:tarball  (mk-ball-1 %foo 'hi')
  =/  old  [*sand:nexus *ball:tarball]
  =/  rows=(list row:loader)
    ~[[%over %| /sub child-sand child-ball]]
  =/  [=sand:nexus =ball:tarball]  (spin:loader old rows)
  =/  got  (~(get ba:tarball ball) /sub %foo)
  ;:  weld
    %+  expect-eq
      !>  `(mk-content 'hi')
    !>  got
    %+  expect-eq
      !>  child-sand
    !>  (~(dip of sand) /sub)
  ==
::
::  ==========================================
::  spin: %fall %& — keep existing, else default
::  ==========================================
::
++  test-fall-file-uses-default
  ::  fall file with no existing uses default content
  =/  old  [*sand:nexus *ball:tarball]
  =/  rows=(list row:loader)
    ~[[%fall %& [/a %foo] (mk-content 'default')]]
  =/  [=sand:nexus =ball:tarball]  (spin:loader old rows)
  =/  got  (~(get ba:tarball ball) /a %foo)
  %+  expect-eq
    !>  `(mk-content 'default')
  !>  got
::
++  test-fall-file-keeps-existing
  ::  fall file with existing keeps old content
  =/  old-ball=ball:tarball
    (~(put ba:tarball *ball:tarball) [/a %foo] (mk-content 'existing'))
  =/  old  [*sand:nexus old-ball]
  =/  rows=(list row:loader)
    ~[[%fall %& [/a %foo] (mk-content 'default')]]
  =/  [=sand:nexus =ball:tarball]  (spin:loader old rows)
  =/  got  (~(get ba:tarball ball) /a %foo)
  %+  expect-eq
    !>  `(mk-content 'existing')
  !>  got
::
::  ==========================================
::  spin: %fall %| — keep existing dir, else default
::  ==========================================
::
++  test-fall-dir-uses-default
  ::  fall dir with no existing uses default sand/ball
  =/  child-sand=sand:nexus  *sand:nexus
  =/  child-ball=ball:tarball  (mk-ball-1 %foo 'default')
  =/  old  [*sand:nexus *ball:tarball]
  =/  rows=(list row:loader)
    ~[[%fall %| /sub child-sand child-ball]]
  =/  [=sand:nexus =ball:tarball]  (spin:loader old rows)
  =/  got  (~(get ba:tarball ball) /sub %foo)
  %+  expect-eq
    !>  `(mk-content 'default')
  !>  got
::
++  test-fall-dir-keeps-existing
  ::  fall dir with existing keeps old ball (and old sand)
  =/  old-sub-ball=ball:tarball  (mk-ball-1 %foo 'existing')
  =/  old-ball=ball:tarball  (put-ball:loader *ball:tarball /sub old-sub-ball)
  =/  old-sub-sand=sand:nexus  *sand:nexus
  =/  old-sand=sand:nexus  (put-sand:loader *sand:nexus /sub old-sub-sand)
  =/  old  [old-sand old-ball]
  ::  provide different defaults
  =/  def-ball=ball:tarball  (mk-ball-1 %foo 'default')
  =/  rows=(list row:loader)
    ~[[%fall %| /sub *sand:nexus def-ball]]
  =/  [=sand:nexus =ball:tarball]  (spin:loader old rows)
  =/  got  (~(get ba:tarball ball) /sub %foo)
  ::  should get old content, not default
  %+  expect-eq
    !>  `(mk-content 'existing')
  !>  got
::
::  ==========================================
::  spin: %load %& — file migration
::  ==========================================
::
++  test-load-file-transforms
  ::  load file extracts old content, runs transform, places at new rail
  =/  old-ball=ball:tarball
    (~(put ba:tarball *ball:tarball) [/old %data] (mk-content 'raw'))
  =/  old  [*sand:nexus old-ball]
  =/  my-load=file-load:loader
    |=  ct=content:tarball
    ct
  =/  rows=(list row:loader)
    ~[[%load %& [/old %data] [/new %data] my-load]]
  =/  [=sand:nexus =ball:tarball]  (spin:loader old rows)
  ;:  weld
    ::  old location should NOT be in new ball (unspecified = dropped)
    %+  expect-eq
      !>  ~
    !>  (~(get ba:tarball ball) /old %data)
    ::  new location has the content
    %+  expect-eq
      !>  `(mk-content 'raw')
    !>  (~(get ba:tarball ball) /new %data)
  ==
::
++  test-load-file-missing-uses-bunt
  ::  load file with missing source uses bunt content
  =/  old  [*sand:nexus *ball:tarball]
  =/  my-load=file-load:loader
    |=  ct=content:tarball
    (mk-content 'fallback')
  =/  rows=(list row:loader)
    ~[[%load %& [/nope %gone] [/new %file] my-load]]
  =/  [=sand:nexus =ball:tarball]  (spin:loader old rows)
  %+  expect-eq
    !>  `(mk-content 'fallback')
  !>  (~(get ba:tarball ball) /new %file)
::
::  ==========================================
::  spin: %load %| — directory migration
::  ==========================================
::
++  test-load-dir-transforms
  ::  load dir extracts old subtree, runs transform, places at new path
  =/  old-sub-ball=ball:tarball  (mk-ball-1 %foo 'original')
  =/  old-ball=ball:tarball  (put-ball:loader *ball:tarball /src old-sub-ball)
  =/  old  [*sand:nexus old-ball]
  =/  my-fold=fold-load:loader
    |=  [sd=sand:nexus bl=ball:tarball]
    [sd bl]
  =/  rows=(list row:loader)
    ~[[%load %| /src /dst my-fold]]
  =/  [=sand:nexus =ball:tarball]  (spin:loader old rows)
  ;:  weld
    ::  old location not in new
    %+  expect-eq
      !>  ~
    !>  (~(get ba:tarball ball) /src %foo)
    ::  new location has the content
    %+  expect-eq
      !>  `(mk-content 'original')
    !>  (~(get ba:tarball ball) /dst %foo)
  ==
::
::  ==========================================
::  spin: unspecified paths are dropped
::  ==========================================
::
++  test-unspecified-dropped
  ::  files not mentioned in rows are not carried over
  =/  old-ball=ball:tarball
    =/  b  (~(put ba:tarball *ball:tarball) [/a %keep] (mk-content 'keep'))
    (~(put ba:tarball b) [/a %drop] (mk-content 'drop'))
  =/  old  [*sand:nexus old-ball]
  ::  only mention %keep
  =/  rows=(list row:loader)
    ~[[%fall %& [/a %keep] (mk-content 'default')]]
  =/  [=sand:nexus =ball:tarball]  (spin:loader old rows)
  ;:  weld
    ::  keep is present (kept from old)
    %+  expect-eq
      !>  `(mk-content 'keep')
    !>  (~(get ba:tarball ball) /a %keep)
    ::  drop is gone
    %+  expect-eq
      !>  ~
    !>  (~(get ba:tarball ball) /a %drop)
  ==
::
::  ==========================================
::  spin: multiple rows compose
::  ==========================================
::
++  test-multiple-rows
  ::  multiple rows build up the new state incrementally
  =/  old  [*sand:nexus *ball:tarball]
  =/  rows=(list row:loader)
    :~  [%over %& [/a %one] (mk-content 'first')]
        [%over %& [/a %two] (mk-content 'second')]
        [%over %& [/b %three] (mk-content 'third')]
    ==
  =/  [=sand:nexus =ball:tarball]  (spin:loader old rows)
  ;:  weld
    %+  expect-eq
      !>  `(mk-content 'first')
    !>  (~(get ba:tarball ball) /a %one)
    %+  expect-eq
      !>  `(mk-content 'second')
    !>  (~(get ba:tarball ball) /a %two)
    %+  expect-eq
      !>  `(mk-content 'third')
    !>  (~(get ba:tarball ball) /b %three)
  ==
::
::  ==========================================
::  spin: empty rows produce empty state
::  ==========================================
::
++  test-empty-rows
  ::  no rows = everything dropped
  =/  old-ball=ball:tarball
    (~(put ba:tarball *ball:tarball) [/a %foo] (mk-content 'bye'))
  =/  old  [*sand:nexus old-ball]
  =/  [=sand:nexus =ball:tarball]  (spin:loader old ~)
  ;:  weld
    %+  expect-eq  !>(*sand:nexus)  !>(sand)
    %+  expect-eq  !>(*ball:tarball)  !>(ball)
  ==
::
::  ==========================================
::  spin: root sand behavior
::  ==========================================
::
++  test-spin-zeros-root-sand
  ::  spin starts with empty sand — old root sand is NOT preserved
  =/  =weir:nexus  [make=~ poke=(sy ~[[%& [%| /]]]) peek=~]
  =/  old-sand=sand:nexus  [`weir ~]
  =/  old  [old-sand *ball:tarball]
  =/  rows=(list row:loader)
    ~[[%over %& [/ %foo] (mk-content 'x')]]
  =/  [=sand:nexus =ball:tarball]  (spin:loader old rows)
  ::  root sand is wiped — this is the current behavior
  %+  expect-eq
    !>  `(unit weir:nexus)`~
  !>  fil.sand
::
::  ==========================================
::  spin vs imperative: server on-load scenario
::  ==========================================
::
++  test-server-scenario-imperative
  ::  simulate server on-load imperative style on existing ball
  =/  server-ct=content:tarball  [~ [/ %server-state] !>('state-data')]
  =/  old-ball=ball:tarball
    =/  b  (~(put ba:tarball *ball:tarball) [/ %'ver.ud'] [~ [/ %ud] !>(0)])
    (~(put ba:tarball b) [/ %'main.server-state'] server-ct)
  =/  old-sand=sand:nexus  [`[make=~ poke=(sy ~[[%& [%| /]]]) peek=~] ~]
  =/  ball=ball:tarball  old-ball
  =.  ball  (~(put ba:tarball ball) [/ %'ver.ud'] [~ [/ %ud] !>(0)])
  =/  existing  (~(get ba:tarball ball) [/ %'main.server-state'])
  =?  ball  =(~ existing)
    (~(put ba:tarball ball) [/ %'main.server-state'] [~ [/ %server-state] !>('fresh')])
  ;:  weld
    %+  expect-eq
      !>  old-sand
    !>  old-sand
    %+  expect-eq
      !>  `server-ct
    !>  (~(get ba:tarball ball) [/ %'main.server-state'])
  ==
::
++  test-server-scenario-spin
  ::  simulate server on-load with spin on existing ball
  =/  server-ct=content:tarball  [~ [/ %server-state] !>('state-data')]
  =/  old-ball=ball:tarball
    =/  b  (~(put ba:tarball *ball:tarball) [/ %'ver.ud'] [~ [/ %ud] !>(0)])
    (~(put ba:tarball b) [/ %'main.server-state'] server-ct)
  =/  old-sand=sand:nexus  [`[make=~ poke=(sy ~[[%& [%| /]]]) peek=~] ~]
  =/  [=sand:nexus =ball:tarball]
    %+  spin:loader  [old-sand old-ball]
    :~  [%over %& [/ %'ver.ud'] [~ [/ %ud] !>(0)]]
        [%fall %& [/ %'main.server-state'] [~ [/ %server-state] !>('fresh')]]
    ==
  ;:  weld
    ::  ball content is correct
    %+  expect-eq
      !>  `server-ct
    !>  (~(get ba:tarball ball) [/ %'main.server-state'])
    ::  BUT: root sand is zeroed out — NOT preserved
    %+  expect-eq
      !>  `(unit weir:nexus)`~
    !>  fil.sand
  ==
::
::  ==========================================
::  get-ver tests
::  ==========================================
::
++  test-get-ver-empty-ball
  ::  empty ball returns ~ (no version)
  %+  expect-eq
    !>  `ver:loader`~
  !>  (get-ver:loader *ball:tarball)
::
++  test-get-ver-no-version-file
  ::  ball with data but no ver.ud returns ~ (same as fresh)
  =/  =ball:tarball
    (~(put ba:tarball *ball:tarball) [/ %foo] (mk-content 'data'))
  %+  expect-eq
    !>  `ver:loader`~
  !>  (get-ver:loader ball)
::
++  test-get-ver-empty-lump-no-version
  ::  ball with empty lump but no ver.ud returns ~ (framework init case)
  =/  =ball:tarball  [`[~ ~ ~] ~]
  %+  expect-eq
    !>  `ver:loader`~
  !>  (get-ver:loader ball)
::
++  test-get-ver-has-version
  ::  ball with ver.ud returns [~ n]
  =/  =ball:tarball
    (~(put ba:tarball *ball:tarball) [/ %'ver.ud'] [~ [/ %ud] !>(5)])
  %+  expect-eq
    !>  `ver:loader``5
  !>  (get-ver:loader ball)
::
++  test-ver-row-produces-over
  ::  ver-row creates an %over row for ver.ud
  =/  =row:loader  (ver-row:loader 3)
  %+  expect-eq
    !>  %.y
  !>  ?=([%over %& [~ %'ver.ud'] *] row)
--
