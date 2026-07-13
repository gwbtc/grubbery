/<  tools    /lib/nex/tools.hoon
/<  wt       /lib/wallet-types.hoon
/<  aio      /lib/wallet/account-io.hoon
/<  b329     /lib/bip329.hoon
/<  taproot  /lib/taproot.hoon
::  wallet-tapscripts: list tapscript trees and their addresses
::
=,  wt
^-  tool:tools
|%
++  name  'wallet_tapscripts'
++  description
  ^~  %-  crip
  ;:  weld
    "List all tapscript trees stored in the wallet. Shows each "
    "tapscript address, its parent key-path address, name, and "
    "tree structure. Optionally filter by parent address."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  malt
  :~  ['parent' [%string 'Filter by parent address (optional)']]
  ==
++  required  *(list @t)
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  parent-filter=@t
    (~(dug jo:json-utils [%o args.st]) /parent so:dejs:format '')
  ::  load ptsts store
  ;<  ptst-view=view:nexus  bind:m
    (peek:io [%& %& /apps/'wallet.wallet_app' %'ptsts.wallet_ptsts'] ~)
  =/  sts=(map @t ptst:taproot)
    ?.  ?=([%file *] ptst-view)  *(map @t ptst:taproot)
    (fall (mole |.(!<((map @t ptst:taproot) (need-vase:tarball sang.ptst-view)))) *(map @t ptst:taproot))
  ::  load labels
  ;<  lbl-view=view:nexus  bind:m
    (peek:io [%& %& /apps/'wallet.wallet_app' %'labels.wallet_labels'] ~)
  =/  lbls=labels:b329
    ?.  ?=([%file *] lbl-view)  *labels:b329
    (fall (mole |.(!<(labels:b329 (need-vase:tarball sang.lbl-view)))) *labels:b329)
  =/  describe-tree
    |=  tree=ptst:taproot
    ^-  @t
    ?~  tree  '(empty)'
    ?-  -.tree
        %leaf
      =/  script-hex=@t  (scot %ux dat.script.tapleaf.tree)
      (rap 3 ~['leaf(v=' (scot %ux version.tapleaf.tree) ' len=' (crip (a-co:co wid.script.tapleaf.tree)) ' script=' (end [3 8] script-hex) '...)'])
        %opaque
      (rap 3 ~['opaque(' (end [3 10] (scot %ux hash.tree)) '...)'])
        %branch
      (rap 3 ~['branch(' $(tree l.tree) ', ' $(tree r.tree) ')'])
    ==
  ::  enumerate tapscript entries
  =/  entries=(list [ts-addr=@t tree=ptst:taproot])  ~(tap by sts)
  ?~  entries
    (pure:m [%text 'No tapscripts found.'])
  ::  format each entry
  =/  out=wain
    %-  zing
    %+  murn  entries
    |=  [ts-addr=@t tree=ptst:taproot]
    ^-  (unit wain)
    ::  find parent from label
    =/  parent=@t
      =/  prefix=tape  "gwbtc:tapscript-of:"
      =/  prefix-len=@ud  (lent prefix)
      =/  e-u=(unit (set label-entry:b329))  (~(get by addr.lbls) ts-addr)
      ?~  e-u  ''
      =/  el=(list label-entry:b329)  ~(tap in u.e-u)
      |-
      ?~  el  ''
      =/  ltape=tape  (trip label.i.el)
      ?:  =(prefix (scag prefix-len ltape))
        (crip (slag prefix-len ltape))
      $(el t.el)
    ::  apply parent filter
    ?.  |(=('' parent-filter) =(parent-filter parent))
      ~
    =/  ts-name=@t  (get-tapscript-name:aio lbls ts-addr)
    =/  tree-desc=@t  (describe-tree tree)
    :-  ~
    :~  (rap 3 ~['tapscript: ' ts-addr])
        (rap 3 ~['  parent: ' parent])
        ?:  =('' ts-name)  '  name: (unnamed)'
        (rap 3 ~['  name: ' ts-name])
        (rap 3 ~['  tree: ' tree-desc])
        ''
    ==
  ?~  out
    (pure:m [%text 'No tapscripts match filter.'])
  (pure:m [%text (of-wain:format out)])
--
