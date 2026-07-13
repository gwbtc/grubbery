/<  tools  /lib/nex/tools.hoon
/<  b329   /lib/bip329.hoon
::  wallet-labels: show BIP329 labels for the wallet
::
^-  tool:tools
|%
++  name  'wallet_labels'
++  description
  ^~  %-  crip
  ;:  weld
    "Show BIP329 labels stored in the wallet. "
    "Optionally filter by type (addr, tx, xpub, output, input, pubkey) "
    "or by a label substring."
  ==
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  malt
  :~  ['type' [%string 'Optional: filter by label type (addr, tx, xpub, output, input, pubkey)']]
      ['filter' [%string 'Optional: show only labels containing this substring']]
  ==
++  required  ~
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  type-filter=(unit @t)
    (bind (~(get by args.st) 'type') |=(j=json ?>(?=(%s -.j) p.j)))
  =/  sub-filter=(unit @t)
    (bind (~(get by args.st) 'filter') |=(j=json ?>(?=(%s -.j) p.j)))
  ::  load labels
  ;<  lbl-view=view:nexus  bind:m
    (peek:io [%& %& /apps/'wallet.wallet_app' %'labels.wallet_labels'] ~)
  =/  lbls=labels:b329
    ?.  ?=([%file *] lbl-view)  *labels:b329
    (fall (mole |.(!<(labels:b329 (need-vase:tarball sang.lbl-view)))) *labels:b329)
  ::  format each category
  =/  out=wain  ~
  =/  cats=(list [@t (map @t (set label-entry:b329))])
    :~  ['addr' addr.lbls]
        ['tx' tx.lbls]
        ['xpub' xpub.lbls]
        ['output' output.lbls]
        ['input' input.lbls]
        ['pubkey' pubkey.lbls]
    ==
  |-
  ?~  cats
    ?~  out
      (pure:m [%text 'No labels found.'])
    (pure:m [%text (of-wain:format (flop out))])
  =/  [cat-name=@t entries=(map @t (set label-entry:b329))]  i.cats
  ::  skip if type filter doesn't match
  ?:  ?&  ?=(^ type-filter)
          !=(u.type-filter cat-name)
      ==
    $(cats t.cats)
  =/  pairs=(list [@t (set label-entry:b329)])  ~(tap by entries)
  =/  cat-lines=wain
    %+  murn  pairs
    |=  [ref=@t es=(set label-entry:b329)]
    =/  labels=wain
      %+  murn  ~(tap in es)
      |=  e=label-entry:b329
      ?:  ?&  ?=(^ sub-filter)
              ?=(~ (find (trip u.sub-filter) (trip label.e)))
          ==
        ~
      `label.e
    ?~  labels  ~
    =/  joined=@t
      |-
      ?~  t.labels  i.labels
      (rap 3 ~[i.labels ', ' $(labels t.labels)])
    `(rap 3 ~['  ' ref ': ' joined])
  ?~  cat-lines  $(cats t.cats)
  =.  out  (weld (flop cat-lines) [(rap 3 ~['[' cat-name ']']) out])
  $(cats t.cats)
--
