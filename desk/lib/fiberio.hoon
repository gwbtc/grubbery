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
    %node  ~[leaf+"vetoed node operation on wire {(spud wire.dart)}"]
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
  [~ state %done ;;(a q.state)]
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
  |=  =wire
  =/  m  (fiber ,bowl:nexus)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %bowl wire)
  (take-bowl wire)
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
  ;<  =cage  bind:m  take-poke
  ?:  ?=(%sig p.cage)
    (pure:m ~)
  (trace leaf+"strange restart mark: {<p.cage>}" ~)
::
++  take-poke
  =/  m  (fiber ,cage)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %poke * *]
    [%done cage.u.in]
  ==
::  Take a poke and return both its source and payload
::
::  Returns [from cage] where:
::    from: %.y bend for internal (relative), %.n prov for external
::    cage: the poke payload
::
::  The from is relative to the current file's location.
::  Use this when you need to verify the poke source for security.
::
++  take-poke-from
  =/  m  (fiber ,[from:fiber:nexus cage])
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %poke * *]
    [%done [from cage]:u.in]
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
  |=  [=wire =road:tarball =make:nexus mark=(unit mark)]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node wire road %make make mark)
  (take-made wire)
::
++  poke
  |=  [=wire =road:tarball =cage]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node wire road %poke cage)
  (take-pack wire)
::
++  peek
  |=  [=wire =road:tarball mark=(unit mark)]
  =/  m  (fiber ,seen:nexus)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node wire road %peek mark)
  (take-peek wire)
::
::  Check if a target (file or directory) exists at a road.
::  Returns %.n on peek failure or %none view, %.y otherwise.
::
++  peek-exists
  |=  [=wire =road:tarball]
  =/  m  (fiber ,?)
  ^-  form:m
  ;<  =seen:nexus  bind:m  (peek wire road ~)
  (pure:m ?&(?=(%& -.seen) !?=(%none -.p.seen)))
::
++  cull
  |=  [=wire =road:tarball]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node wire road %cull ~)
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %gone * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    ?~  err.u.in
      [%done ~]
    [%fail %cull-failed u.err.u.in]
  ==
::
++  sand
  |=  [=wire =road:tarball weir=(unit weir:nexus)]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node wire road %sand weir)
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %sand * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    ?~  err.u.in
      [%done ~]
    [%fail %sand-failed u.err.u.in]
  ==
::
++  over
  |=  [=wire =road:tarball =cage]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node wire road %over cage)
  (take-over wire)
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
++  diff
  |=  [=wire =road:tarball =cage]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node wire road %diff cage)
  (take-diff wire)
::
++  take-diff
  |=  =wire
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %diff * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    ?~  err.u.in
      [%done ~]
    [%fail %diff-failed u.err.u.in]
  ==
::
++  reload
  |=  [=wire =road:tarball]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node wire road %load ~)
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %load * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    ?~  err.u.in
      [%done ~]
    [%fail %load-failed u.err.u.in]
  ==
::  Subscription operations: keep, drop
::
++  keep
  |=  [=wire =road:tarball mark=(unit mark)]
  =/  m  (fiber ,~)
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
  =/  m  (fiber ,~)
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
    ?~  err.u.in
      [%done ~]
    [%fail %keep-failed u.err.u.in]
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
  |*  [=mold =wire =path]
  =/  m  (fiber ,mold)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %scry wire `[mold path])
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %scry * *]
    ?.  =(wire wire.u.in)
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
::
++  build-tube
  |=  [[=ship =desk =case] =mars:clay]
  =*  arg  +<
  =/  m  (fiber ,tube:clay)
  ^-  form:m
  ;<  =riot:clay  bind:m
    (warp ship desk ~ %sing %c case /[a.mars]/[b.mars])
  ?~  riot
    (fiber-fail leaf+<['build-tube' arg]> ~)
  ?>  =(%tube p.r.u.riot)
  (pure:m !<(tube:clay q.r.u.riot))
::
++  build-tube-soft
  |=  [[=ship =desk =case] =mars:clay]
  =/  m  (fiber ,(unit tube:clay))
  ^-  form:m
  ;<  =riot:clay  bind:m
    (warp ship desk ~ %sing %c case /[a.mars]/[b.mars])
  ?~  riot
    (pure:m ~)
  ?>  =(%tube p.r.u.riot)
  (pure:m `!<(tube:clay q.r.u.riot))
