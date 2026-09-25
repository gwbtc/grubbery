# Nexuses

A nexus is the grubbery unit of an application — a core with two arms:

- **`on-load`** declares what persistently lives in the nexus's subtree of
  the namespace: the grubs it owns and their initial state.
- **`on-file`** answers "given this file — a request, a timer, a
  subscription update — do the work." HTTP handlers and fibers live here.

## on-load: declaring your state

`on-load` returns a *bole* built by `spin:loader` over a list of loader
operations. The two you'll reach for constantly:

- **`%fall`** seeds a grub *only if absent* — the runtime owns it after, and
  reloads never clobber it. For state edited at runtime.
- **`%over`** *overwrites* on every load — the code is the source of truth.
  For assets and content authored in-source.

```hoon
%+  spin:loader  ball
:~  (manifest:loader 0)
    [%fall %& [/ %'main.sig'] [[/ %sig] ~]]      ::  a fiber entrypoint
    [%fall %| /cache empty-dir:loader]           ::  a rebuildable cache dir
    [%over %& [/ %'app.js'] [[/ %mime] app-js]]  ::  a served asset
==
```

Getting these backwards is the classic footgun: seed content with `%fall`
and it freezes at first boot; author it with `%over` and every commit
redeploys it. It's the same record-vs-cache distinction as
[Grubs](#grubs.md).

## on-file: doing the work

Requests route in as the file that represents them. A nexus binds an HTTP
path and hands off to a fiber:

```hoon
[~ %'main.sig']
  ;<  ~  bind:m  (rise-wait:io prod "failed")
  ;<  ~  bind:m  (bind-http:io [~ /apps/grubbery])
  (http-dispatch:io %shell)
```

The kernel routes matching requests here and spawns a fiber per request.

## Reading anything, live

A nexus can read any file in the running namespace. Here's how a tool greps
the whole ball — the same read primitive the live-code embeds use:

```live
/gub/lib/tool-bundle/tools/grep.hoon 1-14
```

_TODO: registration via a `%fall` row in `root.hoon`; the full loader
vocabulary; declaring weirs._