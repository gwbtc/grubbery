# S3

The ship's one door to S3-compatible buckets, in the proxy shape
(see openrouter, github). Apps never hold the credentials or reach the
internet: they poke a call, read its result, and the op is logged to
its caller.

## Files

- `config.json` — `{buckets: {name: {access-key, secret-key, region,
  bucket, endpoint}}}`. `name` is the local label every op and mount
  refers to.
- `mounts.json` — `{bucket: [path, ...]}`: which paths of which bucket
  are mirrored. A path is a folder (`a/b/`, `` for the whole bucket) or
  one key (`a/b.txt`).
- `activity.json` — caller-attributed op log (last 500) and a request
  count.
- `main.sig` — poke `{id, body}` to create a call.
- `web.sig` — the UI at `/grubbery/s3`.

## Directories

- `mounts/<bucket>/<path>` — the local mirror of a mounted path. Pulls
  land here; pushes read from here.
- `calls/<id>.json` — one per op: `{status, request, from}` then
  `{status: done, response}`. The consumer culls it.
- `tools/` — this nexus's MCP tools (`s3_list`, `s3_download`,
  `s3_upload`, `s3_delete`). Call them by naming this nexus in `path`.

## Ops

The `body` of a call is `{op, ...}`, every op naming a bucket:

| op       | args                | response           |
|----------|---------------------|--------------------|
| `list`   | `bucket`, `prefix?` | `{keys, count}`    |
| `delete` | `bucket`, `key`     | `{key, ok, code}`  |
| `pull`   | `bucket`, `path`    | `{pulled, failed}` |
| `push`   | `bucket`, `path`    | `{pushed, failed}` |

`pull` and `push` take a path inside one of the bucket's mounts: a file
moves one object, a folder moves everything under it.

A failure is `{error}` in the response; the call still reads `done`.

## Known limits

Payloads are signed and sent as text with a fixed `text/plain`
content-type, so binary objects do not round-trip yet.
