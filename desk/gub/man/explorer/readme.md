# Explorer Nexus

Web-based tarball file browser. Serves directory listings and file contents over HTTP with a full CRUD interface: create, delete, upload, rename, and symlink. Streams live directory changes via SSE so the browser updates without polling.

## Files

- `main.sig` — HTTP binding process. Registers `/grubbery/` with the server nexus.
- `ver.ud` — Schema version.

## Directories

- `requests/` — Per-request fibers for active HTTP connections.
