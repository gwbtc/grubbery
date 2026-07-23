# Oneshot Nexus

Playground for one-shot LLM composition. Experimental nexus for building and testing composed one-shot LLM call pipelines. Each call is independent with no chat history. Poke `/main.sig` with `%json` containing system and prompt fields. View UI at `/ui/page.html`.

## Files

- `ver.ud` — Schema version.
- `descs.json` — Mark format descriptions for LLM output constraining.
- `request.json` — Saved request fields (system, prompt, mark, desc).
- `main.sig` — Accepts JSON pokes with system/prompt/mark/desc, runs one-shot call.
