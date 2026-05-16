::  fiberio: helper functions for nexus fibers
::
/+  nexus, tarball, server, hu=http-utils
|%
++  fiber   fiber:fiber:nexus
+$  input   input:fiber:nexus
+$  intake  intake:fiber:nexus
+$  dart    dart:nexus
::
++  veto-error
  |=  =dart
  ^-  tang
  ?-  -.dart
    %here  ~[leaf+"vetoed here request on wire {(spud wire.dart)}"]
    %kept  ~[leaf+"vetoed kept request on wire {(spud wire.dart)}"]
    %node  ~[leaf+"vetoed node operation on wire {(spud wire.dart)} dest {<road.dart>} load {<-.load.dart>}"]
    %manu  ~[leaf+"vetoed manu request on wire {(spud wire.dart)}"]
  ==
::
++  send-darts
  |=  darts=(list dart)
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  [darts state %done ~]
::
++  send-dart
  |=  =dart
  =/  m  (fiber ,~)
  ^-  form:m
  (send-darts dart ~)
::
::
++  trace
  |=  =tang
  =/  m  (fiber ,~)
  ^-  form:m
  (pure:m ((slog tang) ~))
::
++  fiber-fail
  |=  err=tang
  |=  input
  [~ state %fail err]
::
++  get-state
  =/  m  (fiber ,vase)
  ^-  form:m
  |=  input
  [~ state %done state]
::
++  get-state-as
  |*  a=mold
  =/  m  (fiber ,a)
  ^-  form:m
  |=  input
  [~ state %done !<(a state)] :: ;;(a q.state)
::
++  gut-state-as
  |*  a=mold
  |=  gut=$-(tang a)
  =/  m  (fiber ,a)
  ^-  form:m
  |=  input
  =/  res  (mule |.(;;(a q.state)))
  ?-  -.res
    %&  [~ state %done p.res]
    %|  [~ state %done (gut p.res)]
  ==
::
++  replace
  |=  new=vase
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  ^-  output:m
  [~ new %done ~]
::
++  transform
  |=  f=$-(vase vase)
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  ^-  output:m
  [~ (f state) %done ~]
::  Wait for any input and return it for manual switching
::
++  get-input
  =/  m  (fiber ,(unit intake))
  ^-  form:m
  |=  input
  [~ state %done in]
::
++  find-in-here
  |=  [=here:nexus target=(unit neck:tarball)]
  ^-  (unit @ud)
  ::  Scan pant from nearest ancestor (end) for matching neck.
  ::  Returns steps up from grub to ancestor nexus.
  ::  Value is directly usable as bend step count in lane-from-bend.
  =/  rev=pant:nexus  (flop pant.here)
  =/  steps=@ud  0
  |-
  ?~  rev  ~
  ?~  neck.i.rev  $(rev t.rev, steps +(steps))
  ?:  ?&  ?=(^ target)
          !=(u.target u.neck.i.rev)
      ==
    $(rev t.rev, steps +(steps))
  `steps
::  +ancestor-road: resolve a lane relative to an ancestor nexus
::
::  Finds the nearest ancestor with the given code-id (e.g. [/claw %agent])
::  via find-in-here, then builds a road to the given lane within it.
::  Works from any depth — no hardcoded offsets needed.
::
++  ancestor-road
  |=  [code-id=[=path name=@tas] =lane:tarball]
  =/  m  (fiber ,road:tarball)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %here /ancestor)
  ;<  =here:nexus  bind:m  (take-here-raw /ancestor)
  =/  steps=(unit @ud)  (find-in-here here `code-id)
  ?~  steps
    ~&  >>>  ["fiberio: couldn't find ancestor" code-id]
    (pure:m [%& lane])
  (pure:m [%| u.steps lane])
::
++  take-here-raw
  |=  =wire
  =/  m  (fiber ,here:nexus)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %here * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    [%done here.u.in]
  ==
::
++  coerce-here
  |=  =here:nexus
  ^-  rail:tarball
  ?>  root.here
  [(turn pant.here |=([dir=@ta *] dir)) name.here]
::
++  get-kept
  =/  m  (fiber ,kept:nexus)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %kept /kept)
  (take-kept /kept)
