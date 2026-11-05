import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/cluster_state.dart';
import '../services/k8s_client.dart';
import '../theme/lens_theme.dart';
import '../widgets/resource_card.dart';
import '../widgets/resource_inspector_sheet.dart';
import 'logs_screen.dart';
import 'pod_exec_screen.dart';
import 'yaml_editor_screen.dart';

class WorkloadsScreen extends StatefulWidget {
  const WorkloadsScreen({super.key});

  @override
  State<WorkloadsScreen> createState() => _WorkloadsScreenState();
}

class _WorkloadsScreenState extends State<WorkloadsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<K8sResourceType> _categories = [
    K8sResourceType.pod,
    K8sResourceType.deployment,
    K8sResourceType.statefulSet,
    K8sResourceType.daemonSet,
    K8sResourceType.job,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
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
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                child: Row(
                  children: [
                    const Icon(Icons.layers_rounded, color: LensTheme.cyanAccent, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Workloads Explorer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: LensTheme.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const Spacer(),
                    LensTheme.namespaceBadge(clusterState.currentNamespace, context: context),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _WorkloadsTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: LensTheme.cyanAccent,
                  indicatorWeight: 2.5,
                  labelColor: LensTheme.cyanAccent,
                  unselectedLabelColor: LensTheme.textMuted,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabAlignment: TabAlignment.start,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  tabs: const [
                    Tab(text: 'Pods'),
                    Tab(text: 'Deployments'),
                    Tab(text: 'StatefulSets'),
                    Tab(text: 'DaemonSets'),
                    Tab(text: 'Jobs'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: _categories.map((type) => WorkloadCategoryView(type: type)).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: LensTheme.cyanAccent,
        foregroundColor: Colors.black,
        elevation: 6,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Deploy Workload',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.3),
        ),
        onPressed: () => _showCreateWorkloadSheet(context),
      ),
    );
  }

  void _showCreateWorkloadSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: LensTheme.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const CreateWorkloadSheet(),
    );
  }
}

class WorkloadCategoryView extends StatefulWidget {
  final K8sResourceType type;
  const WorkloadCategoryView({super.key, required this.type});

  @override
  State<WorkloadCategoryView> createState() => _WorkloadCategoryViewState();
}

