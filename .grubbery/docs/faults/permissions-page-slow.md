# The permissions page answers only after it has done all its work

**Problem.** [`GET /permits`](#permissions.md) runs a follower sweep and a share
rebuild before serving a static file, and `POST /permits` runs three cache
rebuilds, a round trip per app each, before answering:

```live
/desk/gub/nex/shell.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 455-466
```

The page takes ten to twenty seconds to appear and goes dead for seven after
every click, growing with the number of apps. Moving the work after
`send-simple` in the same fiber does not help, because the response is not
released until the request fiber finishes.

**Proposed solution.** GET serves the file and POST applies the action,
nothing else. A new `POST /permits/refresh` does the sweep and the rebuilds.
The page calls it in the background after render and after each action, and
reloads its data when it answers.

**Status.** Open, [proposed](https://github.com/gwbtc/grubbery/pull/66).
