# AI — RAG pipeline (NASA fire-safety)

Part of the larger NASA Space Apps project. Self-contained under `ai/`.

## Layout
- `scripts/` — pipeline code
  - `config.py` — paths, Ollama models, tuning knobs
  - `embed.py` — Ollama client (embed + chat)
  - `chunk.py` — page-tagged chunking of `corpus/`
  - `manifest.py` — builds `images/manifest.json`
  - `rag.py` — CLI: `ingest` / `ask`
- `vectors/` — `embeddings.npy` + `chunks.json` (the retrieval index)
- `images/` — extracted figures + `manifest.json`

## Usage
```bash
# 1) build the index (chunk + embed + image manifest)
python ai/scripts/rag.py ingest

# 2) ask a question
python ai/scripts/rag.py ask "how do flames differ in microgravity?"
```

## Image retrieval (dual signal)
- **Proximity** — each chunk and each figure carries `paper NN + page`;
  figures on/near a cited chunk's page become candidates.
- **Content** — each figure has a text `label`; candidates are re-ranked by
  label↔question overlap.

## Models (edit `config.py`)
- embedder: `nomic-embed-text`
- chat: `qwen2.5:3b` (prototype) — upgrade by changing `CHAT_MODEL`.
