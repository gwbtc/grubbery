# Claude Nexus

AI chat via Anthropic API. Flat-chat architecture: one main process (`main.claude-registry`) drives everything. It pokes the inert message store, calls the Anthropic API, dispatches tool/api actions, and manages keep subscriptions.

## Files

- `config.json` — API key, model, max_tokens (JSON).
- `messages.claude-messages` — Ordered message log (claude-messages mark).
- `custom-prompt.txt` — Prepended to system prompt on every API call.
- `main.claude-registry` — Async slot registry. Every request gets a slot.
- `weir.txt` — Live-rendered view of parent directory sandbox rules.

## Directories

- `ui/` — Web interface.
- `ui/chat.html` — Full chat page (re-rendered on each message).
- `ui/sse/` — SSE endpoints for live streaming.
- `ui/sse/last-message.html` — Last message as HTML (SSE stream source).
- `ui/sse/status.json` — Loading indicator state (JSON).

## Processes

- `messages.claude-messages` — Inert store. Accepts `%claude-action` pokes, appends [role content] to the mop.
- `main.claude-registry` — THE process. Multiplexes ALL events: pokes (user messages), peek/ack responses, bond/news/fell (subscription lifecycle). Every outgoing dart gets a slot with wire `/slot/N`. Responses match back by wire.
- `weir.txt` — Watches parent dir via `keep ../`. Renders sandbox rules as text on each change.
- `ui/chat.html` — Watches messages via keep. Re-renders full page (server-side Sail) on each new message.
- `ui/sse/last-message.html` — Watches messages. Emits last message as HTML fragment for SSE consumers.
- `ui/sse/status.json` — Passive. Written by main process to signal loading state to the UI.

## API (via `<api>` tags in chat)

Paths support `./` and `../` relative to the nexus.

- READ: file, kids, tree, sand, weir, keep, drop
- WRITE: make, over, rmf, dir, rmd, poke, diff, setweir, rmweir

All paths are parsed by `cord-to-road`. Trailing `/` means directory, no trailing `/` means file. Relative paths resolve from the nexus.

## Coordination

- Server nexus routes HTTP to `/ui/` for the web interface.
- MCP nexus handles `<tool>` dispatches.
- Keep subscriptions use tarball internal subs (`keep:io` / `drop:io`).
- Messages file is the single source of truth for chat history.
