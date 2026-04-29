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
    %sysc  ~[leaf+"vetoed syscall"]
    %scry  ~[leaf+"vetoed scry on wire {(spud wire.dart)}"]
    %bowl  ~[leaf+"vetoed bowl request on wire {(spud wire.dart)}"]
    %kept  ~[leaf+"vetoed kept request on wire {(spud wire.dart)}"]
    %node  ~[leaf+"vetoed node operation on wire {(spud wire.dart)}"]
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
++  send-card
  |=  =card:agent:gall
  =/  m  (fiber ,~)
  ^-  form:m
  (send-dart %sysc card)
::
++  send-cards
  |=  cards=(list card:agent:gall)
  =/  m  (fiber ,~)
  ^-  form:m
  (send-darts (turn cards |=(=card:agent:gall [%sysc card])))
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
++  get-bowl
  =/  m  (fiber ,bowl:nexus)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %bowl /bowl)
  (take-bowl /bowl)
::
++  take-bowl
  |=  =wire
  =/  m  (fiber ,bowl:nexus)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %bowl * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    [%done bowl.u.in]
  ==
::
::  Try %bowl dart; return %& bowl on success, %| tang on veto
::
++  try-bowl
  =/  m  (fiber ,(each bowl:nexus tang))
  ^-  form:m
  ;<  ~  bind:m  (send-dart %bowl /try-bowl)
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%done |+(veto-error dart.u.in)]
      [~ %bowl * *]
    ?.  =(/try-bowl wire.u.in)
      [%skip ~]
    [%done &+bowl.u.in]
  ==
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
++  take-watch
  =/  m  (fiber ,path)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %watch *]
    [%done path.u.in]
  ==
::
++  take-leave
  =/  m  (fiber ,path)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %leave *]
    [%done path.u.in]
  ==
::
++  take-arvo
  |=  =wire
  =/  m  (fiber ,sign-arvo)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %arvo * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    [%done sign.u.in]
  ==
::
++  take-agent
  |=  =wire
  =/  m  (fiber ,sign:agent:gall)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %agent * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    [%done sign.u.in]
  ==
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
  |=  [=road:tarball mark=(unit mark)]
  =/  m  (fiber ,seen:nexus)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node /peek road %peek mark ~ %.n)
  (take-peek /peek)
::
::  Peek at a historical version of a file
::
++  peek-at
  |=  [=road:tarball mark=(unit mark) =case:nexus]
  =/  m  (fiber ,seen:nexus)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node /peek road %peek mark `case %.n)
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
  |=  [=wire =road:tarball mark=(unit mark)]
  =/  m  (fiber ,view:nexus)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node wire road %keep mark)
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
::  Scry helper
::
++  do-scry
  |*  [=mold =path]
  =/  m  (fiber ,mold)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %scry /scry `[mold path])
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %scry * *]
    ?.  =(/scry wire.u.in)
      [%skip ~]
    [%done !<(mold vase.u.in)]
  ==
::  Clay operations
::
++  warp
  |=  [=ship =riff:clay]
  =/  m  (fiber ,riot:clay)
  ^-  form:m
  ;<  ~  bind:m  (send-card %pass /warp %arvo %c %warp ship riff)
  ;<  =sign-arvo  bind:m  (take-arvo /warp)
  ?>  ?=([%clay %writ *] sign-arvo)
  (pure:m +>.sign-arvo)
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
  =/  m  (fiber ,bins:nexus)
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
::  Gall agent operations (via syscalls)
::
++  gall-poke
  |=  [=dock =cage]
  =/  m  (fiber ,~)
  ^-  form:m
  =/  =card:agent:gall  [%pass /poke %agent dock %poke cage]
  ;<  ~  bind:m  (send-card card)
  (take-gall-poke-ack /poke)
