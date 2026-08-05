# routes

Draw running, cycling, and driving routes on a map — the
on-the-go-map idea, namespace-flavored.

Click the map to drop waypoints; the route snaps along roads between
them. Routing happens entirely in the browser against public
engines — BRouter for foot and bike, the OSRM demo server for
driving — so the ship never proxies a routing request. Falls back to
straight lines when the engines are unreachable.

Saved routes are grubs, one per route, so each carries its own
version history: re-saving a route revises it in place. GPX export
is client-side.

## Files

- `main.sig` — binds `/grubbery/routes`, dispatches HTTP
- `routes/<slug>.json` — one saved route: name, profile, waypoints, geometry, distance
- `index.html`, `app.js`, `icon.svg`, `tile.json` — web client assets

## Directories

- `routes/` — the saved-route grubs
- `requests/` — transient per-HTTP-request fibers
