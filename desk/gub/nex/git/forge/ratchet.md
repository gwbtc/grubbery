# The Ratchet — developing grubbery from inside grubbery

The goal: the ship is where grubbery is made. Source lives in a forge
repo instance in the namespace, edits happen in the namespace, deploys
go namespace → Clay, and commits/pushes to GitHub leave from the ship.
The laptop checkout becomes a mirror and a recovery hatch, not the
source of truth.

## The loop

1. **Hold the source in-ship** — a forge repo instance
   (`/repos/grubbery.git_repo`) cloned from `gwbtc/grubbery` through
   the github proxy (`/apps/github.github`, OAuth device flow).
2. **Edit in the namespace** — forge's working-tree editor
   (`POST /api/src`), explorer, or MCP `edit_file` into
   `/repos/grubbery.git_repo/data/tree/...`.
3. **Deploy namespace → Clay** — a desk syncer (shell `create_desk`)
   pointed at the repo's `desk/` subtree, targeting a STAGING desk
   first, `%grubbery` once trusted. The clay-mime boundary flow was
   verified end-to-end on ahoy (2026-09-08).
4. **Verify** — `check_bin` against the rebuilt code namespace, same
   as today.
5. **Commit + push from the ship** — the repo's serial command lane
   (`run.git-action`: `add`, `commit -m`, `push`). Namespace-to-GitHub
   push is landed and verified (the contacts dark-mode commit was the
   maiden voyage).

## Status of the legs

| leg | state |
| --- | --- |
| clone/pull via github proxy | verified |
| in-namespace editing (forge editor) | working, spartan (CM5 editor is the planned upgrade) |
| namespace → Clay desk deploy | verified e2e (forge flow, ahoy) |
| commit from the ship | working (known bug: empty commit when no changes) |
| push from the ship | **blocked**: push wedges forever on a non-%finished iris response — fix is %fail on crash-restart, NOT a timeout |

## Hazards

- **The self-hosting cliff.** Once the kernel that runs the editor is
  compiled from files edited inside it, a bad commit can brick the
  tool you would use to fix it. Mitigations, all mandatory:
  - develop on the dev ship (zod), never the live ship;
  - deploy to a staging desk before `%grubbery`;
  - keep the Unix mount + dojo `|commit` alive as the recovery hatch —
    the laptop checkout stays cloned forever.
- **Weir lockout class** — `/apps` must stay open (see the recovery
  ladder in the apps-weir-lockout postmortem). Same lesson, same
  ladder.

## Rollout order

1. Fix the push-hang bug (`%fail` on crash-restart).
2. Dry-run the full loop on a leaf repo (contacts or wallet):
   edit → deploy → check → commit → push, all in-ship.
3. Clone `gwbtc/grubbery` as a forge repo (stock card on the landing
   page), wire a desk syncer at `desk/` → staging desk.
4. Promote: staging desk → `%grubbery`, retire sync.sh, laptop becomes
   mirror.
5. Quality of life: CM5 editor, no-changes commit fix.
