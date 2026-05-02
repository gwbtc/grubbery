# Understanding Grubbery

## What I think I know

- Grubbery is a Gall agent that provides a runtime for nested programs
- The ball is the filesystem: `(axal lump)`, a tree of directories containing files
- Files hold typed content (sage = blot + vase)
- Directories can have a neck that identifies which nexus code governs them
- A nexus is code with three arms: on-load (init), on-file (spawn processes), on-manu (docs)
- Files can have fiber processes attached — monadic event loops using `;<` bind
- Fibers communicate by emitting darts (effects) that route through the tree
- The loader declaratively sets up directory structure in on-load
- Weirs are sandbox rules on directories that can block darts
- Code namespaces (neck `[/ %code]`) get compiled by the build system

## Open questions

1. When a nexus "governs" a directory, does it intercept all operations on that subtree, or just initialize structure and spawn processes?

## Answers

1. A nexus governs a directory in three ways:
   - **on-file (primary):** Determines which fiber process runs at each grub (file) in the subtree. Every grub has exactly one sequential monadic process. The fiber takes input, returns effects (darts), a new state, and a continuation function. The nearest parent nexus decides which fiber runs at each file — this is the most fundamental meaning of "governs."
   - **on-load:** Can reload everything beneath it. Typically triggered when its code changes or an ancestor's code changes. Can also be manually triggered.
   - **on-manu:** Defines per-file and per-directory documentation explaining what each part of the namespace does.

   Key clarification: a nexus does NOT intercept operations. It determines what code runs at each file, can reload, and provides docs.

## Revised understanding

- A grub is a file in the namespace — it is both a typed piece of data (a vase: type+noun pair, with a mark name) AND a running fiber process. These are two aspects of one thing, not separate.
- The nexus's primary role is deciding which fiber runs at each grub. It's a dispatch table, not a mediator.
- Reload cascades: when code changes, nexuses reload, which can cascade downward.

## Open questions

2. **The file IS the fiber's state.** The sage (typed content) at a grub is the state that the fiber manipulates. The continuation (the function waiting for next input) is stored separately by the runtime. But the persistent, visible data in the namespace is the fiber's state — they are the same thing.

3. **Dart routing walks the tree literally.** `process-dart` in grubbery.hoon:
   - Resolves the dart's destination to an absolute lane
   - Finds the "governor" — the nearest directory strictly ABOVE both source and destination (the neutral authority over both)
   - Walks UP from the source to the governor, checking the weir at each directory along the way. Any weir that blocks the dart's destination → veto (sent back to source as `%veto` intake)
   - The governor's own weir is NOT checked (you reach it, not pass through)
   - Downward movement from governor to destination is always free
   - For syscalls (dest=~), there is no governor — walk all the way to root, and any weir blocks it
   - If a weir allows but the dart crosses a sandbox boundary, vases get clammed (type-checked)

   Code: `++nearest-governor` (lines 2234-2251), `++allowed` (lines 2253-2273), `++process-dart` (lines 1475-1494)

4. **Code lookup walks up to find the nearest `/code` sibling.**
   - When a grub needs its process, `build-spool` calls `find-nearest-nexus` which walks UP the ball to find the nearest directory with a neck — that's the governing nexus.
   - To compile/find that nexus's code, `build-nexus` uses `find-code-ns` which walks UP from the grub's location, checking at each ancestor whether there's an immediate child directory called `code` in the compiled code map.
   - The first `/code` found is the governing code namespace. It's hermetic: if it doesn't have the artifact, grubbery returns `~` rather than falling back to a parent namespace.
   - So: neck `[/claw %agent]` → find nearest `/code` → look for compiled `/nex/claw/agent.hoon` in that namespace.

   Code: `++find-nearest-nexus` (1445), `++build-spool` (1458), `++find-code-ns` (608), `++seek-built` (620)

5. **The pool mirrors the ball — it holds process state.**
   - `pool = (axal pipe)` — same tree shape as the ball
   - `pipe = [bang=(unit tang) proc=(map @ta proc:fiber)]` — per-directory process info
   - `proc` maps filename → fiber process state (continuation + input queues), mirroring how `lump.contents` maps filename → content
   - `bang` is an optional crash trace for the directory node itself
   - So ball holds data, pool holds processes. One-to-one: every grub in the ball has a corresponding process entry in the pool.

   The fiber continuation (the function waiting for next input) lives in the pool, while the fiber's state (the vase it manipulates) lives in the ball as the file's sage. Two halves of the same grub.

