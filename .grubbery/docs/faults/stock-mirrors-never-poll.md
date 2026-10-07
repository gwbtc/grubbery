# Stock mirrors never poll github

**Problem.** `+ensure-pairing` provisions a stock mirror's git repo and writes
its config with a poll cadence:

```live
/desk/gub/nex/shell.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1930-1938
```

The repo's poll daemon reads `poll.json`, seeded off, and nothing copies the
cadence across. A mirror only pulls when poked, so a version pushed to github
never reaches the distributor by itself, and every subscriber's re-sync waits
on that step.

**Proposed solution.** `+ensure-poll` turns a mirror's daemon on when it is
off and leaves a cadence someone set alone. The shell runs it for every github
stock mirror on every boot, not only the first.

**Status.** Open, [proposed](https://github.com/gwbtc/grubbery/pull/72).
