# Code Build System

## Overview

Replace the build nexus with a build pipeline baked into `app/grubbery.hoon`,
similar to how Clay sync already works. The namespace under `/sys/code/` holds
both source and compiled output. Build state (keys, deps) may live in app state
rather than the namespace.

## Namespace

```
/sys/code/
  src/
    mar/    marks
    nex/    nexuses
    lib/    libraries
  bin/
    mar/    compiled marks
    nex/    compiled nexuses
    lib/    compiled libraries
```

## Bootstrap

One hardcoded mark: `%hoon`. Everything else is compiled from source using the
in-namespace marks and libs.

## Build triggers

- Any change to anything under `/sys/code/src/` triggers a rebuild of affected
  `bin/` entries.
- Any direct change to `/bin/` should also be reacted to — keep bin/ consistent
  with src/ (overwrite back, or at minimum re-validate).

## Clay sync

The Clay desk has `/gub/mar/`, `/gub/nex/`, `/gub/lib/`. On any Clay change:

1. Copy changed files into the corresponding `/sys/code/src/` directory,
   overwriting what's there.
2. Rebuild.
3. If compilation crashes (produces a tang), **crash the event**. No silent
   failures.

Users can also write directly to `src/` — it's not Clay-only. Clay is just one
input that feeds the pipeline.

## Runtime

Marks, nexuses, and libs are read from `bin/`, never from Clay directly.

## Tubes and daises

Probably just libs that explicitly expose a `+build-tube` or similar arm.
Exact mechanism TBD, but the idea is they aren't a separate category — they're
compiled code with a known interface.

## Open questions

- Exact key/dep storage: app state vs namespace files
- Tube/dais convention details
- Incremental rebuild strategy (dep graph tracking)
- What "react to bin/ changes" means precisely (reject? recompile from src?)
