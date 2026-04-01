import 'package:flutter/material.dart';
import '../services/k8s_client.dart';
import 'workloads_screen.dart';

class ConfigScreen extends StatelessWidget {
  const ConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: const TabBar(
          tabs: [
            Tab(text: 'ConfigMaps'),
            Tab(text: 'Secrets'),
          ],
        ),
        body: const TabBarView(
          children: [
            ResourceListView(type: K8sResourceType.configMap),
            ResourceListView(type: K8sResourceType.secret),
          ],
        ),
      ),
    );
  }
}
