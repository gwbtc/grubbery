# The namespace

The namespace is one tree holding every nexus's data. Each leaf is a typed
noun, each node has a version history, and identical content is stored
once. There is no other state: what a nexus knows is what is in its part
of the tree, and what the kernel restores after a reload is the tree. So
reading, writing, versioning, and watching are all operations on the same
structure, and a nexus never has a heap of its own to migrate.

## Rails, lanes, and grubs

A file is named by a `$rail`, its directory path plus its name, and a
directory by a `$fold`, a bare path. A `$lane` is either; it is how every
operation says whether it means the file or the directory.

```live
/grubbery/lib/tarball.hoon 39-43
```

A grub is what lives at a rail: the file's content and the process that
runs beside it, taken as one thing. This page is about the content side;
the process side is [Fibers](#fibers.md).

```live
/grubbery/lib/nexus.hoon 35-43
```

Content is a noun with a mark. A `$blot` names the mark; a `$bask` is a
blot with a raw noun; a `$sage` is a blot with a typed vase; and a
`$sang` is a blot with either a vase or a `$boom`, the noun plus the error
from failing to type it. A grub whose content does not validate against
its mark is still stored, as a boom, so a bad write is visible rather than
lost.

```live
/grubbery/lib/tarball.hoon 5-12
```

## Versions

### A cass and a hist

Every file and every directory has a history: a `$hist`, an ordered map
from a `$cass:clay`, a revision number paired with a date, to an entry.
The entry's `$pace` says what that revision holds: `%firm` or `%temp`
with the hash of the stored content, or `%tomb` for a revision whose
content is gone. Tags are free labels on an entry.

```live
/grubbery/lib/nexus.hoon 404-459
```

### The born

The histories sit in one axal shaped like the tree, the `$born`: at each
path, the directory's own history, `fold`, and a history per file. The
door over it, `+bo`, is the whole vocabulary: get and put a file's
history, read a directory's current version, compute the next cass. A
history is never deleted, so a rail that is deleted and re-created
continues its numbering rather than starting over.

```live
/grubbery/lib/nexus.hoon 651-716
```

### What bumps a version

A file's version bumps only when its content changes. `+record` in the
store compares the new noun's hash, its mark, and its gain flag against the
current revision, and returns the history unchanged if they all match. So
a write that writes the same thing is not a version.

```live
/grubbery/lib/nexus.hoon 979-1027
```

A directory's version bumps when anything beneath it changes. After a
write, `+record-trees` rebuilds the directory's tree object from its
files' and subdirectories' current hashes, walking upward, and stops at
the first level whose hash did not change. The root's version therefore
moves on every write anywhere, and a subtree's version is a summary of
everything under it. This is what a subscription watches; see
[Subscriptions](#subscriptions.md).

```live
/grubbery/lib/nexus.hoon 532-537
```

## Retention

### temp and firm

A revision is `%temp` or `%firm`, and the difference is what happens on
the next write. When a new revision is recorded, the previous one is
tombed if it was `%temp`: its content is released and the entry becomes
`%tomb`. A `%firm` revision stays. So by default a file's history is one
live revision and a trail of tombs; a firm revision is a kept version.

```live
/grubbery/lib/nexus.hoon 969-978
```

Which of the two a write produces is the grub's gain flag: gain on writes
`%firm`, gain off writes `%temp`. A grub is born with gain off unless its
maker asks otherwise, and `+set-gain-lane` flips it, for one file or a
whole subtree.

```live
/grubbery/app/grubbery.hoon 1604-1640
```

`+checkpoint` promotes the current revision to firm, so a grub that is
normally overwritten can keep one version on purpose.

```live
/grubbery/lib/fiberio.hoon 491-499
```

### Dropping history

`+drop-hist` tombs the revisions a `$lose` selects, by cass, by date
range, or by number range, releasing their content. Tombing the current
revision appends a fresh empty `%temp` on top, so the file reads as
absent rather than as its last kept version.

```live
/grubbery/app/grubbery.hoon 1503-1546
```

## Writing

A file is made with a `%make`, which fails if a live revision already
exists unless forced, converts the content to another mark if asked,
validates it, and stores it: validated as a vase, or unvalidated as a boom.
Then it spawns the grub's process.

```live
/grubbery/app/grubbery.hoon 4341-4442
```

Every store goes through `+record`, which hashes the noun, writes the leaf
into the store, and puts the new revision in the history. Then
`+propagate` rebuilds the directory hashes above it and notifies watchers.
This pair is the tail of every write, whatever made it.

```live
/grubbery/app/grubbery.hoon 4711-4750
```

```live
/grubbery/app/grubbery.hoon 4686-4694
```

A directory is made from a `$bole`, a tree of basks, and landed as one
update through `+load-ball-changes`, which records every file, tombs every
file that was there and is not in the bole, rebuilds the tree, and notifies
once. A `%cull` of a directory is the same with an empty bole; a cull of a
file tombs it and removes its process.

```live
/grubbery/app/grubbery.hoon 4443-4466
```

> [!note] Convention: record and cache in sibling grubs
> A nexus keeps authoritative state and rebuildable state in separate
> sibling directories, so a reader of its `+on-load` can tell what is
> precious from what is disposable: the shell's consent records under
> `/permit`, its derived views under `/cache`. Nothing enforces this. It
> is how the tree stays legible.

## Reading

The current content of a rail is the top of its history, if that revision
is live: not a tomb, and holding a hash. `+peek-grub-now` follows that
chain to the stored leaf and returns its sang, or `~` when there is nothing
there.

```live
/grubbery/app/grubbery.hoon 2240-2256
```

A historical revision is reached by `$case`: an exact revision number, or
the latest revision at or before a date. A miss is `~`, an ordinary
outcome.

```live
/grubbery/lib/nexus.hoon 510-531
```

From a fiber, `+peek` returns a `$view`: a file's cass and sang, a
directory's wave and ball, or one of the four ways there is nothing: never
existed, that revision is not here, refused by a weir, tombed. `+peek-as`
casts the content to a mold and gives `~` on any of those; `+peek-at` reads
a revision by case.

```live
/grubbery/lib/nexus.hoon 79-86
```

```live
/grubbery/lib/fiberio.hoon 539-548
```

```live
/grubbery/lib/fiberio.hoon 560-570
```

A peek's answer is carried as a cite naming the ject, and resolved to content
only when the fiber consumes it; across that gap the read owns a reference to
the ject. [A read in flight](#read-in-flight.md) follows that one reference
from the answer to its release.

## From outside

A Gall agent, on this ship or another, reaches the tree through a thin
surface: subscribe to a channel, poke commands tagged with it, and take
every outcome as a fact on the subscription. The types cross the boundary
as paths, mark names, and raw nouns; validating the noun is the reader's
job. The caller acts as its ship's `ship.sig`, our own ship included, so a
local agent's privilege is the absence of a weir on its own path.

```live
/grubbery/sur/grub.hoon 27-53
```

```live
/grubbery/lib/grub.hoon
```

On the kernel side each command becomes a dart from the ship's rail, so it
passes the same weir every fiber's dart does. A peek is answered
synchronously from the tree, with the content raw.

```live
/grubbery/app/grubbery.hoon 990-1018
```
