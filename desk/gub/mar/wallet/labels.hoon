::  mark for labels:bip329
::
/<  b329  /lib/bip329.hoon
=,  format
|_  =labels:b329
++  grab
  |%
  ++  noun  labels:b329
  ++  mime
    |=  [p=mite q=octs]
    ^-  labels:b329
    (json (need (de:json:html (@t q.q))))
  ++  json
    |=  jon=^json
    ^-  labels:b329
    ?>  ?=([%a *] jon)
    (~(import la:b329 *labels:b329) (turn p.jon entry-from-json))
  --
++  grow
  |%
  ++  noun  labels
  ++  json
    ^-  ^json
    :-  %a
    %+  turn  ~(export la:b329 labels)
    |=  e=label-entry:b329
    %-  pairs:enjs
    :~  ['type' s+(scot %tas type.e)]
        ['ref' s+ref.e]
        ['label' s+label.e]
        ['spendable' ?~(spendable.e ~ b+u.spendable.e)]
    ==
  ++  mime  [/application/json (as-octs:mimes:html -:txt)]
  ++  txt   [(en:json:html json)]~
  --
++  entry-from-json
  |=  jon=json
  ^-  label-entry:b329
  ?>  ?=([%o *] jon)
  :*  ;;(label-type:b329 (slav %tas (so:dejs (~(got by p.jon) 'type'))))
      (so:dejs (~(got by p.jon) 'ref'))
      (so:dejs (~(got by p.jon) 'label'))
      ~
      =/  sp=json  (~(got by p.jon) 'spendable')
      ?:(=(~ sp) ~ ?:(=([%b %.y] sp) `%.y ?:(=([%b %.n] sp) `%.n ~)))
  ==
--
