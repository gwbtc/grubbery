::  wallet nexus: bitcoin SPV wallet management UI
::
/<  feather  /lib/feather.hoon
/<  fi       /lib/feather-icons.hoon
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
            [%fall %& [/ %'page.html'] %.n [~ [/ %manx] !>(wallet-page)]]
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
        ;<  ~  bind:m  (rise-wait:io prod "%wallet /page: failed")
        ~&  >  "%wallet /page: rendered"
        ;<  ~  bind:m  (replace:io !>(wallet-page))
        stay:m
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
          accounts. View at /grubbery/api/peek/wallet.wallet/page.html?mark=mime

          FILES:
            page.html         Server-rendered wallet page (manx).
            ver.ud            Schema version.
          """
        ==
          %|
        ?+  rail.p.mana  'File under the wallet nexus.'
          [~ %'page.html']  'Server-rendered wallet page. Mark: manx.'
          [~ %'ver.ud']     'Schema version.'
        ==
      ==
    --
|%
++  wallet-page
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
            ;+  tab-container
          ==
        ==
      ==
      ;script
        ;+  ;/  script-text
      ==
    ==
  ==
::
++  tab-container
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
        ;+  wallets-panel
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
  ^-  manx
  ;div.fc.g2(style "flex: 1; min-height: 0;")
    ;div#wallet-list-container.p4.b0.br2(style "flex: 1; min-height: 0; overflow-y: auto;")
      ;div.p4.b1.br2.tc
        ;div.s0.f2.mb2: No wallets yet
        ;div.f3.s-1: Generate a new wallet or restore from a seed phrase below
      ==
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
++  script-text
  ^-  tape
  """
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
  """
--
