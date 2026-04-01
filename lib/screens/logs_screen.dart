import 'package:flutter/material.dart';
import '../services/k8s_client.dart';

class LogsScreen extends StatelessWidget {
  final K8sResource pod;
  final K8sClientService _client = K8sClientService(baseUrl: 'https://127.0.0.1:6443');

  LogsScreen({super.key, required this.pod});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Logs: ${pod.name}')),
      backgroundColor: Colors.black,
      body: StreamBuilder<String>(
        stream: _client.streamLogs(pod.name),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            reverse: true, // Keep the view scrolled to the bottom
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                snapshot.data ?? '',
                style: const TextStyle(
                  color: Colors.lightGreenAccent,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
