::  per-wallet nexus: individual bitcoin wallet instance
::
::  Each wallet directory contains:
::    main.wallet_wallet  wallet-data + poke handler (name, seed, fingerprint, accounts)
::    page.html           rendered detail page (manx)
::    accounts/      per-account nexuses
::
::
/<  feather       /lib/feather.hoon
/<  fi            /lib/feather-icons.hoon
/<  wt            /lib/wallet-types.hoon
/<  seed-phrases  /lib/seed-phrases.hoon
/<  bip32         /lib/bip32.hoon
/<  bip39         /lib/bip39.hoon
/<  bech32        /lib/bech32.hoon
=,  wt
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
            [%stay %& [/ %'main.wallet_wallet']]
            [%fall %| /ui/sse [~ ~] [~ ~] empty-dir:loader]
            [%over %& [/ui/sse %'accounts.html'] %.n [~ [/ %manx] !>(;div;)]]
            [%over %& [/ui/sse %'error.html'] %.n [~ [/ %manx] !>(;div;)]]
            [%over %& [/ui/sse %'loading.html'] %.n [~ [/ %manx] !>(;div;)]]
            [%load %& [/ %'main.wallet_wallet'] [/ %'page.html'] data-to-page]
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
          ::  /page.html: render wallet detail, re-render on changes
          ::
          [~ %'page.html']
        ;<  ~  bind:m  (rise-wait:io prod "%wallet detail: failed")
        ;<  data=view:nexus  bind:m
          (keep:io /data (cord-to-road:tarball './') ~)
        ;<  accts=view:nexus  bind:m
          (keep:io /accts (cord-to-road:tarball '../../accounts/') ~)
        ;<  sse=view:nexus  bind:m
          (keep:io /sse (cord-to-road:tarball './ui/sse/') ~)
        =/  wal=(unit wallet-data)  (extract-wallet data)
        =/  acct-list=(list account-data)  (extract-accounts accts wal)
        ?~  wal  stay:m
        =/  err=manx   (extract-sse-manx sse 'error.html')
        =/  load=manx  (extract-sse-manx sse 'loading.html')
        ;<  ~  bind:m  (replace:io !>((detail-page u.wal acct-list err load)))
        |-
        ;<  [tag=?(%data %accts %sse) =view:nexus]  bind:m
          (take-any-news /data /accts /sse)
        =?  data   =(tag %data)   view
        =?  accts  =(tag %accts)  view
        =?  sse    =(tag %sse)    view
        =/  wal=(unit wallet-data)  (extract-wallet data)
        =/  acct-list=(list account-data)  (extract-accounts accts wal)
        ?~  wal  stay:m
        =/  err=manx   (extract-sse-manx sse 'error.html')
        =/  load=manx  (extract-sse-manx sse 'loading.html')
        ;<  ~  bind:m  (replace:io !>((detail-page u.wal acct-list err load)))
        $
          ::  /ui/sse/accounts.html: rendered account list for SSE
          ::
          [[%ui %sse ~] %'accounts.html']
        ;<  ~  bind:m  (rise-wait:io prod "%wallet /ui/sse: failed")
        ;<  data=view:nexus  bind:m
          (keep:io /data (cord-to-road:tarball '../../') ~)
        ;<  accts=view:nexus  bind:m
          (keep:io /accts (cord-to-road:tarball '../../../../accounts/') ~)
        =/  wal=(unit wallet-data)  (extract-wallet data)
        =/  acct-list=(list account-data)  (extract-accounts accts wal)
        ?~  wal  stay:m
        ;<  ~  bind:m  (replace:io !>((accounts-fragment acct-list)))
        |-
        ;<  [tag=?(%data %accts) =view:nexus]  bind:m
          (take-either-news /data /accts)
        =?  data   =(tag %data)   view
        =?  accts  =(tag %accts)  view
        =/  wal=(unit wallet-data)  (extract-wallet data)
        =/  acct-list=(list account-data)  (extract-accounts accts wal)
        ?~  wal  stay:m
        ;<  ~  bind:m  (replace:io !>((accounts-fragment acct-list)))
        $
          ::  /main.wallet_wallet: wallet data + poke handler
          ::
          [~ %'main.wallet_wallet']
        ;<  ~  bind:m  (rise-wait:io prod "%wallet /main: failed")
        |-
        ;<  wal=wallet-data  bind:m  (get-state-as:io wallet-data)
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
              %'add-account'
            =/  account-name=@t
              (~(dog jo:json-utils jon) /account-name so:dejs:format)
            =/  purpose-select=@t
              (~(dug jo:json-utils jon) /purpose-select so:dejs:format '84')
            =/  purpose=@ud
              ?:  =(purpose-select 'custom')
                (rash (~(dog jo:json-utils jon) /purpose-custom so:dejs:format) dem)
              (rash purpose-select dem)
            =/  coin-type-select=@t
              (~(dug jo:json-utils jon) /coin-type-select so:dejs:format '0')
            =/  coin-type=@ud
              ?:  =(coin-type-select 'custom')
                (rash (~(dog jo:json-utils jon) /coin-type-custom so:dejs:format) dem)
              (rash coin-type-select dem)
            =/  account-idx=@ud
              (rash (~(dug jo:json-utils jon) /account-number so:dejs:format '0') dem)
            =/  =script-type  (purpose-to-script purpose)
            ::  clear error + show loading
            =/  err-road=road:tarball   (cord-to-road:tarball './ui/sse/error.html')
            =/  load-road=road:tarball  (cord-to-road:tarball './ui/sse/loading.html')
            ;<  ~  bind:m  (over:io err-road [[/ %manx] !>(;div;)])
            ;<  ~  bind:m  (over:io load-road [[/ %manx] !>(loading-bar)])
            ;<  ~  bind:m  (sleep:io `@dr`(div ~s1 10))
            ::  derive account key from master seed
            =/  network=?(%main %testnet %regtest)
              ?:  =(1 coin-type)  %testnet  %main
            =/  master  (from-seed:bip32 (seed-to-bytes seed.wal))
            =/  pax=tape
              "m/{(scow %ud purpose)}'/{(scow %ud coin-type)}'/{(scow %ud account-idx)}'"
            =/  derived  (derive-path:master pax)
            =/  xprv=@t  (crip (prv-extended:derived network))
            ::  derive first receiving address
            =/  first-addr=(unit @t)
              (derive-acct-addr xprv script-type network 0 0)
            =/  receiving=(list address-entry)
              ?~  first-addr  ~
              ~[[u.first-addr ~]]
            ::  create account data
            =/  acct=account-data
              [account-name fingerprint.wal script-type network [%.y purpose] [%.y coin-type] [%.y account-idx] xprv receiving ~]
            =/  acct-pubkey=@ux  public-key:derived
            =/  acct-key=@ta  (crip (hexn:http-utils acct-pubkey))
            =/  acct-dir=@ta  (cat 3 acct-key '.wallet_account')
            =/  acct-lump=lump:tarball
              :+  ~  `[/wallet %account]
              (~(put by *(map @ta content:tarball)) %'data.wallet_account' [~ [/wallet %account] !>(acct)])
            =/  acct-ball=ball:tarball  [`acct-lump ~]
            ;<  err=(unit tang)  bind:m
              (make-soft:io [%| 2 %| (snoc /accounts acct-dir)] &+[*sand:nexus *gain:nexus acct-ball])

            ?^  err
              ;<  ~  bind:m
                (over:io load-road [[/ %manx] !>(;div;)])
              ;<  ~  bind:m
                (over:io err-road [[/ %manx] !>((render-error u.err))])
              $
            ::  clear loading + update wallet accounts map
            ;<  ~  bind:m  (over:io load-road [[/ %manx] !>(;div;)])
            =/  acct-path=account:wt  [[%.y purpose] [%.y coin-type] [%.y account-idx]]
            =.  wal  wal(accounts (~(put by accounts.wal) acct-path acct-pubkey))
            ;<  ~  bind:m  (replace:io !>(wal))
            $
              %'remove-account'
            =/  acct-key=@t
              (~(dog jo:json-utils jon) /account-key so:dejs:format)
            =/  acct-pubkey=@ux  (scan (trip acct-key) hex)
            =/  acct-dir=@ta  (cat 3 (crip (trip acct-key)) '.wallet_account')
            ::  clear error + show loading
            =/  err-road=road:tarball   (cord-to-road:tarball './ui/sse/error.html')
            =/  load-road=road:tarball  (cord-to-road:tarball './ui/sse/loading.html')
            ;<  ~  bind:m  (over:io err-road [[/ %manx] !>(;div;)])
            ;<  ~  bind:m  (over:io load-road [[/ %manx] !>(loading-bar)])
            ;<  ~  bind:m  (sleep:io `@dr`(div ~s1 10))
            ;<  err=(unit tang)  bind:m
              (cull-soft:io [%| 2 %| (snoc /accounts acct-dir)])

            ?^  err
              ;<  ~  bind:m
                (over:io load-road [[/ %manx] !>(;div;)])
              ;<  ~  bind:m
                (over:io err-road [[/ %manx] !>((render-error u.err))])
              $
            ::  clear loading + remove from wallet accounts map
            ;<  ~  bind:m  (over:io load-road [[/ %manx] !>(;div;)])
            =.  wal
              %=  wal
                accounts
                %-  ~(gas by *(map account:wt @ux))
                %+  skip  ~(tap by accounts.wal)
                |=([* pk=@ux] =(pk acct-pubkey))
              ==
            ;<  ~  bind:m  (replace:io !>(wal))
            $
              %'clear-error'
            =/  err-road=road:tarball  (cord-to-road:tarball './ui/sse/error.html')
            ;<  ~  bind:m  (over:io err-road [[/ %manx] !>(;div;)])
            $
          ==
        ==
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
          [~ %'main.wallet_wallet']   'Wallet data + poke handler: name, seed, fingerprint, accounts.'
          [~ %'page.html']            'Rendered wallet detail page. Mark: manx.'
          [~ %'ver.ud']               'Schema version.'
        ==
      ==
    --
