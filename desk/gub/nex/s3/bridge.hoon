::  s3/bridge: bidirectional S3 sync
::
::  TODO: Sometimes when the nexus code is updated, live nexus instances
::  don't reload. BUG in reload-changed-nexuses or build-code propagation.
::
::  TODO: Replace ball-file-mugs with born diffing. The %ball view includes
::  born with per-file version timestamps — diff old born vs new born to get
::  changed files directly instead of mugging every file on every update.
::
::  creds.json          -- s3 credentials
::  source.json         -- s3 key for remote mappings (optional)
::  mapping.json        -- bridge definitions (id, s3-prefix, local-path)
::  sync/mappings.json  -- live sync: watches mapping.json, pushes to source key
::  sync/[id].json      -- live sync: watches local path, pushes diffs to s3
::  log.json            -- activity log
::  browse.json         -- cached bucket listing
::  main.sig            -- poke to pull/sync/unsync/add/delete/browse
::  page.html           -- control panel
::
/<  *  /lib/s3.hoon
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  [=sand:nexus =gain:nexus =ball:tarball]
      ^-  [sand:nexus gain:nexus ball:tarball]
      =/  =ver:loader  (get-ver:loader ball)
      =/  default-creds=json
        %-  pairs:enjs:format
        :~  ['access_key' s+'']
            ['secret_key' s+'']
            ['region' s+'us-east-1']
            ['bucket' s+'']
            ['endpoint' s+'']
        ==
      ?+  ver  !!
          ?(~ [~ %0])
        %+  spin:loader  [sand gain ball]
        :~  (ver-row:loader 0)
            [%fall %& [/ %'main.sig'] %.n [~ [/ %sig] !>(~)]]
            [%fall %& [/ %'creds.json'] %.n [~ [/ %json] !>(default-creds)]]
            [%fall %& [/ %'source.json'] %.n [~ [/ %json] !>(s+'')]]
            [%fall %& [/ %'mapping.json'] %.n [~ [/ %json] !>([%a ~])]]
            [%fall %& [/ %'log.json'] %.n [~ [/ %json] !>([%a ~])]]
            [%fall %& [/ %'browse.json'] %.n [~ [/ %json] !>([%o ~])]]
            [%fall %& [/ %'sync-status.json'] %.n [~ [/ %json] !>([%a ~])]]
            [%fall %| /sync [~ ~] [~ ~] empty-dir:loader]
            [%over %& [/ %'page.html'] %.n [~ [/ %html] !>((manx-to-html (bridge-page ~)))]]
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
        ::
          [~ %'page.html']
        ;<  ~  bind:m  (rise-wait:io prod "%s3-bridge page: failed")
        ;<  map-rd=road:tarball  bind:m
          (ancestor-road:io [/s3 %bridge] [%& / %'mapping.json'])
        ;<  mappings=view:nexus  bind:m  (keep:io /mapping map-rd ~)
        ;<  ~  bind:m  (replace:io !>((manx-to-html (bridge-page (read-bridges mappings)))))
        |-
        ;<  upd=view:nexus  bind:m  (take-news:io /mapping)
        ;<  ~  bind:m  (replace:io !>((manx-to-html (bridge-page (read-bridges upd)))))
        $
        ::
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%s3-bridge: failed")
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
        ?.  ?=(%o -.jon)  $
        =/  action=@t  (get-str jon 'action')
        ?:  =('' action)  $
        ?+    action  $
          ::  Mapping management
          ::
            %log
          =/  level=@t  (get-str jon 'level')
          =/  message=@t  (get-str jon 'message')
          ?:  |(=('' level) =('' message))  $
          ;<  ~  bind:m  (log-msg level message)
          $
            ::
            %'add-mapping'
          =/  s3-prefix=@t  (get-str jon 's3-prefix')
          =/  local-path=@t  (ensure-slash (get-str jon 'local-path'))
          ?:  |(=('' s3-prefix) =('' local-path))  $
          ;<  existing=(list bridge-entry)  bind:m  read-mapping
          =/  id=@t  (next-id existing)
          =/  new=(list bridge-entry)  (snoc existing [id s3-prefix local-path])
          ;<  ~  bind:m  (write-mapping new)
          ;<  ~  bind:m
            (log-msg 'info' (crip "Added mapping #{(trip id)}: {(trip s3-prefix)} -> {(trip local-path)}"))
          $
            ::
            %'delete-mapping'
          =/  id=@t  (get-str jon 'id')
          ?:  =('' id)  $
          :: unsync first if active
          ;<  ~  bind:m  (unsync-mapping id)
          ;<  existing=(list bridge-entry)  bind:m  read-mapping
          =/  new=(list bridge-entry)
            (skip existing |=(b=bridge-entry =(id id.b)))
          ;<  ~  bind:m  (write-mapping new)
          ;<  ~  bind:m  (log-msg 'info' (crip "Deleted mapping #{(trip id)}"))
          $
            ::
            %'edit-mapping'
          =/  id=@t  (get-str jon 'id')
          =/  s3-prefix=@t  (get-str jon 's3-prefix')
          =/  local-path=@t  (ensure-slash (get-str jon 'local-path'))
          ?:  |(=('' id) =('' s3-prefix) =('' local-path))  $
          ;<  existing=(list bridge-entry)  bind:m  read-mapping
          =/  new=(list bridge-entry)
            %+  turn  existing
            |=  b=bridge-entry
            ?.  =(id id.b)  b
            b(s3-prefix s3-prefix, local-path local-path)
          ;<  ~  bind:m  (write-mapping new)
          ;<  ~  bind:m
            (log-msg 'info' (crip "Edited mapping #{(trip id)}: {(trip s3-prefix)} -> {(trip local-path)}"))
          $
            ::
            %sync
          =/  id=@t  (get-str jon 'id')
          ?:  =('' id)  $
          ;<  ~  bind:m  (sync-mapping id)
          $
            ::
            %unsync
          =/  id=@t  (get-str jon 'id')
          ?:  =('' id)  $
          ;<  ~  bind:m  (unsync-mapping id)
          $
          ::  S3 operations (need creds)
          ::
            %'pull-source'
          ;<  creds=s3-creds  bind:m  read-creds
          ?:  (missing-creds creds)
            ;<  ~  bind:m  (log-msg 'error' 'Pull source failed: missing S3 credentials')
            $
          ;<  ~  bind:m  (pull-source creds)
          $
            ::
            %'push-source'
          ;<  creds=s3-creds  bind:m  read-creds
          ?:  (missing-creds creds)
            ;<  ~  bind:m  (log-msg 'error' 'Push source failed: missing S3 credentials')
            $
          ;<  ~  bind:m  (push-source creds)
          $
            ::
            %browse
          ;<  creds=s3-creds  bind:m  read-creds
          ?:  (missing-creds creds)
            ;<  ~  bind:m  (log-msg 'error' 'Browse failed: missing S3 credentials')
            $
          ;<  resp=client-response:iris  bind:m
            (s3-request creds 'GET' '' (build-list-query '') ~)
          ?.  ?=(%finished -.resp)
            ;<  ~  bind:m  (log-msg 'error' 'Browse failed: request did not finish')
            $
          =/  keys=(list @t)
            ?~(full-file.resp ~ (parse-list-response q.data.u.full-file.resp))
          ;<  now=@da  bind:m  get-time:io
          =/  browse-jon=json
            %-  pairs:enjs:format
            :~  ['keys' [%a (turn keys |=(k=@t s+k))]]
                ['fetched' (sect:enjs:format now)]
                ['count' (numb:enjs:format (lent keys))]
            ==
          ;<  brd=road:tarball  bind:m
            (ancestor-road:io [/s3 %bridge] [%& / %'browse.json'])
          ;<  ~  bind:m  (over:io brd [[/ %json] !>(browse-jon)])
          ;<  ~  bind:m  (log-msg 'info' (crip "Browsed bucket: {<(lent keys)>} objects"))
          $
            ::
            %pull
          ;<  creds=s3-creds  bind:m  read-creds
          ?:  (missing-creds creds)
            ;<  ~  bind:m  (log-msg 'error' 'Pull failed: missing S3 credentials')
            $
          =/  id=@t  (get-str jon 'id')
          ;<  mappings=(list bridge-entry)  bind:m  read-mapping
          =/  bridge=(unit bridge-entry)  (find-bridge id mappings)
          ?~  bridge
            ;<  ~  bind:m  (log-msg 'warn' (crip "Pull failed: mapping #{(trip id)} not found"))
            $
          ;<  ~  bind:m  (do-pull creds u.bridge)
          $
            ::
            %'pull-all'
          ;<  creds=s3-creds  bind:m  read-creds
          ?:  (missing-creds creds)
            ;<  ~  bind:m  (log-msg 'error' 'Pull All failed: missing S3 credentials')
            $
          ;<  ~  bind:m  (pull-source creds)
          ;<  mappings=(list bridge-entry)  bind:m  read-mapping
          =/  remaining=(list bridge-entry)  mappings
          |-
          ?~  remaining  ^$
          ;<  ~  bind:m  (do-pull creds i.remaining)
          $(remaining t.remaining)
            ::
            %'sync-all'
          ;<  mappings=(list bridge-entry)  bind:m  read-mapping
          =/  remaining=(list bridge-entry)  mappings
          |-
          ?~  remaining  ^$
          ;<  ~  bind:m  (sync-mapping id.i.remaining)
          $(remaining t.remaining)
            ::
            %'unsync-all'
          ;<  mappings=(list bridge-entry)  bind:m  read-mapping
          =/  remaining=(list bridge-entry)  mappings
          |-
          ?~  remaining  ^$
          ;<  ~  bind:m  (unsync-mapping id.i.remaining)
          $(remaining t.remaining)
        ==
        ::
        ::  sync process: watches local path, pushes diffs to S3
        ::
        ::  Matches sync/[id].json files (not sync/mappings.json).
        ::  Created by %sync action, killed by %unsync via cull:io.
        ::
          [[%sync ~] *]
        =/  name=@ta  +.rail
        ;<  ~  bind:m  (rise-wait:io prod "%s3-bridge sync: failed")
        ?:  =(name %'mappings.json')
          :: Source sync: watch mapping.json, push to S3 source key on change
          ;<  src=@t  bind:m  read-source
          ?:  =('' src)
            ;<  ~  bind:m  (log-msg 'error' 'Source sync: no source key configured')
            stay:m
          ;<  map-rd=road:tarball  bind:m
            (ancestor-road:io [/s3 %bridge] [%& / %'mapping.json'])
          ;<  init=view:nexus  bind:m  (keep:io /source-sync map-rd ~)
          ;<  creds=s3-creds  bind:m  read-creds
          ;<  ~  bind:m  (push-source creds)
          ;<  ~  bind:m  (log-msg 'info' (crip "Source sync started, watching mapping.json -> {(trip src)}"))
          |-
          ;<  upd=view:nexus  bind:m  (take-news:io /source-sync)
          ;<  creds=s3-creds  bind:m  read-creds
          ;<  ~  bind:m  (push-source creds)
          ;<  ~  bind:m  (log-msg 'info' 'Source sync: pushed mapping.json')
          $
        =/  id=@t  (extract-id name)
        ;<  creds=s3-creds  bind:m  read-creds
        ?:  (missing-creds creds)
          ;<  ~  bind:m  (log-msg 'error' (crip "Sync #{(trip id)}: missing S3 credentials"))
          stay:m
        ;<  mappings=(list bridge-entry)  bind:m  read-mapping
        =/  bridge=(unit bridge-entry)  (find-bridge id mappings)
        ?~  bridge
          ;<  ~  bind:m  (log-msg 'error' (crip "Sync #{(trip id)}: mapping not found"))
          stay:m
        =/  entry=bridge-entry  u.bridge
        ;<  self-overlap=?  bind:m  (check-self-overlap local-path.entry)
        ?:  self-overlap
          ;<  ~  bind:m  (log-msg 'error' (crip "Sync #{(trip id)}: local path overlaps this bridge's namespace"))
          stay:m
        =/  local-road=road:tarball  [%& %| (text-to-path local-path.entry)]
        ;<  init=view:nexus  bind:m  (keep:io /sync local-road ~)
        =/  current=(map @t @ud)  (ball-file-mugs init entry)
        ;<  ~  bind:m  (push-changed creds entry current ~)
        ;<  ~  bind:m
          (log-msg 'info' (crip "Sync #{(trip id)} watching {(trip local-path.entry)} ({<~(wyt by current)>} files)"))
        =/  known=(map @t @ud)  current
        |-
        ;<  upd=view:nexus  bind:m  (take-news:io /sync)
        ;<  creds=s3-creds  bind:m  read-creds
        =/  now=(map @t @ud)  (ball-file-mugs upd entry)
        =/  changed=(list @t)
          %+  murn  ~(tap by now)
          |=  [key=@t mug=@ud]
          =/  old=(unit @ud)  (~(get by known) key)
          ?~  old  `key
          ?:  =(u.old mug)  ~
          `key
        =/  deleted=(list @t)
          %+  murn  ~(tap by known)
          |=  [key=@t *]
          ?^  (~(get by now) key)  ~
          `key
        ?:  &(=(~ changed) =(~ deleted))
          $(known now)
        ;<  ~  bind:m  (push-keys creds entry changed upd)
        ;<  ~  bind:m  (delete-keys creds deleted)
        ;<  ~  bind:m
          (log-msg 'info' (crip "Sync #{(trip id)}: {<(lent changed)>} updated, {<(lent deleted)>} deleted"))
        $(known now)
      ==
    ::
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'S3 bridge sync directory.'
            ~
          'Bidirectional S3 sync. Pull from and push to S3 buckets.'
        ==
          %|
        ?+  rail.p.mana  'S3 bridge file.'
          [~ %'creds.json']             'S3 credentials (access_key, secret_key, region, bucket, endpoint).'
          [~ %'source.json']            'S3 key for remote mapping source. Empty string = disabled.'
          [~ %'mapping.json']            'Bridge definitions: id, s3-prefix, local-path.'
          [~ %'log.json']               'Operation log: [{time, level, message}...], newest first, max 50.'
          [~ %'browse.json']            'Cached S3 bucket listing with fetch timestamp.'
          [~ %'main.sig']               'Poke with JSON {action} to pull/sync/unsync/add/delete/browse.'
          [~ %'page.html']              'S3 bridge control panel.'
        ==
      ==
    --
::
::  types + helpers
::
|%
+$  s3-creds
  $:  access-key=@t
      secret-key=@t
      region=@t
      bucket=@t
      endpoint=@t
  ==
+$  bridge-entry
  $:  id=@t
      s3-prefix=@t
      local-path=@t
  ==
++  next-id
  |=  entries=(list bridge-entry)
  ^-  @t
  =/  n=@ud  0
  |-
  =/  candidate=@t  (crip (a-co:co n))
  ?:  =(~ (find-bridge candidate entries))
    candidate
  $(n +(n))
::
++  extract-id
  |=  name=@ta
  ^-  @t
  =/  t=tape  (trip name)
  =/  len=@ud  (lent t)
  ?:  (lth len 6)  name
  (crip (scag (sub len 5) t))
::
++  missing-creds
  |=  c=s3-creds
  |(=('' access-key.c) =('' bucket.c) =('' endpoint.c))
::
++  read-creds
  =/  m  (fiber:fiber:nexus ,s3-creds)
  ^-  form:m
  ;<  rd=road:tarball  bind:m
    (ancestor-road:io [/s3 %bridge] [%& / %'creds.json'])
  ;<  =seen:nexus  bind:m  (peek:io rd ~)
  =/  jon=json
    ?.  ?=([%& %file *] seen)  [%o ~]
    (fall (mole |.(!<(json q.sage.p.seen))) [%o ~])
  ?.  ?=(%o -.jon)  (pure:m *s3-creds)
  %-  pure:m
  :*  (get-str jon 'access_key')
      (get-str jon 'secret_key')
      (fall (bind (~(get by p.jon) 'region') |=(j=json ?>(?=(%s -.j) p.j))) 'us-east-1')
      (get-str jon 'bucket')
      (get-str jon 'endpoint')
  ==
::
++  read-source
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  ;<  rd=road:tarball  bind:m
    (ancestor-road:io [/s3 %bridge] [%& / %'source.json'])
  ;<  =seen:nexus  bind:m  (peek:io rd ~)
  ?.  ?=([%& %file *] seen)  (pure:m '')
  =/  jon=json  (fall (mole |.(!<(json q.sage.p.seen))) s+'')
  ?.  ?=(%s -.jon)  (pure:m '')
  (pure:m p.jon)
::
++  pull-source
  |=  cfg=s3-creds
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  src=@t  bind:m  read-source
  ?:  =('' src)  (pure:m ~)
  ;<  resp=client-response:iris  bind:m  (s3-request cfg 'GET' src '' ~)
  ?.  ?=(%finished -.resp)
    ;<  ~  bind:m  (log-msg 'error' (crip "Pull source failed: request error for {(trip src)}"))
    (pure:m ~)
  ?~  full-file.resp
    ;<  ~  bind:m  (log-msg 'warn' (crip "Pull source: empty response for {(trip src)}"))
    (pure:m ~)
  =/  body=@t  q.data.u.full-file.resp
  =/  jon=json  (fall (de:json:html body) [%a ~])
  ;<  rd=road:tarball  bind:m
    (ancestor-road:io [/s3 %bridge] [%& / %'mapping.json'])
  ;<  ~  bind:m  (over:io rd [[/ %json] !>(jon)])
  ;<  ~  bind:m  (log-msg 'info' (crip "Pulled mapping source from {(trip src)}"))
  (pure:m ~)
::
++  push-source
  |=  cfg=s3-creds
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  src=@t  bind:m  read-source
  ?:  =('' src)  (pure:m ~)
  ;<  rd=road:tarball  bind:m
    (ancestor-road:io [/s3 %bridge] [%& / %'mapping.json'])
  ;<  =seen:nexus  bind:m  (peek:io rd ~)
  ?.  ?=([%& %file *] seen)  (pure:m ~)
  =/  jon=json  (fall (mole |.(!<(json q.sage.p.seen))) [%a ~])
  =/  body=@t  (en:json:html jon)
  ;<  resp=client-response:iris  bind:m  (s3-request cfg 'PUT' src '' `body)
  ?.  ?=(%finished -.resp)
    ;<  ~  bind:m  (log-msg 'error' (crip "Push source failed: request error for {(trip src)}"))
    (pure:m ~)
  ;<  ~  bind:m  (log-msg 'info' (crip "Pushed mapping source to {(trip src)}"))
  (pure:m ~)
