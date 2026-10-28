# The audit report

One page. It tells the human reviewer everything needed to evaluate the
PR, and where to look for more. It is a summary, limited on purpose: the
findings in the chat hold the full reasoning, and the report points at
them and at the code rather than repeating them.

- The same sections in the same order every time, so two reports
  compare and a reader finds an answer without reading the rest.
- Tables and bullets. No paragraphs. Answers never run together.
- Each section is a few lines. The whole report fits on one page.
- Every claim that rests on code points at it: `file:line`. A claim
  that rests on a finding points at the finding.
- An empty answer is stated empty, never skipped.

## Sections, in order

1. **Grades**: one table, one row per question: the value, the one-line
   reason, where to look.
2. **Recommendation**: the value and the rule that gave it, one line.
   Required changes, if any, as bullets: each one sentence.
3. **The problem**: three bullets at most: what the codebase shows,
   what the PR frames, the blind spots.
4. **The solution**: the mechanism in one or two bullets; the callers
   traced, one line each, pass or break; then a table of the
   alternatives, one line each, with the verdict.
5. **Improvement, need and deviation**: three bullets: whether and how
   the change improves the codebase for actual use; why the codebase
   needs or wants it, or does not; the trajectory and the distance
   from it.
6. **Legibility**: one bullet on what the reader had to reconstruct and
   how the author should fix it, or `nothing`.
7. **Testing plan**: bullets, each one test, each one line: what is
   done and what is observed. Independent of what the PR says it
   tested.
8. **Where to look**: the files and lines that decide the case, and the
   account, findings and objections in the chat.

## The grades

One per question. No other grades. Each value is defined; the report
states the value and points at the evidence it rests on. The first is
the question under all the others.

| question | scale |
|---|---|
| improvement | `improves`: the codebase is better for actual use, under its aims and purpose, with this change. `neutral`: nothing the codebase is for changes. `diverts`: it solves something in a direction the codebase is not going, or with a mechanism the codebase's principles exclude. `degrades`: the codebase is worse for actual use with it, or something that works stops working. |
| problem identification | `correct`: the problem the PR names is the problem the codebase shows, at the depth the fix needs. `partial`: the right problem, with a blind spot or missing depth the report names. `incorrect`: the problem named is not what the codebase shows. `absent`: no problem is stated. |
| solution effectiveness | `effective`: the mechanism solves the problem as the codebase shows it and breaks no caller or path the report can name. `effective with gaps`: it solves it and leaves a gap the report names. `ineffective`: it does not solve it, or it breaks a caller or path the report names. `undetermined`: reading cannot tell, including when a claim the PR makes about itself is contradicted by its hunks. |
| comparison with alternatives | `preferable`: better than each alternative the judge derived, with the reason. `equivalent`: as good as the best alternative. `inferior`: an alternative the judge derived is better, named. |
| need | `necessary`: the codebase cannot proceed on its trajectory without this solved. `beneficial`: the codebase is better with it solved. `unnecessary`: solving it changes nothing the codebase needs. `harmful`: solving it works against the codebase. |
| deviation | `on trajectory`: the change is the codebase's predictable next state. `minor deviation`: off the trajectory in a way that is contained and named. `major deviation`: a change of direction for a part of the codebase. `contradiction`: against a principle the codebase states or consistently applies; a second mechanism for a question the codebase already answers with one is this, whatever the PR calls it. |
| legibility | Against the standard: a PR articulates its understanding of the parts it touches, the problem and how the author knows, the solution mechanically, the alternatives considered, and tests someone else could run. `evaluable`: all five are there and true to the hunks. `evaluable with effort`: one or more is left for the reader to reconstruct, and the report names which. `not evaluable`: the PR cannot be judged without work the author should have done, or a claim it makes about itself is contradicted by its hunks. |

## The recommendation

Derived from the grades by rule, never chosen. The size or ease of a
change bears on nothing. The rules are read top to bottom; the first
that applies is the recommendation.

| recommendation | when |
|---|---|
| `reject` | improvement `degrades`; or problem `incorrect` or `absent`; or solution `ineffective`; or need `harmful`; or deviation `contradiction` |
| `return for revision` | otherwise, when solution `undetermined`, or legibility `not evaluable`, or problem `partial` with a blind spot that bears on the fix |
| `defer to the owner` | otherwise, when improvement `diverts`, or need `unnecessary`, or deviation `major deviation`: a change of direction, or a change the codebase did not need, is the owner's decision, not the auditor's |
| `accept with required changes` | otherwise, when solution `effective with gaps`, or comparison `inferior`, or deviation `minor deviation`, or legibility `evaluable with effort` |
| `accept` | every grade at its best value |
