::  fiberio: helper functions for nexus fibers
::
::  +nonce: tag a wire with an entropy suffix to prevent stale matches.
::
::  Problem: fiber wires (/poke, /peek, etc.) are static labels. Within
::  an uninterrupted run this is fine — fibers are sequential. But if a
::  fiber crashes and restarts, a stale response from the previous run
::  can match the restarted fiber's take-* arm on the same wire.
::
::  Fix: nonce tags each wire with entropy so stale responses from a
::  previous run get %skip'd. e.g. /poke → /poke/0v1a.2b3c4
::
::  Nonce uses get-entropy which does a raw send-dart poke to
::  /sys/bowl with a static /sys/eny wire. This avoids infinite recursion
::  (nonce → get-entropy → poke → nonce → ...) since poke calls nonce.
::  The static /sys/eny wire is safe because both stale and fresh
::  responses return valid entropy — consuming the "wrong" one still
::  produces a unique random nonce.
::
::  Subscriptions (keep/drop) are unaffected — caller-provided wires
::  are stable identifiers, and re-keep on restart is idempotent
::  (sub-put overwrites, wave-at re-sends initial state).
::
::  TODO: vase-free queue storage
::
::  Intakes that carry vases (%poke, %peek, %peep, %code) are stored
::  in the fiber's skip queue as-is. Vases contain type nouns from the
::  build that produced them. After a code reload, queued vases have
::  stale types that don't match the new subject — handing these to a
::  fiber can cause type mismatches or silent corruption.
::
::  Fix: split intake into a queue-safe form (nouns only, no vases) and
::  a fiber-facing form (with vases). On enqueue, strip vases to
::  [blot noun] (bask). On dequeue, re-vale the noun against the
::  current type. Affected intakes:
::    %poke — sage [blot vase] → bask [blot noun], re-vale on dequeue
::    %peek — sang [blot reus] → [blot noun], re-vale on dequeue
::    %peep — list of [cass sage] → [cass bask], re-vale on dequeue
::    %code — built can be [%vase vase] → store as noun, re-vale
::  Unaffected: %made/%gone/%pack/%sand/%load/%lost/%gain/%held (just
::  wire+tang), %fell (wire), %news (wave), %here (pant), %veto (dart),
::  %font (bend), %kept (set bend).
::

/-  push
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
  ==
::
++  send-darts
  |=  darts=(list dart)
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  [darts q.state %done ~]
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
  [~ q.state %fail err]
::
++  get-state
  =/  m  (fiber ,vase)
  ^-  form:m
  |=  input
  [~ q.state %done state]
::
++  get-state-as
  |*  a=mold
  =/  m  (fiber ,a)
  ^-  form:m
  |=  input
  [~ q.state %done ;;(a q.state)]
::
++  gut-state-as
  |*  a=mold
  |=  gut=$-(tang a)
  =/  m  (fiber ,a)
  ^-  form:m
  |=  input
  =/  res  (mule |.(;;(a q.state)))
  ?-  -.res
    %&  [~ q.state %done p.res]
    %|  [~ q.state %done (gut p.res)]
  ==
::
++  replace
  |=  new=*
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
  [~ q:(f state) %done ~]
