# Permissions

The kernel enforces weirs, as [Sandboxing & weirs](#weirs.md) describes:
a dart climbing out of a directory is refused unless that directory's weir
names its destination. Something has to decide what an app's weir says,
and for an installed app that is the shell. The app writes what it wants
into its own tree; the user consents, or not, in the shell; the shell
sands the weir. The kernel never decides and the shell never enforces.
Three things write weirs on this ship: a desk, which births each app it
installs behind a fence with no gates; the kernel, which sets a foreign
ship's weir from [usergroups](#usergroups.md); and the shell, which is the
only thing that changes an app's weir after birth. What follows is the
shell's side: what an app declares, what the shell records, how consent
becomes a weir, and how the shell keeps its picture current.

## Two tiers

Every built-in nexus lives directly under `/apps` with no weir: the
trusted tier, filtered by nothing. The root nexus resets `/apps` to that
open state on every load, because a fence there would hold the shell too,
and the shell is what removes fences.

```live
/grubbery/lib/root.hoon 4-9
```

```live
/grubbery/lib/root.hoon 42-47
```

An app installed from a desk is born the other way: its directory gets an
empty weir, `[~ ~ ~]`, the fence with no gates. The nexus still lays out
its own tree, since that rides the make rather than a dart, but its fibers
can reach nothing outside until the shell has approved its ask.

```live
/grubbery/gub/nex/desk.hoon 586-592
```

## What an app declares

### The ask

An app's ask is `weir.json` at its root: three lists, `poke`, `peek`, and
`make`, each line a road, or an object with the road, a `why`, and an
`optional` flag. A road may name another app by alias, `@name`, with a
sub-path after it. The ask is consented to as a unit.

```live
/grubbery/gub/nex/shell.hoon 3273-3298
```

```live
/grubbery/gub/nex/shell.hoon 3315-3327
```

An app root is a direct child of `/apps`, or an app under an installed
desk's `desk/data`; both count.

```live
/grubbery/gub/nex/shell.hoon 2621-2644
```

> [!note] Wart: a dormant root instance is a permanent ask
> When an app's code moves from `/apps/X` into a desk and its data is
> carried over, the old `/apps/X` stays behind with its `weir.json`. Both
> roots are listed, so the dormant one is a pending ask nobody can act on,
> on every ship that ever migrated an app. The scan should skip a root
> instance when a desk-installed one of the same name exists.

### The name

An app names itself in `link.json`: a name, or several, and a description.
A name grants nothing, so it needs no consent; it becomes an option in
that name's menu. The user can hide an option, which drops it from
resolution.

```live
/grubbery/gub/nex/shell.hoon 2650-2691
```

```live
/grubbery/gub/nex/shell.hoon 2693-2716
```

## What the shell records

The shell holds its state in two tiers of its own. Under `/permit` is what
it has decided: `approved.json`, one record per app; `hidden.json`, the
suppressed options; `notified.json`, the asks it has already told the user
about; `share.json`, which aliases are visible to which ships. Under
`/cache` are views it rebuilds from those and from the apps: `asks.json`,
`aliases.json`, `weirs.json`.

```live
/grubbery/gub/nex/shell.hoon 61-81
```

An approval record holds the granted subset, the full ask it ruled on as
`declared`, the alias bindings it resolved, a verdict, and a time. The
`declared` snapshot is what lets a partial grant settle an ask instead of
re-asking.

```live
/grubbery/gub/nex/shell.hoon 3408-3428
```

## Consent

### Approve

Approval takes the granted subset of the ask, resolves each `@alias` to
the option the user picked or the first one, and sands the app's directory
with exactly those roads: a replacement, not a union, so any drift is
wiped. The sand is a make-kind dart from the shell, and the shell's own
climb from `/apps` crosses no fence, which is why the shell can do this
and an app cannot. It writes `grant.json` into the app's root, the
resolved roads and the alias map, so the app can read what it holds. Then
it records the approval and reloads the app, so fibers that crashed while
jailed rise holding their grants.

```live
/grubbery/gub/nex/shell.hoon 3542-3599
```

The shell never reads `grant.json` back. It lives in the app's tree, where
the app can rewrite it; the record the shell trusts is `approved.json`,
which the app cannot reach. An app that edits its own grant file changes
neither its history nor its access, since the access is the weir.

### Deny

A denial records the ask with an empty grant and no sand. The app stays as
it was, and stops prompting until it declares something different.

```live
/grubbery/gub/nex/shell.hoon 3601-3613
```

### Settled

An ask is settled when the app's current `weir.json` matches the
`declared` snapshot in its record, road for road, order aside. A settled
ask is never re-surfaced; a changed one is a new ask.

```live
/grubbery/gub/nex/shell.hoon 2380-2400
```

### Unresolvable references

An `@alias` with no option, or only hidden ones, cannot be granted. The
asks view marks those references, the page shows them disabled, and
approval refuses them rather than dropping them.

```live
/grubbery/gub/nex/shell.hoon 3615-3627
```

## The views

The three caches are rebuilt by diff-then-write: compute the view, compare
to the stored grub, write only on change.

```live
/grubbery/gub/nex/shell.hoon 3252-3271
```

The weirs view is the honest one: for each approved app, its record laid
over the weir actually on its directory, read from the parent's entry the
way the kernel reads it. A granted road present on the weir is `active`;
granted but absent is `missing`; declared but not granted is `denied`; on
the weir but never granted is `unmanaged`. The two kinds of drift are
`missing` and `unmanaged`; `denied` is a choice.

```live
/grubbery/gub/nex/shell.hoon 3437-3447
```

```live
/grubbery/gub/nex/shell.hoon 3471-3509
```

## Keeping it current

### Followers

The shell does not watch `/apps`. For each app root it spawns a follower
grub under `/sync` that keeps exactly three files: the app's `link.json`,
its `weir.json`, and, for a desk, its `share.usergroups`. On news the
follower notifies if the ask is unsettled and rebuilds the views; if the
app is gone, it drops the app's records so a reinstall asks fresh, and
cleans itself up.

```live
/grubbery/gub/nex/shell.hoon 371-420
```

New apps get followers from a sweep, a pass over every app root that
spawns what is missing. The sweep runs on a poke to `sweep.sig`, which a
desk install sends after applying its bill.

```live
/grubbery/gub/nex/shell.hoon 3067-3105
```

### Telling the user

An unsettled ask is pushed to the notifications nexus once. `notified.json`
holds the ask that was last surfaced per app, so a reload does not re-ping;
a changed ask fails the match and pings again.

```live
/grubbery/gub/nex/shell.hoon 3225-3245
```

## The routes

The page reads the caches and `approved.json` through four JSON routes and
sends every action as one POST, which applies it to the `/permit` grubs
and rebuilds the caches before answering.

```live
/grubbery/gub/nex/shell.hoon 453-466
```

```live
/grubbery/gub/nex/shell.hoon 620-654
```

> [!note] Wart: the routes do the slow work in front of the user
> `GET /permits` runs the follower sweep, the share rebuild, and a lazy
> cache seed before it serves a static file; `POST /permits` rebuilds all
> three caches, a round trip per app each, before it answers. Both grow
> with the number of apps: ten to twenty seconds to open the page and
> seven seconds of dead time per click on an eight-app ship. Moving the
> work after the send changes nothing, because a response is released
> only when the request fiber finishes. The page should ask for that work
> itself, in a separate request after it renders and after each action,
> and the reload after a grant should be its own request too.

## Sharing with other ships

What another ship may read here is decided by usergroups, and the shell
is a registrant like any nexus: at rise, `usergroups.sig` registers its
own rail, claiming the shell's directory as its prefix. From then on it
keeps every group's grant current with one `%how` per group. The public
group always gets the two roads other ships need to discover this ship's
desks, `public.json` and `/share/public/desks.json`, both under the
shell. Each group named in `share.json` also gets the `/sys/link` road of
every alias shared with it. It recomputes on any change to `share.json`
or to the public group's weir.

```live
/grubbery/gub/nex/shell.hoon 255-300
```

> [!note] Wart: the alias shares lie outside the shell's prefix
> A `%how` is accepted only if every road in it sits under the
> registrant's claimed prefix, and the shell's prefix is its own
> directory under `/apps`. The two discovery roads do; a `/sys/link`
> road does not. So a group that shares an alias gets its whole `%how`
> refused, discovery roads included, with one line logged. Either the
> link roads need a registrant whose prefix covers `/sys/link`, or the
> alias shares need to be expressed as something under the shell.

The `/sys/link` registry itself is built from the alias directory: one
`dest.lanes` grub per name, holding the roots of every app that claims it.

```live
/grubbery/gub/nex/shell.hoon 3156-3189
```
