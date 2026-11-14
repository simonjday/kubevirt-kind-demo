# kubectl get vmim -o json | jq -r -f jq/vmim-timings.jq
# Wall-clock duration of each live migration.
.items[]
| .status.migrationState as $m
| [ .metadata.name, (.status.phase // "-"),
    (if ($m.startTimestamp and $m.endTimestamp)
     then "\(($m.endTimestamp | fromdateiso8601) - ($m.startTimestamp | fromdateiso8601))s"
     else "-" end),
    ($m.sourceNode // "-") + " → " + ($m.targetNode // "-") ]
| @tsv
