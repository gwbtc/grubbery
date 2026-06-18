# Indexer Nexus

Bitcoind block cache. Polls a bitcoind node and caches block data in the ball namespace. Pure cache layer — no script-hash matching or account awareness.

## Files

- `config.json` — RPC connection settings (url, auth, poll-interval).
- `tip.ud` — Current chain height from bitcoind.
- `poller.sig` — Poll loop process.

## Directories

- `blocks/` — Cached block data keyed by height.
