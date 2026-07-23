# Claw Agent

AI agent nexus. Chat with LLMs, build sub-nexuses.

## Files

- `config.json` — Agent config: model, api-proxy, context_window, message_cap, channel.
- `main.sig` — Chat lifecycle (create/delete) + message routing.
- `page.html` — Chat interface.

## Directories

- `chats/` — Per-chat directories. Each contains:
  - `chat.json` — Chat conversation log + event loop. Pokes arrive here.
  - `status.json` — Chat status: idle/api/tool.
  - `outbox.json` — Append-only result log.
