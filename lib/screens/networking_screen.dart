import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/cluster_state.dart';
import '../services/k8s_client.dart';
import '../services/port_forward_service.dart';
import '../theme/lens_theme.dart';
import '../widgets/cluster_data_loader.dart';
import '../widgets/resource_inspector_sheet.dart';
import 'yaml_editor_screen.dart';

class NetworkingScreen extends StatefulWidget {
  const NetworkingScreen({super.key});

  @override
  State<NetworkingScreen> createState() => _NetworkingScreenState();
}

class _NetworkingScreenState extends State<NetworkingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clusterState = context.watch<ClusterState>();

    return Scaffold(
      backgroundColor: LensTheme.bgDark,
      appBar: AppBar(
        backgroundColor: LensTheme.bgDark,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.hub_rounded, color: LensTheme.cyanAccent, size: 20),
            const SizedBox(width: 8),
            const Text('Network & Routing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            LensTheme.namespaceBadge(clusterState.currentNamespace, context: context),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: LensTheme.cyanAccent,
          indicatorWeight: 2.5,
          labelColor: LensTheme.cyanAccent,
          unselectedLabelColor: LensTheme.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Services'),
            Tab(text: 'Ingresses'),
            Tab(text: 'Port Forwards'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ServicesListView(),
          _IngressesListView(),
          _PortForwardsView(),
        ],
      ),
    );
  }
}

class _ServicesListView extends StatefulWidget {
  const _ServicesListView();

  @override
  State<_ServicesListView> createState() => _ServicesListViewState();
}

class _ServicesListViewState extends State<_ServicesListView> with ClusterDataLoader<_ServicesListView, List<K8sResource>> {

  @override
  Future<List<K8sResource>> load(ClusterState clusterState) =>
      clusterState.client.fetchResources(K8sResourceType.service, namespace: clusterState.currentNamespace);

  void _refresh() => reload();

  @override
  Widget build(BuildContext context) {
    final clusterState = context.watch<ClusterState>();
    final isLive = clusterState.isLiveConnected;
    final isDemo = clusterState.isDemo;

    if (!isLive && !isDemo) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 12),
            const Text('Cluster Unreachable', style: TextStyle(color: LensTheme.textMuted)),
          ],
        ),
      );
    }

    return FutureBuilder<List<K8sResource>>(
      future: dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: LensTheme.cyanAccent));
        }

        final services = snapshot.data ?? [];
        if (services.isEmpty) {
          return Center(
            child: Text(
              'No services found in ${clusterState.currentNamespace}',
              style: const TextStyle(color: LensTheme.textMuted, fontSize: 13),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: reload,
          color: LensTheme.cyanAccent,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final svc = services[index];
              return _buildServiceCard(context, svc);
            },
          ),
        );
      },
    );
  }

  /// Resolves the service's first port to a running pod and starts a real
  /// tunnel through the portforward subresource.
  Future<void> _startServiceForward(BuildContext context, K8sResource svc) async {
    final clusterState = context.read<ClusterState>();
    final messenger = ScaffoldMessenger.of(context);
    if (clusterState.isDemo) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Port forwarding needs a live cluster; the demo cluster has no real pods.')),
      );
      return;
    }
    try {
      final client = clusterState.client;
      final target = await client.resolveServicePortForward(svc);
      final forward = await PortForwardService.startForward(
        client: client,
        namespace: svc.namespace,
        podName: target.podName,
        containerPort: target.containerPort,
        localPort: PortForwardService.preferredLocalPort(target.servicePort),
        label: 'svc/${svc.name}:${target.servicePort}',
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text('Forwarding ${forward.localUrl} -> ${target.podName}:${target.containerPort}'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Port forward failed: $e'), backgroundColor: LensTheme.statusRed),
      );
    }
  }

  Widget _buildServiceCard(BuildContext context, K8sResource svc) {
    final spec = (svc.rawYaml['spec'] as Map?) ?? {};
    final type = spec['type']?.toString() ?? svc.status;
    final clusterIp = spec['clusterIP']?.toString() ?? 'None';
    final ports = (spec['ports'] as List?) ?? [];

    Color typeColor = LensTheme.blueAccent;
    if (type == 'LoadBalancer') typeColor = LensTheme.purpleAccent;
    if (type == 'NodePort') typeColor = LensTheme.statusAmber;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: LensTheme.cardDecoration(radius: 14),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => ResourceInspectorSheet.show(context, resource: svc, onResourceChanged: _refresh),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  svc.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: LensTheme.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: typeColor.withOpacity(0.4), width: 0.8),
                ),
                child: Text(
                  type,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: typeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              LensTheme.namespaceBadge(svc.namespace),
              const SizedBox(width: 8),
              Text(
                'ClusterIP: $clusterIp',
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: LensTheme.textMuted),
              ),
            ],
          ),
          if (ports.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: ports.map((p) {
                final port = p is Map ? p['port'] : p;
                final target = p is Map ? p['targetPort'] : '';
                final proto = p is Map ? (p['protocol'] ?? 'TCP') : 'TCP';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: LensTheme.bgDark.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: LensTheme.borderSubtle),
                  ),
                  child: Text(
                    '$port:$target/$proto',
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: LensTheme.cyanAccent),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: LensTheme.borderSubtle),
          const SizedBox(height: 8),
          Row(
            children: [
              InkWell(
                onTap: () => _startServiceForward(context, svc),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: LensTheme.cyanAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: LensTheme.cyanAccent.withOpacity(0.3), width: 0.8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.forward_to_inbox_rounded, size: 13, color: LensTheme.cyanAccent),
                      SizedBox(width: 4),
                      Text('Port Forward', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: LensTheme.cyanAccent)),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.article_outlined, size: 18, color: LensTheme.textSecondary),
                tooltip: 'View YAML',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => YamlEditorScreen(
                        resourceName: svc.name,
                        initialYaml: svc.rawYaml.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
          ),
        ),
      ),
    );
  }
}

