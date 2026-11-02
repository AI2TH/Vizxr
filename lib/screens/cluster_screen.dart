import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/cluster_state.dart';
import '../services/k8s_client.dart';
import 'workloads_screen.dart';

class ClusterScreen extends StatelessWidget {
  const ClusterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: const TabBar(
          tabs: [
            Tab(text: 'Overview'),
            Tab(text: 'Nodes'),
          ],
        ),
        body: TabBarView(
          children: [
            _buildClusterOverview(context),
            const ResourceListView(type: K8sResourceType.node),
          ],
        ),
      ),
    );
  }

  Widget _buildClusterOverview(BuildContext context) {
    final clusterState = context.watch<ClusterState>();
    final config = clusterState.activeConfig;
    final isLive = clusterState.isLiveConnected;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isLive ? Icons.check_circle : Icons.offline_bolt_outlined,
                      color: isLive ? Colors.greenAccent : Colors.orangeAccent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      config?.name ?? 'Cluster',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isLive ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isLive ? 'ONLINE' : 'SIMULATION',
                        style: TextStyle(
                          color: isLive ? Colors.greenAccent : Colors.orangeAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('API Endpoint: ${config?.server ?? "https://127.0.0.1:6443"}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Text('Active Namespace: ${clusterState.currentNamespace}', style: const TextStyle(fontSize: 12, color: Colors.blueAccent)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildMetricTile('Cluster Health', '100% Healthy', Colors.greenAccent, Icons.favorite)),
            const SizedBox(width: 10),
            Expanded(child: _buildMetricTile('K8s Version', 'v1.28.2+k0s', Colors.blueAccent, Icons.verified)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildMetricTile('Total CPU', '8 Cores (TCG)', Colors.purpleAccent, Icons.memory)),
            const SizedBox(width: 10),
            Expanded(child: _buildMetricTile('Total Memory', '16 GiB Alloc', Colors.tealAccent, Icons.storage)),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Mobile Cluster Host Environment',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        const Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.architecture, color: Colors.blueAccent),
                title: Text('Architecture & Runtime'),
                subtitle: Text('ARM64 Cortex-A76 • Alpine Linux 3.20 (virt) • containerd'),
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.security, color: Colors.greenAccent),
                title: Text('Security & Loopback'),
                subtitle: Text('mTLS Auth • Loopback bound (127.0.0.1:6443) • Hostfwd'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(String label, String value, Color color, IconData icon) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
