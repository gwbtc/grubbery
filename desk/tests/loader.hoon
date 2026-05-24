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
  [[/ %txt] !>(txt)]
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
::  ==========================================
::  put-ball tests
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
::  ==========================================
::  spin: %over %& — always overwrite file
::  ==========================================
::
++  test-over-file-into-empty
  ::  over file into empty ball places file
  =/  old  *ball:tarball
  =/  rows=(list row:loader)
    ~[[%over %& [/a %foo] (mk-content 'hello')]]
  =/  =ball:tarball  (spin:loader old rows)
  %+  expect-eq
    !>  `(mk-content 'hello')
  !>  (~(get ba:tarball ball) /a %foo)
::
++  test-over-file-replaces
  ::  over file replaces existing content
  =/  old=ball:tarball
    (~(put ba:tarball *ball:tarball) [/a %foo] (mk-content 'old'))
  =/  rows=(list row:loader)
    ~[[%over %& [/a %foo] (mk-content 'new')]]
  =/  =ball:tarball  (spin:loader old rows)
  %+  expect-eq
    !>  `(mk-content 'new')
  !>  (~(get ba:tarball ball) /a %foo)
::
::  ==========================================
::  spin: %over %| — always overwrite directory
::  ==========================================
::
++  test-over-dir-into-empty
  ::  over dir places ball at path
  =/  child-ball=ball:tarball  (mk-ball-1 %foo 'hi')
  =/  old  *ball:tarball
  =/  rows=(list row:loader)
    ~[[%over %| /sub child-ball]]
  =/  =ball:tarball  (spin:loader old rows)
  =/  got  (~(get ba:tarball ball) /sub %foo)
  %+  expect-eq
    !>  `(mk-content 'hi')
  !>  got
::
::  ==========================================
::  spin: %fall %& — keep existing, else default
::  ==========================================
::
++  test-fall-file-uses-default
  ::  fall file with no existing uses default content
  =/  old  *ball:tarball
  =/  rows=(list row:loader)
    ~[[%fall %& [/a %foo] (mk-content 'default')]]
  =/  =ball:tarball  (spin:loader old rows)
  =/  got  (~(get ba:tarball ball) /a %foo)
  %+  expect-eq
    !>  `(mk-content 'default')
  !>  got
