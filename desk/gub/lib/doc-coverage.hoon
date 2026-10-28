::  /lib/doc-coverage: the pure handbook coverage engine.
::
::  The shell's docs system (nex/shell.hoon) and a forge-hosted per-repo docs
::  feature both need the same coverage/freshness math over a set of source
::  files and a nav manifest. Everything that touches a SOURCE — peeking a
::  mirror, a repo checkout, or a blob at a commit — stays in the host; this
::  core is pure. The host assembles:
::
::    finfo    (map src-path (list line))   HEAD line map of every source file
::    anchors  (list [doc file commit from to pin-span])  every live-block
::                                           citation, by page, carrying the
::                                           exact lines at its pinned commit
::    nav      json                         the manifest's nav tree
::    ignore   (list @t)                    path/range selectors out of scope
::
::  and calls +fold-coverage to get a cov-state, then +render-coverage per
::  view. All source reads (HEAD and the pinned commits) happen in the host via
::  the git object store (blob-at-commit) — never a mirror; this core only
::  compares and aggregates what the host hands it.
::
|%
::  cov-state: everything coverage needs, folded ONCE per collection: the line
::  map of every file, the ignore sets, and the fold over every live-block
::  anchor (covered lines, per-file fresh/drifted/gone counts, pins to stamp,
::  per-file anchor json, pages carrying a drifted block, per-page covered map).
+$  cov-state
  $:  finfo=(map @t (list @t))
      ig-set=(set @t)
      ignore-lines=(map @t (set @ud))
      covered=(map @t (set @ud))
      flags=(map @t [f=@ud d=@ud g=@ud])
      fancs=(map @t (list json))
      doc-drift=(set @t)
      nanc=@ud
      doc-cov=(map @t (map @t (set @ud)))
  ==
