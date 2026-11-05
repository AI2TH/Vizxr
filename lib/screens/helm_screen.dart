import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/cluster_state.dart';
import '../services/k8s_client.dart';
import '../theme/lens_theme.dart';
import 'yaml_editor_screen.dart';

class HelmChartCatalogItem {
  final String name;
  final String repoName;
  final String repoUrl;
  final String version;
  final String appVersion;
  final String category;
  final String description;
  final IconData icon;
  final Color accentColor;
  final String defaultValuesYaml;

  const HelmChartCatalogItem({
    required this.name,
    required this.repoName,
    required this.repoUrl,
    required this.version,
    required this.appVersion,
    required this.category,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.defaultValuesYaml,
  });
}

const List<HelmChartCatalogItem> kHelmCatalog = [
  HelmChartCatalogItem(
    name: 'nginx',
    repoName: 'bitnami',
    repoUrl: 'https://charts.bitnami.com/bitnami',
    version: '15.14.0',
    appVersion: '1.25.4',
    category: 'Web / App',
    description: 'High-performance HTTP server, reverse proxy, and edge gateway.',
    icon: Icons.language_rounded,
    accentColor: LensTheme.statusGreen,
    defaultValuesYaml: '''replicaCount: 1
image:
  registry: docker.io
  repository: bitnami/nginx
  tag: 1.25.4-debian-12-r0
service:
  type: ClusterIP
  port: 80
resources:
  limits:
    cpu: 250m
    memory: 256Mi
  requests:
    cpu: 50m
    memory: 64Mi
''',
  ),
  HelmChartCatalogItem(
    name: 'redis',
    repoName: 'bitnami',
    repoUrl: 'https://charts.bitnami.com/bitnami',
    version: '18.6.1',
    appVersion: '7.2.3',
    category: 'Databases',
    description: 'Blazing-fast in-memory key-value data store, cache, and message broker.',
    icon: Icons.memory_rounded,
    accentColor: LensTheme.statusRed,
    defaultValuesYaml: '''architecture: standalone
auth:
  enabled: false
master:
  persistence:
    enabled: true
    size: 4Gi
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 100m
      memory: 128Mi
''',
  ),
  HelmChartCatalogItem(
    name: 'postgresql',
    repoName: 'bitnami',
    repoUrl: 'https://charts.bitnami.com/bitnami',
    version: '13.2.24',
    appVersion: '16.1.0',
    category: 'Databases',
    description: 'Powerful, enterprise-grade open-source object-relational database.',
    icon: Icons.storage_rounded,
    accentColor: LensTheme.blueAccent,
    defaultValuesYaml: '''global:
  postgresql:
    auth:
      postgresPassword: "postgrespassword"
      username: "appuser"
      password: "apppassword"
      database: "appdb"
primary:
  persistence:
    enabled: true
    size: 10Gi
  resources:
    limits:
      cpu: 1000m
      memory: 1Gi
    requests:
      cpu: 200m
      memory: 256Mi
''',
  ),
  HelmChartCatalogItem(
    name: 'traefik',
    repoName: 'traefik.io',
    repoUrl: 'https://helm.traefik.io/traefik',
    version: '25.0.0',
    appVersion: 'v2.10.4',
    category: 'Networking',
    description: 'Modern HTTP reverse proxy and ingress controller built for microservices.',
    icon: Icons.alt_route_rounded,
    accentColor: LensTheme.cyanAccent,
    defaultValuesYaml: '''deployment:
  replicas: 1
ports:
  web:
    port: 8000
    expose: true
  websecure:
    port: 8443
    expose: true
ingressClass:
  enabled: true
  isDefaultClass: true
''',
  ),
  HelmChartCatalogItem(
    name: 'cert-manager',
    repoName: 'jetstack',
    repoUrl: 'https://charts.jetstack.io',
    version: 'v1.13.2',
    appVersion: 'v1.13.2',
    category: 'Security',
    description: 'Automated x509 TLS certificate management and Let\'s Encrypt issuer.',
    icon: Icons.verified_user_rounded,
    accentColor: LensTheme.purpleAccent,
    defaultValuesYaml: '''installCRDs: true
replicaCount: 1
resources:
  requests:
    cpu: 10m
    memory: 32Mi
extraArgs:
  - "--dns01-recursive-nameservers-only"
''',
  ),
  HelmChartCatalogItem(
    name: 'kube-prometheus-stack',
    repoName: 'prometheus-community',
    repoUrl: 'https://prometheus-community.github.io/helm-charts',
    version: '55.4.0',
    appVersion: 'v0.70.0',
    category: 'Monitoring',
    description: 'Full observability stack with Prometheus, Grafana, Alertmanager & Node Exporter.',
    icon: Icons.insights_rounded,
    accentColor: LensTheme.statusAmber,
    defaultValuesYaml: '''grafana:
  enabled: true
  adminPassword: "admin"
prometheus:
  prometheusSpec:
    retention: 7d
    storageSpec:
      volumeClaimTemplate:
        spec:
          resources:
            requests:
              storage: 10Gi
''',
  ),
  HelmChartCatalogItem(
    name: 'grafana',
    repoName: 'grafana',
    repoUrl: 'https://grafana.github.io/helm-charts',
    version: '7.0.19',
    appVersion: '10.2.2',
    category: 'Monitoring',
    description: 'The open-source platform for metrics analytics, alerts, and dashboards.',
    icon: Icons.dashboard_customize_rounded,
    accentColor: LensTheme.statusAmber,
    defaultValuesYaml: '''adminPassword: "admin"
persistence:
  enabled: true
  size: 5Gi
service:
  type: ClusterIP
  port: 80
''',
  ),
  HelmChartCatalogItem(
    name: 'vault',
    repoName: 'hashicorp',
    repoUrl: 'https://helm.releases.hashicorp.com',
    version: '0.27.0',
    appVersion: '1.15.2',
    category: 'Security',
    description: 'Secure, store, and tightly control access to tokens, passwords, and keys.',
    icon: Icons.lock_outline_rounded,
    accentColor: LensTheme.purpleAccent,
    defaultValuesYaml: '''server:
  dev:
    enabled: true
  standalone:
    enabled: false
ui:
  enabled: true
  serviceType: ClusterIP
''',
  ),
  HelmChartCatalogItem(
    name: 'rabbitmq',
    repoName: 'bitnami',
    repoUrl: 'https://charts.bitnami.com/bitnami',
    version: '12.5.5',
    appVersion: '3.12.8',
    category: 'Databases',
    description: 'High-throughput, reliable asynchronous message queue broker.',
    icon: Icons.sync_alt_rounded,
    accentColor: LensTheme.statusAmber,
    defaultValuesYaml: '''auth:
  username: "user"
  password: "bitnamipassword"
persistence:
  enabled: true
  size: 8Gi
''',
  ),
  HelmChartCatalogItem(
    name: 'ingress-nginx',
    repoName: 'kubernetes',
    repoUrl: 'https://kubernetes.github.io/ingress-nginx',
    version: '4.9.0',
    appVersion: '1.9.5',
    category: 'Networking',
    description: 'Ingress controller for Kubernetes using NGINX as an edge reverse proxy.',
    icon: Icons.router_rounded,
    accentColor: LensTheme.cyanAccent,
    defaultValuesYaml: '''controller:
  replicaCount: 1
  service:
    type: LoadBalancer
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
''',
  ),
];

