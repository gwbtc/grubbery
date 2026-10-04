# Re-culling an already-culled spur crashes the event

**Problem.** `+farm-top` resolves a spur's top case with a `%gt`/`%gw` pair:

```live
/grubbery/app/grubbery.hoon 7627-7652
```

Gall keeps an emptied plot after a full cull, so `%gt` still lists a spur that
`%gw` crashes on, and a `.^` crash cannot be caught inside the event. One
re-cull of a culled spur answers the request with a 500 and a trace that
contains no caller code. Apps were asked to keep their own count of what they
had grown, a second record of one truth with no way to reconcile the two.

**Proposed solution.** `$scry-state` gains a `farm` map from spur to top case,
written by `+handle-scry-grow` and cleared on cull. `+farm-top` reads it
instead of scrying gall.

**Status.** Open, [proposed](https://github.com/gwbtc/grubbery/pull/58).
