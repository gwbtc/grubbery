::  per-account nexus: individual BIP44 account instance
::
::  Each account directory contains:
::    data.account   account-data (name, xprv, script-type, addresses)
::    main.sig       poke handler for derive-next
::    page.html      rendered detail page (manx)
::
/<  feather       /lib/feather.hoon
/<  fi            /lib/feather-icons.hoon
/<  wt            /lib/wallet-types.hoon
/<  bip32         /lib/bip32.hoon
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
            [%stay %& [/ %'data.wallet_account']]
            [%over %& [/ %'main.sig'] %.n [~ [/ %sig] !>(~)]]
            [%fall %| /ui/sse [~ ~] [~ ~] empty-dir:loader]
            [%over %& [/ui/sse %'addresses.html'] %.n [~ [/ %manx] !>(;div;)]]
            [%over %& [/ %'page.html'] %.n [~ [/ %manx] !>(;div;)]]
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
          ::  /page.html: render account detail, watch for data changes
          ::
          [~ %'page.html']
        ;<  ~  bind:m  (rise-wait:io prod "%account detail: failed")
        ~&  >  [%account-page %init-keep %path (cord-to-road:tarball './')]
        ;<  init=view:nexus  bind:m
          (keep:io /data (cord-to-road:tarball './') ~)
        ~&  >  [%account-page %init-view -.init]
        =/  acct=(unit account-data)  (extract-account init)
        ~&  >  [%account-page %init-extract ?=(^ acct)]
        ?~  acct
          ~&  >  [%account-page %waiting-for-data]
          |-
          ;<  upd=view:nexus  bind:m  (take-news:io /data)
          ~&  >  [%account-page %upd-waiting -.upd]
          =/  acct=(unit account-data)  (extract-account upd)
          ~&  >  [%account-page %upd-waiting-extract ?=(^ acct)]
          ?~  acct  $
          ~&  >  [%account-page %rendering-from-wait]
          ;<  ~  bind:m  (replace:io !>((detail-page u.acct)))
          $
        ~&  >  [%account-page %rendering-immediate]
        ;<  ~  bind:m  (replace:io !>((detail-page u.acct)))
        |-
        ;<  upd=view:nexus  bind:m  (take-news:io /data)
        ~&  >  [%account-page %upd -.upd]
        =/  acct=(unit account-data)  (extract-account upd)
        ?~  acct  $
        ;<  ~  bind:m  (replace:io !>((detail-page u.acct)))
        $
          ::  /ui/sse/addresses.html: live address list fragment
          ::
          [[%ui %sse ~] %'addresses.html']
        ;<  ~  bind:m  (rise-wait:io prod "%account /ui/sse/addresses: failed")
        ;<  init=view:nexus  bind:m
          (keep:io /data (cord-to-road:tarball '../../') ~)
        =/  acct=(unit account-data)  (extract-account init)
        ?~  acct
          |-
          ;<  upd=view:nexus  bind:m  (take-news:io /data)
          =/  acct=(unit account-data)  (extract-account upd)
          ?~  acct  $
          ;<  ~  bind:m  (replace:io !>((addresses-fragment u.acct)))
          $
        ;<  ~  bind:m  (replace:io !>((addresses-fragment u.acct)))
        |-
        ;<  upd=view:nexus  bind:m  (take-news:io /data)
        =/  acct=(unit account-data)  (extract-account upd)
        ?~  acct  $
        ;<  ~  bind:m  (replace:io !>((addresses-fragment u.acct)))
        $
          ::  /main.sig: handle pokes (derive-next)
          ::
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%account /main: failed")
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        ?+    name.p.sage
            ~&  >  [%account-main %unknown-mark name.p.sage]
            $
            %json
          =/  jon=json  !<(json q.sage)
          ?.  ?=([%o *] jon)  $
          =/  act=@t  (~(dug jo:json-utils jon) /action so:dejs:format '')
          ?+    act
              ~&  >  [%account-main %unknown-action act]
              $
              %'derive-next'
            =/  chain=@t
              (~(dug jo:json-utils jon) /chain so:dejs:format 'receiving')
            ;<  cur=view:nexus  bind:m
              (keep:io /acct-read (cord-to-road:tarball './') ~)
            =/  acct=(unit account-data)  (extract-account cur)
            ?~  acct
              ~&  >  [%account-main %no-account-data]
              $
            =/  is-change=?  =(chain 'change')
            =/  addrs=(list @t)
              ?:(is-change change.u.acct receiving.u.acct)
            =/  next-idx=@ud  (lent addrs)
            =/  new-addr=(unit @t)
              %:  derive-addr
                xprv.u.acct
                script-type.u.acct
                network.u.acct
                ?:(is-change 1 0)
                next-idx
              ==
            ?~  new-addr
              ~&  >  [%account-main %derive-failed next-idx]
              $
            =/  new-addrs=(list @t)  (snoc addrs u.new-addr)
            =/  updated=account-data
              ?:  is-change
                u.acct(change new-addrs)
              u.acct(receiving new-addrs)
            ;<  ~  bind:m
              (over:io (cord-to-road:tarball './data.wallet_account') [[/wallet %account] !>(updated)])
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
        ?+  p.mana  'Subdirectory under this account.'
            ~
          'Individual BIP44 account. Derives and displays Bitcoin addresses.'
            [%ui %sse ~]
          'SSE streams for live UI updates.'
        ==
          %|
        ?+  rail.p.mana  'File under this account.'
          [~ %'data.wallet_account']  'Account data: name, xprv, script-type, addresses. Mark: account.'
          [~ %'main.sig']      'Poke handler for account actions. Mark: sig.'
          [~ %'page.html']     'Rendered account detail page. Mark: manx.'
          [~ %'ver.ud']        'Schema version.'
        ==
      ==
    --
