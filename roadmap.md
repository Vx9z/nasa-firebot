# NASA Fire in Freefall — Finish-Line Checklist

> **Status: ~92% toward a competitive submission** (investigations + compare + Gemini swap done).
> The "intelligence layer" — *structure → rank → interpret → compare* — is now built and
> rendered in the CRT UI. Remaining: RAG re-ingest (grounded chat) + API-key rotation.

## What the prompt is actually grading

The challenge verb is: *"create an SI-powered dashboard that **summarizes,
ranks, and interprets** combustion investigations to deliver fire-safety
insights."* It then names concrete things to display:

- Objectives
- Fuels (shape/size)
- Test conditions (O₂%, airflow)
- Variables (how tests within an investigation differed)
- Sensors / types of measurements
- Similarities & differences between investigations
- Relevance to fire safety for crewed environments

## Gap table

| Required capability | Status |
|---|---|
| Summarize an investigation | ✅ done (summary + insight in JSON, rendered in detail view) |
| **Rank** investigations by fire-safety relevance | ✅ done (0–100 rubric, ranked list) |
| **Interpret** → insights | ✅ done (per-investigation "insight" + earth application) |
| Structured attribute extraction (objectives/fuels/conditions/variables/sensors) | ✅ done |
| Compare investigations (similarities/differences) | ✅ done (`/compare` + `c` key) |
| Earth spin-offs (fine-water-mist, smoke detection, firefighter gear) | ✅ done (earth_application field) |
| A "dashboard" of investigations | ✅ done (`/investigate` tile) |
| Grounding pipeline (ingest → retrieve → cite) | ⚠️ ~90% — Gemini swap done; re-embed blocked on free-tier daily quota |
| Presentation layer (tiles, rich markdown, graph, images) | ✅ reusable, good |

The middle **"intelligence" layer** — *structure → rank → interpret → compare* —
is ~5% done, and that's the part worth the most points.

## Why what we have isn't wasted

- **CRT / tiling / markdown / graph** is a genuinely distinctive presentation
  layer — it just needs to display *investigations and insights*, not notes.
- **The RAG pipeline** (chunk/embed/retrieve/cite + figure manifest) is the
  correct grounding layer — it should back a summarizer/ranker/interpreter,
  not be the product itself.

## Shortest path to the finish line (highest impact first)

1. **Structured investigation DB** — a schema per investigation:
   `{id, objective, fuels + geometry, O₂/airflow conditions, variables,
   sensors, hardware, fire-safety area (prevention/detection/suppression)}`.
   Populate from lessons/corpus (LLM-assisted extraction, human-checked).
   *This single artifact unlocks everything else.*

2. **Relevance ranking** — score each investigation against the three pillars
   (prevention/detection/suppression) + crewed-environment applicability +
   data richness. Show a ranked list with reasons. *(Cheap, high points.)*

3. **Investigation summary view** — reuse the rich-markdown tile to render the
   attribute table + a generated "so-what" summary per investigation.

4. **Comparison view** — side-by-side (objectives/conditions/variables/sensors)
   for 2+ investigations, surfacing similarities/differences. ✅ done

5. **Insights / interpretation layer** — grounded, cited "insights" that turn
   data into fire-safety recommendations. (This is where the RAG earns its
   keep as *grounding*, not chat.)

6. **Keep chat secondary** — FireBot stays as an "ask" feature, plus an
   Earth-applications section.

That converts us from "a terminal with a chatbot" into something that actually
answers the prompt.
