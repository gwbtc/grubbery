::  per-account nexus: individual BIP44 account instance
::
::  Each account directory contains:
::    data.account   account-data (name, xprv, script-type, addresses)
::    data.draft     transaction draft state
::    main.sig       poke handler for derive-next + send actions
::
/<  wt            /lib/wallet-types.hoon
/<  bip32         /lib/bip32.hoon
/<  bech32        /lib/bech32.hoon
/<  drft          /lib/tx/draft.hoon
/<  fees          /lib/tx/fees.hoon
/<  utxo-sel      /lib/tx/select.hoon
/<  txb           /lib/tx/build.hoon
/<  bcu           /lib/bitcoin-utils.hoon
/<  acct-ui       /lib/wallet-account-ui.hoon
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
          [%fall %| /addresses [~ ~] [~ ~] empty-dir:loader]
          [%fall %| /proc [~ ~] [~ ~] empty-dir:loader]
          [%stay %& [/proc %'scan.json']]
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
          ::  /main.sig: handle pokes — dispatches to process files
          ::
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%account /main: failed")
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        ~&  ["%account main.sig poke" name.p.sage]
        ?+    name.p.sage  $
            %json
          =/  jon=json  !<(json q.sage)
          ?.  ?=([%o *] jon)  $
          =/  act=@t  (~(dug jo:json-utils jon) /action so:dejs:format '')
          ~&  ["%account main.sig action" act]
          ?+    act  $
              %'derive-next'
            =/  chain=@t
              (~(dug jo:json-utils jon) /chain so:dejs:format 'receiving')
            ;<  acct-seen=seen:nexus  bind:m
              (peek:io (cord-to-road:tarball './data.wallet_account') ~)
            ?.  ?=(%& -.acct-seen)  $
            ?.  ?=([%file *] p.acct-seen)  $
            =/  acct=(unit account-data)
              (mole |.(!<(account-data q.sage.p.acct-seen)))
            ?~  acct  $
            =/  is-change=?  =(chain 'change')
            =/  chain-tag=?(%recv %chng)  ?:(is-change %chng %recv)
            ::  read existing mop for this chain
            ;<  mop=addr-mop  bind:m  (read-mop "." active-network.u.acct chain-tag)
            =/  next-idx=@ud
              =/  top=(unit [idx=@ud address-data])
                (pry:((on @ud address-data) gth) mop)
              ?~  top  0
              +(idx.u.top)
            =/  new-addr=(unit @t)
              %:  derive-addr
                xprv.u.acct
                script-type.u.acct
                active-network.u.acct
                ?:(is-change 1 0)
                next-idx
              ==
            ?~  new-addr  $
            ::  put address into mop and write
            =/  dat=address-data  [u.new-addr %.n ~ ~ ~]
            =/  updated=addr-mop
              (put:((on @ud address-data) gth) mop next-idx dat)
            ;<  ~  bind:m  (write-mop "." active-network.u.acct chain-tag updated)
            ::  auto-refresh the newly derived address
            =/  net=@ta  ;;(@ta active-network.u.acct)
            =/  proc-name=@t
              (crip "refresh-{(trip net)}-{(trip chain-tag)}-{(scow %ud next-idx)}.json")
            =/  proc-road=road:tarball
              (cord-to-road:tarball (crip "./proc/{(trip proc-name)}"))
            =/  proc-json=json
              %-  pairs:enjs:format
              :~  ['network' s+net]
                  ['chain' s+chain-tag]
                  ['index' (numb:enjs:format next-idx)]
              ==
            ;<  ~  bind:m
              (make:io proc-road |+[%.n [[/ %json] !>(proc-json)] ~])
            $
          ::
              %'delete-address'
            =/  chain=@t
              (~(dug jo:json-utils jon) /chain so:dejs:format 'recv')
            =/  idx=@ud
              (~(dug jo:json-utils jon) /index ni:dejs:format 0)
            =/  chain-tag=?(%recv %chng)
              ?:(?=(%recv ;;(?(%recv %chng) (slav %tas chain))) %recv %chng)
            ;<  acct-seen=seen:nexus  bind:m
              (peek:io (cord-to-road:tarball './data.wallet_account') ~)
            ?.  ?=(%& -.acct-seen)  $
            ?.  ?=([%file *] p.acct-seen)  $
            =/  acct=(unit account-data)
              (mole |.(!<(account-data q.sage.p.acct-seen)))
            ?~  acct  $
            ;<  mop=addr-mop  bind:m  (read-mop "." active-network.u.acct chain-tag)
            =/  updated=addr-mop
              +:(del:((on @ud address-data) gth) mop idx)
            ;<  ~  bind:m  (write-mop "." active-network.u.acct chain-tag updated)
            $
          ::
              %'set-network'
            =/  net=@t
              (~(dug jo:json-utils jon) /network so:dejs:format '')
            =/  new-network=?(%main %testnet3 %testnet4 %signet %regtest)
              ;;(?(%main %testnet3 %testnet4 %signet %regtest) (slav %tas net))
            ;<  acct-seen=seen:nexus  bind:m
              (peek:io (cord-to-road:tarball './data.wallet_account') ~)
            ?.  ?=(%& -.acct-seen)  $
            ?.  ?=([%file *] p.acct-seen)  $
            =/  acct=(unit account-data)
              (mole |.(!<(account-data q.sage.p.acct-seen)))
            ?~  acct  $
            ::  ensure address dir exists for the new network
            ;<  ~  bind:m  (ensure-net-dir new-network)
            =/  updated=account-data  u.acct(active-network new-network)
            ;<  ~  bind:m
              (over:io (cord-to-road:tarball './data.wallet_account') [[/wallet %account] !>(updated)])
            $
          ::
              %'full-scan'
            =/  proc-json=json
              %-  pairs:enjs:format
              :~  ['phase' s+'recv']
                  ['idx' (numb:enjs:format 0)]
                  ['gap' (numb:enjs:format 0)]
              ==
            ;<  ~  bind:m
              (make:io (cord-to-road:tarball './proc/scan.json') |+[%.n [[/ %json] !>(proc-json)] ~])
            $
          ::
              %'pause-scan'
            ::  fire-and-forget: don't wait for ack so main.sig stays responsive
            =/  pause-json=json
              (pairs:enjs:format ~[['action' s+'pause']])
            ;<  ~  bind:m
              (send-dart:io [%node /pause (cord-to-road:tarball './proc/scan.json') %poke [[/ %json] !>(pause-json)]])
            $
          ::
              %'resume-scan'
            =/  resume-json=json
              (pairs:enjs:format ~[['action' s+'resume']])
            ;<  ~  bind:m
              (send-dart:io [%node /resume (cord-to-road:tarball './proc/scan.json') %poke [[/ %json] !>(resume-json)]])
            $
          ::
              %'cancel-scan'
            ;<  *  bind:m
              (cull-soft:io (cord-to-road:tarball './proc/scan.json'))
            ;<  *  bind:m
              (cull-soft:io (cord-to-road:tarball './scan-paused.json'))
            $
          ::
              %'refresh'
            =/  chain=@t
              (~(dug jo:json-utils jon) /chain so:dejs:format 'recv')
            =/  idx=@ud
              (~(dug jo:json-utils jon) /index ni:dejs:format 0)
            =/  chain-tag=?(%recv %chng)
              ?:(?=(%recv ;;(?(%recv %chng) (slav %tas chain))) %recv %chng)
            ;<  acct-seen=seen:nexus  bind:m
              (peek:io (cord-to-road:tarball './data.wallet_account') ~)
            ?.  ?=([%& %file *] acct-seen)  $
            =/  acct=(unit account-data)
              (mole |.(!<(account-data q.sage.p.acct-seen)))
            ?~  acct  $
            ::  spawn refresh process file
            =/  net=@ta  ;;(@ta active-network.u.acct)
            =/  proc-name=@t
              (crip "refresh-{(trip net)}-{(trip chain-tag)}-{(scow %ud idx)}.json")
            =/  proc-road=road:tarball
              (cord-to-road:tarball (crip "./proc/{(trip proc-name)}"))
            =/  proc-json=json
              %-  pairs:enjs:format
              :~  ['network' s+net]
                  ['chain' s+chain-tag]
                  ['index' (numb:enjs:format idx)]
              ==
            ~&  >  [%refresh %spawning proc-name]
            ;<  ~  bind:m
              (make:io proc-road |+[%.n [[/ %json] !>(proc-json)] ~])
            $
          ::
          ::  === Draft transaction actions ===
          ::
              %'add-output'
            =/  address=@t  (so:dejs:format (need (~(get by p.jon) 'address')))
            =/  amount=@ud  (ni:dejs:format (need (~(get by p.jon) 'amount')))
            ;<  now=@da  bind:m  get-time:io
            ;<  existing=(unit transaction:drft)  bind:m  read-draft-file
            =/  dr=transaction:drft
              ?~  existing
                [~ ~ ~ `%random now now]
              u.existing(modified now)
            =.  outputs.dr  (snoc outputs.dr [address amount])
            ;<  ~  bind:m  (write-draft dr)
            $
          ::
              %'delete-output'
            =/  idx=@ud  (ni:dejs:format (need (~(get by p.jon) 'index')))
            ;<  existing=(unit transaction:drft)  bind:m  read-draft-file
            ?~  existing  $
            ;<  now=@da  bind:m  get-time:io
            =/  dr=transaction:drft  u.existing(modified now)
            =.  outputs.dr  (oust [idx 1] outputs.dr)
            ;<  ~  bind:m  (write-draft dr)
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
            ;<  existing=(unit transaction:drft)  bind:m  read-draft-file
            =/  dr=transaction:drft
              ?~  existing
                [~ ~ ~ `%random now now]
              u.existing(modified now)
            =.  change.dr  `[fee-rate chg-addr]
            ;<  ~  bind:m  (write-draft dr)
            $
          ::
              %'clear-change-config'
            ;<  existing=(unit transaction:drft)  bind:m  read-draft-file
            ?~  existing  $
            ;<  now=@da  bind:m  get-time:io
            =.  change.u.existing  ~
            ;<  ~  bind:m  (write-draft u.existing(modified now))
            $
          ::
              %'set-auto-select-mode'
            =/  mode-text=@t  (so:dejs:format (need (~(get by p.jon) 'mode')))
            =/  new-auto=(unit select-mode:drft)
              ?:  =('disabled' mode-text)  ~
              ?:  =('largest-first' mode-text)  `%largest-first
              `%random
            ;<  now=@da  bind:m  get-time:io
            ;<  existing=(unit transaction:drft)  bind:m  read-draft-file
            =/  dr=transaction:drft
              ?~  existing
                [~ ~ ~ new-auto now now]
              u.existing(auto-select new-auto, modified now)
            ;<  ~  bind:m  (write-draft dr)
            $
          ::
              %'run-auto-select'
            ;<  acct-seen=seen:nexus  bind:m
              (peek:io (cord-to-road:tarball './data.wallet_account') ~)
            ?.  ?=(%& -.acct-seen)  $
            ?.  ?=([%file *] p.acct-seen)  $
            =/  acct=(unit account-data)
              (mole |.(!<(account-data q.sage.p.acct-seen)))
            ?~  acct  $
            ;<  existing=(unit transaction:drft)  bind:m  read-draft-file
            ?~  existing  $
            =/  mode=select-mode:drft
              (fall auto-select.u.existing %random)
            =/  fee-rate=@ud
              ?~  change.u.existing  1
              fee-rate.u.change.u.existing
            ::  collect UTXOs from all addresses
            ;<  recv=addr-mop  bind:m  (read-mop "." active-network.u.acct %recv)
            ;<  chng=addr-mop  bind:m  (read-mop "." active-network.u.acct %chng)
            =/  utxos=(list utxo-input:drft)
              (collect-utxo-inputs recv chng script-type.u.acct)
            =/  total-outputs=@ud  (sum-outputs:drft outputs.u.existing)
            ?:  =(0 total-outputs)
              ::  nothing to fund, clear inputs
              ;<  now=@da  bind:m  get-time:io
              ;<  ~  bind:m  (write-draft u.existing(inputs ~, modified now))
              $
            ::  calculate output vbytes for selection
            =/  output-vbytes=@ud
              %+  add
                %+  roll  outputs.u.existing
                |=  [out=output:drft sum=@ud]
                (add sum (output-vbytes:fees (address-to-spend:drft address.out)))
              ?~  change.u.existing  0
              (output-vbytes:fees (address-to-spend:drft address.u.change.u.existing))
            ::  convert to selectables and run selection
            =/  selectables=(list utxo-input:drft)
              (turn utxos |=(u=utxo-input:drft [txid.u vout.u amount.u spend.u]))
            ;<  eny=@uvJ  bind:m  get-entropy:io
            =/  sel-result=(unit (list utxo-input:drft))
              ?-  mode
                %largest-first  (largest-first:utxo-sel selectables total-outputs output-vbytes fee-rate)
                %random         (random:utxo-sel selectables total-outputs output-vbytes fee-rate eny)
              ==
            ?~  sel-result  $  ::  insufficient funds
            =/  selected=(list utxo-input:drft)
              %+  turn  u.sel-result
              |=  s=utxo-input:drft
              =/  match  (skim utxos |=(u=utxo-input:drft &(=(txid.u txid.s) =(vout.u vout.s))))
              ?>(?=(^ match) i.match)
            ;<  now=@da  bind:m  get-time:io
            ;<  ~  bind:m  (write-draft u.existing(inputs selected, modified now))
            $
          ::
              %'add-input'
            =/  utxo-txid=@t  (so:dejs:format (need (~(get by p.jon) 'utxo-txid')))
            =/  utxo-vout=@ud  (ni:dejs:format (need (~(get by p.jon) 'utxo-vout')))
            =/  utxo-value=@ud  (ni:dejs:format (need (~(get by p.jon) 'utxo-value')))
            =/  utxo-spend=@t  (so:dejs:format (need (~(get by p.jon) 'utxo-spend')))
            ;<  now=@da  bind:m  get-time:io
            ;<  existing=(unit transaction:drft)  bind:m  read-draft-file
            =/  dr=transaction:drft
              ?~  existing
                [~ ~ ~ `%random now now]
              u.existing(modified now)
            =/  spend=spend:fees  ;;(spend:fees (slav %tas utxo-spend))
            =/  new-input=utxo-input:drft  [utxo-txid utxo-vout utxo-value spend]
            =.  inputs.dr  (snoc inputs.dr new-input)
            ;<  ~  bind:m  (write-draft dr)
            $
          ::
              %'remove-input'
            =/  utxo-txid=@t  (so:dejs:format (need (~(get by p.jon) 'utxo-txid')))
            =/  utxo-vout=@ud  (ni:dejs:format (need (~(get by p.jon) 'utxo-vout')))
            ;<  existing=(unit transaction:drft)  bind:m  read-draft-file
            ?~  existing  $
            ;<  now=@da  bind:m  get-time:io
            =.  inputs.u.existing
              %+  skip  inputs.u.existing
              |=  input=utxo-input:drft
              &(=(txid.input utxo-txid) =(vout.input utxo-vout))
            ;<  ~  bind:m  (write-draft u.existing(modified now))
            $
          ::
              %'build-transaction'
            ~&  >>  "=== BUILD AND BROADCAST TRANSACTION ==="
            ::  read account data
            ;<  acct-seen=seen:nexus  bind:m
              (peek:io (cord-to-road:tarball './data.wallet_account') ~)
            ?.  ?=(%& -.acct-seen)  $
            ?.  ?=([%file *] p.acct-seen)  $
            =/  acct=(unit account-data)
              (mole |.(!<(account-data q.sage.p.acct-seen)))
            ?~  acct
              ~&  >>>  "account data not found"
              $
            ::  read draft
            ;<  existing=(unit transaction:drft)  bind:m  read-draft-file
            ?~  existing
              ~&  >>>  "no draft transaction"
              $
            ?:  =(~ inputs.u.existing)
              ~&  >>>  "no inputs in draft"
              $
            ?:  =(~ outputs.u.existing)
              ~&  >>>  "no outputs in draft"
              $
            ::  load address mops to map UTXOs → derivation paths
            ;<  recv=addr-mop  bind:m  (read-mop "." active-network.u.acct %recv)
            ;<  chng=addr-mop  bind:m  (read-mop "." active-network.u.acct %chng)
            ::  build address → [chain index] lookup
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
            ::  build UTXO → address lookup from mops
            =/  utxo-to-addr=(map [@t @ud] @t)
              =/  m=(map [@t @ud] @t)  ~
              =/  all=(list [@ud address-data])
                (weld (mop-to-list recv) (mop-to-list chng))
              |-
              ?~  all  m
              =/  [idx=@ud a=address-data]  i.all
              =.  m
                |-
                ?~  utxos.a  m
                =.  m  (~(put by m) [txid.i.utxos.a vout.i.utxos.a] addr.a)
                $(utxos.a t.utxos.a)
              $(all t.all)
            ::  create account-level bip32 wallet from xprv
            =/  account-wallet  (from-extended:bip32 (trip xprv.u.acct))
            ::  build tx inputs
            =/  tx-inputs=(list input:ap:tt:txb)
              %+  turn  inputs.u.existing
              |=  in=utxo-input:drft
              ::  find which address owns this UTXO
              =/  owner=(unit @t)  (~(get by utxo-to-addr) [txid.in vout.in])
              ?~  owner  ~|("UTXO owner not found: {<txid.in>}:{<vout.in>}" !!)
              =/  path=(unit [chain=@ud idx=@ud])  (~(get by addr-lookup) u.owner)
              ?~  path  ~|("address path not found: {<u.owner>}" !!)
              ::  derive signing key
              =/  derived  (derive:(derive:account-wallet chain.u.path) idx.u.path)
              =/  privkey=@ux  prv.derived
              =/  pubkey=@ux  (ser-p:derived pub.derived)
              ::  convert txid from hex string to little-endian @ux
              =/  txid-display=@ux  (rash txid.in hex)
              =/  txid=@ux  dat:(flip:byt:bcu [32 txid-display])
              ::  convert spend type
              =/  spend=spend-type:tt:txb
                ?-  spend.in
                  %p2pkh        [%p2pkh ~]
                  %p2sh-p2wpkh  [%p2sh-p2wpkh ~]
                  %p2wpkh       [%p2wpkh ~]
                  %p2tr         [%p2tr %key-path ~]
                ==
              [privkey pubkey txid vout.in amount.in `@ud`0xffff.ffff spend]
            ::  build outputs (including change)
            =/  tx-outputs=(list output:ap:tt:txb)
              (incorporate-change:drft u.existing)
            ::  build and sign transaction
            ~&  >>  "building tx: {<(lent tx-inputs)>} inputs, {<(lent tx-outputs)>} outputs"
            =/  tx-hex=tape
              (build-transaction:txb active-network.u.acct 2 tx-inputs tx-outputs 0)
            =/  tx-hex-cord=@t  (crip tx-hex)
            ~&  >>  "tx hex: {<tx-hex-cord>}"
            ::  broadcast via mempool.space API
            =/  broadcast-url=@t
              ?-  active-network.u.acct
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
            ;<  =client-response:iris  bind:m  take-http
            =/  broadcast-result=cord
              ?+  client-response  'broadcast-failed'
                [%finished * [~ [* [p=@ q=@]]]]
              q.data.u.full-file.client-response
              ==
            ~&  >>  "broadcast result: {<broadcast-result>}"
            ::  clear draft on success
            =/  draft-road=road:tarball
              (cord-to-road:tarball './data.wallet_draft')
            ;<  exists=?  bind:m  (peek-exists:io draft-road)
            ?.  exists  $
            ;<  *  bind:m  (cull-soft:io draft-road)
            $
          ==
        ==
      ::
          ::  /proc/scan.json: full scan process (must be before generic @)
          ::
          [[%proc ~] %'scan.json']
        ;<  ~  bind:m  (rise-wait:io prod "%scan: failed")
        =/  data-road=road:tarball  (cord-to-road:tarball '../data.wallet_account')
        ;<  cur=view:nexus  bind:m
          (keep:io /acct (cord-to-road:tarball '../') ~)
        =/  acct=(unit account-data)  (extract-account cur)
        ?~  acct  (pure:m ~)
        ::  read existing progress to resume where we left off
        ;<  prev-state=vase  bind:m  get-state:io
        =/  prev-json=json  (fall (mole |.(!<(json prev-state))) *json)
        =/  prev=scan-progress  (parse-scan-progress prev-json)
        =/  recv-start-idx=@ud
          ?:  =('recv' phase.prev)  idx.prev
          ?:  =('chng' phase.prev)  0  ::  recv already done
          0
        =/  recv-start-gap=@ud
          ?:  =('recv' phase.prev)  gap.prev
          0
        =/  skip-recv=?  =('chng' phase.prev)
        ::  scan receiving then change
        ;<  ~  bind:m
          ?:  skip-recv  =/(m (fiber:fiber:nexus ,~) (pure:m ~))
          (scan-chain u.acct %receiving active-network.u.acct recv-start-idx recv-start-gap)
        =/  chng-start-idx=@ud
          ?:  =('chng' phase.prev)  idx.prev
          0
        =/  chng-start-gap=@ud
          ?:  =('chng' phase.prev)  gap.prev
          0
        ;<  ~  bind:m
          (scan-chain u.acct %change active-network.u.acct chng-start-idx chng-start-gap)
        (pure:m ~)
          ::  /proc/refresh-*.json: per-address refresh process
          ::
          [[%proc ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%refresh: failed")
        ::  parse params from state
        ;<  state=vase  bind:m  get-state:io
        =/  params=json  (fall (mole |.(!<(json state))) *json)
        ?.  ?=([%o *] params)  stay:m
        ?.  (~(has by p.params) 'network')  stay:m
        =/  network=?(%main %testnet3 %testnet4 %signet %regtest)
          ;;(?(%main %testnet3 %testnet4 %signet %regtest) (slav %tas (~(dog jo:json-utils params) /network so:dejs:format)))
        =/  chain-tag=?(%recv %chng)
          ;;(?(%recv %chng) (slav %tas (~(dog jo:json-utils params) /chain so:dejs:format)))
        =/  idx=@ud  (~(dog jo:json-utils params) /index ni:dejs:format)
        ~&  >  [%refresh %start network=network chain=chain-tag idx=idx]
        ::  set loading flag
        ;<  mop=addr-mop  bind:m  (read-mop ".." network chain-tag)
        =/  dat=(unit address-data)
          (get:((on @ud address-data) gth) mop idx)
        ?~  dat  ~&(>>> [%refresh %bail-no-addr-at-idx idx=idx] (pure:m ~))
        =/  loading-mop=addr-mop
          (put:((on @ud address-data) gth) mop idx u.dat(loading %.y))
        ;<  ~  bind:m  (write-mop ".." network chain-tag loading-mop)
        ::  fetch address info
        =/  base=tape  (mempool-base-url network)
        =/  addr-url=@t  (crip (weld base (trip addr.u.dat)))
        ~&  >  [%refresh %fetching addr=addr.u.dat]
        ;<  ~  bind:m  (send-request:io [%'GET' addr-url ~[['Accept' 'application/json']] ~])
        ;<  info-resp=client-response:iris  bind:m  take-http
        ;<  now=@da  bind:m  get-time:io
        =/  info=(unit address-info)
          (parse-info-response info-resp now)
        ::  fetch UTXOs
        =/  utxo-url=@t  (crip (weld (weld base (trip addr.u.dat)) "/utxo"))
        ;<  ~  bind:m  (send-request:io [%'GET' utxo-url ~[['Accept' 'application/json']] ~])
        ;<  utxo-resp=client-response:iris  bind:m  take-http
        =/  new-utxos=(list utxo)  (parse-utxo-response utxo-resp)
        ::  fetch txs
        =/  txs-url=@t  (crip (weld (weld base (trip addr.u.dat)) "/txs"))
        ;<  ~  bind:m  (send-request:io [%'GET' txs-url ~[['Accept' 'application/json']] ~])
        ;<  txs-resp=client-response:iris  bind:m  take-http
        =/  new-txs=(list transaction)  (parse-txs-response txs-resp)
        ::  clear loading, write results
        =/  updated=address-data  u.dat(loading %.n, info info, utxos new-utxos)
        ;<  fresh-mop=addr-mop  bind:m  (read-mop ".." network chain-tag)
        =/  new-mop=addr-mop
          (put:((on @ud address-data) gth) fresh-mop idx updated)
        ;<  ~  bind:m  (write-mop ".." network chain-tag new-mop)
        ::  merge new txs into tx-map
        ;<  existing-txs=tx-map  bind:m  (read-txs ".." network)
        =/  merged=tx-map
          %-  ~(gas by existing-txs)
          (turn new-txs |=(=transaction [txid.transaction transaction]))
        ;<  ~  bind:m  (write-txs ".." network merged)
        ~&  >  [%refresh %done network=network chain=chain-tag idx=idx info=?=(^ info) utxos=(lent new-utxos) txs=(lent new-txs)]
        (pure:m ~)
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
        ==
          %|
        ?+  rail.p.mana  'File under this account.'
          [~ %'data.wallet_account']  'Account data: name, xprv, script-type, addresses. Mark: account.'
          [~ %'main.sig']      'Poke handler for account actions. Mark: sig.'
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
  [%.n [~ [/ %manx] !>((detail-page:acct-ui acct *addr-mop *addr-mop *@da %none ~ ~ ''))]]
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
++  read-draft-file
  =/  m  (fiber:fiber:nexus ,(unit transaction:drft))
  ^-  form:m
  =/  draft-road=road:tarball
    (cord-to-road:tarball './data.wallet_draft')
  ;<  exists=?  bind:m  (peek-exists:io draft-road)
  ?.  exists  (pure:m ~)
  ;<  seen=seen:nexus  bind:m  (peek:io draft-road ~)
  ?.  ?=(%& -.seen)  (pure:m ~)
  ?.  ?=([%file *] p.seen)  (pure:m ~)
  (pure:m (mole |.(!<(transaction:drft q.sage.p.seen))))
::
++  write-draft
  |=  dr=transaction:drft
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  road=road:tarball  (cord-to-road:tarball './data.wallet_draft')
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?:  exists
    (over:io road [[/wallet %draft] !>(dr)])
  (make:io road |+[%.n [[/wallet %draft] !>(dr)] ~])
::
++  read-wallet-name
  |=  wallet-fp=@ux
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  =/  fp-hex=tape  (hexn:http-utils wallet-fp)
  =/  wal-road=road:tarball
    (cord-to-road:tarball (crip "../../wallets/{fp-hex}.wallet_wallet/main.wallet_wallet"))
  ;<  exists=?  bind:m  (peek-exists:io wal-road)
  ?.  exists  (pure:m '')
  ;<  seen=seen:nexus  bind:m  (peek:io wal-road ~)
  ?.  ?=(%& -.seen)  (pure:m '')
  ?.  ?=([%file *] p.seen)  (pure:m '')
  =/  wal=(unit wallet-data)  (mole |.(!<(wallet-data q.sage.p.seen)))
  ?~  wal  (pure:m '')
  (pure:m name.u.wal)
::
++  collect-utxo-inputs
  |=  [recv=addr-mop chng=addr-mop =script-type]
  ^-  (list utxo-input:drft)
  =/  spend=spend:fees  script-type
  =/  all=(list [@ud address-data])
    (weld (mop-to-list recv) (mop-to-list chng))
  %-  zing
  %+  turn  all
  |=  [idx=@ud a=address-data]
  %+  turn  utxos.a
  |=  u=utxo
  ^-  utxo-input:drft
  [txid.u vout.u value.u spend]
::
+$  scan-progress  [phase=@t idx=@ud gap=@ud]
::
++  parse-scan-progress
  |=  jon=json
  ^-  scan-progress
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
::
++  derive-addr
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
::  +extract-mops: pull recv and chng addr-mops from a ball view
::
++  extract-mops
  |=  [=view:nexus network=?(%main %testnet3 %testnet4 %signet %regtest)]
  ^-  [recv=addr-mop chng=addr-mop]
  ?.  ?=([%ball *] view)  [*addr-mop *addr-mop]
  =/  addrs-ball=(unit ball:tarball)  (~(get by dir.ball.view) 'addresses')
  ?~  addrs-ball  [*addr-mop *addr-mop]
  =/  net-ball=(unit ball:tarball)  (~(get by dir.u.addrs-ball) ;;(@ta network))
  ?~  net-ball  [*addr-mop *addr-mop]
  ?~  fil.u.net-ball  [*addr-mop *addr-mop]
  =/  recv=addr-mop
    =/  ct=(unit content:tarball)  (~(get by contents.u.fil.u.net-ball) 'recv.wallet_addresses')
    ?~  ct  *addr-mop
    (fall (mole |.(!<(addr-mop q.sage.u.ct))) *addr-mop)
  =/  chng=addr-mop
    =/  ct=(unit content:tarball)  (~(get by contents.u.fil.u.net-ball) 'chng.wallet_addresses')
    ?~  ct  *addr-mop
    (fall (mole |.(!<(addr-mop q.sage.u.ct))) *addr-mop)
  [recv chng]
::  +addr-road: compute road to a chain's mop file
::
++  addr-road
  |=  [base=tape network=?(%main %testnet3 %testnet4 %signet %regtest) chain=?(%recv %chng)]
  ^-  road:tarball
  (cord-to-road:tarball (crip "{base}/addresses/{(trip ;;(@ta network))}/{(trip chain)}.wallet_addresses"))
::  +read-mop: fiber that reads a single mop file
::
++  read-mop
  |=  [base=tape network=?(%main %testnet3 %testnet4 %signet %regtest) chain=?(%recv %chng)]
  =/  m  (fiber:fiber:nexus ,addr-mop)
  ^-  form:m
  =/  road=road:tarball  (addr-road base network chain)
  ~&  >>  [%read-mop %road road network=network chain=chain]
  ;<  exists=?  bind:m  (peek-exists:io road)
  ~&  >>  [%read-mop %exists exists]
  ?.  exists  ~&(>>> [%read-mop %no-file-returning-empty] (pure:m *addr-mop))
  ;<  seen=seen:nexus  bind:m  (peek:io road ~)
  ~&  >>  [%read-mop %seen-type ?=([%& %file *] seen)]
  ?.  ?=([%& %file *] seen)  ~&(>>> [%read-mop %not-file-node] (pure:m *addr-mop))
  =/  result=addr-mop  (fall (mole |.(!<(addr-mop q.sage.p.seen))) *addr-mop)
  ~&  >>  [%read-mop %ok size=(lent (tap:((on @ud address-data) gth) result))]
  (pure:m result)
::  +write-mop: fiber that writes a mop file (creates dir structure if needed)
::
++  write-mop
  |=  [base=tape network=?(%main %testnet3 %testnet4 %signet %regtest) chain=?(%recv %chng) mop=addr-mop]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  road=road:tarball  (addr-road base network chain)
  ~&  >>  [%write-mop %road road network=network chain=chain]
  ;<  exists=?  bind:m  (peek-exists:io road)
  ~&  >>  [%write-mop %exists exists]
  ?:  exists
    ~&  >>  [%write-mop %overwriting]
    (over:io road [[/wallet %addresses] !>(mop)])
  ~&  >>  [%write-mop %creating]
  (make:io road |+[%.n [[/wallet %addresses] !>(mop)] ~])
::  +txs-road: compute road to the tx-map file
::
++  txs-road
  |=  [base=tape network=?(%main %testnet3 %testnet4 %signet %regtest)]
  ^-  road:tarball
  (cord-to-road:tarball (crip "{base}/addresses/{(trip ;;(@ta network))}/txs.wallet_txs"))
::  +read-txs: fiber that reads the tx-map file
::
++  read-txs
  |=  [base=tape network=?(%main %testnet3 %testnet4 %signet %regtest)]
  =/  m  (fiber:fiber:nexus ,tx-map)
  ^-  form:m
  =/  road=road:tarball  (txs-road base network)
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?.  exists  (pure:m *tx-map)
  ;<  seen=seen:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%& %file *] seen)  (pure:m *tx-map)
  (pure:m (fall (mole |.(!<(tx-map q.sage.p.seen))) *tx-map))