class HelmScreen extends StatefulWidget {
  const HelmScreen({super.key});

  @override
  State<HelmScreen> createState() => _HelmScreenState();
}

class _HelmScreenState extends State<HelmScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'All',
    'Databases',
    'Networking',
    'Monitoring',
    'Security',
    'Web / App',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clusterState = context.watch<ClusterState>();
    final activeConfig = clusterState.activeConfig;

    return Scaffold(
      backgroundColor: LensTheme.bgDark,
      appBar: AppBar(
        backgroundColor: LensTheme.bgDark,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: LensTheme.cyanAccent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: LensTheme.cyanAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.anchor_rounded, color: LensTheme.cyanAccent, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Helm Hub & Releases',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: LensTheme.textPrimary),
                ),
                Text(
                  activeConfig?.name ?? 'Vizxr Cluster',
                  style: const TextStyle(fontSize: 11, color: LensTheme.textMuted),
                ),
              ],
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: LensTheme.cyanAccent,
          indicatorWeight: 3,
          labelColor: LensTheme.cyanAccent,
          unselectedLabelColor: LensTheme.textMuted,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Charts Catalog'),
            Tab(text: 'Installed Releases'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Marketplace / Catalog
          _buildChartsCatalogTab(context, clusterState),
          // Tab 2: Installed Releases
          _buildInstalledReleasesTab(context, clusterState),
        ],
      ),
    );
  }

  Widget _buildChartsCatalogTab(BuildContext context, ClusterState clusterState) {
    final filtered = kHelmCatalog.where((chart) {
      final matchesCat = _selectedCategory == 'All' || chart.category == _selectedCategory;
      final q = _searchQuery.toLowerCase();
      final matchesSearch = q.isEmpty ||
          chart.name.toLowerCase().contains(q) ||
          chart.repoName.toLowerCase().contains(q) ||
          chart.description.toLowerCase().contains(q);
      return matchesCat && matchesSearch;
    }).toList();

    return Column(
      children: [
        // Search & Filter Header
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          color: LensTheme.bgSurface,
          child: Column(
            children: [
              // Search input
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(fontSize: 13, color: LensTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search charts by name, repository, or keyword...',
                  hintStyle: const TextStyle(fontSize: 12, color: LensTheme.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: LensTheme.cyanAccent),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16, color: LensTheme.textMuted),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: LensTheme.bgCard,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: LensTheme.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: LensTheme.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: LensTheme.cyanAccent, width: 1.2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Category filter pills
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final cat = _categories[idx];
                    final isSel = _selectedCategory == cat;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: isSel,
                      onSelected: (_) => setState(() => _selectedCategory = cat),
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        color: isSel ? Colors.black : LensTheme.textSecondary,
                      ),
                      selectedColor: LensTheme.cyanAccent,
                      backgroundColor: LensTheme.bgCard,
                      side: BorderSide(
                        color: isSel ? LensTheme.cyanAccent : LensTheme.borderSubtle,
                      ),
                      visualDensity: VisualDensity.compact,
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Catalog List
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                    'No Helm charts match your criteria.',
                    style: TextStyle(color: LensTheme.textMuted, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final item = filtered[idx];
                    return _buildChartCard(context, clusterState, item);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildChartCard(
    BuildContext context,
    ClusterState clusterState,
    HelmChartCatalogItem item,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: LensTheme.cardDecoration(radius: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chart Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: item.accentColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: item.accentColor.withOpacity(0.4), width: 1),
                  ),
                  child: Center(
                    child: Icon(item.icon, color: item.accentColor, size: 24),
                  ),
                ),
                const SizedBox(width: 12),
                // Titles and Badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: LensTheme.textPrimary,
                              ),
                            ),
                          ),
                          // Category badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: LensTheme.bgDark,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: LensTheme.borderSubtle),
                            ),
                            child: Text(
                              item.category,
                              style: const TextStyle(fontSize: 10, color: LensTheme.textMuted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: item.accentColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.repoName,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: item.accentColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'v${item.version}',
                            style: const TextStyle(fontSize: 11, color: LensTheme.textMuted, fontFamily: 'monospace'),
                          ),
                          const SizedBox(width: 6),
                          const Text('•', style: TextStyle(color: LensTheme.textMuted, fontSize: 10)),
                          const SizedBox(width: 6),
                          Text(
                            'App ${item.appVersion}',
                            style: const TextStyle(fontSize: 11, color: LensTheme.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item.description,
              style: const TextStyle(fontSize: 12, color: LensTheme.textSecondary, height: 1.3),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: LensTheme.borderSubtle),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item.repoUrl,
                  style: const TextStyle(fontSize: 10, color: LensTheme.textMuted, fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.download_rounded, size: 14),
                  label: const Text('Install'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LensTheme.cyanAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _openInstallSheet(context, clusterState, item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openInstallSheet(
    BuildContext context,
    ClusterState clusterState,
    HelmChartCatalogItem item,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _HelmInstallSheet(
        item: item,
        clusterState: clusterState,
        onInstalled: () {
          setState(() {});
          _tabController.animateTo(1);
        },
      ),
    );
  }

  Widget _buildInstalledReleasesTab(BuildContext context, ClusterState clusterState) {
    final client = clusterState.client;
    final ns = clusterState.currentNamespace;

    return FutureBuilder<List<HelmRelease>>(
      future: client.fetchHelmReleases(namespace: ns),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: LensTheme.cyanAccent));
        }

        final releases = snapshot.data ?? [];

        return Column(
          children: [
            // Status bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: LensTheme.bgSurface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 16, color: LensTheme.statusGreen),
                      const SizedBox(width: 6),
                      Text(
                        '${releases.length} Release${releases.length == 1 ? '' : 's'} Deployed',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: LensTheme.textPrimary),
                      ),
                    ],
                  ),
                  LensTheme.namespaceBadge(ns, fontSize: 11, context: context),
                ],
              ),
            ),

            Expanded(
              child: releases.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 48, color: LensTheme.textMuted.withOpacity(0.5)),
                          const SizedBox(height: 12),
                          const Text(
                            'No Helm releases deployed in this namespace.',
                            style: TextStyle(color: LensTheme.textMuted, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.storefront_rounded, size: 16),
                            label: const Text('Browse Chart Catalog'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: LensTheme.cyanAccent,
                              side: const BorderSide(color: LensTheme.cyanAccent),
                            ),
                            onPressed: () => _tabController.animateTo(0),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(14),
                      itemCount: releases.length,
                      itemBuilder: (context, idx) {
                        final rel = releases[idx];
                        return _buildReleaseCard(context, clusterState, rel);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReleaseCard(
    BuildContext context,
    ClusterState clusterState,
    HelmRelease rel,
  ) {
    Color statusColor = LensTheme.statusGreen;
    if (rel.status.toLowerCase().contains('fail')) {
      statusColor = LensTheme.statusRed;
    } else if (rel.status.toLowerCase().contains('pend')) {
      statusColor = LensTheme.statusAmber;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: LensTheme.cardDecoration(radius: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    rel.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: LensTheme.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        rel.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                LensTheme.namespaceBadge(rel.namespace, fontSize: 10),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: LensTheme.bgDark,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: LensTheme.borderSubtle),
                  ),
                  child: Text(
                    'rev ${rel.revision}',
                    style: const TextStyle(fontSize: 10, color: LensTheme.purpleAccent, fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Chart: ${rel.chart}-${rel.version}',
                  style: const TextStyle(fontSize: 11, color: LensTheme.textMuted, fontFamily: 'monospace'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Updated: ${rel.updated}',
              style: const TextStyle(fontSize: 10, color: LensTheme.textMuted),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: LensTheme.borderSubtle),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Inspect Values YAML
                TextButton.icon(
                  icon: const Icon(Icons.code_rounded, size: 14),
                  label: const Text('Values YAML'),
                  style: TextButton.styleFrom(
                    foregroundColor: LensTheme.cyanAccent,
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => YamlEditorScreen(
                          resourceName: '${rel.name} (Values)',
                          initialYaml: rel.valuesYaml.isNotEmpty
                              ? rel.valuesYaml
                              : '''# Applied values for release: ${rel.name}
chart: ${rel.chart}
version: ${rel.version}
replicaCount: 1
''',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),
                // Rollback
                TextButton.icon(
                  icon: const Icon(Icons.history_rounded, size: 14),
                  label: const Text('Rollback'),
                  style: TextButton.styleFrom(
                    foregroundColor: LensTheme.statusAmber,
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  onPressed: () => _confirmRollback(context, clusterState, rel),
                ),
                const SizedBox(width: 4),
                // Uninstall
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: LensTheme.statusRed),
                  tooltip: 'Uninstall Release',
                  onPressed: () => _confirmUninstall(context, clusterState, rel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRollback(BuildContext context, ClusterState clusterState, HelmRelease rel) {
    int targetRev = rel.revision > 1 ? rel.revision - 1 : 1;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: LensTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: const [
            Icon(Icons.history_rounded, color: LensTheme.statusAmber),
            SizedBox(width: 8),
            Text('Rollback Release', style: TextStyle(color: LensTheme.textPrimary, fontSize: 16)),
          ],
        ),
        content: Text(
          'Rollback Helm release "${rel.name}" to revision $targetRev?',
          style: const TextStyle(color: LensTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: LensTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: LensTheme.statusAmber, foregroundColor: Colors.black),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final res = await clusterState.client.rollbackHelmRelease(
                name: rel.name,
                namespace: rel.namespace,
                targetRevision: targetRev,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(res.message)),
              );
              setState(() {});
            },
            child: const Text('Confirm Rollback'),
          ),
        ],
      ),
    );
  }

  void _confirmUninstall(BuildContext context, ClusterState clusterState, HelmRelease rel) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: LensTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: LensTheme.statusRed),
            SizedBox(width: 8),
            Text('Uninstall Release', style: TextStyle(color: LensTheme.textPrimary, fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to uninstall and remove Helm release "${rel.name}" from namespace "${rel.namespace}"? All associated pods and services will be terminated.',
          style: const TextStyle(color: LensTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: LensTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: LensTheme.statusRed, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final res = await clusterState.client.uninstallHelmRelease(
                name: rel.name,
                namespace: rel.namespace,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(res.message)),
              );
              setState(() {});
            },
            child: const Text('Uninstall'),
          ),
        ],
      ),
    );
  }
}

