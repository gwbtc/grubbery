# Fibers

A fiber is the process that runs beside a grub's file. It is a function from
one input to one output: it takes a message, produces effects and a new
state, and says what it wants next. The kernel holds the queue of messages,
runs the function on each, applies the effects, writes the state back into
the file, and rebuilds the function from the file whenever it fails or the
agent reloads. So a fiber never owns its own continuity. The file is the
state; the process is derived from it; and a process that recovers from its
file alone is a process the kernel can restart at any time.

## A process and its inputs

### The form

A running fiber is a `$form`: a gate from `$input` to `$output`. The input
is the grub's current state as a vase, and maybe one message. The output is
a list of darts to send, the state to keep, and a verb saying what to do
next: wait for the next input, skip this one, continue into another form,
finish with a value, or fail.

```live
/desk/lib/nexus.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 305-313
```

```live
/desk/lib/nexus.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 325-344
```

One invocation is the unit of work, and it is atomic. On `%wait`, `%skip`,
`%cont`, or `%done`, everything the invocation produced stands: the darts go
out, the state is kept. On `%fail` the invocation contributes nothing but a
nack; its darts and state are discarded, and every prior invocation's
contribution stands.

```live
/desk/lib/nexus.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 315-324
```

A `$process` is a form whose final value is `~`, and a `$spool` is what a
nexus hands the kernel for a grub: a gate from a `$prod` to a process. The
prod is `~` on a clean start and a tang on a restart after a crash, so the
process can tell which it is.

### Darts

A dart is an effect a fiber yields. `%node` carries a `$load` to a road: a
poke, a make, a peek, a cull, a subscription, and the rest. `%here` asks
where the fiber is; `%kept` asks what it watches. Each dart names a `wire`
the fiber chose, and the answer comes back on the same wire.

```live
/desk/lib/nexus.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 104-132
```

A road is relative. A fiber does not know its absolute position in the
tree; it addresses other grubs by steps up and a lane, a `$bend`, and it
sees the sender of a poke the same way.

```live
/desk/lib/nexus.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 254-256
```

### Intakes

