::  counter nexus: many auto-incrementing counters identified by @da
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
            [%fall %| /counters empty-dir:loader]
            [%over %& [/ui/views %'page.html'] [[/ %html] (crip (en-xml:html (counter-page ~)))]]
            [%fall %& [/ui %'main.sig'] [[/ %sig] ~]]
            [%fall %| /ui/requests empty-dir:loader]
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
          ::  /counters/*: each counter ticks up every second
          ::
          [[%counters ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%counter: process failed")
        |-
        ;<  count=@ud  bind:m  (get-state-as:io ,@ud)
        ;<  ~  bind:m  (sleep:io ~s1)
        ;<  ~  bind:m  (replace:io +(count))
        $
          ::  /ui/views/page.html: render full page HTML once, persist
          ::
          [[%ui %views ~] %'page.html']
        ;<  ~  bind:m  (rise-wait:io prod "%counter /ui/views/page: failed")
        ;<  init=wave:nexus  bind:m
          (keep:io /ctrs (cord-to-road:tarball '../../counters/') ~)
        |-
        ;<  upd=wave:nexus  bind:m  (take-news:io /ctrs)
        ;<  =seen:nexus  bind:m  (peek:io (cord-to-road:tarball '../../counters/') ~)
        ?.  ?=([%& %ball *] seen)  $
        =/  counters=(list [@ta @ud])
          =/  =lump:tarball  (fall fil.ball.p.seen *lump:tarball)
          %+  murn  ~(tap by contents.lump)
          |=  [name=@ta =sang:tarball gain=? bang=(unit tang)]
          ?.  ?=(%ud name.p.sang)  ~
          `[name !<(@ud (need-vase:tarball sang))]
        =/  page=manx  (counter-page counters)
        ;<  ~  bind:m  (replace:io (crip (en-xml:html page)))
        $
          ::  /ui/main.sig: bind HTTP endpoint and dispatch requests
          ::  into /ui/requests/. URL derived from tree position.
          ::
          [[%ui ~] %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%counter /ui/main: failed")
        ;<  ~  bind:m  (bind-http:io [~ /grubbery/counters])
        (http-dispatch:io %counter)
          ::  /ui/requests/*: individual request handlers
          ::
          [[%ui %requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%counter /ui/requests: failed")
        =/  eyre-id=@ta  name.rail
        ;<  [src=@p req=inbound-request:eyre]  bind:m  (get-state-as:io ,[src=@p inbound-request:eyre])
        ;<  our=@p  bind:m  get-our:io
        ?.  =(src our)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
          (pure:m ~)
        =/  prefix=path  /grubbery/counters
        =/  site=path  site:(parse-url:http-utils url.request.req)
        =/  suffix=path  (slag (lent prefix) site)
        ::  Serve counter page from view grub
        ;<  =seen:nexus  bind:m  (peek:io [%| 2 %& /ui/views %'page.html'] `[/ %mime])
        ?.  ?=([%& %file *] seen)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[500 ~] `(as-octs:mimes:html 'View not ready')])
          (pure:m ~)
        =/  =mime  !<(mime (need-vase:tarball sang.p.seen))
        ;<  ~  bind:m  (send-simple:srv eyre-id (mime-response:http-utils mime))
        (pure:m ~)
      ==
    ++  on-manu
      |=  =mana:nexus
      ^-  @t
      ?-    -.mana
          %&
        ?+  p.mana  'Subdirectory under the counter nexus.'
            ~
          %-  crip
          """
          COUNTER NEXUS — auto-incrementing counters with live web UI

          A simple demo nexus. Each counter is a file in /counters/ holding
          a @ud value. Poke a counter to increment it. The web UI at
          /ui/ renders all counters and streams updates via SSE.

          FILES:
            ver.ud              Schema version.

          DIRECTORIES:
            counters/           Counter storage. Each file is a @ud. Poke to
                                increment. Keyed by @da timestamp on creation.
            ui/                 Web interface with SSE streaming.
            ui/views/           Server-rendered HTML pages.
            ui/views/page.html  Full counter page. Mark: manx. Re-rendered
                                when counters change.
            ui/requests/        Per-request fibers for HTTP connections.
          """
            [%counters ~]
          'Counter storage. Each file holds a @ud value. Poke to increment. New counters are keyed by @da timestamp.'
            [%ui ~]
          'Counter web UI. Serves HTML page with live SSE updates when counters change.'
            [%ui %views ~]
          'Server-rendered HTML views for the counter UI.'
            [%ui %requests ~]
          'Per-request fibers for active HTTP connections to the counter UI.'
        ==
          %|
        ?+  rail.p.mana  'File under the counter nexus.'
          [~ %'ver.ud']                    'Schema version counter. Mark: ud.'
          [[%ui ~] %'main.sig']            'Counter UI HTTP binding process. Mark: sig. Registers with the server nexus and dispatches requests.'
          [[%ui %views ~] %'page.html']    'Full counter page. Mark: manx (Sail HTML). Re-rendered on counter changes.'
        ==
      ==
    --
|%
::  HTTP response door (road from /ui/requests/* to /ui/main.sig)
::
++  srv  ~(. http-res:io [%| 1 %& ~ %'main.sig'])
::
++  counter-page
  |=  counters=(list [@ta @ud])
  ^-  manx
  =/  js=tape
    ;:  weld
      "var P=window.location.pathname;"
      "var API,KEEP;"
      "if(P.indexOf('/ball/')>=0)\{API=P.replace('/ball/','/api/file/').replace('/ui/views/page.html','/counters');KEEP=P.replace('/ball/','/api/keep/').replace('/ui/views/page.html','/counters')}else\{API='/grubbery/api/file/apps/counter.counter/counters';KEEP='/grubbery/api/keep/apps/counter.counter/counters'}"
      "document.getElementById('create').onclick=function()\{fetch(API+'/'+Date.now().toString(36)+'?mark=ud',\{method:'PUT',headers:\{'Content-Type':'text/plain'},body:'0'})};"
      "function removeCounter(n)\{var e=document.getElementById('c-'+n);if(e)e.remove();if(!document.querySelector('.counter'))document.getElementById('counters').textContent='No counters'}"
      "function deleteCounter(n)\{fetch(API+'/'+n,\{method:'DELETE'});removeCounter(n)}"
      "function upsertCounter(n,v)\{var b=document.getElementById('counters');var e=document.getElementById('c-'+n);if(!e)\{if(b.textContent==='No counters')b.textContent='';e=document.createElement('div');e.id='c-'+n;e.className='counter fc fh g2 p2 b1 br1 jcsb';b.appendChild(e)}e.innerHTML='<div class=\"fc-col\"><span class=\"s7 bold\">'+v+'</span><span class=\"s9 muted\">'+n+'</span></div><button class=\"p-1 b1 br1 hover pointer s9\" onclick=\"deleteCounter(\\x27'+n+'\\x27)\">Delete</button>'}"
      "async function connect()\{try\{var r=await fetch(KEEP+'?mark=txt',\{headers:\{Accept:'text/event-stream'}});var R=r.body.getReader();var d=new TextDecoder();var buf='';while(true)\{var c=await R.read();if(c.done)break;buf+=d.decode(c.value,\{stream:true});var ps=buf.split('\\n\\n');buf=ps.pop();for(var i=0;i<ps.length;i++)\{if(!ps[i].trim())continue;var ev='',data='',ls=ps[i].split('\\n');for(var j=0;j<ls.length;j++)\{if(ls[j].indexOf('event: ')===0)ev=ls[j].slice(7);else if(ls[j].indexOf('data: ')===0)data=ls[j].slice(6)}if(!ev)continue;var sp=ev.indexOf(' ');if(sp<0)continue;var act=ev.slice(0,sp);var nm=ev.slice(sp+2);if(act==='old')continue;if(act==='del')removeCounter(nm);else upsertCounter(nm,data)}}}catch(x)\{}setTimeout(connect,2000)}connect()"
    ==
  ;html
    ;head
      ;title: Grubbery Counters
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;style
        ;+  ;/  "body \{ font-family: monospace; max-width: 600px; margin: 0 auto; padding: 2rem; } .counter \{ margin-bottom: 0.5rem; } .muted \{ opacity: 0.5; } .fc \{ display: flex; } .fh \{ flex-direction: row; } .fc-col \{ display: flex; flex-direction: column; } .g2 \{ gap: 0.5rem; } .p2 \{ padding: 0.5rem; } .p-1 \{ padding: 0.25rem 0.5rem; } .b1 \{ border: 1px solid #ccc; } .br1 \{ border-radius: 4px; } .jcsb \{ justify-content: space-between; align-items: center; } .s7 \{ font-size: 1.2rem; } .s9 \{ font-size: 0.8rem; } .bold \{ font-weight: bold; } .hover:hover \{ background: #eee; } .pointer \{ cursor: pointer; } .mb2 \{ margin-bottom: 1rem; }"
      ==
    ==
    ;body
      ;h1: Grubbery Counters
      ;button#create.mb2.p2.b1.br1.hover.pointer: + New Counter
      ;div#counters
        ;*  ?~  counters
              =/  empty=manx  ;span: No counters
              ~[empty]
            %+  turn  counters
            |=  [name=@ta val=@ud]
            =/  n=tape  (trip name)
            =/  v=tape  (a-co:co val)
            ;div.counter.fc.fh.g2.p2.b1.br1.jcsb(id "c-{n}")
              ;div.fc-col
                ;span.s7.bold: {v}
                ;span.s9.muted: {n}
              ==
              ;button.p-1.b1.br1.hover.pointer.s9(onclick "deleteCounter('{n}')"): Delete
            ==
      ==
      ;script
        ;+  ;/  js
      ==
    ==
  ==
--
