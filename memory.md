# 🚀 NASA Space Apps — Project Context & Memory

> Session-continuity notes. You = **V** · Me = **C** (Cline)

## 🎯 Challenge

- **Event:** NASA Space Apps Hackathon
- **Team:** Jellyfire
- **Challenge:** Flame in Freefall — AI-Powered Fire Safety Insights from Microgravity Combustion Data
- **Deliverable:** Interactive, AI-powered dashboard that summarizes, ranks & interprets
  NASA microgravity-combustion findings → fire-safety insights for Moon→Mars exploration.
- **Pain point:** Decades of data, but hard to find / compare / understand.

## 📂 Project Files

| File | Purpose | Status |
|------|---------|--------|
| `01_Overview of Microgravity Combustion.pdf` | Source paper (NASA TM-107353) | ✅ read |
| `Documentation.docx` | Challenge brief | ✅ read |
| `Participant FAQs.pdf` | Hackathon logistics | ⬜ not yet read |
| `Team Banner.png` | Team banner | ⬜ unused |

## 📄 Key Source — NASA TM-107353

- **Title:** Overview of Microgravity Combustion Research at NASA Lewis Research Center and its Potential Commercial Impact
- **Authors:** Valerie Lyons & Robert Friedman · **Date:** Nov 1996 · **Pages:** 8
- **Core idea:** Microgravity removes buoyant flows → simplifies combustion → isolates hidden phenomena.

**Four application areas:**
1. **Fire Safety** — microgravity fire scenarios (overheating from reduced air cooling, persistent aerosol/fluid-leak hazards, smoldering), material flammability that can exceed normal gravity, fire-detection "signatures," smoke detector/alarm criteria, Halon-1301/CO₂ suppression + halon-replacement & water-mist research.
2. **Combustors** — emission reduction (NOx, CO, soot, unburned hydrocarbons), supercritical droplet combustion for rocket/aircraft engines, lean-burn burner (patent 5,516,280).
3. **Sensors & Controls** — non-perturbing rapid diagnostics (flame appearance/velocity/temperature/species), image enhancement, line-absorption spectroscopy → industrial smoke analyzer.
4. **Advanced Materials** — combustion / self-propagating high-temperature synthesis (SHS) for ceramics, intermetallics, fullerenes.

## 🔬 Reputable Sources

| Source | URL | Use |
|--------|-----|-----|
| NASA Technical Reports Server (NTRS) | https://ntrs.nasa.gov | Literature search + full-text PDFs |
| NASA Physical Sciences Informatics (PSI) | https://psi.nasa.gov | Open ISS combustion experiment data |
| NASA Science — Physical Sciences | https://science.nasa.gov/physical-sciences/ | Program overview + 6 disciplines |
| NASA Glenn Research Center | https://www.nasa.gov/glenn/ | Combustion & fluids research |
| NIST (Nat. Inst. Standards & Tech.) | https://www.nist.gov | Fire detection & smoke/aerosol science (feeds spacecraft work) |
| ESA — European Space Agency | https://www.esa.int | Microgravity combustion (parabolic flights, Columbus/ISS) |
| JAXA — Japan | https://global.jaxa.jp | ISS Kibo combustion experiments |
| CNSA / CAS — China | varies | Tiangong Space Station combustion rack; CAS English journals |
| ISRO — India | https://www.isro.gov.in | Sounding-rocket microgravity work |
| Roscosmos — Russia | varies | Historical Mir/ISS combustion (less open now) |

**Key journals:** `Microgravity Science & Technology`, `npj Microgravity` (open access), `Combustion and Flame`, `Proceedings of the Combustion Institute`, `Fire Safety Journal`, `Combustion Science and Technology`.

## 🗺️ Research Roadmap (literature-first)

Build a knowledge **tree/graph with references**, *then* abstract into the app.

1. **Layer 0 — Foundations:** fire/combustion basics, flame anatomy, heat transfer, buoyancy ↔ pressure/density.
2. **Layer 1 — Microgravity combustion:** no-buoyancy transport, flame shape/color/temp, droplet combustion, soot differences, smoldering, kinetics.
3. **Layer 2 — Fire safety (app target):** detection, suppression/extinguishers, materials flammability, spacecraft scenarios, Moon/Mars.

## 📁 Directory Structure

- `memory.md` — this file (context, sources, roadmap, progress)
- `literature/` — downloaded full-text papers (PDFs) + bibliography
- `knowledge/` — info tree nodes with references (`0-foundations/`, `1-microgravity/`, `2-fire-safety/`)
- `data/` — fire/combustion **history** + **test/experiment datasets**
  - `data/history/` — incident history (Shuttle, etc.)
  - `data/datasets/` — raw experiment/test data (PSI, etc.)

## 📖 Reading Roadmap (bottom-up comprehension)

