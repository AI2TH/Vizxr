import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/cluster_state.dart';
import '../services/k8s_client.dart';
import 'logs_screen.dart';
import 'pod_exec_screen.dart';
import 'yaml_editor_screen.dart';

class ExplorerScreen extends StatefulWidget {
  const ExplorerScreen({super.key});

  @override
  State<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends State<ExplorerScreen> {
  late Future<List<K8sResource>> _podsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refresh();
  }

  void _refresh() {
    final clusterState = context.read<ClusterState>();
    setState(() {
      _podsFuture = clusterState.client.fetchResources(
        K8sResourceType.pod,
        namespace: clusterState.currentNamespace,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<K8sResource>>(
        future: _podsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No Pods found.'));
          }

          final pods = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              itemCount: pods.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final pod = pods[index];
                final isRunning = pod.status.toLowerCase().contains('running');
                return ListTile(
                  leading: Icon(
                    Icons.layers,
                    color: isRunning ? Colors.greenAccent : Colors.orangeAccent,
                  ),
                  title: Text(pod.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('${pod.namespace} • ${pod.age} • IP: ${pod.ip ?? "none"}'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isRunning ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      pod.status,
                      style: TextStyle(
                        color: isRunning ? Colors.greenAccent : Colors.orangeAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PodDetailScreen(pod: pod),
                      ),
                    ).then((_) => _refresh());
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class PodDetailScreen extends StatelessWidget {
  final K8sResource pod;
  const PodDetailScreen({super.key, required this.pod});

  @override
  Widget build(BuildContext context) {
    final clusterState = context.read<ClusterState>();
    final client = clusterState.client;
    final isRunning = pod.status.toLowerCase().contains('running');

    return Scaffold(
      appBar: AppBar(
        title: Text(pod.name, style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.code),
            tooltip: 'YAML',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => YamlEditorScreen(
                    resourceName: pod.name,
                    initialYaml: const JsonEncoder.withIndent('  ').convert(pod.rawYaml),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            tooltip: 'Delete Pod',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Pod?'),
                  content: Text('Are you sure you want to terminate pod "${pod.name}"?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('DELETE', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await client.deleteResource(K8sResourceType.pod, pod.name, pod.namespace);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Pod ${pod.name} terminated')),
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.circle, size: 10, color: isRunning ? Colors.greenAccent : Colors.orangeAccent),
                      const SizedBox(width: 8),
                      Text(
                        pod.status,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isRunning ? Colors.greenAccent : Colors.orangeAccent,
                        ),
                      ),
                      const Spacer(),
                      Text('Age: ${pod.age}', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildDetailRow('Namespace', pod.namespace),
                  _buildDetailRow('Pod IP', pod.ip ?? 'Pending / None'),
                  _buildDetailRow('Node', pod.nodeName ?? 'linxr-master'),
                  _buildDetailRow('Restarts', '${pod.restarts}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Actions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.list_alt, color: Colors.blueAccent),
                  title: const Text('Live Logs'),
                  subtitle: const Text('Tail logs & stream container output'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LogsScreen(pod: pod)),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.terminal, color: Colors.greenAccent),
                  title: const Text('Pod Shell (Exec)'),
                  subtitle: const Text('Interactive terminal inside container'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => PodExecScreen(pod: pod)),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.edit_note, color: Colors.orangeAccent),
                  title: const Text('View / Edit Manifest'),
                  subtitle: const Text('Raw YAML / JSON resource specification'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => YamlEditorScreen(
                          resourceName: pod.name,
                          initialYaml: const JsonEncoder.withIndent('  ').convert(pod.rawYaml),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
