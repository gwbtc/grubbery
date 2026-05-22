/-  push
/+  tarball
|%
+$  card  card:agent:gall
+$  built
  $%  [%vase =vase]
      [%tang =tang]
      [%mime =mime]
  ==
+$  keys  (map rail:tarball @uv)
+$  deps  (map rail:tarball (set rail:tarball))
+$  refs  (axal (map @ta @uv))
+$  lode  [=keys =deps =refs]
+$  code  (map fold:tarball lode)
+$  bins  (map @uv [refs=@ud =built])
::  The ball (tarball) is WYSIWYG: fully materialized, no dedup.
::  Every file is stored inline. To deduplicate, make references
::  via path+cass rather than copying content.
::
::  A "grub" is the entity that lives at a rail: its file content and
::  its running process, considered as one thing. You create, delete,
::  poke, and watch grubs. When the distinction matters, "file" means
::  the data (content + metadata) and "process" means the running fiber.
::
::  Grubs live in directories. Directories hold grubs and other
::  directories, may have a neck identifying a nexus, and may have a weir
::  (sandbox rules).
::
+$  prov  [src=@p sap=path]         :: external provenance
+$  from  (each rail:tarball prov)  :: source: [%& rail] internal grub or [%| prov] external
+$  give  [=from =wire]             :: return address (from is always a grub)
+$  take  [here=rail:tarball take:fiber]  :: localized input (here is always a grub)
::  SANDBOXING
::
::  Darts are conceptually emitted by processes and travel up the tree
::  to the nearest common ancestor with their destination, then down to
::  the destination. Downward movement is always legal. Upward movement
::  (or darts to self) must pass through weir filters at each directory.
::
::  Each weir specifies allowed destination prefixes for make/poke/peek.
::  If a dart's destination matches any allowed prefix, it passes.
::  If no weir exists at a directory, there's no filter (permissive).
::  Any weir can veto a dart; vetoed darts become %veto intakes.
::
::  filt results:
::    ~       no filter at this level (permissive)
::    [~ &]   filtered and allowed (should clam vases)
::    [~ |]   filtered and blocked (veto the dart)
::
+$  weir
  $:  make=(set road:tarball)  :: allowed destinations for %make, %cull, %sand
      poke=(set road:tarball)  :: allowed destinations for %poke
      peek=(set road:tarball)  :: allowed destinations for %peek
  ==
+$  sand  (axal weir)   :: weir at each directory in the tree
+$  filt  (unit ?)      :: filter result (see above)
+$  jump  ?(%make %poke %peek)  :: dart category for filtering
::
::  pant: ancestry list from outermost dir to innermost, each with
::  its optional neck. here: grub's location in the tree. root=%.y
::  means the walk reached the tarball root; root=%.n means a weir
::  blocked visibility before reaching root (pant is truncated).
+$  pant  (list [dir=@ta neck=(unit neck:tarball)])
+$  here  [=pant name=@ta root=?]
::
+$  gain  (axal (map @ta ?))
+$  make  (each [=sand =gain =ball:tarball] [gain=? =sage:tarball blot=(unit blot:tarball)])
+$  kept  (set bend:tarball)
::
+$  view
  $%  [%ball =sand =gain =born ball=ball:tarball]
      [%file =hist gain=? =sage:tarball]
      [%none ~]
  ==
+$  seen  (each view tang)
:: dart payload
::
+$  case  $%([%ud p=@ud] [%da p=@da])
+$  lose
  $%  [%pick cass=(set cass:clay)]       :: drop specific versions
      [%date from=(unit @da) to=(unit @da)]  :: drop date range (~ = open-ended)
      [%numb from=(unit @ud) to=(unit @ud)]  :: drop number range (~ = open-ended)
  ==
+$  find  lose
+$  load
  $%  [%poke =sage:tarball]      :: poke a grub
      [%make =make]                    :: create grub or directory
      [%over =sage:tarball]     :: overwrite grub content (runtime mark conversion)
      [%cull ~]                 :: delete grub or directory
      [%sand weir=(unit weir)]  :: set weir
      [%load ~]                 :: trigger on-load for a nexus (folds only)
      [%gain flag=?]            :: set gain flag (recursive on directories)
      [%peek blot=(unit blot:tarball) case=(unit case) clam=?]
                                       :: read a grub
                                       :: blot: convert file sage to this blot
                                       :: case: if set, read historical version
      [%keep blot=(unit blot:tarball)]  :: subscribe to changes at dest (grub or ball per road)
                                       :: blot: if set, convert file sage in news
      [%drop ~]                 :: unsubscribe from dest
      [%lose =lose]             :: drop hist entries, decrement silo refs
      [%seek =lobe:clay]        :: find all [rail cass] pairs with this hash
      [%peep =find]
      [%manu ~]                 :: docs for this path (road resolves nexus + query)
      [%bang ~]                 :: query error state at dest
      [%code ~]                 :: look up compiled artifacts at dest
      [%font ~]                 :: find code responsible for dest node
  ==
::  manu types — documentation query
::
+$  mury  [=rail:tarball =blot:tarball]   :: file query: rail + blot
+$  mana  (each fold:tarball mury)       :: directory or file query
::
::
+$  dart
  $%  [%node =wire road=road:tarball =load]
      [%here =wire]
      [%kept =wire]              :: see your own outgoing subscriptions
      [%manu =wire =neck:tarball =mana]  :: direct docs query to a known nexus
  ==
::  Eyre action: poke payload for HTTP binding/response operations.
::  Nexuses poke %grubbery with %eyre-action to register bindings
::  and send HTTP responses.
::
+$  eyre-action
  $%  [%bind =binding:eyre handler=rail:tarball]
      [%unbind =binding:eyre]
      [%send eyre-id=@ta =eyre-update]
  ==
::
+$  eyre-update
  $%  [%header =response-header:http]
      [%data data=(unit octs)]
      [%kick ~]
      [%simple =simple-payload:http]
  ==
::  Eyre state: binding registry + active connection tracking.
::  Stored as a grub at /sys/eyre/main.server-state.
::
+$  server-state
  $:  %0
      bindings=(map binding:eyre rail:tarball)
      conns=(map @ta binding:eyre)
  ==
::  Timer service state.
::  Stored as a grub at /sys/behn/main.timer-state.
::
+$  timer-state
  [%0 timers=(map [=rail:tarball =wire] @da)]
