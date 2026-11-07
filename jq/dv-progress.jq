# kubectl get dv -o json | jq -r -f jq/dv-progress.jq
.items[] | [ .metadata.name, (.status.phase // "-"), (.status.progress // "-") ] | @tsv
