::  rhizome nexus: wiki-linked markdown notes with backlink tracking
::
::  /rhizome.rhizome/
::    main.sig              watches vault, maintains backlink index
::    page.html             rendered note list with backlinks
::    vault/
::      <name>.md           markdown notes with [[wiki links]]
::    metadata/
::      <name>.json         backlink metadata per note
::
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  =ver:loader  (get-ver:loader ball)
      ?+  ver  !!
          ?(~ [~ %0])
        %+  spin:loader  ball
        :~  (ver-row:loader 0)
            [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
            [%fall %& [/ %'page.html'] [[/ %html] (crip (en-xml:html ;div:"rhizome loading..."))]]
            [%fall %| /vault empty-dir:loader]
            [%fall %| /metadata empty-dir:loader]
        ==
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::  main.sig: watch vault, compute wiki links, sync metadata
          ::
          ::  state: (map @ta (set @ta)) — forward index
          ::  keys are note filenames (e.g. 'pasta.md'),
          ::  values are sets of link targets (e.g. 'sauce')
          ::
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%rhizome /main: failed")
        ~&  >  "%rhizome /main: starting"
        ;<  init=wave:nexus  bind:m
          (keep:io /vault (cord-to-road:tarball './vault/') ~)
        ;<  =seen:nexus  bind:m  (peek:io (cord-to-road:tarball './vault/') ~)
        =/  old-ball=ball:tarball  (ball-from-seen seen)
        =/  notes=(map @ta @t)  (files-from-ball old-ball)
        =/  fwd=fwd-index
          %-  ~(run by notes)
          |=(txt=@t (extract-wiki-links txt))
        =/  back=back-index  (invert-index fwd)
        ::  on startup, create metadata for all notes
        =/  creates=(list @ta)  ~(tap in ~(key by fwd))
        ;<  ~  bind:m
          |-  ^-  form:m
          ?~  creates  (pure:m ~)
          =/  fname=@ta  i.creates
          =/  mname=@ta  (note-to-meta-name fname)
          =/  link-name=@ta  (fname-to-link fname)
          ;<  ~  bind:m
            (make:io (meta-road mname) |+[[[/ %json] (meta-json (~(gut by fwd) fname ~) (~(gut by back) link-name ~))] `[/ %json]])
          $(creates t.creates)
        ~&  >  "%rhizome /main: indexed {<~(wyt by notes)>} notes"
        ::  main loop
        |-
        ;<  upd=wave:nexus  bind:m  (take-news:io /vault)
        ;<  =seen:nexus  bind:m  (peek:io (cord-to-road:tarball './vault/') ~)
        =/  new-ball=ball:tarball  (ball-from-seen seen)
        =/  changed=(set @ta)
          (file-names-from-lanes (changed-lanes:nexus old-ball new-ball))
        =/  new-notes=(map @ta @t)  (files-from-ball new-ball)
        ::  only reparse files that changed
        =/  new-fwd=fwd-index
          %-  ~(rep by new-notes)
          |=  [[fname=@ta txt=@t] out=fwd-index]
          ?.  (~(has in changed) fname)
            (~(put by out) fname (~(gut by fwd) fname ~))
          (~(put by out) fname (extract-wiki-links txt))
        ::  also drop deleted files from fwd
        =/  deleted=(list @ta)
          %+  murn  ~(tap in changed)
          |=(f=@ta ?:((~(has by new-notes) f) ~ `f))
        =.  new-fwd
          %-  ~(rep in (silt deleted))
          |=([f=@ta out=_new-fwd] (~(del by out) f))
        =/  new-back=back-index  (invert-index new-fwd)
        =/  ops=(list meta-op)  (compute-meta-ops fwd new-fwd new-back)
        ;<  ~  bind:m
          |-  ^-  form:m
          ?~  ops  (pure:m ~)
          ?-    -.i.ops
              %create
            ;<  ~  bind:m
              (make:io (meta-road mname.i.ops) |+[[[/ %json] json.i.ops] `[/ %json]])
            $(ops t.ops)
              %update
            ;<  ~  bind:m
              (poke:io (meta-road mname.i.ops) [[/ %json] json.i.ops])
            $(ops t.ops)
              %delete
            ;<  ~  bind:m
              (cull:io (meta-road mname.i.ops))
            $(ops t.ops)
          ==
        $(fwd new-fwd, old-ball new-ball)
          ::
          ::  page.html: render note index with backlinks
          ::
          [~ %'page.html']
        ;<  ~  bind:m  (rise-wait:io prod "%rhizome /page: failed")
        ;<  vault-wave=wave:nexus  bind:m
          (keep:io /vault (cord-to-road:tarball './vault/') ~)
        ;<  vault-seen=seen:nexus  bind:m  (peek:io (cord-to-road:tarball './vault/') ~)
        =/  notes=(map @ta @t)  (files-from-ball (ball-from-seen vault-seen))
        =/  fwd=fwd-index
          %-  ~(run by notes)
          |=(txt=@t (extract-wiki-links txt))
        =/  back=back-index  (invert-index fwd)
        ;<  ~  bind:m  (replace:io !>((crip (en-xml:html (rhizome-page notes fwd back)))))
        |-
        ;<  upd=wave:nexus  bind:m  (take-news:io /vault)
        ;<  vault-seen=seen:nexus  bind:m  (peek:io (cord-to-road:tarball './vault/') ~)
        =/  notes=(map @ta @t)  (files-from-ball (ball-from-seen vault-seen))
        =/  fwd=fwd-index
          %-  ~(run by notes)
          |=(txt=@t (extract-wiki-links txt))
        =/  back=back-index  (invert-index fwd)
        ;<  ~  bind:m  (replace:io !>((crip (en-xml:html (rhizome-page notes fwd back)))))
        $
          ::
          ::  metadata/*.json: accept metadata updates from main.sig
          ::
          [[%metadata ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%rhizome /metadata: failed")
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        ?.  =(%json name.p.sage)  $
        ;<  ~  bind:m  (replace:io q.sage)
        $
          ::
          ::  vault/*.md: passive notes, accept content pokes
          ::
          [[%vault ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%rhizome /vault: failed")
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        ;<  ~  bind:m  (replace:io q.sage)
        $
      ==
    ::
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'Subdirectory under the rhizome nexus.'
            ~
          %-  crip
          """
          RHIZOME NEXUS — wiki-linked markdown notes with backlink tracking

          Store markdown notes in /vault/ with [[wiki links]]. The system
          automatically parses links and maintains a /metadata/ directory
          with forward links (links-to) and backlinks (linked-from) for
          each note. Page at page.html renders the full index.

          FILES:
            main.sig          Vault watcher. Parses [[wiki links]], syncs metadata.
            page.html         Rendered note index with backlinks (manx).

          DIRECTORIES:
            vault/            Markdown notes. Create .md files here.
            metadata/         Auto-generated backlink metadata (JSON).
          """
            [%vault ~]
          'Markdown notes with [[wiki links]]. Create .md files here.'
            [%metadata ~]
          'Auto-generated backlink metadata. One JSON file per note.'
        ==
          %|
        ?+  rail.p.mana  'File under the rhizome nexus.'
          [~ %'main.sig']   'Vault watcher. Parses wiki links and syncs metadata.'
          [~ %'page.html']  'Rendered note index with backlinks.'
        ==
      ==
    --
::
::  helper core
::
|%
+$  fwd-index   (map @ta (set @ta))  :: note-fname → set of link targets
+$  back-index  (map @ta (set @ta))  :: link-target → set of source fnames
+$  meta-op     $%  [%create mname=@ta =json]
                    [%update mname=@ta =json]
                    [%delete mname=@ta]
                ==
::
::  extract-wiki-links: scan text for [[link]] patterns
::  returns set of link targets (bare names, no extension)
::
++  extract-wiki-links
  |=  txt=@t
  ^-  (set @ta)
  =/  t=tape  (trip txt)
  =|  links=(set @ta)
  |-  ^-  (set @ta)
  ?~  t  links
  ?.  ?=([%'[' %'[' *] t)
    $(t +.t)
  =/  rest=tape  +.+.t
  =|  name=tape
  |-  ^-  (set @ta)
  ?~  rest  ^$(t +.t)
  ?:  ?=([%']' %']' *] rest)
    =/  link=@ta  (crip name)
    ?:  =('' link)  ^$(t +.+.rest)
    ^$(t +.+.rest, links (~(put in links) link))
  ?:  =('\0a' i.rest)  ^$(t +.t)  :: no newlines in links
  $(rest +.rest, name (snoc name i.rest))
::
::  invert-index: forward index → backlinks index
::  'pasta.md' links to 'sauce' → 'sauce' is linked-from 'pasta.md'
::
++  invert-index
  |=  fwd=fwd-index
  ^-  back-index
  %-  ~(rep by fwd)
  |=  [[src=@ta targets=(set @ta)] out=back-index]
  =/  tgts=(list @ta)  ~(tap in targets)
  |-  ^-  back-index
  ?~  tgts  out
  =/  existing=(set @ta)  (~(gut by out) i.tgts ~)
  $(tgts t.tgts, out (~(put by out) i.tgts (~(put in existing) src)))
::
::  ball-from-seen: extract ball from a peek result
::
++  ball-from-seen
  |=  =seen:nexus
  ^-  ball:tarball
  ?.  ?=([%& %ball *] seen)  *ball:tarball
  ball.p.seen
::
::  files-from-ball: recursively extract txt files from a ball
::  returns map of relative paths (e.g. 'cooking/pasta.md') to text
::
++  files-from-ball
  |=  =ball:tarball
  ^-  (map @ta @t)
  (files-from-ball-at '' ball)
::
++  files-from-ball-at
  |=  [prefix=@ta =ball:tarball]
  ^-  (map @ta @t)
  =|  out=(map @ta @t)
  ::  files at this level
  =.  out
    =/  =lump:tarball  (fall fil.ball *lump:tarball)
    %-  ~(rep by contents.lump)
    |=  [[name=@ta =content:tarball] acc=(map @ta @t)]
    ?.  =(%txt name.p.content)  acc
    =/  key=@ta  ?:(=('' prefix) name (crip "{(trip prefix)}/{(trip name)}"))
    (~(put by acc) key (of-wain:format !<(wain (need-vase:tarball content))))
  ::  recurse into subdirectories
  =/  kids=(list [@ta ball:tarball])  ~(tap by dir.ball)
  |-  ^-  (map @ta @t)
  ?~  kids  out
  =/  [dname=@ta kid=ball:tarball]  i.kids
  =/  kid-prefix=@ta  ?:(=('' prefix) dname (crip "{(trip prefix)}/{(trip dname)}"))
  =/  kid-files=(map @ta @t)  (files-from-ball-at kid-prefix kid)
  =.  out  (~(uni by out) kid-files)
  $(kids t.kids)
::
::  file-names-from-lanes: extract relative paths from lane set
::  e.g. lane &+[/cooking %'pasta.md'] → 'cooking/pasta.md'
::
++  file-names-from-lanes
  |=  lanes=(set lane:tarball)
  ^-  (set @ta)
  %-  ~(rep in lanes)
  |=  [=lane:tarball out=(set @ta)]
  ?.  ?=([%& *] lane)  out
  =/  segs=(list @ta)  (snoc path.p.lane name.p.lane)
  =/  relpath=@ta  (crip (zing (join "/" (turn segs trip))))
  (~(put in out) relpath)
::
::  note-to-meta-name: 'pasta.md' → 'pasta.json'
::  also works with paths: 'cooking/pasta.md' → 'cooking/pasta.json'
::
++  note-to-meta-name
  |=  fname=@ta
  ^-  @ta
  =/  t=tape  (trip fname)
  =/  base=tape
    ?.  =(".md" (slag (sub (lent t) 3) t))  t
    (scag (sub (lent t) 3) t)
  (crip (weld base ".json"))
::
::  meta-road: build road to metadata file from relative path cord
::  e.g. 'cooking/pasta.json' → [%| 0 %& /metadata/cooking %'pasta.json']
::
++  meta-road
  |=  relpath=@ta
  ^-  road:tarball
  =/  parts=(list @ta)  (split-fas relpath)
  [%| 0 %& (weld /metadata (snip parts)) (rear parts)]
::
::  split-fas: split a cord on '/' into segments
::  e.g. 'cooking/pasta.json' → ~['cooking' 'pasta.json']
::       'pasta.json' → ~['pasta.json']
::
++  split-fas
  |=  t=@ta
  ^-  (list @ta)
  =/  chars=tape  (trip t)
  =|  [seg=tape out=(list @ta)]
  |-  ^-  (list @ta)
  ?~  chars  (flop [(crip seg) out])
  ?:  =(i.chars '/')
    $(chars t.chars, seg ~, out [(crip seg) out])
  $(chars t.chars, seg (snoc seg i.chars))
::
::  fname-to-link: 'pasta.md' → 'pasta'
::
++  fname-to-link
  |=  fname=@ta
  ^-  @ta
  =/  t=tape  (trip fname)
  ?.  =(".md" (slag (sub (lent t) 3) t))  fname
  (crip (scag (sub (lent t) 3) t))
::
::  link-to-fname: 'pasta' → 'pasta.md'
::
++  link-to-fname
  |=  link=@ta
  ^-  @ta
  (crip (weld (trip link) ".md"))
::
::  meta-json: build metadata json for a note
::
++  meta-json
  |=  [links-to=(set @ta) linked-from=(set @ta)]
  ^-  json
  %-  pairs:enjs:format
  :~  ['links-to' (set-to-json links-to)]
      ['linked-from' (set-to-json linked-from)]
  ==
::
++  set-to-json
  |=  s=(set @ta)
  ^-  json
  [%a (turn ~(tap in s) |=(t=@ta s+t))]
::
::  compute-meta-ops: pure function that diffs indices and returns ops
::
++  compute-meta-ops
  |=  [old=fwd-index new=fwd-index back=back-index]
  ^-  (list meta-op)
  ::  notes that need metadata created (new)
  =/  to-create=(list @ta)
    %+  murn  ~(tap in ~(key by new))
    |=(fname=@ta ?.((~(has by old) fname) `fname ~))
  ::  notes that need metadata updated (changed links)
  =/  to-update=(list @ta)
    %+  murn  ~(tap in ~(key by new))
    |=  fname=@ta
    =/  old-links  (~(gut by old) fname ~)
    =/  new-links  (~(gut by new) fname ~)
    ?.  &((~(has by old) fname) !=(old-links new-links))
      ~
    `fname
  ::  notes that need metadata deleted (removed)
  =/  to-delete=(list @ta)
    %+  murn  ~(tap in ~(key by old))
    |=(fname=@ta ?:((~(has by new) fname) ~ `fname))
  ::  also update metadata for all targets whose backlinks changed
  =/  affected=(set @ta)
    %-  ~(rep in (~(uni in (silt to-create)) (~(uni in (silt to-update)) (silt to-delete))))
    |=  [fname=@ta out=(set @ta)]
    =/  old-targets  (~(gut by old) fname ~)
    =/  new-targets  (~(gut by new) fname ~)
    (~(uni in out) (~(uni in old-targets) new-targets))
  ::  affected targets that aren't already handled
  =/  targets-to-update=(list @ta)
    %+  murn  ~(tap in affected)
    |=  link-name=@ta
    =/  fname=@ta  (link-to-fname link-name)
    ?:  (~(has in (silt to-create)) fname)  ~
    ?:  (~(has in (silt to-update)) fname)  ~
    ?:  (~(has in (silt to-delete)) fname)  ~
    ?.  (~(has by old) fname)
      ?.  (~(has by new) fname)  ~
      ~
    `fname
  ::  build op list
  =/  ops=(list meta-op)  ~
  ::  creates
  =.  ops
    %-  welp  :_  ops
    %+  turn  to-create
    |=  fname=@ta
    =/  link-name=@ta  (fname-to-link fname)
    :*  %create
        (note-to-meta-name fname)
        (meta-json (~(gut by new) fname ~) (~(gut by back) link-name ~))
    ==
  ::  updates
  =.  ops
    %-  welp  :_  ops
    %+  turn  to-update
    |=  fname=@ta
    =/  link-name=@ta  (fname-to-link fname)
    :*  %update
        (note-to-meta-name fname)
        (meta-json (~(gut by new) fname ~) (~(gut by back) link-name ~))
    ==
  ::  affected target updates
  =.  ops
    %-  welp  :_  ops
    %+  turn  targets-to-update
    |=  fname=@ta
    =/  link-name=@ta  (fname-to-link fname)
    :*  %update
        (note-to-meta-name fname)
        (meta-json (~(gut by new) fname ~) (~(gut by back) link-name ~))
    ==
  ::  deletes
  =.  ops
    %-  welp  :_  ops
    %+  turn  to-delete
    |=(fname=@ta [%delete (note-to-meta-name fname)])
  ops
::
::  rhizome-page: render the note editor page
::
++  rhizome-page
  |=  [notes=(map @ta @t) fwd=fwd-index back=back-index]
  ^-  manx
  ;html
    ;head
      ;title: Rhizome
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;link(rel "icon", href "data:,");
      ;style
        ;+  ;/  page-css
      ==
    ==
    ;body
      ;div.toolbar
        ;span.title: Rhizome
        ;span.info: {<~(wyt by notes)>} notes
        ;input#new-name(type "text", placeholder "new-note");
        ;button#new-btn.btn: + New
      ==
      ;div.panes
        ;div#tree-pane.tree-pane
          ;div#tree;
        ==
        ;div#content.content-pane
          ;div.placeholder: select a note
        ==
      ==
      ;script
        ;+  ;/  (notes-json notes)
      ==
      ;script
        ;+  ;/  (links-json fwd back)
      ==
      ;script
        ;+  ;/  page-js
      ==
    ==
  ==
::
::  notes-json: inject note text as JS object
::
++  notes-json
  |=  notes=(map @ta @t)
  ^-  tape
  =/  pairs=(list [@ta @t])
    (sort ~(tap by notes) |=([[a=@ta *] [b=@ta *]] (aor a b)))
  =/  out=tape  "window._NOTES=\{"
  =/  first=?  %.y
  |-  ^-  tape
  ?~  pairs  (weld out "};")
  =/  [fname=@ta txt=@t]  i.pairs
  =/  escaped=tape  (escape-js (trip txt))
  =.  out
    ;:  weld  out
      ?:(first "" ",")
      "\"{(trip fname)}\":\"{escaped}\""
    ==
  $(pairs t.pairs, first %.n)
::
::  links-json: inject forward and back links as JS objects
::
++  links-json
  |=  [fwd=fwd-index back=back-index]
  ^-  tape
  ;:  weld
    "window._FWD="  (index-to-js fwd)  ";"
    "window._BACK="  (index-to-js back)  ";"
  ==
::
++  index-to-js
  |=  idx=(map @ta (set @ta))
  ^-  tape
  =/  pairs=(list [@ta (set @ta)])  ~(tap by idx)
  =/  out=tape  "\{"
  |-  ^-  tape
  ?~  pairs  (weld out "}")
  =/  [k=@ta v=(set @ta)]  i.pairs
  =/  arr=tape
    =/  items=(list @ta)  (sort ~(tap in v) aor)
    =/  a=tape  "["
    |-  ^-  tape
    ?~  items  (weld a "]")
    =/  sep=tape  ?~(t.items "" ",")
    $(items t.items, a ;:(weld a "\"{(trip i.items)}\"" sep))
  =.  out  ;:(weld out "\"{(trip k)}\":" arr)
  ?~  t.pairs  (weld out "}")
  $(pairs t.pairs, out (weld out ","))
::
++  escape-js
  |=  t=tape
  ^-  tape
  =|  out=tape
  |-  ^-  tape
  ?~  t  out
  =/  c=@t  i.t
  =.  out
    ?+  c  (snoc out c)
      %'\\'  (weld out "\\\\")
      %'"'   (weld out "\\\"")
      %'\0a'  (weld out "\\n")
      %'\0d'  (weld out "\\r")
    ==
  $(t +.t)
::
++  page-css
  ^-  tape
  ;:  weld
    "* \{ box-sizing: border-box; margin: 0; padding: 0; }"
    " html, body \{ height: 100%; font-family: monospace; }"
    " body \{ display: flex; flex-direction: column; }"
    " .toolbar \{ display: flex; align-items: center; gap: 8px; padding: 8px 12px; "
    "   border-bottom: 1px solid #e0e0e0; background: #fafafa; flex-shrink: 0; }"
    " .toolbar .title \{ font-weight: bold; font-size: 14px; }"
    " .toolbar .info \{ opacity: 0.5; font-size: 12px; }"
    " .toolbar input \{ font-family: monospace; font-size: 12px; border: 1px solid #ccc; "
    "   padding: 2px 6px; width: 140px; margin-left: auto; }"
    " .btn \{ font-family: monospace; font-size: 12px; border: 1px solid #ccc; "
    "   padding: 2px 8px; cursor: pointer; background: none; }"
    " .btn:hover \{ background: #e8e8e8; }"
    " .panes \{ display: flex; flex: 1; overflow: hidden; }"
    " .tree-pane \{ width: 220px; border-right: 1px solid #e0e0e0; overflow-y: auto; "
    "   padding: 4px 0; flex-shrink: 0; }"
    " .content-pane \{ flex: 1; display: flex; flex-direction: column; overflow: hidden; min-width: 0; }"
    " .dir-label \{ display: flex; align-items: center; padding: 2px 8px; cursor: pointer; font-size: 13px; }"
    " .dir-label:hover \{ background: #f0f0f0; }"
    " .dir-label .arrow \{ width: 14px; font-size: 9px; flex-shrink: 0; transition: transform 0.1s; }"
    " .dir-label .arrow.open \{ transform: rotate(90deg); }"
    " .dir-children \{ display: none; }"
    " .dir.open > .dir-children \{ display: block; }"
    " .file \{ padding: 4px 12px; cursor: pointer; font-size: 13px; }"
    " .file:hover \{ background: #f0f0f0; }"
    " .file.active \{ background: #e8f0fe; }"
    " .muted \{ opacity: 0.4; padding: 12px; font-size: 12px; }"
    " .placeholder \{ opacity: 0.3; padding: 3rem; text-align: center; }"
    " .editor-wrap \{ display: flex; flex-direction: column; height: 100%; }"
    " .editor-header \{ display: flex; align-items: center; gap: 8px; padding: 8px 12px; "
    "   border-bottom: 1px solid #e0e0e0; flex-shrink: 0; }"
    " .editor-header .fname \{ font-weight: bold; font-size: 13px; }"
    " .editor-header .saved \{ opacity: 0.4; font-size: 11px; }"
    " .editor-header .dirty \{ color: #cb2431; font-size: 11px; }"
    " .split-edit \{ display: flex; flex: 1; overflow: hidden; }"
    " .edit-pane \{ flex: 1; display: flex; flex-direction: column; min-width: 0; }"
    " .edit-pane textarea \{ flex: 1; border: none; outline: none; resize: none; padding: 12px; "
    "   font-family: monospace; font-size: 13px; line-height: 1.6; border-right: 1px solid #e0e0e0; }"
    " .preview-pane \{ flex: 1; overflow-y: auto; padding: 12px; font-size: 13px; "
    "   line-height: 1.6; min-width: 0; }"
    " .preview-pane h1 \{ font-size: 1.4em; margin: 0.5em 0 0.3em; }"
    " .preview-pane h2 \{ font-size: 1.2em; margin: 0.5em 0 0.3em; }"
    " .preview-pane h3 \{ font-size: 1.05em; margin: 0.5em 0 0.3em; }"
    " .preview-pane p \{ margin: 0.4em 0; }"
    " .preview-pane code \{ background: #f0f0f0; padding: 1px 4px; border-radius: 3px; font-size: 12px; }"
    " .preview-pane pre code \{ display: block; padding: 8px; overflow-x: auto; }"
    " .preview-pane ul, .preview-pane ol \{ margin: 0.4em 0; padding-left: 1.5em; }"
    " .preview-pane blockquote \{ border-left: 3px solid #ccc; padding-left: 8px; opacity: 0.7; margin: 0.4em 0; }"
    " .preview-pane .wiki-link \{ color: #0366d6; cursor: pointer; }"
    " .preview-pane .wiki-link:hover \{ text-decoration: underline; }"
    " .preview-pane .wiki-link.broken \{ color: #cb2431; }"
    " .links-bar \{ border-top: 1px solid #e0e0e0; padding: 8px 12px; font-size: 12px; "
    "   flex-shrink: 0; max-height: 120px; overflow-y: auto; }"
    " .links-bar .section \{ margin-bottom: 4px; }"
    " .links-bar .label \{ font-weight: bold; margin-right: 4px; }"
    " .links-bar .link \{ color: #0366d6; cursor: pointer; margin-right: 6px; }"
    " .links-bar .link:hover \{ text-decoration: underline; }"
  ==
::
++  page-js
  ^-  tape
  ;:  weld
    "var cur=null,dirty=false;"
    "var MAKE=window.location.pathname.replace('/ball/','/api/file/').replace('page.html','vault/');"
    "var OVER=window.location.pathname.replace('/ball/','/api/over/').replace('page.html','vault/');"
    ""
    "function selectNote(fname)\{"
    "  if(dirty&&!confirm('Discard changes?'))return;"
    "  document.querySelectorAll('.file.active').forEach(function(e)\{e.classList.remove('active')});"
    "  var el=document.querySelector('.file[data-name=\"'+fname+'\"]');"
    "  if(el)el.classList.add('active');"
    "  cur=fname;"
    "  dirty=false;"
    "  var pane=document.getElementById('content');"
    "  var txt=window._NOTES[fname]||'';"
    "  var linkName=fname.replace(/\\.md$/,'');"
    "  var fwdLinks=(window._FWD[fname]||[]);"
    "  var backLinks=(window._BACK[linkName]||[]);"
    "  pane.innerHTML="
    "    '<div class=\"editor-wrap\">'+"
    "    '<div class=\"editor-header\">'+"
    "    '<span class=\"fname\">'+fname+'</span>'+"
    "    '<button class=\"btn\" id=\"save-btn\" onclick=\"saveNote()\">Save</button>'+"
    "    '<span id=\"status\" class=\"saved\">saved</span>'+"
    "    '</div>'+"
    "    '<div class=\"split-edit\">'+"
    "    '<div class=\"edit-pane\"><textarea id=\"editor\">'+escHtml(txt)+'</textarea></div>'+"
    "    '<div class=\"preview-pane\" id=\"preview\"></div>'+"
    "    '</div>'+"
    "    '<div class=\"links-bar\">'+"
    "    (fwdLinks.length?'<div class=\"section\"><span class=\"label\">links to:</span>'+fwdLinks.map(function(l)\{return '<span class=\"link\" onclick=\"navLink(\\''+l+'\\')\">' + l + '</span>'}).join('')+'</div>':'')+"
    "    (backLinks.length?'<div class=\"section\"><span class=\"label\">linked from:</span>'+backLinks.map(function(l)\{return '<span class=\"link\" onclick=\"selectNote(\\''+l+'\\')\">' + l + '</span>'}).join('')+'</div>':'')+"
    "    '</div></div>';"
    "  renderPreview(txt);"
    "  document.getElementById('editor').oninput=function()\{"
    "    dirty=true;"
    "    document.getElementById('status').className='dirty';"
    "    document.getElementById('status').textContent='unsaved';"
    "    renderPreview(this.value);"
    "  };"
    "  document.getElementById('editor').onkeydown=function(e)\{"
    "    if((e.ctrlKey||e.metaKey)&&e.key==='s')\{e.preventDefault();saveNote()}"
    "  };"
    "}"
    ""
    "function navLink(name)\{"
    "  var fname=name+'.md';"
    "  if(window._NOTES[fname]!=null)selectNote(fname);"
    "}"
    ""
    "function escHtml(s)\{"
    "  var d=document.createElement('div');d.textContent=s;return d.innerHTML;"
    "}"
    ""
    "function saveNote()\{"
    "  if(!cur)return;"
    "  var txt=document.getElementById('editor').value;"
    "  fetch(OVER+cur+'?mark=txt',\{method:'POST',"
    "    headers:\{'Content-Type':'text/plain'},body:txt"
    "  }).then(function(r)\{"
    "    if(r.ok)\{"
    "      dirty=false;"
    "      document.getElementById('status').className='saved';"
    "      document.getElementById('status').textContent='saved';"
    "      window._NOTES[cur]=txt;"
    "    }else\{"
    "      document.getElementById('status').textContent='error '+r.status;"
    "    }"
    "  });"
    "}"
    ""
    "function createNote()\{"
    "  var inp=document.getElementById('new-name');"
    "  var name=inp.value.trim();"
    "  if(!name)return;"
    "  if(!name.endsWith('.md'))name+='.md';"
    "  fetch(MAKE+name+'?mark=txt',\{method:'PUT',"
    "    headers:\{'Content-Type':'text/plain'},body:' '"
    "  }).then(function(r)\{"
    "    if(r.ok)\{"
    "      window._NOTES[name]='';"
    "      inp.value='';"
    "      rebuildTree();"
    "      selectNote(name);"
    "    }"
    "  });"
    "}"
    ""
    "function renderPreview(src)\{"
    "  var el=document.getElementById('preview');"
    "  if(!el)return;"
    "  el.innerHTML=renderMd(src);"
    "}"
    ""
    "function renderMd(s)\{"
    "  var lines=s.split('\\n'),out=[],inCode=false,codeBuf=[];"
    "  for(var i=0;i<lines.length;i++)\{"
    "    var L=lines[i];"
    "    if(L.match(/^```/))\{"
    "      if(inCode)\{out.push('<pre><code>'+escHtml(codeBuf.join('\\n'))+'</code></pre>');codeBuf=[];inCode=false}"
    "      else\{inCode=true}"
    "      continue"
    "    }"
    "    if(inCode)\{codeBuf.push(L);continue}"
    "    if(L.match(/^### /))  \{out.push('<h3>'+inline(L.slice(4))+'</h3>');continue}"
    "    if(L.match(/^## /))   \{out.push('<h2>'+inline(L.slice(3))+'</h2>');continue}"
    "    if(L.match(/^# /))    \{out.push('<h1>'+inline(L.slice(2))+'</h1>');continue}"
    "    if(L.match(/^> /))    \{out.push('<blockquote>'+inline(L.slice(2))+'</blockquote>');continue}"
    "    if(L.match(/^- /))    \{out.push('<ul><li>'+inline(L.slice(2))+'</li></ul>');continue}"
    "    if(L.match(/^\\d+\\. /)) \{out.push('<ol><li>'+inline(L.replace(/^\\d+\\. /,''))+'</li></ol>');continue}"
    "    if(L.trim()==='')      \{out.push('');continue}"
    "    out.push('<p>'+inline(L)+'</p>')"
    "  }"
    "  if(inCode)out.push('<pre><code>'+escHtml(codeBuf.join('\\n'))+'</code></pre>');"
    "  return out.join('\\n')"
    "}"
    ""
    "function inline(s)\{"
    "  s=escHtml(s);"
    "  s=s.replace(/\\[\\[([^\\]]+)\\]\\]/g,function(_,n)\{"
    "    var fname=n+'.md';"
    "    var cls=window._NOTES[fname]!=null?'wiki-link':'wiki-link broken';"
    "    return '<span class=\"'+cls+'\" onclick=\"navLink(\\''+n+'\\')\">' + n + '</span>'"
    "  });"
    "  s=s.replace(/`([^`]+)`/g,'<code>$1</code>');"
    "  s=s.replace(/\\*\\*([^*]+)\\*\\*/g,'<strong>$1</strong>');"
    "  s=s.replace(/\\*([^*]+)\\*/g,'<em>$1</em>');"
    "  s=s.replace(/\\[([^\\]]+)\\]\\(([^)]+)\\)/g,'<a href=\"$2\">$1</a>');"
    "  return s"
    "}"
    ""
    "function buildTree(files)\{"
    "  var root=\{_f:[],_d:\{}};"
    "  files.forEach(function(f)\{"
    "    var p=f.split('/'),n=root;"
    "    for(var i=0;i<p.length-1;i++)\{"
    "      if(!n._d[p[i]])n._d[p[i]]=\{_f:[],_d:\{}};"
    "      n=n._d[p[i]]}"
    "    n._f.push(p[p.length-1])"
    "  });return root}"
    ""
    "function renderTree(node,el,depth,prefix)\{"
    "  var dirs=Object.keys(node._d).sort();"
    "  dirs.forEach(function(d)\{"
    "    var div=document.createElement('div');div.className='dir open';"
    "    var label=document.createElement('div');"
    "    label.className='dir-label';"
    "    label.style.paddingLeft=(8+depth*14)+'px';"
    "    label.innerHTML='<span class=\"arrow open\">\\u25b6</span> '+d+'/';"
    "    label.onclick=function()\{"
    "      div.classList.toggle('open');"
    "      label.querySelector('.arrow').classList.toggle('open')};"
    "    div.appendChild(label);"
    "    var ch=document.createElement('div');ch.className='dir-children';"
    "    renderTree(node._d[d],ch,depth+1,prefix+d+'/');"
    "    div.appendChild(ch);el.appendChild(div)});"
    "  node._f.sort().forEach(function(f)\{"
    "    var fe=document.createElement('div');fe.className='file';"
    "    fe.style.paddingLeft=(22+depth*14)+'px';"
    "    fe.textContent=f;"
    "    var full=prefix+f;"
    "    fe.dataset.name=full;"
    "    fe.onclick=function()\{selectNote(full)};"
    "    el.appendChild(fe)})}"
    ""
    "function rebuildTree()\{"
    "  var tp=document.getElementById('tree');"
    "  tp.innerHTML='';"
    "  var files=Object.keys(window._NOTES).sort();"
    "  if(!files.length)\{tp.innerHTML='<div class=\"muted\">no notes</div>';return}"
    "  renderTree(buildTree(files),tp,0,'');"
    "}"
    ""
    "document.getElementById('new-btn').onclick=createNote;"
    "document.getElementById('new-name').onkeydown=function(e)\{"
    "  if(e.key==='Enter')createNote();"
    "};"
    "rebuildTree();"
  ==
--