::  +try-build-tube: build a single tube, trying our desk first then %base
::
++  try-build-tube
  |=  [our=@p =desk =case =mars:clay]
  =/  m  (fiber ,(unit tube:clay))
  ^-  form:m
  ;<  tube=(unit tube:clay)  bind:m
    (build-tube-soft [our desk case] mars)
  ?^  tube
    (pure:m tube)
  (build-tube-soft [our %base case] mars)
::  +build-file-soft: compile a source file, return unit vase
::
++  build-file-soft
  |=  [[=ship =desk =case] =spur]
  =/  m  (fiber ,(unit vase))
  ^-  form:m
  ;<  =riot:clay  bind:m
    (warp ship desk ~ %sing %a case spur)
  ?~  riot
    (pure:m ~)
  ?>  =(%vase p.r.u.riot)
  (pure:m `!<(vase q.r.u.riot))
::  +build-dais-soft: build a dais for a mark, return unit
::
++  build-dais-soft
  |=  [[=ship =desk =case] mak=mark]
  =/  m  (fiber ,(unit dais:clay))
  ^-  form:m
  ;<  =riot:clay  bind:m
    (warp ship desk ~ %sing %b case /[mak])
  ?~  riot
    (pure:m ~)
  ?>  =(%dais p.r.u.riot)
  (pure:m `!<(dais:clay q.r.u.riot))
::  +list-marks: list mark files from desk's /mar directory
::
++  list-marks
  |=  [=ship =desk =case]
  =/  m  (fiber ,(list path))
  ^-  form:m
  ;<  =riot:clay  bind:m
    (warp ship desk ~ %sing %t case /mar)
  ?~  riot
    (pure:m ~)
  (pure:m !<((list path) q.r.u.riot))
::  +en-fit: convert /mar/foo/.../bar/hoon path to mark name
::
++  en-fit
  |=  =path
  ^-  @tas
  =.  path  ?>(?=([%mar *] path) (flop t.path))
  =.  path  ?>(?=([%hoon *] path) (flop t.path))
  (rap 3 (join '-' path))
::  +get-mark-arms: inspect a mark core vase for grab/grow arm names
::
++  get-mark-arms
  |=  =vase
  ^-  [grab=(list mark) grow=(list mark)]
  :-  ?.  (slob %grab -:vase)  ~
      (sloe -:(slap vase [%limb %grab]))
  ?.  (slob %grow -:vase)  ~
  (sloe -:(slap vase [%limb %grow]))
::  +mark-pairs: discover all conversion pairs from a mark core
::
++  mark-pairs
  |=  all-marks=(set mark)
  |=  [=path =vase]
  ^-  (list mars:clay)
  =/  fit=mark  (en-fit path)
  =/  [grab=(list mark) grow=(list mark)]
    (get-mark-arms vase)
  ;:  weld  [fit fit]~
    (murn grab |=(=mark ?.((~(has in all-marks) mark) ~ `[mark fit])))
    (murn grow |=(=mark ?.((~(has in all-marks) mark) ~ `[fit mark])))
  ==
::  +build-all-files: compile all mark cores from a list of paths
::
++  build-all-files
  |=  [verb=? =ship =desk =case paths=(list path)]
  =/  cores=(map path vase)  ~
  |-
  =/  m  (fiber ,(map path vase))
  ^-  form:m
  =*  loop  $
  ?~  paths  (pure:m cores)
  ;<  vus=(unit vase)  bind:m
    (build-file-soft [ship desk case] i.paths)
  ?~  vus
    ~?  >>>  verb  [%warm-build-failed i.paths]
    loop(paths t.paths)
  ~?  >  verb  [%warm-built i.paths]
  loop(paths t.paths, cores (~(put by cores) i.paths u.vus))
::  +build-all-tubes: warm all tube conversions
::
++  build-all-tubes
  |=  [verb=? =ship =desk =case mars=(list mars:clay)]
  |-
  =/  m  (fiber ,~)
  ^-  form:m
  =*  loop  $
  ?~  mars  (pure:m ~)
  ;<  tub=(unit tube:clay)  bind:m
    (build-tube-soft [ship desk case] i.mars)
  ~?  >  verb  ?~(tub [%warm-tube-failed i.mars] [%warm-tube i.mars])
  loop(mars t.mars)
