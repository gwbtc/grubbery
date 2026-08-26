# git nexus — TODO

Backlog for the forge + git/repo/data nexuses. Lives with the code so it
travels with the nexus and stays in history. Checked items ship; the rest is
ordered roughly by fruit-to-effort.

## Stash — make the visible stack actionable
- [ ] Apply / pop / drop a **specific** entry — `stash pop 2`, `stash apply 2`,
      `stash drop 2` (index into the stack). The pop machinery exists; add an
      index parameter and target that reflog entry instead of the top.
      Note: our "apply" is a straight checkout of the stash tree (overwrite),
      not git's 3-way merge — fine when applying onto the same base.
- [ ] Take a **single file** out of a stash — read the path's blob from the
      stash commit's tree → working tree (`git checkout stash@{n} -- <file>`).
      A stash is just a commit, so the blob's already in the object store.
- [ ] `stash show` — diff of what a stash contains (rides on the diff view).
- [ ] Wire the UI stash rows to these actions (click a stash to apply/drop).

## Diff view — the high-leverage primitive
- [ ] Re-add `diff` as a **read endpoint** (NOT a lane verb — it's a query that
      mutates nothing). The diff-viewer JS (commit browser + `viewCommitDiff`)
      is preserved in git history / grubbery version 1.269.
- [ ] Per-file diff view; also powers `stash show`.

## Branch visualization — the signature git-GUI feature
- [ ] Commit-graph / lane view (gitk / GitKraken / VS Code "Git Graph" style).
      Data's already emitted: `commits.json` carries each commit's parents,
      `branches.json` + refs give the heads. Pure front-end: lane assignment
      (pack commits into columns so edges don't cross) + SVG render. Start
      linear-with-labels (`git log --graph` lite), grow to full merge routing.

## Cleanup
- [ ] Sweep stale `poll` / `token` fields from existing repo configs (ignored
      now, but tidy — `poll` moved to poll.json, `token` removed entirely).

## Identity / config
- [ ] Forge-level default → genuinely **ship-wide** identity store, if a second
      git consumer ever appears (currently forge stamps per-repo on create).
- [ ] Commit signing (gpgsig), non-UTC author/committer timezone,
      committer ≠ author — only once rebase / applied-patch flows exist.

## git-convention debt (NON-STD internal formats — see data.hoon header)
The wire (packs, refs, objects) is real git; these on-disk encodings are
Hoon-side conveniences that never leave the ship. Move toward git's real
formats over time:
- [ ] INDEX: custom `"mode hash\tpath"` text → git's binary index
- [ ] packs/*.idx: custom `"hex-hash offset"` sidecar → git's real fanout .idx
- [ ] reflog: custom `"old new msg"` line → git's real reflog line (committer + ts)

## import
- [ ] Bundle import was dead and removed; rebuild properly if ever wanted
      (binary bundle payload doesn't fit the text lane — needs its own path).

## Whenever
- [ ] `git push` the desk to the remote.

---

## Done (recent)
- Consolidated every git action into one serial lane at `/run.git-action`
- Stash captures the full working tree; pop restores unstaged (git default)
- `stash list` verb + status explorer (HEAD position, staged/unstaged, stash stack)
- Commit identity (author name/email; commit refuses without it, like git)
- Account genuine-none (push refuses instead of borrowing the first account)
- Root-level ⚙ defaults editor (forge-level identity, stamped into new repos)
- `poll.sig` → `poll.json` self-configuring daemon
- Dropped the legacy `page.html` UI + ~750 lines of dead code; removed the
  vestigial per-repo token; surfaced `/README.md`; documented the reload-recompute
  model + the wire-vs-internal git-format boundary
