# Code nexuses

Code is data in the tree. A directory named `code` carrying the neck
`[/ %code]` is a code namespace: its `/mar`, `/nex`, and `/lib` files are
source, and the kernel keeps them compiled. What the namespace governs is
decided by where it sits, its parent's children and everything below,
nearer namespaces shadowing farther ones, root `/code` last. The compiled
artifacts live outside the tree in a content-addressed store, and a fiber
reaches them with a dart like any other read. So the code an app runs on
is a subtree it can be given, a desk can ship, and a nexus can seed for
its own children, and a write into that subtree is a build.

## A namespace is a directory

The neck `[/ %code]` names no nexus source. It is a sentinel: the reload
walk registers or rebuilds a directory carrying it rather than loading it,
and the spawn walk starts no processes under it.

```live
/grubbery/app/grubbery.hoon 2931-2952
```

```live
/grubbery/app/grubbery.hoon 2959-2975
```

Root `/code` is in the genesis tree, an empty stub under the root nexus,
so the first sync has somewhere to land.

```live
/grubbery/app/grubbery.hoon 151-166
```

It is filled from the desk. `+sync-gub` reads every file under `/gub` in
Clay, restores the dotted names Clay split apart, stores `.hoon` sources
under the hoon mark and everything else as mime, and lands the whole ball
at `/code` through the one bulk write path. A directory named `bundle` or
ending in `-bundle` is data to whatever imports it, not code of this
namespace, and is stored as mime untouched.

```live
/grubbery/app/grubbery.hoon 5666-5706
```

```live
/grubbery/app/grubbery.hoon 5707-5726
```

Any nexus can lay out a `/code` of its own the same way, as a `%fall`
directory with the sentinel neck. The tools nexus does, and its host seeds
the tool bundle into it; a desk composes `/desk/code` from a live or
snapshotted source tree, so the apps under `/desk/data` run on the code
the desk shipped.

```live
/grubbery/gub/nex/tools.hoon 154-169
```

```live
/grubbery/gub/nex/desk.hoon 1180-1196
```

## Governance

A path's candidate namespaces are its sibling `/code`, then each
ancestor's, ending at root `/code`. `X/code` governs the children of `X`
and everything below them, never `X` itself.

```live
/grubbery/lib/tarball.hoon 141-156
```

Resolution walks that list and takes the first registered namespace that
has the artifact. A mark or nexus is addressed by its blot or neck, and
its source is the file `/mar/<path>/<name>.hoon` or `/nex/<path>/<name>.hoon`
inside the namespace; `+source-rail` and `+rail-addr` are that bijection,
and the index is keyed by the source rail.

```live
/grubbery/lib/tarball.hoon 157-187
```

```live
/grubbery/app/grubbery.hoon 1812-1852
```

`+owner-code` answers the other question, which namespace a source file
is inside: the nearest registered `/code` at or above it. Governance is
for readers; ownership is for writes.

```live
/grubbery/app/grubbery.hoon 4751-4767
```

## The index

Each registered namespace has a `$lode`: `keys`, one content-addressed
build key per source rail, and `deps`, the dependency graph. The key of a
file is the hash of its source, its path, and its dependencies' keys. The
artifacts themselves are in `bins`, a map from key to `$built` with a
reference count, shared by every namespace; two namespaces holding the
same file at the same key hold one artifact. The build subject, the
kernel's library vase, is a node in every namespace's graph keyed by its
hash, so a new agent is a changed dependency of every file.

```live
/grubbery/lib/nexus.hoon 10-34
```

