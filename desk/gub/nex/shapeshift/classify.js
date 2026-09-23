// classify.js — the offline keyword classifier (after the original's
// mock.ts). Same output shape as the model (raw systemone answers) so
// the state machine can't tell them apart. It runs on every keystroke;
// the model confirms later.
(function () {
  const INTENTS = ['event', 'reminder', 'todo', 'timer', 'habit', 'color', 'split', 'expense', 'convert', 'calc', 'travel', 'poll', 'contact', 'link', 'countdown', 'timezone', 'random', 'goal', 'note', 'none'];
  const has = (re, t) => re.test(t);

  const DATE_WORDS = /\b(today|tonight|tomorrow|tmrw|mon(day)?|tue(s(day)?)?|wed(nesday)?|thu(rs(day)?)?|fri(day)?|sat(urday)?|sun(day)?|next week|this week|noon|midnight|morning|evening|\d{1,2}\s?(am|pm)|\d{1,2}:\d{2}|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\b/;
  const GATHER = /\b(dinner|lunch|breakfast|brunch|coffee|meeting|meet|call|sync|standup|party|drinks|date|catch ?up|interview|appointment|hangout|1:1|session with|with [a-z]+)\b/;
  const UNIT = '(km|kms|kilomet(er|re)s?|mi|miles?|m|met(er|re)s?|cm|mm|ft|feet|foot|in|inch(es)?|yd|yards?|kg|kgs|kilos?|g|grams?|lbs?|pounds?|oz|ounces?|l|lit(er|re)s?|ml|gal(lons?)?|cups?|°?c|°?f|celsius|fahrenheit|kelvin|mph|kph|km/h)';
  const CONVERT_FULL = new RegExp(`\\d\\s*${UNIT}\\s+(to|in|into|as)\\s+${UNIT}\\b`);
  const CONVERT_PART = new RegExp(`\\d\\s*${UNIT}\\b`);
  const COLOR_WORDS = /\b(red|crimson|scarlet|maroon|burgundy|pink|rose|coral|salmon|peach|orange|tangerine|amber|gold|yellow|mustard|lemon|cream|beige|sand|tan|brown|chocolate|olive|lime|green|sage|mint|emerald|forest|teal|turquoise|cyan|sky|blue|navy|cobalt|indigo|violet|purple|lavender|lilac|magenta|plum|grey|gray|slate|charcoal|black|white|ivory)(ish)?\b/;
  const ZONE_WORD = /\b(pst|pdt|mst|mdt|cst|cdt|est|edt|utc|gmt|bst|cet|cest|ist|jst|aest|sgt|new york|nyc|chicago|denver|los angeles|san francisco|seattle|london|paris|berlin|oslo|tokyo|sydney|dubai|singapore|mumbai|delhi|hong kong|toronto)\b/g;
  const CLOCK = /\b\d{1,2}(:\d{2})?\s*(am|pm)\b|\b\d{1,2}:\d{2}\b|\b(noon|midnight)\b/;

  function scores(raw) {
    const t = raw.toLowerCase().trim();
    const words = t.split(/\s+/).filter(Boolean);
    const s = {};
    const add = (k, v) => (s[k] = (s[k] || 0) + v);
    const num = /\d/.test(t);
    const refs = window.Parse ? window.Parse.colorReference(t) : null;

    if (has(/https?:\/\/|www\.|\b[a-z0-9-]+\.(com|dev|io|app|org|net|co|ai|in|so|xyz|me|sh|gg|tv)\b/, t)) add('link', 6);
    if (has(/#[0-9a-f]{3}\b|#[0-9a-f]{6}\b|rgba?\(/, t)) add('color', 7);
    if (has(/#[0-9a-f]{1,5}$/, t)) add('color', 3);
    if (has(COLOR_WORDS, t)) add('color', 2.5);
    if (refs) add('color', 4.5);
    if (has(/\b(colou?r|shade|hue) (of|like)\b/, t)) add('color', 3);
    if (has(new RegExp(COLOR_WORDS.source + '\\s*$'), t)) add('color', 1.5);
    if (has(/\b(colou?r|shade|hue|palette|tone of)\b/, t)) add('color', 2);
    if (has(/[\w.+-]+@[\w-]+\.\w+/, t)) add('contact', 5);
    if (has(/(\+?1[\s-]?)?\(?\d{3}\)?[\s-]?\d{3}[\s-]?\d{4}\b/, t)) add('contact', 4);
    if (has(/\b(remind|reminder|don'?t forget|remember to)\b/, t)) add('reminder', 6);
    if (has(/\b(split|divide|share)\b/, t)) add('split', num ? 5 : 3);
    if (has(/\b(between|among)\s+(\d+|two|three|four|five|six)\b/, t) && num) add('split', 2);
    if (has(/\b(each|per person|per head)\b/, t) && num) add('split', 2);
    if (has(/\b(spent|paid|bought|cost|expense)\b/, t)) add('expense', num ? 5 : 3);
    if (has(/^(₹|rs\.?|\$)\s?\d/, t)) add('expense', 2);
    if (has(CONVERT_FULL, t)) add('convert', 7);
    else if (has(CONVERT_PART, t) && !has(/\b(min|mins|minutes?|hours?|hrs?|sec|secs?)\b/, t) && words.length <= 3) add('convert', 2);
    if (has(/\bconvert\b/, t)) add('convert', 3);
    if (has(/^[\d\s+\-*/x×÷^().,%]+$/, t) && has(/\d\s*[+\-*/x×÷^%]\s*[\d(]/, t)) add('calc', 7);
    if (has(/\d\s*%\s*(of|off)\b/, t)) add('calc', 6);
    if (has(/\b(what'?s|calculate|compute)\b.*\d/, t)) add('calc', 3);
    if (has(/\b(plus|minus|times|divided by|squared)\b/, t) && num) add('calc', 4);
    if (has(/\b(timer|countdown|stopwatch|pomodoro)\b/, t)) add('timer', 6);
    if (has(/\b\d+\s*(h|hr|hrs|hours?|m|min|mins|minutes?|s|sec|secs|seconds?)\b/, t)) add('timer', 3);
    if (has(/\b(focus|break|rest|nap|deep work)\b/, t) && num) add('timer', 2.5);
    if (has(/\b(every\s*day|daily|every (morning|night|evening)|each (day|morning)|\d\s*x\s*a\s*week|times a week|habit|weekly|every (mon|tue|wed|thu|fri|sat|sun))/, t)) add('habit', 5);
    if (has(/\b(flight|fly|flying|trip|travel|vacation|holiday|train to|bus to|road ?trip|visit|getaway)\b/, t)) add('travel', 5);
    if (has(/\bto [a-z]+/, t) && has(/\b(next weekend|this weekend|flight|trip)\b/, t)) add('travel', 1);
    if (has(/\b(or|vs)\b/, t) && t.endsWith('?')) add('poll', 5.5);
    else if (has(/\b\w+ or \w+/, t)) add('poll', 2);
    if (has(/\b(poll|vote)\b/, t)) add('poll', 3);
    if (has(/\b(days?|weeks?|sleeps?)\s+(until|till|til|to go|left|before)\b|\bcount ?down\b|\bhow (many days|long) (until|till|til)\b/, t)) add('countdown', 6.5);
    if (has(/\b(christmas|xmas|halloween|new year|thanksgiving|valentine|birthday)\b/, t) && has(/\b(until|till|til|to|left)\b/, t)) add('countdown', 3);
    const zones = t.match(ZONE_WORD) || [];
    if (zones.length >= 2) add('timezone', 7);
    else if (zones.length === 1 && (has(CLOCK, t) || has(/\b(time (in|at)|what time)\b/, t))) add('timezone', 6);
    else if (zones.length === 1 && has(/\b(in|to)\s/, t)) add('timezone', 3);
    if (has(/\bwhat time (is it )?in\b/, t)) add('timezone', 4);
    if (has(/\b(roll|dice|die|\d*d\d+|flip|coin|heads or tails)\b/, t)) add('random', 6);
    if (has(/\b(random|pick (one|for me)|choose for me|decide for me|shuffle)\b/, t)) add('random', 5);
    if (has(/\brandom (number|between)\b|\bbetween \d+ and \d+\b/, t)) add('random', 3);
    if (has(/\b\d+\s*(of|\/|out of)\s*\d+\b/, t)) add('goal', 5);
    if (has(/\b(goal|target|progress|so far|done|saved)\b/, t) && num) add('goal', 4);
    if (has(/\b(books?|pages?|workouts?|runs?|steps?|miles|km)\b/, t) && has(/\b(this year|this month|by)\b/, t)) add('goal', 2);
    if (has(/\b(buy|get|pick up|grab|order)\b/, t)) add('todo', 3);
    if (has(/\b(to ?do|todo list|shopping list|groceries|checklist)\b/, t)) add('todo', 5);
    const commas = (t.match(/,/g) || []).length;
    if (commas >= 2 && !s.poll && !s.contact) add('todo', 3);
    else if (commas === 1 && has(/\band\b/, t) && !s.event) add('todo', 2.5);
    if (has(DATE_WORDS, t) && !s.timezone) add('event', 3);
    if (has(GATHER, t)) add('event', 3);
    if (has(/\bwith [a-z]+/, t) && has(DATE_WORDS, t)) add('event', 2);
    if (has(/\b(on|via|over) (zoom|meet|teams|facetime|skype|discord)\b/, t)) add('event', 3);
    if (words.length >= 4 && !Object.keys(s).length) add('note', 2);
    if (words.length >= 8) add('note', 1);
    return s;
  }

  function classify(text) {
    const t = text.trim();
    const words = t.split(/\s+/).filter(Boolean);
    const s = scores(t);
    const probs = {};
    for (const k of INTENTS) probs[k] = 0;
    const total = Object.values(s).reduce((a, b) => a + b, 0);
    if (!t || words.length < 1 || total === 0) {
      probs.none = t.length < 3 ? 1 : 0.6;
      probs.note = t.length < 3 ? 0 : 0.4;
    } else {
      const temp = 1.6;
      let z = 0;
      const ex = {};
      for (const k of Object.keys(s)) { ex[k] = Math.exp(s[k] / temp); z += ex[k]; }
      const noneMass = Math.max(0.05, 1 - Math.min(1, total / 7));
      for (const k of Object.keys(ex)) probs[k] = (ex[k] / z) * (1 - noneMass);
      probs.none += noneMass;
    }
    const intent = { choice: null, probabilities: probs };
    let best = -1;
    for (const k of Object.keys(probs)) if (probs[k] > best) { best = probs[k]; intent.choice = k; }

    const lower = t.toLowerCase();
    const one = (keys, pick, p) => { const o = {}; for (const k of keys) o[k] = (1 - p) / (keys.length - 1); o[pick] = p; return { choice: pick, probabilities: o }; };
    const eventMode = /\b(zoom|meet|gmeet|google meet|teams|facetime|skype|discord|video)\b/.test(lower) ? 'video_call'
      : /\b(call|phone|ring)\b/.test(lower) && !/\bvideo\b/.test(lower) ? 'phone_call'
      : /\b(at|in) [a-z]/.test(lower) ? 'in_person' : 'unspecified';
    const transport = /\b(flight|fly|flying|plane|airport)\b/.test(lower) ? 'flight' : /\btrain\b/.test(lower) ? 'train' : /\bbus\b/.test(lower) ? 'bus' : /\b(drive|driving|road ?trip|car)\b/.test(lower) ? 'car' : 'unspecified';
    const tripType = /\b(work|business|conference|client|office)\b/.test(lower) ? 'work' : /\b(vacation|holiday|beach|getaway|honeymoon|family)\b/.test(lower) ? 'leisure' : 'unspecified';
    const expenseCategory = /\b(food|lunch|dinner|coffee|groceries|restaurant|pizza|drinks|beer)\b/.test(lower) ? 'food'
      : /\b(uber|lyft|cab|taxi|fuel|gas|petrol|ticket|metro|train|bus|parking)\b/.test(lower) ? 'transport'
      : /\b(rent|electric|water|internet|wifi|subscription|netflix|phone bill|recharge)\b/.test(lower) ? 'bills'
      : /\b(movie|cinema|concert|game|show|tickets)\b/.test(lower) ? 'entertainment'
      : /\b(doctor|medicine|pharmacy|gym|dentist|meds)\b/.test(lower) ? 'health'
      : /\b(shoes|clothes|shirt|amazon|gadget|headphones|jacket)\b/.test(lower) ? 'shopping' : 'other';
    const timerKind = /\b(focus|deep work|pomodoro|study)\b/.test(lower) ? 'focus' : /\b(break|rest|nap)\b/.test(lower) ? 'break' : /\bstopwatch\b/.test(lower) ? 'stopwatch' : 'countdown';
    const tone = /\b(ugh|stress|stressed|worried|anxious|frustrat|deadline|late|behind)\b/.test(lower) ? 'stressed'
      : /\b(can'?t wait|excited|finally|yay|!!)\b/.test(lower) || /!{2,}/.test(lower) ? 'excited'
      : /\b(grateful|happy|love|great|nice|thankful)\b/.test(lower) ? 'positive'
      : /\b(wonder|maybe|thinking|quiet|feel|felt|remember|noticed)\b/.test(lower) ? 'reflective' : 'neutral';
    const mood = /\b(pastel|soft|light|baby|powder)\b/.test(lower) ? 'pastel' : /\b(dark|deep|midnight|navy|charcoal|black)\b/.test(lower) ? 'dark' : /\b(neon|electric|vivid|bright|hot)\b/.test(lower) ? 'vivid'
      : /\b(grey|gray|beige|cream|sand|ivory|off.?white|white)\b/.test(lower) ? 'neutral' : /\b(blue|green|teal|purple|violet|indigo|cyan|mint|sky|navy)\b/.test(lower) ? 'cool' : /\b(red|orange|yellow|gold|amber|coral|peach|pink)\b/.test(lower) ? 'warm' : 'neutral';
    const urgent = /\b(urgent|asap|now|immediately|right away|deadline)\b/.test(lower);
    const recurring = /\b(every|daily|weekly|monthly|each (day|week|morning)|times a week|\dx a week)\b/.test(lower) ? 0.9 : 0.1;
    const isQuestion = /\?\s*$/.test(t) || /^(what|when|where|who|how|should|which|is|are|do|does|can)\b/.test(lower) ? 0.85 : 0.1;
    const hasExplicitOptions = /\b\w+ (or|vs) \w+/.test(lower) || (lower.match(/,/g) || []).length >= 1 && /\b(or|pick|choose|vote)\b/.test(lower) ? 0.85 : 0.15;
    const shopping = /\b(buy|get|pick up|grab|order|groceries|shopping)\b/.test(lower) ? 0.9 : /\b(milk|eggs|bread|coffee|butter|rice|cheese|apples|bananas|onions|tomatoes|chicken|beer|wine)\b/.test(lower) ? 0.6 : 0.2;

    const complete = window.Parse && intent.choice !== 'none' && intent.choice !== 'note' ? window.Parse.completeness(intent.choice, t) : Math.min(1, words.length / 6);
    const r = Math.max(0, Math.min(2, complete * 2));
    const rP = { '0': 0, '1': 0, '2': 0 };
    const lo = Math.floor(r), hi = Math.min(2, lo + 1), frac = r - lo;
    rP[String(lo)] += 1 - frac; rP[String(hi)] += frac;

    return {
      model: 'offline', source: 'offline',
      answers: {
        intent,
        readiness: { probabilities: rP },
        isQuestion: { noul: isQuestion },
        recurring: { noul: recurring },
        urgency: { probabilities: urgent ? { '0': 0.05, '1': 0.15, '2': 0.8 } : { '0': 0.8, '1': 0.15, '2': 0.05 } },
        tone: one(['neutral', 'positive', 'excited', 'stressed', 'reflective'], tone, 0.7),
        eventMode: one(['in_person', 'video_call', 'phone_call', 'unspecified'], eventMode, 0.85),
        transport: one(['flight', 'train', 'bus', 'car', 'unspecified'], transport, 0.85),
        tripType: one(['work', 'leisure', 'unspecified'], tripType, 0.8),
        expenseCategory: one(['food', 'transport', 'shopping', 'bills', 'entertainment', 'health', 'other'], expenseCategory, 0.8),
        colorMood: one(['warm', 'cool', 'neutral', 'vivid', 'pastel', 'dark'], mood, 0.75),
        timerKind: one(['countdown', 'focus', 'break', 'stopwatch'], timerKind, 0.8),
        hasExplicitOptions: { noul: hasExplicitOptions },
        isShoppingList: { noul: shopping },
        fromZone: { text: '' },
        toZone: { text: '' },
      },
    };
  }

  window.Classify = { classify, INTENTS };
})();