::
++  take-kept
  |=  =wire
  =/  m  (fiber ,kept:nexus)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %kept * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    [%done kept.u.in]
  ==
::  On %rise, log the error and wait for a poke to restart (expect %sig).
::  On normal startup, continue immediately.
::  Use at the top of a process to make it restartable:
::    ;<  ~  bind:m  (rise-wait prod "my-process: failed")
::    ::  startup code continues here
::
++  rise-wait
  |=  [=prod:fiber:nexus msg=tape]
  =/  m  (fiber ,~)
  ^-  form:m
  ?.  ?=(%rise -.prod)  (pure:m ~)
  %-  (slog leaf+msg tang.prod)
  ;<  =sage:tarball  bind:m  take-poke
  ?:  =([/ %sig] p.sage)
    (pure:m ~)
  (trace leaf+"strange restart mark: {<p.sage>}" ~)
::
++  take-poke
  =/  m  (fiber ,sage:tarball)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %poke * *]
    [%done sage.u.in]
  ==
::  Take a poke and return both its source and payload
::
::  Returns [from sage] where:
::    from: %.y bend for internal (relative), %.n prov for external
::    sage: the poke payload
::
::  The from is relative to the current file's location.
::  Use this when you need to verify the poke source for security.
::
++  take-poke-from
  =/  m  (fiber ,[from:fiber:nexus sage:tarball])
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %poke * *]
    [%done [from sage]:u.in]
  ==
::
::
::
++  take-made
  |=  =wire
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %made * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    ?~  err.u.in
      [%done ~]
    [%fail %make-failed u.err.u.in]
  ==
::
++  take-pack
  |=  =wire
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %pack * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    ?~  err.u.in
      [%done ~]
    [%fail %poke-failed u.err.u.in]
  ==
::
++  take-peek
  |=  =wire
  =/  m  (fiber ,seen:nexus)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %peek * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    [%done seen.u.in]
  ==
::  File operations: make, poke, peek, cull, sand
::
++  make
  |=  [=road:tarball =make:nexus]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node /make road %make make)
  (take-made /make)
::
++  make-soft
  |=  [=road:tarball =make:nexus]
  =/  m  (fiber ,(unit tang))
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node /make road %make make)
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %made * *]
    ?.  =(/make wire.u.in)
      [%skip ~]
    [%done err.u.in]
  ==
::
++  poke
  |=  [=road:tarball =sage:tarball]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node /poke road %poke sage)
  (take-pack /poke)
::
++  peek
  |=  [=road:tarball blot=(unit blot:tarball)]
  =/  m  (fiber ,seen:nexus)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node /peek road %peek blot ~ %.n)
  (take-peek /peek)