::  +write-txs: fiber that writes the tx-map file
::
++  write-txs
  |=  [base=tape network=?(%main %testnet3 %testnet4 %signet %regtest) txs=tx-map]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  road=road:tarball  (txs-road base network)
  ;<  exists=?  bind:m  (peek-exists:io road)
  ?:  exists
    (over:io road [[/wallet %txs] !>(txs)])
  (make:io road |+[%.n [[/wallet %txs] !>(txs)] ~])
::  +ensure-net-dir: create network dir + empty mop files if needed
::
++  ensure-net-dir
  |=  network=?(%main %testnet3 %testnet4 %signet %regtest)
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  recv-road=road:tarball  (addr-road "." network %recv)
  ;<  exists=?  bind:m  (peek-exists:io recv-road)
  ?:  exists  (pure:m ~)
  ;<  ~  bind:m  (write-mop "." network %recv *addr-mop)
  ;<  ~  bind:m  (write-mop "." network %chng *addr-mop)
  (write-txs "." network *tx-map)
::  +mop-to-list: tap mop to indexed list (ascending by index)
::
++  mop-to-list
  |=  mop=addr-mop
  ^-  (list [@ud address-data])
  (flop (tap:((on @ud address-data) gth) mop))
::
::  scan event: either an HTTP response or a pause/resume poke
::
+$  scan-event
  $%  [%http =client-response:iris]
      [%pause ~]
      [%resume ~]
  ==
