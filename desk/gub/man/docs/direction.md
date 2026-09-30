# Documenting the codebase: the direction

The working direction for documenting Grubbery's own source: the kernel, the
libraries, the nexuses. A living document, written down to have something to
push against. How a page is written is in
[The writing standard](#writing-standard.md); this is what the documentation
is for and how it is measured.

## The point is better code, not more documentation

Documentation is the means. The end is a codebase that is simpler and more
legible, to a human and to an AI, at a glance.

The mechanism: **when a unit of code resists a short, clear explanation, the
resistance is the signal.** An arm that needs three paragraphs is doing too
much, named wrong, or factored wrong. Documenting is not a transcription pass
over finished code; it is how the code that should change gets found. Write
the explanation, feel it fight, fix the code, watch the explanation collapse
to a sentence. The doc getting shorter is the win.

Coverage rising is table stakes. The metric that matters is explanation
length falling as the code gets better.

## The anchor is a line range

A doc entry covers a span of lines in a file: `nexus.hoon 79-90`. Line
numbers are trivially correct to capture and impossible to misparse; there is
no unit-extraction machinery to build or get wrong.

The objection is drift: insert lines above a span and it points at the wrong
code. The content hash below answers it. Drift stops being silent and becomes
a visible staleness flag, so line ranges are the simplest anchor that is still
safe, and anchoring by `++` name would solve a problem the hash already
solves.

## Two metrics, kept separate

**Coverage.** A line is covered if some doc entry's range includes it.
Coverage is covered lines over total lines, per file, per section, per
collection. No units to enumerate, no quality score. A line is inside a
documented span or it is not.

**Freshness.** Does the explanation still match the code? A content hash of
the span's text is stored the first time the span is seen. A mismatch flags
the entry as drifted: the code in that range changed, or the range shifted.
Re-read the prose; if the span merely moved, re-anchor it; confirm to
re-stamp.

The two are orthogonal. Both show on the source: covered or not, fresh or
drifted.

## Measuring it without over-engineering

The measurement earns trust by being obviously correct. The enemy is a number
nobody believes.

- Coverage is line arithmetic: the union of documented ranges over the line
  count, verifiable by eye.
- Freshness hashes the text as written. A whitespace-only edit flagging a span
  is fine; the re-confirm is cheap and the signal is honest. No AST diff, no
  "is this change meaningful" heuristic.
- Hash per span, not per file, so a change flags only the entries whose
  ranges cover the changed lines.

The one cost of line ranges is that an edit above a span shifts it and its
hash mismatches though its own code did not change. That noise is accepted.
If it hurts, the fix is to search the file for the hashed text and relocate
the range; not built until the noise proves it is needed.

## Mirroring the code

Coverage needs the source it measures, so the docs nexus subscribes to what it
covers and keeps a local copy. Everything downstream is then a pure function
of the nexus's own tree: coverage recomputes from the mirror and never reaches
outside at compute time. The subscription delivers the content and wakes the
recompute the instant a covered file changes, so recomputation is
event-driven, not polled. It also makes location irrelevant: subscribing to a
local desk and to a remote ship's desk is the same gesture.

A **collection** is a handbook plus the sources it documents:

- **sources**: directories to cover, each under a tag. Covering a directory
  covers everything under it, so a new file counts by default.
- **ignore**: files and subdirectories within the sources that should not
  count. Include the directory, ignore the exceptions.
- **the mirror**: each source's copy, mounted under its tag. The handbook's
  own prose is mirrored separately so markdown never counts as code.
- **references**: an anchor names its source by tag and resolves against the
  mirror, never the original.

The coverage denominator falls out: every non-ignored file under the sources.

## Where the computation lives

Parsing anchors, slicing spans, hashing, comparing to pins: all of it runs on
the ship, in Hoon, when the mirror changes. The hash is `mug`: this is drift
detection, not security. The output is one cache grub per collection holding
the whole-collection result and one view per scoped section. The browser is a
pure reader of that cache. It computes nothing.

A span is stamped the first time the ship recomputes after it appears, at the
commit that introduces it, and never re-stamped on view. Drift stays visible
until someone confirms it.

## The legibility signal

The complexity measure is a rough proxy, labelled as rough: the length of a
unit's explanation. A unit whose honest explanation is long is a
simplification candidate. Track the distribution and the trend, not any single
number. No model scores the prose; the long explanations are read as a to-do
list for the code.

When a unit is simplified and its explanation shrinks, that is a recorded,
material improvement. Total explanation weight falling while coverage holds
is the dashboard.

## Choosing what to document next

Coverage says how much is documented, not what to document first. The better
signal is friction: where someone reading or changing the code had to
reverse-engineer an invariant that no page states.

Open pull requests are the sharpest form of that signal, because each one is
a place where the code's behavior surprised someone enough to change it.
Mapping open PRs onto the handbook's pages gives a ranked list: count how many
land on each page, and read their descriptions for the invariant that had to
be rediscovered. A page several PRs land on is under-documented in a way that
is already costing people. A run of PRs with the same shape, say a fiber
waiting on an answer the other side never sends with nothing logged, is one
contract that one page should state in a sentence, and that page goes first.

Those rediscovered invariants are what the page has to state, in the place
its structure puts them.

One possible standard, offered rather than imposed: a PR either references
documented behavior, the page and section its change is about, or documents
what it changes in the same PR. Whether to adopt it is a decision about how
the project works, and this handbook is not where that decision gets made.

## What we are deliberately not doing

- No semantic diff or "meaningful change" detection for freshness. Hash the
  text.
- No model-scored doc quality. Coverage is covered lines; complexity is a
  length proxy read with judgment.
- No unit-extraction machinery. Line ranges are the anchor; the hash makes
  them safe.
- No documenting for coverage's sake. A trivial span gets a one-line
  explanation; a span that cannot get one is a code problem.

## Open

- **The line-level denominator.** Settled at the file level: every non-ignored
  file under the sources. Open within a file: all lines, or only substantive
  ones, excluding blanks and bare `==`/`--` closers. Current lean: count all
  lines, and exclude a category only if the number feels dishonest.
- **When the complexity measure turns on.** Coverage and freshness first; the
  legibility trend once there is enough documented code for it to mean
  something.
