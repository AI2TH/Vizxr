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
- **Cloud ready:** import a kubeconfig for AKS, GKE, EKS or any self-hosted cluster. Bearer-token (`token`, `tokenFile`) and client-certificate auth. TLS is verified against the kubeconfig's CA unless it sets `insecure-skip-tls-verify: true`. Exec and auth-provider plugins (`aws`, `gke-gcloud-auth-plugin`, `kubelogin`) cannot run on Android; use a ServiceAccount token instead.
- **Demo mode:** point Vizxr at `demo.k8s.local` to try every screen against an in-memory mock cluster.

---

## Features

- **Cluster explorer:** Pods, Deployments, StatefulSets, DaemonSets, Jobs, CronJobs, Services, Ingresses, ConfigMaps, Secrets, PersistentVolumeClaims and Nodes.
- **Resource inspector:** a Lens-style slide-over with overview, containers and pod spec, live events and manifest YAML.
- **CRD explorer:** discover CustomResourceDefinitions and drill into their instances.
- **Logs:** stream a container's logs live (`follow=true`, like `kubectl logs -f`).
- **Pod exec:** an interactive shell in a container over the Kubernetes exec WebSocket (`v4.channel.k8s.io`), with terminal resize.
- **Metrics:** cluster CPU and memory against node allocatable, and per-pod usage, from metrics-server.
- **Port forwarding:** forward a Service to `localhost` on the phone through the `portforward` subresource.
- **Events:** cluster and namespace event feed.
- **YAML apply:** create resources from YAML or JSON; existing objects are updated, like `kubectl apply`.
- **Helm:** list Helm v3 releases (read from their storage Secrets) and k3s `HelmChart` objects, labelled separately. Install and uninstall k3s HelmCharts; Helm v3 releases are read-only.
- **Multi-cluster:** switch contexts from the cluster drawer.

## Status

| Feature | Status |
|---|---|
| Resource browsing, CRDs, logs, events, YAML apply | Working |
| Helm releases | Helm v3 releases listed read-only; k3s HelmCharts listed, installed and uninstalled. Rollback is not supported (use the helm CLI) |
| CPU and memory metrics | Implemented with metrics-server (k3s ships it); shows "Metrics unavailable" without it. Needs testing on a device |
| Pod exec terminal | Implemented over the exec WebSocket. Needs testing on a device against a live cluster |
| Port forwarding | Implemented for Services (one WebSocket per connection); stops when the app is closed or the cluster changes. Needs testing on a device |

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
