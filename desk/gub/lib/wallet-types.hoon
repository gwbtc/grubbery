::  wallet-types: shared types for wallet, account, and address nexuses
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
::  per-address data: stored in each address nexus
::
+$  address-data
  $:  addr=@t
      chain=?(%recv %chng)
      idx=@ud
      network=?(%main %testnet %regtest)
      info=(unit address-info)
      utxos=(list utxo)
      txs=(list transaction)
  ==
::  scan process state: tracks progress through gap-limit scan
::
+$  scan-state
  $:  phase=?(%recv %chng)
      idx=@ud
      gap=@ud
  ==
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
      recv-count=@ud
      chng-count=@ud
  ==
--
