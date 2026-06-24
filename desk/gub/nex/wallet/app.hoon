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
/&  man  ../../man/wallet/app/readme.md
=,  wt
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  =ver:loader  (get-ver:loader ball)
      ?+  ver  !!
          ?(~ [~ %0])
        =/  [wal=wallet-data wal-name=@t acct-dir=@ta acct-ball=ball:tarball]
          (make-dev-wallet 'Dev Wallet' [%t 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about'] %testnet4)
        =/  [fau-wal=wallet-data fau-name=@t fau-acct-dir=@ta fau-acct-ball=ball:tarball]
          (make-dev-wallet 'Fauceted Wallet' [%t 'injury idea term fox crop movie type critic hello inquiry lottery agree'] %testnet3)
        =/  init-lbls=labels:b329
          =/  l=labels:b329  *labels:b329
          =/  xpub1=@t  (scot %ux fingerprint.wal)
          =/  xpub2=@t  (scot %ux fingerprint.fau-wal)
          =.  l  (~(put la:b329 l) [%xpub xpub1 (rap 3 ~['gwbtc:wallet:' wal-name]) ~ ~ ~])
          (~(put la:b329 l) [%xpub xpub2 (rap 3 ~['gwbtc:wallet:' fau-name]) ~ ~ ~])
        =/  init-store=wallet-store
          %-  ~(gas by *wallet-store)
          ~[[fingerprint.wal seed.wal] [fingerprint.fau-wal seed.fau-wal]]
        %+  spin:loader  ball
        :~  (ver-row:loader 0)
            [%over %& [/ %'main.sig'] [[/ %sig] ~]]
            [%fall %& [/ %'labels.wallet_labels'] [[/wallet %labels] init-lbls]]
            [%fall %& [/ %'wallets.wallet_wallets'] [[/wallet %wallets] init-store]]
            [%fall %| /accounts empty-dir:loader]
            [%fall %| /proc empty-dir:loader]
            [%fall %& [/ui %'http.sig'] [[/ %sig] ~]]
            [%fall %| /ui/requests empty-dir:loader]
            [%fall %| (snoc /accounts acct-dir) (ball-to-bole:tarball acct-ball)]
            [%fall %| (snoc /accounts fau-acct-dir) (ball-to-bole:tarball fau-acct-ball)]
            [%over %& [/man %'readme.md'] [[/ %mime] man]]
        ==
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::  /accounts/*/data.wallet_account: per-account poke handler
          ::
          [[%accounts @ ~] %'data.wallet_account']
        (handle-account-data rail prod)
          ::  /main.sig: receive pokes for wallet actions
          ::
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%wallet /main: failed")
        ;<  ~  bind:m  ensure-simple-wallet
        ;<  ~  bind:m  ensure-public-poke
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
            ;<  store=wallet-store  bind:m  load-wallets
            ;<  ~  bind:m  (save-wallets (~(put by store) pubkey u.sd))
            =/  xpub=@t  (scot %ux pubkey)
            ;<  lbls=labels:b329  bind:m  load-labels
            =/  new-lbls=labels:b329
              (~(put la:b329 lbls) [%xpub xpub (rap 3 ~['gwbtc:wallet:' wallet-name]) ~ ~ ~])
            ;<  ~  bind:m  (save-labels new-lbls)
            $
              %'add-wallet-from-entropy'
            =/  wallet-name=@t
              (~(dog jo:json-utils jon) /wallet-name so:dejs:format)
            ;<  eny=@uvJ  bind:m  get-entropy:io
            =/  seed-phrase=cord
              (gen-seed:seed-phrases eny %128)
            =/  pubkey=@ux  (seed-to-pubkey [%t seed-phrase])
            ;<  store=wallet-store  bind:m  load-wallets
            ;<  ~  bind:m  (save-wallets (~(put by store) pubkey [%t seed-phrase]))
            =/  xpub=@t  (scot %ux pubkey)
            ;<  lbls=labels:b329  bind:m  load-labels
            =/  new-lbls=labels:b329
              (~(put la:b329 lbls) [%xpub xpub (rap 3 ~['gwbtc:wallet:' wallet-name]) ~ ~ ~])
            ;<  ~  bind:m  (save-labels new-lbls)
            $
              %'remove-wallet'
            =/  pubkey=@t
              (~(dog jo:json-utils jon) /pubkey so:dejs:format)
            =/  fp=@ux  (slav %ux pubkey)
            ;<  store=wallet-store  bind:m  load-wallets
            ;<  ~  bind:m  (save-wallets (~(del by store) fp))
            $
              %'add-account'
            =/  wallet-key=@t
              (~(dog jo:json-utils jon) /wallet-key so:dejs:format)
            =/  fp=@ux  (slav %ux wallet-key)
            ;<  store=wallet-store  bind:m  load-wallets
            =/  sd=(unit seed)  (~(get by store) fp)
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
            =/  =script-type  (purpose-to-script purpose)
            =/  network=?(%main %testnet3 %testnet4 %signet %regtest)
              ?:  =(1 coin-type)  %testnet3  %main
            =/  master  (from-seed:bip32 (seed-to-bytes u.sd))
            =/  pax=tape
              "m/{(scow %ud purpose)}'/{(scow %ud coin-type)}'/{(scow %ud account-idx)}'"
            =/  derived  (derive-path:master pax)
            =/  xprv=@t  (crip (prv-extended:derived (to-bip-network:wt network)))
            =/  acct=account-data
              [account-name fp script-type network [%.y purpose] [%.y coin-type] [%.y account-idx] xprv]
            =/  acct-pubkey=@ux  public-key:derived
            =/  acct-key=@ta  (crip (hexn:http-utils acct-pubkey))
            =/  acct-dir=@ta  (cat 3 acct-key '.wallet_account')
            =/  acct-contents=(map @ta [=sang:tarball gain=? bang=(unit tang)])
              (~(put by *(map @ta [=sang:tarball gain=? bang=(unit tang)])) %'data.wallet_account' [[[/wallet %account] %& !>(acct)] %.n ~])
            =/  acct-lump=lump:tarball  [~ ~ %.n ~ acct-contents]
            =/  acct-ball=ball:tarball  [`acct-lump ~]
            ;<  acct-rd=road:tarball  bind:m  (wr [%| (snoc /accounts acct-dir)])
            ;<  err=(unit tang)  bind:m
              (make-soft:io acct-rd &+(ball-to-bole:tarball acct-ball))
            ?^  err
              ~&  >>>  [%wallet %add-account-failed]
              $
            $
              %'remove-account'
            =/  acct-key=@t
              (~(dog jo:json-utils jon) /account-key so:dejs:format)
            =/  acct-dir=@ta  (cat 3 (crip (trip acct-key)) '.wallet_account')
            ;<  acct-rd=road:tarball  bind:m  (wr [%| (snoc /accounts acct-dir)])
            ;<  err=(unit tang)  bind:m  (cull-soft:io acct-rd)
            ?^  err
              ~&  >>>  [%wallet %remove-account-failed]
              $
            $
              %'discover-accounts'
            =/  wallet-key=@t
              (~(dog jo:json-utils jon) /wallet-key so:dejs:format)
            =/  fp-key=@ta  (crip (trip wallet-key))
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
              ==
            ;<  eny=@uvJ  bind:m  get-entropy:io
            =/  disc-uuid=@ta  (scot %uv eny)
            ;<  disc-rd=road:tarball  bind:m  (wr [%& /proc (cat 3 disc-uuid '.json')])
            ;<  ~  bind:m  (make:io disc-rd |+[[[/ %json] disc-json] ~])
            $
              %'address-request'
            ::  foreign ship asks us for a receive address
            =/  src=(unit @p)  (get-poke-src:io from)
            ?~  src
              ~&  >  [%wallet %address-request %no-remote-src]
              $
            =/  req-net=@t
              (~(dug jo:json-utils jon) /network so:dejs:format 'testnet3')
            ;<  lbls=labels:b329  bind:m  load-labels
            ;<  sa=(unit [key=@ta acct=account-data])  bind:m
              (get-simple-account lbls req-net)
            ?~  sa
              ~&  >>>  [%wallet %address-request %no-simple-account]
              $
            =/  acct-key=@ta  key.u.sa
            =/  acct=account-data  acct.u.sa
            ;<  recv=addr-mop  bind:m  (load-addr-mop acct-key active-network.acct %recv)
            =/  offer-idx=@ud
              (get-next-offer-index:aio recv lbls xprv.acct)
            =/  addr=(unit @t)
              (derive-addr:aio xprv.acct script-type.acct active-network.acct 0 offer-idx)
            ?~  addr
              ~&  >>>  [%wallet %address-request %derivation-failed]
              $
            ~&  [%wallet %address-request %offering (scow %p u.src) u.addr offer-idx]
            =/  lbl=@t  (rap 3 ~['gwbtc:offered:to:' (scot %p u.src)])
            =/  new-lbls=labels:b329
              (~(put la:b329 lbls) [%addr u.addr lbl ~ ~ ~])
            =/  new-lbls=labels:b329
              (set-last-offered:aio new-lbls xprv.acct offer-idx)
            ;<  ~  bind:m  (save-labels new-lbls)
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
            ;<  lbls=labels:b329  bind:m  load-labels
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
            ;<  ~  bind:m  (save-labels new-lbls)
            ::  append to offer log
            =/  log-road=road:tarball
              [%& %& /apps/'wallet.wallet_app' %'offer-log.json']
            ;<  log-seen=seen:nexus  bind:m  (peek:io log-road ~)
            =/  cur-log=json
              ?.  ?=([%& %file *] log-seen)  [%a ~]
              (fall (mole |.(!<(json (need-vase:tarball sang.p.log-seen)))) [%a ~])
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
              %'refresh-account'
            ::  spawn refresh procs for all addresses in an account
            =/  acct-key=@ta
              (~(dog jo:json-utils jon) /account so:dejs:format)
            ;<  acct=(unit account-data)  bind:m  (load-account acct-key)
            ?~  acct
              ~&  >>>  [%wallet %refresh-account %not-found acct-key]
              $
            =/  net  active-network.u.acct
            ;<  recv=addr-mop  bind:m  (load-addr-mop acct-key net %recv)
            ;<  chng=addr-mop  bind:m  (load-addr-mop acct-key net %chng)
            =/  refresh-list=(list [chain=?(%recv %chng) idx=@ud])
              %-  weld
              :_  ^-  (list [?(%recv %chng) @ud])
                  %+  turn  (tap:((on @ud address-data) gth) chng)
                  |=([idx=@ud *] [%chng idx])
              ^-  (list [?(%recv %chng) @ud])
              %+  turn  (tap:((on @ud address-data) gth) recv)
              |=([idx=@ud *] [%recv idx])
            ;<  now=@da  bind:m  get-time:io
            |-
            ?~  refresh-list  $
            =/  [chain=?(%recv %chng) idx=@ud]  i.refresh-list
            ;<  eny=@uvJ  bind:m  get-entropy:io
            =/  uuid=@ta  (scot %uv eny)
            ;<  proc-road=road:tarball  bind:m  (wr [%& /proc (cat 3 uuid '.json')])
            =/  proc-json=json
              %-  pairs:enjs:format
              :~  ['type' s+'refresh']
                  ['account' s+acct-key]
                  ['network' s+net]
                  ['chain' s+chain]
                  ['index' (numb:enjs:format idx)]
              ==
            ;<  ~  bind:m  (make:io proc-road |+[[[/ %json] proc-json] ~])
            $(refresh-list t.refresh-list)
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
          ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
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
          ;<  store=wallet-store  bind:m  load-wallets
          ;<  lbls=labels:b329  bind:m  load-labels
          =/  wals=(list wallet-data)  (store-to-list store)
          ;<  ~  bind:m  (send-html eyre-id (wallet-page nexus-root wals lbls))
          (pure:m ~)
        ::  route: /simple → simple wallet page
        ?:  ?=([%simple ~] suffix)
          ?:  ?=(%'GET' method.request.req)
            ;<  lbls=labels:b329  bind:m  ~>(%bout load-labels)
            ;<  simple-wal=(unit wallet-data)  bind:m  (get-simple-wallet lbls)
            =/  post-url=tape  "{(spud prefix)}/simple"
            ?~  simple-wal
              ::  auto-create simple wallet with testnet3 + mainnet accounts
              ;<  eny=@uvJ  bind:m  get-entropy:io
              =/  seed-phrase=cord  (gen-seed:seed-phrases eny %256)
              =/  [wal-t=wallet-data * adir-t=@ta ball-t=ball:tarball]
                (make-dev-wallet 'My Wallet' [%t seed-phrase] %testnet3)
              =/  [* * adir-m=@ta ball-m=ball:tarball]
                (make-dev-wallet 'My Wallet' [%t seed-phrase] %main)
              =/  wal=wallet-data  wal-t
              ;<  store=wallet-store  bind:m  load-wallets
              ;<  ~  bind:m  (save-wallets (~(put by store) fingerprint.wal seed.wal))
              ;<  acct-t-rd=road:tarball  bind:m  (wr [%| (snoc /accounts adir-t)])
              ;<  ~  bind:m  (make:io acct-t-rd &+(ball-to-bole:tarball ball-t))
              ;<  acct-m-rd=road:tarball  bind:m  (wr [%| (snoc /accounts adir-m)])
              ;<  ~  bind:m  (make:io acct-m-rd &+(ball-to-bole:tarball ball-m))
              =/  xpub=@t  (scot %ux fingerprint.wal)
              =/  new-lbls=labels:b329  (set-simple-wallet lbls xpub)
              =/  new-lbls=labels:b329
                (~(put la:b329 new-lbls) [%xpub xpub 'gwbtc:wallet:My Wallet' ~ ~ ~])
              ;<  ~  bind:m  (save-labels new-lbls)
              ;<  ~  bind:m
                (send-html eyre-id (simple-page:simp ~ '' ~ *addr-mop *addr-mop *tx-map post-url %.n ~["testnet3" "main"] 2 ~))
              (pure:m ~)
            =/  wal=wallet-data  u.simple-wal
            =/  wal-name=@t  (get-wallet-name lbls fingerprint.wal)
            =/  saved=?  (get-simple-saved lbls (scot %ux fingerprint.wal))
            ;<  accts=(list [key=@ta acct=account-data])  bind:m
              (load-wallet-accounts fingerprint.wal)
            =/  nets=(list tape)  (wallet-nets accts)
            =/  req-net=@t
              (fall (get-key:kv:html-utils 'net' args) 'testnet3')
            =/  acct-pair=(unit [key=@ta acct=account-data])
              (find-account-for-net accts req-net)
            ?~  acct-pair
              ;<  ~  bind:m
                (send-html eyre-id (simple-page:simp `wal wal-name ~ *addr-mop *addr-mop *tx-map post-url saved nets 2 ~))
              (pure:m ~)
            =/  acct-key=@ta  key.u.acct-pair
            =/  acct-ref=@t  (crip (scag (need (find "." (trip acct-key))) (trip acct-key)))
            =/  fee-rate=@ud  (get-simple-fee lbls acct-ref)
            =/  acct=account-data  acct.u.acct-pair
            ;<  recv=addr-mop  bind:m
              (load-addr-mop acct-key active-network.acct %recv)
            ;<  chng=addr-mop  bind:m
              (load-addr-mop acct-key active-network.acct %chng)
            ;<  txs=tx-map  bind:m
              (load-txs acct-key active-network.acct)
            ;<  contacts=(map @t (map @t json))  bind:m  load-contacts
            =/  page=manx  (simple-page:simp `wal wal-name `acct recv chng txs post-url saved nets fee-rate contacts)
            ;<  ~  bind:m  (send-html eyre-id page)
            (pure:m ~)
          ::  POST /simple → simple wallet actions
          =/  args=key-value-list:kv:html-utils  (parse-body:kv:html-utils body.request.req)
          =/  action=@t  (fall (get-key:kv:html-utils 'action' args) '')
          ?+    action
              ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Unknown action')])
              (pure:m ~)
              %'get-receive-address'
            =/  req-net=@t
              (fall (get-key:kv:html-utils 'net' args) 'testnet3')
            ;<  lbls=labels:b329  bind:m  load-labels
            ;<  sa=(unit [key=@ta acct=account-data])  bind:m
              (get-simple-account lbls req-net)
            ?~  sa
              ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html '')])
              (pure:m ~)
            =/  acct-key=@ta  key.u.sa
            =/  acct=account-data  acct.u.sa
            ;<  recv=addr-mop  bind:m
              (load-addr-mop acct-key active-network.acct %recv)
            ::  find local candidate: first addr with no/zero tx-count
            =/  candidate-idx=@ud
              =/  leaves=(list [@ud address-data])
                (tap:((on @ud address-data) gth) recv)
              |-
              ?~  leaves
                (lent (tap:((on @ud address-data) gth) recv))
              =/  [lidx=@ud dat=address-data]  i.leaves
              ?~  info.dat  lidx
              ?:  =(0 tx-count.u.info.dat)  lidx
              $(leaves t.leaves)
            ::  verify against mempool, advance if used
            (verify-receive-addr acct-key acct recv candidate-idx eyre-id)
              %'toggle-saved'
            ;<  lbls=labels:b329  bind:m  load-labels
            =/  fp=(unit @ux)  (get-simple-fp lbls)
            ?~  fp
              ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
              (pure:m ~)
            =/  xpub=@t  (scot %ux u.fp)
            =/  saved=?  (get-simple-saved lbls xpub)
            =/  new-lbls=labels:b329  (set-simple-saved lbls xpub !saved)
            ;<  ~  bind:m  (save-labels new-lbls)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
            (pure:m ~)
              %'refresh-wallet'
            ::  refresh all pending + next-unused addresses
            =/  req-net=@t
              (fall (get-key:kv:html-utils 'net' args) 'testnet3')
            ;<  lbls=labels:b329  bind:m  load-labels
            ;<  sa=(unit [key=@ta acct=account-data])  bind:m
              (get-simple-account lbls req-net)
            ?~  sa
              ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
              (pure:m ~)
            =/  acct-key=@ta  key.u.sa
            =/  acct=account-data  acct.u.sa
            =/  net=@ta  ;;(@ta active-network.acct)
            ;<  recv=addr-mop  bind:m  (load-addr-mop acct-key active-network.acct %recv)
            ;<  chng=addr-mop  bind:m  (load-addr-mop acct-key active-network.acct %chng)
            ::  collect addresses needing refresh: unconfirmed tx addrs + next unused
            ;<  txs=tx-map  bind:m  (load-txs acct-key active-network.acct)
            =/  refresh-list=(list [chain=?(%recv %chng) idx=@ud])
              ::  find addresses involved in unconfirmed transactions
              =/  unconf-addrs=(set @t)
                =/  txns=(list [txid=@t tx=transaction])  ~(tap by txs)
                =/  addrs=(set @t)  ~
                |-
                ?~  txns  addrs
                =/  tx=transaction  tx.i.txns
                ?.  ?=([%unconfirmed *] tx-status.tx)  $(txns t.txns)
                =/  out-addrs=(list @t)
                  (turn outputs.tx |=(o=tx-output address.o))
                =/  in-addrs=(list @t)
                  (murn inputs.tx |=(i=tx-input ?~(prevout.i ~ `address.u.prevout.i)))
                $(txns t.txns, addrs (~(gas in addrs) (weld out-addrs in-addrs)))
              ::  resolve unconfirmed addrs to chain/index via addr-mops
              =/  pending=(list [chain=?(%recv %chng) idx=@ud])
                %-  weld
                :_  ^-  (list [?(%recv %chng) @ud])
                    %+  murn  (tap:((on @ud address-data) gth) chng)
                    |=  [idx=@ud dat=address-data]
                    ?.  (~(has in unconf-addrs) addr.dat)  ~
                    `[%chng idx]
                ^-  (list [?(%recv %chng) @ud])
                %+  murn  (tap:((on @ud address-data) gth) recv)
                |=  [idx=@ud dat=address-data]
                ?.  (~(has in unconf-addrs) addr.dat)  ~
                `[%recv idx]
              ::  add next unused receiving index
              =/  next-recv=@ud
                =/  leaves=(list [@ud address-data])
                  (tap:((on @ud address-data) gth) recv)
                =/  found=(unit @ud)
                  |-
                  ?~  leaves  ~
                  =/  [lidx=@ud dat=address-data]  i.leaves
                  ?:  ?|  ?=(~ info.dat)
                          =(0 tx-count.u.info.dat)
                      ==
                    `lidx
                  $(leaves t.leaves)
                (fall found (lent (tap:((on @ud address-data) gth) recv)))
              =/  next-chng=@ud
                =/  leaves=(list [@ud address-data])
                  (tap:((on @ud address-data) gth) chng)
                =/  found=(unit @ud)
                  |-
                  ?~  leaves  ~
                  =/  [lidx=@ud dat=address-data]  i.leaves
                  ?:  ?|  ?=(~ info.dat)
                          =(0 tx-count.u.info.dat)
                      ==
                    `lidx
                  $(leaves t.leaves)
                (fall found (lent (tap:((on @ud address-data) gth) chng)))
              =/  all=(list [chain=?(%recv %chng) idx=@ud])
                :(weld pending `(list [?(%recv %chng) @ud])`~[[%recv next-recv]] `(list [?(%recv %chng) @ud])`~[[%chng next-chng]])
              ::  deduplicate
              =/  seen=(set [?(%recv %chng) @ud])  ~
              =/  out=(list [chain=?(%recv %chng) idx=@ud])  ~
              |-
              ?~  all  (flop out)
              ?:  (~(has in seen) i.all)  $(all t.all)
            $(all t.all, seen (~(put in seen) i.all), out [i.all out])
            ::  spawn refresh proc files
            ;<  now=@da  bind:m  get-time:io
            |-
            ?~  refresh-list
              ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
              (pure:m ~)
            =/  [chain=?(%recv %chng) idx=@ud]  i.refresh-list
            ;<  eny=@uvJ  bind:m  get-entropy:io
            =/  uuid=@ta  (scot %uv eny)
            ;<  proc-road=road:tarball  bind:m  (wr [%& /proc (cat 3 uuid '.json')])
            =/  proc-json=json
              %-  pairs:enjs:format
              :~  ['type' s+'refresh']
                  ['account' s+acct-key]
                  ['network' s+net]
                  ['chain' s+chain]
                  ['index' (numb:enjs:format idx)]
              ==
            ;<  ~  bind:m
              (make:io proc-road |+[[[/ %json] proc-json] ~])
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
            ;<  lbls=labels:b329  bind:m  load-labels
            ;<  sa=(unit [key=@ta acct=account-data])  bind:m
              (get-simple-account lbls req-net)
            ?~  sa
              ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
              (pure:m ~)
            =/  acct-key=@ta  key.u.sa
            =/  acct=account-data  acct.u.sa
            =/  net=@ta  ;;(@ta active-network.acct)
            ;<  eny=@uvJ  bind:m  get-entropy:io
            =/  uuid=@ta  (scot %uv eny)
            ;<  proc-road=road:tarball  bind:m  (wr [%& /proc (cat 3 uuid '.json')])
            =/  proc-json=json
              %-  pairs:enjs:format
              :~  ['type' s+'refresh']
                  ['account' s+acct-key]
                  ['network' s+net]
                  ['chain' s+chain]
                  ['index' (numb:enjs:format idx)]
              ==
            ;<  ~  bind:m
              (make:io proc-road |+[[[/ %json] proc-json] ~])
            ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
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
                (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Missing address or amount')])
              (pure:m ~)
            ;<  lbls=labels:b329  bind:m  load-labels
            ;<  sa=(unit [key=@ta acct=account-data])  bind:m
              (get-simple-account lbls req-net)
            ?~  sa
              ;<  ~  bind:m
                (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'No account for network')])
              (pure:m ~)
            =/  acct-key=@ta  key.u.sa
            =/  acct=account-data  acct.u.sa
            ::  find unused change address from mop, or derive one
            ;<  chng=addr-mop  bind:m
              (load-addr-mop acct-key active-network.acct %chng)
            =/  change-addr=(unit @t)
              =/  leaves=(list [@ud address-data])
                (tap:((on @ud address-data) gth) chng)
              |-
              ?~  leaves  ~
              =/  [* dat=address-data]  i.leaves
              ?~  info.dat  `addr.dat
              ?:  =(0 tx-count.u.info.dat)  `addr.dat
              $(leaves t.leaves)
            =/  change-addr=@t
              ?^  change-addr  u.change-addr
              ::  derive next change index in-memory
              =/  next-idx=@ud
                =/  top=(unit [@ud address-data])
                  (pry:((on @ud address-data) gth) chng)
                ?~  top  0
                +(-.u.top)
              %-  need
              %:  derive-addr:aio
                xprv.acct
                script-type.acct
                active-network.acct
                1  next-idx
              ==
            (send-bitcoin-pokes acct-key change-addr address amount fee-rate eyre-id)
              %'rename-wallet'
            =/  new-name=@t  (fall (get-key:kv:html-utils 'name' args) '')
            ?:  =('' new-name)
              ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'Name required')])
              (pure:m ~)
            ;<  lbls=labels:b329  bind:m  load-labels
            =/  fp=(unit @ux)  (get-simple-fp lbls)
            ?~  fp
              ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
              (pure:m ~)
            =/  xpub=@t  (scot %ux u.fp)
            =/  old-name=@t  (get-wallet-name lbls u.fp)
            =/  old-lbl=@t  (rap 3 ~['gwbtc:wallet:' old-name])
            =/  new-lbls=labels:b329  (~(del la:b329 lbls) %xpub xpub old-lbl)
            =/  new-lbls=labels:b329
              (~(put la:b329 new-lbls) [%xpub xpub (rap 3 ~['gwbtc:wallet:' new-name]) ~ ~ ~])
            ;<  ~  bind:m  (save-labels new-lbls)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
            (pure:m ~)
              %'set-fee-rate'
            =/  fee-raw=@t  (fall (get-key:kv:html-utils 'fee-rate' args) '2')
            =/  req-net=@t  (fall (get-key:kv:html-utils 'net' args) 'testnet3')
            =/  fee-val=@ud  (fall (rush fee-raw dem) 2)
            ;<  lbls=labels:b329  bind:m  load-labels
            ;<  sa=(unit [key=@ta acct=account-data])  bind:m
              (get-simple-account lbls req-net)
            ?~  sa
              ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
              (pure:m ~)
            =/  acct-ref=@t  (crip (scag (need (find "." (trip key.u.sa))) (trip key.u.sa)))
            =/  new-lbls=labels:b329  (set-simple-fee lbls acct-ref fee-val)
            ;<  ~  bind:m  (save-labels new-lbls)
            ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
            (pure:m ~)
          ==
        ::  route: /w/<wallet-key>/ → wallet detail page
        ?:  ?&  ?=([%w @ *] suffix)
                =(~ t.t.suffix)
            ==
          =/  fp=@ux  (scan (trip i.t.suffix) hex)
          ::  POST → forward as poke to main.sig with wallet-key
          ?:  ?=(%'POST' method.request.req)
            =/  args=key-value-list:kv:html-utils  (parse-body:kv:html-utils body.request.req)
            =/  jon=json  (form-args-to-json args)
            =/  jon=json  [%o (~(put by ?>(?=(%o -.jon) p.jon)) 'wallet-key' s+(scot %ux fp))]
            ;<  main-road=road:tarball  bind:m  (wr [%& ~ %'main.sig'])
            ;<  ~  bind:m  (poke:io main-road [[/ %json] jon])
            ;<  ~  bind:m  (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
            (pure:m ~)
          ::  GET → render wallet detail page
          ;<  store=wallet-store  bind:m  load-wallets
          =/  sd=(unit seed)  (~(get by store) fp)
          ?~  sd
            ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Wallet not found')])
            (pure:m ~)
          =/  wal=wallet-data  [u.sd fp]
          ;<  lbls=labels:b329  bind:m  load-labels
          =/  wal-name=@t  (get-wallet-name lbls fp)
          ;<  accts=(list [key=@ta acct=account-data])  bind:m  (load-wallet-accounts fp)
          =/  acct-list=(list account-data)  (turn accts |=([* a=account-data] a))
          ;<  ~  bind:m  (send-html eyre-id (detail-page:det-ui wal wal-name acct-list))
          (pure:m ~)
        ::  route: /a/<account-key>/ → account page
        ?:  ?&  ?=([%a @ *] suffix)
                =(~ t.t.suffix)
            ==
          =/  acct-key=@ta  (cat 3 i.t.suffix '.wallet_account')
          ;<  acct=(unit account-data)  bind:m  (load-account acct-key)
          ?~  acct
            ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Account not found')])
            (pure:m ~)
          ;<  recv=addr-mop  bind:m  (load-addr-mop acct-key active-network.u.acct %recv)
          ;<  chng=addr-mop  bind:m  (load-addr-mop acct-key active-network.u.acct %chng)
          ;<  now=@da  bind:m  get-time:io
          ;<  [scan=?(%active %paused %none) progress=(unit scan-progress:acct-ui)]  bind:m
            (load-scan-state acct-key)
          ;<  wal-name=@t  bind:m  (load-wallet-name wallet.u.acct)
          ;<  ~  bind:m  (send-html eyre-id (detail-page:acct-ui u.acct recv chng now scan progress ~ wal-name))
          (pure:m ~)
        ::  route: /a/<account-key>/send → send page
        ?:  ?=([%a @ %send ~] suffix)
          =/  acct-key=@ta  (cat 3 i.t.suffix '.wallet_account')
          ;<  acct=(unit account-data)  bind:m  (load-account acct-key)
          ?~  acct
            ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Account not found')])
            (pure:m ~)
          ;<  recv=addr-mop  bind:m  (load-addr-mop acct-key active-network.u.acct %recv)
          ;<  chng=addr-mop  bind:m  (load-addr-mop acct-key active-network.u.acct %chng)
          ;<  now=@da  bind:m  get-time:io
          ;<  dr=(unit transaction:drft)  bind:m  (load-draft acct-key)
          ;<  wal-name=@t  bind:m  (load-wallet-name wallet.u.acct)
          ;<  ~  bind:m  (send-html eyre-id (send-page:acct-ui u.acct recv chng dr now wal-name))
          (pure:m ~)
        ::  route: /a/<account-key>/send/stream → SSE for send page
        ?:  ?=([%a @ %send %stream ~] suffix)
          =/  acct-key=@ta  (cat 3 i.t.suffix '.wallet_account')
          (handle-send-stream eyre-id req acct-key)
        ::  route: /a/<account-key>/stream → SSE for live updates
        ?:  ?=([%a @ %stream ~] suffix)
          =/  acct-key=@ta  (cat 3 i.t.suffix '.wallet_account')
          (handle-account-stream eyre-id req acct-key)
        ::  route: /a/<account-key>/addr/<chain>/<idx>/stream → SSE for address
        ?:  ?=([%a @ %addr @ @ %stream ~] suffix)
          =/  acct-key=@ta  (cat 3 i.t.suffix '.wallet_account')
          =/  chain=@ta  i.t.t.t.suffix
          =/  idx-ta=@ta  i.t.t.t.t.suffix
          =/  chain-tag=?(%recv %chng)  ?:(?=(%recv chain) %recv %chng)
          =/  idx=@ud  (fall (slaw %ud idx-ta) 0)
          (handle-addr-stream eyre-id req acct-key chain-tag idx i.t.suffix)
        ::  route: /a/<account-key>/addr/<chain>/<idx> → address detail
        ?:  ?=([%a @ %addr @ @ ~] suffix)
          =/  acct-key=@ta  (cat 3 i.t.suffix '.wallet_account')
          =/  chain=@ta  i.t.t.t.suffix
          =/  idx-ta=@ta  i.t.t.t.t.suffix
          ;<  acct=(unit account-data)  bind:m  (load-account acct-key)
          ?~  acct
            ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Account not found')])
            (pure:m ~)
          =/  chain-tag=?(%recv %chng)  ?:(?=(%recv chain) %recv %chng)
          =/  idx=@ud  (fall (slaw %ud idx-ta) 0)
          ;<  mop=addr-mop  bind:m  (load-addr-mop acct-key active-network.u.acct chain-tag)
          =/  dat=(unit address-data)
            (get:((on @ud address-data) gth) mop idx)
          ?~  dat
            ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Address not found')])
            (pure:m ~)
          =/  akh=tape  (trip i.t.suffix)
          ;<  txs=tx-map  bind:m  (load-txs acct-key active-network.u.acct)
          ;<  ~  bind:m  (send-html eyre-id (addr-detail-page nexus-root idx u.dat chain-tag u.acct akh txs))
          (pure:m ~)
        ::  route: /a/<account-key>/tx/<txid> → transaction detail
        ?:  ?=([%a @ %tx @ ~] suffix)
          =/  acct-key=@ta  (cat 3 i.t.suffix '.wallet_account')
          =/  txid=@ta  i.t.t.t.suffix
          ;<  acct=(unit account-data)  bind:m  (load-account acct-key)
          ?~  acct
            ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Account not found')])
            (pure:m ~)
          ;<  txs=tx-map  bind:m  (load-txs acct-key active-network.u.acct)
          =/  tx=(unit transaction)  (~(get by txs) txid)
          ?~  tx
            ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Transaction not found')])
            (pure:m ~)
          ;<  recv=addr-mop  bind:m  (load-addr-mop acct-key active-network.u.acct %recv)
          ;<  chng=addr-mop  bind:m  (load-addr-mop acct-key active-network.u.acct %chng)
          =/  hit=(unit [idx=@ud chain=?(%recv %chng) address-data])
            (find-tx-addr u.tx recv chng)
          =/  akh=tape  (trip i.t.suffix)
          =/  [hit-idx=@ud hit-chain=?(%recv %chng) dat=address-data]
            (fall hit [0 %recv *address-data])
          ;<  ~  bind:m  (send-html eyre-id (tx-detail-page u.tx hit-idx hit-chain dat u.acct akh txs))
          (pure:m ~)
        ::  unknown route
        ;<  ~  bind:m  (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Not found')])
        (pure:m ~)
          ::
          ::  /proc/*: generic process handler — dispatches on type in state
          ::
          [[%proc ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%wallet /proc: failed")
        ;<  prev-state=vase  bind:m  get-state:io
        =/  prev=json  (fall (mole |.(!<(json prev-state))) *json)
        =/  proc-type=@t
          (~(dug jo:json-utils prev) /type so:dejs:format '')
        ?+    proc-type
            ~&  >  [%wallet %proc %unknown-type proc-type]
            (pure:m ~)
            %'scan'
          (handle-scan-proc prev)
            %'refresh'
          (handle-refresh-proc prev)
            %'discover'
          (handle-discover-proc prev)
            %'paused'
          stay:m
        ==
      ==
    --
::  wallet helpers
::
|%
++  wr  |=(=lane:tarball (ancestor-road:io [/wallet %app] lane))
::  +get-or-gen-uuid: read optional uuid from json, generate if absent
::
++  get-or-gen-uuid
  |=  jon=(map @t json)
  =/  m  (fiber:fiber:nexus ,@ta)
  ^-  form:m
  =/  raw=@ta  (~(dug jo:json-utils [%o jon]) /uuid so:dejs:format '')
  ?.  =('' raw)  (pure:m raw)
  ;<  eny=@uvJ  bind:m  get-entropy:io
  (pure:m (scot %uv eny))
::
::  Account identity helpers.  Account directories are the canonical
::  serialized account id: <pubkey>.wallet_account.
::
++  acct-dir-from-path
  |=  pax=path
  ^-  @ta
  ?~  pax  ''
  ?:  =(%'data.wallet_account' (rear pax))
    ?:  (lth (lent pax) 2)  ''
    (snag (sub (lent pax) 2) `path`pax)
  (rear pax)
::
++  acct-dir-from-rail
  |=  =rail:tarball
  ^-  @ta
  (acct-dir-from-path path.rail)
::
++  acct-dir-from-proc-rail
  |=  =rail:tarball
  ^-  @ta
  ?:  (lth (lent path.rail) 3)  ''
  (snag 2 path.rail)
::
::  +handle-scan-proc: scan chain process handler
::
++  handle-scan-proc
  |=  prev=json
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  acct-key=@ta
    (~(dog jo:json-utils prev) /account so:dejs:format)
  =/  prefix=path  (snoc /accounts acct-key)
  ::  load account data
  ;<  acct-road=road:tarball  bind:m  (wr [%& prefix %'data.wallet_account'])
  ;<  acct-seen=seen:nexus  bind:m  (peek:io acct-road ~)
  ?.  ?=([%& %file *] acct-seen)  (pure:m ~)
  =/  acct=(unit account-data)
    (mole |.(!<(account-data (need-vase:tarball sang.p.acct-seen))))
  ?~  acct  (pure:m ~)
  =/  network  active-network.u.acct
  =/  progress=scan-progress:aio  (parse-scan-progress:aio prev)
  ::  find paused marker by scanning /proc for a paused proc matching this account
  =/  paused-id=@t
    (~(dug jo:json-utils prev) /paused-id so:dejs:format '')
  =/  paused-road=road:tarball
    ?:  =('' paused-id)
      ::  no paused marker — use a dummy road that won't exist
      [%& %& /proc %'__no-pause__.json']
    [%& %& /proc (cat 3 paused-id '.json')]
  ::  scan recv chain
  =/  acct-path=@t  (spat prefix)
  ;<  ~  bind:m
    %:  scan-chain:aio
      1  prefix  paused-road  acct-path  u.acct
      %receiving  network
      ?:(?=(%recv phase.progress) idx.progress 0)
      ?:(?=(%recv phase.progress) gap.progress 0)
    ==
  ::  scan chng chain
  ;<  ~  bind:m
    %:  scan-chain:aio
      1  prefix  paused-road  acct-path  u.acct
      %change  network  0  0
    ==
  ::  mark proc as done — triggers news for subscribers
  ;<  prev-state=vase  bind:m  get-state:io
  =/  cur=json  (fall (mole |.(!<(json prev-state))) *json)
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
  =/  acct-key=@ta
    (~(dog jo:json-utils prev) /account so:dejs:format)
  =/  prefix=path  (snoc /accounts acct-key)
  =/  net-raw=@t
    (fall (mole |.((so:dejs:format (~(got jo:json-utils prev) /'network')))) 'main')
  =/  network=?(%main %testnet3 %testnet4 %signet %regtest)
    ;;(?(%main %testnet3 %testnet4 %signet %regtest) (slav %tas net-raw))
  =/  chain-tag=?(%recv %chng)
    =/  ch=@t  (fall (mole |.((so:dejs:format (~(got jo:json-utils prev) /'chain')))) 'recv')
    ?:(?=(%recv ;;(?(%recv %chng) (slav %tas ch))) %recv %chng)
  =/  idx=@ud
    (fall (mole |.((ni:dejs:format (~(got jo:json-utils prev) /'index')))) 0)
  ::  read current address data
  ;<  mop=addr-mop  bind:m  (load-addr-mop acct-key network chain-tag)
  =/  dat=(unit address-data)
    (get:((on @ud address-data) gth) mop idx)
  ?~  dat
    ~&  ["%refresh proc missing addr" acct-key network chain-tag idx]
    (pure:m ~)
  ::  set loading flag
  =/  loading-dat=address-data  u.dat(loading %.y)
  =/  updated=addr-mop
    (put:((on @ud address-data) gth) mop idx loading-dat)
  ;<  ~  bind:m  (write-addr-mop acct-key network chain-tag updated)
  ::  fetch address info
  =/  base-url=tape  (mempool-base-url:aio network)
  =/  info-url=@t  (crip (weld base-url (trip addr.u.dat)))
  =/  =request:http
    [%'GET' info-url ~[['Accept' 'application/json']] ~]
  ;<  ~  bind:m  (send-request:io request)
  ;<  info-resp=client-response:iris  bind:m  take-http:aio
  ;<  now=@da  bind:m  get-time:io
  =/  new-info=(unit address-info)  ~>(%bout (parse-info-response:aio info-resp now))
  ::  fetch UTXOs
  =/  utxo-url=@t  (crip :(weld base-url (trip addr.u.dat) "/utxo"))
  =/  utxo-req=request:http
    [%'GET' utxo-url ~[['Accept' 'application/json']] ~]
  ;<  ~  bind:m  (send-request:io utxo-req)
  ;<  utxo-resp=client-response:iris  bind:m  take-http:aio
  =/  utxos=(list utxo)  ~>(%bout (parse-utxo-response:aio utxo-resp))
  ::  fetch transactions
  =/  txs-url=@t  (crip :(weld base-url (trip addr.u.dat) "/txs"))
  =/  txs-req=request:http
    [%'GET' txs-url ~[['Accept' 'application/json']] ~]
  ;<  ~  bind:m  (send-request:io txs-req)
  ;<  txs-resp=client-response:iris  bind:m  take-http:aio
  =/  txs=(list transaction)  ~>(%bout (parse-txs-response:aio txs-resp))
  ::  update address in mop
  ;<  cur-mop=addr-mop  bind:m  (load-addr-mop acct-key network chain-tag)
  =/  new-dat=address-data
    [addr.u.dat %.n ~ new-info utxos]
  =/  final=addr-mop
    ~>(%bout (put:((on @ud address-data) gth) cur-mop idx new-dat))
  ;<  ~  bind:m  (write-addr-mop acct-key network chain-tag final)
  ::  update tx-map
  ;<  existing-txs=tx-map  bind:m  (load-txs acct-key network)
  =/  new-tx-map=tx-map
    ~>  %bout
    %-  ~(gas by existing-txs)
    (turn txs |=(t=transaction [txid.t t]))
  ;<  ~  bind:m  (write-txs acct-key network new-tx-map)
  ::  mark proc as done — triggers news for subscribers
  ;<  prev-state=vase  bind:m  get-state:io
  =/  cur=json  (fall (mole |.(!<(json prev-state))) *json)
  =/  updated=json
    ?.  ?=(%o -.cur)  cur
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
  =/  fp-key=@t
    (~(dog jo:json-utils prev) /fingerprint so:dejs:format)
  =/  fp=@ux  (slav %ux fp-key)
  ;<  store=wallet-store  bind:m  load-wallets
  =/  sd=(unit seed)  (~(get by store) fp)
  ?~  sd  (pure:m ~)
  =/  wal=wallet-data  [u.sd fp]
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
  =/  acct=account-data:wt
    [acct-name fingerprint.wal script-type network [%.y purpose] [%.y coin-type] [%.y account-idx] xprv]
  =/  acct-pubkey=@ux  public-key:derived
  =/  acct-key=@ta  (crip (hexn:http-utils acct-pubkey))
  =/  acct-dir=@ta  (cat 3 acct-key '.wallet_account')
  =/  acct-contents=(map @ta [=sang:tarball gain=? bang=(unit tang)])
    (~(put by *(map @ta [=sang:tarball gain=? bang=(unit tang)])) %'data.wallet_account' [[[/wallet %account] %& !>(acct)] %.n ~])
  =/  acct-lump=lump:tarball  [~ ~ %.n ~ acct-contents]
  =/  acct-ball=ball:tarball  [`acct-lump ~]
  ;<  acct-rd=road:tarball  bind:m  (wr [%| (snoc /accounts acct-dir)])
  ;<  err=(unit tang)  bind:m
    (make-soft:io acct-rd &+(ball-to-bole:tarball acct-ball))
  ?^  err
    ~&(>>> [%discover %account-create-failed] (pure:m ~))
  ::  kick off full scan on the new account
  ;<  scan-eny=@uvJ  bind:m  get-entropy:io
  =/  scan-uuid=@ta  (scot %uv scan-eny)
  =/  scan-json=json
    %-  pairs:enjs:format
    :~  ['type' s+'scan']
        ['account' s+acct-dir]
        ['phase' s+'recv']
        ['idx' (numb:enjs:format 0)]
        ['gap' (numb:enjs:format 0)]
    ==
  ;<  scan-rd=road:tarball  bind:m  (wr [%& /proc (cat 3 scan-uuid '.json')])
  ;<  ~  bind:m  (make:io scan-rd |+[[[/ %json] scan-json] ~])
  ::  write scan ref so UI can find the proc
  ;<  ref-rd=road:tarball  bind:m  (wr [%& (snoc /accounts acct-dir) %'scan-ref.json'])
  ;<  ~  bind:m  (over:io ref-rd [[/ %json] (pairs:enjs:format ~[['uuid' s+scan-uuid]])])
  ::  continue to next account
  $(account-idx +(account-idx))
::  +handle-account-data: per-account poke handler
::
++  handle-account-data
  |=  [=rail:tarball =prod:fiber:nexus]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  process:fiber:nexus
  ;<  ~  bind:m  (rise-wait:io prod "%account /data: failed")
  |-
  ;<  acct=account-data  bind:m  (get-state-as:io account-data)
  =/  acct-dir=@ta  (acct-dir-from-rail rail)
  =/  acct-hex=tape
    (scag (need (find "." (trip acct-dir))) (trip acct-dir))
  ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
  ?+    name.p.sage  $
      %json
    =/  jon=json  !<(json q.sage)
    ?.  ?=([%o *] jon)  $
    =/  act=@t  (~(dug jo:json-utils jon) /action so:dejs:format '')
    ?+    act  $
        %'derive-next'
      =/  chain=@t
        (~(dug jo:json-utils jon) /chain so:dejs:format 'receiving')
      =/  is-change=?  =(chain 'change')
      =/  chain-tag=?(%recv %chng)  ?:(is-change %chng %recv)
      ;<  mop=addr-mop  bind:m  (read-mop:aio 0 ~ active-network.acct chain-tag)
      =/  next-idx=@ud
        =/  top=(unit [idx=@ud address-data])
          (pry:((on @ud address-data) gth) mop)
        ?~  top  0
        +(idx.u.top)
      =/  new-addr=(unit @t)
        %:  derive-addr:aio
          xprv.acct
          script-type.acct
          active-network.acct
          ?:(is-change 1 0)
          next-idx
        ==
      ?~  new-addr
        ~&  >>>  "%derive-next: derive-addr returned ~"
        $
      =/  dat=address-data  [u.new-addr %.n ~ ~ ~]
      =/  updated=addr-mop
        (put:((on @ud address-data) gth) mop next-idx dat)
      ;<  ~  bind:m  (write-mop:aio 0 ~ active-network.acct chain-tag updated)
      ::  auto-refresh the newly derived address
      =/  net=@ta  ;;(@ta active-network.acct)
      ;<  eny=@uvJ  bind:m  get-entropy:io
      =/  uuid=@ta  (scot %uv eny)
      =/  proc-json=json
        %-  pairs:enjs:format
        :~  ['type' s+'refresh']
            ['account' s+acct-dir]
            ['network' s+net]
            ['chain' s+chain-tag]
            ['index' (numb:enjs:format next-idx)]
        ==
      ;<  proc-rd=road:tarball  bind:m  (wr [%& /proc (cat 3 uuid '.json')])
      ;<  ~  bind:m  (make:io proc-rd |+[[[/ %json] proc-json] ~])
      $
    ::
        %'delete-address'
      =/  chain=@t
        (~(dug jo:json-utils jon) /chain so:dejs:format 'recv')
      =/  idx=@ud
        (~(dug jo:json-utils jon) /index ni:dejs:format 0)
      =/  chain-tag=?(%recv %chng)
        ?:(?=(%recv ;;(?(%recv %chng) (slav %tas chain))) %recv %chng)
      ;<  mop=addr-mop  bind:m  (read-mop:aio 0 ~ active-network.acct chain-tag)
      =/  updated=addr-mop
        +:(del:((on @ud address-data) gth) mop idx)
      ;<  ~  bind:m  (write-mop:aio 0 ~ active-network.acct chain-tag updated)
      $
    ::
        %'set-network'
      =/  net=@t
        (~(dug jo:json-utils jon) /network so:dejs:format '')
      =/  new-network=?(%main %testnet3 %testnet4 %signet %regtest)
        ;;(?(%main %testnet3 %testnet4 %signet %regtest) (slav %tas net))
      ;<  ~  bind:m  (ensure-net-dir:aio 0 ~ new-network)
      =.  acct  acct(active-network new-network)
      ;<  ~  bind:m  (replace:io acct)
      $
    ::
        %'full-scan'
      ;<  uuid=@ta  bind:m  (get-or-gen-uuid p.jon)
      =/  proc-json=json
        %-  pairs:enjs:format
        :~  ['type' s+'scan']
            ['account' s+acct-dir]
            ['phase' s+'recv']
            ['idx' (numb:enjs:format 0)]
            ['gap' (numb:enjs:format 0)]
        ==
      ;<  scan-rd=road:tarball  bind:m  (wr [%& /proc (cat 3 uuid '.json')])
      ;<  ~  bind:m  (make:io scan-rd |+[[[/ %json] proc-json] ~])
      ::  write scan ref so UI can find the proc
      ;<  ref-rd=road:tarball  bind:m  (wr [%& (snoc /accounts acct-dir) %'scan-ref.json'])
      ;<  ~  bind:m  (over:io ref-rd [[/ %json] (pairs:enjs:format ~[['uuid' s+uuid]])])
      $
    ::
        %'pause-scan'
      =/  uuid=@ta
        (~(dug jo:json-utils jon) /uuid so:dejs:format '')
      ;<  scan-road=road:tarball  bind:m  (wr [%& /proc (cat 3 uuid '.json')])
      =/  pause-json=json
        (pairs:enjs:format ~[['action' s+'pause']])
      ;<  ~  bind:m
        (send-dart:io [%node /pause scan-road %poke [[/ %json] !>(pause-json)]])
      $
    ::
        %'resume-scan'
      =/  uuid=@ta
        (~(dug jo:json-utils jon) /uuid so:dejs:format '')
      ;<  scan-road=road:tarball  bind:m  (wr [%& /proc (cat 3 uuid '.json')])
      =/  resume-json=json
        (pairs:enjs:format ~[['action' s+'resume']])
      ;<  ~  bind:m
        (send-dart:io [%node /resume scan-road %poke [[/ %json] !>(resume-json)]])
      $
    ::
        %'cancel-scan'
      =/  uuid=@ta
        (~(dug jo:json-utils jon) /uuid so:dejs:format '')
      ;<  scan-rd=road:tarball  bind:m  (wr [%& /proc (cat 3 uuid '.json')])
      ;<  *  bind:m  (cull-soft:io scan-rd)
      $
    ::
        %'refresh'
      =/  chain=@t
        (~(dug jo:json-utils jon) /chain so:dejs:format 'recv')
      =/  idx=@ud
        (~(dug jo:json-utils jon) /index ni:dejs:format 0)
      =/  chain-tag=?(%recv %chng)
        ?:(?=(%recv ;;(?(%recv %chng) (slav %tas chain))) %recv %chng)
      =/  net=@ta  active-network.acct
      ;<  uuid=@ta  bind:m  (get-or-gen-uuid p.jon)
      =/  proc-json=json
        %-  pairs:enjs:format
        :~  ['type' s+'refresh']
            ['account' s+acct-dir]
            ['network' s+net]
            ['chain' s+chain-tag]
            ['index' (numb:enjs:format idx)]
        ==
      ;<  proc-rd=road:tarball  bind:m  (wr [%& /proc (cat 3 uuid '.json')])
      ;<  make-err=(unit tang)  bind:m  (make-soft:io proc-rd |+[[[/ %json] proc-json] ~])
      ?^  make-err
        ~&  ["%account refresh make failed" acct-dir uuid u.make-err]
        $
      $
    ::
    ::  === Draft transaction actions ===
    ::
        %'add-output'
      =/  address=@t  (so:dejs:format (need (~(get by p.jon) 'address')))
      =/  amount=@ud  (ni:dejs:format (need (~(get by p.jon) 'amount')))
      ;<  now=@da  bind:m  get-time:io
      ;<  existing=(unit transaction:drft)  bind:m  read-draft-file:aio
      =/  dr=transaction:drft
        ?~  existing
          [~ ~ ~ `%random now now]
        u.existing(modified now)
      =.  outputs.dr  (snoc outputs.dr [address amount])
      ;<  ~  bind:m  (write-draft:aio dr)
      $
    ::
        %'delete-output'
      =/  idx=@ud  (ni:dejs:format (need (~(get by p.jon) 'index')))
      ;<  existing=(unit transaction:drft)  bind:m  read-draft-file:aio
      ?~  existing  $
      ;<  now=@da  bind:m  get-time:io
      =/  dr=transaction:drft  u.existing(modified now)
      =.  outputs.dr  (oust [idx 1] outputs.dr)
      ;<  ~  bind:m  (write-draft:aio dr)
      $
    ::
        %'clear-draft'
      =/  draft-road=road:tarball
        (cord-to-road:tarball './data.wallet_draft')
      ;<  exists=?  bind:m  (peek-exists:io draft-road)
      ?.  exists  $
      ;<  *  bind:m  (cull-soft:io draft-road)
      $
    ::
        %'set-change-config'
      =/  fee-rate=@ud  (ni:dejs:format (need (~(get by p.jon) 'fee-rate')))
      =/  chg-addr=@t  (so:dejs:format (need (~(get by p.jon) 'change-address')))
      ;<  now=@da  bind:m  get-time:io
      ;<  existing=(unit transaction:drft)  bind:m  read-draft-file:aio
      =/  dr=transaction:drft
        ?~  existing
          [~ ~ ~ `%random now now]
        u.existing(modified now)
      =.  change.dr  `[fee-rate chg-addr]
      ;<  ~  bind:m  (write-draft:aio dr)
      $
    ::
        %'clear-change-config'
      ;<  existing=(unit transaction:drft)  bind:m  read-draft-file:aio
      ?~  existing  $
      ;<  now=@da  bind:m  get-time:io
      =.  change.u.existing  ~
      ;<  ~  bind:m  (write-draft:aio u.existing(modified now))
      $
    ::
        %'set-auto-select-mode'
      =/  mode-text=@t  (so:dejs:format (need (~(get by p.jon) 'mode')))
      =/  new-auto=(unit select-mode:drft)
        ?:  =('disabled' mode-text)  ~
        ?:  =('largest-first' mode-text)  `%largest-first
        `%random
      ;<  now=@da  bind:m  get-time:io
      ;<  existing=(unit transaction:drft)  bind:m  read-draft-file:aio
      =/  dr=transaction:drft
        ?~  existing
          [~ ~ ~ new-auto now now]
        u.existing(auto-select new-auto, modified now)
      ;<  ~  bind:m  (write-draft:aio dr)
      $
    ::
        %'run-auto-select'
      ;<  existing=(unit transaction:drft)  bind:m  read-draft-file:aio
      ?~  existing  $
      =/  mode=select-mode:drft
        (fall auto-select.u.existing %random)
      =/  fee-rate=@ud
        ?~  change.u.existing  1
        fee-rate.u.change.u.existing
      ;<  recv=addr-mop  bind:m  (read-mop:aio 0 ~ active-network.acct %recv)
      ;<  chng=addr-mop  bind:m  (read-mop:aio 0 ~ active-network.acct %chng)
      =/  utxos=(list utxo-input:drft)
        (collect-utxo-inputs:aio recv chng script-type.acct)
      =/  total-outputs=@ud  (sum-outputs:drft outputs.u.existing)
      ?:  =(0 total-outputs)
        ;<  now=@da  bind:m  get-time:io
        ;<  ~  bind:m  (write-draft:aio u.existing(inputs ~, modified now))
        $
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
      ?~  sel-result  $
      =/  selected=(list utxo-input:drft)
        %+  turn  u.sel-result
        |=  s=utxo-input:drft
        =/  match  (skim utxos |=(u=utxo-input:drft &(=(txid.u txid.s) =(vout.u vout.s))))
        ?>(?=(^ match) i.match)
      ;<  now=@da  bind:m  get-time:io
      ;<  ~  bind:m  (write-draft:aio u.existing(inputs selected, modified now))
      $
    ::
        %'add-input'
      =/  utxo-txid=@t  (so:dejs:format (need (~(get by p.jon) 'utxo-txid')))
      =/  utxo-vout=@ud  (ni:dejs:format (need (~(get by p.jon) 'utxo-vout')))
      =/  utxo-value=@ud  (ni:dejs:format (need (~(get by p.jon) 'utxo-value')))
      =/  utxo-spend=@t  (so:dejs:format (need (~(get by p.jon) 'utxo-spend')))
      ;<  now=@da  bind:m  get-time:io
      ;<  existing=(unit transaction:drft)  bind:m  read-draft-file:aio
      =/  dr=transaction:drft
        ?~  existing
          [~ ~ ~ `%random now now]
        u.existing(modified now)
      =/  spend=spend:fees  ;;(spend:fees (slav %tas utxo-spend))
      =/  new-input=utxo-input:drft  [utxo-txid utxo-vout utxo-value spend]
      =.  inputs.dr  (snoc inputs.dr new-input)
      ;<  ~  bind:m  (write-draft:aio dr)
      $
    ::
        %'remove-input'
      =/  utxo-txid=@t  (so:dejs:format (need (~(get by p.jon) 'utxo-txid')))
      =/  utxo-vout=@ud  (ni:dejs:format (need (~(get by p.jon) 'utxo-vout')))
      ;<  existing=(unit transaction:drft)  bind:m  read-draft-file:aio
      ?~  existing  $
      ;<  now=@da  bind:m  get-time:io
      =.  inputs.u.existing
        %+  skip  inputs.u.existing
        |=  input=utxo-input:drft
        &(=(txid.input utxo-txid) =(vout.input utxo-vout))
      ;<  ~  bind:m  (write-draft:aio u.existing(modified now))
      $
    ::
        %'build-transaction'
      ~&  >>  "=== BUILD AND BROADCAST TRANSACTION ==="
      ;<  existing=(unit transaction:drft)  bind:m  read-draft-file:aio
      ?~  existing
        ~&  >>>  "no draft transaction"
        $
      ?:  =(~ inputs.u.existing)
        ~&  >>>  "no inputs in draft"
        $
      ?:  =(~ outputs.u.existing)
        ~&  >>>  "no outputs in draft"
        $
      ;<  recv=addr-mop  bind:m  (read-mop:aio 0 ~ active-network.acct %recv)
      ;<  chng=addr-mop  bind:m  (read-mop:aio 0 ~ active-network.acct %chng)
      =/  addr-lookup=(map @t [chain=@ud idx=@ud])
        =/  m=(map @t [chain=@ud idx=@ud])  ~
        =.  m
          =/  entries=(list [@ud address-data])
            (flop (tap:((on @ud address-data) gth) recv))
          |-
          ?~  entries  m
          =.  m  (~(put by m) addr.i.entries [0 -.i.entries])
          $(entries t.entries)
        =/  entries=(list [@ud address-data])
          (flop (tap:((on @ud address-data) gth) chng))
        |-
        ?~  entries  m
        =.  m  (~(put by m) addr.i.entries [1 -.i.entries])
        $(entries t.entries)
      =/  utxo-to-addr=(map [@t @ud] @t)
        =/  m=(map [@t @ud] @t)  ~
        =/  all=(list [@ud address-data])
          (weld (mop-to-list:aio recv) (mop-to-list:aio chng))
        |-
        ?~  all  m
        =/  [idx=@ud a=address-data]  i.all
        =.  m
          |-
          ?~  utxos.a  m
          =.  m  (~(put by m) [txid.i.utxos.a vout.i.utxos.a] addr.a)
          $(utxos.a t.utxos.a)
        $(all t.all)
      =/  account-wallet  (from-extended:bip32 (trip xprv.acct))
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
        (build-transaction:txb active-network.acct 2 tx-inputs tx-outputs 0)
      =/  tx-hex-cord=@t  (crip tx-hex)
      ~&  >>  "tx hex: {<tx-hex-cord>}"
      =/  broadcast-url=@t
        ?-  active-network.acct
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
      =/  broadcast-result=cord
        ?+  client-response  'broadcast-failed'
          [%finished * [~ [* [p=@ q=@]]]]
        q.data.u.full-file.client-response
        ==
      ~&  >>  "broadcast result: {<broadcast-result>}"
      =/  draft-road=road:tarball
        (cord-to-road:tarball './data.wallet_draft')
      ;<  exists=?  bind:m  (peek-exists:io draft-road)
      ?.  exists  $
      ;<  *  bind:m  (cull-soft:io draft-road)
      $
    ==
  ==
::
::  HTTP response helpers — road from /ui/requests/* to /ui/http.sig
::
::  srv: HTTP response helpers — always 1 step from /ui/requests/* to /ui/http.sig
::  (stable: request handler is always a direct child of /ui/)
++  srv  ~(. http-res:io [%| 1 %& ~ %'http.sig'])
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
  ;<  =seen:nexus  bind:m  (peek:io road `[/ %mime])
  ?.  ?=([%& %file *] seen)
    (send-simple:srv eyre-id [[404 ~] `(as-octs:mimes:html 'Page not found')])
  =/  =mime  !<(mime (need-vase:tarball sang.p.seen))
  (send-simple:srv eyre-id (mime-response:http-utils mime))
::  +load-account: peek account data by key
::
++  load-account
  |=  acct-key=@ta
  =/  m  (fiber:fiber:nexus ,(unit account-data))
  ^-  form:m
  ;<  road=road:tarball  bind:m  (wr [%& /accounts/[acct-key] %'data.wallet_account'])
  ;<  =seen:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%& %file *] seen)  (pure:m ~)
  (pure:m (mole |.(!<(account-data (need-vase:tarball sang.p.seen)))))
::
++  load-labels
  =/  m  (fiber:fiber:nexus ,labels:b329)
  ^-  form:m
  ;<  road=road:tarball  bind:m  (wr [%& ~ %'labels.wallet_labels'])
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?.  exists  (pure:m *labels:b329)
  ;<  =seen:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%& %file *] seen)  (pure:m *labels:b329)
  (pure:m (fall (mole |.(!<(labels:b329 (need-vase:tarball sang.p.seen)))) *labels:b329))
::
++  save-labels
  |=  =labels:b329
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  road=road:tarball  bind:m  (wr [%& ~ %'labels.wallet_labels'])
  (over:io road [[/wallet %labels] labels])
::  +verify-receive-addr: live-check addr against mempool, advance if used
::
++  verify-receive-addr
  |=  $:  acct-key=@ta
          acct=account-data
          recv=addr-mop
          idx=@ud
          eyre-id=@ta
      ==
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ::  get or derive address at idx
  =/  dat=(unit address-data)
    (get:((on @ud address-data) gth) recv idx)
  =/  addr=@t
    ?^  dat  addr.u.dat
    ::  derive if beyond mop range
    %-  fall  :_  ''
    %:  derive-addr:aio
      xprv.acct  script-type.acct
      active-network.acct  0  idx
    ==
  ?:  =('' addr)
    ;<  ~  bind:m
      (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html '')])
    (pure:m ~)
  ::  fetch address info from mempool
  =/  base-url=tape  (mempool-base-url:aio active-network.acct)
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
::  +send-bitcoin-pokes: chain draft pokes to build, sign, and broadcast
::
++  send-bitcoin-pokes
  |=  $:  acct-key=@ta
          change-addr=@t
          dest-addr=@t
          amount=@ud
          fee-rate=@ud
          eyre-id=@ta
      ==
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  acct-road=road:tarball  bind:m  (wr [%& /accounts/[acct-key] %'data.wallet_account'])
  =/  poke-jon  |=(=json [[/ %json] json])
  ::  1. clear-draft
  ;<  ~  bind:m
    (poke:io acct-road (poke-jon (pairs:enjs:format ~[['action' s+'clear-draft']])))
  ::  2. add-output
  ;<  ~  bind:m
    %:  poke:io  acct-road
      %-  poke-jon
      %-  pairs:enjs:format
      :~  ['action' s+'add-output']
          ['address' s+dest-addr]
          ['amount' (numb:enjs:format amount)]
      ==
    ==
  ::  3. set-change-config
  ;<  ~  bind:m
    %:  poke:io  acct-road
      %-  poke-jon
      %-  pairs:enjs:format
      :~  ['action' s+'set-change-config']
          ['fee-rate' (numb:enjs:format fee-rate)]
          ['change-address' s+change-addr]
      ==
    ==
  ::  4. run-auto-select
  ;<  ~  bind:m
    (poke:io acct-road (poke-jon (pairs:enjs:format ~[['action' s+'run-auto-select']])))
  ::  5. build-transaction (signs, broadcasts, clears draft)
  ;<  ~  bind:m
    (poke:io acct-road (poke-jon (pairs:enjs:format ~[['action' s+'build-transaction']])))
  ;<  ~  bind:m
    (send-simple:srv eyre-id [[200 ~] `(as-octs:mimes:html 'ok')])
  (pure:m ~)
::
++  get-simple-fp
  |=  =labels:b329
  ^-  (unit @ux)
  =/  xpubs=(list [@t (set label-entry:b329)])
    ~(tap by xpub.labels)
  |-
  ?~  xpubs  ~
  =/  [ref=@t entries=(set label-entry:b329)]  i.xpubs
  =/  is-simple=?
    %+  lien  ~(tap in entries)
    |=(e=label-entry:b329 =('gwbtc:simple' label.e))
  ?.  is-simple  $(xpubs t.xpubs)
  (slaw %ux ref)
::
++  get-simple-wallet
  |=  =labels:b329
  =/  m  (fiber:fiber:nexus ,(unit wallet-data))
  ^-  form:m
  =/  fp=(unit @ux)  (get-simple-fp labels)
  ?~  fp  (pure:m ~)
  ;<  store=wallet-store  bind:m  load-wallets
  =/  sd=(unit seed)  (~(get by store) u.fp)
  ?~  sd  (pure:m ~)
  (pure:m `[u.sd u.fp])
::
++  get-simple-account
  |=  [=labels:b329 req-net=@t]
  =/  m  (fiber:fiber:nexus ,(unit [key=@ta acct=account-data]))
  ^-  form:m
  =/  fp=(unit @ux)  (get-simple-fp labels)
  ?~  fp  (pure:m ~)
  ;<  accts=(list [key=@ta acct=account-data])  bind:m  (load-wallet-accounts u.fp)
  %-  pure:m
  |-
  ?~  accts  ~
  ?:  =(req-net ;;(@t active-network.acct.i.accts))  `i.accts
  $(accts t.accts)
::
++  get-wallet-name
  |=  [=labels:b329 fp=@ux]
  ^-  @t
  =/  xpub=@t  (scot %ux fp)
  =/  entries=(list label-entry:b329)
    ~(tap in (~(get la:b329 labels) %xpub xpub))
  =/  prefix=tape  "gwbtc:wallet:"
  =/  prefix-len=@ud  (lent prefix)
  |-
  ?~  entries  'Unnamed Wallet'
  =/  lbl=tape  (trip label.i.entries)
  ?.  =(prefix (scag prefix-len lbl))
    $(entries t.entries)
  (crip (slag prefix-len lbl))
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
++  find-account-for-net
  |=  [accts=(list [key=@ta acct=account-data]) req-net=@t]
  ^-  (unit [key=@ta acct=account-data])
  |-
  ?~  accts  ~
  ?:  =(req-net ;;(@t active-network.acct.i.accts))  `i.accts
  $(accts t.accts)
::
++  wallet-nets
  |=  accts=(list [key=@ta acct=account-data])
  ^-  (list tape)
  %+  turn  accts
  |=  [* acct=account-data]
  (trip ;;(@t active-network.acct))
::  +ensure-public-poke: add wallet main.sig to public usergroup's poke weir
::
++  ensure-public-poke
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  weir-road=road:tarball
    [%& %& /sys/ames/usergroups/public %'how.weir']
  =/  wallet-road=road:tarball
    [%& %& /apps/'wallet.wallet_app' %'main.sig']
  ;<  weir-seen=seen:nexus  bind:m  (peek:io weir-road ~)
  =/  cur=weir:nexus
    ?.  ?=([%& %file *] weir-seen)  [~ ~ ~]
    (fall (mole |.(!<(weir:nexus (need-vase:tarball sang.p.weir-seen)))) [~ ~ ~])
  ?:  (~(has in poke.cur) wallet-road)
    (pure:m ~)
  ~&  "%wallet: registering with public usergroup"
  =/  new=weir:nexus  cur(poke (~(put in poke.cur) wallet-road))
  ;<  ~  bind:m  (over:io weir-road [[/ %weir] new])
  (pure:m ~)
::  +ensure-simple-wallet: create simple wallet if none labeled 'gwbtc:simple'
::
++  ensure-simple-wallet
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ::  load labels from root level
  ;<  lbl-rd=road:tarball  bind:m  (wr [%& ~ %'labels.wallet_labels'])
  ;<  lbl-seen=seen:nexus  bind:m  (peek:io lbl-rd ~)
  =/  lbls=labels:b329
    ?.  ?=([%& %file *] lbl-seen)  *labels:b329
    (fall (mole |.(!<(labels:b329 (need-vase:tarball sang.p.lbl-seen)))) *labels:b329)
  =/  fp=(unit @ux)  (get-simple-fp lbls)
  ?^  fp
    ~&  "%wallet: simple wallet exists"
    (pure:m ~)
  ~&  "%wallet: creating simple wallet"
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  seed-phrase=cord  (gen-seed:seed-phrases eny %256)
  =/  [wal-t=wallet-data * adir-t=@ta ball-t=ball:tarball]
    (make-dev-wallet 'My Wallet' [%t seed-phrase] %testnet3)
  =/  [* * adir-m=@ta ball-m=ball:tarball]
    (make-dev-wallet 'My Wallet' [%t seed-phrase] %main)
  =/  wal=wallet-data  wal-t
  ;<  store=wallet-store  bind:m  load-wallets
  ;<  ~  bind:m  (save-wallets (~(put by store) fingerprint.wal seed.wal))
  ;<  acct-t-rd=road:tarball  bind:m  (wr [%| (snoc /accounts adir-t)])
  ;<  ~  bind:m  (make:io acct-t-rd &+(ball-to-bole:tarball ball-t))
  ;<  acct-m-rd=road:tarball  bind:m  (wr [%| (snoc /accounts adir-m)])
  ;<  ~  bind:m  (make:io acct-m-rd &+(ball-to-bole:tarball ball-m))
  =/  xpub=@t  (scot %ux fingerprint.wal)
  =/  new-lbls=labels:b329  (set-simple-wallet lbls xpub)
  =/  new-lbls=labels:b329
    (~(put la:b329 new-lbls) [%xpub xpub 'gwbtc:wallet:My Wallet' ~ ~ ~])
  ;<  ~  bind:m  (over:io lbl-rd [[/wallet %labels] new-lbls])
  ~&  "%wallet: simple wallet created"
  (pure:m ~)
::
++  load-wallets
  =/  m  (fiber:fiber:nexus ,wallet-store)
  ^-  form:m
  ;<  rd=road:tarball  bind:m  (wr [%& ~ %'wallets.wallet_wallets'])
  ;<  exists=?  bind:m  (peek-exists:io rd)
  ?.  exists  (pure:m *wallet-store)
  ;<  =seen:nexus  bind:m  (peek:io rd ~)
  ?.  ?=([%& %file *] seen)  (pure:m *wallet-store)
  (pure:m (fall (mole |.(!<(wallet-store (need-vase:tarball sang.p.seen)))) *wallet-store))
::
++  save-wallets
  |=  store=wallet-store
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  rd=road:tarball  bind:m  (wr [%& ~ %'wallets.wallet_wallets'])
  (over:io rd [[/wallet %wallets] store])
::
++  store-to-list
  |=  store=wallet-store
  ^-  (list wallet-data)
  %+  turn  ~(tap by store)
  |=([fp=@ux sd=seed] `wallet-data`[sd fp])
::  +load-wallet-accounts: load all accounts belonging to a wallet
::
++  load-wallet-accounts
  |=  fp=@ux
  =/  m  (fiber:fiber:nexus ,(list [key=@ta acct=account-data]))
  ^-  form:m
  ;<  accts-rd=road:tarball  bind:m  (wr [%| /accounts])
  ;<  =seen:nexus  bind:m  (peek:io accts-rd ~)
  ?.  ?=([%& %ball *] seen)  (pure:m ~)
  %-  pure:m
  %+  murn  ~(tap by dir.ball.p.seen)
  |=  [dir-name=@ta sub=ball:tarball]
  ^-  (unit [key=@ta acct=account-data])
  =/  sub-lump=lump:tarball  (fall fil.sub *lump:tarball)
  =/  ct=(unit [=sang:tarball gain=? bang=(unit tang)])
    (~(get by contents.sub-lump) 'data.wallet_account')
  ?~  ct  ~
  ?.  ?=(%account name.p.sang.u.ct)  ~
  =/  acct=(unit account-data)
    (mole |.(!<(account-data (need-vase:tarball sang.u.ct))))
  ?~  acct  ~
  ?.  =(wallet.u.acct fp)  ~
  `[dir-name u.acct]
::
::  +load-addr-mop: read an addr-mop file from an account ball
::
++  load-addr-mop
  |=  [acct-key=@ta network=?(%main %testnet3 %testnet4 %signet %regtest) chain=?(%recv %chng)]
  =/  m  (fiber:fiber:nexus ,addr-mop)
  ^-  form:m
  ;<  road=road:tarball  bind:m  (wr [%& /accounts/[acct-key]/addresses/[;;(@ta network)]/[;;(@ta chain)] %'wallet_addresses'])
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?.  exists  (pure:m *addr-mop)
  ;<  =seen:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%& %file *] seen)  (pure:m *addr-mop)
  =/  result=addr-mop  (fall (mole |.(!<(addr-mop (need-vase:tarball sang.p.seen)))) *addr-mop)
  (pure:m result)
::
++  write-addr-mop
  |=  [acct-key=@ta network=?(%main %testnet3 %testnet4 %signet %regtest) chain=?(%recv %chng) mop=addr-mop]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  road=road:tarball  bind:m  (wr [%& /accounts/[acct-key]/addresses/[;;(@ta network)]/[;;(@ta chain)] %'wallet_addresses'])
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?:  exists
    (over:io road [[/wallet %addresses] mop])
  (make:io road |+[[[/wallet %addresses] mop] ~])
::  +load-txs: load tx-map from an account's network directory (app-level)
::
++  load-txs
  |=  [acct-key=@ta network=?(%main %testnet3 %testnet4 %signet %regtest)]
  =/  m  (fiber:fiber:nexus ,tx-map)
  ^-  form:m
  ;<  road=road:tarball  bind:m  (wr [%& /accounts/[acct-key]/addresses/[;;(@ta network)] %'txs.wallet_txs'])
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?.  exists  (pure:m *tx-map)
  ;<  =seen:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%& %file *] seen)  (pure:m *tx-map)
  (pure:m (fall (mole |.(!<(tx-map (need-vase:tarball sang.p.seen)))) *tx-map))
::
++  write-txs
  |=  [acct-key=@ta network=?(%main %testnet3 %testnet4 %signet %regtest) txs=tx-map]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  road=road:tarball  bind:m  (wr [%& /accounts/[acct-key]/addresses/[;;(@ta network)] %'txs.wallet_txs'])
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?:  exists
    (over:io road [[/wallet %txs] txs])
  (make:io road |+[[[/wallet %txs] txs] ~])
::  +load-contacts: peek contacts overlay dir for send-to picker
::
++  contacts-overlay-road  [%& %| /apps/'contacts.contacts'/overlay]
++  load-contacts
  =/  m  (fiber:fiber:nexus ,(map @t (map @t json)))
  ^-  form:m
  ;<  =seen:nexus  bind:m  (peek:io contacts-overlay-road ~)
  ?.  ?=([%& %ball *] seen)  (pure:m ~)
  =/  =lump:tarball  (fall fil.ball.p.seen *lump:tarball)
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
  =/  obj=(map @t json)  (fall (mole |.(!<((map @t json) (need-vase:tarball sang)))) ~)
  ?~  obj  ~
  `[key obj]
::  +load-scan-state: peek scan process file and paused marker
::
++  load-scan-state
  |=  acct-key=@ta
  =/  m  (fiber:fiber:nexus ,[?(%active %paused %none) (unit scan-progress:acct-ui)])
  ^-  form:m
  ;<  ref-road=road:tarball  bind:m  (wr [%& (snoc /accounts acct-key) %'scan-ref.json'])
  ;<  ref-seen=seen:nexus  bind:m  (peek:io ref-road ~)
  ?.  ?=([%& %file *] ref-seen)  (pure:m [%none ~])
  =/  ref-json=json  (fall (mole |.(!<(json (need-vase:tarball sang.p.ref-seen)))) *json)
  =/  scan-uuid=@t
    (~(dug jo:json-utils ref-json) /uuid so:dejs:format '')
  ?:  =('' scan-uuid)  (pure:m [%none ~])
  ;<  scan-road=road:tarball  bind:m  (wr [%& /proc (cat 3 scan-uuid '.json')])
  ;<  scan-exists=?  bind:m  (peek-exists:io scan-road)
  ?.  scan-exists  (pure:m [%none ~])
  ;<  =seen:nexus  bind:m  (peek:io scan-road ~)
  ?.  ?=([%& %file *] seen)  (pure:m [%none ~])
  =/  jon=json  (fall (mole |.(!<(json (need-vase:tarball sang.p.seen)))) *json)
  =/  progress=scan-progress:acct-ui
    ?.  ?=([%o *] jon)  ['' 0 0]
    =/  phase=(unit json)  (~(get by p.jon) 'phase')
    =/  idx-j=(unit json)  (~(get by p.jon) 'idx')
    =/  gap-j=(unit json)  (~(get by p.jon) 'gap')
    ?.  &(?=([~ %s *] phase) ?=([~ %n *] idx-j) ?=([~ %n *] gap-j))
      ['' 0 0]
    =/  idx=(unit @ud)  (rush p.u.idx-j dem)
    =/  gap=(unit @ud)  (rush p.u.gap-j dem)
    ?:  |(?=(~ idx) ?=(~ gap))  ['' 0 0]
    [p.u.phase u.idx u.gap]
  ::  check for paused state in proc json
  =/  proc-type=@t  (~(dug jo:json-utils jon) /type so:dejs:format '')
  (pure:m [?:(=(%'paused' proc-type) %paused %active) `progress])
::  +load-wallet-name: peek wallet name from wallet data
::
++  load-wallet-name
  |=  wallet-fp=@ux
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  ;<  lbls=labels:b329  bind:m  load-labels
  (pure:m (get-wallet-name lbls wallet-fp))
::  +load-draft: peek draft transaction from account
::
++  load-draft
  |=  acct-key=@ta
  =/  m  (fiber:fiber:nexus ,(unit transaction:drft))
  ^-  form:m
  ;<  road=road:tarball  bind:m  (wr [%& /accounts/[acct-key] %'data.wallet_draft'])
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?.  exists  (pure:m ~)
  ;<  =seen:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%& %file *] seen)  (pure:m ~)
  (pure:m (mole |.(!<(transaction:drft (need-vase:tarball sang.p.seen)))))
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
  |=  [eyre-id=@ta acct=account-data chain-tag=?(%recv %chng) mop=addr-mop now=@da]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  entries=(list [@ud address-data])  (mop-to-list:acct-ui mop)
  =/  chain=tape  ?:(?=(%recv chain-tag) "receiving" "change")
  =/  acct-key  (from-extended:bip32 (trip xprv.acct))
  =/  key-hex=tape  (hexn:http-utils public-key:acct-key)
  =/  list-id=@t  (crip "addr-list-{(trip chain-tag)}")
  |-
  ?~  entries  (pure:m ~)
  =/  [idx=@ud a=address-data]  i.entries
  =/  row-id=@t  (crip "addr-{(trip chain-tag)}-{(scow %ud idx)}")
  =/  row=manx  (address-row:acct-ui idx a now chain chain-tag active-network.acct key-hex)
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
  ::  watch the account ball
  ;<  acct-road=road:tarball  bind:m  (wr [%| /accounts/[acct-key]])
  ;<  *  bind:m  (keep:io /acct-stream acct-road ~)
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
    ::  reload all account data and re-render fragments
    ;<  acct=(unit account-data)  bind:m  (load-account acct-key)
    ?~  acct  $
    ;<  recv=addr-mop  bind:m  (load-addr-mop acct-key active-network.u.acct %recv)
    ;<  chng=addr-mop  bind:m  (load-addr-mop acct-key active-network.u.acct %chng)
    ;<  now=@da  bind:m  get-time:io
    ;<  [scan=?(%active %paused %none) progress=(unit scan-progress:acct-ui)]  bind:m
      (load-scan-state acct-key)
    ::  send granular fragments to preserve scroll position
    ::  update receive modal address
    =/  next-addr=(unit @t)  (next-unused-addr:acct-ui recv)
    ;<  ~  bind:m
      ?~  next-addr  (pure:m ~)
      =/  =sse-event:http-utils  [~ `'receive-addr' [u.next-addr]~]
      =/  data=octs  (sse-encode:http-utils ~[sse-event])
      (send-data:srv eyre-id `data)
    ;<  ~  bind:m
      (send-sse-fragment eyre-id 'account-summary-wrap' (account-summary-ui:acct-ui recv chng))
    ;<  ~  bind:m
      (send-sse-fragment eyre-id 'scan-status-wrap' (scan-status-ui:acct-ui scan progress))
    ;<  ~  bind:m  (send-addr-rows eyre-id u.acct %recv recv now)
    ;<  ~  bind:m  (send-addr-rows eyre-id u.acct %chng chng now)
    ;<  ~  bind:m
      (send-sse-fragment eyre-id 'receiving-derive' (derive-button:acct-ui "receiving" recv))
    ;<  ~  bind:m
      (send-sse-fragment eyre-id 'change-derive' (derive-button:acct-ui "change" chng))
    =/  recv-count=@ud  (lent (mop-to-list:acct-ui recv))
    =/  chng-count=@ud  (lent (mop-to-list:acct-ui chng))
    ;<  ~  bind:m
      (send-sse-fragment eyre-id 'tab-bar' (tab-bar:acct-ui recv-count chng-count))
    ;<  ~  bind:m
      (send-sse-fragment eyre-id 'network-badge-wrap' (network-badge-ui:acct-ui active-network.u.acct q.coin-type.u.acct))
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
  ;<  acct-road=road:tarball  bind:m  (wr [%| /accounts/[acct-key]])
  ;<  *  bind:m  (keep:io /send-stream acct-road ~)
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
    ;<  acct=(unit account-data)  bind:m  (load-account acct-key)
    ?~  acct  $
    ;<  recv=addr-mop  bind:m  (load-addr-mop acct-key active-network.u.acct %recv)
    ;<  chng=addr-mop  bind:m  (load-addr-mop acct-key active-network.u.acct %chng)
    ;<  dr=(unit transaction:drft)  bind:m  (load-draft acct-key)
    =/  fi=fee-calc:acct-ui  (compute-fee-info:acct-ui dr)
    =/  utxos=(list [addr=@t u=utxo chain=?(%recv %chng) idx=@ud])
      %+  weld
        ^-  (list [addr=@t u=utxo chain=?(%recv %chng) idx=@ud])
        %-  zing
        %+  turn  (mop-to-list:acct-ui recv)
        |=  [idx=@ud a=address-data]
        (turn utxos.a |=(u=utxo [addr.a u %recv idx]))
      ^-  (list [addr=@t u=utxo chain=?(%recv %chng) idx=@ud])
      %-  zing
      %+  turn  (mop-to-list:acct-ui chng)
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
    =/  spend=spend:fees:acct-ui  script-type.u.acct
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
  ::  watch the account ball
  ;<  acct-road=road:tarball  bind:m  (wr [%| /accounts/[acct-key]])
  ;<  *  bind:m  (keep:io /addr-stream acct-road ~)
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
    ;<  acct=(unit account-data)  bind:m  (load-account acct-key)
    ?~  acct  $
    ;<  mop=addr-mop  bind:m  (load-addr-mop acct-key active-network.u.acct chain-tag)
    =/  dat=(unit address-data)
      (get:((on @ud address-data) gth) mop idx)
    ?~  dat  $
    =/  akh=tape  (trip akh-ta)
    =/  net=@ta  ;;(@ta active-network.u.acct)
    =/  loading=?  %.n
    ;<  txs=tx-map  bind:m  (load-txs acct-key active-network.u.acct)
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
::  +find-tx-addr: given a tx, find first address in mops that it touches
::
++  find-tx-addr
  |=  [tx=transaction recv=addr-mop chng=addr-mop]
  ^-  (unit [idx=@ud chain=?(%recv %chng) address-data])
  =/  all-addrs=(set @t)
    %-  ~(gas in *(set @t))
    %+  weld
      (turn outputs.tx |=(=tx-output address.tx-output))
    %+  murn  inputs.tx
    |=(=tx-input ?~(prevout.tx-input ~ `address.u.prevout.tx-input))
  =/  recv-list=(list [@ud address-data])
    (flop (tap:((on @ud address-data) gth) recv))
  =/  res=(unit [idx=@ud chain=?(%recv %chng) address-data])
    |-
    ?~  recv-list  ~
    =/  [idx=@ud a=address-data]  i.recv-list
    ?:  (~(has in all-addrs) addr.a)  `[idx %recv a]
    $(recv-list t.recv-list)
  ?^  res  res
  =/  chng-list=(list [@ud address-data])
    (flop (tap:((on @ud address-data) gth) chng))
  |-
  ?~  chng-list  ~
  =/  [idx=@ud a=address-data]  i.chng-list
  ?:  (~(has in all-addrs) addr.a)  `[idx %chng a]
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
++  mk-acct-base
  |=  [nexus-root=tape akh=tape]
  ^-  tape
  "{(slag 1 nexus-root)}/accounts/{akh}.wallet_account"
::  +addr-detail-page: render address detail from inline data
::
++  addr-detail-page
  |=  [nexus-root=tape idx=@ud dat=address-data chain-tag=?(%recv %chng) acct=account-data akh=tape txs=tx-map]
  ^-  manx
  =/  network  active-network.acct
  =/  acct-base=tape  (mk-acct-base nexus-root akh)
  =/  addr-text=tape  (trip addr.dat)
  =/  chain-label=tape
    ?:(?=(%recv chain-tag) "Receiving" "Change")
  =/  network-label=tape
    ?-(network %main "Mainnet", %testnet3 "Testnet3", %testnet4 "Testnet4", %signet "Signet", %regtest "Regtest")
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
        ;+  ;/  (addr-script-text acct-base (trip chain-tag) (scow %ud idx))
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
    (sub funded.u.info.dat spent.u.info.dat)
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
          ;div.s-1.mono: {?~(info.dat "—" (format-sats funded.u.info.dat))}
        ==
        ;div
          ;div.f3.s-2: Spent
          ;div.s-1.mono: {?~(info.dat "—" (format-sats spent.u.info.dat))}
        ==
        ;div
          ;div.f3.s-2: Transactions
          ;div.s-1.mono: {?~(info.dat "—" (a-co:co tx-count.u.info.dat))}
        ==
      ==
      ;div(style "display: flex; justify-content: space-between; align-items: center; margin-top: 12px;")
        ;span.f3.s-2: {?~(info.dat "Never checked" "Last: {(scow %da last-check.u.info.dat)}")}
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
    ::  error banner
    ;+  ?~  last-error.dat
          ;span;
        ;div.p3.br1.fc.g1(style "background: rgba(255, 80, 80, 0.15); border: 1px solid rgba(255, 80, 80, 0.3); color: #ff5050;")
          ;span.s-1.bold: Refresh failed
          ;*  %+  turn  u.last-error.dat
              |=  =tank
              ;pre.s-2.mono(style "margin: 0; white-space: pre-wrap; word-break: break-all;")
                ; {~(ram re tank)}
              ==
        ==
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
  |=  [tx=transaction addr-idx=@ud addr-chain=?(%recv %chng) dat=address-data acct=account-data akh=tape txs=tx-map]
  ^-  manx
  =/  network  active-network.acct
  =/  txid-text=tape  (trip txid.tx)
  =/  confirmed=?  ?=(%confirmed -.tx-status.tx)
  =/  block-height=(unit @ud)
    ?:(?=(%unconfirmed -.tx-status.tx) ~ `block-height.tx-status.tx)
  =/  fee=@ud  (fall fee.tx 0)
  =/  size=@ud  (fall size.tx 0)
  =/  network-label=tape
    ?-(network %main "Mainnet", %testnet3 "Testnet3", %testnet4 "Testnet4", %signet "Signet", %regtest "Regtest")
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
  |=  [acct-base=tape chain=tape idx=tape]
  ^-  tape
  """
  var API = '/grubbery/api';
  var acctBase = '{acct-base}';

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
    var url = API + '/poke/' + acctBase + '/main.sig?blot=/json';
    fetch(url, \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(\{action: 'refresh', chain: '{chain}', index: {idx}})
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
++  make-dev-wallet
  |=  [name=@t =seed network=?(%main %testnet3 %testnet4 %signet %regtest)]
  ^-  [wallet-data @t @ta ball:tarball]
  =/  seed-bytes=byts
    ?-  -.seed
      %t  64^(to-seed:bip39 (trip phrase.seed) "")
      %q  =/  val=@  `@`secret.seed  [(met 3 val) val]
    ==
  =/  master  (from-seed:bip32 seed-bytes)
  =/  fp=@ux  public-key:master
  =/  coin=@ud  ?:(=(%main network) 0 1)
  =/  derived  (derive-path:master "m/84'/{(scow %ud coin)}'/0'")
  =/  bip-net  (to-bip-network:wt network)
  =/  xprv=@t  (crip (prv-extended:derived bip-net))
  =/  apk=@ux  public-key:derived
  =/  addr=(unit @t)
    (encode-pubkey:bech32 bip-net [33 public-key:(derive:(derive:derived 0) 0)])
  =/  wal=wallet-data  [seed fp]
  ::  build account data (no inline addresses)
  =/  acct=account-data  ['Default' fp %p2wpkh network [%.y 84] [%.y coin] [%.y 0] xprv]
  ::  build initial recv mop with first address
  =/  init-addr=address-data
    ?~  addr  ['' %.n ~ ~ ~]
    [u.addr %.n ~ ~ ~]
  =/  recv-mop=addr-mop
    (put:((on @ud address-data) gth) *addr-mop 0 init-addr)
  ::  build account ball with address mop files
  =/  adir=@ta  (cat 3 (crip (hexn:http-utils apk)) '.wallet_account')
  =/  net-dir=@ta  ;;(@ta network)
  =/  acct-contents=(map @ta [=sang:tarball gain=? bang=(unit tang)])
    (~(put by *(map @ta [=sang:tarball gain=? bang=(unit tang)])) %'data.wallet_account' [[[/wallet %account] %& !>(acct)] %.n ~])
  =/  acct-lump=lump:tarball  [~ ~ %.n ~ acct-contents]
  ::  build addresses/[network]/ ball with recv + chng mop files
  =/  chain-lump=lump:tarball
    :-  ~  :-  ~  :-  %.n  :-  ~
    %-  ~(gas by *(map @ta [=sang:tarball gain=? bang=(unit tang)]))
    :~  ['recv.wallet_addresses' [[[/wallet %addresses] %& !>(recv-mop)] %.n ~]]
        ['chng.wallet_addresses' [[[/wallet %addresses] %& !>(*addr-mop)] %.n ~]]
        ['txs.wallet_txs' [[[/wallet %txs] %& !>(*tx-map)] %.n ~]]
    ==
  =/  net-ball=ball:tarball  [`chain-lump ~]
  =/  addr-dir=ball:tarball  [~ (~(put by *(map @ta ball:tarball)) net-dir net-ball)]
  =/  acct-ball=ball:tarball
    [`acct-lump (~(put by *(map @ta ball:tarball)) 'addresses' addr-dir)]
  :*  wal  name  adir  acct-ball  ==
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
    |=(w=wallet-data [w (get-wallet-name labels fingerprint.w)])
  =/  sorted=(list [wal=wallet-data wal-name=@t])
    (sort named |=([a=[wallet-data @t] b=[wallet-data @t]] (aor +.a +.b)))
  ;div.fc.g2
    ;*  (turn sorted wallet-card)
  ==
::  page rendering
::
++  wallet-page
  |=  [nexus-root=tape wals=(list wallet-data) =labels:b329]
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
            ;+  (tab-container wals labels)
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
  |=  [wals=(list wallet-data) =labels:b329]
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
  =/  wallet-key=tape  (hexn:http-utils fingerprint.wal)
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
      =data-pubkey  (hexn:http-utils fingerprint.wal)
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
