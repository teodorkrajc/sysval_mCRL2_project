# AGENTS.md — Touchpoint Towers (mCRL2)

Onboarding for an AI agent working in this repository. Read this file fully, then `docs/design.md`, before changing anything.

## 1. What this project is

The System Validation (2IMF30, TU/e) course assignment. We design the controller for a small distributed system in **mCRL2**, state its requirements as **modal µ-calculus** formulas, and verify them with the mCRL2 toolset. Implementation is explicitly out of scope; the deliverable is a verified *model* plus a technical report.

The system: two elevators in two wings (A left, B right), levels 1–5 each, whose rails meet at one shared floor, the Touchpoint **I** (level 3). I is a mutex and the only transfer point between wings. Cross-wing trips are split into two legs via I.

**Source of truth for the design:** `docs/design.md` (system description, components, action table, requirements S1–S10, L1–L4, P1). If code and design disagree, stop and flag it; don't silently pick one.

## 2. Hard constraints from the course

- **Deadlines:** pre-final report on paper before **Mon 26 Oct 2026, 09:00** (this is the one that is graded). Exam Fri 30 Oct. Final report Mon 9 Nov, 12:00.
- The controller must have **at least three parallel components**. Ours has four: Dispatcher, Car A, Car B, Intersection manager. Don't merge them.
- The report must list the **exact commands** used, the **toolset version**, and the **platform/OS**. Every verification run must be reproducible from `scripts/verify.sh`.
- **AI use must be declared in the report**, and every group member must understand everything in it. Log your contributions in `docs/ai-usage.md` (date, what you did, which files). Don't write report prose unless asked; the report must be the group's own writing.

## 3. Repository layout

Create missing pieces in this layout; don't invent a different one.

```
model/touchpoint.mcrl2     # the specification (one file)
properties/<ID>_<name>.mcf # one formula per requirement, e.g. S1_mutex.mcf
properties/sanity/*.mcf    # reachability/vacuity checks (see §7)
scripts/verify.sh          # full pipeline: linearise, state space, all properties
docs/design.md             # design document (source of truth)
docs/figures/              # sketches, diagrams
docs/ai-usage.md           # AI contribution log
docs/results.md            # table: property × configuration → result, state counts
out/                       # generated files (gitignored)
```

## 4. Model conventions

**Data**

```
sort Car      = struct A | B;
     Loc      = struct I | fl(w: Car, n: Nat);      % n ∈ {1, 2, 4, 5}; I is level 3
     LegState = struct blocked | waiting | active;
```

- A car's position is a level `Nat` in 1–5, where 3 = I. Write helper maps (`level: Loc -> Nat`, `carOf: Loc -> Car` for non-I locations) instead of repeating case logic.
- A leg must remember its **original request** (for `done(o, d)` and for unblocking leg 2). Suggested shape: `leg(ro: Loc, rd: Loc, o: Loc, d: Loc, st: LegState)`.
- Use `FSet`, not `Set` or `List`, for the pool and stop sets.
- All bounds are named constants in one place: `map MAXPOOL: Nat; eqn MAXPOOL = 2;`. Start small (2) and raise only after a property passes.
- Never use unbounded data that grows with the run (queues, counters); it makes the state space infinite.

**Behaviour**

- Moves are atomic jumps to the **next stop**: `move(e, f1, f2)`. A jump never passes over a level in the stop set (S9).
- Any move whose range includes level 3 is bracketed by `enterI(e)` … `leaveI(e)` (S1, S2). An idle car must not wait at level 3 (L4).
- Cars **pull** their stop set: `stops(e, S)` is a synchronisation in which the dispatcher offers `stopsOf(e, pool)` and the car sums over `S`. Sum elimination (`lpssumelm`) removes that sum after linearisation.
- One `visit(e, n)` updates every affected leg at once; the dispatcher then emits `pickup`, `dropoff` and `done` reports.
- Leg 2 of a cross-wing trip stays `blocked` until leg 1's `dropoff(_, _, I)`.

**Naming of synchronised actions:** component halves get suffixes and communicate into the name used in requirements, e.g.

