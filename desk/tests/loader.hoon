::  tests for lib/loader
::
/+  *test, tarball, nexus, loader
|%
::  ==========================================
::  Helpers
::  ==========================================
::
++  mk-bask
  |=  txt=@t
  ^-  bask:tarball
  [[/ %txt] txt]
::
++  mk-content
  |=  txt=@t
  ^-  sang:tarball
  [[/ %txt] %& !>(txt)]
::
++  mk-bole-1
  ::  bole with one file at root
  |=  [name=@ta txt=@t]
  ^-  bole:tarball
  =/  contents=(map @ta [=bask:tarball gain=?])
    (~(put by *(map @ta [=bask:tarball gain=?])) name [(mk-bask txt) %.n])
  [`[~ ~ %.n contents] ~]
::
++  mk-ball-1
  ::  ball with one file at root
  |=  [name=@ta txt=@t]
  ^-  ball:tarball
  =/  contents=(map @ta [=sang:tarball gain=? bang=(unit tang)])
    (~(put by *(map @ta [=sang:tarball gain=? bang=(unit tang)])) name [(mk-content txt) %.n ~])
  [`[~ ~ %.n ~ contents] ~]
::
::
::  ==========================================
::  put-bole tests
::  ==========================================
::
++  test-put-bole-root
  ::  put-bole at / replaces the bole
  =/  parent=bole:tarball  *bole:tarball
  =/  child=bole:tarball  (mk-bole-1 %foo 'hi')
  =/  result  (put-bole:loader parent / child)
  %+  expect-eq
    !>  child
  !>  result
::
++  test-put-bole-nested
  ::  put-bole at /sub places child in subdir
  =/  parent=bole:tarball  *bole:tarball
  =/  child=bole:tarball  (mk-bole-1 %foo 'hi')
  =/  result  (put-bole:loader parent /sub child)
  =/  got  (~(get bo:tarball result) /sub %foo)
  %+  expect-eq
    !>  `(mk-bask 'hi')
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
    ~[[%over %& [/a %foo] (mk-bask 'hello')]]
  =/  =bole:tarball  (spin:loader old rows)
  %+  expect-eq
    !>  `(mk-bask 'hello')
  !>  (~(get bo:tarball bole) /a %foo)
::
++  test-over-file-replaces
  ::  over file replaces existing content
  =/  old=ball:tarball
    (~(put ba:tarball *ball:tarball) [/a %foo] (mk-content 'old'))
  =/  rows=(list row:loader)
    ~[[%over %& [/a %foo] (mk-bask 'new')]]
  =/  =bole:tarball  (spin:loader old rows)
  %+  expect-eq
    !>  `(mk-bask 'new')
  !>  (~(get bo:tarball bole) /a %foo)
::
::  ==========================================
::  spin: %over %| — always overwrite directory
::  ==========================================
::
++  test-over-dir-into-empty
  ::  over dir places bole at path
  =/  child-bole=bole:tarball  (mk-bole-1 %foo 'hi')
  =/  old  *ball:tarball
  =/  rows=(list row:loader)
    ~[[%over %| /sub child-bole]]
  =/  =bole:tarball  (spin:loader old rows)
  =/  got  (~(get bo:tarball bole) /sub %foo)
  %+  expect-eq
    !>  `(mk-bask 'hi')
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
    ~[[%fall %& [/a %foo] (mk-bask 'default')]]
  =/  =bole:tarball  (spin:loader old rows)
  =/  got  (~(get bo:tarball bole) /a %foo)
  %+  expect-eq
    !>  `(mk-bask 'default')
  !>  got
::
++  test-fall-file-keeps-existing
  ::  fall file with existing keeps old content (as bask)
  =/  old=ball:tarball
    (~(put ba:tarball *ball:tarball) [/a %foo] (mk-content 'existing'))
  =/  rows=(list row:loader)
    ~[[%fall %& [/a %foo] (mk-bask 'default')]]
  =/  =bole:tarball  (spin:loader old rows)
  =/  got  (~(get bo:tarball bole) /a %foo)
  %+  expect-eq
    !>  `(mk-bask 'existing')
  !>  got
::
::  ==========================================
::  spin: %fall %| — keep existing dir, else default
::  ==========================================
::
++  test-fall-dir-uses-default
  ::  fall dir with no existing uses default bole
  =/  child-bole=bole:tarball  (mk-bole-1 %foo 'default')
  =/  old  *ball:tarball
  =/  rows=(list row:loader)
    ~[[%fall %| /sub child-bole]]
  =/  =bole:tarball  (spin:loader old rows)
  =/  got  (~(get bo:tarball bole) /sub %foo)
  %+  expect-eq
    !>  `(mk-bask 'default')
  !>  got
::
++  test-fall-dir-keeps-existing
  ::  fall dir with existing keeps old ball (converted to bole)
  =/  old=ball:tarball
    =/  sub=ball:tarball  (mk-ball-1 %foo 'existing')
    [~ (~(put by *(map @ta ball:tarball)) %sub sub)]
  ::  provide different defaults
  =/  def-bole=bole:tarball  (mk-bole-1 %foo 'default')
  =/  rows=(list row:loader)
    ~[[%fall %| /sub def-bole]]
  =/  =bole:tarball  (spin:loader old rows)
  =/  got  (~(get bo:tarball bole) /sub %foo)
  ::  should get old content (as bask), not default
  %+  expect-eq
    !>  `(mk-bask 'existing')
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
    |=  bsk=bask:tarball
    bsk
  =/  rows=(list row:loader)
    ~[[%load %& [/old %data] [/new %data] my-load]]
  =/  =bole:tarball  (spin:loader old rows)
  ;:  weld
    ::  old location should NOT be in new bole (unspecified = dropped)
    %+  expect-eq
      !>  ~
    !>  (~(get bo:tarball bole) /old %data)
    ::  new location has the content
    %+  expect-eq
      !>  `(mk-bask 'raw')
    !>  (~(get bo:tarball bole) /new %data)
  ==
::
++  test-load-file-missing-uses-bunt
  ::  load file with missing source uses bunt content
  =/  old  *ball:tarball
  =/  my-load=file-load:loader
    |=  bsk=bask:tarball
    (mk-bask 'fallback')
  =/  rows=(list row:loader)
    ~[[%load %& [/nope %gone] [/new %file] my-load]]
  =/  =bole:tarball  (spin:loader old rows)
  %+  expect-eq
    !>  `(mk-bask 'fallback')
  !>  (~(get bo:tarball bole) /new %file)
