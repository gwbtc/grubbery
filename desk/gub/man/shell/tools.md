# Tools

The MCP (Model Context Protocol) JSON-RPC endpoint, a service of the shell. Exposes Hoon-defined tools to AI clients (Claude Code, etc.) at `/grubbery/tools`. The shell is the HTTP side (`lib/shell/mcp`); discovery and execution are the tools nexus's, mounted at the shell's `/tools`.

## In the shell

- `ui/http.sig` — binds `/grubbery/tools`; a request lands in `ui/requests/{id}` and `serve-request:mcp` answers it: GET the page and its data routes, POST JSON-RPC (`initialize`, `tools/list`, `tools/call`).
- `ui/tools/` — `index.html`, `app.js`, `style.css`, `components.js` (the kit: tab-group, modal-dialog). The page is a viewer for ONE tools nexus, the one its URL names: `/grubbery/tools` shows the shell's own `tools/`, `/grubbery/tools/apps/nostr/tools` shows the nostr app's. Tools with a detail modal (about, schema, source, run) and the runs in flight. The Run form is an ordinary MCP client (JSON-RPC `tools/call`; for another nexus's tool, `call_tool` with `path`). There is no registry and nothing scans: any nexus can mount a tools nexus, and says where in its readme; `list_tools` / `call_tool` take a `path` to reach it.
- `tools/` — the tools nexus (neck `/tools`, code at `nex/tools.hoon`). `@tools` names it.
  - `tools/code/` — its code namespace, seeded from the tool bundle (`lib/tool-bundle`) with runtime-added tools kept. The registry is this directory.
  - `tools/runs/{id}` — one run grub per tool call (mark `%tool-state`), under the child's weir. Culled by the requester on completion.
- `tiles/tools/tile.json` — the launcher tile.
