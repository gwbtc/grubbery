# Git Repo

Clone a public git repo into the namespace and act on it. Config: repo, ref.

## Files

- `config.json` — repo (owner/repo), ref (branch/tag/sha), token, account.
- `run.git-action` — the serial command lane. Poke `{command: "<git command>"}`;
  it parses and runs one command at a time. Read it for the queue/active/log
  outcome. This is the single entry point for every git action.
- `poll.json` — self-configuring sync daemon. Holds `{minutes: N}` (0 = off);
  its own fiber pokes `pull` on that interval.
- `data/` — the git object store (packs, refs, HEAD, index) and checked-out tree.

## Commands (poke `run.git-action`)

Standard git, parsed by `lib/git/action`:

- `pull` — fetch from the remote and check out the tracked ref.
- `push` — push local commits to the remote via the GitHub proxy.
- `add [path ...]` — stage changes (no paths = all).
- `commit -m "msg"` — create a local commit from the staged tree.
- `checkout <branch|commit>` — switch to a branch (attached) or a commit (detached).
- `branch <name>` / `branch -d <name>` — create / delete a local branch.
- `stash` / `stash pop` — stash the working tree / restore it.
