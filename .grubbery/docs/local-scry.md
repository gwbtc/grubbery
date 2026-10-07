# Local scry

Reading this ship's *own* namespace — a Clay file, a desk's revision, whether a
path exists — is **local scry**: a pure read of a vane, no effects and no network.
It goes through the same `/sys/scry` service as the remote-scry farm but under a
different tag (`%scry-request`) — a `.^` into a local vane, its answer validated
through a mark.

## typed-scry

`typed-scry` is the primitive. Given a `mold`, a `mark`, and a vane `path`, it
pokes `/sys/scry` with a `%scry-request`, blocks for the answer, and validates it
through the mark before returning the typed `mold`. The mark must have a marc in
the code namespace, so the service's `.^` result can be hydrated and checked
against it.

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 877-898
```

> [!note] A wart: the name
>
> It should just be `+scry`.

## The clay-* helpers

`fiberio` wraps the common Clay cares as one-liners on `typed-scry`: `clay-case`
reads a desk's current revision, `clay-exists` whether a path resolves, `clay-read`
a file's noun, `clay-tree` the paths under a directory. Each names the Clay care
(`%cw`, `%cu`, `%cx`, `%ct`) and the mark to validate the answer against.

```live
/desk/lib/fiberio.hoon@f1d4c77d9ca3745156c78fb5e99648e8ee4e4290 991-1013
```
