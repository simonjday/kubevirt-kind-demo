# kubectl get vmi <name> -o json | jq -r -f jq/vmi-timings.jq
# Seconds between VMI phase transitions. "Running" = QEMU started, not guest login.
(.status.phaseTransitionTimestamps // [])
| map({ (.phase): (.phaseTransitionTimestamp | fromdateiso8601) }) | add // {}
| . as $p
| def d(a; b): if ($p[a] and $p[b]) then "\($p[b] - $p[a])s" else "-" end;
  "Pending→Scheduled \(d("Pending"; "Scheduled"))  Scheduled→Running \(d("Scheduled"; "Running"))  total \(d("Pending"; "Running"))"
