::  mark for tx-map: map of txid to transaction
::
/<  wt  /lib/wallet-types.hoon
=,  wt
|_  txs=tx-map
++  grab
  |%
  ++  noun  tx-map
  --
++  grow
  |%
  ++  noun  txs
  --
--
