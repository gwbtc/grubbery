# Explorer

The namespace browser and editor, a service of the shell (`lib/shell/explorer`).

## Routes

- `/grubbery/ball[/<path>]` — the tree. A browser gets the pane workspace page;
  `?list=1` lists a directory, `?info=1` describes a file, `?raw=1` gives its
  bytes. POST creates, uploads, renames, deletes.
- `/grubbery/explorer` — the sessions page; `/grubbery/explorer/s/<name>` attaches
  a tab to a session.
- `/grubbery/explorer/sse` and `/follow` — one stream per page; the page says
  which roads it follows.
- `/grubbery/explorer/session` — list, create, delete, attach, ops, write-back.
- `/grubbery/explorer/term` — a terminal pane's dill session.

## Files, under the shell

- `explorer/sessions/<name>.json` — a gmux workspace the ship keeps: spec,
  version, the attached client, a queue of ops. One tab drives it; others mirror.
- `explorer/snaps/` — a tool writes `<id>.json {session, moment}`; the attached
  tab answers with `<id>.answer.json` then `<id>.png`.
- `ui/explorer/` — the page (`browse.html`, `browse.js`, `view.html`) and the kit
  it loads (`kit.js`, `cm.js`, `graph.js`, `hoon-grammar.json`).
- `ui/requests/<id>` — one request, served by `+serve-request`.

`@explorer` names `explorer/` under the shell.
