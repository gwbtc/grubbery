# GitHub Nexus

Local structured proxy for all GitHub traffic. Consumers (git repos,
forge, tools) talk to this nexus instead of the internet: the token
lives here once, client etiquette (auth, redirects) is handled once,
and a consumer's weir needs only this nexus.

## Files

- `config.json` — `{token, api}`. The one GitHub credential on the ship.
- `main.sig` — poke to create a call.

## Directories

- `calls/` — REST call lifecycle grubs (json). Keep `calls/[id].json`,
  poke `main.sig` with `{id, req: {method, path, body?}}`, read the
  result on news: `{status: done, code, body}`.
- `xfer/` — git smart-HTTP transport lifecycle grubs (noun). Poke
  `[%xfer id req]` where req is `[%discovery repo]` or
  `[%pack repo body]`; the grub goes `[%pending req]` →
  `[%done octs]` / `[%fail tang]`. Auth rides along when a token is
  configured, which is what makes private-repo clone possible.
