# Documenting the codebase: the direction

This is the working direction for documenting Grubbery's own source — the
nexuses, the kernel, the build system — the way the tool-authoring standard
governs MCP tools. It is a living document. We write it down to have something
to push against, and we change it as we learn what actually gives us confidence.

## The point is better code, not more documentation

Documentation is the means, not the end. The end is a codebase that is simpler,
clearer, and more legible — to a human and to an AI, at a glance.

The mechanism is this: **when a unit of code resists a short, clear explanation,
that resistance is the signal.** An arm that needs three paragraphs to describe
is doing too much, named wrong, or factored wrong. So documenting is not a
transcription pass over finished code; it is a way of *finding* the code that
should change. You write the explanation, you feel it fight you, you fix the
code, and the explanation collapses to a sentence. The doc getting shorter is
the win.

So coverage rising is table stakes. The metric we actually care about is
**average explanation-complexity falling** as the code gets better.

## The anchor is a line range

A doc entry covers a **span of lines in a file** — `nexus.hoon 79-90`. That is
the anchor. Line numbers are trivially correct to capture and impossible to
misparse; there is no unit-extraction machinery to build or to get wrong.

The obvious objection to line numbers is drift: insert lines above a span and it
now points at the wrong code. The content hash (below) answers that — drift stops
being silent and becomes a visible staleness flag. Given that, line ranges are
the simplest anchor that is still safe, and machinery to anchor by `++`/`+$` name
is solving a problem the hash already solves.

## Two metrics, kept separate

**Coverage** — the code-coverage analogy, literally. A line is covered if some doc
entry's range includes it. Coverage is `covered lines / total lines`, reported
per file, per nexus, per subsystem. No units to enumerate, no quality score —
a line is inside a documented span or it is not.

**Freshness** — does the explanation still match the code it describes? Store a
content hash of the span's text alongside the doc. Re-hash on demand; a mismatch
flags the doc as *possibly stale* — the code in that range moved or changed,
re-read the prose (and, if the span merely shifted, re-anchor it).

The two are orthogonal and both shown as a heatmap over the source: green where
covered, dim where not; a staleness mark where the hash no longer matches.

## Measuring it without over-engineering

The measurement has to earn trust by being obviously correct, not by being
sophisticated. The bar is material confidence, and the enemy is a number nobody
believes.

- **Coverage** is line arithmetic: for each file, the union of the documented
  ranges over the line count. Anyone can verify it by eye.
- **Freshness** is a hash comparison. Hash the span's **text as written** — do not
  try to be clever about semantic equivalence. A whitespace-only edit flagging a
  doc stale is fine: the re-confirm is cheap and the signal is honest. Do not
  build an AST-diff or an "is this change meaningful" heuristic; that is exactly
  the gimmick that makes the number untrustworthy.
- **Hash per span, not per file**, so a change flags only the docs whose ranges
  actually cover the changed lines, not every doc in the file.

That is the entire measurement engine: sum the covered lines, compare span
hashes. Everything it reports is something we can point at and verify by hand.

The one real cost of line ranges is that an edit *above* a span shifts it, so its
hash mismatches even though its own code did not change — some false-stale noise.
We accept that to start. If it turns out to hurt, the cheap fix is to search the
file for the hashed text and auto-relocate the range to where it moved — a small
trick, not a parser. We do not build that until the noise proves it is needed.

## Mirroring the code

Coverage needs the source it measures. Two ways to get it: read it on demand, or
mirror it. We mirror.

The nexus **subscribes to what it covers and keeps a local copy** in a `mirror/`
directory. Everything downstream is then a pure function of the nexus's own ball
— the `data.hoon` property: coverage recomputes from the mirror, never reaching
outside at compute time. The subscription earns its keep twice over: it delivers
the content, and it wakes a recompute the instant a covered file changes, so
"recompute when the code changes" is exact and event-driven, not polled. It also
decouples location — subscribing to local `/code` and to a remote ship's `/code`
are the same gesture, so the docs system can cover code it does not own.

**The canonical shape of a docs collection:**

