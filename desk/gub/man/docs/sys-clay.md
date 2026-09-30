# /sys/clay

A Clay desk is a subtree. `/sys/clay/desks/<desk>` mirrors the desk's
files as grubs, each under the mark its Clay path ends in, and the kernel
keeps the mirror current by subscribing to the desk and re-syncing on
every commit. The grubbery desk's own mirror is what fills root `/code`
(see [Code nexuses](#code-nexuses.md)). The state grub lists the mounted
desks; pokes mount, unmount, create a desk, or write files into one.

```live
/grubbery/lib/nexus.hoon 234-239
```

## The mirror

A sync reads every file in the desk, validates each through its mark,
builds the desk as one bole, and lands it with one write, so a
directory keep on the mirror gets one news per commit and files gone
from Clay are tombed by their absence. Then it subscribes for the next
change.

```live
/grubbery/app/grubbery.hoon 4948-5002
```

```live
/grubbery/app/grubbery.hoon 5750-5769
```

## Mount, unmount, new desk

```live
/grubbery/app/grubbery.hoon 7046-7072
```

`%new-desk` creates a desk from the base skeleton with the few files a
desk needs to build.

```live
/grubbery/app/grubbery.hoon 7074-7101
```

> [!note] Wart: unmounting a protected desk crashes the event
> `+handle-clay-unmount` asserts the desk is neither `base` nor
> `grubbery`. A fiber that asks crashes the event instead of being
> refused, so its poke nacks with a trace rather than a reason. The
> handler should log and return.

## Writing files

`%clay-info` takes a list of paths with an optional mime each and issues
one Clay commit: a mime is an insert, converted by Clay to the mark the
path ends in, and an absent mime is a delete.

```live
/grubbery/app/grubbery.hoon 7102-7135
```

## From a fiber

The mount pokes and the write, plus scries of a desk's case, a file's
existence, and a file's content through the scry service.

```live
/grubbery/lib/fiberio.hoon 989-1030
```
