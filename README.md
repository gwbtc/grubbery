# Grubbery

A tree-shaped manager for stateful long-running processes on Urbit.

## Core Concepts

**Grub** — a file and its running process. Files are the leaves of the tree. Each file has content (a cage) and a long-running fiber that operates on it. When a grub's process completes, the grub is deleted. When it fails, it restarts.

**Nexus** — the behavior definition for a directory. Each directory in the tree has a nexus that defines how its grubs are initialized and updated. Nexus definitions live in `nex/` and are compiled into the tree at load time.

**Tarball** — the filesystem. An `(axal lump)` tree where each node holds content, metadata, a nexus identifier, and version history. The tarball is the single source of truth for all state in grubbery.

**Fiber** — the process monad. Grub processes are monadic computations that yield effects (darts) and receive events (intakes). A fiber can poke other grubs, peek at their state, watch directories for changes, send gall cards, sleep, and more. Fibers survive agent reloads — on load, every process is rebuilt from its nexus and restarted.

**Weir** — sandbox filter. A weir sits on a directory and controls what its children can reach. It specifies allowed destinations for make, poke, and peek operations. Syscalls (raw gall cards) are blocked by any weir on the path to root. External ships enter the tree through a gateway and are subject to weir sandboxing like any other process.

**Dart** — an effect yielded by a fiber. Darts are the fiber's way of interacting with the world: making new grubs, poking files, peeking at state, subscribing to directories, sending gall cards, and so on.

**Intake** — an event received by a fiber. Intakes are responses to darts (peek results, poke acks), external inputs (incoming pokes, subscription updates), or lifecycle events (process start, restart after failure).