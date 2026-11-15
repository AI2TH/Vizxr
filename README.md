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
- **Works with Linxr:** install k3s from the [Linxr](https://github.com/AI2TH/Linxr) Marketplace and pick the **Linxr on this phone** cluster. It connects to `127.0.0.1:6443` and, only for this cluster type, falls back to Linxr's VM address `172.16.0.2` on the same port (forward port 6443 in Linxr if neither answers).
- **Cloud ready:** import a kubeconfig for AKS, GKE, EKS or any self-hosted cluster. Bearer-token (`token`, `tokenFile`) and client-certificate auth. TLS is verified against the kubeconfig's CA unless it sets `insecure-skip-tls-verify: true`. Exec and auth-provider plugins (`aws`, `gke-gcloud-auth-plugin`, `kubelogin`) cannot run on Android; use a ServiceAccount token instead. Tokens and client keys are stored in the Android Keystore (`flutter_secure_storage`); configs saved by older versions are migrated on first launch.
- **Demo mode:** point Vizxr at `demo.k8s.local` to try every screen against an in-memory mock cluster.

---

## Features

- **Cluster explorer:** Pods, Deployments, StatefulSets, DaemonSets, Jobs, CronJobs, Services, Ingresses, ConfigMaps, Secrets, PersistentVolumeClaims and Nodes.
- **Resource inspector:** a Lens-style slide-over with overview, containers and pod spec, live events and manifest YAML.
- **CRD explorer:** discover CustomResourceDefinitions and drill into their instances.
- **Logs:** stream a container's logs live (`follow=true`, like `kubectl logs -f`).
- **Pod exec:** an interactive shell in a container over the Kubernetes exec WebSocket (`v4.channel.k8s.io`), with terminal resize.
- **Metrics:** cluster CPU and memory against node allocatable, per-node and per-pod usage, from metrics-server, with sparklines of the last 40 samples (every 15 s while a metrics view is open).
- **Port forwarding:** forward a Service to `localhost` on the phone through the `portforward` subresource, then open it in the browser.
- **Events:** cluster and namespace event feed.
- **YAML apply:** apply one or many documents (`---`) from YAML or JSON with server-side apply (`fieldManager=vizxr`), like `kubectl apply --server-side`; field conflicts can be forced. View YAML shows real YAML.
- **Helm:** list Helm v3 releases (read from their storage Secrets) and k3s `HelmChart` objects, labelled separately. On k3s, install and uninstall HelmCharts; on other clusters the Helm screen is read-only and says so. Helm v3 releases are always read-only.
- **Multi-cluster:** switch, rename, edit and remove clusters from the cluster drawer. Each cluster has its own id, so two kubeconfigs with the same context name no longer overwrite each other. Clusters that skip TLS verification show a "TLS off" badge; turn verification on from the edit screen.

## Status

| Feature | Status |
|---|---|
| Resource browsing, CRDs, logs, events | Working |
| YAML apply | Multi-document server-side apply. Unit-tested against a fake API server; needs testing on a device against a live cluster |
| Cluster management | Ids, rename, edit screen, TLS verification switch and badge, "Linxr on this phone" type. Credentials in the Android Keystore with migration from SharedPreferences. Needs testing on a device (Keystore and migration from an older install) |
| Helm releases | Helm v3 releases listed read-only; k3s HelmCharts listed, installed and uninstalled. Read-only with an explanation on clusters without the k3s helm-controller. Rollback is not supported (use the helm CLI) |
| CPU and memory metrics | Implemented with metrics-server (k3s ships it), with history sparklines for the cluster, nodes and pods; shows "Metrics unavailable" without it. Per-pod usage is not shown in the list screens yet. Needs testing on a device |
| Pod exec terminal | Implemented over the exec WebSocket. Needs testing on a device against a live cluster |
| Port forwarding | Implemented for Services (one WebSocket per connection), with Open in browser. Forwards stop when the app is closed, Android kills it, or the cluster changes: keeping them alive needs a foreground service, which is not implemented (it needs native Android code or a plugin plus notification and foreground-service permissions). Needs testing on a device |
| CI | GitHub Actions: `flutter analyze`, `flutter test` (Flutter 3.22.2) and gitleaks on every pull request |

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
