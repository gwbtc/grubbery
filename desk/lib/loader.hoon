::  loader: declarative on-load schema for nexuses
::
::  Instead of imperative =?/=. chains, declare a list of rows that
::  describe what the new [sand gain ball] should contain. Anything
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
+$  file-load  $-([? content:tarball] [? content:tarball])
+$  fold-load  $-([sand:nexus gain:nexus ball:tarball] [sand:nexus gain:nexus ball:tarball])
::
+$  row
  $%  [%stay %& =rail:tarball]
      [%stay %| =path]
      [%fall %& =rail:tarball gain=? =content:tarball]
      [%fall %| =path =sand:nexus =gain:nexus =ball:tarball]
      [%over %& =rail:tarball gain=? =content:tarball]
      [%over %| =path =sand:nexus =gain:nexus =ball:tarball]
      [%load %& from=rail:tarball to=rail:tarball =file-load]
      [%load %| from=path to=path =fold-load]
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
  =/  ct=(unit content:tarball)  (~(get ba:tarball ball) [/ %'ver.ud'])
  ?~  ct  ~
  `!<(@ud q.cage.u.ct)
::  +ver-row: convenience row to set the version file
::
++  ver-row
  |=  ver=@ud
  ^-  row
  [%over %& [/ %'ver.ud'] %.n [~ %ud !>(ver)]]
::  +put-sand: place a sub-sand at a path
::
++  put-sand
  |=  [parent=sand:nexus pax=path child=sand:nexus]
  ^-  sand:nexus
  ?~  pax  child
  =/  kid  (~(gut by dir.parent) i.pax *sand:nexus)
  parent(dir (~(put by dir.parent) i.pax $(parent kid, pax t.pax)))
::  +put-gain: place a sub-gain at a path
::
++  put-gain
  |=  [parent=gain:nexus pax=path child=gain:nexus]
  ^-  gain:nexus
  ?~  pax  child
  =/  kid  (~(gut by dir.parent) i.pax *gain:nexus)
  parent(dir (~(put by dir.parent) i.pax $(parent kid, pax t.pax)))
::  +put-ball: place a sub-ball at a path
::
++  put-ball
  |=  [parent=ball:tarball pax=path child=ball:tarball]
  ^-  ball:tarball
  ?~  pax  child
  =/  kid  (~(gut by dir.parent) i.pax *ball:tarball)
  parent(dir (~(put by dir.parent) i.pax $(parent kid, pax t.pax)))
::  +set-file-gain: set the gain flag for a file in the gain tree
::
++  set-file-gain
  |=  [gn=gain:nexus =rail:tarball flag=?]
  ^-  gain:nexus
  =/  dir-gn=(map @ta ?)  (fall (~(get of gn) path.rail) ~)
  (~(put of gn) path.rail (~(put by dir-gn) name.rail flag))
::  +get-file-gain: get the gain flag for a file from the gain tree
::
++  get-file-gain
  |=  [gn=gain:nexus =rail:tarball]
  ^-  ?
  =/  dir-gn=(map @ta ?)  (fall (~(get of gn) path.rail) ~)
  (fall (~(get by dir-gn) name.rail) %.n)
::  +spin: apply a list of rows, building new [sand gain ball] from old
::
++  spin
  |=  [old=[=sand:nexus =gain:nexus =ball:tarball] rows=(list row)]
  ^-  [sand:nexus gain:nexus ball:tarball]
  =/  new-sand=sand:nexus  *sand:nexus
  =/  new-gain=gain:nexus  *gain:nexus
  =/  new-ball=ball:tarball  *ball:tarball
  |-
  ?~  rows  [new-sand new-gain new-ball]
  ?-    i.rows
      [%stay %& *]
    =/  old-content=(unit content:tarball)
      (~(get ba:tarball ball.old) rail.i.rows)
    ?~  old-content  $(rows t.rows)
    =.  new-ball  (~(put ba:tarball new-ball) rail.i.rows u.old-content)
    =/  old-gn=?  (get-file-gain gain.old rail.i.rows)
    =.  new-gain  (set-file-gain new-gain rail.i.rows old-gn)
    $(rows t.rows)
  ::
      [%stay %| *]
    =/  old-ball=(unit ball:tarball)
      (~(dap ba:tarball ball.old) path.i.rows)
    ?~  old-ball  $(rows t.rows)
    =.  new-sand  (put-sand new-sand path.i.rows (~(dip of sand.old) path.i.rows))
    =.  new-gain  (put-gain new-gain path.i.rows (~(dip of gain.old) path.i.rows))
    =.  new-ball  (put-ball new-ball path.i.rows u.old-ball)
    $(rows t.rows)
  ::
      [%fall %& *]
    =/  old-content=(unit content:tarball)
      (~(get ba:tarball ball.old) rail.i.rows)
    =.  new-ball
      (~(put ba:tarball new-ball) rail.i.rows (fall old-content content.i.rows))
    =.  new-gain  (set-file-gain new-gain rail.i.rows gain.i.rows)
    $(rows t.rows)
  ::
      [%fall %| *]
    =/  old-ball=(unit ball:tarball)
      (~(dap ba:tarball ball.old) path.i.rows)
    =.  new-sand
      %-  put-sand
      :+  new-sand  path.i.rows
      ?^(old-ball (~(dip of sand.old) path.i.rows) sand.i.rows)
    =.  new-gain
      %-  put-gain
      :+  new-gain  path.i.rows
      ?^(old-ball (~(dip of gain.old) path.i.rows) gain.i.rows)
    =.  new-ball
      (put-ball new-ball path.i.rows (fall old-ball ball.i.rows))
    $(rows t.rows)
  ::
      [%over %& *]
    =.  new-ball
      (~(put ba:tarball new-ball) rail.i.rows content.i.rows)
    =.  new-gain  (set-file-gain new-gain rail.i.rows gain.i.rows)
    $(rows t.rows)
  ::
      [%over %| *]
    =.  new-sand  (put-sand new-sand path.i.rows sand.i.rows)
    =.  new-gain  (put-gain new-gain path.i.rows gain.i.rows)
    =.  new-ball  (put-ball new-ball path.i.rows ball.i.rows)
    $(rows t.rows)
  ::
      [%load %& *]
    =/  old-content=(unit content:tarball)
      (~(get ba:tarball ball.old) from.i.rows)
    =/  old-gn=?  (get-file-gain gain.old from.i.rows)
    =/  [out-gn=? out=content:tarball]
      (file-load.i.rows old-gn (fall old-content *content:tarball))
    =.  new-ball  (~(put ba:tarball new-ball) to.i.rows out)
    =.  new-gain  (set-file-gain new-gain to.i.rows out-gn)
    $(rows t.rows)
  ::
      [%load %| *]
    =/  sub-sand=sand:nexus  (~(dip of sand.old) from.i.rows)
    =/  sub-gain=gain:nexus  (~(dip of gain.old) from.i.rows)
    =/  sub-ball=ball:tarball  (~(dip ba:tarball ball.old) from.i.rows)
    =/  [out-sand=sand:nexus out-gain=gain:nexus out-ball=ball:tarball]
      (fold-load.i.rows sub-sand sub-gain sub-ball)
    =.  new-sand  (put-sand new-sand to.i.rows out-sand)
    =.  new-gain  (put-gain new-gain to.i.rows out-gain)
    =.  new-ball  (put-ball new-ball to.i.rows out-ball)
    $(rows t.rows)
  ==
--