::  types and rendering
::
|%
++  data-to-page
  |=  [gn=? ct=content:tarball]
  ^-  [? content:tarball]
  ?:  =(ct *content:tarball)  [%.n ct]
  ?:  =([/ %boom] p.sage.ct)  [%.n ct]
  =/  acct=account-data  !<(account-data q.sage.ct)
  [%.n [~ [/ %manx] !>((detail-page acct))]]
::
++  extract-account
  |=  =view:nexus
  ^-  (unit account-data)
  ?.  ?=([%ball *] view)  ~
  =/  =lump:tarball  (fall fil.ball.view *lump:tarball)
  =/  ct=(unit content:tarball)  (~(get by contents.lump) 'data.wallet_account')
  ?~  ct  ~
  ?.  ?=(%account name.p.sage.u.ct)  ~
  (mole |.(!<(account-data q.sage.u.ct)))
::
++  derive-addr
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
++  network-label
  |=  network=?(%main %testnet %regtest)
  ^-  tape
  ?-  network
    %main     "Mainnet"
    %testnet  "Testnet"
    %regtest  "Regtest"
  ==
::
++  address-list-section
  |=  [acct=account-data chain=tape addrs=(list @t)]
  ^-  manx
  =/  next-idx=@ud  (lent addrs)
  =/  is-receiving=?  =(chain "receiving")
  ;div.fc.g2
    ;div(style "display: flex; justify-content: space-between; align-items: center;")
      ;h2.s1.bold: {?:(is-receiving "Receiving" "Change")} Addresses
      ;button.p2.b-3.f-3.br1.hover.pointer
        =onclick  "deriveNext('{chain}')"
        =style  "outline: none; border: none;"
        ; + Derive (Index {(scow %ud next-idx)})
      ==
    ==
    ;+  ?:  =(0 (lent addrs))
          ;div.p3.b1.br2.tc.f3.s-1: No addresses derived yet
        ;div.fc.g1
          ;*  %+  turn  (gulf 0 (dec (lent addrs)))
              |=  idx=@ud
              =/  addr=@t  (snag idx addrs)
              (address-row idx addr)
        ==
  ==
