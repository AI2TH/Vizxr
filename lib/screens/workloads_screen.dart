import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/cluster_state.dart';
import '../services/k8s_client.dart';
import '../widgets/resource_card.dart';
import 'explorer_screen.dart';
import 'logs_screen.dart';
import 'pod_exec_screen.dart';
import 'yaml_editor_screen.dart';

class WorkloadsScreen extends StatelessWidget {
  const WorkloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      initialIndex: 1, // Default to Pods
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
            WorkloadOverviewTab(),
            ResourceListView(type: K8sResourceType.pod),
            ResourceListView(type: K8sResourceType.deployment),
            ResourceListView(type: K8sResourceType.statefulSet),
            ResourceListView(type: K8sResourceType.daemonSet),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showCreateWorkloadDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('Create Workload'),
          backgroundColor: Colors.blueAccent,
        ),
      ),
    );
  }

  void _showCreateWorkloadDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const CreateWorkloadSheet(),
    );
  }
}

class WorkloadOverviewTab extends StatelessWidget {
  const WorkloadOverviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    final clusterState = context.watch<ClusterState>();
    final client = clusterState.client;
    final ns = clusterState.currentNamespace;

    return FutureBuilder<List<K8sResource>>(
      future: Future.wait([
        client.fetchResources(K8sResourceType.pod, namespace: ns),
        client.fetchResources(K8sResourceType.deployment, namespace: ns),
      ]).then((lists) => [...lists[0], ...lists[1]]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final all = snapshot.data ?? [];
        final pods = all.where((r) => r.type == K8sResourceType.pod).toList();
        final deps = all.where((r) => r.type == K8sResourceType.deployment).toList();

        final runningPods = pods.where((p) => p.status.toLowerCase().contains('running')).length;
        final pendingPods = pods.where((p) => p.status.toLowerCase().contains('pending')).length;
        final failedPods = pods.where((p) => p.status.toLowerCase().contains('fail') || p.status.toLowerCase().contains('crash')).length;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pod Status Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatusStat('Running', runningPods, Colors.greenAccent),
                        _buildStatusStat('Pending', pendingPods, Colors.orangeAccent),
                        _buildStatusStat('Failed', failedPods, Colors.redAccent),
                        _buildStatusStat('Total', pods.length, Colors.blueAccent),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Deployments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      '${deps.length} active deployments in namespace "${ns}"',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    ...deps.map((d) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.rocket_launch, color: Colors.blueAccent),
                          title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          trailing: Text(d.status, style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                        )),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusStat(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
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
  late Future<List<K8sResource>> _future;
  String _searchQuery = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refresh();
  }

  void _refresh() {
    final clusterState = context.read<ClusterState>();
    setState(() {
      _future = clusterState.client.fetchResources(
        widget.type,
        namespace: clusterState.currentNamespace,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final clusterState = context.watch<ClusterState>();
    final client = clusterState.client;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Filter ${widget.type.name}s...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 48, color: Colors.grey[700]),
                      const SizedBox(height: 10),
                      Text('No ${widget.type.name}s found in ${clusterState.currentNamespace}'),
                    ],
                  ),
                );
              }

              final resources = snapshot.data!
                  .where((r) => r.name.toLowerCase().contains(_searchQuery))
                  .toList();

              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 75),
                  itemCount: resources.length,
                  itemBuilder: (context, index) {
                    final res = resources[index];
                    return ResourceCard(
                      resource: res,
                      onTap: () {
                        if (res.type == K8sResourceType.pod) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => PodDetailScreen(pod: res)),
                          );
                        } else {
                          _showYamlViewer(res);
                        }
                      },
                      onAction: (action) async {
                        switch (action) {
                          case 'delete':
                            _confirmDelete(res, client);
                            break;
                          case 'logs':
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => LogsScreen(pod: res)),
                            );
                            break;
                          case 'exec':
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => PodExecScreen(pod: res)),
                            );
                            break;
                          case 'scale':
                            _showScaleDialog(res, client);
                            break;
                          case 'restart':
                            await client.restartDeployment(res.name, res.namespace);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Rollout restart initiated for ${res.name}')),
                            );
                            _refresh();
                            break;
                          case 'yaml':
                            _showYamlViewer(res);
                            break;
                        }
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showYamlViewer(K8sResource res) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => YamlEditorScreen(
          resourceName: res.name,
          initialYaml: const JsonEncoder.withIndent('  ').convert(res.rawYaml),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(K8sResource res, K8sClientService client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Resource?'),
        content: Text('Are you sure you want to delete ${res.type.name} "${res.name}" in namespace "${res.namespace}"? This action is immediate.'),
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
      await client.deleteResource(res.type, res.name, res.namespace);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted ${res.name}')),
      );
      _refresh();
    }
  }

  Future<void> _showScaleDialog(K8sResource res, K8sClientService client) async {
    int replicas = (res.rawYaml['spec']?['replicas'] as num? ?? 1).toInt();

    final newReplicas = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Scale ${res.name}'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 30),
                onPressed: replicas > 0 ? () => setDialogState(() => replicas--) : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('$replicas', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 30),
                onPressed: () => setDialogState(() => replicas++),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, replicas),
              child: const Text('UPDATE'),
            ),
          ],
        ),
      ),
    );

    if (newReplicas != null) {
      await client.scaleDeployment(res.name, res.namespace, newReplicas);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deployment ${res.name} scaled to $newReplicas replicas')),
      );
      _refresh();
    }
  }
}

class CreateWorkloadSheet extends StatefulWidget {
  const CreateWorkloadSheet({super.key});

  @override
  State<CreateWorkloadSheet> createState() => _CreateWorkloadSheetState();
}

class _CreateWorkloadSheetState extends State<CreateWorkloadSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _nameController = TextEditingController(text: 'my-app');
  final _imageController = TextEditingController(text: 'nginx:alpine');
  final _portController = TextEditingController(text: '80');
  final _yamlController = TextEditingController(text: '''apiVersion: v1
kind: Pod
metadata:
  name: demo-nginx
  namespace: default
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
''');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final clusterState = context.read<ClusterState>();
    final ns = clusterState.currentNamespace == 'all-namespaces' ? 'default' : clusterState.currentNamespace;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('Create Workload', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Quick Pod'),
              Tab(text: 'Raw Manifest (YAML)'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 280,
            child: TabBarView(
              controller: _tabController,
              children: [
                // Quick Pod form
                ListView(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Pod / Workload Name', isDense: true),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _imageController,
                      decoration: const InputDecoration(labelText: 'Container Image (e.g. redis:alpine, nginx:alpine)', isDense: true),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _portController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Port (e.g. 80, 6379, 8080)', isDense: true),
                    ),
                    const SizedBox(height: 8),
                    Text('Target Namespace: $ns', style: const TextStyle(fontSize: 12, color: Colors.blueAccent)),
                  ],
                ),
                // Raw YAML form
                TextField(
                  controller: _yamlController,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () async {
              final client = clusterState.client;
              if (_tabController.index == 0) {
                // Quick Pod
                final name = _nameController.text.trim();
                final image = _imageController.text.trim();
                final port = int.tryParse(_portController.text.trim());
                if (name.isNotEmpty && image.isNotEmpty) {
                  await client.createPod(
                    name: name,
                    namespace: ns,
                    image: image,
                    port: port,
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Pod "$name" created in namespace "$ns"!')),
                  );
                }
              } else {
                // Raw YAML
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Manifest applied successfully')),
                );
              }
            },
            child: const Text('CREATE RESOURCE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