6. **Bang exists at two levels:**
   - **Process-level:** Each fiber's `process` field is `(each process tang)`. When a fiber crashes, the continuation is replaced with `|+tang` (the crash trace). The process is dead, queued inputs sit idle. Healing is implicit — a successful respawn overwrites `|+tang` with `&+process`.
   - **Nexus-level (directory):** `pipe.bang = (unit tang)`. Set by `++bang-nexus` when nexus code itself fails (e.g. on-load crashes during reload). This cascades: every file underneath gets banged, all processes replaced with `+stay` (frozen). The whole subtree is down.
   - **Querying:** `%bang` dart on a directory returns `[directory-bang (map filename (unit tang))]`. On a file, returns just that file's crash trace.
   - **Healing:** Nexus-level is explicit — `clear-bangs-under` wipes all bangs before reload attempt, then anything that still fails gets re-banged.

7. **Born = version counters. Silo = content-addressed history store.**

   **Born** `(axal [tote bags])` mirrors the ball structure with monotonic counters. Never deleted, even when grubs are deleted.
   - Per-directory (tote): `[weir=cass fold=cass]`
     - `weir` bumps on weir change
     - `fold` bumps when ANY descendant changes (propagates up to root)
   - Per-file (sack in bags): `[proc=cass life=cass file=cass hist=mop]`
     - `proc` bumps on process spawn/restart
     - `life` bumps on grub creation (survives deletion — tracks reincarnation)
     - `file` bumps on content change
     - `hist` is ordered map: cass → lobe (hash into silo)
   - These counters are the basis for the subscription system. The runtime snapshots born before mutations, diffs old vs new after, and sends `%news` intakes to subscribers watching changed lanes. Fibers never touch born directly — they `%keep` (subscribe) and receive `%news` (updates).

   **Silo** `(map lobe [refs=@ud bask])` — content-addressed object store.
   - `lobe = @uvI` from `+sham` (hash of content)
   - `bask = [blot noun]` — typed content without vase overhead
   - Refcounted: `refs` tracks how many hist entries point here; drops to 0 → deleted
   - Connection: file changes with gain enabled → content hashed into silo → hist in born gets `cass → lobe` entry → look up any version by cass → lobe → bask

8. **Grubbery relates to Clay the same way any Gall agent relates to its desk.**
   - Grubbery's own source code lives in Clay on the grubbery desk (at `gub/`)
   - It listens to `gub/` and populates its root `/code` nexus with those files — that's how nexus source, libraries, marks etc. get compiled
   - Beyond that, the grubbery namespace is entirely separate from Clay. Different filesystem, different application model. Clay stores grubbery's code; grubbery runs its own world.

9. **Subscriptions from the fiber's perspective:**
   - `keep:io wire road mark` → sends `%keep` dart, receives `%bond` intake (ack + initial view of the target)
   - `take-news:io wire` → waits for `%news` intake (updated view when target changes)
   - `drop:io wire road` → sends `%drop` dart, receives `%fell` intake (unsubscribe confirmed)
   - `%fell` can also arrive unsolicited if the watched target is deleted or a weir change breaks the subscription
   - Under the hood: the runtime diffs born before/after mutations, finds changed lanes, matches against subscriber registrations in `subs`, and delivers `%news` intakes

10. **What grubbery is for:**

   The core idea: take the benefits of asynchronous monadic processes (composable, sequential, effect-driven) and give them state that lives in a hierarchical namespace.

   A Gall agent is one flat process managing one blob of state. If you want many concurrent concerns, you have to multiplex them yourself — dispatch on wires, manage substates, handle interleaving. It gets complex fast.

   Grubbery solves this by putting processes in a tree. Each file is a process with its own state. The tree structure lets you:
   - **Decompose granularly:** break a complex system into many small processes, each managing one file
   - **Group by concern:** directories organize related processes together
   - **Govern by code:** nexuses let different code control different subtrees — the counter nexus doesn't know or care about the wallet nexus
   - **Sandbox naturally:** weirs restrict what parts of the tree a process can reach, and the restriction follows the tree structure itself
   - **Subscribe structurally:** watch any file or directory for changes, because everything has a path

   The namespace IS the architecture. Instead of designing internal data structures to organize your application, you organize it as a filesystem where every node is live.

11. **Sand and gain are separate because they're policy, not data.**
   - Ball = pure data (files, content, directory structure)
   - Sand = sandbox policy (weirs at each directory)
   - Gain = history policy (which files track versions)
   - Separating them keeps the ball clean — it's just content. Policy is orthogonal.
   - All three are passed through on-load together: `|= [=sand =gain =ball]`

12. **`seen = (each view tang)` — view or error. That's it.**
   - `%peek` can fail, so it returns `seen`
   - Subscriptions deliver `view` directly (already successfully subscribed)
   - `view` itself is a complete snapshot of a node:
     - `%ball` (directory): includes sand, gain, born, and the full subtree ball
     - `%file`: includes sack (version info), gain flag, and sage (content)
     - `%none`: nothing at that path
   - So views carry policy and version info alongside content, not just raw data

