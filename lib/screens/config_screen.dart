import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/cluster_state.dart';
import '../services/k8s_client.dart';
import '../theme/lens_theme.dart';
import '../widgets/resource_inspector_sheet.dart';
import 'yaml_editor_screen.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> with SingleTickerProviderStateMixin {
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
            const Icon(Icons.tune_rounded, color: LensTheme.cyanAccent, size: 20),
            const SizedBox(width: 8),
            const Text('Config & Storage', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
            Tab(text: 'ConfigMaps'),
            Tab(text: 'Secrets'),
            Tab(text: 'Storage / PVCs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ConfigResourceList(type: K8sResourceType.configMap),
          _ConfigResourceList(type: K8sResourceType.secret),
          _StorageTabList(),
        ],
      ),
    );
  }
}

class _StorageTabList extends StatefulWidget {
  const _StorageTabList();

  @override
  State<_StorageTabList> createState() => _StorageTabListState();
}

class _StorageTabListState extends State<_StorageTabList> {
  Future<List<K8sResource>>? _future;
  K8sClientService? _lastClient;
  String? _lastNamespace;

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
      K8sResourceType.persistentVolumeClaim,
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
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: LensTheme.cyanAccent));
        }

        final pvcs = snapshot.data ?? [];
        if (pvcs.isEmpty) {
          return Center(
            child: Text(
              'No PVCs found in ${clusterState.currentNamespace}',
              style: const TextStyle(color: LensTheme.textMuted, fontSize: 13),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          color: LensTheme.cyanAccent,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            itemCount: pvcs.length,
            itemBuilder: (context, index) {
              final pvc = pvcs[index];
              final spec = (pvc.rawYaml['spec'] as Map?) ?? {};
              final storage = spec['resources']?['requests']?['storage']?.toString() ?? '10Gi';
              final accessModes = (spec['accessModes'] as List?)?.join(', ') ?? 'ReadWriteOnce';
              final sc = spec['storageClassName']?.toString() ?? 'local-path';

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: LensTheme.cardDecoration(radius: 14),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => ResourceInspectorSheet.show(context, resource: pvc, onResourceChanged: _refresh),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: LensTheme.cyanAccent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.storage_rounded, size: 20, color: LensTheme.cyanAccent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pvc.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: LensTheme.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  LensTheme.namespaceBadge(pvc.namespace),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Age: ${pvc.age}',
                                    style: const TextStyle(fontSize: 11, color: LensTheme.textMuted),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: LensTheme.statusGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: LensTheme.statusGreen.withOpacity(0.4)),
                          ),
                          child: Text(
                            pvc.status,
                            style: const TextStyle(fontSize: 11, color: LensTheme.statusGreen, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildStorageInfoBadge('Capacity', storage, LensTheme.cyanAccent),
                        const SizedBox(width: 8),
                        _buildStorageInfoBadge('Access', accessModes, LensTheme.blueAccent),
                        const SizedBox(width: 8),
                        _buildStorageInfoBadge('Class', sc, LensTheme.purpleAccent),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: LensTheme.borderSubtle),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.article_outlined, size: 15),
                          label: const Text('View YAML', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => YamlEditorScreen(
                                  resourceName: pvc.name,
                                  initialYaml: pvc.rawYaml.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
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
            },
          ),
        );
      },
    );
  }

  Widget _buildStorageInfoBadge(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: LensTheme.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: LensTheme.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 9, color: LensTheme.textMuted)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigResourceList extends StatefulWidget {
  final K8sResourceType type;
  const _ConfigResourceList({required this.type});

  @override
  State<_ConfigResourceList> createState() => _ConfigResourceListState();
}

class _ConfigResourceListState extends State<_ConfigResourceList> {
  Future<List<K8sResource>>? _future;
  K8sClientService? _lastClient;
  String? _lastNamespace;
  final Set<String> _revealedSecrets = {};

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
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: LensTheme.cyanAccent));
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Text(
              'No ${widget.type.name}s in ${clusterState.currentNamespace}',
              style: const TextStyle(color: LensTheme.textMuted, fontSize: 13),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          color: LensTheme.cyanAccent,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final res = items[index];
              return _buildItemCard(context, res);
            },
          ),
        );
      },
    );
  }

  Widget _buildItemCard(BuildContext context, K8sResource res) {
    final isSecret = widget.type == K8sResourceType.secret;
    final dataMap = (res.rawYaml['data'] as Map?) ?? {};
    final keys = dataMap.keys.toList();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: LensTheme.cardDecoration(
        borderColor: isSecret ? LensTheme.purpleAccent.withOpacity(0.3) : LensTheme.borderSubtle,
        radius: 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => ResourceInspectorSheet.show(context, resource: res, onResourceChanged: _refresh),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Icon(
                  isSecret ? Icons.lock_outline_rounded : Icons.description_outlined,
                  size: 18,
                  color: isSecret ? LensTheme.purpleAccent : LensTheme.blueAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    res.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: LensTheme.textPrimary),
                  ),
                ),
                const Icon(Icons.info_outline_rounded, size: 16, color: LensTheme.cyanAccent),
                const SizedBox(width: 6),
                LensTheme.namespaceBadge(res.namespace),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${keys.length} keys configured • Age: ${res.age}',
            style: const TextStyle(fontSize: 11, color: LensTheme.textMuted),
          ),
          if (keys.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: LensTheme.bgDark.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: LensTheme.borderSubtle),
              ),
              child: Column(
                children: keys.map((k) {
                  final keyStr = k.toString();
                  final valRaw = dataMap[k]?.toString() ?? '';
                  final isRevealed = _revealedSecrets.contains('${res.name}:$keyStr');

                  String displayVal = valRaw;
                  if (isSecret) {
                    if (isRevealed) {
                      try {
                        displayVal = utf8.decode(base64.decode(valRaw));
                      } catch (_) {
                        displayVal = valRaw;
                      }
                    } else {
                      displayVal = '••••••••••••••••';
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Text('$keyStr:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: LensTheme.cyanAccent)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            displayVal,
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: LensTheme.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSecret) ...[
                          IconButton(
                            icon: Icon(
                              isRevealed ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              size: 16,
                              color: isRevealed ? LensTheme.purpleAccent : LensTheme.textMuted,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            tooltip: isRevealed ? 'Hide' : 'Reveal Base64',
                            onPressed: () {
                              setState(() {
                                final id = '${res.name}:$keyStr';
                                if (isRevealed) {
                                  _revealedSecrets.remove(id);
                                } else {
                                  _revealedSecrets.add(id);
                                }
                              });
                            },
                          ),
                        ],
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 14, color: LensTheme.textMuted),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          tooltip: 'Copy value',
                          onPressed: () {
                            String copyText = valRaw;
                            if (isSecret) {
                              try {
                                copyText = utf8.decode(base64.decode(valRaw));
                              } catch (_) {}
                            }
                            Clipboard.setData(ClipboardData(text: copyText));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Copied "$keyStr" to clipboard')),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1, color: LensTheme.borderSubtle),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.article_outlined, size: 15),
                label: const Text('View YAML', style: TextStyle(fontSize: 11)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => YamlEditorScreen(
                        resourceName: res.name,
                        initialYaml: res.rawYaml.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
