/+  tarball
|%
+$  card  card:agent:gall
::  A "grub" is the entity that lives at a rail: its file content and
::  its running process, considered as one thing. You create, delete,
::  poke, and watch grubs. When the distinction matters, "file" means
::  the data (content + metadata) and "process" means the running fiber.
::
::  Grubs live in directories. Directories hold grubs and other
::  directories, have a neck (nexus mark), and may have a weir
::  (sandbox rules).
::
+$  prov  [src=@p sap=path]         :: external provenance
+$  from  (each rail:tarball prov)  :: source: [%& rail] internal grub or [%| prov] external
+$  give  [=from =wire]             :: return address (from is always a grub)
+$  scry  [=mold =path]
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
+$  jump  ?(%sysc %make %poke %peek)  :: dart category for filtering
::
+$  bowl
  $:  now=@da
      our=@p
      eny=@uvJ
      wex=boat:gall
      sup=bitt:gall
      here=rail:tarball
      dap=dude:gall
      byk=beak
  ==
::
+$  make  (each [=sand =ball:tarball] cage)
+$  view
  $%  [%ball =sand =born ball=ball:tarball]
      [%file =sack =cage]
      [%none ~]
  ==
+$  seen  (each view tang)
:: dart payload
::
+$  load
  $%  [%poke =cage]             :: poke a grub
      [%make =make]             :: create grub or directory
      [%cull ~]                 :: delete grub or directory
      [%sand weir=(unit weir)]  :: set weir
      [%load ~]                 :: trigger on-load for a nexus (folds only)
      [%peek ~]                 :: read a grub
      [%keep ~]                 :: subscribe to changes at dest (grub or ball per road)
      [%drop ~]                 :: unsubscribe from dest
  ==
::
+$  dart
  $%  [%sysc =card:agent:gall]  :: regular card
      [%node =wire road=road:tarball =load]
      [%scry =wire scry=(unit scry)]
      [%bowl =wire]
  ==
::
++  fiber
  |%
  +$  proc
    $:  =process                 :: running fiber
        next=(qeu take)          :: queue of held inputs
        skip=(qeu take)          :: queue of skipped inputs
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
  ::
  +$  intake
    $%  [%poke =from =cage] :: command for a running process (from is relative)
        [%peek =wire =seen] :: local read result
        [%made =wire err=(unit tang)] :: response to make
        [%gone =wire err=(unit tang)] :: response to cull
        [%pack =wire err=(unit tang)] :: response from poke; tang is generic if not allowed to peek
        [%sand =wire err=(unit tang)] :: response to sand
        [%load =wire err=(unit tang)] :: response to load
        [%bond =wire err=(unit tang)] :: subscription established/failed
        [%fell =wire]                 :: subscription canceled (weir change, deletion, etc)
        [%news =wire =view] :: state notification
        [%veto =dart] :: notify that a dart was sandboxed
        :: messages from gall and arvo
        ::
        [%scry =wire =vase]
        [%bowl =wire =bowl]
        [%arvo =wire sign=sign-arvo]
        [%agent =wire =sign:agent:gall]
        [%watch =path]
        [%leave =path]
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
        [%load ~]     :: gall on-init or on-load
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
      [~ state %wait ~]
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
      |=  [=bowl state=vase =proc]
      ^-  [(list dart) (list took) vase _proc result]
      =^  =^take  next.proc  ~(get to next.proc)
      |-  :: recursion point so take can be replaced
      =/  res=(each output tang)
        :: TODO: jet +hoss? 
        ::       should use hoss
        ::       but double compute and double slogs sucks
        ::
        (mule |.((process.proc state in.take)))
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
          process.proc  self.next.output
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
+$  pipe  (map @ta proc:fiber)
+$  pool  (axal pipe)
::  Internal subscriptions: process watches tree locations
::
::  fwd: "who is watching this lane?" → watcher + wire for routing
::  rev: "what is this process watching?" → for cleanup on death
::
+$  subs
  $:  fwd=(map lane:tarball (map rail:tarball wire))
      rev=(jug rail:tarball lane:tarball)
  ==
