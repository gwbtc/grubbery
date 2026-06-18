# Goals Nexus

DAG-based goal tracking with web UI. Manages goal stores, each containing a directed acyclic graph of goals. Page at `/grubbery/api/peek/goals.goals/page.html?mark=mime`.

## Files

- `main.sig` — Store management + JSON action routing.
- `page.html` — Server-rendered goal view (manx).

## Directories

- `store/` — Goal stores. Each file is an independent goal collection.
