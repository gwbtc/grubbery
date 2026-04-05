::  per-wallet nexus: individual bitcoin wallet instance
::
::  Each wallet directory contains:
::    data.wallet   wallet-data (name, seed, fingerprint)
::    page.html     rendered detail page (manx)
::
/<  feather       /lib/feather.hoon
/<  fi            /lib/feather-icons.hoon
/<  seed-phrases  /lib/seed-phrases.hoon
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  [=sand:nexus =gain:nexus =ball:tarball]
      ^-  [sand:nexus gain:nexus ball:tarball]
      =/  =ver:loader  (get-ver:loader ball)
      ?+  ver  !!
          ?(~ [~ %0])
        %+  spin:loader  [sand gain ball]
        :~  (ver-row:loader 0)
            [%stay %& [/ %'data.wallet']]
            [%load %& [/ %'data.wallet'] [/ %'page.html'] data-to-page]
        ==
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =mark]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          [~ %'page.html']
        ;<  ~  bind:m  (rise-wait:io prod "%wallet detail: failed")
        ;<  init=view:nexus  bind:m
          (keep:io /data (cord-to-road:tarball './') ~)
        =/  wal=(unit wallet-data)  (extract-wallet init)
        ?~  wal  stay:m
        ;<  ~  bind:m  (replace:io !>((detail-page u.wal)))
        |-
        ;<  upd=view:nexus  bind:m  (take-news:io /data)
        =/  wal=(unit wallet-data)  (extract-wallet upd)
        ?~  wal  stay:m
        ;<  ~  bind:m  (replace:io !>((detail-page u.wal)))
        $
      ==
    ::
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'Subdirectory under this wallet.'
            ~
          'Individual Bitcoin wallet. Contains wallet data and rendered detail page.'
        ==
          %|
        ?+  rail.p.mana  'File under this wallet.'
          [~ %'data.wallet']   'Wallet data: name, seed, fingerprint. Mark: wallet.'
          [~ %'page.html']     'Rendered wallet detail page. Mark: manx.'
          [~ %'ver.ud']        'Schema version.'
        ==
      ==
    --
::  types and rendering
::
|%
+$  seed  $%([%t phrase=@t] [%q secret=@q])
+$  wallet-data  [name=@t =seed fingerprint=@ux]
::
++  data-to-page
  |=  [gn=? ct=content:tarball]
  ^-  [? content:tarball]
  ?:  =(ct *content:tarball)  [%.n ct]
  =/  wal=wallet-data  !<(wallet-data q.sage.ct)
  [%.n [~ [/ %manx] !>((detail-page wal))]]
::
++  extract-wallet
  |=  =view:nexus
  ^-  (unit wallet-data)
  ?.  ?=([%ball *] view)  ~
  =/  =lump:tarball  (fall fil.ball.view *lump:tarball)
  =/  ct=(unit content:tarball)  (~(get by contents.lump) 'data.wallet')
  ?~  ct  ~
  ?.  ?=(%wallet name.p.sage.u.ct)  ~
  (mole |.(!<(wallet-data q.sage.u.ct)))
::
++  seed-to-cord
  |=  =seed
  ^-  @t
  ?-  -.seed
    %t  phrase.seed
    %q  (scot %q secret.seed)
  ==
::
++  mask-seed
  |=  =seed
  ^-  tape
  ?-    -.seed
      %t
    =/  words=(list tape)  (split-words:seed-phrases (trip phrase.seed))
    =/  first=(list tape)  (scag 3 words)
    =/  rest=@ud  (sub (lent words) 3)
    =/  stars=(list tape)  (reap rest "****")
    =/  all=(list tape)  (welp first stars)
    (zing (join " " all))
      %q
    =/  text=tape  (scow %q secret.seed)
    =/  show=@ud  (min 12 (lent text))
    (weld (scag show text) "...")
  ==
::
++  detail-page
  |=  wal=wallet-data
  ^-  manx
  =/  back-url=tape
    "/grubbery/api/file/wallet.wallet_app/page.html"
  ;html
    ;head
      ;title: {(trip name.wal)}
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;+  feather:feather
      ;style
        ;+  ;/  style-text
      ==
    ==
    ;body
      ;div(style "min-width: 650px; height: 100%;")
        ;div.fc.g3.p5.ma.mw-page(style "height: 100%;")
          ;div(style "flex-shrink: 0; display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;")
            ;a.hover.pointer(href back-url, style "color: var(--f3); text-decoration: none;"): ← Back to Wallets
          ==
          ;div.p4.b1.br2(style "flex-shrink: 0;")
            ;h1.s2.bold.mb2: {(trip name.wal)}
            ;div.mb2(style "display: flex; gap: 8px; align-items: center;")
              ;span.f3.s-1: Seed:
              ;code.mono.s-2.p2.b2.br1: {(mask-seed seed.wal)}
              ;button.p1.b0.br1.hover.pointer
                =data-seed  (trip (seed-to-cord seed.wal))
                =onclick  "copyToClipboard(this.dataset.seed)"
                =style  "background: transparent; border: 1px solid var(--b3); color: var(--f3); display: flex; align-items: center; justify-content: center; outline: none;"
                ;div(style "width: 14px; height: 14px; display: flex; align-items: center; justify-content: center;")
                  ;+  (make:fi 'copy')
                ==
              ==
            ==
          ==
          ;div.fc.g3(style "flex: 1; min-height: 0;");
        ==
      ==
      ;script
        ;+  ;/  script-text
      ==
    ==
  ==
::
++  style-text
  ^-  tape
  """
  html, body \{
    height: 100vh !important;
    overflow: hidden !important;
    margin: 0 !important;
  }
  """
::
++  script-text
  ^-  tape
  """
  function copyToClipboard(text) \{
    navigator.clipboard.writeText(text);
  }
  """
--