::
::  Peek at a historical version of a file
::
++  peek-at
  |=  [=road:tarball blot=(unit blot:tarball) =case:nexus]
  =/  m  (fiber ,seen:nexus)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node /peek road %peek blot `case %.n)
  (take-peek /peek)
::
::  Check if a target (file or directory) exists at a road.
::  Returns %.n on peek failure or %none view, %.y otherwise.
::
++  peek-exists
  |=  =road:tarball
  =/  m  (fiber ,?)
  ^-  form:m
  ;<  =seen:nexus  bind:m  (peek road ~)
  (pure:m ?&(?=(%& -.seen) !?=(%none -.p.seen)))
::
::  Direct manu: query a known nexus by neck
::
++  manu
  |=  [=neck:tarball =mana:nexus]
  =/  m  (fiber ,@t)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %manu /manu neck mana)
  (take-manu /manu)
::  Road manu: query docs for a path (system resolves nexus)
::
++  manu-road
  |=  =road:tarball
  =/  m  (fiber ,@t)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node /manu road %manu ~)
  (take-manu /manu)
::
++  take-manu
  |=  =wire
  =/  m  (fiber ,@t)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %manu * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    ?:  ?=(%| -.res.u.in)
      [%fail %manu-failed p.res.u.in]
    [%done p.res.u.in]
  ==
::
++  cull
  |=  =road:tarball
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node /cull road %cull ~)
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %gone * *]
    ?.  =(/cull wire.u.in)
      [%skip ~]
    ?~  err.u.in
      [%done ~]
    [%fail %cull-failed >road< u.err.u.in]
  ==
::  Like +cull but logs and continues on error instead of crashing.
::  Use for best-effort cleanup where the target may already be gone.
::
++  cull-soft
  |=  =road:tarball
  =/  m  (fiber ,(unit tang))
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node /cull road %cull ~)
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %gone * *]
    ?.  =(/cull wire.u.in)
      [%skip ~]
    [%done err.u.in]
  ==
::
++  sand
  |=  [=road:tarball weir=(unit weir:nexus)]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node /sand road %sand weir)
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %sand * *]
    ?.  =(/sand wire.u.in)
      [%skip ~]
    ?~  err.u.in
      [%done ~]
    [%fail %sand-failed u.err.u.in]
  ==
::
++  gain
  |=  [=road:tarball flag=?]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node /gain road %gain flag)
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %gain * *]
    ?.  =(/gain wire.u.in)
      [%skip ~]
    ?~  err.u.in
      [%done ~]
    [%fail %gain-failed u.err.u.in]
  ==
::
++  lose
  |=  [=road:tarball =lose:nexus]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node /lose road %lose lose)
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %lost * *]
    ?.  =(/lose wire.u.in)
      [%skip ~]
    ?~  err.u.in
      [%done ~]
    [%fail %lose-failed u.err.u.in]
  ==
::
++  seek
  |=  [=road:tarball =lobe:clay]
  =/  m  (fiber ,(each (list [=rail:tarball =cass:clay]) tang))
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node /seek road %seek lobe)
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %seek * *]
    ?.  =(/seek wire.u.in)
      [%skip ~]
    [%done res.u.in]
  ==
::
++  peep
  |=  [=road:tarball =find:nexus]
  =/  m  (fiber ,(each (list [=cass:clay =sage:tarball]) tang))
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node /peep road %peep find)
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %peep * *]
    ?.  =(/peep wire.u.in)
      [%skip ~]
    [%done res.u.in]
  ==
::
++  over
  |=  [=road:tarball =sage:tarball]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node /over road %over sage)
  (take-over /over)
::
++  take-over
  |=  =wire
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %over * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    ?~  err.u.in
      [%done ~]
    [%fail %over-failed u.err.u.in]
  ==
::
++  reload
  |=  =road:tarball
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node /load road %load ~)
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %load * *]
    ?.  =(/load wire.u.in)
      [%skip ~]
    ?~  err.u.in
      [%done ~]
    [%fail %load-failed u.err.u.in]
  ==
::  Subscription operations: keep, drop
::
++  keep
  |=  [=wire =road:tarball blot=(unit blot:tarball)]
  =/  m  (fiber ,view:nexus)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node wire road %keep blot)
  (take-bond wire)
::
++  drop
  |=  [=wire =road:tarball]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node wire road %drop ~)
  (take-fell wire)
::
++  take-bond
  |=  =wire
  =/  m  (fiber ,view:nexus)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %bond * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    ?:  ?=(%& -.now.u.in)
      [%done p.now.u.in]
    [%fail %keep-failed p.now.u.in]
  ==
::
++  take-fell
  |=  =wire
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %fell *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    [%done ~]
  ==
::
++  take-news
  |=  =wire
  =/  m  (fiber ,view:nexus)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %news * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    [%done view.u.in]
  ==
::  Scry via /sys/scry/ runtime service
::
++  scry
  |*  [=mold =path]
  =/  m  (fiber ,mold)
  ^-  form:m
  ;<  ~  bind:m
    (poke &+&+[/sys/scry %'main.sig'] [[/ %scry-request] !>(`^path`path)])
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %poke * *]
    ?.  =([/ %scry-response] p.sage.u.in)  [%skip ~]
    [%done !<(mold q.sage.u.in)]
  ==
::  Create a new desk via /sys/clay/ runtime service
::
++  create-desk
  |=  dek=desk
  =/  m  (fiber ,~)
  ^-  form:m
  (poke &+&+[/sys/clay %'main.clay-state'] [[/ %new-desk] !>(dek)])
::  Write/delete files in a Clay desk via /sys/clay/ runtime service.
::  No vases — the runtime clams through marks on the destination desk.
::
++  clay-info
  |=  [dek=desk changes=(list [path ?([%ins @tas *] [%del ~])])]
  =/  m  (fiber ,~)
  ^-  form:m
  (poke &+&+[/sys/clay %'main.clay-state'] [[/ %clay-info] !>([dek changes])])
::  Send a belt to a dill session via /sys/dill/ runtime service
::
++  send-belt
  |=  [session=@tas =belt:dill]
  =/  m  (fiber ,~)
  ^-  form:m
  (poke &+&+[/sys/dill %'main.sig'] [[/ %dill-belt] !>([session belt])])
::  +get-code: peek the code (bins) slice at a road
::
++  get-code
  |=  =road:tarball
  =/  m  (fiber ,(unit vase))
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node /code road %code ~)
  (take-code /code)
::
++  take-code
  |=  =wire
  =/  m  (fiber ,(unit vase))
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %code * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    ?.  ?=(%| -.res.u.in)
      [%skip ~]
    ?:  ?=(%vase -.p.res.u.in)
      [%done `vase.p.res.u.in]
    [%done ~]
  ==
