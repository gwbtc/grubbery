/-  g=grubbery
/+  grubberyio, server, multipart,
    html-utils, fi=feather-icons, x=examples,
    wc=web-components
|%
++  mx  mx:html-utils
++  kv  kv:html-utils
::
++  make-id  |=(p=path (trip (rap 3 (join '_' `path`[%grub p]))))
::
++  base
  =/  grubberyio  grubberyio(hold |)
  =,  grubberyio
  ^-  base:g
  =<
  =/  m  (charm ,~)
  ^-  form:m
  ;<  [=stud:g =vase]  bind:m  get-poke-pail
  ;<  here=path        bind:m  get-here
  ?+    stud  !!
      [%gui %init ~]
    ;<  ~  bind:m  (eyre-connect /grub here)
    done
    ::
      [%handle-http-request ~]
    =+  !<([request-line:server req=inbound-request:eyre] vase)
    ~&  >>  accept+(get-header:http 'accept' header-list.request.req)
    ~&  >>  connection+(get-header:http 'connection' header-list.request.req)
    ~&  >>  last-event-id+(get-header:http 'last-event-id' header-list.request.req)
    ~&  >  "received {(trip method.request.req)} request for {(spud site)}!"
    ?:  (is-sse-request req)
      ~&  >>  %is-sse
      (do-sse (sse-last-id req) [ext site] args)
    ~&  >>  %not-sse
    ?+    method.request.req
      %-  give-simple-payload
      (method-not-allowed method.request.req)
      ::
      %'GET'  (do-get [ext site] args)
      ::
        %'POST'
      =/  parts=(unit (list [@t part:multipart]))
        (de-request:multipart [header-list body]:request.req)
      ?^  parts
        ;<  ~  bind:m  (do-upload site u.parts)
        (give-simple-payload two-oh-four)
      =/  args=key-value-list:kv  (parse-body:kv body.request.req)
      =/  get=(unit @t)  (get-key:kv 'get' args)
      ~&  >>  get+get
      ;<  ~  bind:m  (do-post site (delete-key:kv 'get' args))
      ?~  get
        (give-simple-payload two-oh-four)
      (do-get (parse-request-line:server u.get))
    ==
  ==
  ::
  |%
  ++  do-sse
    |=  [last-id=(unit @t) request-line:server]
    =/  m  (charm ,~)
    ^-  form:m
    ?>  ?=([%grub %events ~] site)
    ~&  >  "HELLO WORLD!"
    ;<  ~  bind:m  give-sse-header
    =|  a=@ud
    |-
    ?:  =(5 a)
      ;<  ~  bind:m  (give-sse-manx ~ `'close' *manx)
      done
    =/  =manx
      ;div: {(scow %ud a)}
    ~&  >  "giving sse {(scow %ud a)}"
    ;<  ~  bind:m  (give-sse-manx `(scot %ud a) ~ manx)
    ;<  ~  bind:m  (sleep ~s1)
    $(a +(a))
  ::
  ++  do-get
    |=  request-line:server
    =/  m  (charm ,~)
    ^-  form:m
    ~&  >>  %doing-get
    ?+    site
      ;<  =cone:g   bind:m  (peek /)
      (give-manx-response (main-page cone))
      ::
        [%grub %mime %web-components %side-bar ~]
      %-  give-mime-response
      :-  ~s0
      :-  /application/javascript
      (as-octs:mimes:html side-bar:wc)
      ::
        [%grub %mime %web-components %row-split ~]
      %-  give-mime-response
      :-  ~s0
      :-  /application/javascript
      (as-octs:mimes:html row-split:wc)
      ::
        [%grub %mime %web-components %col-split ~]
      %-  give-mime-response
      :-  ~s0
      :-  /application/javascript
      (as-octs:mimes:html col-split:wc)
      ::
        [%grub %mime *]
      ~&  >>>  %miming
      ;<  =grub:g  bind:m  (peek-root t.t.site)
      ?>  ?=(%base -.grub)
      ;<  =cone:g  bind:m  (peek t.t.site)
      ;<  =pail  bind:m  (vent t.t.site /gui/mime !>(~))
      ~&  >>>  %we-got-the-pail
      ?>  ?=([%mime ~] p.pail)
      ~&  >>  %extracting-mime
      =+  !<(=mime q.pail)
      ~&  >>  %giving-mime-response
      =/  =manx
        ;h1: Hello, world!
      (give-manx-response manx)
      :: (give-mime-response ~s0 !<(mime q.pail))
      ::
        [%grub %main ~]
      ~&  >>  "got to /grub/main"
      ;<  =cone:g  bind:m  (peek /)
      (give-manx-response (wrap-manx (main cone)))
      ::
        [%grub %search-bar *]
      (give-manx-response (search-bar t.t.site))
      ::
        [%grub %tree %lib *]
      ;<  g=(unit grub:g)  bind:m  (peek-root-soft t.t.site)
      ;<  =manx  bind:m  (grub-tree-lib t.t.t.site)
      (give-manx-response manx)
      ::
        [%grub %tree *]
      ;<  =manx  bind:m  (grub-tree t.t.site)
      (give-manx-response manx)
      ::
        [%grub %view %both *]
      ;<  =manx  bind:m  (grub-view-both t.t.t.site)
      (give-manx-response manx)
      ::
        [%grub %view %stud *]
      ;<  =manx  bind:m  (grub-view-stud t.t.t.site)
      (give-manx-response manx)
      ::
        [%grub %view %cone *]
      ;<  =manx  bind:m  (grub-view-cone t.t.t.site)
      (give-manx-response manx)
      ::
        [%grub %view %sour *]
      ;<  =manx  bind:m  (grub-view-sour t.t.t.site)
      (give-manx-response manx)
      ::
        [%grub %code *]
      ;<  =manx  bind:m  (grub-code t.t.site)
      (give-manx-response manx)
      ::
        [%grub %gui %con *]
      ;<  =manx  bind:m  (grub-gui-con t.t.t.site)
      (give-manx-response manx)
      ::
        [%grub %dom *]
      ;<  =manx   bind:m  (get-dom-manx t.t.site)
      (give-manx-response manx)
    ==
  ::
  ++  do-upload
    |=  [site=path parts=(list [@t part:multipart])]
    =/  m  (charm ,~)
    ^-  form:m
    ?+    site  !!
        [%grub %upload *]
      ;<  =grub:g  bind:m  (peek-root t.t.site)
      ?>  ?=(%base -.grub)
      ;<  *  bind:m  (poke t.t.site /multipart !>(parts))
      (pure:m ~)
    ==
  ::
  ++  do-post
    |=  [site=path args=key-value-list:kv]
    =/  m  (charm ,~)
    ^-  form:m
    ?+    site  !!
      [%grub %get ~]  (pure:m ~)
      ::
        [%grub %make %base ~]
      =/  =path       (rash (need (get-key:kv 'path' args)) stap)
      =/  base=^path  (rash (need (get-key:kv 'base' args)) stap)
      ;<  grub=(unit grub:g)  bind:m  (peek-root-soft %lib %base base)
      ;<  ~  bind:m
        ?^(grub (pure:(charm ,~)) (overwrite-base-lib base base-template:x))
      (overwrite-base path base ~)
      ::
        [%grub %make %stem ~]
      =/  =path       (rash (need (get-key:kv 'path' args)) stap)
      =/  stem=^path  (rash (need (get-key:kv 'stem' args)) stap)
      =/  sour=(set ^path)
        (sy (rash (need (get-key:kv 'sour' args)) (more com stap)))
      ;<  grub=(unit grub:g)  bind:m  (peek-root-soft %lib %stem stem)
      ;<  ~  bind:m
        ?^(grub (pure:(charm ,~)) (overwrite-stem-lib stem stem-template:x))
      (overwrite-stem path stem sour)
      ::
        [%grub %kill %base ~]
      !!
      :: (kill-base (rash (need (get-key:kv 'path' args)) stap))
      ::
        [%grub %init %base ~]
      =/  =path  (rash (need (get-key:kv 'path' args)) stap)
      :: TODO: rewrite +throw
      (poke path /init !>(~))
      ::
        [%grub %load %base ~]
      =/  =path  (rash (need (get-key:kv 'path' args)) stap)
      :: TODO: rewrite +throw
      (poke path /load !>(~))
      ::
        [%grub %sig %base ~]
      =/  =path  (rash (need (get-key:kv 'path' args)) stap)
      :: TODO: rewrite +throw
      (poke path /sig !>(~))
      ::
        [%grub %oust %grub ~]
      (oust-grub (rash (need (get-key:kv 'path' args)) stap))
      ::
        [%grub %cull %cone ~]
      (cull-cone (rash (need (get-key:kv 'path' args)) stap))
      ::
        [%grub %sand %sysc ~]
      (edit-perm (rash (need (get-key:kv 'path' args)) stap) ~)
      ::
        [%grub %sand %grub ~]
      =/  =path       (rash (need (get-key:kv 'path' args)) stap)
      =/  make=(set ^path)
        (sy (rash (need (get-key:kv 'make' args)) (more com stap)))
      =/  poke=(set ^path)
        (sy (rash (need (get-key:kv 'poke' args)) (more com stap)))
      =/  peek=(set ^path)
        (sy (rash (need (get-key:kv 'peek' args)) (more com stap)))
      (edit-perm path ~ make poke peek)
      ::
        [%grub %make %lib ~]
      =/  =path    (rash (need (get-key:kv 'path' args)) stap)
      =/  code=@t  (need (get-key:kv 'code' args))
      (overwrite-lib path code)
      ::
        [%grub %oust %lib ~]
      =/  =path  (rash (need (get-key:kv 'path' args)) stap)
      ;<  ~  bind:m  (oust-grub [%lib path])
      (oust-grub [%bin path])
      ::
        [%grub %cull %lib ~]
      =/  =path  (rash (need (get-key:kv 'path' args)) stap)
      ;<  ~  bind:m  (cull-cone [%lib path])
      (cull-cone [%bin path])
      ::
        [%grub %poke *]
      ~&  >>>  %receiving-poke-post
      ;<  =grub:g  bind:m  (peek-root t.t.site)
      ?>  ?=(%base -.grub)
      ;<  p=grub:g  bind:m  (peek-root (weld /bin/gui/con/poke base.grub))
      =/  =pail:g
        (!<($-(key-value-list:kv pail) (grab-data p)) args)
      ;<  *  bind:m  (poke t.t.site pail)
      (pure:m ~)
    ==
    
  ++  vase-to-manx
    |=  =^vase
    ^-  manx
    ;code.flex-grow:"*{(render-tang-to-marl 80 (sell vase) ~)}"
  ::
  ++  wrap-manx
    |=  =manx
    ^+  manx
    ;html(lang "en")
      ;head
        ;meta(charset "UTF-8");
        ;meta(name "viewport", content "width=device-width, initial-scale=1.0");
        ;title: Grubbery
        ;script(src "https://cdn.tailwindcss.com");
        ;script(src "https://unpkg.com/htmx.org@2.0.3");
        ;script(src "https://unpkg.com/htmx-ext-sse@2.2.2/sse.js");
        ;script(src "https://code.jquery.com/jquery-3.6.0.min.js");
        ;script(type "module", src "/grub/mime/web-components/side-bar");
        ;script(type "module", src "/grub/mime/web-components/row-split");
        ;script(type "module", src "/grub/mime/web-components/col-split");
        ;style
          :not(:defined) \{ visibility: hidden; }
        ==
      ==
      ;body.h-screen.w-screen
        =hx-ext  "sse"
        =sse-connect  "/grub/events"
        =sse-close  "close"
        :: ;div
        ::   ;div
        ::     ;div
        ::       =sse-swap  "message"
        ::       Waiting for message...
        ::     ==
        ::   ==
        :: ==
        :: ;form
        ::   =action  "/grub/upload"
        ::   =method  "POST"
        ::   =enctype  "multipart/form-data"
        ::   ;label(for "file"): Choose a file:
        ::   ;input
        ::     =type  "file"
        ::     =id  "file"
        ::     =name  "file"
        ::     =required  ""
        ::     ;
        ::   ==
        ::   ;button(type "submit"): Upload
        :: ==
        ;+  manx
      ==
    ==
  ::
  ++  main
    |=  =cone:g
    ^-  manx
    ;col-split.h-full.w-full
      ;div(slot "top", height "3.5em")
        ;+  (navbar /)
      ==
      ;div(slot "bottom")
        ;side-bar
          =id  "side-bar"
          =class  "h-full w-full"
          =side  "left"
          =divider-style  "background-color: #3B82F6; width: 3px;"
          =initial  "25%"
          =min-left  "20%"
          =max-left  "30%"
          ;div
            =slot  "left"
            =id  "tree-tab"
            =class  "h-full w-full overflow-auto text-white font-mono font-bold"
            ;+  (cone-navigator / cone)
          ==
          ;div
            =slot  "right"
            =id  "display"
            =class  "h-full w-full flex flex-col bg-gray-100 items-center justify-center overflow-auto"
            ;
          ==
        ==
      ==
    ==
  ::
  ++  navbar
    |=  =path
    ^-  manx
    ;div.h-full.w-full.flex.flex-row.items-center.justify-start.text-white.font-mono.font-bold.bg-blue-500
      ;button
        =class  "px-4 py-2 hover:bg-blue-200"
        =onclick  "$('#side-bar')[0].toggleAttribute('hide');"
        ;+  (make:fi %menu)
      ==
      ;+  (search-bar path)
    ==
  ::
  ++  search-bar
    |=  =path
    ^-  manx
    ;div(id "search-bar", class "h-full w-full flex flex-row")
      ;form#search
        =class  "hidden m-1 flex-grow flex flex-row"
        =hx-post  "/grub/get"
        =hx-swap  "outerHTML"
        =hx-target  "#search-bar"
        =onsubmit  "document.getElementById('search-in').value = '/grub/search-bar' + document.getElementById('search-in').value;"
        =hx-on-htmx-after-request  "$('#search').addClass('hidden'); $('#crumbs').removeClass('hidden');"
        ;input#search-in
          =class  "p-2 bg-blue-200 flex-grow font-mono text-gray-600 focus:outline-none focus:ring-1 focus:ring-blue-500"
          =type  "text"
          =required  ""
          =name  "get"
          =placeholder  ""
          =pattern  "^(/)?([a-zA-Z0-9_\\-\\~\\.]+(/)?)*$"
          =spellcheck  "false"
          =autocomplete  "off"
          =onfocusout  "$('#search').addClass('hidden'); $('#crumbs').removeClass('hidden');"
          =value  ?:(=(~ path) "/" "{(spud path)}/")
          ;
        ==
        ;div(class "font-mono p-2 bg-blue-400")
          ;+  (make:fi %search)
        ==
      ==
      ;div(id "crumbs", class "m-1 flex-grow flex flex-row items-center justify-center")
        ;*  %+  turn  (gulf 0 (lent path))
            |=  i=@ud
            ^-  manx
            ;div
              =hx-get  "/grub/search-bar{=/(rest (scag i path) ?:(=(~ rest) "" (spud rest)))}"
              =hx-target  "#search-bar"
              =hx-swap  "outerHTML"
              =hx-trigger  "click"
              =class  "cursor-pointer"
              ; {?:(=(0 i) "/" "{(trip (snag (dec i) path))}/")}
            ==
        ;button
          =class  "font-mono h-full w-full flex flex-row p-2 hover:bg-blue-200 justify-between"
          =onclick  "$('#crumbs').addClass('hidden'); $('#search').removeClass('hidden'); $('#search-in').focus().get(0).setSelectionRange(999,999);"
          ;div.hidden
            =hx-get  "/grub/tree{(spud path)}"
            =hx-target  "#display"
            =hx-swap  "innerHTML"
            =hx-trigger  "load"
            =hx-indicator  "#loading-indicator"
            ;
          ==
          ;div
            =id  "loading-indicator"
            =class  "htmx-indicator p-2"
            ;+  (pac:~(at mx (make:fi %loader)) "animate-spin")
          ==
          ;div.p-2
            ;+  (make:fi %search)
          ==
        ==
      ==
    ==
  ::
  ++  cone-navigator
    |=  [=path =cone:g]
    ^-  manx
    ;div.pl-6
      ;div
        =class  "flex flex-row px-1 py-2 bg-blue-500 hover:bg-blue-200"
        ;*  ?:  =(~ dir.cone)
              ~
            ;=
              ;button.chevron-right
                =onclick  "$(this).addClass('hidden').siblings('.chevron-down').removeClass('hidden').parent().next().removeClass('hidden');"
                ;+  (make:fi %chevron-right)
              ==
              ;button.chevron-down.hidden
                =onclick  "$(this).addClass('hidden').siblings('.chevron-right').removeClass('hidden').parent().next().addClass('hidden');"
                ;+  (make:fi %chevron-down)
              ==
            ==
        ;div
          =hx-get  "/grub/search-bar{?:(=(~ path) "" (spud path))}"
          =hx-target  "#search-bar"
          =hx-swap  "outerHTML"
          =hx-trigger  "click"
          =class  "cursor-pointer"
          ; {?~(path "/" (trip (rear path)))}
        ==
        ;button
          =class  "ml-auto hover:bg-blue-300 text-white opacity-0 hover:opacity-100 transition-opacity duration-200 font-bold py-1 px-2 rounded"
          +
        == 
      ==
      ;div.children.flex.flex-col.hidden
        ;*  %+  turn  ~(tap by dir.cone)
            |=  [name=@ta =cone:g]
            (cone-navigator (weld path /[name]) cone)
      ==
    ==
  ::
  ++  no-grub
    |=  [=path perm=(unit perm:g)]
    ^-  manx
    ;div.w-full.h-full.flex.flex-col(id (make-id path))
      ;div(class "flex justify-center p-1 border-b border-gray-300 bg-gray-50")
        ;button
          =id  "baseTab"
          =class  "tab-button px-4 py-2 text-gray-700 font-semibold focus:outline-none transition duration-300 border-b-2 border-blue-500 text-blue-500"
          =onclick  "$(this).addClass('border-b-2 border-blue-500 text-blue-500').siblings().removeClass('border-b-2 border-blue-500 text-blue-500'); $('#make-base').show(); $('#make-stem').hide(); $('#sandbox').hide();"
          ; Make Base
        ==
        ;button
          =id  "stemTab"
          =class  "tab-button px-4 py-2 text-gray-700 font-semibold focus:outline-none transition duration-300"
          =onclick  "$(this).addClass('border-b-2 border-blue-500 text-blue-500').siblings().removeClass('border-b-2 border-blue-500 text-blue-500'); $('#make-stem').show(); $('#make-base').hide(); $('#sandbox').hide();"
          ; Make Stem
        ==
        ;button
          =id  "stemTab"
          =class  "tab-button px-4 py-2 text-gray-700 font-semibold focus:outline-none transition duration-300"
          =onclick  "$(this).addClass('border-b-2 border-blue-500 text-blue-500').siblings().removeClass('border-b-2 border-blue-500 text-blue-500'); $('#sandbox').show(); $('#make-stem').hide(); $('#make-base').hide();"
          ; Sandbox
        ==
      ==
      ;div#sandbox.hidden.flex-grow.flex.flex-col.w-full.bg-gray-100.overflow-hidden
        ;div(class "h-full flex-grow flex items-center justify-center")
          ;div.m-4.flex-grow.flex.flex-col
            ;form
              =class  "space-y-4"
              =hx-post  "/grub/sand/sysc"
              =hx-indicator  "#loading-indicator"
              =hx-target  "#{(make-id path)}"
              =hx-swap  "outerHTML"
              =hx-confirm  "Are you sure you want to give system access to {(spud path)}?"
              ;input(type "hidden", name "get", value "/grub/tree{(spud path)}");
              ;input(type "hidden", name "path", value "{(spud path)}");
              ;div(class "flex items-center justify-center mt-6")
                ;+  ?~  perm
                    ;div(class "text-center text-3xl font-bold text-gray-800 p-4 bg-gray-200 rounded-lg shadow-lg")
                      ; Full System Access
                    ==
                    ;button(type "submit", class "bg-blue-500 text-white font-bold py-2 px-6 rounded-lg hover:bg-blue-600 transition duration-300 ease-in-out")
                      ; Give System Access
                    ==
              ==
            ==
            ;form
              =class  "space-y-4"
              =hx-post  "/grub/sand/grub"
              =hx-indicator  "#loading-indicator"
              =hx-target  "#{(make-id path)}"
              =hx-swap  "outerHTML"
              =hx-confirm  "Are you sure you want to edit the perms of {(spud path)}?"
              ;input(type "hidden", name "get", value "/grub/tree{(spud path)}");
              ;input(type "hidden", name "path", value "{(spud path)}");
              ;div
                ;label
                  =for  "make"
                  =class  "block text-gray-700 font-semibold mb-1"
                  ; Make
                ==
                ;textarea
                  =id  "make"
                  =name  "make"
                  =rows  "4"
                  =class  "w-full p-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                  =placeholder  "Enter paths separated by commas: /path/one,/path/two,/path/three"
                  ;+  ;/
                  %-  trip
                  %+  rap  3
                  %+  join  ','
                  (turn ?~(perm ~ ~(tap in make.u.perm)) spat)
                ==
              ==
              ;div
                ;label
                  =for  "poke"
                  =class  "block text-gray-700 font-semibold mb-1"
                  ; Poke
                ==
                ;textarea
                  =id  "poke"
                  =name  "poke"
                  =rows  "4"
                  =class  "w-full p-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                  =placeholder  "Enter paths separated by commas: /path/one,/path/two,/path/three"
                  ;+  ;/
                  %-  trip
                  %+  rap  3
                  %+  join  ','
                  (turn ?~(perm ~ ~(tap in poke.u.perm)) spat)
                ==
              ==
              ;div
                ;label
                  =for  "peek"
                  =class  "block text-gray-700 font-semibold mb-1"
                  ; Peek
                ==
                ;textarea
                  =id  "peek"
                  =name  "peek"
                  =rows  "4"
                  =class  "w-full p-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                  =placeholder  "Enter paths separated by commas: /path/one,/path/two,/path/three"
                  ;+  ;/
                  %-  trip
                  %+  rap  3
                  %+  join  ','
                  (turn ?~(perm ~ ~(tap in peek.u.perm)) spat)
                ==
              ==
              ;div(class "flex items-center justify-center mt-6")
                ;button(type "submit", class "bg-blue-500 text-white font-bold py-2 px-6 rounded-lg hover:bg-blue-600 transition duration-300 ease-in-out")
                  ;+  ;/
                  ?~  perm
                    "Give Perms"
                  "Edit Perms"
                ==
              ==
            ==
          ==
        ==
      ==
      ;div(id "make-base", class "max-w-md mx-auto p-6 bg-white shadow-lg rounded-lg mt-10 border border-gray-200")
        ;h2(class "text-2xl font-bold text-gray-700 mb-6 text-center"): Make Base
        ;form
          =class  "space-y-4"
          =hx-post  "/grub/make/base"
          =hx-indicator  "#loading-indicator"
          =hx-target  "#{(make-id path)}"
          =hx-swap  "outerHTML"
          ;input(type "hidden", name "get", value "/grub/tree{(spud path)}");
          ;input(type "hidden", name "path", value "{(spud path)}");
          ;div
            ;label
              =for  "base"
              =class  "block text-gray-700 font-semibold mb-1"
              ; Base
            ==
            ;input
              =type  "text"
              =id  "base"
              =name  "base"
              =required  ""
              =class  "w-full p-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              ;
            ==
          ==
          ;div(class "flex items-center justify-center mt-6")
            ;button(type "submit", class "bg-blue-500 text-white font-bold py-2 px-6 rounded-lg hover:bg-blue-600 transition duration-300 ease-in-out")
              ; Make
            ==
            ;div(id "loading-indicator", class "ml-4 htmx-indicator")
              ;svg(class "animate-spin h-6 w-6 text-blue-500", xmlns "http://www.w3.org/2000/svg", fill "none", viewBox "0 0 24 24")
                ;circle(class "opacity-25", cx "12", cy "12", r "10", stroke "currentColor", stroke-width "4");
                ;path(class "opacity-75", fill "currentColor", d "M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z");
              ==
            ==
          ==
        ==
      ==
      ;div(id "make-stem", class "hidden max-w-md mx-auto p-6 bg-white shadow-lg rounded-lg mt-10 border border-gray-200")
        ;h2(class "text-2xl font-bold text-gray-700 mb-6 text-center"): Make Stem
        ;form
          =class  "space-y-4"
          =hx-post  "/grub/make/stem"
          =hx-indicator  "#loading-indicator"
          =hx-target  "#{(make-id path)}"
          =hx-swap  "outerHTML"
          ;input(type "hidden", name "get", value "/grub/tree{(spud path)}");
          ;input(type "hidden", name "path", value "{(spud path)}");
          ;div
            ;label
              =for  "stem"
              =class  "block text-gray-700 font-semibold mb-1"
              ; Stem
            ==
            ;input
              =type  "text"
              =id  "stem"
              =name  "stem"
              =required  ""
              =class  "w-full p-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              ;
            ==
          ==
          ;div
            ;label
              =for  "sour"
              =class  "block text-gray-700 font-semibold mb-1"
              ; Sources
            ==
            ;textarea
              =id  "sour"
              =name  "sour"
              =rows  "4"
              =class  "w-full p-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              =placeholder  "Enter paths separated by commas: /path/one,/path/two,/path/three"
              ;
            ==
          ==
          ;div(class "flex items-center justify-center mt-6")
            ;button(type "submit", class "bg-blue-500 text-white font-bold py-2 px-6 rounded-lg hover:bg-blue-600 transition duration-300 ease-in-out")
              ; Make
            ==
            ;div(id "loading-indicator", class "ml-4 htmx-indicator")
              ;svg(class "animate-spin h-6 w-6 text-blue-500", xmlns "http://www.w3.org/2000/svg", fill "none", viewBox "0 0 24 24")
                ;circle(class "opacity-25", cx "12", cy "12", r "10", stroke "currentColor", stroke-width "4");
                ;path(class "opacity-75", fill "currentColor", d "M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z");
              ==
            ==
          ==
        ==
      ==
    ==
  ::
  ++  grub-tree
    |=  =path
    =/  m  (charm ,manx)
    ^-  form:m
    ;<  grub=(unit grub:g)  bind:m  (peek-root-soft path)
    ;<  perm=(unit perm:g)  bind:m  (get-perm path)
    ?~  grub
      (pure:m (no-grub path perm))
    %-  pure:m
    ^-  manx
    ;col-split(id (make-id path), class "w-full h-full mx-auto bg-white shadow-lg rounded-lg flex flex-col")
      ;div.flex.flex-row.items-center.justify-center.text-white.font-mono.font-bold
        =slot  "top"
        =height  "5em"
        ;*  ?.  ?=(%base -.u.grub)  ~
            ;=
              ;form
                =hx-post  "/grub/init/base"
                =hx-trigger  "submit"
                =hx-swap  "outerHTML"
                =hx-target  "#{(make-id path)}"
                =hx-confirm  "Are you sure you want to init base grub {(spud path)}?"
                ;input(type "hidden", name "get", value "/grub/tree{(spud path)}");
                ;input(type "hidden", name "path", value "{(spud path)}");
                ;button
                  =type   "submit"
                  =class  "mx-1 my-2 px-4 py-2 rounded-lg bg-green-500 hover:bg-green-200"
                  ; init
                ==
              ==
              ;form
                =hx-post  "/grub/load/base"
                =hx-trigger  "submit"
                =hx-swap  "outerHTML"
                =hx-target  "#{(make-id path)}"
                =hx-confirm  "Are you sure you want to load base grub {(spud path)}?"
                ;input(type "hidden", name "get", value "/grub/tree{(spud path)}");
                ;input(type "hidden", name "path", value "{(spud path)}");
                ;button
                  =type   "submit"
                  =class  "mx-1 my-2 px-4 py-2 rounded-lg bg-green-500 hover:bg-green-200"
                  ; load
                ==
              ==
              ;form
                =hx-post  "/grub/sig/base"
                =hx-trigger  "submit"
                =hx-swap  "outerHTML"
                =hx-target  "#{(make-id path)}"
                =hx-confirm  "Are you sure you want to poke base grub {(spud path)} with a /sig?"
                ;input(type "hidden", name "get", value "/grub/tree{(spud path)}");
                ;input(type "hidden", name "path", value "{(spud path)}");
                ;button
                  =type   "submit"
                  =class  "mx-1 my-2 px-4 py-2 rounded-lg bg-green-500 hover:bg-green-200"
                  ; sig
                ==
              ==
              ;form
                =hx-post  "/grub/kill/base"
                =hx-trigger  "submit"
                =hx-swap  "outerHTML"
                =hx-target  "#{(make-id path)}"
                =hx-confirm  "Are you sure you want to kill base grub {(spud path)}?"
                ;input(type "hidden", name "get", value "/grub/tree{(spud path)}");
                ;input(type "hidden", name "path", value "{(spud path)}");
                ;+  ?:  %&
                      ;button
                        =type   "submit"
                        =class  "mx-1 my-2 px-4 py-2 rounded-lg bg-gray-500"
                        =disabled  ""
                        ; kill
                      ==
                    ;button
                      =type   "submit"
                      =class  "mx-1 my-2 px-4 py-2 rounded-lg bg-red-500 hover:bg-red-200"
                      ; kill
                    ==
              ==
            ==
        ;form
          =hx-post  "/grub/oust/grub"
          =hx-trigger  "submit"
          =hx-swap  "outerHTML"
          =hx-target  "#{(make-id path)}"
          =hx-confirm  "Are you sure you want to oust {?:(?=(%base -.u.grub) "base" "stem")} grub {(spud path)}?"
          ;input(type "hidden", name "get", value "/grub/tree{(spud path)}");
          ;input(type "hidden", name "path", value "{(spud path)}");
          ;button
            =type   "submit"
            =class  "mx-1 my-2 px-4 py-2 rounded-lg bg-blue-500 hover:bg-blue-200"
            ; oust
          ==
        ==
        ;form
          =hx-post  "/grub/cull/cone"
          =hx-trigger  "submit"
          =hx-swap  "outerHTML"
          =hx-target  "#{(make-id path)}"
          =hx-confirm  "Are you sure you want to cull {?:(?=(%base -.u.grub) "base" "stem")} grub {(spud path)}?"
          ;input(type "hidden", name "get", value "/grub/tree{(spud path)}");
          ;input(type "hidden", name "path", value "{(spud path)}");
          ;button
            =type   "submit"
            =class  "mx-1 my-2 px-4 py-2 rounded-lg bg-blue-500 hover:bg-blue-200"
            ; cull
          ==
        ==
        ;form
          ;div
            =class  "cursor-pointer mx-1 my-2 px-4 py-2 rounded-lg bg-blue-500 hover:bg-blue-200"
            =onclick  "$('#sandbox').show(); $('#grub-view').hide();"
            ; sand
          ==
        ==
      ==
      ;div.w-full.h-full
        =slot  "bottom"
        ;div#sandbox.hidden.flex-grow.flex.flex-col.w-full.bg-gray-100.overflow-hidden
          ;div.p-2.w-full.flex.justify-between.bg-gray-200
            ;button
              =class  "p-2 rounded-full hover:bg-gray-400 text-white font-mono font-bold"
              =onclick  "$('#grub-view').show(); $('#sandbox').hide();"
              ;+  (make:fi %arrow-left)
            ==
          ==
          ;div(class "h-full flex-grow flex items-center justify-center")
            ;div.m-4.flex-grow.flex.flex-col
              ;form
                =class  "space-y-4"
                =hx-post  "/grub/sand/sysc"
                =hx-indicator  "#loading-indicator"
                =hx-target  "#{(make-id path)}"
                =hx-swap  "outerHTML"
                =hx-confirm  "Are you sure you want to give system access to {(spud path)}?"
                ;input(type "hidden", name "get", value "/grub/tree{(spud path)}");
                ;input(type "hidden", name "path", value "{(spud path)}");
                ;div(class "flex items-center justify-center mt-6")
                  ;+  ?~  perm
                      ;div(class "text-center text-3xl font-bold text-gray-800 p-4 bg-gray-200 rounded-lg shadow-lg")
                        ; Full System Access
                      ==
                      ;button(type "submit", class "bg-blue-500 text-white font-bold py-2 px-6 rounded-lg hover:bg-blue-600 transition duration-300 ease-in-out")
                        ; Give System Access
                      ==
                ==
              ==
              ;form
                =class  "space-y-4"
                =hx-post  "/grub/sand/grub"
                =hx-indicator  "#loading-indicator"
                =hx-target  "#{(make-id path)}"
                =hx-swap  "outerHTML"
                =hx-confirm  "Are you sure you want to edit the perms of {(spud path)}?"
                ;input(type "hidden", name "get", value "/grub/tree{(spud path)}");
                ;input(type "hidden", name "path", value "{(spud path)}");
                ;div
                  ;label
                    =for  "make"
                    =class  "block text-gray-700 font-semibold mb-1"
                    ; Make
                  ==
                  ;textarea
                    =id  "make"
                    =name  "make"
                    =rows  "4"
                    =class  "w-full p-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                    =placeholder  "Enter paths separated by commas: /path/one,/path/two,/path/three"
                    ;+  ;/
                    %-  trip
                    %+  rap  3
                    %+  join  ','
                    (turn ?~(perm ~ ~(tap in make.u.perm)) spat)
                  ==
                ==
                ;div
                  ;label
                    =for  "poke"
                    =class  "block text-gray-700 font-semibold mb-1"
                    ; Poke
                  ==
                  ;textarea
                    =id  "poke"
                    =name  "poke"
                    =rows  "4"
                    =class  "w-full p-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                    =placeholder  "Enter paths separated by commas: /path/one,/path/two,/path/three"
                    ;+  ;/
                    %-  trip
                    %+  rap  3
                    %+  join  ','
                    (turn ?~(perm ~ ~(tap in poke.u.perm)) spat)
                  ==
                ==
                ;div
                  ;label
                    =for  "peek"
                    =class  "block text-gray-700 font-semibold mb-1"
                    ; Peek
                  ==
                  ;textarea
                    =id  "peek"
                    =name  "peek"
                    =rows  "4"
                    =class  "w-full p-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                    =placeholder  "Enter paths separated by commas: /path/one,/path/two,/path/three"
                    ;+  ;/
                    %-  trip
                    %+  rap  3
                    %+  join  ','
                    (turn ?~(perm ~ ~(tap in peek.u.perm)) spat)
                  ==
                ==
                ;div(class "flex items-center justify-center mt-6")
                  ;button(type "submit", class "bg-blue-500 text-white font-bold py-2 px-6 rounded-lg hover:bg-blue-600 transition duration-300 ease-in-out")
                    ;+  ;/
                    ?~  perm
                      "Give Perms"
                    "Edit Perms"
                  ==
                ==
              ==
            ==
          ==
        ==
        ;col-split(id "grub-view", class "w-full flex-grow flex flex-col")
          ;div
            =slot  "top"
            =height  "4em"
            =class  "flex justify-center p-1 border-b border-gray-300 bg-gray-50"
            ;button
              =id  "viewTab"
              =class  "tab-button px-4 py-2 text-gray-700 font-semibold focus:outline-none transition duration-300 border-b-2 border-blue-500 text-blue-500"
              =onclick  "$(this).addClass('border-b-2 border-blue-500 text-blue-500').siblings().removeClass('border-b-2 border-blue-500 text-blue-500');"
              =hx-get  "/grub/view/both{(spud path)}"
              =hx-target  "#inner-display"
              =hx-swap  "innerHTML"
              =hx-trigger  "click, load"
              ; View
            ==
            ;button
              =id  "codeTab"
              =class  "tab-button px-4 py-2 text-gray-700 font-semibold focus:outline-none transition duration-300"
              =onclick  "$(this).addClass('border-b-2 border-blue-500 text-blue-500').siblings().removeClass('border-b-2 border-blue-500 text-blue-500');"
              =hx-get  "/grub/code{(spud path)}"
              =hx-target  "#inner-display"
              =hx-swap  "innerHTML"
              ; Code
            ==
            ;button
              =id  "conversionsTab"
              =class  "tab-button px-4 py-2 text-gray-700 font-semibold focus:outline-none transition duration-300"
              =onclick  "$(this).addClass('border-b-2 border-blue-500 text-blue-500').siblings().removeClass('border-b-2 border-blue-500 text-blue-500');"
              =hx-get  "/grub/gui/con{(spud path)}"
              =hx-target  "#inner-display"
              =hx-swap  "innerHTML"
              ; Conversions
            ==
          ==
          ;div
            =id  "inner-display"
            =slot  "bottom"
            =class  "h-full w-full flex flex-col bg-gray-100 items-center justify-center overflow-auto"
            ;
          ==
        ==
      ==
    ==
  ::
  ++  grub-code
    |=  =path
    =/  m  (charm ,manx)
    ^-  form:m
    ;<  =cone:g  bind:m  (peek path)
    =/  =grub:g  (need (~(get of cone) /))
    ;<  =stud:g  bind:m  (get-grub-stud path)
    %-  pure:m
    ^-  manx
    ;div(class "w-full h-full mx-auto bg-white shadow-lg rounded-lg flex flex-col overflow-auto")
      ;div(class "flex justify-center p-1 border-b border-gray-300 bg-gray-50")
        ;button
          =id  "codeTab"
          =class  "tab-button px-4 py-2 text-gray-700 font-semibold focus:outline-none transition duration-300 border-b-2 border-blue-500 text-blue-500"
          =onclick  "$('#grub-path').show(); $('#stud-path').hide(); $(this).addClass('border-b-2 border-blue-500 text-blue-500').siblings().removeClass('border-b-2 border-blue-500 text-blue-500');"
          =hx-get  "/grub/tree/lib/{?:(?=(%base -.grub) "base{(spud base.grub)}" "stem{(spud stem.grub)}")}"
          =hx-target  "#code-display"
          =hx-swap  "innerHTML"
          =hx-trigger  "click, load"
          ;+  ;/
          ?:  ?=(%base -.grub)
            "Base"
          "Stem"
        ==
        ;button
          =id  "viewTab"
          =class  "tab-button px-4 py-2 text-gray-700 font-semibold focus:outline-none transition duration-300"
          =onclick  "$('#stud-path').show(); $('#grub-path').hide(); $(this).addClass('border-b-2 border-blue-500 text-blue-500').siblings().removeClass('border-b-2 border-blue-500 text-blue-500');"
          =hx-get  "/grub/tree/lib/stud{(spud stud)}"
          =hx-target  "#code-display"
          =hx-swap  "innerHTML"
          ; Stud
        ==
      ==
      ;div#stud-path.hidden.w-full.p-1.bg-gray-100.rounded-lg.shadow-md.text-center.text-gray-700.text-lg.font-semibold
        ; {(spud stud)}
      ==
      ;div#grub-path.w-full.p-1.bg-gray-100.rounded-lg.shadow-md.text-center.text-gray-700.text-lg.font-semibold
        ;+  ;/
        ?:  ?=(%base -.grub)
          (spud base.grub)
        (spud stem.grub)
      ==
      ;div#code-display.h-full.w-full.flex.flex-col.bg-gray-100.items-center.justify-center.overflow-auto;
    ==
  ::
  ++  grub-gui-con
    |=  =path
    =/  m  (charm ,manx)
    ^-  form:m
    ;<  =cone:g  bind:m  (peek path)
    =/  =grub:g  (need (~(get of cone) /))
    ;<  =stud:g  bind:m  (get-grub-stud path)
    %-  pure:m
    ^-  manx
    ;div(class "w-full h-full mx-auto bg-white shadow-lg rounded-lg flex flex-col")
      ;div(class "flex justify-center p-1 border-b border-gray-300 bg-gray-50")
        ;button
          =id  "codeTab"
          =class  "tab-button px-4 py-2 text-gray-700 font-semibold focus:outline-none transition duration-300 border-b-2 border-blue-500 text-blue-500"
          =onclick  "$('#cone-path').show().siblings().hide(); $(this).addClass('border-b-2 border-blue-500 text-blue-500').siblings().removeClass('border-b-2 border-blue-500 text-blue-500');"
          =hx-get  "/grub/tree/lib/gui/con/{?:(?=(%base -.grub) "base{(spud base.grub)}" "stem{(spud stem.grub)}")}"
          =hx-target  "#gui-con-display"
          =hx-swap  "innerHTML"
          =hx-trigger  "click, load"
          ; Cone
        ==
        ;button
          =id  "viewTab"
          =class  "tab-button px-4 py-2 text-gray-700 font-semibold focus:outline-none transition duration-300"
          =onclick  "$('#stud-path').show().siblings().hide(); $(this).addClass('border-b-2 border-blue-500 text-blue-500').siblings().removeClass('border-b-2 border-blue-500 text-blue-500');"
          =hx-get  "/grub/tree/lib/gui/con/stud{(spud stud)}"
          =hx-target  "#gui-con-display"
          =hx-swap  "innerHTML"
          ; Stud
        ==
        ;button
          =id  "viewTab"
          =class  "tab-button px-4 py-2 text-gray-700 font-semibold focus:outline-none transition duration-300"
          =onclick  "$('#mime-path').show().siblings().hide(); $(this).addClass('border-b-2 border-blue-500 text-blue-500').siblings().removeClass('border-b-2 border-blue-500 text-blue-500');"
          =hx-get  "/grub/tree/lib/gui/con/mime{(spud stud)}"
          =hx-target  "#gui-con-display"
          =hx-swap  "innerHTML"
          ; Mime
        ==
        ;*  ?.  ?=(%base -.grub)
              ~
            ;=
              ;button
                =id  "codeTab"
                =class  "tab-button px-4 py-2 text-gray-700 font-semibold focus:outline-none transition duration-300"
                =onclick  "$('#cone-path').show().siblings().hide(); $(this).addClass('border-b-2 border-blue-500 text-blue-500').siblings().removeClass('border-b-2 border-blue-500 text-blue-500');"
                =hx-get  "/grub/tree/lib/gui/con/poke{(spud base.grub)}"
                =hx-target  "#gui-con-display"
                =hx-swap  "innerHTML"
                ; Poke
              ==
              ;button
                =id  "codeTab"
                =class  "tab-button px-4 py-2 text-gray-700 font-semibold focus:outline-none transition duration-300"
                =onclick  "$('#cone-path').show().siblings().hide(); $(this).addClass('border-b-2 border-blue-500 text-blue-500').siblings().removeClass('border-b-2 border-blue-500 text-blue-500');"
                =hx-get  "/grub/tree/lib/gui/con/bump{(spud base.grub)}"
                =hx-target  "#gui-con-display"
                =hx-swap  "innerHTML"
                ; Bump
              ==
            ==
      ==
      ;div.flex.flex-col.w-full.p-1.bg-gray-100.rounded-lg.shadow-md.text-center.text-gray-700.text-lg.font-semibold
        ;div#stud-path.hidden: {(spud stud)}
        ;div#cone-path
          ;+  ;/
          ?:  ?=(%base -.grub)
            (spud base.grub)
          (spud stem.grub)
        ==
      ==
      ;div#gui-con-display.h-full.w-full.flex.flex-col.bg-gray-100.items-center.justify-center.overflow-auto;
    ==
  ::
  ++  grub-view-stud
    |=  =path
    =/  m  (charm ,manx)
    ^-  form:m
    ;<  =cone:g  bind:m  (peek path)
    =/  =grub:g  (need (~(get of cone) /))
    ;<  =stud:g  bind:m  (get-grub-stud path)
    ;<  s=(unit grub:g)  bind:m
      (peek-root-soft (weld /bin/gui/con/stud stud))
    %-  pure:m
    ?~  s
      =/  res  (grab-data-soft grub)
      ?:  ?=(%& -.res)
        (vase-to-manx p.res)
      ;div(class "bg-red-100 p-1 rounded-lg w-full h-full overflow-y-auto")
        ;code:"*{(render-tang-to-marl 80 p.res)}"
      ==
    =/  res
      %-  mule  |.
      %.  (grab-data grub)
      !<($-(^vase manx) (grab-data u.s))
    ?:  ?=(%& -.res)
      p.res
    ;div(class "bg-red-100 p-1 rounded-lg w-full h-full overflow-y-auto")
      ;code:"*{(render-tang-to-marl 80 p.res)}"
    ==
  ::
  ++  grub-view-cone
    |=  =path
    =/  m  (charm ,manx)
    ^-  form:m
    ;<  =cone:g  bind:m  (peek path)
    =/  =grub:g  (need (~(get of cone) /))
    =/  con-path=^path
      ?-  -.grub
        %base  (weld /bin/gui/con/base base.grub)
        %stem  (weld /bin/gui/con/stem stem.grub)
      ==
    ;<  c=(unit grub:g)  bind:m  (peek-root-soft con-path)
    %-  pure:m
    ?~  c
      =/  res  (grab-data-soft grub)
      ?:  ?=(%& -.res)
        (vase-to-manx p.res)
      ;div(class "bg-red-100 p-1 rounded-lg w-full h-full overflow-y-auto")
        ;code:"*{(render-tang-to-marl 80 p.res)}"
      ==
    =/  res
      %-  mule  |.
      %.  [path cone]
      !<($-([^path cone:g] manx) (grab-data u.c))
    ?:  ?=(%& -.res)
      p.res
    ;div(class "bg-red-100 p-1 rounded-lg w-full h-full overflow-y-auto")
      ;code:"*{(render-tang-to-marl 80 p.res)}"
    ==
  ::
  ++  grub-view-sour
    |=  =path
    =/  m  (charm ,manx)
    ^-  form:m
    ;<  =grub:g  bind:m  (peek-root path)
    ?>  ?=(%stem -.grub)
    %-  pure:m
    ;div.flex-grow.flex.flex-col.items-center.justify-center
      ;*  %+  turn  ~(tap in sour.grub)
          |=  [=^path *]
          ;div: {(spud path)}
    ==
  ::
  ++  grub-view-both
    |=  =path
    =/  m  (charm ,manx)
    ^-  form:m
    ;<  =grub:g  bind:m  (peek-root path)
    %-  pure:m
    ;div(class "w-full h-full mx-auto bg-white shadow-lg rounded-lg flex flex-col")
      ;div(class "flex justify-center p-1 border-b border-gray-300 bg-gray-50")
        ;button
          =id  "coneTab"
          =class  "tab-button px-4 py-2 text-gray-700 font-semibold focus:outline-none transition duration-300 border-b-2 border-blue-500 text-blue-500"
          =onclick  "$(this).addClass('border-b-2 border-blue-500 text-blue-500').siblings().removeClass('border-b-2 border-blue-500 text-blue-500');"
          =hx-get  "/grub/view/cone{(spud path)}"
          =hx-target  "#view-display"
          =hx-swap  "innerHTML"
          =hx-trigger  "click, load"
          ; Cone
        ==
        ;button
          =id  "studTab"
          =class  "tab-button px-4 py-2 text-gray-700 font-semibold focus:outline-none transition duration-300"
          =onclick  "$(this).addClass('border-b-2 border-blue-500 text-blue-500').siblings().removeClass('border-b-2 border-blue-500 text-blue-500');"
          =hx-get  "/grub/view/stud{(spud path)}"
          =hx-target  "#view-display"
          =hx-swap  "innerHTML"
          ; Stud
        ==
        ;*  ?.  ?=(%stem -.grub)  ~
            ;=
              ;button
                =id  "studTab"
                =class  "tab-button px-4 py-2 text-gray-700 font-semibold focus:outline-none transition duration-300"
                =onclick  "$(this).addClass('border-b-2 border-blue-500 text-blue-500').siblings().removeClass('border-b-2 border-blue-500 text-blue-500');"
                =hx-get  "/grub/view/sour{(spud path)}"
                =hx-target  "#view-display"
                =hx-swap  "innerHTML"
                ; Sources
              ==
            ==
      ==
      ;div#view-display.h-full.w-full.flex.flex-col.bg-gray-100.items-center.justify-center.overflow-auto;
    ==
  ::
  ++  main-page
    |=  =cone:g
    ^-  manx
    %-  wrap-manx
    ;div.p-4.flex.flex-col.justify-center.items-center.min-h-screen.bg-gray-100
      ;div
        ;*  %+  turn  ~(tap of cone)
            |=  [=path *]
            ;p: {(spud path)}
      ==
    ==
  ::
  ++  grub-tree-lib
    |=  here=path
    =/  m  (charm ,manx)
    ^-  form:m
    ;<  lib=(unit grub:g)  bind:m  (peek-root-soft %lib here)
    ?~  lib
      (pure:m (no-lib here))
    =+  !<([code=@t *] (grab-data u.lib))
    ;<  grub=(unit grub:g)  bind:m  (peek-root-soft %bin here)
    ;<  perm=(unit perm:g)  bind:m  (get-perm %lib here)
    ~&  >>  ["perm in +grub-tree-lib:" perm]
    (pure:m (lib-page here code grub perm))
  ::
  ++  no-lib
    |=  =path
    ^-  manx
    =/  template=tape
      ?+  path  ""
        [%base *]  (trip base-template:x)
        [%stem *]  (trip stem-template:x)
        [%gui %con %base *]  (trip gui-con-base-template:x)
        [%gui %con %stem *]  (trip gui-con-stem-template:x)
        [%gui %con %stud *]  (trip gui-con-stud-template:x)
        [%gui %con %mime *]  (trip gui-con-mime-template:x)
        [%gui %con %poke *]  (trip gui-con-poke-template:x)
        [%gui %con %bump *]  (trip gui-con-bump-template:x)
      ==
    ;div(id (make-id %lib path))
      ;form
        =hx-post  "/grub/make/lib"
        =hx-trigger  "submit"
        =hx-swap  "outerHTML"
        =hx-target  "#{(make-id %lib path)}"
        ;input(type "hidden", name "get", value "/grub/tree/lib{(spud path)}");
        ;input(type "hidden", name "path", value "{(spud path)}");
        ;input(type "hidden", name "code", value "{template}");
        ;button
          =type   "submit"
          =class  "mx-1 my-2 px-4 py-2 rounded-lg bg-blue-500 hover:bg-blue-200"
          ; make
        ==
      ==
    ==
  ::
  ++  lib-page
    |=  [=path code=@t grub=(unit grub:g) perm=(unit perm:g)]
    ^-  manx
    ~&  >>  ["perm in +lib-page:" perm]
    =/  data=(each vase tang)
      ?~  grub
        |+~[leaf+"no bin; bad dependency"]
      (grab-data-soft u.grub)
    ;div.w-full.flex-grow.flex.flex-col.overflow-auto
      =id  (make-id [%lib path])
      ;div.flex.flex-row.items-center.justify-center.text-white.font-mono.font-bold
        ;form
          =hx-post  "/grub/oust/lib"
          =hx-trigger  "submit"
          =hx-swap  "outerHTML"
          =hx-target  "#{(make-id %lib path)}"
          =hx-confirm  "Are you sure you want to oust lib {(spud path)}?"
          ;input(type "hidden", name "get", value "/grub/tree/lib{(spud path)}");
          ;input(type "hidden", name "path", value "{(spud path)}");
          ;button
            =type   "submit"
            =class  "mx-1 my-2 px-4 py-2 rounded-lg bg-blue-500 hover:bg-blue-200"
            ; oust
          ==
        ==
        ;form
          =hx-post  "/grub/cull/lib"
          =hx-trigger  "submit"
          =hx-swap  "outerHTML"
          =hx-target  "#{(make-id %lib path)}"
          =hx-confirm  "Are you sure you want to cull lib {(spud path)}?"
          ;input(type "hidden", name "get", value "/grub/tree/lib{(spud path)}");
          ;input(type "hidden", name "path", value "{(spud path)}");
          ;button
            =type   "submit"
            =class  "mx-1 my-2 px-4 py-2 rounded-lg bg-blue-500 hover:bg-blue-200"
            ; cull
          ==
        ==
        ;form
          ;div
            =class  "cursor-pointer mx-1 my-2 px-4 py-2 rounded-lg bg-blue-500 hover:bg-blue-200"
            =onclick  "$('#sandbox').show(); $('#lib-view').hide();"
            ; sand
          ==
        ==
      ==
      ;div
        =id  "lib-view"
        =class  "w-full p-4 flex-grow flex flex-row justify-center items-center bg-gray-100 overflow-auto"
        ;+  (code-result data)
        ;+  (textarea path (trip code))
      ==
      ;div#sandbox.hidden.flex-grow.flex.flex-col.w-full.bg-gray-100.overflow-hidden
        ;div.p-2.w-full.flex.justify-between.bg-gray-200
          ;button
            =class  "p-2 rounded-full hover:bg-gray-400 text-white font-mono font-bold"
            =onclick  "$('#lib-view').show(); $('#sandbox').hide();"
            ;+  (make:fi %arrow-left)
          ==
        ==
        ;div(class "h-full flex-grow flex items-center justify-center")
          ;div.m-4.flex-grow.flex.flex-col
            ;form
              =class  "space-y-4"
              =hx-post  "/grub/sand/sysc"
              =hx-indicator  "#loading-indicator"
              =hx-target  "#{(make-id %lib path)}"
              =hx-swap  "outerHTML"
              =hx-confirm  "Are you sure you want to give system access to {(spud %lib path)}?"
              ;input(type "hidden", name "get", value "/grub/tree{(spud %lib path)}");
              ;input(type "hidden", name "path", value "{(spud %lib path)}");
              ;div(class "flex items-center justify-center mt-6")
                ;+  ?~  perm
                    ;div(class "text-center text-3xl font-bold text-gray-800 p-4 bg-gray-200 rounded-lg shadow-lg")
                      ; Full System Access
                    ==
                    ;button(type "submit", class "bg-blue-500 text-white font-bold py-2 px-6 rounded-lg hover:bg-blue-600 transition duration-300 ease-in-out")
                      ; Give System Access
                    ==
              ==
            ==
            ;form
              =class  "space-y-4"
              =hx-post  "/grub/sand/grub"
              =hx-indicator  "#loading-indicator"
              =hx-target  "#{(make-id %lib path)}"
              =hx-swap  "outerHTML"
              =hx-confirm  "Are you sure you want to edit the perms of {(spud %lib path)}?"
              ;input(type "hidden", name "get", value "/grub/tree{(spud %lib path)}");
              ;input(type "hidden", name "path", value "{(spud %lib path)}");
              ;div
                ;label
                  =for  "make"
                  =class  "block text-gray-700 font-semibold mb-1"
                  ; Make
                ==
                ;textarea
                  =id  "make"
                  =name  "make"
                  =rows  "4"
                  =class  "w-full p-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                  =placeholder  "Enter paths separated by commas: /path/one,/path/two,/path/three"
                  ;+  ;/
                  %-  trip
                  %+  rap  3
                  %+  join  ','
                  (turn ?~(perm ~ ~(tap in make.u.perm)) spat)
                ==
              ==
              ;div
                ;label
                  =for  "poke"
                  =class  "block text-gray-700 font-semibold mb-1"
                  ; Poke
                ==
                ;textarea
                  =id  "poke"
                  =name  "poke"
                  =rows  "4"
                  =class  "w-full p-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                  =placeholder  "Enter paths separated by commas: /path/one,/path/two,/path/three"
                  ;+  ;/
                  %-  trip
                  %+  rap  3
                  %+  join  ','
                  (turn ?~(perm ~ ~(tap in poke.u.perm)) spat)
                ==
              ==
              ;div
                ;label
                  =for  "peek"
                  =class  "block text-gray-700 font-semibold mb-1"
                  ; Peek
                ==
                ;textarea
                  =id  "peek"
                  =name  "peek"
                  =rows  "4"
                  =class  "w-full p-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                  =placeholder  "Enter paths separated by commas: /path/one,/path/two,/path/three"
                  ;+  ;/
                  %-  trip
                  %+  rap  3
                  %+  join  ','
                  (turn ?~(perm ~ ~(tap in peek.u.perm)) spat)
                ==
              ==
              ;div(class "flex items-center justify-center mt-6")
                ;button(type "submit", class "bg-blue-500 text-white font-bold py-2 px-6 rounded-lg hover:bg-blue-600 transition duration-300 ease-in-out")
                  ;+  ;/
                  ?~  perm
                    "Give Perms"
                  "Edit Perms"
                ==
              ==
            ==
          ==
        ==
      ==
    ==
  ::
  ++  code-result
    |=  data=(each vase tang)
    ^-  manx
    =/  color=tape
      ?:(?=(%| -.data) "red" "green")
    ;div
      =class  "flex-1 flex flex-col w-full bg-{color}-200 p-8 rounded-lg shadow-lg h-full"
      ;div(class "text-xl font-bold mb-4 text-center text-{color}-700")
        ; {?:(?=(%| -.data) "crashed" "compiled")}
      ==
      ;*  ?:  ?=(%| -.data)
            ;=
              ;div(class "bg-{color}-100 p-4 rounded-lg w-full h-full overflow-y-auto")
                ;code:"*{(scag 100 (render-tang-to-marl 80 p.data))}"
              ==
            ==
          ;=
            ;div(class "bg-{color}-100 p-4 rounded-lg w-full h-full overflow-y-auto")
              ;code:"*{(scag 100 (render-tang-to-marl 80 (sell p.data) ~))}"
            ==
          ==
    ==
  ::
  ++  textarea
    |=  [=path contents=tape]
    ^-  manx
    ;div(class "flex-1 flex flex-col w-full bg-white p-8 rounded-lg shadow-lg h-full")
      ;form(class "flex-grow flex flex-col")
        =hx-post  "/grub/make/lib"
        =hx-trigger  "submit"
        =hx-swap  "outerHTML"
        =hx-target  "#{(make-id %lib path)}"
        ;label
          =for  "textInput"
          =class  "block text-gray-700 font-bold mb-2"
          ; Enter your text
        ==
        ;input(type "hidden", name "get", value "/grub/tree/lib{(spud path)}");
        ;input(type "hidden", name "path", value "{(spud path)}");
        ;textarea
          =id  "code"
          =name  "code"
          =rows  "6"
          =cols  "50"
          =class  "font-mono flex-grow h-full mb-3 w-full p-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          =placeholder  "Type something..."
          ; {contents}
        ==
        ;br;
        ;button
          =type   "submit"
          =class  "w-full bg-blue-500 text-white font-bold py-2 px-4 rounded-lg hover:bg-blue-600 transition duration-300 ease-in-out"
          ; Submit
        ==
      ==
    ==
  ::
  ++  get-dom-manx
    |=  =path
    =/  m  (charm ,manx)
    ;<  =cone  bind:m  (peek /gui/boot/dom)
    ?~  grub=(~(get of cone) path)
      %-  pure:m
      ;div: No grub at this path.
    =/  res  (mule |.(!<(manx (grab-data u.grub))))
    %-  pure:m
    ?-  -.res
      %&  p.res
      %|  ;div: Bad manx.
    ==
  ::
  ++  counter-page
    |=  [now=@da counter=manx is-even=manx parity=manx]
    ^-  manx
    ;html(lang "en")
      ;head
        ;meta(charset "UTF-8");
        ;meta(name "viewport", content "width=device-width, initial-scale=1.0");
        ;title: Counter App
        ;script(src "https://cdn.tailwindcss.com");
        ;script(src "https://unpkg.com/htmx.org@1.9.4");
      ==
      ;body.p-4.flex.flex-col.justify-center.items-center.min-h-screen.bg-gray-100
        ;+  counter
        ;+  is-even
        ;+  parity
      ==
    ==
  --
--
