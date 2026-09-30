# /sys/gall

Two things cross to Gall agents. A poke to an agent is a poke to
`/sys/gall/main.sig` naming the dock and a page; the kernel validates a
local page through the desk's mark, passes the poke, and pokes the
requester back with the agent's ack under `%poke-ack` on the requester's
wire. A subscription to an agent is materialized: each fact is validated
through its mark and written to a `data` grub under `/sys/gall/subs`,
beside a `live` flag, so any grub can peek or keep an agent's
subscription as a file.

## Poking an agent

```live
/grubbery/app/grubbery.hoon 7196-7254
```

```live
/grubbery/lib/fiberio.hoon 1307-1329
```

## A materialized subscription

```live
/grubbery/app/grubbery.hoon 5821-5843
```

A fact is written under the incoming cage's mark when a marc for it
exists, and as a page otherwise. A kick flips `live` and resubscribes; a
failed watch-ack flips it and stops.

```live
/grubbery/app/grubbery.hoon 5892-5941
```

At boot, every subscription found under `/sys/gall/subs` is
re-established by walking the tree for `live` files.

```live
/grubbery/app/grubbery.hoon 5942-5984
```

> [!note] Wart: the subscription grubs are not gained
> The `live` and `data` grubs under a subscription carry no gain, so the
> tomb sweep can remove them while the subscription is live. The TODO
> above `+gall-sub` says so. They should be gained for as long as the
> subscription is.

> [!note] Wart: a subscription can only be made from outside
> `%gall-watch` and `%gall-leave` are marks on the agent's own poke
> handler, reachable from the dojo or another agent, not from a fiber.
> No service poke under `/sys/gall` makes one, so no weir gates it and
> no nexus can subscribe to an agent for itself. The two should be
> service pokes like `%gall-poke`.
