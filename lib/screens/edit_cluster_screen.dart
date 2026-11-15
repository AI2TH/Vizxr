import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/cluster_state.dart';
import '../services/kubeconfig.dart';
import '../theme/lens_theme.dart';

/// Edits a saved cluster: API server, default namespace, CA and TLS checks.
class EditClusterScreen extends StatefulWidget {
  final KubeConfig config;

  const EditClusterScreen({super.key, required this.config});

  @override
  State<EditClusterScreen> createState() => _EditClusterScreenState();
}

class _EditClusterScreenState extends State<EditClusterScreen> {
  late final TextEditingController _serverController;
  late final TextEditingController _namespaceController;
  late final TextEditingController _caCertController;
  late bool _verifyTls;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.config;
    _serverController = TextEditingController(text: c.server);
    _namespaceController = TextEditingController(text: c.defaultNamespace);
    _caCertController = TextEditingController(text: c.caCert ?? '');
    _verifyTls = !c.insecureSkipTlsVerify;
  }

  @override
  void dispose() {
    _serverController.dispose();
    _namespaceController.dispose();
    _caCertController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final server = _serverController.text.trim();
    if (server.isEmpty) return;
    final ns = _namespaceController.text.trim();
    final ca = _caCertController.text.trim();
    setState(() => _saving = true);
    final updated = KubeConfig(
      name: widget.config.name,
      server: server,
      token: widget.config.token,
      caCert: ca.isEmpty ? null : ca,
      clientCertData: widget.config.clientCertData,
      clientKeyData: widget.config.clientKeyData,
      defaultNamespace: ns.isEmpty ? 'default' : ns,
      insecureSkipTlsVerify: !_verifyTls,
    );
    await context.read<ClusterState>().updateConfig(updated);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved "${updated.name}"')));
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LensTheme.bgCard,
        title: const Text('Remove cluster', style: TextStyle(fontSize: 16, color: LensTheme.textPrimary)),
        content: Text(
          'Remove "${widget.config.name}" and its saved credentials from this phone? The cluster itself is not touched.',
          style: const TextStyle(fontSize: 13, color: LensTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: LensTheme.statusRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<ClusterState>().deleteConfig(widget.config.storageKey);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final authLabel = widget.config.token != null && widget.config.token!.isNotEmpty
        ? 'Bearer token (stored in the Android Keystore)'
        : (widget.config.clientKeyData != null
            ? 'Client certificate (key stored in the Android Keystore)'
            : 'No credentials');

    return Scaffold(
      backgroundColor: LensTheme.bgDark,
      appBar: AppBar(
        backgroundColor: LensTheme.bgDark,
        elevation: 0,
        title: Text('Edit ${widget.config.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Remove cluster',
            icon: const Icon(Icons.delete_outline_rounded, color: LensTheme.statusRed),
            onPressed: _saving ? null : _delete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _serverController,
            decoration: const InputDecoration(labelText: 'Kubernetes API server URL'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _namespaceController,
            decoration: const InputDecoration(labelText: 'Default namespace'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _caCertController,
            maxLines: 3,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            decoration: const InputDecoration(labelText: 'Cluster CA certificate (PEM or base64)'),
          ),
          const SizedBox(height: 6),
          Text('Authentication: $authLabel', style: const TextStyle(fontSize: 11, color: LensTheme.textMuted)),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Verify TLS certificates', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text(
              _verifyTls
                  ? 'The API server certificate is checked against the CA above (or the system CAs).'
                  : 'Off: anyone on the network path can read your credentials. Paste the cluster CA and turn this on.',
              style: TextStyle(fontSize: 11, color: _verifyTls ? LensTheme.textMuted : LensTheme.statusAmber),
            ),
            value: _verifyTls,
            activeColor: LensTheme.cyanAccent,
            onChanged: (val) => setState(() => _verifyTls = val),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: LensTheme.cyanAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _saving ? null : _save,
            child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }
}

/// Small amber badge for clusters that skip TLS verification.
class InsecureTlsBadge extends StatelessWidget {
  const InsecureTlsBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'TLS verification is off for this cluster',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: LensTheme.statusAmber.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: LensTheme.statusAmber.withOpacity(0.6)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 10, color: LensTheme.statusAmber),
            SizedBox(width: 3),
            Text('TLS off', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: LensTheme.statusAmber)),
          ],
        ),
      ),
    );
  }
}
