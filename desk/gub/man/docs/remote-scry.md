# Remote scry

A nexus can publish content into a namespace that *other ships* read directly
over the network — no subscription, no running agent on the far side, just a
signed read: the content itself proves who published it. It can also read
another ship's published content the same way.
That two-way primitive is **remote scry**, and the local store a ship publishes
into is its **farm**. It's how one ship hands data to another without
either one holding a live connection open.

Everything here runs through one kernel service, `/sys/scry`.

## Remote scry in the Urbit kernel

`gall` writes this ship's farm; `ames` reads other ships'.

### Data types

A published thing lives at a **spur** — a path — versioned by a **case**, and the
value bound there is a **page**. Everything a ship has published sits in its **farm**.

A **spur** is a `path` — the `/`-separated name a page is bound at:

```live
/base/sys/hoon.hoon 13782
```

A **page** is a `cask`: a mark paired with its noun.

```live
/base/sys/arvo.hoon 56
```

A **case** names a version — a date (`%da`), a label (`%tas`), a rising sequence
number (`%ud`), or a content hash (`%uv`):

```live
/base/sys/arvo.hoon 38-48
```

Remote scry always uses the `%ud` sequence: a case is a plain integer, counting
up from 1.

A **plot** is everything bound at one spur: its revision history and a **tip**
marking the latest. `fan` is the history — an ordered map from each case to the
value at that version (`&` a live page, `|` a tombstone hash). `bob` is the tip,
the latest revision number.

```live
/base/sys/lull.hoon 3696-3700
```

A **farm** is a ship's whole published store — every spur's plot, held as a tree
you index by the spur's path.

> [!background] Not needed for grubbery remote scry
>
> The two-node shape below is `gall`'s own storage machinery; grubbery's `grow`,
> `tomb`, and `cull` never leave a single spur's plot. Skip the rest of this
> section unless you're curious.

Two kinds of node, split on what they hold beneath them:

- A **`%plot` node** is the recursive branch: `q` maps the next knot to a
  sub-farm, so walking a spur descends knot by knot; `p` optionally holds a
  `plot`, for a spur that ends right here. Mind the collision — the `%plot`
  *node* is not the `+$plot` *type*; it's the branch cell, and only *may carry* a
  plot.
- A **`%coop` node** is terminal: it stops branching and holds a flat map of
  path → `plot`, all sharing one revision (`hutch`) — how a bundle of paths
  published together is versioned as a unit.

```live
/base/sys/lull.hoon 3706-3713
```

### Writing to the namespace

Three verbs move pages through the farm, all `gall`'s, each a direct consequence of
the shapes above:

- **grow** publishes a page at a spur, as a new case.
- **tomb** hollows out one case — keeps the binding, drops the content for a hash.
- **cull** retracts a spur, deleting its cases up to a chosen version.

**grow** — `[spur now=@da page]` → a new `farm`; pure. It adds an entry to the
spur's plot `fan` at the next case number — the highest present + 1, or `1` for a
fresh spur — never overwriting, and the tip (`bob`) records that number so a later
cull can't reopen it. The wrapper `ap-grow` writes the returned farm into the
agent's published state (`sky.yoke`). It emits no **cards** — the effects an agent
hands to arvo (network sends, timers, pokes to others) — so that state write is
the whole of what happens. (In the arm, `las` is the highest existing entry and
its `key` the case number.)

```live
/base/sys/lull.hoon 4019-4027
```

And `ap-grow`, the `gall` wrapper that calls it and writes the new farm back into
`sky.yoke`:

```live
/base/sys/vane/gall.hoon 1447-1456
```

**tomb** — `[case spur]` → the agent core, mutating its published state
(`sky.yoke`). It swaps the case's page for a fingerprint of the old content
(`(shax (jam …))` — serialized, then hashed), so the case still resolves, now to a
tombstone; the binding stays. A missing or already-hollowed case no-ops with a
debug trace. No cards — the state edit is the whole effect.

```live
/base/sys/vane/gall.hoon 1459-1483
```

**cull** — `[case spur]` → the agent core, mutating `sky.yoke`. It deletes every
case up to and including the one named, but only if that case lies within the
spur's **live range** — between its lowest still-bound case and its tip; naming one
outside that range no-ops (with a trace). It records a high-water mark — the case
it culled to — so those numbers can't be re-bound. Because of the range-check,
clearing a spur means culling at its current top case: name the wrong number and
nothing happens. No cards.

```live
/base/sys/vane/gall.hoon 1489-1512
```

### Reading from the namespace

The two read verbs bottom out in `ames` tasks — the kernel's remote-scry interface.
A `%keen` requests a page at a `spar`; a `%yawn` cancels one still in flight.
`%chum` is a `%keen` encrypted to a known peer — a private read over a shared key,
where `%keen` is public — and `%wham` is the blunt cancel: it drops *every* request
at a spar, where `%yawn` drops only the caller's.

```live
/base/sys/lull.hoon 895-898
```

A `spar` is the read's address — the ship to read from, and the path under it:

