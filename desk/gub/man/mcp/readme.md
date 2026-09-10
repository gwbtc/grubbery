# MCP Nexus

Model Context Protocol JSON-RPC tool server. Exposes Hoon-defined tools to AI clients (Claude Code, etc.) via the MCP JSON-RPC protocol at `/grubbery/mcp`. mcp is the HTTP shell; discovery and execution are delegated to a nested tools nexus.

## Files

- `main.sig` — HTTP binding process. Registers `/grubbery/mcp` with the server, handles JSON-RPC dispatch.
- `index.html`, `app.js`, `style.css` — the UI: tool registry, runs in flight, reference reader. Its Run tab is an ordinary MCP client (JSON-RPC `tools/call`).

## Directories

- `requests/` — Per-request fibers for active HTTP connections.
- `tools/` — The tools child nexus (neck `/tools`, code at `nex/tools.hoon`).
  - `tools/code/` — This instance's code namespace, seeded from the tool bundle. The registry is this directory.
  - `tools/runs/{id}` — One run grub per tool call (mark `%tool-state`), under the child's weir. Culled by the requester on completion.
