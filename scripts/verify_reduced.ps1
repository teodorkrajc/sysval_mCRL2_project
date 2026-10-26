# Verification on reduced state spaces (used for MAXPOOL = 2).
# Needs the output of verify.ps1 first.
# Usage (from the repository root):
#   powershell -ExecutionPolicy Bypass -File scripts/verify_reduced.ps1
#   powershell -ExecutionPolicy Bypass -File scripts/verify_reduced.ps1 -Only g2a_requests

param([string]$Dir = "out/mp2", [switch]$Force, [string[]]$Only = @())

$Only  = @($Only | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$lts   = "$Dir/model_min.lts"
$lps   = "$Dir/model.lps"
$props = "TouchpointTowers/properties"
$out   = "$Dir/reduced"
New-Item -ItemType Directory -Force $out | Out-Null

$all = "request","stops","visit","move","open","close","enterI","leaveI","done","emergency","reset"

# groups of properties: which actions stay visible, how to minimise, what to check
$groups = @(
  @{ name = "g7_stops_move_open";  keep = "stops","move","open";                             eq = "branching-bisim";   check = "S9","S10","R5" },
  @{ name = "g1_intersection";     keep = "enterI","leaveI","move";                          eq = "branching-bisim";   check = "S1","S2" },
  @{ name = "g3_release";          keep = "enterI","leaveI","request","emergency","reset";   eq = "dpbranching-bisim"; check = "L4","R1","R2" },
  @{ name = "g4_emergency";        keep = "emergency","reset","move";                        eq = "branching-bisim";   check = "S8","R3","R8" },
  @{ name = "g6_doors";            keep = "open","close","move","visit";                     eq = "branching-bisim";   check = "S3","S4" },
  @{ name = "g8_stops_visit";      keep = "stops","visit";                                   eq = "branching-bisim";   check = "S5" },
  @{ name = "g5_deadlock";         keep = @();                                               eq = "dpbranching-bisim"; check = "L1" },
  @{ name = "g2a_requests";            keep = "request","done";                          eq = "branching-bisim";   check = "R6","R7"; perOrigin = "S7","L3" },
  @{ name = "g2b_requests_emergency";  keep = "request","done","emergency","reset";      eq = "dpbranching-bisim"; check = @();      perOrigin = "L2" }
)

# S7, L2 and L3 are checked once per origin
$locs  = "I","fl(A, 1)","fl(A, 2)","fl(A, 4)","fl(A, 5)","fl(B, 1)","fl(B, 2)","fl(B, 4)","fl(B, 5)"

# make the version of a formula that only covers trips from origin o
function OriginFormula([string]$p, [string]$o) {
  $f = Get-Content -Raw "$props/$p.mcf"
  if ($p -eq "L2") { $old = "val(!normal)"; $new = "val(!normal || !(o == $o))" }
  else             { $old = "val(validLoc(o) && validLoc(d))"; $new = "val(o == $o && validLoc(d))" }
  if (-not $f.Contains($old)) { throw "OriginFormula: '$old' not found in $p.mcf" }
  return $f.Replace($old, $new)
}

& {
  "=== reduced verification of $lts, started $(Get-Date) ==="
  if (-not (Test-Path $lts) -or -not (Test-Path $lps)) { "missing $lts or ${lps} (run verify.ps1 first)"; return }
  $results = @()

  foreach ($g in $groups) {
    if ($Only.Count -gt 0 -and $Only -notcontains $g.name) { continue }
    $red  = "$out/$($g.name).lts"
    $hide = ($all | Where-Object { $g.keep -notcontains $_ }) -join ","

    # hide the other actions and minimise (skipped if already done)
    if ($Force -or -not (Test-Path $red)) {
      "--- $($g.name): keep {$($g.keep -join ', ')}, minimise modulo $($g.eq)"
      $s = Get-Date
      cmd /c "ltsconvert -v --tau=$hide -e$($g.eq) $lts $red 2>&1"
      "    reduction took {0:N1}s" -f ((Get-Date) - $s).TotalSeconds
    } else {
      "--- $($g.name): reusing existing $red"
    }
    $size = (ltsinfo $red 2>&1 | Select-String "Number of states").ToString()
    "    $size"

    # check the properties of this group
    foreach ($p in $g.check) {
      $s = Get-Date
      lts2pbes -q -l $lps -f "$props/$p.mcf" $red "$out/$p.pbes"
      $r = pbessolve -q "$out/$p.pbes"
      if (-not $r) { $r = "ERROR" }
      $line = "{0,-4} {1,-6} {2,8:N1}s   ({3})" -f $p, $r, ((Get-Date) - $s).TotalSeconds, $g.name
      "    $line"
      $results += $line
    }

    # check the per-origin properties, one origin at a time
    foreach ($p in $g.perOrigin) {
      $s = Get-Date; $bad = @(); $i = 0
      New-Item -ItemType Directory -Force "$out/origins" | Out-Null
      foreach ($o in $locs) {
        $i++
        $mcf = "$out/origins/${p}_$i.mcf"
        Set-Content -Encoding ascii $mcf (OriginFormula $p $o)
        lts2pbes -q -l $lps -f $mcf $red "$out/origins/${p}_$i.pbes"
        $r = pbessolve -q "$out/origins/${p}_$i.pbes"
        Remove-Item "$out/origins/${p}_$i.pbes" -ErrorAction SilentlyContinue
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
} *>&1 | Tee-Object -FilePath "$out/log.txt" -Append
