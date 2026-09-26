# The substrate

The compiler doesn't work over raw paths and text. It works over a small
vocabulary of address and content types from `/lib/tarball.hoon`, laid out by
`/lib/loader.hoon`. This page is that substrate: what a file *is*, what a
directory *is*, and how a nexus's grubs get into the ball in the first place.

## Addresses: rail, road, lane, fold

Urbit's native path is flat. Grubbery layers a file/directory distinction on
top, plus an absolute/relative distinction for imports.

- **`rail`** — a directory `path` plus a `name`: the absolute address of one
  file. This is a grub's canonical identity.
- **`fold`** — just a `path`: the absolute address of a directory.
- **`lane`** — a `rail` *or* a `fold`: an absolute reference that might be
  either. `[%& rail]` file, `[%| fold]` directory.
- **`bend`** — a relative reference: an up-count plus a destination `lane`.
- **`road`** — a `lane` *or* a `bend`: what an import rune produces, absolute or
  relative.

```live
/lib/tarball.hoon 39-43
```

```
   /<  name  /lib/foo.hoon        road = [%& %& [/lib %foo.hoon]]   (absolute file)
   /<  name  ../sur/bar.hoon      road = [%| 1 [%& …]]              (relative: 1 up)
   /&  name  /assets/            road = [%& %| /assets]           (absolute dir)

              resolve against "here"
                       │
                       ▼
            rail  [/lib %foo.hoon]         ← absolute; the file's identity
```

Resolution — road → absolute lane — is `lane-from-road`. An absolute road
passes through; a relative one goes to `lane-from-bend`, which reads the current
directory out of `here`, walks up the bend's step count, then welds the base
back onto the destination, preserving the file-vs-directory tag.

```live
/lib/tarball.hoon 189-212
```

## Content: blot, sang, sage, boom

A grub's built content is a `sang`: a `blot` (its mark identity, itself a rail
like `[/ %json]`) paired with a `reus` — either a compiled `vase` (`%&`) or a
build error `boom` (`%|`). A `sage` is a `sang` known to have succeeded (blot +
plain vase). A `bask` is the raw-noun form (blot + noun) that the loader and
namespace store. The helpers below coerce between them — `need-vase` asserts
success, `is-boom` tests for error, `sang-noun` extracts the raw noun either way.

```live
/lib/tarball.hoon 5-24
```

## The ball

A **ball** is an `axal` — a path-indexed tree — of `lump`s. Each directory node
(a `lump`) carries an optional `neck` (the nexus mark identifying it), an
optional `weir` (its [sandbox](#permissions.md)), and a `contents` map from
filename to that grub's built `sang`. Files live in `contents`; subdirectories
are the axal's children.

```live
/lib/tarball.hoon 64-71
```

```
   ball  (axal lump)
   ┌─ /                lump{ neck, weir, contents:{ main.sig → sang } }
   ├─ /lib             lump{ contents:{ build.hoon → sang, nexus.hoon → sang } }
   │    └─ /lib/wasm   lump{ contents:{ … } }
   └─ /mar             lump{ contents:{ json.hoon → sang } }

   ~(tap ba ball)  ⇒  [ [/lib %build.hoon] sang ]
                      [ [/lib %nexus.hoon] sang ]
                      [ [/mar %json.hoon]  sang ]  …
```

The compiler reaches all of this through one door, `ba`. `~(tap ba ball)` — the
call `find-hoon-sources` and `mime-grubs` lean on — flattens the whole tree into
`[rail sang]` pairs; the rest of the door is the keyed accessors (`get`, `got`,
`put`, `has`, …).

```live
/lib/tarball.hoon 767-774
```

## Marks and source addressing

A mark (`/mar/json.hoon`) compiles to a **marc**: a small core exposing `bunt`,
`vale` (coerce a noun into the mark's type), and `grow`/`grab` (conversion tubes
out of and into other marks). The build turns a compiled `/mar` door into a marc
in [`compile-one`](#build-compiler.md).

```live
/lib/tarball.hoon 28-36
```

Marks and nexuses are addressed by their blot/neck, and their *source* lives at
a derived path — the marc for `[/ %json]` is the artifact of `/mar/json.hoon`.
`source-rail` maps a blot to its source rail; `code-candidates` lists the
`/code` namespaces that could govern it, in resolution order (this is the same
ordering [find-code](#build-storage.md) uses).

```live
/lib/tarball.hoon 148-187
```

## The loader lays the ball

Before compilation, a nexus's `on-load` declares what its ball should contain by
calling `spin` over a list of *rows*. `spin` starts from an empty bole and
applies each row against the *old* ball, layering results forward — so anything
no row mentions is simply dropped. No explicit deletes.

```live
/lib/loader.hoon 53-116
```

A row is a **verb** (`%stay` / `%fall` / `%over` / `%load`) crossed with a
**variant** (`%&` file / `%|` directory):

- **`%stay`** — keep what's there, skip if absent.
- **`%fall`** — keep what's there, *else* seed the provided default. **Seed-once.**
- **`%over`** — always overwrite with the given value. **Seed-every-load.**
- **`%load`** — pull from `from`, run a transform gate, place at `to` (renames,
  migrations).

```live
/lib/loader.hoon 24-33
```

The seed-once-vs-overwrite distinction is purely presence-based: `%fall` reads
the old ball and uses its default *only* when nothing is already there, while
`%over` never reads the old ball at all. "User data" just means "already present
at that rail" — there is no provenance flag.

```live
/lib/loader.hoon 77-99
```

`manifest` is not a row variant but a helper that emits an `%over` row writing
`{"version": N}` — the declared version always wins. `empty-dir` and `put-bole`
are the small helpers that seed an empty directory and splice a sub-bole into
place.

```live
/lib/loader.hoon 35-52
```

That's the ground the build stands on. Back up to
[storage & scopes](#build-storage.md) for where the compiled artifacts live and
how a nexus finds code in *another* nexus.
