# Marks

Every grub carries a mark, and the mark is what makes its noun mean
something: a type the noun must fit, and conversions to and from other
marks. A mark is written as an ordinary Hoon mark file, compiled by the
kernel into a marc, a dispatch core with the validator and the
conversion tubes pulled out, and resolved by position, from the nearest
code namespace that has it. Validation happens once per content per
compiled mark and is cached by both hashes, so a read never validates and
a mark that changes re-validates everything written under it. So a mark
is code, resolved like a nexus, and a grub's identity includes which
compiled version of that code it was checked against.

## A blot

A `$blot` names a mark, as a `$rail`: `[/ %json]`, `[/eyre %bindings]`.
The kernel's content types pair a blot with a noun, a vase, or a vase-or-
error, and every write and read moves between them.

```live
/desk/lib/tarball.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 5-12
```

The source of a mark is `/mar/<path>/<name>.hoon` in a code namespace, and
inside a mark core a blot is spelled as one arm name, path segments joined
by double hyphens: `[/eyre %bindings]` is `+eyre--bindings`.

```live
/desk/lib/tarball.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 263-270
```

A mark file is the standard Urbit door: a sample, `+grow` arms that
convert out, `+grab` arms that convert in, and `+noun` under `+grab` as
the validator. `json.hoon` is the whole of one.

```live
/desk/gub/mar/json.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290
```

## The marc

The kernel does not call a mark core directly. It compiles the source
once and wraps the result as a `$marc`: the validated type, its bunt, the
validator as a gate from noun to vase, and two dispatchers that take a
blot and return a tube.

```live
/desk/lib/tarball.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 25-36
```

`+build-marc` builds those five arms from the compiled core. The
validator is `+noun:grab` slapped out of the core; a conversion dispatcher
turns the target blot into an arm name and slaps that arm out of `+grow`
or `+grab`. Each marc is a function of its own source alone; a chain of
conversions is the caller's job.

```live
/desk/lib/marks.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290
```

## Where a marc comes from

A mark is resolved the way a nexus is: through the code namespaces that
govern the grub's position, nearest first, root `/code` last. The lookup
key is the mark's source rail; the artifact is in `bins` under a compile
key, the hash of the built artifact.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1812-1852
```

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1861-1874
```

The compile key is part of every leaf's identity. A leaf ject records
which compiled mark validated its noun, so a recompiled mark changes what
every grub under it means, and the store treats it as a different
version. See [The content-addressed store](#silo.md).

```live
/desk/lib/nexus.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 465-472
```

## Validation

`+validate-noun` runs a noun through the marc for its blot. Every step
that can crash, extracting the marc, building the validator, running it,
building the type, runs under `+mule`, so a bad mark reads as a
validation error carrying its trace rather than an event that dies. On
success the vase is `[type:marc noun]`, the marc's own type, never a type
inferred from the value.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1946-1980
```

Two wrappers carry the kernel's content types across it: a bask to a
sage, and a sang re-validated in place, which is how a boom heals when
its mark is fixed.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1990-2011
```

### The vale cache

A validation result is cached under the pair that determines it: the
content hash and the compile key. The value is `~` for a pass or the tang
for a failure.

```live
/desk/lib/nexus.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 492
```

The cache is written at write time and read at read time. `+record`
validates each stored noun after storing it and caches the answer, so
`+peek-grub` reconstructs a vase from the marc's type and the noun with
no validation at all. Only nouns that live in the store are cached: a
poke payload hashes to a key that will never recur.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1876-1935
```

An entry leaves the cache when its noun leaves the store or its compile
key leaves `bins`. The write path evicts the one entry a replaced leaf
held; the bulk sites, dropping history, releasing a snap, rebuilding
code, sweep the whole map.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 5297-5306
```

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 5318-5337
```

### A whole tree

A nexus's `+on-load` returns basks, and the kernel validates each into a
sang as the bole lands; a failure stores the raw noun as a boom, so a bad
file is visible in the tree rather than lost. `+validate-ball` does the
same over a tree already stored, through the cache.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 2348-2428
```

## Conversion

A conversion from one blot to another is a tube. `+get-tube` asks the
source mark's `+grow` for the target first, and if that has no such arm,
the target mark's `+grab` for the source. Both marcs are resolved from
the grub's position.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 1937-1944
```

> [!note] Wart: a missing target mark crashes the event
> `+get-marc` crashes on a mark it cannot resolve, and `+get-tube` calls
> it for the target blot outside any trap. A conversion to a mark the
> grub's namespace does not have is a crashed event, not a failed
> conversion. `+get-tube` should return the failure as a value, as
> `+validate-noun` does.

## The foundational marks

Four marks are needed before any code namespace exists: `%hoon`, because
mark sources are `.hoon` files; `%mime`, because a synced tree arrives as
bytes; `%tang` and `%kelvin`. At boot the kernel compiles them from the
desk directly and seeds them into `bins` and the root namespace, so the
first source files can be validated at all.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 5049-5092
```

Every code namespace then gets the same four sources injected on every
build, overwriting any copy of its own. Their compile keys are the
bootstrap ones and are never replaced by a compiled copy, since every leaf
written before the build records those keys.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 5246-5261
```

## When a mark changes

A build that changes a mark's artifact re-validates every grub in the
namespace that carries that mark: a pass re-saves the grub with the
marc's type, a failure re-saves it as a boom, and each answer goes into
the cache. A mark edit is therefore a re-typing of its data, immediately,
with the results in the tree.

```live
/desk/app/grubbery.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 5415-5498
```

> [!note] Wart: the foundational marks are never re-validated
> `+validate-marks` skips `%hoon`, `%tang`, `%mime`, and `%kelvin`, with
> a comment that re-validating every source file through them would
> cascade into build loops, because the re-save goes through `+save-file`
> and a save into a code namespace is a build. The skip is the cascade
> guard, not a property of the marks. The re-save should write the grub
> without triggering a build, and then the skip can go.

> [!note] Wart: every build scans every grub
> Finding the grubs a changed mark governs is a pass over the whole born,
> once per build; the comment above the scan says so, and the same walk
> finds the directories a changed nexus governs. A reverse index kept at
> write time, blot to grubs and neck to directories, would make both a
> lookup. Not built; nothing is slow yet.
