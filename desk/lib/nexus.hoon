/-  push
/+  tarball
|%
+$  card  card:agent:gall
+$  built
  $%  [%vase =vase]
      [%tang =tang]
      [%mime =mime]
  ==
+$  keys  (map rail:tarball [in=@uv out=@uv])
+$  deps  (map rail:tarball (set rail:tarball))
+$  refs  (axal (map @ta @uv))
+$  lode  [=keys =deps =refs]
+$  code  (map fold:tarball lode)
+$  bins  (map @uv [refs=@ud =built])
::  A "grub" is the entity that lives at a rail: its file content and
::  its running process, considered as one thing. You create, delete,
::  poke, and watch grubs. When the distinction matters, "file" means
::  the data (content) and "process" means the running fiber.
::
::  Grubs live in directories. Directories hold grubs and other
::  directories, may have a neck identifying a nexus, and may have a weir
::  (sandbox rules).
::
+$  from  rail:tarball               :: source grub (absolute rail)
+$  give  [=from =wire]             :: return address for poke acks
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
+$  weir  weir:tarball
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
+$  make  (each bole:tarball [=bask:tarball blot=(unit blot:tarball)])
+$  kept  (set bend:tarball)
::
+$  wave  (axal [fold=cass:clay file=(map @ta cass:clay)])
+$  view
  $%  [%ball =wave ball=ball:tarball]
      [%file =cass:clay =sang:tarball]
      [%none ~]
      [%miss ~]
      [%veto ~]
      [%tomb ~]
  ==
+$  cite
  $%  [%file =cass:clay lobe=jobe conv=(unit blot:tarball)]
      [%ball =wave lobe=jobe deep=?]
      [%none ~]
      [%miss ~]
      [%veto ~]
      [%tomb ~]
  ==
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
  $%  [%poke =bask:tarball]     :: poke a grub
      [%make force=? gain=? =make]  :: create grub or directory; gain: born with retention on
      [%cull ~]                 :: delete grub or directory
      [%sand weir=(unit weir)]  :: set weir
      [%load ~]                 :: trigger on-load for a nexus (folds only)
      [%peek blot=(unit blot:tarball) case=(unit case) deep=?]
                                       :: read a grub
                                       :: blot: convert file sage to this blot
                                       :: case: if set, read historical version
                                       :: deep: %.y recurse subdirs, %.n shallow
                                       :: remote: dest under /sys/ames/ships/[ship]/root/
      [%keep blot=(unit blot:tarball)]  :: subscribe to changes at dest (grub or ball per road)
                                       :: blot: if set, convert file sage in news
      [%drop ~]                 :: unsubscribe from dest
      [%lose =lose]             :: drop hist entries, decrement silo refs
      [%gain flag=?]            :: set gain flag (recursive on directories)
      [%firm ~]                 :: promote current entry to %firm
      [%tag case=(unit case) tags=(set @t)]  :: set tags on hist entry (~ = current)
      [%seek =nobe]              :: find all [rail cass] pairs with this hash
      [%peep =find]
      [%born ~]                 :: read hist metadata at dest (file or fold)
      [%code ~]                 :: look up compiled artifacts at dest
      [%font ~]                 :: find code responsible for dest node
  ==
+$  dart
  $%  [%node =wire road=road:tarball =load]
      [%here =wire]
      [%kept =wire]              :: see your own outgoing subscriptions
  ==
::  Eyre action: poke payload for HTTP binding/response operations.
::  Nexuses poke %grubbery with %eyre-action to register bindings
::  and send HTTP responses.
::
+$  eyre-action
  $%  [%bind =binding:eyre handler=rail:tarball]
      [%bind-self =binding:eyre]
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
::  Stored as a grub at /sys/behn/main.behn-state.
::
+$  behn-state
  [%0 timers=(map [=rail:tarball =wire] @da)]
::  Iris HTTP client service state.
::  Stored as a grub at /sys/iris/main.iris-state.
::
+$  iris-state
  [%0 requests=(map wire [sender=rail:tarball url=@t])]
