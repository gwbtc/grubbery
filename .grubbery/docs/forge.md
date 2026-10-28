# Forge and the git nexuses

A git repository is a directory. Its packs, refs, `HEAD`, index, and loose
objects are grubs under `/data`, its working tree is `/data/tree`, and
checking out is the `/data` nexus's `+on-load`: given the objects and
`HEAD`, and at most one pending request file, it applies the request,
materializes the tree, and rebuilds the views, so a reload at any moment
yields a consistent working tree. Above it, the `/git/repo` nexus owns the
remote: one serial command lane takes git verbs as pokes, runs them one
at a time, and writes request files or fetches packs. Above that, Forge
is the one page over every repo instance, and the shell's stock mirrors
are repo instances a desk follows. So git on the ship is three nexuses
nested by containment, the wire formats are real git, the on-disk layout
is the tree's own, and nothing outside the ship ever reads it with a git
binary.

## Three nexuses

Forge houses repos at `/repos/<name>.git_repo`. A repo instance holds
its config, the command lane, the poll daemon, and a `/data` child with
the `[/git %data]` neck. Transport stays in the repo; the data nexus
never talks to the network.

```live
/desk/gub/nex/git/forge.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 60-82
```

```live
/desk/gub/nex/git/repo.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 22-45
```

```live
/desk/gub/nex/git/data.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1-11
```

## The object store as grubs

Packs land as mime with a text index beside each; refs are one file per
branch, local and remote-tracking; `HEAD` is a symbolic ref or a bare
hash; the index and reflogs are text in the ship's own line formats. The
header marks which encodings are git's and which are internal.

```live
/desk/gub/nex/git/data.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 13-47
```

The repo nexus rebuilds a `$repository` from those grubs when it needs
one: packs from the pack directory, refs from the heads directory, loose
objects from `/data/objects`. No pack means no clone yet.

```live
/desk/gub/nex/git/repo.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 898-924
```

> [!background] The on-disk layout is not git's
> The pack index, the index file, and the reflogs are line-oriented text
> the data nexus writes for itself; git's are binary. They work because
> nothing outside the ship reads them. Interop with real git happens at
> the wire, where the packs, refs, and objects are git's own formats.

## Checkout is a reload

The data nexus's `+on-load` is the only place git state changes. It
loads the packs, parses `HEAD`, reads the refs and loose objects, and
then looks for a request file: a stash, a stash pop, an add, or a
commit, each written by the parent and consumed here. With no request it
checks out.

```live
/desk/gub/nex/git/data.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 56-78
```

A checkout happens exactly when `HEAD` moved. `TREE-HEAD` records the
commit the tree was last materialized from; when it matches, the working
tree and the staged index are preserved and only the derived views are
rebuilt. Without the marker a reload would reset every edit.

```live
/desk/gub/nex/git/data.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 310-350
```

```live
/desk/gub/nex/git/data.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 370-386
```

Everything under `tree/` must be a mime grub, since a blob with any other
mark would crash the next add or commit and take the nexus inert; a grub
that lands there with another mark removes itself.

```live
/desk/gub/nex/git/data.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 352-368
```

The commit request reads the index as staged, builds trees and a commit
through the library, advances the branch ref or `HEAD`, appends the
reflog, moves the marker with `HEAD` so the tree is preserved, and
rebuilds the views.

```live
/desk/gub/nex/git/data.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 240-308
```

## The command lane

A repo has one working tree, one index, one `HEAD`, so git operations
must not interleave. `run.git-action` is one stateful grub at the repo
root: poke it a command string, and its fiber parses the verb, marks the
job active, runs it to completion, and appends the outcome to a log.

```live
/desk/gub/lib/git/action.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1-53
```

```live
/desk/gub/nex/git/repo.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 47-83
```

```live
/desk/gub/nex/git/repo.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 136-157
```

The verbs that change the working tree write a request file into
`/data` and reload it, so the data nexus does the git work. Add and
commit are that shape. Checkout refuses a dirty tree, writes `HEAD`, and
reloads.

```live
/desk/gub/nex/git/repo.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 290-336
```

```live
/desk/gub/nex/git/repo.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 256-289
```

## Pull

A pull is discovery, then either an incremental fetch or a full clone. An
empty ref in config means the remote's default branch, resolved from the
discovery capabilities and pinned into config. With a repository already
loaded, the hashes it holds are the haves and the refs it lacks are the
wants; the new pack is saved in the next slot and the data nexus
reloaded.

```live
/desk/gub/nex/git/repo.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 337-427
```

The wire goes through the GitHub nexus: one call grub per exchange, kept
until it finishes, then culled. The repo's configured account rides
along.

```live
/desk/gub/nex/git/repo.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 973-1011
```

```live
/desk/gub/nex/git/repo.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 788-828
```

## Push

A push walks the commit chain from the local ref back to the remote
tracking ref and replays each commit through the GitHub API: blobs, then
a tree, then the commit, then the ref. It refuses without a connected
GitHub account and without an account chosen for the repo.

```live
/desk/gub/nex/git/repo.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 428-496
```

## Poll

`poll.json` is the sync daemon. Its fiber pulls once at rise, keeps its
own grub for the interval, and then pokes `pull` on the lane every
`minutes`; zero parks it until the interval is set.

```live
/desk/gub/nex/git/repo.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 84-122
```

> [!note] Wart: the shell seeds the cadence where the daemon does not read it
> The config the shell writes into a stock mirror carries a `poll` field,
> and the daemon reads `minutes` from `poll.json`, seeded at zero. Nothing
> copies one to the other, so a stock mirror pulls only when something
> pokes it. The shell should set `poll.json` when it stands a mirror up.

## Forge

Forge is the page. Its request fiber serves a static shell and a set of
JSON routes: the fleet, one repo's detail, a file's source, the stock
catalog; and POSTs that create, delete, configure, edit a file, or run a
command, each a make, over, or poke at the repo instance.

```live
/desk/gub/nex/git/forge.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 100-138
```

The fleet is read from each repo's config, poll, and current-commit
views; a repo's detail is the data nexus's `ui` outputs plus the lane's
state, read as they are. Forge keeps no view of its own.

```live
/desk/gub/nex/git/forge.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 269-346
```

Creating a repo makes the instance with the `[/git %repo]` neck, gains
it, stamps Forge's identity defaults into its config, and pokes a first
pull when a remote is given. The stock catalog is a list of such creates.

```live
/desk/gub/nex/git/forge.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 347-389
```

```live
/desk/gub/nex/git/forge.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 178-190
```

Forge mounts a tools instance (see [The tools nexus](#tools.md)) whose
`git_cmd` runs a command through any repo's lane, and whose
`deploy_to_desk` writes a tree into a Clay desk.

```live
/desk/gub/nex/git/forge/tool-bundle/tools/git-cmd.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1-23
```

## Stock mirrors

The shell provisions its default desks the same way: for each stock
entry it ensures a repo instance under Forge with the right remote,
pokes a pull, ensures a desk, and points the desk's source at the repo's
checked-out `code` directory. From there [Desks](#desks.md) owns the
version watch, the sync, and the bill.

```live
/desk/gub/nex/shell.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1874-1899
```

```live
/desk/gub/nex/shell.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1900-1956
```