::
++  address-row
  |=  [idx=@ud addr=@t]
  ^-  manx
  ;div.p3.b1.br2(style "display: flex; justify-content: space-between; align-items: center; gap: 8px;")
    ;div(style "flex: 1; min-width: 0;")
      ;span.f3.s-2: Index {(scow %ud idx)}
      ;div.mono.s-2(style "white-space: nowrap; overflow: hidden; text-overflow: ellipsis;"): {(trip addr)}
    ==
    ;button.p1.b0.br1.hover.pointer
      =data-addr  (trip addr)
      =onclick  "copyToClipboard(this.dataset.addr)"
      =style  "background: transparent; border: 1px solid var(--b3); color: var(--f3); display: flex; align-items: center; justify-content: center; outline: none; flex-shrink: 0;"
      ;div(style "width: 14px; height: 14px; display: flex; align-items: center; justify-content: center;")
        ;+  (make:fi 'copy')
      ==
    ==
  ==
::
++  addresses-fragment
  |=  acct=account-data
  ^-  manx
  ;div.fc.g3
    ;+  (address-list-section acct "receiving" receiving.acct)
    ;+  (address-list-section acct "change" change.acct)
  ==
::
++  detail-page
  |=  acct=account-data
  ^-  manx
  ;html
    ;head
      ;title: {(trip name.acct)}
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;+  feather:feather
      ;style
        ;+  ;/  style-text
      ==
    ==
    ;body
      ;input(type "hidden", id "wallet-fp", value (hexn:http-utils wallet.acct));
      ;div(style "min-width: 650px; height: 100%;")
        ;div.fc.g3.p5.ma.mw-page(style "height: 100%;")
          ;div(style "flex-shrink: 0; display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;")
            ;a.hover.pointer(id "back-link", href "#", onclick "goBack(); return false;", style "color: var(--f3); text-decoration: none;"): ← Back to Wallet
          ==
          ;div.p4.b1.br2.mb2(style "flex-shrink: 0;")
            ;h1.s2.bold.mb1: {(trip name.acct)}
            ;div(style "display: flex; gap: 8px; align-items: center; flex-wrap: wrap;")
              ;+  (purpose-badge purpose.acct)
              ;code.mono.s-2.p1.b2.br1: {(format-account-path purpose.acct coin-type.acct account-idx.acct)}
              ;+  (coin-type-badge coin-type.acct)
              ;span.s-1.p1.b2.br1: {(network-label network.acct)}
            ==
          ==
          ;div(id "addresses-container", style "flex: 1; min-height: 0; overflow-y: auto;")
            ;+  (addresses-fragment acct)
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
  """
::
++  script-text
  ^-  tape
  """
  function goBack() \{
    var walletFp = document.getElementById('wallet-fp').value;
    var parts = window.location.pathname.split('/');
    var base = parts.slice(0, parts.indexOf('wallet.wallet_app') + 1).join('/');
    window.location.href = base + '/wallets/' + walletFp + '.wallet_wallet/page.html';
  }

  function getPokeUrl() \{
    var path = window.location.pathname;
    return path.replace('/api/file/', '/api/poke/').replace('page.html', 'main.sig') + '?mark=json';
  }

  function deriveNext(chain) \{
    fetch(getPokeUrl(), \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(\{action: 'derive-next', chain: chain})
    }).then(function(r) \{
      if (!r.ok) return r.text().then(function(t) \{ console.error('derive-next error', t) });
    }).catch(function(e) \{ console.error('derive-next failed', e) });
  }

  function copyToClipboard(text) \{
    navigator.clipboard.writeText(text);
  }

  var path = window.location.pathname;
  var parts = path.split('/');
  var apiIdx = parts.indexOf('api');
  var API = parts.slice(0, apiIdx + 1).join('/');
  var acctBase = path.replace('/api/file/', '').replace('/page.html', '');
  var SSE = API + '/keep/' + acctBase + '/ui/sse?mark=txt';
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
          if (act === 'old') continue;
          if (name === 'addresses.html' && data.length) \{
            var container = document.getElementById('addresses-container');
            if (container) container.innerHTML = data.join('\\n');
          }
        }
      }
    } catch (e) \{
      setTimeout(connectSSE, 2000);
    }
  }
  connectSSE();
  """
--