::  types and rendering
::
|%
++  take-either-news
  |=  [a=wire b=wire]
  =/  m  (fiber:fiber:nexus ,[?(%data %accts) view:nexus])
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %news * *]
    ?:  =(a wire.u.in)  [%done %data view.u.in]
    ?:  =(b wire.u.in)  [%done %accts view.u.in]
    [%skip ~]
  ==
::
++  take-any-news
  |=  [a=wire b=wire c=wire]
  =/  m  (fiber:fiber:nexus ,[?(%data %accts %sse) view:nexus])
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %news * *]
    ?:  =(a wire.u.in)  [%done %data view.u.in]
    ?:  =(b wire.u.in)  [%done %accts view.u.in]
    ?:  =(c wire.u.in)  [%done %sse view.u.in]
    [%skip ~]
  ==
::
++  extract-sse-manx
  |=  [=view:nexus name=@ta]
  ^-  manx
  ?.  ?=([%ball *] view)  ;div;
  =/  =lump:tarball  (fall fil.ball.view *lump:tarball)
  =/  ct=(unit content:tarball)  (~(get by contents.lump) name)
  ?~  ct  ;div;
  =/  result=(unit manx)  (mole |.(!<(manx q.sage.u.ct)))
  (fall result ;div;)
::
++  loading-bar
  ^-  manx
  ;div(style "height: 2px; background: #e0e0e0; overflow: hidden; border-radius: 1px;")
    ;div(style "height: 100%; width: 30%; background: #888; animation: slide 1s ease-in-out infinite;");
  ==