::  Wait for any input and return it for manual switching
::
++  get-input
  =/  m  (fiber ,(unit intake))
  ^-  form:m
  |=  input
  [~ q.state %done in]
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
::  Finds the nearest ancestor with the given neck (e.g. [/claw %agent])
::  via find-in-here, then builds a road to the given lane within it.
::  Works from any depth — no hardcoded offsets needed.
::
++  ancestor-road
  |=  [=neck:tarball =lane:tarball]
  =/  m  (fiber ,road:tarball)
  ^-  form:m
  ;<  =wire  bind:m  (nonce /ancestor)
  ;<  ~  bind:m  (send-dart %here wire)
  ;<  =here:nexus  bind:m  (take-here-raw wire)
  =/  steps=(unit @ud)  (find-in-here here `neck)
  ?~  steps
    ~&  >>>  ["fiberio: couldn't find ancestor" neck]
    (pure:m [%& lane])
  (pure:m [%| u.steps lane])
::  +nex-road: pure road from current rail to nexus-relative lane
::
::  Computes the relative road from the current file's rail to a
::  nexus-relative destination lane. No fiber IO needed.
::
++  nex-road
  |=  [here=rail:tarball target=lane:tarball]
  ^-  road:tarball
  [%| (lent path.here) target]
::
++  take-here-raw
  |=  =wire
  =/  m  (fiber ,here:nexus)
  ^-  form:m
  |=  input
  :+  ~  q.state
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
  ;<  =wire  bind:m  (nonce /kept)
  ;<  ~  bind:m  (send-dart %kept wire)
  (take-kept wire)
::
++  take-kept
  |=  =wire
  =/  m  (fiber ,kept:nexus)
  ^-  form:m
  |=  input
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %kept * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    [%done kept.u.in]
  ==
::  On crash recovery (prod is [~ tang]), log the error and wait for a
::  poke to restart (expect %sig). On clean start (prod is ~), continue.
::  Use at the top of a process to make it restartable:
::    ;<  ~  bind:m  (rise-wait prod "my-process: failed")
::    ::  startup code continues here
::
++  rise-wait
  |=  [=prod:fiber:nexus msg=tape]
  =/  m  (fiber ,~)
  ^-  form:m
  ?~  prod  (pure:m ~)
  %-  (slog leaf+msg u.prod)
  ;<  =sage:tarball  bind:m  take-poke
  ?:  =([/ %sig] p.sage)
    (pure:m ~)
  (trace leaf+"strange restart mark: {<p.sage>}" ~)
::
++  take-poke
  =/  m  (fiber ,sage:tarball)
  ^-  form:m
  |=  input
  :+  ~  q.state
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
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %poke * *]
    [%done [from sage]:u.in]
  ==
::  +get-poke-src: extract foreign ship from a poke's from field
::
::  Remote pokes arrive through /sys/ames/ships/~ship/ in the
::  namespace, so from is always %& (a bend).  This checks the
::  rail path for that prefix and returns the ship if found.
::
++  get-poke-src
  |=  =from:fiber:nexus
  ^-  (unit @p)
  ?.  ?=(%& -.from)  ~
  =/  pax=path  path.q.p.from
  ?.  ?=([%sys %ames %ships @ *] pax)  ~
  (slaw %p i.t.t.t.pax)
::
++  take-made
  |=  =wire
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  :+  ~  q.state
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
  :+  ~  q.state
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
  :+  ~  q.state
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
  ;<  =wire  bind:m  (nonce /make)
  ;<  ~  bind:m  (send-dart %node wire road %make %.n make)
  (take-made wire)
::
++  make-soft
  |=  [=road:tarball =make:nexus]
  =/  m  (fiber ,(unit tang))
  ^-  form:m
  ;<  =wire  bind:m  (nonce /make)
  ;<  ~  bind:m  (send-dart %node wire road %make %.n make)
  |=  input
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %made * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    [%done err.u.in]
  ==
::
++  poke
  |=  [=road:tarball =bask:tarball]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  =wire  bind:m  (nonce /poke)
  ;<  ~  bind:m  (send-dart %node wire road %poke bask)
  (take-pack wire)
::  +checkpoint: promote current state to %firm
::
++  checkpoint
  |=  =rail:tarball
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  =wire  bind:m  (nonce /firm)
  ;<  ~  bind:m
    (send-dart %node wire &+&+rail %firm ~)
  (take-pack wire)
::
++  peek
  |=  [=road:tarball blot=(unit blot:tarball)]
  =/  m  (fiber ,seen:nexus)
  ^-  form:m
  ;<  =wire  bind:m  (nonce /peek)
  ;<  ~  bind:m  (send-dart %node wire road %peek blot ~ %.y)
  (take-peek wire)
::
::  Shallow peek: files at this level, subdir names only (no recursion)
::
++  peek-shallow
  |=  [=road:tarball blot=(unit blot:tarball)]
  =/  m  (fiber ,seen:nexus)
  ^-  form:m
  ;<  =wire  bind:m  (nonce /peek)
  ;<  ~  bind:m  (send-dart %node wire road %peek blot ~ %.n)
  (take-peek wire)
::
::  Peek at a historical version of a file
::
++  peek-at
  |=  [=road:tarball blot=(unit blot:tarball) =case:nexus]
  =/  m  (fiber ,seen:nexus)
  ^-  form:m
  ;<  =wire  bind:m  (nonce /peek)
  ;<  ~  bind:m  (send-dart %node wire road %peek blot `case %.y)
  (take-peek wire)
