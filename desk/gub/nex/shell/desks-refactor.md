# Desk management under the shell — design & refactor plan

Status: **parked** on branch `shell-desks`. Thinking captured so we can resume
without re-deriving. Branched off `develop` @ d0a10ef.

## Goal

Make the **shell the single locus of desk management**. A desk becomes headless
mechanism; the shell owns install/uninstall, consent, and the management UI.
Mirrors how **forge owns its `/repos`** — a governor over headless managed things
plus one UI, not a UI-per-instance.

## Decisions made (this session)

1. **Desks move under the shell** (containment), like forge/repos. `/apps/X.desk`
   → under the shell. This is the most disruptive, least-logic step → do it LAST.
2. **The desk keeps its version-follow.** Following its source is the desk's job
   (`desk.hoon:124-175`: `keep /ver` on the source's `/code/version.json`, on
   `%news` it snapshots + `sync-release`). Consent stays **reactive** (desk
   self-updates → shell's per-desk watch fires → notify). **Consent-before-update
   is OFF the table for now.**
3. **The shell owns install/uninstall.** The watch on a desk's declarations is set
   up **at install** and torn down **at uninstall** — NOT by a scanner. The scanner
   only exists because apps historically mounted into `/apps` independently, so the
   shell had to *discover* them after the fact. Once the shell installs desks,
   discovery is redundant. (The trigger to watch is the shell's add/remove action,
   not "children passively existing.")
4. **Delete the scanner:** the `/sync` subtree, `sweep.sig`, `spawn-followers`, and
   the poll-on-every-permits-page-load. A per-desk watch (install-scoped) replaces
   the global follower mesh. `build-book`'s own TODO (shell.hoon:2005-2010) already
   says the poll should become pure subscription.
5. **Desk UI → shell.** Strip UI-serving from `desk.hoon`; the shell hosts ONE
   desk-management surface that drives each desk's existing API by slug. The desk
   KEEPS its API endpoints (`/state`, `/tree`, `/cat`, `/source-diff`, fetch,
   snapshot, checkout, compose). The composed *app* a desk runs still serves itself
   — it's the *management* UI that moves, not the product.
6. **Opaque-desk consolidation** (the key abstraction). A desk can hold multiple
   apps/nexuses (`/desk/data/*`), each with its own `weir.json`. Rather than have
   the shell descend into desk internals to watch N sub-weirs, the **desk aggregates
   its internal apps' weir asks into ONE desk-level weir** — the union of what it, as
   a whole, wants to reach — recomputed as it composes/updates. The shell
   watches/gates that single aggregate and **never looks inside**. The desk is a
   black box unit of consent.
   - **Enforcement:** the kernel enforces per-nexus weirs, so after the shell
     approves the desk's aggregate ask, the grant must reach each internal app's
     actual weir. The **desk** does this: shell approves aggregate → writes an
     aggregate grant back to the desk → the desk distributes it to its internal
     apps' weirs. (Moves the per-app `sand:io` from shell into desk.) Shell stays
     out of desk internals in BOTH directions.
   - **Granularity:** consent is at desk level (you approve the *desk*, not each
     app). This is correct, not a compromise — the desk is the unit you install.

## Current shell state (from a full read of shell.hoon, 2553 lines)

- **Already ~80% the installer.** Has `/desks/add` (install a peer's desk),
  `/uninstall`, `/desks/delete`, `ensure-pairing`, `sync-defaults`,
  `discover-desks`/`gather-desks`/`desk-card`, `installed-sources`, `stock-status`,
  `default-repos`. The gap is only that consent reconciliation is decoupled from
  these actions (rides on the scanner's followers).
- **Scanner:** `/sync/<app>` per-app follower grubs + `sweep.sig` coordinator +
  `spawn-followers` over `app-roots` (which descends into `/desk/data/*`). Follower
  self-clean on app-gone (269-290) is where consent removal currently rides —
  indirect and fragile; the `/uninstall` POST only culls the subtree and leaves
  consent to the follower noticing later. (Note: on-load comments mention
  `/sync/main.sig` but the real coordinator is `sweep.sig` — doc/impl gap.)
- **Consent:** `approved.json` (record, `/permit`) + rebuildable caches
  (`/cache/asks|aliases|weirs.json`). `notify-if-unsettled` is the gate
  (`is-settled` vs `approved`, `is-notified` vs `notified.json`, both via
  `asks-match`). `apply-permit-action` dispatches approve/deny/alias-share/suppress.
  `do-approve-weir` total-replaces the target weir via `sand:io`, writes `grant.json`
  into the app sandbox, records `approval-entry`, reloads the app. `build-weirs`
  overlays approvals onto the LIVE weir tagging active/missing/denied/unmanaged.
- **UI:** flat root-level assets (`app.js`, `style.css`, `permits.html`,
  `home.html`, docs) — NOT a `/ui` subdir. Binds `/apps/grubbery` + `/grubbery/tiles`
  (main.sig). All HTTP via the `/requests/<eyre-id>` rail, gated `src == our`.

## Surgery (sequence)

1. **Fold consent-cleanup into `/uninstall` + `/desks/delete`** — drop
   `approved.json`/`notified.json`, rebuild `build-book`/`build-asks`/`build-share`
   right in the handler. Uninstall becomes one explicit transaction.
2. **Fold watch-setup into `/desks/add`** — instantiate the follower logic per-desk
   at install, scoped to the desk's consolidated weir.
3. **Delete the scanner** — `sweep.sig`, `spawn-followers`, `/sync` subtree,
   poll-on-permits-load.
4. **Consolidation** — desk aggregates internal weirs → desk-level weir; shell
   watches/gates that; desk distributes grant to internals. Delete `app-roots`'
   descend-into-desk-internals path (for the weir/consent axis, at least).
5. **Desk UI → shell** — add a `/desks` management page; strip UI from `desk.hoon`.
6. **Location move** — desks under the shell (`/apps/shell.shell/desks/`). Last.

## Open questions (resolve before committing to full opacity)

- **Do aliases / discovery / tiles need per-app granularity, or is desk-level
  aggregation enough?** `read-app-aliases`, `/book` discovery, `read-app-tiles`
  currently descend into desk internals. The weir/consent path can be opaque even if
  discovery/tiles stay per-app — CHECK which genuinely need to see inside a desk.
- **Enforcement distribution:** confirm the desk can `sand` its internal apps' weirs
  (it contains them, so it should be able to).
- **Migration:** relocating desks (`/apps/X.desk` → shell) is real state movement —
  needs a proper migration, not a blow-away (per project policy).

## Not doing (for now)

- Consent-before-update (desk keeps autonomous follow; shell reacts).
- Per-app consent (desk is the unit).
