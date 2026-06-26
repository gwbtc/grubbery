/<  tools  /lib/nex/tools.hoon
/<  wt     /lib/wallet-types.hoon
/<  b329   /lib/bip329.hoon
::  wallet-add-account: add an account to an existing wallet
::
=,  wt
^-  tool:tools
|%
++  name  'wallet_add_account'
++  description
  ^~  %-  crip
  ;:  weld
    "Add a new account to an existing wallet. Specify wallet key, "
    "account name, purpose (44=p2pkh, 49=p2sh-p2wpkh, 84=p2wpkh, "
    "86=p2tr), coin type (0=mainnet, 1=testnet), and account number."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  malt
  :~  ['wallet' [%string 'Wallet xpub key (from wallet_status)']]
      ['name' [%string 'Account name (default: Default)']]
      ['purpose' [%string 'BIP purpose: 44, 49, 84, 86 (default: 84)']]
      ['coin_type' [%string 'Coin type: 0=mainnet, 1=testnet (default: 1)']]
      ['account_number' [%string 'Account index (default: 0)']]
  ==
++  required  ~['wallet']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  ?.  (~(has jo:json-utils [%o args.st]) /wallet)
    (pure:m [%error 'Missing required parameter: wallet (xpub key from wallet_status)'])
  =/  wallet-key=@t
    (~(dog jo:json-utils [%o args.st]) /wallet so:dejs:format)
  =/  acct-name=@t
    (~(dug jo:json-utils [%o args.st]) /name so:dejs:format 'Default')
  =/  purpose=@t
    (~(dug jo:json-utils [%o args.st]) /purpose so:dejs:format '84')
  =/  coin-type=@t
    (~(dug jo:json-utils [%o args.st]) /'coin_type' so:dejs:format '1')
  =/  acct-num=@t
    (~(dug jo:json-utils [%o args.st]) /'account_number' so:dejs:format '0')
  ::  poke main.sig
  =/  main-road=road:tarball
    [%& %& /apps/'wallet.wallet_app' %'main.sig']
  ;<  ~  bind:m
    %:  poke:io  main-road
      :-  [/ %json]
      %-  pairs:enjs:format
      :~  ['action' s+'add-account']
          ['wallet-key' s+wallet-key]
          ['account-name' s+acct-name]
          ['purpose-select' s+purpose]
          ['coin-type-select' s+coin-type]
          ['account-number' s+acct-num]
      ==
    ==
  =/  stype=@t
    ?+  purpose  'p2wpkh'
      %'44'  'p2pkh'
      %'49'  'p2sh-p2wpkh'
      %'84'  'p2wpkh'
      %'86'  'p2tr'
    ==
  =/  net=@t
    ?:  =(coin-type '0')  'mainnet'
    'testnet'
  =/  out=wain
    :~  'Account added.'
        (rap 3 ~['  wallet: ' (end [3 12] wallet-key) '...'])
        (rap 3 ~['  name: ' acct-name])
        (rap 3 ~['  purpose: ' purpose ' (' stype ')'])
        (rap 3 ~['  coin-type: ' coin-type ' (' net ')'])
        (rap 3 ~['  account: ' acct-num])
    ==
  (pure:m [%text (of-wain:format out)])
--