::  +get-code-full: peek code slice, returning full built
::
++  get-code-full
  |=  =road:tarball
  =/  m  (fiber ,built:nexus)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node /code road %code ~)
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %code * *]
    ?.  =(/code wire.u.in)
      [%skip ~]
    ?.  ?=(%| -.res.u.in)
      [%skip ~]
    [%done p.res.u.in]
  ==
::  +get-code-tree: peek code slice subtree at a directory road
::
++  get-code-tree
  |=  =road:tarball
  =/  m  (fiber ,(axal (map @ta built:nexus)))
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node /code road %code ~)
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %code * *]
    ?.  =(/code wire.u.in)
      [%skip ~]
    ?.  ?=(%& -.res.u.in)
      [%skip ~]
    [%done p.res.u.in]
  ==
::  +get-bang: query error state at a road
::
++  get-bang
  |=  =road:tarball
  =/  m  (fiber ,(each bangs:nexus (unit tang)))
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node /bang road %bang ~)
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %bang * *]
    ?.  =(/bang wire.u.in)
      [%skip ~]
    [%done res.u.in]
  ==
::  +get-font: find code responsible for a node
::  Returns bend to code namespace (relative to asker) + source rail within
::
++  get-font
  |=  =road:tarball
  =/  m  (fiber ,(unit bend:tarball))
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node /font road %font ~)
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %font * *]
    ?.  =(/font wire.u.in)
      [%skip ~]
    [%done res.u.in]
  ==
::  +get-marc: look up a compiled marc from bins
::
++  get-marc
  |=  [cod=road:tarball =blot:tarball]
  =/  m  (fiber ,(unit marc:tarball))
  ^-  form:m
  =/  =road:tarball  (extend-road:tarball cod (weld /mar path.blot) name.blot)
  ;<  res=(unit vase)  bind:m  (get-code road)
  ?~  res  (pure:m ~)
  (pure:m `!<(marc:tarball u.res))
::  +get-tube: look up a tube via marc grow/grab
::
::  Tries source.grow(target) first, then target.grab(source).
::
++  get-tube
  |=  [cod=road:tarball =bars:tarball]
  =/  m  (fiber ,(unit tube:clay))
  ^-  form:m
  ;<  src-marc=(unit marc:tarball)  bind:m  (get-marc cod a.bars)
  =/  grow-tube=(unit tube:clay)
    ?~  src-marc  ~
    (mole |.((grow.u.src-marc b.bars)))
  ?^  grow-tube  (pure:m grow-tube)
  ::  Fallback: try target.grab(source)
  ;<  dst-marc=(unit marc:tarball)  bind:m  (get-marc cod b.bars)
  ?~  dst-marc  (pure:m ~)
  =/  grab-tube=(unit tube:clay)
    (mole |.((grab.u.dst-marc a.bars)))
  (pure:m grab-tube)
::  +get-vale: look up a vale via marc
::
++  get-vale
  |=  [cod=road:tarball =blot:tarball]
  =/  m  (fiber ,(unit $-(* vase)))
  ^-  form:m
  ;<  marc-res=(unit marc:tarball)  bind:m  (get-marc cod blot)
  ?~  marc-res  (pure:m ~)
  (pure:m `vale.u.marc-res)
