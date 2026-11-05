import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/cluster_state.dart';
import '../services/k8s_client.dart';
import '../theme/lens_theme.dart';
import 'yaml_editor_screen.dart';

class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  late Future<List<K8sResource>> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refresh();
  }

  void _refresh() {
    final clusterState = context.read<ClusterState>();
    setState(() {
      _future = clusterState.client.fetchResources(
        K8sResourceType.persistentVolumeClaim,
        namespace: clusterState.currentNamespace,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final clusterState = context.watch<ClusterState>();
    final isLive = clusterState.isLiveConnected;
    final isDemo = clusterState.isDemo;

    return Scaffold(
      backgroundColor: LensTheme.bgDark,
      appBar: AppBar(
        backgroundColor: LensTheme.bgDark,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.storage_rounded, color: LensTheme.cyanAccent, size: 20),
            const SizedBox(width: 8),
            const Text('Persistent Volumes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            LensTheme.namespaceBadge(clusterState.currentNamespace),
          ],
        ),
      ),
      body: (!isLive && !isDemo)
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off_rounded, size: 40, color: Colors.white.withOpacity(0.2)),
                  const SizedBox(height: 12),
                  const Text('Cluster Unreachable', style: TextStyle(color: LensTheme.textMuted)),
                ],
              ),
            )
          : FutureBuilder<List<K8sResource>>(
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
                        padding: const EdgeInsets.all(14),
                        decoration: LensTheme.cardDecoration(radius: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.disc_full_rounded, size: 18, color: LensTheme.cyanAccent),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    pvc.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: LensTheme.textPrimary),
                                  ),
                                ),
                                LensTheme.statusBadge(pvc.status),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                LensTheme.namespaceBadge(pvc.namespace),
                                const SizedBox(width: 8),
                                Text('Age: ${pvc.age}', style: const TextStyle(fontSize: 11, color: LensTheme.textMuted)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: LensTheme.bgDark.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: LensTheme.borderSubtle),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Capacity', style: TextStyle(fontSize: 10, color: LensTheme.textMuted)),
                                      Text(storage, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: LensTheme.cyanAccent)),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Access Mode', style: TextStyle(fontSize: 10, color: LensTheme.textMuted)),
                                      Text(accessModes, style: const TextStyle(fontSize: 11, color: LensTheme.textSecondary)),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('StorageClass', style: TextStyle(fontSize: 10, color: LensTheme.textMuted)),
                                      Text(sc, style: const TextStyle(fontSize: 11, color: LensTheme.blueAccent)),
                                    ],
                                  ),
                                ],
                              ),
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
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
