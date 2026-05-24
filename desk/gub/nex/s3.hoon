::  s3: S3-compatible object storage nexus
::
::  config.json  -- access-key, secret-key, region, bucket, endpoint
::  mounts.json  -- {name: prefix, ...} mapping
::  main.json    -- poke {op, ...} to run operations, result written here
::  mounts/      -- each subdirectory is a mount, populated by refresh
::  page.html    -- control panel UI
::
/<  *  /lib/s3.hoon
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  ball:tarball
      =/  =ver:loader  (get-ver:loader ball)
      =/  default-config=json
        %-  pairs:enjs:format
        :~  ['access-key' s+'']
            ['secret-key' s+'']
            ['region' s+'us-east-1']
            ['bucket' s+'']
            ['endpoint' s+'']
        ==
      ?+  ver  !!
          ?(~ [~ %0])
        %+  spin:loader  ball
        :~  (ver-row:loader 0)
            [%fall %& [/ %'main.json'] [[/ %json] !>((pairs:enjs:format ~[['status' s+'idle']]))]]
            [%fall %& [/ %'config.json'] [[/ %json] !>(default-config)]]
            [%fall %& [/ %'mounts.json'] [[/ %json] !>([%o ~])]]
            [%fall %| /mounts empty-dir:loader]
            [%over %& [/ %'page.html'] [[/ %html] !>((crip (en-xml:html s3-page)))]]
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
          [~ %'main.json']
        ;<  ~  bind:m  (rise-wait:io prod "%s3: failed")
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
        ?.  ?=(%o -.jon)  $
        =/  op=@t  (get-str jon 'op')
        ?:  =('' op)  $
        ::  mark as working
        ;<  ~  bind:m  (replace:io !>((pairs:enjs:format ~[['status' s+'working'] ['op' s+op]])))
        ::  read config
        ;<  cfg=s3-config  bind:m  read-config
        ?:  ?&  !=(op 'add-mount')
                !=(op 'remove-mount')
                !=(op 'get-mounts')
                |(=('' access-key.cfg) =('' secret-key.cfg) =('' bucket.cfg) =('' endpoint.cfg))
            ==
          ;<  ~  bind:m  (replace:io !>((pairs:enjs:format ~[['status' s+'error'] ['error' s+'missing S3 credentials']])))
          $
        ::  read mounts
        ;<  mounts=(map @t @t)  bind:m  read-mounts
        ::  dispatch
        ;<  ~  bind:m
          ?+    op
            (replace:io !>((pairs:enjs:format ~[['status' s+'error'] ['error' s+(crip "unknown op: {(trip op)}")]])))
            ::
              %'get-mounts'
            =/  entries=(list [@t json])
              %+  turn  ~(tap by mounts)
              |=([n=@t p=@t] [n s+p])
            %-  replace:io  !>
            %-  pairs:enjs:format
            :~  ['status' s+'done']
                ['op' s+'get-mounts']
                ['mounts' [%o (malt entries)]]
            ==
            ::
              %'add-mount'
            =/  name=@t  (get-str jon 'name')
            =/  prefix=@t  (get-str jon 'prefix')
            ?:  |(=('' name) =('' prefix))
              (replace:io !>((pairs:enjs:format ~[['status' s+'error'] ['error' s+'name and prefix required']])))
            =/  new-mounts=(map @t @t)  (~(put by mounts) name prefix)
            ;<  ~  bind:m  (write-mounts new-mounts)
            ::  create mount directory
            ;<  mount-road=road:tarball  bind:m
              (ancestor-road:io [/ %s3] [%| /mounts/[name]])
            ;<  exists=?  bind:m  (peek-exists:io mount-road)
            ;<  *  bind:m
              ?.  exists
                (make-soft:io mount-road &+*ball:tarball)
              (pure:m ~)
            %-  replace:io  !>
            %-  pairs:enjs:format
            :~  ['status' s+'done']
                ['op' s+'add-mount']
                ['name' s+name]
                ['prefix' s+prefix]
            ==
            ::
              %'remove-mount'
            =/  name=@t  (get-str jon 'name')
            ?:  =('' name)
              (replace:io !>((pairs:enjs:format ~[['status' s+'error'] ['error' s+'name required']])))
            =/  new-mounts=(map @t @t)  (~(del by mounts) name)
            ;<  ~  bind:m  (write-mounts new-mounts)
            %-  replace:io  !>
            %-  pairs:enjs:format
            :~  ['status' s+'done']
                ['op' s+'remove-mount']
                ['name' s+name]
            ==
            ::
              %'list-all'
            (do-list cfg '' '')
            ::
              %list
            =/  name=@t  (get-str jon 'name')
            =/  prefix=@t  (fall (~(get by mounts) name) '')
            ?:  =('' prefix)
              (replace:io !>((pairs:enjs:format ~[['status' s+'error'] ['error' s+(crip "unknown mount: {(trip name)}")]])))
            (do-list cfg prefix name)
            ::
              %refresh
            =/  name=@t  (get-str jon 'name')
            =/  prefix=@t  (fall (~(get by mounts) name) '')
            ?:  =('' prefix)
              (replace:io !>((pairs:enjs:format ~[['status' s+'error'] ['error' s+(crip "unknown mount: {(trip name)}")]])))
            (do-refresh cfg prefix name)
            ::
              %pull
            =/  name=@t  (get-str jon 'name')
            =/  key=@t  (get-str jon 'key')
            =/  prefix=@t  (fall (~(get by mounts) name) '')
            ?:  =('' prefix)
              (replace:io !>((pairs:enjs:format ~[['status' s+'error'] ['error' s+(crip "unknown mount: {(trip name)}")]])))
            (do-pull cfg key name)
            ::
              %delete
            =/  name=@t  (get-str jon 'name')
            =/  key=@t  (get-str jon 'key')
            (do-delete cfg key name)
          ==
        $
      ==
    ::
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'Directory under S3 storage.'
            ~
          'S3-compatible object storage. Pull/push between S3 and the ball namespace.'
            [%mounts ~]
          'Mount directories, each synced to an S3 prefix.'
        ==
          %|
        ?+  rail.p.mana  'File under S3 storage.'
          [~ %'config.json']   'S3 credentials: access-key, secret-key, region, bucket, endpoint.'
          [~ %'main.json']     'Poke with JSON {op, ...} to run S3 operations.'
          [~ %'mounts.json']   'Map of mount name to S3 prefix.'
          [~ %'page.html']     'S3 control panel.'
        ==
      ==
    --