::  +get-nexus: look up a compiled nexus from bins
::
++  get-nexus
  |=  [cod=road:tarball =neck:tarball]
  =/  m  (fiber ,(unit nexus:nexus))
  ^-  form:m
  =/  =road:tarball  (extend-road:tarball cod (weld /nex path.neck) name.neck)
  ;<  res=(unit vase)  bind:m  (get-code road)
  ?~  res  (pure:m ~)
  (pure:m `!<(nexus:nexus u.res))
::  +collect-blots: collect all blots used in sages within a ball (deep)
::
++  collect-blots
  |=  =ball:tarball
  ^-  (set blot:tarball)
  =/  blots=(set blot:tarball)  ~
  =?  blots  ?=(^ fil.ball)
    =/  entries=(list (pair @ta content:tarball))
      ~(tap by contents.u.fil.ball)
    |-  ^-  (set blot:tarball)
    ?~  entries  blots
    =*  content  q.i.entries
    $(entries t.entries, blots (~(put in blots) p.sage.content))
  =/  subdirs=(list (pair @ta ball:tarball))  ~(tap by dir.ball)
  |-  ^-  (set blot:tarball)
  ?~  subdirs  blots
  =/  sub=(set blot:tarball)  ^$(ball q.i.subdirs)
  $(subdirs t.subdirs, blots (~(uni in blots) sub))
::  +collect-blots-shallow: collect blots only from immediate files (no recurse)
::
++  collect-blots-shallow
  |=  =ball:tarball
  ^-  (set blot:tarball)
  ?~  fil.ball  ~
  =/  entries=(list (pair @ta content:tarball))
    ~(tap by contents.u.fil.ball)
  =/  blots=(set blot:tarball)  ~
  |-  ^-  (set blot:tarball)
  ?~  entries  blots
  =*  ct  q.i.entries
  $(entries t.entries, blots (~(put in blots) p.sage.ct))
::  +build-blot-conversions: build conversions map for a set of blots
::
++  build-blot-conversions
  |=  blots=(set blot:tarball)
  =/  m  (fiber ,(map bars:tarball tube:clay))
  ^-  form:m
  =/  blot-list=(list blot:tarball)  ~(tap in blots)
  =/  conversions=(map bars:tarball tube:clay)  ~
  |-  ^-  form:m
  ?~  blot-list
    (pure:m conversions)
  =/  =bars:tarball  [i.blot-list [/ %mime]]
  ;<  tube-result=(unit tube:clay)  bind:m
    (get-tube [%& %| /code] bars)
  =?  conversions  ?=(^ tube-result)
    (~(put by conversions) bars u.tube-result)
  $(blot-list t.blot-list)
::  +get-blot-conversions: build blot conversions for all blots in ball (deep)
::
++  get-blot-conversions
  |=  =ball:tarball
  =/  m  (fiber ,(map bars:tarball tube:clay))
  ^-  form:m
  (build-blot-conversions (collect-blots ball))
::  +get-blot-conversions-shallow: build conversions for immediate files only
::
++  get-blot-conversions-shallow
  |=  =ball:tarball
  =/  m  (fiber ,(map bars:tarball tube:clay))
  ^-  form:m
  (build-blot-conversions (collect-blots-shallow ball))
::  +sage-to-mime: convert sage to mime, falling back to jam
::
++  sage-to-mime
  |=  =sage:tarball
  =/  m  (fiber ,mime)
  ^-  form:m
  ?:  =([/ %mime] p.sage)
    (pure:m !<(mime q.sage))
  =/  =bars:tarball  [p.sage [/ %mime]]
  ;<  tube=(unit tube:clay)  bind:m
    (get-tube [%& %| /code] bars)
  ?~  tube
    (pure:m [/application/x-urb-jam (as-octs:mimes:html (jam q.sage))])
  =/  result=(each vase tang)  (mule |.((u.tube q.sage)))
  ?:  ?=(%| -.result)
    (pure:m [/application/x-urb-jam (as-octs:mimes:html (jam q.sage))])
  =/  extracted  (mule |.(!<(mime p.result)))
  ?:  ?=(%| -.extracted)
    (pure:m [/application/x-urb-jam (as-octs:mimes:html (jam q.sage))])
  (pure:m p.extracted)
::  Gall agent operations (via /sys/gall/ runtime service)
::
++  gall-poke
  |=  [=dock =page]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  ~  bind:m
    (poke &+&+[/sys/gall %'main.sig'] [[/ %gall-poke] !>([dock page])])
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %poke * *]
    ?.  =([/ %poke-ack] p.sage.u.in)  [%skip ~]
    =/  err=(unit tang)  !<((unit tang) q.sage.u.in)
    ?~  err  [%done ~]
    [%fail %poke-failed u.err]
  ==
::  Timer helpers — poke /sys/behn/main.timer-state, receive timer-wake back
::
++  set-timer
  |=  [=wire until=@da]
  =/  m  (fiber ,~)
  ^-  form:m
  (poke &+&+[/sys/behn %'main.timer-state'] [[/ %timer-set] !>(`[^wire @da]`[wire until])])
::
++  send-wait
  |=  until=@da
  =/  m  (fiber ,~)
  ^-  form:m
  (set-timer /wait/(scot %da until) until)
::
++  take-wake
  |=  until=(unit @da)
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %poke * *]
    ?.  =([/ %timer-wake] p.sage.u.in)
      [%skip ~]
    =/  wak=path  !<(path q.sage.u.in)
    ?.  |(?=(~ until) ?&(?=([%wait @ ~] wak) =(u.until (slav %da i.t.wak))))
      [%skip ~]
    [%done ~]
  ==
::
++  wait
  |=  until=@da
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  ~  bind:m  (send-wait until)
  (take-wake `until)
