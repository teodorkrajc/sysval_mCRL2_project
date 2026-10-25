# Verification results

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

**Consequence:** full verification is at MAXPOOL = 1. The gap is S9, which is vacuous there (R5). Planned: a targeted MAXPOOL = 2 check of S9 and R5 on a variant with a restricted environment (e.g. requests in one wing only, no emergency). That is evidence for S9, not a proof for the full model, since the variant's behaviour is a subset of the full model's.

## Diagnosis of the MAXPOOL = 2 memory problem (25 Oct 2026)

Measured at MAXPOOL = 1 and scaled to MAXPOOL = 2:

| Route | MAXPOOL = 1 (S1) | Projected for MAXPOOL = 2 |
| --- | --- | --- |
| `lps2pbes` + `pbessolve` (on the fly) | 323,557 equations, 0.15 GB, 81 s | ~70M equations, ~30 GB |
| `lts2pbes` + `pbessolve` (on the reduced LTS, the route of `verify.ps1`) | 155,393 equations, 0.17 GB, 9 s | ~50 GB |

S9 is heavier: 1,482,853 equations at MAXPOOL = 1 (11.7 per state, from `forall e` × `forall n`).

Ruled out:
- **Stale data in the state.** The linearised process resets the stop set and target to a dummy value when they are no longer needed; `lpsstategraph` removes nothing. The 27M states are genuine.
- **Infinite unfolding in the formulas.** All quantifiers are bounded or inside actions; all fixpoint parameters are finite.
- **PBES simplification.** `pbesconstelm` + `pbesparelm` + `pbesstategraph` leave the number of equations unchanged (S1, S9): every state variable influences behaviour.

Conclusion: no bug; plain checking at 27M states needs 2–3× the RAM of a 16 GB laptop.

Model variants (MAXPOOL = 1, for comparison; not adopted): car stores only target and park flag instead of the stop set: −9%. `done` reported immediately after a visit: +2%. Without emergency: exactly half (every state exists with and without emergency).

**Fix: per-property abstraction** (`scripts/verify_reduced.ps1`). For each group of properties, hide the actions their formulas do not mention and minimise modulo branching bisimulation (divergence-preserving for L1, L2, L4). This preserves every formula that is insensitive to inserting or removing internal steps, which holds for all S/L formulas: their regular expressions always put a `*` between actions, and S7/S10 loop on "any other action". At MAXPOOL = 1 the groups shrink 126,850 states to 1–12,272.
- Validation 1: all properties give the same results as on the full MAXPOOL = 1 state space.
- Validation 2: a mutant with the old L4 bug (enterI not gated by the emergency switch) is still caught: L4 = false on the full and on the reduced state space (1,920 states).
- Not applicable to R4 and R9, which require two actions directly after each other.
