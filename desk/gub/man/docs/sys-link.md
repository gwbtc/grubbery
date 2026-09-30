# /sys/link

A name resolves to places. `/sys/link/<name>/dest.lanes` holds the set
of app roots that claim the name, so a peer, local or remote, can keep a
name and learn where its app lives. The kernel lays out the directory
and nothing more; the shell builds the registry from every app's
`link.json`, rewrites a name's grub only when its set changes, and culls
names nothing claims. Which ships may read a name is a usergroups grant
the shell makes per shared alias (see [Permissions](#permissions.md)).

```live
/grubbery/lib/root.hoon 69-71
```

```live
/grubbery/gub/nex/shell.hoon 2748-2763
```

```live
/grubbery/gub/nex/shell.hoon 3187-3218
```

> [!note] Wart: the comment says the build is a poll
> The comment over `+build-links` says driving it by subscription is not
> built. The followers under the shell's `/sync` keep each app's
> `link.json` by subscription and rebuild on news, as the layout comment
> over `/sync` says. One of the two comments is stale.
