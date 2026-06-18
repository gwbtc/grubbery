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
/<  drft          /lib/tx/draft.hoon
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
        =/  [wal-dir=@ta wal-ball=ball:tarball acct-dir=@ta acct-ball=ball:tarball]
          (make-dev-wallet 'Dev Wallet' [%t 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about'] %testnet4)
        =/  [fau-wal-dir=@ta fau-wal-ball=ball:tarball fau-acct-dir=@ta fau-acct-ball=ball:tarball]
          (make-dev-wallet 'Fauceted Wallet' [%t 'injury idea term fox crop movie type critic hello inquiry lottery agree'] %testnet3)
        %+  spin:loader  ball
        :~  (ver-row:loader 0)
            [%over %& [/ %'main.sig'] [[/ %sig] ~]]
            [%over %& [/ %'page.html'] [[/ %html] (crip (en-xml:html (wallet-page "" ~)))]]
            [%fall %| /wallets empty-dir:loader]
            [%fall %| /accounts empty-dir:loader]
            [%fall %| /ui/sse empty-dir:loader]
            [%over %& [/ui/sse %'wallets.html'] [[/ %html] (crip (en-xml:html (wallet-list-html ~)))]]
            [%fall %& [/ui %'http.sig'] [[/ %sig] ~]]
            [%fall %| /ui/requests empty-dir:loader]
            [%fall %| (snoc /wallets wal-dir) (ball-to-bole:tarball wal-ball)]
            [%fall %| (snoc /accounts acct-dir) (ball-to-bole:tarball acct-ball)]
            [%fall %| (snoc /wallets fau-wal-dir) (ball-to-bole:tarball fau-wal-ball)]
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
            =/  wal=wallet-data  [wallet-name u.sd pubkey ~]
            =/  wallet-dir=@ta  (cat 3 wallet-key '.wallet_wallet')
            =/  wal-contents=(map @ta [=bask:tarball gain=?])
              (~(put by *(map @ta [=bask:tarball gain=?])) %'main.wallet_wallet' [[[/wallet %wallet] wal] %.n])
            =/  wal-pulp=pulp:tarball  [`[/wallet %wallet] ~ %.n wal-contents]
            =/  wal-bole=bole:tarball  [`wal-pulp ~]
            ;<  ~  bind:m
              (make:io [%| 0 %| (snoc /wallets wallet-dir)] &+wal-bole)
            $
              %'add-wallet-from-entropy'
            =/  wallet-name=@t
              (~(dog jo:json-utils jon) /wallet-name so:dejs:format)
            ;<  eny=@uvJ  bind:m  get-entropy:io
            =/  seed-phrase=cord
              (gen-seed:seed-phrases eny %128)
            =/  pubkey=@ux  (seed-to-pubkey [%t seed-phrase])
            =/  wallet-key=@ta  (crip (hexn:http-utils pubkey))
            =/  wal=wallet-data  [wallet-name [%t seed-phrase] pubkey ~]
            =/  wallet-dir=@ta  (cat 3 wallet-key '.wallet_wallet')
            =/  wal-contents=(map @ta [=bask:tarball gain=?])
              (~(put by *(map @ta [=bask:tarball gain=?])) %'main.wallet_wallet' [[[/wallet %wallet] wal] %.n])
            =/  wal-pulp=pulp:tarball  [`[/wallet %wallet] ~ %.n wal-contents]
            =/  wal-bole=bole:tarball  [`wal-pulp ~]
            ;<  ~  bind:m
              (make:io [%| 0 %| (snoc /wallets wallet-dir)] &+wal-bole)
            $
              %'remove-wallet'
            =/  pubkey=@t
              (~(dog jo:json-utils jon) /pubkey so:dejs:format)
            =/  wallet-key=@ta  (crip (trip pubkey))
            =/  wallet-dir=@ta  (cat 3 wallet-key '.wallet_wallet')
            ;<  ~  bind:m
              (cull:io [%| 0 %| (snoc /wallets wallet-dir)])
            $
          ==
        ==
          ::  /page.html: render wallet list, re-render on /wallets/ changes
          ::
          [~ %'page.html']
        ;<  ~  bind:m  (rise-wait:io prod "%wallet /page: failed")
        ;<  here=rail:tarball  bind:m  get-here-abs:io
        =/  nexus-root=tape  (spud path.here)
        ;<  *  bind:m  (keep:io /wallets (cord-to-road:tarball './wallets/') ~)
        |-
        ;<  wals-seen=seen:nexus  bind:m  (peek:io (cord-to-road:tarball './wallets/') ~)
        =/  wals=(list wallet-data)  (view-to-wallets wals-seen)
        ;<  ~  bind:m  (replace:io (crip (en-xml:html (wallet-page nexus-root wals))))
        ;<  *  bind:m  (take-news:io /wallets)
        $
          ::  /ui/sse/wallets.html: wallet list HTML fragment for SSE
          ::
          [[%ui %sse ~] %'wallets.html']
        ;<  ~  bind:m  (rise-wait:io prod "%wallet /ui/sse/wallets: failed")
        ;<  *  bind:m  (keep:io /wallets (cord-to-road:tarball '../../wallets/') ~)
        |-
        ;<  wals-seen=seen:nexus  bind:m  (peek:io (cord-to-road:tarball '../../wallets/') ~)
        =/  wals=(list wallet-data)  (view-to-wallets wals-seen)
        ;<  ~  bind:m  (replace:io (crip (en-xml:html (wallet-list-html wals))))
        ;<  *  bind:m  (take-news:io /wallets)
        $
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
        =/  site=path  site:(parse-url:http-utils url.request.req)
        =/  prefix=path  /groundwire/wallet
        =/  suffix=path
          %+  skip  (slag (lent prefix) site)
          |=(s=@ta =('' s))
        ::  route: / → wallet list page
        ?~  suffix
          ;<  wals=(list wallet-data)  bind:m  load-wallets
          ;<  ~  bind:m  (send-html eyre-id (wallet-page nexus-root wals))
          (pure:m ~)
        ::  route: /w/<wallet-key>/ → wallet detail page
        ?:  ?&  ?=([%w @ *] suffix)
                =(~ t.t.suffix)
            ==
          =/  wal-key=@ta  (cat 3 i.t.suffix '.wallet_wallet')
          ;<  ~  bind:m
            (serve-page-html eyre-id (crip "../../wallets/{(trip wal-key)}/page.html"))
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
      ==
    --
::  wallet helpers
::
|%
::  HTTP response helpers — road from /ui/requests/* to /ui/http.sig
::
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
  =/  =road:tarball
    (cord-to-road:tarball (crip "../../accounts/{(trip acct-key)}/data.wallet_account"))
  ;<  =seen:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%& %file *] seen)  (pure:m ~)
  (pure:m (mole |.(!<(account-data (need-vase:tarball sang.p.seen)))))
::
++  load-wallets
  =/  m  (fiber:fiber:nexus ,(list wallet-data))
  ^-  form:m
  ;<  =seen:nexus  bind:m  (peek:io (cord-to-road:tarball '../../wallets/') ~)
  (pure:m (view-to-wallets seen))
::
::  +load-addr-mop: read an addr-mop file from an account ball
::
++  load-addr-mop
  |=  [acct-key=@ta network=?(%main %testnet3 %testnet4 %signet %regtest) chain=?(%recv %chng)]
  =/  m  (fiber:fiber:nexus ,addr-mop)
  ^-  form:m
  =/  =road:tarball
    (cord-to-road:tarball (crip "../../accounts/{(trip acct-key)}/addresses/{(trip ;;(@ta network))}/{(trip chain)}.wallet_addresses"))
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?.  exists  (pure:m *addr-mop)
  ;<  =seen:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%& %file *] seen)  (pure:m *addr-mop)
  (pure:m (fall (mole |.(!<(addr-mop (need-vase:tarball sang.p.seen)))) *addr-mop))
::  +load-txs: load tx-map from an account's network directory (app-level)
::
++  load-txs
  |=  [acct-key=@ta network=?(%main %testnet3 %testnet4 %signet %regtest)]
  =/  m  (fiber:fiber:nexus ,tx-map)
  ^-  form:m
  =/  =road:tarball
    (cord-to-road:tarball (crip "../../accounts/{(trip acct-key)}/addresses/{(trip ;;(@ta network))}/txs.wallet_txs"))
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?.  exists  (pure:m *tx-map)
  ;<  =seen:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%& %file *] seen)  (pure:m *tx-map)
  (pure:m (fall (mole |.(!<(tx-map (need-vase:tarball sang.p.seen)))) *tx-map))
::  +load-scan-state: peek scan process file and paused marker
::
++  load-scan-state
  |=  acct-key=@ta
  =/  m  (fiber:fiber:nexus ,[?(%active %paused %none) (unit scan-progress:acct-ui)])
  ^-  form:m
  =/  scan-road=road:tarball
    (cord-to-road:tarball (crip "../../accounts/{(trip acct-key)}/proc/scan.json"))
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
  ::  check for paused marker
  =/  pause-road=road:tarball
    (cord-to-road:tarball (crip "../../accounts/{(trip acct-key)}/scan-paused.json"))
  ;<  paused=?  bind:m  (peek-exists:io pause-road)
  (pure:m [?:(paused %paused %active) `progress])
::  +load-wallet-name: peek wallet name from wallet data
::
++  load-wallet-name
  |=  wallet-fp=@ux
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  =/  fp-hex=tape  (hexn:http-utils wallet-fp)
  =/  =road:tarball
    (cord-to-road:tarball (crip "../../wallets/{fp-hex}.wallet_wallet/main.wallet_wallet"))
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?.  exists  (pure:m '')
  ;<  =seen:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%& %file *] seen)  (pure:m '')
  =/  wal=(unit wallet-data)  (mole |.(!<(wallet-data (need-vase:tarball sang.p.seen))))
  ?~  wal  (pure:m '')
  (pure:m name.u.wal)
::  +load-draft: peek draft transaction from account
::
++  load-draft
  |=  acct-key=@ta
  =/  m  (fiber:fiber:nexus ,(unit transaction:drft))
  ^-  form:m
  =/  =road:tarball
    (cord-to-road:tarball (crip "../../accounts/{(trip acct-key)}/data.wallet_draft"))
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
  =/  acct-road=road:tarball
    (cord-to-road:tarball (crip "../../accounts/{(trip acct-key)}/"))
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
  =/  acct-road=road:tarball
    (cord-to-road:tarball (crip "../../accounts/{(trip acct-key)}/"))
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
  =/  acct-road=road:tarball
    (cord-to-road:tarball (crip "../../accounts/{(trip acct-key)}/"))
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
    =/  proc-name=@t
      (crip "refresh-{(trip net)}-{(trip chain-tag)}-{(scow %ud idx)}.json")
    =/  proc-road=road:tarball
      (cord-to-road:tarball (crip "../../accounts/{(trip acct-key)}/proc/{(trip proc-name)}"))
    ;<  loading=?  bind:m  (peek-exists:io proc-road)
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
    var url = API + '/poke/' + acctBase + '/main.sig?mark=json';
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
++  make-dev-wallet
  |=  [name=@t =seed network=?(%main %testnet3 %testnet4 %signet %regtest)]
  ^-  [@ta ball:tarball @ta ball:tarball]
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
  =/  apath=account  [[%.y 84] [%.y coin] [%.y 0]]
  =/  wal=wallet-data  [name seed fp (~(put by *(map account @ux)) apath apk)]
  ::  build account data (no inline addresses)
  =/  acct=account-data  ['Default' fp %p2wpkh network [%.y 84] [%.y coin] [%.y 0] xprv]
  ::  build initial recv mop with first address
  =/  init-addr=address-data
    ?~  addr  ['' %.n ~ ~ ~]
    [u.addr %.n ~ ~ ~]
  =/  recv-mop=addr-mop
    (put:((on @ud address-data) gth) *addr-mop 0 init-addr)
  ::  build account ball with address mop files
  =/  wdir=@ta  (cat 3 (crip (hexn:http-utils fp)) '.wallet_wallet')
  =/  adir=@ta  (cat 3 (crip (hexn:http-utils apk)) '.wallet_account')
  =/  net-dir=@ta  ;;(@ta network)
  =/  acct-contents=(map @ta [=sang:tarball gain=? bang=(unit tang)])
    (~(put by *(map @ta [=sang:tarball gain=? bang=(unit tang)])) %'data.wallet_account' [[[/wallet %account] %& !>(acct)] %.n ~])
  =/  acct-lump=lump:tarball  [`[/wallet %account] ~ %.n ~ acct-contents]
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
  :^  wdir
    :-  `[`[/wallet %wallet] ~ %.n ~ (~(put by *(map @ta [=sang:tarball gain=? bang=(unit tang)])) %'main.wallet_wallet' [[[/wallet %wallet] %& !>(wal)] %.n ~])]
    ~
  adir
  acct-ball
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
  [p.name seed fingerprint ~]
::
++  view-to-wallets
  |=  =seen:nexus
  ^-  (list wallet-data)
  ?.  ?=([%& %ball *] seen)  ~
  %+  murn  ~(tap by dir.ball.p.seen)
  |=  [name=@ta sub=ball:tarball]
  =/  sub-lump=lump:tarball  (fall fil.sub *lump:tarball)
  =/  ct=(unit [=sang:tarball gain=? bang=(unit tang)])  (~(get by contents.sub-lump) 'main.wallet_wallet')
  ?~  ct  ~
  ?.  ?=(%wallet name.p.sang.u.ct)  ~
  (mole |.(!<(wallet-data (need-vase:tarball sang.u.ct))))
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
  |=  [nexus-root=tape wals=(list wallet-data)]
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
        ;+  ;/  (script-text nexus-root)
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
    "/groundwire/wallet/w/{wallet-key}"
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
  "var API = '/' + window.location.pathname.split('/')[1] + '/'+'api';\0a"
  "var BASE = '{(slag 1 nexus-root)}';\0a"
  """

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
