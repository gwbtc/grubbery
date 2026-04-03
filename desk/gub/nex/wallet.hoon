::  wallet nexus: bitcoin SPV wallet management UI
::
::
/<  feather       /lib/feather.hoon
/<  fi            /lib/feather-icons.hoon
/<  bip39         /lib/bip39.hoon
/<  bip32         /lib/bip32.hoon
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
            [%over %& [/ %'main.sig'] %.n [~ [/ %sig] !>(~)]]
            [%over %& [/ %'page.html'] %.n [~ [/ %manx] !>((wallet-page ~))]]
            [%fall %| /wallets [~ ~] [~ ~] empty-dir:loader]
            [%fall %| /ui/sse [~ ~] [~ ~] empty-dir:loader]
            [%fall %| /ui/views [~ ~] [~ ~] empty-dir:loader]
            [%load %| /wallets /ui/views/wallets wallets-to-views]
            [%over %& [/ui/sse %'wallets.html'] %.n [~ [/ %manx] !>((wallet-list-html ~))]]
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
          ::  /main.sig: receive pokes for wallet actions
          ::
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%wallet /main: failed")
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        ?+    name.p.sage
            ~&  >  [%wallet-main %unknown-mark name.p.sage]
            $
            %json
          =/  jon=json  !<(json q.sage)
          ?.  ?=([%o *] jon)  $
          =/  act=@t  (~(dug jo:json-utils jon) /action so:dejs:format '')
          ?+    act
              ~&  >  [%wallet-main %unknown-action act]
              $
              %'add-wallet'
            =/  wallet-name=@t
              (~(dog jo:json-utils jon) /wallet-name so:dejs:format)
            =/  seed-phrase=@t
              (~(dog jo:json-utils jon) /seed-phrase so:dejs:format)
            =/  seed-format=@t
              (~(dug jo:json-utils jon) /seed-format so:dejs:format 'bip39')
            ::  validate
            =/  sd=(unit seed)
              ?:  =(seed-format 'q')
                =/  parsed=(unit @q)  (slaw %q seed-phrase)
                ?~  parsed
                  ~&  >  [%wallet-main %invalid-q-format]
                  ~
                `[%q u.parsed]
              ?.  (validate-seed-phrase:seed-phrases seed-phrase)
                ~&  >  [%wallet-main %invalid-seed-phrase]
                ~
              `[%t seed-phrase]
            ?~  sd  $
            =/  pubkey=@ux  (seed-to-pubkey u.sd)
            =/  wallet-key=@ta  (crip (hexn:http-utils pubkey))
            =/  wal=wallet-data  [wallet-name u.sd pubkey]
            ;<  ~  bind:m
              (make:io /create [%| 0 %& /wallets wallet-key] |+[%.n [[/ %wallet] !>(wal)] ~])
            ;<  ~  bind:m
              (make:io /create-view [%| 0 %& /ui/views/wallets (cat 3 wallet-key '.html')] |+[%.n [[/ %manx] !>((wallet-detail-page wal))] ~])
            $
              %'add-wallet-from-entropy'
            =/  wallet-name=@t
              (~(dog jo:json-utils jon) /wallet-name so:dejs:format)
            ;<  =bowl:nexus  bind:m  (get-bowl:io /bowl)
            =/  seed-phrase=cord
              (gen-seed:seed-phrases eny.bowl %128)
            =/  pubkey=@ux  (seed-to-pubkey [%t seed-phrase])
            =/  wallet-key=@ta  (crip (hexn:http-utils pubkey))
            =/  wal=wallet-data  [wallet-name [%t seed-phrase] pubkey]
            ;<  ~  bind:m
              (make:io /create [%| 0 %& /wallets wallet-key] |+[%.n [[/ %wallet] !>(wal)] ~])
            ;<  ~  bind:m
              (make:io /create-view [%| 0 %& /ui/views/wallets (cat 3 wallet-key '.html')] |+[%.n [[/ %manx] !>((wallet-detail-page wal))] ~])
            $
              %'remove-wallet'
            =/  pubkey=@t
              (~(dog jo:json-utils jon) /pubkey so:dejs:format)
            =/  wallet-key=@ta  (crip (trip pubkey))
            ;<  ~  bind:m
              (cull:io /delete [%| 0 %& /wallets wallet-key])
            ;<  ~  bind:m
              (cull:io /delete-view [%| 0 %& /ui/views/wallets (cat 3 wallet-key '.html')])
            $
          ==
        ==
          ::  /page.html: render wallet page, watch /wallets/ for changes
          ::
          [~ %'page.html']
        ;<  ~  bind:m  (rise-wait:io prod "%wallet /page: failed")
        ;<  init=view:nexus  bind:m
          (keep:io /wallets (cord-to-road:tarball './wallets/') ~)
        =/  wals=(list wallet-data)  (view-to-wallets init)
        ;<  ~  bind:m  (replace:io !>((wallet-page wals)))
        |-
        ;<  upd=view:nexus  bind:m  (take-news:io /wallets)
        =/  wals=(list wallet-data)  (view-to-wallets upd)
        ;<  ~  bind:m  (replace:io !>((wallet-page wals)))
        $
          ::  /ui/sse/wallets.html: wallet list HTML fragment for SSE
          ::
          [[%ui %sse ~] %'wallets.html']
        ;<  ~  bind:m  (rise-wait:io prod "%wallet /ui/sse/wallets: failed")
        ;<  init=view:nexus  bind:m
          (keep:io /wallets (cord-to-road:tarball '../../wallets/') ~)
        =/  wals=(list wallet-data)  (view-to-wallets init)
        ;<  ~  bind:m  (replace:io !>((wallet-list-html wals)))
        |-
        ;<  upd=view:nexus  bind:m  (take-news:io /wallets)
        =/  wals=(list wallet-data)  (view-to-wallets upd)
        ;<  ~  bind:m  (replace:io !>((wallet-list-html wals)))
        $
          ::  /ui/views/wallets/*.html: per-wallet detail page
          ::
          [[%ui %views %wallets ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%wallet /ui/views/wallets: failed")
        =/  wallet-key=@ta
          =/  nt=tape  (trip name.rail)
          (crip (scag (sub (lent nt) 5) nt))
        ;<  init=view:nexus  bind:m
          (keep:io /wal (cord-to-road:tarball '../../../wallets/') ~)
        =/  wal=(unit wallet-data)  (find-wallet-in-view init wallet-key)
        ?~  wal  stay:m
        ;<  ~  bind:m  (replace:io !>((wallet-detail-page u.wal)))
        |-
        ;<  upd=view:nexus  bind:m  (take-news:io /wal)
        =/  wal=(unit wallet-data)  (find-wallet-in-view upd wallet-key)
        ?~  wal  stay:m
        ;<  ~  bind:m  (replace:io !>((wallet-detail-page u.wal)))
        $
      ==
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'Subdirectory under the wallet nexus.'
            ~
          %-  crip
          """
          WALLET NEXUS — Bitcoin SPV wallet management

          Manages Bitcoin wallets, watch-only accounts, and signing
          accounts. View at /grubbery/api/file/wallet.wallet/page.html

          FILES:
            main.sig          Poke handler for wallet actions.
            page.html         Server-rendered wallet page (manx).
            ver.ud            Schema version.

          DIRECTORIES:
            wallets/          Wallet storage. Each file keyed by pubkey.
            ui/views/         Server-rendered HTML views.
            ui/views/wallets/ Per-wallet detail pages. Keyed by fingerprint.
            ui/sse/           SSE streams. Sanitized data for live UI updates.
          """
            [%wallets ~]
          'Wallet storage. Each file is a wallet grub keyed by master public key.'
            [%ui %views ~]
          'Server-rendered HTML views.'
            [%ui %views %wallets ~]
          'Per-wallet detail pages. Each file is a manx keyed by wallet fingerprint.'
            [%ui %sse ~]
          'SSE streams. Sanitized wallet data for live UI updates via keep endpoint.'
        ==
          %|
        ?+  rail.p.mana  'File under the wallet nexus.'
          [~ %'main.sig']              'Poke handler for wallet actions. Mark: sig.'
          [~ %'page.html']             'Server-rendered wallet page. Mark: manx.'
          [~ %'ver.ud']                'Schema version.'
          [[%ui %sse ~] %'wallets.html']  'Wallet list HTML fragment for SSE. Mark: manx.'
          [[%ui %views %wallets ~] @]  'Per-wallet detail page. Mark: manx.'
        ==
      ==
    --
::  wallet types
::
|%
+$  seed  $%([%t phrase=@t] [%q secret=@q])
+$  wallet-data  [name=@t =seed fingerprint=@ux]
::
++  seed-to-pubkey
  |=  =seed
  ^-  @ux
  =/  seed-bytes=byts
    ?-  -.seed
      %t  64^(to-seed:bip39 (trip phrase.seed) "")
      %q  =/  val=@  `@`secret.seed
          [(met 3 val) val]
    ==
  public-key:(from-seed:bip32 seed-bytes)
::
++  wallet-to-json
  |=  wal=wallet-data
  ^-  json
  %-  pairs:enjs:format
  :~  ['name' s+name.wal]
      ['fingerprint' s+(crip (hexn:http-utils fingerprint.wal))]
      :-  'seed'
      %-  pairs:enjs:format
      ?-  -.seed.wal
        %t  ~[['type' s+'bip39'] ['value' s+phrase.seed.wal]]
        %q  ~[['type' s+'q'] ['value' s+(scot %q secret.seed.wal)]]
      ==
  ==
::
++  json-to-wallet-data
  |=  jon=json
  ^-  (unit wallet-data)
  =/  m  (mole |.((pairs-to-wallet jon)))
  ?~  m  ~
  `u.m
::
++  pairs-to-wallet
  |=  jon=json
  ^-  wallet-data
  ?>  ?=([%o *] jon)
  =/  name=json      (~(got by p.jon) 'name')
  ?>  ?=([%s *] name)
  =/  fp=json        (~(got by p.jon) 'fingerprint')
  ?>  ?=([%s *] fp)
  =/  seed-jon=json  (~(got by p.jon) 'seed')
  ?>  ?=([%o *] seed-jon)
  =/  stype=json  (~(got by p.seed-jon) 'type')
  ?>  ?=([%s *] stype)
  =/  sval=json   (~(got by p.seed-jon) 'value')
  ?>  ?=([%s *] sval)
  =/  =seed
    ?:  =('bip39' p.stype)  [%t p.sval]
    [%q (slav %q p.sval)]
  =/  fingerprint=@ux  (scan (trip p.fp) hex)
  [p.name seed fingerprint]
::
++  view-to-wallets
  |=  =view:nexus
  ^-  (list wallet-data)
  ?.  ?=([%ball *] view)  ~
  =/  =lump:tarball  (fall fil.ball.view *lump:tarball)
  %+  murn  ~(tap by contents.lump)
  |=  [name=@ta =content:tarball]
  ?.  ?=(%wallet name.p.sage.content)  ~
  (mole |.(!<(wallet-data q.sage.content)))
::
++  find-wallet-in-view
  |=  [=view:nexus key=@ta]
  ^-  (unit wallet-data)
  ?.  ?=([%ball *] view)  ~
  =/  =lump:tarball  (fall fil.ball.view *lump:tarball)
  =/  ct=(unit content:tarball)  (~(get by contents.lump) key)
  ?~  ct  ~
  ?.  ?=(%wallet name.p.sage.u.ct)  ~
  (mole |.(!<(wallet-data q.sage.u.ct)))
::  +wallets-to-views: fold-load that transforms /wallets/ ball into
::  /ui/views/wallets/ ball with rendered detail pages
::
++  wallets-to-views
  |=  [=sand:nexus =gain:nexus =ball:tarball]
  ^-  [sand:nexus gain:nexus ball:tarball]
  =/  =lump:tarball  (fall fil.ball *lump:tarball)
  =/  new-ball=ball:tarball  *ball:tarball
  =/  entries=(list [@ta content:tarball])  ~(tap by contents.lump)
  |-
  ?~  entries  [*sand:nexus *gain:nexus new-ball]
  =/  [key=@ta =content:tarball]  i.entries
  ?.  ?=(%wallet name.p.sage.content)  $(entries t.entries)
  =/  wal=(unit wallet-data)  (mole |.(!<(wallet-data q.sage.content)))
  ?~  wal  $(entries t.entries)
  =/  view-name=@ta  (cat 3 key '.html')
  =/  view-content=content:tarball  [~ [/ %manx] !>((wallet-detail-page u.wal))]
  =.  new-ball  (~(put ba:tarball new-ball) [/ view-name] view-content)
  $(entries t.entries)
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
++  wallet-list-html
  |=  wals=(list wallet-data)
  ^-  manx
  ?~  wals
    ;div.p4.b1.br2.tc
      ;div.s0.f2.mb2: No wallets yet
      ;div.f3.s-1: Generate a new wallet or restore from a seed phrase below
    ==
  =/  sorted=(list wallet-data)
    (sort wals |=([a=wallet-data b=wallet-data] (aor name.a name.b)))
  ;div.fc.g2
    ;*  (turn sorted wallet-card)
  ==
::  page rendering
::
++  wallet-page
  |=  wals=(list wallet-data)
  ^-  manx
  ;html
    ;head
      ;title: Bitcoin Wallet
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;+  feather:feather
      ;style
        ;+  ;/  style-text
      ==
    ==
    ;body
      ;div(style "min-width: 650px; height: 100%;")
        ;div.fc(style "height: 100%;")
          ::  Fixed header
          ;div.p5.ma.mw-page(style "flex-shrink: 0; padding-bottom: 0; width: 100%;")
            ;div.tc.mb2
              ;h1.s3.bold: ₿ Bitcoin Wallet
              ;p.f2.s-1: Manage your Bitcoin wallets and accounts
            ==
          ==
          ::  Scrollable content
          ;div.fc.g3.p5.ma.mw-page(style "flex: 1; min-height: 0; overflow-y: auto; padding-top: 0; width: 100%;")
            ;+  (tab-container wals)
          ==
        ==
      ==
      ;+  delete-modal
      ;script
        ;+  ;/  script-text
      ==
    ==
  ==
::
++  tab-container
  |=  wals=(list wallet-data)
  ^-  manx
  ;div.tab-container.b0.br2(data-active-tab "wallets", style "box-shadow: 0 4px 12px rgba(0,0,0,0.15); overflow: hidden; display: flex; flex-direction: column; min-height: 0; flex: 1; width: 100%;")
    ::  Tab buttons
    ;div.fr.b1(style "flex-shrink: 0;")
      ;button.tab-button.p4.grow.hover.pointer(data-tab "wallets", style "border: none; background: var(--b0); color: var(--f0); border-bottom: 3px solid var(--f-3); outline: none; flex: 1;"): Full Wallets
      ;button.tab-button.p4.grow.hover.pointer(data-tab "watch", style "border: none; background: var(--b1); color: var(--f2); border-bottom: 3px solid transparent; outline: none; flex: 1;"): Watch-Only
      ;button.tab-button.p4.grow.hover.pointer(data-tab "signing", style "border: none; background: var(--b1); color: var(--f2); border-bottom: 3px solid transparent; outline: none; flex: 1;"): Signing
    ==
    ::  Tab content
    ;div.p3.b0(style "flex: 1; min-height: 0; display: flex; flex-direction: column;")
      ;div#content-wallets.tab-content(style "display: flex; flex-direction: column; flex: 1; min-height: 0;")
        ;+  (wallets-panel wals)
      ==
      ;div#content-watch.tab-content(style "display: none;")
        ;+  watch-only-panel
      ==
      ;div#content-signing.tab-content(style "display: none;")
        ;+  signing-panel
      ==
    ==
  ==
::  Full Wallets tab
::
++  wallets-panel
  |=  wals=(list wallet-data)
  ^-  manx
  ;div.fc.g2(style "flex: 1; min-height: 0;")
    ;div#wallet-list-container.p4.b0.br2(style "flex: 1; min-height: 0; overflow-y: auto;")
      ;+  (wallet-list-html wals)
    ==
    ;div.p4.b2.br2(style "flex-shrink: 0;")
      ;div.s0.bold.tc.hover.pointer(onclick "toggleAddPanel(this)", style "display: flex; align-items: center; justify-content: center; gap: 8px; padding-bottom: 4px;")
        ; Add New Wallet
        ;div.add-chevron(style "width: 16px; height: 16px; display: flex; align-items: center; transition: transform 0.2s;")
          ;+  (make:fi 'chevron-down')
        ==
      ==
      ;div.add-panel(style "display: none;")
        ::  Generate / Restore sub-tabs
        ;div.tab-container(data-active-tab "generate")
          ;div.fr.g2(style "margin-bottom: 12px;")
            ;button.tab-button.p2.grow.b0.br1.hover.pointer.bold(data-tab "generate", style "border: 1px solid var(--b3); outline: none;"): Generate
            ;button.tab-button.p2.grow.b1.br1.hover.pointer.bold(data-tab "restore", style "border: 1px solid var(--b3); outline: none;"): Restore
          ==
          ;div#content-generate.tab-content(style "display: block;")
            ;+  generate-wallet-form
          ==
          ;div#content-restore.tab-content(style "display: none;")
            ;+  restore-wallet-form
          ==
        ==
      ==
    ==
  ==
::
++  wallet-card
  |=  wal=wallet-data
  ^-  manx
  =/  wallet-key=tape  (hexn:http-utils fingerprint.wal)
  =/  detail-url=tape
    "/grubbery/api/file/wallet.wallet/ui/views/wallets/{wallet-key}.html"
  ;div.p3.b1.br2.hover.pointer
    =onclick  "window.location.href='{detail-url}'"
    =style  "display: flex; justify-content: space-between; align-items: center; gap: 12px;"
    ;div(style "flex: 1; min-width: 0;")
      ;div.s0.bold.mb-1: {(trip name.wal)}
      ;div(style "display: flex; align-items: center; gap: 8px;")
        ;button.p1.b0.br1.hover.pointer
          =data-seed  (trip (seed-to-cord seed.wal))
          =onclick  "event.preventDefault(); event.stopPropagation(); copyToClipboard(this.dataset.seed);"
          =style  "background: transparent; border: 1px solid var(--b3); color: var(--f3); display: flex; align-items: center; width: 24px; height: 24px; justify-content: center; outline: none;"
          =title  "Copy seed phrase"
          ;div(style "width: 12px; height: 12px; display: flex; align-items: center; justify-content: center;")
            ;+  (make:fi 'copy')
          ==
        ==
        ;div.f3.s-2.mono(style "white-space: nowrap; overflow: hidden; text-overflow: ellipsis; flex: 1;"): {(mask-seed seed.wal)}
      ==
    ==
    ;button.p2.b1.br1.hover.pointer
      =data-wallet-name  (trip name.wal)
      =data-pubkey  (hexn:http-utils fingerprint.wal)
      =onclick  "event.stopPropagation(); showDeleteModal(this.dataset.walletName, this.dataset.pubkey)"
      =style  "background: var(--b2); border: 1px solid var(--b3); color: var(--f3); display: flex; align-items: center; width: 32px; height: 32px; justify-content: center; outline: none; flex-shrink: 0;"
      ;div(style "width: 16px; height: 16px; display: flex; align-items: center; justify-content: center;")
        ;+  (make:fi 'trash-2')
      ==
    ==
  ==
::  wallet detail page
::
++  wallet-detail-page
  |=  wal=wallet-data
  ^-  manx
  =/  back-url=tape
    "/grubbery/api/file/wallet.wallet/page.html"
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
        ;+  ;/  detail-script-text
      ==
    ==
  ==
::
++  delete-modal
  ^-  manx
  ;div(id "delete-modal", style "display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.5); z-index: 1000; align-items: center; justify-content: center;")
    ;div.b0.br3.p5(style "max-width: 400px;")
      ;h3.mb2: Delete Wallet
      ;p.f2.mb2(id "delete-confirm-text"): Are you sure you want to delete this wallet?
      ;div.mb2
        ;label.s-1.bold: Type wallet name to confirm:
        ;input.p2.b1.br1.wf(id "confirm-name", type "text", placeholder "Wallet name", oninput "validateDeleteName()");
        ;div.f-1.s-2.mt-1(id "name-error", style "display: none;"): Wallet name does not match
      ==
      ;div(style "display: flex; gap: 12px; justify-content: flex-end;")
        ;button.p2.b2.br2.hover.pointer(onclick "hideDeleteModal()", style "outline: none;"): Cancel
        ;button.p2.br2.hover.pointer(id "confirm-delete-btn", onclick "confirmDelete()", style "background: var(--f-1); color: var(--b0); outline: none;", disabled "true"): Delete
      ==
    ==
  ==
::
++  generate-wallet-form
  ^-  manx
  ;form(method "post")
    ;div.fc.g1
      ;input(type "hidden", name "action", value "add-wallet-from-entropy");
      ;div
        ;label.s-1.bold: Wallet Name
        ;input.p2.b1.br1.wf(type "text", name "wallet-name", placeholder "My Bitcoin Wallet", required "true");
      ==
      ;button.p3.b-3.f-3.br2.hover.pointer(type "submit", style "outline: none;"): Generate Wallet
    ==
  ==
::
++  restore-wallet-form
  ^-  manx
  ;div
    ;form(method "post")
      ;div.fc.g1
        ;input(type "hidden", name "action", value "add-wallet");
        ;div
          ;label.s-1.bold: Wallet Name
          ;input.p2.b1.br1.wf(type "text", name "wallet-name", placeholder "My Restored Wallet", required "true");
        ==
        ;div
          ;label.s-1.bold: Seed Format
          ;div(style "display: flex; gap: 16px; margin-top: 4px;")
            ;label(style "display: flex; align-items: center; gap: 4px; cursor: pointer;")
              ;input(type "radio", name "seed-format", value "bip39", checked "true", onchange "updateSeedInput(this.value)");
              ; BIP39 Mnemonic
            ==
            ;label(style "display: flex; align-items: center; gap: 4px; cursor: pointer;")
              ;input(type "radio", name "seed-format", value "q", onchange "updateSeedInput(this.value)");
              ; Urbit @q
            ==
          ==
        ==
        ;div
          ;label.s-1.bold(id "seed-label"): Seed Phrase
          ;textarea.p2.b1.br1.wf(id "seed-input", name "seed-phrase", placeholder "abandon abandon abandon...", rows "3", required "true", style "font-family: monospace;", oninput "this.value = this.value.replace(/[^a-z ]/g, '')");
        ==
        ;button.p3.b-3.f-3.br2.hover.pointer(type "submit", style "outline: none;"): Restore Wallet
      ==
    ==
  ==
::  Watch-Only tab
::
++  watch-only-panel
  ^-  manx
  ;div.fc.g2(style "flex: 1; min-height: 0;")
    ;div#watch-only-list-container.p4.b0.br2(style "flex: 1; min-height: 0; overflow-y: auto;")
      ;div.p4.b1.br2.tc
        ;div.s0.f2.mb2: No watch-only accounts yet
        ;div.f3.s-1: Import xpubs or addresses to track balances
      ==
    ==
    ;div.p4.b2.br2(style "flex-shrink: 0;")
      ;div.s0.bold.tc.hover.pointer(onclick "toggleAddPanel(this)", style "display: flex; align-items: center; justify-content: center; gap: 8px;")
        ; Add Watch-Only Account
        ;div.add-chevron(style "width: 16px; height: 16px; display: flex; align-items: center; transition: transform 0.2s;")
          ;+  (make:fi 'chevron-down')
        ==
      ==
      ;div.add-panel(style "display: none;")
        ;form(method "post")
          ;div.fc.g1
            ;input(type "hidden", name "action", value "add-watch-only");
            ;div
              ;label.s-1.bold: Account Name
              ;input.p2.b1.br1.wf(type "text", name "account-name", placeholder "Hardware Wallet", required "true");
            ==
            ;div
              ;label.s-1.bold: Extended Public Key (xpub/tpub)
              ;textarea.p2.b1.br1.wf(name "xpub", placeholder "xpub...", rows "1", required "true", style "font-family: monospace;");
            ==
            ;+  script-type-select
            ;+  network-select
            ;button.p3.b-3.f-3.br2.hover.pointer(type "submit", style "outline: none;"): Add Account
          ==
        ==
      ==
    ==
  ==
::  Signing tab
::
++  signing-panel
  ^-  manx
  ;div.fc.g2(style "flex: 1; min-height: 0;")
    ;div#signing-list-container.p4.b0.br2(style "flex: 1; min-height: 0; overflow-y: auto;")
      ;div.p4.b1.br2.tc
        ;div.s0.f2.mb2: No signing accounts yet
        ;div.f3.s-1: Import private keys or connect hardware wallets
      ==
    ==
    ;div.p4.b2.br2(style "flex-shrink: 0;")
      ;div.s0.bold.tc.hover.pointer(onclick "toggleAddPanel(this)", style "display: flex; align-items: center; justify-content: center; gap: 8px;")
        ; Add Signing Account
        ;div.add-chevron(style "width: 16px; height: 16px; display: flex; align-items: center; transition: transform 0.2s;")
          ;+  (make:fi 'chevron-down')
        ==
      ==
      ;div.add-panel(style "display: none;")
        ;form(method "post")
          ;div.fc.g1
            ;input(type "hidden", name "action", value "add-signing");
            ;div
              ;label.s-1.bold: Account Name
              ;input.p2.b1.br1.wf(type "text", name "account-name", placeholder "Hot Wallet", required "true");
            ==
            ;div
              ;label.s-1.bold: Extended Private Key (xprv/tprv)
              ;textarea.p2.b1.br1.wf(name "xprv", placeholder "xprv...", rows "1", required "true", style "font-family: monospace;");
            ==
            ;+  script-type-select
            ;+  network-select
            ;button.p3.b-3.f-3.br2.hover.pointer(type "submit", style "outline: none;"): Add Account
          ==
        ==
      ==
    ==
  ==
::  Shared form components
::
++  script-type-select
  ^-  manx
  ;div
    ;label.s-1.bold: Script Type
    ;select.p2.b1.br1.wf.hover.pointer(name "script-type", required "true", style "outline: none;")
      ;option(value "p2wpkh", selected "selected"): Native SegWit (P2WPKH)
      ;option(value "p2sh-p2wpkh"): Wrapped SegWit (P2SH-P2WPKH)
      ;option(value "p2pkh"): Legacy (P2PKH)
      ;option(value "p2tr"): Taproot (P2TR)
    ==
  ==
::
++  network-select
  ^-  manx
  ;div
    ;label.s-1.bold: Network
    ;select.p2.b1.br1.wf.hover.pointer(name "network", required "true", style "outline: none;")
      ;option(value "main", selected "selected"): Bitcoin Mainnet
      ;option(value "testnet"): Bitcoin Testnet
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
++  detail-script-text
  ^-  tape
  """
  function copyToClipboard(text) \{
    navigator.clipboard.writeText(text);
  }
  """
::
++  script-text
  ^-  tape
  """
  var API = '/' + window.location.pathname.split('/')[1] + '/'+'api';
  var BASE = 'wallet.wallet';

  function poke(body, cb) \{
    var url = API + '/'+'poke/' + BASE + '/'+'main.sig?mark=json';
    console.log('POKE', url, body);
    return fetch(url, \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(body)
    }).then(function(r) \{
      console.log('POKE response', r.status);
      if (!r.ok) return r.text().then(function(t) \{ console.error('POKE error', t) });
      if (cb) setTimeout(cb, 300);
    }).catch(function(e) \{ console.error('POKE failed', e) })
  }

  document.querySelectorAll('form[method="post"]').forEach(function(form) \{
    form.addEventListener('submit', function(e) \{
      e.preventDefault();
      var data = \{};
      new FormData(form).forEach(function(v, k) \{ data[k] = v; });
      poke(data);
    });
  });

  function toggleAddPanel(el) \{
    var panel = el.parentElement.querySelector('.add-panel');
    var chevron = el.querySelector('.add-chevron');
    if (panel.style.display === 'none' || !panel.style.display) \{
      panel.style.display = 'block';
      chevron.style.transform = 'rotate(180deg)';
    } else \{
      panel.style.display = 'none';
      chevron.style.transform = '';
    }
  }

  function updateSeedInput(format) \{
    var input = document.getElementById('seed-input');
    var label = document.getElementById('seed-label');
    if (format === 'q') \{
      label.textContent = 'Urbit @q';
      input.placeholder = '~sampel-palnet or ~sampel-palnet-sampel-palnet...';
      input.oninput = function() \{ this.value = this.value.replace(/[^a-z~.-]/g, ''); };
    } else \{
      label.textContent = 'Seed Phrase';
      input.placeholder = 'abandon abandon abandon...';
      input.oninput = function() \{ this.value = this.value.replace(/[^a-z ]/g, ''); };
    }
    input.value = '';
  }

  function copyToClipboard(text) \{
    navigator.clipboard.writeText(text).then(function() \{
      console.log('Copied to clipboard');
    }).catch(function(err) \{
      console.error('Failed to copy:', err);
    });
  }

  var _deleteWalletName = '';
  var _deletePubkey = '';

  function showDeleteModal(name, pubkey) \{
    _deleteWalletName = name;
    _deletePubkey = pubkey;
    document.getElementById('delete-confirm-text').textContent =
      'Are you sure you want to delete "' + name + '"?';
    document.getElementById('confirm-name').value = '';
    document.getElementById('name-error').style.display = 'none';
    document.getElementById('confirm-delete-btn').disabled = true;
    var modal = document.getElementById('delete-modal');
    modal.style.display = 'flex';
  }

  function hideDeleteModal() \{
    document.getElementById('delete-modal').style.display = 'none';
  }

  function validateDeleteName() \{
    var input = document.getElementById('confirm-name').value;
    var matches = (input === _deleteWalletName);
    document.getElementById('name-error').style.display = matches ? 'none' : 'block';
    document.getElementById('confirm-delete-btn').disabled = !matches;
  }

  function confirmDelete() \{
    poke(\{action: 'remove-wallet', pubkey: _deletePubkey, 'wallet-name': _deleteWalletName});
    hideDeleteModal();
  }

  (function() \{
    function activateTab(container, tabName) \{
      container.querySelectorAll('.tab-content').forEach(function(c) \{
        c.style.display = 'none';
      });
      var target = container.querySelector('#content-' + tabName);
      if (target) \{
        target.style.display = 'flex';
        target.style.flexDirection = 'column';
        target.style.flex = '1';
        target.style.minHeight = '0';
      }
      container.querySelectorAll(':scope > .fr > .tab-button, :scope > .tab-button').forEach(function(b) \{
        b.style.background = 'var(--b1)';
        b.style.color = 'var(--f2)';
        b.style.borderBottom = '3px solid transparent';
      });
      var activeBtn = container.querySelector('.tab-button[data-tab="' + tabName + '"]');
      if (activeBtn) \{
        activeBtn.style.background = 'var(--b0)';
        activeBtn.style.color = 'var(--f0)';
        activeBtn.style.borderBottom = '3px solid var(--f-3)';
      }
      container.setAttribute('data-active-tab', tabName);
    }

    document.querySelectorAll('.tab-button').forEach(function(btn) \{
      btn.addEventListener('click', function() \{
        var tabName = this.getAttribute('data-tab');
        var container = this.closest('.tab-container');
        activateTab(container, tabName);
      });
    });

    document.querySelectorAll('.tab-container').forEach(function(container) \{
      var activeTab = container.getAttribute('data-active-tab');
      if (activeTab) \{
        activateTab(container, activeTab);
      }
    });
  })();

  var SSE = API + '/'+'keep/' + BASE + '/'+'ui/sse?mark=txt';
  async function connectSSE() \{
    try \{
      var r = await fetch(SSE, \{headers: \{Accept: 'text/event-stream'}});
      var reader = r.body.getReader();
      var dec = new TextDecoder();
      var buf = '';
      while (true) \{
        var chunk = await reader.read();
        if (chunk.done) break;
        buf += dec.decode(chunk.value, \{stream: true});
        var parts = buf.split('\\n\\n');
        buf = parts.pop();
        for (var i = 0; i < parts.length; i++) \{
          if (!parts[i].trim()) continue;
          var ev = '', data = '', lines = parts[i].split('\\n');
          for (var j = 0; j < lines.length; j++) \{
            if (lines[j].indexOf('event: ') === 0) ev = lines[j].slice(7);
            else if (lines[j].indexOf('data: ') === 0) data = lines[j].slice(6);
          }
          if (!ev) continue;
          var sp = ev.indexOf(' ');
          if (sp < 0) continue;
          var act = ev.slice(0, sp);
          var name = ev.slice(sp + 2);
          if (act === 'old') continue;
          if (name === 'wallets.html' && data) \{
            var container = document.getElementById('wallet-list-container');
            if (container) container.innerHTML = data;
          }
        }
      }
    } catch(x) \{}
    setTimeout(connectSSE, 2000);
  }
  connectSSE();
  """
--
