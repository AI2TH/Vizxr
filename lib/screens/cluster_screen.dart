import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/cluster_state.dart';
import '../services/k8s_client.dart';
import '../services/k8s_quantity.dart';
import '../services/metrics_history.dart';
import '../theme/lens_theme.dart';
import '../widgets/cluster_metrics_panel.dart';
import '../widgets/usage_sparklines.dart';
import 'crd_screen.dart';
import 'edit_cluster_screen.dart';
import 'events_screen.dart';
import 'helm_screen.dart';
import 'yaml_editor_screen.dart';

class ClusterScreen extends StatefulWidget {
  const ClusterScreen({super.key});

  @override
  State<ClusterScreen> createState() => _ClusterScreenState();
}

class _ClusterScreenState extends State<ClusterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Requests live here, not in build(): they start when the cluster,
  // namespace or connection changes, or on pull-to-refresh.
  Future<List<K8sResource>>? _telemetryFuture;
  Future<List<K8sResource>>? _nodesFuture;
  Object? _loadedKey;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final clusterState = Provider.of<ClusterState>(context);
    final key = (
      clusterState.client,
      clusterState.currentNamespace,
      clusterState.isLiveConnected || clusterState.isDemo,
    );
    if (key == _loadedKey) return;
    _loadedKey = key;
    _load(clusterState);
  }

  void _load(ClusterState clusterState) {
    if (!clusterState.isLiveConnected && !clusterState.isDemo) {
      _telemetryFuture = null;
      _nodesFuture = null;
      return;
    }
    final client = clusterState.client;
    final ns = clusterState.currentNamespace;
    _telemetryFuture = Future.wait([
      client.fetchResources(K8sResourceType.pod, namespace: ns),
      client.fetchResources(K8sResourceType.deployment, namespace: ns),
      client.fetchEvents(namespace: ns),
    ]).then((r) => [...r[0], ...r[1], ...r[2]]);
    _nodesFuture = client.fetchResources(K8sResourceType.node);
  }

  Future<void> _reload() async {
    setState(() => _load(context.read<ClusterState>()));
    await Future.wait([
      if (_telemetryFuture != null) _telemetryFuture!.then((_) {}, onError: (_) {}),
      if (_nodesFuture != null) _nodesFuture!.then((_) {}, onError: (_) {}),
    ]);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clusterState = context.watch<ClusterState>();
    final isLive = clusterState.isLiveConnected;
    final isDemo = clusterState.isDemo;

    return Scaffold(
      backgroundColor: LensTheme.bgDark,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: _buildClusterHeroHeader(context, clusterState, isLive, isDemo),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: LensTheme.cyanAccent,
                  indicatorWeight: 3,
                  labelColor: LensTheme.cyanAccent,
                  unselectedLabelColor: LensTheme.textMuted,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(icon: Icon(Icons.dashboard_rounded, size: 18), text: 'Cluster Telemetry'),
                    Tab(icon: Icon(Icons.dns_rounded, size: 18), text: 'Nodes & Runtime'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildTelemetryView(context, clusterState, isLive, isDemo),
            _buildNodesView(context, clusterState, isLive, isDemo),
          ],
        ),
      ),
    );
  }

  Widget _buildClusterHeroHeader(
    BuildContext context,
    ClusterState clusterState,
    bool isLive,
    bool isDemo,
  ) {
    final config = clusterState.activeConfig;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      padding: const EdgeInsets.all(16),
      decoration: LensTheme.cardDecoration(
        borderColor: isDemo
            ? LensTheme.purpleAccent.withOpacity(0.4)
            : (isLive ? LensTheme.statusGreen.withOpacity(0.4) : LensTheme.statusRed.withOpacity(0.4)),
        glow: isLive || isDemo,
        radius: 18,
        gradient: LensTheme.elevatedCardGradient,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDemo
                        ? LensTheme.purpleAccent.withOpacity(0.6)
                        : (isLive ? LensTheme.statusGreen.withOpacity(0.6) : LensTheme.statusRed.withOpacity(0.6)),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.5),
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Icon(
                        isDemo ? Icons.auto_awesome_rounded : (isLive ? Icons.hub_rounded : Icons.wifi_off_rounded),
                        color: isDemo ? LensTheme.purpleAccent : (isLive ? LensTheme.statusGreen : LensTheme.statusRed),
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config?.name ?? 'Connecting...',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: LensTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDemo ? LensTheme.purpleAccent : (isLive ? LensTheme.statusGreen : LensTheme.statusRed),
                            boxShadow: [
                              BoxShadow(
                                color: (isDemo ? LensTheme.purpleAccent : (isLive ? LensTheme.statusGreen : LensTheme.statusRed))
                                    .withOpacity(0.8),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isDemo
                              ? 'SIMULATION (DEMO MODE)'
                              : (isLive ? 'CONNECTED • LIVE K8s' : 'OFFLINE • UNREACHABLE'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: isDemo ? LensTheme.purpleAccent : (isLive ? LensTheme.statusGreen : LensTheme.statusRed),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: LensTheme.cyanAccent),
                tooltip: 'Refresh Connection',
                onPressed: () => clusterState.refreshConfigs(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: LensTheme.borderSubtle),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'API: ${config?.server ?? "https://127.0.0.1:6443"}',
                  style: const TextStyle(fontSize: 11, color: LensTheme.textMuted, fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (config != null && config.insecureSkipTlsVerify && !isDemo) ...[
                const SizedBox(width: 8),
                const InsecureTlsBadge(),
              ],
              const SizedBox(width: 8),
              LensTheme.namespaceBadge(clusterState.currentNamespace, fontSize: 10, context: context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryView(
    BuildContext context,
    ClusterState clusterState,
    bool isLive,
    bool isDemo,
  ) {
    if (!isLive && !isDemo) {
      return _buildDisconnectedDiagnosticView(context, clusterState);
    }

    final ns = clusterState.currentNamespace;

    return FutureBuilder<List<K8sResource>>(
      future: _telemetryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: LensTheme.cyanAccent));
        }

        final all = snapshot.data ?? [];
        final pods = all.where((r) => r.type == K8sResourceType.pod && r.message == null).toList();
        final deps = all.where((r) => r.type == K8sResourceType.deployment).toList();
        final events = all.where((r) => r.message != null).toList();

        final runningPods = pods.where((p) => p.status.toLowerCase().contains('running')).length;
        final pendingPods = pods.where((p) => p.status.toLowerCase().contains('pending')).length;
        final failedPods = pods.where((p) => p.status.toLowerCase().contains('fail') || p.status.toLowerCase().contains('crash')).length;
        final completedPods = pods.where((p) => p.status.toLowerCase().contains('completed')).length;

        return RefreshIndicator(
          color: LensTheme.cyanAccent,
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            children: [
              // Pod Health Donut / Breakdown Card
              _buildWorkloadBreakdownCard(
                totalPods: pods.length,
                running: runningPods,
                pending: pendingPods,
                failed: failedPods,
                completed: completedPods,
                deployments: deps.length,
                namespace: ns,
              ),
              const SizedBox(height: 14),

              // Telemetry Gauges (CPU & Memory) from metrics-server
              ClusterMetricsPanel(sampler: clusterState.metrics),
              const SizedBox(height: 14),

              // Quick Actions Dock
              _buildQuickActionsDock(context, clusterState),
              const SizedBox(height: 16),

              // Recent Cluster Events Feed
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'RECENT CLUSTER EVENTS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: LensTheme.textMuted,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const EventsScreen()),
                      );
                    },
                    child: const Text('View All', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (events.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: LensTheme.cardDecoration(radius: 12),
                  child: const Center(
                    child: Text(
                      'No cluster events recorded for active namespace.',
                      style: TextStyle(fontSize: 12, color: LensTheme.textMuted),
                    ),
                  ),
                )
              else
                ...events.take(5).map((e) => _buildEventItem(e)),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDisconnectedDiagnosticView(BuildContext context, ClusterState clusterState) {
    final server = clusterState.activeConfig?.server ?? 'https://127.0.0.1:6443';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: LensTheme.cardDecoration(
            borderColor: LensTheme.statusRed.withOpacity(0.5),
            glow: true,
            radius: 18,
          ),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: LensTheme.statusRed.withOpacity(0.15),
                  border: Border.all(color: LensTheme.statusRed.withOpacity(0.5), width: 1.5),
                ),
                child: const Center(
                  child: Icon(Icons.radar_rounded, size: 32, color: LensTheme.statusRed),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Cluster Unreachable',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: LensTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                server,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: LensTheme.statusAmber,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Vizxr was unable to establish a secure handshake with this Kubernetes API server. Pods and resources cannot be displayed for offline clusters.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: LensTheme.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: LensTheme.borderSubtle),
              const SizedBox(height: 14),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Retry Connection'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LensTheme.cyanAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => clusterState.refreshConfigs(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: LensTheme.purpleAccent),
                      label: const Text('Switch to Demo Cluster (Instant Simulation)'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: LensTheme.purpleAccent.withOpacity(0.5)),
                        foregroundColor: LensTheme.purpleAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        final demoConfig = clusterState.availableConfigs.firstWhere(
                          (c) => K8sClientService.isDemoServer(c.server),
                          orElse: () => clusterState.availableConfigs.first,
                        );
                        clusterState.setConfig(demoConfig);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'DIAGNOSTIC CHECKLIST',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: LensTheme.textMuted),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: LensTheme.cardDecoration(radius: 12),
          child: const Column(
            children: [
              _DiagnosticRow(
                icon: Icons.terminal_rounded,
                title: 'Check Linux / K3s Service',
                subtitle: 'Ensure Linxr or k3s server is started in your environment.',
              ),
              Divider(height: 16, color: LensTheme.borderSubtle),
              _DiagnosticRow(
                icon: Icons.cable_rounded,
                title: 'Loopback & Port Forwarding',
                subtitle: 'If running via Termux/Linxr: verify 127.0.0.1:6443 or ADB reverse.',
              ),
              Divider(height: 16, color: LensTheme.borderSubtle),
              _DiagnosticRow(
                icon: Icons.security_rounded,
                title: 'mTLS Certificates',
                subtitle: 'Verify client-certificate-data and client-key-data in kubeconfig.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWorkloadBreakdownCard({
    required int totalPods,
    required int running,
    required int pending,
    required int failed,
    required int completed,
    required int deployments,
    required String namespace,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: LensTheme.cardDecoration(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Workload Health',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: LensTheme.textPrimary),
              ),
              Text(
                '$deployments Deployments',
                style: const TextStyle(fontSize: 12, color: LensTheme.blueAccent, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Multi-Segment Health Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: totalPods == 0
                  ? Container(color: Colors.white.withOpacity(0.08))
                  : Row(
                      children: [
                        if (running > 0)
                          Expanded(
                            flex: running,
                            child: Container(color: LensTheme.statusGreen),
                          ),
                        if (pending > 0)
                          Expanded(
                            flex: pending,
                            child: Container(color: LensTheme.statusAmber),
                          ),
                        if (failed > 0)
                          Expanded(
                            flex: failed,
                            child: Container(color: LensTheme.statusRed),
                          ),
                        if (completed > 0)
                          Expanded(
                            flex: completed,
                            child: Container(color: LensTheme.k8sBlue),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Breakdown Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatPill('Running', running, LensTheme.statusGreen),
              _buildStatPill('Pending', pending, LensTheme.statusAmber),
              _buildStatPill('Failed', failed, LensTheme.statusRed),
              _buildStatPill('Total', totalPods, LensTheme.cyanAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: LensTheme.textMuted)),
      ],
    );
  }

  Widget _buildQuickActionsDock(BuildContext context, ClusterState clusterState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: LensTheme.cardDecoration(radius: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildQuickDockItem(
            icon: Icons.add_circle_outline_rounded,
            label: 'Apply YAML',
            color: LensTheme.cyanAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const YamlEditorScreen(
                    resourceName: 'New Resource',
                    initialYaml: '''apiVersion: v1
kind: Pod
metadata:
  name: demo-workload
  namespace: default
spec:
  containers:
  - name: web
    image: nginx:alpine
    ports:
    - containerPort: 80
''',
                  ),
                ),
              );
            },
          ),
          _buildQuickDockItem(
            icon: Icons.anchor_rounded,
            label: 'Helm Hub',
            color: LensTheme.cyanAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelmScreen()),
              );
            },
          ),
          _buildQuickDockItem(
            icon: Icons.extension_rounded,
            label: 'CRDs & Ext',
            color: LensTheme.purpleAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CrdScreen()),
              );
            },
          ),
          _buildQuickDockItem(
            icon: Icons.notifications_none_rounded,
            label: 'Events Feed',
            color: LensTheme.blueAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EventsScreen()),
              );
            },
          ),
          _buildQuickDockItem(
            icon: Icons.shield_outlined,
            label: 'mTLS Status',
            color: LensTheme.statusGreen,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(_describeAuth(clusterState))),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickDockItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventItem(K8sResource event) {
    final isWarning = event.status == 'Warning';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: LensTheme.cardDecoration(
        borderColor: isWarning ? LensTheme.statusAmber.withOpacity(0.3) : LensTheme.borderSubtle,
        radius: 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isWarning ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
            size: 16,
            color: isWarning ? LensTheme.statusAmber : LensTheme.blueAccent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      event.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isWarning ? LensTheme.statusAmber : LensTheme.cyanAccent,
                      ),
                    ),
                    Text(
                      event.age,
                      style: const TextStyle(fontSize: 10, color: LensTheme.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  event.message ?? '',
                  style: const TextStyle(fontSize: 12, color: LensTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodesView(
    BuildContext context,
    ClusterState clusterState,
    bool isLive,
    bool isDemo,
  ) {
    if (!isLive && !isDemo) {
      return _buildDisconnectedDiagnosticView(context, clusterState);
    }

    return FutureBuilder<List<K8sResource>>(
      future: _nodesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: LensTheme.cyanAccent));
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not list nodes: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: LensTheme.statusRed),
              ),
            ),
          );
        }
        final nodes = snapshot.data ?? const <K8sResource>[];
        if (nodes.isEmpty) {
          return const Center(
            child: Text('No nodes found.', style: TextStyle(color: LensTheme.textMuted, fontSize: 13)),
          );
        }
        return RefreshIndicator(
          color: LensTheme.cyanAccent,
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(14),
            children: [
              for (final node in nodes) ...[
                _buildNodeCard(node),
                const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Renders one node from a real Node object, or from the flat mock data
  /// used in demo mode.
  Widget _buildNodeCard(K8sResource node) {
    final raw = node.rawYaml;
    final status = raw['status'] is Map ? raw['status'] as Map : const {};
    final info = status['nodeInfo'] is Map ? status['nodeInfo'] as Map : const {};
    final allocatable = status['allocatable'] is Map
        ? status['allocatable'] as Map
        : (raw['capacity'] is Map ? raw['capacity'] as Map : const {});

    final roles = node.labels.keys
        .where((k) => k.startsWith('node-role.kubernetes.io/'))
        .map((k) => k.substring('node-role.kubernetes.io/'.length))
        .where((r) => r.isNotEmpty)
        .toList();

    String? internalIp;
    if (status['addresses'] is List) {
      for (final a in status['addresses'] as List) {
        if (a is Map && a['type'] == 'InternalIP') {
          internalIp = a['address']?.toString();
          break;
        }
      }
    }

    final arch = info['architecture'] ?? raw['architecture'];
    final os = info['osImage'] ?? raw['os'];
    final kernel = info['kernelVersion'] ?? raw['kernel'];
    final runtime = info['containerRuntimeVersion'];
    final kubelet = info['kubeletVersion'] ?? raw['kubeletVersion'];
    final cpu = K8sQuantity.tryParse(allocatable['cpu']);
    final mem = K8sQuantity.tryParse(allocatable['memory']);
    final pods = allocatable['pods'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: LensTheme.cardDecoration(
        borderColor: (node.status == 'Ready' ? LensTheme.statusGreen : LensTheme.statusRed).withOpacity(0.3),
        radius: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dns_rounded, color: LensTheme.cyanAccent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  node.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: LensTheme.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              LensTheme.statusBadge(node.status),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: LensTheme.borderSubtle),
          const SizedBox(height: 12),
          _buildNodeAttribute('Roles', roles.isEmpty ? '<none>' : roles.join(', ')),
          if (arch != null) _buildNodeAttribute('Architecture', arch.toString()),
          if (os != null) _buildNodeAttribute('OS image', os.toString()),
          if (kernel != null) _buildNodeAttribute('Kernel', kernel.toString()),
          if (runtime != null) _buildNodeAttribute('Container runtime', runtime.toString()),
          if (kubelet != null) _buildNodeAttribute('Kubelet version', kubelet.toString()),
          if (internalIp != null) _buildNodeAttribute('Internal IP', internalIp),
          if (cpu != null) _buildNodeAttribute('Allocatable CPU', '${K8sQuantity.formatCores(cpu)} cores'),
          if (mem != null) _buildNodeAttribute('Allocatable memory', K8sQuantity.formatBytes(mem)),
          if (pods != null) _buildNodeAttribute('Max pods', pods.toString()),
          _buildNodeAttribute('Age', node.age),
          // Usage history recorded by the metrics sampler (nothing shown
          // without metrics-server).
          UsageSparklines(
            sampler: context.read<ClusterState>().metrics,
            cpuKey: MetricsHistory.nodeCpu(node.name),
            memKey: MetricsHistory.nodeMem(node.name),
          ),
        ],
      ),
    );
  }

  String _describeAuth(ClusterState clusterState) {
    final config = clusterState.activeConfig;
    if (clusterState.isDemo || config == null) return 'Demo cluster: no authentication';
    final String auth;
    if (config.clientCertData != null && config.clientKeyData != null) {
      auth = 'client certificate (mTLS)';
    } else if (config.token != null && config.token!.isNotEmpty) {
      auth = 'bearer token';
    } else {
      auth = 'no credentials';
    }
    final tls = config.insecureSkipTlsVerify
        ? 'TLS verification OFF (insecure-skip-tls-verify)'
        : (config.caCert != null ? 'TLS verified with cluster CA' : 'TLS verified with system CAs');
    return 'Auth: $auth. $tls.';
  }

  Widget _buildNodeAttribute(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: LensTheme.textMuted)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: LensTheme.textPrimary)),
        ],
      ),
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _DiagnosticRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: LensTheme.cyanAccent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: LensTheme.textPrimary)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: LensTheme.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: LensTheme.bgDark,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
