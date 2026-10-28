# /sys/eyre

Eyre delivers an HTTP request to the Gall agent. The service under
`/sys/eyre` turns that into a poke to a grub, and turns the grub's answer,
another poke, back into the facts Eyre expects. A nexus serves HTTP by
binding a URL prefix to one of its grubs and answering pokes on it; it never
sees an Eyre card. What the service holds is one grub of bindings and a
table of open connections, and everything else is routing.

## The service's tree

The root nexus lays out `/sys/eyre`: the state grub, `main.server-state`,
and a `requests` directory for the kernel's own request fibers.

```live
/desk/lib/root.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 50-54
```

The state is the binding table, URL prefix to handler grub, and the
connections in flight, Eyre's request id to the binding that took it.

```live
/desk/lib/nexus.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 150-157
```

On every load `+sync-eyre` re-registers each binding with Eyre, since
Eyre's table and the grub's can drift and the grub's is the one that
counts, and registers the two routes the kernel serves itself,
`/grubbery/api` and `/grubbery/push`.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 6336-6356
```

> [!note] Wart: every bound request writes the state grub
> `conns` changes on every request and every response, and it lives in
> the same grub as the bindings, so each bound request runs the full grub
> write path twice: a history entry, a tree rebuild, a vale cache sweep,
> silo refs. On a ship with months of traffic that was about a second of
> latency per page and a permanent event-log record per request. The
> grub's own comment says so. `conns` is transient per-request bookkeeping
> and should be agent state; the grub should be written only when a
> binding changes.

## Binding a route

A nexus binds by poking the state grub with an `$eyre-action`. `%bind`
names the handler grub; `%bind-self` lets the kernel use the poker's own
rail, so a nexus serving its own UI need not learn its absolute position;
`%unbind` removes a binding and kicks any connection open on it.

```live
/desk/lib/nexus.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 133-149
```

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 7137-7180
```

The poke never reaches a fiber. The kernel intercepts pokes to `/sys`
grubs at dispatch, validates the payload, and consumes it in the same
event, acking the sender directly.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 3824-3828
```

From a fiber, `+bind-http-self` is the usual call. It tolerates a veto:
a freshly installed app is jailed until its ask is approved, its bind is
refused at rise, and crashing there would park the fiber. It logs and
continues instead, and the reload after approval binds again.

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1883-1924
```

## A request arrives

Eyre pokes the agent with the request and its id. `+route-http` looks at
the URL: `/grubbery/push` is the notification endpoint, `/grubbery/api` is
the kernel's own file API, and anything else is matched against the
bindings.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 174-183
```

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 6393-6425
```

A bound request goes to the binding with the longest matching prefix. The
connection is recorded, and the handler grub is poked with
`%handle-http-request`: the id, the requesting ship, and the request.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 6500-6536
```

## In the nexus

The handler is a fiber like any other, taking pokes. `+http-dispatch` is
the standard loop: on each request it makes a grub under the nexus's
`/requests` directory holding the request, so the nexus's `+on-file` gives
it a fiber of its own; on a cancel it culls that grub; and it relays
responses. One request, one grub, one fiber.

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1982-2004
```

The request grub's content is the ship and the request, in the
`http-request` mark. The kernel's own file API is the pattern in the
smallest form: the request fiber reads its state and dispatches.

```live
/desk/lib/root.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 105-110
```

## Answering

A response is a `%send` poke to the state grub carrying the request id and
an `$eyre-update`: a header, a chunk of data, a kick, or a simple payload
that is all three. The `+http-res` door wraps them.

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1932-1981
```

The kernel turns each update into the corresponding fact or kick on
`/http-response/<id>`, which is where Eyre listens. A simple payload or a
kick ends the connection and drops it from `conns`; a header or data leaves
it open, which is how a stream is served.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 7123-7135
```

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 7181-7193
```

## Cancel

When the client goes away, Eyre leaves the response path. The kernel finds
the connection: a bound request's handler gets a `%handle-http-cancel`
poke, so its dispatcher culls the request grub; an unbound one was the
kernel's own, and its request grub is culled directly.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 357-363
```

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 6377-6391
```

## The kernel's own routes

`/grubbery/api` is the file API over the tree. A request that is a pure
read of current state, a listing, a tree, a file, a weir, is answered
inline from the agent, with no grub made. Only a request that needs an
asynchronous script, a write, a poke, a kept stream, an upload, becomes a
grub under `/sys/eyre/requests` and gets a fiber.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 6427-6498
```

> [!note] Wart: a request grub leaves a record behind
> A request grub is made and culled by plain `+make`, which never gains,
> and a culled grub keeps its history. So the requests directory of every
> HTTP-serving nexus holds one dead record per request it has ever
> answered, and every write under that directory walks them all: the cost
> of a request grows with lifetime traffic. An un-gained grub should leave
> nothing behind when culled; a gained one keeps its record as the
> ordering high-water mark.
