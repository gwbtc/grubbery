# MCP Nexus

Model Context Protocol JSON-RPC tool server. Exposes Hoon-defined tools to AI clients (Claude Code, etc.) via the MCP JSON-RPC protocol at `/grubbery/mcp`. mcp is the HTTP shell; discovery and execution are delegated to a nested tools nexus.

## Files

- `main.sig` — HTTP binding process. Registers `/grubbery/mcp` with the server, handles JSON-RPC dispatch.
- `index.html`, `app.js`, `style.css`, `components.js` — the UI on the kit (tab-group, modal-dialog). It is a viewer for ONE tools nexus, the one its URL names: `/grubbery/mcp` shows this endpoint's own `tools/`, `/grubbery/mcp/apps/nostr/tools` shows the nostr app's. Tools with a detail modal (about, schema, source, run) and the runs in flight. The Run form is an ordinary MCP client (JSON-RPC `tools/call`; for another nexus's tool, `call_tool` with `path`). There is no registry and nothing scans: any nexus can mount a tools nexus, and says where in its readme; `list_tools` / `call_tool` take a `path` to reach it.

## Directories

- `requests/` — Per-request fibers for active HTTP connections.
- `tools/` — The tools child nexus (neck `/tools`, code at `nex/tools.hoon`).
  - `tools/code/` — This instance's code namespace, seeded from the tool bundle. The registry is this directory.
  - `tools/runs/{id}` — One run grub per tool call (mark `%tool-state`), under the child's weir. Culled by the requester on completion.