```live
/base/sys/lull.hoon 1055
```

`ames` routes a `%keen` to `on-keen`. For a known peer it records the outstanding
request in the peer's `tip` and sends the network request (encrypted through `sec`
when the page is shut); for a peer whose keys it doesn't yet hold, it parks the
request in an alien agenda until they resolve.

```live
/base/sys/vane/ames.hoon 5643-5677
```

A `%yawn` routes to `on-cancel-scry`. It finds the per-path listener state and
drops the caller's request — one path, or, with `all`, every listener at that
spar — handing each a null response and clearing it.

```live
/base/sys/vane/ames.hoon 5696-5741
```

### The signed read

A **signed read** is content that proves who published it. When a ship `grow`s a
page it signs the binding — the spur, the case, and the page's hash — with its
network key, so the page carries its own proof of origin.

Verifying it is `ames`'s, not ours: when a scry response arrives, `ames`
authenticates it before the page is handed up. A public response is checked against
the publisher's signature (the `%&` branch, `verify-sig`); one encrypted to a known
peer, against a shared-key MAC (the `%|` branch, `verify-mac`). Either way, a forged
or tampered page fails here and never reaches the caller.

```live
/base/sys/vane/ames.hoon 4351-4360
```

Because the proof rides with the page, the bytes can cross any relay or sit in any
cache and still arrive provably that ship's, unforged and unaltered, with no live
session. The page proves itself — which is exactly why remote scry needs no
connection.

## Remote scry in the grubbery kernel

Grubbery wraps those primitives in one weir-gated service — pokes to `/sys/scry` —
and the `fiberio` helpers nexuses call.

### How it's wired: the /sys/scry service

Everything here is an ordinary **poke** to the scry service — the grub at
`/sys/scry/main.sig` (`/sys/scry` is a directory, holding the service and its
`main.scry-state`). One tag per operation: `%scry-grow`, `%scry-tomb`,
`%scry-cull`, `%scry-keen`, `%scry-yawn`.

Access control is nothing special: like any poke, it's bounded by the sender's
[weir](#permissions.md). A grub may reach the service if its poke set contains any
road that covers the target — that exact grub, or a directory above it
(`/sys/scry/main.sig`, `/sys/scry/`, `/sys/`, or `/`). There's no gate in the
service itself.

It routes each tag to a handler and answers `%pack` immediately. `gall` consumes the
emitted `%grow`/`%tomb`/`%cull` card and answers nothing back, so a write is never
confirmed — the caller's `%pack` means its poke was consumed, not that the page
bound.

> [!note] Two warts in this service
>
> **Split state.** Every other `/sys` service is a single grub that both handles
> pokes and holds its state — `main.behn-state`, `main.clay-state`,
> `main.iris-state`, `main.server-state`. Scry alone splits in two: a `main.sig`
> fiber plus a `main.scry-state` grub it hand-reads and hand-writes
> (`get-scry-state`/`save-scry-state`). It should be one grub, like the rest.
>
> **The dispatch.** The handler below matches the mark with a chain of `?:`
> equalities rather than a `?+` switch on the tag — the switch is the tighter,
> idiomatic form.

```live
/grubbery/app/grubbery.hoon 6879-6904
```

### Writing to the namespace

Each write is one poke, and its handler is short: decode the payload, emit the
matching arvo card to gall. `handle-scry-grow` unpacks `[path page]` and passes a
`%grow`; `handle-scry-tomb` unpacks `[case path]` and passes a `%tomb`. A malformed
payload slogs and drops rather than crashing.

Cull is the one that has to work for its card. `gall` clears a spur only when culled
at its *exact* top case (`ap-cull` range-checks and no-ops on anything else), so
`handle-scry-cull` resolves that top with `farm-top` and culls there — and a spur
with nothing bound emits no card at all.

```live
/grubbery/app/grubbery.hoon 7553-7580
```

> [!note] A wart: these handlers don't act like a normal grub
>
> Each one takes a raw `vase` and hand-extracts it
> (`mole |.(!<([path page] …))`), re-declaring inline the shape its mark already
> defines and dropping a malformed poke with a slog. For a normal grub the kernel
> clams the poke against its mark before delivery, so the grub receives typed data
> — a system grub should get the same. The marks (`scry-grow`, `scry-tomb`, …)
> already exist, and these pokes are meant to be well-formed — a malformed one is a
> bug, not a case to swallow.

#### farm-top: finding a spur's top case

To cull correctly the kernel has to answer "what's the highest case bound at
this spur right now?" — and answering it from the namespace can crash the event.
`%gw` (read one spur's case) is a *partial* read: for a spur it
doesn't hold it answers `[~ ~]`, `+mink` turns that into a **crash**, and a
crashing `.^` can't be softened from inside the event (`+mute` hands the scry
back out to the real namespace, so the crash lands *outside* the simulation you'd
use to catch it). So `%gw` is only ever asked about a spur `%gt` has already
listed — and the trap is that `gall` keeps an *emptied* plot after a full cull, so
`%gt` still lists a spur `%gw` will crash on. The current arm carries that caveat
and pushes the burden onto callers: "gate re-culls on your own records."

```live
/grubbery/app/grubbery.hoon 7581-7624
```

> [!note] A known weakness
>
> This caveat makes every caller keep its own parallel count of what it grew — a
> second copy of one truth. One divergence and the next cull crashes the event,
> with a stack trace holding none of the caller's code. It also keeps the cull API
> narrow: `cull-farm` takes only a spur (full retraction), where `gall`'s `%cull`
> takes `[case spur]`, because the caller has no way to name a case — the farm's
> cases aren't exposed as a read.
>
> One possible solution: have the service keep its own record of what it grew.
> Then `farm-top` could be a lookup instead of the crash-prone `%gw`, a stale
> re-cull would leak an empty plot instead of crashing, and that record could be
> exposed as a read on `/sys/scry` — so `cull` could take a `case`, moving the
> resolution out of the write path.

### Reading from the namespace

A remote read can't be answered synchronously — the answer comes back over the
network later, as a `%keen-response` poke to the requesting grub, routed back by
the arvo wire the request rode out on. So the service records each outstanding
keen in its state, keyed by that wire, so a later `yawn` can cancel *exactly* the
requester's keens at a spar (`ames` cancels by duct, and replaying the keen's
original wire reproduces that duct) without disturbing other grubs parked on the
same name.

