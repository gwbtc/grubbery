::  wallet-detail-ui: rendering for wallet detail page
::
::  Renders the per-wallet detail view showing seed, accounts list,
::  add/discover account forms. Used by the HTTP handler in app.hoon.
::
/<  feather  /lib/feather.hoon
/<  fi       /lib/feather-icons.hoon
/<  wt       /lib/wallet-types.hoon
/<  bip32    /lib/bip32.hoon
/<  seed-phrases  /lib/seed-phrases.hoon
/<  aio      /lib/wallet/account-io.hoon
/<  b329     /lib/bip329.hoon
=,  wt
|%
::
++  detail-page
  |=  [wal=wallet-data wal-name=@t =labels:b329 refs=(list @t)]
  ^-  manx
  =/  back-url=tape
    "/groundwire/wallet"
  ;html
    ;head
      ;title: {(trip wal-name)}
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
          ;+  (render-wallet-header wal wal-name)
          ;div.fc.g2(style "flex: 1; min-height: 0;")
            ;h2.s1.bold: Accounts
            ;div(id "accounts-container", style "flex: 1; min-height: 0; overflow-y: auto;")
              ;+  (render-accounts-list labels refs)
            ==
            ;+  render-discover-form
            ;+  render-add-account-form
          ==
        ==
      ==
      ;script
        ;+  ;/  script-text
      ==
    ==
  ==
::
++  render-wallet-header
  |=  [wal=wallet-data wal-name=@t]
  ^-  manx
  ;div.p4.b1.br2.mb2(style "flex-shrink: 0;")
    ;h1.s2.bold.mb1: {(trip wal-name)}
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
::
++  render-accounts-list
  |=  [=labels:b329 refs=(list @t)]
  ^-  manx
  ?:  =(~ refs)
    ;div.p3.b1.br2.tc.f3.s-1.empty-msg: No accounts yet. Add one below.
  ;div.fc.g1
    ;*  %+  turn  refs
        |=  ref=@t
        =/  key-hex=tape  (trip ref)
        ;div(id "card-{key-hex}")
          ;+  (render-account-card labels ref)
        ==
  ==
::
++  render-account-card
  |=  [=labels:b329 ref=@t]
  ^-  manx
  =/  key-hex=tape  (trip ref)
  =/  detail-url=tape
    "/groundwire/wallet/a/{key-hex}"
  =/  acct-name=@t  (get-acct-name:aio labels ref)
  =/  og=(unit parsed-origin:b329)  (get-acct-origin:aio labels ref)
  =/  account-path-str=tape
    ?~  og  "m/84'/0'/0'"
    (trip (render-origin:b329 u.og))
  ;div.p3.b1.br2.hover(style "display: flex; justify-content: space-between; align-items: center; gap: 12px;")
    ;a.pointer(href detail-url, style "flex: 1; min-width: 0; text-decoration: none; color: inherit; outline: none !important;")
      ;div(style "display: flex; align-items: center; gap: 8px;")
        ;+  ?.  ?&(?=(^ og) ?=(^ path.u.og))  ;span;
            (purpose-badge i.path.u.og)
        ;span.s0.bold: {(trip acct-name)}
        ;+  ?.  ?&(?=(^ og) ?=(^ path.u.og) ?=(^ t.path.u.og))  ;span;
            (coin-type-badge i.t.path.u.og)
      ==
      ;div(style "display: flex; align-items: center; gap: 8px;")
        ;div.f3.s-2.mono: {account-path-str}
      ==
    ==
    ;div(style "display: flex; gap: 4px;")
      ;button.p2.b1.br1.hover.pointer
        =data-key  key-hex
        =data-name  (trip acct-name)
        =onclick  "event.preventDefault(); event.stopPropagation(); if(confirm('Delete account ' + this.dataset.name + '?')) removeAccount(this.dataset.key)"
        =style  "background: var(--b2); border: 1px solid var(--b3); color: var(--f3); display: flex; align-items: center; width: 32px; height: 32px; justify-content: center; outline: none;"
        ;div(style "width: 16px; height: 16px; display: flex; align-items: center; justify-content: center;")
          ;+  (make:fi 'trash-2')
        ==
      ==
    ==
  ==