::  json-strs: a json array of strings as a (list @t); ~ for anything else.
++  json-strs
  |=  j=(unit json)
  ^-  (list @t)
  ?~  j  ~
  ?.  ?=([%a *] u.j)  ~
  (murn p.u.j |=(x=json ?:(?=([%s *] x) `p.x ~)))
::  sang-text: the raw text of a grub's sang. A .hoon/.js/.css grub holds its
::  source in the vase as @t; %txt/%md is a wain; %mime carries octs. Empty
::  for a boom or a shape we can't read. (Hosts enumerating a ball use this to
::  build finfo.)
++  sang-text
  |=  =sang:tarball
  ^-  @t
  ?:  ?=(%| -.q.sang)  ''
  =/  =sage:tarball  (need-sage:tarball sang)
  =/  mk=@tas  name.p.sage
  ?:  =(%txt mk)   (of-wain:format !<(wain q.sage))
  ?:  =(%md mk)    (of-wain:format !<(wain q.sage))
  ?:  =(%mime mk)  `@t`q.q:!<(mime q.sage)
  (fall (mole |.(!<(@t q.sage))) '')
::  triml: drop leading spaces from a tape.
++  triml
  |=  t=tape
  ^-  tape
  ?~  t  t
  ?:  =(' ' i.t)  $(t t.t)
  t
::  parse-ref: a "path[@commit] [from-to]" selector. `@commit` on the file
::  token pins the segment to that commit (absent = floats at HEAD); a bare
::  path (no range) selects the whole file (to=0).
++  parse-ref
  |=  ln=tape
  ^-  (unit [file=@t commit=(unit @t) from=@ud to=@ud])
  =/  t=tape  (triml ln)
  ?~  t  ~
  =/  full=tape  t
  =/  sp=(unit @ud)  (find " " full)
  =/  ftoken=tape  ?~(sp full (scag u.sp full))
  =/  rng=tape  ?~(sp "" (triml (slag +(u.sp) full)))
  ::  split the file token on '@' into path + optional commit
  =/  at=(unit @ud)  (find "@" ftoken)
  =/  file=@t  (crip ?~(at ftoken (scag u.at ftoken)))
  =/  commit=(unit @t)  ?~(at ~ `(crip (slag +(u.at) ftoken)))
  =/  dash=(unit @ud)  (find "-" rng)
  ?~  dash
    =/  n=(unit @ud)  (rush (crip rng) dem)
    ?~(n `[file commit 1 0] `[file commit u.n u.n])
  =/  from=(unit @ud)  (rush (crip (scag u.dash rng)) dem)
  =/  to=(unit @ud)    (rush (crip (slag +(u.dash) rng)) dem)
  ?:  |(?=(~ from) ?=(~ to))  ~
  `[file commit u.from u.to]
::  parse-anchors: the live-block anchors in one doc's markdown — each a
::  ` ```live ` fence whose body is "path range". Returns [file from to] list.
++  parse-anchors
  |=  md=@t
  ^-  (list [file=@t commit=(unit @t) from=@ud to=@ud])
  =/  lines=(list tape)  (turn (to-wain:format md) trip)
  =|  out=(list [@t (unit @t) @ud @ud])
  =/  live=?  %.n
  |-  ^-  (list [@t (unit @t) @ud @ud])
  ?~  lines  (flop out)
  =/  ln=tape  (triml i.lines)
  ?:  live
    ?:  =("```" (scag 3 ln))  $(lines t.lines, live |)
    =/  a=(unit [@t (unit @t) @ud @ud])  (parse-ref ln)
    ?~  a  $(lines t.lines, live |)
    $(lines t.lines, out [u.a out], live |)
  ?:  =("```live" (scag 7 ln))  $(lines t.lines, live &)
  $(lines t.lines)
::  ranges: a set of line numbers as a compact list of contiguous [lo hi] runs.
++  ranges
  |=  s=(set @ud)
  ^-  (list [@ud @ud])
  =/  ns=(list @ud)  (sort ~(tap in s) lth)
  ?~  ns  ~
  =/  lo=@ud  i.ns
  =/  hi=@ud  i.ns
  =/  rest  t.ns
  =|  out=(list [@ud @ud])
  |-  ^-  (list [@ud @ud])
  ?~  rest  (flop [[lo hi] out])
  ?:  =(i.rest +(hi))  $(hi i.rest, rest t.rest)
  $(out [[lo hi] out], lo i.rest, hi i.rest, rest t.rest)
::  ignored: is a source path excluded by the ignore list (itself or under an
::  ignored directory)?
++  ignored
  |=  [src=@t ign=(list @t)]
  ^-  ?
  %+  lien  ign
  |=  ip=@t
  =/  ipt=tape  (trip ip)
  =(ip (crip (scag (lent ipt) (trip src))))
::  nav-items: the flat [path title] of every doc in a nav tree.
++  nav-items
  |=  nav=json
  ^-  (list [path=@t title=@t])
  |^  (walk nav)
  ++  walk
    |=  j=json
    ^-  (list [path=@t title=@t])
    ?.  ?=([%a *] j)  ~
    %-  zing
    %+  turn  p.j
    |=  node=json
    ^-  (list [path=@t title=@t])
    ?.  ?=([%o *] node)  ~
    =/  pax  (~(get by p.node) 'path')
    ?:  ?=([~ %s *] pax)
      =/  ttl  (~(get by p.node) 'title')
      ~[[p.u.pax ?:(?=([~ %s *] ttl) p.u.ttl '')]]
    =/  kids  (~(get by p.node) 'kids')
    ?~(kids ~ (walk u.kids))
  --
::  subtree-scopes: every `scope` selector in a node's subtree (own + descendants).
++  subtree-scopes
  |=  nd=json
  ^-  (list @t)
  ?.  ?=([%o *] nd)  ~
  =/  own=(list @t)  (json-strs (~(get by p.nd) 'scope'))
  =/  kids  (~(get by p.nd) 'kids')
  =/  sub=(list @t)
    ?~  kids  ~
    ?.  ?=([%a *] u.kids)  ~
    (zing (turn p.u.kids subtree-scopes))
  (weld own sub)
::  find-node: the nav node titled `name`, at any depth.
++  find-node
  |=  [nav=json name=@t]
  ^-  (unit json)
  ?.  ?=([%a *] nav)  ~
  |-  ^-  (unit json)
  ?~  p.nav  ~
  =/  nd  i.p.nav
  ?.  ?=([%o *] nd)  $(p.nav t.p.nav)
  =/  ttl  (~(get by p.nd) 'title')
  ?:  ?&(?=([~ %s *] ttl) =(name p.u.ttl))  `nd
  =/  kids  (~(get by p.nd) 'kids')
  =/  sub  ?~(kids ~ (find-node u.kids name))
  ?^(sub sub $(p.nav t.p.nav))
::  node-cover-scope: a node's coverage scope — own `scope` UNIONED with every
::  scoped descendant's. ~ if there's no scope anywhere in the subtree.
++  node-cover-scope
  |=  [nav=json name=@t]
  ^-  (list @t)
  =/  nd=(unit json)  (find-node nav name)
  ?~  nd  ~
  (subtree-scopes u.nd)
::  any-cov: does any node in this annotated nav array carry cov=true?
++  any-cov
  |=  nav=json
  ^-  ?
  ?.  ?=([%a *] nav)  |
  %+  lien  p.nav
  |=(nd=json &(?=([%o *] nd) =([~ %b %.y] (~(get by p.nd) 'cov'))))
::  annotate-nav: tag each node with `cov` — whether it has measured coverage
::  (own `scope` OR any scoped descendant).
++  annotate-nav
  |=  nav=json
  ^-  json
  ?.  ?=([%a *] nav)  nav
  :-  %a
  %+  turn  p.nav
  |=  nd=json
  ^-  json
  ?.  ?=([%o *] nd)  nd
  =/  kids  (~(get by p.nd) 'kids')
  =/  ann=(unit json)  ?~(kids ~ `(annotate-nav u.kids))
  =/  po=(map @t json)  ?~(ann p.nd (~(put by p.nd) 'kids' u.ann))
  =/  own=?  ?=(^ (~(get by po) 'scope'))
  =/  kidcov=?  ?~(ann | (any-cov u.ann))
  [%o (~(put by po) 'cov' [%b |(own kidcov)])]
::  scoped-sections: the titles of every nav node with measured coverage.
++  scoped-sections
  |=  nav=json
  ^-  (list @t)
  ?.  ?=([%a *] nav)  ~
  %-  zing
  %+  turn  p.nav
  |=  nd=json
  ^-  (list @t)
  ?.  ?=([%o *] nd)  ~
  =/  ttl  (~(get by p.nd) 'title')
  =/  self=(list @t)
    ?:(?&(?=([~ %s *] ttl) ?=(^ (subtree-scopes nd))) ~[p.u.ttl] ~)
  =/  kids  (~(get by p.nd) 'kids')
  (weld self ?~(kids ~ (scoped-sections u.kids)))
::  subtree-docs: every page path in the nav subtree at nd (own + descendants).
++  subtree-docs
  |=  nd=json
  ^-  (list @t)
  ?.  ?=([%o *] nd)  ~
  =/  own=(list @t)
    =/  p  (~(get by p.nd) 'path')
    ?:(?=([~ %s *] p) ~[p.u.p] ~)
  =/  kids  (~(get by p.nd) 'kids')
  =/  kd=(list @t)
    ?.  ?=([~ %a *] kids)  ~
    (zing (turn p.u.kids |=(k=json (subtree-docs k))))
  (weld own kd)
::  section-status-of: a section's freshness — drifted iff any live block on
::  its own (or descendant) page is drifted.
++  section-status-of
  |=  [nav=json name=@t doc-drift=(set @t)]
  ^-  @t
  =/  nd=(unit json)  (find-node nav name)
  ?~  nd  'fresh'
  ?:((lien (subtree-docs u.nd) |=(d=@t (~(has in doc-drift) d))) 'drifted' 'fresh')
::  section-covered: the lines covered by a section's OWN pages.
++  section-covered
  |=  [doc-cov=(map @t (map @t (set @ud))) nav=json name=@t]
  ^-  (map @t (set @ud))
  =/  nd=(unit json)  (find-node nav name)
  ?~  nd  ~
  %+  roll  (subtree-docs u.nd)
  |=  [d=@t acc=(map @t (set @ud))]
  %+  roll  ~(tap by (fall (~(get by doc-cov) d) ~))
  |=  [[f=@t s=(set @ud)] a=_acc]
  (~(put by a) f (~(uni in (fall (~(get by a) f) ~)) s))
::  ref-lines: resolve "path [range]" selectors against the line map into
::  per-file line sets — the shared primitive for scopes and ranged ignores.
++  ref-lines
  |=  [finfo=(map @t (list @t)) refs=(list @t)]
  ^-  (map @t (set @ud))
  %+  roll  refs
  |=  [ss=@t acc=(map @t (set @ud))]
  =/  ref=(unit [file=@t commit=(unit @t) from=@ud to=@ud])  (parse-ref (trip ss))
  ?~  ref  acc
  =/  ls=(unit (list @t))  (~(get by finfo) file.u.ref)
  ?~  ls  acc
  =/  total=@ud  (lent u.ls)
  =/  hi=@ud  (min total ?:(=(0 to.u.ref) total to.u.ref))
  =/  lset=(set @ud)
    =/  n=@ud  from.u.ref
    =|  s=(set @ud)
    |-  ^-  (set @ud)
    ?:  (gth n hi)  s
    $(n +(n), s (~(put in s) n))
  (~(put by acc) file.u.ref (~(uni in (fall (~(get by acc) file.u.ref) ~)) lset))
::  section-summaries: one summary per scoped section — {name, covered, total,
::  status} — for the coverage overview.
++  section-summaries
  |=  $:  nav=json
          finfo=(map @t (list @t))
          doc-cov=(map @t (map @t (set @ud)))
          ig-set=(set @t)
          ignore-lines=(map @t (set @ud))
          doc-drift=(set @t)
      ==
  ^-  json
  :-  %a
  %+  turn  (scoped-sections nav)
  |=  name=@t
  ^-  json
  =/  scope-lines=(map @t (set @ud))  (ref-lines finfo (node-cover-scope nav name))
  =/  covered=(map @t (set @ud))  (section-covered doc-cov nav name)
  =/  in-scope
    |=  f=@t
    ^-  (set @ud)
    ?:  (~(has in ig-set) f)  ~
    (~(dif in (fall (~(get by scope-lines) f) ~)) (fall (~(get by ignore-lines) f) ~))
  =/  keys=(list @t)  ~(tap in ~(key by scope-lines))
  =/  total=@ud
    (roll keys |=([f=@t a=@ud] (add a ~(wyt in (in-scope f)))))
  =/  cov=@ud
    %+  roll  keys
    |=  [f=@t a=@ud]
    (add a ~(wyt in (~(int in (fall (~(get by covered) f) ~)) (in-scope f))))
  =/  status=@t  (section-status-of nav name doc-drift)
  %-  pairs:enjs:format
  :~  ['name' s+name]
      ['covered' (numb:enjs:format cov)]
      ['total' (numb:enjs:format total)]
      ['status' s+status]
  ==
::  fold-coverage: the pure core of coverage — given the HEAD line map and the
::  anchors, fold every live block into a cov-state. Each anchor carries
::  `pin-span` — the EXACT lines of its slice AT its pinned commit, read by the
::  host via blob-at-commit (~ = no commit = the block floats at HEAD). A block
::  is FRESH iff it floats or its HEAD slice is byte-for-byte equal to its
::  pinned slice, DRIFTED if they differ, GONE if the file/lines are absent at
::  HEAD. No mug, no stored pins — a direct comparison of the two slices.
++  fold-coverage
  |=  $:  finfo=(map @t (list @t))
          anchors=(list [doc=@t file=@t commit=(unit @t) from=@ud to=@ud pin-span=(unit (list @t))])
          ignore=(list @t)
      ==
  ^-  cov-state
  =/  ig-set=(set @t)
    (silt (skim ~(tap in ~(key by finfo)) |=(s=@t (ignored s ignore))))
  =/  ignore-lines=(map @t (set @ud))
    (ref-lines finfo (skim ignore |=(e=@t !=(~ (find " " (trip e))))))
  =/  nanc=@ud  (lent anchors)
  =+  ^=  res
    =|  cov=(map @t (set @ud))
    =|  flg=(map @t [f=@ud d=@ud g=@ud])
    =|  ancs=(map @t (list json))
    =|  dcv=(map @t (map @t (set @ud)))
    |-  ^-  $:  (map @t (set @ud))
                (map @t [f=@ud d=@ud g=@ud])
                (map @t (list json))
                (map @t (map @t (set @ud)))
            ==
    ?~  anchors  [cov flg ancs dcv]
    =/  a  i.anchors
    =/  fl=[f=@ud d=@ud g=@ud]  (fall (~(get by flg) file.a) [0 0 0])
    =/  al=(list json)  (fall (~(get by ancs) file.a) ~)
    =/  mka
      |=  st=@t
      ^-  json
      %-  pairs:enjs:format
      :~  ['doc' s+doc.a]
          ['commit' ?~(commit.a ~ s+u.commit.a)]
          ['from' (numb:enjs:format from.a)]
          ['to' (numb:enjs:format to.a)]
          ['status' s+st]
      ==
    =/  ls=(unit (list @t))  (~(get by finfo) file.a)
    ?:  |(?=(~ ls) (gth from.a (lent u.ls)))
      %=  $
        anchors  t.anchors
        flg   (~(put by flg) file.a fl(g +(g.fl)))
        ancs  (~(put by ancs) file.a [(mka 'gone') al])
      ==
    =/  total=@ud  (lent u.ls)
    =/  hi=@ud  (min total ?:(=(0 to.a) total to.a))
    =/  s=(set @ud)  (fall (~(get by cov) file.a) ~)
    =/  dm=(map @t (set @ud))  (fall (~(get by dcv) doc.a) ~)
    =/  ds=(set @ud)  (fall (~(get by dm) file.a) ~)
    =^  ds  s
      =/  ln=@ud  from.a
      |-  ^-  [(set @ud) (set @ud)]
      ?:  (gth ln hi)  [ds s]
      $(ln +(ln), s (~(put in s) ln), ds (~(put in ds) ln))
    =/  span=(list @t)  (swag [(dec from.a) +((sub hi from.a))] u.ls)
    ::  fresh if it floats (no commit pinned) or its HEAD slice is exactly its
    ::  slice at the pinned commit; drifted otherwise. A direct comparison —
    ::  both slices are real lines read from the repo, so no hashing is needed.
    =+  ^=  fps
      ?:  |(?=(~ pin-span.a) =(span u.pin-span.a))
        [fl(f +(f.fl)) 'fresh']
      [fl(d +(d.fl)) 'drifted']
    %=  $
      anchors  t.anchors
      cov   (~(put by cov) file.a s)
      dcv   (~(put by dcv) doc.a (~(put by dm) file.a ds))
      flg   (~(put by flg) file.a -.fps)
      ancs  (~(put by ancs) file.a [(mka +.fps) al])
    ==
  =/  fancs=(map @t (list json))  +>-.res
  =/  doc-drift=(set @t)
    %-  ~(gas in *(set @t))
    %-  zing
    %+  turn  ~(val by fancs)
    |=  js=(list json)
    ^-  (list @t)
    %+  murn  js
    |=  j=json
    ^-  (unit @t)
    ?.  ?=([%o *] j)  ~
    =/  st  (~(get by p.j) 'status')
    =/  dc  (~(get by p.j) 'doc')
    ?.  ?=([~ %s *] st)  ~
    ?.  =('drifted' p.u.st)  ~
    ?.  ?=([~ %s *] dc)  ~
    `p.u.dc
  :*  finfo
      ig-set
      ignore-lines
      -.res
      +<.res
      fancs
      doc-drift
      nanc
      +>+.res
  ==
::  render-coverage: the coverage result for one view (whole, or scoped to a
::  section) as a pure function of a loaded cov-state. want-files=%.n skips the
::  per-file list (the cached whole view strips it anyway).
++  render-coverage
  |=  [cs=cov-state nav=json sec=@t want-files=?]
  ^-  json
  =,  cs
  =/  in-section=?  !=('' sec)
  =/  covered=(map @t (set @ud))
    ?.(in-section covered.cs (section-covered doc-cov nav sec))
  =/  scope-strs=(list @t)
    ?:(=('' sec) ~ (node-cover-scope nav sec))
  =/  scope-lines=(map @t (set @ud))
    ?.(in-section ~ (ref-lines finfo scope-strs))
  =/  section-status=@t
    ?.(in-section '' (section-status-of nav sec doc-drift))
  =/  in-scope
    |=  [src=@t ls=(list @t)]
    ^-  (set @ud)
    =/  base=(set @ud)
      ?.  in-section
        =/  n=@ud  1
        =|  s=(set @ud)
        |-  ^-  (set @ud)
        ?:  (gth n (lent ls))  s
        $(n +(n), s (~(put in s) n))
      (fall (~(get by scope-lines) src) ~)
    (~(dif in base) (fall (~(get by ignore-lines) src) ~))
  =/  ign
    |=  src=@t
    ^-  (set @ud)
    (fall (~(get by ignore-lines) src) ~)
  =/  file-jsons=(list json)
    ?.  want-files  ~
    %+  murn  (sort ~(tap by finfo) |=([[a=@t *] [b=@t *]] (aor a b)))
    |=  [src=@t ls=(list @t)]
    ^-  (unit json)
    =/  sc=(set @ud)  (in-scope src ls)
    ?:  &(in-section =(~ sc))  ~
    =/  ig=?  (~(has in ig-set) src)
    =/  fl=[f=@ud d=@ud g=@ud]  (fall (~(get by flags) src) [0 0 0])
    =/  documented=?  |(!=(0 f.fl) !=(0 d.fl) !=(0 g.fl))
    ?:  &(ig !documented)  ~
    =/  cset=(set @ud)  (~(int in (fall (~(get by covered) src) ~)) sc)
    :-  ~
    %-  pairs:enjs:format
    :~  ['file' s+src]
        ['extra' [%b ig]]
        ['total' (numb:enjs:format ~(wyt in sc))]
        ['covered' (numb:enjs:format ~(wyt in cset))]
        ['fresh' (numb:enjs:format f.fl)]
        ['drifted' (numb:enjs:format d.fl)]
        ['gone' (numb:enjs:format g.fl)]
        :-  'ranges'
        :-  %a
        %+  turn  (ranges cset)
        |=([lo=@ud hi=@ud] `json`[%a ~[(numb:enjs:format lo) (numb:enjs:format hi)]])
        :-  'scope'
        :-  %a
        %+  turn  (ranges sc)
        |=([lo=@ud hi=@ud] `json`[%a ~[(numb:enjs:format lo) (numb:enjs:format hi)]])
        ['anchors' [%a (flop (fall (~(get by fancs) src) ~))]]
    ==
  =/  tot-lines=@ud
    %+  roll  ~(tap by finfo)
    |=  [[s=@t l=(list @t)] a=@ud]
    ?:  (~(has in ig-set) s)  a
    ?.  in-section  (add a (sub (lent l) ~(wyt in (ign s))))
    (add a ~(wyt in (in-scope s l)))
  =/  tot-cov=@ud
    %+  roll  ~(tap by covered)
    |=  [[s=@t c=(set @ud)] a=@ud]
    ?:  (~(has in ig-set) s)  a
    ?.  in-section  (add a ~(wyt in (~(dif in c) (ign s))))
    (add a ~(wyt in (~(int in c) (in-scope s (fall (~(get by finfo) s) ~)))))
  =/  tf=[f=@ud d=@ud g=@ud]
    %+  roll  ~(tap by flags)
    |=  [[s=@t x=[f=@ud d=@ud g=@ud]] a=[f=@ud d=@ud g=@ud]]
    ?:  &(in-section =(~ (fall (~(get by scope-lines) s) *(set @ud))))  a
    [(add f.x f.a) (add d.x d.a) (add g.x g.a)]
  %-  pairs:enjs:format
  :~  ['files' [%a file-jsons]]
      ['totalLines' (numb:enjs:format tot-lines)]
      ['coveredLines' (numb:enjs:format tot-cov)]
      ['fresh' (numb:enjs:format f.tf)]
      ['drifted' (numb:enjs:format d.tf)]
      ['gone' (numb:enjs:format g.tf)]
      :-  'section'
      ?:  =('' sec)  ~
      (pairs:enjs:format ~[['name' s+sec] ['status' s+section-status]])
      :-  'sections'
      ?:  in-section  [%a ~]
      (section-summaries nav finfo doc-cov ig-set ignore-lines doc-drift)
  ==
::  cache-name: the coverage cache grub for a collection, keyed by a mug of the
::  collection path.
++  cache-name
  |=  c=path
  ^-  @ta
  `@ta`(rap 3 'cov-' (scot %uv (mug c)) '.json' ~)
--