::
++  sleep
  |=  for=@dr
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time
  (wait (add now for))
::  Convenience accessors
::
++  get-our
  =/  m  (fiber ,ship)
  ^-  form:m
  ;<  =seen:nexus  bind:m  (peek [%& %& /sys/bowl %our] ~)
  ?.  ?=([%& %file *] seen)
    (pure:m *ship)
  (pure:m !<(ship q.sage.p.seen))
::
++  get-time
  =/  m  (fiber ,@da)
  ^-  form:m
  ;<  =seen:nexus  bind:m  (peek [%& %& /sys/bowl %now] ~)
  ?.  ?=([%& %file *] seen)
    (pure:m *@da)
  (pure:m !<(@da q.sage.p.seen))
::
++  get-entropy
  =/  m  (fiber ,@uvJ)
  ^-  form:m
  ;<  =seen:nexus  bind:m  (peek [%& %& /sys/bowl %eny] ~)
  ?.  ?=([%& %file *] seen)
    (pure:m *@uvJ)
  (pure:m !<(@uvJ q.sage.p.seen))
::
++  get-here
  =/  m  (fiber ,here:nexus)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %here /here)
  (take-here-raw /here)
::  +get-here-abs: get absolute rail, crashes if blocked from root
::
++  get-here-abs
  =/  m  (fiber ,rail:tarball)
  ^-  form:m
  ;<  =here:nexus  bind:m  get-here
  (pure:m (coerce-here here))
::
++  dap  %grubbery
++  dek  %grubbery
::
::
++  get-beak
  =/  m  (fiber ,beak)
  ^-  form:m
  ;<  our=@p  bind:m  get-our
  ;<  now=@da  bind:m  get-time
  (pure:m [our dek da+now])
::
++  get-desk
  =/  m  (fiber ,desk)
  ^-  form:m
  (pure:m dek)
::
++  get-case
  =/  m  (fiber ,case)
  ^-  form:m
  ;<  now=@da  bind:m  get-time
  (pure:m da+now)
::
::  HTTP client (iris) helpers
::  Requests go through /sys/iris/ runtime service.
::
++  send-request
  |=  =request:http
  =/  m  (fiber ,~)
  ^-  form:m
  (poke &+&+[/sys/iris %'main.iris-state'] [[/ %http-request] !>(request)])
::
++  take-client-response
  =/  m  (fiber ,client-response:iris)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %poke * *]
    ?.  =([/ %http-response] p.sage.u.in)  [%skip ~]
    =/  resp=client-response:iris  !<(client-response:iris q.sage.u.in)
    ?:  ?=(%cancel -.resp)
      [%fail leaf+"http-request-cancelled" ~]
    [%done resp]
  ==