::
::  ==========================================
::  spin: %load %| — directory migration
::  ==========================================
::
++  test-load-dir-transforms
  ::  load dir extracts old subtree, runs transform, places at new path
  =/  old=ball:tarball
    =/  sub=ball:tarball  (mk-ball-1 %foo 'original')
    [~ (~(put by *(map @ta ball:tarball)) %src sub)]
  =/  my-fold=fold-load:loader
    |=  bl=bole:tarball
    bl
  =/  rows=(list row:loader)
    ~[[%load %| /src /dst my-fold]]
  =/  =bole:tarball  (spin:loader old rows)
  ;:  weld
    ::  old location not in new
    %+  expect-eq
      !>  ~
    !>  (~(get bo:tarball bole) /src %foo)
    ::  new location has the content
    %+  expect-eq
      !>  `(mk-bask 'original')
    !>  (~(get bo:tarball bole) /dst %foo)
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
    ~[[%fall %& [/a %keep] (mk-bask 'default')]]
  =/  =bole:tarball  (spin:loader old rows)
  ;:  weld
    ::  keep is present (kept from old, as bask)
    %+  expect-eq
      !>  `(mk-bask 'keep')
    !>  (~(get bo:tarball bole) /a %keep)
    ::  drop is gone
    %+  expect-eq
      !>  ~
    !>  (~(get bo:tarball bole) /a %drop)
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
    :~  [%over %& [/a %one] (mk-bask 'first')]
        [%over %& [/a %two] (mk-bask 'second')]
        [%over %& [/b %three] (mk-bask 'third')]
    ==
  =/  =bole:tarball  (spin:loader old rows)
  ;:  weld
    %+  expect-eq
      !>  `(mk-bask 'first')
    !>  (~(get bo:tarball bole) /a %one)
    %+  expect-eq
      !>  `(mk-bask 'second')
    !>  (~(get bo:tarball bole) /a %two)
    %+  expect-eq
      !>  `(mk-bask 'third')
    !>  (~(get bo:tarball bole) /b %three)
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
  =/  =bole:tarball  (spin:loader old ~)
  %+  expect-eq  !>(*bole:tarball)  !>(bole)
::
::  ==========================================
::  spin vs imperative: server on-load scenario
::  ==========================================
::
++  test-server-scenario-imperative
  ::  simulate server on-load imperative style on existing ball
  =/  server-bsk=bask:tarball  [[/ %server-state] 'state-data']
  =/  old-ball=ball:tarball
    =/  b  (~(put ba:tarball *ball:tarball) [/ %'ver.ud'] [[/ %ud] %& !>(0)])
    (~(put ba:tarball b) [/ %'main.server-state'] [[/ %server-state] %& !>('state-data')])
  ::  build bole imperatively
  =/  =bole:tarball  *bole:tarball
  =.  bole  (~(put bo:tarball bole) [/ %'ver.ud'] [[/ %ud] 0])
  =/  existing  (~(get ba:tarball old-ball) [/ %'main.server-state'])
  =?  bole  =(~ existing)
    (~(put bo:tarball bole) [/ %'main.server-state'] [[/ %server-state] 'fresh'])
  ::  existing was present, so we should use existing (as bask)
  =.  bole  (~(put bo:tarball bole) [/ %'main.server-state'] server-bsk)
  %+  expect-eq
    !>  `server-bsk
  !>  (~(get bo:tarball bole) [/ %'main.server-state'])
::
++  test-server-scenario-spin
  ::  simulate server on-load with spin on existing ball
  =/  server-ct=sang:tarball  [[/ %server-state] %& !>('state-data')]
  =/  old-ball=ball:tarball
    =/  b  (~(put ba:tarball *ball:tarball) [/ %'ver.ud'] [[/ %ud] %& !>(0)])
    (~(put ba:tarball b) [/ %'main.server-state'] server-ct)
  =/  =bole:tarball
    %+  spin:loader  old-ball
    :~  [%over %& [/ %'ver.ud'] [[/ %ud] 0]]
        [%fall %& [/ %'main.server-state'] [[/ %server-state] 'fresh']]
    ==
  ;:  weld
    ::  bole content is correct (existing kept, as bask)
    %+  expect-eq
      !>  `[[/ %server-state] 'state-data']
    !>  (~(get bo:tarball bole) [/ %'main.server-state'])
    %+  expect-eq
      !>  `[[/ %ud] 0]
    !>  (~(get bo:tarball bole) [/ %'ver.ud'])
  ==
--
