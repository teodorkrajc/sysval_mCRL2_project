# Per-property verification on reduced state spaces.
#
# Why: checking a property directly on the full MAXPOOL = 2 state space (27M states, 18.8M after
# strong-bisimulation reduction) needs ~30-50 GB of RAM. Each formula only mentions a few actions,
# so for each group of properties we
#   1. hide every action the group's formulas do not mention (it becomes the internal action tau),
#   2. minimise modulo branching bisimulation (merge states that behave the same if tau is ignored),
#   3. check the formulas on the much smaller result.
# This preserves the result of every formula that is insensitive to inserting or removing tau steps,
# which holds for all our S/L formulas (see docs/results.md). For liveness (L1, L2, L4), infinite tau
# loops matter, so those groups use the divergence-preserving variant.
# Validated on MAXPOOL = 1: same results as on the full state space, and a deliberately buggy model
# (enterI not gated by the emergency switch) is still caught (L4 = false).
#
# Input:  the strongly reduced LTS and the LPS from a verify.ps1 run (default: out/mp2).
# Run:    powershell -ExecutionPolicy Bypass -File scripts/verify_reduced.ps1            (MAXPOOL = 2)
#         powershell -ExecutionPolicy Bypass -File scripts/verify_reduced.ps1 -Dir out   (MAXPOOL = 1 run)
# Output: reduced LTSs and PBESs in <Dir>/reduced/, everything also logged to <Dir>/reduced/log.txt.
# A group whose reduced LTS already exists is not reduced again (use -Force to redo), so the script can
# be restarted after an interruption.

# -Only g2a_requests,g2b_requests_emergency   runs only the named groups (e.g. after an interruption).

param([string]$Dir = "out/mp2", [switch]$Force, [string[]]$Only = @())

$Only  = @($Only | ForEach-Object { $_ -split ',' } | Where-Object { $_ })   # -File passes "a,b" as one string
$lts   = "$Dir/model_min.lts"   # state space to reduce (strong-bisimulation reduced, from verify.ps1)
$lps   = "$Dir/model.lps"       # supplies the data types and actions that lts2pbes needs for the formulas
$props = "TouchpointTowers/properties"
$out   = "$Dir/reduced"
New-Item -ItemType Directory -Force $out | Out-Null

# All visible actions of the model. Anything not listed in a group's "keep" is hidden.
$all = "request","stops","visit","move","open","close","enterI","leaveI","done","emergency","reset"

# The groups: which actions stay visible, which equivalence to minimise with, which formulas to check.
# Hiding fewer actions than a formula strictly needs is still sound (just less reduction); that is what
# lets several properties share one reduction. Order: quick groups first, the per-origin groups last.
$groups = @(
  @{ name = "g7_stops_move_open";  keep = "stops","move","open";                             eq = "branching-bisim";   check = "S9","S10","R5" },
  @{ name = "g1_intersection";     keep = "enterI","leaveI","move";                          eq = "branching-bisim";   check = "S1","S2" },
  # requests: S7, L3 and R6/R7 do not mention emergency/reset and are safety/reachability properties,
  # so they get the smaller plain-branching reduction; only L2 needs emergency/reset and divergence.
  @{ name = "g3_release";          keep = "enterI","leaveI","request","emergency","reset";   eq = "dpbranching-bisim"; check = "L4","R1","R2" },
  @{ name = "g4_emergency";        keep = "emergency","reset","move";                        eq = "branching-bisim";   check = "S8","R3","R8" },
  @{ name = "g6_doors";            keep = "open","close","move","visit";                     eq = "branching-bisim";   check = "S3","S4" },
  @{ name = "g8_stops_visit";      keep = "stops","visit";                                   eq = "branching-bisim";   check = "S5" },
  @{ name = "g5_deadlock";         keep = @();                                               eq = "dpbranching-bisim"; check = "L1" },
  # S7, L3 and L2 quantify over all 72 trips (o, d); checked in one go they need too much memory, so they are
  # checked once per origin ("perOrigin", see below). These are the slowest groups, so they come last.
  @{ name = "g2a_requests";            keep = "request","done";                          eq = "branching-bisim";   check = "R6","R7"; perOrigin = "S7","L3" },
  @{ name = "g2b_requests_emergency";  keep = "request","done","emergency","reset";      eq = "dpbranching-bisim"; check = @();      perOrigin = "L2" }
)
# Per-origin checking. A formula "for all trips (o, d): phi(o, d)" is true iff, for every origin P, it holds for
# all trips starting at P. Checking one origin at a time (8 trips) needs about 1/9 of the memory of all 72 trips
# at once, and only 9 runs instead of 72 (each run spends most of its time loading the reduced LTS).
# The instance for origin P is made by a textual change of the formula file:
#   S7, L3: the bound  val(validLoc(o) && validLoc(d))  becomes  val(o == P && validLoc(d))
#   L2:     the obligation guard  val(!normal)  becomes  val(!normal || !(o == P)), i.e. the "inevitably done"
#           obligation is only checked for requests from P; the outer loop over all requests, emergencies and
#           resets stays exactly as it is (restricting that loop would weaken the formula).
$locs  = "I","fl(A, 1)","fl(A, 2)","fl(A, 4)","fl(A, 5)","fl(B, 1)","fl(B, 2)","fl(B, 4)","fl(B, 5)"   # 9 origins
function OriginFormula([string]$p, [string]$o) {
  $f = Get-Content -Raw "$props/$p.mcf"
  if ($p -eq "L2") { $old = "val(!normal)"; $new = "val(!normal || !(o == $o))" }
  else             { $old = "val(validLoc(o) && validLoc(d))"; $new = "val(o == $o && validLoc(d))" }
  if (-not $f.Contains($old)) { throw "OriginFormula: '$old' not found in $p.mcf" }
  return $f.Replace($old, $new)
}

