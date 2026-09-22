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

- [x] Ask for more kinds: 6 (repost), 7 (reaction), and anything
      `#p`-tagging a follow (replies to them, reactions to their posts).
- [x] `refs/<id>.json`: replies under the thread root (with parent),
      reposts and reactions under their target. One fact per event,
      deduped across relays, rebuildable from `events/`.
- [x] Feed cards show reply / repost / reaction counts from `refs/`,
      and a "replying in a thread" line on replies.
- [x] Thread view: root and replies as an indented tree; who reacted
      and reposted, named; "Fetch from relays" sends a one-shot
      `#e`/`#q` REQ on every socket (closed on its EOSE).
- [x] Reply (NIP-10 `e` root/reply + `p` tags) and react (kind 7 `+`)
      from the page. UNVERIFIED end to end until a key exists.
- [x] React with any emoji: an existing chip reacts the same way, the
      React picker offers a dozen plus free text; 👥 lists who.
- [ ] Custom emoji reactions (NIP-30 `:shortcode:` with an `emoji` tag
      carrying the image url); the picker sends any string already.
- [ ] Mark our own reactions on the chips, and un-react (a kind-5
      deletion of our kind-7). Needs our pubkey in the refs rows check.
- [x] Reposts: a follow's kind 6 is a feed item shown as the original
      post with a "reposted by" line (the embedded original is filed as
      its own event grub); Repost from the page publishes a kind 6 with
      the original verbatim in its content.
- [ ] Verify the embedded original in a kind 6 (`check-event`) before
      filing it; today a bad embed becomes a bad event grub.
- [x] A mentioned post (`nostr:note…` / `nevent…`) renders inline as a
      compact quoted card, or a gap with Fetch when not held; `q`-tag
      targets join discovery.
- [ ] Quote (`q` tag + `nostr:` URI) from the page.
- [x] When we hold replies but not their root, the thread says so
      loudly and Fetch asks for the root by id as well as for what
      points at it.
- [ ] Backfill references for the posts already indexed (one `#e` REQ
      over feed.json's ids per relay at session start), so counts on
      older cards are not zero because we never asked.
- [ ] Say where a count came from: "seen on 2 relays", never a total.
- [ ] Relay hint in our `e` tags (nostrill includes the relay url).
- [x] `nostr:npub…` / `nprofile…` / `note…` / `nevent…` in content
      decoded (bech32 + TLV, client side) and rendered as links that
      open the person or the thread; names filled in when known.

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
- [x] A person view from any name, avatar or mention: full profile,
      follow/unfollow, the posts we hold (`authors/<pk>.json`), and
      "Fetch from relays" (their kind-0 + 40 latest posts, one-shot).
- [ ] Their relays (NIP-65) on the person view.
- [ ] Accept `npub…` in the follow box (bech32 decode), not only hex.
- [x] Hashtags: `tags/<t>.json` indexes every held kind-1 by its `t`
      tags and by #words in its text (many clients set no `t` tag);
      "Rebuild index" walks events/ (the index began after them); a tag opens a view of those posts with "Fetch from relays"
      (a one-shot `#t` REQ, anyone's posts). Plain ascii tags only get
      a grub; unicode tags render as links but have no index yet.

## Profile and media

- [ ] Picture as a grub: a mime grub under `me/` served at a public URL,
      or uploaded to a Blossom server (signed auth event; we can sign).
      The kind-0 field stays a URL either way.
- [ ] More kind-0 fields: `display_name`, `banner`, `website`, `nip05`,
      `lud16`, `bot`. Render them on People and Profile.
- [ ] Posting media: upload to Blossom / NIP-96, insert the URL.
- [x] Render images/video in posts (the ghostprompter media rules, now
      shared in `lib/ui/post-text.js`).

## Reading better

- [x] Discovery as events arrive: an unknown author's profile is asked
      for (a kind-0 query, not a follow), a reply's missing root is
      asked for by id with what points at it; "Fill in unknowns" asks
      for everything still missing at once (authors/ minus profiles/,
      refs/ minus events/).
- [ ] Backfill on demand: "older posts" pages back with `until` REQs
      instead of the fixed 30-day window.
- [ ] Per-author timelines (a per-author REQ on demand, shown in order).
- [ ] Notifications: things that `#p`-tag us (replies, mentions,
      reactions) into the notifications nexus.
- [ ] Mute list (kind 10000): people and threads you don't want to see,
      honored in the feed and threads. Display-side only: on nostr
      nobody can stop anyone from replying; the most a client does is
      not show it. No reply policies, no permissions, no layer on top.
- [ ] DMs (NIP-17 gift-wrapped, or NIP-04 legacy) — read and send.
      Needs ECDH; last, and only if wanted.

## From nostrill, still ahead of us

- Urbit identity ↔ nostr key: nostrill binds them tightly (its `gwid`
  / `patp` scries derive one from the other). Ours should be looser:
  a ship may *claim* a nostr key (publish "this npub is mine" where
  the ship's peers can read it), and a nostr profile may *point at* a
  ship (a `urbit` field in the kind-0, or a NIP-05 handle at the
  ship's domain). Claims are facts other ships can check both ways;
  nothing is derived, nothing is forced, one ship may claim several
  keys and a key may name no ship. Fits `peers` / the shell's identity
  story with this nexus holding the nostr side.
- nostrill was also a websocket *server* (other clients connected to
  it). Out of scope until eyre-side websockets are a service.
- Its "popular" feed = reactions + reposts counted. Not for this nexus
  (no ranking here); a separate nexus can derive it from `refs/`.

## The page as components

The kit in `/lib/ui` (tab-group, modal-dialog, split-view, card-deck,
file-manager…) is the house way: shadow DOM, attributes in, slots for
content, CSS variables for theme, bubbling events out, welded into one
`ui/components.js` per nexus in on-load (ghostprompter is the model).
This page started as one app.js hand-building every element; it moves
onto the kit piece by piece, and what it grows goes back into the kit
for other social-ish nexuses (feeds, chat, guestbook).

- [x] `<avatar-pic>`: picture, else initial on a seed-derived color.
- [x] `<post-card>`: header, content slot, the standard action row
      (💬 replies opens the thread, 🔁 and one chip per reaction emoji
      open who, Reply / React on the right), a who slot; events
      `pc-open`, `pc-person`, `pc-reply`, `pc-react`, `pc-who`.
- [ ] `<person-row>` for the People tab and who-lists (avatar, names,
      nip05, an actions slot).
- [ ] `<relay-chip>` / relay card with the stage dot.
- [ ] `<kv-list>` for the identity / relay / person key-value blocks.
- [ ] Thread view as a component over a list of posts + a parent map
      (the indent-by-parent walk is generic to any threaded thing).
- [x] Rendered text (urls, `nostr:` mentions, media as attachments) as
      `lib/ui/post-text.js` (`PostText`), which ghostprompter and this
      page both call, so posts render the same everywhere.

## Performance (the ship, not nostr)

- Every HTTP request through grubbery costs ~110ms before any work
  (request grub create + spawn + cull). Serve static files straight
  from the dispatcher; make lifecycle grubs cheaper. Feed/people
  endpoints add one dart per item on top; batch peeks.
- Profiling hooks (`%bout` on http, wakes, frames) are in
  `app/grubbery.hoon`, labelled "kept for now".
