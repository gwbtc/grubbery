/<  tools  /lib/nex/tools.hoon
/<  wt     /lib/wallet-types.hoon
::  wallet-request-address: ask another ship for a receive address
::
::  Sends an address-request poke to the target ship, then
::  subscribes to the local offer-log and waits for the response.
::
=,  wt
^-  tool:tools
|%
++  name  'wallet_request_address'
++  description
  ^~  %-  crip
  ;:  weld
    "Request a receive address from another ship's wallet. "
    "Pokes the target ship's wallet with an address-request. "
    "Waits for the target to derive and send back a fresh address. "
    "Network defaults to testnet3."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  malt
  :~  ['ship' [%string 'Target ship (e.g. ~zod)']]
      ['network' [%string 'Optional: network (main, testnet3, testnet4, signet, regtest). Default: testnet3']]
  ==
++  required  ~['ship']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  ?.  (~(has jo:json-utils [%o args.st]) /ship)
    (pure:m [%error 'Missing required parameter: ship (e.g. ~zod)'])
  =/  ship-raw=@t
    (~(dog jo:json-utils [%o args.st]) /ship so:dejs:format)
  =/  net-raw=@t
    (~(dug jo:json-utils [%o args.st]) /network so:dejs:format 'testnet3')
  =/  target=@p  (slav %p ship-raw)
  =/  net=?(%main %testnet3 %testnet4 %signet %regtest)
    ;;(?(%main %testnet3 %testnet4 %signet %regtest) net-raw)
  ::  snapshot offer-log length before requesting
  =/  log-road=road:tarball
    [%& %& /apps/'wallet.wallet_app' %'offer-log.json']
  ;<  log-view=view:nexus  bind:m  (peek:io log-road ~)
  =/  cur-len=@ud
    ?.  ?=([%file *] log-view)  0
    =/  j=json
      (fall (mole |.(!<(json (need-vase:tarball sang.log-view)))) [%a ~])
    ?.  ?=(%a -.j)  0
    (lent p.j)
  ::  subscribe to offer-log for updates
  ;<  *  bind:m  (keep:io /offer-log log-road ~)
  ::  send the request
  =/  jon=json
    %-  pairs:enjs:format
    :~  ['action' s+'address-request']
        ['network' s+net-raw]
    ==
  =/  req=load:remo:nexus
    :_  [%poke [[/ %json] jon]]
    [/remote-poke %& /apps/'wallet.wallet_app' %'main.sig']
  ;<  ~  bind:m
    (gall-poke:io [target %grubbery] grubbery-load+req)
  ::  set timeout
  ;<  now=@da  bind:m  get-time:io
  ;<  ~  bind:m  (send-wait:io (add now ~s30))
  ::  wait for offer-log to update
  |-
  ;<  nw=news-or-wake:io  bind:m  (take-news-or-wake:io /offer-log)
  ?:  ?=(%wake -.nw)
    ;<  ~  bind:m  (drop:io /offer-log log-road)
    (pure:m [%error 'Timed out waiting for address offer'])
  ::  check if there's a new entry
  ;<  new-view=view:nexus  bind:m  (peek:io log-road ~)
  ?.  ?=([%file *] new-view)  $
  =/  log=json
    (fall (mole |.(!<(json (need-vase:tarball sang.new-view)))) [%a ~])
  ?.  ?=(%a -.log)  $
  ?.  (gth (lent p.log) cur-len)  $
  ::  check the latest entry
  =/  latest=json  (rear p.log)
  ?.  ?=(%o -.latest)  $
  =/  got-ship=@t
    (~(dug jo:json-utils latest) /ship so:dejs:format '')
  =/  got-addr=@t
    (~(dug jo:json-utils latest) /address so:dejs:format '')
  =/  got-net=@t
    (~(dug jo:json-utils latest) /network so:dejs:format '')
  ::  unsubscribe
  ;<  ~  bind:m  (drop:io /offer-log log-road)
  =/  out=wain
    :~  (rap 3 ~['Received address from ' ship-raw ':'])
        (rap 3 ~['  address: ' got-addr])
        (rap 3 ~['  network: ' got-net])
    ==
  (pure:m [%text (of-wain:format out)])
--
