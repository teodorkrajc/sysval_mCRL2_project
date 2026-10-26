# Full verification of the Touchpoint Towers model.
# Usage (from the repository root):
#   powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -MaxPool 2

param([int]$MaxPool = 1, [int]$Threads = 4)

$dir = "out/mp$MaxPool"
New-Item -ItemType Directory -Force $dir | Out-Null

& {
  "=== MAXPOOL = $MaxPool, started $(Get-Date) ==="
  mcrl22lps --version | Select-Object -First 1

  # copy the spec with the chosen MAXPOOL
  (Get-Content TouchpointTowers/TouchpointTowers_spec.mcrl2) -replace 'MAXPOOL = \d+;', "MAXPOOL = $MaxPool;" |
    Set-Content -Encoding ascii "$dir/spec.mcrl2"

  # linearise and simplify
  mcrl22lps -v "$dir/spec.mcrl2" "$dir/model.lps"
  lpssumelm -v "$dir/model.lps" "$dir/model.lps"
  lpsconstelm -v "$dir/model.lps" "$dir/model.lps"
  lpsparelm -v "$dir/model.lps" "$dir/model.lps"

  # generate the state space
  $s = Get-Date
  lps2lts -v --threads=$Threads "$dir/model.lps" "$dir/model.lts"
  "state space generation took {0:N1}s" -f ((Get-Date) - $s).TotalSeconds

  # reduce it (strong bisimulation)
  $s = Get-Date
  ltsconvert -v -ebisim "$dir/model.lts" "$dir/model_min.lts"
  "reduction took {0:N1}s" -f ((Get-Date) - $s).TotalSeconds

  # check every property (S6 has no formula)
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
