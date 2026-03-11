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
  |=  [=wire =road:tarball =make:nexus]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node wire road %make make)
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
  ;<  ~  bind:m  (send-dart %node wire road %peek mark ~ %.n)
  (take-peek wire)
::
::  Peek at a historical version of a file
::
++  peek-at
  |=  [=wire =road:tarball mark=(unit mark) =case:nexus]
  =/  m  (fiber ,seen:nexus)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node wire road %peek mark `case %.n)
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
++  set-gain
  |=  [=wire =road:tarball flag=?]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node wire road %gain flag)
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %gain * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    ?~  err.u.in
      [%done ~]
    [%fail %gain-failed u.err.u.in]
  ==
::
++  lose
  |=  [=wire =road:tarball =lose:nexus]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node wire road %lose lose)
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %lost * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    ?~  err.u.in
      [%done ~]
    [%fail %lose-failed u.err.u.in]
  ==
::
++  seek
  |=  [=wire =road:tarball =lobe:clay]
  =/  m  (fiber ,(list [=rail:tarball =cass:clay]))
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node wire road %seek lobe)
  |=  input
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %found * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    [%done hits.u.in]
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
::  +get-tube: look up a cached tube from /bin/tubes/
::
++  get-tube
  |=  =mars:clay
  =/  m  (fiber ,(unit tube:clay))
  ^-  form:m
  =/  =road:tarball  [%& %& /bin/tubes/[a.mars] b.mars]
  ;<  =seen:nexus  bind:m  (peek /tube road ~)
  ?.  ?=([%& %file *] seen)
    (pure:m ~)
  (pure:m `!<(tube:clay q.cage.p.seen))
::  +get-dais: look up a cached dais from /bin/daises/
::
++  get-dais
  |=  mak=mark
  =/  m  (fiber ,(unit dais:clay))
  ^-  form:m
  =/  =road:tarball  [%& %& /bin/daises mak]
  ;<  =seen:nexus  bind:m  (peek /dais road ~)
  ?.  ?=([%& %file *] seen)
    (pure:m ~)
  (pure:m `!<(dais:clay q.cage.p.seen))
::  +get-nexus: look up a cached nexus from /bin/nexuses/
::
++  get-nexus
  |=  neck=@tas
  =/  m  (fiber ,(unit nexus:nexus))
  ^-  form:m
  =/  =road:tarball  [%& %& /bin/nexuses neck]
  ;<  =seen:nexus  bind:m  (peek /nexus road ~)
  ?.  ?=([%& %file *] seen)
    (pure:m ~)
  (pure:m `!<(nexus:nexus q.cage.p.seen))
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
  =/  mark-list=(list mark)  ~(tap in marks)
  =/  conversions=(map mars:clay tube:clay)  ~
  |-  ^-  form:m
  ?~  mark-list
    (pure:m conversions)
  =/  =mars:clay  [i.mark-list %mime]
  ;<  tube-result=(unit tube:clay)  bind:m
    (get-tube mars)
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
    (pure:m [/application/x-urb-jam (as-octs:mimes:html (jam q.cage))])
  =/  =mars:clay  [p.cage %mime]
  ;<  tube=(unit tube:clay)  bind:m
    (get-tube mars)
  ?~  tube
    (pure:m [/application/x-urb-jam (as-octs:mimes:html (jam q.cage))])
  =/  result=(each vase tang)  (mule |.((u.tube q.cage)))
  ?:  ?=(%| -.result)
    (pure:m [/application/x-urb-jam (as-octs:mimes:html (jam q.cage))])
  =/  extracted  (mule |.(!<(mime p.result)))
  ?:  ?=(%| -.extracted)
    (pure:m [/application/x-urb-jam (as-octs:mimes:html (jam q.cage))])
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