::
++  test-fall-file-keeps-existing
  ::  fall file with existing keeps old content
  =/  old=ball:tarball
    (~(put ba:tarball *ball:tarball) [/a %foo] (mk-content 'existing'))
  =/  rows=(list row:loader)
    ~[[%fall %& [/a %foo] (mk-content 'default')]]
  =/  =ball:tarball  (spin:loader old rows)
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
  ::  fall dir with no existing uses default ball
  =/  child-ball=ball:tarball  (mk-ball-1 %foo 'default')
  =/  old  *ball:tarball
  =/  rows=(list row:loader)
    ~[[%fall %| /sub child-ball]]
  =/  =ball:tarball  (spin:loader old rows)
  =/  got  (~(get ba:tarball ball) /sub %foo)
  %+  expect-eq
    !>  `(mk-content 'default')
  !>  got
::
++  test-fall-dir-keeps-existing
  ::  fall dir with existing keeps old ball
  =/  old-sub-ball=ball:tarball  (mk-ball-1 %foo 'existing')
  =/  old=ball:tarball  (put-ball:loader *ball:tarball /sub old-sub-ball)
  ::  provide different defaults
  =/  def-ball=ball:tarball  (mk-ball-1 %foo 'default')
  =/  rows=(list row:loader)
    ~[[%fall %| /sub def-ball]]
  =/  =ball:tarball  (spin:loader old rows)
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
  =/  old=ball:tarball
    (~(put ba:tarball *ball:tarball) [/old %data] (mk-content 'raw'))
  =/  my-load=file-load:loader
    |=  ct=content:tarball
    ct
  =/  rows=(list row:loader)
    ~[[%load %& [/old %data] [/new %data] my-load]]
  =/  =ball:tarball  (spin:loader old rows)
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
  =/  old  *ball:tarball
  =/  my-load=file-load:loader
    |=  ct=content:tarball
    (mk-content 'fallback')
  =/  rows=(list row:loader)
    ~[[%load %& [/nope %gone] [/new %file] my-load]]
  =/  =ball:tarball  (spin:loader old rows)
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
  =/  old=ball:tarball  (put-ball:loader *ball:tarball /src old-sub-ball)
  =/  my-fold=fold-load:loader
    |=  bl=ball:tarball
    bl
  =/  rows=(list row:loader)
    ~[[%load %| /src /dst my-fold]]
  =/  =ball:tarball  (spin:loader old rows)
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
  =/  old=ball:tarball
    =/  b  (~(put ba:tarball *ball:tarball) [/a %keep] (mk-content 'keep'))
    (~(put ba:tarball b) [/a %drop] (mk-content 'drop'))
  ::  only mention %keep
  =/  rows=(list row:loader)
    ~[[%fall %& [/a %keep] (mk-content 'default')]]
  =/  =ball:tarball  (spin:loader old rows)
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
  =/  old  *ball:tarball
  =/  rows=(list row:loader)
    :~  [%over %& [/a %one] (mk-content 'first')]
        [%over %& [/a %two] (mk-content 'second')]
        [%over %& [/b %three] (mk-content 'third')]
    ==
  =/  =ball:tarball  (spin:loader old rows)
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
  =/  old=ball:tarball
    (~(put ba:tarball *ball:tarball) [/a %foo] (mk-content 'bye'))
  =/  =ball:tarball  (spin:loader old ~)
  %+  expect-eq  !>(*ball:tarball)  !>(ball)
::
::  ==========================================
::  spin vs imperative: server on-load scenario
::  ==========================================
::
++  test-server-scenario-imperative
  ::  simulate server on-load imperative style on existing ball
  =/  server-ct=content:tarball  [[/ %server-state] !>('state-data')]
  =/  old-ball=ball:tarball
    =/  b  (~(put ba:tarball *ball:tarball) [/ %'ver.ud'] [[/ %ud] !>(0)])
    (~(put ba:tarball b) [/ %'main.server-state'] server-ct)
  =/  ball=ball:tarball  old-ball
  =.  ball  (~(put ba:tarball ball) [/ %'ver.ud'] [[/ %ud] !>(0)])
  =/  existing  (~(get ba:tarball ball) [/ %'main.server-state'])
  =?  ball  =(~ existing)
    (~(put ba:tarball ball) [/ %'main.server-state'] [[/ %server-state] !>('fresh')])
  %+  expect-eq
    !>  `server-ct
  !>  (~(get ba:tarball ball) [/ %'main.server-state'])
::
++  test-server-scenario-spin
  ::  simulate server on-load with spin on existing ball
  =/  server-ct=content:tarball  [[/ %server-state] !>('state-data')]
  =/  old-ball=ball:tarball
    =/  b  (~(put ba:tarball *ball:tarball) [/ %'ver.ud'] [[/ %ud] !>(0)])
    (~(put ba:tarball b) [/ %'main.server-state'] server-ct)
  =/  =ball:tarball
    %+  spin:loader  old-ball
    :~  [%over %& [/ %'ver.ud'] [[/ %ud] !>(0)]]
        [%fall %& [/ %'main.server-state'] [[/ %server-state] !>('fresh')]]
    ==
  ;:  weld
    ::  ball content is correct
    %+  expect-eq
      !>  `server-ct
    !>  (~(get ba:tarball ball) [/ %'main.server-state'])
    %+  expect-eq
      !>  `[[/ %ud] !>(0)]
    !>  (~(get ba:tarball ball) [/ %'ver.ud'])
  ==
--
