::  wallet-account-ui: pure rendering arms for account detail + send pages
::
/<  feather       /lib/feather.hoon
/<  fi            /lib/feather-icons.hoon
/<  wt            /lib/wallet-types.hoon
/<  bip32         /lib/bip32.hoon
/<  drft          /lib/tx/draft.hoon
/<  fees          /lib/tx/fees.hoon
=,  wt
|%
::  types
::
+$  scan-progress  [phase=@t idx=@ud gap=@ud]
::
+$  fee-calc
  $:  total-inputs=@ud
      total-outputs=@ud
      has-change-config=?
      fee-rate=@ud
      est-vbytes=@ud
      est-fee=@ud
      change-result=change-result:fees
      actual-fee=@sd
  ==
::
++  format-sats
  |=  n=@ud
  ^-  tape
  =/  digits=tape  (a-co:co n)
  =/  len=@ud  (lent digits)
  ?:  (lte len 3)  digits
  =/  rev=tape  (flop digits)
  =/  out=tape  ~
  =/  i=@ud  0
  |-
  ?~  rev  out
  =?  out  &((gth i 0) =(0 (mod i 3)))
    [',' out]
  $(rev t.rev, out [i.rev out], i +(i))
::
++  compute-total-balance
  |=  [recv=(list [@ud address-data]) chng=(list [@ud address-data])]
  ^-  @ud
  =/  all=(list [@ud address-data])
    (weld recv chng)
  %+  roll  all
  |=  [[idx=@ud a=address-data] total=@ud]
  ?~  info.a  total
  (add total (sub (add funded.u.info.a mem-funded.u.info.a) (add spent.u.info.a mem-spent.u.info.a)))
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
++  next-unused-addr
  |=  entries=(list [@ud address-data])
  ^-  (unit @t)
  |-
  ?~  entries  ~
  =/  [idx=@ud a=address-data]  i.entries
  ?:  ?|(?=(~ info.a) =(0 tx-count.u.info.a))
    `addr.a
  $(entries t.entries)
::
++  next-unused-change-addr
  |=  entries=(list [@ud address-data])
  ^-  (unit @t)
  |-
  ?~  entries  ~
  =/  [idx=@ud a=address-data]  i.entries
  ?:  =(0 (fall (bind info.a |=(i=address-info tx-count.i)) 0))
    `addr.a
  $(entries t.entries)
::
++  compute-fee-info
  |=  dr=(unit transaction:drft)
  ^-  fee-calc
  =/  total-inputs=@ud
    ?~  dr  0
    (sum-inputs:drft inputs.u.dr)
  =/  total-outputs=@ud
    ?~  dr  0
    (sum-outputs:drft outputs.u.dr)
  =/  has-change-config=?
    ?~  dr  %.n
    ?=(^ change.u.dr)
  =/  fee-rate=@ud
    ?~  dr  0
    ?~  change.u.dr  0
    fee-rate.u.change.u.dr
  =/  est-vbytes=@ud
    ?~  dr  0
    (calculate-vbytes:drft u.dr)
  =/  est-fee=@ud  (calculate-fee:fees est-vbytes fee-rate)
  =/  change-result=change-result:fees
    (calculate-change-result:fees total-inputs total-outputs est-fee)
  =/  total-out-with-change=@ud
    %+  add  total-outputs
    ?.  has-change-config  0
    ?:(?=(%ok -.change-result) amount.change-result 0)
  =/  actual-fee=@sd
    ?:  (gte total-inputs total-out-with-change)
      (sun:si (sub total-inputs total-out-with-change))
    (new:si | (sub total-out-with-change total-inputs))
  [total-inputs total-outputs has-change-config fee-rate est-vbytes est-fee change-result actual-fee]
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
++  network-badge
  |=  network=?(%main %testnet3 %testnet4 %signet %regtest)
  ^-  manx
  =/  testnet-svg=manx
    %-  need  %-  de-xml:html
    '<svg xmlns="http://www.w3.org/2000/svg" height="16" width="16" viewBox="0 0 64 64"><g transform="translate(0.00630876,-0.00301984)"><path fill="#6b8fd8" d="m63.033,39.744c-4.274,17.143-21.637,27.576-38.782,23.301-17.138-4.274-27.571-21.638-23.295-38.78,4.272-17.145,21.635-27.579,38.775-23.305,17.144,4.274,27.576,21.64,23.302,38.784z"/><path fill="#FFF" d="m46.103,27.444c0.637-4.258-2.605-6.547-7.038-8.074l1.438-5.768-3.511-0.875-1.4,5.616c-0.923-0.23-1.871-0.447-2.813-0.662l1.41-5.653-3.509-0.875-1.439,5.766c-0.764-0.174-1.514-0.346-2.242-0.527l0.004-0.018-4.842-1.209-0.934,3.75s2.605,0.597,2.55,0.634c1.422,0.355,1.679,1.296,1.636,2.042l-1.638,6.571c0.098,0.025,0.225,0.061,0.365,0.117-0.117-0.029-0.242-0.061-0.371-0.092l-2.296,9.205c-0.174,0.432-0.615,1.08-1.609,0.834,0.035,0.051-2.552-0.637-2.552-0.637l-1.743,4.019,4.569,1.139c0.85,0.213,1.683,0.436,2.503,0.646l-1.453,5.834,3.507,0.875,1.439-5.772c0.958,0.26,1.888,0.5,2.798,0.726l-1.434,5.745,3.511,0.875,1.453-5.823c5.987,1.133,10.489,0.676,12.384-4.739,1.527-4.36-0.076-6.875-3.226-8.515,2.294-0.529,4.022-2.038,4.483-5.155zm-8.022,11.249c-1.085,4.36-8.426,2.003-10.806,1.412l1.928-7.729c2.38,0.594,10.012,1.77,8.878,6.317zm1.086-11.312c-0.99,3.966-7.1,1.951-9.082,1.457l1.748-7.01c1.982,0.494,8.365,1.416,7.334,5.553z"/></g></svg>'
  ?-  network
      %main
    %-  need  %-  de-xml:html
    '<svg xmlns="http://www.w3.org/2000/svg" height="16" width="16" viewBox="0 0 64 64"><g transform="translate(0.00630876,-0.00301984)"><path fill="#f7931a" d="m63.033,39.744c-4.274,17.143-21.637,27.576-38.782,23.301-17.138-4.274-27.571-21.638-23.295-38.78,4.272-17.145,21.635-27.579,38.775-23.305,17.144,4.274,27.576,21.64,23.302,38.784z"/><path fill="#FFF" d="m46.103,27.444c0.637-4.258-2.605-6.547-7.038-8.074l1.438-5.768-3.511-0.875-1.4,5.616c-0.923-0.23-1.871-0.447-2.813-0.662l1.41-5.653-3.509-0.875-1.439,5.766c-0.764-0.174-1.514-0.346-2.242-0.527l0.004-0.018-4.842-1.209-0.934,3.75s2.605,0.597,2.55,0.634c1.422,0.355,1.679,1.296,1.636,2.042l-1.638,6.571c0.098,0.025,0.225,0.061,0.365,0.117-0.117-0.029-0.242-0.061-0.371-0.092l-2.296,9.205c-0.174,0.432-0.615,1.08-1.609,0.834,0.035,0.051-2.552-0.637-2.552-0.637l-1.743,4.019,4.569,1.139c0.85,0.213,1.683,0.436,2.503,0.646l-1.453,5.834,3.507,0.875,1.439-5.772c0.958,0.26,1.888,0.5,2.798,0.726l-1.434,5.745,3.511,0.875,1.453-5.823c5.987,1.133,10.489,0.676,12.384-4.739,1.527-4.36-0.076-6.875-3.226-8.515,2.294-0.529,4.022-2.038,4.483-5.155zm-8.022,11.249c-1.085,4.36-8.426,2.003-10.806,1.412l1.928-7.729c2.38,0.594,10.012,1.77,8.878,6.317zm1.086-11.312c-0.99,3.966-7.1,1.951-9.082,1.457l1.748-7.01c1.982,0.494,8.365,1.416,7.334,5.553z"/></g></svg>'
  ::
      %testnet3  testnet-svg
      %testnet4  testnet-svg
      %signet    testnet-svg
  ::
      %regtest
    %-  need  %-  de-xml:html
    '<svg xmlns="http://www.w3.org/2000/svg" height="16" width="16" viewBox="0 0 64 64"><circle cx="32" cy="32" r="30" fill="#9ca3af"/></svg>'
  ==
