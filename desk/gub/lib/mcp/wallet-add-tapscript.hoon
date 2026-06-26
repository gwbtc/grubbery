/<  tools  /lib/nex/tools.hoon
/<  wt     /lib/wallet-types.hoon
/<  aio    /lib/wallet/account-io.hoon
/<  b329   /lib/bip329.hoon
::  wallet-add-tapscript: attach a script tree to a p2tr address
::
=,  wt
^-  tool:tools
|%
++  name  'wallet_add_tapscript'
++  description
  ^~  %-  crip
  ;:  weld
    "Add a tapscript tree to a taproot (p2tr) address. Requires "
    "account key, parent address, chain (0=recv, 1=chng), index, "
    "and tree as JSON. Tree nodes: leaf (type, version, script, "
    "script_len), branch (type, l, r), opaque (type, hash). "
    "Optionally pass a name for the tapscript."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  malt
  :~  ['account' [%string 'Account key (p2tr account from wallet_status)']]
      ['parent_addr' [%string 'Parent taproot address to attach tree to']]
      ['chain' [%string 'Chain: 0=receiving, 1=change (default: 0)']]
      ['index' [%string 'Derivation index of the parent address']]
      ['tree' [%string 'Script tree as JSON string']]
      ['name' [%string 'Human-readable name for the tapscript (optional)']]
  ==
++  required  ~['account' 'parent_addr' 'index' 'tree']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  ?.  (~(has jo:json-utils [%o args.st]) /account)
    (pure:m [%error 'Missing required parameter: account (p2tr account key from wallet_status)'])
  ?.  (~(has jo:json-utils [%o args.st]) /'parent_addr')
    (pure:m [%error 'Missing required parameter: parent_addr (parent taproot address)'])
  ?.  (~(has jo:json-utils [%o args.st]) /index)
    (pure:m [%error 'Missing required parameter: index (derivation index of parent address)'])
  ?.  (~(has jo:json-utils [%o args.st]) /tree)
    (pure:m [%error 'Missing required parameter: tree (script tree as JSON string)'])
  =/  ref=@t
    (~(dog jo:json-utils [%o args.st]) /account so:dejs:format)
  =/  parent-addr=@t
    (~(dog jo:json-utils [%o args.st]) /'parent_addr' so:dejs:format)
  =/  chain=@t
    (~(dug jo:json-utils [%o args.st]) /chain so:dejs:format '0')
  =/  idx=@t
    (~(dog jo:json-utils [%o args.st]) /index so:dejs:format)
  =/  tree-str=@t
    (~(dog jo:json-utils [%o args.st]) /tree so:dejs:format)
  =/  ts-name=@t
    (~(dug jo:json-utils [%o args.st]) /name so:dejs:format '')
  ::  parse tree JSON string
  =/  tree-json=(unit json)  (de:json:html tree-str)
  ?~  tree-json
    (pure:m [%error 'Failed to parse tree JSON'])
  ::  poke main.sig
  =/  main-road=road:tarball
    [%& %& /apps/'wallet.wallet_app' %'main.sig']
  =/  chain-ud=@ud  (fall (rush chain dem) 0)
  =/  idx-ud=@ud  (fall (rush idx dem) 0)
  ;<  ~  bind:m
    %:  poke:io  main-road
      :-  [/ %json]
      %-  pairs:enjs:format
      :~  ['action' s+'add-tapscript']
          ['account' s+ref]
          ['parent-addr' s+parent-addr]
          ['chain' (numb:enjs:format chain-ud)]
          ['index' (numb:enjs:format idx-ud)]
          ['tree' u.tree-json]
          ['name' s+ts-name]
      ==
    ==
  =/  out=wain
    :~  'Tapscript added.'
        (rap 3 ~['  account: ' (end [3 20] ref) '...'])
        (rap 3 ~['  parent: ' (end [3 20] parent-addr) '...'])
        (rap 3 ~['  chain: ' chain])
        (rap 3 ~['  index: ' idx])
        ?:  =('' ts-name)  '  name: (none)'
        (rap 3 ~['  name: ' ts-name])
    ==
  (pure:m [%text (of-wain:format out)])
--