::
++  extract-body
  |=  =client-response:iris
  =/  m  (fiber ,@t)
  ^-  form:m
  ?>  ?=(%finished -.client-response)
  %-  pure:m
  ?~  full-file.client-response  ''
  q.data.u.full-file.client-response
::
++  fetch
  |=  =request:http
  =/  m  (fiber ,@t)
  ^-  form:m
  ;<  ~                      bind:m  (send-request request)
  ;<  =client-response:iris  bind:m  take-client-response
  (extract-body client-response)
::  Poke our own ship
::
++  gall-poke-our
  |=  [=dude:gall =page]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  our=@p  bind:m  get-our
  (gall-poke [our dude] page)
::  Poke our own ship, returning nack as (unit tang) instead of crashing
::
++  gall-poke-or-nack
  |=  [=dude:gall =page]
  =/  m  (fiber ,(unit tang))
  ^-  form:m
  ;<  our=@p  bind:m  get-our
  ;<  ~  bind:m
    (poke &+&+[/sys/gall %'main.sig'] [[/ %gall-poke] !>([[our dude] page])])
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %poke * *]
    ?.  =([/ %poke-ack] p.sage.u.in)  [%skip ~]
    [%done !<((unit tang) q.sage.u.in)]
  ==
::  +take-news-or-wake: wait for subscription news or timer wake
::
::    Use this in SSE loops to multiplex between data events and
::    keep-alive timers. Returns %news with the update data, or
::    %wake when the timer fires.
+$  news-or-wake
  $%  [%news =view:nexus]
      [%wake ~]
  ==
::
++  take-news-or-wake
  |=  news-wire=wire
  =/  m  (fiber ,news-or-wake)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %news * *]
    ?.  =(news-wire wire.u.in)
      [%skip ~]
    [%done %news view.u.in]
      [~ %poke * *]
    ?.  =([/ %timer-wake] p.sage.u.in)
      [%skip ~]
    [%done %wake ~]
  ==
