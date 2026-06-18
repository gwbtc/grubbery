# Bitcoind Nexus

Bitcoin PKI state machine with live web UI. Maintains urb protocol PKI state by scanning Bitcoin blocks. The walker fiber at `/urb-state.urb-state` owns the PKI state and uses `replace:io` -- anything can `keep:io` it for live updates. Per-ship point files live under `/points/`.

## Files

- `config.json` — RPC connection settings (url, auth).
- `height.ud` — Tip poller. Polls getblockcount every 2s.
- `urb-state.urb-state` — Walker + PKI state. Cursor is `num.block-id` inside the state. Gain on -- subscribable.
- `latest.json` — Last processed block summary.
- `rpc.sig` — RPC proxy poke receiver.
- `reg-tester.sig` — Spawn/test poke receiver.
- `page.html` — Dashboard shell.

## Usage from the browser

- `GET  /grubbery/api/file/groundwire.groundwire/page.html`
- `SSE  /grubbery/api/keep/groundwire.groundwire/urb-state.urb-state?mark=json`
- `POKE /grubbery/api/poke/groundwire.groundwire/reg-tester.sig?mark=json`
