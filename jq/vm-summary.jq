# kubectl get vm -A -o json | jq -r -f jq/vm-summary.jq
.items[]
| [ .metadata.namespace,
    .metadata.name,
    (.spec.runStrategy // "-"),
    (.status.printableStatus // "-"),
    ((.status.conditions // []) | map(select(.type == "Ready")) | (.[0].status // "-")) ]
| @tsv
