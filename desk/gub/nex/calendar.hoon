::  calendar: events over the rules library
::
::  /calendar.calendar   portable intent: config + events (poke CRUD)
::  /order.cal-cache     derived index, reinflated on calendar news
::  /main.sig            binds /grubbery/cal
::  /requests            window.json + events.json endpoints
::
/<  cal    /lib/cal.hoon
/<  rules  /lib/rules.hoon
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'calendar.calendar'] [[/ %calendar] fresh-calendar:cal]]
          [%fall %& [/ %'order.cal-cache'] [[/ %cal-cache] *cache:cal]]
          [%fall %| /requests empty-dir:loader]
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
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%calendar main: failed")
        ;<  ~  bind:m  (bind-http:io [~ /grubbery/cal])
        (http-dispatch:io %cal)
          ::
          ::  /calendar.calendar: poke CRUD on events
          ::
          [~ %'calendar.calendar']
        ;<  ~  bind:m  (rise-wait:io prod "%calendar events: failed")
        |-
        ;<  [* =sage:tarball]  bind:m  take-poke-from:io
        =/  jon=json  (fall (mole |.(!<(json q.sage))) *json)
        ?.  ?=(%o -.jon)  $
        =/  act=@t  (gs jon 'action')
        ;<  c=calendar:cal  bind:m  (get-state-as:io ,calendar:cal)
        ?:  =('del-event' act)
          =/  id=@ta  (crip (trip (gs jon 'id')))
          ?:  =('' id)  $
          ;<  ~  bind:m  (replace:io c(events (~(del by events.c) id)))
          $
        ?.  =('add-event' act)  $
        =/  ev=(unit event:cal)  (parse-event jon)
        ?~  ev
          ~&  >>>  "%calendar: bad add-event"
          $
        ;<  eny=@uvJ  bind:m  get-entropy:io
        =/  id=@ta  (scot %uv (end [3 8] eny))
        ;<  ~  bind:m  (replace:io c(events (~(put by events.c) id u.ev)))
        $
          ::
          ::  /order.cal-cache: reinflate on calendar news
          ::
          [~ %'order.cal-cache']
        ;<  ~  bind:m  (rise-wait:io prod "%calendar cache: failed")
        =/  road  (cord-to-road:tarball './calendar.calendar')
        ;<  *  bind:m  (keep:io /cal road ~)
        |-
        ;<  =view:nexus  bind:m  (peek:io road ~)
        ?.  ?=([%file *] view)
          ;<  *  bind:m  (take-news:io /cal)
          $
        =/  c=calendar:cal
          %+  fall
            (mole |.(!<(calendar:cal (need-vase:tarball sang.view))))
          fresh-calendar:cal
        =/  rails=(list rail:tarball)
          %~  tap  in
          %-  sy
          (turn ~(tap by events.c) |=([@ta e=event:cal] kind.rule.e))
        ;<  kinds=(map rail:tarball kind:rules)  bind:m  (resolve-kinds rails)
        ;<  now=@da  bind:m  get-time:io
        =/  thru=@da  (add now horizon.c)
        =/  o=order:cal  (inflate:cal events.c kinds thru)
        ;<  ~  bind:m  (replace:io `cache:cal`[thru o])
        ;<  *  bind:m  (take-news:io /cal)
        $
          ::
          ::  /requests: window.json, events.json
          ::
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%calendar request: failed")
        =/  eyre-id=@ta  name.rail
        ;<  [src=@p req=inbound-request:eyre]  bind:m
          (get-state-as:io ,[src=@p inbound-request:eyre])
        ;<  our=@p  bind:m  get-our:io
        ?.  =(src our)
          ;<  ~  bind:m  (send-simple:srv eyre-id [[403 ~] `(as-octs:mimes:html 'Forbidden')])
          (pure:m ~)
        =/  [site=path args=quay:eyre]  (parse-url:http-utils url.request.req)
        =/  suffix=path  (slag (lent `path`/grubbery/cal) site)
        ?:  ?=([%'window.json' ~] suffix)
          =/  from=(unit @da)  (ms-arg args 'from')
          =/  to=(unit @da)    (ms-arg args 'to')
          ?:  |(?=(~ from) ?=(~ to))
            ;<  ~  bind:m  (send-simple:srv eyre-id [[400 ~] `(as-octs:mimes:html 'need from/to (unix ms)')])
            (pure:m ~)
          ;<  cache-view=view:nexus  bind:m
            (peek:io (cord-to-road:tarball '../order.cal-cache') ~)
          ;<  cal-view=view:nexus  bind:m
            (peek:io (cord-to-road:tarball '../calendar.calendar') ~)
          =/  o=order:cal
            ?.  ?=([%file *] cache-view)  ~
            order:(fall (mole |.(!<(cache:cal (need-vase:tarball sang.cache-view)))) *cache:cal)
          =/  c=calendar:cal
            ?.  ?=([%file *] cal-view)  fresh-calendar:cal
            %+  fall
              (mole |.(!<(calendar:cal (need-vase:tarball sang.cal-view))))
            fresh-calendar:cal
          =/  refs=(list ref:cal)  ~(tap in (window:cal o u.from u.to))
          =/  rows=json
            :-  %a
            %+  murn  refs
            |=  r=ref:cal
            ^-  (unit json)
            =/  ev=(unit event:cal)  (~(get by events.c) eid.r)
            ?~  ev  ~
            :-  ~
            %-  pairs:enjs:format
            :~  ['id' s+eid.r]
                ['idx' (numb:enjs:format idx.r)]
                ['name' s+name.meta.u.ev]
                ['note' s+note.meta.u.ev]
                ['color' s+color.meta.u.ev]
                ['l' (numb:enjs:format (da-to-ms l.span.r))]
                ['r' (numb:enjs:format (da-to-ms r.span.r))]
            ==
          (send-json eyre-id rows)
        ?:  ?=([%'events.json' ~] suffix)
          ;<  cal-view=view:nexus  bind:m
            (peek:io (cord-to-road:tarball '../calendar.calendar') ~)
          =/  c=calendar:cal
            ?.  ?=([%file *] cal-view)  fresh-calendar:cal
            %+  fall
              (mole |.(!<(calendar:cal (need-vase:tarball sang.cal-view))))
            fresh-calendar:cal
          =/  rows=json
            :-  %a
            %+  turn  ~(tap by events.c)
            |=  [id=@ta e=event:cal]
            ^-  json
            %-  pairs:enjs:format
            :~  ['id' s+id]
                ['name' s+name.meta.e]
                ['color' s+color.meta.e]
                ['kind' s+name.kind.rule.e]
            ==
          (send-json eyre-id rows)
        ::  default: serve the calendar page
        ;<  here=rail:tarball  bind:m  get-here-abs:io
        =/  ball=tape
          %-  zing
          %+  join  "/"
          ^-  (list tape)
          (turn (snip path.here) trip)
        =/  page=@t  (crip (en-xml:html (cal-page ball)))
        ;<  ~  bind:m
          (send-simple:srv eyre-id [[200 ['content-type' 'text/html'] ~] `(as-octs:mimes:html page)])
        (pure:m ~)
      ==
    --
|%
++  srv  ~(. http-res:io [%| 1 %& ~ %'main.sig'])
::
++  cal-page
  |=  ball=tape
  ^-  manx
  ;html
    ;head
      ;title: calendar
      ;meta(charset "utf-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;style
        ;+  ;/  style-text
      ==
    ==
    ;body
      ;div#app
        ;div#header
          ;div#nav
            ;button#prev.nav-btn: <
            ;button#today.nav-btn: today
            ;button#next.nav-btn: >
          ==
          ;span#month-label;
          ;button#add-btn.nav-btn: + event
        ==
        ;div#dow-row;
        ;div#grid;
        ;div#modal-back
          ;div#modal
            ;div#modal-header
              ;span: New event
              ;button#modal-close.nav-btn: close
            ==
            ;label.f: name
            ;input#f-name(type "text");
            ;label.f: kind
            ;select#f-kind
              ;option(value "once"): once
              ;option(value "daily"): daily
              ;option(value "weekly", selected ""): weekly
              ;option(value "monthly"): monthly
              ;option(value "monthly-nth"): monthly-nth
              ;option(value "yearly"): yearly
              ;option(value "every"): every
            ==
            ;label.f: start date
            ;input#f-date(type "date");
            ;label.f.tf: time
            ;input#f-time(type "time", value "09:00");
            ;label.f.wf: weekdays
            ;div#f-days.wf;
            ;label.f.mf: day of month
            ;input#f-day(type "number", min "1", max "31", value "1");
            ;label.f.nf: ordinal
            ;select#f-ord
              ;option(value "first"): first
              ;option(value "second"): second
              ;option(value "third"): third
              ;option(value "fourth"): fourth
              ;option(value "last"): last
            ==
            ;label.f.nf: weekday
            ;select#f-dow;
            ;label.f.yf: month
            ;input#f-month(type "number", min "1", max "12", value "1");
            ;label.f.ef: period (minutes)
            ;input#f-period(type "number", min "1", value "60");
            ;label.f: duration (minutes, 0 = instant)
            ;input#f-dur(type "number", min "0", value "60");
            ;label.f: timezone
            ;input#f-zone(type "text");
            ;label.f: color
            ;input#f-color(type "color", value "#4a6a8a");
            ;div#modal-foot
              ;span#f-status;
              ;button#f-save.nav-btn: save
            ==
          ==
        ==
      ==
      ;script
        ;+  ;/  (script-text ball)
      ==
    ==
  ==
::
++  style-text
  ^-  tape
  """
  * \{ margin: 0; padding: 0; box-sizing: border-box; }
  body \{ font-family: -apple-system, system-ui, sans-serif; background: #111; color: #eee; }
  #app \{ max-width: 1100px; margin: 0 auto; padding: 16px; display: flex; flex-direction: column; height: 100vh; height: 100dvh; }
  #header \{ display: flex; align-items: center; gap: 12px; padding-bottom: 12px; }
  #month-label \{ font-size: 18px; font-weight: 700; flex: 1; }
  #nav \{ display: flex; gap: 4px; }
  .nav-btn \{ font-size: 13px; padding: 6px 12px; border-radius: 6px; border: 1px solid #333; background: #1a1a1a; color: #ccc; cursor: pointer; }
  .nav-btn:hover \{ border-color: #555; color: #fff; }
  #dow-row \{ display: grid; grid-template-columns: repeat(7, 1fr); gap: 4px; padding-bottom: 4px; }
  .dow \{ font-size: 11px; color: #666; text-align: center; text-transform: uppercase; }
  #grid \{ display: grid; grid-template-columns: repeat(7, 1fr); grid-auto-rows: 1fr; gap: 4px; flex: 1; min-height: 0; }
  .cell \{ background: #181818; border: 1px solid #222; border-radius: 6px; padding: 4px; overflow: hidden; display: flex; flex-direction: column; gap: 2px; min-height: 0; }
  .cell.other \{ opacity: 0.35; }
  .cell.today \{ border-color: #2563eb; }
  .dnum \{ font-size: 11px; color: #888; }
  .chip \{ font-size: 11px; padding: 2px 6px; border-radius: 4px; color: #fff; cursor: pointer; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; flex-shrink: 0; }
  .chip:hover \{ filter: brightness(1.25); }
  #modal-back \{ display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.6); z-index: 100; }
  #modal-back.open \{ display: flex; align-items: center; justify-content: center; }
  #modal \{ background: #1a1a1a; border: 1px solid #333; border-radius: 10px; width: 92%; max-width: 380px; padding: 20px; max-height: 90vh; overflow-y: auto; }
  #modal-header \{ display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; }
  #modal-header span \{ font-size: 14px; font-weight: 600; }
  label.f \{ display: block; font-size: 11px; color: #888; margin: 10px 0 3px; }
  #modal input, #modal select \{ width: 100%; padding: 7px 9px; border-radius: 6px; border: 1px solid #333; background: #111; color: #eee; font-size: 13px; outline: none; }
  #modal input:focus, #modal select:focus \{ border-color: #2563eb; }
  #f-days \{ display: flex; gap: 4px; flex-wrap: wrap; }
  .day-tog \{ font-size: 11px; padding: 5px 8px; border-radius: 5px; border: 1px solid #333; background: #111; color: #888; cursor: pointer; user-select: none; }
  .day-tog.on \{ background: #2563eb; border-color: #2563eb; color: #fff; }
  #modal-foot \{ display: flex; justify-content: space-between; align-items: center; margin-top: 16px; }
  #f-status \{ font-size: 12px; color: #f87171; }
  @media (max-width: 600px) \{
    #app \{ padding: 8px; }
    .chip \{ font-size: 9px; padding: 1px 4px; }
    .dnum \{ font-size: 10px; }
  }
  """
::
++  script-text
  |=  ball=tape
  ^-  tape
  %+  weld
    "var API='/grubbery/api';var BALL='{ball}';var CAL='/grubbery/cal';\0a"
  """
  var cur = new Date(); cur.setDate(1); cur.setHours(0,0,0,0);
  var grid = document.getElementById('grid');
  var label = document.getElementById('month-label');
  var WD = ['mon','tue','wed','thu','fri','sat','sun'];
  var MN = ['January','February','March','April','May','June','July','August','September','October','November','December'];

  document.getElementById('dow-row').innerHTML =
    WD.map(function(d) \{ return '<div class="dow">' + d + '</div>'; }).join('');

  function gridRange() \{
    var s = new Date(cur);
    s.setDate(1 - ((s.getDay() + 6) % 7));
    var e = new Date(s);
    e.setDate(e.getDate() + 42);
    return [s, e];
  }

  function dayKey(d) \{
    return d.getFullYear() + '-' + d.getMonth() + '-' + d.getDate();
  }

  function load() \{
    var r = gridRange();
    label.textContent = MN[cur.getMonth()] + ' ' + cur.getFullYear();
    fetch(CAL + '/window.json?from=' + r[0].getTime() + '&to=' + r[1].getTime())
      .then(function(x) \{ return x.json(); })
      .then(render)
      .catch(function() \{ render([]); });
  }

  function render(rows) \{
    var byDay = \{};
    rows.forEach(function(ev) \{
      var d = new Date(ev.l);
      var k = dayKey(d);
      (byDay[k] = byDay[k] || []).push(ev);
    });
    var r = gridRange();
    var today = dayKey(new Date());
    grid.innerHTML = '';
    var d = new Date(r[0]);
    for (var i = 0; i < 42; i++) \{
      var cell = document.createElement('div');
      cell.className = 'cell' + (d.getMonth() !== cur.getMonth() ? ' other' : '') +
        (dayKey(d) === today ? ' today' : '');
      var num = document.createElement('div');
      num.className = 'dnum';
      num.textContent = d.getDate();
      cell.appendChild(num);
      var evs = (byDay[dayKey(d)] || []).sort(function(a, b) \{ return a.l - b.l; });
      evs.forEach(function(ev) \{
        var chip = document.createElement('div');
        chip.className = 'chip';
        chip.style.background = ev.color || '#4a6a8a';
        var t = new Date(ev.l);
        var hh = ('0' + t.getHours()).slice(-2) + ':' + ('0' + t.getMinutes()).slice(-2);
        chip.textContent = hh + ' ' + ev.name;
        chip.title = ev.name + (ev.note ? ' — ' + ev.note : '');
        chip.onclick = function() \{
          if (!confirm('Delete "' + ev.name + '" (whole series)?')) return;
          fetch(API + '/poke/' + BALL + '/calendar.calendar?blot=/json', \{
            method: 'POST',
            headers: \{'Content-Type': 'application/json'},
            body: JSON.stringify(\{action: 'del-event', id: ev.id})
          }).then(function() \{ setTimeout(load, 400); });
        };
        cell.appendChild(chip);
      });
      grid.appendChild(cell);
      d.setDate(d.getDate() + 1);
    }
  }

  document.getElementById('prev').onclick = function() \{ cur.setMonth(cur.getMonth() - 1); load(); };
  document.getElementById('next').onclick = function() \{ cur.setMonth(cur.getMonth() + 1); load(); };
  document.getElementById('today').onclick = function() \{ cur = new Date(); cur.setDate(1); cur.setHours(0,0,0,0); load(); };

  // modal
  var back = document.getElementById('modal-back');
  var kindSel = document.getElementById('f-kind');
  var dowSel = document.getElementById('f-dow');
  var daysDiv = document.getElementById('f-days');
  WD.forEach(function(d) \{
    var o = document.createElement('option');
    o.value = d; o.textContent = d;
    dowSel.appendChild(o);
    var t = document.createElement('div');
    t.className = 'day-tog';
    t.textContent = d;
    t.dataset.d = d;
    t.onclick = function() \{ t.classList.toggle('on'); };
    daysDiv.appendChild(t);
  });
  document.getElementById('f-zone').value =
    (Intl.DateTimeFormat().resolvedOptions().timeZone || '');

  function syncFields() \{
    var k = kindSel.value;
    var show = \{
      tf: k !== 'once' && k !== 'every',
      wf: k === 'weekly',
      mf: k === 'monthly' || k === 'yearly',
      nf: k === 'monthly-nth',
      yf: k === 'yearly',
      ef: k === 'every'
    };
    ['tf','wf','mf','nf','yf','ef'].forEach(function(c) \{
      document.querySelectorAll('.' + c).forEach(function(el) \{
        el.style.display = show[c] ? '' : 'none';
      });
    });
  }
  kindSel.onchange = syncFields;

  document.getElementById('add-btn').onclick = function() \{
    document.getElementById('f-date').value = new Date().toISOString().slice(0, 10);
    syncFields();
    back.classList.add('open');
  };
  document.getElementById('modal-close').onclick = function() \{ back.classList.remove('open'); };
  back.onclick = function(e) \{ if (e.target === back) back.classList.remove('open'); };

  document.getElementById('f-save').onclick = function() \{
    var st = document.getElementById('f-status');
    var name = document.getElementById('f-name').value.trim();
    var dv = document.getElementById('f-date').value;
    if (!name || !dv) \{ st.textContent = 'name and date required'; return; }
    var k = kindSel.value;
    var p = dv.split('-');
    var tv = (document.getElementById('f-time').value || '00:00').split(':');
    var startMs;
    if (k === 'once' || k === 'every') \{
      startMs = Date.UTC(+p[0], +p[1] - 1, +p[2], +tv[0], +tv[1]);
    } else \{
      startMs = Date.UTC(+p[0], +p[1] - 1, +p[2]);
    }
    var body = \{
      action: 'add-event',
      name: name,
      kind: k,
      start_ms: startMs,
      color: document.getElementById('f-color').value,
      note: ''
    };
    var zone = document.getElementById('f-zone').value.trim();
    if (zone) body.zone = zone;
    var dur = +document.getElementById('f-dur').value;
    if (dur > 0) body.dur_min = dur;
    if (k !== 'once' && k !== 'every') body.at_min = (+tv[0]) * 60 + (+tv[1]);
    if (k === 'weekly') \{
      var days = [].slice.call(daysDiv.querySelectorAll('.on')).map(function(t) \{ return t.dataset.d; });
      if (!days.length) \{ st.textContent = 'pick weekdays'; return; }
      body.days = days;
    }
    if (k === 'monthly') body.day = +document.getElementById('f-day').value;
    if (k === 'monthly-nth') \{ body.ord = document.getElementById('f-ord').value; body.day = dowSel.value; }
    if (k === 'yearly') \{ body.month = +document.getElementById('f-month').value; body.day = +document.getElementById('f-day').value; }
    if (k === 'every') body.period_min = +document.getElementById('f-period').value || 60;
    fetch(API + '/poke/' + BALL + '/calendar.calendar?blot=/json', \{
      method: 'POST',
      headers: \{'Content-Type': 'application/json'},
      body: JSON.stringify(body)
    }).then(function(r) \{
      if (!r.ok) \{ st.textContent = 'save failed'; return; }
      back.classList.remove('open');
      setTimeout(load, 400);
    });
  };

  load();
  """
::
++  gs
  |=  [jon=json k=@t]
  ^-  @t
  ?.  ?=(%o -.jon)  ''
  (fall (bind (~(get by p.jon) k) |=(=json ?>(?=(%s -.json) p.json))) '')
::
++  gn
  |=  [jon=json k=@t]
  ^-  (unit @ud)
  ?.  ?=(%o -.jon)  ~
  =/  j=(unit json)  (~(get by p.jon) k)
  ?~  j  ~
  ?.  ?=(%n -.u.j)  ~
  (rush p.u.j dem)
::
++  ms-to-da  |=(ms=@ud `@da`(add ~1970.1.1 (div (mul ms ~s1) 1.000)))
++  da-to-ms  |=(d=@da `@ud`(div (mul (sub d ~1970.1.1) 1.000) ~s1))
::
++  ms-arg
  |=  [args=quay:eyre k=@t]
  ^-  (unit @da)
  =/  v=(unit @t)  (get-key:kv:html-utils k args)
  ?~  v  ~
  (bind (rush u.v dem) ms-to-da)
::
++  send-json
  |=  [eyre-id=@ta =json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  bod=octs  (as-octs:mimes:html (en:json:html json))
  ;<  ~  bind:m
    (send-simple:srv eyre-id [[200 ['content-type' 'application/json'] ~] `bod])
  (pure:m ~)
