# Writing a tool

A tool is one Hoon file that compiles to `tool:tools` (`name`, `description`,
`parameters`, `required`, `handler`). Its name is its file location: the
bijection turns `store/read.hoon` into `store__read`. The name IS the
address.

This is the standard for the two things a caller reads before the code runs:
the **description** and the **schema**. A tool is used by a machine and a
human at once — an AI choosing which tool to call and with what, and a person
reading the same page to understand the surface. Both read the same text. It
has to serve both without either having to decode the other's channel.

## The one rule

**Structure carries every fact it can. Prose carries only what structure
cannot.**

A parameter's type, whether it is required, its allowed values, its default —
these are facts a schema can state exactly. State them in the schema, never in
English. Reserve the description for what no schema field can hold: what the
tool does, when to reach for it, how two parameters interact, what it changes,
and what bites. The machine reads structure precisely and never has to parse a
sentence to learn that a value must be one of three words. The human reads
prose and never has to reverse-engineer intent from a type. Neither channel
repeats the other.

Where the schema *should* hold a fact but the wire format does not yet carry it
(enums and defaults today — see **Gaps** at the end), a fixed convention puts it
in the description in one canonical shape, so a reader and a linter both find it
in the same place every time. That is a stopgap with a known expiry, not a
license to write structure as prose.

## The greater virtue: clarity

Minimalism is a virtue. Clarity is the greater one, and where they conflict,
clarity wins. A description is not scored by how short it is. It is scored by
whether a reader who does not already know this corner of the system comes away
knowing what the tool is for, what it acts on, and how its pieces relate.

So a good description does three things, in whatever length that honestly takes:

- **States the intent.** Not just the mechanical action but the point of it —
  what a caller reaches for this tool *to accomplish*.
- **Names every object it touches, and says what each one is.** A "weir", a
  "desk", a "grub", a "run", a "silo" — name it and explain it in a clause. Do
  not assume the reader can supply the definition. An unexplained noun is a hole
  the reader falls into.
- **Spells out the relationships.** How the objects connect, how one parameter
  conditions another, what order things happen in, what the tool reads versus
  what it changes. Relationships are the part a bare schema can never show, and
  the part a caller most needs.

This does not license padding. Every sentence still earns its place by adding a
fact the reader needs. The test is not "is this short" but "could a competent
stranger mis-call this tool after reading it" — if yes, it is too sparse,
whatever its length.

**The bar is "understood at a glance," not "self-contained."** Some concepts are
too large to redefine in every tool that touches them — a whole subsystem's data
model, the weir system, how the namespace addresses grubs. Fully inlining them
would bury the tool in a treatise. Use judgment: explain the small thing inline,
and for the large one, name it precisely and point to where it is defined — the
nexus's readme, a sibling tool, a named design doc. A reader who needs the depth
knows where to go; a reader skimming gets the shape without drowning. Reaching
for a reference is right only when inlining would genuinely overwhelm the tool;
it is not an excuse to leave an ordinary object unexplained.

Explaining how parameters relate is not the same as mechanically re-typing the
schema table. Restating "`path` (string): the path" adds nothing and is noise.
Explaining that "`old_string` must match a unique run of text in the file the
`path` names, or the edit refuses" is a relationship, and belongs in the prose.

## The name

- `verb_noun`, lowercase, underscores: `read_grub`, `add_weir`, `commit`.
- The verb is the action the tool takes, from the caller's side. `get_`, `list_`,
  `read_` for reads; `add_`, `create_`, `delete_`, `poke_` for writes.
- The name is the file path. Group by placing files in directories, not by
  prefixing names: `store/upload.hoon` over `store_upload.hoon` where a
  directory exists. The name disambiguates; the directory groups.

## The description

One `@t`. Read top to bottom, it answers, in order. Take the length each
answer honestly needs; do not pad, do not starve.

1. **What it does, and to what** — a declarative sentence, present tense, naming
   the action and its object. This first line stands alone: it is the only text
   shown in the tool list, so it must make sense with nothing else on screen. No
   "This tool…", no restating the name.

   > Commit a mounted desk and return version info with logs.

2. **The objects, named and explained** — every domain object the tool touches
   that a caller might not already know: what a weir is, what a run grub is, what
   a silo holds. One clause each is often enough, but say it. An unexplained
   noun is where a caller goes wrong.

3. **When to use it, and when not** — when a caller could reasonably pick the
   wrong tool. Name the sibling it is confused with and the distinction.

4. **What it reads, changes, and returns** — the side effects and the shape of
   the result. A read says what it reads back; a write says what moved, and
   whether it is reversible. "Returns the new version number" is worth a clause;
   "returns a string" is not.