::  Remote-scry service state: outstanding keens, keyed by the arvo
::  wire each was passed on. Lets a yawn cancel by duct (ames %yawn
::  matches the listener's duct, i.e. the original wire) exactly the
::  requesting grub's keens at a spar, leaving other grubs' keens at
::  the same spar parked — the longpoll pattern has many grubs on one
::  name, so a by-spar %wham would cancel them all.
::  Stored as a grub at /sys/scry/main.scry-state.
::
+$  scry-state
  [%0 keens=(map wire [=ship pax=path sender=rail:tarball])]
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
::  Usergroups registry action.
::  Poked to /sys/ames/registry with blot [/usergroups %registry-action].
::
+$  registry-action
  $%  [%register =rail:tarball pax=path]
      [%deregister =rail:tarball clean=?]
      [%how group=path =weir]
      [%gc ~]
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
  ::  Fiber bends always target grubs (rail), not directories.
  ::  Pokes come from grubs, pokes go to grubs.
  ::
  +$  bend  (pair @ud rail:tarball)   :: fiber-relative: steps up + target grub
  +$  from  bend
  +$  road  (each rail:tarball bend)
  ::
  +$  intake
    $%  [%poke =from =sage:tarball] :: command for a running process (from is relative)
        [%peek =wire =view] :: local read result
        [%kept =wire =kept]              :: your outgoing subscriptions
        [%made =wire err=(unit tang)] :: response to make
        [%gone =wire err=(unit tang)] :: response to cull
        [%pack =wire err=(unit tang)] :: response from poke; tang is generic if not allowed to peek
        [%sand =wire err=(unit tang)] :: response to sand
        [%load =wire err=(unit tang)] :: response to load
        [%lost =wire err=(unit tang)] :: response to lose
        [%gain =wire err=(unit tang)] :: response to gain
        [%held =wire err=(unit tang)] :: response to firm
        [%seek =wire res=(each (list [=rail:tarball =cass:clay]) tang)] :: response to seek
        [%peep =wire res=(each (list [=cass:clay =sage:tarball]) tang)] :: response to peep
        [%born =wire res=(each (list [=cass:clay tags=(set @t) tomb=?]) tang)] :: hist metadata

        [%fell =wire]                 :: subscription canceled (weir change, deletion, etc)
        [%news =wire =wave] :: subscription wave (initial or update)
        [%veto =dart] :: notify that a dart was sandboxed
        [%code =wire res=(each (axal (map @ta built)) built)]  :: code subtree or single artifact
        [%font =wire res=(unit (unit bend:tarball))]  :: ~: blocked, [~ ~]: none, [~ ~ bend]: found
        [%here =wire =here]
    ==
  ::  +$  pend: cold intake for queuing. No vases — lobes and ckeys only.
  ::  Hydrated to intake at consumption time.
  ::
  +$  pend
    $%  [%poke =from =bask:tarball]
        [%peek =wire =cite]
        [%peep =wire res=(each (list [=cass:clay lobe=jobe]) tang)]
        [%code =wire res=(each (axal (map @ta @uv)) (each @uv tang))]
        [%news =wire =wave]
        [%kept =wire =kept]
        [%made =wire err=(unit tang)]
        [%gone =wire err=(unit tang)]
        [%pack =wire err=(unit tang)]
        [%sand =wire err=(unit tang)]
        [%load =wire err=(unit tang)]
        [%lost =wire err=(unit tang)]
        [%gain =wire err=(unit tang)]
        [%held =wire err=(unit tang)]
        [%seek =wire res=(each (list [=rail:tarball =cass:clay]) tang)]
        [%born =wire res=(each (list [=cass:clay tags=(set @t) tomb=?]) tang)]
        [%fell =wire]
        [%veto =dart]
        [%font =wire res=(unit (unit bend:tarball))]
        [%here =wire =here]
    ==
  ::
  +$  input
    $:  state=vase       :: state for which we are responsible
        in=(unit intake) :: command/response/data to ingest (null means start)
    ==
  ::
  +$  take  [give=(unit give) in=(unit pend)]
  :: Three situations for process initialization
  ::
  +$  prod  (unit tang)    :: ~ = clean start, [~ tang] = crash recovery
  ::
  ::  THE TRANSACTION IS THE ARROW: a form is $-(input output), and
  ::  one invocation — one input (a null kick counts) in, one verb
  ::  out — is the atomic unit. On %wait/%skip/%cont/%done, everything
  ::  the invocation produced (state transition, darts) is permanent
  ::  and complete. On %fail, the invocation contributes nothing but
  ::  the nack: its state and darts are annulled, and every prior
  ::  invocation's contribution stands. Consumption follows the same
  ::  grain: %done/%wait/%cont consume the input (success ack), %fail
  ::  consumes it (nack), %skip alone defers it to the successor.
  ::
  ++  output-raw
    |*  value=mold
    $~  [~ * %done *value]
    $:  darts=(list dart)
        state=*
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
      [~ q.state %done value]
    :: the default for a grub with no handler: wait on rise, CRASH on
    :: any real input. the failing input nacks its poke; the crashed
    :: process then nacks further pokes immediately; a prod restarts
    :: it to wait again, crashing on the next input. pokes into
    :: handlerless grubs therefore always nack instead of vanishing.
    ::
    ++  stay
      ^-  form
      |=  input
      ^-  output
      ?~  in  [~ q.state %wait ~]
      [~ q.state %fail ~[leaf+"inert: no handler for input"]]
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
  --
::
+$  pipe   [bang=(unit tang) proc=(map @ta proc:fiber)]
+$  pool   (axal pipe)
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
  $%  [%firm p=(unit jobe)]
      [%temp p=(unit jobe)]
      [%tomb ~]
  ==
++  hist
  =<  hist
  |%
  ++  cor   |=([a=cass:clay b=cass:clay] (lth ud.a ud.b))
  +$  entry  [=pace tags=(set @t)]
  +$  hist  ((mop cass:clay entry) cor)
  ++  hon    ((on cass:clay entry) cor)
  ::  +get-pace: look up just the pace at a revision (ignoring tags)
  ::
  ++  get-pace
    |=  [=hist cas=cass:clay]
    ^-  (unit pace)
    (bind (get:hon hist cas) |=(=entry pace.entry))
  ::  +put-pace: store a pace with empty tags at a revision
  ::
  ++  put-pace
    |=  [=hist cas=cass:clay =pace]
    ^-  ^hist
    (put:hon hist cas [pace ~])
  ::  +tag: set the tags on an existing hist entry (replace — the caller
  ::  hands the full desired set, so this both adds and removes). Tags are
  ::  ordinary mutable metadata on the entry; %lose still tombstones the
  ::  whole revision, this just rewrites its label set.
  ::
  ++  tag
    |=  [=hist cas=cass:clay tags=(set @t)]
    ^-  ^hist
    =/  got=(unit entry)  (get:hon hist cas)
    ?~  got  hist
    (put:hon hist cas u.got(tags tags))
  ++  top
    |=  =hist
    ^-  (unit cass:clay)
    =/  got=(unit [key=cass:clay val=entry])  (ram:hon hist)
    ?~  got  ~
    `key.u.got
  ++  ver
    |=  =hist
    ^-  @ud
    ud:(need (top hist))
  --
::
+$  born  (axal [fold=hist file=(map @ta hist)])
::  jobe/nobe: same atom as lobe:clay, but the alias says which
::  silo store the hash names. Pace and cite lobes are always
::  jobes; leaf content and bangs are always nobes. Use the alias
::  in every signature so kind confusion is visible at the type.
::
::  Jects hash the file-as-experienced: noun, mark (compile key
::  included), health. A mark recompile changes what a file means,
::  so it changes the file's identity; reload detection, vale, snap,
::  and subscribers depend on exactly this. Deliberate — don't
::  "purify" these to content-only hashes. Anything wanting pure
::  data identity (dedup, signatures, version control) builds it as
::  a separate projection on top.
::
+$  jobe  lobe:clay                ::  hash naming a ject (jects.silo)
+$  nobe  lobe:clay                ::  hash naming a noun (nouns.silo)
+$  leaf
  $:  lobe=nobe
      mark=[=blot:tarball ckey=@uv ns=path]
      gain=?
      bang=(unit nobe)
  ==
+$  tree
  $:  nek=(unit [=neck:tarball ckey=@uv ns=path])
      gain=?
      bang=(unit nobe)
      fil=(map @ta jobe)
      dir=(map @ta [lobe=jobe weir=(unit weir)])
  ==
+$  ject
  $%  [%leaf =leaf]
      [%tree =tree]
  ==
+$  vale  (map [nobe @uv] (unit tang))
::  kind-separated lobe sets: never flatten jects and nouns into one
::  bag — every silo operation is kind-directed, so consumers must
::  know which store a lobe lives in.
::
+$  lobes  [jects=(set jobe) nouns=(set nobe)]
+$  silo
  $:  nouns=(map nobe [refs=@ud =noun])
      jects=(map jobe [refs=@ud =ject])
  ==
::  Resolve a hist case to a lobe from the hist mop
::  %ud: exact match on revision number
::  %da: latest entry with da <= target date
::
::  +resolve-case: map a case (version) to its stored revision. A miss
::  is ~ — an ORDINARY lookup outcome, never a crash. Callers decide
::  what "that version isn't here" means (a %miss view, a 404, a skip).
::
++  resolve-case
  |=  [cas=case =hist]
  ^-  (unit [cass=cass:clay pace=pace:^hist])
  ?-    -.cas
      %ud
    =/  entries=(list [key=cass:clay val=entry:^hist])
      (tap:hon:^hist hist)
    |-
    ?~  entries  ~
    ?:  =(ud.key.i.entries p.cas)
      `[key.i.entries pace.val.i.entries]
    $(entries t.entries)
      %da
    =/  entries=(list [key=cass:clay val=entry:^hist])
      (tap:hon:^hist hist)
    ::  tap gives ascending order; find latest entry with da <= target
    =/  best=(unit [cass:clay pace:^hist])  ~
    |-
    ?~  entries  best
    ?:  (gth da.key.i.entries p.cas)  best
    $(entries t.entries, best `[key.i.entries pace.val.i.entries])
  ==
::  +record-trees: Snapshot directory state into tree objects.
::  Walks from dir up to root. At each level, builds a tree from
::  grub hists (fil) and child fold hists (dir), content-addresses it,
::  and only bumps fold if the hash changed. Stops propagating when
::  a level produces the same hash.
::
++  record-trees
  |=  [=born =silo =code now=@da dir=path]
  ^-  [^born ^silo]
  =/  sub-born=^born  (~(dip of born) dir)
  =/  boo  ~(. bo now born)
  =/  top-fold  top:hist
  =/  top-hist  top:hist
  =/  node=[fold=hist file=(map @ta hist)]
    (fall fil.sub-born default-node:boo)
  ::  existing tree ject from silo (for neck + child weirs)
  =/  existing-tree=(unit tree)
    =/  fold-top=(unit cass:clay)  (top-fold fold.node)
    ?~  fold-top  ~
    =/  got=(unit pace:hist)  (get-pace:hist fold.node u.fold-top)
    ?~  got  ~
    ?:  ?=(%tomb -.u.got)  ~
    ?~  p.u.got  ~
    =/  jot  (~(get by jects.silo) u.p.u.got)
    ?~  jot  ~
    ?.  ?=(%tree -.ject.u.jot)  ~
    `tree.ject.u.jot
  ::  nek: nexus identity + ckey from existing tree ject
  =/  nek=(unit [=neck:tarball ckey=@uv ns=path])
    ?~  existing-tree  ~
    ?~  nek.u.existing-tree  ~
    =/  =neck:tarball  neck.u.nek.u.existing-tree
    =/  nex-ns=(unit fold:tarball)
      =/  pax=path  dir
      |-
      =/  cod=(list @ta)
        ?~  pax  /code
        (snoc (snip `(list @ta)`pax) %code)
      ?:  (~(has by code) cod)  `cod
      ?~  pax  ~
      $(pax (snip `(list @ta)`pax))
    =/  nex-ckey=@uv
      ?~  nex-ns  0v0
      =/  =lode  (~(got by code) u.nex-ns)
      =/  node=(unit (map @ta @uv))  (~(get of refs.lode) (weld /nex path.neck))
      ?~  node  0v0
      (fall (~(get by u.node) name.neck) 0v0)
    `[neck nex-ckey (fall nex-ns /)]
  ::  fil: each grub's current ject-lobe from hist (skip deleted/tombed)
  =/  fil=(map @ta jobe)
    %-  ~(rep by file.node)
    |=  [[name=@ta sk=hist] out=(map @ta jobe)]
    =/  cas=(unit cass:clay)  (top-hist sk)
    ?~  cas  out
    =/  val=(unit pace:hist)  (get-pace:hist sk u.cas)
    ?~  val  out
    ?:  ?=(%tomb -.u.val)  out
    ?~  p.u.val  out
    (~(put by out) name u.p.u.val)
  ::  dir: each child's latest tree lobe + weir from existing tree
  =/  dir-map=(map @ta [jobe weir=(unit weir)])
    %-  ~(rep by dir.sub-born)
    |=  [[name=@ta kid=^born] out=(map @ta [jobe weir=(unit weir)])]
    =/  kid-node=(unit [fold=hist file=(map @ta hist)])  fil.kid
    ?~  kid-node  out
    =/  cas=(unit cass:clay)  (top-fold fold.u.kid-node)
    ?~  cas  out
    =/  got=(unit pace:hist)
      (get-pace:hist fold.u.kid-node u.cas)
    ?~  got  out
    ?:  ?=(%tomb -.u.got)  out
    ?~  p.u.got  out
    =/  kid-weir=(unit weir)
      ?~  existing-tree  ~
      =/  entry  (~(get by dir.u.existing-tree) name)
      ?~  entry  ~
      weir.u.entry
    (~(put by out) name [u.p.u.got kid-weir])
  ::  Build tree object + store via put-tree
  =/  tree-gain=?  ?~(existing-tree %.n gain.u.existing-tree)
  =/  tree-bang=(unit nobe)  ?~(existing-tree ~ bang.u.existing-tree)
  =/  =tree  [nek tree-gain tree-bang fil dir-map]
  =/  [changed=? new-born=^born new-silo=^silo]
    (put-tree born silo now dir node tree)
  ?.  changed  [born silo]
  ?~  dir  [new-born new-silo]
  $(born new-born, silo new-silo, dir (snip `path`dir))
::  +put-tree: store a tree ject at dir, update born fold hist.
::  Returns [changed born silo].
::
++  put-tree
  |=  [=born =silo now=@da dir=path node=[fold=hist file=(map @ta hist)] =tree]
  ^-  [changed=? ^born ^silo]
  =/  new-lobe=jobe  `@uvI`(sham [%tree tree])
  =/  top-fold  top:hist
  =/  fold-cas=(unit cass:clay)  (top-fold fold.node)
  =/  cur-lobe=(unit jobe)
    =/  cur-pace=(unit pace:hist)
      ?~  fold-cas  ~
      (get-pace:hist fold.node u.fold-cas)
    ?~  cur-pace  ~
    ?:  ?=(%tomb -.u.cur-pace)  ~
    p.u.cur-pace
  ?:  =(`new-lobe cur-lobe)
    [%.n born silo]
  =/  [* new-silo=^silo]
    (~(put-ject si silo) [%tree tree])
  ::  Tombstone previous %temp fold entry
  =/  [tombed-silo=^silo tombed-fold=hist]
    ?~  fold-cas  [new-silo fold.node]
    (~(tomb-temp si new-silo) fold.node u.fold-cas)
  =.  silo  tombed-silo
  =/  old-fold=cass:clay  (fall fold-cas [0 now])
  =/  new-fold=cass:clay
    =/  nex-da=@da  ?:((lth da.old-fold now) now +(da.old-fold))
    [+(ud.old-fold) nex-da]
  =/  =pace:hist  ?:(gain.tree [%firm `new-lobe] [%temp `new-lobe])
  =/  new-hist=hist
    (put-pace:hist tombed-fold new-fold pace)
  =.  born  (~(put of born) dir node(fold new-hist))
  [%.y born silo]
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
  |_  [now=@da old=born]
  ::  Default node with initial hist entry
  ::
  ++  default-node
    ^-  [fold=hist file=(map @ta hist)]
    =/  zero=cass:clay  [0 now]
    [[[zero [[%temp ~] ~]] ~ ~] ~]
  ::  Get hist for a file
  ::
  ++  get
    |=  here=rail:tarball
    ^-  (unit hist)
    =/  node=(unit [fold=hist file=(map @ta hist)])
      (~(get of old) path.here)
    ?~  node  ~
    (~(get by file.u.node) name.here)
  ::  Put hist for a file
  ::
  ++  put
    |=  [here=rail:tarball sok=hist]
    ^-  born
    =/  node=[fold=hist file=(map @ta hist)]
      (fall (~(get of old) path.here) default-node)
    (~(put of old) path.here node(file (~(put by file.node) name.here sok)))
  ::  Get dir cass
  ::
  ++  get-dir-cass
    |=  dir=fold:tarball
    ^-  (unit cass:clay)
    =/  top-fold  top:hist
    =/  node=(unit [fold=hist file=(map @ta hist)])
      (~(get of old) dir)
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
      (put here [[zero [[%temp ~] ~]] ~ ~])
    (put here u.existing)
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
    ^-  nobe
    `@uvI`(sham noun)
  ::  Insert noun, increment refcount if exists. Returns lobe and new silo.
  ::
  ++  put
    |=  =noun
    ^-  [nobe ^silo]
    =/  lobe=nobe  (hash noun)
    =/  got  (~(get by nouns.silo) lobe)
    ?~  got
      [lobe silo(nouns (~(put by nouns.silo) lobe [0 noun]))]
    [lobe silo]
  ::  Decrement refcount, delete if zero.
  ::
  ++  drop
    |=  lobe=nobe
    ^-  ^silo
    =/  got  (~(get by nouns.silo) lobe)
    ?~  got
      ~&  >>>  [%silo-drop-noun-absent lobe]
      silo
    ?:  (lte refs.u.got 1)
      silo(nouns (~(del by nouns.silo) lobe))
    silo(nouns (~(put by nouns.silo) lobe [refs=(dec refs.u.got) noun.u.got]))
  ::  Look up noun by lobe.
  ::
  ++  get
    |=  lobe=nobe
    ^-  (unit noun)
    =/  got  (~(get by nouns.silo) lobe)
    ?~  got  ~
    `noun.u.got
  ::  Drop refs for all ject lobes in a hist.
  ::
  ++  drop-hist
    |=  =hist
    ^-  ^silo
    =/  entries=(list [key=cass:clay val=entry:^hist])
      (tap:hon:^hist hist)
    |-
    ?~  entries  silo
    =/  pv=pace:^hist  pace.val.i.entries
    ?:  ?=(%tomb -.pv)  $(entries t.entries)
    ?~  p.pv  $(entries t.entries)
    $(entries t.entries, silo (drop-ject u.p.pv))
  ::  Increment noun refcount by lobe (must exist).
  ::
  ++  bump-ref
    |=  lobe=nobe
    ^-  ^silo
    =/  got  (~(get by nouns.silo) lobe)
    ?~  got
      ~&  >>>  [%silo-bump-noun-absent lobe]
      silo
    silo(nouns (~(put by nouns.silo) lobe [+(refs.u.got) noun.u.got]))
  ::  Increment ject refcount by lobe (must exist).
  ::
  ++  bump-ject-ref
    |=  lobe=jobe
    ^-  ^silo
    =/  got  (~(get by jects.silo) lobe)
    ?~  got
      ~&  >>>  [%silo-bump-ject-absent lobe]
      silo
    silo(jects (~(put by jects.silo) lobe [+(refs.u.got) ject.u.got]))
  ::  Insert ject, increment refcount if exists.
  ::  On first insert, bumps refs on all referenced nouns and child jects.
  ::  Children MUST already be in the silo — the bump silently no-ops
  ::  on absent lobes. Batch callers must insert bottom-up (leaves
  ::  before the trees that reference them).
  ::
  ++  put-ject
    |=  =ject
    ^-  [jobe ^silo]
    =/  lobe=jobe  `@uvI`(sham ject)
    =/  got  (~(get by jects.silo) lobe)
    ?^  got
      [lobe silo(jects (~(put by jects.silo) lobe [+(refs.u.got) ject]))]
    ::  new ject — store it, then bump refs on children
    =.  jects.silo  (~(put by jects.silo) lobe [1 ject])
    ?-  -.ject
        %leaf
      =.  silo  (~(bump-ref si silo) lobe.leaf.ject)
      =?  silo  ?=(^ bang.leaf.ject)  (~(bump-ref si silo) u.bang.leaf.ject)
      [lobe silo]
        %tree
      =?  silo  ?=(^ bang.tree.ject)  (~(bump-ref si silo) u.bang.tree.ject)
      =.  silo
        %-  ~(rep by fil.tree.ject)
        |=  [[* =jobe] =_silo]
        (~(bump-ject-ref si silo) jobe)
      =.  silo
        %-  ~(rep by dir.tree.ject)
        |=  [[* =jobe *] =_silo]
        (~(bump-ject-ref si silo) jobe)
      [lobe silo]
    ==
  ::  Decrement ject refcount, delete if zero.
  ::
  ++  drop-ject
    |=  lobe=jobe
    ^-  ^silo
    =/  got  (~(get by jects.silo) lobe)
    ?~  got
      ~&  >>>  [%silo-drop-ject-absent lobe]
      silo
    ?.  (lte refs.u.got 1)
      silo(jects (~(put by jects.silo) lobe [refs=(dec refs.u.got) ject.u.got]))
    ::  refs hit zero — delete ject and cascade to children
    =.  jects.silo  (~(del by jects.silo) lobe)
    =/  jt=ject  ject.u.got
    ?-  -.jt
        %leaf
      =.  silo  (~(drop si silo) lobe.leaf.jt)
      ?~(bang.leaf.jt silo (~(drop si silo) u.bang.leaf.jt))
        %tree
      =?  silo  ?=(^ bang.tree.jt)  (~(drop si silo) u.bang.tree.jt)
      =.  silo
        %-  ~(rep by fil.tree.jt)
        |=  [[* =jobe] =_silo]
        (~(drop-ject si silo) jobe)
      %-  ~(rep by dir.tree.jt)
      |=  [[* =jobe *] =_silo]
      (~(drop-ject si silo) jobe)
    ==
  ::  Collect all lobes reachable from a root ject lobe (transitive closure).
  ::  Returns kind-separated ject and noun lobes.
  ::
  ++  reachable
    |=  root=jobe
    ^-  lobes
    =|  out=lobes
    =|  seen=(set jobe)
    =|  queue=(list jobe)
    =.  queue  ~[root]
    |-
    ?~  queue  out
    =/  cur=jobe  i.queue
    ?:  (~(has in seen) cur)
      $(queue t.queue)
    =.  seen  (~(put in seen) cur)
    ::  everything on the queue was referenced as a ject
    =.  jects.out  (~(put in jects.out) cur)
    =/  got  (~(get by jects.silo) cur)
    ?~  got  $(queue t.queue)
    =/  jt=ject  ject.u.got
    ?-  -.jt
        %leaf
      =.  nouns.out  (~(put in nouns.out) lobe.leaf.jt)
      =?  nouns.out  ?=(^ bang.leaf.jt)  (~(put in nouns.out) u.bang.leaf.jt)
      $(queue t.queue)
        %tree
      =?  nouns.out  ?=(^ bang.tree.jt)  (~(put in nouns.out) u.bang.tree.jt)
      =/  fil-lobes=(list jobe)
        (turn ~(val by fil.tree.jt) |=(=jobe jobe))
      =/  dir-lobes=(list jobe)
        (turn ~(val by dir.tree.jt) |=([=jobe *] jobe))
      $(queue (weld t.queue (weld fil-lobes dir-lobes)))
    ==
  ::  Shallow reachable: like +reachable but doesn't recurse into
  ::  subdirectory lobes. Collects the root tree ject, its files'
  ::  leaf jects + nouns, but treats dir lobes as opaque.
  ::
  ++  reachable-shallow
    |=  root=jobe
    ^-  lobes
    =|  out=lobes
    =.  jects.out  (~(put in jects.out) root)
    =/  got  (~(get by jects.silo) root)
    ?~  got  out
    =/  jt=ject  ject.u.got
    ?-  -.jt
        %leaf
      =.  nouns.out  (~(put in nouns.out) lobe.leaf.jt)
      =?  nouns.out  ?=(^ bang.leaf.jt)  (~(put in nouns.out) u.bang.leaf.jt)
      out
        %tree
      =?  nouns.out  ?=(^ bang.tree.jt)  (~(put in nouns.out) u.bang.tree.jt)
      ::  Include file lobes and their leaf contents
      =/  fil-entries=(list [name=@ta =jobe])
        ~(tap by fil.tree.jt)
      |-
      ?~  fil-entries  out
      =/  fl=jobe  jobe.i.fil-entries
      =.  jects.out  (~(put in jects.out) fl)
      =/  fgot  (~(get by jects.silo) fl)
      =?  nouns.out  &(?=(^ fgot) ?=(%leaf -.ject.u.fgot))
        (~(put in nouns.out) lobe.leaf.ject.u.fgot)
      =?  nouns.out  &(?=(^ fgot) ?=(%leaf -.ject.u.fgot) ?=(^ bang.leaf.ject.u.fgot))
        (~(put in nouns.out) u.bang.leaf.ject.u.fgot)
      $(fil-entries t.fil-entries)
    ==
  ::  Set bang on an existing ject.  Stores the tang as a noun,
  ::  builds a new ject with bang=`tang-lobe, drops the old ject,
  ::  and returns the new ject lobe.
  ::
  ++  set-bang
    |=  [old-lobe=jobe err=tang]
    ^-  [jobe ^silo]
    =/  got  (~(get by jects.silo) old-lobe)
    ?~  got  [old-lobe silo]
    ::  store tang noun in silo
    =/  [tang-lobe=nobe mid-silo=^silo]  (~(put si silo) err)
    ::  build new ject with bang set
    =/  new-ject=ject
      ?-  -.ject.u.got
        %leaf  [%leaf leaf.ject.u.got(bang `tang-lobe)]
        %tree  [%tree tree.ject.u.got(bang `tang-lobe)]
      ==
    =/  [new-jobe=jobe fin-silo=^silo]
      (~(put-ject si mid-silo) new-ject)
    ::  drop old ject ref
    =.  fin-silo  (~(drop-ject si fin-silo) old-lobe)
    [new-jobe fin-silo]
  ::  Clear bang on an existing ject.  Builds a new ject with bang=~,
  ::  drops the old ject and the old bang noun ref.
  ::  Returns ~ if ject has no bang or doesn't exist.
  ::
  ++  clear-bang
    |=  old-lobe=jobe
    ^-  (unit [lobe=jobe =^silo])
    =/  got  (~(get by jects.silo) old-lobe)
    ?~  got  ~
    =/  old-bang=(unit nobe)
      ?-  -.ject.u.got
        %leaf  bang.leaf.ject.u.got
        %tree  bang.tree.ject.u.got
      ==
    ?~  old-bang  ~  :: no bang to clear
    ::  build new ject with bang cleared
    =/  new-ject=ject
      ?-  -.ject.u.got
        %leaf  [%leaf leaf.ject.u.got(bang ~)]
        %tree  [%tree tree.ject.u.got(bang ~)]
      ==
    =/  [new-jobe=jobe mid-silo=^silo]
      (~(put-ject si silo) new-ject)
    ::  drop old ject ref (cascades to drop old bang noun ref)
    =.  mid-silo  (~(drop-ject si mid-silo) old-lobe)
    `[new-jobe mid-silo]
  ::  Tombstone previous %temp entry in hist, dropping silo refs.
  ::  %firm entries are left untouched.
  ::
  ++  tomb-temp
    |=  [=hist prev-cas=cass:clay]
    ^-  [^silo ^hist]
    =/  prev-pace=(unit pace:^hist)  (get-pace:^hist hist prev-cas)
    ?~  prev-pace  [silo hist]
    ?.  ?=(%temp -.u.prev-pace)  [silo hist]
    =.  silo
      ?~  p.u.prev-pace  silo
      (~(drop-ject si silo) u.p.u.prev-pace)
    [silo (put-pace:^hist hist prev-cas [%tomb ~])]
  ::  Record a noun: insert into silo, update hist.
  ::  Returns [lobe new-silo new-hist].
  ::
  ::  gain=%.y: entry is %firm (permanent until explicitly tombed).
  ::  gain=%.n: entry is %temp (dropped on next write).
  ::
  ++  record
    |=  $:  =noun
            =blot:tarball
            ckey=@uv
            ns=path
            gain=?
            =cass:clay
            file-cass=cass:clay
            =hist
        ==
    ^-  [nobe ^silo ^hist]
    ::  Look up previous leaf ject
    =/  prev-leaf=(unit leaf)
      =/  prev-pace=(unit pace:^hist)  (get-pace:^hist hist file-cass)
      ?~  prev-pace  ~
      ?:  ?=(%tomb -.u.prev-pace)  ~
      ?~  p.u.prev-pace  ~
      =/  got  (~(get by jects.silo) u.p.u.prev-pace)
      ?~  got  ~
      ?.  ?=(%leaf -.ject.u.got)  ~
      `leaf.ject.u.got
    ::  Skip if blot, governing marc, namespace, and content are unchanged
    =/  noun-lobe=nobe  (hash noun)
    ?:  ?&  ?=(^ prev-leaf)
            =(noun-lobe lobe.u.prev-leaf)
            =(blot blot.mark.u.prev-leaf)
            =(ckey ckey.mark.u.prev-leaf)
            =(ns ns.mark.u.prev-leaf)
            =(gain gain.u.prev-leaf)
        ==
      [noun-lobe silo hist]
    =/  prev-bang=(unit nobe)
      ?~(prev-leaf ~ bang.u.prev-leaf)
    ::  Store noun, then wrap as leaf ject
    =/  new-silo=^silo
      ?^  (~(get by nouns.silo) noun-lobe)  silo
      silo(nouns (~(put by nouns.silo) noun-lobe [0 noun]))
    =/  [ject-lobe=jobe newer-silo=^silo]
      (~(put-ject si new-silo) [%leaf noun-lobe [blot ckey ns] gain prev-bang])
    =/  [tombed-silo=^silo tombed-hist=^hist]
      (~(tomb-temp si newer-silo) hist file-cass)
    =/  =pace:^hist  ?:(gain [%firm `ject-lobe] [%temp `ject-lobe])
    [noun-lobe tombed-silo (put-pace:^hist tombed-hist cass pace)]
  --
::  +stamp-mtimes: no-op (metadata removed from content)
::
++  stamp-mtimes
  |=  [=born b=ball:tarball]
  ^-  ball:tarball
  b
::  +wave-from-born: build wave (axal of cass) from born (axal of hist)
::
++  wave-from-born
  |=  =born
  ^-  wave
  =/  top-hist  top:hist
  :-  ?~  fil.born  ~
      :-  ~
      :-  (fall (top-hist fold.u.fil.born) *cass:clay)
      (~(run by file.u.fil.born) |=(sk=hist (fall (top-hist sk) *cass:clay)))
  (~(run by dir.born) |=(kid=^born ^$(born kid)))
::
::  +wave-at: build wave subtree at a target lane from born
::  Used for subscription responses — returns the wave dipped to target.
::
++  wave-at
  |=  [=born target=lane:tarball]
  ^-  wave
  =/  pax=path
    ?-(-.target %| p.target, %& path.p.target)
  =/  sub-born=^born  (~(dip of born) pax)
  (wave-from-born sub-born)
::
::  +diff-wave: compare two waves, return map of changed lanes with new cass
::
++  diff-wave
  =|  here=path
  =|  out=(map lane:tarball cass:clay)
  |=  [old=wave new=wave]
  ^-  (map lane:tarball cass:clay)
  ::  Compare fold (directory-level version)
  =/  old-fold=cass:clay  ?~(fil.old *cass:clay fold.u.fil.old)
  =/  new-fold=cass:clay  ?~(fil.new *cass:clay fold.u.fil.new)
  =?  out  !=(old-fold new-fold)
    (~(put by out) [%| here] new-fold)
  ::  Compare files
  =/  old-file=(map @ta cass:clay)  ?~(fil.old ~ file.u.fil.old)
  =/  new-file=(map @ta cass:clay)  ?~(fil.new ~ file.u.fil.new)
  =/  all-names=(list @ta)
    ~(tap in (~(uni in ~(key by old-file)) ~(key by new-file)))
  =.  out
    |-
    ?~  all-names  out
    =/  old-cas=cass:clay  (fall (~(get by old-file) i.all-names) *cass:clay)
    =/  new-cas=cass:clay  (fall (~(get by new-file) i.all-names) *cass:clay)
    =?  out  !=(old-cas new-cas)
      (~(put by out) [%& here i.all-names] new-cas)
    $(all-names t.all-names)
  ::  Recurse into subdirectories
  =/  all-kids=(list @ta)
    ~(tap in (~(uni in ~(key by dir.old)) ~(key by dir.new)))
  |-
  ?~  all-kids  out
  =/  old-kid=wave  (fall (~(get by dir.old) i.all-kids) *wave)
  =/  new-kid=wave  (fall (~(get by dir.new) i.all-kids) *wave)
  %=  $
    all-kids  t.all-kids
    out
      %=  ^$
        here  (snoc here i.all-kids)
        old   old-kid
        new   new-kid
        out   out
      ==
  ==
::
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
  ::  Unchanged subtrees are shared nouns: equal means nothing changed
  ?:  =(old new)  ~
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
  ::  Compare file hists (skip when the map is the shared, unchanged noun)
  =.  result
    =/  old-file=(map @ta hist)  ?~(fil.old ~ file.u.fil.old)
    =/  new-file=(map @ta hist)  ?~(fil.new ~ file.u.fil.new)
    ?:  =(old-file new-file)  result
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
  =?  result  !=(old-kid new-kid)
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
  =/  old-files=(map @ta [=sang:tarball gain=? bang=(unit tang)])
    ?~(fil.old ~ contents.u.fil.old)
  =/  new-files=(map @ta [=sang:tarball gain=? bang=(unit tang)])
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
          !=((~(got by old-files) i.all-names) (~(got by new-files) i.all-names))
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
::  Cross-ship remote protocol
::
::  Load: outbound requests to a remote ship's grubbery.
::  Simple operations (make/cull/sand/load/poke/over) route through
::  the dart system as if they came from /sys/ames/ships/[ship]/ship.sig.
::
::  Peek: content-addressed read with have/want negotiation.
::  Flow: peek → snap (pace + reachable refs) → want (missing lobes) → data (silo subset).
::  The requesting ship tracks outstanding peeks in a +peeks map,
::  keyed by [requester-rail wire]. When all refs are locally present
::  in the silo, the peek is discharged: pace is written to +afar
::  and the requesting grub is notified.
::
::  Keep: cross-ship subscriptions. Subscriber sends %keep, publisher
::  registers in local subs with watcher=ship.sig. On changes, publisher
::  pushes waves (lane→cass). Subscriber delivers %news to local grubs.
::  Subscriber routes via /sys/ames/ships/[ship]/root/[path] namespace.
::
::  Intake: inbound responses from a remote ship.
::  %snap delivers the resolved pace and reachable content hashes.
::  %data delivers the silo subset (jects + nouns) for requested lobes.
::  Initial and ongoing waves both delivered as %news.
::  %wave delivers ongoing wave updates.
::
++  remo
  =<  remo
  |%
  +$  remo  [=peeks =snaps]
  +$  load
    $:  [=wire dest=lane:tarball]
        $%  [%make force=? gain=? =make]
            [%cull ~]
            [%sand weir=(unit weir)]
            [%load ~]
            [%poke =bask:tarball]
            [%peek case=(unit case) deep=?]
            [%keep ~]
            [%drop ~]
        ==
    ==
  ::  Runtime-to-runtime content-addressed negotiation.
  ::  Separate from load (dart-like ops) and intake (subscription events).
  ::
  +$  transfer
    $:  =wire
        ::  %snap's data field carries the content inline when the
        ::  server judged it cheaper to send than to negotiate — the
        ::  receiver merges it on arrival and skips the want/data
        ::  legs. Wire-only: inline data is never stored in a peek.
        $%  [%snap dest=lane:tarball snap-id=@uvJ snap=(unit snap) data=(unit silo)]
            [%veto dest=lane:tarball]
            [%want dest=lane:tarball snap-id=@uvJ]
            [%data =silo]
            [%miss ~]
            ::  consumption result of a %poke load the sender ran for
            ::  us; wire is the sender-encoded return address from
            ::  +dart-poke's remote branch. The cross-ship form of a %pack.
            [%pack err=(unit tang)]
        ==
    ==
  +$  make  (each bole:tarball [=bask:tarball blot=(unit blot:tarball)])
  ::  Inbound subscription events from remote watchers.
  ::
  +$  intake  [=wire dest=lane:tarball =wave]
  ::  Staged peek state: tracks an outstanding cross-ship peek
  ::  from initiation through negotiation to discharge.
  ::  snap is ~ until %snap response arrives with pace + refs.
  ::
  +$  snap   [=cass:clay =pace refs=lobes]
  +$  peek   [ship=@p dest=lane:tarball deep=? blot=(unit blot:tarball) snap=(unit snap) snap-id=@uvJ]
  +$  peeks  (map [rail:tarball wire] peek)
  +$  snaps  (map [@uvJ @p] [dest=lane:tarball refs=lobes expiry=@da])
  --
+$  ack   (unit tang)
+$  upki  (unit rail:tarball) :: urbit PKI source in the namespace
+$  last  [now=@da eny=@uvJ]  :: monotonic time and entropy
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
::  Relativize an absolute source rail to a fiber bend.
::
++  relativize-from
  |=  [here=rail:tarball =from]
  ^-  from:fiber
  =/  pref=path  (prefix:tarball path.here path.from)
  =/  here-tail=path  (need (decap:tarball pref path.here))
  =/  src-tail=path  (need (decap:tarball pref path.from))
  [(lent here-tail) [src-tail name.from]]
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
    |~  ball:tarball
    *bole:tarball
  :: every grub has a running process alongside its file content.
  :: processes should be able to recover proper operation based on
  ::   state alone, even when restarted. this is not guaranteed and
  ::   is a responsibility of the programmer.
  ::
  ++  on-file
    |~  [rail:tarball blot:tarball]
    *spool:fiber :: define spool (initializer) for grub at rail
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
      |=  [key=cass:clay val=entry:hist]
      %-  pairs:enjs:format
      :~  ['ud' (numb:enjs:format ud.key)]
          ['da' s+(scot %da da.key)]
          :-  'pace'
          ?-  -.pace.val
            %tomb  s+'tomb'
            %firm
          ?~  p.pace.val  s+'deleted'
          s+(cat 3 'firm+' (scot %uv u.p.pace.val))
            %temp
          ?~  p.pace.val  s+'deleted'
          s+(cat 3 'temp+' (scot %uv u.p.pace.val))
          ==
          :-  'tags'
          ?:  ?=(%tomb -.pace.val)  ~
          a+(turn ~(tap in tags.val) |=(t=@t s+t))
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
            |=  [key=cass:clay val=entry:hist]
            %-  pairs:enjs:format
            :~  ['ud' (numb:enjs:format ud.key)]
                ['da' s+(scot %da da.key)]
                :-  'pace'
                ?-  -.pace.val
                  %tomb  s+'tomb'
                  %firm
                ?~  p.pace.val  s+'deleted'
                s+(cat 3 'firm+' (scot %uv u.p.pace.val))
                  %temp
                ?~  p.pace.val  s+'deleted'
                s+(cat 3 'temp+' (scot %uv u.p.pace.val))
                ==
                :-  'tags'
                ?:  ?=(%tomb -.pace.val)  ~
                a+(turn ~(tap in tags.val) |=(t=@t s+t))
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
++  ball-weirs-to-json
  |=  b=ball:tarball
  ^-  json
  =/  subdirs=json  [%o (~(run by dir.b) ball-weirs-to-json)]
  =/  weir=(unit weir)  ?~(fil.b ~ weir.u.fil.b)
  ?~  weir
    (pairs:enjs:format ~[['dirs' subdirs]])
  %-  pairs:enjs:format
  :~  ['weir' (weir-to-json u.weir)]
      ['dirs' subdirs]
  ==
--
