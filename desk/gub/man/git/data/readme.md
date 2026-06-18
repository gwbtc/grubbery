# Git Data

Git object store. Stores pack, index, refs. Checkout via reload.

## Files

- `HEAD` — Git HEAD: "ref: refs/heads/<branch>" or raw commit hash (detached).
- `stash-request.sig` — Poke to stash dirty index and reset to HEAD.
- `stash-pop-request.sig` — Poke to pop the most recent stash.
