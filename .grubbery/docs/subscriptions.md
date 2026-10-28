# Subscriptions

A subscription is a grub asking to be told when part of the tree changes.
The kernel records who is watching what, and after every write it works out
which watchers are affected and hands each one a *wave*. The watcher's fiber
takes the wave as an input and decides what to read. This is how one nexus
reacts to another's writes without either calling the other: they meet
through the namespace, and a subscription is the namespace saying "this
moved."

## Lanes and waves

### A lane

A subscription target is a `$lane`: either one file, by its `$rail`, or one
directory, by its `$fold`. Watching a directory means watching everything under
it.

```live
/desk/lib/tarball.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 39-43
```

### A wave

Every grub and every directory has a version, a `$cass:clay`: a revision
number or a date. A directory's version bumps whenever anything beneath it
changes, so one number at the top of a subtree already says whether
something under it moved. The kernel keeps every version history, a `$hist`, in one
axal shaped like the tree, the `$born`.

A wave, `$wave`, is the born cut down to one lane and reduced to current versions: at
each directory under the lane, the directory's own version (`fold`) and the
version of each file in it.

```live
/desk/lib/nexus.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 78
```

Two arms build waves. `+wave-from-born` walks a born, takes the top of each
history, and recurses into every subdirectory; `+wave-at` dips the born to a
lane first. So a wave for a directory is not that directory's version. It is
the version of everything under it, however deep.

```live
/desk/lib/nexus.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1037-1057
```

A wave carries no content. It says which versions exist now; a watcher that
wants the bytes reads them with a peek. What the
subtree is for, rather than the one number that would say "something
moved," appears when a watcher compares two waves, below.

## The two indices

The kernel keeps subscriptions in `$subs`, two axals over the same facts.
`fwd` answers "who watches this lane?": at each path, the watchers of the
directory itself and, per file name, the watchers of that file. A watcher is
a grub, named by its `$rail`, with the `wire` it chose for this subscription. The
`blot` beside it is recorded when the subscription is made; delivery does not
read it. `rev` answers "what does this grub watch?": at the watcher's path,
per grub name, the set of lanes.

```live
/desk/lib/nexus.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 393-403
```

> [!note] Wart: a blot with nothing to convert
>
> The `%keep` dart carries a `blot`, `+keep` takes one, and `+sub-put`
> stores it beside the wire, so the surface promises that what a watcher
> receives will be converted to that mark. But a news carries a wave,
> versions only, never content, so there is nothing at delivery to convert
> and `+notify` never reads the field; `+hydrate`, which does convert a
> `%peek`'s result to its blot, passes a `%news` through untouched. The
> field should be dropped from the dart and the index.

`+fwd-get` shows the shape of a lookup: the path selects the node, and the
lane's kind selects the directory's watchers or one file's.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 3011-3018
```

Every registration writes both indices, and every removal clears both, so
the two never disagree.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 3089-3100
```

## Watching

