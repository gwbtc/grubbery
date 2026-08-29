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
  ~|  %real-input-to-oneshot-step
  ?>  =(~ in)
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
  ~|  %real-input-to-oneshot-step
  ?>  =(~ in)
  [~ q.state %done state]
::
++  get-state-as
  |*  a=mold
  =/  m  (fiber ,a)
  ^-  form:m
  |=  input
  ~|  %real-input-to-oneshot-step
  ?>  =(~ in)
  [~ q.state %done ;;(a q.state)]
::
++  gut-state-as
  |*  a=mold
  |=  gut=$-(tang a)
  =/  m  (fiber ,a)
  ^-  form:m
  |=  input
  ~|  %real-input-to-oneshot-step
  ?>  =(~ in)
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
  ~|  %real-input-to-oneshot-step
  ?>  =(~ in)
  [~ new %done ~]
::
++  transform
  |=  f=$-(vase vase)
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  ^-  output:m
  ~|  %real-input-to-oneshot-step
  ?>  =(~ in)
  [~ q:(f state) %done ~]
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
::  poke to restart. On clean start (prod is ~), continue.
::  Any poke restarts the process — %sig is the convention; a non-sig
::  poke logs a warning but restarts anyway, and its payload is
::  consumed (the restarted process never sees it).
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
::    from: bend (relative path to sender)
::    sage: the poke payload
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
::  namespace, so the bend path starts with /sys/ames/ships/~ship/.
::
++  get-poke-src
  |=  =from:fiber:nexus
  ^-  (unit @p)
  =/  pax=path  path.q.from
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
  =/  m  (fiber ,view:nexus)
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
    [%done view.u.in]
  ==
::  File operations: make, poke, peek, cull, sand
::
++  make
  |=  [=road:tarball =make:nexus]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  =wire  bind:m  (nonce /make)
  ;<  ~  bind:m  (send-dart %node wire road %make %.n %.n make)
  (take-made wire)
::  +make-gained: make born with gain set — retention on from the
::  first event. No make-then-gain window for a fast process's
::  self-clean to slip through.
::
++  make-gained
  |=  [=road:tarball =make:nexus]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  =wire  bind:m  (nonce /make)
  ;<  ~  bind:m  (send-dart %node wire road %make %.n %.y make)
  (take-made wire)
::
++  make-gained-soft
  |=  [=road:tarball =make:nexus]
  =/  m  (fiber ,(unit tang))
  ^-  form:m
  ;<  =wire  bind:m  (nonce /make)
  ;<  ~  bind:m  (send-dart %node wire road %make %.n %.y make)
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
++  make-soft
  |=  [=road:tarball =make:nexus]
  =/  m  (fiber ,(unit tang))
  ^-  form:m
  ;<  =wire  bind:m  (nonce /make)
  ;<  ~  bind:m  (send-dart %node wire road %make %.n %.n make)
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
::  +poke: poke a road, local or remote. Crashes on nack.
::
++  poke
  |=  [=road:tarball =bask:tarball]
  =/  m  (fiber ,~)
  ^-  form:m
  ?~  (road-to-remote road)
    ;<  =wire  bind:m  (nonce /poke)
    ;<  ~  bind:m  (send-dart %node wire road %poke bask)
    (take-pack wire)
  ;<  err=(unit tang)  bind:m  (poke-soft road bask)
  ?~  err  (pure:m ~)
  ~|(%remote-poke-failed (mean u.err))
