# Usergroups

Another ship acts in this ship's tree as a grub. Every poke, peek, or keep
it sends arrives from a `ship.sig` under `/sys/ames/ships/`, and climbs
from there like any dart (see [Sandboxing & weirs](#weirs.md)). The first
fence on that climb is the weir on the ship's own directory; the
directories above it carry none. So what a ship may reach here is one
weir, and usergroups are how that weir is decided. A group is a set of
ships and a set of roads. A ship's weir is the union of the roads of every
group it belongs to, plus the public group's. And the registry is how a
nexus grants roads into groups without owning the groups: it claims a
prefix of the tree, and from then on it may put roads under that prefix
into any group. Sharing part of the tree with another ship is therefore
two facts held apart: which ships are in a group, and which roads a group
has.

## A foreign ship is a grub

The rail a ship's darts arrive from is fixed by its name.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 884-891
```

The first time a ship sends anything, a remote load, a transfer, or a
client command, the kernel makes its place in the tree: the directory; a
`/root` under it, which is the prefix this ship uses to name places in
*that* ship's tree; the `ship.sig` with a running process; and the weir
on the directory. Our own ship gets no weir and reaches everything.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1039-1043
```

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 6162-6179
```

A dart the weir refuses is not answered with a veto, as a local grub's
would be. It crashes the event, so Gall nacks the sending ship.

## A group

### Where a group lives

A group is a directory under `/sys/ames/usergroups/`, named by a path with
`.grp` on its last segment, so groups can nest under plain directories:
`/contacts/friends` is stored at
`/sys/ames/usergroups/contacts/friends.grp/`. Three grubs inside it carry
the group: `who.ships`, the members; `how.weir`, the roads; `man.md`, a
page describing the group to the ships in it.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 6199-6233
```

`+find-groups` walks the usergroups directory and returns every `.grp`
with its group path.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 6234-6245
```

### Members and roads

`who.ships` is a `$ships`, a set of `@p`, with a text form of
space-separated ships.

```live
/desk/gub/mar/ships.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290
```

`how.weir` is a `$weir`, the same three road sets a directory's weir has.
Every road in a group's weir is absolute. The relative form a fiber uses
for its own darts is refused here, since a group's roads are resolved
against no directory.

```live
/desk/lib/tarball.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 59-63
```

```live
/desk/gub/mar/weir.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1-39
```

### The public group

`/public` exists on every ship, created empty by `+ensure-public-group`.
Its roads apply to every foreign ship whether or not the ship is a member
of anything, so it is where a ship opens something to everyone.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 6126-6161
```

### Reading the groups

The kernel reads all groups at once into two maps: group path to members,
and group path to weir. `+build-peer-src` inverts the first into ship to
groups.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 6246-6273
```

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 6289-6305
```

## A ship's weir

A ship's weir is the union of its groups' weirs, unioned with the public
weir. Union of weirs is union per kind.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 6306-6333
```

It is written onto the ship's directory with `+set-weir`, the arm that
sets any directory's weir: an entry in the parent's tree, here the tree
of `/sys/ames/ships`. From then on the kernel enforces it like any other
fence. Whenever group data changes, `+recompute-all-weirs` recomputes and
rewrites the weir of every foreign ship that has a directory.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 7960-7972
```

> [!note] A membership edit reaches enforcement only through the registry
> Nothing watches `who.ships` or `how.weir`. Writing them changes what
> the next recompute will produce, and a recompute runs only at the end
> of a registry action. The tools that edit groups poke `%gc` afterward
> for that reason; a fiber that writes group files directly must do the
> same.

## The registry

### Registrants and prefixes

The registry is one grub, `/sys/ames/registry`, holding a map from a
registrant's rail to the path prefix it has claimed. A nexus that wants to
grant roads into groups registers first; a `%how` from an unregistered
rail is refused.

```live
/desk/gub/mar/usergroups/registry.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290
```

Four actions reach it, as pokes carrying the registry-action mark. The
kernel intercepts pokes to `/sys` grubs at dispatch and consumes them in
the same event, so the registry has no fiber; `+handle-ames-registry` runs
inline and the sender is acked directly.

```live
/desk/lib/nexus.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 225-233
```

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 6924-6929
```

### register and deregister

`%register` claims a prefix for a rail. The registry is itself a watcher,
in the sense of [Subscriptions](#subscriptions.md): it keeps the
registrant's rail, and since it has no fiber, its news is delivered
synchronously from inside `+notify`. A claim is last-writer-wins: an
existing row whose prefix overlaps the new one, in either direction, is
evicted and its watch dropped. `%deregister` removes the row and, if
asked, strips every road under the prefix from every group.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 7740-7786
```

> [!note] Wart: overlap eviction empties the registry
> The root nexus registers `/`, and `/` is a prefix of every path, so the
> symmetric overlap test above means the root's re-registration evicts
> every other registrant. The root re-rises on every rebuild. After one,
> the registry holds one row and every delegated `%how` is refused as
> not registered, with nothing logged beyond that line. Eviction should
> apply only to a claim of the same prefix; nested prefixes never contend,
> because `%how` scopes each registrant to its own. And `%deregister`'s
> strip should skip the prefixes of registrants nested inside the one
> leaving.

### how

`%how` sets a group's roads, from the registrant, within its prefix. Every
road in the request must be absolute and under the prefix, or the whole
request is refused. Roads already in the group under that prefix are
replaced by the request's; roads elsewhere in the group are untouched.
Then every ship's weir is recomputed.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 7788-7809
```

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 7924-7959
```

> [!note] Wart: a sandboxed registrant cannot name itself
> A fiber inside a fence learns its position only as far as `%here` may
> climb, so the rail it can name for itself is relative, `[/ %main.sig]`,
> and the roads it grants are relative too. The registry stores the rail
> as sent, so that row collides with the root nexus's own `[/ %main.sig]`;
> the `%how` from the app's real rail finds no registrant; and
> `+ug-extract-dir` rejects the relative roads outright. The registry
> should resolve a relative rail and relative roads against the sender,
> whose absolute rail the kernel knows: a rail whose path is a suffix of
> the sender's is the sender.

### gc

`%gc` reconciles: drop rows whose registrant grub no longer exists, strip
every group road no live prefix covers, re-establish the watches on the
registrants that remain, and recompute. It only removes, so any local
sender may invoke it.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 7811-7857
```

### A registrant dies

The registry's watch on each registrant delivers the registrant's deletion
to `+registry-news`. A content change is ignored. A death removes the row,
strips the group roads under its prefix, and recomputes.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 7860-7903
```

> [!note] Wart: the header lists actions that do not exist
> The comment above `+handle-ames-registry` names `%create-group`,
> `%delete-group`, `%add-ship`, and `%del-ship`. The action type has four
> tags and none of those are among them; groups and members are written
> as files. The comment should name what the type has.

## From a fiber

The library wraps the four actions as pokes to the registry's road.
`+reg-register` climbs to the root to learn its own absolute rail and
registers that, so it works only for a nexus no fence stops;
`+reg-register-at` takes the rail from the caller, for a nexus that was
told its place. The soft forms return the veto or nack as a value, for a
nexus for which registering is optional: refused, it keeps every local
feature and loses only the ability to open itself to other ships.

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 2020-2048
```

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 2066-2082
```

The tools that manage groups write the group files and then poke `%gc` so
the change reaches the weirs.

```live
/desk/gub/lib/tool-bundle/tools/create-usergroup.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 51-57
```