class _HelmInstallSheet extends StatefulWidget {
  final HelmChartCatalogItem item;
  final ClusterState clusterState;
  final VoidCallback onInstalled;

  const _HelmInstallSheet({
    required this.item,
    required this.clusterState,
    required this.onInstalled,
  });

  @override
  State<_HelmInstallSheet> createState() => _HelmInstallSheetState();
}

class _HelmInstallSheetState extends State<_HelmInstallSheet> {
  late TextEditingController _nameController;
  late TextEditingController _valuesController;
  late String _selectedNamespace;
  bool _isInstalling = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _valuesController = TextEditingController(text: widget.item.defaultValuesYaml);
    _selectedNamespace = widget.clusterState.currentNamespace == 'all-namespaces'
        ? 'default'
        : widget.clusterState.currentNamespace;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valuesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: LensTheme.bgDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: LensTheme.cyanAccent, width: 1.5)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: LensTheme.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: widget.item.accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(widget.item.icon, color: widget.item.accentColor, size: 20),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Install ${widget.item.name}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: LensTheme.textPrimary),
                      ),
                      Text(
                        '${widget.item.repoName} • v${widget.item.version}',
                        style: const TextStyle(fontSize: 11, color: LensTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: LensTheme.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: LensTheme.borderSubtle),

          // Inputs Form
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Release Name
                const Text(
                  'RELEASE NAME',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: LensTheme.textMuted, letterSpacing: 1),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(fontSize: 13, color: LensTheme.textPrimary, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: 'e.g. my-${widget.item.name}',
                    filled: true,
                    fillColor: LensTheme.bgCard,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: LensTheme.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: LensTheme.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: LensTheme.cyanAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Target Namespace
                const Text(
                  'TARGET NAMESPACE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: LensTheme.textMuted, letterSpacing: 1),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: LensTheme.bgCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: LensTheme.borderSubtle),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: widget.clusterState.namespaces.contains(_selectedNamespace)
                          ? _selectedNamespace
                          : widget.clusterState.namespaces.firstWhere((n) => n != 'all-namespaces', orElse: () => 'default'),
                      isExpanded: true,
                      dropdownColor: LensTheme.bgCard,
                      icon: const Icon(Icons.arrow_drop_down, color: LensTheme.cyanAccent),
                      items: widget.clusterState.namespaces
                          .where((n) => n != 'all-namespaces')
                          .map((ns) => DropdownMenuItem(
                                value: ns,
                                child: Text(ns, style: const TextStyle(fontSize: 13, color: LensTheme.textPrimary)),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedNamespace = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Values YAML Editor
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'CUSTOM VALUES (YAML)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: LensTheme.textMuted, letterSpacing: 1),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () {
                        setState(() {
                          _valuesController.text = widget.item.defaultValuesYaml;
                        });
                      },
                      child: const Text('Reset Defaults', style: TextStyle(fontSize: 11, color: LensTheme.cyanAccent)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: LensTheme.bgCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: LensTheme.borderSubtle),
                  ),
                  child: TextField(
                    controller: _valuesController,
                    maxLines: 12,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: LensTheme.textPrimary,
                      height: 1.4,
                    ),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.all(12),
                      border: InputBorder.none,
                      hintText: 'Enter custom values in YAML format...',
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Deploy Dock
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: LensTheme.bgSurface,
              border: Border(top: BorderSide(color: LensTheme.borderSubtle)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LensTheme.cyanAccent,
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(46),
                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isInstalling ? null : _installChart,
                    child: _isInstalling
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : Text('Deploy "${_nameController.text.trim()}"'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _installChart() async {
    final releaseName = _nameController.text.trim();
    if (releaseName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please specify a release name.')),
      );
      return;
    }

    setState(() => _isInstalling = true);

    final res = await widget.clusterState.client.installHelmRelease(
      name: releaseName,
      namespace: _selectedNamespace,
      chart: widget.item.name,
      repo: widget.item.repoUrl,
      version: widget.item.version,
      valuesYaml: _valuesController.text,
    );

    setState(() => _isInstalling = false);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.success ? LensTheme.statusGreen : LensTheme.statusRed,
        ),
      );
      if (res.success) {
        widget.onInstalled();
      }
    }
  }
}
