import 'package:flutter/material.dart';
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
            Tab(text: 'Nodes'),
            Tab(text: 'Overview'),
          ],
        ),
        body: TabBarView(
          children: [
            const ResourceListView(type: K8sResourceType.node),
            _buildClusterOverview(),
          ],
        ),
      ),
    );
  }

  Widget _buildClusterOverview() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatCard('Cluster Health', 'Healthy', Colors.green),
        const SizedBox(height: 12),
        _buildStatCard('Total CPU Capacity', '4 Cores', Colors.blue),
        const SizedBox(height: 12),
        _buildStatCard('Total Memory', '8 GiB', Colors.purple),
        const SizedBox(height: 12),
        _buildStatCard('Kubernetes Version', 'v1.28.2', Colors.orange),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Card(
      child: ListTile(
        title: Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        trailing: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }
}