::
++  take-gall-poke-ack
  |=  =wire
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %agent * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    ?.  ?=(%poke-ack -.sign.u.in)
      [%skip ~]
    ?~  p.sign.u.in
      [%done ~]
    [%fail %poke-failed u.p.sign.u.in]
  ==
::
++  gall-watch
  |=  [=wire =dock =path]
  =/  m  (fiber ,~)
  ^-  form:m
  =/  =card:agent:gall  [%pass wire %agent dock %watch path]
  ;<  ~  bind:m  (send-card card)
  (take-watch-ack wire)
::
++  take-watch-ack
  |=  =wire
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %agent * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    ?.  ?=(%watch-ack -.sign.u.in)
      [%skip ~]
    ?~  p.sign.u.in
      [%done ~]
    [%fail %watch-failed u.p.sign.u.in]
  ==
::
++  take-fact
  |=  =wire
  =/  m  (fiber ,cage)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %agent * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    ?.  ?=(%fact -.sign.u.in)
      [%skip ~]
    [%done cage.sign.u.in]
  ==
::
++  take-kick
  |=  =wire
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %agent * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    ?.  ?=(%kick -.sign.u.in)
      [%skip ~]
    [%done ~]
  ==
::
++  gall-leave
  |=  [=wire =dock]
  =/  m  (fiber ,~)
  ^-  form:m
  =/  =card:agent:gall  [%pass wire %agent dock %leave ~]
  (send-card card)
