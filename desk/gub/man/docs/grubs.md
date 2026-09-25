# Grubs & the namespace

A **grub** is one file in the namespace: a path, a name, and a **blot** —
its content plus a **mark** (its type). Marks are what let the system
convert a grub on the way out — the kernel's file API serves a `.hoon` grub
as text by running its mark's `mime` tube.

The **namespace** is the shared tree of every nexus's grubs. It's
content-addressed, so identical content is stored once and dedup'd across
the whole system. Crucially it *is* the state — there is no separate agent
heap to migrate when a type changes.

## Two tiers: record vs cache

Not all state is equal, and grubbery keeps a hard line between:

- **System of record** — authoritative state, the truth. Lose it and you
  lose data.
- **Cache** — derived, rebuildable state. Lose it and you recompute it.

The convention is to keep them in *separate sibling grubs* so the tiers are
legible at a glance. The shell nexus does exactly this: consent records live
under `/permit`, rebuildable views under `/cache`. That split is a design
rule, not a suggestion — it's how you know, staring at an `on-load`, what's
precious and what's disposable.

## %fall vs %over encode lifecycle

The two loader verbs aren't just "seed" and "write" — they declare who owns
a grub:

- **`%fall`** = "owned at runtime; seed once." Record tier, or anything a
  user or editor mutates.
- **`%over`** = "defined in code; overwrite." Assets, and content with no
  runtime editor yet.

## Reading a grub

From inside a fiber you `peek` a grub by its road, optionally casting to a
mark:

```hoon
;<  jon=(unit json)  bind:m
  (peek-as:io (nex-road:io rail [%& /cache %'weirs.json']) ,json)
```

A `~` back means "nothing there" — a clean miss the reader handles, not an
error.

_TODO: content-addressing internals; the blot type in depth; marks and
tubes; cross-nexus and cross-ship peeks._