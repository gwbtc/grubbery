::  wallet-types: shared types for wallet and account nexuses
::
|%
+$  seg  (pair ? @ud)
+$  seed  $%([%t phrase=@t] [%q secret=@q])
+$  account  [purpose=seg coin-type=seg account=seg]
+$  wallet-data  [name=@t =seed fingerprint=@ux accounts=(map account @ux)]
+$  script-type  ?(%p2pkh %p2sh-p2wpkh %p2wpkh %p2tr)
::  per-address fetched info from mempool.space
::
+$  address-info
  $:  tx-count=@ud
      funded=@ud          :: chain_stats.funded_txo_sum (total sats received)
      spent=@ud           :: chain_stats.spent_txo_sum (total sats spent)
      last-check=@da
  ==
::  address entry: derived address string + optional fetched info
::
+$  address-entry  [addr=@t info=(unit address-info)]
::  scan process state: tracks progress through gap-limit scan
::
+$  scan-state
  $:  phase=?(%recv %chng)
      idx=@ud
      gap=@ud
  ==
::  refresh process state: which address to refresh
::
+$  refresh-state  [chain=?(%recv %chng) idx=@ud]
::
+$  account-data
  $:  name=@t
      wallet=@ux
      =script-type
      network=?(%main %testnet %regtest)
      purpose=seg
      coin-type=seg
      account-idx=seg
      xprv=@t
      receiving=(list address-entry)
      change=(list address-entry)
  ==
--
