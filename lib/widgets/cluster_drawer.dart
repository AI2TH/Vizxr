import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/cluster_state.dart';
import '../screens/add_cluster_screen.dart';

class ClusterDrawer extends StatelessWidget {
  const ClusterDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final clusterState = context.watch<ClusterState>();

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.hub_rounded, size: 48, color: Colors.blueAccent),
                  const SizedBox(height: 10),
                  const Text(
                    'Vizxr K8s Clusters',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: clusterState.isLiveConnected ? Colors.greenAccent : Colors.orangeAccent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        clusterState.isLiveConnected ? 'Live Cluster Active' : 'Simulation / Local Standby',
                        style: TextStyle(
                          fontSize: 11,
                          color: clusterState.isLiveConnected ? Colors.greenAccent : Colors.orangeAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text(
                  'CLUSTERS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1),
                ),
                const Spacer(),
                Text(
                  '${clusterState.availableConfigs.length} configured',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: clusterState.availableConfigs.length,
              itemBuilder: (context, index) {
                final config = clusterState.availableConfigs[index];
                final isActive = clusterState.activeConfig?.name == config.name;
                final isLocal = config.server.contains('127.0.0.1') || config.server.contains('localhost');

                return Dismissible(
                  key: Key(config.name),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (dir) async {
                    if (isLocal) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cannot remove default Linxr cluster.')),
                      );
                      return false;
                    }
                    return true;
                  },
                  onDismissed: (dir) {
                    clusterState.deleteConfig(config.name);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Removed ${config.name}')),
                    );
                  },
                  background: Container(
                    color: Colors.red.withOpacity(0.8),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: ListTile(
                    leading: Icon(
                      isLocal ? Icons.smartphone_rounded : Icons.cloud_queue_rounded,
                      color: isActive ? Colors.blueAccent : Colors.grey,
                    ),
                    title: Text(
                      config.name,
                      style: TextStyle(
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        color: isActive ? Colors.blueAccent : Colors.white70,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      config.server,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: isActive
                        ? const Icon(Icons.check_circle_rounded, color: Colors.blueAccent, size: 18)
                        : null,
                    selected: isActive,
                    selectedTileColor: Colors.blue.withOpacity(0.08),
                    onTap: () {
                      clusterState.setConfig(config);
                      Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.add_circle_outline_rounded, color: Colors.greenAccent),
            title: const Text('Add Cluster / Kubeconfig'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddClusterScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
