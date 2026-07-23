# Counter Nexus

Auto-incrementing counters with live web UI.

A simple demo nexus. Each counter is a file in `/counters/` holding a `@ud` value. Poke a counter to increment it. The web UI at `/ui/` renders all counters and streams updates via SSE.

## Files

- `ver.ud` — Schema version.

## Directories

- `counters/` — Counter storage. Each file is a `@ud`. Poke to increment. Keyed by `@da` timestamp on creation.
- `ui/` — Web interface with SSE streaming.
- `ui/views/` — Server-rendered HTML pages.
- `ui/views/page.html` — Full counter page. Mark: manx. Re-rendered when counters change.
- `ui/requests/` — Per-request fibers for HTTP connections.
