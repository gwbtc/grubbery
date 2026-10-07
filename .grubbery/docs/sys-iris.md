# /sys/iris

An outbound HTTP request is a poke of a `$request:http` to
`/sys/iris/main.iris-state`; the response is a poke back to the fiber
under `%http-response`. The state grub records each request in flight
by the wire the kernel passed it on, keyed to the requester, and drops it
when the response comes.

```live
/desk/lib/nexus.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 163-167
```

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 7273-7316
```

## From a fiber

`+send-request` and `+take-client-response` are the pair; a cancelled
request fails the fiber rather than returning. `+fetch` composes them and
extracts the body.

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1587-1610
```

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1690-1705
```

> [!note] Outbound URLs need double percent-encoding
> The runtime's HTTP client decodes a URL once before sending it, so a
> percent sequence meant for the wire has to be encoded twice. A URL
> built from user text with a single encoding reaches the server with
> the sequence decoded.

The websocket client shares the vane and has its own state grub beside
this one; see [/sys/iris/ws](#sys-ws.md).