::  +resolve-kinds: load kind gates from the code namespace
::
++  resolve-kinds
  |=  rails=(list rail:tarball)
  =/  m  (fiber:fiber:nexus ,(map rail:tarball kind:rules))
  ^-  form:m
  =|  out=(map rail:tarball kind:rules)
  |-
  ?~  rails  (pure:m out)
  =/  code-road=road:tarball
    &+&+[(weld /code path.i.rails) name.i.rails]
  ;<  code=(unit vase)  bind:m  (get-code:io code-road)
  ?~  code  $(rails t.rails)
  =/  got=(each kind:rules tang)  (mule |.(!<(kind:rules u.code)))
  ?:  ?=(%| -.got)  $(rails t.rails)
  $(rails t.rails, out (~(put by out) i.rails p.got))
::  +parse-event: json -> event. kind-specific args are built here;
::  eventually kinds should export their own codecs.
::
++  parse-event
  |=  jon=json
  ^-  (unit event:cal)
  =/  kind=@t  (gs jon 'kind')
  =/  name=@t  (gs jon 'name')
  ?:  |(=('' kind) =('' name))  ~
  =/  =meta:cal
    :*  name
        (gs jon 'note')
        =/(c (gs jon 'color') ?:(=('' c) '#4a6a8a' c))
    ==
  =/  start=(unit @da)  (bind (gn jon 'start_ms') ms-to-da)
  ?~  start  ~
  =/  zone=(unit @t)
    =/  z=@t  (gs jon 'zone')
    ?:(=('' z) ~ `z)
  =/  =end:rules
    =/  dur=(unit @ud)  (gn jon 'dur_min')
    ?~  dur  ~
    ?:  =(0 u.dur)  ~
    [%for (mul u.dur ~m1)]
  =/  at=@dr  (mul (fall (gn jon 'at_min') 0) ~m1)
  =/  args=(unit *)
    ?:  =('once' kind)   `~
    ?:  =('every' kind)
      (bind (gn jon 'period_min') |=(p=@ud `*`(mul p ~m1)))
    ?:  =('daily' kind)  `at
    ?:  =('weekly' kind)
      =/  days=(unit json)  ?.(?=(%o -.jon) ~ (~(get by p.jon) 'days'))
      ?~  days  ~
      ?.  ?=([~ %a *] days)  ~
      =/  wl=(list wkd:rules)
        %+  murn  p.u.days
        |=  =json
        ?.  ?=(%s -.json)  ~
        (mole |.(;;(wkd:rules p.json)))
      ?~  wl  ~
      `[wl at]
    ?:  =('monthly' kind)
      (bind (gn jon 'day') |=(d=@ud `*`[d at]))
    ?:  =('monthly-nth' kind)
      =/  dow=(unit wkd:rules)  (mole |.(;;(wkd:rules (gs jon 'day'))))
      =/  ord=(unit ord:rules)  (mole |.(;;(ord:rules (gs jon 'ord'))))
      ?:  |(?=(~ dow) ?=(~ ord))  ~
      `[u.ord u.dow at]
    ?:  =('yearly' kind)
      =/  mo=(unit @ud)  (gn jon 'month')
      =/  dy=(unit @ud)  (gn jon 'day')
      ?:  |(?=(~ mo) ?=(~ dy))  ~
      `[u.mo u.dy at]
    ~
  ?~  args  ~
  =/  =rule:rules
    :*  [/lib/rules (slav %tas kind)]
        u.args
        zone
        u.start
        end
        ~
        ~
    ==
  `[rule meta]
--
