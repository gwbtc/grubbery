# Wallet Nexus

Bitcoin SPV wallet management. Manages Bitcoin wallets, watch-only accounts, and signing accounts. View at `/grubbery/api/file/wallet.wallet_app/page.html`.

## Files

- `main.sig` — Poke handler for wallet actions.
- `page.html` — Server-rendered wallet page (manx).
- `ver.ud` — Schema version.

## Directories

- `wallets/` — Per-wallet nexuses. Each keyed by pubkey fingerprint.
- `accounts/` — Per-account nexuses. Each keyed by account pubkey.
- `ui/sse/` — SSE streams. Sanitized wallet data for live UI updates.
