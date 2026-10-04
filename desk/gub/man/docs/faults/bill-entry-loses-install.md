# One unreadable bill entry loses the whole install

**Problem.** `+apply-bill` reads every value in [`bill.json`](#desks.md) with
`so:dejs`, which crashes on anything but a string:

```live
/grubbery/gub/nex/desk.hoon 566-570
```

The crash takes the whole bill with it: no instance, no consent ask,
`manifest.json` at version 0, and no log line, because a crashed fiber rolls
its event back. From outside it looks like a clone still running.

**Proposed solution.** Skip the entries that are not strings, print each
skipped key, and install the rest.

**Status.** Open, [proposed](https://github.com/gwbtc/grubbery/pull/62).
