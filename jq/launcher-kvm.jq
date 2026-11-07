# kubectl get pod <virt-launcher> -o json | jq -r -f jq/launcher-kvm.jq
# A VMI scheduled with hardware virt requests devices.kubevirt.io/kvm; under useEmulation it doesn't.
.spec.containers[]
| select(.name == "compute")
| "compute container requests devices.kubevirt.io/kvm = \(.resources.requests["devices.kubevirt.io/kvm"] // "none (emulation)")"
