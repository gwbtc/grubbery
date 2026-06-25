::  mark for account-store: map of pubkey-hex to xprv
::
/<  wt  /lib/wallet-types.hoon
=,  wt
=,  format
|_  store=account-store
++  grab
  |%
  ++  noun  account-store
  ++  json
    |=  jon=^json
    ^-  account-store
    ?>  ?=([%o *] jon)
    %-  ~(gas by *account-store)
    %+  turn  ~(tap by p.jon)
    |=  [origin=@t xprv-jon=^json]
    ^-  [@t @t]
    ?>  ?=([%s *] xprv-jon)
    [origin p.xprv-jon]
  ++  mime
    |=  [p=mite q=octs]
    ^-  account-store
    (json (need (de:json:html (@t q.q))))
  --
++  grow
  |%
  ++  noun  store
  ++  json
    ^-  ^json
    :-  %o
    %-  ~(gas by *(map @t ^json))
    %+  turn  ~(tap by store)
    |=  [origin=@t xprv=@t]
    ^-  [@t ^json]
    [origin s+xprv]
  ++  mime  [/application/json (as-octs:mimes:html -:txt)]
  ++  txt   [(en:json:html json)]~
  --
--