13. **Reload cascade: top-down restructure, then respawn everything.**
   1. `reload-nexus-at`: clear all bangs under this nexus, run on-load (may restructure the entire subtree), validate marks, write back ball/sand/gain
   2. `reload-child-nexuses`: walk children, find directories with necks (skip `/code`), build their nexus code, `reload-nexus-at` each one — top-down recursion
   3. After the full tree restructures, `spawn-all-files` walks every file and spawns its fiber with `[%load ~]` prod
   - During reload, everything is just state. All processes are dead. The tree is purely data being restructured by on-loads. Once the dust settles, every grub gets a fresh process.
   - If on-load crashes → bang the nexus, stay all processes underneath (they're frozen with the crash trace)
   - Fibers receive `%load` prod on spawn so they know they're resuming from a reload (vs `%make` for new creation)

14. **Marks/blots are simple.**
   - Blot = a rail used as a type identity: `[/ %json]`, `[/wallet %account]`
   - Marc = compiled mark core with three arms: `vale` (validate noun → vase), `grow` (outbound conversion to another blot), `grab` (inbound conversion from another blot)
   - Source lives in `/mar/` in code namespaces. Blot `[/wallet %account]` → `/mar/wallet/account.hoon`
   - Conversion: try `grow` on source marc first, fall back to `grab` on target marc
   - Runtime validates content through marc `vale` on write. Some marks hardcoded for bootstrap (hoon, mime, tang, boom, kelvin)

15. **`make` = create a thing.**
   - `(each [sand gain ball] [gain=? sage mark=(unit mark)])`
   - Left: create a directory (with policy + data subtree)
   - Right: create a file (with gain flag, typed content, optional mark conversion on write)

16. **The seven parallel structures, all keyed by the namespace:**
   - Ball = data tree
   - Pool = process tree
   - Born = version counter tree (never deleted)
   - Sand = weir policy tree
   - Gain = history policy tree
   - Silo = content-addressed store for historical versions
   - Code = compiled artifacts per code namespace

17. **Claw architecture in grubbery terms:**

   **claw/app** (`app.hoon`) — the container nexus at `/claw.claw_app/`:
   - Creates agent instances in `/agents/` and channel instances in `/channels/`
   - Runs the Anthropic API proxy at `/apis/anthropic.sig` (adds API key, forwards HTTP)
   - Sets a **weir** on each agent instance:
     - `make = ~` → cannot create/delete OUTSIDE its own subtree
     - `poke = [/sys/bowl, ../../apis]` → can only poke system bowl and the API proxy
     - `peek = [/]` → can READ the entire tree (full read access)
   - This means agents are sandboxed: full read, write only within self, poke only the API proxy

   **claw/agent** (`agent.hoon`) — the AI agent nexus:
   - Manages conversations, tools, LLM interaction
   - Tools run as sub-fibers at `/tools/{tid}/` — one level below agent root
   - `agent-road` helper adjusts relative paths so tools resolve from agent root, not tool dir
   - The main loop: assemble conversation (prompts + history), send to API via proxy, dispatch tool calls to tool fibers, append results, loop
   - Agent can spawn children in `./children/` (within its subtree, so weir allows it)
   - Agent can build code in `./content/code/` (its own code namespace)

   **What the AI CAN do:**
   - Read/write files in its own subtree
   - Read files anywhere in the ball (full peek access)
   - Build and compile code in its code namespace
   - Create child nexuses within `./children/`
   - Call the Anthropic API via the proxy
   - Write dynamic tools

   **What the AI CANNOT do:**
   - Write/create files outside its subtree
   - Poke processes outside its subtree (except the API proxy)
   - Modify other agents or system nexuses
   - Access the API key directly (the proxy holds it)

18. **How the AI is intended to use grubbery:**

   Two separate directories, two separate concerns:

   **`./apps/`** — the AI's application space.
   - `./apps/code/` — source code: nexus definitions, libraries, marks, tools
   - `./apps/my-thing/` — running nexus instances (created via create_nexus)
   - This is where the AI builds programs. Write code, compile, instantiate, build tool interfaces.

   **`./children/`** — sub-agents for task delegation.
   - spawn_task creates temporary claw agent instances here
   - These are other AIs handling subtasks, NOT custom applications

   Key constraints:
   - The AI NEVER modifies its own nexus code — that's authored by the developer, compiled in the parent code namespace, and governs from above
   - Channels (`/channels/`) are a claw app concern (external chat interfaces), not the AI's
   - Nothing outlives the agent instance — everything is scoped to its subtree

## Remaining gaps
