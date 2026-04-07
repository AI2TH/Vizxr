import 'package:flutter/material.dart';
import '../services/k8s_client.dart';
import 'workloads_screen.dart';

class StorageScreen extends StatelessWidget {
  const StorageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: const TabBar(
          tabs: [
            Tab(text: 'PersistentVolumeClaims'),
            Tab(text: 'StorageClasses'),
          ],
        ),
        body: const TabBarView(
          children: [
            ResourceListView(type: K8sResourceType.persistentVolumeClaim),
            Center(child: Text('Storage Classes (Standard, Fast)')),
          ],
        ),
      ),
    );
  }
}