Read order = **`NN Title year serial`**, matching the filenames in `literature/` exactly. Foundations → microgravity physics → fire safety → exploration.

### Tier 0 — Foundations (01–13)
- [ ] `01` Skylab M-479 Zero-Gravity Flammability 1974 19740021777
- [ ] `02` Priorities for Microgravity Combustion Research 1993 19930010997
- [ ] `03` Microgravity Combustion Science 1995 Program Update 1995 19950017584
- [ ] `04` NASA Microgravity Combustion Program 1997 19970020548
- [ ] `05` Selected Diagnostics for Microgravity Combustion 1997 19970020591
- [ ] `06` NASA Microgravity Combustion Program 1999 19990053966
- [ ] `07` NASA Microgravity Combustion Program 2015 20150023100
- [ ] `08` 2nd Intl Microgravity Combustion Workshop 1993 19930010989
- [ ] `09` 3rd Intl Microgravity Combustion Workshop 1995 19960008386
- [ ] `10` 4th Intl Microgravity Combustion Workshop 1997 19970020547
- [ ] `11` 5th Intl Microgravity Combustion Workshop 1999 19990053965
- [ ] `12` 6th Intl Microgravity Combustion Workshop 2001 20010073993
- [ ] `13` 7th Intl Microgravity Combustion Workshop 2003 20040053504

### Tier 1 — Microgravity combustion physics (14–27)
- [ ] `14` Overview of Microgravity Combustion Research 1996 TM-107353 ← start here
- [ ] `15` SIBAL Solid Inflammability Boundary 1999 19990053968
- [ ] `16` Microgravity Smoldering Combustion USML-1 2003 20030075804
- [ ] `17` JAXA Droplet and Array Combustion 1995 19960008398
- [ ] `18` FLEX A Decisive Step Forward 2012 20120015928
- [ ] `19` FLEX MDCA Flame Extinguishment 2009 20090014812
- [ ] `20` FLEX Detailed Results 2015 20150023456
- [ ] `21` Cup-Burner Flame Extinguishment 2004 20040142357
- [ ] `22` Oxygen Fuel Jet Diffusion Flames 2004 20040053527
- [ ] `23` ACME on ISS 2021 20210015913
- [ ] `24` ACME Advanced Combustion Microgravity 2022 20220015583
- [ ] `25` Gaseous Fuel Flames on ISS 2021 20210022542
- [ ] `26` Gaseous Non-Premixed Flame Planned 2014 20140009169
- [ ] `27` Microgravity Multi-Jet Flames China Space Station 2026 10.1016-j.combustflame.2026.115316 🔒 download

### Tier 2 — Fire safety (28–38)
- [ ] `28` Spacecraft Fire Safety CP-2476 1987 19880003138 ← the safety bible
- [ ] `29` Smoke Particulate Characterization Detection 2004 20040053578
- [ ] `30` FPDS Fire Safety Exploration 2007 20070010766
- [ ] `31` BASS Combustion of Solids Results 2014 20160000593
- [ ] `32` BASS-II Summary Report 2021 20210011385
- [ ] `33` PMMA Rods Concurrent Flow Flammability 2015 20150008961
- [ ] `34` Material Flammability Thickness Effects 2013 20140011099
- [ ] `35` Mixed Convection Blowoff Limits 2017 20170006615
- [ ] `36` FLARE Flammability Limits Reduced-g 2016 20160001023
- [ ] `37` SoFIE Project ISS 2019 20200000361
- [ ] `38` Hazardous Product Detection Clean-up 2019 20200000365

