# Claw Agent Container

Manages claw agent nexuses in `/agents/` and channels in `/channels/`. Each agent runs `/claw/agent` code with a read-only weir. Channels exist independently; agents link to them via their config.

Poke `main.sig` with JSON:
- `{"action": "create", "name": "my-agent"}`
- `{"action": "delete", "name": "my-agent"}`
- `{"action": "create-channel", "name": "tg", "type": "telegram"}`
- `{"action": "delete-channel", "name": "tg"}`
- `{"action": "create-api", "name": "openai", "type": "openai"}`
- `{"action": "delete-api", "name": "openai"}`

API proxy nexuses in `/apis/` handle HTTP for sandboxed agents.

## Files

- `main.sig` — Management process. Poke with JSON to create or delete agents.
- `page.html` — Dashboard page. Lists all agents with links to their UIs.

## Directories

- `agents/` — Agent nexuses. Each subdirectory is a claw agent with `/claw/agent` code.
- `apis/` — API proxy nexuses. Each subdirectory is a proxy nexus (e.g. anthropic/).
- `sse/` — SSE fragments for live dashboard updates.
