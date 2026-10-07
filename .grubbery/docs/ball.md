# The ball

A directory can be held as one value. A ball is a subtree with typed
content at every leaf; a bole is the same subtree with raw nouns. A peek
of a directory materializes a ball from the stored tree jects. A nexus's
`+on-load` computes a bole. The kernel lands a bole as one write, tombing
whatever the bole leaves out. So the three ways a whole directory moves,
being read, being described, and being written, are one tree shape in two
forms, and one door over each. The kernel's HTTP file API is that shape
served over the wire.

## Two shapes of tree

Both are an axal: at each path, an optional node and a map of children.
A ball's node is a `$lump`: the directory's neck, weir, gain, bang, and its
files as sangs, each with its own gain and bang. A bole's node is a
`$pulp`: the same without bangs, and the files as basks. A ball is what
you get; a bole is what you give.

```live
/desk/lib/tarball.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 64-82
```

A ball becomes a bole by dropping each sang to its noun, and becomes a
`$tree`, names and marks only, for listings.

```live
/desk/lib/tarball.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 607-624
```

## The doors

`+ba` is the door over a ball. `+get` and `+put` address a file by rail;
`+put` creates the directories on the way and refuses a name that is
already a directory, or a directory name that is already a file.

```live
/desk/lib/tarball.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 644-678
```

`+tap` flattens a ball to rail-and-sang pairs and `+gas` folds them back;
between them sit map, reduce, and the predicates.

```live
/desk/lib/tarball.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 767-795
```

`+dip` descends to a subdirectory as a new ball; `+dap` does the same and
says when the path is not there.

```live
/desk/lib/tarball.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 859-875
```

`+bo` is the door over a bole, with the two arms a builder needs.

```live
/desk/lib/tarball.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 890-915
```

## Materializing

A directory peek answers with a ball built from the tree jects: for each
file hash, the leaf's sang through the mark cache and its gain and bang;
for each child, the child's ball, with the child's weir copied in from
this directory's entry, since a directory's weir lives in its parent.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 2081-2127
```

The shallow form resolves this directory's files and leaves each child as
an empty ball carrying only its weir. A directory listing costs the files
at that level, not the whole subtree beneath.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 2176-2224
```

> [!note] A shallow ball is indistinguishable from an empty one
> A child in a shallow ball is `[`[~ weir %.n ~ ~] ~]`, which is also what
> a deep ball holds for a directory with no files and no children. The
> ball does not say which it is. Code that walks a ball has to know how
> the ball was peeked.

The current ball at a fold is the directory's top revision followed to
its tree ject; a bole is materialized the same way when the kernel needs
raw nouns rather than vases, as for a reload.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 2257-2271
```

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 2160-2175
```

## Landing

Every whole-directory write goes through `+load-ball-changes`: a make of a
directory, a reload's `+on-load` result, a cull as the empty bole, a
mirror's overwrite. It lands the bole, rebuilds the tree hashes above,
deregisters any code namespace the bole removed, rebuilds any it changed,
and notifies once.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 4768-4781
```

`+sync-bole` is the landing. It recurses into every child named by the
bole or present in the born, bottom-up, so children settle before their
parent's tree is built. At each level it records the bole's files, tombs
every file the born has that the bole does not and drops that file's
process, and then builds the directory's tree ject from what settled. A
level the bole leaves entirely empty is recorded as deleted.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 4822-4949
```

`+ball-diff` names the rails that differ between two balls, by mark and
noun; the build uses it to find what a landed bole changed.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 5147-5181
```

## The HTTP file API

`/grubbery/api` is the ball over HTTP, one endpoint per operation, on the
requesting ship's own authority only: read a file with an optional mark
conversion, list children, fetch a tree or a tarball, make and delete
files and directories, poke, overwrite, upload a multipart tree, read and
set weirs, and keep a stream. Pure reads are answered inline by the
kernel before a fiber exists (see [/sys/eyre](#sys-eyre.md)); the rest run
here, in a request fiber under `/sys/eyre/requests`.

```live
/desk/lib/ball-api.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 14-63
```

`GET /keep` is a subscription as a stream: the fiber keeps the lane,
sends an `old` event per file for the initial wave, then one `new`,
`upd`, or `del` event per lane that moves, and a keep-alive every thirty
seconds.

```live
/desk/lib/ball-api.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 453-548
```

> [!note] Wart: the API's file read materializes the whole tree
> `+serve-file-peek` peeks the root as a deep ball and dips to the one
> file it wants. The kernel's inline read for `GET /file` shadows this
> arm for every request from our own ship, and the fiber refuses other
> ships, so the arm is unreachable today; but it is the arm the fiber
> would run, and it should peek the file's rail.

```live
/desk/lib/ball-api.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 137-160
```