::
++  render-error
  |=  =tang
  ^-  manx
  =/  lines=(list tape)
    %+  turn  (flop tang)
    |=(=tank ~(ram re tank))
  =/  message=tape
    =/  msgs=(list tape)
      %+  skim  lines
      |=  l=tape
      ?&  !=(l "")
          !=('/' (snag 0 l))
      ==
    ?~  msgs  "Something went wrong"
    =/  raw=tape  i.msgs
    =/  stripped=tape
      ?.  ?&  (gte (lent raw) 2)
              =('"' (snag 0 raw))
              =('"' (rear raw))
          ==
        raw
      (scag (sub (lent raw) 2) (slag 1 raw))
    (weld "Error: " stripped)
  ;details(style "background: #fce8e6; color: #c62828; padding: 6px 10px; border-radius: 3px; border: 1px solid #f5c6cb; font-size: 13px;")
    ;summary(style "display: flex; align-items: center; gap: 6px; cursor: pointer; list-style: none;")
      ;span(style "flex: 1;"): {message}
      ;button
        =onclick  "clearError()"
        =style  "background: none; border: none; color: #c62828; cursor: pointer; padding: 0; display: flex; align-items: center; justify-content: center; opacity: 0.6;"
        ;div(style "width: 14px; height: 14px; display: flex; align-items: center; justify-content: center;")
          ;+  (make:fi 'x')
        ==
      ==
      ;div(style "width: 14px; height: 14px; display: flex; align-items: center; justify-content: center; flex-shrink: 0;")
        ;+  (make:fi 'chevron-down')
      ==
    ==
    ;pre(style "margin-top: 6px; white-space: pre-wrap; font-family: monospace; font-size: 11px; max-height: 160px; overflow-y: auto; opacity: 0.8;")
      ;*  %+  turn  lines
          |=  line=tape
          ^-  manx
          ;div: {line}
    ==
  ==