```
comm stops_d | stops_c -> stops,  visit_c | visit_d -> visit,
     enterI_c | enterI_m -> enterI, leaveI_c | leaveI_m -> leaveI;
```

`emergency` and `reset` are three-party (environment + both cars). Check that the `comm` spelling you use is accepted by the installed toolset version.

Only actions from the action table in `docs/design.md` may stay visible after `allow`. Requirements are written over exactly those names. Don't hide actions that a requirement mentions.

## 5. Verification pipeline

`scripts/verify.sh` must do this. Check flags with `--help` for the installed version, and record `mcrl22lps --version` in `docs/results.md`.

```bash
mcrl22lps -v model/touchpoint.mcrl2 out/model.lps
lpssumelm out/model.lps out/model.lps
lpsconstelm out/model.lps out/model.lps
lpsparelm out/model.lps out/model.lps
lps2lts -v out/model.lps out/model.lts      # prints state/transition counts
lps2lts -D -t out/model.lps                 # deadlock check with traces

for f in properties/*.mcf properties/sanity/*.mcf; do
  n=$(basename "$f" .mcf)
  lps2pbes -c -f "$f" out/model.lps "out/$n.pbes"
  pbessolve -f out/model.lps --evidence-file="out/$n.evidence.lps" "out/$n.pbes"
done
```

A counterexample is in `out/<n>.evidence.lps`. Turn it into an LTS with `lps2lts` and inspect it with `ltsgraph` or `ltsview`.

## 6. Formula patterns

```
% S1: mutual exclusion on I
forall e1, e2: Car . val(e1 != e2) =>
  [true* . enterI(e1) . (!leaveI(e1))* . enterI(e2)] false

% S3: never move with open doors
forall e: Car .
  [true* . open(e) . (!close(e))* . exists f1, f2: Nat . move(e, f1, f2)] false

% L1: deadlock freedom
[true*] <true> true

% L2: every request is served, assuming no new environment input
forall o, d: Loc . [true* . request(o, d)]
  mu Y . [!(done(o, d) || exists x, y: Loc . request(x, y) || emergency || reset)] Y
      && <!(exists x, y: Loc . request(x, y) || emergency || reset)> true
```

- mCRL2 has **no built-in fairness**. A plain "eventually" fails because the environment can make requests forever. Use the L2 pattern (exclude environment actions) and say so in the report.
- Data-dependent safety (S9, S10, P1) needs fixpoint parameters, e.g. `nu X(pos: Nat = 1, S: FSet(Nat) = {}) . …` updated on `move` and `stops`.

## 7. Working rules

1. **Never weaken a formula to make it pass.** If a property fails, save the counterexample, explain the trace in plain words, propose a design fix, and ask before changing the requirement itself.
2. **Every property gets a sanity check** in `properties/sanity/`: a reachability formula showing the scenario it talks about can actually happen (e.g. `<true* . pickup(B, I, fl(B, 5))> true` for S6). A safety formula over unreachable actions passes trivially.
3. Safety alone is meaningless (a model that never moves satisfies it). Keep L1–L4 green alongside it.
4. After every model change, rerun the full pipeline and update `docs/results.md`: state count, transition count, and each property's result per configuration.
5. Keep state spaces small: 5 levels per car, `MAXPOOL` ≤ 3. If generation takes more than a few minutes, reduce first and report it; don't add tricks silently.
6. Comment the model per component and per non-obvious guard. The report must let an engineer rebuild the controller exactly from it.

## 8. Plan and status

Status: design done (`docs/design.md`), model not yet written.

1. **Milestone 1:** same-wing trips only, mutex on I, doors, emergency. Requirements S1–S5, S7–S10, L1–L4 green.
2. **Milestone 2:** cross-wing trips with blocked/waiting/active legs. Add S6 and recheck everything. Target: running and verified by **16 Oct**.
3. **Milestone 3 (extension):** bounded transfer area at I. Expect a deadlock, document the counterexample, fix it, re-verify.
4. **Further extensions, if time allows:** crossing fairness; emergency while a car holds I; approach-zone reservation.

Open design decisions (see `docs/design.md`): opposite-direction pickups, idle position, when a car re-reads its stop set, P1 formulation, and whether the dispatcher and intersection manager need to communicate.
