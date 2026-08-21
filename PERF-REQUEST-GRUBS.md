# Why bound HTTP requests get slower forever

Measured on ~feb, August 2026, with `~>(%bout)` hints in the request path.

## The shape of a request

One bound HTTP request is a single gall event. It is not a chain of ten
events, which is what we assumed for a long time.

```
ev-poke                    429ms      the whole request, one event
  fh-bindings               10ms      binding lookup, reads the server-state grub
  fh-fiber                  19us      the poke only enqueues
  abet drain             8 steps      416ms total, ~52ms per fiber step
```

The work lives in the fiber drain inside `abet`, not in `route-http`.

## Where the drain goes

Each request performs four `make` cycles. Per make:

```
mk-validate                ~8ms
sf-record                  ~8ms
sf-propagate            3 - 160ms     the variable one
mk-spawn                   <1ms
```

`propagate` splits evenly into its two halves, and in steady state both are
expensive:

```
pg-trees                   77ms       rebuild ancestor tree hashes
pg-notify                  81ms       wake watchers
  nt-diff                  80ms       of which: a whole-namespace diff
```

`diff-born-state` is 99% of `notify`. It walks the namespace to rediscover a
change that `propagate` was handed as an argument.

## The root cause

`+cull` on a file calls `+delete`, and `+delete` ends with:

```hoon
=.  born  (~(put bo:nexus now.bowl born) [dir name] new-sok)
```

That writes a tombstone hist entry. It never removes the key. nexus.hoon states
the invariant directly: "Born records are NEVER deleted (high-water mark for
ordering)."

So every HTTP request permanently adds one entry to the handling nexus's
requests directory. Both hot functions then walk that whole map on every
subsequent write:

- `+record-trees` does `~(rep by file.node)` across every entry, tombstones
  included.
- `+diff-born-at` unions every name in both the old and new maps.

Per-request cost is therefore proportional to the total number of requests the
nexus has ever served.

## The measurement

Hitting one static asset repeatedly on a ship that started this session:

| requests directory entries | ev-poke |
| --- | --- |
| 3,733 | 554ms |
| 4,034 | 482ms |
| 4,335 | 592ms |
| 4,636 | 645ms |

Entries rise by exactly one per request. The count never falls. A fresh build
reads fast and then degrades as traffic arrives, which is why the cost looked
bimodal before the directory size was visible.

~ricsul-bilwyt has been serving for months. Its 6 second page loads are this
curve, much further along.

## Fix options

1. Remove the born key when a grub is culled. Smallest change and it removes
   the growth entirely. It collides with the ordering invariant: a recreated
   rail would restart its version numbering, which matters for remote scry
   caching. Safe for request grubs because eyre ids are never reused.

2. Mark a directory ephemeral at declaration, so `+cull` hard-removes inside it
   and leaves every other directory alone. More code, and it keeps the
   invariant where the invariant earns its keep.

3. Pass the known change set from `+record-trees` into `+notify` instead of
   calling `diff-born-state`. This is worth doing on its own merits, since the
   walk already knows which levels it bumped. It cuts roughly half the
   per-request cost and it does not stop the growth.

Option 2 plus option 3 fixes the cause and the waste. Option 3 alone is the
lowest risk and lands a real win today.
