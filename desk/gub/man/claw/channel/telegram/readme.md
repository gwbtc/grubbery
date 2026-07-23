# Telegram Channel

Telegram channel. Polls getUpdates, writes inbox, sends via bot API.

## Files

- `config.json` — Channel config: bot-token and chat-id.
- `inbox.json` — Append-only inbound message list.
- `send.sig` — Poke with `{"text": "..."}` to send via telegram.
- `poller.sig` — Long-polling loop for incoming messages.
