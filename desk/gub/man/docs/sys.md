# The Urbit kernel interface

A fiber never sees Arvo. Every vane a nexus might need is a directory
under `/sys`: a state grub the fiber pokes with a request, and grubs the
kernel writes when the vane answers. A poke to a `/sys` grub is
intercepted at dispatch, validated through the request's mark, and
consumed in the same event, so the fiber gets its pack at once; the
vane's answer arrives later as a poke back to the fiber, or as a write to
a grub the fiber can keep. Because the request is a dart, the weir gates
it like any other reach, and a sandboxed app is refused a timer or an
HTTP fetch by the same rule that refuses it a file. So the kernel's
whole surface to Arvo is a handful of directories with marks, and the
fiber library is a thin set of pokes and takes over them.

## The layout

The root nexus lays out each service as a `%fall` directory with its
state grub, so a service's state is a grub in the tree and survives
reloads as one. Foundational services with no seed row are made at boot.

```live
/grubbery/lib/root.hoon 50-76
```

```live
/grubbery/app/grubbery.hoon 621-640
```

The state types are the kernel's own, one per service, each stored under
its mark at a fixed rail.

```live
/grubbery/lib/nexus.hoon 150-167
```

## A request

A poke whose destination is under `/sys` is validated at dispatch, not at
consumption, and matched against the service table. Four services are
matched first by rail and mark; the rest go through `+handle-sys-poke`,
which switches on the directory name. A poke no service claims falls
through to an ordinary poke, so a `/sys` grub with a process can still be
poked.

```live
/grubbery/app/grubbery.hoon 3802-3839
```

```live
/grubbery/app/grubbery.hoon 6826-6834
```

Every handler ends the same way: the request is consumed, and the caller
gets a `%pack` on its wire. What the vane says later is a separate
input.

## An answer

The kernel passes each Arvo task on a wire that encodes the requesting
rail and its own wire, and decodes the sign back into a poke at the
requester. The dispatch on signs is the whole map of what comes back.

```live
/grubbery/app/grubbery.hoon 465-576
```

Two shapes of answer exist. A response is poked to the requester under a
result mark, `%timer-wake`, `%http-response`, `%keen-response`, matched by
the fiber on its wire. A materialized answer is written to a grub the
kernel owns, the dill log, a key, a lick port's inbox, a gall fact, and a
fiber reads or keeps it like any grub.

## The library

Each service has its pokes and takes in the fiber library, so a nexus
writes `set-timer` and `take-wake`, or `fetch`, and never names a mark.
The pages that follow take the services one at a time.
