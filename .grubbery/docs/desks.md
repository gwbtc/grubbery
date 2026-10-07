# Desks

A desk is a nexus that follows a code directory somewhere in the tree, on
this ship or another, and runs what it finds there. It mirrors the source
into its own `/desk/code`, makes the nexuses that code's bill declares
under `/desk/data`, jailed, and pulls again only when the source's version
file changes. Every change to its world is preceded by a snapshot, so any
earlier code and data can be brought back. Publishing is the same nexus
from the other side: open `/desk/code` to a usergroup and bump the
version. So software moves between ships as a directory that one ship
watches and another ship bumps, and nothing else.

## Host and guest

A desk's tree has two halves. The host half sits at the nexus root and is
governed by the root code namespace: the source config, the version file,
the HTTP fiber, and the snapshot and checkout state. The guest half is
`/desk`: `/desk/code` is a code namespace of its own, holding what was
pulled, and it governs `/desk/data`, the working instances, and nothing
else. Guests distribute every mark they use; content addressing dedups
the shared ones.

```live
/desk/gub/nex/desk.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1-44
```

```live
/desk/gub/nex/desk.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 56-124
```

## Following a source

### The source and its version

`source.json` names one thing: the road to a code directory. A path
beginning with a ship name is routed through `/sys/ames`, so a remote
source and a local one are the same to everything downstream. The
version file is not configured; it is `version.json` inside that code
directory, the authored version of the content.

```live
/desk/gub/nex/desk.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 377-382
```

```live
/desk/gub/nex/desk.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 471-480
```

The version is an opaque tag. The desk pulls when the source's differs
from its own copy, and never reads the source at a historical revision: a
source need not keep its history, and a git-backed one rewrites it on
every checkout. Reproducibility is the desk's own concern, below.

```live
/desk/gub/nex/desk.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 500-508
```

### The pull

`+sync-release` reads the source's version file, mirrors the source's
whole code tree into `/desk/code` as one bole, and copies the version file
under its own name at the desk root, so a follower of this desk watches
the republished version. The mirror is one directory overwrite, not a
file at a time, since each write into a code directory is a build.
`.hoon` files arrive from a git checkout as raw mime and are rewritten to
the `%hoon` blot on the way in, or the code namespace would not see
them. The destination's own neck is preserved through the overwrite.

```live
/desk/gub/nex/desk.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 510-535
```

```live
/desk/gub/nex/desk.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 633-668
```

```live
/desk/gub/nex/desk.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1063-1095
```

> [!note] Wart: a neck-less code directory is never repaired
> `/desk/code` created without the `[/ %code]` neck, by an older kernel
> or by hand, is not a code namespace, so nothing compiles what lands in
> it, and every instance the bill declares bangs with no built nexus.
> Because the pull preserves the destination's neck, no release can fix
> it; the desk reports itself up to date while its app hangs. The desk
> should check the neck on rise and after every pull, re-fold the same
> contents under the right one when it is wrong, and reload the
> instances that banged.

### The fiber

The `source.json` fiber registers the desk with the usergroups registry,
keeps the source's version file, pulls once at rise if behind, and then
waits: news on the version means snapshot, then pull; a poke means the
source changed, so drop the keep and start over.

```live
/desk/gub/nex/desk.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 135-189
```

## Installing the bill

`bill.json` at the code root maps instance names to the nexus in the code
that should run there. On every real version, the version watcher runs
`+apply-bill`: for each entry not yet present under `/desk/data`, make a
directory with that neck and an empty weir, so the instance is born
unable to reach anything until the shell approves its ask. Existing
entries are skipped, so the bill can grow. It then rebuilds the desk's
aggregate ask and pokes the shell's sweep, so the new apps' asks surface
at once.

```live
/desk/gub/nex/desk.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 355-374
```

```live
/desk/gub/nex/desk.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 537-602
```

> [!note] Wart: one bad bill entry loses the whole bill
> Every value in the bill is read as a string with `+so:dejs`, which
> crashes on any other shape, and the crash takes the whole fiber's
> event with it: no instance made, no ask raised, no error, since a
> crashed fiber's step contributes nothing. A bill with one leftover
> object key beside a good entry installs nothing and looks like a
> clone still running. An entry the desk cannot read should cost that
> entry, named in the log, and nothing else.

The desk-level ask is the union of its children's `weir.json` files, one
entry per child, tagged by app; it is what the desk's own UI shows.

```live
/desk/gub/nex/desk.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 604-631
```

## Snapshots

A snapshot is one firm of the `/desk` directory, which firms everything
beneath it: code and data together, one revision, one number. The number
is a monotonic counter kept in `snapshot.ud` and written as a tag on the
revision; a firm of unchanged content dedups to the existing revision,
which is already a snapshot, so the same world is never numbered twice.
Every action that changes the live world snapshots first.

```live
/desk/gub/nex/desk.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 698-732
```

The first real version takes snapshot zero after wiping any earlier
history of `/desk`, so a desk's history starts at its first release.

```live
/desk/gub/nex/desk.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 688-696
```

### Checkout

A snapshot can be laid out for inspection under `/checkout`, as two inert
directories: no neck, so nothing compiles or runs, and a permit-nothing
weir. The snapshot's necks are written beside it as a sidecar so the file
view can still show which directories were nexuses.

```live
/desk/gub/nex/desk.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 229-274
```

### Compose

Composing builds a new live world by choosing code from live, a snapshot,
or none, and data from live or a snapshot, independently. It snapshots
first, then culls `/desk` and makes the assembled bole in one step, so
code and data reload together. Each half rides as a neck-preserving bole,
so data instances land governed and `/desk/code` keeps its neck.

```live
/desk/gub/nex/desk.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1158-1202
```

## Publishing

Opening a desk to other ships is a set of usergroups in `share.usergroups`.
Each group named there is granted, through the registry, exactly what a
follower needs: peek on `/desk/code` and on the desk's `version.json`.
Groups dropped from the set, and the public group always, are cleared.
See [Usergroups](#usergroups.md) for the registry.

```live
/desk/gub/nex/desk.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 191-216
```

```live
/desk/gub/nex/desk.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 422-457
```

## The wrapper on the shell

A desk lives at `/apps/shell.shell/desks/<name>.desk`, made by the shell.
For a stock entry backed by GitHub the shell first provisions a git
repository nexus that polls the remote and checks it out, then makes the
desk, then points the desk's source at the checkout's code directory. For
an entry backed by a namespace path it makes the desk and points it.

```live
/desk/gub/nex/shell.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1843-1854
```

```live
/desk/gub/nex/shell.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1874-1936
```

> [!note] Wart: the desk is made after a pull that may never answer
> The pairing fires a fresh pull as a hard poke at the end of its first
> step and makes the desk after it. The repository's fetch waits on a
> transfer grub with no deadline, so a fetch that never completes leaves
> the poke unacked, the fiber parked, and no desk made, with nothing
> logged. Everything that needs no network, the repository, its config,
> the desk, and its source, should be made first, and the pull sent last
> as a soft poke.

## Actions

The desk's HTTP fiber binds `/grubbery/desk/<name>` and answers reads
from its state and its history. Its actions are set the source, fetch
now, snapshot, compose, share, checkout, clear or tag a snapshot. Each
one writes a grub or pokes a fiber above; the routes hold no state.

```live
/desk/gub/nex/desk.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1609-1659
```
