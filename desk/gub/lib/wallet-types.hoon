::  wallet-types: shared types for wallet, account, and address nexuses
::
|%
+$  seg  (pair ? @ud)
+$  seed  $%([%t phrase=@t] [%q secret=@q])
+$  account  [purpose=seg coin-type=seg account=seg]
+$  wallet-data  [=seed xpub=@t]
+$  secrets
  $:  seeds=(map @t seed)       :: wallet xpub → seed
      xprvs=(map @t @t)         :: account xpub → xprv
  ==
+$  script-type  ?(%p2pkh %p2sh-p2wpkh %p2wpkh %p2tr)
::  per-address fetched info from mempool.space
::
+$  address-info
  $:  tx-count=@ud
      funded=@ud          :: chain_stats.funded_txo_sum (confirmed sats received)
      spent=@ud           :: chain_stats.spent_txo_sum (confirmed sats spent)
      mem-tx-count=@ud    :: mempool_stats.tx_count
      mem-funded=@ud      :: mempool_stats.funded_txo_sum
      mem-spent=@ud       :: mempool_stats.spent_txo_sum
      last-check=(unit @da)
  ==
::  transaction status: confirmed or unconfirmed
::
+$  tx-status
  $%  [%unconfirmed ~]
      [%confirmed block-hash=@t block-height=@ud]
  ==
::  transaction input
::
+$  tx-input
  $:  spent-txid=@t
      spent-vout=@ud
      prevout=(unit tx-output)
  ==
::  transaction output
::
+$  tx-output  [value=@ud address=@t]
::  transaction: full mempool.space transaction data
::
+$  transaction
  $:  txid=@t
      inputs=(list tx-input)
      outputs=(list tx-output)
      =tx-status
      fee=(unit @ud)
      size=(unit @ud)
  ==
::  unspent transaction output
::
+$  utxo
  $:  txid=@t
      vout=@ud
      value=@ud
      =tx-status
  ==
::  per-address data enriched from labels
::
+$  address-data
  $:  addr=@t
      info=(unit address-info)
      utxos=(list utxo)
  ==
+$  tx-map  (map @t transaction)
::  scan process state: tracks progress through gap-limit scan
::
+$  scan-state
  $:  phase=?(%recv %chng)
      idx=@ud
      gap=@ud
  ==
::  process registry: main.sig's bookkeeping of active procs
::
+$  proc-registry
  $:  wallets=(map @t wallet-procs)    :: keyed by wallet xpub
      accounts=(map @t account-procs)  :: keyed by acct-ref
  ==
+$  wallet-procs
  $:  discover=(unit @ta)              :: uuid of active discover proc
  ==
+$  account-procs
  $:  scan=(unit @ta)                  :: uuid of active scan proc
      refresh=(map @ta @ta)            :: "recv-0" -> uuid
  ==
+$  network  ?(%main %testnet3 %testnet4 %signet %regtest)
::  +to-bip-network: map expanded network to bip32/bech32 protocol network
::
++  to-bip-network
  |=  network=?(%main %testnet3 %testnet4 %signet %regtest)
  ^-  ?(%main %testnet %regtest)
  ?-  network
    %main      %main
    %testnet3  %testnet
    %testnet4  %testnet
    %signet    %testnet
    %regtest   %regtest
  ==
--
