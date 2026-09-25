# Fibers

A **fiber** is grubbery's unit of work: a monadic process that reads and
writes the namespace, binds HTTP, peeks other nexuses, waits on timers —
and, the whole point, **restarts cleanly from state** at any moment.

## The monad

Open a fiber by naming its result type, sequence effects with `;< … bind:m`,
finish with `pure:m`:

```hoon
=/  m  (fiber:fiber:nexus ,~)
;<  now=@da         bind:m  get-time:io
;<  ~               bind:m  (bind-http:io [~ /apps/grubbery])
;<  wv=(unit json)  bind:m  (peek-as:io road ,json)
(pure:m ~)
```

Each `;<` line is one step: run the effect on the right, bind its result on
the left, continue. Reads, writes, time, HTTP — everything sequences the
same way, and the main arm reads top-to-bottom as the action it performs.

## Roads and weirs

A **road** names a location in the namespace —
`(nex-road:io rail [%& /dir %'file'])` addresses a grub relative to the
nexus. A **weir** is a *capability*: the set of reaches a nexus declares it
may make. Reaching outside your declared weir is refused — that's how
cross-nexus and cross-ship reads stay safe without per-call auth checks.

> An empty weir `{}` means "declared, with no holes"; an *absent* weir `~`
> means "no filter at all." That's a real, intentional distinction — not a
> typo to paper over.

## The restart contract

The load-bearing invariant: **reboot at any time, recover from state.** A
fiber isn't a long-lived thread you must keep alive — it's derived from the
namespace, so the runtime can restart it whenever and it resumes from where
the state says. This is why grubbery treats restarts as ordinary rather than
hazardous, and why a loud crash is a *bug report*, not corruption to hide.

_TODO: timeouts and `%timer-rest`; `poke` / `poke-soft`; the fiber
code-style conventions (one-line binds, helpers in a bottom core)._