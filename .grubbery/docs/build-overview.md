# The build system

Every Grubbery nexus is Hoon source living in the namespace as grubs. Something
has to turn that source into running code — parse it, resolve its imports,
compile it in the right order, and hand the kernel a vase it can slam. That
something is the **build system**, and this section is a full read of it, top to
bottom, against the actual kernel source.

It is small (one file does the compiling, `/lib/build.hoon`, only 719 lines) but it
earns its keep by being **deterministic** and **incremental**: the same inputs
always produce the same artifact, and a one-line edit recompiles only what that
edit could have changed — not the whole desk.

## The four moving parts

```
   SOURCE                LAYOUT            COMPILE              STORE
   ┌────────┐   spin    ┌────────┐  build ┌──────────┐        ┌──────────┐
   │ grubs  │ ───────▶  │  ball  │ ─────▶ │ build-out│ ─────▶ │  lode    │
   │(.hoon, │  loader   │(a tree │ build. │ results  │        │ [keys    │
   │ mime,  │           │ of     │ hoon   │ keys     │        │  deps]   │
   │ marks) │           │ grubs) │        │ deps     │        │    +     │
   └────────┘           └────────┘        │ cache    │        │  bins    │
                                          └──────────┘        │(artifacts│
                                                              │ by @uv)  │
                                                              └──────────┘
```

1. **The ball** — a nexus's own subtree of grubs: `.hoon` source, `%mime`
   assets, `/mar` marks. This is the input. See [the substrate](#build-substrate.md).
2. **The loader** (`/lib/loader.hoon`) — `spin` lays the declared grubs
   (`%fall`/`%over` rows) into that ball before it is compiled. See
   [the substrate](#build-substrate.md).
3. **The compiler** (`/lib/build.hoon`) — walks the ball, parses each file's
   imports, sorts by dependency, and compiles bottom-up into a `build-out`.
   This is the heart: [the compiler](#build-compiler.md).
4. **The store** (`/lib/nexus.hoon`) — the `build-out` becomes a **lode**
   (the build index: `keys` + `deps`) plus **bins** (the artifacts themselves,
   content-addressed and reference-counted). See
   [storage & scopes](#build-storage.md).

## Three ideas hold it together

Everything below is an elaboration of three moves. Hold these and the code reads
easily.

**Content-addressing.** Every file gets a `key`: the hash of *its inputs* —
`sham [source-hash, path, sorted keys-of-its-deps]`. The key is both the cache
address and the artifact (`bins`) address. Same inputs ⇒ same key ⇒ the compiler
never runs; it hands back the stored vase.

**The subject sentinel.** Every file is compiled against a shared *subject*
vase (the standard library and kernel it builds on top of). Rather than special-
casing it, the build treats the subject as a node in the dependency graph —
`sut-rail`, the rail `[/ %sut]` — that every file depends on. So "the subject
changed" is just "a dependency changed," with no separate code path.

```
        sut-rail  [/ %sut]         ← the compile subject, a node like any other
         ▲   ▲   ▲
         │   │   └──────────┐
      ┌──┘   └───┐          │
   /lib/a.hoon  /lib/b.hoon /lib/c.hoon
      ▲                      ▲
      │                      │
   /lib/d.hoon ──────────────┘        d imports a and c
```

**Incremental reuse.** When source changes, the build computes the **reverse
closure** of the changed set over the dependency graph — the changed files, plus
everything that (transitively) imports them — and recompiles exactly that.
Everything else is *reused*: never re-read, re-parsed, or re-hashed.

```
   changed: [b]
                      reverse closure of {b}:
   a   b*  c            b  (changed)
   │   │   │            └─ d   (imports b)
   └─▶ d ◀─┘            └─ … (anything importing d)

   recompile: { b, d, … }      reuse: { a, c, everything else }
```

Read on for how each of these is actually coded — starting with
[the compiler](#build-compiler.md), then [storage & scopes](#build-storage.md),
then [the substrate](#build-substrate.md) the whole thing runs on.