::  Timer helpers
::
++  send-wait
  |=  until=@da
  =/  m  (fiber ,~)
  ^-  form:m
  =/  =card:agent:gall
    [%pass /wait/(scot %da until) %arvo %b %wait until]
  (send-card card)
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
      [~ %arvo [%wait @ ~] %behn %wake *]
    ?.  |(?=(~ until) =(`u.until (slaw %da i.t.wire.u.in)))
      [%skip ~]
    ?~  error.sign.u.in
      [%done ~]
    [%fail %timer-error u.error.sign.u.in]
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
  ;<  =bowl:nexus  bind:m  get-bowl
  (wait (add now.bowl for))
::  Convenience bowl accessors
::
::  Try %bowl dart first; if vetoed, fall back to /sys/bowl/ oracle
::
++  get-our
  =/  m  (fiber ,ship)
  ^-  form:m
  ;<  res=(each bowl:nexus tang)  bind:m  try-bowl
  ?:  ?=(%& -.res)  (pure:m our.p.res)
  ;<  ~  bind:m  (poke [&+&+[/sys/bowl %'our.sig']] [/ %sig] !>(~))
  ;<  =sage:tarball  bind:m  take-poke
  (pure:m !<(@p q.sage))
::
++  get-time
  =/  m  (fiber ,@da)
  ^-  form:m
  ;<  res=(each bowl:nexus tang)  bind:m  try-bowl
  ?:  ?=(%& -.res)  (pure:m now.p.res)
  ;<  ~  bind:m  (poke [&+&+[/sys/bowl %'now.sig']] [/ %sig] !>(~))
  ;<  =sage:tarball  bind:m  take-poke
  (pure:m !<(@da q.sage))
::
++  get-entropy
  =/  m  (fiber ,@uvJ)
  ^-  form:m
  ;<  res=(each bowl:nexus tang)  bind:m  try-bowl
  ?:  ?=(%& -.res)  (pure:m eny.p.res)
  ;<  ~  bind:m  (poke [&+&+[/sys/bowl %'eny.sig']] [/ %sig] !>(~))
  ;<  =sage:tarball  bind:m  take-poke
  (pure:m !<(@uvJ q.sage))
::
++  get-here
  =/  m  (fiber ,rail:tarball)
  ^-  form:m
  ;<  res=(each bowl:nexus tang)  bind:m  try-bowl
  ?:  ?=(%& -.res)  (pure:m here.p.res)
  ;<  ~  bind:m  (poke [&+&+[/sys/bowl %'here.sig']] [/ %sig] !>(~))
  ;<  =sage:tarball  bind:m  take-poke
  (pure:m !<(rail:tarball q.sage))
::
++  get-agent
  =/  m  (fiber ,dude:gall)
  ^-  form:m
  ;<  =bowl:nexus  bind:m  get-bowl
  (pure:m dap.bowl)
::
++  get-beak
  =/  m  (fiber ,beak)
  ^-  form:m
  ;<  =bowl:nexus  bind:m  get-bowl
  (pure:m byk.bowl)
::
++  get-desk
  =/  m  (fiber ,desk)
  ^-  form:m
  ;<  =bowl:nexus  bind:m  get-bowl
  (pure:m q.byk.bowl)
::
++  get-case
  =/  m  (fiber ,case)
  ^-  form:m
  ;<  =bowl:nexus  bind:m  get-bowl
  (pure:m r.byk.bowl)
::  HTTP client (iris) helpers
::
++  cancel-request
  |=  =wire
  =/  m  (fiber ,~)
  ^-  form:m
  (send-card %pass wire %arvo %i %cancel-request ~)
::
++  send-request
  |=  =request:http
  =/  m  (fiber ,~)
  ^-  form:m
  (send-card %pass /request %arvo %i %request request *outbound-config:iris)
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
      [~ %arvo [%request ~] %iris %http-response %cancel *]
    [%fail leaf+"http-request-cancelled" ~]
      [~ %arvo [%request ~] %iris %http-response %finished *]
    [%done client-response.sign.u.in]
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
  |=  [=dude:gall =cage]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  our=@p  bind:m  get-our
  (gall-poke [our dude] cage)
::  Poke our own ship, returning nack as (unit tang) instead of crashing
::
++  gall-poke-or-nack
  |=  [=dude:gall =cage]
  =/  m  (fiber ,(unit tang))
  ^-  form:m
  ;<  our=@p  bind:m  get-our
  =/  =card:agent:gall  [%pass /poke %agent [our dude] %poke cage]
  ;<  ~  bind:m  (send-card card)
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %agent * *]
    ?.  =(/poke wire.u.in)
      [%skip ~]
    ?.  ?=(%poke-ack -.sign.u.in)
      [%skip ~]
    [%done p.sign.u.in]
  ==
::
++  give-response-header
  |=  [eyre-id=@ta =response-header:http]
  =/  m  (fiber ,~)
  ^-  form:m
  (send-card (give-response-header:hu eyre-id response-header))
::
++  give-response-data
  |=  [eyre-id=@ta data=(unit octs)]
  =/  m  (fiber ,~)
  ^-  form:m
  (send-card (give-response-data:hu eyre-id data))
::
++  give-simple-payload
  |=  [eyre-id=@ta =simple-payload:http]
  =/  m  (fiber ,~)
  ^-  form:m
  %-  send-cards
  (give-simple-payload:app:server eyre-id simple-payload)
::
++  kick-eyre
  |=  eyre-id=@ta
  =/  m  (fiber ,~)
  ^-  form:m
  (send-card (kick-eyre-sub:hu eyre-id))
::  SSE helpers
::
++  give-sse-header
  |=  eyre-id=@ta
  =/  m  (fiber ,~)
  ^-  form:m
  (send-card (give-sse-header:hu eyre-id))
::
++  give-sse-event
  |=  [eyre-id=@ta =sse-event:hu]
  =/  m  (fiber ,~)
  ^-  form:m
  (send-card (give-sse-event:hu eyre-id sse-event))
::
++  give-sse-keep-alive
  |=  eyre-id=@ta
  =/  m  (fiber ,~)
  ^-  form:m
  (send-card (give-sse-keep-alive:hu eyre-id))
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
      [~ %arvo [%wait @ ~] %behn %wake *]
    ?~  error.sign.u.in
      [%done %wake ~]
    [%fail %timer-error u.error.sign.u.in]
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
--
