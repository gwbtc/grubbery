# The writing standard

How to actually write a handbook page. This is the craft companion to
[Documenting the codebase](#direction.md), which sets the *why* and what we
measure; this sets the *how*. It's prescriptive on purpose, and it will change
as we find things that work and things that don't.

## The one rule everything serves

The point is better code, not more prose. If a unit resists a short, clear
explanation, the resistance is the signal: the code is doing too much, named
wrong, or factored wrong. So you write to *find* the code that should change.
Brevity isn't a style preference here, it's the measurement. A page that keeps
getting shorter as you understand it is the page working.

## Write by altitude

Every page moves top-down through three altitudes. Name which one you're at and
don't mix them in a paragraph.

- **Paradigm** — what this subsystem does and *why it exists*, its shape in one
  breath. This is the opening, before any code.
- **Core** — the role each core or file plays in the subsystem.
- **Unit** — what one arm, type, or constant is: its inputs and outputs, its
  invariants, its gotchas, its place in the machine.

A reader should be able to stop after the paradigm and know what the thing is
for; descend only as far as they need.

## The process

The order the work happens in. It is a way of finding the structure that is
there, and the structure that wants to be there.

1. **Scope.** Name the files and line ranges that back the phenomenon: the
   code a reader would have to read to see it happen. That list is the page's
   `scope` in the nav. If you can't draw the boundary, you don't have a topic
   yet; you have two, or half of one.
2. **Joints.** Split the topic where it actually divides, and split each part
   the same way, until the shape of the whole shows from the headers alone.
   Test it: cover the body, read only the headers, ask whether the mechanism
   is visible. Headers name the things in the subject — "Lanes and waves,"
   "The two indices" — never the step of this process that produced them.
   "The objects," "The shape," "Orientation" are the scaffold, and the
   scaffold does not appear in the page.
3. **Orient.** Open with the shapes: the objects, and the context they live
   in. Then how those objects change, or act on their context. Then what that
   buys: why it's useful here, and how that usefulness feeds the section above
   it. Each page motivates itself one level up and links; the chain to the top
   runs across pages, not inside each one.
4. **Write it in order, and let it unfold.** Nothing — no object, concept, or
   arm — is used before it has been introduced. The page is written top to
   bottom, each beat standing on the ones before it, so a reader goes through
   once and never has to jump ahead. A concept whose home is another page may
   appear if it is linked at first mention; a concept whose home is this page
   may not appear before its own introduction.

What you find along the way that isn't structure — a concrete failure, a
place the code fights the explanation — goes in a callout, not in the spine
of the page. Recording it is part of the work; organizing the page around it
is not.

## The shape of a page

1. **Open at the top.** One paragraph: what this is and why, in plain language,
   before a single line of code. If you can't write that paragraph, you don't
   understand the subsystem yet.
2. **Lay the model — objects before actions.** The concepts and vocabulary the
   rest depends on, in dependency order. Flesh out the data structures — show the
   types — *before* the operations on them: a reader can't follow the verbs until
   they hold the shapes those verbs move. Name every noun here so nothing
   downstream is a hole. A one-line "these objects, these verbs" preview is fine;
   just don't start enumerating what each verb does until its objects are on the
   page.
3. **Descend, tiling the code.** Prose, live block, prose, live block. Walk the
   real arms in the order a reader builds understanding, each block introduced
   by the one thing to look for in it.
4. **Don't bury a real failure mode.** If a part bites — an arm that crashes, a
   count that diverges — make sure the reader meets it, and meets the *concrete*
   failure ("a re-cull crashes the event"), not a vague caution. Its own section
   or a beat inline is a judgment call: a big or subtle trap earns a section, a
   one-liner doesn't.

## Live blocks embed the real code

The ` ```live ` fence takes a target-relative path and a line range
(`/lib/build.hoon 438-476`). It renders the **actual source** and counts toward
coverage, so the reader is reading the kernel and your prose together.

- Use `live` for real code the reader should see. Use a plain ` ```hoon ` fence
  only for an illustrative snippet you wrote yourself (an example call, a shape),
  never for real source you could have anchored.
- **Never drop a block cold.** Every live block gets a sentence or two before it
  saying what to notice and why. The code carries the detail; your job is the
  beat that isn't obvious from reading it.
- A good page reads like a literate walkthrough: the blocks tile the subsystem in
  order, and the prose is the through-line between them.

## Name and explain every object

An unexplained noun is a hole the reader falls into. The first time a type, arm,
or concept appears, say what it is. For a big concept with its own home, link it
rather than reprinting the explanation in every page that touches it.
Reference over repetition.

A link is a promise that the target explains the thing. Never link a stub, or
a page that exists but doesn't yet cover what you're citing it for: that is a
hole with a door painted on it. Until the home page is written, explain in
place, in a clause, and add the link when the page can carry it.

## Naming code in prose

A name in prose says what kind of thing it is by its sigil, in backticks:
`$wave` is a type, `+notify` is an arm, `%news` is a tag. A face or a field
with no sigil of its own is plain in backticks: `wire`, `fwd`. A path is
plain in backticks too: `/sys/ames`. The sigil is the reader's cue for where
to look in the source, so it is never dropped and never guessed.

## Callouts

A callout is a blockquote whose first paragraph is the marker: `> [!note]
Title`, then a bare `>` line, then the body. Without the blank quote line
the title runs into the body and the box has no head. Types: `note`,
`tip`, `warn`, `background`. The title says what the box is about at a
glance; a reader skimming should be able to skip it or stop on it from the
title alone.

## Diagrams carry relationships

The renderer is plain markdown (no mermaid), so diagrams are ASCII. Draw one
when a *relationship* carries the understanding and the source can't show it at a
glance: a pipeline, a state machine, a tree, a resolution order, a data flow.
Don't diagram what a sentence already says. A good diagram is documentation of a
shape; a decorative one is noise.

## Voice

- **Say what it is,** not "this arm is responsible for." Direct and declarative.
- **Write about the subject, not about reading it.** Cut phrases that rank the
  content's importance instead of giving it — "worth knowing," "worth seeing,"
  "note that," "keep in mind," "it's important to." If a span matters, the
  explanation shows why; its name ("the sharp edge") already says so.
- **Never editorialize difficulty or danger.** No "the hard part," "the tricky
  bit," "this is where it gets dangerous," "easy to misuse." Describe what the
  thing is and does; if it's dangerous, say the concrete failure ("a re-cull here
  crashes the event"), not that it's dangerous. Difficulty is never a label or a
  headline — only, at most, a described property of the mechanism.
- **Explain why,** not just what. The mechanism and the reason it's that way.
- **Never fabricate a why.** The "why" slot is easy to pad with a plausible
  justification that isn't true ("validated through its mark by definition").
  State only what's verified. An empty why is honest; a false one is worse
  than none.
- **Verify a claim rather than softening it.** Hedging ("probably," "in most
  cases") is the tell that you didn't check. Check, then state it plainly or
  cut it.
- **Docs describe what is. Critique lives in callouts.** "That caveat is the
  subsystem's real weakness" is not description; put it in a note. When the
  fix is clear, the note says it plainly: "the field should be dropped."
  Never pad a note with alternatives that aren't real to look even-handed.
- **The handbook describes the system, not how we work.** No PR conventions,
  workflow, or process in any page. That material has its own home (this
  section), and it is guidance, not a spec.
- **Clarity over completeness.** Leave out what the structure or the code already
  shows. Prose carries only what they can't.
- **Concrete over abstract.** Name the real arm, the real failure, the real
  number. "It 500s on the second cull" beats "an error may occur."
- **Brief.** Three paragraphs on one unit is a code smell surfacing, not a doc to
  polish. Fix the code or cut the prose.

## Coverage is a consequence, not a goal

A page that documents code declares a `scope` (see
[Documenting the codebase](#direction.md)) naming the exact arms it walks; its
live blocks then measure how much of that code it actually embeds, and go amber
when the code drifts out from under the prose. A page with no code — like this
one — declares no scope and stays *loose*: fine, and unmeasured. Never add a
block or pad a scope to move a number. If a span is genuinely trivial, a
one-line explanation is complete; if it can't get one, that's a code problem.

## What not to do

- No documenting for coverage's sake, ever.
- No restating the code in English. If the prose is the code in words, cut it.
- No unexplained jargon, no undefined nouns.
- No walls of text, no completeness for its own sake.
- No clause that survives its own deletion. If cutting a phrase loses no
  information, it was filler — the surest tell of meta-commentary and hedging.
- No cleverness in place of clarity.

## Worked examples

The pages built to this standard, to read as models:

- **[The compiler](#build-compiler.md)** — a literate walkthrough that tiles all
  of one file, prose between every block.
- **[The build system](#build-overview.md)** — paradigm-altitude opening plus the
  pipeline, subject-sentinel, and reverse-closure diagrams.
- **[Remote scry](#remote-scry.md)** — model first, then the verbs, then a named
  "sharp edge" section for the one dangerous arm.
