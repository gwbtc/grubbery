::  peers nexus: external ship gateway + role-based access control
::
::  All foreign ship interaction enters through /peers. Each ship gets
::  a gateway process at /ships/~ship/main that handles bidirectional
::  pokes. Usergroups provide role-based weir management: group
::  membership determines what each ship can reach.
::
::  /peers/
::    /main          inbound poke router + weir manager
::    /usergroups/   role-based access data
::      /who/        group → members: /who/admins → (set @p)
::                     hierarchical: /who/acme/eng/leads → (set @p)
::      /how/        group → weir template: /how/admins → weir
::                     /how/public weir is applied to ALL ships
::    /ships/        per-ship directories, created lazily on first poke
::                     our own ship lives here too, with full tree access
::                     (skips usergroup lookup entirely)
::      /~zod/       weir derived from union of group weir templates
::        /main      inbound gateway: page → cage, forward to tree
::
::  Inbound poke flow (%poke-in):
::    1. Foreign ship pokes grubbery with [dest =page]
::    2. Grubbery forwards %poke-in to /peers/main
::    3. /peers/main creates /ships/~src/ dir+gateway if absent
::    4. /peers/main forwards %poke-in to /ships/~src/main
::    5. Gateway asserts from is /peers/main (trusted router)
::    6. Converts page to cage, forwards to dest in tree
::
::  Outbound poke flow (%poke-out):
::    1. Tree process pokes /peers/main with %poke-out [ship dude page]
::    2. /peers/main sends Gall poke to [ship dude] (has syscall access)
::
::  Weir strategy:
::    /peers/ has a permissive weir (full tree, no syscalls). Anything
::    leaving /peers/ gets clammed. Ship dirs have tighter weirs derived
::    from usergroup membership. /peers/main watches /who, /how, and
::    /ships, recalculating and %sand'ing weirs reactively.
::
::  Security:
::    The gateway enforces provenance on %poke-in: only accepted from
::    /peers/main (the trusted inbound router). Grubs cannot forge
::    inbound pokes. %poke-out goes through /peers/main which has
::    syscall access (ship gateways don't — weirs block syscalls).
::
/+  nexus, tarball, io=fiberio
!: :: turn on stack trace
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  [=sand:nexus =ball:tarball]
      ^-  [sand:nexus ball:tarball]
      ::  Create /main file (weir manager) if not present
      =?  ball  =(~ (~(get ba:tarball ball) [/ %main]))
        (~(put ba:tarball ball) [/ %main] [~ %sig !>(~)])
      ::  Create /usergroups directory (role-based access data)
      =?  ball  =(~ (~(get of ball) /usergroups))
        (~(put of ball) /usergroups [~ ~ ~])
      ::  Create /usergroups/who - group membership sets
      =?  ball  =(~ (~(get of ball) /usergroups/who))
        (~(put of ball) /usergroups/who [~ ~ ~])
      ::  Create /usergroups/how - weir templates per group
      =?  ball  =(~ (~(get of ball) /usergroups/how))
        (~(put of ball) /usergroups/how [~ ~ ~])
      ::  Create /ships directory (ship dirs created lazily)
      ::  Permissive weir: ships can reach the full tree from here.
      ::  Per-ship weirs narrow access for each foreign ship.
      =?  ball  =(~ (~(get of ball) /ships))
        (~(put of ball) /ships [~ ~ ~])
      =/  root-roads=(set road:tarball)  (sy [%& %| /]~)
      =.  sand  (~(put of sand) /ships [root-roads root-roads root-roads])
      [sand ball]
    ::
    ++  on-file
      |=  [=rail:tarball =mark]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ::  NOTE: we switch on rail alone because ?+ [rail mark] doesn't
      ::  narrow rail's subfaces (path.rail stays (list @ta), breaks
      ::  i.t.path.rail). Mark is asserted inside each case instead.
      ::
      ?+    rail  stay:m
        ::  /main: poke router + weir manager
        ::  Routes inbound %poke-in to per-ship gateways,
        ::  lazily creating ship directories on first contact.
        ::  Watches /who, /how, and /ships for changes, re-syncs all
        ::  ship weirs on any change. /ships is watched to prevent
        ::  rogue weir manipulation — any unauthorized weir change
        ::  gets immediately overwritten with the correct computed
        ::  weir. set-weir is idempotent (no-op if weir unchanged),
        ::  so our own sanding triggers a second no-op sync.
        ::  TODO: consider making this more granular (e.g. use
        ::  diff-born to scope work to changed ships only) to avoid
        ::  the redundant pass.
        ::
          [~ %main]
        ?>  ?=(%sig mark)
        ;<  ~  bind:m  (rise-wait:io prod "%peers /main: failed, poke to restart")
        ~&  >  "%peers /main: starting"
        ;<  ~  bind:m  (keep:io /watch-who [%| 0 %| /usergroups/who])
        ;<  ~  bind:m  (keep:io /watch-how [%| 0 %| /usergroups/how])
        ;<  ~  bind:m  (keep:io /watch-ships [%| 0 %| /ships])
        |-
        ;<  =main-event  bind:m  take-main-event
        ?-    -.main-event
            %poke
          =/  =from:fiber:nexus  from.main-event
          =/  =cage  cage.main-event
          ?+    p.cage  $
              %peers-sync
            ~&  >  [%peers-main %sync]
            ;<  ~  bind:m  sync-all-weirs
            $
              %poke-in
            ?.  ?=(%| -.from)
              ~&  >  [%peers-main %internal-poke-rejected]
              $
            =/  src=@p  src.p.from
            ~&  >  [%peers-main %routing (scot %p src)]
            ;<  ~  bind:m  (ensure-ship-dir src)
            ;<  ~  bind:m
              (poke:io /forward [%| 0 %& [/ships/[(scot %p src)] %main]] cage)
            $
              %poke-out
            =/  [=ship =dude:gall =page]
              !<([@p dude:gall page] q.cage)
            ~&  >  [%peers-main %outbound (scot %p ship) dude]
            ;<  ~  bind:m  (gall-poke:io /outbound [ship dude] [p.page !>(q.page)])
            $
          ==
        ::
            %news
          ~&  >  [%peers-main %change-detected wire.main-event]
          ;<  ~  bind:m  sync-all-weirs
          $
        ::
            %fell
          ~&  >  [%peers-main %fell-resubscribe wire.main-event]
          ;<  ~  bind:m
            %+  keep:io  wire.main-event
            ?:  =(/watch-who wire.main-event)  [%| 0 %| /usergroups/who]
            ?:  =(/watch-how wire.main-event)  [%| 0 %| /usergroups/how]
            [%| 0 %| /ships]
          $
        ==
        ::  /ships/*/main: per-ship gateway
        ::  Per-ship gateway: receives %poke-in from /peers/main,
        ::  converts page to cage, forwards into the tree.
        ::
          [[%ships @ ~] %main]
        ?>  ?=(%sig mark)
        ;<  ~  bind:m  (rise-wait:io prod "%peers /ships/*/main: failed, poke to restart")
        =/  ship-name=@ta  i.t.path.rail
        ~&  >  [%peers-gateway ship-name %ready]
        |-
        ;<  [=from:fiber:nexus =cage]  bind:m  take-poke-from:io
        ?.  ?=(%poke-in p.cage)
          ~&  >  [%peers-gateway ship-name %unknown-mark p.cage]
          $
        ?>  ?&  ?=(%& -.from)
                =(p.from [2 [/ %main]])
            ==
        =/  [dest=rail:tarball =page]
          !<([rail:tarball page] q.cage)
        ~&  >  [%peers-gateway ship-name %inbound dest p.page]
        =/  payload=^cage  [p.page !>(q.page)]
        ;<  ~  bind:m  (poke:io /forward [%& %& dest] payload)
        $
          [[%usergroups %who *] @]
        ?>  ?=(%ships mark)  who-file
          [[%usergroups %how *] @]
        ?>  ?=(%weir mark)  how-file
      ==
    --
