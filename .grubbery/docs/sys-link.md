# /sys/link

A name resolves to places. `/sys/link/<name>/dest.lanes` holds the app
roots that claim the name, earliest claimant first, so a peer, local or
remote, can keep a name and learn where its app lives. The kernel lays
out the directory and nothing more; the shell builds the registry from
every app's `link.json`, keeps the order it already has when it rebuilds,
appending new claimants and dropping gone ones, and culls names nothing
claims. Which ships may read a name is a usergroups grant the shell
makes per shared alias (see [Permissions](#permissions.md)). An app that
needs another app asks for the name and appends the place it wants, so
an app that moves from `/apps` into a desk keeps its callers.

```live
/desk/lib/root.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 69-71
```

```live
/desk/gub/nex/shell.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 2748-2763
```

```live
/desk/gub/nex/shell.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 3188-3228
```

## From a fiber

The library resolves a name to its default root, the head of the list,
or to a place under that root; the remote forms read the publisher's
registry and prefix each lane with the ship's place in our tree.

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 2083-2171
```
