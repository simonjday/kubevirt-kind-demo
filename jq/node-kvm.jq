# kubectl get nodes -o json | jq -r -f jq/node-kvm.jq
# virt-handler advertises devices.kubevirt.io/kvm only when /dev/kvm is usable.
.items[]
| [ .metadata.name, (.status.allocatable["devices.kubevirt.io/kvm"] // "0") ]
| @tsv
