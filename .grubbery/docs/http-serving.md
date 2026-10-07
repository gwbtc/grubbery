# HTTP serving

A nexus serves a page by holding a route and answering each hit in a
fiber of its own. One long-lived grub binds a prefix and loops over the
requests the kernel forwards, making a grub under `/requests` per hit;
that grub's fiber reads the request from its own state, does its work
with ordinary peeks and pokes, and sends the response through `/sys/eyre`
(see [/sys/eyre](#sys-eyre.md) for the kernel's side). The page itself is
a static file in the nexus's tree and the data it shows comes from JSON
routes beside it, so the same grubs the fibers write are what the browser
reads. So serving is three arms the library provides, a directory, and a
dispatch on the URL suffix, and everything a request does is a fiber
doing what fibers do.

## Binding

`+bind-http-self` binds a route to the grub that sends it; the kernel
takes the handler rail from the poke's source, so a nexus needs no walk
to root to serve its own page. A jailed app's bind is vetoed at rise, and
the arm logs and continues rather than parking the fiber, since the
reload after approval runs the bind again with grants in hand.

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1895-1924
```

## Dispatch

`+http-dispatch` is the loop the binding grub runs: a forwarded request
becomes a grub named by the eyre id under `/requests`, holding the source
ship and the request; a cancel culls it.

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1982-2004
```

The two rows and the two arms in a nexus, with the request fiber handed
its own name.

```live
/desk/gub/nex/github.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 55-61
```

```live
/desk/gub/nex/github.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 74-80
```

## Answering

The request fiber reads `[src request]` from its state, refuses a foreign
source, strips the bound prefix from the URL, and switches on the
suffix: named routes answer with JSON, everything else is served as a
static file from the nexus root.

```live
/desk/gub/nex/github.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 488-521
```

Responses are pokes to the server state. `+http-res` gives the four
sends, one whole response or a header, data chunks, and a kick for a
stream; `+web` in the web library wraps the three replies a nexus writes
most, a status with a message, a JSON body, and a static file read from
the tree as mime.

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1950-1981
```

```live
/desk/gub/lib/nexus-web.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 99-123
```

The content types and cache headers for a static payload are in the
server library.

```live
/desk/lib/server.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 76-159
```

## Static shell and data routes

A page is one `%over` row per asset, so the code is the truth of the
UI, and the data it renders is read from JSON routes after the page
loads. A route that reads the tree answers from the same grubs the
nexus's other fibers write, so there is no view state to keep current.

```live
/desk/gub/nex/github.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 46-53
```

A route that changes something writes the grub and answers; the page
asks again.

```live
/desk/gub/nex/github.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 536-554
```

## Streams

A response can be held open: send a header, then data chunks as events
happen, then a kick. The HTTP utilities detect an event-stream request
and encode server-sent events; the kernel's `GET /keep` on the file API
is the pattern at full length (see [The ball](#ball.md)).

```live
/desk/lib/http-utils.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 67-79
```

```live
/desk/lib/http-utils.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 123-165
```

> [!note] Wart: the dispatcher's server relay is dead
> `+http-res` pokes the server state directly, and its comment says the
> dispatcher's `%eyre-action` relay only added an eval cycle and a second
> validation. The relay branch in `+http-dispatch` and the door's sample
> road stay so existing call sites compile. The branch should go and the
> door should take no sample.
