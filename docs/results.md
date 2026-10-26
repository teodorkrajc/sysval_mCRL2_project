# Verification results

## Summary

| Bound | States | Method | Result |
| --- | --- | --- | --- |
| `MAXPOOL = 1` | 126,850 | full state space (strong-bisimulation reduced) | all S/L true (S6 by construction); R1–R9 true except R5 (expected) |
| `MAXPOOL = 2` | 27,258,226 | per-property abstraction (hide + branching bisimulation), per-origin splitting for S7/L3/L2 | all S/L true (S6 by construction); R1–R3, R5–R8 true; R4, R9 true by monotonicity |

**Monotonicity in MAXPOOL.** `MAXPOOL` occurs only in the request guard `#pool < MAXPOOL`, so the MAXPOOL = 1 state space is a sub-LTS of the MAXPOOL = 2 one (same initial state; every transition possible at 1 is possible at 2). Hence reachability (diamond) properties that hold at 1 also hold at 2 (the same witness path exists): **R4 and R9 hold at MAXPOOL = 2**. Conversely, safety (box) properties that hold at 2 also hold at 1. Liveness properties (L2, L4) are not monotone in general; they were checked at both bounds. Checked on 26 Oct: the verified spec copy (`out/mp2/spec.mcrl2`) is identical to the current spec apart from the MAXPOOL value.

Not covered: S6 as a formula (holds by construction) and `MAXPOOL ≥ 3`. R4/R9 were not checked at `MAXPOOL = 2` directly, but follow from `MAXPOOL = 1` by monotonicity (see below). The `MAXPOOL = 2` results rely on the abstraction preserving our formulas (argued in design.md §6.11, validated below).

Toolset: mCRL2 202607.0 (Release). Platform: Windows 11 Enterprise 10.0.26200, 15.6 GB RAM, 4 threads for state space generation.

Pipeline (`scripts/verify.ps1`): linearise (`mcrl22lps`, `lpssumelm`, `lpsconstelm`, `lpsparelm`) → generate the state space once (`lps2lts --threads=4`) → reduce modulo strong bisimulation (`ltsconvert -ebisim`, preserves all µ-calculus properties) → per property `lts2pbes` + `pbessolve` against the reduced state space. S6 is not model-checked (holds by construction, see `TouchpointTowers/properties/S6.mcf`).

## MAXPOOL = 1 (21–22 Oct 2026)

Run with the commands of `scripts/verify.ps1`, typed by hand.

| | States | Transitions | Time |
| --- | --- | --- | --- |
| State space | 126,850 | 332,630 | 7.2 s |
| After strong-bisimulation reduction | 58,880 | 158,208 | |

| Property | Result | Time |
| --- | --- | --- |
| S1 | true | 10.1 s |
| S2 | true | 16.8 s |
| S3 | true | 13.4 s |
| S4 | true | 19.3 s |
| S5 | true | 35.4 s |
| S6 | not model-checked (by construction) | |
| S7 | true | 69.0 s |
| S8 | true | 9.8 s |
| S9 | true | 19.4 s |
| S10 | true | 10.7 s |
| L1 | true | 3.3 s |
| L2 | true | 14.6 s |
| L3 | true | 99.0 s |
| L4 | true | 13.3 s |
| R1 | true | 3.3 s |
| R2 | true | 3.2 s |
| R3 | true | 3.5 s |
| R4 | true | 3.9 s |
| R5 | **false** (expected) | 3.5 s |
| R6 | true | 3.4 s |
| R7 | true | 3.6 s |
| R8 | true | 10.2 s |
| R9 | true | 4.4 s |

**R5 is false as expected:** with one request in the pool, a car's stop set never has more than one level. So S9 ("never skip a stop") is vacuously true at this bound; it needs MAXPOOL ≥ 2 to mean anything.

**What MAXPOOL = 1 covers.** All properties except S9 can fail in principle at this bound, but scenarios that need two outstanding requests do not exist: the pool is full after one request, so no request can arrive while a car is under way.