::
++  take-scan-event
  =/  m  (fiber:fiber:nexus ,scan-event)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error:io dart.u.in)]
      [~ %poke * *]
    ?:  =([/ %http-response] p.sage.u.in)
      =/  resp=client-response:iris  !<(client-response:iris q.sage.u.in)
      ?:  ?=(%cancel -.resp)
        [%fail leaf+"http-request-cancelled" ~]
      [%done %http resp]
    =/  res=(unit json)  (mole |.(!<(json q.sage.u.in)))
    ?~  res  [%skip ~]
    ?.  ?=([%o *] u.res)  [%skip ~]
    =/  act=(unit json)  (~(get by p.u.res) 'action')
    ?:  =(`s+'pause' act)   [%done %pause ~]
    ?:  =(`s+'resume' act)  [%done %resume ~]
    [%skip ~]
  ==
::
++  mempool-base-url
  |=  network=?(%main %testnet3 %testnet4 %signet %regtest)
  ^-  tape
  ?-  network
    %main      "https://mempool.space/api/address/"
    %testnet3  "https://mempool.space/testnet/api/address/"
    %testnet4  "https://mempool.space/testnet4/api/address/"
    %signet    "https://mempool.space/signet/api/address/"
    %regtest   "http://localhost:3000/address/"
  ==
