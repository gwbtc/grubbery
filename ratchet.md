# Grubbery Next Ratchet

Seven changes that unblock the next level of capability.

## 1. Usergroup Namespace Registration

Minor refactor to usergroups. Two new patterns:

- **Namespace-scoped write access**: parts of the namespace can grant write access to usergroups that are "registered to" that namespace region. The namespace itself controls which usergroups can write to it.

- **Cross-app usergroup registration**: apps can register paths under usergroups managed by other apps. This lets one app (e.g. contacts) own the usergroup membership, while another app (e.g. itinerary) registers its paths under that group for access control.

Enables: shared namespaces, collaborative apps, delegation without duplication of group management.

## 2. Eliminate All Type-of-Type Data ✓

`take` now uses `pend` (cold) instead of `intake` (hot). Queued inputs store `bask` (blot + noun) instead of `sage` (blot + vase). Types are resolved at consumption time via `++hydrate`. State migration %0→%1 landed — only `pool` resets; everything else carries over.

Silo was already clean: content-addressed nouns + ject metadata with ckey references into bins. No vases stored.

## 3. Cross-Ship Code Installation with Migration Safety

New pattern for cross-ship code nexus installation:

- Each reload **commits** the namespace state, creating a snapshot before the new code runs its migration.

- This means you can **check out old versions** of both the namespace (data) and the code, so if a migration goes wrong, you can re-attempt it from the old data with fixed code.

- Creates a forgiving migration environment: migrations become retryable, not one-shot. You always have the pre-migration snapshot to fall back to.

Enables: safe cross-ship app distribution, fearless upgrades, iterative migration development.

## 4. Extract Experimental Nexuses to Separate Repos

Move nexuses that aren't core grubbery (itinerary, wallet, telegram, etc.) out of the main grubbery repo and into their own repos. Each becomes an independently distributed package.

Near-term: distribute these from within grubbery itself, served from a groundwire ship. The grubbery becomes its own app distribution channel — install a nexus by pointing your ship at another ship that has it.

Decouples nexus development velocity from core grubbery releases. Lets third parties build and distribute nexuses without touching the main repo.

## 5. Standard Weirs for /apps/

Provide a sensible default weir set for nexuses installed under `/apps/`. The standard weirs prevent apps from writing to the root, `/sys`, or other apps' namespaces, but are otherwise permissive for peeks and pokes, and allow writes to `/docs`. This is just basic hygiene — a trivially overridable default, not a hard sandbox. Privileged nexuses like the explorer will likely run with broader permissions. The point is that a newly installed app shouldn't be able to accidentally clobber things it has no business touching.

## 6. Cross-Ship Code Registers in Tiles

When a nexus is installed cross-ship, it should be able to register itself in the tiles launcher interface. The installed code declares its tile metadata (title, color, icon, href) and the tiles nexus picks it up automatically.

This closes the UX loop: install a nexus from another ship → it appears in your launcher → you can use it. No manual tile creation, no separate configuration step. Apps become first-class citizens on arrival.

## 7. Obelisk on Grubbery

Talk to Jack Fox about porting Obelisk to grubbery. Should be incredibly easy to port — Lattice already uses it (not fundamental to what Lattice does, but it fits in naturally).

---

**Prerequisite assumption**: the grubbery runtime — in particular its core data structures — needs to have stabilized to the point where they change extremely infrequently, and special care can be given to each migration. This was not the case up until now, but will be after these changes land.
