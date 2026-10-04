# A read in flight

A peek does not answer with content. It answers with a `$cite` naming the ject
it resolved, and the bytes are pulled only when the fiber consumes the answer.
Between the two the ject could be tombed out from under the reader, so the read
holds a reference to it the whole way across: bumped when the answer is queued,
released when the read is consumed. This page follows that one reference, from
the peek's answer to its release. The [content-addressed store](#silo.md) counts
the read as one of its owners; [Fibers](#fibers.md) carries the answer as a
queued take and decides when it is consumed; the reference is the thread between
them.

## The cite and the take

A `$cite` names what a peek resolved, not the bytes: a `%file` or `%ball` cite
carries the lobe of a ject, a `%peep` a set of them. The answer reaches the
fiber as a [take](#fibers.md) — a queued pend holding the cite until the fiber
consumes it. While the take waits, the store keeps the cite's ject alive on the
read's behalf, under the one rule every owner obeys: a release is the exact
inverse of a bump by the same owner.

## Bumped when queued

When a peek resolves to a live revision, the kernel bumps the ject's reference
and enqueues the take that carries the cite — the bump the rest of this page
accounts for.

```live
/grubbery/app/grubbery.hoon 3686-3690
```

A cross-ship peek bumps at the same point, once its content has arrived and the
discharged cite is enqueued.

```live
/grubbery/app/grubbery.hoon 843-883
```

## Resolved at consume

The take is offered to the fiber by `+take`, one step of the eval loop, which
hydrates the pend into an intake at the moment of consumption — cite to content,
right as the fiber's form runs on it.

```live
/grubbery/app/grubbery.hoon 4137-4141
```

`+hydrate` does that resolve, and releases the cite's reference as it reads.

```live
/grubbery/app/grubbery.hoon 4067-4069
```

## Skipped, and offered again

A fiber need not consume the answer when it is offered. Returning `%skip` parks
the take on the process's skip queue and moves on to the next one.

```live
/grubbery/app/grubbery.hoon 4224-4237
```

A later `%cont` empties the skip queue back onto `next`, so every parked take is
offered once more — and hydrated again.

```live
/grubbery/app/grubbery.hoon 4198-4207
```

> [!note] Wart: the reference is released per offer, not per read
> The queue bumps a cite's ject once, but `+hydrate` releases it on every
> offer, and a skipped take is offered again on each wakeup, so one bump meets
> many drops. While the ject is absent the surplus drops are no-ops; once
> identical content re-creates the shared, content-addressed leaf, they carry
> it to zero and delete it, and a version elsewhere that shares those bytes
> booms when it is read. The release belongs at the one consume.
> `+drop-pend-refs` already does that inverse drop when a parked take dies
> (below); the same release, run when a take is consumed and taken out of
> `+hydrate`, is what the per-offer drop should become.

## Released on death

If the process dies with takes still parked — a crash, or a reload that replaces
it — `+nack-poke-takes` walks what is left in the skip queue and nacks each
pending poke.

```live
/grubbery/app/grubbery.hoon 2738-2745
```

`+drop-pend-refs` releases the references those parked takes still hold: a
`%file`/`%ball` cite's lobe, or a `%peep`'s whole set. It is the exact inverse
of the queue bump — the grave end of the reference's life.

```live
/grubbery/app/grubbery.hoon 2748-2764
```