- **`targets`** — the *directories* to cover (local `/code` or a remote ship's),
  not individual files. Covering a directory means covering everything under it;
  a file added to a target directory becomes a coverage target automatically,
  with nothing to update by hand.
- **`ignore`** — files and subdirectories within the targets to exclude:
  generated code, vendored libraries, tests, anything that should not count.
  Include-the-directory, ignore-the-exceptions, the `.gitignore` shape. Removing
  something from coverage is an ignore entry, not the un-listing of every file.
- **`mirror/`** — the local copy the subscriptions keep in sync. The nexus's own
  data, so on-load recompute is pure.
- **`dests`** — where each target lands in the mirror. The mirror layout is
  configurable, not forced to echo the source's.
- **references** — the live-block anchors resolve against the **mirror**, never
  the original, so a doc never reaches outside the nexus at compute time.

The **coverage denominator** falls out of this: every non-ignored file under the
target directories. That is the "how much of what we mean to cover, is covered"
number, and it stays honest as the codebase grows because new files count by
default.

## Where the computation lives

Once the code is mirrored, all of it — parsing anchors, slicing spans, hashing,
comparing to pins — happens **ship-side**, in Hoon, on reload / on a mirror
change. The hash is `mug`, the built-in noun hash: fast, deterministic, and this
is drift detection, not security, so `mug` is exactly right. Because only the
ship hashes, there is **nothing to match** across languages — the earlier worry
about replicating a JS hash disappears. The derived output is one `coverage.json`
grub: per-file coverage plus per-block fresh / drifted / gone.

The **browser is a pure reader**. It fetches `coverage.json` and renders it — the
heatmaps, the badges, the cross-navigation. No hashing, no coverage computation
in the client. (The first cut computed in the browser to move fast; this is where
it settles.)

Auto-pin moves with the computation: a block is stamped the first time the *ship*
recomputes after it appears — at the commit that introduces it — which is truer
"stamp on write" than "stamp on first browser view."

## The legibility signal

The complexity KPI is a **rough proxy, labelled as rough**: the length (word or
line count) of a unit's explanation. A unit whose honest explanation is long is a
simplification candidate. Track the distribution and the trend, not any single
number. We are not scoring prose quality with a model; we are noticing which
units cost the most to explain and treating that as a to-do list for the code.

When we simplify a unit and its explanation shrinks, that is a recorded,
material improvement. That trend line — total explanation-weight falling while
coverage holds — is the real dashboard.

## The doc standard

The prose itself follows the same spine as the tool-authoring standard:

- **Clarity of intent over completeness.** Structure carries what it can; prose
  carries only what it cannot.
- **Name and explain every object and relationship.** An unexplained noun is a
  hole the reader falls into. Reference a large concept's home rather than
  reprinting it in every unit that touches it.
- **Understood at a glance**, for a human and an AI both.

Layered by altitude:

- **Paradigm** — what this subsystem does and *why*, the high-level shape.
- **Core** — the role of this core in the subsystem.
- **Unit** — what this arm/type/constant is, its inputs and outputs, its
  invariants, its gotchas, its place in the larger machine.

Diagrams where structure or dataflow carries the understanding — a pipeline, a
state machine, a tree. A diagram is documentation of a relationship the source
cannot show at a glance.

## First case study: the build system

The build system is the first target: it is a pipeline (so it earns a diagram),
it is core, it is complex, and it is the thing we most want to understand.

"Done" for the case study is not "every arm has a comment." It is:

- every unit in the build subsystem **covered and fresh**,
- one real **pipeline diagram** of the build's stages,
- and a handful of **simplifications the documentation pass forced out** and we
  actually made — the proof that the loop works.

Then we generalize outward to the rest of the kernel behind the same coverage
dashboard, and see how the numbers feel on something bigger.

## What we are deliberately not doing

Guardrails against over-engineering, because the value dies if the numbers stop
being believable:

- No semantic-diff or "meaningful change" detection for freshness. Hash the text.
- No model-scored doc quality. Coverage is covered-lines; complexity is a length
  proxy we read with judgment.
- No unit-extraction machinery. Line ranges are the anchor; the hash makes them
  safe.
- No documenting for coverage's sake. If a span is genuinely trivial, a one-line
  explanation is complete; if it cannot get one, that is a code problem, not a
  doc problem.

## Open, and evolving as we go

- **Where doc entries live** — inline comments, or sidecar grubs keyed by
  `file + line range`. The handbook's ` ```live ` blocks already anchor exactly
  this way (path + range), so they are the foundation to build on. Current lean:
  sidecar grubs, rendered in an interactive code-plus-coverage view, keeping the
  source clean and giving diagrams a home.
- **The coverage denominator** — settled at the file level: every non-ignored
  file under the target directories. Still open at the line level within a file:
  all lines, or only substantive ones (excluding blanks and bare `==`/`--`
  closers). Current lean: count all lines to start, and only exclude a category
  if the number feels dishonest.
- **When the complexity KPI turns on** — coverage and freshness first, the
  legibility trend once there is data to make it real.

We will revisit all three once the build-system case study tells us how the
measurement actually feels in the hand.