::  Clay file helpers
::
::  +build-clay-file: compile a hoon source file, returns (unit vase)
::
++  build-clay-file
  |=  [dek=desk pax=path]
  =/  m  (fiber ,(unit vase))
  ^-  form:m
  ;<  our=ship    bind:m  get-our
  ;<  now=@da     bind:m  get-time
  =/  base=path   /(scot %p our)/[dek]/(scot %da now)
  =/  exists=?    .^(? %cu (weld base pax))
  ?.  exists  (pure:m ~)
  =/  res=(each vase tang)
    (mule |.(.^(vase %ca (weld base pax))))
  ?:(?=(%& -.res) (pure:m `p.res) (pure:m ~))
::  +list-clay-tree: list all file paths under a directory
::
++  list-clay-tree
  |=  [dek=desk pax=path]
  =/  m  (fiber ,(list path))
  ^-  form:m
  ;<  our=ship  bind:m  get-our
  ;<  now=@da   bind:m  get-time
  =/  base=path  /(scot %p our)/[dek]/(scot %da now)
  (pure:m .^((list path) %ct (weld base pax)))
::  +check-clay-file: check if a file exists
::
++  check-clay-file
  |=  [dek=desk pax=path]
  =/  m  (fiber ,?)
  ^-  form:m
  ;<  our=ship  bind:m  get-our
  ;<  now=@da   bind:m  get-time
  =/  base=path  /(scot %p our)/[dek]/(scot %da now)
  (pure:m .^(? %cu (weld base pax)))
::  +copy-grub: copy a file from src to dst
::
++  copy-grub
  |=  [src=road:tarball dst=road:tarball]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  =seen:nexus  bind:m  (peek src ~)
  ?.  ?=([%& %file *] seen)
    ~|(%copy-grub-src-not-found !!)
  (make dst |+[%.n sage.p.seen ~])
::  +copy-fold: copy a directory from src to dst
::
++  copy-fold
  |=  [src=road:tarball dst=road:tarball]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  =seen:nexus  bind:m  (peek src ~)
  ?.  ?=([%& %ball *] seen)
    ~|(%copy-fold-src-not-found !!)
  (make dst &+[sand.p.seen gain.p.seen ball.p.seen])
::  +move-grub: move a file from src to dst (copy + delete)
::
++  move-grub
  |=  [src=road:tarball dst=road:tarball]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  ~  bind:m  (copy-grub src dst)
  (cull src)
::  +move-fold: move a directory from src to dst (copy + delete)
::
++  move-fold
  |=  [src=road:tarball dst=road:tarball]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  ~  bind:m  (copy-fold src dst)
  (cull src)
::
::  HTTP BINDING + RESPONSE PRIMITIVES
::
::  +bind-http: register an eyre binding, sender is the handler.
::  Resolves caller's absolute position as the handler rail.
::
++  bind-http
  |=  =binding:eyre
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  here=rail:tarball  bind:m  get-here-abs
  (eyre-poke [%bind binding here])
::  +unbind-http: remove a binding
::
++  unbind-http
  |=  =binding:eyre
  =/  m  (fiber ,~)
  ^-  form:m
  (eyre-poke [%unbind binding])
::
++  server-road  `road:tarball`[%& %& /sys/eyre %'main.server-state']
::
++  eyre-poke
  |=  act=eyre-action:nexus
  =/  m  (fiber ,~)
  ^-  form:m
  (poke server-road [[/ %eyre-action] !>(act)])
::  HTTP response helpers, parameterized on dispatcher road.
::  Sends route through the dispatcher (main.sig) so the server fiber
::  sees from=main.sig for cancel-back on orphaned connections.
::  Usage: =/  srv  ~(. http-res:io [%| 1 %& ~ %'main.sig'])
::         (send-simple:srv eyre-id payload)
::
++  http-res
  |_  main=road:tarball
  ++  send
    |=  [eyre-id=@ta =eyre-update:nexus]
    =/  m  (fiber ,~)
    ^-  form:m
    (poke main [[/ %eyre-action] !>(`eyre-action:nexus`[%send eyre-id eyre-update])])
  ::
  ++  send-simple
    |=  [eyre-id=@ta =simple-payload:http]
    =/  m  (fiber ,~)
    ^-  form:m
    (send eyre-id %simple simple-payload)
  ::
  ++  send-header
    |=  [eyre-id=@ta =response-header:http]
    =/  m  (fiber ,~)
    ^-  form:m
    (send eyre-id %header response-header)
  ::
  ++  send-data
    |=  [eyre-id=@ta data=(unit octs)]
    =/  m  (fiber ,~)
    ^-  form:m
    (send eyre-id %data data)
  ::
  ++  send-kick
    |=  eyre-id=@ta
    =/  m  (fiber ,~)
    ^-  form:m
    (send eyre-id %kick ~)
  --
::  Standard HTTP dispatcher loop for nexuses with /requests/ sub-dir.
::  Spawns per-request processes, forwards responses, handles cancels.
::
++  http-dispatch
  |=  label=@tas
  =/  m  (fiber ,~)
  ^-  form:m
  |-
  ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from
  ?+    name.p.sage  $
      %handle-http-request
    =/  [eyre-id=@ta src=@p req=inbound-request:eyre]
      !<([eyre-id=@ta @p inbound-request:eyre] q.sage)
    ~&  >  [label %dispatch eyre-id url.request.req]
    ;<  ~  bind:m  (make [%| 0 %& /requests eyre-id] |+[%.n [[/ %http-request] !>([src req])] ~])
    $
      %handle-http-cancel
    =/  eyre-id=@ta  !<(@ta q.sage)
    ~&  >  [label %cancel eyre-id]
    ;<  ~  bind:m  (cull [%| 0 %& /requests eyre-id])
    $
      %eyre-action
    ;<  ~  bind:m  (poke server-road sage)
    $
  ==
::  +resolve-bend: resolve a fiber bend to an absolute rail
::
++  resolve-bend
  |=  [here=rail:tarball =bend:fiber:nexus]
  ^-  rail:tarball
  =/  base=path  path.here
  =/  up=@ud  p.bend
  =/  resolved=path
    |-
    ?:  =(0 up)  base
    ?~  base  ~
    $(up (dec up), base (snip `path`base))
  [(weld resolved path.q.bend) name.q.bend]
--