::  +scan-fetch: like fetch-address-info but pausable during HTTP wait
::
++  scan-fetch
  |=  [address=@t network=?(%main %testnet3 %testnet4 %signet %regtest)]
  =/  m  (fiber:fiber:nexus ,(unit address-info))
  ^-  form:m
  =/  url=@t
    (crip (weld (mempool-base-url network) (trip address)))
  =/  =request:http
    [%'GET' url ~[['Accept' 'application/json']] ~]
  ;<  ~  bind:m  (send-request:io request)
  |-
  ;<  evt=scan-event  bind:m  take-scan-event
  ?-    -.evt
      %pause   ;<  ~  bind:m  pause-loop  $
      %resume  $
      %http    (parse-address-response client-response.evt)
  ==
::  +parse-address-response: extract address-info from HTTP response
::
++  parse-address-response
  |=  =client-response:iris
  =/  m  (fiber:fiber:nexus ,(unit address-info))
  ^-  form:m
  ?.  ?=(%finished -.client-response)
    (pure:m ~)
  ?~  full-file.client-response
    (pure:m ~)
  =/  body=@t  q.data.u.full-file.client-response
  =/  parsed=(each json tang)  (mule |.((need (de:json:html body))))
  ?:  ?=(%| -.parsed)  (pure:m ~)
  =/  data=json  p.parsed
  =/  tx-count=(unit @ud)
    (mole |.((ni:dejs:format (~(got jo:json-utils data) /'chain_stats'/'tx_count'))))
  =/  funded=(unit @ud)
    (mole |.((ni:dejs:format (~(got jo:json-utils data) /'chain_stats'/'funded_txo_sum'))))
  =/  spent=(unit @ud)
    (mole |.((ni:dejs:format (~(got jo:json-utils data) /'chain_stats'/'spent_txo_sum'))))
  ?~  tx-count  (pure:m ~)
  ?~  funded    (pure:m ~)
  ?~  spent     (pure:m ~)
  ;<  now=@da  bind:m  get-time:io
  (pure:m `[u.tx-count u.funded u.spent now])
::  +take-http: simple HTTP response handler for non-cancellable requests
::
++  take-http
  =/  m  (fiber:fiber:nexus ,client-response:iris)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %poke * *]
    ?.  =([/ %http-response] p.sage.u.in)  [%skip ~]
    =/  resp=client-response:iris  !<(client-response:iris q.sage.u.in)
    [%done resp]
  ==
::  +parse-info-response: extract address-info from HTTP response (non-fiber)
::
++  parse-info-response
  |=  [=client-response:iris now=@da]
  ^-  (unit address-info)
  ?.  ?=(%finished -.client-response)  ~
  ?~  full-file.client-response  ~
  =/  body=@t  q.data.u.full-file.client-response
  =/  parsed=(each json tang)  (mule |.((need (de:json:html body))))
  ?:  ?=(%| -.parsed)  ~
  =/  data=json  p.parsed
  =/  tc=(unit @ud)  (mole |.((ni:dejs:format (~(got jo:json-utils data) /'chain_stats'/'tx_count'))))
  =/  funded=(unit @ud)  (mole |.((ni:dejs:format (~(got jo:json-utils data) /'chain_stats'/'funded_txo_sum'))))
  =/  spent=(unit @ud)  (mole |.((ni:dejs:format (~(got jo:json-utils data) /'chain_stats'/'spent_txo_sum'))))
  ?:  |(?=(~ tc) ?=(~ funded) ?=(~ spent))  ~
  `[u.tc u.funded u.spent now]
::  +parse-utxo-response: extract UTXOs from HTTP response
::
++  parse-utxo-response
  |=  =client-response:iris
  ^-  (list utxo)
  ?.  ?=(%finished -.client-response)  ~
  ?~  full-file.client-response  ~
  =/  body=@t  q.data.u.full-file.client-response
  =/  parsed=(each json tang)  (mule |.((need (de:json:html body))))
  ?:  ?=(%| -.parsed)  ~
  ?.  ?=(%a -.p.parsed)  ~
  %+  murn  p.p.parsed
  |=  j=json
  ^-  (unit utxo)
  =/  txid=(unit @t)
    (mole |.((so:dejs:format (~(got jo:json-utils j) /txid))))
  =/  vout=(unit @ud)
    (mole |.((ni:dejs:format (~(got jo:json-utils j) /vout))))
  =/  value=(unit @ud)
    (mole |.((ni:dejs:format (~(got jo:json-utils j) /value))))
  ?~  txid   ~
  ?~  vout   ~
  ?~  value  ~
  =/  status=tx-status
    =/  sj=(unit json)  (mole |.((~(got jo:json-utils j) /status)))
    ?~  sj  [%unconfirmed ~]
    (parse-tx-status u.sj)
  `[u.txid u.vout u.value status]
::
++  parse-tx-status
  |=  sj=json
  ^-  tx-status
  =/  conf=(unit ?)
    (mole |.((bo:dejs:format (~(got jo:json-utils sj) /confirmed))))
  ?~  conf  [%unconfirmed ~]
  ?.  u.conf  [%unconfirmed ~]
  =/  bh=(unit @t)
    (mole |.((so:dejs:format (~(got jo:json-utils sj) /'block_hash'))))
  =/  ht=(unit @ud)
    (mole |.((ni:dejs:format (~(got jo:json-utils sj) /'block_height'))))
  ?~  bh  [%unconfirmed ~]
  ?~  ht  [%unconfirmed ~]
  [%confirmed u.bh u.ht]
::  +parse-txs-response: extract transactions from HTTP response
::
++  parse-txs-response
  |=  =client-response:iris
  ^-  (list transaction)
  ?.  ?=(%finished -.client-response)  ~
  ?~  full-file.client-response  ~
  =/  body=@t  q.data.u.full-file.client-response
  =/  parsed=(each json tang)  (mule |.((need (de:json:html body))))
  ?:  ?=(%| -.parsed)  ~
  ?.  ?=(%a -.p.parsed)  ~
  %+  murn  p.p.parsed
  |=  tj=json
  ^-  (unit transaction)
  =/  txid=(unit @t)
    (mole |.((so:dejs:format (~(got jo:json-utils tj) /txid))))
  ?~  txid  ~
  =/  vin-json=(unit json)  (mole |.((~(got jo:json-utils tj) /vin)))
  =/  inputs=(list tx-input)
    ?~  vin-json  ~
    ?.  ?=(%a -.u.vin-json)  ~
    %+  murn  p.u.vin-json
    |=  ij=json
    ^-  (unit tx-input)
    =/  st=(unit @t)  (mole |.((so:dejs:format (~(got jo:json-utils ij) /txid))))
    =/  sv=(unit @ud)  (mole |.((ni:dejs:format (~(got jo:json-utils ij) /vout))))
    ?~  st  ~
    ?~  sv  ~
    =/  prevout=(unit tx-output)
      =/  pj=(unit json)  (mole |.((~(got jo:json-utils ij) /prevout)))
      ?~  pj  ~
      =/  pv=(unit @ud)  (mole |.((ni:dejs:format (~(got jo:json-utils u.pj) /value))))
      =/  pa=(unit @t)  (mole |.((so:dejs:format (~(got jo:json-utils u.pj) /'scriptpubkey_address'))))
      ?~  pv  ~
      ?~  pa  ~
      `[u.pv u.pa]
    `[u.st u.sv prevout]
  =/  vout-json=(unit json)  (mole |.((~(got jo:json-utils tj) /vout)))
  =/  outputs=(list tx-output)
    ?~  vout-json  ~
    ?.  ?=(%a -.u.vout-json)  ~
    %+  murn  p.u.vout-json
    |=  oj=json
    ^-  (unit tx-output)
    =/  v=(unit @ud)  (mole |.((ni:dejs:format (~(got jo:json-utils oj) /value))))
    =/  a=(unit @t)  (mole |.((so:dejs:format (~(got jo:json-utils oj) /'scriptpubkey_address'))))
    ?~  v  ~
    ?~  a  ~
    `[u.v u.a]
  =/  sj=(unit json)  (mole |.((~(got jo:json-utils tj) /status)))
  =/  status=tx-status
    ?~  sj  [%unconfirmed ~]
    (parse-tx-status u.sj)
  =/  fee=(unit @ud)  (mole |.((ni:dejs:format (~(got jo:json-utils tj) /fee))))
  =/  size=(unit @ud)  (mole |.((ni:dejs:format (~(got jo:json-utils tj) /size))))
  `[u.txid inputs outputs status fee size]
::
::  +pause-loop: block until resumed, managing marker file
::
++  take-pause-event
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]
    [%fail (veto-error:io dart.u.in)]
      [~ %poke * *]
    =/  res=(unit json)  (mole |.(!<(json q.sage.u.in)))
    ?~  res  [%skip ~]
    ?.  ?=([%o *] u.res)  [%skip ~]
    =/  act=(unit json)  (~(get by p.u.res) 'action')
    ?:  =(`s+'resume' act)  [%done %.y]
    [%skip ~]
  ==
