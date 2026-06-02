::  loader: declarative on-load schema for nexuses
::
::  Instead of imperative =?/=. chains, declare a list of rows that
::  describe what the new bole should contain. Anything
::  not listed is dropped — no explicit deletions needed.
::
::  IMPORTANT: since unspecified paths are not carried over, any files
::  you want to survive across loads must live under a directory that
::  is covered by a %load %| or %fall %| row.
::
::  Four row types, each with file (%&) or directory (%|) variant:
::    %stay: keep existing if present, skip if not
::    %fall: keep existing if present, else use default
::    %over: always overwrite with given value
::    %load: extract from old, run transformation, place in new
::
/+  tarball, nexus
|%
+$  file-load  $-(bask:tarball bask:tarball)
+$  fold-load  $-(bole:tarball bole:tarball)
++  same-file  |=(bask:tarball +<)
++  same-fold  |=(bole:tarball +<)
::
+$  row
  $%  [%stay %& =rail:tarball]
      [%stay %| =path]
      [%fall %& =rail:tarball =bask:tarball]
      [%fall %| =path =bole:tarball]
      [%over %& =rail:tarball =bask:tarball]
      [%over %| =path =bole:tarball]
      [%load %& from=rail:tarball to=rail:tarball =file-load]
      [%load %| from=fold:tarball to=fold:tarball =fold-load]
  ==
::
+$  ver  (unit @ud)
::  +get-ver: extract schema version from ball
::
::    ~      no ver.ud found (fresh or legacy — needs initialization)
::    [~ n]  ver.ud exists with value n
::
++  get-ver
  |=  =ball:tarball
  ^-  ver
  =/  ct=(unit sang:tarball)  (~(get ba:tarball ball) [/ %'ver.ud'])
  ?~  ct  ~
  `!<(@ud (need-vase:tarball u.ct))
::  +ver-row: convenience row to set the version file
::
++  empty-dir  [`[~ ~ ~] ~]
::
++  ver-row
  |=  ver=@ud
  ^-  row
  [%over %& [/ %'ver.ud'] [[/ %ud] ver]]
::  +put-bole: place a sub-bole at a path
::
++  put-bole
  |=  [parent=bole:tarball pax=path child=bole:tarball]
  ^-  bole:tarball
  ?~  pax  child
  =/  kid  (~(gut by dir.parent) i.pax *bole:tarball)
  parent(dir (~(put by dir.parent) i.pax $(parent kid, pax t.pax)))
::  +spin: apply a list of rows, building new bole from old ball
::
++  spin
  |=  [old=ball:tarball rows=(list row)]
  ^-  bole:tarball
  =/  new=bole:tarball  *bole:tarball
  |-
  ?~  rows  new
  ?-    i.rows
      [%stay %& *]
    =/  old-content=(unit sang:tarball)
      (~(get ba:tarball old) rail.i.rows)
    ?~  old-content  $(rows t.rows)
    =.  new
      (~(put bo:tarball new) rail.i.rows [p.u.old-content (sang-noun:tarball u.old-content)])
    $(rows t.rows)
  ::
      [%stay %| *]
    =/  old-ball=(unit ball:tarball)
      (~(dap ba:tarball old) path.i.rows)
    ?~  old-ball  $(rows t.rows)
    =.  new  (put-bole new path.i.rows (ball-to-bole:tarball u.old-ball))
    $(rows t.rows)
  ::
      [%fall %& *]
    =/  old-content=(unit sang:tarball)
      (~(get ba:tarball old) rail.i.rows)
    =/  bsk=bask:tarball
      ?~  old-content  bask.i.rows
      [p.u.old-content (sang-noun:tarball u.old-content)]
    =.  new  (~(put bo:tarball new) rail.i.rows bsk)
    $(rows t.rows)
  ::
      [%fall %| *]
    =/  old-ball=(unit ball:tarball)
      (~(dap ba:tarball old) path.i.rows)
    =.  new
      (put-bole new path.i.rows ?~(old-ball bole.i.rows (ball-to-bole:tarball u.old-ball)))
    $(rows t.rows)
  ::
      [%over %& *]
    =.  new  (~(put bo:tarball new) rail.i.rows bask.i.rows)
    $(rows t.rows)
  ::
      [%over %| *]
    =.  new  (put-bole new path.i.rows bole.i.rows)
    $(rows t.rows)
  ::
      [%load %& *]
    =/  old-content=(unit sang:tarball)
      (~(get ba:tarball old) from.i.rows)
    =/  old-bask=bask:tarball
      ?~  old-content  *bask:tarball
      [p.u.old-content (sang-noun:tarball u.old-content)]
    =/  out=bask:tarball  (file-load.i.rows old-bask)
    =.  new  (~(put bo:tarball new) to.i.rows out)
    $(rows t.rows)
  ::
      [%load %| *]
    =/  sub-ball=ball:tarball  (~(dip ba:tarball old) from.i.rows)
    =/  out=bole:tarball  (fold-load.i.rows (ball-to-bole:tarball sub-ball))
    =.  new  (put-bole new to.i.rows out)
    $(rows t.rows)
  ==
--
