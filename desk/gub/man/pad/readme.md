# pad

Cross-ship collaborative text pads: an owner-authoritative CRDT relay
living entirely in the namespace.

A pad is a directory of opaque Yjs update blobs (base64 cords). The
owning ship's inbox fiber is the single sequencing authority — every
editor, local or remote, pokes it and each accepted update lands as a
fresh log grub in arrival order. Remote editors hold a live local
mirror of the owner's log by remote subscription, so their browsers
only ever talk to their own ship. All CRDT merging happens in Yjs in
the browser; the ship side never inspects blob contents.

Reads ride the built-in keep SSE API (`/grubbery/api/keep/...`): its
`old` events replay the whole log on connect, which doubles as initial
state and reconnect recovery, since reapplying a Yjs update is a
no-op.

## Files

- `main.sig` — registers /public grants, binds `/grubbery/pad`, dispatches HTTP
- `docs/<doc>/inbox.sig` — the sequencer: pokes in, log grubs out
- `mirror/<host>/<doc>/sync.sig` — remote subscription driving the local mirror
- `index.html`, `pad.js`, `icon.svg`, `tile.json` — web client assets

## Directories

- `docs/<doc>/log/` — the doc's update log, one blob per grub, named by arrival time
- `mirror/<host>/<doc>/log/` — local copy of a remote doc's log
- `requests/` — transient per-HTTP-request fibers
