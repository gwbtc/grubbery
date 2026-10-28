# A remote file peek leaks a ject ref

**Problem.** A data-carrying cite gets a [ject](#silo.md) ref bumped when it is
discharged, matched by `+hydrate`'s single drop on read. The `%file` branch of
the bump is written twice, so every discharged remote file peek nets one extra
ref. A ject whose count never reaches zero is never collected, and the silo
grows for the life of the ship. `%ball` is bumped once and is correct.

Separately, the four refcount traces are unconditional `~& >>>`. One ship
logged thousands of identical lines for a lobe that `+audit-silo` showed was
already fully collected, with nothing referencing it.

**Proposed solution.** Remove the duplicate `%file` bump. Put the four traces
behind a per-file `+dbg`, off by default.

**Status.** Open, [proposed](https://github.com/gwbtc/grubbery/pull/74). Conflicts with [A skipped peek take over-drops its silo ref](#faults/skipped-take-over-drops-ref.md) on where the accounting lives.