A build takes the namespace's ball, forces the four foundational mark
sources into it (see [Marks](#marks.md)), works out which artifacts can
be reused, compiles the rest, indexes the results by key, and swaps the
namespace's references in `bins`, new keys counted up before old ones are
counted down. Then it re-validates grubs under changed marks and reloads
directories under changed nexuses. The compiler and the reuse set are
[The build system](#build-overview.md)'s subject.

```live
/grubbery/app/grubbery.hoon 5195-5245
```

```live
/grubbery/app/grubbery.hoon 5025-5048
```

> [!note] Wart: every artifact is stored as a raw vase
> A compiled mark is indexed as a `[%vase vase]` and every reader, the
> kernel's marc lookup, the nexus builder, the `%code` take, extracts it
> again, after `+validate-build` has already extracted it once to check
> its shape. A built kind per artifact, `[%marc marc]` and
> `[%nexus nexus]`, extracted once at index time as the foundational marks
> already are, would make every read a lookup. The comment in
> `+index-results` says so; it is a derived-state migration plus a type
> change through every reader, and is not built.

## Following writes

Nothing scans the tree for source changes. The one bulk write path lands
its bole, then deregisters every namespace under the write whose
directory is gone or no longer carries the sentinel, releasing its
artifacts, then diffs the ball before and after, groups the changed rails
by the namespace each is inside, and builds each such namespace once with
exactly those rails.

```live
/grubbery/app/grubbery.hoon 4768-4781
```

```live
/grubbery/app/grubbery.hoon 4782-4821
```

The reload walk covers the two cases a write cannot: a namespace that
exists but was never registered, and one compiled against a previous
agent. It makes each level's `/code` fresh before touching anything
beside it, so every nexus built on the way down resolves into a namespace
already compiled against the current subject. An unchanged subject is a
comparison of one hash, so an ordinary restart builds nothing.

```live
/grubbery/app/grubbery.hoon 2895-2930
```

### When a rebuild reloads

A recompile reloads the directories it governs. After a namespace
rebuilds, `+reload-changed-nexuses` finds every directory in the tree
whose recorded namespace is the one that rebuilt and whose nexus
artifact changed, and reloads it. The recorded namespace is stamped on
the directory's tree ject when the tree is built, from the ordinary
resolution, so the filter is a lookup, not a walk through the candidate
list, and a directory governed by a nearer namespace that has not yet
built is left alone.

```live
/grubbery/app/grubbery.hoon 5562-5621
```

The one caller that asks the build not to cascade is the boot walk,
which reloads the whole tree itself on the way down; cascading there
would reload everything twice.

> [!note] Wart: a forced make of a code namespace reloaded nothing
> `+make` landed its bole with the cascade off and relied on walking the
> made subtree. A desk delivers a release by making `/desk/code` alone,
> whose subtree holds no nexus, while the apps it governs live beside it
> under `/desk/data`; a release changed their code and nothing reloaded
> them. `+make` now cascades like any other write. The section above is a
> stub: the stamp, the filter, and the boot exception deserve a full
> account.

## Reading artifacts

A fiber reads the store with a `%code` dart, routed and fenced like a
peek. A directory destination answers with the artifacts under it as a
tree of source names; a file destination answers with one artifact, a
bare name meaning the `.hoon` source of that name. The kernel resolves the
destination through `+owner-code`, the namespace the path is inside, so a
fiber reads the namespace it names, not the one that governs it.

```live
/grubbery/app/grubbery.hoon 3729-3766
```

```live
/grubbery/app/grubbery.hoon 4094-4118
```

The library wraps the dart: `+get-code` for a vase or nothing,
`+get-code-full` for the artifact including a build failure's tang,
`+get-code-tree` for a directory. Over those sit the typed forms, a marc
or a nexus extracted from the vase, and `+get-tube`, which asks the
source mark's `+grow` and then the target's `+grab`, as the kernel does.

```live
/grubbery/lib/fiberio.hoon 1038-1066
```

```live
/grubbery/lib/fiberio.hoon 1109-1157
```

This is how a nexus runs code it was given. The tools nexus lists its
tools by walking its own `/code/lib/tools` and reading each artifact, and
runs one by reading the artifact for its name; a tool that failed to build
reports its tang as the run's error. The `check_bin` tool is the same read
offered to an agent: a bins path and a name, answered with the compile
error or a confirmation.

```live
/grubbery/gub/nex/tools.hoon 83-101
```

```live
/grubbery/gub/lib/tool-bundle/tools/check-bin.hoon 67-75
```

> [!note] Wart: the tube form of the code dart has no callers
> A file destination `/tub/<from>/<to>` builds a tube through the source
> mark's `+grow`, puts it into `bins` under its own hash with one
> reference, and answers with that key. Nothing sends it; `+get-tube` in
> the library resolves tubes through the marcs instead. The entry it
> would write belongs to no lode, so no deregistration or rebuild would
> ever release it. The branch should go.

```live
/grubbery/app/grubbery.hoon 3767-3785
```
