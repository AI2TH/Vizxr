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
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF2C3E50)),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hub, size: 48, color: Colors.blue),
                  SizedBox(height: 10),
                  Text('K8s Clusters', style: TextStyle(fontSize: 20, color: Colors.white)),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: clusterState.availableConfigs.length,
              itemBuilder: (context, index) {
                final config = clusterState.availableConfigs[index];
                final isActive = clusterState.activeConfig == config;
                return ListTile(
                  leading: Icon(Icons.cloud_queue, color: isActive ? Colors.blue : Colors.grey),
                  title: Text(config.name, style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
                  subtitle: Text(config.server, style: const TextStyle(fontSize: 11)),
                  selected: isActive,
                  selectedTileColor: Colors.blue.withOpacity(0.1),
                  onTap: () {
                    clusterState.setConfig(config);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.add, color: Colors.green),
            title: const Text('Add Cluster'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddClusterScreen()),
              ).then((_) => clusterState.refreshConfigs());
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
