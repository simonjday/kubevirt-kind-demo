# KubeVirt on kind (Colima, Apple Silicon M3)

**Run real, KVM-accelerated virtual machines on Kubernetes on a MacBook. kind runs on a Colima VM with nested virtualisation, and Argo CD delivers everything from an in-lab Gitea.**

```bash
git clone https://github.com/simonjday/kubevirt-kind-demo.git && cd kubevirt-kind-demo
./scripts/up.sh            # Colima VM -> kind -> Gitea -> Argo CD -> KubeVirt + CDI + demo VMs
./demo/flow-1-lifecycle.sh # then flow-2-datavolume.sh, flow-3-live-migration.sh
```

Versions verified 2026-11-07 · Target: MacBook Pro M3, macOS 15+, zsh

---

## TL;DR

| Item | Choice | Why |
|---|---|---|
| VM runtime | **Colima, `--vm-type vz --nested-virtualization`**, separate profile `kubevirt` | This is the only common Mac container runtime that exposes `/dev/kvm` inside the Linux VM. It needs an **M3 or later** and **macOS 15+**. Docker Desktop and Podman machine don't expose it |
| Kubernetes | **kind v0.33, `kindest/node:v1.35.8`** (digest pinned), 1 control plane + 2 workers | Two workers give live migration somewhere to go |
| KubeVirt | **v1.9.0** (30 Jul 2026), `useEmulation: false` | Hardware KVM. From 1.9, all Beta feature gates are on by default |
| CDI | **v1.66.1** | Pairs with KubeVirt 1.9. Imports cloud images into PVCs through DataVolumes |
| GitOps | **Argo CD** (argo-helm chart **10.7.1**), app-of-apps with sync waves | Operators go in wave 0, CRs in wave 1, VMs in wave 2. Application health is restored so the waves actually wait |
| Git source | **Gitea 1.26** as a container on the `kind` docker network | Self-contained: there's no dependency on `kind-devops-lab` or GitHub, and it survives cluster rebuilds |
| Guests | **arm64 only**: CirrOS containerDisk + Fedora 43 imported with CDI | KVM on aarch64 can't run x86 guests. TCG cross-arch emulation exists in 1.9, but only as an alpha |

```
 ┌──────────────────────── macOS (M3) ────────────────────────────────────────────┐
 │  Docker Desktop (untouched)        Colima VM "kubevirt" (vz, nested virt)      │
 │  velero-* clusters etc.            /dev/kvm ✔ · docker context colima-kubevirt │
 │                                    ┌─ docker network "kind" ──────────────────┐│
 │                                    │ kind: kubevirt-lab                       ││
 │                                    │  control-plane  worker  worker           ││
 │                                    │  argocd ─pull─┐  virt-launcher (qemu-kvm)││
 │                                    │               ▼                          ││
 │                                    │  gitea:3000 (container, volume)          ││
 │                                    └──────────────────────────────────────────┘│
 └──────────── 127.0.0.1:3300 → gitea · port-forward → argocd ───────────────────┘
```

## How it fits together

1. **`01-colima.sh`** starts the Colima profile and **fails fast** if `/dev/kvm` is missing. You can't add nested virtualisation to an existing profile, so if the check fails, delete the profile and recreate it. It also raises `fs.inotify.max_user_instances` to 8192. At Colima's default of 128, virt-handler crash-loops with `Failed to create an inotify watcher: too many open files`. The setting doesn't survive a VM restart, so the script reapplies it on every run.
2. **`02-cluster.sh`**: kind nodes are privileged containers, so they inherit `/dev/kvm` without `extraMounts`. The script checks every node, checks for cgroup v2 (cgroup v1 is deprecated in KubeVirt 1.9), and checks that the guest images have an arm64 variant.
3. **`03-gitea.sh`** runs Gitea, creates `lab/kubevirt-kind-demo`, and pushes this checkout.
4. **`04-argocd.sh`** is the only imperative step. It runs a Helm install of Argo CD and applies `gitops/bootstrap/root-app.yaml`. From then on, Git is the source of truth.

`scripts/env.sh` sets `DOCKER_CONTEXT=colima-kubevirt` **for the scripts' shell only**, so your Docker Desktop context and clusters are left alone. To use `kind` or `docker` against this lab yourself:

```bash
export DOCKER_CONTEXT=colima-kubevirt
```

## GitOps loop

```bash
# edit gitops/..., then
git commit -am "fedora: 4Gi"
./scripts/push.sh --refresh     # push HEAD to in-lab Gitea, ask Argo to reconcile now
```

To point Argo CD at GitHub instead, run `GITOPS_REPO_URL=https://github.com/simonjday/kubevirt-kind-demo.git ./scripts/04-argocd.sh`. The root app patches `repoURL` into every child Application.

