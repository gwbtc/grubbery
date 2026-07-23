# S3

S3-compatible object storage. Pull/push between S3 and the ball namespace.

## Files

- `config.json` — S3 credentials: access-key, secret-key, region, bucket, endpoint.
- `main.json` — Poke with JSON `{op, ...}` to run S3 operations.
- `mounts.json` — Map of mount name to S3 prefix.
- `page.html` — S3 control panel.

## Directories

- `mounts/` — Mount directories, each synced to an S3 prefix.