::
++  network-label
  |=  network=?(%main %testnet3 %testnet4 %signet %regtest)
  ^-  tape
  ?-  network
    %main      "Mainnet"
    %testnet3  "Testnet3"
    %testnet4  "Testnet4"
    %signet    "Signet"
    %regtest   "Regtest"
  ==
::
++  network-badge-ui
  |=  network=?(%main %testnet3 %testnet4 %signet %regtest)
  =/  coin-type=@ud  ?:(=(%main network) 0 1)
  ^-  manx
  ;div#network-status(data-network "{(trip ;;(@ta network))}", style "display: flex; align-items: center; gap: 8px; margin-top: 12px;")
    ;div.p2.br1(style "display: flex; align-items: center; gap: 8px; background: var(--b2);")
      ;div.p2.b1.br2(style "display: flex; align-items: center; gap: 6px;")
        ;+  (network-badge network)
        ;span.f2.s-1: {(network-label network)}
      ==
      ;button.hover.pointer
        =onclick  "showNetworkModal()"
        =title  "Change network"
        =style  "background: var(--b1); border: none; color: var(--f3); display: flex; align-items: center; justify-content: center; width: 32px; height: 32px; border-radius: 4px; cursor: pointer; outline: none;"
        ;div(style "width: 16px; height: 16px; display: flex; align-items: center; justify-content: center;")
          ;+  (make:fi 'edit-2')
        ==
      ==
    ==
    ;+  (network-modal network coin-type)
  ==
::
++  network-modal
  |=  [current=?(%main %testnet3 %testnet4 %signet %regtest) coin-type=@ud]
  ^-  manx
  =/  is-mainnet-cointype=?  =(0 coin-type)
  =/  is-testnet-cointype=?  !is-mainnet-cointype
  =/  testnet-svg=manx
    %-  need  %-  de-xml:html
    '<svg xmlns="http://www.w3.org/2000/svg" height="16" width="16" viewBox="0 0 64 64"><g transform="translate(0.00630876,-0.00301984)"><path fill="#6b8fd8" d="m63.033,39.744c-4.274,17.143-21.637,27.576-38.782,23.301-17.138-4.274-27.571-21.638-23.295-38.78,4.272-17.145,21.635-27.579,38.775-23.305,17.144,4.274,27.576,21.64,23.302,38.784z"/><path fill="#FFF" d="m46.103,27.444c0.637-4.258-2.605-6.547-7.038-8.074l1.438-5.768-3.511-0.875-1.4,5.616c-0.923-0.23-1.871-0.447-2.813-0.662l1.41-5.653-3.509-0.875-1.439,5.766c-0.764-0.174-1.514-0.346-2.242-0.527l0.004-0.018-4.842-1.209-0.934,3.75s2.605,0.597,2.55,0.634c1.422,0.355,1.679,1.296,1.636,2.042l-1.638,6.571c0.098,0.025,0.225,0.061,0.365,0.117-0.117-0.029-0.242-0.061-0.371-0.092l-2.296,9.205c-0.174,0.432-0.615,1.08-1.609,0.834,0.035,0.051-2.552-0.637-2.552-0.637l-1.743,4.019,4.569,1.139c0.85,0.213,1.683,0.436,2.503,0.646l-1.453,5.834,3.507,0.875,1.439-5.772c0.958,0.26,1.888,0.5,2.798,0.726l-1.434,5.745,3.511,0.875,1.453-5.823c5.987,1.133,10.489,0.676,12.384-4.739,1.527-4.36-0.076-6.875-3.226-8.515,2.294-0.529,4.022-2.038,4.483-5.155zm-8.022,11.249c-1.085,4.36-8.426,2.003-10.806,1.412l1.928-7.729c2.38,0.594,10.012,1.77,8.878,6.317zm1.086-11.312c-0.99,3.966-7.1,1.951-9.082,1.457l1.748-7.01c1.982,0.494,8.365,1.416,7.334,5.553z"/></g></svg>'
  =/  mainnet-svg=manx
    %-  need  %-  de-xml:html
    '<svg xmlns="http://www.w3.org/2000/svg" height="16" width="16" viewBox="0 0 64 64"><g transform="translate(0.00630876,-0.00301984)"><path fill="#f7931a" d="m63.033,39.744c-4.274,17.143-21.637,27.576-38.782,23.301-17.138-4.274-27.571-21.638-23.295-38.78,4.272-17.145,21.635-27.579,38.775-23.305,17.144,4.274,27.576,21.64,23.302,38.784z"/><path fill="#FFF" d="m46.103,27.444c0.637-4.258-2.605-6.547-7.038-8.074l1.438-5.768-3.511-0.875-1.4,5.616c-0.923-0.23-1.871-0.447-2.813-0.662l1.41-5.653-3.509-0.875-1.439,5.766c-0.764-0.174-1.514-0.346-2.242-0.527l0.004-0.018-4.842-1.209-0.934,3.75s2.605,0.597,2.55,0.634c1.422,0.355,1.679,1.296,1.636,2.042l-1.638,6.571c0.098,0.025,0.225,0.061,0.365,0.117-0.117-0.029-0.242-0.061-0.371-0.092l-2.296,9.205c-0.174,0.432-0.615,1.08-1.609,0.834,0.035,0.051-2.552-0.637-2.552-0.637l-1.743,4.019,4.569,1.139c0.85,0.213,1.683,0.436,2.503,0.646l-1.453,5.834,3.507,0.875,1.439-5.772c0.958,0.26,1.888,0.5,2.798,0.726l-1.434,5.745,3.511,0.875,1.453-5.823c5.987,1.133,10.489,0.676,12.384-4.739,1.527-4.36-0.076-6.875-3.226-8.515,2.294-0.529,4.022-2.038,4.483-5.155zm-8.022,11.249c-1.085,4.36-8.426,2.003-10.806,1.412l1.928-7.729c2.38,0.594,10.012,1.77,8.878,6.317zm1.086-11.312c-0.99,3.966-7.1,1.951-9.082,1.457l1.748-7.01c1.982,0.494,8.365,1.416,7.334,5.553z"/></g></svg>'
  =/  active-style=tape  " background: rgba(100, 150, 255, 0.15); border-color: rgba(100, 150, 255, 0.4);"
  ;div#network-modal(style "display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.5); z-index: 1000; align-items: center; justify-content: center;", onclick "if(event.target === this) hideModal('network-modal')")
    ;div.p4.b1.br2(style "max-width: 320px; width: 100%;")
      ;div(style "display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;")
        ;h3.s1.bold: Select Network
        ;button.hover.pointer(onclick "hideModal('network-modal')", style "background: transparent; border: none; color: var(--f3); cursor: pointer; padding: 4px;")
          ;div(style "width: 20px; height: 20px;")
            ;+  (make:fi 'x')
          ==
        ==
      ==
      ;div.fc.g2
        ;+  ?:  is-testnet-cointype
              ;span;
            ;button.p3.b1.br2.hover.pointer.wf(onclick "setNetwork('main')", style "text-align: left; display: flex; align-items: center; gap: 8px;{?:(=(%main current) active-style "")}")
              ;+  mainnet-svg
              ;span: Mainnet
            ==
        ;+  ?:  is-mainnet-cointype
              ;span;
            ;button.p3.b1.br2.hover.pointer.wf(onclick "setNetwork('testnet4')", style "text-align: left; display: flex; align-items: center; gap: 8px;{?:(=(%testnet4 current) active-style "")}")
              ;+  testnet-svg
              ;span: Testnet4
            ==
        ;+  ?:  is-mainnet-cointype
              ;span;
            ;button.p3.b1.br2.hover.pointer.wf(onclick "setNetwork('testnet3')", style "text-align: left; display: flex; align-items: center; gap: 8px;{?:(=(%testnet3 current) active-style "")}")
              ;+  testnet-svg
              ;span: Testnet3
            ==
        ;+  ?:  is-mainnet-cointype
              ;span;
            ;button.p3.b1.br2.hover.pointer.wf(onclick "setNetwork('signet')", style "text-align: left; display: flex; align-items: center; gap: 8px;{?:(=(%signet current) active-style "")}")
              ;+  testnet-svg
              ;span: Signet
            ==
        ;+  ?:  is-mainnet-cointype
              ;span;
            ;button.p3.b1.br2.hover.pointer.wf(onclick "setNetwork('regtest')", style "text-align: left; display: flex; align-items: center; gap: 8px;{?:(=(%regtest current) active-style "")}")
              ;+  testnet-svg
              ;span: Regtest
            ==
      ==
    ==
  ==
