# S3 Bridge

Bidirectional S3 sync. Pull from and push to S3 buckets.

## Files

- `creds.json` — S3 credentials (access_key, secret_key, region, bucket, endpoint).
- `source.json` — S3 key for remote mapping source. Empty string = disabled.
- `mapping.json` — Bridge definitions: id, s3-prefix, local-path.
- `log.json` — Operation log: [{time, level, message}...], newest first, max 50.
- `browse.json` — Cached S3 bucket listing with fetch timestamp.
- `main.sig` — Poke with JSON {action} to pull/sync/unsync/add/delete/browse.
- `page.html` — S3 bridge control panel.
