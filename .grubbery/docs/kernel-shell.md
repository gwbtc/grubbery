# The kernel and the shell

Grubbery is one Gall agent and a tree of nexuses running inside it. The
agent is the kernel: it keeps the namespace, routes darts, enforces weirs,
builds code, and runs fibers. It knows no application; it does not know
what a home screen, a permission, or an installed app is. The shell is one
nexus among the others, born by the root nexus at `/apps/shell.shell` with
no privilege the kernel can name. It is where a person meets the ship, and
it is the set of files an app lays out to be met there: a name, an ask, a
tile, a notification. The kernel enforces; the shell decides. So the
operating system is small and fixed, and the part that makes it usable is
code like any other, replaceable without touching the kernel.

## The kernel

The agent imports the libraries every nexus compiles against and the
marks it needs to exist at all, and carries the root nexus compiled in.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1-11
```

The root nexus is the kernel's own layout. It carries the existing tree
forward, keeps `/apps` open, lays out the `/sys` services, and creates
each built-in as a directory with its neck. The shell is one row in that
list, between the tiles store and the counter.

```live
/desk/lib/root.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 36-49
```

```live
/desk/lib/root.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 77-89
```

The one process the root nexus runs itself is the request fiber for the
kernel's HTTP file API (see [The ball](#ball.md)). Everything else that
answers a person runs in a nexus.

```live
/desk/lib/root.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 96-111
```

> [!note] Wart: the root nexus changes only with the kernel
> `root.hoon` is compiled into the agent, so an edit to the root layout
> takes effect on the next agent build, not on the next write. The TODO
> at the top of the agent says so. The root nexus should be reloaded at
> `/` when its source changes, as every other nexus is when its
> namespace rebuilds.

## The shell

Every built-in lives under `/apps` with no weir, the shell included. The
shell's ability to fence other apps comes from nothing more than that:
its climb from `/apps` crosses no fence, so its make-kind darts reach any
app's directory. See [Permissions](#permissions.md) for the sand.

```live
/desk/lib/root.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 4-9
```

```live
/desk/gub/nex/shell.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1-13
```

Its tree is in two tiers, the way [The namespace](#namespace.md) sorts
grubs: what the user decided, under `/permit`, which nothing rebuilds; and
what is derived, under `/cache`, `/docs/mirror`, `/docs/cache`, `/sync`,
and `/share`, which a follower or a fiber rebuilds and losing costs
nothing. Installed desks live under the shell at `/desks`, because they
need permission management and built-ins do not.

```live
/desk/gub/nex/shell.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 38-46
```

```live
/desk/gub/nex/shell.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 61-81
```

```live
/desk/gub/nex/shell.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 100-135
```

> [!note] Wart: the layout comment says the views are never materialized
> The comment over `/permit` says the asks, aliases, and weirs views are
> computed live per request and never stored. Three rows below it seed
> them as grubs under `/cache`, and the followers rebuild them. The
> comment should say what the rows do.

The main fiber binds two HTTP prefixes, the home page and the tile
store, and dispatches each request to a fiber under `/requests`, the
pattern every nexus with a page uses.

```live
/desk/gub/nex/shell.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 156-161
```

```live
/desk/gub/nex/shell.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 437-447
```

## The patterns

An app becomes visible by laying out files at its root. The shell reads
them; the app never pokes the shell. Each file is a `%over` row in the
app's `+on-load`, so the code is the truth of it and a reload re-declares
it.

```live
/desk/gub/nex/github.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 26-48
```

### A name and an ask

`link.json` names the app; `weir.json` says what it wants to reach. A
name grants nothing and needs no consent; an ask is consented to as a
unit, and the shell writes the app's weir from the answer.
[Permissions](#permissions.md) is the whole of that.

### A tile

`tile.json` puts the app on the home page: title, info, color, image,
href. The shell walks every app root, reads the file, and uses a sibling
`icon.*` file as the image when there is one, served from the tile store
by the app's path.

```live
/desk/gub/nex/shell.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 2597-2637
```

An app with no `tile.json` is not on the home page. The notifications
nexus has none on purpose: the inbox is chrome, rendered as the bell, not
a tile.

```live
/desk/gub/nex/notifications.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1-13
```

### A notification

The bus is a sibling nexus, not the shell. An app registers once, which
covers its whole subtree, then pokes notifications; the service owns
delivery, acks, and the inbox page; the shell renders the bell. The library gives the
two pokes.

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1711-1738
```

### A page

A nexus that serves a page binds a prefix from a long-lived fiber and
lets the kernel spawn a request fiber per hit into its `/requests`
directory; the request fiber reads the request from its own state and
answers. The shell's main fiber is one instance of it.

```live
/desk/gub/nex/notifications.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 47-68
```

### Being found

An installed desk says which usergroups may see it in `share.usergroups`;
the shell derives `/share/<group>/desks.json` from those and registers
the discovery roads into the groups. A desk install pokes the shell's
`sweep.sig` after applying its bill, so the new app gets a follower and
its ask is surfaced at once.

```live
/desk/gub/nex/shell.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 82-99
```
