# Cross-ship

Another ship's tree is a place in this one. A lane under
`/sys/ames/ships/<ship>/root/` names a rail or fold on that ship, and a
dart at it is sent there as a load, arriving from the sending ship's own
`ship.sig` grub and climbing through that grub's weir like any dart (see
[Usergroups](#usergroups.md)). Pokes, makes, culls, sands, and loads cross
as they are; a peek crosses as a negotiation over content hashes, so the
requester fetches only the jects and nouns it does not already hold; a
keep crosses as a watcher on the other side, with waves poked back. So a
fiber reads and writes a remote tree with the same darts it uses at home,
and what comes back is a view, a pack, or news, with the refusals a
remote can add: a veto, a miss, a tomb.

## Naming a remote place

`+resolve-remote` splits a lane under the ships prefix into the ship and
the lane as that ship sees it; the library does the same on the way out
and offers `+peek-remote`, which builds the prefixed road from a plain
one.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 3410-3421
```

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 568-590
```

## The wire

Three marks cross between two grubberies. A load is a request about a
place: the same operations as a local dart, minus the ones that only read
history. A transfer is the peek negotiation and the poke result. An
intake is a subscription wave. The kernel takes each as a poke from the
peer's agent.

```live
/desk/lib/nexus.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1213-1285
```

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 191-211
```

## Loads

A load arrives with the peer as source. The kernel makes sure the peer
has its directory and `ship.sig` (see [Usergroups](#usergroups.md)), and
then processes a dart from that grub, so the peer's weir is the only gate
and the operation is otherwise the local one.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1039-1057
```

A poke keeps its request wire so the consumption result finds its way
back. Outbound, `+dart-poke` encodes the sender's rail and wire into the
load's wire and gives no pack, since consumption happens on the other
ship; the pack arrives later as a transfer, and `+process-pack` decodes
the wire and delivers it on the sender's own wire, indistinguishable from
a local pack.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 3786-3808
```

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1176-1196
```

## Peeks

### Staging

A peek at a remote lane is staged in `peeks`, keyed by the requesting
rail and wire, and sent as a load. The fiber suspends on its take as it
would for a local peek; the answer comes from the discharge sweep.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 3642-3654
```

### The snap

On the peer, the peek is gated by the caller's weir; a refusal is a
`%veto` transfer, so the requester is answered rather than left waiting.
Otherwise the peer resolves the version, computes the set of jects and
nouns reachable from it, and answers with a snap: the version, its pace,
and the hashes. A small payload rides inline in the snap; a larger one
is pinned, every referenced lobe's count bumped so a tomb cannot remove
it, with a five-minute expiry.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1058-1145
```

```live
/desk/lib/nexus.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1277-1284
```

### Want and data

The requester accepts only snaps it asked for. It records the snap on
each matching staged peek, diffs the hashes against its own silo, and
either discharges at once, everything already held, or sends a `%want`
with the snap id. The peer serves the pinned subset as `%data`, releases
the pin, and cancels the expiry.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1359-1420
```

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1197-1221
```

Received content is verified by hash, merged into the silo at a count of
one or bumped if present, jects inserted bottom-up so a tree never lands
before its children, and then the transfer releases exactly the bumps it
made, once the discharge sweep has let each cite claim its own.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1222-1294
```

### Discharge

A staged peek whose snap's hashes are all present is discharged: the
kernel builds the view from the snap and the silo, bumps the cite's lobe
the way a local peek does, and delivers the `%peek` take to the fiber.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 836-883
```

### The refusals

A view has three answers a local peek never gives. `%veto` is the peer's
weir. `%miss` is a snap that expired before the want arrived, so the
caller may retry. `%none` from a peer means nothing at that lane.

```live
/desk/lib/nexus.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 79-86
```

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1421-1458
```

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 7012-7027
```

> [!note] Wart: a miss discharges every peek at that ship
> A `%miss` transfer carries no lane and no snap id, and the handler
> discharges every staged peek whose ship matches, including peeks whose
> snaps are still live. The peer knows which snap missed; the transfer
> should carry the id, and the handler should discharge that one.

## Keeps

A keep at a remote lane registers the watcher here under the prefixed
lane and forwards a `%keep` load; the peer registers the caller's
`ship.sig` as a watcher and pokes waves back as intakes, which the kernel
delivers as news to the local watchers. [Subscriptions](#subscriptions.md)
walks both sides.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1335-1349
```

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1467-1491
```
