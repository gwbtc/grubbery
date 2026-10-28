# Grubbery

A tree-shaped manager for stateful long-running processes on Urbit.

- **Grub-based Shrubbery** — active, bug-like processes inspired by %spider,
  in a file system inspired by Shrubbery. Emphasis on *doing* over *being*.
- **Grug-brained Shrubbery** — a simple, mechanical feel with few moving
  parts.
- **Groundwire Shrubbery** — asynchronous monadic processes make complex
  blockchain operations easy to express. Sandboxing provides security.

## Core concepts

**Grub** — a file and its running process. Files are the leaves of the tree.
Each has content (a marked noun) and a long-running fiber that operates on
it. When a grub's process completes, the grub is deleted; when it fails, it
restarts. See [The namespace](#namespace.md).

**Nexus** — the behavior definition for a directory. Each directory has a
nexus that defines how its grubs are initialized (`on-load`) and run
(`on-file`). Nexus definitions live in `nex/` and are compiled into the tree
at load time. See [Nexuses](#nexuses.md).

**Tarball** — the filesystem. An `(axal lump)` tree where each node holds
content, metadata, a nexus identifier, and version history. The tarball is
the single source of truth for all state in grubbery. See
[The ball](#ball.md) and [The content-addressed store](#silo.md).

**Fiber** — the process monad. Grub processes are monadic computations that
yield effects (darts) and receive events (intakes). A fiber can poke other
grubs, peek at their state, watch directories for changes, reach the Urbit
kernel through `/sys`, sleep, and more. Fibers survive agent reloads: on
load, every process is rebuilt from its nexus and restarted. See
[Fibers](#fibers.md).

**Weir** — sandbox filter. A weir sits on a directory and controls what its
children can reach: the allowed destinations for make, poke, and peek.
Kernel access is blocked by any weir on the path to root. External ships
enter the tree through a gateway and are subject to weirs like any other
process. See [Sandboxing & weirs](#weirs.md).

**Dart** — an effect yielded by a fiber: make a grub, poke a file, peek at
state, subscribe to a directory, and so on. Darts travel up the tree to the
nearest common ancestor with their destination, then down, passing every
weir on the upward leg.

**Intake** — an event received by a fiber: responses to darts (peek results,
poke acks), external inputs (incoming pokes, subscription news), or
lifecycle events (start, restart after failure).

## Why this shape

A stock Gall app is one agent holding one big state noun, migrated by hand
every time that shape changes. Grubbery takes the opposite bet, and three
commitments follow from it:

- **The namespace is the truth.** Authoritative state lives in grubs; derived
  or rebuildable caches go in sibling grubs. Write cost never justifies
  moving truth out.
- **Reboot anytime.** A fiber can be killed at any step and recovers from
  persisted state. Restarts are the normal case, not a hazard.
- **Compose, don't entangle.** Nexuses meet through the namespace, never
  through shared mutable state.

## Design note: ject identity

Jects hash the file-as-experienced: noun, mark (compile key included), and
health, not bare content. A mark recompile changes what a file means, so it
changes the file's identity; reload detection, validation caching, the snap
protocol, and subscriptions all depend on this. Content-only identity
(dedup, signatures, version control) is a separate layer on top of the
namespace, not a change to jects. See
[The content-addressed store](#silo.md).

## This handbook is live

> These pages are markdown grubs served by the shell nexus, and they quote
> source **straight from the running ship** — no copy-paste, so a snippet
> can't drift from the code it describes.

Here is a whole nexus helper lib, read live from the namespace through the
kernel's own file API and highlighted in place:

```live
/desk/gub/lib/shell.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290
```
