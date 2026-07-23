::  mar/urb-wallet.hoon
::
::  Mark for a ship's wallet state: the identity seed, spawn tweak,
::  and current UTXO.  The tweak binds the ship's identity to its
::  precommit satpoint and never changes.  The UTXO is ~ before the
::  first spawn confirms and gets updated after every on-chain action.
::
/<  gw   /lib/groundwire.hoon
/<  unv  /lib/unv.hoon
|_  wal=[seed=$%([%t =@t] [%uw =@uw] [%ux =@ux]) twk=@ utxo=(unit utxo:unv)]
++  grow
  |%
  ++  noun  wal
  ++  json
    ^-  ^json
    %-  pairs:enjs:format
    :~  :-  'seed'
        ?-  -.seed.wal
          %t   s+t.seed.wal
          %uw  s+(scot %uw uw.seed.wal)
          %ux  s+(scot %ux ux.seed.wal)
        ==
        ['tweak' s+(scot %ux twk.wal)]
        :-  'utxo'
        ?~  utxo.wal  ~
        %-  pairs:enjs:format
        :~  ['txid' s+(scot %ux txid.u.utxo.wal)]
            ['vout' (numb:enjs:format vout.u.utxo.wal)]
            ['value' (numb:enjs:format value.u.utxo.wal)]
        ==
    ==
  ++  mime
    =/  jon=^json  json
    [/application/json (as-octs:mimes:html (en:json:html jon))]
  --
++  grab
  |%
  +$  noun  [seed=$%([%t =@t] [%uw =@uw] [%ux =@ux]) twk=@ utxo=(unit utxo:unv)]
  --
--
