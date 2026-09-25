# The Grubbery Handbook

Grubbery is a general-purpose application model for Urbit. A stock Gall app
is one agent holding one big state noun, migrated by hand every time that
shape changes. Grubbery takes the opposite bet: an application is a set of
small **nexuses** composing over a shared **namespace** of content-addressed
**grubs**, and all their work runs as restartable **fibers**. State doesn't
live in an agent heap — it lives in the namespace, versioned and portable,
and code reads it back on demand.

Three nouns carry the whole model:

- **Nexus** — the unit of an application. Declares what lives in its slice
  of the namespace, and answers requests against it.
- **Grub** — the unit of state. One content-addressed file carrying a mark
  (its type).
- **Fiber** — the unit of work. A monadic process that reads and writes the
  namespace and can be rebooted at any point.

## Why bother

The payoff is how it scales. A monolithic agent gets *harder* to extend the
bigger it grows — every feature entangles with one state and one event
handler. Nexuses compose instead of entangle, so the next feature reuses
primitives rather than thickening a core. And because state *is* the
namespace, the two worst Gall taxes — hand-written migrations and cross-ship
auth boilerplate — mostly evaporate.

## Where to start

- [Nexuses](#nexuses.md) — the unit of an application
- [Grubs & the namespace](#grubs.md) — where state actually lives
- [Fibers](#fibers.md) — how work gets done

## This handbook is live

> These pages are markdown grubs served by the shell nexus, and they quote
> source **straight from the running ship** — no copy-paste, so a snippet
> can't drift from the code it describes.

Here is a whole nexus helper lib, read live from the namespace through the
kernel's own file API and highlighted in place:

```live
/gub/lib/shell.hoon
```