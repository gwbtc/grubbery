::  wallet nexus: bitcoin SPV wallet management UI
::
/<  feather       /lib/feather.hoon
/<  fi            /lib/feather-icons.hoon
/<  wt            /lib/wallet-types.hoon
/<  bip39         /lib/bip39.hoon
/<  bip32         /lib/bip32.hoon
/<  seed-phrases  /lib/seed-phrases.hoon
/<  bech32        /lib/bech32.hoon
/<  acct-ui       /lib/wallet-account-ui.hoon
/<  aio           /lib/wallet/account-io.hoon
/<  fees          /lib/tx/fees.hoon
/<  utxo-sel      /lib/tx/select.hoon
/<  txb           /lib/tx/build.hoon
/<  bcu           /lib/bitcoin-utils.hoon
/<  simp          /lib/wallet-simple-ui.hoon
/<  det-ui        /lib/wallet/detail-ui.hoon
/<  drft          /lib/tx/draft.hoon
/<  b329          /lib/bip329.hoon
/<  taproot       /lib/taproot.hoon
/&  man           /man/wallet/app/readme.md
/&  icon          icon.svg
=,  wt
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      ~&  >>  [%wallet-on-load %proc-in-old-ball ?=(^ (~(dap ba:tarball ball) /proc))]
      ~&  >>  [%wallet-on-load %registry-in-old-ball ?=(^ (~(get ba:tarball ball) [/ %'registry.wallet_registry']))]
      ~&  >>  [%wallet-on-load %dir-keys ~(key by dir.ball)]
      =/  [wal=wallet-data mxpub1=@t ref1=@t xprv1=@t net1=network:wt st1=script-type og1=parsed-origin:b329]
        (make-dev-wallet 'Dev Wallet' [%t 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about'] %testnet4)
      =/  [fau-wal=wallet-data mxpub2=@t ref2=@t xprv2=@t net2=network:wt st2=script-type og2=parsed-origin:b329]
        (make-dev-wallet 'Fauceted Wallet' [%t 'injury idea term fox crop movie type critic hello inquiry lottery agree'] %testnet3)
      =/  init-lbls=labels:b329
        =/  l=labels:b329  *labels:b329
        =.  l  (~(put la:b329 l) [%xpub mxpub1 (rap 3 ~['gwbtc:wallet:' 'Dev Wallet']) ~ ~ ~])
        =.  l  (~(put la:b329 l) [%xpub mxpub2 (rap 3 ~['gwbtc:wallet:' 'Fauceted Wallet']) ~ ~ ~])
        =.  l  (make-acct-labels:aio l ref1 'Default' net1 og1)
        (make-acct-labels:aio l ref2 'Default' net2 og2)
      =/  init-sec=secrets
        :*  %-  ~(gas by *(map @t seed))
            ~[[xpub.wal seed.wal] [xpub.fau-wal seed.fau-wal]]
            *(map @t @t)
        ==
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'Wallet'
            info+s+'Bitcoin wallet'
            color+s+'#f7931a'
            image+s+'/grubbery/tiles/icon/wallet'
            href+s+'/groundwire/wallet/simple'
        ==
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%over %& [/ %'tile.json'] [[/ %json] tile]]
          [%over %& [/ %'icon.svg'] [[/ %mime] icon]]
          [%over %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'labels.wallet_labels'] [[/wallet %labels] init-lbls]]
          [%fall %& [/ %'secrets.wallet_secrets'] [[/wallet %secrets] init-sec]]
          [%fall %& [/ %'drafts.wallet_drafts'] [[/wallet %drafts] *(map @t transaction:drft)]]
          [%fall %& [/ %'ptsts.wallet_ptsts'] [[/wallet %ptsts] *(map @t ptst:taproot)]]
          [%fall %& [/ %'registry.wallet_registry'] [[/wallet %registry] *proc-registry]]
          [%fall %| /proc empty-dir:loader]
          [%fall %& [/ui %'http.sig'] [[/ %sig] ~]]
          [%fall %| /ui/requests empty-dir:loader]
          [%over %& [/ %'README.md'] [[/ %mime] man]]
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      =*  h  ~(. +>+ rail)
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::  /main.sig: receive pokes for wallet actions
          ::
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%wallet /main: failed")
        ;<  ~  bind:m  ensure-simple-wallet:h
        ;<  ~  bind:m  ensure-public-poke:h
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
            =/  xpub=@t  (seed-to-xpub:h u.sd)
            ;<  sec=secrets  bind:m  load-secrets:h
            ;<  ~  bind:m  (save-secrets:h sec(seeds (~(put by seeds.sec) xpub u.sd)))
            ;<  lbls=labels:b329  bind:m  load-labels:h
            =/  new-lbls=labels:b329
              (~(put la:b329 lbls) [%xpub xpub (rap 3 ~['gwbtc:wallet:' wallet-name]) ~ ~ ~])
            ;<  ~  bind:m  (save-labels:h new-lbls)
            $
              %'add-wallet-from-entropy'
            =/  wallet-name=@t
              (~(dog jo:json-utils jon) /wallet-name so:dejs:format)
            ;<  eny=@uvJ  bind:m  get-entropy:io
            =/  seed-phrase=cord
              (gen-seed:seed-phrases eny %128)
            =/  xpub=@t  (seed-to-xpub:h [%t seed-phrase])
            ;<  sec=secrets  bind:m  load-secrets:h
            ;<  ~  bind:m  (save-secrets:h sec(seeds (~(put by seeds.sec) xpub [%t seed-phrase])))
            ;<  lbls=labels:b329  bind:m  load-labels:h
            =/  new-lbls=labels:b329
              (~(put la:b329 lbls) [%xpub xpub (rap 3 ~['gwbtc:wallet:' wallet-name]) ~ ~ ~])
            ;<  ~  bind:m  (save-labels:h new-lbls)
            $
              %'remove-wallet'
            =/  pubkey=@t
              (~(dog jo:json-utils jon) /pubkey so:dejs:format)
            ;<  sec=secrets  bind:m  load-secrets:h
            ;<  ~  bind:m  (save-secrets:h sec(seeds (~(del by seeds.sec) pubkey)))
            $
              %'add-account'
            =/  wallet-xpub=@t
              (~(dog jo:json-utils jon) /wallet-key so:dejs:format)
            ;<  sec=secrets  bind:m  load-secrets:h
            =/  sd=(unit seed)  (~(get by seeds.sec) wallet-xpub)
            ?~  sd
              ~&  >>>  [%wallet %add-account %wallet-not-found]
              $
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
            =/  =script-type  (purpose-to-script:h purpose)
            =/  network=network:wt
              ?:  =(1 coin-type)  %testnet3  %main
            =/  master  (from-seed:bip32 (seed-to-bytes:h u.sd))
            =/  pax=tape
              "m/{(scow %ud purpose)}'/{(scow %ud coin-type)}'/{(scow %ud account-idx)}'"
            =/  derived  (derive-path:master pax)
            =/  xprv=@t  (crip (prv-extended:derived (to-bip-network:wt network)))
            =/  acct-ref=@t  (crip (pub-extended:derived (to-bip-network:wt network)))
            =/  og=parsed-origin:b329
              [(to-descriptor:b329 script-type) fingerprint:master ~[[%.y purpose] [%.y coin-type] [%.y account-idx]]]
            ::  write account labels
            ;<  lbls=labels:b329  bind:m  load-labels:h
            ;<  ~  bind:m  (save-labels:h (make-acct-labels:aio lbls acct-ref account-name network og))
            $
              %'remove-account'
            =/  acct-ref=@t
              (~(dog jo:json-utils jon) /account-key so:dejs:format)
            ::  remove account labels + secrets entry if any
            ;<  lbls=labels:b329  bind:m  load-labels:h
            ;<  ~  bind:m  (save-labels:h (~(del-all la:b329 lbls) %xpub acct-ref))
            ;<  sec=secrets  bind:m  load-secrets:h
            ?:  (~(has by xprvs.sec) acct-ref)
              ;<  ~  bind:m  (save-secrets:h sec(xprvs (~(del by xprvs.sec) acct-ref)))
              $
            $
              %'add-watch-only'
            =/  account-name=@t
              (~(dog jo:json-utils jon) /account-name so:dejs:format)
            =/  xpub=@t
              (~(dog jo:json-utils jon) /xpub so:dejs:format)
            =/  xpub-tape=tape  (trip xpub)
            ?.  ?|  =((scag 4 xpub-tape) "xpub")
                    =((scag 4 xpub-tape) "tpub")
                ==
              ~&  >>>  [%wallet %add-watch-only %invalid-prefix]
              $
            =/  script-type-str=@t
              (~(dug jo:json-utils jon) /script-type so:dejs:format 'p2wpkh')
            =/  =script-type
              ?+  script-type-str  %p2wpkh
                %p2pkh        %p2pkh
                %p2sh-p2wpkh  %p2sh-p2wpkh
                %p2wpkh       %p2wpkh
                %p2tr         %p2tr
              ==
            =/  network-str=@t
              (~(dug jo:json-utils jon) /network so:dejs:format 'testnet3')
            =/  =network:wt
              ?+  network-str  %testnet3
                %main      %main
                %testnet3  %testnet3
                %testnet4  %testnet4
                %signet    %signet
                %regtest   %regtest
              ==
            ;<  lbls=labels:b329  bind:m  load-labels:h
            ;<  ~  bind:m
              (save-labels:h (make-standalone-labels:aio lbls xpub account-name network script-type))
            $
              %'add-signing'
            =/  account-name=@t
              (~(dog jo:json-utils jon) /account-name so:dejs:format)
            =/  xprv=@t
              (~(dog jo:json-utils jon) /xprv so:dejs:format)
            =/  xprv-tape=tape  (trip xprv)
            ?.  ?|  =((scag 4 xprv-tape) "xprv")
                    =((scag 4 xprv-tape) "tprv")
                ==
              ~&  >>>  [%wallet %add-signing %invalid-prefix]
              $
            =/  derived  (from-extended:bip32 xprv-tape)
            =/  script-type-str=@t
              (~(dug jo:json-utils jon) /script-type so:dejs:format 'p2wpkh')
            =/  =script-type
              ?+  script-type-str  %p2wpkh
                %p2pkh        %p2pkh
                %p2sh-p2wpkh  %p2sh-p2wpkh
                %p2wpkh       %p2wpkh
                %p2tr         %p2tr
              ==
            =/  network-str=@t
              (~(dug jo:json-utils jon) /network so:dejs:format 'testnet3')
            =/  =network:wt
              ?+  network-str  %testnet3
                %main      %main
                %testnet3  %testnet3
                %testnet4  %testnet4
                %signet    %signet
                %regtest   %regtest
              ==
            =/  acct-xpub=@t
              (crip (pub-extended:derived (to-bip-network:wt network)))
            ;<  lbls=labels:b329  bind:m  load-labels:h
            ;<  ~  bind:m
              (save-labels:h (make-standalone-labels:aio lbls acct-xpub account-name network script-type))
            ;<  sec=secrets  bind:m  load-secrets:h
            ;<  ~  bind:m  (save-secrets:h sec(xprvs (~(put by xprvs.sec) acct-xpub xprv)))
            $
              %'discover-accounts'
            =/  wallet-xpub=@t
              (~(dog jo:json-utils jon) /wallet-key so:dejs:format)
            =/  fp-key=@ta  (crip (hexn:http-utils fingerprint:(from-extended:bip32 (trip wallet-xpub))))
            =/  purpose-select=@t
              (~(dug jo:json-utils jon) /purpose-select so:dejs:format '84')
            =/  purpose=@ud
              ?:(=(purpose-select 'custom') (rash (~(dog jo:json-utils jon) /purpose-custom so:dejs:format) dem) (rash purpose-select dem))
            =/  coin-type-select=@t
              (~(dug jo:json-utils jon) /coin-type-select so:dejs:format '0')
            =/  coin-type=@ud
              ?:(=(coin-type-select 'custom') (rash (~(dog jo:json-utils jon) /coin-type-custom so:dejs:format) dem) (rash coin-type-select dem))
            =/  disc-json=json
              %-  pairs:enjs:format
              :~  ['type' s+'discover']
                  ['purpose' (numb:enjs:format purpose)]
                  ['coin-type' (numb:enjs:format coin-type)]
                  ['account-idx' (numb:enjs:format 0)]
                  ['fingerprint' s+fp-key]
                  ['wallet-xpub' s+wallet-xpub]
              ==
            ;<  reg=proc-registry  bind:m  load-registry:h
            =/  wal-procs=wallet-procs
              (fall (~(get by wallets.reg) wallet-xpub) *wallet-procs)
            ?:  ?=(^ discover.wal-procs)
              ~&  >  [%wallet %discover %already-running wallet-xpub]
              $
            ;<  eny=@uvJ  bind:m  get-entropy:io
            =/  disc-uuid=@ta  (short-id:h eny)
            =/  disc-rd=road:tarball  (nex-road:h [%& /proc (cat 3 disc-uuid '.json')])
            ;<  ~  bind:m  (make:io disc-rd |+[[[/ %json] disc-json] ~])
            =.  wallets.reg  (~(put by wallets.reg) wallet-xpub [discover=`disc-uuid])
            ;<  ~  bind:m  (save-registry:h reg)
            $
              %'address-request'
            ::  foreign ship asks us for a receive address
            =/  src=(unit @p)  (get-poke-src:io from)
            ?~  src
              ~&  >  [%wallet %address-request %no-remote-src]
              $
            =/  req-net=@t
              (~(dug jo:json-utils jon) /network so:dejs:format 'testnet3')
            ;<  lbls=labels:b329  bind:m  load-labels:h
            =/  sa=(unit @t)  (get-simple-account:h lbls req-net)
            ?~  sa
              ~&  >>>  [%wallet %address-request %no-simple-account]
              $
            =/  acct-ref=@t  u.sa
            ;<  wstore=secrets  bind:m  load-secrets:h
            =/  xprv=(unit @t)  (derive-xprv:aio lbls wstore acct-ref)
            ?~  xprv
              ~&  >>>  [%wallet %address-request %no-xprv]
              $
            =/  network=network:wt  (get-acct-network:aio lbls acct-ref)
            =/  stype=script-type  (get-acct-script-type:aio lbls acct-ref)
            =/  acct-og=(unit parsed-origin:b329)  (get-acct-origin:aio lbls acct-ref)
            =/  recv-addrs=(list [idx=@ud addr=@t])
              ?~  acct-og  ~
              recv:(read-account-addrs:aio lbls u.acct-og)
            =/  offer-idx=@ud
              (get-next-offer-index:aio recv-addrs lbls acct-ref)
            =/  addr=(unit @t)
              (derive-addr:aio u.xprv stype network 0 offer-idx)
            ?~  addr
              ~&  >>>  [%wallet %address-request %derivation-failed]
              $
            ~&  [%wallet %address-request %offering (scow %p u.src) u.addr offer-idx]
            =/  lbl=@t  (rap 3 ~['gwbtc:offered:to:' (scot %p u.src)])
            =/  acct-og=(unit parsed-origin:b329)  (get-acct-origin:aio lbls acct-ref)
            =/  new-lbls=labels:b329
              (label-derived-addr:aio lbls u.addr lbl acct-og 0 offer-idx acct-ref)
            =/  new-lbls=labels:b329
              (set-last-offered:aio new-lbls acct-ref offer-idx)
            ;<  ~  bind:m  (save-labels:h new-lbls)
            ::  poke back with address-offer
            =/  offer-jon=json
              %-  pairs:enjs:format
              :~  ['action' s+'address-offer']
                  ['address' s+u.addr]
                  ['network' s+req-net]
              ==
            =/  req=load:remo:nexus
              :_  [%poke [[/ %json] offer-jon]]
              [/remote-poke %& /apps/'wallet.wallet_app' %'main.sig']
            ;<  ~  bind:m
              (gall-poke:io [u.src %grubbery] grubbery-load+req)
            $
              %'address-offer'
            ::  foreign ship is giving us an address we requested
            =/  src=(unit @p)  (get-poke-src:io from)
            ?~  src
              ~&  >  [%wallet %address-offer %no-remote-src]
              $
            =/  addr=@t
              (~(dog jo:json-utils jon) /address so:dejs:format)
            =/  req-net=@t
              (~(dug jo:json-utils jon) /network so:dejs:format 'testnet3')
            ~&  [%wallet %address-offer %received (scow %p u.src) addr req-net]
            ;<  lbls=labels:b329  bind:m  load-labels:h
            ::  clear old simple:send:active labels
            =/  addr-list=(list [@t (set label-entry:b329)])
              ~(tap by addr.lbls)
            =/  cleaned=labels:b329
              |-
              ?~  addr-list  lbls
              =/  [ref=@t entries=(set label-entry:b329)]  i.addr-list
              =/  has-active=?
                %+  lien  ~(tap in entries)
                |=(e=label-entry:b329 =('simple:send:active' label.e))
              ?.  has-active  $(addr-list t.addr-list)
              %=  $
                addr-list  t.addr-list
                lbls  (~(del la:b329 lbls) %addr ref 'simple:send:active')
              ==
            ::  label with offered-from and send-active
            =/  lbl=@t  (rap 3 ~['gwbtc:offered:from:' (scot %p u.src)])
            =/  new-lbls=labels:b329
              (~(put la:b329 cleaned) [%addr addr lbl ~ ~ ~])
            =/  new-lbls=labels:b329
              (~(put la:b329 new-lbls) [%addr addr 'simple:send:active' ~ ~ ~])
            ;<  ~  bind:m  (save-labels:h new-lbls)
            ::  append to offer log
            =/  log-road=road:tarball
              [%& %& /apps/'wallet.wallet_app' %'offer-log.json']
            ;<  log-view=view:nexus  bind:m  (peek:io log-road ~)
            =/  cur-log=json
              ?.  ?=([%file *] log-view)  [%a ~]
              !<(json (need-vase:tarball sang.log-view))
            =/  entry=json
              %-  pairs:enjs:format
              :~  ['ship' s+(scot %p u.src)]
                  ['address' s+addr]
                  ['network' s+req-net]
              ==
            =/  new-log=json
              [%a (snoc ?>(?=(%a -.cur-log) p.cur-log) entry)]
            ;<  ~  bind:m  (over:io log-road [[/ %json] new-log])
            $
              %'tx-broadcast'
            ::  foreign ship notifies us they broadcast a tx to our address
            =/  src=(unit @p)  (get-poke-src:io from)
            ?~  src
              ~&  >  [%wallet %tx-broadcast %no-remote-src]
              $
            =/  addr=@t
              (~(dog jo:json-utils jon) /address so:dejs:format)
            =/  txid=@t
              (~(dog jo:json-utils jon) /txid so:dejs:format)
            ~&  [%wallet %tx-broadcast %from (scow %p u.src) addr txid]
            ;<  lbls=labels:b329  bind:m  load-labels:h
            ::  verify we actually own this address
            ?.  (~(has by addr.lbls) addr)
              ~&  >>>  [%wallet %tx-broadcast %unknown-address addr]
              $
            ;<  now=@da  bind:m  get-time:io
            =/  unix=@ud  (unt:chrono:userlib now)
            =/  lbl=@t
              (rap 3 ~['gwbtc:broadcast:' (scot %p u.src) ':' txid ':' (crip (a-co:co unix))])
            =/  new-lbls=labels:b329
              (~(put la:b329 lbls) [%addr addr lbl ~ ~ ~])
            ;<  ~  bind:m  (save-labels:h new-lbls)
            ::  auto-refresh the notified address
            =/  deriv=(unit [acct=@t chain=?(%recv %chng) idx=@ud])
              (get-addr-derivation:aio new-lbls addr)
            ?~  deriv
              ~&  >  [%wallet %tx-broadcast %no-derivation-info addr]
              $
            ;<  reg=proc-registry  bind:m  load-registry:h
            ;<  reg=proc-registry  bind:m
              (spawn-refreshes:h ~[addr] new-lbls acct.u.deriv reg)
            ;<  ~  bind:m  (save-registry:h reg)
            $
              %'refresh-account'
            ::  spawn refresh procs for all addresses in an account
            =/  acct-ref=@t
              (~(dog jo:json-utils jon) /account so:dejs:format)
            ;<  ra-lbls=labels:b329  bind:m  load-labels:h
            ?.  (has-account:aio ra-lbls acct-ref)
              ~&  >>>  [%wallet %refresh-account %not-found acct-ref]
              $
            =/  ra-og=(unit parsed-origin:b329)  (get-acct-origin:aio ra-lbls acct-ref)
            =/  [ra-recv=(list [idx=@ud addr=@t]) ra-chng=(list [idx=@ud addr=@t])]
              ?~  ra-og  [~ ~]
              (read-account-addrs:aio ra-lbls u.ra-og)
            =/  all-addrs=(list @t)
              (weld (turn ra-recv |=([* addr=@t] addr)) (turn ra-chng |=([* addr=@t] addr)))
            ;<  reg=proc-registry  bind:m  load-registry:h
            ;<  reg=proc-registry  bind:m
              (spawn-refreshes:h all-addrs ra-lbls acct-ref reg)
            ;<  ~  bind:m  (save-registry:h reg)
            $
          ::  account-specific actions (derive, scan, draft, etc)
          ::
              ?(%'derive-address' %'derive-next' %'delete-address' %'set-network' %'full-scan' %'pause-scan' %'resume-scan' %'cancel-scan' %'refresh' %'send' %'add-output' %'delete-output' %'clear-draft' %'set-change-config' %'clear-change-config' %'set-auto-select-mode' %'run-auto-select' %'add-input' %'remove-input' %'build-transaction' %'add-tapscript' %'delete-tapscript')
            =/  acct-ref=@t  (~(dog jo:json-utils jon) /account so:dejs:format)
            ;<  ~  bind:m  (handle-account-action:h jon acct-ref)
            $
          ==
        ==
          ::  /ui/http.sig: bind /groundwire/wallet/ and dispatch requests
          ::
          [[%ui ~] %'http.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%wallet /ui/http: failed")
        =/  prefix=path  /groundwire/wallet
        ;<  ~  bind:m  (bind-http:io [~ prefix])
        (http-dispatch:io %wallet)
          ::  /ui/requests/*: individual HTTP request handlers
          ::
          [[%ui %requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%wallet /ui/requests: failed")
        =/  eyre-id=@ta  name.rail
        ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
        ;<  our=@p  bind:m  get-our:io
        ?.  =(src our)
          ;<  ~  bind:m  (send-simple:srv:h eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
          (pure:m ~)
        ;<  here=rail:tarball  bind:m  get-here-abs:io
        =/  nexus-root=tape  (spud (snip (snip path.here)))
        =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
        =/  prefix=path  /groundwire/wallet
        =/  suffix=path
          %+  skip  (slag (lent prefix) site)
          |=(s=@ta =('' s))
        ::  route: / → wallet list page
        ?~  suffix
          ;<  sec=secrets  bind:m  load-secrets:h
          ;<  lbls=labels:b329  bind:m  load-labels:h
          =/  wals=(list wallet-data)  (secrets-to-wallets:h sec)
          ;<  ~  bind:m  (send-html:h eyre-id (wallet-page:h nexus-root wals lbls sec))
          (pure:m ~)
        ::  route: /simple → simple wallet page
        ?:  ?=([%simple ~] suffix)
          ?:  ?=(%'GET' method.request.req)
            ;<  lbls=labels:b329  bind:m  load-labels:h
            ;<  simple-wal=(unit wallet-data)  bind:m  (get-simple-wallet:h lbls)
            =/  post-url=tape  "{(spud prefix)}/simple"
            ?~  simple-wal
              ::  auto-create simple wallet with testnet3 + mainnet accounts
              ;<  eny=@uvJ  bind:m  get-entropy:io
              =/  seed-phrase=cord  (gen-seed:seed-phrases eny %256)
              =/  [wal-t=wallet-data mxpub=@t ref-t=@t xprv-t=@t net-t=network:wt st-t=script-type og-t=parsed-origin:b329]
                (make-dev-wallet:h 'My Wallet' [%t seed-phrase] %testnet3)
              =/  [* * ref-m=@t xprv-m=@t net-m=network:wt st-m=script-type og-m=parsed-origin:b329]
                (make-dev-wallet:h 'My Wallet' [%t seed-phrase] %main)
              =/  wal=wallet-data  wal-t
              ;<  sec=secrets  bind:m  load-secrets:h
              ;<  ~  bind:m  (save-secrets:h sec(seeds (~(put by seeds.sec) xpub.wal seed.wal)))
              ::  save labels
              =/  new-lbls=labels:b329  (set-simple-wallet:h lbls mxpub)
              =/  new-lbls=labels:b329
                (~(put la:b329 new-lbls) [%xpub mxpub 'gwbtc:wallet:My Wallet' ~ ~ ~])
              =/  new-lbls=labels:b329  (make-acct-labels:aio new-lbls ref-t 'Default' net-t og-t)
              =/  new-lbls=labels:b329  (make-acct-labels:aio new-lbls ref-m 'Default' net-m og-m)
              ;<  ~  bind:m  (save-labels:h new-lbls)
              ;<  ~  bind:m
                (send-html:h eyre-id (simple-page:simp ~ '' ~ ~ ~ *tx-map post-url %.n ~["testnet3" "main"] 2 ~ ~ ~))
              (pure:m ~)
            =/  wal=wallet-data  u.simple-wal
            =/  wal-name=@t  (get-wallet-name:aio lbls xpub.wal)
            =/  saved=?  (get-simple-saved:h lbls xpub.wal)
            =/  fp=@ux  fingerprint:(from-extended:bip32 (trip xpub.wal))
            =/  refs=(list @t)  (load-wallet-account-keys:h lbls fp)
            =/  nets=(list tape)  (wallet-nets:h lbls refs)
            =/  req-net=@t
              (fall (get-key:kv:html-utils 'net' args) 'testnet3')
            =/  acct-ref=(unit @t)
              (find-account-for-net:h lbls refs req-net)
            ?~  acct-ref
              ;<  ~  bind:m
                (send-html:h eyre-id (simple-page:simp `wal wal-name ~ ~ ~ *tx-map post-url saved nets 2 ~ ~ ~))
              (pure:m ~)
            =/  fee-rate=@ud  (get-simple-fee:h lbls u.acct-ref)
            =/  network=network:wt  (get-acct-network:aio lbls u.acct-ref)
            =/  stype=script-type  (get-acct-script-type:aio lbls u.acct-ref)
            =/  [recv=(list [@ud address-data]) chng=(list [@ud address-data])]
              (load-recv-chng:h lbls u.acct-ref)
            =/  txs=tx-map  (build-acct-tx-map:h lbls u.acct-ref)
            =/  last-offered=(unit @ud)
              (get-last-offered:aio lbls u.acct-ref)
            =/  last-change=(unit @ud)
              (get-last-change:aio lbls u.acct-ref)
            =/  recv-addrs=(list @t)  (turn recv |=([* ad=address-data] addr.ad))
            =/  chng-addrs=(list @t)  (turn chng |=([* ad=address-data] addr.ad))
            =/  tx-addrs=(list @t)
              %-  zing
              %+  turn  ~(val by txs)
              |=  tx=transaction
              ^-  (list @t)
              %+  weld
                (turn outputs.tx |=(o=tx-output address.o))
              (murn inputs.tx |=(i=tx-input ?~(prevout.i ~ `address.u.prevout.i)))
            =/  all-addrs=(list @t)
              :(weld recv-addrs chng-addrs tx-addrs)
            =/  ships=(map @t @t)
              =|  acc=(map @t @t)
              =/  addrs=(list @t)  all-addrs
              |-  ^-  (map @t @t)
              ?~  addrs  acc
              =/  s=(unit @t)  (addr-to-ship:aio lbls i.addrs)
              ?~  s  $(addrs t.addrs)
              $(addrs t.addrs, acc (~(put by acc) i.addrs u.s))
            =/  page=manx  (simple-page:simp `wal wal-name `(trip ;;(@t network)) recv chng txs post-url saved nets fee-rate last-offered last-change ships)
            ;<  ~  bind:m  (send-html:h eyre-id page)
            (pure:m ~)
          ::  POST /simple → simple wallet actions
          =/  args=key-value-list:kv:html-utils  (parse-body:kv:html-utils body.request.req)
          =/  action=@t  (fall (get-key:kv:html-utils 'action' args) '')
          ?+    action
              ;<  ~  bind:m  (send-simple:srv:h eyre-id [[400 ~] `(as-octs:mimes:html 'Unknown action')])
              (pure:m ~)
              %'get-receive-address'
            =/  req-net=@t
              (fall (get-key:kv:html-utils 'net' args) 'testnet3')
            ;<  lbls=labels:b329  bind:m  load-labels:h
            =/  sa=(unit @t)  (get-simple-account:h lbls req-net)
            ?~  sa
              ;<  ~  bind:m  (send-simple:srv:h eyre-id [[200 ~] `(as-octs:mimes:html '')])
              (pure:m ~)
            =/  acct-ref=@t  u.sa
            =/  network=network:wt  (get-acct-network:aio lbls acct-ref)
            ;<  wstore=secrets  bind:m  load-secrets:h
            =/  xprv=(unit @t)  (derive-xprv:aio lbls wstore acct-ref)
            ?~  xprv
              ;<  ~  bind:m  (send-simple:srv:h eyre-id [[400 ~] `(as-octs:mimes:html 'Cannot derive key')])
              (pure:m ~)
            =/  stype=script-type  (get-acct-script-type:aio lbls acct-ref)
            =/  recv=(list [@ud address-data])
              recv:(load-recv-chng:h lbls acct-ref)
            ::  find local candidate: first addr with no/zero tx-count
            =/  candidate-idx=@ud
              |-
              ?~  recv
                (lent recv)
              =/  [lidx=@ud dat=address-data]  i.recv
              ?~  info.dat  lidx
              ?:  =(0 tx-count.u.info.dat)  lidx
              $(recv t.recv)
            ::  verify against mempool, advance if used
            (verify-receive-addr:h u.xprv stype network recv candidate-idx eyre-id)
              %'toggle-saved'
            ;<  lbls=labels:b329  bind:m  load-labels:h
            =/  xpub=(unit @t)  (get-simple-xpub:h lbls)
            ?~  xpub
              ;<  ~  bind:m  (send-simple:srv:h eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
              (pure:m ~)
            =/  saved=?  (get-simple-saved:h lbls u.xpub)
            =/  new-lbls=labels:b329  (set-simple-saved:h lbls u.xpub !saved)
            ;<  ~  bind:m  (save-labels:h new-lbls)
            ;<  ~  bind:m  (send-simple:srv:h eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
            (pure:m ~)
              %'refresh-wallet'
            ::  refresh all pending + next-unused addresses
            =/  req-net=@t
              (fall (get-key:kv:html-utils 'net' args) 'testnet3')
            ;<  lbls=labels:b329  bind:m  load-labels:h
            =/  sa=(unit @t)  (get-simple-account:h lbls req-net)
            ?~  sa
              ;<  ~  bind:m  (send-simple:srv:h eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
              (pure:m ~)
            =/  acct-ref=@t  u.sa
            =/  network=network:wt  (get-acct-network:aio lbls acct-ref)
            =/  net=@ta  ;;(@ta network)
            =/  [recv=(list [@ud address-data]) chng=(list [@ud address-data])]
              (load-recv-chng:h lbls acct-ref)
            ::  collect addresses needing refresh:
            ::    - any address with pending activity (mempool, unconfirmed tx, broadcast)
            ::    - next unused recv + chng (for gap-limit discovery)
            ::
            =/  txs=tx-map  (build-acct-tx-map:h lbls acct-ref)
            ::  set of addresses involved in unconfirmed transactions
            =/  unconf-addrs=(set @t)
              =/  acc=(set @t)  ~
              =/  txns=(list [txid=@t tx=transaction])  ~(tap by txs)
              |-
              ?~  txns  acc
              ?.  ?=([%unconfirmed *] tx-status.tx.i.txns)  $(txns t.txns)
              =/  out=(list @t)  (turn outputs.tx.i.txns |=(o=tx-output address.o))
              =/  inp=(list @t)  (murn inputs.tx.i.txns |=(i=tx-input ?~(prevout.i ~ `address.u.prevout.i)))
              $(txns t.txns, acc (~(gas in acc) (weld out inp)))
            ::  +needs-refresh: does this address have any pending activity?
            =/  needs-refresh
              |=  dat=address-data
              ?|  ::  involved in an unconfirmed transaction
                  (~(has in unconf-addrs) addr.dat)
                  ::  mempool activity (funded or spent)
                  ?&  ?=(^ info.dat)
                      |((gth mem-funded.u.info.dat 0) (gth mem-spent.u.info.dat 0))
                  ==
                  ::  mempool tx count (catches edge cases above might miss)
                  ?&  ?=(^ info.dat)
                      (gth mem-tx-count.u.info.dat 0)
                  ==
                  ::  new broadcast notification since last check
                  (has-new-broadcast:aio lbls addr.dat)
              ==
            ::  scan recv + chng for addresses needing refresh
            =/  from-recv=(list [chain=?(%recv %chng) idx=@ud])
              %+  murn  recv
              |=  [idx=@ud dat=address-data]
              ^-  (unit [?(%recv %chng) @ud])
              ?.  (needs-refresh dat)  ~
              `[%recv idx]
            =/  from-chng=(list [chain=?(%recv %chng) idx=@ud])
              %+  murn  chng
              |=  [idx=@ud dat=address-data]
              ^-  (unit [?(%recv %chng) @ud])
              ?.  (needs-refresh dat)  ~
              `[%chng idx]
            ::  find next unused address on each chain (for discovery)
            =/  next-recv=@ud
              =/  r  recv
              |-
              ?~  r  (lent recv)
              =/  [lidx=@ud dat=address-data]  i.r
              ?:  ?|  ?=(~ info.dat)
                      =(0 (add tx-count.u.info.dat mem-tx-count.u.info.dat))
                  ==
                lidx
              $(r t.r)
            =/  next-chng=@ud
              =/  c  chng
              |-
              ?~  c  (lent chng)
              =/  [lidx=@ud dat=address-data]  i.c
              ?:  ?|  ?=(~ info.dat)
                      =(0 (add tx-count.u.info.dat mem-tx-count.u.info.dat))
                  ==
                lidx
              $(c t.c)
            ::  combine and deduplicate
            =/  all=(list [chain=?(%recv %chng) idx=@ud])
              ;:  weld
                from-recv
                from-chng
                `(list [?(%recv %chng) @ud])`~[[%recv next-recv]]
                `(list [?(%recv %chng) @ud])`~[[%chng next-chng]]
              ==
            =/  refresh-list=(list [chain=?(%recv %chng) idx=@ud])
              =/  seen=(set [?(%recv %chng) @ud])  ~
              =/  out=(list [chain=?(%recv %chng) idx=@ud])  ~
              |-
              ?~  all  (flop out)
              ?:  (~(has in seen) i.all)  $(all t.all)
              $(all t.all, seen (~(put in seen) i.all), out [i.all out])
            ::  spawn refresh proc files
            ;<  reg=proc-registry  bind:m  load-registry:h
            =/  acct-procs=account-procs
              (fall (~(get by accounts.reg) acct-ref) *account-procs)
            ;<  now=@da  bind:m  get-time:io
            |-
            ?~  refresh-list
              ;<  ~  bind:m  (save-registry:h reg)
              ;<  ~  bind:m  (send-simple:srv:h eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
              (pure:m ~)
            =/  [chain=?(%recv %chng) idx=@ud]  i.refresh-list
            =/  rkey=@ta  (refresh-key:h chain idx)
            ?:  (~(has by refresh.acct-procs) rkey)
              $(refresh-list t.refresh-list)
            ;<  eny=@uvJ  bind:m  get-entropy:io
            =/  uuid=@ta  (short-id:h eny)
            =/  proc-road=road:tarball  (nex-road:h [%& /proc (cat 3 uuid '.json')])
            =/  proc-json=json
              %-  pairs:enjs:format
              :~  ['type' s+'refresh']
                  ['account' s+acct-ref]
                  ['network' s+net]
                  ['chain' s+chain]
                  ['index' (numb:enjs:format idx)]
              ==
            ;<  ~  bind:m
              (make:io proc-road |+[[[/ %json] proc-json] ~])
            =.  refresh.acct-procs  (~(put by refresh.acct-procs) rkey uuid)
            =.  accounts.reg  (~(put by accounts.reg) acct-ref acct-procs)
            $(refresh-list t.refresh-list)
              %'refresh-address'
            ::  refresh a single address by chain + index
            =/  chain-raw=@t  (fall (get-key:kv:html-utils 'chain' args) 'recv')
            =/  idx-raw=@t    (fall (get-key:kv:html-utils 'index' args) '0')
            =/  chain=?(%recv %chng)
              ?:(?=(%recv ;;(?(%recv %chng) (slav %tas chain-raw))) %recv %chng)
            =/  idx=@ud  (fall (slaw %ud idx-raw) 0)
            =/  req-net=@t
              (fall (get-key:kv:html-utils 'net' args) 'testnet3')
            ;<  lbls=labels:b329  bind:m  load-labels:h
            =/  sa=(unit @t)  (get-simple-account:h lbls req-net)
            ?~  sa
              ;<  ~  bind:m  (send-simple:srv:h eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
              (pure:m ~)
            =/  acct-ref=@t  u.sa
            =/  network=network:wt  (get-acct-network:aio lbls acct-ref)
            =/  net=@ta  ;;(@ta network)
            =/  rkey=@ta  (refresh-key:h chain idx)
            ;<  reg=proc-registry  bind:m  load-registry:h
            =/  acct-procs=account-procs
              (fall (~(get by accounts.reg) acct-ref) *account-procs)
            ?:  (~(has by refresh.acct-procs) rkey)
              ;<  ~  bind:m  (send-simple:srv:h eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
              (pure:m ~)
            ;<  eny=@uvJ  bind:m  get-entropy:io
            =/  uuid=@ta  (short-id:h eny)
            =/  proc-road=road:tarball  (nex-road:h [%& /proc (cat 3 uuid '.json')])
            =/  proc-json=json
              %-  pairs:enjs:format
              :~  ['type' s+'refresh']
                  ['account' s+acct-ref]
                  ['network' s+net]
                  ['chain' s+chain]
                  ['index' (numb:enjs:format idx)]
              ==
            ;<  ~  bind:m
              (make:io proc-road |+[[[/ %json] proc-json] ~])
            =.  refresh.acct-procs  (~(put by refresh.acct-procs) rkey uuid)
            =.  accounts.reg  (~(put by accounts.reg) acct-ref acct-procs)
            ;<  ~  bind:m  (save-registry:h reg)
            ;<  ~  bind:m  (send-simple:srv:h eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
            (pure:m ~)
              %'send-bitcoin'
            ::  Build, sign, and broadcast a transaction
            =/  address=@t
              (fall (get-key:kv:html-utils 'address' args) '')
            =/  amount-raw=@t
              (fall (get-key:kv:html-utils 'amount' args) '0')
            =/  fee-rate-raw=@t
              (fall (get-key:kv:html-utils 'fee-rate' args) '2')
            =/  req-net=@t
              (fall (get-key:kv:html-utils 'net' args) 'testnet3')
            =/  amount=@ud  (fall (rush amount-raw dem) 0)
            =/  fee-rate=@ud  (fall (rush fee-rate-raw dem) 2)
            ?:  |(=('' address) =(0 amount))
              ;<  ~  bind:m
                (send-simple:srv:h eyre-id [[400 ~] `(as-octs:mimes:html 'Missing address or amount')])
              (pure:m ~)
            ;<  lbls=labels:b329  bind:m  load-labels:h
            =/  sa=(unit @t)  (get-simple-account:h lbls req-net)
            ?~  sa
              ;<  ~  bind:m
                (send-simple:srv:h eyre-id [[400 ~] `(as-octs:mimes:html 'No account for network')])
              (pure:m ~)
            =/  acct-ref=@t  u.sa
            =/  network=network:wt  (get-acct-network:aio lbls acct-ref)
            ;<  wstore=secrets  bind:m  load-secrets:h
            =/  xprv=(unit @t)  (derive-xprv:aio lbls wstore acct-ref)
            ?~  xprv
              ;<  ~  bind:m
                (send-simple:srv:h eyre-id [[400 ~] `(as-octs:mimes:html 'Cannot derive key')])
              (pure:m ~)
            =/  stype=script-type  (get-acct-script-type:aio lbls acct-ref)
            ::  derive next change address, label it, advance counter
            =/  chng=(list [@ud address-data])
              chng:(load-recv-chng:h lbls acct-ref)
            =/  chng-simple=(list [idx=@ud addr=@t])
              (turn chng |=([idx=@ud ad=address-data] [idx addr.ad]))
            =/  next-idx=@ud
              (get-next-change-index:aio chng-simple lbls acct-ref)
            =/  change-addr=@t
              %-  need
              (derive-addr:aio u.xprv stype network 1 next-idx)
            =/  acct-og=(unit parsed-origin:b329)  (get-acct-origin:aio lbls acct-ref)
            =/  lbls=labels:b329
              (label-derived-addr:aio lbls change-addr '' acct-og 1 next-idx acct-ref)
            =/  lbls=labels:b329
              (set-last-change:aio lbls acct-ref next-idx)
            ;<  ~  bind:m  (save-labels:h lbls)
            (simple-send:h acct-ref change-addr address amount fee-rate eyre-id)
              %'rename-wallet'
            =/  new-name=@t  (fall (get-key:kv:html-utils 'name' args) '')
            ?:  =('' new-name)
              ;<  ~  bind:m  (send-simple:srv:h eyre-id [[400 ~] `(as-octs:mimes:html 'Name required')])
              (pure:m ~)
            ;<  lbls=labels:b329  bind:m  load-labels:h
            =/  xpub=(unit @t)  (get-simple-xpub:h lbls)
            ?~  xpub
              ;<  ~  bind:m  (send-simple:srv:h eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
              (pure:m ~)
            =/  old-name=@t  (get-wallet-name:aio lbls u.xpub)
            =/  old-lbl=@t  (rap 3 ~['gwbtc:wallet:' old-name])
            =/  new-lbls=labels:b329  (~(del la:b329 lbls) %xpub u.xpub old-lbl)
            =/  new-lbls=labels:b329
              (~(put la:b329 new-lbls) [%xpub u.xpub (rap 3 ~['gwbtc:wallet:' new-name]) ~ ~ ~])
            ;<  ~  bind:m  (save-labels:h new-lbls)
            ;<  ~  bind:m  (send-simple:srv:h eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
            (pure:m ~)
              %'request-address'
            ::  Request a receive address from another ship
            =/  ship-name=@t
              (fall (get-key:kv:html-utils 'ship' args) '')
            =/  req-net=@t
              (fall (get-key:kv:html-utils 'net' args) 'testnet3')
            ?:  =('' ship-name)
              ;<  ~  bind:m
                (send-simple:srv:h eyre-id [[400 ~] `(as-octs:mimes:html 'Missing ship')])
              (pure:m ~)
            =/  target=(unit @p)  (slaw %p ship-name)
            ?~  target
              ;<  ~  bind:m
                (send-simple:srv:h eyre-id [[400 ~] `(as-octs:mimes:html 'Invalid ship')])
              (pure:m ~)
            ~&  [%wallet %request-address %asking (scow %p u.target) req-net]
            ::  clear old simple:send:active labels
            ;<  lbls=labels:b329  bind:m  load-labels:h
            =/  addr-list=(list [@t (set label-entry:b329)])
              ~(tap by addr.lbls)
            =/  cleaned=labels:b329
              |-
              ?~  addr-list  lbls
              =/  [ref=@t entries=(set label-entry:b329)]  i.addr-list
              =/  has-active=?
                %+  lien  ~(tap in entries)
                |=(e=label-entry:b329 =('simple:send:active' label.e))
              ?.  has-active  $(addr-list t.addr-list)
              %=  $
                addr-list  t.addr-list
                lbls  (~(del la:b329 lbls) %addr ref 'simple:send:active')
              ==
            ;<  ~  bind:m  (save-labels:h cleaned)
            ::  poke target ship with address-request
            =/  req-jon=json
              %-  pairs:enjs:format
              :~  ['action' s+'address-request']
                  ['network' s+req-net]
              ==
            =/  req=load:remo:nexus
              :_  [%poke [[/ %json] req-jon]]
              [/remote-poke %& /apps/'wallet.wallet_app' %'main.sig']
            ;<  ~  bind:m
              (gall-poke:io [u.target %grubbery] grubbery-load+req)
            ;<  ~  bind:m  (send-simple:srv:h eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
            (pure:m ~)
              %'offer-status'
            ::  Check if we have a send:active address (from an offer)
            ;<  lbls=labels:b329  bind:m  load-labels:h
            =/  addr-list=(list [@t (set label-entry:b329)])
              ~(tap by addr.lbls)
            =/  active=(unit @t)
              |-
              ?~  addr-list  ~
              =/  [ref=@t entries=(set label-entry:b329)]  i.addr-list
              =/  has-active=?
                %+  lien  ~(tap in entries)
                |=(e=label-entry:b329 =('simple:send:active' label.e))
              ?:  has-active  `ref
              $(addr-list t.addr-list)
            =/  body=@t
              %-  en:json:html
              ?~  active
                [%o (~(gas by *(map @t json)) ~[['status' s+'waiting']])]
              [%o (~(gas by *(map @t json)) ~[['status' s+'ready'] ['address' s+u.active]])]
            ;<  ~  bind:m
              (send-simple:srv:h eyre-id [[200 ~[['content-type' 'application/json']]] `(as-octs:mimes:html body)])
            (pure:m ~)
              %'set-fee-rate'
            =/  fee-raw=@t  (fall (get-key:kv:html-utils 'fee-rate' args) '2')
            =/  req-net=@t  (fall (get-key:kv:html-utils 'net' args) 'testnet3')
            =/  fee-val=@ud  (fall (rush fee-raw dem) 2)
            ;<  lbls=labels:b329  bind:m  load-labels:h
            =/  sa=(unit @t)  (get-simple-account:h lbls req-net)
            ?~  sa
              ;<  ~  bind:m  (send-simple:srv:h eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
              (pure:m ~)
            =/  acct-ref=@t  u.sa
            =/  new-lbls=labels:b329  (set-simple-fee:h lbls acct-ref fee-val)
            ;<  ~  bind:m  (save-labels:h new-lbls)
            ;<  ~  bind:m  (send-simple:srv:h eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
            (pure:m ~)
          ==
        ::  route: /w/<wallet-key>/ → wallet detail page
        ?:  ?&  ?=([%w @ *] suffix)
                =(~ t.t.suffix)
            ==
          =/  wallet-xpub=@t  i.t.suffix
          ::  POST → forward as poke to main.sig with wallet-key
          ?:  ?=(%'POST' method.request.req)
            =/  args=key-value-list:kv:html-utils  (parse-body:kv:html-utils body.request.req)
            =/  jon=json  (form-args-to-json:h args)
            =/  jon=json  [%o (~(put by ?>(?=(%o -.jon) p.jon)) 'wallet-key' s+wallet-xpub)]
            =/  main-road=road:tarball  (nex-road:h [%& ~ %'main.sig'])
            ;<  ~  bind:m  (poke:io main-road [[/ %json] jon])
            ;<  ~  bind:m  (send-simple:srv:h eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
            (pure:m ~)
          ::  GET → render wallet detail page
          ;<  sec=secrets  bind:m  load-secrets:h
          =/  sd=(unit seed)  (~(get by seeds.sec) wallet-xpub)
          ?~  sd
            ;<  ~  bind:m  (send-simple:srv:h eyre-id [[404 ~] `(as-octs:mimes:html 'Wallet not found')])
            (pure:m ~)
          =/  wal=wallet-data  [u.sd wallet-xpub]
          ;<  lbls=labels:b329  bind:m  load-labels:h
          =/  wal-name=@t  (get-wallet-name:aio lbls wallet-xpub)
          =/  fp=@ux  fingerprint:(from-extended:bip32 (trip wallet-xpub))
          =/  refs=(list @t)  (load-wallet-account-keys:h lbls fp)
          ;<  ~  bind:m  (send-html:h eyre-id (detail-page:det-ui wal wal-name lbls refs))
          (pure:m ~)
        ::  route: /a/<account-key>/ → account page
        ?:  ?&  ?=([%a @ *] suffix)
                =(~ t.t.suffix)
            ==
          =/  acct-key=@ta  (cat 3 i.t.suffix '.wallet_account')
          =/  acct-ref=@t  (acct-ref-from-key:h acct-key)
          ;<  lbls=labels:b329  bind:m  load-labels:h
          ?.  (has-account:aio lbls acct-ref)
            ;<  ~  bind:m  (send-simple:srv:h eyre-id [[404 ~] `(as-octs:mimes:html 'Account not found')])
            (pure:m ~)
          =/  network=network:wt  (get-acct-network:aio lbls acct-ref)
          =/  stype=script-type  (get-acct-script-type:aio lbls acct-ref)
          =/  og=(unit parsed-origin:b329)  (get-acct-origin:aio lbls acct-ref)
          =/  wallet-xpub=@t
            ?~  og  ''
            =/  fp=@ux  fingerprint.u.og
            (fall (fp-to-xpub:aio lbls fp) '')
          =/  acct-name=@t  (get-acct-name:aio lbls acct-ref)
          =/  [recv=(list [@ud address-data]) chng=(list [@ud address-data])]
            (load-recv-chng:h lbls acct-ref)
          ;<  now=@da  bind:m  get-time:io
          ;<  [scan=?(%active %paused %none) progress=(unit scan-progress:acct-ui)]  bind:m
            (load-scan-state:h acct-ref)
          =/  wal-name=@t  ?:(=('' wallet-xpub) '' (get-wallet-name:aio lbls wallet-xpub))
          ;<  sec=secrets  bind:m  load-secrets:h
          =/  can-sign=?  ?|(?=(^ og) (~(has by xprvs.sec) acct-ref))
          ;<  ~  bind:m  (send-html:h eyre-id (detail-page:acct-ui acct-name (trip acct-ref) wallet-xpub network stype recv chng now scan progress ~ wal-name can-sign))
          (pure:m ~)
        ::  route: /a/<account-key>/send → send page
        ?:  ?=([%a @ %send ~] suffix)
          =/  acct-key=@ta  (cat 3 i.t.suffix '.wallet_account')
          =/  acct-ref=@t  (acct-ref-from-key:h acct-key)
          ;<  lbls=labels:b329  bind:m  load-labels:h
          ?.  (has-account:aio lbls acct-ref)
            ;<  ~  bind:m  (send-simple:srv:h eyre-id [[404 ~] `(as-octs:mimes:html 'Account not found')])
            (pure:m ~)
          =/  network=network:wt  (get-acct-network:aio lbls acct-ref)
          =/  stype=script-type  (get-acct-script-type:aio lbls acct-ref)
          =/  og=(unit parsed-origin:b329)  (get-acct-origin:aio lbls acct-ref)
          =/  wallet-xpub=@t
            ?~  og  ''
            (fall (fp-to-xpub:aio lbls fingerprint.u.og) '')
          =/  acct-name=@t  (get-acct-name:aio lbls acct-ref)
          =/  [recv=(list [@ud address-data]) chng=(list [@ud address-data])]
            (load-recv-chng:h lbls acct-ref)
          ;<  now=@da  bind:m  get-time:io
          ;<  dr=(unit transaction:drft)  bind:m  (load-draft:h acct-ref)
          =/  wal-name=@t  ?:(=('' wallet-xpub) '' (get-wallet-name:aio lbls wallet-xpub))
          ;<  ~  bind:m  (send-html:h eyre-id (send-page:acct-ui acct-name (trip acct-ref) network stype recv chng dr now wal-name))
          (pure:m ~)
        ::  route: /a/<account-key>/send/stream → SSE for send page
        ?:  ?=([%a @ %send %stream ~] suffix)
          =/  acct-key=@ta  (cat 3 i.t.suffix '.wallet_account')
          (handle-send-stream:h eyre-id req acct-key)
        ::  route: /a/<account-key>/stream → SSE for live updates
        ?:  ?=([%a @ %stream ~] suffix)
          =/  acct-key=@ta  (cat 3 i.t.suffix '.wallet_account')
          (handle-account-stream:h eyre-id req acct-key)
        ::  route: /a/<account-key>/addr/<chain>/<idx>/stream → SSE for address
        ?:  ?=([%a @ %addr @ @ %stream ~] suffix)
          =/  acct-key=@ta  (cat 3 i.t.suffix '.wallet_account')
          =/  chain=@ta  i.t.t.t.suffix
          =/  idx-ta=@ta  i.t.t.t.t.suffix
          =/  chain-tag=?(%recv %chng)  ?:(?=(%recv chain) %recv %chng)
          =/  idx=@ud  (fall (slaw %ud idx-ta) 0)
          (handle-addr-stream:h eyre-id req acct-key chain-tag idx i.t.suffix)
        ::  route: /a/<account-key>/addr/<chain>/<idx> → address detail
        ?:  ?=([%a @ %addr @ @ ~] suffix)
          =/  acct-key=@ta  (cat 3 i.t.suffix '.wallet_account')
          =/  chain=@ta  i.t.t.t.suffix
          =/  idx-ta=@ta  i.t.t.t.t.suffix
          =/  acct-ref=@t  (acct-ref-from-key:h acct-key)
          ;<  lbls=labels:b329  bind:m  load-labels:h
          ?.  (has-account:aio lbls acct-ref)
            ;<  ~  bind:m  (send-simple:srv:h eyre-id [[404 ~] `(as-octs:mimes:html 'Account not found')])
            (pure:m ~)
          =/  network=network:wt  (get-acct-network:aio lbls acct-ref)
          =/  chain-tag=?(%recv %chng)  ?:(?=(%recv chain) %recv %chng)
          =/  idx=@ud  (fall (slaw %ud idx-ta) 0)
          =/  chain-list=(list [@ud address-data])
            ?:  ?=(%recv chain-tag)
              recv:(load-recv-chng:h lbls acct-ref)
            chng:(load-recv-chng:h lbls acct-ref)
          =/  dat=(unit address-data)
            |-
            ?~  chain-list  ~
            ?:  =(idx -.i.chain-list)  `+.i.chain-list
            $(chain-list t.chain-list)
          ?~  dat
            ;<  ~  bind:m  (send-simple:srv:h eyre-id [[404 ~] `(as-octs:mimes:html 'Address not found')])
            (pure:m ~)
          =/  akh=tape  (trip i.t.suffix)
          =/  txs=tx-map  (build-acct-tx-map:h lbls acct-ref)
          ;<  ~  bind:m  (send-html:h eyre-id (addr-detail-page:h nexus-root idx u.dat chain-tag network akh txs))
          (pure:m ~)
        ::  route: /a/<account-key>/tx/<txid> → transaction detail
        ?:  ?=([%a @ %tx @ ~] suffix)
          =/  acct-key=@ta  (cat 3 i.t.suffix '.wallet_account')
          =/  txid=@ta  i.t.t.t.suffix
          =/  acct-ref=@t  (acct-ref-from-key:h acct-key)
          ;<  lbls=labels:b329  bind:m  load-labels:h
          ?.  (has-account:aio lbls acct-ref)
            ;<  ~  bind:m  (send-simple:srv:h eyre-id [[404 ~] `(as-octs:mimes:html 'Account not found')])
            (pure:m ~)
          =/  network=network:wt  (get-acct-network:aio lbls acct-ref)
          =/  txs=tx-map  (build-acct-tx-map:h lbls acct-ref)
          =/  tx=(unit transaction)  (~(get by txs) txid)
          ?~  tx
            ;<  ~  bind:m  (send-simple:srv:h eyre-id [[404 ~] `(as-octs:mimes:html 'Transaction not found')])
            (pure:m ~)
          =/  [recv=(list [@ud address-data]) chng=(list [@ud address-data])]
            (load-recv-chng:h lbls acct-ref)
          =/  hit=(unit [idx=@ud chain=?(%recv %chng) address-data])
            (find-tx-addr:h u.tx recv chng)
          =/  akh=tape  (trip i.t.suffix)
          =/  [hit-idx=@ud hit-chain=?(%recv %chng) dat=address-data]
            (fall hit [0 %recv *address-data])
          ;<  ~  bind:m  (send-html:h eyre-id (tx-detail-page:h u.tx hit-idx hit-chain dat network akh txs))
          (pure:m ~)
        ::  unknown route
        ;<  ~  bind:m  (send-simple:srv:h eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
        (pure:m ~)
          ::
          ::  /proc/*: generic process handler — dispatches on type in state
          ::
          [[%proc ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%wallet /proc: failed")
        ;<  prev-state=vase  bind:m  get-state:io
        =/  prev=json  !<(json prev-state)
        =/  proc-type=@t
          (~(dug jo:json-utils prev) /type so:dejs:format '')
        ?+    proc-type
            ~&  >  [%wallet %proc %unknown-type proc-type]
            (pure:m ~)
            %'scan'
          (handle-scan-proc:h prev)
            %'refresh'
          (handle-refresh-proc:h prev)
            %'discover'
          (handle-discover-proc:h prev)
            %'send'
          (on-send-proc:h prev)
            %'paused'
          stay:m
        ==
      ==
    --
::  wallet helpers
::
|_  =rail:tarball
++  nex-road
  |=  =lane:tarball
  ^-  road:tarball
  (nex-road:io rail lane)
::  +get-or-gen-uuid: read optional uuid from json, generate if absent
::
++  get-or-gen-uuid
  |=  jon=(map @t json)
  =/  m  (fiber:fiber:nexus ,@ta)
  ^-  form:m
  =/  raw=@ta  (~(dug jo:json-utils [%o jon]) /uuid so:dejs:format '')
  ?.  =('' raw)  (pure:m raw)
  ;<  eny=@uvJ  bind:m  get-entropy:io
  (pure:m (short-id eny))
::  +spawn-refreshes: spawn refresh procs for a list of addresses
::
::  Looks up derivation info for each address, skips already-refreshing,
::  and creates proc files. Returns updated registry.
::
++  spawn-refreshes
  |=  $:  addrs=(list @t)
          =labels:b329
          acct-ref=@t
          reg=proc-registry
      ==
  =/  m  (fiber:fiber:nexus ,proc-registry)
  ^-  form:m
  ?~  addrs  (pure:m reg)
  =/  rest=(list @t)  t.addrs
  ;<  reg=proc-registry  bind:m
    (spawn-one-refresh i.addrs labels acct-ref reg)
  (spawn-refreshes rest labels acct-ref reg)
::
++  spawn-one-refresh
  |=  [addr=@t =labels:b329 acct-ref=@t reg=proc-registry]
  =/  m  (fiber:fiber:nexus ,proc-registry)
  ^-  form:m
  =/  deriv=(unit [acct=@t chain=?(%recv %chng) idx=@ud])
    (get-addr-derivation:aio labels addr)
  ?~  deriv
    ~&  >>>  [%spawn-refresh %no-derivation addr]
    (pure:m reg)
  =/  network=network:wt  (get-acct-network:aio labels acct-ref)
  =/  net=@ta  ;;(@ta network)
  =/  acct-procs=account-procs
    (fall (~(get by accounts.reg) acct-ref) *account-procs)
  =/  rkey=@ta  (refresh-key chain.u.deriv idx.u.deriv)
  ?:  (~(has by refresh.acct-procs) rkey)
    (pure:m reg)
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  uuid=@ta  (short-id eny)
  =/  proc-road=road:tarball  (nex-road [%& /proc (cat 3 uuid '.json')])
  =/  proc-json=json
    %-  pairs:enjs:format
    :~  ['type' s+'refresh']
        ['account' s+acct-ref]
        ['network' s+net]
        ['chain' s+chain.u.deriv]
        ['index' (numb:enjs:format idx.u.deriv)]
    ==
  ;<  ~  bind:m
    (make:io proc-road |+[[[/ %json] proc-json] ~])
  =.  refresh.acct-procs  (~(put by refresh.acct-procs) rkey uuid)
  =.  accounts.reg  (~(put by accounts.reg) acct-ref acct-procs)
  ~&  [%wallet %spawn-refresh addr chain.u.deriv idx.u.deriv]
  (pure:m reg)
::
::  +handle-scan-proc: scan chain process handler
::
++  handle-scan-proc
  |=  prev=json
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  status=@t  (~(dug jo:json-utils prev) /status so:dejs:format '')
  ?:  =('done' status)  (pure:m ~)
  =/  acct-ref=@t
    (~(dog jo:json-utils prev) /account so:dejs:format)
  ;<  lbls=labels:b329  bind:m  load-labels
  ?.  (has-account:aio lbls acct-ref)  (pure:m ~)
  =/  network=network:wt  (get-acct-network:aio lbls acct-ref)
  =/  progress=scan-progress:aio  (parse-scan-progress:aio prev)
  =/  main-road=road:tarball  (nex-road [%& ~ %'main.sig'])
  ::  scan recv chain (skip if already past it)
  ;<  ~  bind:m
    ?:  ?=(%chng phase.progress)  (pure:m ~)
    %:  scan-chain:aio
      acct-ref
      %receiving  network
      idx.progress
      gap.progress
      main-road
    ==
  ::  scan chng chain
  ;<  ~  bind:m
    %:  scan-chain:aio
      acct-ref
      %change  network
      ?:(?=(%chng phase.progress) idx.progress 0)
      ?:(?=(%chng phase.progress) gap.progress 0)
      main-road
    ==
  ::  clear registry entry
  ;<  reg=proc-registry  bind:m  load-registry
  =/  acct-procs=account-procs
    (fall (~(get by accounts.reg) acct-ref) *account-procs)
  =/  cleared=account-procs  [~ refresh.acct-procs]
  =.  accounts.reg  (~(put by accounts.reg) acct-ref cleared)
  ;<  ~  bind:m  (save-registry reg)
  ::  mark proc as done — triggers news for subscribers
  ;<  cur=json  bind:m  (get-state-as:io json)
  =/  updated=json
    ?.  ?=(%o -.cur)  cur
    [%o (~(put by p.cur) 'status' s+'done')]
  ;<  ~  bind:m  (replace:io updated)
  ;<  ~  bind:m  (sleep:io ~m5)
  (pure:m ~)
::  +handle-refresh-proc: single address refresh process handler
::
++  handle-refresh-proc
  |=  prev=json
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  status=@t  (~(dug jo:json-utils prev) /status so:dejs:format '')
  ?:  =('done' status)  (pure:m ~)
  =/  acct-ref=@t
    (~(dog jo:json-utils prev) /account so:dejs:format)
  =/  net-raw=@t
    (fall (mole |.((so:dejs:format (~(got jo:json-utils prev) /'network')))) 'main')
  =/  network=?(%main %testnet3 %testnet4 %signet %regtest)
    ;;(?(%main %testnet3 %testnet4 %signet %regtest) (slav %tas net-raw))
  =/  chain-tag=?(%recv %chng)
    =/  ch=@t  (fall (mole |.((so:dejs:format (~(got jo:json-utils prev) /'chain')))) 'recv')
    ?:(?=(%recv ;;(?(%recv %chng) (slav %tas ch))) %recv %chng)
  =/  idx=@ud
    (fall (mole |.((ni:dejs:format (~(got jo:json-utils prev) /'index')))) 0)
  ::  read current address data from labels
  ;<  lbls=labels:b329  bind:m  load-labels
  =/  rc  (load-recv-chng lbls acct-ref)
  =/  chain-list=(list [@ud address-data])
    ?:(?=(%recv chain-tag) recv.rc chng.rc)
  =/  dat=(unit address-data)
    |-
    ?~  chain-list  ~
    ?:  =(idx -.i.chain-list)  `+.i.chain-list
    $(chain-list t.chain-list)
  ?~  dat
    ~&  ["%refresh proc missing addr" acct-ref network chain-tag idx]
    ::  clear registry on early exit
    =/  rkey=@ta  (refresh-key chain-tag idx)
    ;<  reg=proc-registry  bind:m  load-registry
    =/  acct-procs=account-procs
      (fall (~(get by accounts.reg) acct-ref) *account-procs)
    =.  refresh.acct-procs  (~(del by refresh.acct-procs) rkey)
    =.  accounts.reg  (~(put by accounts.reg) acct-ref acct-procs)
    (save-registry reg)
  ;<  [new-info=(unit address-info) utxos=(list utxo) txs=(list transaction)]  bind:m
    (fetch-address-data:aio addr.u.dat network)
  ;<  lbls=labels:b329  bind:m  load-labels
  =/  lbls=labels:b329
    ?~  new-info  lbls
    (label-addr-info:aio lbls addr.u.dat u.new-info)
  =/  lbls=labels:b329  (label-utxos:aio lbls addr.u.dat utxos)
  =/  lbls=labels:b329  (label-txs:aio lbls txs)
  ;<  ~  bind:m  (save-labels lbls)
  ::  clear registry entry
  =/  rkey=@ta  (refresh-key chain-tag idx)
  ;<  reg=proc-registry  bind:m  load-registry
  =/  acct-procs=account-procs
    (fall (~(get by accounts.reg) acct-ref) *account-procs)
  =.  refresh.acct-procs  (~(del by refresh.acct-procs) rkey)
  =.  accounts.reg  (~(put by accounts.reg) acct-ref acct-procs)
  ;<  ~  bind:m  (save-registry reg)
  ::  mark proc as done — triggers news for subscribers
  ;<  cur=json  bind:m  (get-state-as:io json)
  =/  updated=json
    ?.  ?=(%o -.cur)  cur
    [%o (~(put by p.cur) 'status' s+'done')]
  ;<  ~  bind:m  (replace:io updated)
  ;<  ~  bind:m  (sleep:io ~m5)
  (pure:m ~)
::  +do-send: shared send logic — draft, broadcast, refresh
::  returns %.y on success, %.n on failure
::
++  do-send
  |=  [acct-ref=@t dest-addr=@t change-addr=@t amount=@ud fee-rate=@ud]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ::  1. clear-draft
  ;<  ~  bind:m
    (handle-account-action (pairs:enjs:format ~[['action' s+'clear-draft']]) acct-ref)
  ::  2. add-output
  ;<  ~  bind:m
    %:  handle-account-action
      %-  pairs:enjs:format
      :~  ['action' s+'add-output']
          ['address' s+dest-addr]
          ['amount' (numb:enjs:format amount)]
      ==
      acct-ref
    ==
  ::  3. set-change-config
  ;<  ~  bind:m
    %:  handle-account-action
      %-  pairs:enjs:format
      :~  ['action' s+'set-change-config']
          ['fee-rate' (numb:enjs:format fee-rate)]
          ['change-address' s+change-addr]
      ==
      acct-ref
    ==
  ::  4. run-auto-select
  ;<  ~  bind:m
    (handle-account-action (pairs:enjs:format ~[['action' s+'run-auto-select']]) acct-ref)
  ::  5. check if inputs were selected
  ;<  existing=(unit transaction:drft)  bind:m  (load-draft acct-ref)
  ?:  |(?=(~ existing) =(~ inputs.u.existing))
    (pure:m %.n)
  ::  6. collect input addresses before broadcast clears the draft
  ;<  lbls=labels:b329  bind:m  load-labels
  =/  input-addrs=(list @t)
    %+  murn  inputs.u.existing
    |=  inp=utxo-input:drft
    ^-  (unit @t)
    =/  ref=@t  (rap 3 ~[txid.inp ':' (num:aio vout.inp)])
    (~(read-kv la:b329 lbls) %output ref 'gwbtc:addr:')
  ::  7. build-transaction (signs, broadcasts, clears draft)
  ;<  ~  bind:m
    (handle-account-action (pairs:enjs:format ~[['action' s+'build-transaction']]) acct-ref)
  ::  8. check if draft was cleared (= success) or still exists (= failure)
  ;<  post-draft=(unit transaction:drft)  bind:m  (load-draft acct-ref)
  ?^  post-draft  (pure:m %.n)
  ::  9. refresh our own addresses (inputs + change)
  =/  own-addrs=(list @t)  (weld input-addrs ~[change-addr])
  ;<  lbls=labels:b329  bind:m  load-labels
  ;<  reg=proc-registry  bind:m  load-registry
  ;<  reg=proc-registry  bind:m
    (spawn-refreshes own-addrs lbls acct-ref reg)
  ;<  ~  bind:m  (save-registry reg)
  (pure:m %.y)
::  +on-send-proc: build, sign, broadcast a transaction
::
++  on-send-proc
  |=  prev=json
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  status=@t  (~(dug jo:json-utils prev) /status so:dejs:format '')
  ?:  =('done' status)  (pure:m ~)
  ?:  =('error' status)  (pure:m ~)
  =/  acct-ref=@t
    (~(dog jo:json-utils prev) /account so:dejs:format)
  =/  dest-addr=@t
    (~(dog jo:json-utils prev) /address so:dejs:format)
  =/  amount=@ud
    (~(dog jo:json-utils prev) /amount ni:dejs:format)
  =/  fee-rate=@ud
    (~(dug jo:json-utils prev) /fee-rate ni:dejs:format 2)
  =/  change-addr=@t
    (~(dog jo:json-utils prev) /change-address so:dejs:format)
  ;<  ok=?  bind:m  (do-send acct-ref dest-addr change-addr amount fee-rate)
  ;<  cur=json  bind:m  (get-state-as:io json)
  =/  updated=json
    ?.  ?=(%o -.cur)  cur
    ?.  ok
      [%o (~(put by (~(put by p.cur) 'status' s+'error')) 'error' s+'Send failed')]
    [%o (~(put by p.cur) 'status' s+'done')]
  ;<  ~  bind:m  (replace:io updated)
  ;<  ~  bind:m  (sleep:io ~m5)
  (pure:m ~)
::  +handle-discover-proc: account discovery process
::
++  handle-discover-proc
  |=  prev=json
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  status=@t  (~(dug jo:json-utils prev) /status so:dejs:format '')
  ?:  =('done' status)  (pure:m ~)
  =/  fp-key=@t
    (~(dog jo:json-utils prev) /fingerprint so:dejs:format)
  =/  fp=@ux  (slav %ux fp-key)
  =/  wxpub=@t
    (~(dog jo:json-utils prev) /wallet-xpub so:dejs:format)
  ;<  sec=secrets  bind:m  load-secrets
  =/  sd=(unit seed)  (~(get by seeds.sec) wxpub)
  ?~  sd  (pure:m ~)
  =/  wal=wallet-data  [u.sd wxpub]
  =/  purpose=@ud
    (fall (mole |.((ni:dejs:format (~(got jo:json-utils prev) /'purpose')))) 84)
  =/  coin-type=@ud
    (fall (mole |.((ni:dejs:format (~(got jo:json-utils prev) /'coin-type')))) 0)
  =/  start-idx=@ud
    (fall (mole |.((ni:dejs:format (~(got jo:json-utils prev) /'account-idx')))) 0)
  =/  =script-type  (purpose-to-script purpose)
  =/  network=?(%main %testnet3 %testnet4 %signet %regtest)
    ?:(=(1 coin-type) %testnet3 %main)
  =/  account-idx=@ud  start-idx
  |-
  ::  update progress in proc state
  =/  prog=json
    %-  pairs:enjs:format
    :~  ['type' s+'discover']
        ['purpose' (numb:enjs:format purpose)]
        ['coin-type' (numb:enjs:format coin-type)]
        ['account-idx' (numb:enjs:format account-idx)]
        ['fingerprint' s+fp-key]
        ['wallet-xpub' s+wxpub]
    ==
  ;<  ~  bind:m  (replace:io prog)
  ::  derive xprv for this account index
  =/  master  (from-seed:bip32 (seed-to-bytes seed.wal))
  =/  pax=tape
    "m/{(scow %ud purpose)}'/{(scow %ud coin-type)}'/{(scow %ud account-idx)}'"
  =/  derived  (derive-path:master pax)
  =/  xprv=@t  (crip (prv-extended:derived (to-bip-network:wt network)))
  ::  check recv + change chains for any activity
  ;<  recv-active=?  bind:m
    (discover-check-chain xprv script-type network 0)
  ;<  chng-active=?  bind:m
    (discover-check-chain xprv script-type network 1)
  ::  no activity = discovery complete
  ?.  |(recv-active chng-active)
    ::  clear registry entry
    ;<  reg=proc-registry  bind:m  load-registry
    =/  wal-procs=wallet-procs
      (fall (~(get by wallets.reg) wxpub) *wallet-procs)
    =.  discover.wal-procs  ~
    =.  wallets.reg  (~(put by wallets.reg) wxpub wal-procs)
    ;<  ~  bind:m  (save-registry reg)
    =/  done-prog=json
      %-  pairs:enjs:format
      :~  ['type' s+'discover']
          ['status' s+'done']
          ['fingerprint' s+fp-key]
      ==
    ;<  ~  bind:m  (replace:io done-prog)
    ;<  ~  bind:m  (sleep:io ~m5)
    (pure:m ~)
  ::  account has activity — create it
  =/  acct-name=@t  (crip "Account {(scow %ud account-idx)}")
  =/  acct-ref=@t  (crip (pub-extended:derived (to-bip-network:wt network)))
  =/  og=parsed-origin:b329
    [(to-descriptor:b329 script-type) fingerprint:(from-extended:bip32 (trip xpub.wal)) ~[[%.y purpose] [%.y coin-type] [%.y account-idx]]]
  ::  write labels
  ;<  cur-lbls=labels:b329  bind:m  load-labels
  =/  new-lbls=labels:b329  (make-acct-labels:aio cur-lbls acct-ref acct-name network og)
  ;<  ~  bind:m  (save-labels new-lbls)
  ::  kick off full scan on the new account
  ;<  scan-eny=@uvJ  bind:m  get-entropy:io
  =/  scan-uuid=@ta  (short-id scan-eny)
  =/  scan-json=json
    %-  pairs:enjs:format
    :~  ['type' s+'scan']
        ['account' s+acct-ref]
        ['phase' s+'recv']
        ['idx' (numb:enjs:format 0)]
        ['gap' (numb:enjs:format 0)]
    ==
  =/  scan-rd=road:tarball  (nex-road [%& /proc (cat 3 scan-uuid '.json')])
  ;<  ~  bind:m  (make:io scan-rd |+[[[/ %json] scan-json] ~])
  ::  register scan proc
  ;<  reg=proc-registry  bind:m  load-registry
  =/  acct-procs=account-procs
    (fall (~(get by accounts.reg) acct-ref) *account-procs)
  =.  scan.acct-procs  `scan-uuid
  =.  accounts.reg  (~(put by accounts.reg) acct-ref acct-procs)
  ;<  ~  bind:m  (save-registry reg)
  $(account-idx +(account-idx))
::  +handle-account-action: dispatch account-specific actions
::
++  handle-account-action
  |=  [jon=json acct-ref=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=([%o *] jon)  (pure:m ~)
  =/  act=@t  (~(dug jo:json-utils jon) /action so:dejs:format '')
  ;<  lbls=labels:b329  bind:m  load-labels
  ;<  wstore=secrets  bind:m  load-secrets
  =/  xprv=(unit @t)  (derive-xprv:aio lbls wstore acct-ref)
  =/  dkey=(unit @t)  (derive-key:aio lbls wstore acct-ref)
  =/  network=network:wt  (get-acct-network:aio lbls acct-ref)
  =/  stype=script-type  (get-acct-script-type:aio lbls acct-ref)
  ?+    act  (pure:m ~)
      %'derive-address'
    ?~  dkey  (pure:m ~)
    =/  chain=@t
      (~(dug jo:json-utils jon) /chain so:dejs:format 'receiving')
    =/  is-change=?  =(chain 'change')
    =/  chain-tag=?(%recv %chng)  ?:(is-change %chng %recv)
    =/  idx=@ud
      (~(dug jo:json-utils jon) /index ni:dejs:format 0)
    =/  new-addr=(unit @t)
      (derive-addr:aio u.dkey stype network ?:(is-change 1 0) idx)
    ?~  new-addr
      ~&  >>>  "%derive-address: derive-addr returned ~"
      (pure:m ~)
    ::  label + write
    =/  acct-og=(unit parsed-origin:b329)  (get-acct-origin:aio lbls acct-ref)
    =/  lbl=@t  (~(dug jo:json-utils jon) /label so:dejs:format '')
    =/  new-lbls=labels:b329
      (label-derived-addr:aio lbls u.new-addr lbl acct-og ?:(is-change 1 0) idx acct-ref)
    ;<  ~  bind:m  (save-labels new-lbls)
    (pure:m ~)
  ::
      %'derive-next'
    =/  chain=@t
      (~(dug jo:json-utils jon) /chain so:dejs:format 'receiving')
    =/  is-change=?  =(chain 'change')
    =/  chain-tag=?(%recv %chng)  ?:(is-change %chng %recv)
    =/  rc  (load-recv-chng lbls acct-ref)
    =/  chain-list=(list [@ud address-data])
      ?:(?=(%recv chain-tag) recv.rc chng.rc)
    =/  next-idx=@ud
      ?~  chain-list  0
      +(-:(rear chain-list))
    =/  derive-jon=json
      %-  pairs:enjs:format
      :~  ['action' s+'derive-address']
          ['account' s+acct-ref]
          ['chain' s+chain]
          ['index' (numb:enjs:format next-idx)]
      ==
    ;<  ~  bind:m  (handle-account-action derive-jon acct-ref)
    ::  auto-refresh the newly derived address
    =/  net=@ta  ;;(@ta network)
    =/  rkey=@ta  (refresh-key chain-tag next-idx)
    ;<  reg=proc-registry  bind:m  load-registry
    =/  acct-procs=account-procs
      (fall (~(get by accounts.reg) acct-ref) *account-procs)
    ?:  (~(has by refresh.acct-procs) rkey)
      (pure:m ~)
    ;<  eny=@uvJ  bind:m  get-entropy:io
    =/  uuid=@ta  (short-id eny)
    =/  proc-json=json
      %-  pairs:enjs:format
      :~  ['type' s+'refresh']
          ['account' s+acct-ref]
          ['network' s+net]
          ['chain' s+chain-tag]
          ['index' (numb:enjs:format next-idx)]
      ==
    =/  proc-rd=road:tarball  (nex-road [%& /proc (cat 3 uuid '.json')])
    ;<  ~  bind:m  (make:io proc-rd |+[[[/ %json] proc-json] ~])
    =.  refresh.acct-procs  (~(put by refresh.acct-procs) rkey uuid)
    =.  accounts.reg  (~(put by accounts.reg) acct-ref acct-procs)
    (save-registry reg)
  ::
      %'delete-address'
    =/  chain=@t
      (~(dug jo:json-utils jon) /chain so:dejs:format 'recv')
    =/  idx=@ud
      (~(dug jo:json-utils jon) /index ni:dejs:format 0)
    =/  chain-tag=?(%recv %chng)
      ?:(?=(%recv ;;(?(%recv %chng) (slav %tas chain))) %recv %chng)
    ::  find the address at this index and delete its labels
    =/  rc  (load-recv-chng lbls acct-ref)
    =/  chain-list=(list [@ud address-data])
      ?:(?=(%recv chain-tag) recv.rc chng.rc)
    =/  addr=(unit @t)
      |-
      ?~  chain-list  ~
      ?:  =(idx -.i.chain-list)  `addr.+.i.chain-list
      $(chain-list t.chain-list)
    ?~  addr  (pure:m ~)
    =/  new-lbls=labels:b329  (~(del-all la:b329 lbls) %addr u.addr)
    (save-labels new-lbls)
  ::
      %'set-network'
    =/  net=@t
      (~(dug jo:json-utils jon) /network so:dejs:format '')
    =/  new-network=?(%main %testnet3 %testnet4 %signet %regtest)
      ;;(?(%main %testnet3 %testnet4 %signet %regtest) (slav %tas net))
    ::  update network label
    ;<  cur-lbls=labels:b329  bind:m  load-labels
    =/  old-net-lbl=@t  (rap 3 ~['gwbtc:network:' ;;(@t network)])
    =/  new-net-lbl=@t  (rap 3 ~['gwbtc:network:' ;;(@t new-network)])
    =/  new-lbls=labels:b329  (~(del la:b329 cur-lbls) %xpub acct-ref old-net-lbl)
    =/  new-lbls=labels:b329  (~(put la:b329 new-lbls) [%xpub acct-ref new-net-lbl ~ ~ ~])
    (save-labels new-lbls)
  ::
      %'full-scan'
    ;<  reg=proc-registry  bind:m  load-registry
    =/  acct-procs=account-procs
      (fall (~(get by accounts.reg) acct-ref) *account-procs)
    ?:  ?=(^ scan.acct-procs)
      ~&  >  [%wallet %scan %already-running acct-ref]
      (pure:m ~)
    ;<  uuid=@ta  bind:m  (get-or-gen-uuid p.jon)
    =/  proc-json=json
      %-  pairs:enjs:format
      :~  ['type' s+'scan']
          ['account' s+acct-ref]
          ['phase' s+'recv']
          ['idx' (numb:enjs:format 0)]
          ['gap' (numb:enjs:format 0)]
      ==
    =/  fs-rd=road:tarball  (nex-road [%& /proc (cat 3 uuid '.json')])
    ;<  ~  bind:m  (make:io fs-rd |+[[[/ %json] proc-json] ~])
    =/  new-procs=account-procs  [`uuid refresh.acct-procs]
    =.  accounts.reg  (~(put by accounts.reg) acct-ref new-procs)
    (save-registry reg)
  ::
      %'pause-scan'
    ;<  reg=proc-registry  bind:m  load-registry
    =/  acct-procs=account-procs
      (fall (~(get by accounts.reg) acct-ref) *account-procs)
    ?~  scan.acct-procs  (pure:m ~)
    =/  scan-road=road:tarball  (nex-road [%& /proc (cat 3 u.scan.acct-procs '.json')])
    =/  pause-json=json
      (pairs:enjs:format ~[['action' s+'pause']])
    (poke:io scan-road [[/ %json] pause-json])
  ::
      %'resume-scan'
    ;<  reg=proc-registry  bind:m  load-registry
    =/  acct-procs=account-procs
      (fall (~(get by accounts.reg) acct-ref) *account-procs)
    ?~  scan.acct-procs  (pure:m ~)
    =/  scan-road=road:tarball  (nex-road [%& /proc (cat 3 u.scan.acct-procs '.json')])
    =/  resume-json=json
      (pairs:enjs:format ~[['action' s+'resume']])
    (poke:io scan-road [[/ %json] resume-json])
  ::
      %'cancel-scan'
    ;<  reg=proc-registry  bind:m  load-registry
    =/  acct-procs=account-procs
      (fall (~(get by accounts.reg) acct-ref) *account-procs)
    ?~  scan.acct-procs
      (pure:m ~)
    =/  cs-rd=road:tarball  (nex-road [%& /proc (cat 3 u.scan.acct-procs '.json')])
    ;<  *  bind:m  (cull-soft:io cs-rd)
    =/  new-procs=account-procs  [~ refresh.acct-procs]
    =.  accounts.reg  (~(put by accounts.reg) acct-ref new-procs)
    (save-registry reg)
  ::
      %'refresh'
    =/  chain=@t
      (~(dug jo:json-utils jon) /chain so:dejs:format 'recv')
    =/  idx=@ud
      (~(dug jo:json-utils jon) /index ni:dejs:format 0)
    =/  chain-tag=?(%recv %chng)
      ?:(?=(%recv ;;(?(%recv %chng) (slav %tas chain))) %recv %chng)
    =/  net=@ta  ;;(@ta network)
    =/  rkey=@ta  (refresh-key chain-tag idx)
    ;<  reg=proc-registry  bind:m  load-registry
    =/  acct-procs=account-procs
      (fall (~(get by accounts.reg) acct-ref) *account-procs)
    ?:  (~(has by refresh.acct-procs) rkey)
      (pure:m ~)
    ;<  uuid=@ta  bind:m  (get-or-gen-uuid p.jon)
    =/  proc-json=json
      %-  pairs:enjs:format
      :~  ['type' s+'refresh']
          ['account' s+acct-ref]
          ['network' s+net]
          ['chain' s+chain-tag]
          ['index' (numb:enjs:format idx)]
      ==
    =/  proc-rd=road:tarball  (nex-road [%& /proc (cat 3 uuid '.json')])
    ;<  make-err=(unit tang)  bind:m  (make-soft:io proc-rd |+[[[/ %json] proc-json] ~])
    ?^  make-err
      ~&  ["%account refresh make failed" acct-ref uuid u.make-err]
      (pure:m ~)
    =.  refresh.acct-procs  (~(put by refresh.acct-procs) rkey uuid)
    =.  accounts.reg  (~(put by accounts.reg) acct-ref acct-procs)
    (save-registry reg)
  ::
      %'send'
    =/  dest-addr=@t  (~(dog jo:json-utils jon) /address so:dejs:format)
    =/  amount=@ud  (~(dog jo:json-utils jon) /amount ni:dejs:format)
    =/  fee-rate=@ud  (~(dug jo:json-utils jon) /fee-rate ni:dejs:format 2)
    =/  change-addr=@t  (~(dog jo:json-utils jon) /change-address so:dejs:format)
    ;<  uuid=@ta  bind:m  (get-or-gen-uuid p.jon)
    =/  proc-json=json
      %-  pairs:enjs:format
      :~  ['type' s+'send']
          ['account' s+acct-ref]
          ['address' s+dest-addr]
          ['amount' (numb:enjs:format amount)]
          ['fee-rate' (numb:enjs:format fee-rate)]
          ['change-address' s+change-addr]
      ==
    =/  proc-rd=road:tarball  (nex-road [%& /proc (cat 3 uuid '.json')])
    (make:io proc-rd |+[[[/ %json] proc-json] ~])
  ::
  ::  === Draft transaction actions ===
  ::
      %'add-output'
    =/  address=@t  (so:dejs:format (need (~(get by p.jon) 'address')))
    =/  amount=@ud  (ni:dejs:format (need (~(get by p.jon) 'amount')))
    ;<  now=@da  bind:m  get-time:io
    ;<  existing=(unit transaction:drft)  bind:m  (load-draft acct-ref)
    =/  dr=transaction:drft
      ?~  existing
        [~ ~ ~ `%random now now]
      u.existing(modified now)
    =.  outputs.dr  (snoc outputs.dr [address amount])
    (save-draft acct-ref dr)
  ::
      %'delete-output'
    =/  idx=@ud  (ni:dejs:format (need (~(get by p.jon) 'index')))
    ;<  existing=(unit transaction:drft)  bind:m  (load-draft acct-ref)
    ?~  existing  (pure:m ~)
    ;<  now=@da  bind:m  get-time:io
    =/  dr=transaction:drft  u.existing(modified now)
    =.  outputs.dr  (oust [idx 1] outputs.dr)
    (save-draft acct-ref dr)
  ::
      %'clear-draft'
    (delete-draft acct-ref)
  ::
      %'set-change-config'
    =/  fee-rate=@ud  (ni:dejs:format (need (~(get by p.jon) 'fee-rate')))
    =/  chg-addr=@t  (so:dejs:format (need (~(get by p.jon) 'change-address')))
    ;<  now=@da  bind:m  get-time:io
    ;<  existing=(unit transaction:drft)  bind:m  (load-draft acct-ref)
    =/  dr=transaction:drft
      ?~  existing
        [~ ~ ~ `%random now now]
      u.existing(modified now)
    =.  change.dr  `[fee-rate chg-addr]
    (save-draft acct-ref dr)
  ::
      %'clear-change-config'
    ;<  existing=(unit transaction:drft)  bind:m  (load-draft acct-ref)
    ?~  existing  (pure:m ~)
    ;<  now=@da  bind:m  get-time:io
    =.  change.u.existing  ~
    (save-draft acct-ref u.existing(modified now))
  ::
      %'set-auto-select-mode'
    =/  mode-text=@t  (so:dejs:format (need (~(get by p.jon) 'mode')))
    =/  new-auto=(unit select-mode:drft)
      ?:  =('disabled' mode-text)  ~
      ?:  =('largest-first' mode-text)  `%largest-first
      `%random
    ;<  now=@da  bind:m  get-time:io
    ;<  existing=(unit transaction:drft)  bind:m  (load-draft acct-ref)
    =/  dr=transaction:drft
      ?~  existing
        [~ ~ ~ new-auto now now]
      u.existing(auto-select new-auto, modified now)
    (save-draft acct-ref dr)
  ::
      %'run-auto-select'
    ;<  existing=(unit transaction:drft)  bind:m  (load-draft acct-ref)
    ?~  existing  (pure:m ~)
    =/  mode=select-mode:drft
      (fall auto-select.u.existing %random)
    =/  fee-rate=@ud
      ?~  change.u.existing  1
      fee-rate.u.change.u.existing
    =/  [recv=(list [@ud address-data]) chng=(list [@ud address-data])]
      (load-recv-chng lbls acct-ref)
    =/  utxos=(list utxo-input:drft)
      (collect-utxo-inputs:aio recv chng stype)
    =/  total-outputs=@ud  (sum-outputs:drft outputs.u.existing)
    ?:  =(0 total-outputs)
      ;<  now=@da  bind:m  get-time:io
      (save-draft acct-ref u.existing(inputs ~, modified now))
    =/  output-vbytes=@ud
      %+  add
        %+  roll  outputs.u.existing
        |=  [out=output:drft sum=@ud]
        (add sum (output-vbytes:fees (address-to-spend:drft address.out)))
      ?~  change.u.existing  0
      (output-vbytes:fees (address-to-spend:drft address.u.change.u.existing))
    =/  selectables=(list utxo-input:drft)
      (turn utxos |=(u=utxo-input:drft [txid.u vout.u amount.u spend.u]))
    ;<  eny=@uvJ  bind:m  get-entropy:io
    =/  sel-result=(unit (list utxo-input:drft))
      ?-  mode
        %largest-first  (largest-first:utxo-sel selectables total-outputs output-vbytes fee-rate)
        %random         (random:utxo-sel selectables total-outputs output-vbytes fee-rate eny)
      ==
    ?~  sel-result  (pure:m ~)
    =/  selected=(list utxo-input:drft)
      %+  turn  u.sel-result
      |=  s=utxo-input:drft
      =/  match  (skim utxos |=(u=utxo-input:drft &(=(txid.u txid.s) =(vout.u vout.s))))
      ?>(?=(^ match) i.match)
    ;<  now=@da  bind:m  get-time:io
    (save-draft acct-ref u.existing(inputs selected, modified now))
  ::
      %'add-input'
    =/  utxo-txid=@t  (so:dejs:format (need (~(get by p.jon) 'utxo-txid')))
    =/  utxo-vout=@ud  (ni:dejs:format (need (~(get by p.jon) 'utxo-vout')))
    =/  utxo-value=@ud  (ni:dejs:format (need (~(get by p.jon) 'utxo-value')))
    =/  utxo-spend=@t  (so:dejs:format (need (~(get by p.jon) 'utxo-spend')))
    ;<  now=@da  bind:m  get-time:io
    ;<  existing=(unit transaction:drft)  bind:m  (load-draft acct-ref)
    =/  dr=transaction:drft
      ?~  existing
        [~ ~ ~ `%random now now]
      u.existing(modified now)
    =/  spend=spend:fees  ;;(spend:fees (slav %tas utxo-spend))
    =/  new-input=utxo-input:drft  [utxo-txid utxo-vout utxo-value spend]
    =.  inputs.dr  (snoc inputs.dr new-input)
    (save-draft acct-ref dr)
  ::
      %'remove-input'
    =/  utxo-txid=@t  (so:dejs:format (need (~(get by p.jon) 'utxo-txid')))
    =/  utxo-vout=@ud  (ni:dejs:format (need (~(get by p.jon) 'utxo-vout')))
    ;<  existing=(unit transaction:drft)  bind:m  (load-draft acct-ref)
    ?~  existing  (pure:m ~)
    ;<  now=@da  bind:m  get-time:io
    =.  inputs.u.existing
      %+  skip  inputs.u.existing
      |=  input=utxo-input:drft
      &(=(txid.input utxo-txid) =(vout.input utxo-vout))
    (save-draft acct-ref u.existing(modified now))
  ::
      %'build-transaction'
    ?~  xprv  (pure:m ~)
    ~&  >>  "=== BUILD AND BROADCAST TRANSACTION ==="
    ;<  existing=(unit transaction:drft)  bind:m  (load-draft acct-ref)
    ?~  existing
      ~&  >>>  "no draft transaction"
      (pure:m ~)
    ?:  =(~ inputs.u.existing)
      ~&  >>>  "no inputs in draft"
      (pure:m ~)
    ?:  =(~ outputs.u.existing)
      ~&  >>>  "no outputs in draft"
      (pure:m ~)
    =/  [recv=(list [@ud address-data]) chng=(list [@ud address-data])]
      (load-recv-chng lbls acct-ref)
      =/  addr-lookup=(map @t [chain=@ud idx=@ud])
        =/  m=(map @t [chain=@ud idx=@ud])  ~
        =.  m
          =/  entries=(list [@ud address-data])  recv
          |-
          ?~  entries  m
          =.  m  (~(put by m) addr.+.i.entries [0 -.i.entries])
          $(entries t.entries)
        =/  entries=(list [@ud address-data])  chng
        |-
        ?~  entries  m
        =.  m  (~(put by m) addr.+.i.entries [1 -.i.entries])
        $(entries t.entries)
      =/  utxo-to-addr=(map [@t @ud] @t)
        =/  m=(map [@t @ud] @t)  ~
        =/  all=(list [@ud address-data])  (weld recv chng)
        |-
        ?~  all  m
        =/  [idx=@ud a=address-data]  i.all
        =.  m
          |-
          ?~  utxos.a  m
          =.  m  (~(put by m) [txid.i.utxos.a vout.i.utxos.a] addr.a)
          $(utxos.a t.utxos.a)
        $(all t.all)
      =/  account-wallet  (from-extended:bip32 (trip u.xprv))
      =/  tx-inputs=(list input:ap:tt:txb)
        %+  turn  inputs.u.existing
        |=  in=utxo-input:drft
        =/  owner=(unit @t)  (~(get by utxo-to-addr) [txid.in vout.in])
        ?~  owner  ~|("UTXO owner not found: {<txid.in>}:{<vout.in>}" !!)
        =/  path=(unit [chain=@ud idx=@ud])  (~(get by addr-lookup) u.owner)
        ?~  path  ~|("address path not found: {<u.owner>}" !!)
        =/  derived  (derive:(derive:account-wallet chain.u.path) idx.u.path)
        =/  privkey=@ux  prv.derived
        =/  pubkey=@ux  (ser-p:derived pub.derived)
        =/  txid-display=@ux  (rash txid.in hex)
        =/  txid=@ux  dat:(flip:byt:bcu [32 txid-display])
        =/  spend=spend-type:tt:txb
          ?-  spend.in
            %p2pkh        [%p2pkh ~]
            %p2sh-p2wpkh  [%p2sh-p2wpkh ~]
            %p2wpkh       [%p2wpkh ~]
            %p2tr         [%p2tr %key-path ~]
          ==
        [privkey pubkey txid vout.in amount.in `@ud`0xffff.ffff spend]
      =/  tx-outputs=(list output:ap:tt:txb)
        (incorporate-change:drft u.existing)
      ~&  >>  "building tx: {<(lent tx-inputs)>} inputs, {<(lent tx-outputs)>} outputs"
      =/  tx-hex=tape
        (build-transaction:txb network 2 tx-inputs tx-outputs 0)
      =/  tx-hex-cord=@t  (crip tx-hex)
      ~&  >>  "tx hex: {<tx-hex-cord>}"
      =/  broadcast-url=@t
        ?-  network
          %main      'https://mempool.space/api/tx'
          %testnet3  'https://mempool.space/testnet/api/tx'
          %testnet4  'https://mempool.space/testnet4/api/tx'
          %signet    'https://mempool.space/signet/api/tx'
          %regtest   'http://localhost:3000/tx'
        ==
      =/  =request:http
        :*  %'POST'
            broadcast-url
            ~[['content-type' 'text/plain']]
            `(as-octs:mimes:html tx-hex-cord)
        ==
      ;<  ~  bind:m  (send-request:io request)
      ;<  =client-response:iris  bind:m  take-http:aio
      =/  [ok=? broadcast-result=cord]
        ?+  client-response  [%.n 'broadcast-failed']
          [%finished [@ *] [~ [* [p=@ q=@]]]]
        =/  status=@ud  status-code.response-header.client-response
        [`?`=(200 status) q.data.u.full-file.client-response]
        ==
      ~&  >>  "broadcast result: {<ok>} {<broadcast-result>}"
      ?.  ok
        ~&  >>>  "%build-transaction: broadcast failed, skipping notifications"
        (pure:m ~)
      =/  out-addrs=(list @t)
        (turn outputs.u.existing |=(o=output:drft address.o))
      ;<  ~  bind:m  (notify-broadcast-recipients lbls broadcast-result out-addrs)
      (delete-draft acct-ref)
  ::
  ::  === Tapscript actions ===
  ::
      %'add-tapscript'
    ::  Attach a script tree to an existing taproot address.
    ::  Derives internal pubkey from account + chain + index, then
    ::  computes the tapscript address from internal_pubkey + tree.
    ::
    ::  parent-addr: the key-path taproot address (for label linking)
    ::  chain: 0 (recv) or 1 (chng) — which chain the parent is on
    ::  index: derivation index of the parent address
    ::  name: human-readable label for the tapscript
    ::  tree: ptst as JSON
    ?.  ?=(%p2tr stype)
      ~&  >>>  "%add-tapscript: account is not p2tr"
      (pure:m ~)
    ?~  dkey
      ~&  >>>  "%add-tapscript: no derivation key"
      (pure:m ~)
    =/  parent-addr=@t  (~(dog jo:json-utils jon) /parent-addr so:dejs:format)
    =/  chain=@ud  (~(dug jo:json-utils jon) /chain ni:dejs:format 0)
    =/  idx=@ud  (~(dog jo:json-utils jon) /index ni:dejs:format)
    =/  ts-name=@t  (~(dug jo:json-utils jon) /name so:dejs:format '')
    =/  tree-jon=(unit json)  (~(get by p.jon) 'tree')
    ?~  tree-jon  (pure:m ~)
    =/  tree=ptst:taproot  (json-to-ptst:taproot u.tree-jon)
    ?~  tree
      ~&  >>>  "%add-tapscript: empty tree"
      (pure:m ~)
    ::  derive the internal pubkey (33-byte compressed) from account key
    =/  acct-wallet  (from-extended:bip32 (trip u.dkey))
    =/  derived  (derive:(derive:acct-wallet chain) idx)
    =/  internal-pubkey=@ux  (ser-p:derived pub.derived)
    ::  compute tapscript address
    =/  bip-net  (to-bip-network:wt network)
    =/  ts-addr=@t  (tapscript-address:taproot internal-pubkey tree bip-net)
    ::  store tree
    ;<  sts=(map @t ptst:taproot)  bind:m  load-ptsts
    ;<  ~  bind:m  (save-ptsts (~(put by sts) ts-addr tree))
    ::  label: link tapscript addr to parent, and set name
    =/  ts-of-lbl=@t  (rap 3 ~['gwbtc:tapscript-of:' parent-addr])
    =/  new-lbls=labels:b329
      (~(put la:b329 lbls) [%addr ts-addr ts-of-lbl ~ ~ ~])
    =/  new-lbls=labels:b329
      ?.  =('' ts-name)  (~(put la:b329 new-lbls) [%addr ts-addr (rap 3 ~['gwbtc:tapscript-name:' ts-name]) ~ ~ ~])
      new-lbls
    ;<  ~  bind:m  (save-labels new-lbls)
    (pure:m ~)
  ::
      %'delete-tapscript'
    =/  ts-addr=@t  (~(dog jo:json-utils jon) /tapscript-addr so:dejs:format)
    ::  remove from ptsts store
    ;<  sts=(map @t ptst:taproot)  bind:m  load-ptsts
    ;<  ~  bind:m  (save-ptsts (~(del by sts) ts-addr))
    ::  remove all labels for this tapscript address
    =/  new-lbls=labels:b329  (~(del-all la:b329 lbls) %addr ts-addr)
    ;<  ~  bind:m  (save-labels new-lbls)
    (pure:m ~)
  ==
::
::  +notify-broadcast-recipients: after broadcasting, poke ships
::  that offered us any of the output addresses
::
++  notify-broadcast-recipients
  |=  [=labels:b329 txid=@t out-addrs=(list @t)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  prefix=tape  "gwbtc:offered:from:"
  =/  prefix-len=@ud  (lent prefix)
  |-
  ?~  out-addrs  (pure:m ~)
  =/  addr=@t  i.out-addrs
  =/  entries=(unit (set label-entry:b329))  (~(get by addr.labels) addr)
  ?~  entries  $(out-addrs t.out-addrs)
  =/  el=(list label-entry:b329)  ~(tap in u.entries)
  =/  ship=(unit @p)
    |-
    ?~  el  ~
    =/  ltape=tape  (trip label.i.el)
    ?.  =(prefix (scag prefix-len ltape))
      $(el t.el)
    (slaw %p (crip (slag prefix-len ltape)))
  ?~  ship  $(out-addrs t.out-addrs)
  ~&  [%wallet %notify-broadcast u.ship addr txid]
  =/  notify-jon=json
    %-  pairs:enjs:format
    :~  ['action' s+'tx-broadcast']
        ['address' s+addr]
        ['txid' s+txid]
    ==
  =/  req=load:remo:nexus
    :_  [%poke [[/ %json] notify-jon]]
    [/remote-poke %& /apps/'wallet.wallet_app' %'main.sig']
  ;<  ~  bind:m
    (gall-poke:io [u.ship %grubbery] grubbery-load+req)
  $(out-addrs t.out-addrs)
::
::  HTTP response helpers — road from /ui/requests/* to /ui/http.sig
::
++  srv  ~(. http-res:io (nex-road [%& /ui %'http.sig']))
::
++  send-html
  |=  [eyre-id=@ta page=manx]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  bod=@t  (crip (en-xml:html page))
  =/  =octs  (as-octs:mimes:html bod)
  (send-simple:srv eyre-id [[200 ~[['content-type' 'text/html']]] `octs])
::  +serve-page-html: peek a page.html manx from the ball and serve it
::
++  serve-page-html
  |=  [eyre-id=@ta road-cord=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  =road:tarball  (cord-to-road:tarball road-cord)
  ;<  =view:nexus  bind:m  (peek:io road `[/ %mime])
  ?.  ?=([%file *] view)
    (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Page not found')])
  =/  =mime  !<(mime (need-vase:tarball sang.view))
  (send-simple:srv eyre-id (mime-response:http-utils mime))
::  +acct-ref-from-key: extract pubkey-hex from directory name
::
++  acct-ref-from-key
  |=  acct-key=@ta
  ^-  @t
  (crip (scag (need (find "." (trip acct-key))) (trip acct-key)))
::
++  load-labels
  =/  m  (fiber:fiber:nexus ,labels:b329)
  ^-  form:m
  =/  road=road:tarball  (nex-road [%& ~ %'labels.wallet_labels'])
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?.  exists  (pure:m *labels:b329)
  ;<  =view:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%file *] view)  (pure:m *labels:b329)
  (pure:m !<(labels:b329 (need-vase:tarball sang.view)))
::
++  save-labels
  |=  =labels:b329
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  road=road:tarball  (nex-road [%& ~ %'labels.wallet_labels'])
  (over:io road [[/wallet %labels] labels])
::  +verify-receive-addr: live-check addr against mempool, advance if used
::
++  verify-receive-addr
  |=  $:  vr-xprv=@t
          vr-stype=script-type
          vr-net=network:wt
          recv=(list [@ud address-data])
          idx=@ud
          eyre-id=@ta
      ==
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ::  get or derive address at idx
  =/  dat=(unit address-data)
    |-
    ?~  recv  ~
    ?:  =(idx -.i.recv)  `+.i.recv
    $(recv t.recv)
  =/  addr=@t
    ?^  dat  addr.u.dat
    ::  derive if beyond list range
    %-  fall  :_  ''
    %:  derive-addr:aio
      vr-xprv  vr-stype
      vr-net  0  idx
    ==
  ?:  =('' addr)
    ;<  ~  bind:m
      (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html '')])
    (pure:m ~)
  ::  fetch address info from mempool
  =/  base-url=tape  (mempool-base-url:aio vr-net)
  =/  info-url=@t  (crip (weld base-url (trip addr)))
  =/  =request:http
    [%'GET' info-url ~[['Accept' 'application/json']] ~]
  ;<  ~  bind:m  (send-request:io request)
  ;<  resp=client-response:iris  bind:m  take-http:aio
  ;<  now=@da  bind:m  get-time:io
  =/  info=(unit address-info)
    (parse-info-response:aio resp now)
  =/  has-activity=?
    ?~  info  %.n
    (gth tx-count.u.info 0)
  ?.  has-activity
    ::  unused — return it
    ;<  ~  bind:m
      (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html addr)])
    (pure:m ~)
  ::  used — try next index
  $(idx +(idx))
::  +simple-send: build, sign, broadcast via simple page
::
++  simple-send
  |=  [acct-ref=@t change-addr=@t dest-addr=@t amount=@ud fee-rate=@ud eyre-id=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  ok=?  bind:m  (do-send acct-ref dest-addr change-addr amount fee-rate)
  ?.  ok
    (send-simple:srv eyre-id [[500 ~] `(as-octs:mimes:html 'Send failed')])
  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
::
++  get-simple-xpub
  |=  =labels:b329
  ^-  (unit @t)
  =/  xpubs=(list [@t (set label-entry:b329)])
    ~(tap by xpub.labels)
  |-
  ?~  xpubs  ~
  =/  [ref=@t entries=(set label-entry:b329)]  i.xpubs
  =/  is-simple=?
    %+  lien  ~(tap in entries)
    |=(e=label-entry:b329 =('gwbtc:simple' label.e))
  ?.  is-simple  $(xpubs t.xpubs)
  `ref
::
++  get-simple-wallet
  |=  =labels:b329
  =/  m  (fiber:fiber:nexus ,(unit wallet-data))
  ^-  form:m
  =/  xpub=(unit @t)  (get-simple-xpub labels)
  ?~  xpub  (pure:m ~)
  ;<  sec=secrets  bind:m  load-secrets
  =/  sd=(unit seed)  (~(get by seeds.sec) u.xpub)
  ?~  sd  (pure:m ~)
  (pure:m `[u.sd u.xpub])
::
++  get-simple-account
  |=  [=labels:b329 req-net=@t]
  ^-  (unit @t)
  =/  xpub=(unit @t)  (get-simple-xpub labels)
  ?~  xpub  ~
  =/  fp=@ux  fingerprint:(from-extended:bip32 (trip u.xpub))
  =/  refs=(list @t)  (load-wallet-account-keys labels fp)
  (find-account-for-net labels refs req-net)
::
++  set-simple-wallet
  |=  [=labels:b329 xpub=@t]
  ^-  labels:b329
  ::  clear any existing simple-wallet label
  =/  cleared=labels:b329  (clear-simple-wallet labels)
  (~(put la:b329 cleared) [%xpub xpub 'gwbtc:simple' ~ ~ ~])
::
++  clear-simple-wallet
  |=  =labels:b329
  ^-  labels:b329
  =/  xpubs=(list [@t (set label-entry:b329)])
    ~(tap by xpub.labels)
  |-
  ?~  xpubs  labels
  =/  [ref=@t entries=(set label-entry:b329)]  i.xpubs
  =/  has=?
    %+  lien  ~(tap in entries)
    |=(e=label-entry:b329 =('gwbtc:simple' label.e))
  ?.  has  $(xpubs t.xpubs)
  (~(del la:b329 labels) %xpub ref 'gwbtc:simple')
::
++  get-simple-saved
  |=  [=labels:b329 xpub=@t]
  ^-  ?
  =/  entries=(list label-entry:b329)
    ~(tap in (~(get la:b329 labels) %xpub xpub))
  %+  lien  entries
  |=(e=label-entry:b329 =('gwbtc:saved' label.e))
::
++  set-simple-saved
  |=  [=labels:b329 xpub=@t saved=?]
  ^-  labels:b329
  ?:  saved
    (~(put la:b329 labels) [%xpub xpub 'gwbtc:saved' ~ ~ ~])
  (~(del la:b329 labels) %xpub xpub 'gwbtc:saved')
::
++  get-simple-fee
  |=  [=labels:b329 xpub=@t]
  ^-  @ud
  =/  entries=(list label-entry:b329)
    ~(tap in (~(get la:b329 labels) %xpub xpub))
  =/  prefix=tape  "gwbtc:fee:"
  =/  prefix-len=@ud  (lent prefix)
  |-
  ?~  entries  2
  =/  lbl=tape  (trip label.i.entries)
  ?.  =(prefix (scag prefix-len lbl))
    $(entries t.entries)
  (fall (rush (crip (slag prefix-len lbl)) dem) 2)
::
++  set-simple-fee
  |=  [=labels:b329 xpub=@t fee=@ud]
  ^-  labels:b329
  =/  entries=(list label-entry:b329)
    ~(tap in (~(get la:b329 labels) %xpub xpub))
  =/  prefix=tape  "gwbtc:fee:"
  =/  prefix-len=@ud  (lent prefix)
  =.  labels
    |-
    ?~  entries  labels
    =/  lbl=tape  (trip label.i.entries)
    ?:  =(prefix (scag prefix-len lbl))
      $(entries t.entries, labels (~(del la:b329 labels) %xpub xpub label.i.entries))
    $(entries t.entries)
  (~(put la:b329 labels) [%xpub xpub (crip "gwbtc:fee:{(a-co:co fee)}") ~ ~ ~])
::
::  +load-registry/save-registry: read/write process registry
::
++  load-registry
  =/  m  (fiber:fiber:nexus ,proc-registry)
  ^-  form:m
  =/  rd=road:tarball  (nex-road [%& ~ %'registry.wallet_registry'])
  ;<  exists=?  bind:m  (peek-exists:io rd)
  ?.  exists  (pure:m *proc-registry)
  ;<  =view:nexus  bind:m  (peek:io rd ~)
  ?.  ?=([%file *] view)  (pure:m *proc-registry)
  (pure:m !<(proc-registry (need-vase:tarball sang.view)))
::
++  save-registry
  |=  reg=proc-registry
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  rd=road:tarball  (nex-road [%& ~ %'registry.wallet_registry'])
  (over:io rd [[/wallet %registry] reg])
::  +short-id: 8 hex chars from entropy, no dots
::
++  short-id
  |=  eny=@uvJ
  ^-  @ta
  =/  hex=tape  ((x-co:co 8) (end [3 4] (mug eny)))
  (crip hex)
::  +refresh-key: build registry key for a refresh proc
::
++  refresh-key
  |=  [chain=?(%recv %chng) idx=@ud]
  ^-  @ta
  (crip "{(trip chain)}-{(scow %ud idx)}")
::  +load-recv-chng: build recv/chng address lists from labels
::
++  load-recv-chng
  |=  [=labels:b329 acct-ref=@t]
  ^-  [recv=(list [@ud address-data]) chng=(list [@ud address-data])]
  =/  og=(unit parsed-origin:b329)  (get-acct-origin:aio labels acct-ref)
  ?.  ?=(~ og)
    =/  addrs  (read-account-addrs:aio labels u.og)
    [(build-addr-data:aio recv.addrs labels) (build-addr-data:aio chng.addrs labels)]
  ::  standalone account: find addresses via gwbtc:derived-from: labels
  =/  addrs  (read-standalone-addrs:aio labels acct-ref)
  [(build-addr-data:aio recv.addrs labels) (build-addr-data:aio chng.addrs labels)]
::  +build-acct-tx-map: reconstruct tx-map for an account from labels
::
++  build-acct-tx-map
  |=  [=labels:b329 acct-ref=@t]
  ^-  tx-map
  =/  og=(unit parsed-origin:b329)  (get-acct-origin:aio labels acct-ref)
  ?~  og  *tx-map
  =/  addrs  (read-account-addrs:aio labels u.og)
  =/  addr-set=(set @t)
    %-  ~(gas in *(set @t))
    (weld (turn recv.addrs |=([* a=@t] a)) (turn chng.addrs |=([* a=@t] a)))
  (build-tx-map:aio labels addr-set)
::  +load-wallet-account-keys: find account refs belonging to a wallet
::  returns list of pubkey-hex refs
::
++  load-wallet-account-keys
  |=  [=labels:b329 fp=@ux]
  ^-  (list @t)
  =/  xpubs=(list [@t (set label-entry:b329)])
    ~(tap by xpub.labels)
  %+  murn  xpubs
  |=  [ref=@t entries=(set label-entry:b329)]
  ^-  (unit @t)
  =/  og=(unit parsed-origin:b329)
    =/  elist=(list label-entry:b329)  ~(tap in entries)
    |-
    ?~  elist  ~
    ?^  origin.i.elist  origin.i.elist
    $(elist t.elist)
  ?~  og  ~
  ?.  =(fingerprint.u.og fp)  ~
  `ref
::
++  find-account-for-net
  |=  [=labels:b329 refs=(list @t) req-net=@t]
  ^-  (unit @t)
  ?~  refs  ~
  =/  network=@t  ;;(@t (get-acct-network:aio labels i.refs))
  ?:  =(req-net network)  `i.refs
  $(refs t.refs)
::
++  wallet-nets
  |=  [=labels:b329 refs=(list @t)]
  ^-  (list tape)
  %+  turn  refs
  |=(ref=@t (trip ;;(@t (get-acct-network:aio labels ref))))
::  +ensure-public-poke: register and expose main.sig for pokes via /public
::
++  ensure-public-poke
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  ~  bind:m  reg-register:io
  ;<  here=rail:tarball  bind:m  get-here-abs:io
  (reg-how:io /public [~ (sy ~[[%& %& here]]) ~])
::  +ensure-simple-wallet: create simple wallet if none labeled 'gwbtc:simple'
::
++  ensure-simple-wallet
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ::  load labels from root level
  =/  lbl-rd=road:tarball  (nex-road [%& ~ %'labels.wallet_labels'])
  ;<  lbl-view=view:nexus  bind:m  (peek:io lbl-rd ~)
  =/  lbls=labels:b329
    ?.  ?=([%file *] lbl-view)  *labels:b329
    !<(labels:b329 (need-vase:tarball sang.lbl-view))
  =/  xpub=(unit @t)  (get-simple-xpub lbls)
  ?^  xpub
    ~&  "%wallet: simple wallet exists"
    (pure:m ~)
  ~&  "%wallet: creating simple wallet"
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  seed-phrase=cord  (gen-seed:seed-phrases eny %256)
  =/  [wal-t=wallet-data mxpub=@t ref-t=@t xprv-t=@t net-t=network:wt st-t=script-type og-t=parsed-origin:b329]
    (make-dev-wallet 'My Wallet' [%t seed-phrase] %testnet3)
  =/  [* * ref-m=@t xprv-m=@t net-m=network:wt st-m=script-type og-m=parsed-origin:b329]
    (make-dev-wallet 'My Wallet' [%t seed-phrase] %main)
  =/  wal=wallet-data  wal-t
  ;<  sec=secrets  bind:m  load-secrets
  ;<  ~  bind:m  (save-secrets sec(seeds (~(put by seeds.sec) xpub.wal seed.wal)))
  ::  save labels
  =/  new-lbls=labels:b329  (set-simple-wallet lbls mxpub)
  =/  new-lbls=labels:b329
    (~(put la:b329 new-lbls) [%xpub mxpub 'gwbtc:wallet:My Wallet' ~ ~ ~])
  =/  new-lbls=labels:b329  (make-acct-labels:aio new-lbls ref-t 'Default' net-t og-t)
  =/  new-lbls=labels:b329  (make-acct-labels:aio new-lbls ref-m 'Default' net-m og-m)
  ;<  ~  bind:m  (over:io lbl-rd [[/wallet %labels] new-lbls])
  ~&  "%wallet: simple wallet created"
  (pure:m ~)
::
++  load-secrets
  =/  m  (fiber:fiber:nexus ,secrets)
  ^-  form:m
  =/  rd=road:tarball  (nex-road [%& ~ %'secrets.wallet_secrets'])
  ;<  exists=?  bind:m  (peek-exists:io rd)
  ?.  exists  (pure:m *secrets)
  ;<  =view:nexus  bind:m  (peek:io rd ~)
  ?.  ?=([%file *] view)  (pure:m *secrets)
  (pure:m !<(secrets (need-vase:tarball sang.view)))
::
++  save-secrets
  |=  sec=secrets
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  rd=road:tarball  (nex-road [%& ~ %'secrets.wallet_secrets'])
  (over:io rd [[/wallet %secrets] sec])
::
++  load-ptsts
  =/  m  (fiber:fiber:nexus ,(map @t ptst:taproot))
  ^-  form:m
  =/  rd=road:tarball  (nex-road [%& ~ %'ptsts.wallet_ptsts'])
  ;<  exists=?  bind:m  (peek-exists:io rd)
  ?.  exists  (pure:m *(map @t ptst:taproot))
  ;<  =view:nexus  bind:m  (peek:io rd ~)
  ?.  ?=([%file *] view)  (pure:m *(map @t ptst:taproot))
  (pure:m !<((map @t ptst:taproot) (need-vase:tarball sang.view)))
::
++  save-ptsts
  |=  sts=(map @t ptst:taproot)
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  rd=road:tarball  (nex-road [%& ~ %'ptsts.wallet_ptsts'])
  (over:io rd [[/wallet %ptsts] sts])
::
++  secrets-to-wallets
  |=  sec=secrets
  ^-  (list wallet-data)
  %+  turn  ~(tap by seeds.sec)
  |=([xp=@t sd=seed] `wallet-data`[sd xp])
::
::  +load-contacts: peek contacts overlay dir for send-to picker
::
++  contacts-overlay-road  [%& %| /apps/'contacts.contacts'/overlay]
++  load-contacts
  =/  m  (fiber:fiber:nexus ,(map @t (map @t json)))
  ^-  form:m
  ;<  =view:nexus  bind:m  (peek:io contacts-overlay-road ~)
  ?.  ?=([%ball *] view)  (pure:m ~)
  =/  =lump:tarball  (fall fil.ball.view *lump:tarball)
  %-  pure:m
  %-  ~(gas by *(map @t (map @t json)))
  %+  murn  ~(tap by contents.lump)
  |=  [name=@ta =sang:tarball gain=? bang=(unit tang)]
  ?.  =(%jobj name.p.sang)  ~
  ?:  (is-boom:tarball sang)  ~
  =/  key=@t
    =/  parts=(list tape)  (rash name (more dot (star ;~(less dot prn))))
    ?~  parts  name
    (crip i.parts)
  =/  obj=(map @t json)  !<((map @t json) (need-vase:tarball sang))
  ?~  obj  ~
  `[key obj]
::  +load-scan-state: read scan status from registry + proc file
::
++  load-scan-state
  |=  acct-ref=@t
  =/  m  (fiber:fiber:nexus ,[?(%active %paused %none) (unit scan-progress:acct-ui)])
  ^-  form:m
  ;<  reg=proc-registry  bind:m  load-registry
  =/  acct-procs=account-procs
    (fall (~(get by accounts.reg) acct-ref) *account-procs)
  ?~  scan.acct-procs
    (pure:m [%none ~])
  ::  peek the proc file for progress and paused state
  =/  proc-rd=road:tarball  (nex-road [%& /proc (cat 3 u.scan.acct-procs '.json')])
  ;<  exists=?  bind:m  (peek-exists:io proc-rd)
  ?.  exists
    ::  proc file gone but registry stale — clean up
    =/  cleared=account-procs  [~ refresh.acct-procs]
    =.  accounts.reg  (~(put by accounts.reg) acct-ref cleared)
    ;<  ~  bind:m  (save-registry reg)
    (pure:m [%none ~])
  ;<  =view:nexus  bind:m  (peek:io proc-rd ~)
  ?.  ?=([%file *] view)
    (pure:m [%active ~])
  =/  jon=json  !<(json (need-vase:tarball sang.view))
  =/  status=@t
    (~(dug jo:json-utils jon) /status so:dejs:format '')
  ?:  =(status 'done')
    (pure:m [%none ~])
  =/  progress=(unit scan-progress:acct-ui)
    (mole |.((parse-scan-progress:aio jon)))
  =/  paused-marker=(unit json)
    ?:  ?=([%o *] jon)  (~(get by p.jon) 'paused')
    ~
  =/  is-paused=?  =(paused-marker `b+%.y)
  (pure:m [?:(is-paused %paused %active) progress])
::  +load-draft: peek draft transaction from account
::
++  load-draft
  |=  acct-ref=@t
  =/  m  (fiber:fiber:nexus ,(unit transaction:drft))
  ^-  form:m
  =/  rd=road:tarball  (nex-road [%& ~ %'drafts.wallet_drafts'])
  ;<  =view:nexus  bind:m  (peek:io rd ~)
  ?.  ?=([%file *] view)  (pure:m ~)
  =/  drafts=(map @t transaction:drft)
    !<((map @t transaction:drft) (need-vase:tarball sang.view))
  (pure:m (~(get by drafts) acct-ref))
::
++  save-draft
  |=  [acct-ref=@t dr=transaction:drft]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  rd=road:tarball  (nex-road [%& ~ %'drafts.wallet_drafts'])
  ;<  =view:nexus  bind:m  (peek:io rd ~)
  ?.  ?=([%file *] view)  (pure:m ~)
  =/  drafts=(map @t transaction:drft)
    !<((map @t transaction:drft) (need-vase:tarball sang.view))
  (over:io rd [[/wallet %drafts] (~(put by drafts) acct-ref dr)])
::
++  delete-draft
  |=  acct-ref=@t
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  rd=road:tarball  (nex-road [%& ~ %'drafts.wallet_drafts'])
  ;<  =view:nexus  bind:m  (peek:io rd ~)
  ?.  ?=([%file *] view)  (pure:m ~)
  =/  drafts=(map @t transaction:drft)
    !<((map @t transaction:drft) (need-vase:tarball sang.view))
  (over:io rd [[/wallet %drafts] (~(del by drafts) acct-ref)])
::  +send-sse-fragment: send a single SSE fragment targeting a DOM element
::
++  send-sse-fragment
  |=  [eyre-id=@ta target=@t content=manx]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  =json
    (pairs:enjs:format ~[['target' s+target] ['html' s+(crip (en-xml:html content))]])
  =/  =sse-event:http-utils  [~ `'fragment' [(en:json:html json)]~]
  =/  data=octs  (sse-encode:http-utils ~[sse-event])
  (send-data:srv eyre-id `data)
::  +send-sse-prepend: prepend a row to a DOM element if rowId doesn't exist
::
++  send-sse-prepend
  |=  [eyre-id=@ta target=@t row-id=@t content=manx]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  =json
    %-  pairs:enjs:format
    :~  ['target' s+target]
        ['html' s+(crip (en-xml:html content))]
        ['action' s+'prepend']
        ['rowId' s+row-id]
    ==
  =/  =sse-event:http-utils  [~ `'fragment' [(en:json:html json)]~]
  =/  data=octs  (sse-encode:http-utils ~[sse-event])
  (send-data:srv eyre-id `data)
::  +send-sse-update: update an existing row by ID (outerHTML replace)
::
++  send-sse-update
  |=  [eyre-id=@ta target=@t row-id=@t content=manx]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  =json
    %-  pairs:enjs:format
    :~  ['target' s+target]
        ['html' s+(crip (en-xml:html content))]
        ['action' s+'update']
        ['rowId' s+row-id]
    ==
  =/  =sse-event:http-utils  [~ `'fragment' [(en:json:html json)]~]
  =/  data=octs  (sse-encode:http-utils ~[sse-event])
  (send-data:srv eyre-id `data)
::  +send-addr-rows: prepend new rows, update existing ones in-place
::
++  send-addr-rows
  |=  [eyre-id=@ta acct-ref=@t ar-net=network:wt chain-tag=?(%recv %chng) entries=(list [@ud address-data]) now=@da]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  chain=tape  ?:(?=(%recv chain-tag) "receiving" "change")
  =/  key-hex=tape  (trip acct-ref)
  =/  list-id=@t  (crip "addr-list-{(trip chain-tag)}")
  |-
  ?~  entries  (pure:m ~)
  =/  [idx=@ud a=address-data]  i.entries
  =/  row-id=@t  (crip "addr-{(trip chain-tag)}-{(scow %ud idx)}")
  =/  row=manx  (address-row:acct-ui idx a now chain chain-tag ar-net key-hex)
  ;<  ~  bind:m  (send-sse-prepend eyre-id list-id row-id row)
  ;<  ~  bind:m  (send-sse-update eyre-id list-id row-id row)
  $(entries t.entries)
::  +handle-account-stream: SSE stream for account detail page
::
++  handle-account-stream
  |=  [eyre-id=@ta req=inbound-request:eyre acct-key=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  (is-sse-request:http-utils req)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'SSE only')])
    (pure:m ~)
  ;<  ~  bind:m  (send-header:srv eyre-id sse-header:http-utils)
  ::  watch stores
  =/  lbl-road=road:tarball   (nex-road [%& ~ %'labels.wallet_labels'])
  ;<  *  bind:m  (keep:io /acct-stream lbl-road ~)
  ;<  now=@da  bind:m  get-time:io
  ;<  ~  bind:m  (send-wait:io (add now ~s30))
  |-
  ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /acct-stream)
  ?-    -.nw
      %wake
    ;<  ~  bind:m  (send-data:srv eyre-id `sse-keep-alive:http-utils)
    ;<  now=@da  bind:m  get-time:io
    ;<  ~  bind:m  (send-wait:io (add now ~s30))
    $
      %news
    ::  lightweight update: just summary + address rows
    =/  s-ref=@t  (acct-ref-from-key acct-key)
    ;<  s-lbls=labels:b329  bind:m  load-labels
    ?.  (has-account:aio s-lbls s-ref)  $
    =/  s-net=network:wt  (get-acct-network:aio s-lbls s-ref)
    =/  [recv=(list [@ud address-data]) chng=(list [@ud address-data])]
      (load-recv-chng s-lbls s-ref)
    ;<  now=@da  bind:m  get-time:io
    =/  next-addr=(unit @t)  (next-unused-addr:acct-ui recv)
    ;<  ~  bind:m
      ?~  next-addr  (pure:m ~)
      =/  =sse-event:http-utils  [~ `'receive-addr' [u.next-addr]~]
      =/  data=octs  (sse-encode:http-utils ~[sse-event])
      (send-data:srv eyre-id `data)
    ;<  ~  bind:m
      (send-sse-fragment eyre-id 'account-summary-wrap' (account-summary-ui:acct-ui recv chng))
    ;<  ~  bind:m  (send-addr-rows eyre-id s-ref s-net %recv recv now)
    ;<  ~  bind:m  (send-addr-rows eyre-id s-ref s-net %chng chng now)
    $
  ==
::  +handle-send-stream: SSE stream for send page
::
++  handle-send-stream
  |=  [eyre-id=@ta req=inbound-request:eyre acct-key=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  (is-sse-request:http-utils req)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'SSE only')])
    (pure:m ~)
  ;<  ~  bind:m  (send-header:srv eyre-id sse-header:http-utils)
  =/  lbl-road=road:tarball    (nex-road [%& ~ %'labels.wallet_labels'])
  =/  draft-road=road:tarball  (nex-road [%& ~ %'drafts.wallet_drafts'])
  ;<  *  bind:m  (keep:io /send-stream lbl-road ~)
  ;<  *  bind:m  (keep:io /send-stream draft-road ~)
  ;<  now=@da  bind:m  get-time:io
  ;<  ~  bind:m  (send-wait:io (add now ~s30))
  |-
  ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /send-stream)
  ?-    -.nw
      %wake
    ;<  ~  bind:m  (send-data:srv eyre-id `sse-keep-alive:http-utils)
    ;<  now=@da  bind:m  get-time:io
    ;<  ~  bind:m  (send-wait:io (add now ~s30))
    $
      %news
    =/  ss-ref=@t  (acct-ref-from-key acct-key)
    ;<  ss-lbls=labels:b329  bind:m  load-labels
    ?.  (has-account:aio ss-lbls ss-ref)  $
    =/  ss-net=network:wt  (get-acct-network:aio ss-lbls ss-ref)
    =/  ss-stype=script-type  (get-acct-script-type:aio ss-lbls ss-ref)
    =/  [recv=(list [@ud address-data]) chng=(list [@ud address-data])]
      (load-recv-chng ss-lbls ss-ref)
    ;<  dr=(unit transaction:drft)  bind:m  (load-draft ss-ref)
    =/  fi=fee-calc:acct-ui  (compute-fee-info:acct-ui dr)
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
    =/  total-balance=@ud
      %+  roll  utxos
      |=  [[addr=@t u=utxo chain=?(%recv %chng) idx=@ud] sum=@ud]
      (add sum value.u)
    =/  next-chg=(unit @t)  (next-unused-change-addr:acct-ui chng)
    =/  auto-mode=(unit select-mode:drft)
      ?~  dr  ~
      auto-select.u.dr
    =/  has-auto=?  ?=(^ auto-mode)
    =/  is-random=?  =(auto-mode `%random)
    =/  is-largest=?  =(auto-mode `%largest-first)
    =/  spend=spend:fees:acct-ui  ss-stype
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
      (utxo-row-ui:acct-ui txid.u vout.u value.u addr spend is-sel)
    ::  send balance
    ;<  ~  bind:m
      =/  bal=manx  ;span: Available: {(scow %ud total-balance)} sats
      (send-sse-fragment eyre-id 'send-balance' bal)
    ::  send fee info
    ;<  ~  bind:m
      (send-sse-fragment eyre-id 'send-fee-info' (fee-info-ui:acct-ui fi))
    ::  send auto-select
    ;<  ~  bind:m
      (send-sse-fragment eyre-id 'send-auto-select' (auto-select-ui:acct-ui has-auto is-random is-largest (add total-outputs.fi est-fee.fi)))
    ::  send utxo list
    ;<  ~  bind:m
      =/  utxo-manx=manx  [[%div [%class "fc"]~] utxo-rows]
      (send-sse-fragment eyre-id 'utxo-list' utxo-manx)
    ::  send change section
    ;<  ~  bind:m
      (send-sse-fragment eyre-id 'send-change-section' (change-section-ui:acct-ui has-change-config.fi fee-rate.fi est-fee.fi est-vbytes.fi change-result.fi next-chg))
    ::  send output list
    ;<  ~  bind:m
      (send-sse-fragment eyre-id 'output-list' (output-list-ui:acct-ui dr))
    $
  ==
::  +handle-addr-stream: SSE stream for address detail page
::
++  handle-addr-stream
  |=  [eyre-id=@ta req=inbound-request:eyre acct-key=@ta chain-tag=?(%recv %chng) idx=@ud akh-ta=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  (is-sse-request:http-utils req)
    ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'SSE only')])
    (pure:m ~)
  ;<  ~  bind:m  (send-header:srv eyre-id sse-header:http-utils)
  ::  watch labels
  =/  lbl-road=road:tarball   (nex-road [%& ~ %'labels.wallet_labels'])
  ;<  *  bind:m  (keep:io /addr-stream lbl-road ~)
  ;<  now=@da  bind:m  get-time:io
  ;<  ~  bind:m  (send-wait:io (add now ~s30))
  |-
  ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /addr-stream)
  ?-    -.nw
      %wake
    ;<  ~  bind:m  (send-data:srv eyre-id `sse-keep-alive:http-utils)
    ;<  now=@da  bind:m  get-time:io
    ;<  ~  bind:m  (send-wait:io (add now ~s30))
    $
      %news
    ::  reload address data and re-render live content
    =/  as-ref=@t  (acct-ref-from-key acct-key)
    ;<  as-lbls=labels:b329  bind:m  load-labels
    ?.  (has-account:aio as-lbls as-ref)  $
    =/  as-net=network:wt  (get-acct-network:aio as-lbls as-ref)
    =/  rc  (load-recv-chng as-lbls as-ref)
    =/  chain-list=(list [@ud address-data])
      ?:(?=(%recv chain-tag) recv.rc chng.rc)
    =/  dat=(unit address-data)
      |-  ^-  (unit address-data)
      ?~  chain-list  ~
      ?:  =(idx -.i.chain-list)  `+.i.chain-list
      $(chain-list t.chain-list)
    ?~  dat  $
    =/  akh=tape  (trip akh-ta)
    ;<  reg=proc-registry  bind:m  load-registry
    =/  acct-procs=account-procs
      (fall (~(get by accounts.reg) as-ref) *account-procs)
    =/  rkey=@ta  (refresh-key chain-tag idx)
    =/  loading=?  (~(has by refresh.acct-procs) rkey)
    =/  txs=tx-map  (build-acct-tx-map as-lbls as-ref)
    =/  addr-txs=(list transaction)
      %-  sort-txs
      %+  murn  ~(val by txs)
      |=  =transaction
      =/  in-out=?
        ?|  %+  lien  outputs.transaction
            |=(=tx-output =(address.tx-output addr.u.dat))
          ::
            %+  lien  inputs.transaction
            |=  =tx-input
            ?~  prevout.tx-input  %.n
            =(address.u.prevout.tx-input addr.u.dat)
        ==
      ?:(in-out `transaction ~)
    ;<  ~  bind:m
      (send-sse-fragment eyre-id 'live-content' (addr-live-content u.dat loading akh addr-txs))
    $
  ==
::  +find-tx-addr: given a tx, find first address in lists that it touches
::
++  find-tx-addr
  |=  [tx=transaction recv=(list [@ud address-data]) chng=(list [@ud address-data])]
  ^-  (unit [idx=@ud chain=?(%recv %chng) address-data])
  =/  addressess=(set @t)
    %-  ~(gas in *(set @t))
    %+  weld
      (turn outputs.tx |=(=tx-output address.tx-output))
    %+  murn  inputs.tx
    |=(=tx-input ?~(prevout.tx-input ~ `address.u.prevout.tx-input))
  =/  recv-list=(list [@ud address-data])  recv
  =/  res=(unit [idx=@ud chain=?(%recv %chng) address-data])
    |-
    ?~  recv-list  ~
    =/  [idx=@ud a=address-data]  i.recv-list
    ?:  (~(has in addressess) addr.a)  `[idx %recv a]
    $(recv-list t.recv-list)
  ?^  res  res
  =/  chng-list=(list [@ud address-data])  chng
  |-
  ?~  chng-list  ~
  =/  [idx=@ud a=address-data]  i.chng-list
  ?:  (~(has in addressess) addr.a)  `[idx %chng a]
  $(chng-list t.chng-list)
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
++  sort-txs
  |=  txs=(list transaction)
  ^-  (list transaction)
  %+  sort  txs
  |=  [a=transaction b=transaction]
  ::  unconfirmed first, then by descending block height
  ?:  ?=(%unconfirmed -.tx-status.a)
    ?:  ?=(%unconfirmed -.tx-status.b)  %.y
    %.y
  ?:  ?=(%unconfirmed -.tx-status.b)  %.n
  (gth block-height.tx-status.a block-height.tx-status.b)
::
++  truncate-txid
  |=  txid=@t
  ^-  tape
  =/  full=tape  (trip txid)
  =/  len=@ud  (lent full)
  ?:  (lte len 16)  full
  :(weld (scag 8 full) "..." (slag (sub len 8) full))
::
::  +addr-detail-page: render address detail from inline data
::
++  addr-detail-page
  |=  [nexus-root=tape idx=@ud dat=address-data chain-tag=?(%recv %chng) ad-net=network:wt akh=tape txs=tx-map]
  ^-  manx
  =/  addr-text=tape  (trip addr.dat)
  =/  chain-label=tape
    ?:(?=(%recv chain-tag) "Receiving" "Change")
  =/  network-label=tape
    ?-(ad-net %main "Mainnet", %testnet3 "Testnet3", %testnet4 "Testnet4", %signet "Signet", %regtest "Regtest")
  =/  addr-txs=(list transaction)
    %-  sort-txs
    %+  murn  ~(val by txs)
    |=  =transaction
    =/  in-out=?
      ?|  %+  lien  outputs.transaction
          |=(=tx-output =(address.tx-output addr.dat))
        ::
          %+  lien  inputs.transaction
          |=  =tx-input
          ?~  prevout.tx-input  %.n
          =(address.u.prevout.tx-input addr.dat)
      ==
    ?:(in-out `transaction ~)
  ;html
    ;head
      ;title: Address {(scag 12 addr-text)}...
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;+  feather:feather
      ;style
        ;+  ;/  addr-style-text
      ==
    ==
    ;body
      ;div(style "min-width: 650px; height: 100%;")
        ;div.fc.g3.p5.ma.mw-page(style "height: 100%; overflow: hidden;")
          ::  back link
          ;div(style "flex-shrink: 0;")
            ;a.hover.pointer(id "back-link", href "#", onclick "goBack(); return false;", style "color: var(--f3); text-decoration: none;"): ← Back to Account
          ==
          ::  header
          ;div.p4.b1.br2(style "flex-shrink: 0;")
            ;div(style "display: flex; align-items: center; gap: 8px; margin-bottom: 8px;")
              ;span.s-2.bold.f3(style "background: var(--b2); padding: 2px 8px; border-radius: 4px;"): {chain-label} #{(a-co:co idx)}
              ;span.s-2.f3(style "background: var(--b2); padding: 2px 8px; border-radius: 4px;"): {network-label}
            ==
            ;div(style "display: flex; align-items: center; gap: 8px;")
              ;code.mono.s-1(style "word-break: break-all; flex: 1;"): {addr-text}
              ;button.p1.b0.br1.hover.pointer
                =data-addr  addr-text
                =onclick  "copyToClipboard(this.dataset.addr)"
                =style  "background: transparent; border: 1px solid var(--b3); color: var(--f3); display: flex; align-items: center; width: 28px; height: 28px; justify-content: center; outline: none; flex-shrink: 0;"
                ;div(style "width: 14px; height: 14px; display: flex; align-items: center; justify-content: center;")
                  ;+  (make:fi 'copy')
                ==
              ==
            ==
          ==
          ::  live content
          ;+  (addr-live-content dat %.n akh addr-txs)
        ==
      ==
      ;script
        ;+  ;/  (addr-script-text akh (trip chain-tag) (scow %ud idx))
      ==
    ==
  ==
::  +addr-live-content: balance, UTXOs, and tx list for address page
::
++  addr-live-content
  |=  [dat=address-data is-loading=? akh=tape addr-txs=(list transaction)]
  ^-  manx
  =/  balance=@ud
    ?~  info.dat  0
    %+  sub
      (add funded.u.info.dat mem-funded.u.info.dat)
    (add spent.u.info.dat mem-spent.u.info.dat)
  ;div#live-content.fc.g3(style "flex: 1; min-height: 0; overflow: hidden;")
    ::  balance stats
    ;div.p4.b2.br2(style "flex-shrink: 0; overflow: hidden;")
      ;h2.s0.bold.mb2: Balance
      ;div(style "display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px;")
        ;div
          ;div.f3.s-2: Balance
          ;div.s0.bold.mono: {(format-sats balance)} sats
        ==
        ;div
          ;div.f3.s-2: Funded
          ;div.s-1.mono: {?~(info.dat "—" (format-sats (add funded.u.info.dat mem-funded.u.info.dat)))}
        ==
        ;div
          ;div.f3.s-2: Spent
          ;div.s-1.mono: {?~(info.dat "—" (format-sats (add spent.u.info.dat mem-spent.u.info.dat)))}
        ==
        ;div
          ;div.f3.s-2: Transactions
          ;div.s-1.mono: {?~(info.dat "—" (a-co:co tx-count.u.info.dat))}
        ==
      ==
      ;div(style "display: flex; justify-content: space-between; align-items: center; margin-top: 12px;")
        ;span.f3.s-2: {?~(info.dat "Never checked" ?~(last-check.u.info.dat "Never checked" "Last: {(scow %da u.last-check.u.info.dat)}"))}
        ;+  ?:  is-loading
              ;div(style "display: flex; gap: 4px;")
                ;div.p2.b1.br1(style "background: rgba(100, 150, 255, 0.2); border: 1px solid var(--b3); color: var(--f3); display: flex; align-items: center; height: 32px; padding: 0 8px; justify-content: center;")
                  ;div(style "width: 16px; height: 16px; display: flex; align-items: center; justify-content: center; animation: spin 1s linear infinite;")
                    ;+  (make:fi 'loader')
                  ==
                ==
              ==
            ;button.p2.b1.br1.hover.pointer
              =onclick  "doRefresh()"
              =style  "border: 1px solid var(--b3); color: var(--f2); display: flex; align-items: center; gap: 6px; outline: none;"
              ;div(style "width: 14px; height: 14px; display: flex; align-items: center; justify-content: center;")
                ;+  (make:fi 'refresh-cw')
              ==
              ;span.s-2: Refresh
            ==
      ==
    ==
    ::
    ::  UTXOs
    ;div.p4.b1.br2(style "flex: 1; min-height: 0; display: flex; flex-direction: column;")
      ;h2.s0.bold.mb2(style "flex-shrink: 0;"): UTXOs ({(a-co:co (lent utxos.dat))})
      ;+  ?:  =(~ utxos.dat)
            ;div.p3.b2.br2.tc.f3.s-1: No unspent outputs
          ;div.fc.g1(style "flex: 1; min-height: 0; overflow-y: auto;")
            ;*  =/  akh  akh
                %+  turn  utxos.dat
                |=  =utxo
                ^-  manx
                ;div.p3.b2.br2(style "display: flex; justify-content: space-between; align-items: center;")
                  ;div(style "min-width: 0; flex: 1;")
                    ;div(style "display: flex; align-items: center; gap: 6px;")
                      ;a.mono.s-2.f2(href "/groundwire/wallet/a/{akh}/tx/{(trip txid.utxo)}", style "white-space: nowrap; overflow: hidden; text-overflow: ellipsis; color: var(--f2); text-decoration: none;"): {(truncate-txid txid.utxo)}:{(a-co:co vout.utxo)}
                      ;+  ?-  -.tx-status.utxo
                              %confirmed
                            ;span.s-2(style "color: #10b981; font-size: 11px;"): ✓
                              %unconfirmed
                            ;span.s-2(style "color: #f59e0b; font-size: 11px;"): ○
                          ==
                    ==
                  ==
                  ;span.mono.s-1.bold: {(format-sats value.utxo)} sats
                ==
          ==
    ==
    ::  transactions
    ;div.p4.b1.br2(style "flex: 1; min-height: 0; display: flex; flex-direction: column;")
      ;h2.s0.bold.mb2(style "flex-shrink: 0;"): Transactions ({(a-co:co (lent addr-txs))})
      ;+  ?:  =(~ addr-txs)
            ;div.p3.b2.br2.tc.f3.s-1: No transactions
          ;div.fc.g1(style "flex: 1; min-height: 0; overflow-y: auto;")
            ;*  =/  akh  akh
                %+  turn  addr-txs
                |=  =transaction
                ^-  manx
                =/  is-incoming=?
                  %+  lien  outputs.transaction
                  |=(=tx-output =(address.tx-output addr.dat))
                =/  is-outgoing=?
                  %+  lien  inputs.transaction
                  |=  =tx-input
                  ?~  prevout.tx-input  %.n
                  =(address.u.prevout.tx-input addr.dat)
                =/  direction=tape
                  ?:  &(is-incoming is-outgoing)  "↕ Self"
                  ?:(is-incoming "↓ Recv" "↑ Send")
                =/  dir-color=tape
                  ?:  &(is-incoming is-outgoing)  "#888"
                  ?:(is-incoming "#10b981" "#ef4444")
                =/  recv-amt=@ud
                  %+  roll  outputs.transaction
                  |=  [=tx-output total=@ud]
                  ?.  =(address.tx-output addr.dat)  total
                  (add total value.tx-output)
                =/  send-amt=@ud
                  %+  roll  inputs.transaction
                  |=  [=tx-input total=@ud]
                  ?~  prevout.tx-input  total
                  ?.  =(address.u.prevout.tx-input addr.dat)  total
                  (add total value.u.prevout.tx-input)
                =/  net-text=tape
                  ?:  (gte recv-amt send-amt)
                    "+{(format-sats (sub recv-amt send-amt))}"
                  "-{(format-sats (sub send-amt recv-amt))}"
                ;div.p3.b2.br2(style "display: flex; justify-content: space-between; align-items: center;")
                  ;div(style "min-width: 0; flex: 1;")
                    ;div(style "display: flex; align-items: center; gap: 8px;")
                      ;span.s-1.bold(style "color: {dir-color};"): {direction}
                      ;a.mono.s-2.f2(href "/groundwire/wallet/a/{akh}/tx/{(trip txid.transaction)}", style "white-space: nowrap; overflow: hidden; text-overflow: ellipsis; color: var(--f2); text-decoration: none; display: flex; align-items: center; gap: 4px;")
                        ;span(style "overflow: hidden; text-overflow: ellipsis;"): {(truncate-txid txid.transaction)}
                        ;div(style "width: 12px; height: 12px; display: flex; align-items: center; justify-content: center; flex-shrink: 0;")
                          ;+  (make:fi 'external-link')
                        ==
                      ==
                      ;+  ?-  -.tx-status.transaction
                              %confirmed
                            ;span.s-2(style "color: #10b981; font-size: 11px;"): ✓ block {(a-co:co block-height.tx-status.transaction)}
                              %unconfirmed
                            ;span.s-2(style "color: #f59e0b; font-size: 11px;"): ○ pending
                          ==
                    ==
                    ;div.f3.s-2(style "display: flex; gap: 12px; margin-top: 2px;")
                      ;span: {(a-co:co (lent inputs.transaction))} in → {(a-co:co (lent outputs.transaction))} out
                      ;+  ?~  fee.transaction  ;span;
                          ;span: fee: {(format-sats u.fee.transaction)}
                    ==
                  ==
                  ;span.mono.s-1.bold(style "color: {dir-color}; white-space: nowrap;"): {net-text} sats
                ==
          ==
    ==
  ==
::  +tx-detail-page: render transaction detail from inline data
::
++  tx-detail-page
  |=  [tx=transaction addr-idx=@ud addr-chain=?(%recv %chng) dat=address-data tx-net=network:wt akh=tape txs=tx-map]
  ^-  manx
  =/  txid-text=tape  (trip txid.tx)
  =/  confirmed=?  ?=(%confirmed -.tx-status.tx)
  =/  block-height=(unit @ud)
    ?:(?=(%unconfirmed -.tx-status.tx) ~ `block-height.tx-status.tx)
  =/  fee=@ud  (fall fee.tx 0)
  =/  size=@ud  (fall size.tx 0)
  =/  network-label=tape
    ?-(tx-net %main "Mainnet", %testnet3 "Testnet3", %testnet4 "Testnet4", %signet "Signet", %regtest "Regtest")
  =/  status-color=tape  ?:(confirmed "rgba(50, 200, 100, 0.3)" "rgba(255, 180, 50, 0.3)")
  =/  status-text=tape  ?:(confirmed "Confirmed" "Unconfirmed")
  =/  indexed-outputs=(list [vout-index=@ud output=tx-output])
    =/  idx=@ud  0
    =/  outs=(list tx-output)  outputs.tx
    |-  ^-  (list [vout-index=@ud output=tx-output])
    ?~  outs  ~
    [[idx i.outs] $(outs t.outs, idx +(idx))]
  =/  utxo-set=(set [@t @ud])
    %-  ~(gas in *(set [@t @ud]))
    (turn utxos.dat |=(=utxo [txid.utxo vout.utxo]))
  =/  known-txids=(set @t)  ~(key by txs)
  ;html
    ;head
      ;title: Transaction: {(scag 12 txid-text)}...
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;+  feather:feather
      ;style
        ;+  ;/  addr-style-text
      ==
    ==
    ;body
      ;div(style "min-width: 650px; height: 100%;")
        ;div.fc.g3.p5.ma.mw-page(style "height: 100%; overflow-y: auto;")
          ;script
            ;+  ;/  tx-script-text
          ==
          ;a.hover.pointer(id "back-link", href "#", onclick "goBackToAddr(); return false;", style "color: var(--f3); text-decoration: none;"): ← Back to Address
          ;div(style "display: flex; align-items: center; gap: 8px;")
            ;h1: Transaction Details
            ;span.s-2.f3(style "background: var(--b2); padding: 2px 8px; border-radius: 4px;"): {network-label}
          ==
          ::  Transaction ID
          ;div.p3.b2.br2
            ;div.f3.s-2.pb2: Transaction ID
            ;div(style "display: flex; align-items: center; gap: 8px;")
              ;div.mono.f2(style "overflow: hidden; text-overflow: ellipsis; white-space: nowrap; flex: 1;"): {txid-text}
              ;button.p1.b0.br1.hover.pointer
                =data-txid  txid-text
                =onclick  "copyToClipboard(this.dataset.txid)"
                =title  "Copy transaction ID"
                =style  "background: transparent; border: 1px solid var(--b3); color: var(--f3); display: flex; align-items: center; width: 24px; height: 24px; justify-content: center; outline: none;"
                ;div(style "width: 12px; height: 12px; display: flex; align-items: center; justify-content: center;")
                  ;+  (make:fi 'copy')
                ==
              ==
            ==
          ==
          ::  Transaction Info
          ;div.p3.b2.br2
            ;div.f3.s-2.pb2: Transaction Info
            ;div(style "display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 16px;")
              ;div
                ;div.f3.s-1(style "opacity: 0.8; margin-bottom: 4px;"): Status
                ;span.f3.s-2.p2.br1(style "background: {status-color}; display: inline-block;"): {status-text}
              ==
              ;div
                ;div.f3.s-1(style "opacity: 0.8; margin-bottom: 4px;"): Block
                ;+  ?~  block-height
                      ;div.f3: Pending
                    ;div.f3: {(a-co:co u.block-height)}
              ==
              ;div
                ;div.f3.s-1(style "opacity: 0.8; margin-bottom: 4px;"): Fee
                ;div.f3: {(format-sats fee)} sats
              ==
              ;div
                ;div.f3.s-1(style "opacity: 0.8; margin-bottom: 4px;"): Size
                ;div.f3: {(a-co:co size)} bytes
              ==
            ==
          ==
          ::  Inputs
          ;div.p3.b2.br2
            ;div.f3.s-2.pb2: Inputs ({(a-co:co (lent inputs.tx))})
            ;div(style "max-height: 400px; overflow-y: auto;")
              ;div.fc.g2
                ;*  =/  akh  akh
                %+  turn  inputs.tx
                    |=  =tx-input
                    ^-  manx
                    =/  in-txid=tape  (trip spent-txid.tx-input)
                    =/  vout=@ud  spent-vout.tx-input
                    ?~  prevout.tx-input
                      ;div.p3.b1.br2(style "display: flex; justify-content: space-between; align-items: center;")
                        ;span.f3(style "opacity: 0.5;"): [Prevout data not available]
                      ==
                    =/  value=@ud  value.u.prevout.tx-input
                    =/  address=tape  (trip address.u.prevout.tx-input)
                    =/  is-ours=?  =(address.u.prevout.tx-input addr.dat)
                    ;div.p3.b1.br2(style "display: flex; justify-content: space-between; align-items: center; gap: 12px;")
                      ;div(style "flex: 1; min-width: 0;")
                        ;div(style "display: flex; align-items: center; gap: 8px; margin-bottom: 8px;")
                          ;button.p1.b0.br1.hover.pointer
                            =data-txid  in-txid
                            =onclick  "copyToClipboard(this.dataset.txid)"
                            =title  "Copy transaction ID"
                            =style  "background: transparent; border: 1px solid var(--b3); color: var(--f3); display: flex; align-items: center; width: 24px; height: 24px; justify-content: center; outline: none; flex-shrink: 0;"
                            ;div(style "width: 12px; height: 12px; display: flex; align-items: center; justify-content: center;")
                              ;+  (make:fi 'copy')
                            ==
                          ==
                          ;+  ?:  (~(has in known-txids) spent-txid.tx-input)
                                ;a.mono.f2.s-1(href "/groundwire/wallet/a/{akh}/tx/{in-txid}", style "white-space: nowrap; overflow: hidden; text-overflow: ellipsis; color: var(--f2); text-decoration: none; display: flex; align-items: center; gap: 4px; flex: 1; min-width: 0;")
                                  ;span(style "overflow: hidden; text-overflow: ellipsis;"): {(truncate-txid (crip in-txid))}:{(a-co:co vout)}
                                  ;div(style "width: 12px; height: 12px; display: flex; align-items: center; justify-content: center; flex-shrink: 0;")
                                    ;+  (make:fi 'external-link')
                                  ==
                                ==
                              ;div.mono.f2.s-1(style "white-space: nowrap; overflow: hidden; text-overflow: ellipsis; color: var(--f3); flex: 1; min-width: 0;"): {(truncate-txid (crip in-txid))}:{(a-co:co vout)}
                        ==
                        ;div(style "display: flex; align-items: center; gap: 8px;")
                          ;button.p1.b0.br1.hover.pointer
                            =data-addr  address
                            =onclick  "copyToClipboard(this.dataset.addr)"
                            =title  "Copy address"
                            =style  "background: transparent; border: 1px solid var(--b3); color: var(--f3); display: flex; align-items: center; width: 24px; height: 24px; justify-content: center; outline: none; flex-shrink: 0;"
                            ;div(style "width: 12px; height: 12px; display: flex; align-items: center; justify-content: center;")
                              ;+  (make:fi 'copy')
                            ==
                          ==
                          ;+  ?:  is-ours
                                ;a.mono.f2.s-1(href "/groundwire/wallet/a/{akh}/addr/{(trip addr-chain)}/{(scow %ud addr-idx)}", style "white-space: nowrap; overflow: hidden; text-overflow: ellipsis; color: #10b981; text-decoration: none; flex: 1; min-width: 0;"): {address}
                              ;span.mono.f2.s-1(style "white-space: nowrap; overflow: hidden; text-overflow: ellipsis; color: var(--f3); flex: 1; min-width: 0;"): {address}
                        ==
                      ==
                      ;div.f3.s-2(style "white-space: nowrap; flex-shrink: 0;"): {(format-sats value)} sats
                    ==
              ==
            ==
          ==
          ::  Outputs
          ;div.p3.b2.br2
            ;div.f3.s-2.pb2: Outputs ({(a-co:co (lent outputs.tx))})
            ;div(style "max-height: 400px; overflow-y: auto;")
              ;div.fc.g2
                ;*  =/  akh  akh
                %+  turn  indexed-outputs
                    |=  [vout-index=@ud output=tx-output]
                    ^-  manx
                    =/  value=@ud  value.output
                    =/  address=tape  (trip address.output)
                    =/  is-ours=?  =(address.output addr.dat)
                    =/  is-utxo=?
                      (~(has in utxo-set) [txid.tx vout-index])
                    =/  row-bg=tape
                      ?:(is-utxo "background: rgba(255, 200, 50, 0.15);" "background: var(--b1);")
                    ;div.p3.b1.br2(style "display: flex; justify-content: space-between; align-items: center; gap: 12px; {row-bg}")
                      ;div(style "flex: 1; min-width: 0;")
                        ;div(style "display: flex; align-items: center; gap: 8px;")
                          ;button.p1.b0.br1.hover.pointer
                            =data-addr  address
                            =onclick  "copyToClipboard(this.dataset.addr)"
                            =title  "Copy address"
                            =style  "background: transparent; border: 1px solid var(--b3); color: var(--f3); display: flex; align-items: center; width: 24px; height: 24px; justify-content: center; outline: none; flex-shrink: 0;"
                            ;div(style "width: 12px; height: 12px; display: flex; align-items: center; justify-content: center;")
                              ;+  (make:fi 'copy')
                            ==
                          ==
                          ;span.f3.s-2.mono(style "opacity: 0.8; white-space: nowrap; flex-shrink: 0;"): Output #{(a-co:co vout-index)}
                          ;+  ?:  is-ours
                                ;a.mono.f2.s-1(href "/groundwire/wallet/a/{akh}/addr/{(trip addr-chain)}/{(scow %ud addr-idx)}", style "white-space: nowrap; overflow: hidden; text-overflow: ellipsis; color: #10b981; text-decoration: none; flex: 1; min-width: 0;"): {address}
                              ;span.mono.f2.s-1(style "white-space: nowrap; overflow: hidden; text-overflow: ellipsis; color: var(--f3); flex: 1; min-width: 0;"): {address}
                        ==
                      ==
                      ;div(style "display: flex; align-items: center; gap: 8px; flex-shrink: 0;")
                        ;+  ?:  is-utxo
                              ;div(style "width: 14px; height: 14px; display: flex; align-items: center; justify-content: center;", title "UTXO")
                                ;+  (make:fi 'star')
                              ==
                            ;div;
                        ;div.f3.s-2(style "white-space: nowrap;"): {(format-sats value)} sats
                      ==
                    ==
              ==
            ==
          ==
        ==
      ==
    ==
  ==
::
++  addr-style-text
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
  """
::
++  tx-script-text
  ^-  tape
  """
  var path = window.location.pathname;

  function goBackToAddr() \{
    var m = path.match(/^(\\/groundwire\\/wallet\\/a\\/[^/]+)/);
    if (m) \{
      window.location.href = m[1];
    } else \{
      history.back();
    }
  }

  function copyToClipboard(text) \{
    navigator.clipboard.writeText(text);
  }
  """
::
++  addr-script-text
  |=  [acct-ref=tape chain=tape idx=tape]
  ^-  tape
  """
  var API = '/grubbery/api';
  var mainSig = 'apps/wallet.wallet_app/main.sig';
  var acctRef = '{acct-ref}';

  function goBack() \{
    var path = window.location.pathname;
    var m = path.match(/^\\/groundwire\\/wallet\\/a\\/([^/]+)/);
    if (m) \{
      window.location.href = '/groundwire/wallet/a/' + m[1];
    } else \{
      history.back();
    }
  }

  function copyToClipboard(text) \{
    navigator.clipboard.writeText(text);
  }

  function doRefresh() \{
    var url = API + '/poke/' + mainSig + '?blot=/json';
    fetch(url, \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(\{action: 'refresh', account: acctRef, chain: '{chain}', index: {idx}})
    }).then(function(r) \{
      if (!r.ok) return r.text().then(function(t) \{ console.error('refresh error', t) });
    }).catch(function(e) \{ console.error('refresh failed', e) });
  }

  function connectSSE() \{
    var path = window.location.pathname;
    var url = path + (path.endsWith('/') ? 'stream' : '/stream');
    var es = new EventSource(url);
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
::
++  seed-to-xpub
  |=  =seed
  ^-  @t
  =/  seed-bytes=byts
    ?-  -.seed
      %t  64^(to-seed:bip39 (trip phrase.seed) "")
      %q  =/  val=@  `@`secret.seed
          [(met 3 val) val]
    ==
  (crip (pub-extended:(from-seed:bip32 seed-bytes) %main))
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
  |=  [xprv=@t =script-type network=?(%main %testnet3 %testnet4 %signet %regtest) chain=@ud index=@ud]
  ^-  (unit @t)
  =/  acct-key  (from-extended:bip32 (trip xprv))
  =/  chain-key  (derive:acct-key chain)
  =/  addr-key  (derive:chain-key index)
  =/  pubkey=@  public-key:addr-key
  =/  bip-net  (to-bip-network:wt network)
  ?-  script-type
    %p2wpkh      (encode-pubkey:bech32 bip-net [33 pubkey])
    %p2tr        (encode-taproot:bech32 bip-net [32 (end [3 32] pubkey)])
    %p2pkh       ~
    %p2sh-p2wpkh  ~
  ==
::
++  discover-check-chain
  |=  [xprv=@t =script-type network=?(%main %testnet3 %testnet4 %signet %regtest) chain=@ud]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  gap-limit=@ud  20
  =/  idx=@ud  0
  =/  gap=@ud  0
  =/  found=?  %.n
  |-
  ?:  (gte gap gap-limit)  (pure:m found)
  =/  addr=(unit @t)  (derive-acct-addr xprv script-type network chain idx)
  ?~  addr  (pure:m found)
  =/  url=@t  (crip (weld (disc-mempool-url network) (trip u.addr)))
  ;<  ~  bind:m  (send-request:io [%'GET' url ~[['Accept' 'application/json']] ~])
  ;<  resp=client-response:iris  bind:m  disc-take-http
  =/  tc=@ud  (disc-parse-tx-count resp)
  ;<  ~  bind:m  (sleep:io `@dr`(div ~s1 1.000))
  ?:  (gth tc 0)
    $(idx +(idx), gap 0, found %.y)
  $(idx +(idx), gap +(gap))
::
++  disc-mempool-url
  |=  network=?(%main %testnet3 %testnet4 %signet %regtest)
  ^-  tape
  ?-  network
    %main      "https://mempool.space/api/address/"
    %testnet3  "https://mempool.space/testnet/api/address/"
    %testnet4  "https://mempool.space/testnet4/api/address/"
    %signet    "https://mempool.space/signet/api/address/"
    %regtest   "http://localhost:3000/address/"
  ==
::
++  disc-take-http
  =/  m  (fiber:fiber:nexus ,client-response:iris)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %poke * *]
    ?.  =([/ %http-response] p.sage.u.in)  [%skip ~]
    =/  resp=client-response:iris  !<(client-response:iris q.sage.u.in)
    [%done resp]
  ==
::
++  disc-parse-tx-count
  |=  =client-response:iris
  ^-  @ud
  ?.  ?=(%finished -.client-response)  0
  ?~  full-file.client-response  0
  =/  body=@t  q.data.u.full-file.client-response
  =/  parsed=(each json tang)  (mule |.((need (de:json:html body))))
  ?:  ?=(%| -.parsed)  0
  (fall (mole |.((ni:dejs:format (~(got jo:json-utils p.parsed) /'chain_stats'/'tx_count')))) 0)
::
++  form-args-to-json
  |=  args=key-value-list:kv:html-utils
  ^-  json
  :-  %o
  %-  ~(gas by *(map @t json))
  %+  turn  args
  |=  [k=@t v=@t]
  [k s+v]
::
::  +make-dev-wallet: create wallet + account data for dev/init
::
++  make-dev-wallet
  |=  [name=@t =seed network=network:wt]
  =/  seed-bytes=byts
    ?-  -.seed
      %t  64^(to-seed:bip39 (trip phrase.seed) "")
      %q  =/  val=@  `@`secret.seed  [(met 3 val) val]
    ==
  =/  master  (from-seed:bip32 seed-bytes)
  =/  fp=@ux  fingerprint:master
  =/  coin=@ud  ?:(=(%main network) 0 1)
  =/  derived  (derive-path:master "m/84'/{(scow %ud coin)}'/0'")
  =/  bip-net  (to-bip-network:wt network)
  =/  xprv=@t  (crip (prv-extended:derived bip-net))
  =/  acct-xpub=@t  (crip (pub-extended:derived bip-net))
  =/  master-xpub=@t  (crip (pub-extended:master bip-net))
  =/  wal=wallet-data  [seed master-xpub]
  =/  =script-type  %p2wpkh
  =/  og=parsed-origin:b329
    [(to-descriptor:b329 script-type) fp ~[[%.y 84] [%.y coin] [%.y 0]]]
  [wal master-xpub acct-xpub xprv network script-type og]
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
  |=  [wals=(list wallet-data) =labels:b329]
  ^-  manx
  ?~  wals
    ;div.p4.b1.br2.tc
      ;div.s0.f2.mb2: No wallets yet
      ;div.f3.s-1: Generate a new wallet or restore from a seed phrase below
    ==
  =/  named=(list [wal=wallet-data wal-name=@t])
    %+  turn  wals
    |=(w=wallet-data [w (get-wallet-name:aio labels xpub.w)])
  =/  sorted=(list [wal=wallet-data wal-name=@t])
    (sort named |=([a=[wallet-data @t] b=[wallet-data @t]] (aor +.a +.b)))
  ;div.fc.g2
    ;*  (turn sorted wallet-card)
  ==
::  page rendering
::
++  wallet-page
  |=  [nexus-root=tape wals=(list wallet-data) =labels:b329 =secrets]
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
            ;+  (tab-container wals labels secrets)
          ==
        ==
      ==
      ;+  delete-modal
      ;script
        ;+  ;/  (script-text nexus-root)
      ==
    ==
  ==
::
++  tab-container
  |=  [wals=(list wallet-data) =labels:b329 =secrets]
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
        ;+  (wallets-panel wals labels)
      ==
      ;div#content-watch.tab-content(style "display: none;")
        ;+  (watch-only-panel labels secrets)
      ==
      ;div#content-signing.tab-content(style "display: none;")
        ;+  (signing-panel labels secrets)
      ==
    ==
  ==
::  Full Wallets tab
::
++  wallets-panel
  |=  [wals=(list wallet-data) =labels:b329]
  ^-  manx
  ;div.fc.g2(style "flex: 1; min-height: 0;")
    ;div#wallet-list-container.p4.b0.br2(style "flex: 1; min-height: 0; overflow-y: auto;")
      ;+  (wallet-list-html wals labels)
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
  |=  [wal=wallet-data wal-name=@t]
  ^-  manx
  =/  wallet-key=tape  (trip xpub.wal)
  =/  detail-url=tape
    "/groundwire/wallet/w/{wallet-key}"
  ;div.p3.b1.br2.hover.pointer
    =onclick  "window.location.href='{detail-url}'"
    =style  "display: flex; justify-content: space-between; align-items: center; gap: 12px;"
    ;div(style "flex: 1; min-width: 0;")
      ;div.s0.bold.mb-1: {(trip wal-name)}
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
      =data-wallet-name  (trip wal-name)
      =data-pubkey  (trip xpub.wal)
      =onclick  "event.stopPropagation(); showDeleteModal(this.dataset.walletName, this.dataset.pubkey)"
      =style  "background: var(--b2); border: 1px solid var(--b3); color: var(--f3); display: flex; align-items: center; width: 32px; height: 32px; justify-content: center; outline: none; flex-shrink: 0;"
      ;div(style "width: 16px; height: 16px; display: flex; align-items: center; justify-content: center;")
        ;+  (make:fi 'trash-2')
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
::  Standalone account card (watch-only or signing)
::
++  standalone-card
  |=  [=labels:b329 =secrets ref=@t mode=@t]
  ^-  manx
  =/  acct-name=@t  (get-acct-name:aio labels ref)
  =/  network=network  (get-acct-network:aio labels ref)
  =/  stype=script-type  (get-acct-script-type:aio labels ref)
  =/  is-signing=?  =(mode 'signing')
  =/  display-key=@t  ?:(is-signing (fall (~(get by xprvs.secrets) ref) ref) ref)
  =/  copy-title=tape  ?:(is-signing "Copy xprv" "Copy xpub")
  ;div.p3.b1.br2.hover(style "display: flex; justify-content: space-between; align-items: center; gap: 12px; outline: none;")
    ;a(href "/groundwire/wallet/a/{(trip ref)}/", style "flex: 1; min-width: 0; text-decoration: none; color: inherit; outline: none !important;")
      ;div(style "display: flex; align-items: center; gap: 8px; margin-bottom: 4px;")
        ;+  (script-type-badge stype)
        ;span.s0.bold: {(trip acct-name)}
      ==
      ;div(style "display: flex; align-items: center; gap: 8px;")
        ;+  (network-badge:acct-ui network)
        ;button.p1.b0.br1.hover.pointer
          =data-key  (trip display-key)
          =onclick  "event.preventDefault(); event.stopPropagation(); copyToClipboard(this.dataset.key);"
          =style  "background: transparent; border: 1px solid var(--b3); color: var(--f3); display: flex; align-items: center; width: 24px; height: 24px; justify-content: center; outline: none;"
          =title  copy-title
          ;div(style "width: 12px; height: 12px; display: flex; align-items: center; justify-content: center;")
            ;+  (make:fi 'copy')
          ==
        ==
        ;div.f3.s-2.f2(style "font-family: monospace; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; flex: 1;"): {(trip display-key)}
      ==
    ==
    ;button.p2.b1.br1.hover.pointer
      =onclick  "event.preventDefault(); event.stopPropagation(); deleteStandalone('{(trip acct-name)}', '{(trip ref)}');"
      =style  "background: var(--b2); border: 1px solid var(--b3); color: var(--f3); display: flex; align-items: center; width: 32px; height: 32px; justify-content: center; outline: none;"
      ;div(style "width: 16px; height: 16px; display: flex; align-items: center; justify-content: center;")
        ;+  (make:fi 'trash-2')
      ==
    ==
  ==
::  Script type badge (colored circle with BIP number)
::
++  script-type-badge
  |=  =script-type
  ^-  manx
  =/  [color=tape label=tape tooltip=tape]
    ?-  script-type
        %p2pkh         ["#6b7280" "44" "Legacy (BIP44) - P2PKH"]
        %p2sh-p2wpkh   ["#f59e0b" "49" "Wrapped SegWit (BIP49) - P2SH-P2WPKH"]
        %p2wpkh        ["#10b981" "84" "Native SegWit (BIP84) - P2WPKH"]
        %p2tr          ["#9333ea" "86" "Taproot (BIP86) - P2TR"]
    ==
  ;div(title "{tooltip}", style "display: inline-flex; align-items: center; justify-content: center; width: 18px; height: 18px; border-radius: 50%; background: {color}; color: white; font-size: 10px; font-weight: bold; font-family: monospace; cursor: default;"): {label}
::  Watch-Only tab
::
++  watch-only-panel
  |=  [=labels:b329 =secrets]
  ^-  manx
  =/  all-refs=(list @t)
    %+  murn  ~(tap by xpub.labels)
    |=  [ref=@t *]
    ^-  (unit @t)
    ?.  (has-account:aio labels ref)  ~
    ?:  ?=(^ (get-acct-origin:aio labels ref))  ~
    ?:  (~(has by xprvs.secrets) ref)  ~
    `ref
  =/  list-content=manx
    ?~  all-refs
      ;div.p4.b1.br2.tc
        ;div.s0.f2.mb2: No watch-only accounts yet
        ;div.f3.s-1: Import xpubs or addresses to track balances
      ==
    ;div.fc.g2
      ;*  (turn all-refs |=(ref=@t (standalone-card labels secrets ref %'watch-only')))
    ==
  ;div.fc.g2(style "flex: 1; min-height: 0;")
    ;div#watch-only-list-container.p4.b0.br2(style "flex: 1; min-height: 0; overflow-y: auto;")
      ;+  list-content
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
  |=  [=labels:b329 =secrets]
  ^-  manx
  =/  all-refs=(list @t)
    %+  murn  ~(tap by xpub.labels)
    |=  [ref=@t *]
    ^-  (unit @t)
    ?.  (has-account:aio labels ref)  ~
    ?:  ?=(^ (get-acct-origin:aio labels ref))  ~
    ?.  (~(has by xprvs.secrets) ref)  ~
    `ref
  =/  list-content=manx
    ?~  all-refs
      ;div.p4.b1.br2.tc
        ;div.s0.f2.mb2: No signing accounts yet
        ;div.f3.s-1: Import private keys or connect hardware wallets
      ==
    ;div.fc.g2
      ;*  (turn all-refs |=(ref=@t (standalone-card labels secrets ref %signing)))
    ==
  ;div.fc.g2(style "flex: 1; min-height: 0;")
    ;div#signing-list-container.p4.b0.br2(style "flex: 1; min-height: 0; overflow-y: auto;")
      ;+  list-content
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
  |=  nexus-root=tape
  ^-  tape
  ;:  weld
  "var API = '/grubbery/api';\0a"
  "var BASE = '{(slag 1 nexus-root)}';\0a"
  """

  function poke(body, cb) \{
    var url = API + '/'+'poke/' + BASE + '/'+'main.sig?blot=/json';
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
      poke(data, function() \{ location.reload(); });
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
    poke(\{action: 'remove-wallet', pubkey: _deletePubkey, 'wallet-name': _deleteWalletName}, function() \{ location.reload(); });
    hideDeleteModal();
  }

  function deleteStandalone(name, ref) \{
    if (confirm('Delete account "' + name + '"? This cannot be undone.')) \{
      poke(\{'action': 'remove-account', 'account-key': ref}, function() \{ location.reload(); });
    }
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

  var SSE = API + '/'+'keep/' + BASE + '/'+'ui/sse?blot=/txt';
  var sseController = null;
  var sseReader = null;

  async function connectSSE() \{
    if (sseReader) try \{ sseReader.cancel(); } catch(e) \{}
    if (sseController) sseController.abort();
    sseController = new AbortController();
    try \{
      var r = await fetch(SSE, \{
        headers: \{Accept: 'text/event-stream'},
        signal: sseController.signal
      });
      sseReader = r.body.getReader();
      var dec = new TextDecoder();
      var buf = '';
      while (true) \{
        var chunk = await sseReader.read();
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
    } catch (e) \{
      if (e.name !== 'AbortError') \{
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
  ==
--