class _IngressesListView extends StatefulWidget {
  const _IngressesListView();

  @override
  State<_IngressesListView> createState() => _IngressesListViewState();
}

class _IngressesListViewState extends State<_IngressesListView> with ClusterDataLoader<_IngressesListView, List<K8sResource>> {

  @override
  Future<List<K8sResource>> load(ClusterState clusterState) =>
      clusterState.client.fetchResources(K8sResourceType.ingress, namespace: clusterState.currentNamespace);

  void _refresh() => reload();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<K8sResource>>(
      future: dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: LensTheme.cyanAccent));
        }

        final ingresses = snapshot.data ?? [];
        if (ingresses.isEmpty) {
          return const Center(
            child: Text('No Ingress rules configured.', style: TextStyle(color: LensTheme.textMuted, fontSize: 13)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          itemCount: ingresses.length,
          itemBuilder: (context, index) {
            final ing = ingresses[index];
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: LensTheme.cardDecoration(radius: 14),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => ResourceInspectorSheet.show(context, resource: ing, onResourceChanged: _refresh),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.alt_route_rounded, size: 18, color: LensTheme.purpleAccent),
                            const SizedBox(width: 8),
                            Text(ing.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: LensTheme.textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LensTheme.namespaceBadge(ing.namespace),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PortForwardsView extends StatelessWidget {
  const _PortForwardsView();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: PortForwardService.changes,
      builder: (context, _, __) => _buildList(context),
    );
  }

  Widget _buildList(BuildContext context) {
    final forwards = PortForwardService.activeForwards;

    if (forwards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forward_to_inbox_rounded, size: 44, color: Colors.white.withOpacity(0.15)),
            const SizedBox(height: 10),
            const Text('No active port forwards.', style: TextStyle(color: LensTheme.textMuted, fontSize: 13)),
            const SizedBox(height: 6),
            const Text(
              'Tap "Port Forward" on a Service to reach it from this device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: LensTheme.textMuted, fontSize: 11),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: forwards.length,
      itemBuilder: (context, index) {
        final f = forwards[index];
        final statusText = f.isActive
            ? 'Listening on 127.0.0.1:${f.localPort} • ${f.openConnections} open, ${f.totalConnections} total'
            : 'Stopped';
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: LensTheme.cardDecoration(
            borderColor: LensTheme.cyanAccent.withOpacity(0.4),
            glow: f.isActive,
            radius: 14,
          ),
          child: Row(
            children: [
              const Icon(Icons.leak_add_rounded, color: LensTheme.cyanAccent, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'localhost:${f.localPort} -> ${f.label}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: LensTheme.textPrimary, fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'pod ${f.namespace}/${f.podName}:${f.containerPort}',
                      style: const TextStyle(fontSize: 11, color: LensTheme.textSecondary, fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      style: TextStyle(fontSize: 11, color: f.isActive ? LensTheme.statusGreen : LensTheme.textMuted),
                    ),
                    if (f.lastError != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Last error: ${f.lastError}',
                        style: const TextStyle(fontSize: 11, color: LensTheme.statusRed),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: LensTheme.textSecondary, size: 18),
                tooltip: 'Copy URL',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: f.localUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Copied ${f.localUrl}')),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.stop_circle_outlined, color: LensTheme.statusRed),
                tooltip: 'Stop',
                onPressed: () => PortForwardService.stopForward(f),
              ),
            ],
          ),
        );
      },
    );
  }
}
