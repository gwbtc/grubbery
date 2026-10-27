# Auditing a PR

A PR is a case. Someone argues that their change belongs in the codebase.
The case arrives assembled on one page. The codebase's side of the
argument does not. Why the code is the way it is, where it is heading,
what it would do next on its own: all of that is implicit, spread across
files, history, tests and docs. The auditor's job is to assemble the
codebase's side and then hear the case against it.

The recipe is `nex/git/forge/recipes/audit-pr.json`; the report's
shape, scales and rule are `nex/git/forge/recipes/audit-pr/report.md`.
The forge ships both into each repo's clanker, under its `recipes/`,
made once; the clanker's copy is the one it runs.

The output is a report a human can interpret. The human takes the
codebase's side, adversarially, and wants genuine improvements that come
from real use of the codebase.

## Stance

Two roles, in order.

- First, the codebase's advocate. The codebase's side is assembled
  honestly, but as a partisan of the codebase: why it is the way it is,
  where it is heading, what it would do next on its own. The PR's case
  has not been heard yet and gets no concession.
- Then, the impartial judge. Both cases in hand, the codebase's written
  by its advocate and the PR's made by its author, the judge decides.

- The PR is a strong case for a change. Engage it as a case, not as a
  description of a change.
- The author is probably well-intentioned, possibly hostile, and more
  than anything potentially incompetent. Nothing the PR says about
  itself is evidence: not its description, not its comments, not its
  commit message, not what it says it tested. Only the diff's hunks and
  the codebase are evidence. A claim the mechanism contradicts is a
  finding against the PR, never a choice to defer to.
- A diff's comments and strings are the author's argument carried into
  the code. The advocate reads the hunks for which parts are touched and
  takes nothing else from the diff.
- Where the codebase already answers the question the change answers,
  the advocate says so, as a principle. A second mechanism for a
  question the codebase has one mechanism for is a finding by
  construction, whatever the PR calls it.
- A question the judge can only settle by "verify whether" is a blind
  spot that bears on the fix. It is graded as one, not written into the
  testing plan.
- The codebase has a trajectory: a predictable next state given its
  present state, properly understood. The PR either lies on that
  trajectory or deviates from it. Say which, and how far.
- Reading only. No test is run. What a PR says it tested counts for
  nothing.
- `.grubbery/docs/` is the primer on a codebase. Read it before the code
  when it exists.

## The questions, in order

The order matters. The codebase's side is written down before the PR's
argument is read, or the auditor adopts the PR's framing without
noticing.

1. **Which parts are affected.** The systems, subsystems and parts of the
   codebase the PR touches, directly and by consequence.
2. **What those parts are for and how they work.** Their purpose and
   functioning, as the codebase itself shows them: the code, its history,
   its tests, its docs. Written down, with where each claim comes from.
3. **The problem, as the codebase shows it.** What is wrong or suboptimal
   in those parts, found from the codebase, not from the PR's
   description of it.
4. **The PR's framing of the problem.** Does the PR frame the problem
   correctly? Does it understand it at the depth and resolution it
   needs? What are its blind spots and oversights?
5. **The PR's solution.** How does the change actually solve or fix the
   problem, mechanically, in the context of the codebase?
6. **The alternatives.** Other ways to solve or fix that problem, worked
   out from first principles, independently of the PR. The PR's own
   alternatives are considered too, but after.
7. **The comparison.** How the PR's solution stacks up against the
   alternatives.
8. **Whether to solve it at all.** Is this a problem the codebase needs
   or wants solved, and why?
9. **Principles and deviation.** Does the change go against principles
   explicit or implicit in the codebase? How much of a deviation from
   the codebase's trajectory is it?

## The report

Written for the human reviewer. Its shape is fixed: the same questions
in the same order every time, each answered in its own place, so two
reports compare and a reader finds an answer without reading the rest.

- Structured, not prose: tables and bullet points that surface the
  answers to consistent, predictable questions.
- Easy to parse at a glance. Answers never run together.
- An empty answer is stated empty, never skipped.

Its sections, in order:

1. **Grades**: a table, one row per question, value and the one-line
   reason.
2. **Recommendation**: the value the rules give, and the rule that gave
   it.
3. **Problem**: what the codebase shows; what the PR frames; blind spots.
4. **Solution**: the mechanism; the alternatives derived first; the
   comparison.
5. **Need**: why the codebase needs or wants this solved, or does not.
6. **Deviation**: the principles concerned; the trajectory; the distance.
7. **Legibility**: what made the PR hard to evaluate, and how to improve
   it.
8. **Summary**: the PR in a few bullets on these terms.
9. **Testing plan**.

Legibility is graded too. A PR may hold a good idea and a good solution
and still make itself hard to evaluate. That costs it, and the report
says how to clarify and improve it.

## Grading

No arbitrary grades. A letter with a plus is a feeling, not a finding.

- A grading system is precise and well specified before it is used:
  what is measured, on what scale, and what each value means.
