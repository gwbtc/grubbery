/+  nexus, tarball, io=fiberio, loader
^-  nexus:nexus
!:  :: turn on stack trace
|%
++  on-load
  |=  [=sand:nexus =gain:nexus =ball:tarball]
  ^-  [sand:nexus gain:nexus ball:tarball]
  =/  =ver:loader  (get-ver:loader ball)
  ?+  ver  !!
      ?(~ [~ %0])
    %+  spin:loader  [sand gain ball]
    :~  (ver-row:loader 0)
        [%fall %& [/sys %'main.sig'] %.n [~ %sig !>(~)]]
        ::  child nexuses
        [%fall %| /'server.server' [~ ~] [~ ~] [`[~ `%server ~] ~]]
        [%fall %| /'counter.counter' [~ ~] [~ ~] [`[~ `%counter ~] ~]]
        [%fall %| /'explorer.explorer' [~ ~] [~ ~] [`[~ `%explorer ~] ~]]
        [%fall %| /'peers.peers' [~ ~] [~ ~] [`[~ `%peers ~] ~]]
        [%fall %| /'claude.claude' [~ ~] [~ ~] [`[~ `%claude ~] ~]]
        :: [%fall %| /'mcp.mcp' [~ ~] [~ ~] [`[~ `%mcp ~] ~]]
        [%fall %| /sys/'build.build' [~ ~] [~ ~] [`[~ `%build ~] ~]]
        ::  config
        [%fall %| /config/creds [~ ~] [~ ~] empty-dir:loader]
        ::  system internals — populated by app/grubbery.hoon before
        ::  on-load runs. Must be preserved or the framework breaks.
        [%fall %| /sys/daises [~ ~] [~ ~] empty-dir:loader]
        [%fall %| /sys/nexuses [~ ~] [~ ~] empty-dir:loader]
        [%fall %| /sys/tubes [~ ~] [~ ~] empty-dir:loader]
        [%fall %| /sys/clay [~ ~] [~ ~] empty-dir:loader]
        [%fall %| /sys/dill [~ ~] [~ ~] empty-dir:loader]
        [%fall %| /sys/jael [~ ~] [~ ~] empty-dir:loader]
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
      [[%sys ~] %'main.sig']
    ;<  ~  bind:m  (rise-wait:io prod "%sys /main: failed, poke to restart")
    stay:m
  ==
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
      Each subdirectory with a neck (e.g. server.server/) is a child
      nexus managed by its own nex/ file.

      NEXUSES:
        server.server/     HTTP gateway. Routes requests to handler nexuses.
        claude.claude/     AI chat via Anthropic API.
        mcp.mcp/           MCP (Model Context Protocol) JSON-RPC tool server.
        explorer.explorer/ Web-based tarball file browser.
        counter.counter/   Auto-incrementing counters with live UI.
        peers.peers/       External ship gateway with role-based access control.
        wallet.wallet/     Bitcoin wallet management.

      SYSTEM:
        sys/               System internals — build compiler, terminal logs,
                           cryptographic keys, root main process.
        config/            User configuration and credentials.
      """
        [%sys ~]
      %-  crip
      """
      sys/ — System internals.

      SUBDIRECTORIES:
        build.build/    Hoon compiler nexus. Compiles /src/ to /bin/.
        dill/           Terminal I/O logs. Mark: dill-told. History retained.
        jael/           Cryptographic key storage. History retained.
                        private-keys.jael-private-keys — ship private keys.
                        public-keys.jael-public-keys-result — PKI cache.

      FILES:
        main.sig        Root system process. Mark: sig.
      """
        [%config ~]
      %-  crip
      """
      config/ — User configuration.

      SUBDIRECTORIES:
        creds/          API keys and service credentials. Files here are
                        read by nexuses that need them (e.g. claude reads
                        config.json for its API key, MCP tools read
                        telegram tokens, S3 keys, etc).
      """
        [%config %creds ~]
      'Credentials store. Service API keys and tokens. Files are read by nexuses on demand.'
    ==
      %|
    ?+  rail.p.mana  'File under the root nexus.'
      [~ %'ver.ud']         'Schema version counter. Mark: ud. Incremented on structural migrations in on-load.'
      [[%sys ~] %'main.sig']  'Root system process. Mark: sig. Manages system-level coordination.'
    ==
  ==
--
