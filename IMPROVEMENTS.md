# Vizxr — Improvements

What still needs work, in priority order. Last reviewed: November 2026 (after the code review in #6).

---

## P0 — Security

### 1. A cluster-admin key is in git history and old APKs
- **What:** `lib/services/kubeconfig.dart` on `main` contained a `kubernetes-admin` kubeconfig with a client certificate and private key for `https://172.16.0.2:6443`. #6 removes it from the code, but it stays in history and in every APK released before #6.
- **How to fix:**
  1. Rotate that cluster's admin certificate (and CA if it could be trusted elsewhere): `kubeadm certs renew admin.conf`, or recreate the cluster if it was a throwaway VM.
  2. Optionally purge it from history with `git filter-repo --replace-text secrets.txt` (listing the certificate and key blocks), then force-push and ask forks to re-clone. Rotation matters more than the purge: the key is already public.
  3. Add a secret-scanning check (gitleaks) in CI so it cannot happen again.

### 2. Credentials stored in plain SharedPreferences
- **What:** tokens and client keys are saved unencrypted.
- **How to fix:** move secrets to Android Keystore via `flutter_secure_storage`; keep only non-secret config in SharedPreferences, and migrate existing entries on first launch.

### 3. Old saved configs keep TLS verification off
- **What:** #6 fixes the default, but configs saved before it keep `insecureSkipTlsVerify: true`, and there is no edit screen.
- **How to fix:** add an edit screen with a "Verify TLS certificates" switch, and show a warning badge on clusters that skip verification.

---

## P1 — Correctness

### 4. Configs with the same context name overwrite each other
Two k3s kubeconfigs (both `default`) collide. Key clusters by a generated id and let users rename them.

### 5. YAML apply is single-document and uses PUT
Split multi-document YAML (`---`), and use server-side apply (`PATCH` with `application/apply-patch+yaml`, `fieldManager=vizxr`) to match `kubectl apply`.

### 6. `addFromYaml` truncates after the first private-key footer
It cuts everything after `-----END RSA PRIVATE KEY-----` to work around pasted notes. Parse the YAML properly and report errors instead.

### 7. Screens refetch on every rebuild
Several screens create their `Future` inside `build()`. Move them to `initState` / a provider and refresh explicitly (pull-to-refresh, timer).

### 8. Cluster-scoped custom resources are deleted with a namespaced path
Use the CRD's `scope` to build the path (`/apis/<g>/<v>/<plural>/<name>` when cluster-scoped).

### 9. Networking tab "View YAML" is not YAML
It prints top-level `key: value` pairs. Use the same YAML serializer as the inspector.

### 10. Hard-coded Linxr address fallback
The `172.16.0.2` ↔ `127.0.0.1` fallback is specific to Linxr. Make it an explicit "Linxr on this phone" cluster type instead of a silent retry.

---

## P2 — Product

### 11. Helm beyond k3s — #5
- Install still creates a k3s `HelmChart`, so it fails on other clusters.
- No repository browser.
- Helm v3 rollback and uninstall need Helm SDK logic.
Options: a small in-cluster helper Job that runs `helm`, or limit Helm to read-only outside k3s and say so.

### 12. Port forwarding polish — #4
No half-close support in the v4 protocol, no "Open in browser" (add `url_launcher`), and forwards stop when Android kills the app (consider a foreground service while forwards are active).

### 13. Real metrics history
#6 adds live metrics; keep a short history per node and pod for real sparklines, and show per-pod usage in lists.

---

## P3 — Process

### 14. CI
Add GitHub Actions running `flutter analyze`, `flutter test` and gitleaks on every PR.

### 15. Device test checklist
Before each release: metrics, exec, port forwarding and Helm against Linxr's k3s and one cloud cluster; record results in the release notes.
