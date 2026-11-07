# kubectl get applications -o json | jq -r -f jq/argocd-apps.jq
.items
| sort_by((.metadata.annotations["argocd.argoproj.io/sync-wave"] // "0" | tonumber), .metadata.name)[]
| [ .metadata.name,
    "wave=" + (.metadata.annotations["argocd.argoproj.io/sync-wave"] // "0"),
    (.status.sync.status // "-"),
    (.status.health.status // "-") ]
| @tsv
