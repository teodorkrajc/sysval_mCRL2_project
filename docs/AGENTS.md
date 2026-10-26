# AGENTS.md — Touchpoint Towers (mCRL2)

Onboarding for an AI agent working in this repository. Read this file fully, then `docs/design.md` (design + all decisions), `docs/results.md` (verification results) and `docs/report.tex` (the report, with `%%%` guidance comments). Last updated 2026-10-25.

## 1. What this project is

The System Validation (2IMF30, TU/e) course assignment. We design the controller for a small distributed system in **mCRL2**, state its requirements as **modal µ-calculus** formulas, and verify them with the mCRL2 toolset. The deliverable is a verified *model* plus a technical report.

The system: two elevators in two wings (A left, B right), levels 1–5 each, whose rails meet at one shared floor, the Touchpoint **I** (level 3). I is a mutex and the only transfer point between wings. Cross-wing trips are split into two legs via I.

**Source of truth for the design:** `docs/design.md`. If the model and design.md disagree, stop and flag it.

## 2. Hard constraints from the course

- **Deadlines:** pre-final report on paper before **Mon 26 Oct 2026, 09:00** (graded). Exam Fri 30 Oct. Final report Mon 9 Nov, 12:00.
- The controller must have at least three parallel components (we have five processes; four without the emergency switch).
- The report must list the **exact commands**, the **toolset version** (mCRL2 202607.0) and the **platform** (Windows 11). Commands are in `scripts/verify.ps1` and `scripts/verify_reduced.ps1`.
- **AI use must be declared in the report**, and every group member must understand everything in it. Log AI contributions in `docs/ai-usage.md` (date, what, files).

## 3. Working with the user (important)

- **The user writes the report prose themselves.** Never insert report prose into `report.tex`. Your job there: `%%%` comment skeletons (what a section must contain), `%%% FIX:` markers where existing text contradicts the model, and answering questions. Items that came from the MAXPOOL = 2 run are marked `%%% RESULT (MAXPOOL = 2 run):`.
- **The user wants to understand everything.** Explain step by step, give the reasoning behind each construct and decision, show evidence (tool output) rather than assertions, and leave decisions to the user.
- **State coverage gaps up front, unprompted.** With every bound, abstraction or results table, say what is vacuous or untested (e.g. S9 is vacuous at MAXPOOL = 1).
- **Long verification runs:** the user prefers to run them in their own terminal or the mCRL2 IDE. Ask before starting anything long; short checks (typecheck, `mcrl2i`, small experiments on scratch copies) are fine.
- Be terse when asked for something pasteable.

## 4. Repository layout

```
TouchpointTowers/TouchpointTowers_spec.mcrl2   the model (one file)
TouchpointTowers/TouchpointTowers.mcrl2proj    mCRL2 IDE project (lists the properties)
TouchpointTowers/properties/S1..S10, L1..L4    requirement formulas (.mcf); S6 is comments only (by construction)
TouchpointTowers/properties/R1..R9             sanity (reachability) checks
scripts/verify.ps1                             full pipeline: linearise, state space, strong reduction, all properties
scripts/verify_reduced.ps1                     per-property abstraction (used for MAXPOOL = 2)
docs/design.md                                 design, formula revisions (§5), design decisions (§6), status (§7)
docs/results.md                                verification results, timings, diagnosis of the MAXPOOL = 2 problem
docs/report.tex                                the report (body only; preamble lives in the group's LaTeX project)
docs/questions.md                              questions prepared for the tutor meeting of 22 Oct
docs/ai-usage.md                               AI contribution log
out/                                           generated files (gitignored; large)
```

## 5. The model in brief (details: design.md §2–§3, §6)

- `Loc = struct I | fl(wing: Car, lvl: Nat)`, valid levels 1, 2, 4, 5 (`validLoc`); I is level 3.
- Pool entry `req(origSrc, origDst, src, dst, st)`, `st ∈ {waiting, active, finished}`: original trip + current leg. Pool = `List(Req)` kept sorted and duplicate-free by `ins` (not `FSet`: no pattern matching on FSet).
- Cross-wing trip = one entry whose first leg ends at I and which is **rewritten** into its second leg when the first car drops the passenger at I (no `blocked` state; S6 holds by construction).
- Processes: `Dispatcher(pool)`, `Elevator`/`Go`/`Serve` (cars A and B), `IntersectionManager(mutex)`, `EmergencySwitch(on)`.
- Synchronisation halves: `_d` dispatcher, `_c` car, `_im` intersection manager, `_em` emergency switch; only the unsuffixed result is in `allow`. `enterI` is three-party (car, IM, switch); `move` and `request` sync with the switch.
- Cars: LOOK, serve the current level if it has work, wait (no polling) when idle, intersection protocol "hold I exactly when at level 3", idle rule: at I with no work, step one level on and release I.
- `MAXPOOL` = number of outstanding requests (currently 1 in the spec; the scripts substitute the value).

## 6. Verification (details: results.md, design.md §6.11)

- **MAXPOOL = 1** (126,850 states): `verify.ps1` route (state space once, strong-bisimulation reduction, `lts2pbes` + `pbessolve` per property). All S/L true; R1–R9 true except R5 (expected: S9 is vacuous at this bound).
- **MAXPOOL = 2** (27.3M states, 18.8M after strong reduction): plain checking needs ~30–50 GB. Used **per-property abstraction** (`verify_reduced.ps1`): per group of properties, hide unmentioned actions and minimise modulo branching bisimulation (divergence-preserving for L1, L2, L4), then check; S7, L3, L2 checked per origin (9 instances). Validated at MAXPOOL = 1 and with a mutant.
- **Final (2026-10-25, 23:06): all S/L properties true at MAXPOOL = 2** (S6 by construction); R1–R3, R5–R8 true; R4/R9 only at MAXPOOL = 1. Full table: results.md; log: docs/mp2_reduced_log.txt.
- Lessons for formulas: never quantify over an infinite sort at the top of a formula without a bound (`val(validLoc(o) && ...)`, `val(n >= 1 && n <= 5)`) or moving it into the action; keep fixpoint parameters bounded (S7's counter is capped at MAXPOOL).

## 7. Working rules

1. **Never weaken a formula to make it pass.** If a property fails, save the counterexample, explain it, propose a design fix, ask before changing a requirement. Every formula change is recorded in design.md §5 with the original.
2. Every property gets a sanity check; a safety formula over actions that never happen passes trivially.
3. After every model change, rerun verification and update results.md and design.md §7.
4. Comment the model per component and per non-obvious guard.

## 8. Plan and status

- Model: complete (same-wing + cross-wing trips, intersection, done reporting, emergency). Last model change committed in `9fb24a1`.
- Verification: complete at MAXPOOL = 1 and MAXPOOL = 2 (all true). results.md, design.md §7 and the former `%%% OPEN` markers in report.tex (now `%%% RESULT`) are filled in.
- Report: skeleton with `%%% GUIDE` / `%%% FIX` / `%%% OPEN` comments in place; the user is writing the prose. Main FIX items: FIFO → LOOK, no `blocked` state, five processes in the figure, pickup/dropoff not modelled, revised S2/S7/L3 formulas, S6 by construction.
- Dropped: bounded transfer area at I (extension), P1 (LOOK as a formula).
