# Vizxr — Kubernetes IDE for Android

**Kubernetes management in your pocket: browse, debug and change local and cloud clusters from one Android app.**

Vizxr is a mobile Kubernetes IDE. It talks directly to the Kubernetes API to browse resources, stream logs, read events and apply YAML.

---

## How it works

```
Android app (Flutter)
  └── Context manager ──▶ local and cloud clusters (kubeconfig)
  └── Kubernetes client (Dart) ──▶ HTTPS / TLS
                                   ├── Cloud clusters (AKS, GKE, EKS, self-hosted)
                                   └── Linxr's k3s on the same phone: localhost:6443
```

- **Pure client:** Vizxr runs no VM and no control plane of its own; it connects to clusters you already have.
- **Works with Linxr:** install k3s from the [Linxr](https://github.com/AI2TH/Linxr) Marketplace and connect to `localhost:6443` (forward port 6443 in Linxr if it is not listed).
- **Cloud ready:** import a kubeconfig for AKS, GKE, EKS or any self-hosted cluster. Bearer-token auth; `insecure-skip-tls-verify` is supported for home labs.
- **Demo mode:** point Vizxr at `demo.k8s.local` to try every screen against an in-memory mock cluster.

---

## Features

- **Cluster explorer:** Pods, Deployments, StatefulSets, DaemonSets, Jobs, CronJobs, Services, Ingresses, ConfigMaps, Secrets, PersistentVolumeClaims and Nodes.
- **Resource inspector:** a Lens-style slide-over with overview, containers and pod spec, live events and manifest YAML.
- **CRD explorer:** discover CustomResourceDefinitions and drill into their instances.
- **Logs:** stream a container's logs live (`follow=true`, like `kubectl logs -f`).
- **Events:** cluster and namespace event feed.
- **YAML apply:** create resources from YAML or JSON; existing objects are updated, like `kubectl apply`.
- **Helm on k3s:** list, install, roll back and uninstall k3s `HelmChart` releases (`helm.cattle.io/v1`).
- **Multi-cluster:** switch contexts from the cluster drawer.

## Status

| Feature | Status |
|---|---|
| Resource browsing, CRDs, logs, events, YAML apply | Working |
| Helm releases | Working on k3s; classic Helm v3 releases are next |
| CPU and memory metrics | In progress: the dashboard gauges show placeholder values until metrics-server integration lands |
| Pod exec terminal | In progress: the terminal view exists; exec over the Kubernetes API is being built |
| Port forwarding | Planned |

---

## Download

APK: [github.com/AI2TH/Vizxr/releases/latest](https://github.com/AI2TH/Vizxr/releases/latest) (Android 8.0+)

## License

Licensed under the GNU General Public License v3.0. See [LICENSE](LICENSE).

---

## About AI2TH

**Applied Intelligence To Tackle Hardships**

AI2TH builds open-source tools across Linux, Kubernetes, Bible study and security.

🌐 [ai2th.github.io](https://ai2th.github.io) · 💬 [AI2TH Google Group](https://groups.google.com/g/ai2th)
