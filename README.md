# Vizxr — High-fidelity Kubernetes IDE for Android

**High-fidelity Kubernetes management in your pocket — manage remote and local clusters from a single app.**

Vizxr provides an interactive, mobile-optimized IDE for Kubernetes. It allows for deep visibility into cluster health, resource management, log streaming, and pod shell access.

---

## How it works

```
Android App (Flutter)
  └── Multi-Context Support ──▶  Context Management (Local/Cloud)
  └── K8s Client (Dart)     ──▶  HTTPS / TLS Connectivity
                                  ├── Remote Clusters (AKS, GKE, EKS)
                                  └── Local Clusters (via Kubxr) :6443
```

- **Pure UI/IDE layer** — Does not host its own control plane; connects to existing clusters.
- **Cross-App Communication** — Seamlessly connects to the local [Kubxr](../k8s/README.md) node via `localhost:6443`.
- **Cloud Ready** — Support for AKS, GKE, and self-hosted clusters via Kubeconfig import.

---

## Features

- **Cluster Explorer**: Hierarchical view of Nodes, Workloads, Network, Configuration, and Storage.
- **Interactive Tools**:
  - **Log Streamer**: Tail logs from multiple containers in real-time.
  - **Pod Exec**: Integrated terminal for `kubectl exec` directly into containers.
  - **YAML Editor**: View and modify resource manifests with syntax highlighting.
- **Multi-Cluster Shifting**: Quickly toggle between contexts via the Cluster Drawer.
- **Real-time Metrics**: Visual indicators for pod and node resource utilization.

---

## About AI2TH

**Applied Intelligence To Tackle Hardships**

AI2TH builds developer tools that bring powerful computing environments to constrained devices.

🌐 [ai2th.github.io](https://ai2th.github.io)