::  +build-all-dais: warm all dais validators
::
++  build-all-dais
  |=  [verb=? =ship =desk =case marks=(list mark)]
  |-
  =/  m  (fiber ,~)
  ^-  form:m
  =*  loop  $
  ?~  marks  (pure:m ~)
  ;<  das=(unit dais:clay)  bind:m
    (build-dais-soft [ship desk case] i.marks)
  ~?  >  verb  ?~(das [%warm-dais-failed i.marks] [%warm-dais i.marks])
  loop(marks t.marks)
::  +warm-tubes: pre-warm all tube and dais caches for a desk
::  Call from root nexus on-load to ensure Clay caches are hot
::
++  warm-tubes
  |=  verb=?
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  our=@p   bind:m  get-our
  ;<  =desk    bind:m  get-desk
  ;<  now=@da  bind:m  get-time
  ::  List mark files from /mar
  ;<  paths=(list path)  bind:m  (list-marks our desk %da now)
  =.  paths  (turn (skim (turn paths flop) |=(=path ?=([%hoon *] path))) flop)
  ::  Build all mark cores
  ;<  cores=(map path vase)  bind:m
    (build-all-files verb our desk da+now paths)
  ::  Discover all mark conversion pairs
  =/  marks=(list mark)  (turn paths en-fit)
  =/  all-marks=(set mark)  (sy marks)
  =/  mars=(list mars:clay)
    %~  tap  in
    %-  ~(gas in *(set mars:clay))
    %-  zing
    %+  turn  ~(tap by cores)
    (mark-pairs all-marks)
  ::  Warm all tubes
  ;<  ~  bind:m  (build-all-tubes verb our desk da+now mars)
  ::  Warm all dais
  ;<  ~  bind:m  (build-all-dais verb our desk da+now marks)
  ~&  >  [%warm-complete tubes+(lent mars) dais+(lent marks)]
  (pure:m ~)
::  +collect-marks: collect all marks used in cages within a ball (deep)
::
++  collect-marks
  |=  =ball:tarball
  ^-  (set mark)
  =/  marks=(set mark)  ~
  ::  Collect marks from current node's contents
  =?  marks  ?=(^ fil.ball)
    =/  entries=(list (pair @ta content:tarball))
      ~(tap by contents.u.fil.ball)
    |-  ^-  (set mark)
    ?~  entries  marks
    =*  content  q.i.entries
    ?:  =(%temp p.cage.content)
      $(entries t.entries)
    $(entries t.entries, marks (~(put in marks) p.cage.content))
  ::  Recurse into subdirectories
  =/  subdirs=(list (pair @ta ball:tarball))  ~(tap by dir.ball)
  |-  ^-  (set mark)
  ?~  subdirs  marks
  =/  submarks=(set mark)  ^$(ball q.i.subdirs)
  $(subdirs t.subdirs, marks (~(uni in marks) submarks))
::  +collect-marks-shallow: collect marks only from immediate files (no recurse)
::
++  collect-marks-shallow
  |=  =ball:tarball
  ^-  (set mark)
  ?~  fil.ball  ~
  =/  entries=(list (pair @ta content:tarball))
    ~(tap by contents.u.fil.ball)
  =/  marks=(set mark)  ~
  |-  ^-  (set mark)
  ?~  entries  marks
  =*  ct  q.i.entries
  ?:  =(%temp p.cage.ct)
    $(entries t.entries)
  $(entries t.entries, marks (~(put in marks) p.cage.ct))
::  +build-mark-conversions: build conversions map for a set of marks
::
++  build-mark-conversions
  |=  marks=(set mark)
  =/  m  (fiber ,(map mars:clay tube:clay))
  ^-  form:m
  ;<  our=@p  bind:m  get-our
  ;<  =desk  bind:m  get-desk
  ;<  now=@da  bind:m  get-time
  =/  mark-list=(list mark)  ~(tap in marks)
  =/  conversions=(map mars:clay tube:clay)  ~
  |-  ^-  form:m
  ?~  mark-list
    (pure:m conversions)
  =/  =mars:clay  [i.mark-list %mime]
  ;<  tube-result=(unit tube:clay)  bind:m
    (try-build-tube our desk da+now mars)
  =?  conversions  ?=(^ tube-result)
    (~(put by conversions) mars u.tube-result)
  $(mark-list t.mark-list)