::
++  account-summary-ui
  |=  [recv=(list [@ud address-data]) chng=(list [@ud address-data])]
  ^-  manx
  =/  total-balance=@ud  (compute-total-balance recv chng)
  ;div#account-summary(style "display: flex; justify-content: space-between; align-items: baseline;")
    ;span.f2(style "opacity: 0.8;"): Total Balance
    ;span.s0.bold.mono: {(format-sats total-balance)} sats
  ==
::
++  tab-bar
  |=  [recv-count=@ud chng-count=@ud]
  ^-  manx
  ;div(style "display: flex; border-bottom: 1px solid var(--b3);")
    ;button.tab-btn(data-tab "receiving", onclick "showTab('receiving')", style "flex: 1; padding: 8px 16px; background: transparent; border: none; border-bottom: 2px solid var(--f1); color: var(--f1); font-weight: bold; cursor: pointer; outline: none;")
      ; Receiving ({(scow %ud recv-count)})
    ==
    ;button.tab-btn(data-tab "change", onclick "showTab('change')", style "flex: 1; padding: 8px 16px; background: transparent; border: none; border-bottom: 2px solid transparent; color: var(--f3); cursor: pointer; outline: none;")
      ; Change ({(scow %ud chng-count)})
    ==
  ==
::
++  derive-button
  |=  [chain=tape mop=(list [@ud address-data])]
  ^-  manx
  =/  next-idx=@ud
    ?~  mop  0
    =/  [last-idx=@ud *]  (rear mop)
    +(last-idx)
  =/  chain-tag=tape
    ?:(=("receiving" chain) "recv" "chng")
  ;div.p3.b2.br2.hover.pointer
    =id  "derive-{chain-tag}"
    =onclick  "deriveNext('{chain}')"
    =style  "display: flex; align-items: center; justify-content: center; gap: 8px; border: 2px dashed var(--b3);"
    ;div(style "font-size: 24px; color: var(--f-3);"): +
    ;span.f2.bold.f-3: Derive Next Address (Index {(scow %ud next-idx)})
  ==
::
++  address-list
  |=  [network=network:wt key-hex=tape chain-tag=?(%recv %chng) mop=(list [@ud address-data]) now=@da]
  ^-  manx
  =/  chain=tape  ?:(?=(%recv chain-tag) "receiving" "change")
  ;div.fc.g2(id "addr-list-{(trip chain-tag)}")
    ;*  ?:  =(~ mop)
          :~  ;div.p4.b1.br2.tc(id "empty-{(trip chain-tag)}")
                ;div.s0.f2.mb2: No addresses yet
                ;div.f3.s-1: Click above to derive your first address
              ==
          ==
        (turn (flop mop) |=([idx=@ud a=address-data] (address-row idx a now chain chain-tag network key-hex)))
  ==
::
++  address-row
  |=  [idx=@ud a=address-data now=@da chain=tape chain-tag=?(%recv %chng) network=?(%main %testnet3 %testnet4 %signet %regtest) key-hex=tape]
  ^-  manx
  =/  addr-text=tape  (trip addr.a)
  =/  row-id=tape  "addr-{(trip chain-tag)}-{(scow %ud idx)}"
  =/  has-txs=?
    ?~  info.a  %.n
    (gth tx-count.u.info.a 0)
  =/  row-classes=tape
    ?:(has-txs "p3 b1 br2 hover" "p3 b1 br2 hover empty-address")
  ;div(id row-id, class row-classes, style "display: flex; justify-content: space-between; align-items: center; gap: 12px;")
    ;div(style "flex: 1; min-width: 0;")
      ;div(style "display: flex; align-items: center; gap: 8px;")
        ;span.f3.s-2.mono: Index {(scow %ud idx)}
        ;+  ?~  info.a  ;span;
            =/  balance=@ud
              (sub (add funded.u.info.a mem-funded.u.info.a) (add spent.u.info.a mem-spent.u.info.a))
            ;div(style "display: flex; gap: 8px;")
              ;span.f3.s-2(style "opacity: 0.8;")
                ; • {(scow %ud tx-count.u.info.a)} txs
              ==
              ;span.f3.s-2(style "opacity: 0.8;")
                ; • {(format-sats balance)} sats
              ==
            ==
      ==
      ;div(style "display: flex; align-items: center; gap: 8px;")
        ;button.p1.b0.br1.hover.pointer
          =data-addr  addr-text
          =onclick  "copyAddr(this)"
          =title  "Copy address"
          =style  "background: transparent; border: 1px solid var(--b3); color: var(--f3); display: flex; align-items: center; width: 24px; height: 24px; justify-content: center; outline: none;"
          ;div.copy-icon(style "width: 12px; height: 12px; display: flex; align-items: center; justify-content: center;")
            ;+  (make:fi 'copy')
          ==
          ;div.check-icon(style "width: 12px; height: 12px; display: none; align-items: center; justify-content: center; color: #10b981;")
            ;+  (make:fi 'check')
          ==
        ==
        ;a.mono.f2.s-1.hover
          =href  "/groundwire/wallet/a/{key-hex}/addr/{?:(?=(%recv chain-tag) "recv" "chng")}/{(scow %ud idx)}"
          =style  "white-space: nowrap; overflow: hidden; text-overflow: ellipsis; color: var(--f3); text-decoration: none;"
          ;+  ;/  addr-text
        ==
      ==
    ==
    ;div(style "display: flex; gap: 4px; flex-shrink: 0;")
      ;button.p2.b1.br1.hover.pointer
        =title  ?~(info.a "Never checked" ?~(last-check.u.info.a "Never checked" "Last: {(scow %da u.last-check.u.info.a)}"))
        =data-chain  (trip chain-tag)
        =data-idx  (scow %ud idx)
        =onclick  "refreshAddress(this.dataset.chain, this.dataset.idx)"
        =style  "background: var(--b2); border: 1px solid var(--b3); color: var(--f3); display: flex; align-items: center; width: 32px; height: 32px; justify-content: center; outline: none;"
        ;div(style "width: 16px; height: 16px; display: flex; align-items: center; justify-content: center;")
          ;+  (make:fi 'refresh-cw')
        ==
      ==
      ;button.p2.b1.br1.hover.pointer
        =title  "Remove address"
        =data-chain  (trip chain-tag)
        =data-idx  (scow %ud idx)
        =onclick  "deleteAddress(this.dataset.chain, this.dataset.idx)"
        =style  "background: var(--b2); border: 1px solid var(--b3); color: var(--f3); display: flex; align-items: center; width: 32px; height: 32px; justify-content: center; outline: none; opacity: 0.5;"
        ;div(style "width: 16px; height: 16px; display: flex; align-items: center; justify-content: center;")
          ;+  (make:fi 'trash-2')
        ==
      ==
    ==
  ==
