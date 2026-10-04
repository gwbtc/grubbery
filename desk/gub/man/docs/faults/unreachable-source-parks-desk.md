# A desk following an unreachable source parks forever

**Problem.** The desk nexus [keeps](#subscriptions.md) its source's version
file with `+keep`, which sends `%keep` and waits on `+take-bond`:

```live
/grubbery/lib/fiberio.hoon 832-838
```

Nothing ends that wait. For a remote road it is on a peer, so a follower whose
publisher is unreachable when it subscribes ends up with nothing subscribed,
an empty `/desk/code`, no instance, and no error or retry:

```live
/grubbery/gub/nex/desk.hoon 157-159
```

**Proposed solution.** `+keep-soft`, a `+keep` with a deadline that returns
`~` if the bond never arrives, arming a timer beside the bond and taking
whichever comes first. The desk's source wait uses it and retries with
backoff, doubling from one minute to one hour, sleeping on behn between tries.

**Status.** Open, [proposed](https://github.com/gwbtc/grubbery/pull/63).
