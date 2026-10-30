# Git Data

Git object store. Stores packs, loose objects, the index, refs and HEAD, and
materializes the working tree under `tree/`. Checkout via reload.

## Files

- `HEAD` — Git HEAD: "ref: refs/heads/<branch>" or raw commit hash (detached).
- `requests.json` — the request log: `{pending: [{id, kind, ...}], done: [{id, kind, ok, message, paths}]}`.
  The repo nexus appends a request and reloads this nexus; every pending request runs
  in order in that load and its outcome is recorded under its id. Kinds: `checkout`
  `{head, force}`, `add` `{all}` or `{paths}`, `commit` `{message, author_name,
  author_email, date, paths}`, `stash`, `stash-pop`, `stash-drop`.
- `INDEX` — the staging index, one `mode hash mtime<tab>path` line per entry.
- `tree/` — the working tree. The one part anyone may write; the watcher reloads on changes.
- `ui/` — derived views (`status.json`, `commits.json`, `branches.json`, `current.json`,
  `stash.json`), rebuilt on every reload, never authoritative.