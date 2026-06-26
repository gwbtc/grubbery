# Wallet Nexus

Bitcoin wallet management. Create wallets from seed phrases, import watch-only accounts (xpub) and signing accounts (xprv), derive addresses, scan balances, and send transactions.

View at `/grubbery/ball/wallet/`.

## State

All wallet state lives in files at the nexus root:

- `labels.wallet_labels` -- BIP-329 label store. Wallets, accounts, addresses, transactions, and UTXOs are all represented as labeled entries. Account metadata (name, network, script type) is stored as label prefixes like `gwbtc:account:`, `gwbtc:network:`, `gwbtc:script-type:`.
- `secrets.wallet_secrets` -- Sensitive key material. Contains `seeds=(map @t seed)` keyed by master xpub, and `xprvs=(map @t @t)` keyed by account xpub for standalone signing accounts.
- `ptsts.wallet_ptsts` -- Tapscript tree store. Contains `(map @t ptst:taproot)` keyed by tapscript address. Each ptst is a recursive tree of leaf, opaque, and branch nodes. Tapscript addresses are linked to parent key-path addresses via `gwbtc:tapscript-of:{parent-addr}` labels.

## Account Types

**Wallet-derived** -- Created from a seed phrase (BIP39 or Urbit @q). The wallet has a master xpub stored in labels and a seed in secrets. Accounts are discovered via BIP44/49/84/86 derivation paths. Each account has a BIP-329 origin linking it back to the master fingerprint and path.

**Watch-only** -- Imported via xpub/tpub. No private key material. Can derive addresses and scan balances but cannot sign transactions. Addresses are tracked via `gwbtc:derived-from:{ref}:{chain}:{idx}` labels instead of BIP-329 origins.

**Signing** -- Imported via xprv/tprv. The xprv is stored in `xprvs.secrets`, and the derived xpub is used as the account ref. Full functionality including sending. Uses the same `derived-from` label scheme as watch-only.

## Routes

- `/` -- Wallet list page with tabs: Full Wallets, Watch-Only, Signing
- `/w/{wallet-xpub}/` -- Wallet detail page (accounts list, discover)
- `/a/{account-ref}/` -- Account detail page (addresses, send/receive, scan)
- `/a/{account-ref}/send` -- Send transaction page
- `/a/{account-ref}/stream` -- SSE stream for live account updates
- `/a/{account-ref}/addr/{chain}/{idx}` -- Address detail page
- `/a/{account-ref}/tx/{txid}` -- Transaction detail page

## Actions (POST)

Wallet-level: `generate-wallet`, `restore-wallet`, `remove-wallet`

Account-level: `add-watch-only`, `add-signing`, `remove-account`, `discover-accounts`

Address/TX-level: `derive-address`, `derive-next`, `delete-address`, `full-scan`, `pause-scan`, `resume-scan`, `cancel-scan`, `refresh`, `send`

Tapscript-level: `add-tapscript`, `delete-tapscript`

## Libraries

- `lib/wallet-types.hoon` -- Type definitions (secrets, seed, wallet-data, script-type, network)
- `lib/wallet/account-io.hoon` -- Pure helpers for address derivation, label management, account lookups
- `lib/wallet-account-ui.hoon` -- Sail rendering for account detail, send page, address rows
- `lib/bip32.hoon`, `lib/bip39.hoon`, `lib/bech32.hoon` -- Bitcoin key derivation and encoding
- `lib/bip329.hoon` -- BIP-329 label store with prefix scanning
- `lib/taproot.hoon` -- Tapscript tree types, hashing, merkle proofs, address generation, JSON serialization
- `lib/tx/draft.hoon`, `lib/tx/fees.hoon` -- Transaction building and fee estimation
