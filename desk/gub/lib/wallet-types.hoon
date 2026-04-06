::  wallet-types: shared types for wallet and account nexuses
::
|%
+$  seg  (pair ? @ud)
+$  seed  $%([%t phrase=@t] [%q secret=@q])
+$  account  [purpose=seg coin-type=seg account=seg]
+$  wallet-data  [name=@t =seed fingerprint=@ux accounts=(map account @ux)]
+$  script-type  ?(%p2pkh %p2sh-p2wpkh %p2wpkh %p2tr)
+$  account-data
  $:  name=@t
      wallet=@ux
      =script-type
      network=?(%main %testnet %regtest)
      purpose=seg
      coin-type=seg
      account-idx=seg
      xprv=@t
      receiving=(list @t)
      change=(list @t)
  ==
--
