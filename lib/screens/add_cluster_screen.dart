import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/cluster_state.dart';
import '../services/kubeconfig.dart';

class AddClusterScreen extends StatefulWidget {
  const AddClusterScreen({super.key});

  @override
  State<AddClusterScreen> createState() => _AddClusterScreenState();
}

class _AddClusterScreenState extends State<AddClusterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _yamlController = TextEditingController();
  final TextEditingController _nameController = TextEditingController(text: 'My K8s Cluster');
  final TextEditingController _serverController = TextEditingController(text: 'https://127.0.0.1:6443');
  final TextEditingController _tokenController = TextEditingController();
  bool _insecure = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Kubernetes Cluster'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Presets'),
            Tab(text: 'Kubeconfig'),
            Tab(text: 'Manual'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPresetsTab(),
                _buildYamlTab(),
                _buildManualTab(),
              ],
            ),
    );
  }

  Widget _buildPresetsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Quick 1-Tap Mobile Presets',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Connect immediately to local mobile Kubernetes runtimes without manual configuration.',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        _buildPresetCard(
          title: 'Linxr / Kubxr Local Node',
          subtitle: 'https://127.0.0.1:6443 (On-Device Mobile VM)',
          icon: Icons.smartphone_rounded,
          color: Colors.blueAccent,
          onTap: () async {
            final config = KubeConfig(
              name: 'Linxr Local Cluster',
              server: 'https://127.0.0.1:6443',
              insecureSkipTlsVerify: true,
            );
            await _saveAndFinish(config);
          },
        ),
        const SizedBox(height: 12),
        _buildPresetCard(
          title: 'Android Emulator Loopback',
          subtitle: 'https://10.0.2.2:6443 (Host machine cluster)',
          icon: Icons.laptop_chromebook,
          color: Colors.purpleAccent,
          onTap: () async {
            final config = KubeConfig(
              name: 'Host Workstation Cluster',
              server: 'https://10.0.2.2:6443',
              insecureSkipTlsVerify: true,
            );
            await _saveAndFinish(config);
          },
        ),
        const SizedBox(height: 12),
        _buildPresetCard(
          title: 'Demo Simulator Cluster',
          subtitle: 'Simulated multi-node Lens experience (offline ready)',
          icon: Icons.model_training,
          color: Colors.tealAccent,
          onTap: () async {
            final config = KubeConfig(
              name: 'Demo Cluster (Simulation)',
              server: 'https://demo.k8s.local',
              insecureSkipTlsVerify: true,
            );
            await _saveAndFinish(config);
          },
        ),
      ],
    );
  }

  Widget _buildPresetCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildYamlTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Paste your Kubeconfig (YAML)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Automatically extracts contexts, servers, namespaces, and auth tokens.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: _yamlController,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                hintText: 'apiVersion: v1\nkind: Config\nclusters:\n- cluster:\n    server: https://...\n...',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Color(0xFF0F172A),
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () async {
              final text = _yamlController.text.trim();
              if (text.isEmpty) return;
              setState(() => _isLoading = true);
              try {
                final config = await KubeConfig.addFromYaml(text);
                await context.read<ClusterState>().addConfig(config);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Cluster "${config.name}" added successfully!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: const Text('IMPORT KUBECONFIG', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildManualTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text(
          'Direct Cluster Parameters',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Cluster Display Name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _serverController,
          decoration: const InputDecoration(
            labelText: 'Kubernetes API Server URL',
            hintText: 'https://192.168.1.100:6443',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _tokenController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Bearer / ServiceAccount Token (Optional)',
            hintText: 'eyJhbGciOiJSUzI1NiIs...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Skip TLS Certificate Verification'),
          subtitle: const Text('Recommended for self-signed development & local clusters'),
          value: _insecure,
          onChanged: (val) => setState(() => _insecure = val),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: () async {
            final name = _nameController.text.trim();
            final server = _serverController.text.trim();
            final token = _tokenController.text.trim();
            if (name.isEmpty || server.isEmpty) return;

            final config = KubeConfig(
              name: name,
              server: server,
              token: token.isNotEmpty ? token : null,
              insecureSkipTlsVerify: _insecure,
            );
            await _saveAndFinish(config);
          },
          child: const Text('SAVE & CONNECT', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Future<void> _saveAndFinish(KubeConfig config) async {
    setState(() => _isLoading = true);
    await context.read<ClusterState>().addConfig(config);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to ${config.name}')),
      );
    }
  }
}