::  +get-mark-conversions: build mark conversions for all marks in ball (deep)
::
++  get-mark-conversions
  |=  =ball:tarball
  =/  m  (fiber ,(map mars:clay tube:clay))
  ^-  form:m
  (build-mark-conversions (collect-marks ball))
::  +get-mark-conversions-shallow: build conversions for immediate files only
::
++  get-mark-conversions-shallow
  |=  =ball:tarball
  =/  m  (fiber ,(map mars:clay tube:clay))
  ^-  form:m
  (build-mark-conversions (collect-marks-shallow ball))
::  +cage-to-mime: convert cage to mime, falling back to jam
::
++  cage-to-mime
  |=  =cage
  =/  m  (fiber ,mime)
  ^-  form:m
  ?:  =(%mime p.cage)
    (pure:m !<(mime q.cage))
  ?:  =(%temp p.cage)
    (pure:m [/text/plain (as-octs:mimes:html (crip (noah q.cage)))])
  ;<  our=@p  bind:m  get-our
  ;<  =desk  bind:m  get-desk
  ;<  now=@da  bind:m  get-time
  =/  =mars:clay  [p.cage %mime]
  ;<  tube=(unit tube:clay)  bind:m
    (try-build-tube our desk [%da now] mars)
  ?~  tube
    (pure:m [/application/octet-stream (as-octs:mimes:html (jam q.cage))])
  =/  result=(each vase tang)  (mule |.((u.tube q.cage)))
  ?:  ?=(%| -.result)
    (pure:m [/application/octet-stream (as-octs:mimes:html (jam q.cage))])
  =/  extracted  (mule |.(!<(mime p.result)))
  ?:  ?=(%| -.extracted)
    (pure:m [/application/octet-stream (as-octs:mimes:html (jam q.cage))])
  (pure:m p.extracted)
::  Gall agent operations (via syscalls)
::
++  gall-poke
  |=  [=wire =dock =cage]
  =/  m  (fiber ,~)
  ^-  form:m
  =/  =card:agent:gall  [%pass wire %agent dock %poke cage]
  ;<  ~  bind:m  (send-card card)
  (take-gall-poke-ack wire)
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
  ;<  =bowl:nexus  bind:m  (get-bowl /sleep)
  (wait (add now.bowl for))
::  Convenience bowl accessors
::
++  get-our
  =/  m  (fiber ,ship)
  ^-  form:m
  ;<  =bowl:nexus  bind:m  (get-bowl /get-our)
  (pure:m our.bowl)
::
++  get-time
  =/  m  (fiber ,@da)
  ^-  form:m
  ;<  =bowl:nexus  bind:m  (get-bowl /get-time)
  (pure:m now.bowl)
::
++  get-entropy
  =/  m  (fiber ,@uvJ)
  ^-  form:m
  ;<  =bowl:nexus  bind:m  (get-bowl /get-entropy)
  (pure:m eny.bowl)
::
++  get-here
  =/  m  (fiber ,rail:tarball)
  ^-  form:m
  ;<  =bowl:nexus  bind:m  (get-bowl /get-here)
  (pure:m here.bowl)
::
++  get-agent
  =/  m  (fiber ,dude:gall)
  ^-  form:m
  ;<  =bowl:nexus  bind:m  (get-bowl /get-agent)
  (pure:m dap.bowl)
::
++  get-beak
  =/  m  (fiber ,beak)
  ^-  form:m
  ;<  =bowl:nexus  bind:m  (get-bowl /get-beak)
  (pure:m byk.bowl)
::
++  get-desk
  =/  m  (fiber ,desk)
  ^-  form:m
  ;<  =bowl:nexus  bind:m  (get-bowl /get-desk)
  (pure:m q.byk.bowl)
::
++  get-case
  =/  m  (fiber ,case)
  ^-  form:m
  ;<  =bowl:nexus  bind:m  (get-bowl /get-case)
  (pure:m r.byk.bowl)
::  HTTP client (iris) helpers
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
  (gall-poke /poke [our dude] cage)
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
--
