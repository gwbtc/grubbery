# Anthropic API Proxy

Proxies requests to the Anthropic Messages API. Holds API key and URL in `config.json`. Poke `main.sig` with `{"id": "call-id", "body": {...api body...}}`. Subscribe to `calls/[id].json` before poking to get the response. Response arrives as `{"status": "done", "response": {...}}`.

## Files

- `config.json` — API config: api-key, url, input-cost, output-cost (per million tokens).
- `main.sig` — Poke with JSON (id + body) to create a call in `calls/`.
- `usage.json` — Cumulative API usage: tokens, requests, cost. Auto-updated per call.
- `page.html` — Usage dashboard UI.

## Directories

- `calls/` — Per-request lifecycle files. Each call gets its own file and fiber.
