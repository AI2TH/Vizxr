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
      length: 6,
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
            Tab(text: 'Jobs'),
          ],
        ),
        body: const TabBarView(
          children: [
            WorkloadOverviewTab(),
            ResourceListView(type: K8sResourceType.pod),
            ResourceListView(type: K8sResourceType.deployment),
            ResourceListView(type: K8sResourceType.statefulSet),
            ResourceListView(type: K8sResourceType.daemonSet),
            ResourceListView(type: K8sResourceType.job),
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
        client.fetchResources(K8sResourceType.job, namespace: ns),
      ]).then((lists) => [...lists[0], ...lists[1], ...lists[2]]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final all = snapshot.data ?? [];
        final pods = all.where((r) => r.type == K8sResourceType.pod).toList();
        final deps = all.where((r) => r.type == K8sResourceType.deployment).toList();
        final jobs = all.where((r) => r.type == K8sResourceType.job).toList();

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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Pod Status Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            ns,
                            style: const TextStyle(fontSize: 11, color: Colors.lightBlueAccent, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
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
                      '${deps.length} active deployments in namespace "$ns"',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    if (deps.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('No deployments in this namespace.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      )
                    else
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
            if (jobs.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Batch Jobs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      ...jobs.map((j) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.task_alt, color: Colors.tealAccent),
                            title: Text(j.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            trailing: Text(j.status, style: const TextStyle(color: Colors.tealAccent, fontSize: 12)),
                          )),
                    ],
                  ),
                ),
              ),
            ],
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
                      onTap: () async {
                        if (res.type == K8sResourceType.pod) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => PodDetailScreen(pod: res)),
                          );
                          _refresh();
                        } else {
                          final modified = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => YamlEditorScreen(
                                resourceName: res.name,
                                initialYaml: const JsonEncoder.withIndent('  ').convert(res.rawYaml),
                              ),
                            ),
                          );
                          if (modified == true) _refresh();
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
                            final messenger = ScaffoldMessenger.of(context);
                            await client.restartDeployment(res.name, res.namespace);
                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(content: Text('Rollout restart initiated for ${res.name}')),
                            );
                            _refresh();
                            break;
                          case 'yaml':
                            final modified = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (context) => YamlEditorScreen(
                                  resourceName: res.name,
                                  initialYaml: const JsonEncoder.withIndent('  ').convert(res.rawYaml),
                                ),
                              ),
                            );
                            if (modified == true) _refresh();
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

  Future<void> _confirmDelete(K8sResource res, K8sClientService client) async {
    bool forceDelete = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Delete ${res.type.name}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to delete ${res.type.name} "${res.name}" in namespace "${res.namespace}"?'),
              const SizedBox(height: 14),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Force delete (grace period = 0)', style: TextStyle(fontSize: 13)),
                value: forceDelete,
                onChanged: (val) => setDialogState(() => forceDelete = val ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('DELETE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await client.deleteResource(res.type, res.name, res.namespace, force: forceDelete);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted ${res.type.name} "${res.name}"')),
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
      if (!mounted) return;
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
  final _podNameController = TextEditingController(text: 'my-app');
  final _podImageController = TextEditingController(text: 'nginx:alpine');
  final _podPortController = TextEditingController(text: '80');
  final _podEnvController = TextEditingController(text: 'PORT=80');

  final _depNameController = TextEditingController(text: 'web-service');
  final _depImageController = TextEditingController(text: 'redis:alpine');
  final _depPortController = TextEditingController(text: '6379');
  int _depReplicas = 2;

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
    _tabController = TabController(length: 4, vsync: this);
  }

  void _applyTemplate(String title, String yaml) {
    setState(() {
      _yamlController.text = yaml;
      _tabController.animateTo(3); // Switch to Raw Manifest Tab
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Loaded "$title" template into Manifest Editor')),
    );
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
              const Text('Create Kubernetes Resource', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Quick Pod'),
              Tab(text: 'Quick Deployment'),
              Tab(text: 'Templates'),
              Tab(text: 'Raw Manifest (YAML)'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 320,
            child: TabBarView(
              controller: _tabController,
              children: [
                // Quick Pod form
                ListView(
                  children: [
                    TextField(
                      controller: _podNameController,
                      decoration: const InputDecoration(labelText: 'Pod Name', isDense: true),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _podImageController,
                      decoration: const InputDecoration(labelText: 'Container Image', isDense: true),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: [
                        _buildImageChip('nginx:alpine', _podImageController),
                        _buildImageChip('redis:alpine', _podImageController),
                        _buildImageChip('busybox', _podImageController),
                        _buildImageChip('python:3.11-alpine', _podImageController),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _podPortController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Port (optional)', isDense: true),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _podEnvController,
                      decoration: const InputDecoration(labelText: 'Env (KEY=VAL, comma separated)', isDense: true),
                    ),
                    const SizedBox(height: 8),
                    Text('Target Namespace: $ns', style: const TextStyle(fontSize: 12, color: Colors.blueAccent)),
                  ],
                ),

                // Quick Deployment form
                ListView(
                  children: [
                    TextField(
                      controller: _depNameController,
                      decoration: const InputDecoration(labelText: 'Deployment Name', isDense: true),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _depImageController,
                      decoration: const InputDecoration(labelText: 'Container Image', isDense: true),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text('Replicas:', style: TextStyle(fontSize: 14)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: _depReplicas > 1 ? () => setState(() => _depReplicas--) : null,
                        ),
                        Text('$_depReplicas', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => setState(() => _depReplicas++),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _depPortController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Container Port', isDense: true),
                    ),
                  ],
                ),

                // Templates List
                ListView(
                  children: [
                    _buildTemplateItem(
                      'Nginx Web Server',
                      'Lightweight HTTP server on port 80',
                      Icons.language,
                      '''apiVersion: v1
kind: Pod
metadata:
  name: nginx-web
  namespace: default
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
''',
                    ),
                    _buildTemplateItem(
                      'Redis Cache Pod',
                      'In-memory key-value data store on port 6379',
                      Icons.memory,
                      '''apiVersion: v1
kind: Pod
metadata:
  name: redis-cache
  namespace: default
spec:
  containers:
  - name: redis
    image: redis:7.2-alpine
    ports:
    - containerPort: 6379
''',
                    ),
                    _buildTemplateItem(
                      'Busybox Debug Pod',
                      'Utility pod with sleep loop for kubectl exec testing',
                      Icons.bug_report,
                      '''apiVersion: v1
kind: Pod
metadata:
  name: debug-busybox
  namespace: default
spec:
  containers:
  - name: busybox
    image: busybox:latest
    command: ["sleep", "3600"]
''',
                    ),
                    _buildTemplateItem(
                      'Echo HTTP Server',
                      'Returns request headers & body on port 8080',
                      Icons.repeat,
                      '''apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo-server
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: echo
  template:
    metadata:
      labels:
        app: echo
    spec:
      containers:
      - name: echo
        image: ealen/echo-server:latest
        ports:
        - containerPort: 80
''',
                    ),
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
                    hintText: 'Paste Kubernetes YAML or JSON manifest here...',
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
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);

              if (_tabController.index == 0) {
                // Quick Pod
                final name = _podNameController.text.trim();
                final image = _podImageController.text.trim();
                final port = int.tryParse(_podPortController.text.trim());
                final envMap = <String, String>{};
                final envText = _podEnvController.text.trim();
                if (envText.isNotEmpty) {
                  for (final item in envText.split(',')) {
                    final parts = item.split('=');
                    if (parts.length == 2) {
                      envMap[parts[0].trim()] = parts[1].trim();
                    }
                  }
                }

                if (name.isNotEmpty && image.isNotEmpty) {
                  await client.createPod(
                    name: name,
                    namespace: ns,
                    image: image,
                    port: port,
                    env: envMap.isNotEmpty ? envMap : null,
                  );
                  if (!mounted) return;
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(content: Text('Pod "$name" created in namespace "$ns"!')),
                  );
                }
              } else if (_tabController.index == 1) {
                // Quick Deployment
                final name = _depNameController.text.trim();
                final image = _depImageController.text.trim();
                final port = int.tryParse(_depPortController.text.trim());
                if (name.isNotEmpty && image.isNotEmpty) {
                  await client.createDeployment(
                    name: name,
                    namespace: ns,
                    image: image,
                    replicas: _depReplicas,
                    port: port,
                  );
                  if (!mounted) return;
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(content: Text('Deployment "$name" created with $_depReplicas replicas!')),
                  );
                }
              } else {
                // Raw YAML / Selected Template
                final manifestText = _yamlController.text.trim();
                if (manifestText.isNotEmpty) {
                  final result = await client.applyManifest(manifestText, targetNamespace: ns);
                  if (!mounted) return;
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(result.message),
                      backgroundColor: result.success ? Colors.green[800] : Colors.red[800],
                    ),
                  );
                }
              }
            },
            child: const Text('CREATE / APPLY RESOURCE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildImageChip(String tag, TextEditingController controller) {
    return ActionChip(
      label: Text(tag, style: const TextStyle(fontSize: 11)),
      onPressed: () => setState(() => controller.text = tag),
    );
  }

  Widget _buildTemplateItem(String title, String desc, IconData icon, String yaml) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.blueAccent),
        title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Text(desc, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: () => _applyTemplate(title, yaml),
      ),
    );
  }
}
