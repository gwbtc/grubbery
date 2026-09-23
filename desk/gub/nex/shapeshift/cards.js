// cards.js — one renderer per intent (after the original's registry).
// Each takes {data, signals, saved, ...callbacks} and returns a DOM
// node. `signals` lists which systemone signals the card reads, so the
// gate only tracks those; `example` feeds the explainer and palette.
(function () {
  const el = (tag, cls, text) => { const n = document.createElement(tag); if (cls) n.className = cls; if (text != null) n.textContent = text; return n; };
  const P = () => window.Parse;
  const money = (v, cur) => (v == null ? '—' : P().formatAmount(v, cur));
  const fmtDate = (iso, hasTime) => {
    if (!iso) return null;
    const d = new Date(iso);
    const day = d.toLocaleDateString(undefined, { weekday: 'long', month: 'short', day: 'numeric' });
    return hasTime ? `${day} · ${d.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' })}` : day;
  };
  const fmtNum = (n) => (n == null ? '—' : Math.abs(n) >= 1e6 || (Math.abs(n) < 1e-3 && n !== 0) ? n.toExponential(3) : Number(n.toFixed(4)).toLocaleString());
  const chip = (text, kind) => el('span', 'chip' + (kind ? ' ' + kind : ''), text);
  const meta = (...chips) => { const m = el('div', 'card-meta'); for (const c of chips) if (c) m.appendChild(c); return m; };
  const urgentChip = (s) => (s.urgent ? chip('Urgent', 'urgent') : null);
  const repeatChip = (s) => (s.recurring ? chip('↻ Repeats') : null);

  const CARDS = {
    event: {
      label: 'Event', icon: '📅', example: 'dinner with Tenzin and Pema friday 8pm on zoom', signals: ['eventMode', 'recurring'],
      render({ data, signals }) {
        const c = el('div', 'card card-event');
        c.appendChild(el('div', 'card-title', data.title || 'Untitled event'));
        const when = fmtDate(data.date, data.hasTime);
        c.appendChild(meta(
          when && chip(when, 'when'),
          data.location && chip('📍 ' + data.location),
          data.link ? chip('🎥 ' + data.link) : signals.eventMode === 'video_call' ? chip('🎥 Video call') : signals.eventMode === 'phone_call' ? chip('📞 Phone call') : null,
          repeatChip(signals),
        ));
        if (data.people.length) {
          const p = el('div', 'card-people');
          for (const name of data.people) { const a = el('span', 'avatar', name[0]); a.title = name; p.appendChild(a); }
          p.appendChild(el('span', 'muted', data.people.join(', ')));
          c.appendChild(p);
        }
        return c;
      },
    },
    reminder: {
      label: 'Reminder', icon: '🔔', example: 'remind me to call mom tomorrow', signals: ['urgency', 'recurring'],
      render({ data, signals }) {
        const c = el('div', 'card card-reminder' + (signals.urgent ? ' caution' : ''));
        c.appendChild(el('div', 'card-title', data.task || 'Reminder'));
        c.appendChild(meta(data.when ? chip(fmtDate(data.when, data.hasTime), 'when') : chip('when?'), urgentChip(signals), repeatChip(signals)));
        return c;
      },
    },
    todo: {
      label: 'Checklist', icon: '☑︎', example: 'buy milk, eggs, bread and coffee', signals: ['isShoppingList', 'urgency'],
      render({ data, signals, saved, onToggle }) {
        const c = el('div', 'card card-todo');
        c.appendChild(el('div', 'card-title', signals.isShoppingList || data.verb === 'buy' ? 'Shopping list' : 'Checklist'));
        const ul = el('ul', 'todo-list');
        const done = new Set((saved && saved.done) || []);
        data.items.forEach((item, i) => {
          const li = el('li', done.has(i) ? 'done' : '');
          const box = el('input'); box.type = 'checkbox'; box.checked = done.has(i);
          box.addEventListener('change', () => { li.classList.toggle('done', box.checked); if (onToggle) onToggle(i, box.checked); });
          li.appendChild(box); li.appendChild(el('span', null, item)); ul.appendChild(li);
        });
        c.appendChild(ul);
        c.appendChild(meta(el('span', 'muted', `${data.items.length} item${data.items.length === 1 ? '' : 's'}`), urgentChip(signals)));
        return c;
      },
    },
    timer: {
      label: 'Timer', icon: '⏱', example: '25 min focus', signals: ['timerKind'],
      render({ data, signals, saved, onTick }) {
        const kind = signals.timerKind;
        const c = el('div', 'card card-timer');
        c.appendChild(el('div', 'card-title', (kind === 'focus' ? 'Focus' : kind === 'break' ? 'Break' : kind === 'stopwatch' ? 'Stopwatch' : 'Timer') + (data.label ? ' · ' + data.label : '')));
        const big = el('div', 'card-big mono', data.seconds != null ? P().formatClock(data.seconds) : '--:--');
        c.appendChild(big);
        if (data.seconds != null) {
          const row = el('div', 'card-meta');
          const start = el('button', 'small', 'Start');
          let left = data.seconds, handle = null;
          start.addEventListener('click', () => {
            if (handle) { clearInterval(handle); handle = null; start.textContent = 'Start'; return; }
            start.textContent = 'Pause';
            handle = setInterval(() => { left--; big.textContent = P().formatClock(left); if (left <= 0) { clearInterval(handle); handle = null; start.textContent = 'Done'; big.textContent = '00:00'; } }, 1000);
          });
          const reset = el('button', 'small', 'Reset');
          reset.addEventListener('click', () => { if (handle) clearInterval(handle); handle = null; left = data.seconds; big.textContent = P().formatClock(left); start.textContent = 'Start'; });
          row.appendChild(start); row.appendChild(reset); c.appendChild(row);
        }
        return c;
      },
    },
    habit: {
      label: 'Habit', icon: '🌱', example: 'meditate every morning', signals: [],
      render({ data }) {
        const c = el('div', 'card card-habit');
        c.appendChild(el('div', 'card-title', data.title || 'Habit'));
        const strip = el('div', 'week-strip');
        ['S', 'M', 'T', 'W', 'T', 'F', 'S'].forEach((d, i) => strip.appendChild(el('span', 'day' + (data.days.includes(i) ? ' on' : ''), d)));
        c.appendChild(strip);
        c.appendChild(meta(data.label ? chip(data.label) : chip('how often?')));
        return c;
      },
    },
    color: {
      label: 'Color', icon: '◉', example: 'tiffany blue', signals: ['colorMood'],
      render({ data, signals }) {
        const c = el('div', 'card card-color');
        const sw = el('div', 'swatch');
        sw.style.background = data.hex || 'transparent';
        if (!data.hex) sw.classList.add('empty');
        c.appendChild(sw);
        const body = el('div', 'color-body');
        body.appendChild(el('div', 'card-title mono', data.hex ? data.hex.toUpperCase() : '#?'));
        const m = meta(data.name && chip(data.name), signals.colorMood && chip(signals.colorMood, 'mood'));
        if (data.hex) { const r = parseInt(data.hex.slice(1, 3), 16), g = parseInt(data.hex.slice(3, 5), 16), b = parseInt(data.hex.slice(5, 7), 16); m.appendChild(chip(`rgb(${r}, ${g}, ${b})`, 'mono')); }
        body.appendChild(m);
        c.appendChild(body);
        return c;
      },
    },
    split: {
      label: 'Split', icon: '÷', example: 'split 2400 between 3', signals: [],
      render({ data }) {
        const c = el('div', 'card card-split');
        c.appendChild(el('div', 'card-title', 'Split the bill'));
        c.appendChild(el('div', 'card-big', data.each != null ? money(data.each, data.currency) + ' each' : '—'));
        c.appendChild(meta(chip(data.total != null ? money(data.total, data.currency) + ' total' : 'amount?'), chip(data.people ? `${data.people} people` : 'how many?')));
        return c;
      },
    },
    expense: {
      label: 'Expense', icon: '💸', example: 'spent 45 on uber', signals: ['expenseCategory'],
      render({ data, signals }) {
        const ICON = { food: '🍽', transport: '🚕', shopping: '🛍', bills: '🧾', entertainment: '🎟', health: '💊' };
        const c = el('div', 'card card-expense');
        const row = el('div', 'expense-row');
        row.appendChild(el('span', 'expense-icon', ICON[signals.expenseCategory] || '💸'));
        const body = el('div', 'expense-body');
        body.appendChild(el('div', 'card-title', data.item || 'Expense'));
        body.appendChild(meta(signals.expenseCategory && chip(signals.expenseCategory, 'mood'), chip(new Date().toLocaleDateString(undefined, { month: 'short', day: 'numeric' }))));
        row.appendChild(body);
        row.appendChild(el('span', 'expense-amount', data.amount != null ? money(data.amount, data.currency) : '—'));
        c.appendChild(row);
        return c;
      },
    },
    convert: {
      label: 'Convert', icon: '⇄', example: '5 miles in km', signals: [],
      render({ data, onChangeTarget }) {
        const c = el('div', 'card card-convert');
        c.appendChild(el('div', 'card-title', 'Convert'));
        const L = P().LABELS;
        const row = el('div', 'card-big');
        row.appendChild(el('span', null, data.value != null ? `${fmtNum(data.value)} ${L[data.from] || data.from || ''}` : '—'));
        row.appendChild(el('span', 'muted', ' = '));
        row.appendChild(el('span', 'accent', data.result != null ? `${fmtNum(data.result)} ${L[data.to] || data.to}` : '?'));
        c.appendChild(row);
        if (data.from) {
          const sel = el('select', 'unit-select');
          for (const u of P().unitOptions(data.from)) { const o = el('option', null, L[u] || u); o.value = u; if (u === data.to) o.selected = true; sel.appendChild(o); }
          sel.addEventListener('change', () => onChangeTarget && onChangeTarget(sel.value));
          c.appendChild(meta(el('span', 'muted', 'to '), sel));
        }
        return c;
      },
    },
    calc: {
      label: 'Calculate', icon: '=', example: '18% of 3450', signals: [],
      render({ data }) {
        const c = el('div', 'card card-calc');
        c.appendChild(el('div', 'card-title mono', data.expression || ''));
        c.appendChild(el('div', 'card-big', data.result != null ? '= ' + fmtNum(data.result) : '…'));
        return c;
      },
    },
    travel: {
      label: 'Trip', icon: '✈️', example: 'flight to denver next weekend', signals: ['transport', 'tripType'],
      render({ data, signals }) {
        const T = { flight: '✈️', train: '🚆', bus: '🚌', car: '🚗' };
        const c = el('div', 'card card-travel');
        c.appendChild(el('div', 'card-title', (T[signals.transport] || '🧳') + ' ' + (data.destination ? 'Trip to ' + data.destination : 'Trip')));
        const s = data.start ? new Date(data.start) : null, e = data.end ? new Date(data.end) : null;
        const range = s ? s.toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric' }) + (e ? ' → ' + e.toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric' }) : '') : null;
        c.appendChild(meta(range && chip(range, 'when'), data.origin && chip('from ' + data.origin), signals.tripType === 'work' ? chip('💼 Work') : signals.tripType === 'leisure' ? chip('🌴 Leisure') : null));
        return c;
      },
    },
    poll: {
      label: 'Poll', icon: '🗳', example: 'pizza or burgers for friday?', signals: ['hasExplicitOptions'],
      render({ data, saved, onVote }) {
        const c = el('div', 'card card-poll');
        c.appendChild(el('div', 'card-title', data.title || 'Poll'));
        const votes = (saved && saved.votes) || {};
        const total = Object.values(votes).reduce((a, b) => a + b, 0);
        const list = el('div', 'poll-options');
        data.options.forEach((opt, i) => {
          const n = votes[i] || 0;
          const row = el('button', 'poll-opt');
          const fill = el('span', 'poll-fill'); fill.style.width = total ? Math.round((n / total) * 100) + '%' : '0';
          row.appendChild(fill);
          row.appendChild(el('span', 'poll-label', opt));
          row.appendChild(el('span', 'poll-count', total ? `${n} · ${Math.round((n / total) * 100)}%` : ''));
          row.addEventListener('click', () => onVote && onVote(i));
          list.appendChild(row);
        });
        c.appendChild(list);
        return c;
      },
    },
    contact: {
      label: 'Contact', icon: '👤', example: 'Dave Miller 555 867 5309 dave@mail.com', signals: [],
      render({ data }) {
        const c = el('div', 'card card-contact');
        const row = el('div', 'contact-row');
        row.appendChild(el('span', 'avatar big', data.initials || '?'));
        const body = el('div', 'contact-body');
        body.appendChild(el('div', 'card-title', data.name || 'Contact'));
        const m = el('div', 'card-meta');
        if (data.phone) { const a = el('a', 'chip mono', data.phone); a.href = 'tel:' + data.phone.replace(/[^\d+]/g, ''); m.appendChild(a); }
        if (data.email) { const a = el('a', 'chip mono', data.email); a.href = 'mailto:' + data.email; m.appendChild(a); }
        if (!data.phone && !data.email) m.appendChild(chip('number or email?'));
        body.appendChild(m);
        row.appendChild(body);
        c.appendChild(row);
        return c;
      },
    },
    link: {
      label: 'Bookmark', icon: '🔗', example: 'https://urbit.org/blog check later', signals: [],
      render({ data }) {
        const c = el('div', 'card card-link');
        const row = el('div', 'contact-row');
        row.appendChild(el('span', 'avatar big mono', data.monogram || '?'));
        const body = el('div', 'contact-body');
        if (data.url) { const a = el('a', 'card-title link', data.domain); a.href = data.url; a.target = '_blank'; a.rel = 'noopener'; body.appendChild(a); body.appendChild(el('div', 'muted mono url', data.url)); }
        else body.appendChild(el('div', 'card-title', 'Bookmark'));
        if (data.note) body.appendChild(el('div', 'note-body', data.note));
        row.appendChild(body);
        c.appendChild(row);
        return c;
      },
    },
    countdown: {
      label: 'Countdown', icon: '⏳', example: 'days until christmas', signals: [],
      render({ data }) {
        const c = el('div', 'card card-countdown');
        c.appendChild(el('div', 'card-title', data.title || 'Countdown'));
        const big = data.days == null ? '—' : data.days === 0 ? 'Today' : `${Math.abs(data.days)} day${Math.abs(data.days) === 1 ? '' : 's'}`;
        c.appendChild(el('div', 'card-big', big));
        c.appendChild(meta(data.date && chip((data.days < 0 ? 'since ' : 'until ') + new Date(data.date).toLocaleDateString(undefined, { weekday: 'long', month: 'short', day: 'numeric' }), 'when')));
        return c;
      },
    },
    timezone: {
      label: 'Time zone', icon: '🌐', example: '3pm pst in tokyo', signals: ['fromZone', 'toZone'],
      render({ data }) {
        const c = el('div', 'card card-timezone');
        c.appendChild(el('div', 'card-title', data.to ? `${data.fromLabel} → ${data.toLabel}` : 'Time zones'));
        if (data.to) {
          const row = el('div', 'tz-row');
          const a = el('div', 'tz-side'); a.appendChild(el('div', 'card-big', data.fromTime)); a.appendChild(el('div', 'muted', data.fromLabel + (data.isNow ? ' · now' : '')));
          const b = el('div', 'tz-side'); b.appendChild(el('div', 'card-big accent', data.toTime)); b.appendChild(el('div', 'muted', data.toLabel + (data.dayShift ? (data.dayShift > 0 ? ' · next day' : ' · previous day') : '')));
          row.appendChild(a); row.appendChild(el('span', 'tz-arrow', '→')); row.appendChild(b);
          c.appendChild(row);
          c.appendChild(meta(chip(data.from, 'mono'), chip(data.to, 'mono')));
        } else c.appendChild(meta(chip('where to?')));
        return c;
      },
    },
    random: {
      label: 'Random', icon: '🎲', example: 'roll 2d6', signals: [],
      render({ data, saved, onRoll }) {
        const c = el('div', 'card card-random');
        const titles = { dice: `Roll ${data.count}d${data.sides}`, coin: 'Flip a coin', number: `Random ${data.min}–${data.max}`, pick: 'Pick one' };
        c.appendChild(el('div', 'card-title', titles[data.kind] || 'Random'));
        const roll = () => {
          if (data.kind === 'dice') { const r = Array.from({ length: data.count }, () => 1 + Math.floor(Math.random() * data.sides)); return { rolls: r, text: r.reduce((a, b) => a + b, 0) + (r.length > 1 ? '  (' + r.join(' + ') + ')' : '') }; }
          if (data.kind === 'coin') return { text: Math.random() < 0.5 ? 'Heads' : 'Tails' };
          if (data.kind === 'number') return { text: String(data.min + Math.floor(Math.random() * (data.max - data.min + 1))) };
          if (data.kind === 'pick' && data.options && data.options.length) return { text: data.options[Math.floor(Math.random() * data.options.length)] };
          return { text: '?' };
        };
        const result = saved && saved.result ? saved.result : roll();
        const big = el('div', 'card-big', result.text);
        c.appendChild(big);
        if (data.kind === 'pick' && data.options) c.appendChild(meta(...data.options.map((o) => chip(o))));
        if (data.kind) { const again = el('button', 'small', 'Again'); again.addEventListener('click', () => { const r = roll(); big.textContent = r.text; if (onRoll) onRoll(r); }); c.appendChild(again); }
        c.result = result;
        return c;
      },
    },
    goal: {
      label: 'Goal', icon: '🎯', example: 'read 12 books this year, 4 done', signals: [],
      render({ data, saved, onProgress }) {
        const c = el('div', 'card card-goal');
        c.appendChild(el('div', 'card-title', data.title || 'Goal'));
        const cur = saved && saved.current != null ? saved.current : data.current;
        const pct = data.target ? Math.min(100, Math.round((cur / data.target) * 100)) : 0;
        const bar = el('div', 'goal-bar'); const fill = el('div', 'goal-fill'); fill.style.width = pct + '%'; bar.appendChild(fill); c.appendChild(bar);
        const m = meta(chip(data.target ? `${cur} / ${data.target}${data.unit ? ' ' + data.unit : ''}` : 'target?'), data.target && chip(pct + '%'));
        if (onProgress && data.target) { const plus = el('button', 'small', '+1'); plus.addEventListener('click', () => onProgress(Math.min(data.target, cur + 1))); m.appendChild(plus); }
        c.appendChild(m);
        return c;
      },
    },
    note: {
      label: 'Note', icon: '✎', example: 'the best ideas arrive mid-sentence', signals: ['tone', 'isQuestion', 'urgency'],
      render({ data, signals }) {
        const TONE = { positive: 'Upbeat note', excited: 'Excited note', stressed: 'Stressed note', reflective: 'Reflective note' };
        const c = el('div', 'card card-note' + (signals.tone ? ' tone-' + signals.tone : ''));
        c.appendChild(el('div', 'card-kind-inline', TONE[signals.tone] || (signals.isQuestion ? 'Question' : 'Note')));
        c.appendChild(el('div', 'card-title', data.title || 'Note'));
        if (data.body) c.appendChild(el('div', 'note-body', data.body));
        const u = urgentChip(signals);
        if (u) c.appendChild(meta(u));
        return c;
      },
    },
  };

  window.Cards = CARDS;
})();
