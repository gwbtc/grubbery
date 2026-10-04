# Dropping a remote subscription parks the fiber forever

**Problem.** [`+drop`](#subscriptions.md) sends `%drop` and waits on
`+take-fell`:

```live
/grubbery/lib/fiberio.hoon 839-845
```

For a local road the agent enqueues the `%fell` itself. For a remote road
`+handle-dart` only forwards the drop to the peer, and a peer never answers a
drop:

```live
/grubbery/app/grubbery.hoon 3521-3532
```

So the fiber waits forever. The desk nexus drops its version subscription on
every `source.json` poke, so a follower stopped tracking version bumps, its
pokes hung with no response, and nothing was logged.

**Proposed solution.** The remote `%drop` path enqueues the `%fell` after
sending the drop, as the local path does.

**Status.** Open, [proposed](https://github.com/gwbtc/grubbery/pull/71).
