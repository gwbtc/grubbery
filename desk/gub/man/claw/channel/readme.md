# Channel

Chat channel with standard API. Bridges external sources to claw agents.

## Files

- `config.json` — Channel config: source road (relative to `/claw/app`) and chat-id.
- `inbox.json` — Append-only inbound message list. Subscribe here for new messages.
- `send.sig` — Poke with `{"text": "..."}` to send outbound messages via source.
- `relay.sig` — Internal relay: watches source, writes to inbox.
