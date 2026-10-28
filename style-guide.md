# Grubbery Hoon Style Guide

A style guide for the grubbery codebase, written for LLM-assisted
development. The rules here are established as we work. When a pattern
proves itself in practice it gets recorded here, and from then on all
new and touched code follows it. An LLM working on this codebase should
read this guide first and treat it as binding.

Reference: the official hoon style guide at
`docs.urbit.org/content/hoon/style.md`, and live practice in
`gall.hoon` and `clay.hoon`. Where this guide is silent, follow those.

## Tunneling

Tunneling is the standard this codebase is held to and the method for
evaluating whether it meets it. The goal: one person can move up and
down the codebase and, at every depth, read the code in front of them
completely.

### The standard

- Every unit of code reads at a single abstraction level. At that
  level it presents a decision and the information needed to follow
  it. The detail below is reached through a named helper: a hatch the
  reader chooses to descend through or not.
- When an arm's job is a decision, the switch sits at the surface.
  The cases are visible in the left margin and each case is one line
  into a helper. The reader gets the whole map before descending.
- Logic gets a hatch. Data gets shown. A helper that merely forwards
  to another helper without abstracting anything is a defect, and so
  is an inline literal hidden behind a name when its shape is the
  thing the reader needs to see.
- A helper has one responsibility, a name that says what it does, and
  a position near its callers or its kin, so the next level down is
  where the reader would look for it.

### The evaluation method

Evaluate clarity by reading, not by inspection tools. Start where a
newcomer starts: for a gall agent, the state definition, then the
agent arms in lifecycle order. Read as a fresh reader who knows hoon
but not this codebase. Descend only through hatches: a pass follows
the call graph downward from the surface, and position in the file
means nothing. Do not skip ahead on memory of what the code is
supposed to say.

The first place you stall is the finding. A stall is any of: an
inline body long enough to bury the switch it lives in, a case or
field with no explanation where one is needed, a name that does not
match what the thing does, a comment that hedges or doubts itself,
code that nothing calls. Fix the finding, then start the pass again
from the top.

Fixing is the point. The refactor is the reading: an arm cannot be
reduced to a clean hatch until what is essential in it is understood,
so each pass forces comprehension and leaves the code more legible
than the reader found it. Passes of this kind have surfaced real
bugs, dead code, and unreachable cases in this codebase, because a
reader who refuses to skim notices what inspection misses.

## Comments

### Arm comments

Every arm that deserves documentation gets a comment directly above it
in this form: `::`, two spaces, the arm name with its rune prefix, a
colon, and a one-line lowercase ASCII headline. One bare `::` line sits
below the comment, between it and the code. No bare `::` line sits
above the comment.

```hoon
::  +discharge-peeks: discharge staged peeks whose refs have all arrived
::
++  discharge-peeks
```

If one line is not enough, use the complex form: the headline, a bare
`::` line, then body paragraphs indented four spaces. The body may use
mixed case. Paragraphs are separated by bare `::` lines.

```hoon
::  +discharge-peeks: discharge staged peeks whose refs have all arrived
::
::    Sweeps the staged cross-ship peeks. If every ref a peek's snap
::    names is now in the local silo, the requesting grub can read the
::    content it asked for: it gets its %peek intake and the staged
::    peek is removed.
::
++  discharge-peeks
```

The rule behind the two forms: either the whole explanation fits on
one line, or a long explanation carries a one-line headline above it.
A reader skimming should get the summary from the headline alone.

### Where explanation lives

The full description of an arm lives on its definition. A call site
gets at most a one-line hint saying why this call happens here. A call
site never re-explains what the callee does.

### Comments inside arms

Short comments inside an arm describe the step below them. They follow
the same shape: `::`, two spaces, lowercase text, and a bare `::` line
between the comment and the code below when the comment is more than
one line.

### Plain style

Comments are plain professional English, in ASCII. Short aligned
annotations sit beside type fields and constants; real explanations
get their own lines. Say only what you have verified: if a count or
a cost matters, measure it first or leave it out.

### File headers

A file that has grown large enough to need navigation gets a reading
map at the top: what the file contains, section by section, and the
entry point for each concern. The model is the header of `clay.hoon`,
which tells the reader which arm to start from for each subsystem.
`app/grubbery.hoon` should eventually carry one of these.