::
++  read-mapping
  =/  m  (fiber:fiber:nexus ,(list bridge-entry))
  ^-  form:m
  ;<  rd=road:tarball  bind:m
    (ancestor-road:io [/s3 %bridge] [%& / %'mapping.json'])
  ;<  =seen:nexus  bind:m  (peek:io rd ~)
  =/  jon=json
    ?.  ?=([%& %file *] seen)  [%a ~]
    (fall (mole |.(!<(json q.sage.p.seen))) [%a ~])
  ?.  ?=(%a -.jon)  (pure:m ~)
  %-  pure:m
  %+  murn  p.jon
  |=  j=json
  ?.  ?=(%o -.j)  ~
  =/  id=@t  (get-str j 'id')
  =/  s3-prefix=@t  (get-str j 's3-prefix')
  =/  local-path=@t  (ensure-slash (get-str j 'local-path'))
  ?:  |(=('' id) =('' s3-prefix) =('' local-path))  ~
  `[id s3-prefix local-path]
::
++  write-mapping
  |=  entries=(list bridge-entry)
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  jon=json
    :-  %a
    %+  turn  entries
    |=  =bridge-entry
    %-  pairs:enjs:format
    :~  ['id' s+id.bridge-entry]
        ['s3-prefix' s+s3-prefix.bridge-entry]
        ['local-path' s+local-path.bridge-entry]
    ==
  ;<  rd=road:tarball  bind:m
    (ancestor-road:io [/s3 %bridge] [%& / %'mapping.json'])
  (over:io rd [[/ %json] !>(jon)])
::
++  sync-mapping
  |=  id=@t
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  name=@ta  (crip "{(trip id)}.json")
  ;<  rd=road:tarball  bind:m
    (ancestor-road:io [/s3 %bridge] [%& /sync name])
  ;<  exists=?  bind:m  (peek-exists:io rd)
  ?:  exists
    ;<  ~  bind:m  (log-msg 'warn' (crip "Sync #{(trip id)}: already synced"))
    (pure:m ~)
  ;<  ~  bind:m  (make:io rd |+[%.n [[/ %json] !>([%o ~])] ~])
  ;<  ~  bind:m  (log-msg 'info' (crip "Sync #{(trip id)} started"))
  (update-sync-status id %.y)
::
++  unsync-mapping
  |=  id=@t
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  name=@ta  (crip "{(trip id)}.json")
  ;<  rd=road:tarball  bind:m
    (ancestor-road:io [/s3 %bridge] [%& /sync name])
  ;<  exists=?  bind:m  (peek-exists:io rd)
  ?.  exists  (pure:m ~)
  ;<  ~  bind:m  (cull:io rd)
  ;<  ~  bind:m  (log-msg 'info' (crip "Sync #{(trip id)} stopped"))
  (update-sync-status id %.n)
::
++  update-sync-status
  |=  [id=@t add=?]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  rd=road:tarball  bind:m
    (ancestor-road:io [/s3 %bridge] [%& / %'sync-status.json'])
  ;<  =seen:nexus  bind:m  (peek:io rd ~)
  =/  existing=(set @t)
    ?.  ?=([%& %file *] seen)  ~
    =/  jon=json  (fall (mole |.(!<(json q.sage.p.seen))) [%a ~])
    ?.  ?=(%a -.jon)  ~
    %-  ~(gas in *(set @t))
    (murn p.jon |=(j=json ?.(?=(%s -.j) ~ `p.j)))
  =/  updated=(set @t)
    ?:  add  (~(put in existing) id)
    (~(del in existing) id)
  =/  jon=json  [%a (turn ~(tap in updated) |=(t=@t s+t))]
  (over:io rd [[/ %json] !>(jon)])
