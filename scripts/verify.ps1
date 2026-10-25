# Full verification pipeline for the Touchpoint Towers model.
# Run from the repository root:  powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -MaxPool 2
# Works on a copy of the spec with MAXPOOL replaced, so the spec file itself is not changed.
# Everything goes to out/mp<N>/; the console output is also saved in out/mp<N>/log.txt.

param([int]$MaxPool = 1, [int]$Threads = 4)

$dir = "out/mp$MaxPool"
New-Item -ItemType Directory -Force $dir | Out-Null

& {
  "=== MAXPOOL = $MaxPool, started $(Get-Date) ==="
  mcrl22lps --version | Select-Object -First 1

  # spec copy with the chosen bound (the spec is pure ASCII)
  (Get-Content TouchpointTowers/TouchpointTowers_spec.mcrl2) -replace 'MAXPOOL = \d+;', "MAXPOOL = $MaxPool;" |
    Set-Content -Encoding ascii "$dir/spec.mcrl2"

  # 1. linearise and clean up the LPS
  mcrl22lps -v "$dir/spec.mcrl2" "$dir/model.lps"
  lpssumelm -v "$dir/model.lps" "$dir/model.lps"
  lpsconstelm -v "$dir/model.lps" "$dir/model.lps"
  lpsparelm -v "$dir/model.lps" "$dir/model.lps"

  # 2. state space, once
  $s = Get-Date
  lps2lts -v --threads=$Threads "$dir/model.lps" "$dir/model.lts"
  "state space generation took {0:N1}s" -f ((Get-Date) - $s).TotalSeconds

  # 3. reduce modulo strong bisimulation (preserves all mu-calculus properties)
  $s = Get-Date
  ltsconvert -v -ebisim "$dir/model.lts" "$dir/model_min.lts"
  "reduction took {0:N1}s" -f ((Get-Date) - $s).TotalSeconds

  # 4. every property against the reduced state space (S6 is not model-checked, see S6.mcf)
  $props = "S1","S2","S3","S4","S5","S7","S8","S9","S10","L1","L2","L3","L4",
           "R1","R2","R3","R4","R5","R6","R7","R8","R9"
  foreach ($p in $props) {
    $s = Get-Date
    lts2pbes -q -l "$dir/model.lps" -f "TouchpointTowers/properties/$p.mcf" "$dir/model_min.lts" "$dir/$p.pbes"
    $r = pbessolve -q "$dir/$p.pbes"
    "{0,-4} {1,-6} {2,8:N1}s" -f $p, $r, ((Get-Date) - $s).TotalSeconds
  }
  "=== finished $(Get-Date) ==="
} *>&1 | Tee-Object -FilePath "$dir/log.txt"