| Path | Argo CD app | Wave |
|---|---|---|
| `gitops/platform/kubevirt-operator` | kubevirt-operator (upstream release manifest via kustomize remote resource) | 0 |
| `gitops/platform/cdi-operator` | cdi-operator | 0 |
| `gitops/platform/kubevirt` | kubevirt (KubeVirt CR) | 1 |
| `gitops/platform/cdi` | cdi (CDI CR) | 1 |
| `gitops/workloads/demo-vms` | demo-vms (namespace, `cirros`, `fedora`) | 2 |

`spec.runStrategy` on VMs is in `ignoreDifferences`. `virtctl start/stop` is an operational action, so self-heal doesn't revert it.

## Demo flows

| Script | Shows |
|---|---|
| `flow-1-lifecycle.sh` | The VM is a `virt-launcher` pod. Proof of KVM: the compute container requests `devices.kubevirt.io/kvm`. Then pause, unpause, stop and start |
| `flow-2-datavolume.sh` | CDI imports Fedora into a PVC (WaitForFirstConsumer), and the persistent VM boots from it with cloud-init |
| `flow-3-live-migration.sh` | The CirrOS VM (containerDisk, so it's migratable) moves to the other worker without a restart |

In-depth walkthrough of every flow (what KubeVirt does underneath, presenter setup, troubleshooting, Q&A): [`docs/demo-flows-explained.md`](docs/demo-flows-explained.md).

`./scripts/status.sh` shows apps, sync waves and health, per-node `devices.kubevirt.io/kvm` allocatable, VMs and VMIs. All jq filters are in `jq/`.

## Connecting to the VMs

| VM | Username | Password | Best way in |
|---|---|---|---|
| `fedora` | `fedora` | `kubevirt` (set by cloud-init) | VNC or SSH |
| `cirros` | `cirros` | `gocubsgo` (image default) | Serial console or SSH |

The VNC connection itself has **no password**: leave it blank if the viewer asks. These are throwaway lab credentials.

```bash
cd ~/git/kubevirt-kind-demo && export PATH="$PWD/bin:$PATH"
```

**Serial console (Terminal):**

```bash
virtctl --context kind-kubevirt-lab -n vm-demo console cirros
```

Press `Ctrl+]` to exit.

**Graphical console (VNC).** `virtctl vnc` launches TigerVNC, Chicken, RealVNC Viewer or `remote-viewer` automatically. macOS **Screen Sharing doesn't work**: it requires a VNC password, and KubeVirt's VNC server has none.

```bash
brew install --cask tigervnc-viewer
virtctl --context kind-kubevirt-lab -n vm-demo vnc fedora
```

To use any other VNC app, start only the proxy, then connect the app to `127.0.0.1:5901`:

```bash
virtctl --context kind-kubevirt-lab -n vm-demo vnc fedora --proxy-only --port 5901
```

**SSH** (Terminal, Termius, Royal TSX and so on). Keep the port-forward running while you're connected:

```bash
virtctl --context kind-kubevirt-lab -n vm-demo port-forward vm/fedora 2222:22
ssh -p 2222 fedora@127.0.0.1
```

For CirrOS, forward a different local port, e.g. `port-forward vm/cirros 2223:22`.

**Browsing the objects:** Freelens or Lens → `kind-kubevirt-lab` → Custom Resources → `kubevirt.io` lists VMs and VMIs. It has no console of its own.

Gotchas:

- `fedora` starts **Halted**. Run `virtctl ... start fedora`, or Flow 2, before you connect.
- If the Fedora login is rejected, cloud-init hasn't finished its first boot yet. Wait a minute and try again.
- CirrOS sends its output to the serial port, so its VNC screen may stay blank. Use `console`.
- zsh doesn't allow inline `# comments` by default: a pasted line with a trailing comment passes the comment as arguments (`accepts 1 arg(s), received 5`). Strip the comments, or add `setopt interactivecomments` to `~/.zshrc`.

## Caveats

- **Memory:** Colima takes 16 GiB. If Docker Desktop is also running with a 24 GiB VM, a 32 GB Mac will swap, so quit Docker Desktop or stop its clusters while you use this lab. `00-prereqs.sh` warns you about this.
- **No `/dev/kvm`?** (M1/M2, Docker Desktop, Podman): set `useEmulation: true` in `gitops/platform/kubevirt/kubevirt-cr.yaml`, then commit and push. Everything still works under QEMU TCG, but slowly.
- **Fedora VM** uses an RWO local-path PVC, so it's pinned to one node: `evictionStrategy: None`, and no live migration. Live migrating it would need RWX storage, for example Longhorn or NFS.
- **Not installed here:** Kyverno, Prometheus. If you add Kyverno, `virt-launcher` pods need exceptions. They run as non-root (UID 107), but add `NET_BIND_SERVICE` and request `devices.kubevirt.io/{kvm,tun,vhost-net}` device resources.
- **Lab credentials** (Gitea `lab/lab-gitea-pass`, Fedora `fedora/kubevirt`, Argo CD `server.insecure`) are throwaway values.

## Teardown

```bash
./scripts/teardown.sh        # kind cluster + Gitea; Colima VM kept
./scripts/teardown.sh --all  # also deletes the Colima profile
```