::
::  helpers
::
|%
+$  s3-config
  $:  access-key=@t
      secret-key=@t
      region=@t
      bucket=@t
      endpoint=@t
  ==
::
++  read-config
  =/  m  (fiber:fiber:nexus ,s3-config)
  ^-  form:m
  ;<  cfg-road=road:tarball  bind:m
    (ancestor-road:io [/ %s3] [%& / %'config.json'])
  ;<  cfg-seen=seen:nexus  bind:m  (peek:io cfg-road ~)
  =/  jon=json
    ?.  ?=([%& %file *] cfg-seen)  [%o ~]
    (fall (mole |.(!<(json q.sage.p.cfg-seen))) [%o ~])
  ?.  ?=(%o -.jon)
    (pure:m *s3-config)
  %-  pure:m
  :*  (get-str jon 'access-key')
      (get-str jon 'secret-key')
      (get-str jon 'region')
      (get-str jon 'bucket')
      (get-str jon 'endpoint')
  ==
::
++  read-mounts
  =/  m  (fiber:fiber:nexus ,(map @t @t))
  ^-  form:m
  ;<  rd=road:tarball  bind:m
    (ancestor-road:io [/ %s3] [%& / %'mounts.json'])
  ;<  seen=seen:nexus  bind:m  (peek:io rd ~)
  =/  jon=json
    ?.  ?=([%& %file *] seen)  [%o ~]
    (fall (mole |.(!<(json q.sage.p.seen))) [%o ~])
  ?.  ?=(%o -.jon)
    (pure:m *(map @t @t))
  %-  pure:m
  %-  ~(gas by *(map @t @t))
  %+  murn  ~(tap by p.jon)
  |=  [k=@t v=json]
  ?.  ?=(%s -.v)  ~
  `[k p.v]
::
++  write-mounts
  |=  mounts=(map @t @t)
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  entries=(list [@t json])
    %+  turn  ~(tap by mounts)
    |=([n=@t p=@t] [n s+p])
  ;<  rd=road:tarball  bind:m
    (ancestor-road:io [/ %s3] [%& / %'mounts.json'])
  (over:io rd [[/ %json] !>([%o (malt entries)])])
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
++  s3-request
  |=  [cfg=s3-config method=@t key=@t qs=@t content=(unit @t)]
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
::  ops
::
++  do-list
  |=  [cfg=s3-config prefix=@t name=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  qs=@t  (build-list-query prefix)
  ;<  resp=client-response:iris  bind:m  (s3-request cfg 'GET' '' qs ~)
  ?.  ?=(%finished -.resp)
    (replace:io !>((pairs:enjs:format ~[['status' s+'error'] ['error' s+'request failed']])))
  ?~  full-file.resp
    (replace:io !>((pairs:enjs:format ~[['status' s+'done'] ['op' s+'list'] ['name' s+name] ['keys' [%a ~]]])))
  =/  body=@t  q.data.u.full-file.resp
  =/  keys=(list @t)  (parse-list-response body)
  %-  replace:io  !>
  %-  pairs:enjs:format
  :~  ['status' s+'done']
      ['op' s+'list']
      ['name' s+name]
      ['keys' [%a (turn keys |=(k=@t s+k))]]
      ['count' (numb:enjs:format (lent keys))]
  ==
::
++  do-refresh
  |=  [cfg=s3-config prefix=@t name=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ::  list all objects under prefix
  =/  qs=@t  (build-list-query prefix)
  ;<  resp=client-response:iris  bind:m  (s3-request cfg 'GET' '' qs ~)
  ?.  ?=(%finished -.resp)
    (replace:io !>((pairs:enjs:format ~[['status' s+'error'] ['error' s+'list failed']])))
  ?~  full-file.resp
    (replace:io !>((pairs:enjs:format ~[['status' s+'done'] ['op' s+'refresh'] ['name' s+name] ['pulled' (numb:enjs:format 0)]])))
  =/  body=@t  q.data.u.full-file.resp
  =/  keys=(list @t)  (parse-list-response body)
  ::  pull each object
  =/  pulled=@ud  0
  |-
  ?~  keys
    %-  replace:io  !>
    %-  pairs:enjs:format
    :~  ['status' s+'done']
        ['op' s+'refresh']
        ['name' s+name]
        ['pulled' (numb:enjs:format pulled)]
    ==
  =/  key=@t  i.keys
  ::  strip prefix from key to get relative path
  =/  rel=@t
    =/  pre=tape  (trip prefix)
    =/  k=tape  (trip key)
    ?:  =(pre (scag (lent pre) k))
      (crip (slag (lent pre) k))
    key
  ::  skip "directory" keys (ending in /)
  ?:  |(=('' rel) =('/' (rear (trip rel))))
    $(keys t.keys)
  ;<  ~  bind:m  (pull-one cfg key rel name)
  $(keys t.keys, pulled +(pulled))
::
++  pull-one
  |=  [cfg=s3-config key=@t rel=@t name=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  resp=client-response:iris  bind:m  (s3-request cfg 'GET' key '' ~)
  ?.  ?=(%finished -.resp)  (pure:m ~)
  ?~  full-file.resp  (pure:m ~)
  =/  content=@t  q.data.u.full-file.resp
  =/  ct=(unit @t)  (extract-content-type headers.response-header.resp)
  =/  filename=@ta  (extract-filename rel)
  =/  rel-path=path  (key-to-path rel)
  =/  mtype=path  (determine-mime-type:tarball ct filename)
  =/  file-mime=mime  [mtype (as-octs:mimes:html content)]
  =/  full-path=path  (weld /mounts/[name] rel-path)
  ;<  file-road=road:tarball  bind:m
    (ancestor-road:io [/ %s3] [%& full-path filename])
  ;<  exists=?  bind:m  (peek-exists:io file-road)
  ?:  exists
    (over:io file-road [[/ %mime] !>(file-mime)])
  =/  ext=(unit blot:tarball)  (bind (parse-extension:tarball filename) |=(e=@ta [/ e]))
  ;<  err=(unit tang)  bind:m
    (make-soft:io file-road |+[[[/ %mime] !>(file-mime)] ext])
  ?~  err  (pure:m ~)
  ::  mark not found, retry as plain mime
  (make:io file-road |+[[[/ %mime] !>(file-mime)] ~])
::
++  do-pull
  |=  [cfg=s3-config key=@t name=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  resp=client-response:iris  bind:m  (s3-request cfg 'GET' key '' ~)
  ?.  ?=(%finished -.resp)
    (replace:io !>((pairs:enjs:format ~[['status' s+'error'] ['error' s+'download failed']])))
  ?~  full-file.resp
    (replace:io !>((pairs:enjs:format ~[['status' s+'error'] ['error' s+'empty response']])))
  =/  content=@t  q.data.u.full-file.resp
  =/  ct=(unit @t)  (extract-content-type headers.response-header.resp)
  =/  filename=@ta  (extract-filename key)
  =/  rel-path=path  (key-to-path key)
  =/  mtype=path  (determine-mime-type:tarball ct filename)
  =/  file-mime=mime  [mtype (as-octs:mimes:html content)]
  =/  full-path=path  (weld /mounts/[name] rel-path)
  ;<  file-road=road:tarball  bind:m
    (ancestor-road:io [/ %s3] [%& full-path filename])
  ;<  exists=?  bind:m  (peek-exists:io file-road)
  ;<  ~  bind:m
    ?:  exists
      (over:io file-road [[/ %mime] !>(file-mime)])
    =/  ext=(unit blot:tarball)  (bind (parse-extension:tarball filename) |=(e=@ta [/ e]))
    ;<  err=(unit tang)  bind:m
      (make-soft:io file-road |+[[[/ %mime] !>(file-mime)] ext])
    ?~  err  (pure:m ~)
    (make:io file-road |+[[[/ %mime] !>(file-mime)] ~])
  %-  replace:io  !>
  %-  pairs:enjs:format
  :~  ['status' s+'done']
      ['op' s+'pull']
      ['key' s+key]
      ['name' s+name]
  ==
::
++  do-delete
  |=  [cfg=s3-config key=@t name=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  resp=client-response:iris  bind:m  (s3-request cfg 'DELETE' key '' ~)
  ?.  ?=(%finished -.resp)
    (replace:io !>((pairs:enjs:format ~[['status' s+'error'] ['error' s+'delete failed']])))
  =/  code=@ud  status-code.response-header.resp
  %-  replace:io  !>
  %-  pairs:enjs:format
  :~  ['status' s+'done']
      ['op' s+'delete']
      ['key' s+key]
      ['name' s+name]
      ['ok' [%b (lth code 300)]]
  ==
::
++  key-to-path
  |=  key=@t
  ^-  path
  =/  parts=(list @t)  (split-cord key '/')
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
::  page
::
++  s3-page
  ^-  manx
  ;html
    ;head
      ;title: S3 Storage
      ;meta(charset "utf-8");
      ;style
        ;+  ;/  %-  trip  %-  crip
          ;:  weld
            "* \{ margin: 0; padding: 0; box-sizing: border-box; }"
            "body \{ font-family: -apple-system, system-ui, sans-serif; background: #0a0a0a; color: #eee; padding: 24px; max-width: 900px; margin: 0 auto; }"
            "h1 \{ font-size: 18px; margin-bottom: 16px; }"
            "h2 \{ font-size: 14px; color: #888; margin-top: 20px; margin-bottom: 8px; }"
            ".hdr \{ display: flex; align-items: center; gap: 12px; margin-bottom: 20px; }"
            ".btn \{ background: none; border: 1px solid #333; color: #aaa; padding: 4px 12px; border-radius: 6px; cursor: pointer; font-size: 12px; }"
            ".btn:hover \{ border-color: #666; color: #fff; }"
            ".btn:disabled \{ opacity: 0.4; cursor: default; }"
            ".btn-grn \{ border-color: #2a5a2a; color: #6c6; }"
            ".btn-grn:hover \{ border-color: #4a8a4a; }"
            ".btn-red \{ border-color: #5a2a2a; color: #c66; }"
            ".btn-red:hover \{ border-color: #8a4a4a; }"
            "table \{ width: 100%; border-collapse: collapse; margin-top: 8px; }"
            "th \{ text-align: left; color: #666; font-size: 11px; text-transform: uppercase; padding: 6px 8px; border-bottom: 1px solid #333; }"
            "td \{ padding: 6px 8px; border-bottom: 1px solid #1a1a1a; font-size: 13px; font-family: monospace; }"
            "#msg \{ font-size: 12px; margin-bottom: 8px; min-height: 16px; }"
            ".mount \{ border: 1px solid #222; border-radius: 8px; padding: 12px; margin-bottom: 12px; }"
            ".mount-hdr \{ display: flex; align-items: center; gap: 8px; margin-bottom: 8px; }"
            ".mount-name \{ font-weight: bold; font-size: 14px; }"
            ".mount-prefix \{ color: #666; font-size: 12px; font-family: monospace; }"
            ".modal-bg \{ display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.6); z-index: 100; align-items: center; justify-content: center; }"
            ".modal-bg.open \{ display: flex; }"
            ".modal \{ background: #111; border: 1px solid #333; border-radius: 12px; padding: 20px; width: 420px; }"
            ".modal h2 \{ margin-top: 0; }"
            ".lbl \{ display: block; color: #888; font-size: 11px; text-transform: uppercase; margin-bottom: 4px; margin-top: 12px; }"
            ".inp \{ width: 100%; padding: 8px 10px; border-radius: 6px; border: 1px solid #333; background: #111; color: #eee; font-size: 13px; font-family: monospace; outline: none; box-sizing: border-box; }"
            ".modal .btn \{ margin-top: 16px; }"
          ==
      ==
    ==
    ;body
      ;div(class "hdr")
        ;h1: S3 Storage
        ;button(class "btn", onclick "openConfig()"): Config
        ;button(class "btn", onclick "doListAll()"): List All
        ;button(class "btn btn-grn", onclick "openAddMount()"): + Mount
      ==
      ;div(id "msg");
      ;div(id "mounts");
      ::  config modal
      ;div(class "modal-bg", id "cfg-bg")
        ;div(class "modal")
          ;h2: S3 Configuration
          ;label(class "lbl"): Access Key
          ;input(class "inp", id "cfg-ak", type "text");
          ;label(class "lbl"): Secret Key
          ;input(class "inp", id "cfg-sk", type "password");
          ;label(class "lbl"): Region
          ;input(class "inp", id "cfg-rg", type "text");
          ;label(class "lbl"): Bucket
          ;input(class "inp", id "cfg-bk", type "text");
          ;label(class "lbl"): Endpoint
          ;input(class "inp", id "cfg-ep", type "text");
          ;button(class "btn", onclick "saveConfig()"): Save
          ;div(id "cfg-msg", style "font-size: 12px; margin-top: 8px;");
        ==
      ==
      ::  add mount modal
      ;div(class "modal-bg", id "mount-bg")
        ;div(class "modal")
          ;h2: Add Mount
          ;label(class "lbl"): Name
          ;input(class "inp", id "mount-name", type "text", placeholder "e.g. blog-images");
          ;label(class "lbl"): S3 Prefix
          ;input(class "inp", id "mount-prefix", type "text", placeholder "e.g. blog-images/");
          ;button(class "btn btn-grn", onclick "addMount()"): Create
          ;div(id "mount-msg", style "font-size: 12px; margin-top: 8px;");
        ==
      ==
      ;script
        ;+  ;/  %-  trip  %-  crip
          ;:  weld
            "var P=location.pathname.replace(/page\\.html$/,'');\0a"
            "var OVER=P.replace('/ball/','/api/over/');\0a"
            "var POKE=P.replace('/ball/','/api/poke/');\0a"
            "function $(id)\{ return document.getElementById(id); }\0a"
            "var busy=false;\0a"
            ::
            "function msg(t,err)\{ $('msg').textContent=t; $('msg').style.color=err?'#f55':'#666'; }\0a"
            ::
            ::  modals
            ::
            "document.querySelectorAll('.modal-bg').forEach(bg=>\{\0a"
            "  bg.onclick=function(e)\{ if(e.target===bg) bg.classList.remove('open'); };\0a"
            "});\0a"
            ::
            ::  config
            ::
            "function openConfig()\{\0a"
            "  $('cfg-msg').textContent='';\0a"
            "  fetch(P+'config.json').then(r=>r.json()).then(c=>\{\0a"
            "    $('cfg-ak').value=c['access-key']||'';\0a"
            "    $('cfg-sk').value=c['secret-key']||'';\0a"
            "    $('cfg-rg').value=c.region||'';\0a"
            "    $('cfg-bk').value=c.bucket||'';\0a"
            "    $('cfg-ep').value=c.endpoint||'';\0a"
            "  }).catch(()=>\{});\0a"
            "  $('cfg-bg').classList.add('open');\0a"
            "}\0a"
            "function saveConfig()\{\0a"
            "  fetch(OVER+'config.json?mark=json',\{method:'POST',headers:\{'content-type':'application/json'},\0a"
            "    body:JSON.stringify(\{\0a"
            "      'access-key':$('cfg-ak').value.trim(),\0a"
            "      'secret-key':$('cfg-sk').value.trim(),\0a"
            "      region:$('cfg-rg').value.trim()||'us-east-1',\0a"
            "      bucket:$('cfg-bk').value.trim(),\0a"
            "      endpoint:$('cfg-ep').value.trim()\0a"
            "    })\0a"
            "  }).then(r=>\{\0a"
            "    $('cfg-msg').textContent=r.ok?'Saved':'Error';\0a"
            "    $('cfg-msg').style.color=r.ok?'#4f4':'#f55';\0a"
            "    if(r.ok) setTimeout(()=>$('cfg-bg').classList.remove('open'),600);\0a"
            "  });\0a"
            "}\0a"
            ::
            ::  poke + sse
            ::
            "var KEEP=P.replace('/ball/','/api/keep/');\0a"
            "function poke(payload,cb)\{\0a"
            "  if(busy)\{ msg('Busy...', false); return; }\0a"
            "  busy=true;\0a"
            "  msg('Working...', false);\0a"
            "  fetch(POKE+'main.json?mark=json',\{method:'POST',headers:\{'content-type':'application/json'},\0a"
            "    body:JSON.stringify(payload)\0a"
            "  }).then(r=>\{\0a"
            "    if(!r.ok)\{ msg('Poke failed (HTTP '+r.status+')', true); busy=false; return; }\0a"
            "    watchResult(cb);\0a"
            "  }).catch(e=>\{ msg('Request failed: '+e, true); busy=false; });\0a"
            "}\0a"
            "function watchResult(cb)\{\0a"
            "  fetch(KEEP+'main.json?mark=json',\{headers:\{Accept:'text/event-stream'}})\0a"
            "  .then(r=>\{\0a"
            "    var rd=r.body.getReader(),dec=new TextDecoder(),buf='';\0a"
            "    function pump()\{\0a"
            "      rd.read().then(res=>\{\0a"
            "        if(res.done)\{ busy=false; return; }\0a"
            "        buf+=dec.decode(res.value,\{stream:true});\0a"
            "        var ps=buf.split('\\n\\n'); buf=ps.pop();\0a"
            "        for(var i=0;i<ps.length;i++)\{\0a"
            "          if(!ps[i].trim()) continue;\0a"
            "          var ls=ps[i].split('\\n'),data='';\0a"
            "          for(var j=0;j<ls.length;j++)\{\0a"
            "            if(ls[j].indexOf('data: ')===0) data+=ls[j].slice(6); }\0a"
            "          try\{ var d=JSON.parse(data);\0a"
            "            if(d.status==='working')\{ pump(); return; }\0a"
            "            rd.cancel(); busy=false;\0a"
            "            if(d.status==='error')\{ msg(d.error||'Failed',true); return; }\0a"
            "            cb(d);\0a"
            "            return;\0a"
            "          }catch(e)\{}\0a"
            "        }\0a"
            "        pump();\0a"
            "      }).catch(()=>\{ busy=false; });\0a"
            "    }\0a"
            "    pump();\0a"
            "  }).catch(e=>\{ msg('SSE failed: '+e,true); busy=false; });\0a"
            "}\0a"
            ::
            ::  mounts
            ::
            "function openAddMount()\{\0a"
            "  $('mount-msg').textContent='';\0a"
            "  $('mount-name').value='';\0a"
            "  $('mount-prefix').value='';\0a"
            "  $('mount-bg').classList.add('open');\0a"
            "}\0a"
            "function addMount()\{\0a"
            "  var n=$('mount-name').value.trim();\0a"
            "  var p=$('mount-prefix').value.trim();\0a"
            "  if(!n||!p)\{ $('mount-msg').textContent='Name and prefix required'; $('mount-msg').style.color='#f55'; return; }\0a"
            "  poke(\{op:'add-mount',name:n,prefix:p},function(d)\{\0a"
            "    $('mount-bg').classList.remove('open');\0a"
            "    msg('Mount added: '+n, false);\0a"
            "    loadMounts();\0a"
            "  });\0a"
            "}\0a"
            "function removeMount(name)\{\0a"
            "  if(!confirm('Remove mount '+name+'?')) return;\0a"
            "  poke(\{op:'remove-mount',name:name},function()\{\0a"
            "    msg('Removed '+name, false);\0a"
            "    loadMounts();\0a"
            "  });\0a"
            "}\0a"
            "function loadMounts()\{\0a"
            "  poke(\{op:'get-mounts'},function(d)\{\0a"
            "    var el=$('mounts'); el.innerHTML='';\0a"
            "    var m=d.mounts||\{};\0a"
            "    var names=Object.keys(m);\0a"
            "    if(names.length===0)\{ msg('No mounts. Click + Mount to add one.', false); return; }\0a"
            "    msg(names.length+' mount'+(names.length===1?'':'s'), false);\0a"
            "    names.forEach(function(n)\{\0a"
            "      var div=document.createElement('div');\0a"
            "      div.className='mount';\0a"
            "      div.id='mount-'+n;\0a"
            "      div.innerHTML='<div class=mount-hdr>'\0a"
            "        +'<span class=mount-name>'+n+'</span>'\0a"
            "        +'<span class=mount-prefix>'+m[n]+'</span>'\0a"
            "        +'<button class=\"btn btn-grn\" onclick=\"doRefresh(\\''+n+'\\')\">&darr; Refresh</button>'\0a"
            "        +'<button class=\"btn\" onclick=\"doListMount(\\''+n+'\\')\">&equiv; List</button>'\0a"
            "        +'<button class=\"btn btn-red\" onclick=\"removeMount(\\''+n+'\\')\">&times;</button>'\0a"
            "        +'</div>'\0a"
            "        +'<div id=\"files-'+n+'\"></div>';\0a"
            "      el.appendChild(div);\0a"
            "    });\0a"
            "  });\0a"
            "}\0a"
            ::
            ::  list all
            ::
            "function doListAll()\{\0a"
            "  poke(\{op:'list-all'},function(d)\{\0a"
            "    var keys=d.keys||[];\0a"
            "    var el=$('mounts');\0a"
            "    if(keys.length===0)\{ msg('Bucket is empty', false); return; }\0a"
            "    msg(keys.length+' object'+(keys.length===1?'':'s')+' in bucket', false);\0a"
            "    var h='<div class=mount><div class=mount-hdr><span class=mount-name>All Objects</span></div>';\0a"
            "    h+='<table><thead><tr><th>Key</th></tr></thead><tbody>';\0a"
            "    keys.forEach(function(k)\{\0a"
            "      h+='<tr><td style=\"font-size:12px;font-family:monospace\">'+k+'</td></tr>';\0a"
            "    });\0a"
            "    h+='</tbody></table></div>';\0a"
            "    el.insertAdjacentHTML('afterbegin',h);\0a"
            "  });\0a"
            "}\0a"
            ::
            ::  list mount contents
            ::
            "function doListMount(name)\{\0a"
            "  poke(\{op:'list',name:name},function(d)\{\0a"
            "    var el=$('files-'+name); if(!el) return;\0a"
            "    var keys=d.keys||[];\0a"
            "    if(keys.length===0)\{ el.innerHTML='<div style=\"color:#666;font-size:12px\">Empty</div>'; return; }\0a"
            "    var h='<table><thead><tr><th>Key</th><th></th></tr></thead><tbody>';\0a"
            "    keys.forEach(function(k)\{\0a"
            "      h+='<tr><td style=\"font-size:12px;font-family:monospace\">'+k+'</td><td>'\0a"
            "        +'<button class=\"btn btn-grn\" style=\"font-size:11px;padding:2px 8px\" onclick=\"doPull(\\''+name+'\\',\\''+k+'\\')\">&darr;</button> '\0a"
            "        +'<button class=\"btn btn-red\" style=\"font-size:11px;padding:2px 8px\" onclick=\"doDel(\\''+name+'\\',\\''+k+'\\')\">&times;</button>'\0a"
            "        +'</td></tr>';\0a"
            "    });\0a"
            "    h+='</tbody></table>';\0a"
            "    el.innerHTML=h;\0a"
            "  });\0a"
            "}\0a"
            ::
            ::  refresh
            ::
            "function doRefresh(name)\{\0a"
            "  poke(\{op:'refresh',name:name},function(d)\{\0a"
            "    msg('Refreshed '+name+': '+(d.pulled||0)+' files pulled', false);\0a"
            "  });\0a"
            "}\0a"
            ::
            ::  pull single
            ::
            "function doPull(name,key)\{\0a"
            "  poke(\{op:'pull',name:name,key:key},function(d)\{\0a"
            "    msg('Pulled '+key, false);\0a"
            "  });\0a"
            "}\0a"
            ::
            ::  delete
            ::
            "function doDel(name,key)\{\0a"
            "  if(!confirm('Delete '+key+' from S3?')) return;\0a"
            "  poke(\{op:'delete',name:name,key:key},function(d)\{\0a"
            "    if(d.ok) \{ msg('Deleted '+key, false); doListMount(name); }\0a"
            "    else msg('Delete failed', true);\0a"
            "  });\0a"
            "}\0a"
            ::
            ::  init
            ::
            "loadMounts();\0a"
          ==
      ==
    ==
  ==
--