|%
+$  main-event
  $%  [%poke =from:fiber:nexus =cage]
      [%news =wire =view:nexus]
      [%fell =wire]
  ==
::
++  take-main-event
  =/  m  (fiber:fiber:nexus ,main-event)
  ^-  form:m
  |=  =input:fiber:nexus
  :+  ~  state.input
  ?+  in.input  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error:io dart.u.in.input)]
      [~ %poke * *]
    [%done %poke [from cage]:u.in.input]
      [~ %news * *]
    [%done %news [wire view]:u.in.input]
      [~ %fell *]
    [%done %fell wire.u.in.input]
  ==
::  /usergroups/who/**:  group membership (hierarchical paths supported)
::  State: (set @p). Pokes: %put-members, %add-member, %del-member
::
++  who-file
  |=  =input:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  output:m
  ?+  in.input  [~ state.input %skip ~]
      ~  [~ state.input %wait ~]
      [~ %poke * *]
    ?+  p.cage.u.in.input  [~ state.input %skip ~]
        %put-members  [~ q.cage.u.in.input %wait ~]
        %add-member
      =/  members  !<((set @p) state.input)
      [~ !>((~(put in members) !<(@p q.cage.u.in.input))) %wait ~]
        %del-member
      =/  members  !<((set @p) state.input)
      [~ !>((~(del in members) !<(@p q.cage.u.in.input))) %wait ~]
    ==
  ==
::  /usergroups/how/**:  weir templates (hierarchical paths supported)
::  State: weir:nexus. Pokes: %put-weir
::
++  how-file
  |=  =input:fiber:nexus
  =/  m  (fiber:fiber:nexus ,~)
  ^-  output:m
  ?+  in.input  [~ state.input %skip ~]
      ~  [~ state.input %wait ~]
      [~ %poke * *]
    ?.  =(%put-weir p.cage.u.in.input)
      [~ state.input %skip ~]
    [~ q.cage.u.in.input %wait ~]
  ==
::  Ensure /ships/~ship/ directory exists with gateway process.
::  Our ship: no weir (full tree access).
::  Foreign ship: weir computed from current usergroups.
::
++  ensure-ship-dir
  |=  src=@p
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  our=@p  bind:m  get-our:io
  =/  ship-ta=@ta  (scot %p src)
  =/  ship-dir=path  /ships/[ship-ta]
  ;<  exists=?  bind:m  (peek-exists:io /check-ship [%| 0 %| ship-dir])
  ?:  exists  (pure:m ~)
  =/  ship-ball=ball:tarball
    (~(put ba:tarball *ball:tarball) [/ %main] [~ %sig !>(~)])
  ?:  =(src our)
    (make:io /create-ship [%| 0 %| ship-dir] &+[*sand:nexus ship-ball])
  ;<  [who=(map rail:tarball (set @p)) how=(map rail:tarball weir:nexus)]  bind:m
    read-usergroups
  =/  =weir:nexus  (compute-ship-weir src (build-src who) how)
  =/  ship-sand=sand:nexus  (~(put of *sand:nexus) / weir)
  (make:io /create-ship [%| 0 %| ship-dir] &+[ship-sand ship-ball])
::  Sand weirs for all foreign ship directories from pre-built data.
::
++  sand-all-ships
  |=  $:  src=(map @p (set rail:tarball))
          how=(map rail:tarball weir:nexus)
          ships-ball=ball:tarball
      ==
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  our=@p  bind:m  get-our:io
  =/  ship-names=(list @ta)  ~(tap in ~(key by dir.ships-ball))
  |-
  ?~  ship-names  (pure:m ~)
  =/  ship-ta=@ta  i.ship-names
  =/  ship-p=(unit @p)  (slaw %p ship-ta)
  ?~  ship-p
    $(ship-names t.ship-names)
  ?:  =(u.ship-p our)
    ;<  ~  bind:m  (sand:io /sand-weir [%| 0 %| /ships/[ship-ta]] ~)
    $(ship-names t.ship-names)
  =/  =weir:nexus  (compute-ship-weir u.ship-p src how)
  ~&  >  [%peers-main %sand-weir ship-ta]
  ;<  ~  bind:m  (sand:io /sand-weir [%| 0 %| /ships/[ship-ta]] `weir)
  $(ship-names t.ship-names)
::  Full sync: read usergroups, sand all ship weirs.
::
++  sync-all-weirs
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  [who=(map rail:tarball (set @p)) how=(map rail:tarball weir:nexus)]  bind:m
    read-usergroups
  ;<  ships-seen=seen:nexus  bind:m
    (peek:io /read-ships [%| 0 %| /ships])
  ?.  ?&(?=(%& -.ships-seen) ?=(%ball -.p.ships-seen))
    ~&  >  [%peers-main %no-ships-data]
    (pure:m ~)
  =/  src=(map @p (set rail:tarball))  (build-src who)
  (sand-all-ships src how ball.p.ships-seen)
::  Peek /usergroups and return parsed who + how data
::
++  read-usergroups
  =/  m  (fiber:fiber:nexus ,[(map rail:tarball (set @p)) (map rail:tarball weir:nexus)])
  ^-  form:m
  ;<  ug-seen=seen:nexus  bind:m
    (peek:io /read-usergroups [%| 0 %| /usergroups])
  ?.  ?&(?=(%& -.ug-seen) ?=(%ball -.p.ug-seen))
    (pure:m [~ ~])
  =/  ug-ball=ball:tarball  ball.p.ug-seen
  (pure:m [(read-tree ug-ball %who (set @p)) (read-tree ug-ball %how weir:nexus)])
::  Extract typed files from a sub-directory of a ball (recursive)
::
++  read-tree
  |*  [=ball:tarball dir=@ta =mold]
  ^-  (map rail:tarball mold)
  =/  sub=ball:tarball  (~(gut by dir.ball) dir *ball:tarball)
  %-  ~(gas by *(map rail:tarball mold))
  %+  murn  ~(tap ba:tarball sub)
  |=  [=rail:tarball =content:tarball]
  ^-  (unit [rail:tarball mold])
  =/  res  (mule |.(!<(mold q.cage.content)))
  ?:(?=(%| -.res) ~ `[rail p.res])
::  Build reverse index: ship → group rails from who map
::
++  build-src
  |=  who=(map rail:tarball (set @p))
  ^-  (map @p (set rail:tarball))
  =/  groups=(list [rail:tarball (set @p)])  ~(tap by who)
  =|  acc=(map @p (set rail:tarball))
  |-
  ?~  groups  acc
  =/  [=rail:tarball members=(set @p)]  i.groups
  =/  ships=(list @p)  ~(tap in members)
  =.  acc
    |-
    ?~  ships  acc
    =/  existing=(set rail:tarball)  (fall (~(get by acc) i.ships) ~)
    $(ships t.ships, acc (~(put by acc) i.ships (~(put in existing) rail)))
  $(groups t.groups)
::  Union two weirs (merge road sets)
::
++  union-weirs
  |=  [a=weir:nexus b=weir:nexus]
  ^-  weir:nexus
  :+  (~(uni in make.a) make.b)
    (~(uni in poke.a) poke.b)
  (~(uni in peek.a) peek.b)
::  Compute the weir for a single ship from pre-built data
::
++  compute-ship-weir
  |=  $:  =ship
          src=(map @p (set rail:tarball))
          how=(map rail:tarball weir:nexus)
      ==
  ^-  weir:nexus
  =/  public-weir=weir:nexus
    (fall (~(get by how) [/ %public]) *weir:nexus)
  =/  ship-rails=(set rail:tarball)
    (fall (~(get by src) ship) ~)
  =/  ship-weir=weir:nexus
    %+  roll  ~(tap in ship-rails)
    |=  [=rail:tarball acc=weir:nexus]
    (union-weirs acc (fall (~(get by how) rail) *weir:nexus))
  (union-weirs ship-weir public-weir)
--
