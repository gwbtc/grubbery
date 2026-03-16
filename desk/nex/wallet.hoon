::  wallet nexus: bitcoin wallet management UI (stub)
::
/+  nexus, tarball, io=fiberio, server, http-utils, feather, nex-server
!: :: turn on stack trace
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  [=sand:nexus =gain:nexus =ball:tarball]
      ^-  [sand:nexus gain:nexus ball:tarball]
      =.  ball  (~(put ba:tarball ball) [/ %'ver.ud'] [~ %ud !>(0)])
      ::  Create /wallets directory if not present
      =?  ball  =(~ (~(get of ball) /wallets))
        (~(put of ball) /wallets [~ ~ ~])
      ::  Create /main.sig file if not present
      =?  ball  =(~ (~(get ba:tarball ball) [/ %'main.sig']))
        (~(put ba:tarball ball) [/ %'main.sig'] [~ %sig !>(~)])
      ::  Create /requests directory if not present
      =?  ball  =(~ (~(get of ball) /requests))
        (~(put of ball) /requests [~ ~ ~])
      [sand gain ball]
    ::
    ++  on-file
      |=  [=rail:tarball =mark]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::  /main.sig: bind paths and dispatch requests
          ::
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%wallet /main: failed")
        ~&  >  "%wallet /main: binding /grubbery/wallet"
        ;<  ~  bind:m  (bind-http:nex-server [~ /grubbery/wallet])
        ;<  ~  bind:m  (bind-http:nex-server [~ /grubbery/wallet/delete])
        ;<  ~  bind:m  (bind-http:nex-server [~ /grubbery/wallet/stream])
        ~&  >  "%wallet /main: ready"
        (http-dispatch:nex-server %wallet)
          ::  /requests/*: individual request handlers
          ::
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%wallet /requests: failed")
        =/  eyre-id=@ta  name.rail
        ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
        ;<  our=@p  bind:m  get-our:io
        ?.  =(src our)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
          (pure:m ~)
        ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
        =/  site=path  site:(parse-url:http-utils url.request.req)
        =/  suffix=path
          ?.  ?=([%grubbery %wallet *] site)  ~
          t.t.site
        ?+    suffix
          ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not Found')])
          (pure:m ~)
        ::
            ~
          ?:  ?=(%'POST' method.request.req)
            ::  Create a new wallet grub
            =/  bod=(unit octs)  body.request.req
            ?~  bod
              ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing body')])
              (pure:m ~)
            =/  params=(list [@t @t])  (fall (rush q.u.bod yquy:de-purl:html) ~)
            =/  wallet-name=@t
              |-
              ?~  params  'Unnamed'
              =/  [key=@t val=@t]  i.params
              ?:  =('wallet-name' key)  val
              $(params t.params)
            =/  wallet-key=@ta  (scot %da now.bowl)
            ;<  ~  bind:m  (make:io /make [%| 1 %& /wallets wallet-key] |+[%.n sig+!>(wallet-name) ~])
            ;<  ~  bind:m  (send-simple:srv eyre-id two-oh-four:http-utils)
            (pure:m ~)
          ::  GET /: serve wallet page
          =/  bod=octs  (manx-to-octs:server (wallet-page))
          ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils [/text/html bod]))
          (pure:m ~)
        ::
            [%delete ~]
          ?.  ?=(%'POST' method.request.req)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[405 ~] ~])
            (pure:m ~)
          =/  bod=(unit octs)  body.request.req
          ?~  bod
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing body')])
            (pure:m ~)
          =/  params=(list [@t @t])  (fall (rush q.u.bod yquy:de-purl:html) ~)
          =/  id=(unit @t)
            |-
            ?~  params  ~
            =/  [key=@t val=@t]  i.params
            ?:  =('id' key)  `val
            $(params t.params)
          ?~  id
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing id')])
            (pure:m ~)
          =/  wallet-key=@ta  u.id
          ;<  ~  bind:m  (cull:io /cull [%| 1 %& /wallets wallet-key])
          ;<  ~  bind:m  (send-simple:srv eyre-id two-oh-four:http-utils)
          (pure:m ~)
        ::
            [%stream ~]
          ?.  (is-sse-request:http-utils req)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'SSE only')])
            (pure:m ~)
          ;<  ~  bind:m  (send-header:srv eyre-id sse-header:http-utils)
          ::  Subscribe to /wallets directory
          ;<  *  bind:m  (keep:io /wallets [%| 1 %| /wallets] ~)
          ;<  ~  bind:m  (send-wait:io (add now.bowl ~s30))
          |-
          ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /wallets)
          ?-  -.nw
              %wake
            ;<  ~  bind:m  (send-data:srv eyre-id `sse-keep-alive:http-utils)
            ;<  =bowl:nexus  bind:m  (get-bowl:io /sse)
            ;<  ~  bind:m  (send-wait:io (add now.bowl ~s30))
            $
              %news
            =/  =sse-event:http-utils
              [~ `'wallet-list-update' (manx-to-wain:http-utils (render-wallets view.nw))]
            =/  data=octs  (sse-encode:http-utils ~[sse-event])
            ;<  ~  bind:m  (send-data:srv eyre-id `data)
            $
          ==
        ==
      ==
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'Inert subdirectory under the wallet nexus. No special behavior.'
          ~  'Wallet nexus. Bitcoin wallet management with web UI. /wallets/ holds wallet grubs. Serves HTML interface with SSE streaming for live updates.'
          [%wallets ~]  'Wallet storage. Each file is a wallet grub.'
        ==
          %|
        ?+  name.rail.p.mana  'Inert file under the wallet nexus. No special documentation.'
          %'main.sig'  'Wallet HTTP binding process. Serves wallet UI and handles SSE streaming.'
        ==
      ==
    --
|%
++  srv  ~(. res:nex-server [%| 1 %& ~ %'main.sig'])
::
++  render-wallets
  |=  =view:nexus
  ^-  manx
  ?.  ?=(%ball -.view)
    ;div#wallet-list: No wallets
  =/  files=(list [key=@ta =content:tarball])
    ?~  fil.ball.view  ~
    %+  sort  ~(tap by contents.u.fil.ball.view)
    |=  [[a=@ta *] [b=@ta *]]
    (aor a b)
  ?~  files
    ;div#wallet-list(style "padding: 16px; text-align: center; color: var(--f3);")
      ;p: No wallets yet. Add one below.
    ==
  ;div#wallet-list
    ;*  %+  turn  files
        |=  [key=@ta =content:tarball]
        ^-  manx
        =/  name=@t  !<(@t q.cage.content)
        ;div(style "display: flex; justify-content: space-between; align-items: center; gap: 12px; padding: 12px; background: var(--b1); border-radius: 8px; margin-bottom: 8px;")
          ;div(style "flex: 1; min-width: 0;")
            ;div(style "font-weight: bold; font-size: 16px;"): {(trip name)}
            ;div(style "font-size: 12px; color: var(--f3); font-family: monospace;"): {(scow %da (slav %da key))}
          ==
          ;form(hx-post "/grubbery/wallet/delete", hx-swap "none")
            ;input(type "hidden", name "id", value (trip key));
            ;button(type "submit", style "padding: 6px 12px; background: var(--b2); border: 1px solid var(--b3); color: var(--f3); border-radius: 4px; cursor: pointer; font-size: 12px;"): Delete
          ==
        ==
  ==
::
++  wallet-page
  |.
  ^-  manx
  ;html
    ;head
      ;title: Bitcoin Wallet
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;script(src "https://unpkg.com/htmx.org@2.0.3");
      ;script(src "https://unpkg.com/htmx-ext-sse@2.2.2/sse.js");
      ;+  feather:feather
      ;style
        ;+  ;/  style-text
      ==
    ==
    ;body
      ;div(style "max-width: 700px; margin: 0 auto; padding: 32px 16px;")
        ;div(style "text-align: center; margin-bottom: 24px;")
          ;h1(style "font-size: 28px; font-weight: bold; margin: 0 0 4px 0;"): Bitcoin Wallet
          ;p(style "font-size: 14px; color: var(--f2); margin: 0;"): Manage your Bitcoin wallets
        ==
        ::  SSE connection for live updates
        ;div(hx-ext "sse", sse-connect "/grubbery/wallet/stream", sse-swap "wallet-list-update")
          ;div#wallet-list: Connecting...
        ==
        ::  Add wallet form
        ;div(style "background: var(--b0); border: 1px solid var(--b2); border-radius: 8px; padding: 16px; margin-top: 24px;")
          ;h2(style "font-size: 18px; font-weight: bold; margin: 0 0 16px 0; text-align: center;"): Add Wallet
          ;form(hx-post "/grubbery/wallet", hx-swap "none", style "display: flex; flex-direction: column; gap: 12px;")
            ;div
              ;label(style "display: block; font-size: 13px; font-weight: bold; margin-bottom: 4px;"): Wallet Name
              ;input(type "text", name "wallet-name", placeholder "My Bitcoin Wallet", required "true", style "width: 100%; padding: 8px; border: 1px solid var(--b3); border-radius: 4px; background: var(--b1); color: var(--f0); font-family: inherit; box-sizing: border-box;");
            ==
            ;button(type "submit", style "padding: 12px; background: var(--f-3); color: white; border: none; border-radius: 6px; cursor: pointer; font-weight: bold; font-size: 14px;"): Add Wallet
          ==
        ==
      ==
    ==
  ==
::
++  style-text
  ^-  tape
  """
  :root \{
    --b0: #1a1a2e; --b1: #16213e; --b2: #0f3460; --b3: #533483;
    --f0: #e4e4e4; --f1: #c4c4c4; --f2: #a4a4a4; --f3: #747474;
    --f-1: #ff4444; --f-3: #e94560;
  }
  body \{
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    background: var(--b0); color: var(--f0); margin: 0;
  }
  a \{ color: var(--f-3); }
  button:hover \{ opacity: 0.85; }
  """
--