An intake is a message a fiber receives: a poke from another grub, the
answer to a dart it sent, a subscription wave, a fell, or a veto saying a
dart was refused by a weir on its way (see
[Sandboxing & weirs](#weirs.md)). Every answer carries the wire of the
dart it answers.

```live
/desk/lib/nexus.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 258-282
```

The kernel does not queue intakes in this form. It queues a `$pend`, the
same message with every vase replaced by what names it: a poke's payload as
a `$bask`, a peek's result as a `$cite`, a code lookup as a hash. The vase
is rebuilt at the moment the fiber consumes the message, so a message that
waited across a code reload is typed against the code that runs now, not
the code that queued it.

```live
/desk/lib/nexus.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 283-304
```

> [!note] Wart: a done TODO in the header
> The header of `fiberio.hoon` carries a "TODO: vase-free queue storage"
> describing exactly the `$pend` form above as work to be done. The types
> show it done. The comment should go.

### The take queue

A `$take` is one queued pend with, for a poke, the return address to ack
it to. Each grub's process sits in a `$proc` with two queues: `next`, the
takes waiting to be consumed, and `skip`, the takes the process declined
and set aside. The procs of a directory's grubs sit in its `$pipe`, and the
pipes form a `$pool` shaped like the tree.

```live
/desk/lib/nexus.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 243-253
```

```live
/desk/lib/nexus.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 391-392
```

## Composing steps

### bind and pure

A fiber program is written as a chain of forms. `+pure` is a form that
finishes at once with a value and touches nothing. `+bind` runs one form
and, when it finishes, hands its value to a gate that produces the next
form; every other verb passes through unchanged, so a wait in the middle of
a chain is a wait for the whole chain.

```live
/desk/lib/nexus.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 346-389
```

`+stay` is the form a grub gets when its nexus defines no handler: it waits
on start and fails on any real input, so a poke into a handlerless grub
nacks instead of vanishing.

The `;<` rune is `+bind` with the result bound to a face, which is how a
chain reads in source: one line per step, the effect on the right, its
result on the left.

```hoon
=/  m  (fiber:fiber:nexus ,~)
;<  ~              bind:m  (make:io road |+[[[/ %json] json] ~])
;<  =view:nexus    bind:m  (peek:io road ~)
(pure:m ~)
```

### Sending and taking

A step that sends a dart is a form that emits it and finishes; a step that
waits for the answer is a form that returns `%wait` until an intake on its
wire arrives, `%skip` for any other intake, and `%done` with the answer.
Every verb in the library is those two forms bound together.

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 62-77
```

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 325-341
```

The wire is tagged with entropy by `+nonce` before the dart goes out, so an
answer to a dart sent by an earlier run of this fiber, before it crashed and
restarted, does not match the wire the new run is waiting on.

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1544-1549
```

### The verbs

Each file operation is that pattern with its load: `+make` creates a grub
or directory, `+cull` deletes one, `+sand` sets a weir, `+peek` reads,
`+poke` sends a payload, `+keep` and `+drop` subscribe and unsubscribe,
`+over` overwrites, `+checkpoint` and `+tag` mark a version. `+make` shows
the shape whole.

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 342-349
```

`+poke` crashes the fiber on a nack; `+poke-soft` returns the nack, or the
veto, as a value. The answer to a poke is a `%pack` on the wire whether the
target is local or on another ship.

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 448-467
```

### State

The grub's file is the fiber's state, and the input carries it as a vase.
`+get-state` reads it, `+replace` and `+transform` write it. A write does
not touch the file directly: it sets the output's state, and the kernel
validates and stores it after the step.

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 89-96
```

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 120-137
```

## The driver

### Spawning

A grub's process comes from its nexus. The nexus's `+on-file` takes the
grub's rail, relative to the nexus, and its blot, and returns the spool.

```live
/desk/lib/nexus.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1412-1419
```

`+build-spool` finds the nearest ancestor directory with a neck, builds
that nexus, and calls its `+on-file`. `+spawn-proc-with` applies the spool
to the prod to get a live process, stores it, and enqueues an empty take so
the process runs its first step. A failure in either is a bang on the file,
covered below. Any takes an earlier process at that rail left in `next`
move to the new process's `skip`, so a fresh process is not fed messages
meant for the old one until it is ready.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 3321-3356
```

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 3898-3940
```

### One event

Everything that reaches a fiber goes through one queue on the agent,
`takes`, and `+enqu-take` is the only way in. At the end of every event
`+abet` drains it: pop a take, process it, repeat until empty. A step that
enqueues a take, for another fiber or for itself, runs it in the same event.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1803-1805
```

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1494-1500
```

`+process-take` puts the take on the grub's `next` queue and runs the
process. A take for a rail with no process nacks its poke, and a take for a
crashed process is queued without running, except a poke, which is nacked
with the crash.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 3946-4007
```

### The step

`+take` in the `+eval` core is one step: pop the next take, hydrate its
pend into an intake, run the form on the state and the intake, then act on
the verb. Two things can fail before the form runs, hydration and the form
itself crashing; both count as `%fail`. After a successful step the new
state is validated against the file's mark by `+clam-output`, and a state
that fails to validate is a `%fail` too.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 4128-4247
```

The verbs, as the step handles them:

- `%done` and `%wait` keep the darts and the validated state. `%wait` goes
  on to the next queued take if there is one, so one call to `+take` can
  run many steps.
- `%cont` swaps the process for the continuation and, before running it,
  moves everything in `skip` back to the front of `next`: a process that
  advanced may now want what it declined.
- `%skip` moves the take to `skip` and tries the next one. A null input
  cannot be skipped; that is a `%fail`.
- `%fail` returns the failing take with its error and stops.

### After the step

`+process-do-next` runs `+take` and then acts on the whole batch: sends
the darts, acks every consumed poke, and saves the state into the file. On
`%done` it saves the final state and deletes the grub; the process finished
its work, so the grub is gone. On `%fail` it saves the state the last
successful step left, since every completed step stands, then rebuilds the
process from its spool with the error as the prod and enqueues an empty
take so it starts again.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 4248-4332
```

A poke's ack is a `%pack` take to the sender's rail. If the sender could
not peek the target, a nack's tang is replaced by a generic one.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 2714-2722
```

### Restart

The restart is the spool applied to the prod. `+rise-wait` at the top of a
process makes the two starts differ: on a clean start it continues; on a
crash restart it logs the error and waits for a poke before doing anything,
so a process that failed does not re-run its failing step until someone
asks.

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 236-245
```

> [!note] Wart: a restart runs in the event that failed
> A `%fail` rebuilds the process and enqueues its start take, and `+abet`
> is still draining, so the restarted process runs its first step in the
> same event. A process that does not wait on restart and fails again for
> the same reason, a refused dart, a poison state, restarts again, in the
> same drain, without bound. The event never finishes and the ship answers
> nothing. The driver should cap restarts per event and park the fiber.

### Bangs

A bang is a process that cannot be built: `+on-file` crashed, the spool
crashed, or the nexus itself failed to build. `+bang-file` records the
error on the grub's proc and persists it into the grub's ject, so it
survives a reload and shows in the tree. `+bang-nexus` does the same for a
directory and every grub under it, then replaces every process below with
`+stay`. A banged nexus spawns nothing until it is reloaded.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 2459-2488
```

### Reload

A fiber's continuation is a function, and functions do not survive an agent
upgrade. `+on-save` bangs the whole pool, keeping each proc's queues,
and `+on-load` rebuilds every process from its nexus. `+spawn-all-files`
walks the tree, builds each nexus once at the directory that carries its
neck, and spawns every grub under it from that nexus's `+on-file`.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 116-122
```

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 2429-2449
```

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 2953-3010
```

This is the contract the nexus door states: a process recovers from its
state alone. The kernel guarantees the restart; the nexus guarantees the
recovery.

## Ending

A process ends in one of three ways. It returns `%done`, and the kernel
saves its state and deletes the grub, nacking whatever was still queued.
It is banged, and stays until a reload. Or its grub is deleted from
outside, and `+delete` drops its subscriptions, tombs the file, and removes
the proc from the pool.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 2669-2713
```
