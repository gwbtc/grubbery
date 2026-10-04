# A consumed take comes back when the fiber is banged

**Problem.** A consumed take never comes back: that is the invariant. The
eval loop pops the take a step consumed from its working copy of the
process, `new-proc`, and every outcome stores that copy. `%next` stores it,
`%done` nacks from it, `%fail` restarts from it:

```live
/grubbery/app/grubbery.hoon 4332-4336
```

Banging did not. `+mark-bang` copies the queues from the pool, which still
holds the snapshot taken before the step ran, so the take the step consumed
is carried into the banged process:

```live
/grubbery/app/grubbery.hoon 2489-2500
```

A reload then merges those queues into the fresh process, which is offered a
take its predecessor already consumed. The `%fail` branch reaches a bang
when the spool fails to rebuild, and a design that bangs on every
[`%veto`](#weirs.md) failure reaches it every time: the fresh fiber fails on
the resurrected veto before it has sent anything, and granting the permits
and reloading never revives it.

**Proposed solution.** The `%fail` branch stores `new-proc` before anything
can bang, so a bang reached from a failed step carries the synced queues:

```live
/grubbery/app/grubbery.hoon 4316-4321
```

The other bang callers run before a step, when the pool is the truth, so
`+mark-bang` reading the pool is right for them.

**Status.** Fixed in `+process-do-next`.