| Property | Covered at MAXPOOL = 1 | Only exists at MAXPOOL ≥ 2 |
| --- | --- | --- |
| S1, S2, L4 | contention for I during a transfer (A holds I, B waits) | both cars busy with independent requests, both heading for I |
| S3, S4, S8 | fully (one car's own cycle; emergency) | — |
| S5, S10 | normal flow: read stops, go, serve | stale stop sets: the pool changing between reading and serving |
| S7, L2 | request → done, no double done | merging of identical requests (refused at 1 because the pool is full) |
| L2, L3 | a single request is served | a request served while another competes for the same car |
| S9 | **vacuous** | any two-level stop set |
| L1 | all states at this bound | states that only exist at a larger bound |

**IDE vs command line.** The mCRL2 IDE checks each property on the fly from the LPS (`lps2pbes` + `pbessolve`), which re-evaluates all data functions per formula: S1 took 81 s that way, against 10 s via the explicit LTS. At MAXPOOL = 2 the IDE route ran for hours without finishing; that is why the scripts generate the state space once.

## MAXPOOL = 2 (22 Oct 2026, `scripts/verify.ps1 -MaxPool 2`)

| | States | Transitions | Time |
| --- | --- | --- | --- |
| State space | 27,258,226 | 84,931,546 | 1,522.9 s (25.4 min) |
| After strong-bisimulation reduction | 18,822,336 | 62,148,384 | 1,572.7 s (26.2 min) |

The state space is about 215× that of MAXPOOL = 1. Reduction removed 31% of the states (54% at MAXPOOL = 1). Files: `out/mp2/model.lts` 1.6 GB, `out/mp2/model_min.lts` 1.3 GB.

**Model checking did not succeed at this bound: out of memory.**
- S1: `lts2pbes` ran for 6,997.7 s (1.9 h) and ended without writing a PBES file and without a result, almost certainly out of memory.
- S2: `lts2pbes` reached a peak of 9.8 GB with 0.3 GB of system RAM left (heavy swapping); expected to end the same way, so the run was abandoned here.

`lts2pbes` builds the complete equation system (18.8 million states × the formula's fixpoint variables) in memory before solving, which exceeds 16 GB here.

**Consequence at the time:** full verification only at MAXPOOL = 1, where S9 is vacuous (R5). The planned restricted-variant check was superseded by the per-property abstraction below, which verifies the full MAXPOOL = 2 model.

## Diagnosis of the MAXPOOL = 2 memory problem (25 Oct 2026)

Measured at MAXPOOL = 1 and scaled to MAXPOOL = 2:

| Route | MAXPOOL = 1 (S1) | Projected for MAXPOOL = 2 |
| --- | --- | --- |
| `lps2pbes` + `pbessolve` (on the fly) | 323,557 equations, 0.15 GB, 81 s | ~70M equations, ~30 GB |
| `lts2pbes` + `pbessolve` (on the reduced LTS, the route of `verify.ps1`) | 155,393 equations, 0.17 GB, 9 s | ~50 GB |

Equations per state differ per formula: S1 323,557 (2.5 per state), S3 341,157 (2.7), S9 1,482,853 (11.7: `forall e` × `forall n` gives 10 instances). Memory was measured as the peak working set of `pbessolve`/`lts2pbes` (about 450 bytes per equation).

**Memory budget derived from this:** 0.17 GB for checking 58,880 states, so about 1M states per checked state space for light formulas fits comfortably in ~10 GB of free RAM; heavy formulas (S9, the 72-trip formulas) need less.

Ruled out:
- **Stale data in the state.** The linearised process has 13 parameters, including each car's stop set `S` and target `t`, which are only needed briefly. The linearizer assigns them a "don't care" global variable (`dc`) whenever they are no longer needed, and `lps2lts` fills those with one fixed dummy value, so stale values do not create extra states. `lpsstategraph` (dead-variable analysis) removes nothing: 126,850 states before and after. The 27M states are genuine.
- **Infinite unfolding in the formulas.** All quantifiers are bounded or inside actions; all fixpoint parameters are finite.
- **PBES simplification.** `pbesconstelm` + `pbesparelm` + `pbesstategraph` leave the number of equations unchanged (S1: 323,557 before and after; S9: 1,482,853 before and after), and add time (S1: 81 s → 105 s): every state variable influences behaviour.

Conclusion: no bug; plain checking at 27M states needs 2–3× the RAM of a 16 GB laptop.

**Model variants** (MAXPOOL = 1, generated from copies of the spec; not adopted):

| Variant | States | vs. model |
| --- | --- | --- |
| model as is | 126,850 | |
| A: car stores only target and a park flag, not its stop set | 114,882 | −9% |
| C: `done` reported right after the visit (dispatcher-only reporting phase) | 129,138 | +2% |
| A + C | 117,170 | −8% |
| no emergency (switch never pressed) | 63,425 | −50% (exactly half) |

The emergency doubles the state space because every situation exists with and without an emergency. Since the switch only blocks behaviour and never adds any, safety properties that do not mention `emergency`/`reset` could soundly be checked on the emergency-free model (half the size); not needed in the end.

**Where the 27M states come from:** about 280 possible pool entries (40 same-wing trips × 3 states + 32 cross-wing trips × 5 entry forms), so pools of up to 2 entries give ~39,000 combinations; times both cars' positions, directions and phases (independent, so they multiply); times 2 for the emergency.

**Fix: per-property abstraction** (`scripts/verify_reduced.ps1`). For each group of properties, hide the actions their formulas do not mention and minimise modulo branching bisimulation (divergence-preserving for L1, L2, L4). This preserves every formula that is insensitive to inserting or removing internal steps, which holds for all S/L formulas: their regular expressions always put a `*` between actions, and S7/S10 loop on "any other action". At MAXPOOL = 1 the groups shrink 126,850 states to 1–12,272.
- Validation 1: all properties give the same results as on the full MAXPOOL = 1 state space.
- Validation 2: a mutant with the old L4 bug (enterI not gated by the emergency switch) is still caught: L4 = false on the full and on the reduced state space (1,920 states).
- Not applicable to R4 and R9, which require two actions directly after each other.

**Reduction per property at MAXPOOL = 1** (from 126,850 states; hide everything the formula does not mention, then minimise):

| Property | Kept visible | Equivalence | States |
| --- | --- | --- | --- |
| S1 | enterI, leaveI | branching | 41 |
| S2 | enterI, leaveI, move | branching | 4,736 |
| S3 | open, close, move | branching | 11,152 |
| S4 | open, close, visit | branching | 1,584 |
| S5 | stops, visit | branching | 844 |
| S7, L3 | request, done | branching | 73 |
| S8 | emergency, reset, move | branching | 5,088 |
| S9 | stops, move | branching | 6,352 |
| S10 | stops, move, open | branching | 7,040 |
| L1 | (none) | div.-preserving | 1 |
| L2 | request, done, emergency, reset | div.-preserving | 290 |
| L4 | enterI, leaveI, request, emergency, reset | div.-preserving | 584 |

Grouped (as used in `verify_reduced.ps1`): {open, close, move, visit} 12,272; {stops, move, open} 7,040; {stops, move, open, close, visit, enterI, leaveI} 25,280 (too big to share, not used). Lesson: the fractions measured at MAXPOOL = 1 did not transfer to MAXPOOL = 2. {request, done, emergency, reset} was 0.23% of the state space at 1 (290 states) but 12% of the reduced state space at 2 (2,254,088 states), because which requests are outstanding must stay visible.

**Tau-confluence** (tested, not used): for S9 (hide all but `stops`, `move`), `lpsconfcheck` marked 7 internal summands as confluent, and `lps2lts -cctau` then generated 21,105 instead of 126,850 states at MAXPOOL = 1 (6× fewer, without building the full state space). Limitation: `lps2lts` only supports confluence single-threaded ("Option 'confluence' can only be used in single thread mode"). A MAXPOOL = 2 attempt used only 0.47 GB but was stopped after ~24 CPU-minutes in favour of the grouped `ltsconvert` route. The documentation only guarantees branching bisimilarity for confluence reduction, not divergence preservation, so it would not have been used for L1, L2, L4.

## MAXPOOL = 2 results, per-property abstraction (25 Oct 2026)

`scripts/verify_reduced.ps1` on `out/mp2/model_min.lts` (18,822,336 states). Each reduction (hide + minimise) took 185–326 s. Full log: `docs/mp2_reduced_log.txt`. Finished 25 Oct 2026, 23:06.

| Property | Group (visible actions) | Equivalence | Reduced states | Result | Check time |
| --- | --- | --- | --- | --- | --- |
| S1 | enterI, leaveI, move | branching | 722,572 | true | 112 s |
| S2 | enterI, leaveI, move | branching | 722,572 | true | 191 s |
| S3 | open, close, move, visit | branching | 1,966,648 | true | 330 s |
| S4 | open, close, move, visit | branching | 1,966,648 | true | 589 s |
| S5 | stops, visit | branching | 346,364 | true | 266 s |
| S6 | — | — | — | not model-checked (by construction) | — |
| S7 | request, done | branching | 653,308 | true (per origin, 9 of 9) | 4,382 s |
| S8 | emergency, reset, move | branching | 1,075,496 | true | 145 s |
| S9 | stops, move, open | branching | 1,100,116 | true | 325 s |
| S10 | stops, move, open | branching | 1,100,116 | true | 198 s |
| L1 | (none) | div.-preserving branching | 1 | true | 49 s |
| L2 | request, done, emergency, reset | div.-preserving branching | 2,254,088 | true (per origin, 9 of 9) | 6,846 s |
| L3 | request, done | branching | 653,308 | true (per origin, 9 of 9) | 2,424 s |
| L4 | enterI, leaveI, request, emergency, reset | div.-preserving branching | 664,224 | true | 131 s |
| R1, R2 | enterI, leaveI, request, emergency, reset | div.-preserving branching | 664,224 | true, true | 51 s, 52 s |
| R3 | emergency, reset, move | branching | 1,075,496 | true | 67 s |
| R5 | stops, move, open | branching | 1,100,116 | **true** | 77 s |
| R6, R7 | request, done | branching | 653,308 | true, true | 78 s, 78 s |
| R8 | emergency, reset, move | branching | 1,075,496 | true | 155 s |
| R4, R9 | — | — | — | not checked at this bound (need "directly after each other"); true at MAXPOOL = 1 | — |

**All S/L properties hold at MAXPOOL = 2** (S6 by construction). **R5 is true**: two-level stop sets occur, so S9 is meaningful at this bound.

Run history:
- the first attempt checked S7 over all 72 trips at once on the 2.25M-state {request, done, emergency, reset} reduction and was stopped (12.6 GB committed, swapping);
- the group was then split ({request, done} for S7, L3, R6, R7; the larger one only for L2);
- per-trip checking (72 instances) worked but was too slow: 1,751 s for the first 12 trips of S7 (~2.4 min each, almost all of it loading the 653k-state reduced LTS), i.e. ~3 h per property;
- the final run used per-origin checking (9 instances of 8 trips): S7 ~8 min per origin, L2 ~13 min per origin.

Every step stayed within the 16 GB of the laptop.

**Coverage at MAXPOOL = 2:** scenarios with two outstanding requests (stale stop sets, merging of identical requests, both cars busy at once) are included, and S9 is non-vacuous. Not covered: S6 (by construction, at any bound) and MAXPOOL ≥ 3 (not attempted). R4 and R9 hold at this bound by monotonicity (summary at the top). The MAXPOOL = 2 results rely on the abstraction preserving our formulas (argued in design.md §6.11, validated at MAXPOOL = 1 and with a mutant).

## Measurements from model development

Earlier versions of the model, for the record (they show how the state space grew with each feature):

| When | Version | States | Note |
| --- | --- | --- | --- |
| 15 Oct | dispatcher alone (car A's wing, visits for any level) | 41 / 811 / 10,291 / 93,986 | MAXPOOL = 1 / 2 / 3 / 4; roughly "choose up to MAXPOOL of 40 entries" |
| 15 Oct | step 1: dispatcher + car A, same-wing trips only, MAXPOOL = 2 | 14,953 | S3, S4, S5, S9, S10, L1 true |
| 20 Oct | + car B + intersection manager, MAXPOOL = 2 | > 650,000 after 90 s (not completed) | first sign that MAXPOOL = 2 would be large |
| 21 Oct | full model (cross-wing, `done`, emergency), MAXPOOL = 1 | 126,850 | 41 s single-threaded, 7.2 s with 4 threads |

Other checks during development:
- The `Go` process as an if-else chain and as a two-question version ("need to enter I?" / "need to leave I?") are **strongly bisimilar** for all 25 (pos, target) pairs (`ltscompare -ebisim`: true).
- With the work and idle branches written as two separate `stops_c` summands, `lps2lts` failed with "Cannot enumerate elements of finite set sort FSet(Nat)" (the linearizer had clustered them); one summand with an inner if-then-else fixed it (design.md §6.8).
- A recursive `nextUp` written with `if(...)` made `mcrl22lps` hang; `mcrl2i` showed the `if` version never returns on an unknown argument, while the conditional-equation version returns it unevaluated (design.md §6.5).
- A mutant without `enterI` gating (the L4 bug found by review) gives L4 = false at MAXPOOL = 1, on the full state space and on the reduced one (1,920 states).

## Practical findings (tools and machine)

- **`lts2pbes` memory:** it builds the complete equation system for all states before `pbessolve` instantiates it again, so on large state spaces it needs far more memory than the on-the-fly route. On the 18.8M-state LTS it ran 1.9 h without a result.
- **`ltsinfo`** does not report deadlocks; L1 was checked as a formula (on the fully hidden, divergence-preservingly minimised state space: 1 state).
- **`ltsconvert`** (hide + minimise) on the 18.8M-state, 1.3 GB LTS took 3–5.5 min per group and fit in memory; it was the workhorse of the MAXPOOL = 2 verification.
- **Free memory matters:** with Docker Desktop / WSL and other apps running, only 3.4 GB of 15.6 GB was free; `wsl --shutdown` and closing apps freed several GB.
- **Sleep:** the laptop has Modern Standby (S0 low-power idle); with sleep set to "never", no standby occurred during the runs. A power-source change at 16:39 suggests a period on battery, where Windows may throttle background processes; long runs were done plugged in.
- **PowerShell 5.1:** progress messages on stderr appear as `NativeCommandError` (fixed by running `ltsconvert` via `cmd /c … 2>&1`); `Tee-Object` writes UTF-16 (the log in `docs/` is converted to UTF-8); arrays passed with `-File` arrive as one string ("a,b" is split in the script).
