# Sandboxing & weirs

A dart does not go straight to its destination. It climbs from the grub
that sent it to the nearest directory that stands above both sender and
destination, and then descends. Climbing is what a weir governs: each
directory on the way up may carry one, a statement of what may leave it,
and a dart that no weir on its climb refuses gets through. Descending is
always free. So a directory's weir is a fence around everything inside it,
set by whoever owns the directory, and a nexus is sandboxed by the fences
between it and the rest of the tree, none of which it can see or change.

## A weir

A weir is three sets of roads, one per kind of dart: what may be made,
culled, sanded, or loaded; what may be poked; what may be read. A road in
a weir is either absolute or relative to the directory that carries the
weir.

```live
/desk/lib/tarball.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 59-63
```

A directory with no weir filters nothing. A directory with a weir whose
sets are empty lets nothing out: a fence with no gates. The two are
different values, `~` and `[~ ~ ~]`, and both are meant.

```live
/desk/lib/nexus.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 47-73
```

## Where a weir lives

A directory's weir is not stored in the directory. It is a field of the
parent's tree ject, on the entry that names the child, so the child cannot
rewrite its own fence: that is a write to the parent, which is outside it.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 4638-4662
```

Setting one is `+set-weir`: rewrite the parent's tree with the new entry,
record the tree hashes up to the root, notify, and then re-check every
subscription held by a grub under the fence, felling any the new weir
would now refuse.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 4485-4527
```

A fiber sets a weir with a `%sand` dart, which is a make-kind dart, so a
grub may only sand directories its own fences let it make in. A grub
remaking its own root cannot smuggle a weir in on the make: the kernel
records a made bole's root weir only when the maker sits outside it.

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 645-663
```

## The climb

### The governor

The governor is the nearest directory strictly above both the sender and
the destination. For a file destination that is the common prefix of the
two paths. For a directory destination at or above the sender, the
operation touches an entry the directory's parent owns, so the governor is
one level higher. The climb checks every directory from the sender up to
but not including the governor; the governor is reached, not passed
through.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 4573-4595
```

### The walk

`+allowed` walks from the sender's directory to the governor. At each
level it reads that directory's weir and folds the answer into a `$filt`:
`~` so far means no weir has spoken, `[~ &]` means one has allowed, and
`[~ |]` means one has refused. A refusal ends the walk. Reaching the
governor with no refusal is a pass.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 4596-4637
```

One weir answers by resolving its roads against its own directory and
asking whether any of them covers the destination. A file road covers only
that file; a directory road covers everything at or under it; a file road
never covers a directory operation.

```live
/desk/lib/nexus.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1340-1395
```

## The gate

Every dart passes through `+process-dart` before anything is done with it.
The dart's road is resolved to an absolute lane, its load is classed as a
make, a poke, or a peek, and the climb is run. A dart with no destination,
`%here` or `%kept`, crosses no boundary and is not filtered.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 3390-3409
```

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 3357-3389
```

A refused dart from a local grub becomes a `%veto` intake back to that
grub: its answer, on the wire it sent. The hard verbs in the fiber library
fail on it and the soft ones return it as a value. A refused dart from
another ship crashes the event instead, so Gall nacks the sending ship.

> [!note] Wart: `+validate-sage` has no callers
> The arm below is described as validation at the sandbox boundary, for
> data crossing a weir from an untrusted source. Nothing calls it. Peek
> results are validated when the reading fiber hydrates them, against the
> reader's own mark; pokes are validated at hydration too. The arm should
> go.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1979-1989
```

## Where am I

A grub inside a fence does not know its absolute rail. `%here` walks up
from the grub, one directory at a time, and stops at the first one the
grub may not peek; what comes back is the ancestry as far as the fences
allow, with each directory's neck, and whether the root was reached. A
sandboxed nexus therefore sees the tree from its own root, which is why
it names itself and its roads relatively.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 4528-4572
```

## When a weir changes

A weir is part of the parent's tree, so changing one bumps the parent's
version like any write, and watchers of the parent hear about it.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 4467-4484
```

Subscriptions held by grubs under the fence are re-checked as reads:
any the new weir refuses is felled, and the watcher gets a `%fell` on the
wire it kept with.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 3261-3280
```

> [!note] Roads relative to a nexus, not a directory
> A relative road counts directories up from the sender, so a fiber that
> moves within its nexus, or a nexus mounted at a different depth, gets a
> different answer from the same road. The library's `+nex-road` and
> `+ancestor-road` compute the count from the nearest neck instead. A
> road syntax that resolves from the governing nexus directly is
> sketched in a comment and not built.

```live
/desk/lib/tarball.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 44-56
```
