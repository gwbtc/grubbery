# Routine traces drown the warnings

**Problem.** Routine `~&` prints run unconditionally: ten per explorer request,
dozens in the agent and in the desk nexus per sync tick, progress lines in the
build and git code. The two veto prints dump the whole weir and filter every
time. A nexus peeking its own root directory, which is how a sandboxed fiber
[learns where it is](#weirs.md), is vetoed and announced on most requests; on
one ship that print was the entire console. The lines that mean something are
buried.

**Proposed solution.** A per-file `+dbg` constant, off by default, and every
routine trace as `~?` on it. Warnings stay unconditional. Veto prints name the
boundary, jump and destination on one line, and the own-root peek is vetoed
silently.

**Status.** Open, [proposed](https://github.com/gwbtc/grubbery/pull/79).