::  +poke-soft: poke a road, local or remote — ~ on ack, `tang on
::  nack. Never crashes.
::
::    Carries no deadline of its own: local pokes are covered by the
::    termination guarantee, and a remote pack arrives when the network
::    delivers it. A caller unwilling to wait wraps this in
::    +with-timeout.
::
::    Completion is a framework %pack on our wire, whether the target was
::    local or on another ship — a cross-ship poke's pack comes back over
::    the network and is re-injected as a %pack by +process-pack.
::
++  poke-soft
  |=  [=road:tarball =bask:tarball]
  =/  m  (fiber ,(unit tang))
  ^-  form:m
  ;<  =wire  bind:m  (nonce /poke)
  ;<  ~  bind:m  (send-dart %node wire road %poke bask)
  ::  local OR remote: the consumption result arrives as a %pack on our
  ::  wire. A cross-ship poke's pack comes back over the network and is
  ::  re-injected as a %pack by +process-pack — no local/remote fork.
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %pack * *]
    ?.  =(wire wire.u.in)  [%skip ~]
    ?~  err.u.in  [%done ~]
    [%done `u.err.u.in]
  ==
::  +take-held: wait for a %held response on a wire
::
++  take-held
  |=  =wire
  =/  m  (fiber ,~)
  ^-  form:m
  |=  input
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %held * *]
    ?.  =(wire wire.u.in)
      [%skip ~]
    ?~  err.u.in
      [%done ~]
    [%fail %held-failed u.err.u.in]
  ==
::  +checkpoint: promote current hist entry to %firm.
::  Takes a road: file dests firm the file hist, directory dests
::  firm the fold hist (whose pace lobe is the subtree merkle root).
::
++  checkpoint
  |=  =road:tarball
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  =wire  bind:m  (nonce /firm)
  ;<  ~  bind:m
    (send-dart %node wire road %firm ~)
  (take-held wire)
::  +tag: set tags on a hist entry (file or fold, per road)
::
++  tag
  |=  [=road:tarball cas=(unit case:nexus) tags=(set @t)]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  =wire  bind:m  (nonce /tag)
  ;<  ~  bind:m
    (send-dart %node wire road %tag cas tags)
  (take-held wire)
::
++  peek
  |=  [=road:tarball blot=(unit blot:tarball)]
  =/  m  (fiber ,view:nexus)
  ^-  form:m
  ;<  =wire  bind:m  (nonce /peek)
  ;<  ~  bind:m  (send-dart %node wire road %peek blot ~ %.y)
  (take-peek wire)
::
::  Peek a file and extract its value as a typed noun.
::  Crashes if file not found or wrong type.
::
++  peek-as
  |*  [=road:tarball a=mold]
  =/  m  (fiber ,(unit a))
  ^-  form:m
  ;<  res=view:nexus  bind:m  (peek road ~)
  ?.  ?=([%file *] res)
    (pure:m ~)
  (pure:m `!<(a (need-vase:tarball sang.res)))
::
::  Shallow peek: files at this level, subdir names only (no recursion)
::
++  peek-shallow
  |=  [=road:tarball blot=(unit blot:tarball)]
  =/  m  (fiber ,view:nexus)
  ^-  form:m
  ;<  =wire  bind:m  (nonce /peek)
  ;<  ~  bind:m  (send-dart %node wire road %peek blot ~ %.n)
  (take-peek wire)
::
::  Peek at a historical version of a file
::
++  peek-at
  |=  [=road:tarball blot=(unit blot:tarball) =case:nexus]
  =/  m  (fiber ,view:nexus)
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
  =/  m  (fiber ,view:nexus)
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
  ;<  =view:nexus  bind:m  (peek road ~)
  (pure:m !?=(?(%none %miss %veto %tomb) -.view))
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
      ::  soft: a vetoed cull returns the veto as an error, it does
      ::  NOT crash the caller (that is what +cull is for) — the
      ::  poke-soft precedent
      [~ %veto *]
    [%done `(veto-error dart.u.in)]
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
  |=  [=road:tarball =nobe:nexus]
  =/  m  (fiber ,(each (list [=rail:tarball =cass:clay]) tang))
  ^-  form:m
  ;<  =wire  bind:m  (nonce /seek)
  ;<  ~  bind:m  (send-dart %node wire road %seek nobe)
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
::  +born: read hist metadata at dest — file (%&) or fold (%|).
::  Pure metadata: revision, tags, tombstone flag per entry.
::
++  born
  |=  =road:tarball
  =/  m  (fiber ,(each (list [=cass:clay tags=(set @t) tomb=?]) tang))
  ^-  form:m
  ;<  =wire  bind:m  (nonce /born)
  ;<  ~  bind:m  (send-dart %node wire road %born ~)
  |=  input
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %born * *]
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
  ;<  ~  bind:m  (send-dart %node wire road %make %.y %.n |+[bask ~])
  (take-made wire)
