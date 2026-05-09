::  Root nexus — hardcoded in app/grubbery.hoon, not loaded from code namespace.
::
/+  nexus, tarball, loader, io=fiberio, ball-api, http-utils
^-  nexus:nexus
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
        ::  /sys/eyre: runtime-managed HTTP state + request fibers
        ::
        [%fall %| /sys/eyre [~ ~] [~ ~] [`[~ ~ ~] ~]]
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
        peer/           Foreign ship management. Runtime-owned.
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
        [%sys %peer ~]
      %-  crip
      """
      sys/peer/ — Foreign ship management (runtime-owned).

      Foreign pokes are emitted as darts from ship.sig, filtered by
      the weir on the ship's directory. Weirs are computed from
      usergroups and recompute atomically on any change.

      SUBDIRECTORIES:
        usergroups/who/   Group membership. Each file is a (set @p).
                          Nested paths supported (e.g. /who/acme/eng).
        usergroups/how/   Weir templates per group. Each file is a weir.
                          /how/public applies to ALL foreign ships.
        ships/            Per-ship directories, created lazily.
                          Each has a ship.sig grub and a computed weir.
      """
        [%sys %peer %usergroups ~]
      'Usergroup definitions. /who/ has membership sets (set @p), /how/ has weir templates. Groups control what foreign ships can access.'
        [%sys %peer %usergroups %who ~]
      'Group membership. Each file contains a (set @p). Nested paths supported.'
        [%sys %peer %usergroups %how ~]
      'Weir templates per group. Each file contains a weir:nexus. /how/public applies to all ships.'
        [%sys %peer %ships ~]
      'Per-ship directories. Created lazily on first foreign poke. Each contains ship.sig with a weir computed from usergroups.'
    ==
      %|
    ?+  rail.p.mana  'File under the root nexus.'
      [~ %'ver.ud']         'Schema version counter. Mark: ud. Incremented on structural migrations in on-load.'
    ==
  ==
--