::
++  pause-loop
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  marker-json=json  (pairs:enjs:format ~[['paused' b+%.y]])
  ;<  ~  bind:m
    (make:io (cord-to-road:tarball '../scan-paused.json') |+[%.n [[/ %json] !>(marker-json)] ~])
  |-
  ;<  resumed=?  bind:m  take-pause-event
  ?.  resumed  $
  ;<  *  bind:m  (cull-soft:io (cord-to-road:tarball '../scan-paused.json'))
  (pure:m ~)
::
++  scan-chain
  |=  $:  acct=account-data
          chain=?(%receiving %change)
          network=?(%main %testnet3 %testnet4 %signet %regtest)
          start-idx=@ud
          start-gap=@ud
      ==
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  is-change=?  =(chain %change)
  =/  chain-tag=?(%recv %chng)  ?:(is-change %chng %recv)
  =/  gap-limit=@ud  20
  =/  scan-idx=@ud  start-idx
  =/  gap=@ud  start-gap
  |-
  ?:  (gte gap gap-limit)
    (pure:m ~)
  =/  new-addr=(unit @t)
    %:  derive-addr
      xprv.acct
      script-type.acct
      network
      ?:(is-change 1 0)
      scan-idx
    ==
  ?~  new-addr
    (pure:m ~)
  ::  update scan progress in proc file
  =/  phase-tape=@t  ?:(is-change 'chng' 'recv')
  =/  scan-prog=json
    %-  pairs:enjs:format
    :~  ['phase' s+phase-tape]
        ['idx' (numb:enjs:format scan-idx)]
        ['gap' (numb:enjs:format gap)]
    ==
  ;<  ~  bind:m  (replace:io !>(scan-prog))
  ::  write address with loading flag before fetch
  =/  loading-dat=address-data  [u.new-addr %.y ~ ~ ~]
  ;<  pre-mop=addr-mop  bind:m  (read-mop ".." network chain-tag)
  =/  pre-updated=addr-mop
    (put:((on @ud address-data) gth) pre-mop scan-idx loading-dat)
  ;<  ~  bind:m  (write-mop ".." network chain-tag pre-updated)
  ;<  ~  bind:m  (sleep:io `@dr`(div ~s1 1.000))
  ::  fetch address info
  ;<  new-info=(unit address-info)  bind:m
    (scan-fetch u.new-addr network)
  ::  clear loading, write results
  =/  addr-dat=address-data  [u.new-addr %.n ~ new-info ~]
  ;<  mop=addr-mop  bind:m  (read-mop ".." network chain-tag)
  =/  updated=addr-mop
    (put:((on @ud address-data) gth) mop scan-idx addr-dat)
  ;<  ~  bind:m  (write-mop ".." network chain-tag updated)
  ::  check gap
  ?~  new-info
    $(scan-idx +(scan-idx), gap +(gap))
  ?:  =(0 tx-count.u.new-info)
    $(scan-idx +(scan-idx), gap +(gap))
  $(scan-idx +(scan-idx), gap 0)
--
