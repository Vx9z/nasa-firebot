# 🏗️ Application Blueprint — Categorized Knowledge Map

> **Purpose:** the structural blueprint for the fire-safety dashboard app.
> It organizes *all* corpus material into chapters/parts, each with key findings + citations.
> **Over-categorized on purpose** — merge chapters later as the app takes shape.
> Citations use `[NN]` = paper number in the reading roadmap (see `memory.md` → 📖 Reading Roadmap).

---

## Chapter 1 — Overview & Program History
**Scope:** what microgravity combustion research is, why it matters, and how the program evolved.
**Key findings:**
- Microgravity (near-zero g) minimizes buoyant flows → simplifies combustion and isolates phenomena normally hidden by gravity-driven forces. `[14]`
- NASA's microgravity combustion program grew from the need to prevent/detect/suppress spacecraft fires into fundamental research. `[18]`
- Four application areas: fire safety, combustors, sensors & controls, advanced materials. `[14]`
- Field spans Skylab M-479 (1974) → ISS experiments → Saffire (2024) → China Space Station (2026). `[01, 56, 27]`
**Papers:** 01, 02, 03, 04, 06, 07, 14, 18, 60

## Chapter 2 — Combustion Fundamentals
**Scope:** what fire/combustion *is* — chemistry, flame anatomy, heat transfer.
**Key findings:**
- Fire = exothermic oxidation reaction; sustained by the fire tetrahedron (fuel, oxidizer, heat, chain reaction). `[14, 28]`
- Flame anatomy: preheat → reaction → post-flame zones; diffusion vs. premixed flames. `[14]`
- Heat transfer: conduction, convection, radiation — radiation dominates once convection vanishes in µg. `[14]`
- Combustion is the dominant mode of energy production (transport, power, industry). `[14]`
**Papers:** 01, 03, 14, 28

## Chapter 3 — Buoyancy & Microgravity Physics
**Scope:** the physics of buoyancy and what changes when gravity is removed.
**Key findings:**
- Buoyancy arises from density gradients under gravity (ρ = P/RT → thermal expansion → natural convection). `[14]`
- Removing buoyancy → diffusion-dominated transport; no natural convection, no flame flicker/teardrop shape. `[14, 27]`
- Microgravity isolates phenomena concealed on Earth by buoyant flows. `[14]`
**Papers:** 14, 16, 27, 49

## Chapter 4 — Flame Behavior, Spread & Soot
**Scope:** how flames look and move in microgravity, and how soot differs.
**Key findings:**
- µg flames are spherical/dome, dimmer, bluer (less soot), and cooler than 1-g flames. `[14, 27, 38]`
- Hydrocarbon droplet flames form a soot shell + concentric flame; soot agglomeration differs in µg. `[14, 20]`
- Flame spread over solids is concurrent vs. opposed; some materials spread as fast or faster in µg. `[14, 33, 49]`
- Pure methane burns dimmer/cooler; N₂-diluted flames brighten (soot accumulation). `[27]`
**Papers:** 14, 20, 27, 33, 38, 49, 50

## Chapter 5 — Droplet & Spray Combustion (FLEX)
**Scope:** liquid droplet combustion — the FLEX program and droplet physics.
**Key findings:**
- FLEX used the Multi-User Droplet Combustion Apparatus (MDCA) on ISS for idealized droplet studies. `[18, 19]`
- Microgravity permits near-spherical droplets (2–6 mm) for clean ignition/flame studies. `[14]`
- Bi-component fuels show disruptive, near-explosive burning (volatility mismatch). `[14]`
- Supercritical droplet combustion applies to high-pressure rocket/aircraft combustors. `[14]`
- Digital measurement of droplet flame diameter enables quantitative analysis. `[65]`
**Papers:** 14, 17, 18, 19, 20, 65

## Chapter 6 — Gas-Phase Combustion (ACME, jets)
**Scope:** gaseous fuel flames — ACME and jet diffusion flames.
**Key findings:**
- ACME studied gaseous flames on ISS (multiple sub-experiments). `[23, 24]`
- Gaseous non-premixed flame research planned for ISS. `[26]`
- China Space Station multi-jet flames: buoyancy suppression → diffusion-dominated; flame length grows with fuel velocity, exceeding theory due to jet interaction. `[27]`
- Oxygen/fuel jet diffusion flames motivated by spacecraft O₂-storage fire safety. `[22]`
**Papers:** 22, 23, 24, 25, 26, 27

## Chapter 7 — Solid Fuel Combustion & Flammability (BASS, SoFIE, SIBAL, FLARE)
**Scope:** burning and flammability of solid materials in microgravity.
**Key findings:**
- BASS/BASS-II studied burning & suppression of solids (fabrics, PMMA) on ISS. `[31, 32]`
- SoFIE (Solid Fuel Ignition and Extinction) extends solid-fuel research, incl. lunar applications. `[37, 64]`
- SIBAL defines the solid inflammability boundary at low-speed flow. `[15]`
- FLARE measures flammability limits at reduced gravity (everyday materials). `[36]`
- PMMA rods: concurrent-flow flammability; thickness & preheat effects matter. `[33, 34]`
- Silicone sample flammability depends on buoyant conditions. `[45]`
**Papers:** 15, 31, 32, 33, 34, 36, 37, 45, 49, 50, 64

