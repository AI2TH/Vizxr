import 'package:flutter/material.dart';
import '../services/k8s_client.dart';
import 'workloads_screen.dart';

class StorageScreen extends StatelessWidget {
  const StorageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 1,
      child: Scaffold(
        appBar: TabBar(
          tabs: [
            Tab(text: 'PersistentVolumeClaims'),
          ],
        ),
        body: TabBarView(
          children: [
            ResourceListView(type: K8sResourceType.persistentVolumeClaim),
          ],
        ),
      ),
    );
  }
}
