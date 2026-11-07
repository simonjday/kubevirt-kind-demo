# kubectl get vmi -A -o json | jq -r -f jq/vmi-summary.jq
.items[]
| [ .metadata.name,
    (.status.phase // "-"),
    (.status.nodeName // "-"),
    ((.status.interfaces // [])[0].ipAddress // "-"),
    (if .status.migrationState.completed then "yes" else "no" end) ]
| @tsv