::  +over-as: overwrite with a blot override — the runtime tubes
::  the given bask to the target blot and validates at destination.
::
++  over-as
  |=  [=road:tarball =bask:tarball =blot:tarball]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  =wire  bind:m  (nonce /make)
  ;<  ~  bind:m  (send-dart %node wire road %make %.y %.n |+[bask `blot])
  (take-made wire)
::
::  +put: overwrite if exists, create if not
::
++  put
  |=  [=road:tarball =bask:tarball]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  exists=?  bind:m  (peek-exists road)
  ?:  exists
    (over road bask)
  (make road |+[bask ~])
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
::  Remote-scry farm operations, via the /sys/scry service.
::
::  Requests are ordinary pokes to the service grub, so weirs gate
::  them like any /sys reach: a sandboxed grub (whose weir does not
::  grant /sys) is vetoed by default, and no special-case gating
::  exists anywhere. gall consumes the resulting %grow/%tomb/%cull
::  cards directly and signs nothing back, so all three complete
::  fire-and-forget on the service %pack.
::
::  +grow: publish a page at spur in this ship's remote-scry farm.
::
++  grow
  |=  [=spur =page]
  =/  m  (fiber ,~)
  ^-  form:m
  (poke &+&+[/sys/scry %'main.sig'] [[/ %scry-grow] [`path`spur page]])
::  +tomb: tombstone revision case of a published spur. The bound
::  content is replaced by its hash; the binding stays. gall honors
::  only %ud cases, so the revision rides bare.
::
++  tomb
  |=  [case=@ud =spur]
  =/  m  (fiber ,~)
  ^-  form:m
  (poke &+&+[/sys/scry %'main.sig'] [[/ %scry-tomb] [case `path`spur]])
::  +cull-farm: retract EVERY case bound at a published spur.
::
::  NOT +cull. +cull above deletes a node from the nexus TREE; this
::  deletes bindings from gall's scry FARM, a different namespace.
::
::  Use this, not +tomb, to unpublish: gall assigns key+1 on every
::  %grow at an already-bound spur, so a regrown spur answers at
::  several cases and tombing one leaves the rest readable.
::
::  NOT idempotent, and this is the one sharp edge: gall keeps the
::  emptied binding after a cull, and the follow-up top-case read
::  misses uncatchably (see +farm-top in the agent). Gate a second
::  cull of the same spur on whatever record says the thing still
::  exists. A spur that was never grown is a silent no-op.
::
++  cull-farm
  |=  =spur
  =/  m  (fiber ,~)
  ^-  form:m
  (poke &+&+[/sys/scry %'main.sig'] [[/ %scry-cull] `path`spur])
::  +keen: read a path from a remote ship's farm via remote scry.
::
::  Returns the remote's answer as a (unit page): `[mark noun]` is
::  the content bound at the path, ~ means the remote bound nothing.
::  ames verifies the publisher's signature before it reaches us, and
::  the answer hydrates through the %keen-response mark like any poke
::  (signed but arbitrary content: consumers validate the page's noun
::  against their own expected shape before trusting its structure).
::  Carries no deadline of its own — ames holds
::  the request until the remote answers, which may be never. A
::  caller unwilling to wait wraps this in +with-timeout, and yawns
::  the request it abandoned.
::
::  The answer arrives as an ordinary %keen-response poke-back from
::  the /sys/scry service (the iris idiom), correlated by our wire.
::
++  keen
  |=  [=ship =path]
  =/  m  (fiber ,(unit page))
  ^-  form:m
  ;<  =wire  bind:m  (nonce /keen)
  ;<  ~  bind:m
    (poke &+&+[/sys/scry %'main.sig'] [[/ %scry-keen] [ship `^path`path wire]])
  |=  input
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %poke * *]
    ?.  =([/ %keen-response] p.sage.u.in)  [%skip ~]
    =/  [ret=^wire pag=(unit page)]  !<([^wire (unit page)] q.sage.u.in)
    ?.  =(wire ret)  [%skip ~]
    [%done pag]
  ==
::  +yawn: cancel this grub's outstanding +keens for [ship path].
::  Precise: the service records each keen's wire and cancels by
::  duct, so other grubs parked on the same spar (the longpoll
::  pattern) stay parked. Fire-and-forget.
::
++  yawn
  |=  [=ship =path]
  =/  m  (fiber ,~)
  ^-  form:m
  (poke &+&+[/sys/scry %'main.sig'] [[/ %scry-yawn] [ship `^path`path]])
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
::  Local IPC (lick vane, via /sys/lick/ runtime service)
::
::  +lick-spin: open a local IPC port. vere serves the socket at
::  <pier>/.urb/dev/grubbery/<name>. Inbound messages materialize at
::  /sys/lick/<name>/in as [seq=@ud =mark noun=*] (seq bumps per message
::  so identical payloads still fire a wave); connection state at
::  /sys/lick/<name>/live. keep the in-grub and take-news to react.
::
++  lick-spin
  |=  [name=path gained=?]
  =/  m  (fiber ,~)
  ^-  form:m
  (poke &+&+[/sys/lick %'main.sig'] [[/ %lick-spin] name gained])
::  +lick-shut: close a local IPC port and delete its /sys/lick tree
::
++  lick-shut
  |=  name=path
  =/  m  (fiber ,~)
  ^-  form:m
  (poke &+&+[/sys/lick %'main.sig'] [[/ %lick-shut] name])
::  +lick-spit: send [mark noun] to the client connected to a port
::
++  lick-spit
  |=  [name=path =mark noun=*]
  =/  m  (fiber ,~)
  ^-  form:m
  (poke &+&+[/sys/lick %'main.sig'] [[/ %lick-spit] name mark noun])
::  +lick-handler: the gate a +lick-serve app supplies — maps an HTTP-like
::  request [verb path query body] to a fibered [status body] reply.
++  lick-handler
  =/  m  (fiber ,[status=@ud rbody=@t])
  $-([verb=@t path=@t query=@t body=@t] form:m)
::  +lick-serve: a request/response server over a lick port. Spins the socket
::  (owner-only, ungained), keeps its inbound grub, and for each inbound frame
::  decodes [mark [verb path query body]], calls `handler`, and spits back
::  [%res [status body]]. Generic — the app supplies only `handler`, an
::  HTTP-like dispatcher; auth is filesystem-presence (the socket lives in the
::  pier). Requests are assumed synchronous (one in flight), so no seq de-dup.
::  Wire (per man/lick-echo): 0x00 + LE-u32 len + jam([mark noun]). The runtime
::  types the inbound noun as *, so it is extracted generally then clammed to the
::  request tuple — a direct !< to the specific shape nest-fails on the *.
++  lick-serve
  |=  [name=path handler=lick-handler]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  ~  bind:m  (lick-spin name |)
  ;<  *  bind:m  (keep /in [%& %& (weld /sys/lick name) %in] ~)
  |-
  ;<  *  bind:m  (take-news /in)
  ;<  =view:nexus  bind:m  (peek [%& %& (weld /sys/lick name) %in] ~)
  ?.  ?=([%file *] view)  $
  =/  raw=(unit [seq=@ud mark=@tas noun=*])
    (mole |.(!<([seq=@ud mark=@tas noun=*] (need-vase:tarball sang.view))))
  ?~  raw  $
  =/  req=(unit [verb=@t path=@t query=@t body=@t])
    (mole |.(;;([@t @t @t @t] noun.u.raw)))
  ?~  req  $
  ;<  [status=@ud rbody=@t]  bind:m  (handler u.req)
  ::  skip the reply if the client has already disconnected — a killed/timed-out
  ::  client would otherwise draw a runtime "not connected" error on the spit.
  ::  /live is advisory, so only a definitive %.n suppresses; anything else spits.
  ;<  live=view:nexus  bind:m  (peek [%& %& (weld /sys/lick name) %live] ~)
  =/  gone=?
    ?.  ?=([%file *] live)  |
    =(| (fall (mole |.(!<(? (need-vase:tarball sang.live)))) &))
  ?:  gone  $
  ;<  ~  bind:m  (lick-spit name %res [status rbody])
  $
::  Gall agent operations (via /sys/gall/ runtime service)
::
++  gall-poke
  |=  [=dock =page]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  =wire  bind:m  (nonce /gall-poke)
  ;<  ~  bind:m
    (send-dart %node wire &+&+[/sys/gall %'main.sig'] %poke [[/ %gall-poke] [dock page]])
  ::  the /sys/gall grub consumes our request first (%pack on our wire),
  ::  then the gall agent's ack comes back as a wire-keyed [/ %poke-ack].
  ;<  ~  bind:m  (take-pack wire)
  |=  input
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %poke * *]
    ?.  =([/ %poke-ack] p.sage.u.in)  [%skip ~]
    =/  [w=^wire err=(unit tang)]  !<([^wire (unit tang)] q.sage.u.in)
    ?.  =(wire w)  [%skip ~]
    ?~  err  [%done ~]
    [%fail %poke-failed u.err]
  ==
::  +road-to-remote: parse a /sys/ames/ships/ road into the target ship
::  and the real lane on that ship, mirroring the runtime's
::  +resolve-remote. ~ for local roads.
::
++  road-to-remote
  |=  =road:tarball
  ^-  (unit [target=@p dest=lane:tarball])
  ?.  ?=(%& -.road)  ~
  =/  pax=path
    ?-(-.p.road %& path.p.p.road, %| p.p.road)
  ?.  ?=([%sys %ames %ships @ %root *] pax)  ~
  =/  target=(unit @p)  (slaw %p i.t.t.t.pax)
  ?~  target  ~
  =/  real=path  t.t.t.t.t.pax
  :-  ~  :-  u.target
  ?-(-.p.road %& [%& real name.p.p.road], %| [%| real])
::  Timer helpers — poke /sys/behn/main.behn-state, receive timer-wake back
::
++  set-timer
  |=  [=wire until=@da]
  =/  m  (fiber ,~)
  ^-  form:m
  (poke &+&+[/sys/behn %'main.behn-state'] [[/ %timer-set] `[^wire @da]`[wire until]])
::
::  +cancel-timer: cancel a timer set with +set-timer on the same wire.
::  No-op if it already fired — a wake for it may still be in flight,
::  so intakes must scope wakes by wire regardless.
::
++  cancel-timer
  |=  =wire
  =/  m  (fiber ,~)
  ^-  form:m
  (poke &+&+[/sys/behn %'main.behn-state'] [[/ %timer-rest] `^wire`wire])
::
++  send-wait
  |=  until=@da
  =/  m  (fiber ,~)
  ^-  form:m
  ::  STABLE wire: a restarted fiber's next sleep replaces its old
  ::  behn-state entry instead of accumulating one orphan timer per
  ::  restart (the reboot fetch-herd bug). behn-state rests the
  ::  superseded arvo timer and drops stale in-flight wakes, so any
  ::  delivered /wait wake is the current one.
  (set-timer /wait until)
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
    ::  behn-state validates wakes against its state, so no da check
    ::  here; [%wait @ ~] still matches old-format in-flight wakes
    ?.  ?=([%wait *] wak)
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
::  +with-timeout: run any fiber computation against a deadline.
::  Returns `value on completion, ~ on timeout — the caller decides
::  what a timeout means; this arm has no policy of its own.
::
::  The timer is scoped to /timeout/[wire] and checked against the
::  wire a wake carries in its sage, so another timer's wake can never
::  satisfy it (the stray-wake loop that got poke-soft's timer deleted
::  in 3c1c61b). The wire is caller-supplied and durable: a restarted
::  fiber re-runs the same code with the same wire, so its new timer
::  REPLACES the abandoned one (set-on-same-wire semantics) instead of
::  orphaning it. Nested timeouts need distinct wires — the caller
::  writes both levels, so that's theirs to ensure. On completion —
::  value or failure — the timer is cancelled.
::
::  The interception must survive the computation's own stepping:
::  on %cont the continuation is re-wrapped so every subsequent input
::  still passes through the timeout check first (strandio's
::  +set-timeout idiom).
::
++  with-timeout
  |*  result=mold
  =/  m   (fiber ,(unit result))
  =/  mr  (fiber ,result)
  |=  [=wire time=@dr computation=form:mr]
  ^-  form:m
  =.  wire  (weld /timeout wire)
  ;<  now=@da  bind:m  get-time
  ;<  ~        bind:m  (set-timer wire (add now time))
  |=  input
  ^-  output:m
  ::  our own deadline fired before the computation finished
  ?:  ?&  ?=([~ %poke * *] in)
          =([/ %timer-wake] p.sage.u.in)
          =(wire !<(^wire q.sage.u.in))
      ==
    [~ q.state %done ~]
  =/  c-res=output:mr  (computation +<)
  ?:  ?=(%cont -.next.c-res)
    [darts.c-res state.c-res %cont ..$(computation self.next.c-res)]
  ?:  ?=(%done -.next.c-res)
    =/  fin=form:m
      ;<  ~  bind:m  (cancel-timer wire)
      (pure:m `value.next.c-res)
    [darts.c-res state.c-res %cont fin]
  ?:  ?=(%fail -.next.c-res)
    =/  err=tang  err.next.c-res
    =/  fin=form:m
      ;<  ~  bind:m  (cancel-timer wire)
      |=  input
      [~ q.state %fail err]
    [darts.c-res state.c-res %cont fin]
  :+  darts.c-res  state.c-res
  ?-  -.next.c-res
    %wait  [%wait ~]
    %skip  [%skip ~]
  ==
::  Convenience accessors
::
::  Bowl reads (+get-our/+get-time/+get-entropy) poke /sys/bowl.sig and
::  get back TWO inputs in either order: the %pack ack of the poke and
::  the response poke. Both must be consumed. The old matchers only
::  drained a pack that arrived FIRST; a response-first ordering left
::  the ack stray, skipping past every wire-scoped matcher into the
::  terminal — invisible while +idle ate strays, a crash-nack per call
::  under honest +stay. +take-bowl consumes exactly one of each.
::
++  take-bowl
  |*  a=mold
  |=  =blot:tarball
  =/  m  (fiber ,a)
  ^-  form:m
  ;<  got=(each a ~)  bind:m
    =/  mi  (fiber ,(each a ~))
    ^-  form:mi
    |=  input
    :+  ~  q.state
    ?+  in  [%skip ~]
        ~  [%wait ~]
        [~ %veto *]
      [%fail (veto-error dart.u.in)]
        [~ %pack *]
      [%done %| ~]
        [~ %poke * *]
      ?.  =(blot p.sage.u.in)  [%skip ~]
      [%done %& !<(a q.sage.u.in)]
    ==
  ?:  ?=(%| -.got)
    ::  ack first: now take the response
    =/  mr  (fiber ,a)
    ^-  form:mr
    |=  input
    :+  ~  q.state
    ?+  in  [%skip ~]
        ~  [%wait ~]
        [~ %poke * *]
      ?.  =(blot p.sage.u.in)  [%skip ~]
      [%done !<(a q.sage.u.in)]
    ==
  ::  response first: drain the trailing ack (ours — a fiber is
  ::  sequential, so no other un-acked dart of ours is outstanding)
  ;<  ~  bind:m
    =/  md  (fiber ,~)
    ^-  form:md
    |=  input
    :+  ~  q.state
    ?+  in  [%skip ~]
        ~  [%wait ~]
        [~ %pack *]
      [%done ~]
    ==
  (pure:m p.got)
::
++  get-our
  =/  m  (fiber ,ship)
  ^-  form:m
  ;<  =wire  bind:m  (nonce /sys/our)
  ;<  ~  bind:m  (send-dart %node wire &+&+[/sys %'bowl.sig'] %poke [[/ %bowl-req] %our])
  ((take-bowl ship) [/ %ship])
::
++  get-time
  =/  m  (fiber ,@da)
  ^-  form:m
  ;<  =wire  bind:m  (nonce /sys/now)
  ;<  ~  bind:m  (send-dart %node wire &+&+[/sys %'bowl.sig'] %poke [[/ %bowl-req] %now])
  ((take-bowl @da) [/ %time])
::  get-entropy uses raw send-dart with a static /sys/eny wire to avoid
::  recursion: poke → nonce → get-entropy → poke. Static wire is safe
::  because stale entropy is still valid entropy.
::
++  get-entropy
  =/  m  (fiber ,@uvJ)
  ^-  form:m
  ;<  ~  bind:m  (send-dart %node /sys/eny &+&+[/sys %'bowl.sig'] %poke [[/ %bowl-req] %eny])
  ((take-bowl @uvJ) [/ %entropy])
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
::  Notification service helpers — the human-addressed message bus
::  at /apps/notifications.notifications. Register once (a registrant
::  covers its directory subtree), then notify; payload jobj is
::  opaque (title/body/url are conventions). The service owns
::  delivery (push) and ack tracking.
::
++  notify-road
  `road:tarball`[%& %& /apps/[%'notifications.notifications'] %'main.sig']
::
++  register-app
  |=  name=@t
  =/  m  (fiber ,~)
  ^-  form:m
  %+  poke  notify-road
  :-  [/ %json]
  (pairs:enjs:format ~[['action' s+'register'] ['name' s+name]])
::
++  notify
  |=  [push=? metadata=json]
  =/  m  (fiber ,~)
  ^-  form:m
  %+  poke  notify-road
  :-  [/ %json]
  %-  pairs:enjs:format
  :~  ['action' s+'notify']
      ['push' s+?:(push 'true' 'false')]
      ['metadata' metadata]
  ==
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
  ;<  =wire  bind:m  (nonce /gall-poke)
  ;<  ~  bind:m
    (send-dart %node wire &+&+[/sys/gall %'main.sig'] %poke [[/ %gall-poke] [[our dude] page]])
  ;<  ~  bind:m  (take-pack wire)
  |=  input
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error dart.u.in)]
      [~ %poke * *]
    ?.  =([/ %poke-ack] p.sage.u.in)  [%skip ~]
    =/  [w=^wire err=(unit tang)]  !<([^wire (unit tang)] q.sage.u.in)
    ?.  =(wire w)  [%skip ~]
    [%done err]
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
  ;<  =view:nexus  bind:m  (peek src ~)
  ?.  ?=([%file *] view)
    ~|(%copy-grub-src-not-found !!)
  (make dst |+[[p.sang.view (sang-noun:tarball sang.view)] ~])
::  +copy-fold: copy a directory from src to dst
::
++  copy-fold
  |=  [src=road:tarball dst=road:tarball]
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek src ~)
  ?.  ?=([%ball *] view)
    ~|(%copy-fold-src-not-found !!)
  (make dst &+(ball-to-bole:tarball ball.view))
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
::  +bind-http-self: bind requests to THIS grub, letting the kernel use the
::  poke's source rail. Avoids get-here-abs — so a nexus serving its own UI
::  needs no walk to root (no peek /). Use this unless you're binding a route
::  on behalf of some other grub.
::
++  bind-http-self
  |=  =binding:eyre
  =/  m  (fiber ,~)
  ^-  form:m
  ::  veto-tolerant: a jailed app (fresh install, weir not yet approved)
  ::  gets its eyre poke vetoed at rise. Crashing here would park the
  ::  whole fiber; instead log it and continue — the fiber lands in its
  ::  normal request loop, and the approval reload re-runs this bind
  ::  with grants in hand.
  ::  fixed wire, no nonce: nonce needs entropy (a /sys/bowl.sig poke)
  ::  which is itself vetoed in jail — the crash would land before the
  ::  tolerant take below. One bind per fiber; no collision.
  =/  =wire  /bind-self
  ;<  ~  bind:m  (send-dart %node wire server-road %poke [[/ %eyre-action] [%bind-self binding]])
  |=  input
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    %.  [%done ~]
    (slog leaf+"bind-http-self: vetoed (sandboxed?) — binding deferred until approval" ~)
      [~ %pack * *]
    ?.  =(wire wire.u.in)  [%skip ~]
    [%done ~]
  ==
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
::  HTTP response helpers. Sends poke server-road directly: the
::  /sys/eyre intercept consumes %send in the sending event, so the
::  dispatcher relay (main.sig) only added an eval cycle plus a second
::  validation of the response. Nothing consumes from=main.sig (cancel
::  routing is conns -> %handle-http-cancel -> dispatcher cull), and
::  the dispatcher's %eyre-action branch stays for direct pokes. The
::  door sample is retained so existing call sites compile unchanged.
::  Usage: =/  srv  ~(. http-res:io [%| 1 %& ~ %'main.sig'])
::         (send-simple:srv eyre-id payload)
::
++  http-res
  |_  main=road:tarball
  ++  send
    |=  [eyre-id=@ta =eyre-update:nexus]
    =/  m  (fiber ,~)
    ^-  form:m
    (poke server-road [[/ %eyre-action] `eyre-action:nexus`[%send eyre-id eyre-update]])
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
    ;<  ~  bind:m  (make [%| 0 %& /requests eyre-id] |+[[[/ %http-request] [src req]] ~])
    $
      %handle-http-cancel
    =/  eyre-id=@ta  !<(@ta q.sage)
    ;<  ~  bind:m  (cull [%| 0 %& /requests eyre-id])
    $
      %eyre-action
    ;<  ~  bind:m  (send-dart %node / server-road %poke [p.sage q.q.sage])
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
::  Usergroup registry helpers.
::
++  reg-road  `road:tarball`[%& %& /sys/ames %'registry']
++  reg-blot  `blot:tarball`[/usergroups %registry-action]
::
++  reg-poke
  |=  act=registry-action:nexus
  =/  m  (fiber ,~)
  ^-  form:m
  (poke reg-road [reg-blot act])
::
++  reg-register
  =/  m  (fiber ,~)
  ^-  form:m
  ;<  here=rail:tarball  bind:m  get-here-abs
  (reg-poke [%register here path.here])
::  +reg-register-at: register a caller-supplied rail (e.g. from its grant
::  via here-abs:sh) instead of walking to root — lets a granted app
::  register with no peek /. Niladic +reg-register stays for callers that
::  want the trustless walk.
++  reg-register-at
  |=  here=rail:tarball
  =/  m  (fiber ,~)
  ^-  form:m
  (reg-poke [%register here path.here])
::
++  reg-how
  |=  [group=path =weir:nexus]
  =/  m  (fiber ,~)
  ^-  form:m
  (reg-poke [%how group weir])
--