5. **How the pieces relate, and the gotchas** — how parameters condition each
   other, what order things happen in, the precondition (the desk must be
   mounted first), the surprising limit. This is the load-bearing part; a schema
   can never show it.

Steps 3–5 apply as the tool warrants: a genuinely trivial tool (`echo`,
`get_ship`) is done at step 1, and forcing the rest on it would be padding. The
bar is not length, it is that a competent stranger could not mis-call the tool
after reading. If they could, it is too sparse — add the missing object or
relationship, however many lines that takes.

Explaining how the parameters relate belongs here. Mechanically re-typing the
schema table (`path` — the path) does not: that is noise, and the schema already
carries it.

## The parameters

Each parameter is a `type` and a `description`. Get both right.

**Type.** Use the type that matches the value:

- `%boolean` for a flag. Never a `%string` of `"true"`/`"false"`.
- `%number` for a count, duration, index, amount.
- `%string` for text, paths, names, ids, dates-as-text.
- `%array` / `%object` for structured input, with the shape given in the
  description (the wire format does not yet carry nested schema — see **Gaps**).

A `%string` that only ever holds a number, a yes/no, or one of a fixed set of
words is the most common defect in the corpus. Fix the type.

**Required.** A parameter the tool cannot run without goes in `required`. Never
signal requiredness only by writing "required" in the description, and never
mark a parameter required when the handler supplies a default for it.

**Description.** Says what the value *is*, its role in the tool, its format, and
an example in the exact form the handler parses. A phrase is fine when a phrase
is unambiguous; use a full sentence, or two, when the value's role or its
relationship to other parameters needs explaining:

  > Directory to add the rule to, an absolute path (e.g. `/apps/example`). The
  > rule's reach is relative to this directory when `steps_up` is set.

Rules for it:

- Lead with the meaning, not the type. The type is already structured; do not
  open with "A string that…".
- Explain the role, not just the label. If the value only makes sense in terms
  of another parameter or a domain object, say how they connect. That
  relationship is the whole reason the description exists.
- Give an example whenever the format is not self-evident, and make the example
  parse. A date example must be in the format the tool reads
  (`~2026.7.21..18.30.00`), not a friendly gloss. Give more than one when the
  values differ in kind and one would mislead.
- If a parameter needs a paragraph to explain, that is a signal to check whether
  it is doing too much — but a genuinely rich parameter gets the words it needs.
  Clarity first.

## Conditional parameters

Some tools are genuinely polymorphic: a `kind` (or `mode`) parameter selects
between variants, and each variant uses a different set of the other fields.
This is the hard case, because the schema has no `oneOf`. Handle it in two
places, consistently:

- **In the tool description**, name the modes and which fields each one uses, as
  a short list. This is the map the caller reads first.
- **On each conditional parameter**, prefix the description with the mode tag it
  belongs to, always the same tag (`<mode>:`), so a caller scanning the schema
  can tell at a glance which fields apply to their mode.

Prefer splitting into separate tools when the modes barely overlap. One
polymorphic tool is justified only when the modes share most of their fields and
their result.

## Anti-patterns

Drawn from real tools, before their fixes:

- **Everything is a `%string`.** `road_type` holds only `dir` or `file` — an
  enum. `steps_up` holds `"1"`, `"0"` — a number. Typing them as strings pushes
  the real contract into prose the machine has to parse back out.
- **Type or default smuggled into prose.** `Timeout in seconds (default: 30)` on
  a `%number`: the default is a fact for the schema, parked in English because
  the schema has nowhere to put it yet. Use the canonical `(default: N)` form
  (see **Gaps**) so it is at least always in the same place.
- **Enum smuggled into prose.** `Categories: write, poke, read` in the tool
  description is the schema of a parameter, written as a sentence. Its home is
  the `category` parameter, as an enum, in canonical form.
- **The description re-lists the parameters.** Two sources of truth that drift.
  Delete the copy in the description.

## Canonical interim forms

Until the schema carries these structurally, write them exactly this way, at the
end of the parameter's description, so both a human and a linter find them:

- **Enum:** ` One of: write | poke | read.` (values pipe-separated, no quotes.)
- **Default:** ` (default: 30)` for the value used when the parameter is omitted.
- **Both:** ` One of: dir | file (default: dir).`

## Gaps

The wire format (`tool-schema` in `nex/tools.hoon`, `tool-json` in `nex/mcp.hoon`)
emits only `type` and `description` per parameter. Enums, defaults, and nested
array/object shape therefore have no structural home and live in the description
by the canonical forms above. When the schema grows an `enum` and `default`
field and the serializers emit them, this section retires and the canonical
forms move into structure. The standard above is written to that target: follow
it and the migration is mechanical.
