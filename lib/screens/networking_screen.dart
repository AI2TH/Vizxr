import 'package:flutter/material.dart';
import '../services/k8s_client.dart';
import 'workloads_screen.dart';

class NetworkingScreen extends StatelessWidget {
  const NetworkingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: const TabBar(
          tabs: [
            Tab(text: 'Services'),
            Tab(text: 'Ingresses'),
          ],
        ),
        body: const TabBarView(
          children: [
            ResourceListView(type: K8sResourceType.service),
            ResourceListView(type: K8sResourceType.ingress),
          ],
        ),
      ),
    );
  }
}
