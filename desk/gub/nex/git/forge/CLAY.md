# Clay desk workflow

Tools for going from a git repo to a running Clay desk. Always in this order:

1. **`new_desk`** — create the desk with minimum viable files (marks, kelvin,
   skeleton agent from %base). Required before any writes.
2. **`deploy_to_desk`** — walk a grubbery directory tree (e.g. a repo's
   `/data/tree/desk/`), read every file as mime, diff against the target desk,
   and write inserts + deletes as one atomic Clay `%info`. File extensions
   become Clay marks (`foo.hoon` -> `/foo/hoon` -> mark `%hoon`).
3. **`install_app`** — set zest to `%live`, which triggers `goad` to read
   `desk.bill` and start the listed agents.

## Full forge flow

```
forge_create_repo name=ahoy remote=owner/repo
new_desk desk=ahoy
deploy_to_desk source=/apps/forge.git_forge/repos/ahoy.git_repo/data/tree/desk desk=ahoy
install_app desk=ahoy
```

## Single-file editing (patches, not full deploys)

- `insert_clay_file` — write/overwrite one file
- `edit_clay_file` — exact string replacement
- `batch_edit_clay` — atomic multi-file edits
- `delete_clay_file` — remove one file

## Inspection

- `list_clay_files` / `get_clay_file` — browse desk contents
- `desk_version` — current revision number
- `run_tests` — run test arms
