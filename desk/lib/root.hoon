::  Root nexus — hardcoded in app/grubbery.hoon, not loaded from code namespace.
::
/+  nexus, tarball, loader, io=fiberio, ball-api, http-utils, server
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  [=sand:nexus =gain:nexus =ball:tarball]
      ^-  [sand:nexus gain:nexus ball:tarball]
      =/  =ver:loader  ~  :: (get-ver:loader ball)
      ?+  ver  !!
          ?(~ [~ %0])
        %+  spin:loader  [sand gain ball]
        :~  (ver-row:loader 0)
            [%load %| / / same-fold:loader]
            [%fall %| /apps [~ ~] [~ ~] [`[~ ~ ~] ~]]
            [%fall %| /docs [~ ~] [~ ~] [`[~ ~ ~] ~]]
            ::  /sys/eyre: HTTP server state + request fibers
            ::
            [%fall %| /sys/eyre [~ ~] [~ ~] [`[~ ~ ~] ~]]
            [%fall %& [/sys/eyre %'main.server-state'] %.n [~ [/ %server-state] !>(*server-state:nexus)]]
            [%fall %| /sys/eyre/requests [~ ~] [~ ~] [`[~ ~ ~] ~]]
            ::  /sys/behn: timer service
            ::
            [%fall %| /sys/behn [~ ~] [~ ~] [`[~ ~ ~] ~]]
            [%fall %& [/sys/behn %'main.timer-state'] %.n [~ [/ %timer-state] !>(*timer-state:nexus)]]
            ::  /sys/iris: HTTP client service
            ::
            [%fall %| /sys/iris [~ ~] [~ ~] [`[~ ~ ~] ~]]
            [%fall %& [/sys/iris %'main.iris-state'] %.n [~ [/ %iris-state] !>(*iris-state:nexus)]]
            ::  /sys/clay: desk sync service (state + desks/ subdir)
            ::
            [%fall %& [/sys/clay %'main.clay-state'] %.n [~ [/ %clay-state] !>(*clay-state:nexus)]]
            [%fall %| /sys/clay/desks [~ ~] [~ ~] [`[~ ~ ~] ~]]
            ::  /sys/scry: scry service
            ::
            [%fall %| /sys/scry [~ ~] [~ ~] [`[~ ~ ~] ~]]
            [%fall %& [/sys/scry %'main.sig'] %.n [~ [/ %sig] !>(~)]]
            ::  child nexuses
            ::
            [%fall %| /apps/'counter.counter' [~ ~] [~ ~] [`[~ `[/ %counter] ~] ~]]
            [%fall %| /apps/'explorer.explorer' [~ ~] [~ ~] [`[~ `[/ %explorer] ~] ~]]
            [%fall %| /apps/'mcp.mcp' [~ ~] [~ ~] [`[~ `[/ %mcp] ~] ~]]
            [%fall %| /apps/'peers.peers' [~ ~] [~ ~] [`[~ `[/ %peers] ~] ~]]
        ==
      ==
    ::
    ++  on-file
      |=  [=rail:tarball mak=mark]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::  /sys/eyre/main.server-state: HTTP server fiber
          ::  Manages bindings, dispatches requests, proxies responses.
          ::
          [[%sys %eyre ~] %'main.server-state']
        ;<  ~  bind:m  (rise-wait:io prod "%eyre /state: failed")
        ::  Register /grubbery/api with eyre
        ;<  ~  bind:m
          %-  send-cards:io
          [%pass /eyre-api %arvo %e %connect [~ /grubbery/api] dap:io]~
        ::  Server loop
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        ;<  here=rail:tarball  bind:m  get-here-abs:io
        ;<  st=server-state:nexus  bind:m  (get-state-as:io ,server-state:nexus)
        ?+    name.p.sage  $
            ::  Eyre action: bind, unbind, send
            ::
            %eyre-action
          =+  !<(act=eyre-action:nexus q.sage)
          ?-    -.act
              %bind
            ~&  >  [%eyre-bind binding.act handler.act]
            =.  bindings.st  (~(put by bindings.st) binding.act handler.act)
            ;<  ~  bind:m  (replace:io !>(st))
            ;<  ~  bind:m
              %-  send-cards:io
              [%pass /eyre-bind %arvo %e %connect binding.act dap:io]~
            $
          ::
              %unbind
            ~&  >  [%eyre-unbind binding.act]
            =/  orphans=(list @ta)
              %+  murn  ~(tap by conns.st)
              |=  [eid=@ta =binding:eyre]
              ?.  =(binding binding.act)  ~
              `eid
            ;<  ~  bind:m
              %-  send-cards:io
              %+  turn  orphans
              |=  eid=@ta
              ^-  card:agent:gall
              [%give %kick ~[/http-response/[eid]] ~]
            =.  conns.st
              %-  ~(gas by *(map @ta binding:eyre))
              %+  skip  ~(tap by conns.st)
              |=  [eid=@ta =binding:eyre]
              =(binding binding.act)
            =.  bindings.st  (~(del by bindings.st) binding.act)
            ;<  ~  bind:m  (replace:io !>(st))
            $
          ::
              %send
            =/  conn-binding=(unit binding:eyre)
              (~(get by conns.st) eyre-id.act)
            ?~  conn-binding
              ::  Unknown connection — poke sender back with cancel
              ?.  ?=(%& -.from)  $
              =/  sender-rail=rail:tarball
                (resolve-bend:io here p.from)
              ;<  ~  bind:m
                (poke:io [%& %& sender-rail] [[/ %handle-http-cancel] !>(eyre-id.act)])
              $
            =/  cards=(list card:agent:gall)
              (eyre-response-cards eyre-id.act eyre-update.act)
            ?:  ?=(?(%kick %simple) -.eyre-update.act)
              =.  conns.st  (~(del by conns.st) eyre-id.act)
              ;<  ~  bind:m  (replace:io !>(st))
              ;<  ~  bind:m  (send-cards:io cards)
              $
            ;<  ~  bind:m  (send-cards:io cards)
            $
          ==
        ==
          ::  /sys/eyre/requests/*: ball API request fibers
          ::
          [[%sys %eyre %requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%eyre /requests: failed")
        =/  eyre-id=@ta  name.rail
        ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
        =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
        (dispatch:ball-api eyre-id src req site args)
        ::
          ::  /sys/behn/main.timer-state: runtime-hooked (no fiber)
          ::  Timer pokes intercepted in app/grubbery.hoon handle-dart.
          ::  Behn wakes handled in app/grubbery.hoon on-arvo.
          ::
          [[%sys %behn ~] %'main.timer-state']
        stay:m
          ::  /sys/iris/main.iris-state: runtime-hooked (no fiber)
          ::  HTTP request pokes intercepted in app/grubbery.hoon handle-dart.
          ::  Iris responses handled in app/grubbery.hoon on-arvo.
          ::
          [[%sys %iris ~] %'main.iris-state']
        stay:m
          ::  /sys/clay/main.clay-state: runtime-hooked (no fiber)
          ::  Mount/unmount pokes intercepted in app/grubbery.hoon handle-dart.
          ::
          [[%sys %clay ~] %'main.clay-state']
        stay:m
          ::  /sys/scry/main.sig: runtime-hooked (no fiber)
          ::  Scry request pokes intercepted in app/grubbery.hoon handle-dart.
          ::
          [[%sys %scry ~] %'main.sig']
        stay:m
          ::  /sys/dill/main.sig: runtime-hooked (no fiber)
          ::  Belt pokes intercepted in app/grubbery.hoon handle-dart.
          ::
          [[%sys %dill ~] %'main.sig']
        stay:m
          ::  /sys/gall/main.sig: runtime-hooked (no fiber)
          ::  Agent pokes intercepted in app/grubbery.hoon handle-dart.
          ::
          [[%sys %gall ~] %'main.sig']
        stay:m
      ==
    ::
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'Subdirectory under the root nexus.'
            ~
          %-  crip
          """
          GRUBBERY ROOT — top-level tarball

          The root nexus bootstraps all system nexuses and user data.
          Each subdirectory with a neck (e.g. counter.counter/) is a child
          nexus managed by its own nex/ file.

          NEXUSES:
            mcp.mcp/           MCP (Model Context Protocol) JSON-RPC tool server.
            explorer.explorer/ Web-based tarball file browser.
            counter.counter/   Auto-incrementing counters with live UI.
            wallet.wallet_app/ Bitcoin wallet management with per-wallet nexuses.
            indexer.indexer_app/ Bitcoind block cache. Polls RPC, caches blocks.

          SYSTEM:
            sys/               System internals — build compiler, terminal logs,
                               cryptographic keys, virtual bowl files, eyre state.
          """
            [%sys ~]
          %-  crip
          """
          sys/ — System internals.

          SUBDIRECTORIES:
            code/           Compiled marks, nexuses, daises, tubes, and libraries.
            dill/           Terminal I/O logs. Mark: dill-told. History retained.
            eyre/           HTTP binding state and request fibers.
            jael/           Cryptographic key storage. History retained.
                            private-keys.jael-private-keys — ship private keys.
                            public-keys.jael-public-keys-result — PKI cache.
            ames/           Foreign ship management. Runtime-owned.
                            Weirs recompute atomically on usergroup changes.
                            ships/~ship/ship.sig — virtual grub per foreign ship.
          """
            [%sys %eyre ~]
          %-  crip
          """
          sys/eyre/ — HTTP binding state and request fibers.

          FILES:
            main.server-state    Active bindings and connection tracking.
                                Runtime-managed, cleared on reload.

          DIRECTORIES:
            requests/           Per-request fibers for /grubbery/api/ endpoints.
                                Each inbound API request spawns a short-lived
                                fiber here, cleaned up on response or disconnect.
          """
            [%sys %eyre %requests ~]
          'Active HTTP request fibers. Each inbound API request spawns a fiber here; cleaned up on completion or client disconnect.'
            [%sys %behn ~]
          %-  crip
          """
          sys/behn/ — Timer service.

          FILES:
            main.timer-state    Timer proxy. Receives timer-set pokes from
                                sandboxed fibers, proxies to behn, pokes back
                                timer-wake when fired.
          """
            [%sys %ames ~]
          %-  crip
          """
          sys/ames/ — Foreign ship management (runtime-owned).

          Foreign pokes are emitted as darts from ship.sig, filtered by
          the weir on the ship's directory. Weirs are computed from
          usergroups and recompute atomically on any change.

          SUBDIRECTORIES:
            usergroups/       Per-group directories. Each contains:
                                who.ships — group membership (set @p).
                                how.weir  — weir template for the group.
                              The 'public' group applies to ALL foreign ships.
            ships/            Per-ship directories, created lazily.
                              Each has a ship.sig grub and a computed weir.
          """
            [%sys %ames %usergroups ~]
          'Per-group directories. Each group is a directory containing who.ships (members) and how.weir (permissions).'
            [%sys %ames %ships ~]
          'Per-ship directories. Created lazily on first foreign poke. Each contains ship.sig with a weir computed from usergroups.'
        ==
          %|
        ?+  rail.p.mana  'File under the root nexus.'
            [~ %'ver.ud']         'Schema version counter. Mark: ud. Incremented on structural migrations in on-load.'
            [[%sys %eyre ~] %'main.server-state']  'HTTP server state. Manages bindings, dispatches requests, proxies responses.'
            [[%sys %behn ~] %'main.timer-state']  'Timer proxy. Receives timer-set pokes, forwards to behn, pokes back timer-wake on fire.'
        ==
      ==
    --
::  Helper arms for the server fiber
::
|%
::  Eyre helpers
::
++  eyre-response-cards
  |=  [eyre-id=@ta upd=eyre-update:nexus]
  ^-  (list card:agent:gall)
  ?-    -.upd
      %header
    [%give %fact ~[/http-response/[eyre-id]] http-response-header+!>(response-header.upd)]~
      %data
    [%give %fact ~[/http-response/[eyre-id]] http-response-data+!>(data.upd)]~
      %kick
    [%give %kick ~[/http-response/[eyre-id]] ~]~
      %simple
    (give-simple-payload:app:server eyre-id simple-payload.upd)
  ==
--