::  High-water marks per grub - NEVER deleted, even when grubs are deleted.
::  Prevents stale responses and enables subscription ordering.
::
::  proc: incremented on process spawn/restart
::  file: incremented on content change
::
+$  tote  [weir=cass:clay fold=cass:clay]
+$  sack  [proc=cass:clay file=cass:clay]
+$  born  (axal [=tote bags=(map @ta sack)])
::  +bo: Pure operations on born (version tracking)
::
::  Structure: (axal [tote bags=(map @ta sack)])
::    - tote = [weir=cass:clay fold=cass:clay]
::    - Each directory node has a tote and bags (grub sacks)
::    - sack = [proc=cass:clay file=cass:clay]
::
::  Semantics:
::    - proc cass: bumped on process spawn/restart (stale detection + notifications)
::    - file cass: bumped on content change (notifications)
::    - fold cass: bumped when ANY descendant changes (propagates up to root)
::    - weir cass: bumped when weir changes at this directory
::
::  All four trigger subscriber notifications via diff-born.
::
::  Lifecycle for new grub:
::    init      → [0 0]  (file exists)
::    bump-proc → [1 0]  (process spawned)
::    bump-file → [1 1]  (first content saved)
::
::  Invariants:
::    - Born records are NEVER deleted (high-water mark for ordering)
::    - File cass bumps IFF content changes
::    - Fold cass bumps on any descendant change
::    - Weir cass bumps on weir change at that directory
::
++  bo
  |_  [now=@da old=[=born =ball:tarball]]
  ::  Get sack for a file
  ::
  ++  get
    |=  here=rail:tarball
    ^-  (unit sack)
    =/  node=(unit [=tote bags=(map @ta sack)])
      (~(get of born.old) path.here)
    ?~  node  ~
    (~(get by bags.u.node) name.here)
  ::  Put sack for a file
  ::
  ++  put
    |=  [here=rail:tarball sok=sack]
    ^-  born
    =/  node=[=tote bags=(map @ta sack)]
      (fall (~(get of born.old) path.here) [[[0 now] [0 now]] ~])
    (~(put of born.old) path.here node(bags (~(put by bags.node) name.here sok)))
  ::  Get dir cass
  ::
  ++  get-dir-cass
    |=  dir=fold:tarball
    ^-  (unit cass:clay)
    =/  node=(unit [=tote bags=(map @ta sack)])
      (~(get of born.old) dir)
    ?~  node  ~
    `fold.tote.u.node
  ::  Next cass value (increment ud, update da)
  ::
  ++  next-cass
    |=  =cass:clay
    ^-  cass:clay
    =/  nex-da=@da
      ?:((lth da.cass now) now +(da.cass))
    [+(ud.cass) nex-da]
  ::  Init born for new file: [proc=0 file=0] (no bump - first creation)
  ::
  ++  init
    |=  here=rail:tarball
    ^-  born
    (put here [[0 now] [0 now]])
  ::  Bump proc cass (asserts born exists)
  ::
  ++  bump-proc
    |=  here=rail:tarball
    ^-  born
    =/  sok=sack  (need (get here))
    (put here [(next-cass proc.sok) file.sok])
  ::  Bump dir cass and propagate up to root
  ::
  ++  bump-dir
    |=  dir=fold:tarball
    ^-  born
    =/  node=[=tote bags=(map @ta sack)]
      (fall (~(get of born.old) dir) [[[0 now] [0 now]] ~])
    =/  new-cass=cass:clay  (next-cass fold.tote.node)
    =.  born.old  (~(put of born.old) dir node(fold.tote new-cass))
    ?~  dir  born.old
    (bump-dir (snip `fold:tarball`dir))
  ::  Bump file cass and propagate dir cass up to root (asserts born exists)
  ::
  ++  bump-file
    |=  here=rail:tarball
    ^-  born
    =/  sok=sack  (need (get here))
    =.  born.old  (put here [proc.sok (next-cass file.sok)])
    (bump-dir path.here)
  ::  Bump weir cass of directory node and propagate fold cass up
  ::
  ++  bump-weir
    |=  dir=fold:tarball
    ^-  born
    =/  node=[=tote bags=(map @ta sack)]
      (fall (~(get of born.old) dir) [[[0 now] [0 now]] ~])
    =.  born.old
      (~(put of born.old) dir node(weir.tote (next-cass weir.tote.node)))
    (bump-dir dir)
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
  ::  Diff two balls and track all changes
  ::
  ::  - New files (in new, not in old): init + bump
  ::  - Changed files (in both, content differs): bump
  ::  - Deleted files (in old, not in new): bump
  ::  - Empty dir appears (no previous children): bump-dir
  ::  - Empty dir disappears (no new children): bump-dir
  ::  - Recurse into all subdirs
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
    ::  Process files: new, changed, deleted
    =/  all-names=(list @ta)  ~(tap in (~(uni in old-names) new-names))
    |-  ^-  born
    ?^  all-names
      =/  name=@ta  i.all-names
      =/  in-old=?  (~(has in old-names) name)
      =/  in-new=?  (~(has in new-names) name)
      =.  born.old
        ?:  &(in-new !in-old)
          ::  New file: init then bump
          =.  born.old  (init [here name])
          (bump-file [here name])
        ?:  &(in-old !in-new)
          ::  Deleted file: bump
          (bump-file [here name])
        ::  File in both: check if changed
        =/  old-content=content:tarball  (~(got by old-files) name)
        =/  new-content=content:tarball  (~(got by new-files) name)
        ?.  =(cage.old-content cage.new-content)
          ::  Changed: bump
          (bump-file [here name])
        ::  No change
        born.old
      $(all-names t.all-names)
    ::  Handle empty dir edge cases
    =/  old-exists=?  (dir-exists old-ball)
    =/  new-exists=?  (dir-exists new-ball)
    =/  old-is-empty=?  (is-empty-dir old-ball)
    =/  new-is-empty=?  (is-empty-dir new-ball)
    ::  Empty dir appears
    =?  born.old  &(new-is-empty !old-exists)
      (bump-dir here)
    ::  Empty dir disappears
    =?  born.old  &(old-is-empty !new-exists)
      (bump-dir here)
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
::  +stamp-mtimes: stamp born datetimes into ball metadata as mtime
::
++  stamp-mtimes
  |=  [=born b=ball:tarball]
  ^-  ball:tarball
  =/  lumps  ~(tap of b)
  |-
  ?~  lumps  b
  =/  [pax=path lmp=lump:tarball]  i.lumps
  =/  node=(unit [=tote bags=(map @ta sack)])
    (~(get of born) pax)
  ?~  node  $(lumps t.lumps)
  =.  metadata.lmp
    (~(put by metadata.lmp) 'mtime' (da-oct:tarball da.fold.tote.u.node))
  =.  contents.lmp
    %-  ~(urn by contents.lmp)
    |=  [name=@ta =content:tarball]
    =/  sk=(unit sack)  (~(get by bags.u.node) name)
    ?~  sk  content
    content(metadata (~(put by metadata.content) 'mtime' (da-oct:tarball da.file.u.sk)))
  =.  b  (~(put of b) pax lmp)
  $(lumps t.lumps)
::  +diff-born: compare two born trees and return set of changed lanes
::
::  Pure function: walks both trees, comparing totes and sacks.
::  Four modes:
::    %all   - compare everything (tote + bags)
::    %state - compare fold cass + file cass only (content changes)
::    %weir  - compare weir cass only (sandbox changes)
::    %proc  - compare proc cass only (process restarts)
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
++  diff-born-weir
  |=  [old=born new=born]
  ^-  (set lane:tarball)
  (diff-born-at / old new %weir)
::
++  diff-born-proc
  |=  [old=born new=born]
  ^-  (set lane:tarball)
  (diff-born-at / old new %proc)
::
++  diff-born-at
  |=  [here=fold:tarball old=born new=born mode=?(%all %state %weir %proc)]
  ^-  (set lane:tarball)
  =|  result=(set lane:tarball)
  ::  Compare directory-level totes
  =/  old-tote=tote  ?~(fil.old *tote tote.u.fil.old)
  =/  new-tote=tote  ?~(fil.new *tote tote.u.fil.new)
  =/  dir-changed=?
    ?-  mode
      %all    !=(old-tote new-tote)
      %state  !=(fold.old-tote fold.new-tote)
      %weir   !=(weir.old-tote weir.new-tote)
      %proc   %.n
    ==
  =?  result  dir-changed
    (~(put in result) |+here)
  ::  Compare bags (file sacks) — skip for weir-only mode
  =.  result
    ?:  ?=(%weir mode)  result
    =/  old-bags=(map @ta sack)  ?~(fil.old ~ bags.u.fil.old)
    =/  new-bags=(map @ta sack)  ?~(fil.new ~ bags.u.fil.new)
    =/  all-names=(list @ta)
      ~(tap in (~(uni in ~(key by old-bags)) ~(key by new-bags)))
    |-
    ?~  all-names  result
    =/  old-sk=sack  (fall (~(get by old-bags) i.all-names) *sack)
    =/  new-sk=sack  (fall (~(get by new-bags) i.all-names) *sack)
    =/  sack-changed=?
      ?:  ?=(%all mode)    !=(old-sk new-sk)
      ?:  ?=(%state mode)  !=(file.old-sk file.new-sk)
      !=(proc.old-sk proc.new-sk)
    =?  result  sack-changed
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
::  External action type for pokes
::
+$  action
  $:  [=wire dest=lane:tarball]
      $%  [%make =make]
          [%cull ~]
          [%sand weir=(unit weir)]
          [%load ~]
          [%poke =page]
      ==
  ==
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
  ?:  ?=(%sysc jump)
    [~ |]                           :: weirs always block syscalls
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
    |~  [sand ball:tarball]
    [*sand *ball:tarball]
  :: every grub has a running process alongside its file content.
  :: processes should be able to recover proper operation based on
  ::   state alone, even when restarted. this is not guaranteed and
  ::   is a responsibility of the programmer.
  ::
  ++  on-file
    |~  [rail:tarball mark]
    *spool:fiber :: define spool (initializer) for grub at rail
  --
--
