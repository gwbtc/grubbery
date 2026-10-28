# /sys/behn

A timer is a poke to `/sys/behn/main.behn-state` naming a wire and a
time, and a wake is a poke back to the fiber carrying that wire. The
state grub holds one entry per requester and wire, so setting a timer
on a wire the fiber already holds replaces the old one, and a wake that
does not match the live entry is dropped. A restarted fiber that sets
its timer again on the same wire therefore never accumulates orphans,
and a stale wake in flight never reaches it.

## Set, rest, wake

```live
/desk/lib/nexus.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 158-162
```

`+handle-timer-set` records the entry, rests any superseded Arvo timer,
and passes the wait on a wire that encodes the requester and its wire.
`+handle-timer-rest` cancels by the same key.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 6932-6967
```

The wake decodes the wire, checks it against the live entry, and pokes
the requester with `%timer-wake` carrying the wire.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 7009-7043
```

## From a fiber

`+set-timer` and `+cancel-timer` are the two pokes; `+wait` and
`+sleep` set a timer on the fixed wire `/wait` and take its wake.
`+with-timeout` runs any fiber computation against a deadline on a
caller-named wire, cancels the timer when the computation finishes, and
returns nothing if the deadline fired first.

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1346-1401
```

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1409-1464
```