::
++  data-to-page
  |=  [gn=? ct=content:tarball]
  ^-  [? content:tarball]
  ?:  =(ct *content:tarball)  [%.n ct]
  ?:  =([/ %boom] p.sage.ct)  [%.n ct]
  =/  wal=wallet-data  !<(wallet-data q.sage.ct)
  [%.n [~ [/ %manx] !>((detail-page wal ~ ;div; ;div;))]]
::
++  extract-wallet
  |=  =view:nexus
  ^-  (unit wallet-data)
  ?.  ?=([%ball *] view)  ~
  =/  =lump:tarball  (fall fil.ball.view *lump:tarball)
  =/  ct=(unit content:tarball)  (~(get by contents.lump) 'main.wallet_wallet')
  ?~  ct  ~
  ?.  ?=(%wallet name.p.sage.u.ct)  ~
  (mole |.(!<(wallet-data q.sage.u.ct)))
::
++  extract-accounts
  |=  [=view:nexus wal=(unit wallet-data)]
  ^-  (list account-data)
  ?~  wal  ~
  ?.  ?=([%ball *] view)  ~
  %+  murn  ~(tap by dir.ball.view)
  |=  [name=@ta sub=ball:tarball]
  =/  sub-lump=lump:tarball  (fall fil.sub *lump:tarball)
  =/  ct=(unit content:tarball)  (~(get by contents.sub-lump) 'data.wallet_account')
  ?~  ct  ~
  ?.  ?=(%account name.p.sage.u.ct)  ~
  =/  acct=(unit account-data)  (mole |.(!<(account-data q.sage.u.ct)))
  ?~  acct  ~
  ?.  =(wallet.u.acct fingerprint.u.wal)  ~
  acct
::
++  seed-to-cord
  |=  =seed
  ^-  @t
  ?-  -.seed
    %t  phrase.seed
    %q  (scot %q secret.seed)
  ==
::
++  seed-to-bytes
  |=  =seed
  ^-  byts
  ?-  -.seed
    %t  [64 (to-seed:bip39 (trip phrase.seed) "")]
    %q  =/  val=@  `@`secret.seed
        [(met 3 val) val]
  ==
::
++  purpose-to-script
  |=  p=@ud
  ^-  script-type
  ?+  p  %p2wpkh
    %44  %p2pkh
    %49  %p2sh-p2wpkh
    %84  %p2wpkh
    %86  %p2tr
  ==
::
++  derive-acct-addr
  |=  [xprv=@t =script-type network=?(%main %testnet %regtest) chain=@ud index=@ud]
  ^-  (unit @t)
  =/  acct-key  (from-extended:bip32 (trip xprv))
  =/  chain-key  (derive:acct-key chain)
  =/  addr-key  (derive:chain-key index)
  =/  pubkey=@  public-key:addr-key
  ?-  script-type
    %p2wpkh      (encode-pubkey:bech32 network [33 pubkey])
    %p2tr        (encode-taproot:bech32 network [32 (end [3 32] pubkey)])
    %p2pkh       ~
    %p2sh-p2wpkh  ~
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
++  format-account-path
  |=  [purpose=seg coin-type=seg account-idx=seg]
  ^-  tape
  =/  [ph=? pi=@ud]  purpose
  =/  [ch=? ci=@ud]  coin-type
  =/  [ah=? ai=@ud]  account-idx
  %+  welp  "m/"
  %+  welp  (scow %ud pi)
  %+  welp  ?:(ph "'" "")
  %+  welp  "/"
  %+  welp  (scow %ud ci)
  %+  welp  ?:(ch "'" "")
  %+  welp  "/"
  %+  welp  (scow %ud ai)
  ?:(ah "'" "")
