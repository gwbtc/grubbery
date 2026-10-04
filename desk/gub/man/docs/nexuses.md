# Nexuses

A nexus is what gives a directory its behavior. It is a core with two arms:
`+on-load`, which says what the directory contains, and `+on-file`, which
says what runs beside each file in it. The kernel calls nothing else. A
directory becomes a nexus by carrying a neck, the name of a nexus source
in a code namespace; the kernel builds the core from that source, calls
`+on-load` to lay the directory out, and calls `+on-file` for each grub to
get its process. A reload is the same two steps run again over what is
there now. So an application is a directory with a neck, its state is the
directory's contents, and its behavior is a pure function from the old
contents to the new plus a process per file.

## The core

The kernel's contract with a nexus is the `$nexus` door: `+on-load` takes
the directory's current tree as a `$ball` and returns the tree it should
become as a `$bole`; `+on-file` takes a grub's rail, relative to the nexus,
and its blot, and returns the spool the kernel starts a process from (see
[Fibers](#fibers.md)).

```live
/grubbery/lib/nexus.hoon 1396-1420
```

The mirror nexus is the shape in its smallest form: a config grub, a data
directory, two assets, and one fiber that follows the config.

```live
/grubbery/gub/nex/mirror.hoon 13-22
```

```live
/grubbery/gub/nex/mirror.hoon 23-64
```

## A neck

A neck is a `$rail` naming a nexus: `[/ %mirror]`, `[/git %forge]`. It is
the same shape as a blot, a mark's name, and resolves the same way: the
source is `/nex/<path>/<name>.hoon` in a code namespace, as a mark's is
`/mar/<path>/<name>.hoon`.

```live
/grubbery/lib/tarball.hoon 5-6
```

```live
/grubbery/lib/tarball.hoon 140-187
```

Which code namespace is decided by position. A directory's nexus is
looked up in its sibling `/code`, then in each ancestor's, ending at the
root `/code`; `X/code` governs everything under `X` and never `X` itself.
`+build-nexus` resolves the neck through that order and extracts the core
from the built artifact.

```live
/grubbery/app/grubbery.hoon 3290-3320
```

A directory's neck is set by whoever makes the directory, as a field of
the bole: the root nexus gives each built-in its neck in the row that
creates it. The directory's name is a convention that mirrors the neck
and carries no meaning to the kernel.

```live
/grubbery/lib/root.hoon 77-93
```

The neck is stored in the directory's tree ject and read back from there,
so finding a rail's governing nexus is a walk up the born, not a
materialization of the tree.

```live
/grubbery/app/grubbery.hoon 2297-2314
```

> [!note] Wart: `+ext-to-neck` has no callers
> `tarball.hoon` carries an arm that parses a directory name's
> underscore-separated extension into a neck, as if `forge.git_forge`
> named `[/git %forge]` by its suffix. Nothing calls it; the neck always
> comes from the bole. The arm should go, or the convention it implies
> should be made real.

## The loader

### The contract

`+on-load` is a function from the old tree to the new one, and the new
one is complete: anything the returned bole does not contain is dropped.
There are no deletions to write, because not listing something is the
deletion. The loader library turns that into a declaration: a list of
rows, each saying what one path should hold, folded over the old tree.

```live
/grubbery/lib/loader.hoon 1-16
```

### Rows

Four row kinds, each in a file form and a directory form. `%stay` keeps
what is there and adds nothing if it is absent. `%fall` keeps what is
there and seeds a default if it is absent: the row for a grub the runtime
owns after birth, config, state, a fiber's trigger. `%over` writes the
given value every time: the row for an asset, or anything the code is the
truth of. `%load` takes what is there, runs a function over it, and places
the result, possibly elsewhere: the row for a migration or a repair.

```live
/grubbery/lib/loader.hoon 17-44
```

`+spin` is the fold. Each row reads from the old ball and writes into the
bole under construction; the old tree is never modified, only consulted.

```live
/grubbery/lib/loader.hoon 47-116
```

Getting `%fall` and `%over` the wrong way round is the mistake to know
about. Content seeded with `%fall` freezes at first boot and never
follows the code again; state written with `%over` is reset on every
load. The choice is the same one as record versus cache in
[The namespace](#namespace.md): who owns the grub after it exists.

### The root nexus

The root nexus is the one nexus the kernel does not build from a neck: it
is compiled into the agent and reloaded at `/` on every boot. Its
`+on-load` carries the whole existing tree forward with one `%load` row
over `/`, resets `/apps` to no weir, lays out the `/sys` services, and
creates each built-in application as a `%fall` directory with its neck.

```live
/grubbery/lib/root.hoon 36-49
```

## The kernel's side

### Loading one nexus

`+reload-nexus-at` is the load of one directory. It clears any bangs
under it, runs `+on-load` under `+mule`, and bangs the whole subtree if it
crashes. Then it restores two things the nexus is not allowed to set: the
directory's own neck, and the directory's own weir. A nexus lays out its
children's fences; its own is imposed from above (see
[Sandboxing & weirs](#weirs.md)). The bole lands as one directory update,
weir changes are recorded, subscriptions under any changed weir are
re-checked, and the walk continues into the children.

```live
/grubbery/app/grubbery.hoon 2855-2894
```

### Code first

The walk into children makes each level's `/code` fresh before touching
anything beside it, so every nexus built on the way down resolves into a
namespace already compiled against the current agent. A `/code` directory
is a namespace, not a nexus; the walk registers or rebuilds it and does
not load it.

```live
/grubbery/app/grubbery.hoon 2895-2952
```

### Then processes

Loading writes the tree and spawns nothing. Once the whole subtree is
settled, `+spawn-all-files` walks it, builds each governing nexus once at
the directory carrying its neck, and starts a process for every grub from
that nexus's `+on-file`. See [Fibers](#fibers.md) for what a process is.

### Boot

At boot the root nexus is reloaded at `/`, which loads everything under it
in one walk, and then every file in the tree is spawned.

```live
/grubbery/app/grubbery.hoon 621-640
```

### When code changes

A write into a code namespace rebuilds it, and every nexus whose artifact
changed is reloaded at each directory that carries its neck, then
respawned. This is how an edit to `nex/mirror.hoon` reaches every mirror
instance without a reboot.

```live
/grubbery/app/grubbery.hoon 5562-5621
```

A fiber can ask for the same from inside: `+reload` sends a `%load` dart
at a directory, which the kernel answers by reloading the nexus there. The
shell uses it to rebirth an app after granting its permissions.

```live
/grubbery/lib/fiberio.hoon 811-829
```

```live
/grubbery/app/grubbery.hoon 3484-3491
```

> [!note] Wart: the code-change reload prints four progress lines
> `+reload-changed-nexuses` prints start and done for the reload and for
> the spawn, per nexus per directory, on every code write. They are
> traces, not diagnostics, and should sit behind the debug flag the
> rest of the agent's traces use.
