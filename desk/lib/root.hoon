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
            [%fall %& [/sys/eyre %'state.server-state'] %.n [~ [/ %server-state] !>(*server-state:nexus)]]
            [%fall %| /sys/eyre/requests [~ ~] [~ ~] [`[~ ~ ~] ~]]
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
          ::  /sys/eyre/state.server-state: HTTP server fiber
          ::  Manages bindings, dispatches requests, proxies responses.
          ::
          [[%sys %eyre ~] %'state.server-state']
        ;<  ~  bind:m  (rise-wait:io prod "%eyre /state: failed")
        ::  Clear state on reload — nexuses re-bind on startup
        ;<  ~  bind:m  (replace:io !>(*server-state:nexus))
        ::  Register /grubbery/api with eyre
        ;<  =dude:gall  bind:m  get-agent:io
        ;<  ~  bind:m
          %-  send-cards:io
          [%pass /eyre-api %arvo %e %connect [~ /grubbery/api] dude]~
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
            ;<  =dude:gall  bind:m  get-agent:io
            ;<  ~  bind:m
              %-  send-cards:io
              [%pass /eyre-bind %arvo %e %connect binding.act dude]~
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
            ::  Incoming HTTP request from eyre
            ::
            %handle-http-request
          =/  [eyre-id=@ta src=@p req=inbound-request:eyre]
            !<([eyre-id=@ta @p inbound-request:eyre] q.sage)
          =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
          ::  Ball API: dispatch to /requests/{eyre-id} fiber
          ?:  ?=([%grubbery %api *] site)
            ~&  >  [%eyre-api eyre-id url.request.req]
            ;<  ~  bind:m
              (make:io [%| 0 %& /requests eyre-id] |+[%.n [[/ %http-request] !>([src req])] ~])
            $
          ::  Binding match: find handler, forward request
          =/  match=(unit [=binding:eyre handler=rail:tarball])
            (find-eyre-binding bindings.st site)
          ?~  match
            ~&  >  [%eyre-no-binding site]
            ;<  ~  bind:m
              %-  send-cards:io
              (give-simple-payload:app:server eyre-id [[404 ~] `(as-octs:mimes:html 'Not Found')])
            $
          ~&  >  [%eyre-dispatch binding.u.match handler.u.match]
          =.  conns.st  (~(put by conns.st) eyre-id binding.u.match)
          ;<  ~  bind:m  (replace:io !>(st))
          ;<  ~  bind:m
            (poke:io [%& %& handler.u.match] [[/ %handle-http-request] !>([eyre-id src req])])
          $
            ::  Client disconnected (eyre on-leave)
            ::
            %handle-http-cancel
          =/  eyre-id=@ta  !<(@ta q.sage)
          ~&  >  [%eyre-cancel eyre-id]
          =/  conn-binding=(unit binding:eyre)  (~(get by conns.st) eyre-id)
          =.  conns.st  (~(del by conns.st) eyre-id)
          ;<  ~  bind:m  (replace:io !>(st))
          ::  No binding = ball API request — cull the request fiber
          ?~  conn-binding
            ;<  *  bind:m  (cull-soft:io [%| 0 %& /requests eyre-id])
            $
          ::  Bound request — forward cancel to handler
          =/  handler=rail:tarball
            (fall (~(get by bindings.st) u.conn-binding) *rail:tarball)
          ;<  ~  bind:m
            (poke:io [%& %& handler] [[/ %handle-http-cancel] !>(eyre-id)])
          $
        ==
          ::  /sys/eyre/requests/*: ball API request fibers
          ::
          [[%sys %eyre %requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%eyre /requests: failed")
        =/  eyre-id=@ta  name.rail
        ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
        =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
        (dispatch:ball-api eyre-id src req site args)
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
            state.server-state    Active bindings and connection tracking.
                                Runtime-managed, cleared on reload.

          DIRECTORIES:
            requests/           Per-request fibers for /grubbery/api/ endpoints.
                                Each inbound API request spawns a short-lived
                                fiber here, cleaned up on response or disconnect.
          """
            [%sys %eyre %requests ~]
          'Active HTTP request fibers. Each inbound API request spawns a fiber here; cleaned up on completion or client disconnect.'
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
            [[%sys %eyre ~] %'state.server-state']  'HTTP server state. Manages bindings, dispatches requests, proxies responses.'
        ==
      ==
    --
::  Helper arms for the server fiber
::
|%
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
::
++  find-eyre-binding
  |=  [bindings=(map binding:eyre rail:tarball) site=path]
  ^-  (unit [=binding:eyre handler=rail:tarball])
  =|  best=(unit [=binding:eyre handler=rail:tarball])
  =/  entries=(list [=binding:eyre handler=rail:tarball])
    ~(tap by bindings)
  |-
  ?~  entries  best
  =/  suffix=(unit path)
    =+  [prefix=path.binding.i.entries full=site]
    |-  ^-  (unit path)
    ?~  prefix  `full
    ?~  full    ~
    ?.  =(i.prefix i.full)  ~
    $(prefix t.prefix, full t.full)
  ?~  suffix
    $(entries t.entries)
  ?~  best  $(best `i.entries, entries t.entries)
  ?:  (gth (lent path.binding.i.entries) (lent path.binding.u.best))
    $(best `i.entries, entries t.entries)
  $(entries t.entries)
--
