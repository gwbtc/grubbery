# The tools nexus

A tool is one Hoon file that compiles to a name, a description, a
parameter schema, and a handler fiber. The tools nexus is the engine that
holds a set of them and runs them: a directory any nexus mounts, whose own
`/code` is seeded with the tool sources by the host, whose `main.sig`
accepts calls, and whose `/runs` holds one grub per execution. It has no
page, no name, no ask; it is not an app. What it may reach is the weir its
host puts on it, so where a host mounts it is the sandbox its tools run
in. The MCP nexus is one host; so are calendar, goals, notifications, and
any nexus that wants an agent to drive it.

## The mount

A host imports a source directory and seeds it. `+seed-tools` turns the
imported files into a bole with the `[/ %tools]` neck and a child `/code`
holding them under `/lib`, so the tools compile in the instance's own
namespace against their own dependencies (see
[Code nexuses](#code-nexuses.md)).

```live
/desk/gub/lib/tools.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 90-105
```

The host lays that bole down as a `%over` row, merged over whatever the
mounted instance already holds, so a reseed updates the bundled tools
without deleting ones added at runtime.

```live
/desk/gub/nex/mcp.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 362-374
```

```live
/desk/gub/nex/mcp.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 398-404
```

```live
/desk/gub/lib/tools.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 106-134
```

The instance's own `+on-load` adds the supervisor, the run directory,
and the standard for writing a tool, and keeps `/code` as a `%fall` so the
seed survives its reloads.

```live
/desk/gub/nex/tools.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1-21
```

```live
/desk/gub/nex/tools.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 155-169
```

## A tool

The type is a core with five arms. The handler is a fiber that returns a
result: text, an error, or a mime.

```live
/desk/gub/lib/tools.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 7-24
```

```live
/desk/gub/lib/tools.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 39-52
```

A tool's name is its file location under `/code/lib/tools`: path
segments joined by a double underscore, hyphens rendered as underscores.
The mapping is a bijection, so the name is the address and nothing has
to be registered.

```live
/desk/gub/lib/tools.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 65-68
```

```live
/desk/gub/lib/tools.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 169-186
```

A whole tool: it reads its arguments from the run grub's state, does its
work through the library, and returns.

```live
/desk/gub/lib/tool-bundle/tools/create-folder.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290
```

> [!note] Wart: the library header names a directory that no longer exists
> `lib/tools.hoon` says its helpers are used by tool files in
> `/lib/mcp/tools/` and that names are locations under a `lib/mcp` root.
> Tools live in a bundle at `/lib/tool-bundle/tools` and land at
> `/code/lib/tools` in the instance. The comments should say so.

## Discovery

The instance is the only thing that can read its own `/code`, since a
relative read from its own rail is how it finds it. It lists its tools by
walking `/code/lib/tools`, reading each artifact, and keeping the ones
that compiled to a tool; nothing is cached, and there is no fallback to
any other namespace.

```live
/desk/gub/nex/tools.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 77-110
```

A host asks with a `list` poke and gets the schema array poked straight
back, a request and a response with no grub written.

```live
/desk/gub/nex/tools.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 178-200
```

```live
/desk/gub/nex/mcp.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 227-259
```

## A run

The supervisor takes `call` and `cull` on `main.sig`. A call with an id, a
name, and arguments makes `/runs/<id>` holding a tool state at `%start`;
a call for an id that exists is ignored, so a retried call is idempotent.

```live
/desk/gub/nex/tools.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 201-220
```

The run grub's fiber reads its state, resolves the tool by name from
`/code`, runs the handler, and overwrites itself at `%done` with the
result. A tool that fails to build reports its tang as the result, and a
handler that crashes is caught on restart and reported the same way, so a
caller always sees a `%done`.

```live
/desk/gub/nex/tools.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 221-256
```

```live
/desk/gub/nex/tools.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 61-78
```

```live
/desk/gub/nex/tools.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 122-151
```

The caller's side is the calls pattern: keep the run grub, poke the call,
take news until the state is `%done`, read the result, cull the run. The
MCP nexus does it inside the request fiber for `tools/call`.

```live
/desk/gub/nex/mcp.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 515-550
```

## The sandbox

A tool runs as a fiber under `/runs`, so its darts climb out through the
instance's weir, which is whatever the host set at the mount. Nothing in
the instance declares a reach of its own. The MCP host sets none and
declares that as its ask, because its tools are arbitrary and it runs
them under its own reach.

```live
/desk/gub/nex/mcp.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 19-42
```

> [!note] Wart: every tool in an instance runs under one weir
> The instance's weir bounds every tool in it alike, so a host that runs
> one tool needing `/sys/scry` must open that road to all of them, and a
> host with arbitrary tools must be unrestricted. The comment over the
> MCP ask says the fix: a weir per run, set on the run grub's directory
> from the tool's own declaration, so the host can be narrow.