::
++  render-discover-form
  ^-  manx
  ;div.p4.b2.br2.add-account-form
    ;div.s0.bold.tc.hover.pointer(onclick "toggleAddPanel(this)", style "display: flex; align-items: center; justify-content: center; gap: 8px; padding-bottom: 4px;")
      ; Discover Accounts
      ;div.add-chevron(style "width: 16px; height: 16px; display: flex; align-items: center; transition: transform 0.2s;")
        ;+  (make:fi 'chevron-down')
      ==
    ==
    ;div.add-panel(style "display: none;")
      ;p.f3.s-2.mb2: Scan for existing accounts by checking addresses on-chain
      ;form(method "post", onsubmit "submitDiscover(event)")
        ;div.fc.g2
          ;+  render-purpose-select
          ;+  render-coin-type-select
          ;input(type "hidden", name "action", value "discover-accounts");
          ;button.p3.b-3.f-3.br2.hover.pointer(type "submit", style "outline: none; border: none;"): Discover
        ==
      ==
    ==
  ==
::
++  render-add-account-form
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
          ;+  render-purpose-select
          ;+  render-coin-type-select
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
++  render-purpose-select
  ^-  manx
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
    ==
  ==
::
++  render-coin-type-select
  ^-  manx
  ;div
    ;label.s-1.bold.f3: Coin Type
    ;select.coin-type-select.p2.b1.br1.wf.hover.pointer(name "coin-type-select", required "true", style "outline: none;")
      ;option(value "0", selected "selected"): Bitcoin Mainnet - 0
      ;option(value "1"): Bitcoin Testnet - 1
      ;option(value "custom"): Custom...
    ==
    ;div.custom-coin-type-container.fc.g1(style "display: none; margin-top: 8px;")
      ;input.custom-coin-type-input.p2.b1.br1.wf(type "number", name "coin-type-custom", placeholder "Enter coin type (SLIP-44)", min "0", max "2147483647");
    ==
  ==
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
  @keyframes spin \{
    from \{ transform: rotate(0deg) }
    to \{ transform: rotate(360deg) }
  }
  """
::
++  script-text
  ^-  tape
  """
  function walletPost(action, data) \{
    var url = window.location.pathname;
    return fetch(url, \{
      method: 'POST',
      headers: \{'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'action=' + action + (data ? '&' + data : '')
    });
  }

  function submitAddAccount(e) \{
    e.preventDefault();
    var fd = new FormData(e.target);
    var params = new URLSearchParams(fd).toString();
    fetch(window.location.pathname, \{
      method: 'POST',
      headers: \{'Content-Type': 'application/x-www-form-urlencoded'},
      body: params
    }).then(function(r) \{
      if (r.ok) location.reload();
      else r.text().then(function(t) \{ console.error('add-account error', t) });
    });
  }

  function submitDiscover(e) \{
    e.preventDefault();
    var fd = new FormData(e.target);
    var params = new URLSearchParams(fd).toString();
    fetch(window.location.pathname, \{
      method: 'POST',
      headers: \{'Content-Type': 'application/x-www-form-urlencoded'},
      body: params
    }).then(function(r) \{
      if (r.ok) location.reload();
      else r.text().then(function(t) \{ console.error('discover error', t) });
    });
  }

  function removeAccount(key) \{
    fetch(window.location.pathname, \{
      method: 'POST',
      headers: \{'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'action=remove-account&account-key=' + key
    }).then(function(r) \{
      if (r.ok) location.reload();
      else r.text().then(function(t) \{ console.error('remove-account error', t) });
    });
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
  """
--
