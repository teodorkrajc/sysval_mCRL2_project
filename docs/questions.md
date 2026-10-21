# Questions for the tutor meeting (22 Oct 2026)

Each question has the context needed to ask it. Details are in `docs/design.md` (sections 5 and 6).

## 1. S6 (transfer order): "by construction" instead of a formula?

**Context.** S6: a transfer passenger may only board car B at I after car A has dropped them there. In our model this cannot go wrong *by construction*: a cross-wing request is stored as one pool entry that is **rewritten** into its second leg at the moment car A drops the passenger at I. Before that, no second leg exists that B could serve.

Expressing it as a µ-calculus formula is hard:
- formulas only see actions, and boarding/alighting happen silently inside the dispatcher's pool update on `visit`;
- a per-passenger formula would need passenger identities, but identical requests are merged and the pool does not track passengers (5-field request entries, no IDs);
- an earlier draft of S6 used `request(i, o, d)` with a request ID, which does not exist in our model.

The alternative would be to add `pickup`/`dropoff` report actions (two extra request states plus two dispatcher branches) and a counter formula ("pickups at I never outnumber drop-offs at I" per trip).

**Question:** is arguing S6 by construction in the report acceptable, or do you expect it model-checked, e.g. with `pickup`/`dropoff` actions?

## 2. State space size and which bound to verify

**Context.** `MAXPOOL` bounds the number of outstanding requests. Measured: `MAXPOOL = 1` gives 126,850 states (41 s to generate). `MAXPOOL = 2` is expected to be in the millions: two independent cars, 72 possible requests, an emergency switch and pending completion reports all multiply. The design document originally said 5.

**Questions:**
- Is verifying with `MAXPOOL = 1` (and `MAXPOOL = 2` for some properties, if feasible) acceptable, if we state and motivate the bound?
- Which techniques would you recommend for a larger bound? (Generate the LTS once and check formulas against it with `lts2pbes`; LTS reduction modulo bisimulation first; `lpsparunfold`/`lpsrewr`; the `jittyc` rewriter, which may not be available on Windows; other `pbessolve` strategies?)

## 3. Are our formula revisions sound and acceptable?

**Context.** Three formulas did not terminate as first written, and were rewritten without (we believe) changing their meaning. Originals and reasoning are in `design.md` section 5.
- **S2:** `forall f1, f2: Nat . val(...) => [... move(e, f1, f2)] false` became `[... exists f1, f2: Nat . val(...) && move(e, f1, f2)] false`. The outer `forall` over `Nat` made the solver enumerate infinitely many pairs.
- **S7:** two unbounded counters (requests accepted / completed) became one counter of outstanding requests, **capped at `MAXPOOL`**. Our soundness argument: the capped counter is never larger than the real one, so passing the capped check implies passing the original; and it never drops below the number of pool entries for that trip, so it cannot fail spuriously.
- **S7, L3:** `forall o, d: Loc` became `forall o, d: Loc . val(validLoc(o) && validLoc(d)) => …`, because `Loc` contains `fl(A, 17)` and so on. Requests only occur for valid locations, so we believe this is not a weakening.

**Questions:** are these rewrites sound and acceptable as presented? Is the capping argument rigorous enough for the report?

## 4. Emergency design

**Context.** An emergency **pauses** the system instead of resetting it, so that no requests are lost and liveness still holds after `reset`. It is modelled as a fifth process, an *emergency switch*, which plays the role of the button. Cars' `move` and the dispatcher's `request` must synchronise with it, and it only allows them while no emergency is active. Everything else (stop-set reads, visits, completion reports, the intersection manager) is bookkeeping and continues. A car that is serving a floor may finish (open, visit, close). Our first design had both cars synchronise directly on `emergency`/`reset`.

We decided **not** to open the doors on emergency: S10 says doors only open where there is work, and changing that would weaken a requirement.

**Questions:**
- Is a separate switch process that gates moves and requests a reasonable way to model this?
- Is "no new moves, no new requests, everything else continues" an acceptable reading of "emergency stops both cars" (S8)?

## 5. Liveness without fairness (L2, L4)

**Context.** mCRL2 has no built-in fairness. L2 ("every request is served") is stated as: after `request(o, d)`, `done(o, d)` is inevitable on all paths **without further `request`, `emergency` or `reset`**, and only for requests made outside an emergency (tracked with a `normal` flag). L4 uses the same exclusion.

**Question:** is excluding environment actions an acceptable way to state these properties? Should the report discuss stronger fairness-based versions?

## 6. Merging identical requests

**Context.** Identical pool entries are merged. Two passengers making the same request before pickup share one entry and get one `done`. Requests made after the first passenger boarded stay separate (different state).

**Question:** is one `done` for merged identical requests acceptable with respect to L2 ("every request is eventually completed") and S7?

**Related limitation.** `done(o, d)` names a *trip*, not a passenger. If a request A1 → A5 arrives while an older A1 → A5 entry is already `finished` but not yet reported, the old `done(A1, A5)` satisfies L2 for the new request too, even though the new passenger has not moved yet. The new passenger is still served; L2 just doesn't prove it. The root cause is the same as for S6 (no passenger identities). Is it enough to discuss this as a limitation in the report?

## 7. Conditional equations: is there a reference?

**Context.** A recursive function written with `if(...)`, e.g. `nextUp(n, S) = if(n >= 5, 0, ... nextUp(n + 1, S))`, made `mcrl22lps` loop forever: during linearisation `n` is still a variable, so the rewriter unfolds the recursion endlessly. Conditional equations (`n < 5 -> nextUp(n, S) = ...`) fix it, because they only fire once the condition is decidable. We demonstrated this with `mcrl2i`.

**Question:** is this documented somewhere (mCRL2 manual, the mCRL2 book) that we can cite?

## 8. Report expectations

- How much of the mCRL2 specification should be in the main text vs. an appendix?
- We dropped the planned extension (bounded transfer area at I, expected to deadlock). Is an extension expected for a good grade, or is the core model with full verification enough?
- If all properties pass, what do you want to see about verification beyond the result table (sanity/reachability checks, timings, a deliberately broken variant that shows a property can fail)?
