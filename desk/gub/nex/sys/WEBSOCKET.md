# /sys/iris/ws.ws-state — websocket client service

Status: **built and verified** (2026-09-22): a fiber in `/apps/nostr`
connected to an echo server, sent a text frame, got it back, closed.
Next: the nostr relay client on top of it.

Grubbery builds on any runtime. `lib/nexus.hoon` carries its own copies
of the frame and event shapes (`ws-message`, `ws-event`, faces matching
the runtime's so vases nest at the agent boundary), the `%websocket-
response` sign is matched as a noun, and the `%websocket-connect` task
card is built from a vase inside `mule`: on a stock lull it is not an
iris task, the nest fails at runtime, and the fiber gets `[/ %ws-fail]`
"runtime has no websocket support" instead of the desk failing to build.

Three things the build taught that the design below did not say:

  * every blot poked at a `/sys` rail needs a marc under `gub/mar/`
    (`ws-connect`, `ws-send`, `ws-close`, and the poke-backs `ws-open`,
    `ws-fail`, `ws-frame`, `ws-closed`, plus `ws-state`). The `/sys`
    validator falls through to a plain grub poke when the marc is
    missing, silently.
  * iris delivers the `%accept` sign BEFORE it subscribes on
    `/websocket-client/<wid>`. Promoting on the sign lets the owner send
    into a path with no subscriber and gall drops the fact. The row is
    promoted in `on-watch` (the wid's url comes from iris's `%ix` scry,
    `/ws/<app>/id/<wid>`); the `%accept` sign is a no-op. nostrill does
    the same, which is what its "handled elsewhere" comment meant.

## Why this is a kernel service and not a nexus

Grubbery's fiber I/O today is request/response: `/sys/iris` turns an
HTTP request poke into an arvo task and pokes the response back to the
requesting fiber. A websocket is a long-lived connection that produces
frames for as long as it is open, and both directions carry many
messages. No nexus can own that: iris delivers frames to the *agent*
(`%grubbery`), so the app has to route each frame to the fiber that
owns the connection. Same tier as timers, scry, and iris.

## What the runtime provides (groundwire vere, UIP-125)

iris tasks (`lull.hoon`):

    [%websocket-connect app=term url=@t]        open; app names the receiver
    [%websocket-response id=@ud websocket-event:eyre]
                                                  %message → send a frame
                                                  %disconnect → close
                                                  %accept → ack (client side: no-op)
    [%cancel-websocket id=@ud]                    abort a pending connect

iris gift, on the wire the task was passed on:

    [%websocket-response wid=@ event=websocket-event]
      %accept      the handshake succeeded; wid is now live
      %reject      handshake failed
      %disconnect  the socket closed (peer or us)
      %message     never here — frames come as POKES, below

frames: vere plans a `%websocket-event` on wire `/http-client/<sev>`;
eyre turns it into a **poke** to `app` with mark
`%websocket-client-message` carrying `[wid=@ud websocket-message:eyre]`
where `websocket-message = [opcode=@ud message=(unit octs)]`. So the
agent sees a `%poke` per frame, keyed by wid. (Stock vere has none of
this; this is groundwire-only. nec cannot run it.)

Sanity check against a working client: `ships/gw-zod/nostrill` does
exactly this — `%websocket-connect` from `lib/websockets.hoon:connect`,
frames in `on-poke` under `%websocket-client-message`, lifecycle in
`on-arvo` under `[%ws-connect url=@ ~]`, sending via a `%fact` on
`/websocket-client/<wid>` with cage `[%message !>(msg)]` — iris
*subscribes* to the app on that path to pull outbound frames. That
last part matters: outbound frames are not a task, they are facts on a
subscription iris opens when the socket accepts.

## The service

    /sys/iris/ws.ws-state         the connection table (rebuildable).
                                  Same vane as HTTP requests, so it sits
                                  next to main.iris-state rather than in
                                  a service of its own.

Pokes a fiber sends to `/sys/iris/ws.ws-state` (weir-gated like every
/sys poke):

    [/ %ws-connect]   [key=wire url=@t]   → gets back [/ %ws-open] [wid] or
                                            [/ %ws-fail] tang on the fiber's own rail.
                                            key is the fiber's name for the socket,
                                            as a timer's wire is for behn: one socket
                                            per [owner key]; connecting again on a
                                            key closes the socket it held.
    [/ %ws-send]      [wid=@ud text=@t]   → a %message fact on /websocket-client/<wid>
    [/ %ws-close]     wid=@ud             → %websocket-response %disconnect

What the app does with the two inbound shapes:

  * `on-arvo` `[%ws %connect <sender rail…> ~]` `%websocket-response`:
    `%accept` → record wid → owner, poke the owner `[/ %ws-open] wid`;
    `%reject` → poke `[/ %ws-fail]`; `%disconnect` → poke
    `[/ %ws-closed] wid` and drop the row.
  * `on-poke` mark `%websocket-client-message` `[wid msg]`: look up the
    owner rail by wid, poke it `[/ %ws-frame] [wid msg]`. Unknown wid →
    log and drop (a frame after we closed).
  * `on-watch` `[%websocket-client <wid> ~]`: iris subscribing to pull
    our outbound frames; accept. `%ws-send` becomes
    `[%give %fact ~[/websocket-client/<wid>] %message !>(msg)]`.
  * `on-leave` on that path = the socket is gone from iris's side; same
    as %disconnect.

fiberio gains:

    ++  ws-connect   |=(url=@t …)   → (unit wid)      (poke + take open/fail)
    ++  ws-send      |=([wid=@ud text=@t] …)
    ++  ws-close     |=(wid=@ud …)
    ++  take-ws-frame  |=(wid=@ud …) → (unit octs)     ~ on close; interruptible
                                                        like take-news-or-interrupt

## Restart contract

Sockets do not survive a runtime restart (vere's h2o sessions are
gone), and nothing tells the agent: iris's `%born` cancels HTTP
requests, not websockets, and gall keeps iris's subscription to
`/websocket-client/<wid>` so no `on-leave` arrives either. So:

  * a row for a dead socket stays in `open` until its owner closes it.
    `[/ %ws-close]` drops the row and answers `[/ %ws-closed]` itself,
    without waiting for iris to leave.
  * the runtime restarts wids from 0. When iris subscribes on a wid
    that is still in `open`, that row is a dead socket: its owner is
    told `[/ %ws-closed]` and the new socket takes the row.
  * a fiber blocked in `take-ws-frame` owns its own timeout and
    reconnect policy (the nostr client's loop). Every poke terminates;
    no auto-healing in the service.
  * a respun fiber (nexus reload) does nothing special: it connects
    on its key and the service closes the socket its previous life
    held under that key. An accept whose pending row was replaced is
    an orphan and is closed at once.
  * a fiber's intake must DROP frames for sockets that are not its
    current one (`%wait`), never `%skip` them: a skipped input is
    retained and re-offered on every later step.

## What the nostr relay client then is

A fiber per relay under `/apps/nostr/relays/<host>.json`: connect, send
`["REQ", sub, filter]`, loop on `take-ws-frame`, parse `["EVENT", sub,
ev]` → `make-soft` `/events/<id>.json` (idempotent, same as the poller),
`["EOSE"]` → mark synced, on close → sleep/backoff → reconnect. Keys and
signing (`lib/nostr/keys.hoon`, ~50 lines, kernel secp) port as a lib for
publishing. The poller in `nostr.hoon` gives way to it; every reader is already
on the namespace.

## Order

1. `ws.ws-state` in app/grubbery.hoon + the four fiberio arms. Test with an
   echo server (`wss://echo.websocket.org` or a local one).
2. `/apps/nostr` relay fibers alongside the poller; compare event sets.
3. Remove the poller; drop `/sys/scry` from nostr's weir.
