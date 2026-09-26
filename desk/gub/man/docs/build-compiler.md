# The compiler

`/lib/build.hoon` is the whole compiler: it takes a nexus's ball of source
grubs and returns a `build-out` — every file's compiled vase (or its error),
plus the caching and dependency bookkeeping the [store](#build-storage.md) needs
to do this incrementally next time. This page reads it end to end.

## The shapes it works in

Before the logic, the types. An `import` is one `/<` or `/&` line; once its
path is resolved to an absolute [rail](#build-substrate.md) it becomes a
`resolved-import`. A `file-info` is everything the compiler learns about one
file up front. A `build-result` is a compiled `vase` or an error `tang`. And
`build-out` is the whole return: results, the content-addressed `cache`, the
dependency graph `deps`, and each rail's `key`.

```live
/lib/build.hoon 17-41
```

## Step 1 — find the imports

Compilation starts by reading each file's import lines. `parse-imports` walks
the source top-down, skipping blanks and `::` comments, trying each import rune
against the line until it hits code — everything from there down is the *body*.

```live
/lib/build.hoon 86-118
```

The runes themselves are a little parser combinator grammar. `/<  name  path`
is a named file import, `/<  *  path` a bare one (spliced into the subject with
no face), and `/&  name  path` a mime import — a single asset file, or, with a
trailing slash, a whole directory gathered as `(axal (map @ta mime))`. Paths are
absolute (`/lib/foo.hoon`) or relative with a `../` up-count.

```live
/lib/build.hoon 127-207
```

## Step 2 — resolve, parse, compile one file

An import as written is a `road` — possibly relative. `resolve-import` turns it
into an absolute `rail` (for a file/bare) or `lane` (for a mime, which may be a
directory) by resolving it against the file's own location. The heavy lifting is
[`lane-from-road`](#build-substrate.md) in tarball; this arm just wraps it per
import kind.

```live
/lib/build.hoon 286-307
```

Parsing the body into a Hoon AST is `parse-hoon`. The one subtle thing: it sets
`vang` with `bug=&` and `wer=path`, so every expression carries a `%dbug`
annotation with its file and line — which is why a *compile* error deep in a
build points at the real source location, Clay-style. A *parse* error is
rendered by hand as the offending line with a `^` caret under the column.

```live
/lib/build.hoon 217-234
```

Compilation is `slap` against a subject vase, wrapped in `mule` with `!.` so the
caller's own stack traces are suppressed and only the source's `%dbug`
annotations survive into the error. `build-hoon` chains the two.

```live
/lib/build.hoon 244-261
```

A few small readers sit alongside: `extract-src` pulls text out of a `%hoon` or
`%txt` grub, `render-tang` flattens an error to text, and
`find-hoon-sources` / `has-hoon-ext` select the `.hoon` grubs out of a ball.

```live
/lib/build.hoon 266-337
```

## Step 3 — order by dependency

You can't compile a file before the files it imports. `topo-sort` repeatedly
peels off the nodes whose dependencies are all already done — a leaves-first
order — and returns whatever's left stuck in a cycle.

```live
/lib/build.hoon 343-364
```

## The engine: build-inc

`build-all` is just `build-inc` with nothing to reuse. Everything real happens
in `build-inc`, and it's organized as a sequence of phases, each an arm below,
feeding the next. Read the phase list in the comment, then the setup:

```live
/lib/build.hoon 380-433
```

The phases, in order:

- **`sources-to-build`** — every `.hoon` source in the ball, minus the rails
  we're reusing from last time.
- **`mime-grubs`** + **`grub-mime`** — the `[/ %mime]` grubs, which enter a
  build as *data* (imported by `/&`), never compiled.
- **`parse-sources`** — parse every source's imports, resolve them, and verify
  each names something that actually exists; a file that fails here gets an
  error instead of a `file-info`. Note `src-hash` = `(sham src)`, the content
  hash that anchors the file's cache key.
- **`fold-mimes`** + **`fold-axal`** — the mimes gathered under a `/&`
  *directory* import. These are compile inputs too, so they must be keyed and
  edged — otherwise editing a file under the fold wouldn't change the importer's
  key and a stale vase would be reused.
- **`dep-graph`** — every file's edges, plus the reused rails' prior edges, plus
  the subject as a dependency of every file.
- **`seed-results`** — the inputs the compile loop *starts* from: the subject,
  the mimes, and the parse/cycle errors, each already carrying its key.

```live
/lib/build.hoon 534-601
```

```live
/lib/build.hoon 608-678
```

```live
/lib/build.hoon 684-718
```

## The compile loop

With the topological order, the keys of the seed inputs, and the dependency
graph in hand, `compile-loop` walks each rail in order. For each one it computes
the **content-addressed key** — `sham [source-hash, path, sorted dep-keys]` —
then does one of three things: fail early if a dependency failed, return the
stored vase on a **cache hit**, or actually **compile** and store the result
under that key.

```live
/lib/build.hoon 438-476
```

Because the key folds in the *keys of the dependencies*, a change anywhere
upstream changes this file's key too, all the way down the graph — which is
exactly what makes the cache safe:

```
   edit /lib/a.hoon
     └▶ src-hash(a) changes
        └▶ key(a) = sham[src-hash(a), path, …] changes
           └▶ key(d) = sham[…, sorted[key(a), key(c)]] changes   (d imports a)
              └▶ key(anything importing d) changes … 

   unchanged files keep their keys → cache hit → never recompiled
```

Compiling one file is `compile-one`: build the subject by layering this file's
imports onto the base subject (`augment`), compile the body, and — if the file
is a mark (`/mar/*`) — turn the compiled door into a `marc`.

```live
/lib/build.hoon 480-492
```

`augment` is where imports become the subject. Each import adds one named face:
a file import contributes its vase, a bare import is `slop`ped in directly, a
mime file contributes its `mime`, and a mime *directory* contributes the
gathered `(axal (map @ta mime))` — read from the very same mimes the graph
keyed, so the compile inputs and the key inputs are identical by construction.

```live
/lib/build.hoon 500-529
```

## Incremental support

Two arms make the *next* build cheap. `reverse-closure` is the "what changed"
calculation: give it the dependency graph and a seed set of changed rails, and
it returns them plus everyone who transitively depends on them — the exact set
that must recompile. Everything else is safe to reuse.

```live
/lib/build.hoon 48-64
```

And `bins-to-cache` rebuilds the compiler's `cache` from the [store's
bins](#build-storage.md): since a rail's key is *both* its cache address and its
artifact address, the stored artifacts are already a content-addressed cache —
this just re-presents them in the shape `build-inc` wants.

```live
/lib/build.hoon 69-78
```

That's the compiler whole. Next: where its output lives, how artifacts are
reference-counted, and how imports reach *across* nexuses —
[storage & scopes](#build-storage.md).
