# Storage & scopes

The [compiler](#build-compiler.md) is a pure function: ball in, `build-out` out.
It never touches persistent state. The *driver* — the code that decides when to
build, stores the artifacts, reference-counts them, and resolves imports across
nexuses — lives in the kernel agent, `/app/grubbery.hoon`, over a handful of
types defined in `/lib/nexus.hoon`. This page is that half.

## The stored shapes

`nexus.hoon` defines what a compiled namespace looks like at rest. A `built` is
one artifact (a `vase`, a `tang` error, or a `mime`). `keys` maps each rail to
its content key; `deps` is the dependency graph (with `sut-rail`, `[/ %sut]`,
the subject node). A `lode` bundles the two — it's one namespace's whole build
index. `code` maps every scoped `/code` namespace (by `fold`) to its lode. And
`bins` is the artifact store proper: keyed by the content key `@uv`, each entry
carrying a **reference count** alongside its `built`.

```live
/lib/nexus.hoon 5-34
```

The key move: an artifact is addressed by its content key, and a rail's key is
*both* its lookup in `keys` and its address in `bins`. There is no second index.
`artifacts` drops the subject node, which is an input with no artifact.

## The subject

Every file compiles against one subject vase — the kernel and standard library
it's allowed to lean on. It's assembled once, in `sut`: a record of the libs
(`tarball`, `nexus`, `build`, `io=fiberio`, …) slopped onto `..zuse`.

```live
/app/grubbery.hoon 72-95
```

Its hash is pinned once as a leg, `sut-hash`. This hash is what makes "the whole
kernel changed" tractable: `sut-rail` is a node in every lode's `deps`, keyed by
this hash, so a kernel upgrade is detected as one changed dependency rather than
by re-checking every file.

```live
/app/grubbery.hoon 98-102
```

## The one write path

Every reload, make, cull, and sync funnels through a single arm that rebuilds a
namespace: `build-code-with`. It's eight numbered steps, and it's worth reading
in full because it's the entire lifecycle of a build in one place:

```live
/app/grubbery.hoon 5172-5219
```

Walking the steps: **(1)** get the namespace's source ball and force in the
foundational marks; **(2)** reconstruct the compiler's cache from `bins`
([`bins-to-cache`](#build-compiler.md)), compute the reuse set (`skip-set`,
below), and run [`build-inc`](#build-compiler.md); **(3)** index each result's
artifact by key; **(4)** update `bins` — increment the *new* keys, then
decrement the *old* ones; **(5)** GC the vale cache; **(6)** store the new
`lode`; **(7)** re-validate grubs through any changed marks; **(8)** reload the
nexuses whose compiled code actually changed.

## Incremental reuse

`skip-set` is the counterpart to the compiler's `reverse-closure`. Given the set
of changed rails, it decides what may be *reused* and hands `build-inc` the
`skip`/`skip-deps` maps. It sweeps everything (returns empty) when the change set
is unknown, when there's no prior graph, or when a changed rail is a *create* —
because a new file can change how unchanged files resolve their imports. When it
can be incremental, it seeds the changed set (plus the always-changed
foundational marks, plus the subject if its hash moved), takes the reverse
closure, and reuses every keyed rail outside it — pulling each one's prior result
straight from `bins`.

```live
/app/grubbery.hoon 5070-5120
```

## Reference counting

Because artifacts are content-addressed, two files that compile to the same vase
share one bin — so bins are reference-counted. On each build the driver
increments the new keys *before* decrementing the old ones, so a key present in
both never transiently drops to zero and gets evicted. A bin hits zero and is
deleted only when nothing keys it any more.

```live
/app/grubbery.hoon 5002-5022
```

```
   build N        bins                       build N+1 (edit b, a & c shared)
   key(a) ─┐                                  refs-inc new: a↑ c↑ b'↑
   key(c) ─┼─▶ { a:[refs 1], c:[refs 1],      refs-dec old: a↓ c↓ b↓
   key(b) ─┘      b:[refs 1] }                 ⇒ a:[refs 1] c:[refs 1]   (shared, survive)
                                                  b:[refs 0]→evicted, b':[refs 1] new
```

## Scoped /code and cross-nexus imports

A nexus doesn't compile in isolation — it can import code another nexus owns.
Resolution is *scoped*: a `/code` namespace nearest the importer wins, falling
back to ancestors, ending at root `/code`. `find-code-ns` finds the governing
namespace for a path; `resolve-built` is the actual resolver — it turns a mark
or nexus address into its source rail, walks the candidate namespaces in order,
and returns the first one whose lode has a key for that source and whose artifact
is in `bins`.

```live
/app/grubbery.hoon 1815-1852
```

```
   importer at /apps/foo/bar          code-candidates (resolution order):
        │                               1. /apps/foo/bar/code   (sibling)
        │  resolve-built walks ──────▶  2. /apps/foo/code       (ancestor)
        ▼                               3. /apps/code
   first candidate whose lode           4. /code                (root fallback)
   has key[source] & bin  ──▶ built     first hit wins
```

That's the whole system: the ball ([substrate](#build-substrate.md)) is compiled
by the pure [compiler](#build-compiler.md), and the result is stored, refcounted,
and resolved here. Back to the [overview](#build-overview.md) for the map.
