import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/cluster_state.dart';
import '../services/kubeconfig.dart';
import '../theme/lens_theme.dart';
import '../screens/add_cluster_screen.dart';
import '../screens/crd_screen.dart';
import '../screens/helm_screen.dart';

class ClusterDrawer extends StatelessWidget {
  const ClusterDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final clusterState = context.watch<ClusterState>();
    final activeConfig = clusterState.activeConfig;
    final isLive = clusterState.isLiveConnected;
    final isDemo = clusterState.isDemo;

    return Drawer(
      backgroundColor: LensTheme.bgDark,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                gradient: LensTheme.headerGradient,
                border: Border(bottom: BorderSide(color: LensTheme.borderSubtle)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/logo.png',
                          width: 34,
                          height: 34,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: LensTheme.cyanAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: LensTheme.cyanAccent.withOpacity(0.4), width: 1),
                            ),
                            child: const Icon(Icons.hub_rounded, size: 20, color: LensTheme.cyanAccent),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'VIZXR',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: LensTheme.textPrimary,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            'Kubernetes IDE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: LensTheme.cyanAccent,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: LensTheme.textMuted),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Active Cluster Status Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: LensTheme.cardDecoration(
                      borderColor: isDemo
                          ? LensTheme.purpleAccent.withOpacity(0.4)
                          : (isLive ? LensTheme.statusGreen.withOpacity(0.4) : LensTheme.statusRed.withOpacity(0.4)),
                      radius: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDemo ? LensTheme.purpleAccent : (isLive ? LensTheme.statusGreen : LensTheme.statusRed),
                            boxShadow: [
                              BoxShadow(
                                color: (isDemo ? LensTheme.purpleAccent : (isLive ? LensTheme.statusGreen : LensTheme.statusRed))
                                    .withOpacity(0.8),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activeConfig?.name ?? 'No Cluster Active',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: LensTheme.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                isDemo
                                    ? 'Simulation / Demo Mode'
                                    : (isLive ? 'Active mTLS Connection' : 'Cluster Offline / Standby'),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDemo ? LensTheme.purpleAccent : (isLive ? LensTheme.statusGreen : LensTheme.statusRed),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Section Label
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'AVAILABLE CLUSTERS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: LensTheme.textMuted,
                    ),
                  ),
                  Text(
                    '${clusterState.availableConfigs.length} configured',
                    style: const TextStyle(fontSize: 10, color: LensTheme.textMuted),
                  ),
                ],
              ),
            ),

            // Configs List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: clusterState.availableConfigs.length,
                itemBuilder: (context, index) {
                  final config = clusterState.availableConfigs[index];
                  final isActive = clusterState.activeConfig?.name == config.name;
                  final isDemoItem = config.name.contains('Demo') || config.server.contains('demo');

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive ? LensTheme.cyanAccent.withOpacity(0.08) : LensTheme.bgCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isActive ? LensTheme.cyanAccent.withOpacity(0.5) : LensTheme.borderSubtle,
                        width: 1,
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      leading: Icon(
                        isDemoItem
                            ? Icons.auto_awesome_rounded
                            : (config.server.contains('127.0.0.1') ? Icons.smartphone_rounded : Icons.cloud_queue_rounded),
                        color: isDemoItem
                            ? LensTheme.purpleAccent
                            : (isActive ? LensTheme.cyanAccent : LensTheme.textMuted),
                        size: 20,
                      ),
                      title: Text(
                        config.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                          color: isActive ? LensTheme.cyanAccent : LensTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        config.server,
                        style: const TextStyle(fontSize: 10, color: LensTheme.textMuted, fontFamily: 'monospace'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: isActive
                          ? const Icon(Icons.check_circle_rounded, color: LensTheme.cyanAccent, size: 18)
                          : null,
                      onTap: () {
                        clusterState.setConfig(config);
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),

            // Helm Charts & Releases Quick Access Tile
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: LensTheme.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: LensTheme.cyanAccent.withOpacity(0.3)),
              ),
              child: ListTile(
                dense: true,
                leading: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: LensTheme.cyanAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.anchor_rounded, size: 18, color: LensTheme.cyanAccent),
                ),
                title: const Text(
                  'Helm Hub & Releases',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: LensTheme.textPrimary),
                ),
                subtitle: const Text(
                  'Charts Catalog, Values & Deployments',
                  style: TextStyle(fontSize: 10, color: LensTheme.textMuted),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: LensTheme.cyanAccent),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HelmScreen()),
                  );
                },
              ),
            ),

            // CRD Quick Access Tile
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: LensTheme.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: LensTheme.purpleAccent.withOpacity(0.3)),
              ),
              child: ListTile(
                dense: true,
                leading: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: LensTheme.purpleAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.extension_rounded, size: 18, color: LensTheme.purpleAccent),
                ),
                title: const Text(
                  'Custom Resources (CRDs)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: LensTheme.textPrimary),
                ),
                subtitle: const Text(
                  'Certificates, Helm, Traefik & APIs',
                  style: TextStyle(fontSize: 10, color: LensTheme.textMuted),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: LensTheme.purpleAccent),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CrdScreen()),
                  );
                },
              ),
            ),

            const Divider(height: 1, color: LensTheme.borderSubtle),

            // Bottom Actions
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                    label: const Text('Add Cluster / Import Kubeconfig'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LensTheme.cyanAccent,
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(42),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AddClusterScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.folder_open_rounded, size: 16, color: LensTheme.textSecondary),
                    label: const Text('Scan Device for K3s YAML'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                      side: const BorderSide(color: LensTheme.borderSubtle),
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      final detected = await KubeConfig.autoDetectLinxrKubeconfig();
                      if (detected != null) {
                        await clusterState.refreshConfigs();
                        await clusterState.setConfig(detected);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Imported cluster: ${detected.name}')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No kubeconfig detected in /sdcard/Linxr/k3s.yaml or Downloads.')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
