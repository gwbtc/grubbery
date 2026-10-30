::  git/transport: smart HTTP protocol
::
::  Pure functions for parsing/building git smart HTTP protocol
::  messages. The caller handles actual HTTP requests.
::
/<  *  /lib/git/hash.hoon
/<  *  /lib/git/object.hoon
/<  *  /lib/git/refs.hoon
|%
+$  git-ref  [=hash =refname]
+$  discovery  [caps=(set @t) refs=(list git-ref)]
::
::  +default-branch: extract default branch from discovery caps
::
::  Parses symref=HEAD:refs/heads/<branch> capability
::
++  default-branch
  |=  caps=(set @t)
  ^-  (unit @t)
  =/  prefix=tape  "symref=HEAD:refs/heads/"
  =/  plen=@ud  (lent prefix)
  =/  match=(unit @t)
    %-  ~(rep in caps)
    |=  [cap=@t found=(unit @t)]
    ?^  found  found
    =/  t=tape  (trip cap)
    ?.  =(prefix (scag plen t))  ~
    `(crip (slag plen t))
  match
::
::  +list-branches: extract branch names from discovery refs
::
++  list-branches
  |=  ref-list=(list git-ref)
  ^-  (list @t)
  =/  prefix=refname  ~['refs' 'heads']
  %+  murn  ref-list
  |=  r=git-ref
  ?.  =(prefix (scag 2 refname.r))  ~
  `(crip (join '/' (turn (slag 2 refname.r) trip)))
::
::  +parse-discovery: parse GET /info/refs?service=git-upload-pack
::
::  Response is pkt-line encoded:
::    001e# service=git-upload-pack\n
::    0000
::    00xx<sha> <refname>\0<caps>\n     (first ref has caps)
::    00xx<sha> <refname>\n
::    ...
::    0000
::
++  parse-discovery
  |=  body=octs
  ^-  discovery
  =/  pos=@ud  0
  ::  skip service header pkt-line
  =^  *  pos  (read-pkt pos body)
  ::  skip flush (0000)
  =^  *  pos  (read-pkt pos body)
  ::  read ref lines until flush
  =|  ref-list=(list git-ref)
  =|  caps=(set @t)
  |-
  =^  pkt=(unit octs)  pos  (read-pkt pos body)
  ?~  pkt  [caps (flop ref-list)]
  ?:  =(0 p.u.pkt)  $  :: skip empty payloads
  =/  line=tape  (trip q.u.pkt)
  ::  strip trailing newline
  =?  line  &(!=(~ line) =((rear line) 10))
    (snip `tape`line)
  ::  first 40 chars = hex SHA, char 41 = space, rest = refname
  =/  hex=tape  (scag 40 line)
  =/  rest=tape  (slag 41 line)
  ::  first ref line has capabilities after NUL byte
  =/  nul=(unit @ud)  (find "\00" rest)
  =/  ref-text=tape  ?~(nul rest (scag u.nul rest))
  =?  caps  ?=(^ nul)
    =/  cap-text=tape  (slag +(u.nul) rest)
    (~(uni in caps) (silt (turn (split cap-text ' ') crip)))
  =/  h=hash  (scan hex parse-hash-sha-1)
  =/  rn=refname
    (fall (rust ref-text parse-refname) ~[(crip ref-text)])
  $(ref-list [[h rn] ref-list])
