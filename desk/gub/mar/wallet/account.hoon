::  mark for account-data: BIP44 bitcoin account
::
/<  wt  /lib/wallet-types.hoon
=,  wt
=,  format
|_  acct=account-data
++  grab
  |%
  ++  noun  account-data
  ++  json
    |=  jon=^json
    ^-  account-data
    ?>  ?=([%o *] jon)
    :*  (~(dog jo:json-utils jon) /name so:dejs:format)
        (slav %ux (~(dog jo:json-utils jon) /wallet so:dejs:format))
        ;;(script-type (slav %tas (~(dog jo:json-utils jon) /script-type so:dejs:format)))
        ;;(?(%main %testnet3 %testnet4 %signet %regtest) (slav %tas (~(dog jo:json-utils jon) /network so:dejs:format)))
        [%.y (rash (~(dog jo:json-utils jon) /purpose so:dejs:format) dem)]
        [%.y (rash (~(dog jo:json-utils jon) /coin-type so:dejs:format) dem)]
        [%.y (rash (~(dog jo:json-utils jon) /account-idx so:dejs:format) dem)]
        (~(dog jo:json-utils jon) /xprv so:dejs:format)
        (~(dog jo:json-utils jon) /recv-count ni:dejs:format)
        (~(dog jo:json-utils jon) /chng-count ni:dejs:format)
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
        ['recv-count' (numb:enjs recv-count.acct)]
        ['chng-count' (numb:enjs chng-count.acct)]
    ==
  ++  mime  [/application/json (as-octs:mimes:html -:txt)]
  ++  txt   [(en:json:html json)]~
  --
--
