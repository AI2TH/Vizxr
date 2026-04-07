import 'package:flutter/material.dart';
import '../services/kubeconfig.dart';

class AddClusterScreen extends StatefulWidget {
  const AddClusterScreen({super.key});

  @override
  State<AddClusterScreen> createState() => _AddClusterScreenState();
}

class _AddClusterScreenState extends State<AddClusterScreen> {
  final TextEditingController _yamlController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Cluster')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Paste your Kubeconfig (YAML) or ServiceAccount Token below.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _yamlController,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  hintText: 'apiVersion: v1\nkind: Config\n...',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Color(0xFF1E1E1E),
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (_yamlController.text.isNotEmpty) {
                  await KubeConfig.addFromYaml(_yamlController.text);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cluster added successfully')),
                  );
                }
              },
              child: const Text('IMPORT CLUSTER'),
            ),
            const SizedBox(height: 16),
            const Text(
              'For AKS/GKE, ensure you use a Static Token or ServiceAccount as Cloud CLIs are not available on mobile.',
              style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}