::
::  +build-want: build POST /git-upload-pack request body
::
::  For a fresh clone (no haves):
::    want <sha> <caps>\n
::    want <sha>\n
::    ...
::    deepen <n>\n       (optional, for shallow clone)
::    0000
::    done\n
::
++  build-want
  |=  [wants=(list hash) caps=(list @t) depth=(unit @ud) haves=(list hash)]
  ^-  octs
  ?>  ?=(^ wants)
  =/  sea=bays:bytestream  *bays:bytestream
  ::  first want line includes capabilities
  =/  first-line=tape
    ;:  weld
      "want "
      (print-hash-sha-1 i.wants)
      ?~(caps ~ " ")
      (join ' ' (turn caps trip))
      "\0a"
    ==
  =.  sea  (append-pkt sea first-line)
  ::  remaining want lines
  =.  sea
    %+  roll  t.wants
    |=  [h=hash s=_sea]
    (append-pkt s (weld "want " (weld (print-hash-sha-1 h) "\0a")))
  ::  deepen for shallow clone
  =?  sea  ?=(^ depth)
    (append-pkt sea (weld "deepen " (weld ((d-co:co 1) u.depth) "\0a")))
  ::  flush separates wants from haves
  =.  sea  (append-octs:bytestream sea [4 '0000'])
  ::  have lines for incremental fetch
  =.  sea
    %+  roll  haves
    |=  [h=hash s=_sea]
    (append-pkt s (weld "have " (weld (print-hash-sha-1 h) "\0a")))
  ::  done
  =.  sea  (append-pkt sea "done\0a")
  (to-octs:bytestream sea)
::
::  +extract-pack: extract raw pack data from upload-pack response
::
::  Without side-band: NAK\n followed by raw PACK data
::  With side-band-64k: NAK\n, then pkt-lines with channel byte:
::    \01 = pack data, \02 = progress, \03 = error
::
++  extract-pack
  |=  [body=octs sideband=?]
  ^-  octs
  =/  pos=@ud  0
  ::  skip pkt-lines until we find NAK or ACK (shallow lines, flushes, etc)
  |-
  =^  pkt=(unit octs)  pos  (read-pkt pos body)
  ?~  pkt  $  :: skip flush, keep looking
  =/  line=tape  (trip q.u.pkt)
  ?.  ?|  =("NAK" (scag 3 line))
          =("NAK\0a" (scag 4 line))
          =("ACK" (scag 3 line))
      ==
    $
  ::  after NAK/ACK: detect format from actual data
  ::  if next 4 bytes are "PACK" signature, it's raw (no sideband)
  =/  next-4=@  (cut 3 [pos 4] q.body)
  ?:  =(next-4 'PACK')
    [(sub p.body pos) (rsh [3 pos] q.body)]
  ::  otherwise demux sideband: collect channel 1 data
  =/  sea=bays:bytestream  *bays:bytestream
  |-
  ?:  (gte pos p.body)
    (to-octs:bytestream sea)
  =^  pkt=(unit octs)  pos  (read-pkt pos body)
  ?~  pkt  (to-octs:bytestream sea)  :: flush = done
  ?:  =(0 p.u.pkt)  $
  =/  channel=@  (cut 3 [0 1] q.u.pkt)
  ?.  =(1 channel)  $  :: skip progress/error channels
  =/  dat=octs  [(dec p.u.pkt) (rsh [3 1] q.u.pkt)]
  $(sea (append-octs:bytestream sea dat))
::
::  +checkout: materialize files from a commit's tree
::
::  Walks the tree recursively, returns list of [path octs]
::  for every blob. Skips submodules (gitlinks).
::
++  checkout
  |=  [get-tree=$-(hash (unit tree-dir)) get-blob=$-(hash (unit octs)) tree-hash=hash]
  ^-  (list [path octs])
  =/  tree=(unit tree-dir)  (get-tree tree-hash)
  ?~  tree  ~
  (walk-tree get-tree get-blob / u.tree)
::
++  walk-tree
  |=  [get-tree=$-(hash (unit tree-dir)) get-blob=$-(hash (unit octs)) here=path dir=tree-dir]
  ^-  (list [path octs])
  %-  zing
  %+  turn  dir
  |=  ent=tree-entry
  ?:  (is-gitlink ent)  ~
  ?:  (is-dir ent)
    =/  sub=(unit tree-dir)  (get-tree hash.ent)
    ?~  sub  ~
    (walk-tree get-tree get-blob (snoc here name.ent) u.sub)
  =/  blob=(unit octs)  (get-blob hash.ent)
  ?~  blob  ~
  ~[[(snoc here name.ent) u.blob]]