class _WorkloadCategoryViewState extends State<WorkloadCategoryView> {
  Future<List<K8sResource>>? _future;
  K8sClientService? _lastClient;
  String? _lastNamespace;
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final clusterState = Provider.of<ClusterState>(context);
    _loadFuture(clusterState);
  }

  void _loadFuture(ClusterState clusterState) {
    _lastClient = clusterState.client;
    _lastNamespace = clusterState.currentNamespace;
    _future = clusterState.client.fetchResources(
      widget.type,
      namespace: clusterState.currentNamespace,
    );
  }

  void _refresh() {
    final clusterState = context.read<ClusterState>();
    setState(() {
      _loadFuture(clusterState);
    });
  }

  @override
  Widget build(BuildContext context) {
    final clusterState = context.watch<ClusterState>();
    final isLive = clusterState.isLiveConnected;
    final isDemo = clusterState.isDemo;

    if (_lastClient != clusterState.client || _lastNamespace != clusterState.currentNamespace || _future == null) {
      _loadFuture(clusterState);
    }

    if (!isLive && !isDemo) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: LensTheme.statusRed.withOpacity(0.12),
                  border: Border.all(color: LensTheme.statusRed.withOpacity(0.4), width: 1.5),
                ),
                child: const Center(
                  child: Icon(Icons.cloud_off_rounded, size: 28, color: LensTheme.statusRed),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Cluster Unreachable',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: LensTheme.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'Real cluster is offline. Fake pods are hidden to guarantee accurate diagnostics.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: LensTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: const Text('Switch to Demo Simulation'),
                style: ElevatedButton.styleFrom(backgroundColor: LensTheme.purpleAccent, foregroundColor: Colors.white),
                onPressed: () {
                  final demoConfig = clusterState.availableConfigs.firstWhere(
                    (c) => c.name.contains('Demo') || c.server.contains('demo'),
                    orElse: () => clusterState.availableConfigs.first,
                  );
                  clusterState.setConfig(demoConfig);
                },
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Search & Filter Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: LensTheme.bgInput,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: LensTheme.borderSubtle),
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Filter ${widget.type.name}s...',
                      hintStyle: const TextStyle(fontSize: 12, color: LensTheme.textMuted),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: LensTheme.textMuted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      isDense: true,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Quick Status Filter Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: ['All', 'Running', 'Pending', 'Failed'].map((status) {
              final isSelected = _statusFilter == status;
              return Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 6),
                child: ChoiceChip(
                  label: Text(status),
                  selected: isSelected,
                  selectedColor: LensTheme.cyanAccent.withOpacity(0.18),
                  backgroundColor: LensTheme.bgInput,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? LensTheme.cyanAccent : LensTheme.textSecondary,
                  ),
                  side: BorderSide(
                    color: isSelected ? LensTheme.cyanAccent.withOpacity(0.5) : LensTheme.borderSubtle,
                    width: 0.8,
                  ),
                  onSelected: (selected) {
                    if (selected) setState(() => _statusFilter = status);
                  },
                ),
              );
            }).toList(),
          ),
        ),

        // Resource List
        Expanded(
          child: FutureBuilder<List<K8sResource>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: LensTheme.cyanAccent));
              } else if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error: ${snapshot.error}', style: const TextStyle(color: LensTheme.statusRed, fontSize: 12)),
                  ),
                );
              }

              final all = snapshot.data ?? [];
              final filtered = all.where((r) {
                final matchesSearch = r.name.toLowerCase().contains(_searchQuery);
                if (!matchesSearch) return false;
                if (_statusFilter == 'All') return true;
                return r.status.toLowerCase().contains(_statusFilter.toLowerCase());
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.layers_clear_rounded, size: 44, color: Colors.white.withOpacity(0.15)),
                      const SizedBox(height: 10),
                      Text(
                        'No ${widget.type.name}s found in ${clusterState.currentNamespace}',
                        style: const TextStyle(fontSize: 13, color: LensTheme.textMuted),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                color: LensTheme.cyanAccent,
                backgroundColor: LensTheme.bgSurface,
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 85),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final res = filtered[index];
                    return ResourceCard(
                      resource: res,
                      onTap: () {
                        ResourceInspectorSheet.show(
                          context,
                          resource: res,
                          onResourceChanged: () => _refresh(),
                        );
                      },
                      onAction: (action) => _handleAction(res, action),
                      onScale: res.type == K8sResourceType.deployment
                          ? (delta) async {
                              final parts = res.status.split('/');
                              final current = int.tryParse(parts.first.trim()) ?? 1;
                              final newReplicas = (current + delta).clamp(0, 50);
                              await clusterState.client.scaleDeployment(res.name, res.namespace, newReplicas);
                              _refresh();
                            }
                          : null,
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

  void _handleAction(K8sResource res, String action) async {
    final clusterState = context.read<ClusterState>();

    if (action == 'logs') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LogsScreen(pod: res)),
      );
    } else if (action == 'exec') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PodExecScreen(pod: res)),
      );
    } else if (action == 'yaml') {
      final modified = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => YamlEditorScreen(
            resourceName: res.name,
            initialYaml: _yamlString(res.rawYaml),
          ),
        ),
      );
      if (modified == true) _refresh();
    } else if (action == 'restart') {
      await clusterState.client.restartDeployment(res.name, res.namespace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Triggered rollout restart for "${res.name}"')),
        );
      }
      _refresh();
    } else if (action == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: LensTheme.bgSurface,
          title: const Text('Confirm Deletion', style: TextStyle(color: LensTheme.statusRed, fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete ${res.type.name} "${res.name}" from namespace "${res.namespace}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: LensTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: LensTheme.statusRed, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await clusterState.client.deleteResource(res.type, res.name, res.namespace);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted ${res.type.name} "${res.name}"')),
          );
        }
        _refresh();
      }
    }
  }

  String _yamlString(Map<String, dynamic> raw) {
    final buffer = StringBuffer();
    raw.forEach((k, v) => buffer.writeln('$k: $v'));
    return buffer.toString();
  }
}