::
++  receive-modal
  |=  recv=(list [@ud address-data])
  ^-  manx
  =/  next=(unit @t)  (next-unused-addr recv)
  ;div#receive-modal(style "display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.5); z-index: 1000; align-items: center; justify-content: center;", onclick "if(event.target === this) hideModal('receive-modal')")
    ;div.p4.b1.br2(style "max-width: 400px; width: 100%;")
      ;div(style "display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;")
        ;h2.s1.bold: Receive Bitcoin
        ;button.hover.pointer(onclick "hideModal('receive-modal')", style "background: transparent; border: 1px solid var(--b3); color: var(--f3); padding: 4px; outline: none; border-radius: 4px;")
          ;div(style "width: 20px; height: 20px;")
            ;+  (make:fi 'x')
          ==
        ==
      ==
      ;+  ?~  next
            ;div.tc.p4
              ;p.f2: No address available. Derive or scan your account first.
            ==
          ;div
            ;div.tc(style "margin-bottom: 16px;")
              ;div#receive-qr(data-address "{(trip u.next)}", style "display: inline-block;");
            ==
            ;div.p3.b2.br2(style "display: flex; align-items: center; gap: 8px;")
              ;button.p1.b0.br1.hover.pointer
                =onclick  "copyReceiveAddr()"
                =title  "Copy address"
                =style  "background: transparent; border: 1px solid var(--b3); color: var(--f3); display: flex; align-items: center; width: 24px; height: 24px; justify-content: center; outline: none; flex-shrink: 0;"
                ;div(style "width: 12px; height: 12px; display: flex; align-items: center; justify-content: center;")
                  ;+  (make:fi 'copy')
                ==
              ==
              ;div#receive-addr.mono.f3(style "overflow: hidden; text-overflow: ellipsis; white-space: nowrap; flex: 1; min-width: 0;"): {(trip u.next)}
            ==
          ==
    ==
  ==
::
++  scan-status-ui
  |=  [scan=?(%active %paused %none) progress=(unit scan-progress)]
  ^-  manx
  ?-    scan
      %active
    =/  border-color=tape  "rgba(100, 150, 255, 0.4)"
    =/  bg-color=tape  "rgba(100, 150, 255, 0.1)"
    ;div#scan-status.p3.b2.br2(style "display: flex; align-items: center; justify-content: space-between; gap: 12px; border: 2px solid {border-color}; background: {bg-color};")
      ;div(style "display: flex; align-items: center; gap: 12px; flex: 1;")
        ;div(style "width: 20px; height: 20px; display: flex; align-items: center; justify-content: center; animation: spin 1s linear infinite;")
          ;+  (make:fi 'loader')
        ==
        ;div(style "display: flex; flex-direction: column; gap: 4px;")
          ;+  ?~  progress
                ;span.f2.bold: Scanning...
              ;span.f2.bold: {?:(=('recv' phase.u.progress) "Receiving" "Change")}
          ;+  ?~  progress
                ;span;
              ;span.f3.s-1: Index: {(scow %ud idx.u.progress)} • Gap: {(scow %ud gap.u.progress)}/20
        ==
      ==
      ;div(style "display: flex; gap: 4px;")
        ;button.p2.b1.br1.hover.pointer
          =title  "Pause full scan"
          =onclick  "pauseScan()"
          =style  "background: rgba(255, 180, 50, 0.2); border: 1px solid rgba(255, 180, 50, 0.4); color: #ffb432; display: flex; align-items: center; width: 32px; height: 32px; justify-content: center; outline: none;"
          ;div(style "width: 16px; height: 16px; display: flex; align-items: center; justify-content: center;")
            ;+  (make:fi 'pause')
          ==
        ==
        ;button.p2.b1.br1.hover.pointer
          =title  "Cancel full scan"
          =onclick  "cancelScan()"
          =style  "background: rgba(255, 80, 80, 0.2); border: 1px solid rgba(255, 80, 80, 0.4); color: #ff5050; display: flex; align-items: center; width: 32px; height: 32px; justify-content: center; outline: none;"
          ;div(style "width: 16px; height: 16px; display: flex; align-items: center; justify-content: center;")
            ;+  (make:fi 'x-circle')
          ==
        ==
      ==
    ==
  ::
      %paused
    =/  border-color=tape  "rgba(150, 150, 150, 0.4)"
    =/  bg-color=tape  "rgba(150, 150, 150, 0.1)"
    ;div#scan-status.p3.b2.br2(style "display: flex; align-items: center; justify-content: space-between; gap: 12px; border: 2px solid {border-color}; background: {bg-color};")
      ;div(style "display: flex; align-items: center; gap: 12px; flex: 1;")
        ;div(style "width: 20px; height: 20px; display: flex; align-items: center; justify-content: center;")
          ;+  (make:fi 'pause-circle')
        ==
        ;div(style "display: flex; flex-direction: column; gap: 4px;")
          ;+  ?~  progress
                ;span.f2.bold: Scan Paused
              ;span.f2.bold: Paused — {?:(=('recv' phase.u.progress) "Receiving" "Change")}
          ;+  ?~  progress
                ;span;
              ;span.f3.s-1: Index: {(scow %ud idx.u.progress)} • Gap: {(scow %ud gap.u.progress)}/20
        ==
      ==
      ;div(style "display: flex; gap: 4px;")
        ;button.p2.b1.br1.hover.pointer
          =title  "Resume full scan"
          =onclick  "resumeScan()"
          =style  "background: rgba(50, 200, 100, 0.2); border: 1px solid rgba(50, 200, 100, 0.4); color: #32c864; display: flex; align-items: center; width: 32px; height: 32px; justify-content: center; outline: none;"
          ;div(style "width: 16px; height: 16px; display: flex; align-items: center; justify-content: center;")
            ;+  (make:fi 'play')
          ==
        ==
        ;button.p2.b1.br1.hover.pointer
          =title  "Cancel full scan"
          =onclick  "cancelScan()"
          =style  "background: rgba(255, 80, 80, 0.2); border: 1px solid rgba(255, 80, 80, 0.4); color: #ff5050; display: flex; align-items: center; width: 32px; height: 32px; justify-content: center; outline: none;"
          ;div(style "width: 16px; height: 16px; display: flex; align-items: center; justify-content: center;")
            ;+  (make:fi 'x-circle')
          ==
        ==
      ==
    ==
  ::
      %none
    ;div#scan-status.p3.b2.br2.hover.pointer
      =onclick  "fullScan()"
      =style  "display: flex; align-items: center; justify-content: center; gap: 8px; border: 2px solid var(--b3); background: var(--b2);"
      ;div(style "font-size: 24px; color: var(--f-3);"): ↻
      ;span.f2.bold.f-3: Full Scan
    ==
  ==
