# A skipped peek take over-drops its silo ref

**Problem.** A `%file`, `%ball` or `%peep` answer carries a
[lobe](#silo.md), and [its ref is bumped once when the take is
queued](#read-in-flight.md). `+hydrate` releases that ref every time it reads
the cite:

```live
/grubbery/app/grubbery.hoon 4066-4070
```

A fiber that skips the answer is offered it again on every wakeup, and
hydrated again, so one bump meets many drops. While the jobe is absent the
surplus drops no-op. When identical content recreates it, the next drops take
it to zero and delete it. Leaves are content-addressed, so a grub holding the
same bytes another ship sent reads back as `%none` after its own `make`
reported `%made`.

**Proposed solution.** Release the ref when the take is consumed, not per read.
`+hydrate` stops dropping, and the eval loop runs `+drop-pend-refs` on every
consumed path and not on `%skip`:

```live
/grubbery/app/grubbery.hoon 2748-2766
```

Process death already runs the same arm over `skip.proc`. Because this moves
when a ref is spent, a take already sitting in a skip queue at upgrade has
spent its ref under the old rule and would over-drop once under the new one.
Closing that needs a one-time pass at upgrade over every skip queue, re-bumping
a present jobe or neutralising a cite whose jobe is gone, and a new state
version so the pass runs once.

**Status.** Open, [proposed](https://github.com/gwbtc/grubbery/pull/81). [A remote file peek leaks a ject ref](#faults/remote-file-peek-leaks-ref.md) keeps the drop in `+hydrate`; the two cannot both land.
