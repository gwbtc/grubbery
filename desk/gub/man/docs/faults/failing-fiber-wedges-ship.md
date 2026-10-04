# A deterministically failing fiber wedges the ship

**Problem.** A failed fiber [restarts](#fibers.md) at once with a fresh start
take, drained in the same event:

```live
/grubbery/app/grubbery.hoon 4318-4331
```

A failure that recurs on every run therefore loops inside one gall event. The
serf pegs, HTTP stops answering, and the event never commits, so a kernel
update cannot land either. A sandboxed app whose first fiber poked a road it
had not been granted did this to ships in use.

**Proposed solution.** Two guards on the restart path. In the `%fail` branch
of `+process-do-next`, a failing take whose input was a `%veto` parks the
fiber with a message naming Permits, since the same dart is refused on every
retry. In `+abet`, one fiber is bounded to 32 restarts per drain and parked
past that. The counter is local to the drain, so no state changes shape.

**Status.** Open, [proposed](https://github.com/gwbtc/grubbery/pull/77).
