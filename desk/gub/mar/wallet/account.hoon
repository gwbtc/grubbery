::  mark for account-data: BIP44 bitcoin account
::
/<  wt  /lib/wallet-types.hoon
=,  wt
=,  format
=>
|%
::  parse a JSON address entry: either a string (legacy) or an object
::
++  parse-entries
  |=  entries=(list json)
  ^-  (list address-entry)
  %+  turn  entries
  |=  j=json
  ^-  address-entry
  ?:  ?=([%s *] j)  [p.j ~]
  ?>  ?=([%o *] j)
  =/  addr=@t  (~(dog jo:json-utils j) /addr so:dejs:format)
  =/  has-info=?  (~(has by p.j) 'tx-count')
  ?:  has-info
    :+  addr  ~
    :^    (~(dog jo:json-utils j) /tx-count ni:dejs:format)
        (~(dog jo:json-utils j) /funded ni:dejs:format)
      (~(dog jo:json-utils j) /spent ni:dejs:format)
    (slav %da (~(dog jo:json-utils j) /last-check so:dejs:format))
  [addr ~]
::
++  entry-to-json
  |=  e=address-entry
  ^-  json
  ?~  info.e  s+addr.e
  %-  pairs:enjs
  :~  ['addr' s+addr.e]
      ['tx-count' (numb:enjs tx-count.u.info.e)]
      ['funded' (numb:enjs funded.u.info.e)]
      ['spent' (numb:enjs spent.u.info.e)]
      ['last-check' s+(scot %da last-check.u.info.e)]
  ==
--
|_  acct=account-data
++  grab
  |%
  ++  noun  account-data
  ++  json
    |=  jon=^json
    ^-  account-data
    ?>  ?=([%o *] jon)
    =/  recv-json=(unit ^json)  (~(get by p.jon) 'receiving')
    =/  chng-json=(unit ^json)  (~(get by p.jon) 'change')
    :*  (~(dog jo:json-utils jon) /name so:dejs:format)
        (slav %ux (~(dog jo:json-utils jon) /wallet so:dejs:format))
        ;;(script-type (slav %tas (~(dog jo:json-utils jon) /script-type so:dejs:format)))
        ;;(?(%main %testnet %regtest) (slav %tas (~(dog jo:json-utils jon) /network so:dejs:format)))
        [%.y (rash (~(dog jo:json-utils jon) /purpose so:dejs:format) dem)]
        [%.y (rash (~(dog jo:json-utils jon) /coin-type so:dejs:format) dem)]
        [%.y (rash (~(dog jo:json-utils jon) /account-idx so:dejs:format) dem)]
        (~(dog jo:json-utils jon) /xprv so:dejs:format)
        ?~  recv-json  ~
        ?.  ?=([%a *] u.recv-json)  ~
        (parse-entries p.u.recv-json)
        ?~  chng-json  ~
        ?.  ?=([%a *] u.chng-json)  ~
        (parse-entries p.u.chng-json)
    ==
  ++  mime
    |=  [p=mite q=octs]
    ^-  account-data
    (json (need (de:json:html (@t q.q))))
  --
++  grow
  |%
  ++  noun  acct
  ++  json
    ^-  ^json
    %-  pairs:enjs
    :~  ['name' s+name.acct]
        ['wallet' s+(scot %ux wallet.acct)]
        ['script-type' s+(scot %tas script-type.acct)]
        ['network' s+(scot %tas network.acct)]
        ['purpose' (numb:enjs q.purpose.acct)]
        ['coin-type' (numb:enjs q.coin-type.acct)]
        ['account-idx' (numb:enjs q.account-idx.acct)]
        ['xprv' s+xprv.acct]
        ['receiving' a+(turn receiving.acct entry-to-json)]
        ['change' a+(turn change.acct entry-to-json)]
    ==
  ++  mime  [/application/json (as-octs:mimes:html -:txt)]
  ++  txt   [(en:json:html json)]~
  --
--