::
::  Peek a remote ship. Constructs a road targeting
::  /sys/ames/ships/[ship]/root/[path] so the grubbery routes
::  the peek cross-ship via the namespace.
::
++  peek-remote
  |=  [=road:tarball =@p case=(unit case:nexus)]
  =/  m  (fiber ,seen:nexus)
  ^-  form:m
  =/  remote-road=road:tarball
    ?-  -.road
        %|  road  :: relative roads pass through as-is
        %&
      =/  prefix=path  /sys/ames/ships/[(scot %p p)]/root
      ?-  -.p.road
          %&  :: file: [path name] → /sys/ames/ships/[ship]/root/[path] name
        [%& %& (weld prefix path.p.p.road) name.p.p.road]
          %|  :: dir: path → /sys/ames/ships/[ship]/root/[path]
        [%& %| (weld prefix p.p.road)]
      ==
    ==
  ;<  =wire  bind:m  (nonce /peek)
  ;<  ~  bind:m  (send-dart %node wire remote-road %peek ~ case %.y)
  (take-peek wire)
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
++  cull
  |=  =road:tarball
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  =wire  bind:m  (nonce /cull)
  ;<  ~  bind:m  (send-dart %node wire road %cull ~)
  |=  input
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %gone * *]
    ?.  =(wire wire.u.in)
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
  ;<  =wire  bind:m  (nonce /cull)
  ;<  ~  bind:m  (send-dart %node wire road %cull ~)
  |=  input
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %gone * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    [%done err.u.in]
  ==
::
++  sand
  |=  [=road:tarball weir=(unit weir:nexus)]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  =wire  bind:m  (nonce /sand)
  ;<  ~  bind:m  (send-dart %node wire road %sand weir)
  |=  input
  :+  ~  q.state
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
++  gain
  |=  [=road:tarball flag=?]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  =wire  bind:m  (nonce /gain)
  ;<  ~  bind:m  (send-dart %node wire road %gain flag)
  |=  input
  :+  ~  q.state
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
  |=  [=road:tarball =lose:nexus]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  =wire  bind:m  (nonce /lose)
  ;<  ~  bind:m  (send-dart %node wire road %lose lose)
  |=  input
  :+  ~  q.state
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
  |=  [=road:tarball =lobe:clay]
  =/  m  (fiber ,(each (list [=rail:tarball =cass:clay]) tang))
  ^-  form:m
  ;<  =wire  bind:m  (nonce /seek)
  ;<  ~  bind:m  (send-dart %node wire road %seek lobe)
  |=  input
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %seek * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    [%done res.u.in]
  ==
::
++  peep
  |=  [=road:tarball =find:nexus]
  =/  m  (fiber ,(each (list [=cass:clay =sage:tarball]) tang))
  ^-  form:m
  ;<  =wire  bind:m  (nonce /peep)
  ;<  ~  bind:m  (send-dart %node wire road %peep find)
  |=  input
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %peep * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    [%done res.u.in]
  ==
::
++  over
  |=  [=road:tarball =bask:tarball]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  =wire  bind:m  (nonce /make)
  ;<  ~  bind:m  (send-dart %node wire road %make %.y |+[bask ~])
  (take-made wire)
::
++  reload
  |=  =road:tarball
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  =wire  bind:m  (nonce /load)
  ;<  ~  bind:m  (send-dart %node wire road %load ~)
  |=  input
  :+  ~  q.state
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
  |=  [=wire =road:tarball blot=(unit blot:tarball)]
  =/  m  (fiber ,wave:nexus)
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
  (take-news wire)
::
++  take-fell
  |=  =wire
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  :+  ~  q.state
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
  =/  m  (fiber ,wave:nexus)
  ^-  form:m
  |=  input
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %news * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    [%done wave.u.in]
  ==
::  Typed scry via /sys/scry/ runtime service
::
::  Scries a vane path and returns the result validated through
::  the specified mark. The mark must have a marc in the code
::  namespace so hydration can validate the response.
::
++  typed-scry
  |*  [=mold mark=@tas =path]
  =/  m  (fiber ,mold)
  ^-  form:m
  ;<  ~  bind:m
    (poke &+&+[/sys/scry %'main.sig'] [[/ %scry-request] [mark `^path`path]])
  |=  input
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %poke * *]
    ?.  =([/ mark] p.sage.u.in)  [%skip ~]
    [%done !<(mold q.sage.u.in)]
  ==
