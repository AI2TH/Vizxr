import 'package:flutter/material.dart';
import '../services/k8s_client.dart';
import '../widgets/resource_card.dart';
import 'explorer_screen.dart';

class WorkloadsScreen extends StatelessWidget {
  const WorkloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'Overview'),
            Tab(text: 'Pods'),
            Tab(text: 'Deployments'),
            Tab(text: 'StatefulSets'),
            Tab(text: 'DaemonSets'),
          ],
        ),
        body: const TabBarView(
          children: [
            Center(child: Text('Cluster Workload Summary')),
            ResourceListView(type: K8sResourceType.pod),
            ResourceListView(type: K8sResourceType.deployment),
            ResourceListView(type: K8sResourceType.statefulSet),
            ResourceListView(type: K8sResourceType.daemonSet),
          ],
        ),
      ),
    );
  }
}

class ResourceListView extends StatefulWidget {
  final K8sResourceType type;
  const ResourceListView({super.key, required this.type});

  @override
  State<ResourceListView> createState() => _ResourceListViewState();
}

class _ResourceListViewState extends State<ResourceListView> {
  final K8sClientService _client = K8sClientService(baseUrl: 'https://127.0.0.1:6443');
  late Future<List<K8sResource>> _future;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _future = _client.fetchResources(widget.type);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search ${widget.type.name}...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<K8sResource>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(child: Text('No ${widget.type.name} resources found.'));
              }

              final resources = snapshot.data!
                  .where((r) => r.name.toLowerCase().contains(_searchQuery))
                  .toList();

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: resources.length,
                itemBuilder: (context, index) {
                  final res = resources[index];
                  return ResourceCard(
                    resource: res,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => PodDetailScreen(pod: res)),
                      );
                    },
                    onAction: (action) async {
                      if (action == 'delete') {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Resource?'),
                            content: Text('Are you sure you want to delete ${res.name}? This cannot be undone.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('DELETE', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await _client.deleteResource(widget.type, res.name, res.namespace);
                          _refresh();
                        }
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