::
++  purpose-badge
  |=  purpose=seg
  ^-  manx
  =/  [hardened=? index=@ud]  purpose
  =/  tooltip=tape
    ?+  index  (scow %ud index)
        %86  "Taproot (BIP86) - 86"
        %84  "Native SegWit (BIP84) - 84"
        %49  "Wrapped SegWit (BIP49) - 49"
        %44  "Legacy (BIP44) - 44"
    ==
  =/  [color=tape label=tape]
    ?+  index  ["#888" (scow %ud index)]
        %86  ["#9333ea" "86"]
        %84  ["#10b981" "84"]
        %49  ["#f59e0b" "49"]
        %44  ["#6b7280" "44"]
    ==
  ;div(title "{tooltip}", style "display: inline-flex; align-items: center; justify-content: center; width: 18px; height: 18px; border-radius: 50%; background: {color}; color: white; font-size: 10px; font-weight: bold; font-family: monospace; cursor: default;"): {label}
::
++  coin-type-badge
  |=  coin-type=seg
  ^-  manx
  =/  [hardened=? index=@ud]  coin-type
  =/  tooltip=tape
    ?+  index  (scow %ud index)
        %0  "Bitcoin Mainnet - 0"
        %1  "Bitcoin Testnet - 1"
    ==
  =/  badge=manx
    ?+  index
      %-  need  %-  de-xml:html
      '<svg xmlns="http://www.w3.org/2000/svg" height="16" width="16" viewBox="0 0 64 64"><circle cx="32" cy="32" r="30" fill="#9ca3af"/></svg>'
    ::
        %0
      %-  need  %-  de-xml:html
      '<svg xmlns="http://www.w3.org/2000/svg" height="16" width="16" viewBox="0 0 64 64"><g transform="translate(0.00630876,-0.00301984)"><path fill="#f7931a" d="m63.033,39.744c-4.274,17.143-21.637,27.576-38.782,23.301-17.138-4.274-27.571-21.638-23.295-38.78,4.272-17.145,21.635-27.579,38.775-23.305,17.144,4.274,27.576,21.64,23.302,38.784z"/><path fill="#FFF" d="m46.103,27.444c0.637-4.258-2.605-6.547-7.038-8.074l1.438-5.768-3.511-0.875-1.4,5.616c-0.923-0.23-1.871-0.447-2.813-0.662l1.41-5.653-3.509-0.875-1.439,5.766c-0.764-0.174-1.514-0.346-2.242-0.527l0.004-0.018-4.842-1.209-0.934,3.75s2.605,0.597,2.55,0.634c1.422,0.355,1.679,1.296,1.636,2.042l-1.638,6.571c0.098,0.025,0.225,0.061,0.365,0.117-0.117-0.029-0.242-0.061-0.371-0.092l-2.296,9.205c-0.174,0.432-0.615,1.08-1.609,0.834,0.035,0.051-2.552-0.637-2.552-0.637l-1.743,4.019,4.569,1.139c0.85,0.213,1.683,0.436,2.503,0.646l-1.453,5.834,3.507,0.875,1.439-5.772c0.958,0.26,1.888,0.5,2.798,0.726l-1.434,5.745,3.511,0.875,1.453-5.823c5.987,1.133,10.489,0.676,12.384-4.739,1.527-4.36-0.076-6.875-3.226-8.515,2.294-0.529,4.022-2.038,4.483-5.155zm-8.022,11.249c-1.085,4.36-8.426,2.003-10.806,1.412l1.928-7.729c2.38,0.594,10.012,1.77,8.878,6.317zm1.086-11.312c-0.99,3.966-7.1,1.951-9.082,1.457l1.748-7.01c1.982,0.494,8.365,1.416,7.334,5.553z"/></g></svg>'
    ::
        %1
      %-  need  %-  de-xml:html
      '<svg xmlns="http://www.w3.org/2000/svg" height="16" width="16" viewBox="0 0 64 64"><g transform="translate(0.00630876,-0.00301984)"><path fill="#6b8fd8" d="m63.033,39.744c-4.274,17.143-21.637,27.576-38.782,23.301-17.138-4.274-27.571-21.638-23.295-38.78,4.272-17.145,21.635-27.579,38.775-23.305,17.144,4.274,27.576,21.64,23.302,38.784z"/><path fill="#FFF" d="m46.103,27.444c0.637-4.258-2.605-6.547-7.038-8.074l1.438-5.768-3.511-0.875-1.4,5.616c-0.923-0.23-1.871-0.447-2.813-0.662l1.41-5.653-3.509-0.875-1.439,5.766c-0.764-0.174-1.514-0.346-2.242-0.527l0.004-0.018-4.842-1.209-0.934,3.75s2.605,0.597,2.55,0.634c1.422,0.355,1.679,1.296,1.636,2.042l-1.638,6.571c0.098,0.025,0.225,0.061,0.365,0.117-0.117-0.029-0.242-0.061-0.371-0.092l-2.296,9.205c-0.174,0.432-0.615,1.08-1.609,0.834,0.035,0.051-2.552-0.637-2.552-0.637l-1.743,4.019,4.569,1.139c0.85,0.213,1.683,0.436,2.503,0.646l-1.453,5.834,3.507,0.875,1.439-5.772c0.958,0.26,1.888,0.5,2.798,0.726l-1.434,5.745,3.511,0.875,1.453-5.823c5.987,1.133,10.489,0.676,12.384-4.739,1.527-4.36-0.076-6.875-3.226-8.515,2.294-0.529,4.022-2.038,4.483-5.155zm-8.022,11.249c-1.085,4.36-8.426,2.003-10.806,1.412l1.928-7.729c2.38,0.594,10.012,1.77,8.878,6.317zm1.086-11.312c-0.99,3.966-7.1,1.951-9.082,1.457l1.748-7.01c1.982,0.494,8.365,1.416,7.334,5.553z"/></g></svg>'
    ==
  ;span(title "{tooltip}", style "cursor: default;")
    ;+  badge
  ==
