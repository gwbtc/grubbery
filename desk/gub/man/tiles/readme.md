# Tiles

Customizable launcher grid. Each tile is a JSON file under `/tiles/` with fields: title, info, color, image, href. Edit tiles through the web UI or directly as JSON files.

## Files

- `main.sig` — HTTP binding process. Serves the tile grid UI.
- `page.html` — Rendered tile grid page. Re-rendered on tile changes.

## Directories

- `tiles/` — Tile definitions. Each file is a JSON object with title, info, color, image, href.
- `requests/` — Per-request fibers for HTTP connections.