# Not checked here: S6 (holds by construction, see S6.mcf), R4 and R9 (they require two actions directly
# after each other, which minimisation does not preserve; both are true on the full MAXPOOL = 1 model).

& {
  "=== reduced verification of $lts, started $(Get-Date) ==="
  if (-not (Test-Path $lts) -or -not (Test-Path $lps)) { "missing $lts or ${lps} (run verify.ps1 first)"; return }
  $results = @()

  foreach ($g in $groups) {
    if ($Only.Count -gt 0 -and $Only -notcontains $g.name) { continue }
    $red  = "$out/$($g.name).lts"
    $hide = ($all | Where-Object { $g.keep -notcontains $_ }) -join ","

    # Step 1+2: hide the actions this group does not need (--tau) and minimise (-e).
    # ltsconvert loads the whole input LTS, so this is the slow, memory-heavy step (minutes per group).
    if ($Force -or -not (Test-Path $red)) {
      "--- $($g.name): keep {$($g.keep -join ', ')}, minimise modulo $($g.eq)"
      $s = Get-Date
      # (run via cmd so its progress messages on stderr are logged as plain text, not as PowerShell errors)
      cmd /c "ltsconvert -v --tau=$hide -e$($g.eq) $lts $red 2>&1"
      "    reduction took {0:N1}s" -f ((Get-Date) - $s).TotalSeconds
    } else {
      "--- $($g.name): reusing existing $red"
    }
    # ltsinfo prints the size of the reduced state space.
    $size = (ltsinfo $red 2>&1 | Select-String "Number of states").ToString()
    "    $size"

    # Step 3: per formula, build the equation system (lts2pbes: formula + reduced LTS) and solve it (pbessolve).
    foreach ($p in $g.check) {
      $s = Get-Date
      lts2pbes -q -l $lps -f "$props/$p.mcf" $red "$out/$p.pbes"
      $r = pbessolve -q "$out/$p.pbes"
      if (-not $r) { $r = "ERROR" }
      $line = "{0,-4} {1,-6} {2,8:N1}s   ({3})" -f $p, $r, ((Get-Date) - $s).TotalSeconds, $g.name
      "    $line"
      $results += $line
    }

    # Step 3b: the per-origin properties: one formula instance per origin, true iff all 9 instances are true.
    foreach ($p in $g.perOrigin) {
      $s = Get-Date; $bad = @(); $i = 0
      New-Item -ItemType Directory -Force "$out/origins" | Out-Null
      foreach ($o in $locs) {
        $i++
        $mcf = "$out/origins/${p}_$i.mcf"
        Set-Content -Encoding ascii $mcf (OriginFormula $p $o)
        lts2pbes -q -l $lps -f $mcf $red "$out/origins/${p}_$i.pbes"
        $r = pbessolve -q "$out/origins/${p}_$i.pbes"
        Remove-Item "$out/origins/${p}_$i.pbes" -ErrorAction SilentlyContinue   # keep disk usage low
        if ($r -ne "true") { $bad += "origin $o : $(if ($r) { $r } else { 'ERROR' })" }
        "    $p : origin $i/9 ($o) $(if ($r) { $r } else { 'ERROR' }), {0:N0}s so far" -f ((Get-Date) - $s).TotalSeconds
      }
      $r = if ($bad.Count -eq 0) { "true" } else { "false" }
      $line = "{0,-4} {1,-6} {2,8:N1}s   ({3}, per origin: {4} of 9 true)" -f $p, $r, ((Get-Date) - $s).TotalSeconds, $g.name, (9 - $bad.Count)
      "    $line"
      $bad | ForEach-Object { "      not true for $_" }
      $results += $line
    }
  }

  "=== results ==="
  $results
  "=== finished $(Get-Date) ==="
} *>&1 | Tee-Object -FilePath "$out/log.txt" -Append   # -Append: a restart adds to the log instead of overwriting it
