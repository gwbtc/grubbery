::  lib/git/blame: per-line attribution over the native object store.
::
::  +blame(head, path) returns, for each line of the file as it stands at
::  commit `head` (a @ux object hash), the commit that introduced that line.
::
::  Positional blame, the way git does it. Walk the first-parent chain from
::  `head` backwards. At each commit where the file CHANGED (its blob hash
::  differs from its parent's -- checked without inflating the blob), line-diff
::  that version against the parent's: new lines (no match in the parent) are
::  attributed to that commit; survivors carry their provenance one step back,
::  re-anchored to their position in the parent. Commits that didn't touch the
::  file are skipped. The walk stops as soon as every line is attributed, so a
::  file whose lines are mostly recent never pays for the deep history.
::
::  The diff is a patience diff: match the common prefix and suffix, anchor on
::  the lines that occur exactly once on BOTH sides, keep the longest
::  increasing run of those anchors, and recurse into the gaps. Unmatched
::  regions stay unmatched -- a big refactor just reads as "introduced here"
::  with no expensive alignment, so the cost stays near-linear even when the
::  whole file was rewritten.
::
::  Pure: the caller caches the result keyed by commit hash (which never
::  changes), so this runs once per (file, commit) and never on the request
::  path. `commit` in the output is the hash as hex text.
::
::  First-parent only: a line that actually entered via a merge's side branch
::  is attributed to the merge commit. develop is near-linear, so this matches
::  git's default in practice.
::
/<  *  /lib/git/object.hoon
/<  git-repo  /lib/git/repository.hoon
=>  |%
    +$  line   [text=@t commit=@t author=@t when=@da]
    +$  frame  [hash=@ux author=@t when=@da lines=(list @t)]
    --
|_  repo=repository:git-repo
+*  rg  ~(. git-repo repo)
::  +lines-at: a file's lines at a commit, ~ when the file is absent there
++  lines-at
  |=  [c=@ux pax=path]
  ^-  (list @t)
  =/  b=(unit octs)  (blob-at-commit:rg c pax)
  ?~(b ~ (to-wain:format q.u.b))
::  +blob-hash-at: the file's blob hash at a commit, without inflating it.
::  ~ when the file (or a path segment) is absent. Used to tell whether a
::  commit touched the file, cheaply.
++  blob-hash-at
  |=  [c=@ux pax=path]
  ^-  (unit @ux)
  =/  com=(unit commit:git-repo)  (get-commit:store:rg c)
  ?~  com  ~
  =/  troot=@ux  tree.u.com
  =/  segs=path  pax
  |-  ^-  (unit @ux)
  ?~  segs  ~
  =/  td=(unit (list tree-entry))  (get-tree:store:rg troot)
  ?~  td  ~
  =/  ent=(unit tree-entry)
    |-  ^-  (unit tree-entry)
    ?~  u.td  ~
    ?:  =(i.segs name.i.u.td)  `i.u.td
    $(u.td t.u.td)
  ?~  ent  ~
  ?~  t.segs  `hash.u.ent
  ?.  (is-dir u.ent)  ~
  $(troot hash.u.ent, segs t.segs)
::  +lines-to-map: a line list as index -> line, for random access
++  lines-to-map
  |=  a=(list @t)
  ^-  (map @ud @t)
  =|  m=(map @ud @t)
  =/  i=@ud  0
  |-  ^-  (map @ud @t)
  ?~  a  m
  $(a t.a, i +(i), m (~(put by m) i i.a))
::  +counts: per-value occurrence count over mv[lo..hi)
++  counts
  |=  [mv=(map @ud @t) lo=@ud hi=@ud]
  ^-  (map @t @ud)
  =/  i=@ud  lo
  =|  c=(map @t @ud)
  |-  ^-  (map @t @ud)
  ?:  (gte i hi)  c
  =/  v=@t  (~(got by mv) i)
  $(i +(i), c (~(put by c) v +((~(gut by c) v 0))))
::  +first-idx: per-value index over mv[lo..hi) (only used where unique)
++  first-idx
  |=  [mv=(map @ud @t) lo=@ud hi=@ud]
  ^-  (map @t @ud)
  =/  i=@ud  lo
  =|  f=(map @t @ud)
  |-  ^-  (map @t @ud)
  ?:  (gte i hi)  f
  $(i +(i), f (~(put by f) (~(got by mv) i) i))
::  +match: patience line-diff. Returns, for the lines of `a`, the index in
::  `b` of each line that aligns. An `a`-index absent from the result is a
::  line with no counterpart in `b`.
++  match
  |=  [a=(list @t) b=(list @t)]
  ^-  (map @ud @ud)
  =/  an=@ud  (lent a)
  =/  bn=@ud  (lent b)
  ?:  |(=(0 an) =(0 bn))  ~
  =/  av=(map @ud @t)  (lines-to-map a)
  =/  bv=(map @ud @t)  (lines-to-map b)
  |^  (go 0 an 0 bn ~)
  ::  +go: align region a[alo..ahi) with b[blo..bhi), adding to acc
  ++  go
    |=  [alo=@ud ahi=@ud blo=@ud bhi=@ud acc=(map @ud @ud)]
    ^-  (map @ud @ud)
    =/  p  (pre alo ahi blo bhi acc)
    =/  s  (suf alo.p ahi blo.p bhi acc.p)
    ?:  |((gte alo.p ahi.s) (gte blo.p bhi.s))  acc.s
    =/  anchors=(list [a=@ud b=@ud])  (uniq-anchors alo.p ahi.s blo.p bhi.s)
    ?~  anchors  acc.s
    =/  keep=(list [a=@ud b=@ud])  (lis-by-b anchors)
    ?~  keep  acc.s
    (recurse-gaps alo.p ahi.s blo.p bhi.s keep acc.s)
  ::  +pre: consume the common prefix
  ++  pre
    |=  [alo=@ud ahi=@ud blo=@ud bhi=@ud acc=(map @ud @ud)]
    ^-  [alo=@ud blo=@ud acc=(map @ud @ud)]
    ?:  |((gte alo ahi) (gte blo bhi))  [alo blo acc]
    ?.  =((~(got by av) alo) (~(got by bv) blo))  [alo blo acc]
    $(alo +(alo), blo +(blo), acc (~(put by acc) alo blo))
  ::  +suf: consume the common suffix
  ++  suf
    |=  [alo=@ud ahi=@ud blo=@ud bhi=@ud acc=(map @ud @ud)]
    ^-  [ahi=@ud bhi=@ud acc=(map @ud @ud)]
    ?:  |((lte ahi alo) (lte bhi blo))  [ahi bhi acc]
    ?.  =((~(got by av) (dec ahi)) (~(got by bv) (dec bhi)))  [ahi bhi acc]
    $(ahi (dec ahi), bhi (dec bhi), acc (~(put by acc) (dec ahi) (dec bhi)))
  ::  +uniq-anchors: a[alo..ahi) indices whose line occurs exactly once in
  ::  both ranges, paired with their b index, in a-order
  ++  uniq-anchors
    |=  [alo=@ud ahi=@ud blo=@ud bhi=@ud]
    ^-  (list [a=@ud b=@ud])
    =/  ac=(map @t @ud)  (counts av alo ahi)
    =/  bc=(map @t @ud)  (counts bv blo bhi)
    =/  bf=(map @t @ud)  (first-idx bv blo bhi)
    =/  i=@ud  alo
    =|  out=(list [a=@ud b=@ud])
    |-  ^-  (list [a=@ud b=@ud])
    ?:  (gte i ahi)  (flop out)
    =/  v=@t  (~(got by av) i)
    ?:  ?&  =(1 (~(gut by ac) v 0))
            =(1 (~(gut by bc) v 0))
        ==
      $(i +(i), out [[i (~(got by bf) v)] out])
    $(i +(i))
  ::  +lis-by-b: longest run of anchors with strictly increasing b index
  ::  (a is already strictly increasing). O(k^2); k = anchor count, small.
  ++  lis-by-b
    |=  ps=(list [a=@ud b=@ud])
    ^-  (list [a=@ud b=@ud])
    =/  pairs=(map @ud [a=@ud b=@ud])  (pairs-to-map ps)
    =/  k=@ud  (lent ps)
    ?:  =(0 k)  ~
    =|  dp=(map @ud @ud)
    =|  pv=(map @ud (unit @ud))
    =/  i=@ud  0
    |-  ^-  (list [a=@ud b=@ud])
    ?:  =(i k)  (reconstruct pairs dp pv k)
    =/  bi=@ud  b:(~(got by pairs) i)
    =/  best=[len=@ud prev=(unit @ud)]  [1 ~]
    =.  best
      =/  j=@ud  0
      |-  ^-  [len=@ud prev=(unit @ud)]
      ?:  =(j i)  best
      =/  bj=@ud  b:(~(got by pairs) j)
      =/  lj=@ud  (~(gut by dp) j 0)
      ?:  &((lth bj bi) (gth +(lj) len.best))
        $(j +(j), best [+(lj) `j])
      $(j +(j))
    $(i +(i), dp (~(put by dp) i len.best), pv (~(put by pv) i prev.best))
  ::  +reconstruct: follow the dp back-pointers from the longest run
  ++  reconstruct
    |=  $:  pairs=(map @ud [a=@ud b=@ud])
            dp=(map @ud @ud)
            pv=(map @ud (unit @ud))
            k=@ud
        ==
    ^-  (list [a=@ud b=@ud])
    =/  i=@ud  0
    =/  best=[idx=(unit @ud) len=@ud]  [~ 0]
    =.  best
      |-  ^-  [idx=(unit @ud) len=@ud]
      ?:  =(i k)  best
      =/  l=@ud  (~(gut by dp) i 0)
      ?:  (gth l len.best)  $(i +(i), best [`i l])
      $(i +(i))
    ?~  idx.best  ~
    =/  cur=(unit @ud)  idx.best
    =|  out=(list [a=@ud b=@ud])
    |-  ^-  (list [a=@ud b=@ud])
    ?~  cur  out
    $(cur (~(got by pv) u.cur), out [(~(got by pairs) u.cur) out])
  ::  +pairs-to-map: index the anchor list for random access
  ++  pairs-to-map
    |=  ps=(list [a=@ud b=@ud])
    ^-  (map @ud [a=@ud b=@ud])
    =|  m=(map @ud [a=@ud b=@ud])
    =/  i=@ud  0
    |-  ^-  (map @ud [a=@ud b=@ud])
    ?~  ps  m
    $(ps t.ps, i +(i), m (~(put by m) i i.ps))
  ::  +recurse-gaps: add each kept anchor, and align the gap before it
  ++  recurse-gaps
    |=  $:  alo=@ud  ahi=@ud  blo=@ud  bhi=@ud
            keep=(list [a=@ud b=@ud])
            acc=(map @ud @ud)
        ==
    ^-  (map @ud @ud)
    =/  pa=@ud  alo
    =/  pb=@ud  blo
    =/  ls=(list [a=@ud b=@ud])  keep
    |-  ^-  (map @ud @ud)
    ?~  ls  (go pa ahi pb bhi acc)
    =.  acc  (go pa a.i.ls pb b.i.ls acc)
    =.  acc  (~(put by acc) a.i.ls b.i.ls)
    $(ls t.ls, pa +(a.i.ls), pb +(b.i.ls))
  --
::  +step: account one suspect commit. For each final line still open, if its
::  line survives into the parent (mm maps its current index) carry it to the
::  parent index; else it was introduced here -- finalize it to this commit.
++  step
  |=  $:  suspect=frame
          mm=(map @ud @ud)
          cur=(map @ud (unit @ud))
          out=(map @ud frame)
      ==
  ^-  [(map @ud (unit @ud)) (map @ud frame)]
  =/  keys=(list @ud)  ~(tap in ~(key by cur))
  |-  ^-  [(map @ud (unit @ud)) (map @ud frame)]
  ?~  keys  [cur out]
  =/  i=@ud  i.keys
  =/  vi=(unit @ud)  (~(got by cur) i)
  ?~  vi  $(keys t.keys)
  =/  pj=(unit @ud)  (~(get by mm) u.vi)
  ?~  pj
    $(keys t.keys, cur (~(put by cur) i ~), out (~(put by out) i suspect))
  $(keys t.keys, cur (~(put by cur) i `u.pj))
::  +finalize-all: attribute every still-open final line to frame `f`
++  finalize-all
  |=  [cur=(map @ud (unit @ud)) out=(map @ud frame) f=frame]
  ^-  (map @ud frame)
  =/  keys=(list @ud)  ~(tap in ~(key by cur))
  |-  ^-  (map @ud frame)
  ?~  keys  out
  =/  vi=(unit @ud)  (~(got by cur) i.keys)
  ?~  vi  $(keys t.keys)
  $(keys t.keys, out (~(put by out) i.keys f))
::  +all-done: every final line attributed?
++  all-done
  |=  cur=(map @ud (unit @ud))
  ^-  ?
  (levy ~(val by cur) |=(v=(unit @ud) ?=(~ v)))
::  +emit: render final blame in file order
++  emit
  |=  [heads=(list @t) out=(map @ud frame)]
  ^-  (list line)
  =/  i=@ud  0
  =/  hs=(list @t)  heads
  |-  ^-  (list line)
  ?~  hs  ~
  =/  f=frame  (~(gut by out) i *frame)
  :_  $(hs t.hs, i +(i))
  [i.hs (scot %ux hash.f) author.f when.f]
::  +blame: positional per-line attribution of `pax` as it is at `head`
++  blame
  |=  [head=@ux pax=path]
  ^-  (list line)
  =/  hc=(unit commit:git-repo)  (get-commit:store:rg head)
  ?~  hc  ~
  =/  heads=(list @t)  (lines-at head pax)
  =/  n=@ud  (lent heads)
  ?:  =(0 n)  ~
  ::  cur: final-line -> its index in the current suspect version (~ = done)
  =/  cur=(map @ud (unit @ud))
    =|  m=(map @ud (unit @ud))
    =/  i=@ud  0
    |-  ^-  (map @ud (unit @ud))
    ?:  =(i n)  m
    $(i +(i), m (~(put by m) i `i))
  =|  out=(map @ud frame)
  ::  suspect state: the oldest commit still holding the current version
  =/  s-hash=@ux          head
  =/  s-com=commit:git-repo  u.hc
  =/  s-lines=(list @t)   heads
  =/  s-bh=(unit @ux)     (blob-hash-at head pax)
  =/  walked=@ud  0   :: XX diag: commits examined
  =/  changed=@ud  0  :: XX diag: change-points diffed
  |-  ^-  (list line)
  ?:  (all-done cur)
    ~>(%slog.[0 leaf+"blame done: walked={<walked>} diffed={<changed>} lines={<n>}"] (emit heads out))
  =/  s-frame=frame
    [s-hash (crip name.author.s-com) date.author-time.s-com s-lines]
  ?~  parents.s-com
    ::  root: whatever is still open was introduced here
    ~>(%slog.[0 leaf+"blame root: walked={<walked>} diffed={<changed>}"] (emit heads (finalize-all cur out s-frame)))
  =/  p-hash=@ux  i.parents.s-com
  =/  pc=(unit commit:git-repo)  ~>(%bout.[1 %get-commit] (get-commit:store:rg p-hash))
  ?~  pc  (emit heads (finalize-all cur out s-frame))
  =/  p-bh=(unit @ux)  ~>(%bout.[1 %hashwalk] (blob-hash-at p-hash pax))
  ?:  =(s-bh p-bh)
    ::  file unchanged across this edge: advance, same version and indices
    $(s-hash p-hash, s-com u.pc, s-bh p-bh, walked +(walked))
  ::  file changed: diff this version against the parent's and attribute
  =/  p-lines=(list @t)  ?~(p-bh ~ ~>(%bout.[1 %inflate] (lines-at p-hash pax)))
  =/  mm=(map @ud @ud)  ~>(%bout.[1 %diff] (match s-lines p-lines))
  =/  res  (step s-frame mm cur out)
  ~>  %slog.[0 leaf+"blame CHANGE {<+(changed)>}: at={<(scot %da date.author-time.s-com)>}"]
  %=  $
    cur      -.res
    out      +.res
    s-hash   p-hash
    s-com    u.pc
    s-lines  p-lines
    s-bh     p-bh
    walked   +(walked)
    changed  +(changed)
  ==
--