::
::  +diff-trees: compare two commit trees, return list of changes
::
::  Walks both trees in parallel by name. Same hash = skip.
::  Different hash on dirs = recurse. Blobs = mod/add/del.
::
+$  tree-change
  $%  [%add =path =hash]
      [%del =path =hash]
      [%mod =path old=hash new=hash]
  ==
::
++  diff-trees
  |=  [get-tree=$-(hash (unit tree-dir)) old=hash new=hash]
  ^-  (list tree-change)
  ?:  =(old new)  ~
  =/  old-dir=(unit tree-dir)  (get-tree old)
  =/  new-dir=(unit tree-dir)  (get-tree new)
  ?~  old-dir  ~
  ?~  new-dir  ~
  (diff-dirs get-tree / u.old-dir u.new-dir)
::
++  diff-dirs
  |=  [get-tree=$-(hash (unit tree-dir)) here=path old=tree-dir new=tree-dir]
  ^-  (list tree-change)
  ::  index entries by name for fast lookup
  =/  new-map=(map @ta tree-entry)
    (malt (turn new |=(e=tree-entry [name.e e])))
  =/  old-map=(map @ta tree-entry)
    (malt (turn old |=(e=tree-entry [name.e e])))
  ::  deletions and modifications from old entries
  =/  del-mod=(list tree-change)
    %-  zing
    %+  turn  old
    |=  o=tree-entry
    ^-  (list tree-change)
    ?:  (is-gitlink o)  ~
    =/  full=path  (snoc here name.o)
    =/  n=(unit tree-entry)  (~(get by new-map) name.o)
    ?~  n
      ?:  (is-dir o)
        =/  sub=(unit tree-dir)  (get-tree hash.o)
        ?~  sub  ~
        %+  turn  (all-blobs get-tree full u.sub)
        |=([p=path h=hash] `tree-change`[%del p h])
      ~[[%del full hash.o]]
    ?:  =(hash.o hash.u.n)  ~
    ?:  &((is-dir o) (is-dir u.n))
      =/  os=(unit tree-dir)  (get-tree hash.o)
      =/  ns=(unit tree-dir)  (get-tree hash.u.n)
      ?~  os  ~
      ?~  ns  ~
      (diff-dirs get-tree full u.os u.ns)
    ?:  &((is-dir o) !(is-dir u.n))
      ::  dir->file: delete all old blobs, add new file
      =/  sub=(unit tree-dir)  (get-tree hash.o)
      ?~  sub  ~[[%add full hash.u.n]]
      =/  dels=(list tree-change)
        (turn (all-blobs get-tree full u.sub) |=([p=path h=hash] `tree-change`[%del p h]))
      (snoc dels `tree-change`[%add full hash.u.n])
    ?:  &(!(is-dir o) (is-dir u.n))
      ::  file->dir: delete old file, add all new blobs
      =/  sub=(unit tree-dir)  (get-tree hash.u.n)
      ?~  sub  ~[[%del full hash.o]]
      =/  adds=(list tree-change)
        (turn (all-blobs get-tree full u.sub) |=([p=path h=hash] `tree-change`[%add p h]))
      [`tree-change`[%del full hash.o] adds]
    ::  blob→blob
    ~[[%mod full hash.o hash.u.n]]
  ::  additions from new entries
  =/  adds=(list tree-change)
    %-  zing
    %+  turn  new
    |=  n=tree-entry
    ^-  (list tree-change)
    ?:  (is-gitlink n)  ~
    ?:  (~(has by old-map) name.n)  ~
    =/  full=path  (snoc here name.n)
    ?:  (is-dir n)
      =/  sub=(unit tree-dir)  (get-tree hash.n)
      ?~  sub  ~
      %+  turn  (all-blobs get-tree full u.sub)
      |=([p=path h=hash] `tree-change`[%add p h])
    ~[[%add full hash.n]]
  (weld del-mod adds)
::
::  +all-blobs: collect all blob paths+hashes from a tree recursively
::
++  all-blobs
  |=  [get-tree=$-(hash (unit tree-dir)) here=path dir=tree-dir]
  ^-  (list [path hash])
  %-  zing
  %+  turn  dir
  |=  ent=tree-entry
  ?:  (is-gitlink ent)  ~
  ?:  (is-dir ent)
    =/  sub=(unit tree-dir)  (get-tree hash.ent)
    ?~  sub  ~
    (all-blobs get-tree (snoc here name.ent) u.sub)
  ~[[(snoc here name.ent) hash.ent]]