::
++  account-card
  |=  acct=account-data
  ^-  manx
  =/  acct-key  (from-extended:bip32 (trip xprv.acct))
  =/  acct-pubkey=@ux  public-key:acct-key
  =/  key-hex=tape  (hexn:http-utils acct-pubkey)
  =/  detail-url=tape
    "/grubbery/api/file/wallet.wallet_app/accounts/{key-hex}.wallet_account/page.html"
  =/  account-path-str=tape
    (format-account-path purpose.acct coin-type.acct account-idx.acct)
  ;div.p3.b1.br2.hover(style "display: flex; justify-content: space-between; align-items: center; gap: 12px;")
    ;a.pointer(href detail-url, style "flex: 1; min-width: 0; text-decoration: none; color: inherit; outline: none !important;")
      ;div(style "display: flex; align-items: center; gap: 8px;")
        ;+  (purpose-badge purpose.acct)
        ;span.s0.bold: {(trip name.acct)}
      ==
      ;div(style "display: flex; align-items: center; gap: 8px;")
        ;+  (coin-type-badge coin-type.acct)
        ;div.f3.s-2.mono: {account-path-str}
      ==
    ==
    ;div(style "display: flex; gap: 4px;")
      ;button.p2.b1.br1.hover.pointer
        =data-key  key-hex
        =data-name  (trip name.acct)
        =onclick  "event.preventDefault(); event.stopPropagation(); if(confirm('Delete account ' + this.dataset.name + '?')) removeAccount(this.dataset.key)"
        =style  "background: var(--b2); border: 1px solid var(--b3); color: var(--f3); display: flex; align-items: center; width: 32px; height: 32px; justify-content: center; outline: none;"
        ;div(style "width: 16px; height: 16px; display: flex; align-items: center; justify-content: center;")
          ;+  (make:fi 'trash-2')
        ==
      ==
    ==
  ==