::  Clay convenience helpers
::
++  clay-case
  |=  dek=desk
  =/  m  (fiber ,cass:clay)
  ^-  form:m
  (typed-scry cass:clay %clay-case /cw/[dek])
::
++  clay-exists
  |=  [dek=desk pax=path]
  =/  m  (fiber ,?)
  ^-  form:m
  (typed-scry ? %loob (weld /cu/[dek] pax))
::
++  clay-read
  |=  [dek=desk pax=path]
  =/  m  (fiber ,*)
  ^-  form:m
  (typed-scry * %noun (weld /cx/[dek] pax))
::
++  clay-tree
  |=  [dek=desk pax=path]
  =/  m  (fiber ,(list path))
  ^-  form:m
  (typed-scry (list path) %clay-tree [%ct dek pax])
::  Create a new desk via /sys/clay/ runtime service
::
++  create-desk
  |=  dek=desk
  =/  m  (fiber ,~)
  ^-  form:m
  (poke &+&+[/sys/clay %'main.clay-state'] [[/ %new-desk] dek])
::  Write/delete files in a Clay desk via /sys/clay/ runtime service.
::  No vases — the runtime clams through marks on the destination desk.
::
++  clay-info
  |=  [dek=desk changes=(list [path ?([%ins @tas *] [%del ~])])]
  =/  m  (fiber ,~)
  ^-  form:m
  (poke &+&+[/sys/clay %'main.clay-state'] [[/ %clay-info] [dek changes]])
::  Send a belt to a dill session via /sys/dill/ runtime service
::
++  send-belt
  |=  [session=@tas =belt:dill]
  =/  m  (fiber ,~)
  ^-  form:m
  (poke &+&+[/sys/dill %'main.sig'] [[/ %dill-belt] [session belt]])
::  +get-code: peek the code (bins) slice at a road
::
++  get-code
  |=  =road:tarball
  =/  m  (fiber ,(unit vase))
  ^-  form:m
  ;<  =wire  bind:m  (nonce /code)
  ;<  ~  bind:m  (send-dart %node wire road %code ~)
  (take-code wire)
::
++  take-code
  |=  =wire
  =/  m  (fiber ,(unit vase))
  ^-  form:m
  |=  input
  :+  ~  q.state
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
  ;<  =wire  bind:m  (nonce /code)
  ;<  ~  bind:m  (send-dart %node wire road %code ~)
  |=  input
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %code * *]
    ?.  =(wire wire.u.in)
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
  ;<  =wire  bind:m  (nonce /code)
  ;<  ~  bind:m  (send-dart %node wire road %code ~)
  |=  input
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %code * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    ?.  ?=(%& -.res.u.in)
      [%skip ~]
    [%done p.res.u.in]
  ==
::  +get-font: find code responsible for a node
::  ~: blocked (weir), [~ ~]: definitively none, [~ ~ bend]: found
::
++  get-font
  |=  =road:tarball
  =/  m  (fiber ,(unit (unit bend:tarball)))
  ^-  form:m
  ;<  =wire  bind:m  (nonce /font)
  ;<  ~  bind:m  (send-dart %node wire road %font ~)
  |=  input
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %font * *]
    ?.  =(wire wire.u.in)
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
    =/  entries=(list [@ta [=sang:tarball gain=? bang=(unit tang)]])
      ~(tap by contents.u.fil.ball)
    |-  ^-  (set blot:tarball)
    ?~  entries  blots
    $(entries t.entries, blots (~(put in blots) p.sang.i.entries))
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
  =/  entries=(list [@ta [=sang:tarball gain=? bang=(unit tang)]])
    ~(tap by contents.u.fil.ball)
  =/  blots=(set blot:tarball)  ~
  |-  ^-  (set blot:tarball)
  ?~  entries  blots
  $(entries t.entries, blots (~(put in blots) p.sang.i.entries))
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
    (poke &+&+[/sys/gall %'main.sig'] [[/ %gall-poke] [dock page]])
  |=  input
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %pack *]
    ?~  err.u.in  [%done ~]
    [%fail %poke-failed u.err.u.in]
  ==
