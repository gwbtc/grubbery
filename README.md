# Grubbery

A tree-shaped manager for stateful long-running processes on Urbit.

A **grub** is the unified concept of a file and its running process — the living thing at a path. Directories hold grubs and other directories, have a **nexus** that defines how grubs within behave, and may have a **weir** (sandbox rules).

## Setup

### Installation

Copy desk files to your ship's pier and commit:

```
|mount %grubbery
```

Then sync:

```
cp -R desk/* /path/to/your/ship/grubbery/
```

Or use the included `sync.sh` with `config.json`:

```
cp config.example.json config.json
# Edit config.json with your ship's pier path
./sync.sh
```

Then in dojo:

```
|commit %grubbery
```

### MCP Server

Grubbery includes an MCP (Model Context Protocol) server for AI tool integration. Available tools include scry, commit, desk version, file listing, and more.

Connect your MCP client to the `/grubbery/mcp` HTTP endpoint.

## Architecture

### Core Concepts

- **Grub** = file + process. Every grub has exactly one running process alongside its file content.
- **Nexus** = directory behavior definition. Defines how grubs in a directory are initialized and what they do.
- **Tarball** = the filesystem. An `(axal lump)` tree where each lump holds metadata, a nexus identifier, and content.
- **Fiber** = the process monad. Grub processes are monadic fibers that yield effects (darts) and receive events (intakes).
- **Weir** = sandbox filter. Controls what destinations a process can reach (make, poke, peek).

### Process Lifecycle

| Result | Effect |
|--------|--------|
| `%done` | Grub is deleted (process completed) |
| `%fail` | Process restarts with `[%rise tang]`, queued pokes are nacked |
| `%wait` | Process continues, waiting for next input |
| `%skip` | Skip current intake, process it later |

On agent load, all processes are rebuilt from their nexus and restarted.

### Tree Layout

```
/                     root nexus
/server/main          HTTP request routing
/counter/main         example: multi-counter with web UI
/explorer/main        web UI for browsing the tree
/peers/
  /main               poke router + usergroup weir manager
  /usergroups/
    /who/              group → members
    /how/              group → weir templates
  /ships/
    /~ship/main        per-ship gateway (inbound pokes)
/mcp/
  /main               MCP JSON-RPC endpoint
/tools/
  /main               MCP tool execution
```

### Sandboxing

Weirs control what processes can reach. A weir specifies allowed destinations for `%make`, `%poke`, and `%peek` operations. Syscalls (raw Gall cards) are blocked by any weir on the path to root.

External ships enter at `/peers/~ship/*` and are subject to weir sandboxing like any tree citizen. Weirs are managed reactively via usergroups.

### Key Files

| File | Purpose |
|------|---------|
| `app/grubbery.hoon` | Gall agent shell |
| `lib/nexus.hoon` | Core engine: process lifecycle, routing, sandboxing |
| `lib/tarball.hoon` | Filesystem data structure |
| `lib/fiberio.hoon` | Monadic I/O primitives for fibers |
| `lib/server.hoon` | HTTP server helpers |
| `lib/mcp.hoon` | MCP protocol handler |
| `nex/*.hoon` | Nexus definitions (server, counter, explorer, peers, mcp, tools, root) |

## License

See LICENSE.txt.