class PodDetailScreen extends StatelessWidget {
  final K8sResource pod;
  const PodDetailScreen({super.key, required this.pod});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LensTheme.bgDark,
      appBar: AppBar(
        title: Text(pod.name, style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.terminal_rounded, color: LensTheme.cyanAccent),
            tooltip: 'View Logs',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LogsScreen(pod: pod))),
          ),
          IconButton(
            icon: const Icon(Icons.code_rounded, color: LensTheme.blueAccent),
            tooltip: 'Shell Exec',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PodExecScreen(pod: pod))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: LensTheme.cardDecoration(radius: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      pod.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: LensTheme.textPrimary),
                    ),
                    LensTheme.statusBadge(pod.status),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: LensTheme.borderSubtle),
                const SizedBox(height: 10),
                _buildRow('Namespace', pod.namespace),
                _buildRow('Age', pod.age),
                _buildRow('Restarts', '${pod.restarts}'),
                _buildRow('Pod IP', pod.ip ?? 'None (HostNetwork)'),
                _buildRow('Node', pod.nodeName ?? 'Unassigned'),
                _buildRow('Containers', pod.containers.join(', ')),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.terminal_rounded, size: 16),
                  label: const Text('Pod Logs'),
                  style: ElevatedButton.styleFrom(backgroundColor: LensTheme.cyanAccent, foregroundColor: Colors.black),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LogsScreen(pod: pod))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.code_rounded, size: 16),
                  label: const Text('Exec Shell'),
                  style: ElevatedButton.styleFrom(backgroundColor: LensTheme.blueAccent, foregroundColor: Colors.black),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PodExecScreen(pod: pod))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
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

class CreateWorkloadSheet extends StatefulWidget {
  const CreateWorkloadSheet({super.key});

  @override
  State<CreateWorkloadSheet> createState() => _CreateWorkloadSheetState();
}

class _CreateWorkloadSheetState extends State<CreateWorkloadSheet> {
  final _nameController = TextEditingController(text: 'my-app');
  final _imageController = TextEditingController(text: 'nginx:alpine');
  final _portController = TextEditingController(text: '80');
  String _selectedKind = 'Deployment';
  int _replicas = 1;

  @override
  Widget build(BuildContext context) {
    final clusterState = context.read<ClusterState>();

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Deploy New Workload',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: LensTheme.textPrimary),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: LensTheme.textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Template Quick Picks
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTemplatePill('Nginx', 'nginx:alpine', 80),
                _buildTemplatePill('Redis', 'redis:alpine', 6379),
                _buildTemplatePill('Busybox', 'busybox:latest', null),
                _buildTemplatePill('Postgres', 'postgres:15-alpine', 5432),
              ],
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Workload Name', isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _imageController,
            decoration: const InputDecoration(labelText: 'Container Image', isDense: true),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _portController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Container Port', isDense: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedKind,
                  decoration: const InputDecoration(labelText: 'Kind', isDense: true),
                  dropdownColor: LensTheme.bgSurface,
                  items: ['Deployment', 'Pod'].map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedKind = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: LensTheme.cyanAccent,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () async {
              final name = _nameController.text.trim();
              final image = _imageController.text.trim();
              final port = int.tryParse(_portController.text.trim());
              final ns = clusterState.currentNamespace == 'all-namespaces' ? 'default' : clusterState.currentNamespace;

              if (name.isEmpty || image.isEmpty) return;

              if (_selectedKind == 'Deployment') {
                await clusterState.client.createDeployment(name: name, namespace: ns, image: image, port: port, replicas: _replicas);
              } else {
                await clusterState.client.createPod(name: name, namespace: ns, image: image, port: port);
              }

              if (mounted) {
                Navigator.pop(context);
                clusterState.triggerReload();
              }
            },
            child: const Text('Deploy to Cluster', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplatePill(String label, String image, int? port) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        backgroundColor: LensTheme.bgInput,
        side: const BorderSide(color: LensTheme.borderSubtle),
        onPressed: () {
          setState(() {
            _nameController.text = label.toLowerCase();
            _imageController.text = image;
            _portController.text = port != null ? '$port' : '';
          });
        },
      ),
    );
  }
}

class _WorkloadsTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _WorkloadsTabBarDelegate(this.tabBar);

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
  bool shouldRebuild(_WorkloadsTabBarDelegate oldDelegate) => false;
}