::  Timer helpers — poke /sys/behn/main.timer-state, receive timer-wake back
::
++  set-timer
  |=  [=wire until=@da]
  =/  m  (fiber ,~)
  ^-  form:m
  (poke &+&+[/sys/behn %'main.timer-state'] [[/ %timer-set] `[^wire @da]`[wire until]])
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
  :+  ~  q.state
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
  ;<  ~  bind:m
    (poke &+&+[/sys/bowl %'main.sig'] [[/ %bowl-req] %our])
  ;<  =sage:tarball  bind:m  take-poke
  (pure:m !<(ship q.sage))
::
++  get-time
  =/  m  (fiber ,@da)
  ^-  form:m
  ;<  ~  bind:m
    (poke &+&+[/sys/bowl %'main.sig'] [[/ %bowl-req] %now])
  ;<  =sage:tarball  bind:m  take-poke
  (pure:m !<(@da q.sage))
::  get-entropy uses raw send-dart with a static /sys/eny wire to avoid
::  recursion: poke → nonce → get-entropy → poke. Static wire is safe
::  because stale entropy is still valid entropy.
::
++  get-entropy
  =/  m  (fiber ,@uvJ)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node /sys/eny &+&+[/sys/bowl %'main.sig'] %poke [[/ %bowl-req] %eny])
  |=  input
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %pack *]
    [%wait ~]
      [~ %poke * *]
    ?.  =([/ %entropy] p.sage.u.in)  [%skip ~]
    [%done !<(@uvJ q.sage.u.in)]
  ==
::
++  nonce
  |=  base=wire
  =/  m  (fiber ,wire)
  ^-  form:m
  ;<  eny=@uvJ  bind:m  get-entropy
  (pure:m (snoc base (scot %uv (end 5 eny))))
::
++  get-here
  =/  m  (fiber ,here:nexus)
  ^-  form:m
  ;<  =wire  bind:m  (nonce /here)
  ;<  ~  bind:m  (send-dart %here wire)
  (take-here-raw wire)
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
  (poke &+&+[/sys/iris %'main.iris-state'] [[/ %iris-request] request])
::
++  take-client-response
  =/  m  (fiber ,client-response:iris)
  ^-  form:m
  |=  input
  :+  ~  q.state
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
::  Push notification helpers
::  Sends via /sys/push/ runtime service.
::
++  push-road  `road:tarball`[%& %& /sys/push %'main.push-state']
::
++  send-push
  |=  =push-send:push
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  eny=@uvJ  bind:m  get-entropy
  (poke push-road [[/ %push-action] `push-action:nexus`[%send push-send eny]])
::
++  init-push
  |=  sub=@t
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  eny=@uvJ  bind:m  get-entropy
  (poke push-road [[/ %push-action] `push-action:nexus`[%init eny sub]])
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
    (poke &+&+[/sys/gall %'main.sig'] [[/ %gall-poke] [[our dude] page]])
  |=  input
  :+  ~  q.state
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
  $%  [%news =wave:nexus]
      [%wake ~]
  ==
::
++  take-news-or-wake
  |=  news-wire=wire
  =/  m  (fiber ,news-or-wake)
  ^-  form:m
  |=  input
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %news * *]
    ?.  =(news-wire wire.u.in)
      [%skip ~]
    [%done %news wave.u.in]
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
  (make dst |+[[p.sang.p.seen (sang-noun:tarball sang.p.seen)] ~])
::  +copy-fold: copy a directory from src to dst
::
++  copy-fold
  |=  [src=road:tarball dst=road:tarball]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  =seen:nexus  bind:m  (peek src ~)
  ?.  ?=([%& %ball *] seen)
    ~|(%copy-fold-src-not-found !!)
  (make dst &+(ball-to-bole:tarball ball.p.seen))
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
  (poke server-road [[/ %eyre-action] act])
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
    (poke main [[/ %eyre-action] `eyre-action:nexus`[%send eyre-id eyre-update]])
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
    ;<  ~  bind:m  (make [%| 0 %& /requests eyre-id] |+[[[/ %http-request] [src req]] ~])
    $
      %handle-http-cancel
    =/  eyre-id=@ta  !<(@ta q.sage)
    ~&  >  [label %cancel eyre-id]
    ;<  ~  bind:m  (cull [%| 0 %& /requests eyre-id])
    $
      %eyre-action
    ;<  ~  bind:m  (poke server-road [p.sage q.q.sage])
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