A fiber subscribes, unsubscribes, and asks what it is subscribed to with
three darts, the effects a fiber yields to the kernel, each answered by an
input. A dart travels through the tree like any other and is filtered by the
weirs on its way (see [Sandboxing & weirs](#weirs.md)); a subscription is
gated like a read.

### keep: register, and the first wave

`+keep` sends a `%keep` dart and then waits, with `+take-bond`, for a `%news`
on the same wire.

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 832-837
```

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 846-848
```

For a local lane the kernel registers the watcher and immediately enqueues
that news, carrying the wave at the target as it is now. So `+keep` returns
the current versions of what it watches, and a fiber that keeps a lane
always learns its state before any change to it.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 3516-3519
```

### drop: unregister, and the fell

`+drop` sends a `%drop` dart and waits for a `%fell` on the wire. The kernel
removes the watcher and enqueues the fell. Nothing else arrives on that wire
afterward.

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 839-844
```

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 3535-3536
```

### kept: what a grub is watching

`+get-kept` asks the kernel for the grub's own subscriptions. The kernel reads
`rev` and answers with each lane relativized to the grub, as a `$bend`, so a
sandboxed grub that cannot see its absolute position still gets a usable
answer.

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 205-210
```

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 3620-3627
```

## Delivery

### What counts as a change

Every write to the tree ends in `+propagate`: rebuild the tree hashes above
the written leaf, then `+notify` with the born as it was before the write.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 4686-4694
```

`+notify` diffs old born against new with `+diff-born-state`, which compares
only the top version of each history: a file or directory changed if its
current version did. Unchanged subtrees are the same noun in both borns, so
the walk stops at them without looking inside.

```live
/desk/lib/nexus.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1113-1162
```

### Who hears it

With the set of changed lanes in hand, `+notify` walks every watched lane in
`fwd`. A file target matches only itself. A directory target matches any
changed lane at or under it. For each target with a match it builds one wave
at that target and delivers it to each of the target's watchers. The
delivery has five shapes, by who the watcher is: the usergroups registry gets
it synchronously; a watcher whose grub no longer exists is dropped instead of
delivered to; a client channel gets a fact; a remote ship gets a poke; a
local grub gets a `%news` input.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 3124-3201
```

### One news per write

`+propagate` runs once per written leaf, so `+notify` does too. A watcher of a
directory receives one wave per write beneath it, each wave reflecting the
tree at that moment.

> [!note] A loop of writes is a loop of waves
>
> Code that writes many files in one event, each through its own
> `+propagate`, queues that many waves to every directory watcher above them.
> The watcher's fiber runs after the event's writes are done, so its first
> wave already shows the final state and every wave after it shows nothing
> new. Writing a subtree as one bole through `+load-ball-changes` notifies
> once for the whole subtree; the Clay desk mirror does this, so a commit is
> one wave.

## Reading a wave

A fiber takes a wave with `+take-news`, matching the wire it kept on and
skipping anything else.

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 864-876
```

A wave alone says what is. A watcher that holds the previous wave learns
what moved with `+diff-wave`, which returns each changed lane with its new
version, and this is why a wave is a subtree rather than one number: with
two subtrees the watcher names the changed files itself, with no peek; with
two directory versions it would know only that something changed and would
have to read the directory to find out what. A diff at the top of a subtree
names both the directory and the file, since both versions moved.

```live
/desk/lib/nexus.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1060-1099
```

A fiber that waits on both news and a timer uses `+take-news-or-wake`, which
returns whichever arrives first.

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1794-1810
```

> [!note] Wart: any wake is a wake
>
> `+take-news-or-wake` accepts any `[/ %timer-wake]` poke, not only the
> timer this fiber armed. A wake from a deadline that was cancelled can
> still be in flight, and a fiber that arms deadlines in sequence would take
> the earlier one's late wake as the current one's. A wake's payload is the
> wire it was set on, and the take should match on it.

## A watcher, end to end

A fiber that follows a directory does four things: keep it and hold the
bond as the first wave, take each news, diff it against the wave it holds,
and act on what moved. The road is relative, as every road a fiber sends
is; the wire is the fiber's own name for this subscription and stays fixed
for its life.

```hoon
=/  m  (fiber:fiber:nexus ,~)
;<  prev=wave:nexus  bind:m  (keep:io /watch road ~)
|-  ^-  form:m
;<  cur=wave:nexus   bind:m  (take-news:io /watch)
=/  moved=(map lane:tarball cass:clay)  (diff-wave:nexus prev cur)
;<  ~  bind:m  (react moved)
$(prev cur)
```

Nothing here survives a restart except the registration. The process is
rebuilt from its spool, so `prev` is gone, but the entry in `fwd` is not:
a restart touches neither index. A restarted process that runs `+keep` again on the same wire
gets a fresh bond and overwrites the stored wire with the same one; a
process that does not is still registered and still receives news it no
longer takes. So a process either re-keeps on every start, as above, or
asks `+get-kept` what it is still registered for and drops what it no
longer wants.

```hoon
;<  ~  bind:m  (drop:io /watch road)
```

A `+drop` ends with the `%fell` on the wire, and no news arrives on it
after that.

## Cross-ship

A lane whose path begins `/sys/ames/ships/<ship>/root/` names a place in
another ship's tree. `+resolve-remote`
recognizes that prefix and splits it into the ship and the lane as that ship
sees it.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 3410-3421
```

### The subscriber's side

When a `%keep` resolves to a remote lane, the kernel registers the watcher
locally under the namespaced lane, exactly as for a local one, and then
forwards a `%keep` load to the peer instead of enqueuing a news itself. The
bond is the peer's to send.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 3505-3515
```

> [!note] The bond depends on the peer
>
> `+keep` waits on `+take-bond` with nothing else to end the wait. For a local
> lane the kernel answers in the same event. For a remote lane the answer is
> a poke from the other ship, and a peer that is down or refuses sends none,
> so the fiber sits on the bond with nothing logged. A caller following a
> remote lane can arm a timer and take whichever comes first.

### The publisher's side

On the peer, the `%keep` load arrives with the subscriber's ship.sig as the
caller. `+process-keep` gates it like a read against the weir computed for
that ship, then `+keep` registers the ship.sig as a watcher of the lane,
builds the wave, and pokes it back as an `$intake`.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1149-1155
```

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1338-1349
```

From then on the publisher's `+notify` treats the ship.sig like any watcher:
its remote branch pokes each new wave to the subscriber.

### Delivery back

An `$intake` from the peer carries the lane as the peer named it. `+process-intake`
puts the ship prefix back on to recover the namespaced lane, looks up its
local watchers in `fwd`, and delivers a `%news` to each. Two things happen on
the same path as delivery: a watcher whose grub is gone is dropped, and if
that leaves no watchers at all, the kernel sends the peer a `%drop`, so
cross-ship cleanup rides delivery the way local self-healing does.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1467-1491
```

### What a peer never answers

A `%drop` on a remote lane removes the local registration and forwards a
`%drop` load to the peer, which removes its side with `+process-drop`. No
intake comes back.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 3525-3534
```

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1158-1162
```

> [!note] Wart: the fell never arrives
>
> `+drop` waits on `+take-fell`. On a local lane the kernel enqueues the
> `%fell` itself. On a remote lane, in the code above, nothing does: the
> peer does not answer a drop, and the local branch that enqueues the fell
> is not reached. The dropping fiber waits forever. The remote path should
> enqueue the `%fell` locally too; the local registration is already gone.

## Cleanup

### On death

When a grub is deleted, `+sub-wipe` reads its lanes from `rev` and removes
each registration from both indices. It is called from `+delete`, so a dead watcher does not linger in `fwd`; the
self-heal in delivery covers the case where one does.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 3113-3123
```

### On a weir change

Setting a weir re-checks every subscription whose watcher sits under it.
Any that the new weir would now refuse as a read is felled: removed from
both indices, and its watcher gets a `%fell` on the wire it kept with. The
walk is `+audit-weir`; the per-subscription step is here.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 3253-3260
```

### Client channels

A client outside the ship, on the agent's channel surface, can keep a lane
too. The watcher is the client's ship.sig and the wire is the channel id;
`+notify`'s client branch turns each wave into a fact on that channel.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 972-989
```

When the channel leaves, `+drop-client-keeps` removes every registration that
carries its wire.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 912-925
```

> [!note] Wart: one entry per ship, not per channel
>
> `fwd` keys watchers by `$rail`, and every channel of one ship has the same
> ship.sig rail. Two channels of one ship keeping the same lane share one
> entry, and the second registration overwrites the first's wire.
