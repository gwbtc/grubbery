# A neck-less /desk/code wedges an app forever

**Problem.** A `/desk/code` created as a plain directory never gets the
`[/ %code]` [neck](#build-substrate.md). Files land with the right blots,
nothing compiles them, `+apply-bill` finds no built nexus, and the app never
rises. The desk page compares file trees, finds them identical, and reports
nothing to pull. `+sync-dir` preserves the destination's neck on purpose:

```live
/desk/gub/nex/desk.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 641-677
```

So a release cannot repair it. The instance that rose against the broken
directory keeps its bang, because `+apply-bill` only makes missing instances
and skips existing ones.

**Proposed solution.** On rise, re-fold the same contents under the right neck
when it is wrong; a no-op on a healthy desk. Add `+reload-soft` so the
instances the bill declares are restarted after the repair without one refusal
stranding the rest. Run the repair from `+sync-release` too, since a
subscriber does not rise on its own.

**Status.** Open, [proposed](https://github.com/gwbtc/grubbery/pull/73).