::  Iris HTTP client service state.
::  Stored as a grub at /sys/iris/main.iris-state.
::
+$  iris-state
  [%0 requests=(map wire [sender=rail:tarball url=@t])]
::  Push notification service state.
::  Stored as a grub at /sys/push/main.push-state.
::
+$  push-sub  [=ship =subscription:push]
+$  push-state
  $:  %0
      config=(unit push-config:push)
      subs=(map @ta push-sub)
      inflight=(map wire rail:tarball)
  ==
+$  push-action
  $%  [%subscribe sub-id=@ta =ship =subscription:push]
      [%unsubscribe sub-id=@ta]
      [%send =push-send:push eny=@]
      [%init eny=@ sub=@t]
  ==
::  Clay desk sync service state.
::  Stored as a grub at /sys/clay/main.clay-state.
::  Desk mirrors live at /sys/clay/desks/[desk]/.
::
+$  clay-state
  [%0 desks=(set desk)]
::
++  fiber
  |%
  +$  proc
    $:  process=(each process tang)  :: running fiber or crash error
        next=(qeu take)              :: queue of held inputs
        skip=(qeu take)              :: queue of skipped inputs
    ==
  ::  Relative source path for pokes
  ::
  ::  Fibers see only relative paths so they don't know their absolute location.
  ::  [%& bend] = internal source (relative path to a grub)
  ::  [%| prov] = external source (ship + path)
  ::
  ::  Fiber bends always target grubs (rail), not directories.
  ::  Pokes come from grubs, pokes go to grubs.
  ::
  +$  bend  (pair @ud rail:tarball)   :: fiber-relative: steps up + target grub
  +$  from  (each bend prov)
  +$  road  (each rail:tarball bend)
  ::
  +$  intake
    $%  [%poke =from =sage:tarball] :: command for a running process (from is relative)
        [%peek =wire =seen] :: local read result
        [%kept =wire =kept]              :: your outgoing subscriptions
        [%made =wire err=(unit tang)] :: response to make
        [%gone =wire err=(unit tang)] :: response to cull
        [%pack =wire err=(unit tang)] :: response from poke; tang is generic if not allowed to peek
        [%sand =wire err=(unit tang)] :: response to sand
        [%load =wire err=(unit tang)] :: response to load
        [%gain =wire err=(unit tang)] :: response to gain
        [%lost =wire err=(unit tang)] :: response to lose
        [%seek =wire res=(each (list [=rail:tarball =cass:clay]) tang)] :: response to seek
        [%peep =wire res=(each (list [=cass:clay =sage:tarball]) tang)] :: response to peep
        [%manu =wire res=(each @t tang)] :: response to manu
        [%bang =wire res=(each bangs (unit tang))]  :: directory bangs or file error
        [%over =wire err=(unit tang)] :: response to over (content overwrite)
        [%writ ~] :: notify grub its file was externally modified by %over
        [%bond =wire now=seen] :: subscription ack with initial view
        [%fell =wire]                 :: subscription canceled (weir change, deletion, etc)
        [%news =wire =view] :: state notification
        [%veto =dart] :: notify that a dart was sandboxed
        [%code =wire res=(each (axal (map @ta built)) built)]  :: code subtree or single artifact
        [%font =wire res=(unit bend:tarball)]  :: bend to governing /code namespace
        [%here =wire =here]
    ==
  ::
  +$  input
    $:  state=vase       :: state for which we are responsible
        in=(unit intake) :: command/response/data to ingest (null means start)
    ==
  ::
  +$  take  [=give in=(unit intake)]
  :: Three situations for process initialization
  ::
  +$  prod
    $%  [%make ~]     :: making new file
        [%load ~]     :: nexus was reloaded
        [%rise =tang] :: failed while running
    ==
  ::
  ++  output-raw
    |*  value=mold
    $~  [~ *vase %done *value]
    $:  darts=(list dart)
        state=vase
        $=  next
        $%  [%wait ~] :: process intake and await next
            [%skip ~] :: queue intake and await next
            [%cont self=(form-raw value)] :: continue to next computation
            [%fail err=tang] :: return failure
            [%done =value]   :: return result
        ==
    ==
  ::
  ++  form-raw
    |*  value=mold
    $-(input (output-raw value))
  ::
  +$  process  _*form:(fiber ,~)
  +$  spool    $-(prod process)    :: initializer - takes prod, returns process
  ::
  ++  fiber
    |*  value=mold
    |%
    ++  output  (output-raw value)
    ++  form    (form-raw value)
    :: give value; leave state unchanged
    ::
    ++  pure
      |=  =value
      ^-  form
      |=  input
      ^-  output
      [~ state %done value]
    :: do nothing - forever
    ::
    ++  stay
      ^-  form
      |=  input
      ^-  output
      ?~  in  [~ state %wait ~]
      [~ state %skip ~]
    ::
    ++  bind
      |*  b=mold
      |=  [m-b=(form-raw b) fun=$-(b form)]
      ^-  form
      |=  =input
      =/  b-res=(output-raw b)  (m-b input)
      ^-  output
      :-  darts.b-res
      :-  state.b-res
      ?-    -.next.b-res
        %wait  [%wait ~]
        %skip  [%skip ~]
        %cont  [%cont ..$(m-b self.next.b-res)]
        %fail  [%fail err.next.b-res]
        %done  [%cont (fun value.next.b-res)]
      ==
    --
  :: evaluation engine for the main state and continuation monad
  ::
  ++  eval
    |%
    ++  output  (output-raw ,~)
    ::
    +$  result
      $%  [%next ~]
          [%fail err=tang]
          [%done ~]
      ==
    ::
    +$  took  [=^take err=(unit tang)]
    ::
    ++  take
      =|  darts=(list dart) :: effects
      =|  done=(list took)  :: consumed takes for acking
      |=  [state=vase =proc]
      ^-  [(list dart) (list took) vase _proc result]
      =^  =^take  next.proc  ~(get to next.proc)
      |-  :: recursion point so take can be replaced
      =/  res=(each output tang)
        :: TODO: jet +hoss? 
        ::       should use hoss
        ::       but double compute and double slogs sucks
        ::
        ?>  ?=(%& -.process.proc)
        (mule |.((p.process.proc state in.take)))
      ?:  ?=(%| -.res)
        =/  =tang  [leaf+"crash" p.res]
        :-  darts :: no output darts on failure
        :-  :_(done [take `tang])
        :-  state :: no output state on failure
        :-  proc
        [%fail tang]
      =/  =output  p.res
      ?-    -.next.output
          %fail
        :-  darts :: no output darts on failure
        :-  :_(done [take `err.next.output])
        :-  state :: no output state on failure
        :-  proc
        [%fail err.next.output]
        ::
          %done
        :-  (weld darts darts.output)
        :-  :_(done [take ~])
        :-  state.output
        :-  proc
        [%done ~]
        ::
          %cont
        %=  $
          darts         (weld darts darts.output)
          done          :_(done [take ~])
          state         state.output
          next.proc     (~(gas to next.proc) ~(tap to skip.proc))
          skip.proc     ~
          process.proc  &+self.next.output
          take          [give.take ~]
        ==
        ::
          %wait
        =.  darts  (weld darts darts.output)
        =.  done   :_(done [take ~])
        ?.  =(~ next.proc)
          :: recurse on queued input
          ::
          =^  top  next.proc  ~(get to next.proc)
          %=  $
            take       top
            state      state.output
          ==
        :: await input
        ::
        :-  darts
        :-  done
        :-  state.output
        :-  proc
        [%next ~]
        ::
          %skip
        ?:  =(~ in.take)
          :: can't %skip a ~ input
          ::
          =/  =tang  [leaf+"cannot skip null input" ~]
          :-  darts :: no output darts on failure
          :-  :_(done [take `tang])
          :-  state :: no output state on failure
          :-  proc
          [%fail tang]
        :: skip input - NOT added to done
        ::
        =.  skip.proc  (~(put to skip.proc) take)
        ?.  =(~ next.proc)
          :: recurse on queued input
          ::
          =^  top  next.proc  ~(get to next.proc)
          $(take top)
        :-  darts :: %skips can't send effects
        :-  done
        :-  state :: %skips can't change state
        :-  proc
        [%next ~]
      ==
    --
  --
::
+$  pipe   [bang=(unit tang) proc=(map @ta proc:fiber)]
+$  pool   (axal pipe)
+$  bangs  [bang=(unit tang) err=(map @ta (unit tang))]
::  Internal subscriptions: process watches tree locations
::
+$  subscribers    (map rail:tarball [=wire blot=(unit blot:tarball)])
+$  subscriptions  (set lane:tarball)
::  fwd: "who is watching this lane?" → watcher + wire for routing
::  rev: "what is this process watching?" → for cleanup on death
::
+$  subs
  $:  fwd=(axal [dir=subscribers fil=(map @ta subscribers)])
      rev=(axal (map @ta subscriptions))
  ==
::  High-water marks per grub - NEVER deleted, even when grubs are deleted.
::  Prevents stale responses and enables subscription ordering.
::
::  proc: incremented on process spawn/restart
::  file: incremented on content change
::
:: version history for files and directories
::
+$  pace
  $%  [%live p=(unit lobe:clay)]
      [%tomb ~]
  ==
++  hist
  =<  hist
  |%
  ++  cor   |=([a=cass:clay b=cass:clay] (lth ud.a ud.b))
  +$  hist  ((mop cass:clay pace) cor)
  ++  hon    ((on cass:clay pace) cor)
  ++  top
    |=  =hist
    ^-  (unit cass:clay)
    =/  got=(unit [key=cass:clay val=pace])  (ram:hon hist)
    ?~  got  ~
    `key.u.got
  ++  ver
    |=  =hist
    ^-  @ud
    ud:(need (top hist))
  --
::
+$  born  (axal [fold=hist file=(map @ta hist)])
+$  leaf
  $:  =blot:tarball
      =lobe:clay
  ==
+$  tree
  $:  nek=(unit neck:tarball)
      fil=(map @ta lobe:clay)
      dir=(map @ta [=lobe:clay weir=(unit weir)])
  ==
+$  ject
  $%  [%leaf =leaf]
      [%tree =tree]
  ==
+$  silo
  $:  nouns=(map lobe:clay [refs=@ud =noun])
      jects=(map lobe:clay [refs=@ud =ject])
  ==
::  Resolve a hist case to a lobe from the hist mop
::  %ud: exact match on revision number
::  %da: latest entry with da <= target date
::
++  resolve-case
  |=  [cas=case =hist]
  ^-  pace:^hist
  ?-    -.cas
      %ud
    =/  entries=(list [key=cass:clay val=pace:^hist])
      (tap:hon:^hist hist)
    |-
    ?~  entries  ~|(%hist-version-not-found !!)
    ?:  =(ud.key.i.entries p.cas)
      val.i.entries
    $(entries t.entries)
      %da
    =/  entries=(list [key=cass:clay val=pace:^hist])
      (tap:hon:^hist hist)
    ::  tap gives ascending order; find latest entry with da <= target
    =/  best=(unit pace:^hist)  ~
    |-
    ?~  entries
      ?~  best  ~|(%hist-version-not-found !!)
      u.best
    ?:  (gth da.key.i.entries p.cas)
      ?~  best  ~|(%hist-version-not-found !!)
      u.best
    $(entries t.entries, best `val.i.entries)
  ==
::  +record-trees: Snapshot directory state into tree objects.
::  Walks from dir up to root. At each level, builds a tree from
::  grub hists (fil) and child fold hists (dir), content-addresses it,
::  and only bumps fold if the hash changed. Stops propagating when
::  a level produces the same hash.
::
++  record-trees
  |=  [=born =silo =sand =ball:tarball now=@da dir=path]
  ^-  [^born ^silo]
  =/  sub-born=^born  (~(dip of born) dir)
  =/  boo  ~(. bo now [born ball])
  =/  top-fold  top:hist
  =/  top-hist  top:hist
  =/  node=[fold=hist file=(map @ta hist)]
    (fall fil.sub-born default-node:boo)
  ::  nek: nexus identity from ball at this directory
  =/  nek=(unit neck:tarball)
    =/  sub-ball=ball:tarball  (~(dip of ball) dir)
    ?~(fil.sub-ball ~ neck.u.fil.sub-ball)
  ::  fil: each grub's current ject-lobe from hist (skip deleted/tombed)
  =/  fil=(map @ta lobe:clay)
    %-  ~(rep by file.node)
    |=  [[name=@ta sk=hist] out=(map @ta lobe:clay)]
    =/  cas=(unit cass:clay)  (top-hist sk)
    ?~  cas  out
    =/  val=(unit pace:hist)  (get:hon:hist sk u.cas)
    ?~  val  out
    ?.  ?=(%live -.u.val)  out
    ?~  p.u.val  out
    (~(put by out) name u.p.u.val)
  ::  dir: each child's latest tree lobe + weir
  =/  sub-sand=^sand  (~(dip of sand) dir)
  =/  dir-map=(map @ta [lobe:clay weir=(unit weir)])
    %-  ~(urn by dir.sub-born)
    |=  [name=@ta kid=^born]
    =/  kid-node=(unit [fold=hist file=(map @ta hist)])  fil.kid
    =/  tree-lobe=lobe:clay
      ?~  kid-node  *lobe:clay
      =/  cas=(unit cass:clay)  (top-fold fold.u.kid-node)
      ?~  cas  *lobe:clay
      =/  got=(unit pace:hist)
        (get:hon:hist fold.u.kid-node u.cas)
      ?~  got  *lobe:clay
      ?.  ?=(%live -.u.got)  *lobe:clay
      (fall p.u.got *lobe:clay)
    =/  kid-weir=(unit weir)
      =/  kid-sand=(unit ^sand)  (~(get by dir.sub-sand) name)
      ?~  kid-sand  ~
      fil.u.kid-sand
    [tree-lobe kid-weir]
  ::  Build tree object + hash via ject
  =/  =tree  [nek fil dir-map]
  =/  =lobe:clay  `@uvI`(sham [%tree tree])
  ::  Check if tree changed from current
  =/  fold-cas=(unit cass:clay)  (top-fold fold.node)
  =/  cur-pace=(unit pace:hist)
    ?~  fold-cas  ~
    (get:hon:hist fold.node u.fold-cas)
  =/  cur-lobe=(unit lobe:clay)
    ?~  cur-pace  ~
    ?.  ?=(%live -.u.cur-pace)  ~
    p.u.cur-pace
  ?:  =(`lobe cur-lobe)
    [born silo]
  ::  Different — store tree ject
  =/  [* new-silo=^silo]
    (~(put-ject si silo) [%tree tree])
  =.  silo  new-silo
  =/  old-fold=cass:clay  (need fold-cas)
  =/  new-fold=cass:clay
    =/  nex-da=@da  ?:((lth da.old-fold now) now +(da.old-fold))
    [+(ud.old-fold) nex-da]
  =/  new-fold=hist
    (put:hon:hist fold.node new-fold [%live `lobe])
  =.  born
    (~(put of born) dir node(fold new-fold))
  ?~  dir  [born silo]
  $(dir (snip `path`dir))
::  +bo: Pure operations on born (version tracking)
::
::  Structure: (axal [fold=hist file=(map @ta hist)])
::    - fold and file hists are both mops keyed by cass:clay
::    - top of hist = current version; (top:hist fold) / (top:hist file)
::
::  Invariants:
::    - Born records are NEVER deleted (high-water mark for ordering)
::    - Sack hist bumps IFF content changes
::    - Tote hist bumps on any descendant change (fold)
::    - Weir cass bumps on weir change at that directory
::
++  bo
  |_  [now=@da old=[=born =ball:tarball]]
  ::  Default node with initial hist entry
  ::
  ++  default-node
    ^-  [fold=hist file=(map @ta hist)]
    =/  zero=cass:clay  [0 now]
    [[[zero [%live ~]] ~ ~] ~]
  ::  Get hist for a file
  ::
  ++  get
    |=  here=rail:tarball
    ^-  (unit hist)
    =/  node=(unit [fold=hist file=(map @ta hist)])
      (~(get of born.old) path.here)
    ?~  node  ~
    (~(get by file.u.node) name.here)
  ::  Put hist for a file
  ::
  ++  put
    |=  [here=rail:tarball sok=hist]
    ^-  born
    =/  node=[fold=hist file=(map @ta hist)]
      (fall (~(get of born.old) path.here) default-node)
    (~(put of born.old) path.here node(file (~(put by file.node) name.here sok)))
  ::  Get dir cass
  ::
  ++  get-dir-cass
    |=  dir=fold:tarball
    ^-  (unit cass:clay)
    =/  top-fold  top:hist
    =/  node=(unit [fold=hist file=(map @ta hist)])
      (~(get of born.old) dir)
    ?~  node  ~
    (top-fold fold.u.node)
  ::  Next cass value (increment ud, update da)
  ::
  ++  next-cass
    |=  =cass:clay
    ^-  cass:clay
    =/  nex-da=@da
      ?:((lth da.cass now) now +(da.cass))
    [+(ud.cass) nex-da]
  ::  Init born for new file — reuse existing hist if present (re-creation)
  ::
  ++  init
    |=  here=rail:tarball
    ^-  born
    =/  existing=(unit hist)  (get here)
    ?~  existing
      =/  zero=cass:clay  [0 now]
      (put here [[zero [%live ~]] ~ ~])
    (put here u.existing)
  ::  Check if a ball node is an empty directory (exists but no files, no subdirs)
  ::
  ++  is-empty-dir
    |=  =ball:tarball
    ^-  ?
    ?&  ?=(^ fil.ball)
        =(~ contents.u.fil.ball)
        =(~ dir.ball)
    ==
  ::  Check if a directory exists in a ball (has lump or has children)
  ::  (technically has lump should be enough to identify it)
  ::
  ++  dir-exists
    |=  bol=ball:tarball
    ^-  ?
    |(?=(^ fil.bol) !=(~ dir.bol))
  ::  Diff two balls and ensure born entries for changes
  ::
  ::  - New files (in new, not in old): init born entry
  ::  - Empty dir appears (no previous children): ensure born node
  ::  - Empty dir disappears (no new children): ensure born node
  ::  - Recurse into all subdirs
  ::
  ::  Note: actual hist/silo mutations happen in record-ball-changes
  ::  in grubbery.hoon, not here. This only ensures born entries exist
  ::  so that record can write to them.
  ::
  ++  diff-balls
    |=  [here=fold:tarball old-ball=ball:tarball new-ball=ball:tarball]
    ^-  born
    ::  Get file maps at this level
    =/  old-files=(map @ta content:tarball)
      ?~(fil.old-ball ~ contents.u.fil.old-ball)
    =/  new-files=(map @ta content:tarball)
      ?~(fil.new-ball ~ contents.u.fil.new-ball)
    =/  old-names=(set @ta)  ~(key by old-files)
    =/  new-names=(set @ta)  ~(key by new-files)
    ::  Init born entries for new files
    =/  new-only=(list @ta)  ~(tap in (~(dif in new-names) old-names))
    |-  ^-  born
    ?^  new-only
      =.  born.old  (init [here i.new-only])
      $(new-only t.new-only)
    ::  Handle empty dir edge cases
    =/  old-exists=?  (dir-exists old-ball)
    =/  new-exists=?  (dir-exists new-ball)
    =/  old-is-empty=?  (is-empty-dir old-ball)
    =/  new-is-empty=?  (is-empty-dir new-ball)
    ::  Empty dir appears — ensure node exists in born
    =?  born.old  &(new-is-empty !old-exists)
      (~(put of born.old) here (fall (~(get of born.old) here) default-node))
    ::  Empty dir disappears — ensure node exists in born
    =?  born.old  &(old-is-empty !new-exists)
      (~(put of born.old) here (fall (~(get of born.old) here) default-node))
    ::  Recurse into all subdirs
    =/  all-kids=(set @ta)
      (~(uni in ~(key by dir.old-ball)) ~(key by dir.new-ball))
    =/  kids=(list @ta)  ~(tap in all-kids)
    |-  ^-  born
    ?~  kids  born.old
    =/  kid-old=ball:tarball  (fall (~(get by dir.old-ball) i.kids) *ball:tarball)
    =/  kid-new=ball:tarball  (fall (~(get by dir.new-ball) i.kids) *ball:tarball)
    =.  born.old  (diff-balls (snoc here i.kids) kid-old kid-new)
    $(kids t.kids)
  --
::  +si: Pure operations on silo (content-addressed object store)
::
::  Nouns store raw data. Callers pair with blot from ject/hist
::  to interpret. Callers must clam on read to reconstruct typed data.
::
++  si
  |_  =silo
  ++  hash
    |=  =noun
    ^-  lobe:clay
    `@uvI`(sham noun)
  ::  Insert noun, increment refcount if exists. Returns lobe and new silo.
  ::
  ++  put
    |=  =noun
    ^-  [lobe:clay ^silo]
    =/  =lobe:clay  (hash noun)
    =/  got  (~(get by nouns.silo) lobe)
    ?~  got
      [lobe silo(nouns (~(put by nouns.silo) lobe [0 noun]))]
    [lobe silo]
  ::  Decrement refcount, delete if zero.
  ::
  ++  drop
    |=  =lobe:clay
    ^-  ^silo
    =/  got  (~(get by nouns.silo) lobe)
    ?~  got  silo
    ?:  (lte refs.u.got 1)
      silo(nouns (~(del by nouns.silo) lobe))
    silo(nouns (~(put by nouns.silo) lobe [refs=(dec refs.u.got) noun.u.got]))
  ::  Look up noun by lobe.
  ::
  ++  get
    |=  =lobe:clay
    ^-  (unit noun)
    =/  got  (~(get by nouns.silo) lobe)
    ?~  got  ~
    `noun.u.got
  ::  Drop refs for all ject lobes in a hist.
  ::
  ++  drop-hist
    |=  =hist
    ^-  ^silo
    =/  entries=(list [key=cass:clay val=pace:^hist])
      (tap:hon:^hist hist)
    |-
    ?~  entries  silo
    =/  pv=pace:^hist  val.i.entries
    ?.  ?=(%live -.pv)  $(entries t.entries)
    ?~  p.pv  $(entries t.entries)
    $(entries t.entries, silo (drop-ject u.p.pv))
  ::  Increment noun refcount by lobe (must exist).
  ::
  ++  bump-ref
    |=  =lobe:clay
    ^-  ^silo
    =/  got  (~(get by nouns.silo) lobe)
    ?~  got  silo
    silo(nouns (~(put by nouns.silo) lobe [+(refs.u.got) noun.u.got]))
  ::  Increment ject refcount by lobe (must exist).
  ::
  ++  bump-ject-ref
    |=  =lobe:clay
    ^-  ^silo
    =/  got  (~(get by jects.silo) lobe)
    ?~  got  silo
    silo(jects (~(put by jects.silo) lobe [+(refs.u.got) ject.u.got]))
  ::  Insert ject, increment refcount if exists.
  ::  On first insert, bumps refs on all referenced nouns and child jects.
  ::
  ++  put-ject
    |=  =ject
    ^-  [lobe:clay ^silo]
    =/  =lobe:clay  `@uvI`(sham ject)
    =/  got  (~(get by jects.silo) lobe)
    ?^  got
      [lobe silo(jects (~(put by jects.silo) lobe [+(refs.u.got) ject]))]
    ::  new ject — store it, then bump refs on children
    =.  jects.silo  (~(put by jects.silo) lobe [1 ject])
    ?-  -.ject
        %leaf
      ::  leaf references a noun — bump its refcount
      =.  silo  (~(bump-ref si silo) lobe.leaf.ject)
      [lobe silo]
        %tree
      =.  silo
        %-  ~(rep by fil.tree.ject)
        |=  [[* =lobe:clay] =_silo]
        (~(bump-ject-ref si silo) lobe)
      =.  silo
        %-  ~(rep by dir.tree.ject)
        |=  [[* =lobe:clay *] =_silo]
        (~(bump-ject-ref si silo) lobe)
      [lobe silo]
    ==
  ::  Decrement ject refcount, delete if zero.
  ::
  ++  drop-ject
    |=  =lobe:clay
    ^-  ^silo
    =/  got  (~(get by jects.silo) lobe)
    ?~  got  silo
    ?.  (lte refs.u.got 1)
      silo(jects (~(put by jects.silo) lobe [refs=(dec refs.u.got) ject.u.got]))
    ::  refs hit zero — delete ject and cascade to children
    =.  jects.silo  (~(del by jects.silo) lobe)
    =/  jt=ject  ject.u.got
    ?-  -.jt
        %leaf
      (~(drop si silo) lobe.leaf.jt)
        %tree
      =.  silo
        %-  ~(rep by fil.tree.jt)
        |=  [[* =lobe:clay] =_silo]
        (~(drop-ject si silo) lobe)
      %-  ~(rep by dir.tree.jt)
      |=  [[* =lobe:clay *] =_silo]
      (~(drop-ject si silo) lobe)
    ==
    ::  Record a noun: insert into silo, update hist per gain flag.
  ::  Returns [lobe new-silo new-hist].
  ::
  ::  gain=%.y: append to hist, keeping full history.
  ::  gain=%.n: don't accumulate history. If the current live
  ::    version (identified by the file cass) is in hist, drop its
  ::    silo ref and remove it. Older history is preserved —
  ::    gain only controls what happens live, not retroactively.
  ::
  ++  record
    |=  $:  =noun
            =blot:tarball
            =cass:clay
            gain=?
            file=cass:clay
            =hist
        ==
    ^-  [lobe:clay ^silo ^hist]
    ::  Store noun, then wrap as leaf ject
    =/  [noun-lobe=lobe:clay new-silo=^silo]  (put noun)
    =/  [ject-lobe=lobe:clay newer-silo=^silo]
      (~(put-ject si new-silo) [%leaf blot noun-lobe])
    ?:  gain
      [noun-lobe newer-silo (put:hon:^hist hist cass [%live `ject-lobe])]
    ::  !gain: tombstone previous live version, append new
    =/  prev=(unit pace:^hist)  (get:hon:^hist hist file)
    =.  newer-silo
      ?~  prev  newer-silo
      =/  pv=pace:^hist  u.prev
      ?.  ?=(%live -.pv)  newer-silo
      ?~  p.pv  newer-silo
      (~(drop-ject si newer-silo) u.p.pv)
    =/  tombed
      ?~  prev  hist
      (put:hon:^hist hist file [%tomb ~])
    [noun-lobe newer-silo (put:hon:^hist tombed cass [%live `ject-lobe])]
  --
::  +stamp-mtimes: stamp born datetimes into ball metadata as mtime
::
++  stamp-mtimes
  |=  [=born b=ball:tarball]
  ^-  ball:tarball
  =/  lumps  ~(tap of b)
  =/  top-fold  top:hist
  =/  top-hist  top:hist
  |-
  ?~  lumps  b
  =/  [pax=path lmp=lump:tarball]  i.lumps
  =/  node=(unit [fold=hist file=(map @ta hist)])
    (~(get of born) pax)
  ?~  node  $(lumps t.lumps)
  =.  metadata.lmp
    =/  cas=(unit cass:clay)  (top-fold fold.u.node)
    ?~  cas  metadata.lmp
    (~(put by metadata.lmp) 'mtime' (da-oct:tarball da.u.cas))
  =.  contents.lmp
    %-  ~(urn by contents.lmp)
    |=  [name=@ta =content:tarball]
    =/  sk=(unit hist)  (~(get by file.u.node) name)
    ?~  sk  content
    =/  cas=(unit cass:clay)  (top-hist u.sk)
    ?~  cas  content
    content(metadata (~(put by metadata.content) 'mtime' (da-oct:tarball da.u.cas)))
  =.  b  (~(put of b) pax lmp)
  $(lumps t.lumps)
::  +diff-born: compare two born trees and return set of changed lanes
::
::  Pure function: walks both trees, comparing totes and sacks.
::  Two modes:
::    %all   - compare everything (fold + file)
::    %state - compare fold cass + file cass only (content changes)
::
++  diff-born
  |=  [old=born new=born]
  ^-  (set lane:tarball)
  (diff-born-at / old new %all)
::
++  diff-born-state
  |=  [old=born new=born]
  ^-  (set lane:tarball)
  (diff-born-at / old new %state)
::
++  diff-born-at
  |=  [here=fold:tarball old=born new=born mode=?(%all %state)]
  ^-  (set lane:tarball)
  =|  result=(set lane:tarball)
  ::  Compare directory-level totes
  =/  old-fold=hist  ?~(fil.old *hist fold.u.fil.old)
  =/  new-fold=hist  ?~(fil.new *hist fold.u.fil.new)
  =/  dir-changed=?
    ?-  mode
      %all    !=(old-fold new-fold)
      %state  !=((ram:hon:hist old-fold) (ram:hon:hist new-fold))
    ==
  =?  result  dir-changed
    (~(put in result) |+here)
  ::  Compare file hists
  =.  result
    =/  old-file=(map @ta hist)  ?~(fil.old ~ file.u.fil.old)
    =/  new-file=(map @ta hist)  ?~(fil.new ~ file.u.fil.new)
    =/  all-names=(list @ta)
      ~(tap in (~(uni in ~(key by old-file)) ~(key by new-file)))
    |-
    ?~  all-names  result
    =/  old-sk=hist  (fall (~(get by old-file) i.all-names) *hist)
    =/  new-sk=hist  (fall (~(get by new-file) i.all-names) *hist)
    =/  file-changed=?
      ?-  mode
        %all    !=(old-sk new-sk)
        %state  !=((ram:hon:hist old-sk) (ram:hon:hist new-sk))
      ==
    =?  result  file-changed
      (~(put in result) &+[here i.all-names])
    $(all-names t.all-names)
  ::  Recurse into children
  =/  all-kids=(list @ta)
    ~(tap in (~(uni in ~(key by dir.old)) ~(key by dir.new)))
  |-
  ?~  all-kids  result
  =/  old-kid=born  (fall (~(get by dir.old) i.all-kids) *born)
  =/  new-kid=born  (fall (~(get by dir.new) i.all-kids) *born)
  =.  result
    (~(uni in result) (diff-born-at (snoc here i.all-kids) old-kid new-kid mode))
  $(all-kids t.all-kids)
::  +changed-lanes: diff two balls, return set of changed lanes
::
::  Compares content directly (not born metadata).
::  Returns lanes for all added, changed, and deleted files,
::  plus folds for directories that appeared or disappeared.
::
++  changed-lanes
  |=  [old=ball:tarball new=ball:tarball]
  ^-  (set lane:tarball)
  (changed-lanes-at / old new)
::
++  changed-lanes-at
  |=  [here=fold:tarball old=ball:tarball new=ball:tarball]
  ^-  (set lane:tarball)
  =|  result=(set lane:tarball)
  =/  old-files=(map @ta content:tarball)
    ?~(fil.old ~ contents.u.fil.old)
  =/  new-files=(map @ta content:tarball)
    ?~(fil.new ~ contents.u.fil.new)
  =/  all-names=(list @ta)
    ~(tap in (~(uni in ~(key by old-files)) ~(key by new-files)))
  =.  result
    |-  ^-  (set lane:tarball)
    ?~  all-names  result
    =/  in-old  (~(has by old-files) i.all-names)
    =/  in-new  (~(has by new-files) i.all-names)
    =/  file-changed=?
      ?:  &(in-new !in-old)  %.y                :: added
      ?:  &(in-old !in-new)  %.y                :: deleted
      ?&  in-old  in-new
          !=(sage:(~(got by old-files) i.all-names) sage:(~(got by new-files) i.all-names))
      ==                                         :: changed
    =?  result  file-changed
      (~(put in result) &+[here i.all-names])
    $(all-names t.all-names)
  ::  dir appeared or disappeared
  =/  old-exists=?  |(?=(^ fil.old) !=(~ dir.old))
  =/  new-exists=?  |(?=(^ fil.new) !=(~ dir.new))
  =?  result  !=(old-exists new-exists)
    (~(put in result) |+here)
  ::  recurse into subdirs
  =/  all-kids=(list @ta)
    ~(tap in (~(uni in ~(key by dir.old)) ~(key by dir.new)))
  |-  ^-  (set lane:tarball)
  ?~  all-kids  result
  =/  kid-old=ball:tarball  (fall (~(get by dir.old) i.all-kids) *ball:tarball)
  =/  kid-new=ball:tarball  (fall (~(get by dir.new) i.all-kids) *ball:tarball)
  =.  result
    (~(uni in result) (changed-lanes-at (snoc here i.all-kids) kid-old kid-new))
  $(all-kids t.all-kids)
::  Cross-ship load/intake types
::  Mirrors internal dart load / fiber intake pattern.
::
++  remote
  |%
  +$  load
    $:  [=wire dest=lane:tarball]
        $%  [%make =make]
            [%cull ~]
            [%sand weir=(unit weir)]
            [%load ~]
            [%poke =bask:tarball]
            [%peek blot=(unit blot:tarball)]
        ==
    ==
  +$  make  (each [=sand =gain =ball:tarball] [gain=? =bask:tarball blot=(unit blot:tarball)])
  +$  intake
    $:  =wire
        $%  [%peek ~] :: TBD
        ==
    ==
  --
+$  ack  (unit tang)
::
:: ++  deaf
::   |=  tap=(trap)
::   ^-  (each * (list tank))
::   =/  ton  (mock [tap %9 2 %0 1] ~)
::   ?-  -.ton
::     %0  [%& p.ton]
::   ::
::     %1  =/  sof=(unit path)  ((soft path) p.ton)
::         [%| ?~(sof leaf+"deaf.hunk" (smyt u.sof)) ~]
::   ::
::     %2  [%| p.ton]
::   ==
:: ::  Scry-free mule: like +mule but blocks .^ calls
:: ::  FSCK: Runs the code twice, including slogs, etc.
:: ::        +mule doesn't do that because it's jetted.
:: ::
:: ++  hoss
::   |*  tap=(trap)
::   =/  mud  (deaf tap)
::   ?-  -.mud
::     %&  [%& p=$:tap]
::     %|  [%| p=p.mud]
::   ==
:: ::
:: ++  mohr
::   |*  [tul=mold pul=mold]
::   |=  [tap=(trap tul) gul=$@(~ $-(^ (unit (unit))))]
::   =/  ton  (mock [tap %9 2 %0 1] gul)
::   ?-  -.ton
::     %0  [%0 p=`tul`!<(tul [-:!>(*tul) p.ton])]
::   ::
::     %1  ?@  gul  !!
::         :-  %1  ^=  p
::         ?~  pax=((soft pul) p.ton)
::           |^p.ton
::         &^u.pax
::   ::
::     %2  [%2 p=p.ton]
::   ==
::  Convert absolute from (rail) to relative from (fiber bend)
::
::  External sources pass through unchanged.
::  Internal sources get relativized to a fiber bend (always targets rail).
::
++  relativize-from
  |=  [here=rail:tarball =from]
  ^-  from:fiber
  ?.  ?=(%& -.from)
    from  :: external passes through
  =/  src=rail:tarball  p.from
  =/  pref=path  (prefix:tarball path.here path.src)
  =/  here-tail=path  (need (decap:tarball pref path.here))
  =/  src-tail=path  (need (decap:tarball pref path.src))
  &+[(lent here-tail) [src-tail name.src]]
::  Check if dest lane is permitted by an allowed lane.
::
++  raw-filter
  |=  [dest=lane:tarball allow=lane:tarball]
  ^-  ?
  ?-    -.dest
      ::  Destination is a file
      %&
    ?-  -.allow
      ::  Allowed lane is a file: must be the exact same file
      %&  =(p.dest p.allow)
      ::  Allowed lane is a dir: file must be somewhere under that dir
      %|  ?=(^ (decap:tarball p.allow path.p.dest))
    ==
      ::  Destination is a directory
      %|
    ?-  -.allow
      ::  Allowed lane is a file: a file rule can't permit directory operations
      %&  |
      ::  Allowed lane is a dir: dest dir must be under (or equal to) allowed dir
      %|  ?=(^ (decap:tarball p.allow p.dest))
    ==
  ==
::  Convert roads to absolute lanes, then check if dest is allowed.
::  `fold` is the directory whose weir we're checking
::
++  filter-roads
  |=  [=fold:tarball dest=lane:tarball roads=(list road:tarball)]
  ^-  ?
  ::  Convert relative roads to absolute lanes (murn filters out invalid roads)
  =/  lanes=(list lane:tarball)  (murn roads (cury lane-from-road:tarball [%| fold]))
  |-
  ?~  lanes  |
  ?:  (raw-filter dest i.lanes)  &
  $(lanes t.lanes)
::  Check a single weir: is this jump to dest allowed from here?
::  `fold` is the directory whose weir we're checking
::
++  filter
  |=  [=jump =fold:tarball dest=lane:tarball weir=(unit weir)]
  ^-  filt
  ?~  weir  ~                       :: no weir = no filter (permissive)
  :-  ~
  ?-  jump
    %make  (filter-roads fold dest ~(tap in make.u.weir))
    %poke  (filter-roads fold dest ~(tap in poke.u.weir))
    %peek  (filter-roads fold dest ~(tap in peek.u.weir))
  ==
::  Combine two filter results. Veto wins; otherwise allow+clam wins.
::
++  next-filt
  |=  [cur=filt nex=filt]
  ^-  filt
  ?~  cur  nex
  ?~  nex  cur
  ?:  ?=([~ %|] cur)  [~ |]
  ?:  ?=([~ %|] nex)  [~ |]
  [~ &]
:: NOTES:
::  - in the +on-load, we recursively run nexus +on-loads in a top-down manner
::  - +on-load assumes all processes are being restarted
::  - we generate the process for every leaf node (file) and run it with ~,
::    accumulating effects
::  - each nexus should create a main process to handle its API
::
+$  nexus
  $_  ^?
  |%
  :: top-down reconsideration of directory structure in +on-load and whenever
  :: this nexus is initially created
  ::
  ++  on-load
    |~  [sand gain ball:tarball]
    [*sand *gain *ball:tarball]
  :: every grub has a running process alongside its file content.
  :: processes should be able to recover proper operation based on
  ::   state alone, even when restarted. this is not guaranteed and
  ::   is a responsibility of the programmer.
  ::
  ++  on-file
    |~  [rail:tarball blot:tarball]
    *spool:fiber :: define spool (initializer) for grub at rail
  :: manual page for a grub or directory. returns documentation text.
  ::
  ++  on-manu
    |~  mana
    *@t
  --
::  JSON conversion helpers
::
++  road-to-json
  |=  =road:tarball
  ^-  json
  ?-    -.road
      %&
    ?-  -.p.road
      %&  s+(crip (spud (snoc path.p.p.road name.p.p.road)))
      %|  s+(crip (spud p.p.road))
    ==
      %|
    %-  pairs:enjs:format
    :~  ['up' (numb:enjs:format p.p.road)]
        :-  'dest'
        ?-  -.q.p.road
          %&  s+(crip (spud (snoc path.p.q.p.road name.p.q.p.road)))
          %|  s+(crip (spud p.q.p.road))
        ==
    ==
  ==
::
++  weir-to-json
  |=  =weir
  ^-  json
  %-  pairs:enjs:format
  :~  ['make' [%a (turn ~(tap in make.weir) road-to-json)]]
      ['poke' [%a (turn ~(tap in poke.weir) road-to-json)]]
      ['peek' [%a (turn ~(tap in peek.weir) road-to-json)]]
  ==
::
++  road-from-json
  |=  =json
  ^-  road:tarball
  ?>  ?=([%s *] json)
  [%& %| (stab p.json)]
::
++  weir-from-json
  |=  =json
  ^-  weir
  =/  [make=(list road:tarball) poke=(list road:tarball) peek=(list road:tarball)]
    %.  json
    %-  ot:dejs:format
    :~  ['make' (ar:dejs:format road-from-json)]
        ['poke' (ar:dejs:format road-from-json)]
        ['peek' (ar:dejs:format road-from-json)]
    ==
  [(~(gas in *(set road:tarball)) make) (~(gas in *(set road:tarball)) poke) (~(gas in *(set road:tarball)) peek)]
::
++  cass-to-json
  |=  =cass:clay
  ^-  json
  (pairs:enjs:format ~[['ud' (numb:enjs:format ud.cass)] ['da' s+(scot %da da.cass)]])
::
++  hist-to-json
  |=  sk=hist
  ^-  json
  %-  pairs:enjs:format
  :~  ['file' (cass-to-json (need (top:hist sk)))]
      :-  'hist'
      :-  %a
      %+  turn  (tap:hon:hist sk)
      |=  [key=cass:clay val=pace:hist]
      %-  pairs:enjs:format
      :~  ['ud' (numb:enjs:format ud.key)]
          ['da' s+(scot %da da.key)]
          :-  'pace'
          ?-  -.val
            %tomb  s+'tomb'
            %live
          ?~  p.val  s+'deleted'
          s+(scot %uv u.p.val)
          ==
      ==
  ==
::
++  born-to-json
  |=  b=born
  ^-  json
  =/  node-json=json
    ?~  fil.b  ~
    %-  pairs:enjs:format
    :~  :-  'fold'
        %-  pairs:enjs:format
        :~  ['cass' (cass-to-json (need (top:hist fold.u.fil.b)))]
            :-  'hist'
            :-  %a
            %+  turn  (tap:hon:hist fold.u.fil.b)
            |=  [key=cass:clay val=pace:hist]
            %-  pairs:enjs:format
            :~  ['ud' (numb:enjs:format ud.key)]
                ['da' s+(scot %da da.key)]
                :-  'pace'
                ?-  -.val
                  %tomb  s+'tomb'
                  %live
                ?~  p.val  s+'deleted'
                s+(scot %uv u.p.val)
                ==
            ==
        ==
        :-  'file'
        [%o (~(run by file.u.fil.b) hist-to-json)]
    ==
  =/  kids-json=json
    [%o (~(run by dir.b) |=(kid=born ^$(b kid)))]
  ?~  fil.b
    ?:  =(~ dir.b)  ~
    (pairs:enjs:format ~[['dirs' kids-json]])
  %-  pairs:enjs:format
  :~  ['node' node-json]
      ['dirs' kids-json]
  ==
::
++  sand-to-json
  |=  s=sand
  ^-  json
  =/  subdirs=json  [%o (~(run by dir.s) sand-to-json)]
  ?~  fil.s
    (pairs:enjs:format ~[['dirs' subdirs]])
  %-  pairs:enjs:format
  :~  ['weir' (weir-to-json u.fil.s)]
      ['dirs' subdirs]
  ==
::
++  gain-to-json
  |=  g=gain
  ^-  json
  =/  subdirs=json  [%o (~(run by dir.g) gain-to-json)]
  ?~  fil.g
    (pairs:enjs:format ~[['dirs' subdirs]])
  %-  pairs:enjs:format
  :~  ['node' [%o (~(run by u.fil.g) |=(f=? b+f))]]
      ['dirs' subdirs]
  ==
--
