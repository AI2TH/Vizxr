import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/cluster_state.dart';
import '../services/k8s_client.dart';
import '../theme/lens_theme.dart';
import 'yaml_editor_screen.dart';

class CrdScreen extends StatefulWidget {
  const CrdScreen({super.key});

  @override
  State<CrdScreen> createState() => _CrdScreenState();
}

class _CrdScreenState extends State<CrdScreen> {
  Future<List<K8sResource>>? _crdFuture;
  K8sClientService? _lastClient;
  String _searchQuery = '';
  String _selectedGroup = 'All';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final clusterState = Provider.of<ClusterState>(context);
    _loadFuture(clusterState);
  }

  void _loadFuture(ClusterState clusterState) {
    _lastClient = clusterState.client;
    _crdFuture = clusterState.client.fetchResources(K8sResourceType.customResourceDefinition);
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

    if (_lastClient != clusterState.client || _crdFuture == null) {
      _loadFuture(clusterState);
    }

    return Scaffold(
      backgroundColor: LensTheme.bgDark,
      appBar: AppBar(
        backgroundColor: LensTheme.bgDark,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: LensTheme.purpleAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.extension_rounded, color: LensTheme.purpleAccent, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Custom Resources',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: LensTheme.textPrimary),
                ),
                Text(
                  'Definitions & Extensions',
                  style: TextStyle(fontSize: 10, color: LensTheme.textMuted),
                ),
              ],
            ),
            const Spacer(),
            LensTheme.namespaceBadge(clusterState.currentNamespace, context: context),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20, color: LensTheme.textSecondary),
            tooltip: 'Refresh CRDs',
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.add_box_outlined, size: 20, color: LensTheme.purpleAccent),
            tooltip: 'Install Custom Resource Manifest',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const YamlEditorScreen(
                    resourceName: 'Custom Resource',
                    initialYaml: '''apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: myresources.example.com
spec:
  group: example.com
  scope: Namespaced
  names:
    plural: myresources
    singular: myresource
    kind: MyResource
    shortNames:
    - mr
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              replicas:
                type: integer
''',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: (!isLive && !isDemo)
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off_rounded, size: 48, color: Colors.white.withOpacity(0.2)),
                  const SizedBox(height: 14),
                  const Text(
                    'Cluster Unreachable',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: LensTheme.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Connect a live cluster or switch to Demo mode to explore CRDs',
                    style: TextStyle(fontSize: 12, color: LensTheme.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : FutureBuilder<List<K8sResource>>(
              future: _crdFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: LensTheme.purpleAccent));
                }

                final allCrds = snapshot.data ?? [];
                if (allCrds.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.extension_off_rounded, size: 44, color: Colors.white.withOpacity(0.2)),
                        const SizedBox(height: 12),
                        const Text(
                          'No CustomResourceDefinitions installed',
                          style: TextStyle(color: LensTheme.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                // Extract unique groups
                final groups = <String>{'All'};
                for (final crd in allCrds) {
                  final grp = crd.annotations['group'] ?? '';
                  if (grp.isNotEmpty) groups.add(grp);
                }

                // Filter CRDs
                final filtered = allCrds.where((crd) {
                  final grp = crd.annotations['group'] ?? '';
                  final kind = crd.annotations['kind'] ?? '';
                  final matchesGroup = _selectedGroup == 'All' || grp == _selectedGroup;
                  final q = _searchQuery.toLowerCase().trim();
                  final matchesQuery = q.isEmpty ||
                      crd.name.toLowerCase().contains(q) ||
                      grp.toLowerCase().contains(q) ||
                      kind.toLowerCase().contains(q);
                  return matchesGroup && matchesQuery;
                }).toList();

                return Column(
                  children: [
                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: LensTheme.bgInput,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: LensTheme.borderSubtle),
                        ),
                        child: TextField(
                          style: const TextStyle(fontSize: 13, color: LensTheme.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Search CRDs by kind, name, group...',
                            hintStyle: const TextStyle(fontSize: 12, color: LensTheme.textMuted),
                            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: LensTheme.textMuted),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 9),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16, color: LensTheme.textMuted),
                                    onPressed: () => setState(() => _searchQuery = ''),
                                  )
                                : null,
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val),
                        ),
                      ),
                    ),

                    // Group Filter Chips Bar
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Row(
                        children: groups.map((grp) {
                          final isSelected = _selectedGroup == grp;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(grp),
                              selected: isSelected,
                              labelStyle: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.white : LensTheme.textSecondary,
                              ),
                              backgroundColor: LensTheme.bgCard,
                              selectedColor: LensTheme.purpleAccent.withOpacity(0.35),
                              checkmarkColor: Colors.white,
                              side: BorderSide(
                                color: isSelected ? LensTheme.purpleAccent : LensTheme.borderSubtle,
                                width: 0.8,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              onSelected: (_) => setState(() => _selectedGroup = grp),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    // Count summary
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${filtered.length} CRD${filtered.length == 1 ? '' : 's'} Available',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: LensTheme.textMuted),
                          ),
                          Text(
                            _selectedGroup == 'All' ? 'All API Groups' : _selectedGroup,
                            style: const TextStyle(fontSize: 11, color: LensTheme.purpleAccent, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),

                    // List of CRDs
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async => _refresh(),
                        color: LensTheme.purpleAccent,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final crd = filtered[index];
                            return _buildCrdCard(context, crd);
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildCrdCard(BuildContext context, K8sResource crd) {
    final group = crd.annotations['group'] ?? 'custom';
    final version = crd.annotations['version'] ?? 'v1';
    final kind = crd.annotations['kind'] ?? crd.name;
    final scope = crd.annotations['scope'] ?? crd.status;
    final isNamespaced = scope.toLowerCase() == 'namespaced';

    // Extract shortnames if present in raw spec
    List<String> shortNames = [];
    final spec = (crd.rawYaml['spec'] as Map?) ?? {};
    final names = (spec['names'] as Map?) ?? {};
    if (names['shortNames'] is List) {
      shortNames = (names['shortNames'] as List).map((e) => e.toString()).toList();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: LensTheme.cardDecoration(radius: 14),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            // Drill down to Custom Resource instances
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CustomResourceInstancesScreen(crd: crd),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: LensTheme.purpleAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: LensTheme.purpleAccent.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.extension_rounded, size: 20, color: LensTheme.purpleAccent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                kind,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: LensTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: LensTheme.cyanAccent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  version,
                                  style: const TextStyle(fontSize: 10, color: LensTheme.cyanAccent, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            crd.name,
                            style: const TextStyle(fontSize: 11, color: LensTheme.textMuted, fontFamily: 'monospace'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Scope Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isNamespaced ? LensTheme.blueAccent.withOpacity(0.15) : LensTheme.statusAmber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isNamespaced ? LensTheme.blueAccent.withOpacity(0.4) : LensTheme.statusAmber.withOpacity(0.4),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        scope,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isNamespaced ? LensTheme.blueAccent : LensTheme.statusAmber,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Group Pill & Shortnames
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: LensTheme.bgDark,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: LensTheme.borderSubtle),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.corporate_fare_rounded, size: 12, color: LensTheme.purpleAccent),
                          const SizedBox(width: 4),
                          Text(
                            group,
                            style: const TextStyle(fontSize: 11, color: LensTheme.textSecondary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    if (shortNames.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: LensTheme.bgDark,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: LensTheme.borderSubtle),
                        ),
                        child: Text(
                          'aliases: ${shortNames.join(', ')}',
                          style: const TextStyle(fontSize: 11, color: LensTheme.textMuted, fontFamily: 'monospace'),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: LensTheme.bgDark,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: LensTheme.borderSubtle),
                      ),
                      child: Text(
                        'Age: ${crd.age}',
                        style: const TextStyle(fontSize: 11, color: LensTheme.textMuted),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: LensTheme.borderSubtle),
                const SizedBox(height: 8),

                // Action Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Drill down action button
                    ElevatedButton.icon(
                      icon: const Icon(Icons.data_object_rounded, size: 14),
                      label: const Text('Explore Objects', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LensTheme.purpleAccent.withOpacity(0.2),
                        foregroundColor: LensTheme.purpleAccent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: LensTheme.purpleAccent.withOpacity(0.4)),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CustomResourceInstancesScreen(crd: crd),
                          ),
                        );
                      },
                    ),

                    Row(
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.article_outlined, size: 14),
                          label: const Text('Schema YAML', style: TextStyle(fontSize: 11)),
                          style: TextButton.styleFrom(
                            foregroundColor: LensTheme.textSecondary,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => YamlEditorScreen(
                                  resourceName: crd.name,
                                  initialYaml: jsonEncode(crd.rawYaml),
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 16, color: LensTheme.statusRed),
                          tooltip: 'Delete CRD',
                          onPressed: () => _confirmDeleteCrd(context, crd),
                        ),
                      ],
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

  void _confirmDeleteCrd(BuildContext context, K8sResource crd) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LensTheme.bgCard,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: LensTheme.statusRed, size: 22),
            SizedBox(width: 8),
            Text('Delete CRD Definition', style: TextStyle(fontSize: 16, color: LensTheme.textPrimary)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${crd.name}"?\nThis will remove the definition and all custom resource instances across the cluster.',
          style: const TextStyle(fontSize: 13, color: LensTheme.textSecondary),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: LensTheme.statusRed),
            child: const Text('Delete CRD', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              Navigator.pop(ctx);
              final clusterState = context.read<ClusterState>();
              await clusterState.client.deleteResource(
                K8sResourceType.customResourceDefinition,
                crd.name,
                crd.namespace,
              );
              _refresh();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Deleted CRD: ${crd.name}')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Custom Resource Instances Explorer Screen
/// Displays all live instances/objects of a specific CRD (e.g., HelmCharts, Certificates, IngressRoutes)
class CustomResourceInstancesScreen extends StatefulWidget {
  final K8sResource crd;

  const CustomResourceInstancesScreen({super.key, required this.crd});

  @override
  State<CustomResourceInstancesScreen> createState() => _CustomResourceInstancesScreenState();
}

class _CustomResourceInstancesScreenState extends State<CustomResourceInstancesScreen> {
  late Future<List<K8sResource>> _instancesFuture;
  String _search = '';

  String get group => widget.crd.annotations['group'] ?? '';
  String get version => widget.crd.annotations['version'] ?? 'v1';
  String get plural => widget.crd.annotations['plural'] ?? widget.crd.name;
  String get kind => widget.crd.annotations['kind'] ?? widget.crd.name;
  String get scope => widget.crd.annotations['scope'] ?? 'Namespaced';
  bool get isNamespaced => scope.toLowerCase() == 'namespaced';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refresh();
  }

  void _refresh() {
    final clusterState = context.read<ClusterState>();
    setState(() {
      _instancesFuture = clusterState.client.fetchCustomResourceObjects(
        group: group,
        version: version,
        plural: plural,
        namespace: isNamespaced ? clusterState.currentNamespace : null,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final clusterState = context.watch<ClusterState>();

    return Scaffold(
      backgroundColor: LensTheme.bgDark,
      appBar: AppBar(
        backgroundColor: LensTheme.bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: LensTheme.cyanAccent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  kind,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: LensTheme.textPrimary),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: LensTheme.purpleAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$group/$version',
                    style: const TextStyle(fontSize: 10, color: LensTheme.purpleAccent, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            Text(
              'Instances (${widget.crd.name})',
              style: const TextStyle(fontSize: 11, color: LensTheme.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20, color: LensTheme.textSecondary),
            tooltip: 'Refresh Objects',
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 22, color: LensTheme.cyanAccent),
            tooltip: 'Create $kind',
            onPressed: _openCreateObjectDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: LensTheme.purpleAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text('Create $kind', style: const TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _openCreateObjectDialog,
      ),
      body: Column(
        children: [
          // Filter / Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: LensTheme.bgInput,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: LensTheme.borderSubtle),
              ),
              child: TextField(
                style: const TextStyle(fontSize: 13, color: LensTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search $kind objects by name...',
                  hintStyle: const TextStyle(fontSize: 12, color: LensTheme.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: LensTheme.textMuted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16, color: LensTheme.textMuted),
                          onPressed: () => setState(() => _search = ''),
                        )
                      : null,
                ),
                onChanged: (val) => setState(() => _search = val),
              ),
            ),
          ),

          // Namespace indicator row
          if (isNamespaced)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Text('Active Scope: ', style: TextStyle(fontSize: 11, color: LensTheme.textMuted)),
                  LensTheme.namespaceBadge(clusterState.currentNamespace, context: context),
                ],
              ),
            ),

          // Object list
          Expanded(
            child: FutureBuilder<List<K8sResource>>(
              future: _instancesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: LensTheme.purpleAccent));
                }

                final objects = snapshot.data ?? [];
                final filtered = objects.where((o) {
                  if (_search.isEmpty) return true;
                  return o.name.toLowerCase().contains(_search.toLowerCase().trim());
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_rounded, size: 44, color: Colors.white.withOpacity(0.2)),
                        const SizedBox(height: 12),
                        Text(
                          'No $kind instances found',
                          style: const TextStyle(color: LensTheme.textMuted, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isNamespaced
                              ? 'No objects found in namespace "${clusterState.currentNamespace}"'
                              : 'No objects found on cluster',
                          style: const TextStyle(color: LensTheme.textMuted, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: Text('Create $kind Object'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: LensTheme.purpleAccent,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _openCreateObjectDialog,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  color: LensTheme.purpleAccent,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 80),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _buildInstanceCard(context, item);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstanceCard(BuildContext context, K8sResource item) {
    Color statusColor = LensTheme.statusGreen;
    final st = item.status.toLowerCase();
    if (st.contains('fail') || st.contains('error') || st.contains('invalid')) {
      statusColor = LensTheme.statusRed;
    } else if (st.contains('pending') || st.contains('progress')) {
      statusColor = LensTheme.statusAmber;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: LensTheme.cardDecoration(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: LensTheme.purpleAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.hub_rounded, size: 18, color: LensTheme.purpleAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: LensTheme.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        LensTheme.namespaceBadge(item.namespace),
                        const SizedBox(width: 8),
                        Text('Age: ${item.age}', style: const TextStyle(fontSize: 11, color: LensTheme.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Text(
                  item.status,
                  style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          // Key spec highlights (if spec is present)
          if (item.rawYaml['spec'] is Map && (item.rawYaml['spec'] as Map).isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: LensTheme.bgDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: LensTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: (item.rawYaml['spec'] as Map)
                    .entries
                    .take(3)
                    .map(
                      (e) => Text(
                        '${e.key}: ${e.value}',
                        style: const TextStyle(fontSize: 11, color: LensTheme.textSecondary, fontFamily: 'monospace'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                    .toList(),
              ),
            ),
          ],

          const SizedBox(height: 10),
          const Divider(height: 1, color: LensTheme.borderSubtle),
          const SizedBox(height: 6),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.article_outlined, size: 14),
                label: const Text('View YAML', style: TextStyle(fontSize: 11)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => YamlEditorScreen(
                        resourceName: item.name,
                        initialYaml: jsonEncode(item.rawYaml),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: LensTheme.statusRed),
                tooltip: 'Delete $kind',
                onPressed: () => _confirmDeleteInstance(context, item),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDeleteInstance(BuildContext context, K8sResource item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LensTheme.bgCard,
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: LensTheme.statusRed, size: 22),
            const SizedBox(width: 8),
            Text('Delete $kind', style: const TextStyle(fontSize: 16, color: LensTheme.textPrimary)),
          ],
        ),
        content: Text(
          'Delete "$kind" named "${item.name}" from namespace "${item.namespace}"?',
          style: const TextStyle(fontSize: 13, color: LensTheme.textSecondary),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: LensTheme.statusRed),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              Navigator.pop(ctx);
              final clusterState = context.read<ClusterState>();
              await clusterState.client.deleteCustomResource(
                group: group,
                version: version,
                plural: plural,
                name: item.name,
                namespace: item.namespace,
              );
              _refresh();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Deleted $kind: ${item.name}')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _openCreateObjectDialog() {
    final clusterState = context.read<ClusterState>();
    final ns = isNamespaced ? clusterState.currentNamespace : 'none';
    final targetNs = ns == 'all-namespaces' ? 'default' : ns;

    final initialYaml = '''apiVersion: $group/$version
kind: $kind
metadata:
  name: demo-${kind.toLowerCase()}
  namespace: $targetNs
spec: {}
''';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => YamlEditorScreen(
          resourceName: 'New $kind',
          initialYaml: initialYaml,
        ),
      ),
    ).then((_) => _refresh());
  }
}
