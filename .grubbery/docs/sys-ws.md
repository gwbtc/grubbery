# /sys/iris/ws

A websocket is a row in `/sys/iris/ws.ws-state`, keyed like a timer by
the owning rail and a wire the fiber chooses. A connect on a key the
fiber already holds closes that socket first, so a restarted fiber
reconnects on its key and gets a clean replacement. Frames arrive as
pokes to the owner; a socket that dies with the runtime sends nothing,
so the fiber owns its own timeout and reconnect. The vane is a
groundwire runtime feature, and the kernel builds the connect task from
a vase so the desk builds on a stock runtime and a connect there fails
with a tang.

## The contract

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 7317-7361
```

```live
/desk/lib/nexus.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 168-198
```

## Connect, promote, frame, close

A connect parks a row under the Arvo wire of the connect. The accept
sign does not promote it: the runtime subscribes for outbound frames
after accepting, and that watch is where the row moves to `open` and
the owner is told the socket id. An accept with no pending row is an
orphan and is closed on the spot.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 7377-7421
```

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 7453-7488
```

Inbound frames are pokes from the runtime to the agent, routed to the
owner by socket id. Send is a fact on the socket's path. Close drops the
row at once, since after a runtime restart the vane will never leave.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 7490-7522
```

## From a fiber

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1612-1688
```
