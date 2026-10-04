# The content-addressed store

Every version of every file and directory is stored once, under its hash,
in the silo. A version is a `$ject`, an object named by the hash of what it
says: for a file, the hash of its content, its mark, and its health; for a
directory, the hashes of its children. Content itself is a `$noun` under
its own hash. Two files with the same content share one noun; two
directories with the same children share one ject; and what keeps an
entry alive is a count of who refers to it. So the store gives the
namespace dedup and garbage collection out of one rule, that a reference
is a count, and everything on this page is who counts and when.

## Jects and nouns

A leaf ject names a file's content noun, the mark it was validated
against with the compile key of that mark, its gain flag, and, if the file
is banged, the noun holding the crash. A tree ject names a directory's
nexus, if any, its gain and bang, and a hash per file and per
subdirectory beneath it. A `$jobe` is a hash that names a ject and a
`$nobe` one that names a noun; they are the same atom type, and the
alias says which table to look in.

```live
/grubbery/lib/nexus.hoon 460-501
```

A ject hashes the file as experienced, not the bytes alone. A mark
recompile changes the compile key, so it changes every leaf's identity
under that mark, which is what lets reload detection, validation caching,
subscriptions, and cross-ship transfer all key on the same hash. Anything
wanting pure content identity builds it on top.

Reading a file through its ject is a walk: history to ject, ject to noun,
noun through the mark's validator into a vase, with the validation result
cached by noun and compile key.

```live
/grubbery/app/grubbery.hoon 2044-2078
```

## The two tables

The silo is two maps, nouns and jects, each entry a refcount and the
object. The four primitive operations are put, drop, get, and hash. A put
of an existing noun is a no-op that returns its hash; a drop below one
reference deletes.

```live
/grubbery/lib/nexus.hoon 724-758
```

A refcount is the number of owners, and a release must be the exact
inverse of a bump by the same owner. There are four kinds of owner.

## Owners

### A revision

A file's history holds one reference per live revision: `+record` stores
the noun, wraps it in a leaf ject, and puts the ject's hash in the
history entry's pace. When the next revision lands, the previous one is
tombed if it was `%temp`, and tombing drops the reference.

```live
/grubbery/lib/nexus.hoon 969-1027
```

### A parent

A ject owns what it names. When a ject is first inserted, `+put-ject`
bumps every noun and every child ject it references; when its count
reaches zero, `+drop-ject` drops them, and the drop cascades down through
whatever reaches zero in turn. A parent therefore keeps its whole subtree
alive from the root, and a batch insert has to go bottom-up, since a bump
on a child that is not there yet is silently nothing.

```live
/grubbery/lib/nexus.hoon 797-850
```

### A queued read

A peek answers with a `$cite` naming the ject, not the content, and the
content is resolved when the fiber consumes the answer. The answer waits as
a queued [take](#fibers.md), and in between the ject could be tombed out from
under it, so the kernel bumps its reference when the take is queued.
`+hydrate` resolves the cite to content when the take is offered to the
fiber, and drops the reference there.

```live
/grubbery/app/grubbery.hoon 3686-3690
```

```live
/grubbery/app/grubbery.hoon 4067-4069
```

The same holds for a cross-ship peek once its content has arrived: the
discharged cite bumps, and hydration drops.

```live
/grubbery/app/grubbery.hoon 843-883
```

A skipped take is offered — and so hydrated — again on each wakeup, so the one
bump can meet many drops. [A read in flight](#read-in-flight.md) follows this
reference from answer to release, and the over-drop a skipped take currently
suffers.

> [!note] Wart: the `%file` cite bumps twice
> The discharge above bumps a `%file` cite's ject in two consecutive
> lines, one of them added with the comment explaining why there must be
> one. Two bumps against one drop means every discharged remote file peek
> nets a reference that is never released, and a ject whose count never
> reaches zero is never collected. The second `%file` bump should go.

### A snap

A cross-ship peek is answered by a snap: the version's pace and the full
set of hashes reachable from it, so the reader can ask for what it lacks.
While the snap is pinned on the serving ship, every hash in it is bumped,
so the content survives until the reader has fetched it or the pin
expires; release is the exact inverse.

```live
/grubbery/lib/nexus.hoon 1281-1284
```

```live
/grubbery/app/grubbery.hoon 675-684
```

```live
/grubbery/app/grubbery.hoon 7012-7027
```

`+snap-subset` cuts the silo down to a set of hashes for sending; the
copies go out with zero counts, and the receiving side counts them as it
merges.

```live
/grubbery/app/grubbery.hoon 1299-1319
```

## Trees

A directory's ject is rebuilt after every write beneath it. `+record-trees`
takes the current ject hash of each file and each subdirectory from the
born, builds the tree object, and hashes it; if the hash matches the
directory's current version, nothing changes and the walk stops; if not,
`+put-tree` stores the new ject, bumps the directory's version, tombs the
previous `%temp` one, and the walk continues to the parent. A write to one
file therefore rewrites the tree jects on the path to the root and nothing
else.

```live
/grubbery/lib/nexus.hoon 532-616
```

```live
/grubbery/lib/nexus.hoon 617-650
```

## Reachability and bangs

`+reachable` is the transitive closure from a ject: every ject and noun
under it, kind-separated. `+reachable-shallow` stops at subdirectories.
Snaps are built from these.

```live
/grubbery/lib/nexus.hoon 854-917
```

A bang is part of a ject's identity. `+set-bang` stores the crash tang as a
noun, builds a new ject that references it, and drops the old one;
`+clear-bang` does the reverse. A grub that crashed and one that did not
are different objects with different hashes.

```live
/grubbery/lib/nexus.hoon 922-967
```

## Finding content by hash

`+seek-lobe` answers "which files, at which revisions, hold this content":
a walk over the histories under a lane, matching each live revision's leaf
against the noun hash.

```live
/grubbery/app/grubbery.hoon 1743-1793
```

## Audit and repair

A reference to a hash that is not in the table is a version that will
boom when read. `+audit-silo` finds every such version without walking
trees: one flat pass marks each ject with an absent immediate reference as
broken, a fixpoint propagates brokenness to whatever references a broken
ject, and each history entry is then a single lookup. It is read-only.

```live
/grubbery/app/grubbery.hoon 685-758
```

`+repair-silo` tombs each damaged version so the books say the content is
gone instead of a reader finding out. It never tombs a latest version, and
it runs only when poked.

```live
/grubbery/app/grubbery.hoon 775-841
```

> [!note] Wart: the absent-lobe traces are not evidence
> `+drop`, `+bump-ref`, `+bump-ject-ref`, and `+drop-ject` each print
> unconditionally when handed a hash the table lacks. A drop on a hash
> that is already gone is the cascade burying a corpse, and one ship
> printed the same line three thousand times for a lobe the audit did
> not list at all. The audit is the authority on damage; the traces
> should be behind a debug flag.