## Chapter 8 — Smoldering, Ignition & Extinction
**Scope:** non-flaming combustion, ignition thresholds, and extinction/blowoff.
**Key findings:**
- Smoldering = low-temperature, non-flaming reaction; controlled by heat losses (reduced in µg). `[16]`
- Mixed-convection blowoff limits depend on oxygen concentration. `[35]`
- Radiant extinction of gaseous diffusion flames; extinction & stability of diffusion flames. `[14]`
**Papers:** 16, 35, 14

## Chapter 9 — Fire Detection & Diagnostics
**Scope:** how fires are sensed, and measurement/diagnostic techniques.
**Key findings:**
- Fire detectors respond to "signatures" — heat, smoke, light (radiation), gas. `[28]`
- Detector choice balances early warning vs. false alarms; analytical fire-growth modeling aids matching. `[28]`
- Smoke particulate characterization (NASA + NIST) refines detector sensitivity/alarm criteria. `[29]`
- Two-color broadband pyrometry measures flame temperature. `[52]`
- Diagnostics favor non-perturbing, rapid measurements (flame appearance, velocity, temperature, species). `[05, 14]`
- Robotic fire-fighting sensor infrastructure is an emerging direction. `[66]`
**Papers:** 05, 28, 29, 52, 59, 66

## Chapter 10 — Fire Suppression & Extinguishment
**Scope:** agents and systems that put out spacecraft fires.
**Key findings:**
- Shuttle used Halon 1301; ISS modules use CO₂ (Russian cabins: foam; decompression chamber: N₂). `[14, 28]`
- Cup-burner flame extinguishment quantifies agent effectiveness. `[21]`
- FPDS (Fire Prevention, Detection & Suppression) is the programmatic umbrella. `[30]`
- Halon replacement research seeks low ODP/GWP, low toxicity, "drop-in" alternatives — incl. water mist. `[14]`
**Papers:** 21, 22, 28, 30

## Chapter 11 — Materials, Toxicity & Combustion Products
**Scope:** material flammability and the hazardous products of spacecraft fires.
**Key findings:**
- Spacecraft polymers generate acids, ammonia, and other toxic products when heated/burned. `[28]`
- PTFE wire insulation degrades to toxic gases + ultrafine (lung-hazardous) particles. `[14]`
- HCl (hydrogen chloride) uptake onto interior spacecraft materials is modeled. `[51]`
- Combustion products from large-scale fires are evaluated; acid-gas interactions studied. `[48, 54]`
- Toxic-exposure limits should be based on mental acuity/judgment (psychology of escape). `[28]`
- Materials flammability research update (2021). `[62]`
**Papers:** 28, 34, 38, 46, 48, 51, 54, 59, 62

## Chapter 12 — Spacecraft Fire Safety & Exploration (Saffire)
**Scope:** applied fire safety for spacecraft, and the Saffire experiment series.
**Key findings:**
- Saffire I–VI: large-scale fire experiments flown on uncrewed Cygnus vehicles after ISS departure. `[39, 40, 41, 42, 47, 56]`
- Fire scenarios in spacecraft: thermally-stressed components (reduced air cooling), persistent aerosol/fluid-leak hazards, smoldering. `[14, 28]`
- Saffire VI (2024) provides the freshest results; vehicle modeling of burn events (2025). `[56, 57]`
- Spacecraft Fire Safety Technology Development Plan (2020) is the roadmap for exploration missions. `[60]`
- Fire-safety needs for exploration (Moon/Mars); technology development for habitats. `[61, 63]`
- SoFIE results extend to lunar solid-fuel applications. `[64]`
**Papers:** 28, 30, 39–47, 55–61, 63, 64

## Chapter 13 — Standards, Testing & Modeling
**Scope:** how flammability is tested and how fires are modeled computationally.
**Key findings:**
- Historically flammability tests were empirical; new-generation bench-scale tests predict full-scale behavior. `[28]`
- New tests evaluate ignitability, flame spread, heat & product release. `[28]`
- Vehicle modeling of large-scale fires; a "verified Saffire model" enables fire-safety predictions. `[53, 55, 57, 58]`
- Results of large-scale spacecraft flammability tests inform standards. `[43]`
**Papers:** 15, 36, 43, 53, 55, 57, 58

## Chapter 14 — History & Milestones
**Scope:** the timeline of microgravity combustion & fire-safety research.
**Key findings:**
- 1974 — Skylab M-479: first zero-gravity flammability experiment. `[01]`
- 1993–2003 — 2nd–7th International Microgravity Combustion Workshops (foundational corpus). `[08–13]`
- 1996 — TM-107353 overview defines the field's four application areas. `[14]`
- 2009–2015 — FLEX droplet combustion. `[18, 19, 20]`
- 2014–2021 — BASS/BASS-II solid combustion. `[31, 32]`
- 2019–2025 — SoFIE solid fuel. `[37, 64]`
- 2016–2024 — Saffire I–VI large-scale fire tests. `[39–47, 56]`
- 2021–2022 — ACME gaseous flames. `[23, 24]`
- 2026 — China Space Station multi-jet flames; droplet-flame & robotic-firefighting arXiv work. `[27, 65, 66]`
**Papers:** 01, 08–13, 14, 18, 19, 20, 23, 24, 27, 31, 32, 37, 39–47, 56, 64, 65, 66

---

## How to use this blueprint
- **Now:** it's the categorical map — every `[NN]` points to a paper in `literature/` and a chunk in the RAG index.
- **Next:** deepen each chapter by summarizing its papers (RAG-assisted), refining labels, and adding the "rank" feature.
- **App:** each chapter maps to a dashboard view (Ch 4/9/10/12 → Insights & Rankings; Ch 14 → Timeline; Ch 1–13 → Concept explorer nodes).