That record is the service's whole state, `scry-state`: behind a `%0` version tag,
one map — `keens`, from the arvo `wire` a keen went out on to the three things
needed to route its answer home — the `ship` and `path` (`pax`) being read, and
the `sender` rail of the grub that asked.

```live
/grubbery/lib/nexus.hoon 199-208
```

> [!note] A wart: `ship` and `pax` are a `spar`
>
> A keen's `ship` and `pax` are exactly a `spar` — `[ship path]`, the address type
> `ames` and the read verbs already use — but they're kept as loose fields here
> rather than the `spar` they form.

Two handlers ride on it. `handle-scry-keen` builds the return-address wire, stores
the keen under it, and passes the `%keen` to ames. `handle-scry-yawn` looks up the
caller's own keens at the spar and replays `%yawn` on each — cancelling only that
caller's reads, and falling back to a broad `%wham` (which would cancel every grub
waiting on the name) only when it finds no record.

```live
/grubbery/app/grubbery.hoon 7625-7662
```

The answer comes back as an `ames` `%sage` sign on the keen's wire. The page in
it is the publisher's binding: signed, so its origin is proven, but not shaped —
a hostile publisher can bind a cell where the page's mark should be an atom, and
a plain cast would pass that through and crash the `%keen-response` validation
downstream, restarting the reading fiber on every answer. So the sign is matched
as a noun and the page clammed inside a `mule`: a well-formed binding passes, and
a malformed one reads as `~`, nothing bound — a miss the reader already handles.
`take-keen-sage` then drops an answer whose spar names a different ship than the
wire asked for, clears the keen from `scry-state`, and pokes the requester.

```live
/grubbery/app/grubbery.hoon 541-562
```

```live
/grubbery/app/grubbery.hoon 7686-7703
```

### The fiberio utility surface

Nexuses never touch `gall` or `ames` directly; they call five `fiberio` helpers,
one per `/sys/scry` tag. Three write this ship's farm — `grow`, `tomb`,
`cull-farm` — and two read another ship's — `keen` and `yawn`. Four of them are a
single fire-and-forget poke to `/sys/scry/main.sig` and nothing more; only `keen`
does more, blocking until the remote's answer comes back as a poke, then returning
a `(unit page)`.

```live
/grubbery/lib/fiberio.hoon 899-943
```

> [!note] The naming is a wart
>
> These five sit at `fiberio`'s top level, so `cull` couldn't be one of them —
> `cull-farm` dodges the collision — and `grow`/`tomb` take those bare names for
> remote scry, leaving grubbery-native code unable to use them for anything else.
> Cleaner would be a single core, `fa`, with a symmetric `grow`/`tomb`/`cull`
> trio — `(grow:fa …)`, `(tomb:fa …)`, `(cull:fa …)` — freeing the bare names.

`keen` takes a `ship` and a `path` — together they name the page as
`/gw/<ship>/…/<spur>` in the scry namespace — and returns a `(unit page)`:
`[mark noun]` for the content bound there, `~` if the remote bound nothing. It
pokes `%scry-keen` and then blocks, parking until the matching `%keen-response`
comes back (correlated by the wire it sent), so a nexus reads a remote ship as if
synchronously. `ames` verifies the publisher's signature before the answer arrives;
the noun inside is still arbitrary, so a consumer checks the shape it expects
before trusting it.

`keen` carries no deadline — `ames` holds the request until the remote answers, maybe
never — so a caller unwilling to wait wraps it in `with-timeout` and `yawn`s the
request it abandoned. `yawn` takes the same `ship` and `path`, pokes `%scry-yawn`,
and cancels only this grub's keens there.

```live
/grubbery/lib/fiberio.hoon 944-988
```