::
::  +write-pack: a version-2 packfile holding the given objects. Every
::  entry is a whole object (no deltas), compressed as zlib stored
::  blocks, so the writer needs no deflate: the receiver inflates it like
::  any other pack. Trailer is the SHA-1 of everything before it.
::
++  write-pack
  |=  objs=(list raw-object)
  ^-  octs
  =/  sea=bays:bytestream  *bays:bytestream
  =.  sea  (append-octs:bytestream sea (as-octt:bytestream "PACK"))
  =.  sea  (append-octs:bytestream sea [4 (rev 3 4 2)])
  =.  sea  (append-octs:bytestream sea [4 (rev 3 4 (lent objs))])
  =.  sea
    %+  roll  objs
    |=  [rob=raw-object s=_sea]
    =.  s  (append-octs:bytestream s (pack-entry-header type.rob size.rob))
    (append-octs:bytestream s (zlib-stored data.rob))
  =/  sum=@ux  (hash-octs-sha-1 (to-octs:bytestream sea))
  (to-octs:bytestream (append-hash sea %sha-1 sum))
::
::  +pack-entry-header: the varint object header of a pack entry. Low
::  nibble of the first byte and seven bits per byte after, LSB first;
::  the type sits in bits 4-6 of the first byte; 0x80 continues.
::
++  pack-entry-header
  |=  [type=object-type size=@ud]
  ^-  octs
  =/  tnum=@  ?-(type %commit 1, %tree 2, %blob 3, %tag 4)
  =/  first=@  (con (lsh [0 4] tnum) (dis size 0xf))
  =/  rest=@ud  (rsh [0 4] size)
  ?:  =(0 rest)  [1 first]
  =/  bytes=(list @)  ~[(con first 0x80)]
  |-
  =/  b=@  (dis rest 0x7f)
  =/  more=@ud  (rsh [0 7] rest)
  ?:  =(0 more)
    =/  all=(list @)  (flop [b bytes])
    [(lent all) (rep 3 all)]
  $(bytes [(con b 0x80) bytes], rest more)
::
::  +zlib-stored: a zlib stream with no compression: the two-byte
::  header, stored blocks of at most 65535 bytes, and the adler32.
::
++  zlib-stored
  |=  data=octs
  ^-  octs
  =/  sea=bays:bytestream  *bays:bytestream
  =.  sea  (append-octs:bytestream sea [2 0x178])
  =/  pos=@ud  0
  =.  sea
    |-  ^-  bays:bytestream
    =/  left=@ud  (sub p.data pos)
    =/  len=@ud  (min left 65.535)
    =/  last=?  (lte left 65.535)
    =.  sea  (append-byte:bytestream sea ?:(last 0x1 0x0))
    =.  sea  (append-octs:bytestream sea [2 len])
    =.  sea  (append-octs:bytestream sea [2 (mix len 0xffff)])
    =.  sea  (append-octs:bytestream sea [len (cut 3 [pos len] q.data)])
    ?:  last  sea
    $(pos (add pos len))
  =.  sea  (append-octs:bytestream sea [4 (rev 3 4 (adler32:adler:checksum data))])
  (to-octs:bytestream sea)
::
::  +build-push-request: the body of POST /git-receive-pack. One
::  command line, old and new tip for the ref with capabilities after
::  the NUL, a flush, then the pack.
::
++  build-push-request
  |=  [old=hash new=hash refname=tape caps=(list @t) pack=octs]
  ^-  octs
  ::  built as octs, not a tape: the NUL between the ref and the
  ::  capabilities has no width in a cord and would vanish under +crip
  =/  line=octs
    %-  can-octs:bytestream
    :~  (as-octt:bytestream (print-hash-sha-1 old))
        [1 ' ']
        (as-octt:bytestream (print-hash-sha-1 new))
        [1 ' ']
        (as-octt:bytestream refname)
        [1 0x0]
        (as-octt:bytestream (join ' ' (turn caps trip)))
        [1 0xa]
    ==
  =/  len=octs  (as-octt:bytestream (print-hex-pad (add 4 p.line) 4))
  (can-octs:bytestream ~[len line [4 '0000'] pack])