::
++  log-msg
  |=  [level=@t message=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  entry=json
    %-  pairs:enjs:format
    :~  ['time' (sect:enjs:format now)]
        ['level' s+level]
        ['message' s+message]
    ==
  ;<  rd=road:tarball  bind:m
    (ancestor-road:io [/s3 %bridge] [%& / %'log.json'])
  ;<  =seen:nexus  bind:m  (peek:io rd ~)
  =/  existing=(list json)
    ?.  ?=([%& %file *] seen)  ~
    =/  jon=json  (fall (mole |.(!<(json q.sage.p.seen))) [%a ~])
    ?.  ?=(%a -.jon)  ~
    p.jon
  =/  new=(list json)  (scag 50 ^-((list json) [entry existing]))
  (over:io rd [[/ %json] !>([%a new])])
::
++  read-bridges
  |=  =view:nexus
  ^-  (list bridge-entry)
  ?.  ?=(%file -.view)  ~
  =/  jon=json
    (fall (mole |.(!<(json q.sage.view))) [%a ~])
  ?.  ?=(%a -.jon)  ~
  %+  murn  p.jon
  |=  j=json
  ?.  ?=(%o -.j)  ~
  =/  id=@t  (get-str j 'id')
  =/  s3-prefix=@t  (get-str j 's3-prefix')
  =/  local-path=@t  (ensure-slash (get-str j 'local-path'))
  ?:  |(=('' id) =('' s3-prefix) =('' local-path))  ~
  `[id s3-prefix local-path]
::
++  find-bridge
  |=  [id=@t bridges=(list bridge-entry)]
  ^-  (unit bridge-entry)
  ?~  bridges  ~
  ?:  =(id id.i.bridges)  `i.bridges
  $(bridges t.bridges)
::
++  get-str
  |=  [jon=json key=@t]
  ^-  @t
  ?.  ?=(%o -.jon)  ''
  =/  val=(unit json)  (~(get by p.jon) key)
  ?~  val  ''
  ?.  ?=(%s -.u.val)  ''
  p.u.val
::
++  ensure-slash
  |=  t=@t
  ^-  @t
  ?:  =('' t)  t
  (spat (text-to-path t))
::  text-to-path: split cord on '/' into path, skipping empties
::  e.g. '/docs/' → /docs, 'docs' → /docs
::
++  text-to-path
  |=  t=@t
  ^-  path
  %+  turn
    (skip (split (trip t) '/') |=(s=@t =('' s)))
  |=(s=@t `@ta`s)
::  check-self-overlap: true if local-path overlaps this bridge's namespace
::
++  check-self-overlap
  |=  local=@t
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  here=rail:tarball  bind:m  get-here-abs:io
  =/  self-path=path  path.here
  =/  local-path=path  (text-to-path local)
  %-  pure:m
  ?|  =(self-path local-path)
      =((scag (lent local-path) self-path) local-path)
      =((scag (lent self-path) local-path) self-path)
  ==
::
::  ext-to-blot: convert filename extension to blot
::  e.g. 'json' → [/ %json], 'my_mark' → [/my %mark]
::
++  ext-to-blot
  |=  ext=@ta
  ^-  blot:tarball
  =/  segs=(list @t)  (split (trip ext) '_')
  =/  segs=(list @ta)  (turn segs |=(s=@t `@ta`s))
  ?~  segs  [/ ext]
  ?~  t.segs  [/ i.segs]
  [(snip `path`segs) (rear segs)]
::
::  known-mark: marks we know how to sync
::  %text marks store @t, %wain marks store wain, %mime marks store mime
::  ~ means unknown — skip this file
::
++  known-mark
  |=  =blot:tarball
  ^-  (unit ?(%text %wain %mime))
  ?.  =(/ path.blot)  ~
  ?+  name.blot  ~
    ?(%json %html %hoon %css %js %md)  `%text
    %txt                                `%wain
    %mime                               `%mime
  ==
::  build-s3-key: join prefix, relative path, and filename into an s3 key
::
++  build-s3-key
  |=  [prefix=@t rel=path name=@ta]
  ^-  @t
  =/  segs=path
    :(weld (text-to-path prefix) rel ~[name])
  (crip (slag 1 (spud segs)))
::  serialize-for-s3: convert content to @t for S3 upload
::  Returns ~ for unknown marks (caller should skip)
::
++  serialize-for-s3
  |=  =content:tarball
  ^-  (unit @t)
  =/  kind=(unit ?(%text %wain %mime))  (known-mark p.sage.content)
  ?~  kind  ~
  =/  res=(each @t tang)
    %-  mule  |.
    ?-  u.kind
      %text  !<(@t q.sage.content)
      %wain  (of-wain:format !<(wain q.sage.content))
      %mime  q.q:!<(mime q.sage.content)
    ==
  ?:(?=(%& -.res) `p.res ~)
