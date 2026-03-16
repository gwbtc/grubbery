/+  nexus, tarball, io=fiberio
^-  nexus:nexus
!:  :: turn on stack trace
|%
++  on-load
  |=  [=sand:nexus =gain:nexus =ball:tarball]
  ^-  [sand:nexus gain:nexus ball:tarball]
  =.  ball  (~(put ba:tarball ball) [/ %'ver.ud'] [~ %ud !>(0)])
  ::  Create /sys directory with system processes
  =?  ball  =(~ (~(get of ball) /sys))
    (~(put of ball) /sys [~ ~ ~])
  =?  ball  =(~ (~(get ba:tarball ball) [/sys %'main.sig']))
    (~(put ba:tarball ball) [/sys %'main.sig'] [~ %sig !>(~)])
  ::  Create /server.server directory with neck=%server
  =?  ball  =(~ (~(get of ball) /'server.server'))
    (~(put of ball) /'server.server' [~ `%server ~])
  ::  Create /counter.counter directory with neck=%counter
  =?  ball  =(~ (~(get of ball) /'counter.counter'))
    (~(put of ball) /'counter.counter' [~ `%counter ~])
  ::  Create /explorer.explorer directory with neck=%explorer
  =?  ball  =(~ (~(get of ball) /'explorer.explorer'))
    (~(put of ball) /'explorer.explorer' [~ `%explorer ~])
  ::  Create /peers.peers directory with neck=%peers
  ::  All foreign ship interaction goes through here.
  ::  Peers nexus manages gateway processes, usergroups, and weirs.
  =?  ball  =(~ (~(get of ball) /'peers.peers'))
    (~(put of ball) /'peers.peers' [~ `%peers ~])
  ::  Create /claude.claude directory with neck=%claude
  =?  ball  =(~ (~(get of ball) /'claude.claude'))
    (~(put of ball) /'claude.claude' [~ `%claude ~])
  ::  Create /mcp.mcp directory with neck=%mcp
  =?  ball  =(~ (~(get of ball) /'mcp.mcp'))
    (~(put of ball) /'mcp.mcp' [~ `%mcp ~])
  ::  Create /sys/build.build directory with neck=%build
  =?  ball  =(~ (~(get of ball) /sys/'build.build'))
    (~(put of ball) /sys/'build.build' [~ `%build ~])
  ::  Create /config/creds directory if not present
  =?  ball  =(~ (~(get of ball) /config))
    (~(put of ball) /config [~ ~ ~])
  =?  ball  =(~ (~(get of ball) /config/creds))
    (~(put of ball) /config/creds [~ ~ ~])
  ::  Enable history retention for dill and jael grubs
  =/  dill-jael=(list rail:tarball)
    :~  [/sys/dill %'logs.dill-told']
        [/sys/jael %'private-keys.jael-private-keys']
        [/sys/jael %'public-keys.jael-public-keys-result']
    ==
  =.  gain
    %+  roll  dill-jael
    |=  [here=rail:tarball gn=_gain]
    =/  node=(map @ta ?)  (fall (~(get of gn) path.here) ~)
    (~(put of gn) path.here (~(put by node) name.here %.y))
  [sand gain ball]
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
