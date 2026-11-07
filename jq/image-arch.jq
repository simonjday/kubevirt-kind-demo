# docker manifest inspect <image> | jq -r -f jq/image-arch.jq
if .manifests then [.manifests[].platform | "\(.os)/\(.architecture)"] | join(", ")
else "single-arch manifest (inspect config to confirm)" end
