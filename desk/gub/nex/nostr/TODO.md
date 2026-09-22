# nostr nexus — the road to a full client

Status as of 2026-09-22. Everything is a grub under `/apps/nostr`; the
page is a reader over those grubs. Loose inspiration: nostrill, the
gall-agent nostr client this nexus grew out of; its
`lib/nostrill/relay.hoon`, `posts.hoon` and `lib/nostr/*.hoon` are the
reference for how the protocol is actually handled. We port ideas into
grubbery's shape: one fiber per socket, one grub per thing, derivations
as sibling index grubs.

**No algorithm here.** This nexus holds the record — events, profiles,
follows, relays, and indexes that are plain facts about them (which
replies belong to which root, who reacted to what) — and shows it in
time order. Ranking, scoring, filtering, "popular", topic feeds: those
are other nexuses reading these grubs (ghostprompter already is one).
The feed stays barebones on purpose; the richness is in rendering
what is there: threads, replies, reactions, media, mentions, and easy
basic discovery of people and relays.

## Done

- [x] `/sys/iris/ws.ws-state`: websocket service, keyed sockets
      (`[owner key]`, same-key replace like behn), runtime-neutral.
- [x] Relay clients: `relays/<host>.sig` + `.json` status; REQ from the
      newest indexed event; kind-0 profiles since the previous session;
      reconnect with backoff; 30s handshake timeout; manual
      Connect / Reconnect / Disconnect / Remove; raw frame sender; frame log.
- [x] Storage: `events/<id>.json` (verbatim, immutable),
      `profiles/<pk>.json`, `feed.json` index, `follows.json`,
      `config.json`, `defaults.json` (shipped starting points + reset).
- [x] Identity: `me/identity.json`, `me/secret.json`, `me/profile.json`;
      `lib/nostr.hoon` (keys, id, schnorr sign/verify, npub/nsec).
- [x] Publishing path: `outbox/<id>.json` with per-relay OK verdicts;
      kind 0 (profile) and kind 1 (post) from the page.
- [x] Page: Feed, People, Relays, Profile, Posts; spinners; explanations.
- [x] ghostprompter reads the mirror (flow, get_feed, references).

## Verify first

- [ ] Generate a key on the page, save a profile, publish a post; confirm
      the outbox shows an `OK` from each relay and the post appears on a
      public client (e.g. njump.me/<id>). Nothing below matters until
      this round-trips.
- [ ] `check-event` on inbound events (id recomputes, sig verifies):
      decide whether to drop bad events or flag them. nostrill trusts
      the relay; we can do better cheaply.

## Threads, replies, reactions (NIP-10, 18, 25, 27)

- [ ] Ask for more kinds: 6 (repost), 7 (reaction), and kind-1 replies
      *to* our follows' posts (`#p` / `#e` filters), not only their
      authored posts.
- [ ] `refs/<root-id>.json`: a derived index written on every event
      write — replies, reposts, reactions grouped by the root `e` tag.
      Sibling grub, rebuildable from `events/`, never inline state.
- [ ] Feed cards show reply / repost / reaction counts from `refs/`.
- [ ] Thread view: click a post → root, parents, replies as a tree;
      subscribe `#e = root` on open so the thread fills live.
- [ ] Reply from the page: publish kind 1 with NIP-10 `e` (root, reply)
      and `p` tags. React: kind 7 (`+`, emoji) with `e` + `p`. Repost:
      kind 6 with the event embedded. Quote: `q` tag + `nostr:` URI.
- [ ] Render `nostr:npub…` / `nostr:note…` mentions in content as
      links to the profile / post (NIP-27); bech32 decode in
      `lib/nostr.hoon`.

## People and discovery (NIP-02, 05, 50, 65)

- [ ] Our contact list: publish `follows.json` as kind 3 when it
      changes; read our own kind 3 back on a fresh ship (the follow list
      then round-trips through relays, and other clients see it).
- [ ] NIP-05 lookup: `name@domain` → `/.well-known/nostr.json` → pubkey,
      as a way to follow someone by handle. One HTTP fetch via /sys/iris.
- [ ] NIP-05 for us: serve `/.well-known/nostr.json` from the ship (an
      eyre binding), so `you@your-ship-domain` verifies.
- [ ] Follow graph: fetch kind 3 of our follows; "followed by N of the
      people you follow" on a profile; suggestions from overlap.
- [ ] Search: a search box that sends a NIP-50 `search` REQ to a search
      relay (relay.nostr.band) and lists results — profiles and posts.
- [ ] Relay lists (NIP-65, kind 10002): read a person's write relays and
      ask there; publish ours. The "outbox model" — the main reason a
      client sees posts a two-relay client misses.
- [ ] People tab: open a person → their profile in full, their recent
      posts (a per-author REQ on demand), follow/unfollow, their relays.
- [ ] Accept `npub…` in the follow box (bech32 decode), not only hex.

## Profile and media

- [ ] Picture as a grub: a mime grub under `me/` served at a public URL,
      or uploaded to a Blossom server (signed auth event; we can sign).
      The kind-0 field stays a URL either way.
- [ ] More kind-0 fields: `display_name`, `banner`, `website`, `nip05`,
      `lud16`, `bot`. Render them on People and Profile.
- [ ] Posting media: upload to Blossom / NIP-96, insert the URL.
- [ ] Render images/video in posts (the ghostprompter media rules).

## Reading better

- [ ] Backfill on demand: "older posts" pages back with `until` REQs
      instead of the fixed 30-day window.
- [ ] Per-author timelines (a per-author REQ on demand, shown in order).
- [ ] Notifications: things that `#p`-tag us (replies, mentions,
      reactions) into the notifications nexus.
- [ ] Mute list (kind 10000) honored in the feed.
- [ ] DMs (NIP-17 gift-wrapped, or NIP-04 legacy) — read and send.
      Needs ECDH; last, and only if wanted.

## From nostrill, still ahead of us

- Urbit identity ↔ nostr key mapping (its `gwid` / `patp` scries):
  a ship publishing which nostr key is its own, and vice versa. Fits
  `peers` / the shell's identity story, not this nexus alone.
- nostrill was also a websocket *server* (other clients connected to
  it). Out of scope until eyre-side websockets are a service.
- Its "popular" feed = reactions + reposts counted. Not for this nexus
  (no ranking here); a separate nexus can derive it from `refs/`.

## Performance (the ship, not nostr)

- Every HTTP request through grubbery costs ~110ms before any work
  (request grub create + spawn + cull). Serve static files straight
  from the dispatcher; make lifecycle grubs cheaper. Feed/people
  endpoints add one dart per item on top; batch peeks.
- Profiling hooks (`%bout` on http, wakes, frames) are in
  `app/grubbery.hoon`, labelled "kept for now".
