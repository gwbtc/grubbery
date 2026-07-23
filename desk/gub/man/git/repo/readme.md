# Git Repo

Clone a public git repo into the namespace. Config: repo, ref.

## Files

- `config.json` — Config: repo (owner/repo), ref (branch/tag/sha), token.
- `page.html` — Dashboard page. Shows config, sync button, file tree.
- `push.json` — Push request: {message, files: [{path, content}]}.

## Actions (`actions/`)

- `sync.sig` — Poke to fetch from remote.
- `switch.sig` — Poke to switch branch locally.
- `checkout.sig` — Poke with commit hash to checkout.
- `diff.sig` — Poke with commit hash to compute diff.
- `add.sig` — Stage files. Poke with json {all: true} or {paths: [...]}.
- `commit.sig` — Poke with commit message to create local commit.
- `branch.sig` — Poke with branch name to create at HEAD.
- `delete-branch.sig` — Poke with branch name to delete.
- `stash.sig` — Poke to stash dirty index and reset to HEAD.
- `stash-pop.sig` — Poke to pop the most recent stash.
- `push.sig` — Poke to push files to GitHub via REST API.