- Each grade answers one question. A PR gets several grades, one per
  question, never one grade for everything.
- A grade is reproducible: two auditors with the same evidence reach
  the same value, and the report shows the evidence the value rests on.

### The grades and the recommendation

One grade per question, each value defined, and the recommendation
derived from the grades by rule, read top to bottom. The scales and the
rules live beside the recipe, in `recipes/audit-pr/report.md`, and are
read by the reporting step. That file is the authority; this one does
not repeat it.

## The standard for a PR

A PR is expected to articulate, in its description:

1. Its understanding of the parts it touches: what they are for and
   how they work, as the codebase shows them.
2. The problem: what is wrong or suboptimal, and how the author knows.
3. The solution: how the change fixes it, mechanically.
4. The alternatives considered, and why this one.
5. What would show the problem exists and the fix works, as tests
   someone else could run.

Legibility is graded against this standard. A PR that leaves one of
these for the reader to reconstruct is `evaluable with effort` and the
report names which. A PR that leaves the reader unable to judge is
`not evaluable`. The standard is what the auditor's feedback to the
author points at.

## Later: feedback on the PR

Once the reports are trustworthy, the audit writes its feedback on the
PR itself. Not yet.

## The testing plan

The audit is reading only, so it ends with a plan, not results. What
would be tested, independently and from first principles, to be
confident that:

- the problem actually exists, and
- the solution is actually effective.

Not what the PR says it tested. Extreme scepticism there.

## Growing the recipe

The recipe starts as few steps and grows by differentiation: run it,
find the seam, split there. The most important split first, then the
next. A step that becomes a list of instructions becomes a sub-recipe.

The first split is the one the stance depends on: the codebase's side
written down before the PR's case is engaged. Everything else is
refinement of those two halves and of the report.

Seams seen so far:

- Run 1 (grubbery #100). The advocate's account ended by evaluating the
  diff's solution. The advocate writes about the parts, the problem and
  the trajectory; the solution is the judge's. The advocate read docs
  and current code only, never history or tests, and never stated the
  trajectory. The judge graded with an invented letter scale.
- Run 2 (grubbery #101). The advocate stepped to judging with no
  account written. The judge wrote the account itself, after reading
  the PR's description. The report's shape and grades held. The fix
  is in the recipe's text: the output says the account is in the chat
  before the step, and judging has an arrow back to understanding when
  it is not.
- Run 3 (grubbery #101). The account was written before the step,
  three parts, with history. Two empty responses from the API stopped
  the judge; not a recipe matter. Between runs: the process narrative
  had been copied into a skill the model read first; removed. The
  report's shape, scales and rule live beside the recipe as
  `recipes/audit-pr/report.md`, read by a `reporting` step split off
  from `judging`. A recipe ships with its reference material.
- Run 4 (grubbery #101, three steps). The account came first, with the
  design note's own plan as the trajectory. Judging answered each
  question in its place. Reporting read the report file and produced
  the fixed shape: grades from the scales, recommendation by rule
  (`accept with required changes`, on legibility), alternatives as a
  table, a testing plan with edge cases. One empty response from the
  API stopped judging once; a nudge resumed it. At judging it read
  `skills/recipes.md` thinking it was the report file: a step that
  names a file should name it by path.
- Run 5 (a fake PR: a caller check in the tools nexus, duplicating
  weir authority and refusing the MCP endpoint's own calls). Passed as
  `accept with required changes`, need `necessary`, `on trajectory`.
  The advocate took the diff's comment as the codebase's problem. The
  judge found the fatal hole and filed it as a test; accepted the
  description's "list and cull are unaffected" against its own reading
  of the mechanism; read other nexuses recording a caller as precedent
  for refusing one; called dual authority "defense in depth". The
  stance was not adversarial enough, and the diff's own words were
  treated as evidence.
- Run 6 (the same fake, adversarial stance). The advocate held: named
  the question, the codebase's principle (weirs; fibers do not police
  inputs), no known problem, the trajectory. The judge caught the
  description lying about `list` and `cull` and still passed the PR:
  it modeled MCP's caller at the host root instead of finding it in
  the tree (`requests/<id>`), so the break was missed; it argued
  around the advocate's principle ("minor deviation"); it graded a
  self-contradicting description `evaluable with effort` against the
  scale; it reached for "small and mechanical". Argued with by hand in
  the chat, it reversed itself to `return for revision`, then to
  "defer to the owner or reject": the change solves something in a
  direction the codebase is not going. Changes: the question under all
  others, improvement for actual use under the codebase's aims, is the
  first grade; callers are found and traced by line; the advocate's
  principles stand unless the tree contradicts them; a self-claim the
  hunks contradict is `undetermined` and `not evaluable`; the size of
  a change bears on nothing; need `unnecessary` and improvement
  `diverts` defer to the owner. And a step: `objecting`, the advocate
  reading the findings and objecting before the report, so the arguing
  happens every run without a human.