::
++  add-account-form
  ^-  manx
  ;div.p4.b2.br2.add-account-form
    ;div.s0.bold.tc.hover.pointer(onclick "toggleAddPanel(this)", style "display: flex; align-items: center; justify-content: center; gap: 8px; padding-bottom: 4px;")
      ; Add Account
      ;div.add-chevron(style "width: 16px; height: 16px; display: flex; align-items: center; transition: transform 0.2s;")
        ;+  (make:fi 'chevron-down')
      ==
    ==
    ;div.add-panel(style "display: none;")
      ;p.f3.s-2.mb2: Add an account at a specific derivation path
      ;form(method "post", onsubmit "submitAddAccount(event)")
        ;div.fc.g2
          ;div
            ;label.s-1.bold.f3: Account Name
            ;input.p2.b1.br1.wf(type "text", name "account-name", placeholder "My Account", required "true");
          ==
          ;div
            ;label.s-1.bold.f3: Purpose
            ;select.purpose-select.p2.b1.br1.wf.hover.pointer(name "purpose-select", required "true", style "outline: none;")
              ;option(value "84", selected "selected"): Native SegWit (BIP84) - 84
              ;option(value "49"): Wrapped SegWit (BIP49) - 49
              ;option(value "44"): Legacy (BIP44) - 44
              ;option(value "86"): Taproot (BIP86) - 86
              ;option(value "custom"): Custom...
            ==
            ;div.custom-purpose-container.fc.g1(style "display: none; margin-top: 8px;")
              ;input.custom-purpose-input.p2.b1.br1.wf(type "number", name "purpose-custom", placeholder "Enter purpose number", min "0", max "2147483647");
              ;div.f3.s-2(style "color: var(--f-2);"): Non-standard purposes may not work with other wallets
            ==
          ==
          ;div
            ;label.s-1.bold.f3: Coin Type
            ;select.coin-type-select.p2.b1.br1.wf.hover.pointer(name "coin-type-select", required "true", style "outline: none;")
              ;option(value "0", selected "selected"): Bitcoin Mainnet - 0
              ;option(value "1"): Bitcoin Testnet - 1
              ;option(value "custom"): Custom...
            ==
            ;div.custom-coin-type-container.fc.g1(style "display: none; margin-top: 8px;")
              ;input.custom-coin-type-input.p2.b1.br1.wf(type "number", name "coin-type-custom", placeholder "Enter coin type (SLIP-44)", min "0", max "2147483647");
              ;div.f3.s-2(style "color: var(--f-2);"): See SLIP-44 registry for valid coin types
            ==
          ==
          ;div
            ;label.s-1.bold.f3: Account Number
            ;input.p2.b1.br1.wf(type "number", name "account-number", placeholder "0", min "0", max "2147483647", required "true", value "0");
          ==
          ;input(type "hidden", name "action", value "add-account");
          ;button.p3.b-3.f-3.br2.hover.pointer(type "submit", style "outline: none; border: none;"): Add Account
        ==
      ==
    ==
  ==
::
++  accounts-fragment
  |=  accts=(list account-data)
  ^-  manx
  =/  sorted=(list account-data)
    %+  sort  accts
    |=([a=account-data b=account-data] (aor name.a name.b))
  ?:  =(~ sorted)
    ;div.p3.b1.br2.tc.f3.s-1.empty-msg: No accounts yet. Add one below.
  ;div.fc.g1
    ;*  %+  turn  sorted
        |=  acct=account-data
        =/  acct-key  (from-extended:bip32 (trip xprv.acct))
        =/  key-hex=tape  (hexn:http-utils public-key:acct-key)
        ;div(id "card-{key-hex}")
          ;+  (account-card acct)
        ==
  ==
