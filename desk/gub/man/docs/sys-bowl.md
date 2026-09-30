# /sys/bowl

A fiber has no bowl. It asks `/sys/bowl.sig` for our ship, the time, or
entropy, and is poked back with the answer. Time and entropy are
answered from a counter the kernel keeps so that two asks in one event
never get the same value: the clock is advanced by a millisecond per
ask when the event's time has not moved, and entropy is rehashed per
ask.

```live
/grubbery/app/grubbery.hoon 7705-7719
```

> [!note] `%now` is not the clock
> Two `+get-time` reads in the same event differ by exactly one
> millisecond whatever the work between them took. Timing a computation
> with them measures the number of asks. Wall time of an event is
> measured with a `%bout` hint, not with the bowl.

## From a fiber

A bowl read gets two inputs back in either order, the pack of its poke
and the response, and `+take-bowl` consumes exactly one of each. Entropy
uses a fixed wire, because a nonce would itself need entropy.

```live
/grubbery/lib/fiberio.hoon 1467-1519
```

```live
/grubbery/lib/fiberio.hoon 1521-1543
```