::
++  addresses-fragment
  |=  [network=network:wt key-hex=tape recv=(list [@ud address-data]) chng=(list [@ud address-data]) now=@da scan=?(%active %paused %none) progress=(unit scan-progress)]
  ^-  manx
  =/  recv-count=@ud  (lent recv)
  =/  chng-count=@ud  (lent chng)
  ;div.fc(style "flex: 1; min-height: 0;")
    ;div.fc.g2(style "flex-shrink: 0;")
      ;div#scan-status-wrap
        ;+  (scan-status-ui scan progress)
      ==
      ;div#tab-bar
        ;+  (tab-bar recv-count chng-count)
      ==
      ;div#receiving-derive(style "padding-top: 8px;")
        ;+  (derive-button "receiving" recv)
      ==
      ;div#change-derive(style "display: none; padding-top: 8px;")
        ;+  (derive-button "change" chng)
      ==
    ==
    ;div#addr-scroll.fc.g2(style "flex: 1; min-height: 0; overflow-y: auto; padding-top: 8px;")
      ;div#receiving-addresses
        ;+  (address-list network key-hex %recv recv now)
      ==
      ;div#change-addresses(style "display: none;")
        ;+  (address-list network key-hex %chng chng now)
      ==
    ==
  ==
::
++  fee-info-ui
  |=  fi=fee-calc
  ^-  manx
  =/  fee-color=tape
    ?:  (syn:si actual-fee.fi)  "var(--f3)"
    "rgba(255, 100, 100, 0.8)"
  ;div#fee-info.f2(style "margin-top: 4px; display: flex; gap: 16px; flex-wrap: wrap;")
    ;span: Inputs: {(scow %ud total-inputs.fi)} sats
    ;span: Outputs: {(scow %ud total-outputs.fi)} sats
    ;span: Size: ~{(scow %ud est-vbytes.fi)} vB
    ;span(style "color: {fee-color};"): Fee: {?:((syn:si actual-fee.fi) (scow %ud (abs:si actual-fee.fi)) "-{(scow %ud (abs:si actual-fee.fi))}")} sats
  ==
::
++  auto-select-ui
  |=  [has-auto=? is-random=? is-largest=? target=@ud]
  ^-  manx
  ;div#auto-select(style "margin-bottom: 8px;")
    ;div(style "display: flex; align-items: center; gap: 8px;")
      ;label.pointer(style "display: flex; align-items: center; gap: 8px;")
        ;+  ?:  has-auto
              ;input(type "checkbox", checked "", onchange "setAutoMode(this.checked ? 'random' : 'disabled')", style "width: 16px; height: 16px; cursor: pointer;");
            ;input(type "checkbox", onchange "setAutoMode(this.checked ? 'random' : 'disabled')", style "width: 16px; height: 16px; cursor: pointer;");
        ;span.f3: Auto-select UTXOs
      ==
      ;+  ?:  has-auto
            ;span.f3(style "opacity: 0.6;"): (target: {(scow %ud target)} sats)
          ;span;
    ==
    ;div(style "margin-left: 24px; margin-top: 8px; display: {?:(has-auto "flex" "none")}; align-items: center; gap: 16px;")
      ;button.p1.b1.br1.hover.pointer
        =onclick  "runAutoSelect()"
        =title  "Re-select UTXOs"
        =style  "background: rgba(100, 150, 255, 0.15); border: 1px solid rgba(100, 150, 255, 0.4); color: var(--f3); display: flex; align-items: center; justify-content: center; width: 28px; height: 28px; outline: none;"
        ;div(style "width: 14px; height: 14px; display: flex; align-items: center; justify-content: center;")
          ;+  (make:fi 'refresh-cw')
        ==
      ==
      ;label.pointer(style "display: flex; align-items: center; gap: 4px;")
        ;+  ?:  is-random
              ;input(type "radio", name "auto-mode", value "random", checked "", onchange "setAutoMode('random')", style "cursor: pointer;");
            ;input(type "radio", name "auto-mode", value "random", onchange "setAutoMode('random')", style "cursor: pointer;");
        ;span.f3: Random
      ==
      ;label.pointer(style "display: flex; align-items: center; gap: 4px;")
        ;+  ?:  is-largest
              ;input(type "radio", name "auto-mode", value "largest-first", checked "", onchange "setAutoMode('largest-first')", style "cursor: pointer;");
            ;input(type "radio", name "auto-mode", value "largest-first", onchange "setAutoMode('largest-first')", style "cursor: pointer;");
        ;span.f3: Largest first
      ==
    ==
  ==
::
++  utxo-row-ui
  |=  [txid=@t vout=@ud value=@ud addr=@t spend=spend:fees is-sel=?]
  ^-  manx
  ;div.p3.b1.br2(style "display: flex; align-items: center; gap: 12px; margin-bottom: 4px;")
    ;button.p1.b0.br1.hover.pointer
      =onclick  "toggleInput('{(trip txid)}', {(a-co:co vout)}, {(a-co:co value)}, '{(trip (scot %tas spend))}', {?:(is-sel "true" "false")})"
      =style  "background: transparent; border: 1px solid var(--b3); color: var(--f3); display: flex; align-items: center; width: 24px; height: 24px; justify-content: center; outline: none; flex-shrink: 0;"
      ;div(style "width: 16px; height: 16px; display: flex; align-items: center; justify-content: center;")
        ;+  (make:fi ?:(is-sel 'check-square' 'square'))
      ==
    ==
    ;div(style "flex: 1; min-width: 0;")
      ;div.mono.f2.s-1(style "white-space: nowrap; overflow: hidden; text-overflow: ellipsis; color: var(--f3);"): {(trip txid)}:{(scow %ud vout)}
      ;div.mono.f3.s-2(style "white-space: nowrap; overflow: hidden; text-overflow: ellipsis; opacity: 0.7;"): {(trip addr)}
    ==
    ;div.f3.s-2(style "white-space: nowrap; flex-shrink: 0;"): {(scow %ud value)} sats
  ==
::
++  output-list-ui
  |=  dr=(unit transaction:drft)
  ^-  manx
  ;div.fc.g2(style "max-height: 200px; overflow-y: auto;")
    ;*  ?~  dr
          :~  ;div.p4.b1.br2.tc
                ;div.s0.f2.mb2: No outputs yet
                ;div.f3.s-1: Add your first output below
              ==
          ==
        ?:  =(~ outputs.u.dr)
          :~  ;div.p4.b1.br2.tc
                ;div.s0.f2.mb2: No outputs yet
                ;div.f3.s-1: Add your first output below
              ==
          ==
        =/  idx=@ud  0
        =/  remaining=(list output:drft)  outputs.u.dr
        |-
        ?~  remaining  ~
        :-  ;div.p3.b1.br2(style "display: flex; align-items: center; gap: 8px;")
              ;span.mono.f2.s-1(style "overflow: hidden; text-overflow: ellipsis; white-space: nowrap; flex: 1; min-width: 0;"): {(trip address.i.remaining)}
              ;span.f3.s-2(style "white-space: nowrap; flex-shrink: 0;"): {(scow %ud amount.i.remaining)} sats
              ;button.p1.b0.br1.hover.pointer
                =onclick  "deleteOutput({(scow %ud idx)})"
                =title  "Delete output"
                =style  "background: var(--b2); border: 1px solid var(--b3); color: var(--f3); display: flex; align-items: center; width: 24px; height: 24px; justify-content: center; outline: none; flex-shrink: 0;"
                ;div(style "width: 12px; height: 12px; display: flex; align-items: center; justify-content: center;")
                  ;+  (make:fi 'trash-2')
                ==
              ==
            ==
        $(idx +(idx), remaining t.remaining)
  ==