::
++  detail-page
  |=  [wal=wallet-data accts=(list account-data) err=manx load=manx]
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
          ;div.p4.b1.br2.mb2(style "flex-shrink: 0;")
            ;h1.s2.bold.mb1: {(trip name.wal)}
            ;div(style "display: flex; gap: 8px; align-items: center;")
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
          ::  accounts section
          ;div.fc.g2(style "flex: 1; min-height: 0;")
            ;h2.s1.bold: Accounts
            ;div(id "accounts-container", style "flex: 1; min-height: 0; overflow-y: auto;")
              ;+  (accounts-fragment accts)
            ==
            ;div(id "loading-container")
              ;+  load
            ==
            ;div(id "error-container")
              ;+  err
            ==
            ;+  add-account-form
          ==
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
  @keyframes slide \{
    0% \{ transform: translateX(-100%) }
    100% \{ transform: translateX(400%) }
  }
  """
::
++  script-text
  ^-  tape
  """
  var path = window.location.pathname;
  var m = path.match(/^(\\/\\w+)\\/(?:api\\/file|ball)\\/(.*?)\\/page\\.html/);
  var API = m ? m[1] + '/api' : '/grubbery/api';
  var walBase = m ? m[2] : '';

  function getPokeUrl() \{
    return API + '/poke/' + walBase + '/main.wallet_wallet?mark=json';
  }

  function submitAddAccount(e) \{
    e.preventDefault();
    var data = \{};
    new FormData(e.target).forEach(function(v, k) \{ data[k] = v; });
    fetch(getPokeUrl(), \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(data)
    }).then(function(r) \{
      if (!r.ok) return r.text().then(function(t) \{ console.error('add-account error', t) });
      e.target.reset();
    }).catch(function(e) \{ console.error('add-account failed', e) });
  }

  (function() \{
    var containers = document.querySelectorAll('.add-account-form');
    containers.forEach(function(container) \{
      var purposeSelect = container.querySelector('.purpose-select');
      if (purposeSelect) purposeSelect.onchange = function() \{
        var cc = this.parentElement.querySelector('.custom-purpose-container');
        var ci = cc.querySelector('.custom-purpose-input');
        if (this.value === 'custom') \{
          cc.style.display = 'flex';
          ci.required = true;
        } else \{
          cc.style.display = 'none';
          ci.required = false;
        }
      };
      var coinTypeSelect = container.querySelector('.coin-type-select');
      if (coinTypeSelect) coinTypeSelect.onchange = function() \{
        var cc = this.parentElement.querySelector('.custom-coin-type-container');
        var ci = cc.querySelector('.custom-coin-type-input');
        if (this.value === 'custom') \{
          cc.style.display = 'flex';
          ci.required = true;
        } else \{
          cc.style.display = 'none';
          ci.required = false;
        }
      };
    });
  })();

  function clearError() \{
    fetch(getPokeUrl(), \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(\{action: 'clear-error'})
    });
  }

  function removeAccount(key) \{
    fetch(getPokeUrl(), \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(\{action: 'remove-account', 'account-key': key})
    }).then(function(r) \{
      if (!r.ok) return r.text().then(function(t) \{ console.error('remove-account error', t) });
    }).catch(function(e) \{ console.error('remove-account failed', e) });
  }

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

  function copyToClipboard(text) \{
    navigator.clipboard.writeText(text);
  }

  var SSE = API + '/keep/' + walBase + '/ui/sse?mark=txt';
  var sseController = null;
  var sseReader = null;

  async function connectSSE() \{
    if (sseReader) try \{ sseReader.cancel(); } catch(e) \{}
    if (sseController) sseController.abort();
    sseController = new AbortController();
    console.log('SSE: connecting to', SSE);
    try \{
      var r = await fetch(SSE, \{
        headers: \{Accept: 'text/event-stream'},
        signal: sseController.signal
      });
      console.log('SSE: connected, status', r.status);
      sseReader = r.body.getReader();
      var dec = new TextDecoder();
      var buf = '';
      while (true) \{
        var chunk = await sseReader.read();
        if (chunk.done) break;
        buf += dec.decode(chunk.value, \{stream: true});
        var evts = buf.split('\\n\\n');
        buf = evts.pop();
        for (var i = 0; i < evts.length; i++) \{
          if (!evts[i].trim()) continue;
          var ev = '', data = [], lines = evts[i].split('\\n');
          for (var j = 0; j < lines.length; j++) \{
            if (lines[j].indexOf('event: ') === 0) ev = lines[j].slice(7);
            else if (lines[j].indexOf('data: ') === 0) data.push(lines[j].slice(6));
          }
          if (!ev) continue;
          var sp = ev.indexOf(' ');
          if (sp < 0) continue;
          var act = ev.slice(0, sp);
          var name = ev.slice(sp + 2);
          var html = data.join('\\n');
          console.log('SSE:', act, name, html.length + ' chars');
          if (name === 'accounts.html') \{
            var el = document.getElementById('accounts-container');
            if (el) el.innerHTML = html;
          } else if (name === 'error.html') \{
            var el = document.getElementById('error-container');
            if (el) el.innerHTML = html;
          } else if (name === 'loading.html') \{
            var el = document.getElementById('loading-container');
            if (el) el.innerHTML = html;
          }
        }
      }
    } catch (e) \{
      if (e.name !== 'AbortError') \{
        console.error('SSE: error', e);
        setTimeout(connectSSE, 2000);
      }
    }
  }
  window.addEventListener('beforeunload', function() \{
    if (sseReader) try \{ sseReader.cancel(); } catch(e) \{}
    if (sseController) sseController.abort();
  });
  connectSSE();
  """
--
