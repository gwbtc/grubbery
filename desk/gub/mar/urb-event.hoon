::  mar/urb-event.hoon
::
::  Mark for a single urb protocol event observed on-chain.
::  Stored in files — subscribers see each event
::  as it flows through. Includes tx outputs for UTXO derivation.
::  ~ when no event has been recorded yet.
::
/<  urb      /lib/sur/urb.hoon
/<  bitcoin  /lib/sur/bitcoin.hoon
|_  evt=(unit [height=@ud txid=@ux =ship =sotx:urb os=(list output:tx:bitcoin)])
++  grow
  |%
  ++  noun  evt
  ++  json
    ^-  ^json
    ?~  evt  ~
    %-  pairs:enjs:format
    :~  ['height' (numb:enjs:format height.u.evt)]
        ['txid' s+(en:base16:mimes:html 32^txid.u.evt)]
        ['ship' s+(scot %p ship.u.evt)]
        ['action' s+-.+.sotx.u.evt]
        :-  'detail'
        =/  sk  +.sotx.u.evt
        ?+  -.sk  ~
          %spawn   (pairs:enjs:format ~[['pass' s+(scot %ux pass.sk)]])
          %keys    (pairs:enjs:format ~[['breach' b+breach.sk]])
          %escape  (pairs:enjs:format ~[['parent' s+(scot %p parent.sk)]])
          %cancel-escape  (pairs:enjs:format ~[['parent' s+(scot %p parent.sk)]])
          %adopt   (pairs:enjs:format ~[['ship' s+(scot %p ship.sk)]])
          %reject  (pairs:enjs:format ~[['ship' s+(scot %p ship.sk)]])
          %detach  (pairs:enjs:format ~[['ship' s+(scot %p ship.sk)]])
          %fief    (pairs:enjs:format ~[['fief' b+?=(^ fief.sk)]])
          %set-mang  (pairs:enjs:format ~[['mang' b+?=(^ mang.sk)]])
        ==
        :-  'outputs'
        :-  %a
        %+  turn  os.u.evt
        |=  out=output:tx:bitcoin
        %-  pairs:enjs:format
        :~  ['scriptpubkey' s+(en:base16:mimes:html script-pubkey.out)]
            ['value' (numb:enjs:format value.out)]
        ==
    ==
  ++  mime
    =/  jon=^json  json
    [/application/json (as-octs:mimes:html (en:json:html jon))]
  --
++  grab
  |%
  +$  noun  (unit [height=@ud txid=@ux =ship =sotx:urb os=(list output:tx:bitcoin)])
  --
--
