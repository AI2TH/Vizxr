import 'package:flutter/material.dart';
import '../services/k8s_client.dart';
import 'logs_screen.dart';
import 'pod_exec_screen.dart';

class ExplorerScreen extends StatefulWidget {
  const ExplorerScreen({super.key});

  @override
  State<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends State<ExplorerScreen> {
  final K8sClientService _client = K8sClientService(baseUrl: 'https://127.0.0.1:6443');
  late Future<List<K8sResource>> _podsFuture;

  @override
  void initState() {
    super.initState();
    _podsFuture = _client.fetchResources(K8sResourceType.pod);
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
            onRefresh: () async {
              setState(() {
                _podsFuture = _client.fetchResources(K8sResourceType.pod);
              });
            },
            child: ListView.separated(
              itemCount: pods.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final pod = pods[index];
                return ListTile(
                  leading: Icon(
                    Icons.layers,
                    color: pod.status == 'Running' ? Colors.green : Colors.orange,
                  ),
                  title: Text(pod.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Namespace: ${pod.namespace} • Age: ${pod.age}'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: pod.status == 'Running' ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      pod.status,
                      style: TextStyle(
                        color: pod.status == 'Running' ? Colors.green : Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  onTap: () {
                    // Navigate to Pod detail / logs
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PodDetailScreen(pod: pod),
                      ),
                    );
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
    return Scaffold(
      appBar: AppBar(title: Text(pod.name)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: ListTile(
                title: const Text('Pod Information'),
                subtitle: Text('Status: ${pod.status}\nNamespace: ${pod.namespace}\nAge: ${pod.age}'),
              ),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.list_alt),
            title: const Text('Logs'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => LogsScreen(pod: pod)),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.terminal),
            title: const Text('Shell (Exec)'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PodExecScreen(pod: pod)),
              );
            },
          ),
        ],
      ),
    );
  }
}