::
++  change-section-ui
  |=  [has-cfg=? fee-rate=@ud est-fee=@ud est-vbytes=@ud change-result=change-result:fees next-chg=(unit @t)]
  ^-  manx
  ;div.p3.b1.br2.mb2(style "border: 1px dashed var(--b3);")
    ;div(style "display: flex; align-items: center; gap: 12px; margin-bottom: 8px;")
      ;label.pointer(style "display: flex; align-items: center; gap: 8px;")
        ;+  ?:  has-cfg
              ;input#use-change(type "checkbox", checked "", onchange "toggleChange(this.checked)", style "width: 16px; height: 16px; cursor: pointer;");
            ;input#use-change(type "checkbox", onchange "toggleChange(this.checked)", style "width: 16px; height: 16px; cursor: pointer;");
        ;span.f2.bold: Send change to self
      ==
    ==
    ;div#change-details(style "display: {?:(has-cfg "block" "none")};")
      ;div(style "display: flex; align-items: center; gap: 12px; margin-bottom: 8px;")
        ;label.f3(style "white-space: nowrap;"): Fee rate:
        ;input#fee-rate.p2.b1.br1.mono(type "number", min "1", value "{(scow %ud fee-rate)}", oninput "updateChange()", style "width: 80px; background: var(--b1); border: 1px solid var(--b3); color: var(--f2); outline: none;");
        ;span.f3: sat/vB
      ==
      ;+  ?~  next-chg
            ;div.f3(style "color: rgba(255,100,100,0.9); padding: 8px;"): No unused change address — derive more addresses first
          ;div(style "display: flex; flex-direction: column; gap: 4px; padding: 8px; background: var(--b2); border-radius: 4px;")
            ;div(style "display: flex; align-items: center; gap: 8px;")
              ;span.f3(style "opacity: 0.6;"): Est. fee:
              ;span#est-fee.mono.f2: {(scow %ud est-fee)} sats ({(scow %ud est-vbytes)} vB × {(scow %ud fee-rate)} sat/vB)
            ==
            ;div(style "display: flex; align-items: center; gap: 8px;")
              ;span.f3(style "opacity: 0.8;"): Change:
              ;+  ?-  -.change-result
                    %ok  ;span#change-amount.mono.f2: {(scow %ud amount.change-result)} sats
                    %insufficient  ;span#change-amount.mono.f2(style "background: rgba(220,80,80,0.9); color: white; padding: 2px 6px; border-radius: 3px;"): need {(scow %ud shortfall.change-result)} more sats
                    %dust  ;span#change-amount.mono.f2(style "background: rgba(200,150,50,0.9); color: white; padding: 2px 6px; border-radius: 3px;"): {(scow %ud amount.change-result)} sats → fee (dust)
                  ==
            ==
            ;div(style "display: flex; align-items: center; gap: 8px;")
              ;span.f3(style "opacity: 0.6;"): To:
              ;span.mono.f3.s-1(style "opacity: 0.8; overflow: hidden; text-overflow: ellipsis;"): {(trip u.next-chg)}
            ==
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
  @keyframes spin \{
    from \{ transform: rotate(0deg); }
    to \{ transform: rotate(360deg); }
  }
  #account-page.hide-empty .empty-address \{
    display: none !important;
  }
  """
::
++  script-text
  |=  [network=?(%main %testnet3 %testnet4 %signet %regtest) acct-ref=tape acct-hex=tape]
  ^-  tape
  """
  var API = '/grubbery/api';
  var mainSig = 'apps/wallet.wallet_app/main.sig';
  var acctRef = '{acct-hex}';
  var activeNetwork = '{(trip ;;(@ta network))}';
  var activeTab = 'receiving';

  function showReceiveModal() \{
    document.getElementById('receive-modal').style.display = 'flex';
    var qrContainer = document.getElementById('receive-qr');
    if (qrContainer) \{
      var address = qrContainer.getAttribute('data-address');
      qrContainer.innerHTML = '';
      new QRCode(qrContainer, \{text: address, width: 200, height: 200});
    }
  }

  function copyReceiveAddr() \{
    var el = document.getElementById('receive-addr');
    if (el) navigator.clipboard.writeText(el.textContent.trim());
  }

  function showNetworkModal() \{
    document.getElementById('network-modal').style.display = 'flex';
  }

  function hideModal(id) \{
    document.getElementById(id).style.display = 'none';
  }

  function setNetwork(network) \{
    acctPoke(\{action: 'set-network', network: network}).then(function() \{
      window.location.reload();
    });
  }

  function acctPoke(body, cb) \{
    body.account = acctRef;
    var url = API + '/poke/' + mainSig + '?blot=/json';
    return fetch(url, \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(body)
    }).then(function(r) \{
      if (!r.ok) return r.text().then(function(t) \{ console.error('poke error', t) });
      if (cb) setTimeout(cb, 500);
    }).catch(function(e) \{ console.error('poke failed', e) });
  }
  function deriveNext(chain) \{
    acctPoke(\{action: 'derive-next', chain: chain});
  }

  function deleteAddress(chain, idx) \{
    if (!confirm('Remove address ' + chain + '-' + idx + '?')) return;
    acctPoke(\{action: 'delete-address', chain: chain, index: Number(idx)});
  }

  function refreshAddress(chain, idx) \{
    acctPoke(\{action: 'refresh', chain: chain, index: Number(idx)});
  }

  function fullScan() \{
    acctPoke(\{action: 'full-scan'});
  }

  function pauseScan() \{
    acctPoke(\{action: 'pause-scan'});
  }

  function resumeScan() \{
    acctPoke(\{action: 'resume-scan'});
  }

  function cancelScan() \{
    acctPoke(\{action: 'cancel-scan'});
  }

  function toggleEmptyAddresses() \{
    var page = document.getElementById('account-page');
    var button = document.getElementById('empty-toggle');
    var iconContainer = document.getElementById('eye-icon');
    var isHiding = page.classList.contains('hide-empty');
    if (isHiding) \{
      page.classList.remove('hide-empty');
      button.setAttribute('title', 'Hide addresses without transactions');
      iconContainer.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path><circle cx="12" cy="12" r="3"></circle></svg>';
    } else \{
      page.classList.add('hide-empty');
      button.setAttribute('title', 'Show addresses without transactions');
      iconContainer.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"></path><line x1="1" y1="1" x2="23" y2="23"></line></svg>';
    }
  }

  function copyAddr(btn) \{
    navigator.clipboard.writeText(btn.dataset.addr);
    var ci = btn.querySelector('.copy-icon');
    var ki = btn.querySelector('.check-icon');
    if (ci) ci.style.display = 'none';
    if (ki) ki.style.display = 'flex';
    setTimeout(function() \{
      if (ci) ci.style.display = 'flex';
      if (ki) ki.style.display = 'none';
    }, 1500);
  }

  function showTab(tab) \{
    activeTab = tab;
    applyTab();
  }

  function applyTab() \{
    var r = document.getElementById('receiving-addresses');
    var c = document.getElementById('change-addresses');
    var rd = document.getElementById('receiving-derive');
    var cd = document.getElementById('change-derive');
    if (r) r.style.display = activeTab === 'receiving' ? '' : 'none';
    if (c) c.style.display = activeTab === 'change' ? '' : 'none';
    if (rd) rd.style.display = activeTab === 'receiving' ? '' : 'none';
    if (cd) cd.style.display = activeTab === 'change' ? '' : 'none';
    document.querySelectorAll('.tab-btn').forEach(function(btn) \{
      var active = btn.dataset.tab === activeTab;
      btn.style.borderBottomColor = active ? 'var(--f1)' : 'transparent';
      btn.style.color = active ? 'var(--f1)' : 'var(--f3)';
      btn.style.fontWeight = active ? 'bold' : 'normal';
    });
  }

  function connectSSE() \{
    var es = new EventSource('/groundwire/wallet/a/' + acctRef + '/stream');
    es.addEventListener('fragment', function(e) \{
      try \{
        var data = JSON.parse(e.data);
        var el = document.getElementById(data.target);
        if (!el) return;
        if (data.action === 'prepend') \{
          if (data.rowId && document.getElementById(data.rowId)) return;
          var empty = el.querySelector('[id^="empty-"]');
          if (empty) empty.remove();
          el.insertAdjacentHTML('afterbegin', data.html);
        } else if (data.action === 'update') \{
          var existing = document.getElementById(data.rowId);
          if (existing) existing.outerHTML = data.html;
        } else \{
          el.innerHTML = data.html;
        }
        applyTab();
      } catch(err) \{ console.error('SSE fragment error', err); }
    });
    es.addEventListener('receive-addr', function(e) \{
      try \{
        var addr = e.data;
        var qr = document.getElementById('receive-qr');
        if (qr) qr.setAttribute('data-address', addr);
        var el = document.getElementById('receive-addr');
        if (el) el.textContent = addr;
      } catch(err) \{ console.error('SSE receive-addr error', err); }
    });
    es.onerror = function() \{
      es.close();
      setTimeout(connectSSE, 3000);
    };
  }
  connectSSE();
  """
::
++  send-scripts-ui
  |=  [next-chg-tape=tape acct-ref=tape key-hex=tape]
  ^-  manx
  =/  js=tape
    """
    var API = '/grubbery/api';
    var mainSig = 'apps/wallet.wallet_app/main.sig';
    var acctRef = '{acct-ref}';
    var changeAddress = '{next-chg-tape}';

    function poke(action, extra) \{
      var body = Object.assign(\{action: action, account: acctRef}, extra || \{});
      var url = API + '/poke/' + mainSig + '?blot=/json';
      return fetch(url, \{
        method: 'POST',
        headers: \{'Content-Type': 'application/json'},
        body: JSON.stringify(body)
      });
    }

    function addOutput() \{
      var addr = document.getElementById('output-addr').value.trim();
      var amt = parseInt(document.getElementById('output-amt').value);
      if (!addr || !amt) return;
      poke('add-output', \{address: addr, amount: amt}).then(function() \{
        document.getElementById('output-addr').value = '';
        document.getElementById('output-amt').value = '';
      });
    }

    function deleteOutput(idx) \{
      poke('delete-output', \{index: idx});
    }

    function clearDraft() \{
      poke('clear-draft');
    }

    function toggleInput(txid, vout, value, spend, isSelected) \{
      if (isSelected) \{
        poke('remove-input', \{'utxo-txid': txid, 'utxo-vout': vout});
      } else \{
        poke('add-input', \{'utxo-txid': txid, 'utxo-vout': vout, 'utxo-value': value, 'utxo-spend': spend});
      }
    }

    function toggleChange(enabled) \{
      document.getElementById('change-details').style.display = enabled ? 'block' : 'none';
      if (enabled) \{
        updateChange();
      } else \{
        poke('clear-change-config');
      }
    }

    function updateChange() \{
      if (!changeAddress) return;
      var feeRate = parseInt(document.getElementById('fee-rate').value) || 10;
      poke('set-change-config', \{'fee-rate': feeRate, 'change-address': changeAddress});
    }

    function setAutoMode(mode) \{
      poke('set-auto-select-mode', \{mode: mode});
    }

    function runAutoSelect() \{
      poke('run-auto-select');
    }

    function buildTransaction() \{
      poke('build-transaction');
    }

    function connectSSE() \{
      var es = new EventSource('/groundwire/wallet/a/{key-hex}/send/stream');
      es.addEventListener('fragment', function(e) \{
        try \{
          var data = JSON.parse(e.data);
          var el = document.getElementById(data.target);
          if (!el) return;
          el.innerHTML = data.html;
        } catch(err) \{ console.error('SSE fragment error', err); }
      });
      es.onerror = function() \{
        es.close();
        setTimeout(connectSSE, 3000);
      };
    }
    connectSSE();
    """
  ;script
    ;+  ;/  js
  ==
::
++  detail-page
  |=  [acct-name=@t key-hex=tape wallet-xpub=@t network=network:wt stype=script-type recv=(list [@ud address-data]) chng=(list [@ud address-data]) now=@da scan=?(%active %paused %none) progress=(unit scan-progress) rfsh=(set (pair ?(%recv %chng) @ud)) wal-name=@t can-sign=?]
  ^-  manx
  ;html
    ;head
      ;title: {(trip acct-name)}
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;+  feather:feather
      ;script(src "https://cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js");
      ;style
        ;+  ;/  style-text
      ==
    ==
    ;body
      ;div(style "min-width: 650px; height: 100%;")
        ;div#account-page.fc.g3.p5.ma.mw-page(style "height: 100%;")
          ;div(style "flex-shrink: 0; display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;")
            ;+  ?:  =('' wallet-xpub)
                  ;a.hover.pointer(href "/groundwire/wallet/", style "color: var(--f3); text-decoration: none;"): ← Back to Wallets
                ;a.hover.pointer(href "/groundwire/wallet/w/{(trip wallet-xpub)}/", style "color: var(--f3); text-decoration: none;"): ← Back to Wallet
          ==
          ;div.p4.b1.br2(style "flex-shrink: 0; position: relative;")
            ;button#empty-toggle.hover.pointer
              =onclick  "toggleEmptyAddresses()"
              =title  "Hide addresses without transactions"
              =style  "position: absolute; top: 16px; right: 16px; background: transparent; border: 1px solid var(--b3); color: var(--f3); display: flex; align-items: center; justify-content: center; width: 32px; height: 32px; border-radius: 4px; cursor: pointer; outline: none;"
              ;div#eye-icon(style "width: 16px; height: 16px; display: flex; align-items: center; justify-content: center;")
                ;+  (make:fi 'eye')
              ==
            ==
            ;h1.s2.bold.mb2
              ; {(trip acct-name)}
              ;+  ?:  =('' wal-name)  ;span;
                  ;span.f2(style "opacity: 0.4; font-weight: normal;"): {" | "}{(trip wal-name)}
            ==
            ;div#network-badge-wrap
              ;+  (network-badge-ui network)
            ==
          ==
          ;div.p4.b2.br2(style "flex-shrink: 0;")
            ;h2.s1.bold.mb2: Account Summary
            ;div#account-summary-wrap
              ;+  (account-summary-ui recv chng)
            ==
            ;div(style "display: flex; gap: 8px; margin-top: 12px; justify-content: center;")
              ;+  ?.  can-sign  ;span;
                ;a.p2.b1.br2.hover.pointer
                  =href  "/groundwire/wallet/a/{key-hex}/send"
                  =style  "display: flex; align-items: center; justify-content: center; gap: 6px; background: rgba(100, 150, 255, 0.15); border: 1px solid rgba(100, 150, 255, 0.4); color: var(--f3); text-decoration: none; outline: none; white-space: nowrap;"
                  ;div(style "width: 16px; height: 16px; display: flex; align-items: center; justify-content: center;")
                    ;+  (make:fi 'arrow-up')
                  ==
                  ;span.f2.bold: Send
                ==
              ;button.p2.b1.br2.hover.pointer
                =onclick  "showReceiveModal()"
                =style  "display: flex; align-items: center; justify-content: center; gap: 6px; background: rgba(50, 200, 100, 0.15); border: 1px solid rgba(50, 200, 100, 0.4); color: var(--f3); outline: none; white-space: nowrap;"
                ;div(style "width: 16px; height: 16px; display: flex; align-items: center; justify-content: center;")
                  ;+  (make:fi 'arrow-down')
                ==
                ;span.f2.bold: Receive
              ==
            ==
          ==
          ;div#live-content.fc.g3(style "flex: 1; min-height: 0;")
            ;+  (receive-modal recv)
            ;+  (addresses-fragment network key-hex recv chng now scan progress)
          ==
        ==
      ==
      ;script
        ;+  ;/  (script-text network key-hex key-hex)
      ==
    ==
  ==
::
++  send-page
  |=  [acct-name=@t key-hex=tape network=network:wt stype=script-type recv=(list [@ud address-data]) chng=(list [@ud address-data]) dr=(unit transaction:drft) now=@da wal-name=@t]
  ^-  manx
  =/  fi=fee-calc  (compute-fee-info dr)
  =/  utxos=(list [addr=@t u=utxo chain=?(%recv %chng) idx=@ud])
    %+  weld
      ^-  (list [addr=@t u=utxo chain=?(%recv %chng) idx=@ud])
      %-  zing
      %+  turn  recv
      |=  [idx=@ud a=address-data]
      (turn utxos.a |=(u=utxo [addr.a u %recv idx]))
    ^-  (list [addr=@t u=utxo chain=?(%recv %chng) idx=@ud])
    %-  zing
    %+  turn  chng
    |=  [idx=@ud a=address-data]
    (turn utxos.a |=(u=utxo [addr.a u %chng idx]))
  =/  next-chg=(unit @t)  (next-unused-change-addr chng)
  =/  next-chg-tape=tape  ?~(next-chg "" (trip u.next-chg))
  =/  auto-mode=(unit select-mode:drft)
    ?~  dr  ~
    auto-select.u.dr
  =/  has-auto=?  ?=(^ auto-mode)
  =/  is-random=?  =(auto-mode `%random)
  =/  is-largest=?  =(auto-mode `%largest-first)
  =/  spend=spend:fees  stype
  =/  total-balance=@ud
    %+  roll  utxos
    |=  [[addr=@t u=utxo chain=?(%recv %chng) idx=@ud] sum=@ud]
    (add sum value.u)
  =/  utxo-rows=(list manx)
    ?~  utxos
      :~  ;div.p3.b1.br2.f3: No UTXOs available
      ==
    %+  turn  utxos
    |=  [addr=@t u=utxo chain=?(%recv %chng) idx=@ud]
    =/  is-sel=?
      ?~  dr  %.n
      %+  lien  inputs.u.dr
      |=(i=utxo-input:drft &(=(txid.i txid.u) =(vout.i vout.u)))
    (utxo-row-ui txid.u vout.u value.u addr spend is-sel)
  ;html
    ;head
      ;title: Send - {(trip acct-name)}
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;+  feather:feather
      ;style: html, body \{ height: 100vh !important; overflow: hidden !important; margin: 0 !important; }
    ==
    ;body.dark.b0.f1(style "height: 100%;")
      ;div.fc.g3.p5.ma(style "max-width: 720px; height: 100%; overflow-y: auto;")
        ;a.hover.pointer(href "/groundwire/wallet/a/{key-hex}/", style "color: var(--f3); text-decoration: none; flex-shrink: 0;"): ← Back
        ;div.p4.b1.br2(style "flex-shrink: 0;")
          ;h1.s2.bold(style "margin-bottom: 8px;")
            ; Send Bitcoin
            ;span(style "opacity: 0.4; margin: 0 8px;"): |
            ;span.f2(style "opacity: 0.5; font-weight: normal;"): {(trip acct-name)}
          ==
          ;div#send-balance.f2(style "margin-top: 4px;"): Available: {(scow %ud total-balance)} sats
          ;div#send-fee-info
            ;+  (fee-info-ui fi)
          ==
        ==
        ;div.p4.b2.br2
          ;h2.s1.bold.mb2: Select UTXOs (Inputs)
          ;div#send-auto-select
            ;+  (auto-select-ui has-auto is-random is-largest (add total-outputs.fi est-fee.fi))
          ==
          ;div.f3(style "opacity: 0.8; margin-bottom: 8px;"): Select which coins to spend
          ;div#utxo-list(style "max-height: 300px; overflow-y: auto;")
            ;*  utxo-rows
          ==
        ==
        ;div.p3.b2.br2(style "flex-shrink: 0;")
          ;h3.s0.bold(style "margin-bottom: 8px;"): Add Output
          ;div(style "display: flex; gap: 8px; width: 100%;")
            ;div(style "flex: 2;")
              ;label.f3.bold(style "display: block; margin-bottom: 4px;"): Address
              ;input#output-addr.p2.b1.br1(type "text", placeholder "bc1q... or tb1q...", style "outline: none; width: 100%;");
            ==
            ;div(style "flex: 1;")
              ;label.f3.bold(style "display: block; margin-bottom: 4px;"): Amount (sats)
              ;input#output-amt.p2.b1.br1(type "number", placeholder "10000", min "1", style "outline: none; width: 100%;");
            ==
          ==
          ;button.p2.b1.br2.hover.pointer
            =onclick  "addOutput()"
            =style  "background: rgba(100, 150, 255, 0.15); border: 1px solid rgba(100, 150, 255, 0.4); outline: none; color: var(--f3); width: 100%; margin-top: 8px;"
            ;span.f3: + Add Output
          ==
        ==
        ;div.p4.b2.br2(style "flex-shrink: 0;")
          ;h2.s1.bold.mb2: Transaction Outputs
          ;div.f3(style "opacity: 0.8; margin-bottom: 12px;"): Draft outputs for this transaction
          ;div#send-change-section
            ;+  (change-section-ui has-change-config.fi fee-rate.fi est-fee.fi est-vbytes.fi change-result.fi next-chg)
          ==
          ;div#output-list
            ;+  (output-list-ui dr)
          ==
        ==
        ;div.p4.b2.br2(style "display: flex; gap: 12px; justify-content: center; flex-shrink: 0;")
          ;button.p3.b1.br2.hover.pointer
            =onclick  "if(confirm('Clear all outputs?')) clearDraft()"
            =style  "background: rgba(255, 100, 100, 0.15); border: 1px solid rgba(255, 100, 100, 0.4); outline: none; color: var(--f3); min-width: 120px;"
            ;span.f2: Clear
          ==
          ;button.p3.b1.br2.hover.pointer
            =onclick  "if(confirm('Broadcast this transaction?')) buildTransaction()"
            =style  "background: rgba(100, 200, 100, 0.2); border: 1px solid rgba(100, 200, 100, 0.5); outline: none; color: var(--f3); min-width: 120px;"
            ;span.f2: Send
          ==
        ==
      ==
      ;+  (send-scripts-ui next-chg-tape key-hex key-hex)
    ==
  ==
--