::
::  +parse-push-response: the report-status reply. ~ when the server
::  unpacked and updated the ref; otherwise the lines it sent.
::
++  parse-push-response
  |=  body=octs
  ^-  (unit tape)
  =/  all=(list tape)  (report-lines body)
  =/  unpacked=?  (lien all |=(l=tape =("unpack ok" (scag 9 l))))
  =/  refused=?  (lien all |=(l=tape =("ng " (scag 3 l))))
  ?:  &(unpacked !refused)  ~
  `(join ' ' all)
::
::  +report-lines: every pkt-line payload in a report-status reply, with
::  side-band demuxed: GitHub wraps the report in channel 1 even when it
::  was not asked for, so a channel-1 payload is itself a run of
::  pkt-lines; channels 2 and 3 are text to keep as they are.
::
++  report-lines
  |=  body=octs
  ^-  (list tape)
  =/  pos=@ud  0
  =|  lines=(list tape)
  |-
  ?:  (gth (add pos 4) p.body)  (flop lines)
  =^  pkt=(unit octs)  pos  (read-pkt pos body)
  ?~  pkt  $
  ?:  =(0 p.u.pkt)  $
  =/  chan=@  (cut 3 [0 1] q.u.pkt)
  ?:  =(1 chan)
    =/  inner=octs  [(dec p.u.pkt) (rsh [3 1] q.u.pkt)]
    $(lines (weld (flop (report-lines inner)) lines))
  =/  text=octs  ?:(|(=(2 chan) =(3 chan)) [(dec p.u.pkt) (rsh [3 1] q.u.pkt)] u.pkt)
  =/  line=tape  (trip q.text)
  =?  line  &(!=(~ line) =((rear line) 10))  (snip `tape`line)
  $(lines [line lines])
::
::  Helpers
::
++  read-pkt
  |=  [pos=@ud body=octs]
  ^-  [(unit octs) @ud]
  ?:  (gth (add pos 4) p.body)  [~ pos]
  =/  hex=tape  (trip (cut 3 [pos 4] q.body))
  =/  len=@ud  (scan hex (bass 16 (plus hit)))
  ?:  =(0 len)  [~ (add pos 4)]  :: flush
  =/  payload-len=@ud  (sub len 4)
  ?:  =(0 payload-len)  [`[0 0x0] (add pos 4)]
  [`[(min payload-len (sub p.body (add pos 4))) (cut 3 [(add pos 4) payload-len] q.body)] (add pos len)]
::
++  append-pkt
  |=  [sea=bays:bytestream payload=tape]
  ^-  bays:bytestream
  =/  dat=octs  (as-octt:bytestream payload)
  =/  total=@ud  (add 4 p.dat)
  =/  len=tape  (print-hex-pad total 4)
  =.  sea  (append-octs:bytestream sea (as-octt:bytestream len))
  (append-octs:bytestream sea dat)
::
++  print-hex-pad
  |=  [val=@ud wid=@ud]
  ^-  tape
  =/  raw=tape  ((x-co:co 1) val)
  =/  pad=@ud  ?:((gte (lent raw) wid) 0 (sub wid (lent raw)))
  (weld (reap pad '0') raw)
::
++  split
  |=  [t=tape del=@t]
  ^-  (list tape)
  =|  acc=(list tape)
  =|  cur=tape
  |-
  ?~  t  (flop [(flop cur) acc])
  ?:  =(i.t del)
    $(t t.t, acc [(flop cur) acc], cur ~)
  $(t t.t, cur [i.t cur])
::
++  join
  |=  [del=@t ts=(list tape)]
  ^-  tape
  ?~  ts  ~
  ?~  t.ts  i.ts
  (weld i.ts [del (join del t.ts)])
--
