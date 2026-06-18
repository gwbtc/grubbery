# Rhizome Nexus

Wiki-linked markdown notes with backlink tracking. Store markdown notes in `/vault/` with `[[wiki links]]`. The system automatically parses links and maintains a `/metadata/` directory with forward links (links-to) and backlinks (linked-from) for each note. Page at `page.html` renders the full index.

## Files

- `main.sig` — Vault watcher. Parses `[[wiki links]]`, syncs metadata.
- `page.html` — Rendered note index with backlinks (manx).

## Directories

- `vault/` — Markdown notes. Create `.md` files here.
- `metadata/` — Auto-generated backlink metadata (JSON).
