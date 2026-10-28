# /sys/lick

A local IPC port is a directory under `/sys/lick`. A nexus spins one by
name; the runtime serves the socket under the pier, and everything the
client sends is written to the port's `in` grub with a sequence number,
so a keep on it wakes once per message even when two messages are
equal. Connection state is a `live` flag, advisory, since a client could
send the connect and disconnect marks itself. Ports are respun from the
tree at boot.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 5985-6001
```

## Spin, spit, shut, soak

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 6013-6041
```

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 6042-6067
```

## From a fiber

The three pokes, and `+lick-serve`, a request-and-response server over a
port: it spins the socket, keeps the inbox, decodes each frame as an
HTTP-shaped request, calls the handler, and spits the reply unless the
client has already gone.

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1237-1304
```