::
++  s3-request
  |=  [cfg=s3-creds method=@t key=@t qs=@t content=(unit @t)]
  =/  m  (fiber:fiber:nexus ,client-response:iris)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  [amz-date=@t payload-hash=@t authorization=@t]
    %:  build-signature
      method=method
      access-key=access-key.cfg
      secret-key=secret-key.cfg
      region=region.cfg
      endpoint=endpoint.cfg
      bucket=bucket.cfg
      object-key=key
      query-string=qs
      content=content
      now=now
    ==
  =/  url=@t  (build-url endpoint.cfg bucket.cfg key ?:(=('' qs) ~ `qs))
  =/  hed=(list [@t @t])  (build-headers method payload-hash amz-date authorization)
  =/  bod=(unit octs)  (bind content |=(c=@t (as-octs:mimes:html c)))
  =/  meth=method:http  ;;(method:http method)
  ;<  ~  bind:m  (send-request:io [meth url hed bod])
  take-client-response:io
::
++  do-pull
  |=  [cfg=s3-creds =bridge-entry]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  self-overlap=?  bind:m  (check-self-overlap local-path.bridge-entry)
  ?:  self-overlap
    ;<  ~  bind:m  (log-msg 'error' (crip "Pull #{(trip id.bridge-entry)}: local path overlaps this bridge's namespace"))
    (pure:m ~)
  =/  qs=@t  (build-list-query s3-prefix.bridge-entry)
  ;<  resp=client-response:iris  bind:m  (s3-request cfg 'GET' '' qs ~)
  ?.  ?=(%finished -.resp)
    ;<  ~  bind:m  (log-msg 'error' (crip "Pull #{(trip id.bridge-entry)}: list request failed"))
    (pure:m ~)
  ?~  full-file.resp
    ;<  ~  bind:m  (log-msg 'warn' (crip "Pull #{(trip id.bridge-entry)}: empty response"))
    (pure:m ~)
  =/  body=@t  q.data.u.full-file.resp
  =/  keys=(list @t)  (parse-list-response body)
  =/  =ball:tarball  *ball:tarball
  =/  pulled=@ud  0
  |-
  ?~  keys
    =/  dest=path  (text-to-path local-path.bridge-entry)
    =/  dest-name=@ta  (rear dest)
    =/  dest-ext=(unit @ta)  (parse-extension:tarball dest-name)
    =/  root-neck=(unit neck:tarball)
      (bind dest-ext ext-to-neck:tarball)
    =/  =lump:tarball  (fall fil.ball [~ ~ ~])
    =/  root-ball=ball:tarball
      ball(fil `lump(neck root-neck))
    =/  local-road=road:tarball  [%& %| dest]
    ;<  exists=?  bind:m  (peek-exists:io local-road)
    ;<  ~  bind:m  ?.  exists  (pure:m ~)
                   (cull:io local-road)
    ;<  ~  bind:m  (make:io local-road &+[*sand:nexus *gain:nexus root-ball])
    ;<  ~  bind:m
      (log-msg 'info' (crip "Pulled {<pulled>} files for #{(trip id.bridge-entry)}"))
    (pure:m ~)
  =/  key=@t  i.keys
  =/  rel=@t
    =/  pre=tape  (trip s3-prefix.bridge-entry)
    =/  k=tape  (trip key)
    ?:  =(pre (scag (lent pre) k))
      (crip (slag (lent pre) k))
    key
  ?:  |(=('' rel) =('/' (rear (trip rel))))
    $(keys t.keys)
  =/  filename=@ta  (extract-filename rel)
  =/  rel-path=path  (key-to-path rel)
  =/  ext=(unit @ta)  (parse-extension:tarball filename)
  =/  =blot:tarball  ?~(ext [/ %mime] (ext-to-blot u.ext))
  =/  kind=?(%text %wain %mime)
    (fall (known-mark blot) %mime)
  =?  blot  =(%mime kind)  [/ %mime]
  ;<  resp=client-response:iris  bind:m  (s3-request cfg 'GET' key '' ~)
  ?.  ?=(%finished -.resp)  $(keys t.keys)
  ?~  full-file.resp  $(keys t.keys)
  =/  body=octs  data.u.full-file.resp
  =/  ct=(unit @t)  (extract-content-type headers.response-header.resp)
  =/  =sage:tarball
    ?-  kind
      %text  [blot !>(q.body)]
      %wain  [blot !>((to-wain:format q.body))]
      %mime
        =/  mtype=path  (determine-mime-type:tarball ct filename)
        [blot !>(`mime`[mtype body])]
    ==
  =/  =content:tarball  [~ sage]
  ::  set necks on directories with extensions
  =/  nb=ball:tarball
    =/  segs=path  rel-path
    =/  built=path  /
    |-
    ?~  segs  ball
    =/  seg=@ta  i.segs
    =/  dext=(unit @ta)  (parse-extension:tarball seg)
    ?~  dext  $(segs t.segs, built (snoc built seg))
    =/  nec=neck:tarball  (ext-to-neck:tarball u.dext)
    $(segs t.segs, built (snoc built seg), ball (~(mkd ba:tarball ball) (snoc built seg) ~ `nec))
  $(keys t.keys, pulled +(pulled), ball (~(put ba:tarball nb) [rel-path filename] content))
::
::  sync push helpers
::
::  Build map of s3-key -> mug from a namespace view
::
++  ball-file-mugs
  |=  [=view:nexus =bridge-entry]
  ^-  (map @t @ud)
  ?.  ?=(%ball -.view)  ~
  =/  files=(list [=rail:tarball =content:tarball])
    (list-ball-files ball.view (text-to-path local-path.bridge-entry))
  %-  malt
  %+  murn  files
  |=  [=rail:tarball =content:tarball]
  =/  kind=(unit ?(%text %wain %mime))  (known-mark p.sage.content)
  ?~  kind  ~
  =/  rel-path=path
    =/  base=path  (text-to-path local-path.bridge-entry)
    (slag (lent base) path.rail)
  =/  s3-key=@t  (build-s3-key s3-prefix.bridge-entry rel-path name.rail)
  `[s3-key (mug q.sage.content)]
::
::  Push only specific keys from a view
::
++  push-keys
  |=  [cfg=s3-creds =bridge-entry keys=(list @t) =view:nexus]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=(%ball -.view)  (pure:m ~)
  =/  files=(list [=rail:tarball =content:tarball])
    (list-ball-files ball.view (text-to-path local-path.bridge-entry))
  =/  key-set=(set @t)  (silt keys)
  =/  remaining=(list [rail:tarball content:tarball])
    %+  skim  files
    |=  [=rail:tarball =content:tarball]
    =/  rel-path=path
      =/  base=path  (text-to-path local-path.bridge-entry)
      (slag (lent base) path.rail)
    =/  s3-key=@t  (build-s3-key s3-prefix.bridge-entry rel-path name.rail)
    (~(has in key-set) s3-key)
  |-
  ?~  remaining  (pure:m ~)
  =/  [=rail:tarball =content:tarball]  i.remaining
  =/  rel-path=path
    =/  base=path  (text-to-path local-path.bridge-entry)
    (slag (lent base) path.rail)
  =/  s3-key=@t  (build-s3-key s3-prefix.bridge-entry rel-path name.rail)
  =/  body=(unit @t)  (serialize-for-s3 content)
  ?~  body  $(remaining t.remaining)
  ;<  resp=client-response:iris  bind:m  (s3-request cfg 'PUT' s3-key '' body)
  $(remaining t.remaining)
::
::  Push all files (initial sync)
::
++  push-changed
  |=  [cfg=s3-creds =bridge-entry current=(map @t @ud) prev=(map @t @ud)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  local-road=road:tarball  [%& %| (text-to-path local-path.bridge-entry)]
  ;<  =seen:nexus  bind:m  (peek:io local-road ~)
  ?.  ?=([%& %ball *] seen)  (pure:m ~)
  =/  files=(list [=rail:tarball =content:tarball])
    (list-ball-files ball.p.seen (text-to-path local-path.bridge-entry))
  |-
  ?~  files  (pure:m ~)
  =/  [=rail:tarball =content:tarball]  i.files
  =/  rel-path=path
    =/  base=path  (text-to-path local-path.bridge-entry)
    (slag (lent base) path.rail)
  =/  s3-key=@t  (build-s3-key s3-prefix.bridge-entry rel-path name.rail)
  =/  body=(unit @t)  (serialize-for-s3 content)
  ?~  body  $(files t.files)
  ;<  resp=client-response:iris  bind:m  (s3-request cfg 'PUT' s3-key '' body)
  $(files t.files)
::
::  Delete S3 keys that no longer exist locally
::
++  delete-keys
  |=  [cfg=s3-creds keys=(list @t)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  keys  (pure:m ~)
  ;<  resp=client-response:iris  bind:m  (s3-request cfg 'DELETE' i.keys '' ~)
  $(keys t.keys)
::
++  list-ball-files
  |=  [=ball:tarball base=path]
  ^-  (list [rail:tarball content:tarball])
  =/  acc=(list [rail:tarball content:tarball])  ~
  =?  acc  ?=(^ fil.ball)
    =/  fils=(list [@ta content:tarball])  ~(tap by contents.u.fil.ball)
    %+  weld  acc
    %+  turn  fils
    |=([name=@ta =content:tarball] [[base name] content])
  =/  dirs=(list [@ta ball:tarball])  ~(tap by dir.ball)
  |-
  ?~  dirs  acc
  =/  [dname=@ta sub=ball:tarball]  i.dirs
  $(dirs t.dirs, acc (weld acc (list-ball-files sub (snoc base dname))))
::
++  tank-to-tape
  |=  =tank
  ^-  tape
  ~(ram re tank)
::
++  extract-content-type
  |=  headers=(list [key=@t value=@t])
  ^-  (unit @t)
  =/  ct=(list @t)
    %+  murn  headers
    |=  [key=@t value=@t]
    ?:  =('content-type' (cass:co (trip key)))
      `value
    ~
  ?~  ct  ~
  `i.ct
::
++  extract-filename
  |=  key=@t
  ^-  @ta
  =/  parts=(list @t)  (split-cord key '/')
  ?~  parts  key
  `@ta`(rear parts)
::
++  key-to-path
  |=  key=@t
  ^-  path
  =/  parts=(list @t)  (skip (split-cord key '/') |=(s=@t =('' s)))
  ?:  (lte (lent parts) 1)  /
  (turn (snip `(list @t)`parts) |=(s=@t `@ta`s))
::
++  split-cord
  |=  [t=@t del=@t]
  ^-  (list @t)
  (split (trip t) del)
::
++  split
  |=  [t=tape del=@t]
  ^-  (list @t)
  =|  acc=(list @t)
  =|  cur=tape
  |-
  ?~  t  (flop [(crip (flop cur)) acc])
  ?:  =(i.t del)
    $(t t.t, acc [(crip (flop cur)) acc], cur ~)
  $(t t.t, cur [i.t cur])
::
::
++  manx-to-html
  |=  m=manx
  ^-  @t
  (crip (en-xml:html m))
::  page
::
++  bridge-page
  |=  bridges=(list bridge-entry)
  ^-  manx
  ;html
    ;head
      ;title: S3 Bridge
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;style
        ;+  ;/  style-text
      ==
    ==
    ;body
      ;div#app
        ;div#header
          ;div
            ;h1: S3 Bridge
            ;div.f3.mono.s-2: bidirectional S3 sync
          ==
        ==
        ;div#log-bar(onclick "openLog()")
          ;span#log-latest.f3.mono.s-2: no activity yet
        ==
        ;div#log-backdrop
          ;div#log-modal
            ;div#log-header
              ;span: Activity Log
              ;div
                ;button#log-close.hdr-btn: close
              ==
            ==
            ;div#log-list;
          ==
        ==
        ;div#browse-backdrop
          ;div#browse-modal
            ;div#browse-header
              ;span: Bucket Contents
              ;div
                ;span#browse-age.f3.s-2;
                ;button#browse-refresh.hdr-btn: refresh
                ;button#browse-close.hdr-btn: close
              ==
            ==
            ;div#browse-list;
          ==
        ==
        ;div#creds-backdrop
          ;div#creds-modal
            ;div#creds-header
              ;span: S3 Credentials
              ;div
                ;button#creds-save.hdr-btn: save
                ;button#creds-close.hdr-btn: close
              ==
            ==
            ;textarea#creds-json(rows "8", placeholder "\{}");
            ;div#creds-status;
          ==
        ==
        ;div#edit-backdrop
          ;div#edit-modal
            ;div#edit-header
              ;span: Edit Mapping
              ;div
                ;button#edit-save.hdr-btn: save
                ;button#edit-close.hdr-btn: close
              ==
            ==
            ;input#edit-id(type "hidden");
            ;div.edit-field
              ;label: s3 prefix
              ;input#edit-prefix.create-input(type "text", autocomplete "off");
            ==
            ;div.edit-field
              ;label: local path
              ;input#edit-path.create-input(type "text", autocomplete "off");
            ==
          ==
        ==
        ;div.section-header
          ;div.section-row
            ;h2.section-title: credentials
            ;button.hdr-btn(onclick "openCreds()"): edit
            ;button.hdr-btn(onclick "openBrowse()"): browse bucket
          ==
        ==
        ;div.section-header
          ;div.section-row
            ;h2.section-title: mappings
          ==
        ==
        ;div.source-bar
          ;span.source-label: source
          ;input.source-input(id "m-source", type "text", placeholder "s3 key for remote mappings (optional)", autocomplete "off");
          ;button.hdr-btn(onclick "saveSource()"): save
          ;button.btn.btn-grn(onclick "pullSource()"): pull
          ;button.sync-btn(id "source-sync-btn", onclick "toggleSourceSync()"): sync
        ==
        ;div.bulk-actions
          ;button.btn.btn-grn(onclick "pullAll()"): Pull All
          ;button.btn.btn-grn(onclick "syncAll()"): Sync All
          ;button.btn.btn-grn(onclick "unsyncAll()"): Unsync All
        ==
        ;div.create-bar
          ;input.create-input(id "m-prefix", type "text", placeholder "s3 prefix (e.g. photos/)", autocomplete "off");
          ;input.create-input(id "m-path", type "text", placeholder "local path (e.g. /media/photos)", autocomplete "off");
          ;button.create-btn(onclick "addMapping()"): + add
        ==
        ;div#bridges
          ;*  ?~  bridges
                :~  ;div.empty: No mappings configured.
                ==
              %+  turn  bridges
              bridge-card
        ==
      ==
      ;script
        ;+  ;/  script-text
      ==
    ==
  ==
::
++  bridge-card
  |=  =bridge-entry
  ^-  manx
  =/  i=tape  (trip id.bridge-entry)
  =/  pre=tape  (trip s3-prefix.bridge-entry)
  =/  loc=tape  (trip local-path.bridge-entry)
  ;div.bridge-card(data-bridge i)
    ;div.bridge-left
      ;span.bridge-id: #{i}
      ;div.bridge-info
        ;span.bridge-detail: s3://{pre} -> {loc}
      ==
    ==
    ;div.card-actions
      ;button.hdr-btn(onclick "openEdit('{i}','{pre}','{loc}')"): edit
      ;button.btn.btn-grn(onclick "pull('{i}')"): pull
      ;button.sync-btn(data-id i, onclick "toggleSync('{i}')"): sync
      ;button.delete-btn(onclick "deleteMapping('{i}')"): delete
    ==
  ==
::
++  style-text
  ^-  tape
  """
  * \{ margin: 0; padding: 0; box-sizing: border-box; }
  body \{ font-family: -apple-system, system-ui, sans-serif; background: #111; color: #eee; height: 100vh; }
  #app \{ display: flex; flex-direction: column; height: 100vh; max-width: 700px; margin: 0 auto; padding: 16px; }
  #header \{ display: flex; justify-content: space-between; align-items: flex-start; padding: 12px 0; border-bottom: 1px solid #333; margin-bottom: 16px; flex-shrink: 0; }
  #header h1 \{ font-size: 20px; font-weight: 700; }
  .f3 \{ color: #888; }
  .mono \{ font-family: monospace; }
  .s-2 \{ font-size: 12px; }
  .hdr-btn \{ font-size: 11px; padding: 4px 10px; border-radius: 4px; border: 1px solid #444; background: none; color: #888; cursor: pointer; }
  .hdr-btn:hover \{ color: #eee; border-color: #666; }
  .btn \{ background: none; border: 1px solid #333; color: #aaa; padding: 4px 12px; border-radius: 6px; cursor: pointer; font-size: 11px; }
  .btn:hover \{ border-color: #666; color: #fff; }
  .btn-grn \{ border-color: #2a5a2a; color: #6c6; }
  .btn-grn:hover \{ border-color: #4a8a4a; }
  .btn-blue \{ border-color: #2a2a5a; color: #66c; }
  .btn-blue:hover \{ border-color: #4a4a8a; }
  #browse-backdrop \{ display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.6); z-index: 100; }
  #browse-backdrop.open \{ display: flex; align-items: center; justify-content: center; }
  #browse-modal \{ background: #1a1a1a; border: 1px solid #333; border-radius: 8px; width: 90%; max-width: 500px; max-height: 80vh; padding: 20px; display: flex; flex-direction: column; }
  #browse-header \{ display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; flex-shrink: 0; }
  #browse-header span \{ font-size: 14px; font-weight: 600; }
  #browse-header div \{ display: flex; gap: 6px; align-items: center; }
  #browse-list \{ overflow-y: auto; font-family: monospace; font-size: 12px; color: #aaa; line-height: 1.6; }
  .browse-dir \{ cursor: pointer; padding: 2px 0; user-select: none; }
  .browse-dir:hover \{ color: #eee; }
  .browse-dir::before \{ content: '\\25B6 '; font-size: 9px; display: inline-block; width: 14px; transition: transform 0.1s; }
  .browse-dir.open::before \{ transform: rotate(90deg); }
  .browse-children \{ display: none; padding-left: 16px; }
  .browse-dir.open + .browse-children \{ display: block; }
  .browse-file \{ padding: 2px 0; padding-left: 14px; }
  .browse-file:hover \{ color: #eee; }
  .browse-empty \{ color: #555; padding: 20px 0; text-align: center; }
  #edit-backdrop \{ display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.6); z-index: 100; }
  #edit-backdrop.open \{ display: flex; align-items: center; justify-content: center; }
  #edit-modal \{ background: #1a1a1a; border: 1px solid #333; border-radius: 8px; width: 90%; max-width: 400px; padding: 20px; }
  #edit-header \{ display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; }
  .edit-field \{ margin-bottom: 10px; }
  .edit-field label \{ display: block; color: #888; font-size: 11px; margin-bottom: 4px; }
  .edit-field input \{ width: 100%; }
  #creds-backdrop \{ display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.6); z-index: 100; }
  #creds-backdrop.open \{ display: flex; align-items: center; justify-content: center; }
  #creds-modal \{ background: #1a1a1a; border: 1px solid #333; border-radius: 8px; width: 90%; max-width: 400px; padding: 20px; }
  #creds-header \{ display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
  #creds-header span \{ font-size: 14px; font-weight: 600; }
  #creds-header div \{ display: flex; gap: 6px; }
  #creds-json \{ width: 100%; font-family: monospace; font-size: 12px; border: 1px solid #333; border-radius: 6px; padding: 10px; resize: vertical; background: #111; color: #eee; outline: none; }
  #creds-json:focus \{ border-color: #2563eb; }
  #creds-status \{ margin-top: 10px; font-size: 12px; color: #4ade80; }
  .section-header \{ margin-top: 16px; margin-bottom: 8px; }
  .section-row \{ display: flex; align-items: center; gap: 8px; }
  .section-title \{ font-size: 13px; font-weight: 600; color: #888; text-transform: uppercase; letter-spacing: 0.05em; }
  .source-bar \{ display: flex; align-items: center; gap: 8px; margin-bottom: 8px; }
  .source-label \{ color: #555; font-size: 11px; font-family: monospace; text-transform: uppercase; flex-shrink: 0; }
  .source-input \{ flex: 1; padding: 6px 10px; border-radius: 6px; border: 1px solid #222; background: #1a1a1a; color: #888; font-size: 12px; font-family: monospace; outline: none; }
  .source-input:focus \{ border-color: #2563eb; color: #eee; }
  .bulk-actions \{ display: flex; justify-content: center; gap: 10px; margin-bottom: 10px; }
  .create-bar \{ display: flex; gap: 8px; margin-bottom: 12px; }
  .create-input \{ flex: 1; padding: 8px 12px; border-radius: 8px; border: 1px solid #333; background: #1a1a1a; color: #eee; font-size: 13px; outline: none; }
  .create-input:focus \{ border-color: #2563eb; }
  .create-btn \{ padding: 8px 16px; border-radius: 8px; border: none; background: #2563eb; color: white; font-size: 13px; cursor: pointer; white-space: nowrap; }
  .create-btn:hover \{ background: #1d4ed8; }
  .bridge-card \{ display: flex; justify-content: space-between; align-items: center; padding: 10px 14px; border-radius: 8px; background: #1a1a1a; border: 1px solid #222; margin-bottom: 6px; }
  .bridge-card:hover \{ border-color: #444; }
  .bridge-card.synced \{ border-color: #2a5a2a; }
  .bridge-left \{ display: flex; align-items: center; gap: 8px; min-width: 0; }
  .bridge-id \{ color: #444; font-size: 11px; font-family: monospace; flex-shrink: 0; }
  .bridge-info \{ display: flex; flex-direction: column; gap: 2px; min-width: 0; }
  .bridge-detail \{ color: #888; font-size: 12px; font-family: monospace; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .card-actions \{ display: flex; gap: 6px; flex-shrink: 0; }
  .sync-btn \{ font-size: 11px; padding: 4px 10px; border-radius: 4px; border: 1px solid #2a5a2a; background: none; color: #6c6; cursor: pointer; }
  .sync-btn:hover \{ border-color: #4a8a4a; }
  .sync-btn.active \{ background: #2a5a2a; color: #fff; }
  .delete-btn \{ font-size: 11px; padding: 4px 10px; border-radius: 4px; border: 1px solid transparent; background: none; color: #555; cursor: pointer; }
  .delete-btn:hover \{ color: #f87171; border-color: #f87171; }
  .empty \{ color: #555; font-size: 14px; padding: 20px 0; text-align: center; }
  #log-bar \{ padding: 8px 12px; border-radius: 6px; background: #1a1a1a; border: 1px solid #222; cursor: pointer; margin-bottom: 8px; display: flex; align-items: center; gap: 8px; }
  #log-bar:hover \{ border-color: #444; }
  .log-dot \{ width: 6px; height: 6px; border-radius: 50%; flex-shrink: 0; }
  .log-dot-info \{ background: #4ade80; }
  .log-dot-warn \{ background: #facc15; }
  .log-dot-error \{ background: #f87171; }
  #log-backdrop \{ display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.6); z-index: 100; }
  #log-backdrop.open \{ display: flex; align-items: center; justify-content: center; }
  #log-modal \{ background: #1a1a1a; border: 1px solid #333; border-radius: 8px; width: 90%; max-width: 550px; max-height: 80vh; padding: 20px; display: flex; flex-direction: column; }
  #log-header \{ display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; flex-shrink: 0; }
  #log-header span \{ font-size: 14px; font-weight: 600; }
  #log-list \{ overflow-y: auto; font-family: monospace; font-size: 12px; line-height: 1.8; }
  .log-entry \{ display: flex; align-items: flex-start; gap: 8px; padding: 2px 0; }
  .log-time \{ color: #555; white-space: nowrap; }
  .log-msg-info \{ color: #aaa; }
  .log-msg-warn \{ color: #facc15; }
  .log-msg-error \{ color: #f87171; }
  """
::
++  script-text
  ^-  tape
  """
  var P = location.pathname.replace(/page[.]html$/, '');
  var POKE = P.replace('/ball/', '/api/poke/');
  var OVER = P.replace('/ball/', '/api/over/');
  var KEEP = P.replace('/ball/', '/api/keep/');

  function poke(payload) \{
    fetch(POKE + 'main.sig?mark=json', \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(payload)
    });
  }

  // Creds modal
  var credsBack = document.getElementById('creds-backdrop');
  var credsJson = document.getElementById('creds-json');
  var credsStatus = document.getElementById('creds-status');

  function openCreds() \{
    credsStatus.textContent = '';
    credsStatus.style.color = '#4ade80';
    fetch(P + 'creds.json').then(function(r) \{ return r.json(); })
      .then(function(j) \{ credsJson.value = JSON.stringify(j, null, 2); })
      .catch(function() \{ credsJson.value = '\{}'; });
    credsBack.classList.add('open');
  }

  document.getElementById('creds-close').onclick = function() \{
    credsBack.classList.remove('open');
  };

  credsBack.onclick = function(e) \{
    if (e.target === credsBack) credsBack.classList.remove('open');
  };

  document.getElementById('creds-save').onclick = async function() \{
    var parsed;
    try \{ parsed = JSON.parse(credsJson.value); } catch(e) \{
      credsStatus.textContent = 'Invalid JSON';
      credsStatus.style.color = '#f87171';
      return;
    }
    var r = await fetch(OVER + 'creds.json?mark=json', \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(parsed)
    });
    if (r.ok) \{
      credsStatus.textContent = 'Saved';
      credsStatus.style.color = '#4ade80';
      poke(\{action: 'log', level: 'info', message: 'S3 credentials saved'});
      setTimeout(function() \{ credsBack.classList.remove('open'); }, 600);
    } else \{
      credsStatus.textContent = 'Save failed';
      credsStatus.style.color = '#f87171';
    }
  };

  // Edit modal
  var editBack = document.getElementById('edit-backdrop');

  function openEdit(id, prefix, path) \{
    document.getElementById('edit-id').value = id;
    document.getElementById('edit-prefix').value = prefix;
    document.getElementById('edit-path').value = path;
    editBack.classList.add('open');
  }

  document.getElementById('edit-close').onclick = function() \{
    editBack.classList.remove('open');
  };

  editBack.onclick = function(e) \{
    if (e.target === editBack) editBack.classList.remove('open');
  };

  document.getElementById('edit-save').onclick = function() \{
    var id = document.getElementById('edit-id').value;
    var prefix = document.getElementById('edit-prefix').value.trim();
    var path = document.getElementById('edit-path').value.trim();
    if (!prefix || !path) return;
    poke(\{action: 'edit-mapping', id: id, 's3-prefix': prefix, 'local-path': path});
    editBack.classList.remove('open');
  };

  // Browse modal
  var browseBack = document.getElementById('browse-backdrop');

  function openBrowse() \{
    browseBack.classList.add('open');
    loadBrowse();
  }

  document.getElementById('browse-close').onclick = function() \{
    browseBack.classList.remove('open');
  };

  browseBack.onclick = function(e) \{
    if (e.target === browseBack) browseBack.classList.remove('open');
  };

  document.getElementById('browse-refresh').onclick = function() \{
    poke(\{action: 'browse'});
    document.getElementById('browse-list').innerHTML = '<div class="browse-empty">loading...</div>';
    setTimeout(loadBrowse, 2000);
  };

  function loadBrowse() \{
    fetch(P + 'browse.json').then(function(r) \{ return r.json(); })
      .then(function(data) \{
        var keys = data.keys || [];
        var fetched = data.fetched;
        var count = data.count || keys.length;
        var age = document.getElementById('browse-age');
        if (fetched) \{
          var secs = Math.floor(Date.now() / 1000) - fetched;
          var ago;
          if (secs < 60) ago = secs + 's ago';
          else if (secs < 3600) ago = Math.floor(secs / 60) + 'm ago';
          else ago = Math.floor(secs / 3600) + 'h ago';
          age.textContent = count + ' objects, ' + ago;
        } else \{
          age.textContent = 'never fetched';
        }
        var list = document.getElementById('browse-list');
        if (!keys.length) \{
          list.innerHTML = '<div class="browse-empty">empty bucket (or not yet fetched)</div>';
          return;
        }
        var tree = \{};
        for (var i = 0; i < keys.length; i++) \{
          var parts = keys[i].split('/');
          var node = tree;
          for (var j = 0; j < parts.length; j++) \{
            if (!parts[j]) continue;
            if (j === parts.length - 1 && !keys[i].endsWith('/')) \{
              if (!node._files) node._files = [];
              node._files.push(parts[j]);
            } else \{
              if (!node[parts[j]]) node[parts[j]] = \{};
              node = node[parts[j]];
            }
          }
        }
        list.innerHTML = renderTree(tree);
      })
      .catch(function() \{
        document.getElementById('browse-list').innerHTML =
          '<div class="browse-empty">failed to load</div>';
      });
  }

  function renderTree(node) \{
    var html = '';
    var dirs = [], files = node._files || [];
    for (var k in node) if (k !== '_files') dirs.push(k);
    dirs.sort();
    files.sort();
    for (var i = 0; i < dirs.length; i++) \{
      html += '<div class="browse-dir" onclick="this.classList.toggle(&apos;open&apos;)">' + dirs[i] + '/</div>';
      html += '<div class="browse-children">' + renderTree(node[dirs[i]]) + '</div>';
    }
    for (var i = 0; i < files.length; i++) \{
      html += '<div class="browse-file">' + files[i] + '</div>';
    }
    return html;
  }

  // Mapping management
  function addMapping() \{
    var prefix = document.getElementById('m-prefix').value.trim();
    var path = document.getElementById('m-path').value.trim();
    if (!prefix || !path) return;
    poke(\{action: 'add-mapping', 's3-prefix': prefix, 'local-path': path});
    document.getElementById('m-prefix').value = '';
    document.getElementById('m-path').value = '';
  }

  function deleteMapping(id) \{
    if (!confirm('Delete this mapping?')) return;
    poke(\{action: 'delete-mapping', id: id});
  }

  // Source
  fetch(P + 'source.json').then(function(r) \{ return r.json(); })
    .then(function(v) \{ if (v) document.getElementById('m-source').value = v; })
    .catch(function() \{});

  function saveSource() \{
    var val = document.getElementById('m-source').value.trim();
    fetch(OVER + 'source.json?mark=json', \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(val)
    }).then(function() \{
      poke(\{action: 'log', level: 'info', message: val ? 'Source set to ' + val : 'Source cleared'});
    });
  }

  // S3 actions
  function pullSource() \{ poke(\{action: 'pull-source'}); }
  var sourceSynced = false;
  function toggleSourceSync() \{
    if (sourceSynced) \{
      poke(\{action: 'unsync', id: 'mappings'});
      sourceSynced = false;
    } else \{
      poke(\{action: 'sync', id: 'mappings'});
      sourceSynced = true;
    }
    updateSyncUI();
  }
  function pull(id) \{
    if (!confirm('Pull will overwrite everything at the local path. Continue?')) return;
    poke(\{action: 'pull', id: id});
  }
  function pullAll() \{
    if (!confirm('Pull All will overwrite all local paths. Continue?')) return;
    poke(\{action: 'pull-all'});
  }
  function syncAll() \{ poke(\{action: 'sync-all'}); }
  function unsyncAll() \{ poke(\{action: 'unsync-all'}); }

  // Sync toggle
  var syncedIds = \{};

  function toggleSync(id) \{
    if (syncedIds[id]) \{
      poke(\{action: 'unsync', id: id});
      syncedIds[id] = false;
    } else \{
      poke(\{action: 'sync', id: id});
      syncedIds[id] = true;
    }
    updateSyncUI();
  }

  function updateSyncUI() \{
    var cards = document.querySelectorAll('.bridge-card');
    for (var i = 0; i < cards.length; i++) \{
      var id = cards[i].getAttribute('data-bridge');
      var btn = cards[i].querySelector('.sync-btn');
      if (syncedIds[id]) \{
        cards[i].classList.add('synced');
        if (btn) \{ btn.classList.add('active'); btn.textContent = 'unsync'; }
      } else \{
        cards[i].classList.remove('synced');
        if (btn) \{ btn.classList.remove('active'); btn.textContent = 'sync'; }
      }
    }
    var srcBtn = document.getElementById('source-sync-btn');
    if (srcBtn) \{
      srcBtn.textContent = sourceSynced ? 'unsync' : 'sync';
      srcBtn.classList.toggle('active', sourceSynced);
    }
  }

  function updateSyncState(ids) \{
    syncedIds = \{};
    for (var i = 0; i < ids.length; i++) syncedIds[ids[i]] = true;
    updateSyncUI();
  }

  // SSE: live-update bridges when sync/mappings.json changes
  function renderBridges(entries) \{
    var el = document.getElementById('bridges');
    if (!entries || !entries.length) \{
      el.innerHTML = '<div class="empty">No mappings configured.</div>';
      return;
    }
    var html = '';
    for (var i = 0; i < entries.length; i++) \{
      var b = entries[i];
      var id = b.id || '';
      var pre = b['s3-prefix'] || '';
      var loc = b['local-path'] || '';
      var isSynced = syncedIds[id];
      html += '<div class="bridge-card' + (isSynced ? ' synced' : '') + '" data-bridge="' + id + '">'
        + '<div class="bridge-left">'
        + '<span class="bridge-id">#' + id + '</span>'
        + '<div class="bridge-info">'
        + '<span class="bridge-detail">s3://' + pre + ' -&gt; ' + loc + '</span>'
        + '</div></div>'
        + '<div class="card-actions">'
        + '<button class="hdr-btn" onclick="openEdit(&apos;' + id + '&apos;,&apos;' + pre + '&apos;,&apos;' + loc + '&apos;)">edit</button>'
        + '<button class="btn btn-grn" onclick="pull(&apos;' + id + '&apos;)">pull</button>'
        + '<button class="sync-btn' + (isSynced ? ' active' : '') + '" data-id="' + id + '" onclick="toggleSync(&apos;' + id + '&apos;)">' + (isSynced ? 'unsync' : 'sync') + '</button>'
        + '<button class="delete-btn" onclick="deleteMapping(&apos;' + id + '&apos;)">delete</button>'
        + '</div></div>';
    }
    el.innerHTML = html;
  }

  var mapEs = new EventSource(KEEP + 'mapping.json?mark=json');
  mapEs.addEventListener('upd mapping.json', function(e) \{
    try \{ renderBridges(JSON.parse(e.data)); } catch(x) \{}
  });

  function applySyncStatus(ids) \{
    sourceSynced = false;
    var mapped = [];
    for (var i = 0; i < ids.length; i++) \{
      if (ids[i] === 'mappings') \{ sourceSynced = true; }
      else \{ mapped.push(ids[i]); }
    }
    updateSyncState(mapped);
  }

  // SSE: live-update sync status
  var syncEs = new EventSource(KEEP + 'sync-status.json?mark=json');
  syncEs.addEventListener('upd sync-status.json', function(e) \{
    try \{ applySyncStatus(JSON.parse(e.data)); } catch(x) \{}
  });

  // Initial load
  fetch(P + 'sync-status.json').then(function(r) \{ return r.json(); })
    .then(function(ids) \{ applySyncStatus(ids || []); })
    .catch(function() \{});

  // Log bar + modal
  var logBack = document.getElementById('log-backdrop');

  function openLog() \{
    logBack.classList.add('open');
    loadLog();
  }

  document.getElementById('log-close').onclick = function() \{
    logBack.classList.remove('open');
  };

  logBack.onclick = function(e) \{
    if (e.target === logBack) logBack.classList.remove('open');
  };

  function fmtTime(ts) \{
    var d = new Date(ts * 1000);
    var h = d.getHours(), m = d.getMinutes(), s = d.getSeconds();
    return (h < 10 ? '0' : '') + h + ':' + (m < 10 ? '0' : '') + m + ':' + (s < 10 ? '0' : '') + s;
  }

  function updateLogBar(entries) \{
    var bar = document.getElementById('log-bar');
    var el = document.getElementById('log-latest');
    if (!entries || !entries.length) \{
      el.textContent = 'no activity yet';
      var dot = bar.querySelector('.log-dot');
      if (dot) dot.remove();
      return;
    }
    var e = entries[0];
    var lvl = e.level || 'info';
    el.textContent = e.message || '';
    var dot = bar.querySelector('.log-dot');
    if (!dot) \{
      dot = document.createElement('span');
      dot.className = 'log-dot';
      bar.insertBefore(dot, el);
    }
    dot.className = 'log-dot log-dot-' + lvl;
  }

  function renderLog(entries) \{
    var el = document.getElementById('log-list');
    if (!entries || !entries.length) \{
      el.innerHTML = '<div class="empty">No log entries.</div>';
      return;
    }
    var html = '';
    for (var i = 0; i < entries.length; i++) \{
      var e = entries[i];
      var lvl = e.level || 'info';
      var t = e.time ? fmtTime(e.time) : '';
      html += '<div class="log-entry">'
        + '<span class="log-time">' + t + '</span>'
        + '<span class="log-dot log-dot-' + lvl + '" style="margin-top:5px"></span>'
        + '<span class="log-msg-' + lvl + '">' + (e.message || '') + '</span>'
        + '</div>';
    }
    el.innerHTML = html;
  }

  function loadLog() \{
    fetch(P + 'log.json').then(function(r) \{ return r.json(); })
      .then(function(entries) \{
        updateLogBar(entries);
        renderLog(entries);
      })
      .catch(function() \{});
  }

  var logEs = new EventSource(KEEP + 'log.json?mark=json');
  logEs.addEventListener('upd log.json', function(e) \{
    try \{
      var entries = JSON.parse(e.data);
      updateLogBar(entries);
      if (logBack.classList.contains('open')) renderLog(entries);
    } catch(x) \{}
  });

  loadLog();
  window.addEventListener('beforeunload', function() \{ mapEs.close(); logEs.close(); syncEs.close(); });
  """
--
