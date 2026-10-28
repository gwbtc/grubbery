# /sys/push

Web push is a state grub holding the ship's VAPID keypair, generated at
boot if absent, and the browser subscriptions registered by ship. A send
names targets and an exclusion set, builds one signed request per
subscription, and passes each to the HTTP client on a wire that names
the requester; a response of 404 or 410 drops the subscription as
stale, and the last outcome is written where a tool can read it.

```live
/desk/lib/nexus.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 209-224
```

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 6538-6547
```

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 6567-6651
```

## From a fiber

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1706-1709
```

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1740-1752
```

The human-addressed bus that most nexuses use sits above this, in the
notifications nexus; see [The kernel and the shell](#kernel-shell.md).
