# MCP Nexus

Model Context Protocol JSON-RPC tool server. Exposes Hoon-defined tools to AI clients (Claude Code, etc.) via the MCP JSON-RPC protocol. Tools are compiled by the standard build pipeline (`gub/lib/mcp/`) and looked up from bins at runtime.

## Files

- `main.sig` — HTTP binding process. Registers `/grubbery/mcp` with the server, handles JSON-RPC dispatch.
- `ver.ud` — Schema version.

## Directories

- `tools/` — Running tool instances. Each active tool call gets a fiber here (tool-state mark). Cleaned up on completion.
- `requests/` — Per-request fibers for active HTTP connections.