### Tier 3 — Modern state-of-the-art & exploration (39–67)
- [ ] `39` Large-Scale Spacecraft Fire Safety Tests 2014 20150000894
- [ ] `40` Spacecraft Fire Safety Demonstration 2016 20160010292
- [ ] `41` Saffire Objectives and Development 2016 20170001636
- [ ] `42` Saffire Operation and Development 2017 20170000230
- [ ] `43` Saffire A Novel Approach 2017 20180005168
- [ ] `44` Large-Scale Spacecraft Flammability Results 2017 20170008805
- [ ] `45` Spacecraft Fire Safety Research Glenn 2016 20170007283
- [ ] `46` Buoyant Effects Silicone Flammability 2015 20150022123
- [ ] `47` Saffire Offgas Testing Strategy 2015 20150003025
- [ ] `48` Fire Safety Implications Saffire IV V 2021 20210011521
- [ ] `49` Evaluation of Combustion Products 2021 20210017343
- [ ] `50` Buoyancy Effects Flame Spread PMMA 2018 20200000557
- [ ] `51` Opposed Flame Spreading PMMA 2021 20210017785
- [ ] `52` Modeling HCl Uptake Spacecraft Materials 2021 20210010621
- [ ] `53` Flame Temperature Two-Color Pyrometry 2022 20220012861
- [ ] `54` Model Development Large-Scale Fires 2022 20220002714
- [ ] `55` Acid Gas Interactions 2023 20230004106
- [ ] `56` Vehicle Modeling Thermally Thick 2024 20240008602
- [ ] `57` Saffire VI Preliminary Results 2024 20240002981 ← freshest results
- [ ] `58` Vehicle Modeling Saffire VI Burn Events 2025 20250002675
- [ ] `59` Spacecraft Fire Safety Predictions Verified Model 2026 20260001600
- [ ] `60` Heat and Smoke Emission Saffire VI 2026 20260001992
- [ ] `61` Spacecraft Fire Safety Tech Plan 2020 20205000063 ← the roadmap doc
- [ ] `62` Spacecraft Fire Safety Needs Exploration 2020 20205007829
- [ ] `63` NASA Materials Flammability Update 2021 20210021181
- [ ] `64` Spacecraft Fire Safety Tech Exploration 2021 20210021318
- [ ] `65` SoFIE Lunar Applications 2025 20250002114
- [ ] `66` Digital Droplet Flame Diameter 2026 arxiv-2607.16587
- [ ] `67` Robotic Firefighting Sensors 2026 arxiv-2609.22786

## ✅ Progress Log

- [x] Read challenge brief
- [x] Read TM-107353
- [x] Verify internet/NTRS access
- [ ] Read Participant FAQs.pdf
- [x] Pull comprehensive literature corpus (~72 docs, 1974–2026: Saffire, FLEX/ACME/SoFIE/BASS/FLARE, workshops, international)
- [ ] Read & mine papers into `knowledge.md` (next phase)
- [ ] Build knowledge tree/graph
- [ ] Collect fire/combustion history + test data
- [ ] Design dashboard concept (later)
- [ ] Build prototype (later)

## 🔧 Tech Decisions

- **Dashboard = structured knowledge graph + RAG AI + hard-coded UI** (NOT a fine-tuned "AI trained on literature").
- AI roles: (a) ingest/summarize papers → graph (human-reviewed); (b) interpret / answer Q&A grounded in citations (RAG).
- UI views: Insights (ranked findings) · Concept explorer (graph) · Timeline · Rankings/comparison · "Ask" copilot.
- "Rank" = deterministic scoring over the graph (relevance / recency / evidence strength), not LLM guesswork.
- **Stack:** Flutter (Dart) — app lives in `app/`, MVC layout (`models/` `services/` `controllers/` `views/`). Cross-platform (Win/Linux/Android/iOS), offline-first. AI = local Ollama via HTTP (`localhost:11434`) — desktop now, mobile deferred. Preview targets: `-d edge`/`-d chrome`(Brave) web, `-d windows` native (needs VS C++ workload).

## 💡 Backlog (come back to)

- **Rank feature** — deterministic "rank" (e.g., rank suppression agents / detection methods by microgravity suitability). Needs the structured graph, not just retrieval. *(V flagged — return soon.)*
- **Image label refinement** — run qwen2.5 over figure captions to replace noisy labels with clean one-line subjects.
- **Bigger chat model** — upgrade qwen2.5:3b → 7b/14b after prototyping (laptop-friendly iteration first).
- **Full-corpus re-embed** — re-run ingest with `SKIP_NN` cleared (include the 6 workshop volumes) once we can afford the time; "get everything down to the model."
- **"Constellation" UI mode** — Obsidian-graph-like lesson navigator: default mode shows N constellations (clusters of lessons); hovering a node shows its lesson name; users can add their own nodes. *(V's idea — build later; base the graph on the topic/subtopic hierarchy in `curriculum.md`.)*
- **Fire particle animation (Phase 2)** — consider `flame` / `GraphX` for particles & shaders later; the graph *physics* we do ourselves (pure Dart + CustomPainter).

## 🎨 UI/UX & Gamification Ideas

- **Fire-level progression** — animate a "fire level" per lesson (abstraction depth) AND an overall fire level tracking total progress; Duolingo / chess.com-streak-style flame, but for lesson completion + mastery. Flame *color* can encode depth (blue = foundations/cool → yellow = sooty/rich → white-hot = advanced), mirroring real flame physics.
- **Constellation mapping** — each module = a constellation (themed container); each lesson = a star that lights up on completion. Working candidate set:
  - 0 Foundations → **Norma** (the Level/Square) · 1 Combustion & Fire → **Phoenix** (fire bird) · 2 Microgravity → **Ara** (the Altar) · 3 Detection & Suppression → **Boötes** (the Watcher) · 4 Materials & Toxicity → **Sagitta** (the Arrow) · 5 Exploration → **Vela** (the Sails) · 6 History → **Horologium** (the Clock).
